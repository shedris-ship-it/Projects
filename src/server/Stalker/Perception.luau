-- The stalker's senses (doc section 5, "Perception model"). It only acts on
-- what it has seen, heard or remembered: no wallhacks.
--   Vision:  ~100 degree cone, 40 studs in lit rooms, 15 in the dark, longer
--            if the target's flashlight is on; raycast line of sight.
--   Hearing: noise events with radii (NoiseService).
--   Memory:  last-known position per Witness, confidence decaying over 30 s.
-- Also answers the observation rule: who is watching it right now.

local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Constants = require(Shared.Constants)
local StalkRules = require(Shared.Logic.StalkRules)

local S = Config.Stalker
local PA = Constants.PlayerAttributes

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

local Perception = {}
Perception.__index = Perception

-- body: StalkerModel's parts; bodyCtl: Stalker/Body (where his head really
-- is for the pose clients are drawing, e.g. leaning round a door frame).
function Perception.new(services, body, bodyCtl)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { body.model }
	params.RespectCanCollide = true
	return setmetatable({
		services = services,
		body = body,
		bodyCtl = bodyCtl,
		memory = {}, -- player -> { position, facing, t, confidence, seen }
		-- Noises nobody's position is behind: a thrown thing landing, a flush,
		-- a radio left on (docs/plans/gameplay-rework.md section 4.9).
		lures = {}, -- { position, t, radius, checked }
		followed = {}, -- when he went to check one (too many and he gets wary)
		watchTime = {}, -- player -> seconds continuously watched (in the light)
		beamHeld = {}, -- player -> seconds their full beam has held him, alone
		lastWatch = nil, -- { lit, dark, beams, roomLit } for the overlay
		visibleList = {}, -- players he can see this tick, nearest first
		hearingMultiplier = 1,
		params = params,
	}, Perception)
end

function Perception:Reset()
	self.memory = {}
	self.lures = {}
	self.followed = {}
	self.watchTime = {}
	self.beamHeld = {}
	self.visibleList = {}
end

function Perception:_rayParams()
	return self.params
end

function Perception:EyePosition(): Vector3
	if self.bodyCtl then
		return self.bodyCtl:EyePosition()
	end
	local head = self.body.head
	return head and head.Position or (self.body.root.Position + Vector3.new(0, 3, 0))
end

-- Is the player safe from the hunt in a lit Lantern room with company?
function Perception:InSafeRoom(player: Player): boolean
	local services = self.services
	local pos = services.PlayerStateService:Position(player)
	if not pos then
		return false
	end
	local roomId = services.WorldService:RoomAt(pos)
	if not services.WorldService:IsLanternRoom(roomId) then
		return false
	end
	local company = 0
	for _, other in services.PlayerStateService:LivingPlayers() do
		local otherPos = services.PlayerStateService:Position(other)
		if otherPos and services.WorldService:RoomAt(otherPos) == roomId then
			company += 1
		end
	end
	local companion = services.CompanionService
	if companion and companion:IsPresent() then
		local cpos = companion:GetPosition()
		if cpos and services.WorldService:RoomAt(cpos) == roomId then
			company += 1
		end
	end
	-- Alone, your own company is enough (Config.Run.LanternCompany: the
	-- owner's RE save room, 2026-10-06); with friends it takes two of you.
	local squad = math.clamp(#services.PlayerStateService:RunPlayers(), 1, 4)
	local need = (Config.Run.LanternCompany or {})[squad] or 2
	return company >= need
end

-- Can the stalker see this player right now?
function Perception:CanSee(player: Player): boolean
	local services = self.services
	if services.HidingService:IsHidden(player) then
		return false
	end
	local character = player.Character
	local root = services.PlayerStateService:Root(player)
	if not character or not root then
		return false
	end
	local eye = self:EyePosition()
	local target = root.Position + Vector3.new(0, 1, 0)
	local offset = target - eye
	local distance = offset.Magnitude
	local lit = services.WorldService:IsLit(root.Position)
		or services.PlayerStateService:FlashlightOn(player)
		or player:GetAttribute("LanternOn") == true
	local range = lit and S.VisionRangeLit or S.VisionRangeDark
	if distance > range then
		return false
	end
	-- Very close: it senses you regardless of facing.
	if distance > 5 then
		local forward = self.body.root.CFrame.LookVector
		local flatOffset = Vector3.new(offset.X, 0, offset.Z)
		if
			flatOffset.Magnitude > 0.1
			and forward:Dot(flatOffset.Unit) < math.cos(math.rad(S.VisionConeDegrees / 2))
		then
			return false
		end
	end
	local result = Workspace:Raycast(eye, offset, self:_rayParams())
	return result == nil or result.Instance:IsDescendantOf(character)
end

function Perception:_remember(player: Player, position: Vector3, confidence: number, seen: boolean, facing: Vector3?)
	local existing = self.memory[player]
	local now = os.clock()
	if existing and not seen then
		-- A sound doesn't override a fresher, more certain sighting.
		local currentConfidence = existing.confidence * math.max(0, 1 - (now - existing.t) / S.MemorySeconds)
		if currentConfidence > confidence then
			return
		end
	end
	self.memory[player] = { position = position, facing = facing, t = now, confidence = confidence, seen = seen }
end

-- The newest lure he hasn't looked into, no older than `maxAge` seconds.
function Perception:FreshLure(maxAge: number)
	local now = os.clock()
	for i = #self.lures, 1, -1 do
		local lure = self.lures[i]
		if now - lure.t > maxAge then
			break
		end
		if not lure.checked then
			return lure
		end
	end
	return nil
end

-- He went to look. Returns how many lures he has followed lately, this one
-- included: a squad that leans on them finds him slower to fall for the next.
function Perception:FollowLure(lure, window: number): number
	lure.checked = true
	local now = os.clock()
	for i = #self.followed, 1, -1 do
		if now - self.followed[i] > window then
			table.remove(self.followed, i)
		end
	end
	table.insert(self.followed, now)
	return #self.followed
end

-- How wary he is of lures: 1 fresh, smaller the more he's followed lately.
function Perception:LureTrust(window: number, factor: number): number
	local now, count = os.clock(), 0
	for _, t in self.followed do
		if now - t <= window then
			count += 1
		end
	end
	return factor ^ count
end

function Perception:Confidence(player: Player): number
	local m = self.memory[player]
	if not m then
		return 0
	end
	return m.confidence * math.max(0, 1 - (os.clock() - m.t) / S.MemorySeconds)
end

-- Freshest memory worth acting on.
function Perception:BestMemory(exclude: { [Player]: boolean }?)
	local best, bestPlayer, bestScore = nil, nil, 0.08
	for player, m in self.memory do
		if player.Parent and not (exclude and exclude[player]) then
			local score = self:Confidence(player)
			if score > bestScore then
				best, bestPlayer, bestScore = m, player, score
			end
		end
	end
	return bestPlayer, best
end

-- Players currently visible, nearest first.
function Perception:Visible(): { { player: Player, distance: number } }
	local list = {}
	local services = self.services
	local here = self.body.root.Position
	for _, player in services.PlayerStateService:LivingPlayers() do
		if not self:InSafeRoom(player) and self:CanSee(player) then
			local pos = services.PlayerStateService:Position(player)
			table.insert(list, { player = player, distance = (pos - here).Magnitude })
		end
	end
	table.sort(list, function(a, b)
		return a.distance < b.distance
	end)
	return list
end

-- Update memory from sight and from noises heard since the last tick.
function Perception:Update(hearingBoost: number?)
	local services = self.services
	-- Kept for this tick so Stalk can see who is right next to him without
	-- casting the same rays again.
	self.visibleList = self:Visible()
	for _, entry in self.visibleList do
		local root = services.PlayerStateService:Root(entry.player)
		if root then
			self:_remember(entry.player, root.Position, 1, true, root.CFrame.LookVector)
		end
	end
	local here = self.body.root.Position
	local multiplier = self.hearingMultiplier * (hearingBoost or 1)
	for _, noise in services.NoiseService:Drain() do
		-- A floor muffles it to half its reach; the hall and the stairwells
		-- carry it (owner, 2026-10-04; Logic/Storeys).
		local radius = services.WorldService:AudibleRadius(noise.radius, noise.position, here)
		if (noise.position - here).Magnitude <= radius * multiplier then
			if noise.source and noise.source.Parent then
				self:_remember(noise.source, noise.position, S.MemoryHeardConfidence, false)
			elseif noise.kind == "impact" or noise.kind == "lure" then
				-- Nobody's position, but something to go and look at.
				table.insert(self.lures, { position = noise.position, t = os.clock(), radius = noise.radius })
				if #self.lures > 6 then
					table.remove(self.lures, 1)
				end
			end
			self.lastHeard = { position = noise.position, t = os.clock(), kind = noise.kind }
		end
	end
end

-- Is he in this player's light at `point` (Logic/StalkRules.litFor)? Also
-- answers whether it's their full beam that lights him.
function Perception:_litFor(player: Player, point: Vector3, roomLit: boolean, cfg): (boolean, boolean)
	local services = self.services
	local ps = services.PlayerStateService
	local view = services.WitnessService:GetView(player)
	local distance, beamAngle = math.huge, 180
	if view then
		local offset = point - view.Position
		distance = offset.Magnitude
		if distance > 0.01 then
			beamAngle = math.deg(math.acos(math.clamp(view.LookVector:Dot(offset.Unit), -1, 1)))
		end
	end
	local clipAngle = 180
	local root = ps:Root(player)
	if root then
		local offset = flat(point - root.Position)
		local facing = flat(root.CFrame.LookVector)
		if offset.Magnitude > 0.01 and facing.Magnitude > 0.01 then
			clipAngle = math.deg(math.acos(math.clamp(facing.Unit:Dot(offset.Unit), -1, 1)))
		end
	end
	local torchOn = ps:FlashlightOn(player)
	local clipped = services.ToolService:TorchClipped(player)
	local ctx = {
		distance = distance,
		roomLit = roomLit,
		beamOn = torchOn and not clipped,
		beamAngle = beamAngle,
		clipOn = torchOn and clipped,
		clipAngle = clipAngle,
		lanternOn = player:GetAttribute("LanternOn") == true,
	}
	local beam = ctx.beamOn and distance <= cfg.BeamRange and beamAngle <= cfg.BeamHalfAngle
	return StalkRules.litFor(ctx, cfg), beam
end

-- The observation rule: update continuous watch time per player and return
-- the list of watchers. Since the owner's audit (2026-10-06) a look counts
-- only while he is in that player's light (Config.Stare: the room, their
-- beam or clip light, a lit Lantern, or arm's length), and the Companion no
-- longer counts. Alone, a full beam held steady on him stands in for the
-- second pair of eyes (a "beam" entry in the list), and the battery pays.
function Perception:Watchers(dt: number, visibleTo: { [Player]: boolean }): { any }
	local services = self.services
	local cfg = Config.Stare
	-- His head and chest as clients draw them (a peeking head sticks out of
	-- a doorway while his body is behind the wall).
	local points = self.bodyCtl and self.bodyCtl:ExposedPoints() or { self.body.root.Position + Vector3.new(0, 1.5, 0) }
	local ignore = { self.body.model }
	local roomLit = services.WorldService:IsLit(self.body.root.Position)
	local active = services.PlayerStateService:ActivePlayers()
	local alone = #active == 1
	local watchers = {}
	local lit, dark, beams = 0, 0, 0
	for _, player in active do
		local looking, inLight, beam = false, false, false
		if visibleTo[player] == true then
			for _, point in points do
				if services.WitnessService:IsLookingAt(player, point, S.WatchConeDegrees, S.WatchRange, ignore) then
					looking = true
					inLight, beam = self:_litFor(player, point, roomLit, cfg)
					break
				end
			end
		end
		local counts = looking and inLight
		if looking and not counts then
			dark += 1
		elseif counts then
			lit += 1
		end
		self.watchTime[player] = counts and (self.watchTime[player] or 0) + dt or 0
		local watching = self.watchTime[player] >= S.WatchedAfterSeconds
		if watching then
			table.insert(watchers, player)
		end
		-- Alone: a steady full beam on him counts double, and drains the battery.
		local holding = alone and cfg.SoloBeam and counts and beam
		self.beamHeld[player] = holding and (self.beamHeld[player] or 0) + dt or 0
		local held = watching and self.beamHeld[player] >= cfg.SoloBeamSeconds
		if held then
			beams += 1
		end
		if (player:GetAttribute(PA.BeamHold) == true) ~= held then
			player:SetAttribute(PA.BeamHold, held or nil)
		end
	end
	if beams > 0 then
		table.insert(watchers, "beam")
	end
	self.lastWatch = { lit = lit, dark = dark, beams = beams, roomLit = roomLit }
	return watchers
end

-- Is anyone (regardless of visibility rules) looking toward this position?
-- Used to keep relocations out of sight.
function Perception:AnyoneLookingAt(position: Vector3, cone: number?): boolean
	local services = self.services
	for _, player in services.PlayerStateService:LivingPlayers() do
		if services.WitnessService:IsLookingAt(player, position, cone or 110, 140, { self.body.model }) then
			return true
		end
	end
	return false
end

Perception.Tag = Constants.Tags.Stalker

return Perception
