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

local S = Config.Stalker

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
		watchTime = {}, -- player -> seconds continuously watched
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
	return company >= 2
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

-- The observation rule: update continuous watch time per Witness and return
-- the list of watchers (players, plus "companion" if it backs one up).
function Perception:Watchers(dt: number, visibleTo: { [Player]: boolean }): { any }
	local services = self.services
	-- His head and chest as clients draw them (a peeking head sticks out of
	-- a doorway while his body is behind the wall).
	local points = self.bodyCtl and self.bodyCtl:ExposedPoints() or { self.body.root.Position + Vector3.new(0, 1.5, 0) }
	local torso = points[#points]
	local ignore = { self.body.model }
	local watchers = {}
	for _, player in services.PlayerStateService:ActivePlayers() do
		local looking = false
		if visibleTo[player] == true then
			for _, point in points do
				if services.WitnessService:IsLookingAt(player, point, S.WatchConeDegrees, S.WatchRange, ignore) then
					looking = true
					break
				end
			end
		end
		if looking then
			self.watchTime[player] = (self.watchTime[player] or 0) + dt
		else
			self.watchTime[player] = 0
		end
		if self.watchTime[player] >= S.WatchedAfterSeconds then
			table.insert(watchers, player)
		end
	end
	if #watchers >= 1 then
		local companion = services.CompanionService
		if
			companion
			and companion:IsPresent()
			and (companion:CanSee(torso, ignore) or companion:CanSee(points[1], ignore))
		then
			table.insert(watchers, "companion")
		end
	end
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
