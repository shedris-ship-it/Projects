-- Hiding spots (doc section 5, "Hide mechanics"): beds, curtains and tables
-- (E hides you), and closets, wardrobes and lockers (you walk in). Capacity
-- 1-2, a noise value, spot heat that the stalker learns from, and a
-- hold-breath meter. You can't slip into a spot while the stalker has direct
-- line of sight to you.
--
-- Walk-in places are physical spots: walk-in closets (gameplay rework 4.8),
-- and since the owner's word of 2026-10-09 ("I want wardrobes and lockers
-- that you can open or slide the door and physically step into and close
-- it") wardrobes and lockers too. No prompt, no teleport, no invisibility:
-- you're hidden while you stand inside with every door shut and your light
-- off, and not the moment you step out, a door opens or your light comes on
-- (it shows through the slats). You look out through the louvres with your
-- own eyes. If he watched you get in, he knows. His inspection opens the
-- doors.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Constants = require(Shared.Constants)
local HideRules = require(Shared.Logic.HideRules)
local Net = require(Shared.Net)
local Signal = require(Shared.Lib.Signal)

local PA = Constants.PlayerAttributes

local HidingService = {
	Entered = Signal.new(), -- (player, spot)
	Left = Signal.new(), -- (player, spot, forced): forced when found or pulled out
}

local hidden: { [Player]: any } = {} -- player -> { spot, breath, holding, gaspUntil, lastBreathNoise }
local shutIn: { [Player]: any } = {} -- player -> the walk-in place they stand in, its doors shut
local seenGoingIn: { [Player]: number } = {} -- player -> when he last saw them in a walk-in's open door
local glowSeen: { [Player]: any } = {} -- player -> the walk-in whose lit slats he noticed

function HidingService:Init(services)
	self.services = services
	self.World = services.WorldService
	self.PlayerState = services.PlayerStateService
	self.Noise = services.NoiseService
	self.SquadProfile = services.SquadProfileService
end

function HidingService:Start()
	self.World.Built:Connect(function(world)
		for _, spot in world.hidingSpots do
			self:_setup(spot)
		end
	end)
	self.World.Cleared:Connect(function()
		for player in table.clone(hidden) do
			self:ForceLeave(player)
		end
		self.physical = {}
		table.clear(shutIn)
		table.clear(seenGoingIn)
		table.clear(glowSeen)
	end)
	Net.onServer("LeaveHiding", { interval = 0.3, types = {} }, function(player)
		self:Leave(player)
	end)
	-- Peeking out (Logic/HideRules): what you see widens, and he may notice.
	Net.onServer("HidePeek", { interval = 0.05, types = { "boolean" } }, function(player, on)
		local state = hidden[player]
		if state and not state.spot.physical then
			local peeking = on == true
			if peeking ~= (state.peekSince ~= nil) then
				state.peekSince = peeking and os.clock() or nil
				state.noticed = false
				player:SetAttribute(PA.Peeking, peeking or nil)
			end
		end
	end)
	Net.onServer("HoldBreath", { interval = 0.05, types = { "boolean" } }, function(player, holding)
		local state = hidden[player]
		if state then
			state.holding = holding == true and os.clock() >= state.gaspUntil
		end
	end)
	RunService.Heartbeat:Connect(function(dt)
		self:_tick(dt)
	end)
end

local function notify(player, text, kind)
	Net.get("Notify"):FireClient(player, text, kind or "info")
end

function HidingService:_setup(spot)
	if spot.physical then
		self.physical = self.physical or {}
		table.insert(self.physical, spot)
		return
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "HidePrompt"
	prompt.ActionText = "Hide"
	prompt.ObjectText = spot.label
	prompt.HoldDuration = 0.25
	prompt.MaxActivationDistance = 7
	prompt.RequiresLineOfSight = false
	-- At the top of the anchor (a wardrobe's middle, a bed's top), not its
	-- low middle: Roblox shows a prompt only while it's on screen, and a
	-- player close to a locker looks at its door, not its feet (the owner's
	-- solo playtest, 2026-10-08; E's focus fires only a prompt Roblox shows).
	local at = Instance.new("Attachment")
	at.Name = "PromptAt"
	at.Position = Vector3.new(0, spot.anchor.Size.Y / 2, 0)
	at.Parent = spot.anchor
	prompt.Parent = at
	prompt.Triggered:Connect(function(player)
		self:Enter(player, spot)
	end)
	spot.prompt = prompt
end

local function setCharacterVisible(character: Model, visible: boolean)
	for _, d in character:GetDescendants() do
		if (d:IsA("BasePart") and d.Name ~= "HumanoidRootPart") or d:IsA("Decal") then
			if visible then
				local original = d:GetAttribute("HideOriginalTransparency")
				if original ~= nil then
					d.Transparency = original
					d:SetAttribute("HideOriginalTransparency", nil)
				end
			else
				if d:GetAttribute("HideOriginalTransparency") == nil then
					d:SetAttribute("HideOriginalTransparency", d.Transparency)
				end
				d.Transparency = 1
			end
		end
	end
end

function HidingService:Enter(player: Player, spot)
	if hidden[player] or not self.PlayerState:CanAct(player) then
		return
	end
	if #spot.occupants >= spot.capacity then
		notify(player, "There's no room in there.", "warning")
		return
	end
	local stalker = self.services.StalkerService
	if stalker and stalker:CanSeePlayer(player) then
		notify(player, "Not while it's watching you.", "danger")
		return
	end
	self.PlayerState:SetCrouch(player, false)
	local character = player.Character
	local root = self.PlayerState:Root(player)
	if not character or not root then
		return
	end
	table.insert(spot.occupants, player)
	spot.heat += 1
	hidden[player] =
		{ spot = spot, breath = Config.Player.BreathMax, holding = false, gaspUntil = 0, lastBreathNoise = 0 }
	self.PlayerState:SetFlashlight(player, false)
	self.PlayerState:MarkTeleport(player)
	-- Ducking in (the squad playtest, 2026-10-08: "could use a hiding
	-- animation"): you're hidden from the first moment, while everyone else
	-- sees you crouch into it (Controllers/PoseController) before you're gone.
	root.Anchored = true
	player:SetAttribute(PA.HideEnter, true)
	task.delay(Config.Hide.DuckSeconds, function()
		local state = hidden[player]
		if state and state.spot == spot and root.Parent then
			root.CFrame = spot.insideCFrame
			setCharacterVisible(character, false)
		end
		player:SetAttribute(PA.HideEnter, nil)
	end)
	player:SetAttribute(PA.Hidden, spot.id)
	player:SetAttribute("HidePeek", spot.peekCFrame)
	player:SetAttribute("HideTuck", spot.tuckCFrame or spot.peekCFrame)
	player:SetAttribute("HideSlit", HideRules.slit(spot.category))
	player:SetAttribute("Breath", 1)
	spot.anchor:SetAttribute("Occupied", #spot.occupants)
	self.Noise:Emit(spot.frontPosition, spot.noise, player, "hide")
	local now = os.clock()
	if self.SquadProfile then
		self.SquadProfile:RecordHide(spot, now)
	end
	self.Entered:Fire(player, spot)
end

function HidingService:Leave(player: Player, silent: boolean?)
	local state = hidden[player]
	if not state then
		return
	end
	local spot = state.spot
	hidden[player] = nil
	local index = table.find(spot.occupants, player)
	if index then
		table.remove(spot.occupants, index)
	end
	spot.anchor:SetAttribute("Occupied", #spot.occupants)
	player:SetAttribute(PA.Hidden, nil)
	player:SetAttribute("HidePeek", nil)
	player:SetAttribute("HideTuck", nil)
	player:SetAttribute("HideSlit", nil)
	player:SetAttribute(PA.Peeking, nil)
	player:SetAttribute(PA.HideEnter, nil)
	player:SetAttribute("HidePhysical", nil)
	player:SetAttribute("Breath", nil)
	if spot.physical then
		-- You were standing there all along: nothing to undo.
		self.Left:Fire(player, spot, silent == true)
		return
	end
	local character = player.Character
	local root = self.PlayerState:Root(player)
	if character then
		setCharacterVisible(character, true)
	end
	if root then
		self.PlayerState:MarkTeleport(player)
		root.CFrame = CFrame.new(spot.frontPosition + Vector3.new(0, 3, 0))
		root.Anchored = false
	end
	if not silent then
		self.Noise:Emit(spot.frontPosition, spot.noise, player, "hide")
	end
	self.Left:Fire(player, spot, silent == true)
end

function HidingService:ForceLeave(player: Player)
	self:Leave(player, true)
end

function HidingService:IsHidden(player: Player): boolean
	return hidden[player] ~= nil
end

function HidingService:SpotOf(player: Player)
	local state = hidden[player]
	return state and state.spot
end

-- Called by the stalker when it inspects a spot. Returns the players found.
-- A walk-in place's doors open on whoever is inside.
function HidingService:Inspect(spot): { Player }
	if spot.physical then
		self:_openDoors(spot)
	end
	local found = table.clone(spot.occupants)
	for _, player in found do
		self:ForceLeave(player)
	end
	return found
end

-- A walk-in place's doors (FurnitureService pieces of its model).
function HidingService:_doors(spot)
	if spot.doors and #spot.doors > 0 then
		return spot.doors
	end
	local list = {}
	local furniture = self.services.FurnitureService
	for _, piece in furniture and furniture.pieces or {} do
		if piece.prop.model == spot.model then
			table.insert(list, piece)
		end
	end
	spot.doors = list
	return list
end

function HidingService:_openDoors(spot)
	local furniture = self.services.FurnitureService
	for _, piece in self:_doors(spot) do
		furniture:SetOpen(piece, true, true)
	end
end

-- Whether someone stands inside a walk-in place.
function HidingService:_inside(spot, player: Player): boolean
	local root = self.PlayerState:Root(player)
	if not root or not spot.interior then
		return false
	end
	local p = spot.interior.cframe:PointToObjectSpace(root.Position)
	local size = spot.interior.size / 2
	return math.abs(p.X) <= size.X and math.abs(p.Y) <= size.Y and math.abs(p.Z) <= size.Z
end

-- Anyone in it, hidden or not (Services/PushService won't push a wardrobe
-- with someone standing in it).
function HidingService:Within(spot): boolean
	if #spot.occupants > 0 then
		return true
	end
	if spot.physical then
		for _, player in self.PlayerState:ActivePlayers() do
			if self:_inside(spot, player) then
				return true
			end
		end
	end
	return false
end

-- Whether he'd see a light through a walk-in place's slats: its front in
-- his sight, as he'd see you (Stalker/Perception: range, cone, a clear line).
function HidingService:_glowSeen(spot, stalker): boolean
	local eye, facing = stalker:Gaze()
	if not eye or not facing or not spot.anchor then
		return false
	end
	local S = Config.Stalker
	local glow = spot.anchor.Position + Vector3.new(0, 2, 0) -- (the slats' height)
	local offset = glow - eye
	if offset.Magnitude > S.VisionRangeLit then
		return false
	end
	local flat = Vector3.new(offset.X, 0, offset.Z)
	local look = Vector3.new(facing.X, 0, facing.Z)
	if
		flat.Magnitude > 0.1
		and look.Magnitude > 0.1
		and look.Unit:Dot(flat.Unit) < math.cos(math.rad(S.VisionConeDegrees / 2))
	then
		return false
	end
	return self.services.WitnessService:ClearLine(eye, glow, { spot.model })
end

-- Walk-in places: who stands inside with every door shut and their light
-- off is hidden; who steps out, opens a door or lights up isn't. Your light
-- goes off as you shut yourself in, as it does in any hiding place; turned
-- on again, it shows through the slats.
function HidingService:_physical()
	local stalker = self.services.StalkerService
	local now = os.clock()
	for _, spot in self.physical or {} do
		if spot.model.Parent and spot.interior then
			local shut = true
			for _, piece in self:_doors(spot) do
				shut = shut and piece.state.value < 0.3
			end
			for _, player in self.PlayerState:ActivePlayers() do
				local inside = self:_inside(spot, player)
				local closed = inside and shut
				if closed and shutIn[player] ~= spot then
					shutIn[player] = spot
					self.PlayerState:SetFlashlight(player, false)
				elseif not closed and shutIn[player] == spot then
					shutIn[player] = nil
				end
				-- Getting in with him watching: he knows where you went.
				if inside and not shut and stalker and stalker:CanSeePlayer(player) then
					seenGoingIn[player] = now
				end
				local lit = player:GetAttribute(PA.Flashlight) == true
				-- A light on in there shows through the slats: he notices if
				-- he's looking at it (his sight stops at the door itself).
				if closed and lit and stalker and glowSeen[player] ~= spot and self:_glowSeen(spot, stalker) then
					glowSeen[player] = spot
					stalker:NoticePeek(player, spot)
				elseif not closed and glowSeen[player] == spot then
					glowSeen[player] = nil
				end
				local state = hidden[player]
				if closed and not lit and not state and #spot.occupants < spot.capacity then
					table.insert(spot.occupants, player)
					spot.heat += 1
					hidden[player] = {
						spot = spot,
						breath = Config.Player.BreathMax,
						holding = false,
						gaspUntil = 0,
						lastBreathNoise = 0,
					}
					player:SetAttribute("HidePhysical", true)
					player:SetAttribute(PA.Hidden, spot.id)
					player:SetAttribute("Breath", 1)
					spot.anchor:SetAttribute("Occupied", #spot.occupants)
					if self.SquadProfile then
						self.SquadProfile:RecordHide(spot, now)
					end
					self.Entered:Fire(player, spot)
					if stalker and now - (seenGoingIn[player] or -math.huge) < Config.Hide.SeenGoingIn then
						stalker:NoticePeek(player, spot)
					end
				elseif state and state.spot == spot and (not closed or lit) then
					self:Leave(player, true)
					if closed then
						notify(player, "Your light shows through the slats.", "warning")
					end
				end
			end
		end
	end
end

function HidingService:_tick(dt: number)
	self:_physical()
	local stalker = self.services.StalkerService
	local stalkerPos = stalker and stalker:GetPosition()
	-- He's always somewhere in the house now; he's only a danger to someone
	-- hiding once he's closing in (tier 2+) or hunting.
	if stalker and stalker.tier < 2 and not stalker:IsHunting() then
		stalkerPos = nil
	end
	local now = os.clock()
	for player, state in hidden do
		local spot = state.spot
		-- Near means on your floor (or in the hall with you), not underfoot.
		local near = stalkerPos ~= nil and self.World:Together(stalkerPos, spot.frontPosition, 16)
		if state.holding then
			state.breath = math.max(0, state.breath - Config.Player.BreathDrainPerSecond * dt)
			if state.breath <= 0 then
				-- Gasp: loud, and you can't hold again for a moment.
				state.holding = false
				state.gaspUntil = now + 3
				self.Noise:Emit(spot.frontPosition, 26, player, "gasp")
				notify(player, "You gasp for air!", "danger")
			end
		else
			state.breath = math.min(Config.Player.BreathMax, state.breath + Config.Player.BreathRegenPerSecond * dt)
			if near and now - state.lastBreathNoise > 2 then
				state.lastBreathNoise = now
				self.Noise:Emit(spot.frontPosition, 9, player, "breath")
			end
		end
		player:SetAttribute("Breath", state.breath / Config.Player.BreathMax)
		player:SetAttribute("HideDanger", near)
		if state.peekSince and not state.noticed and stalker then
			self:_peekSeen(player, state, stalker, now)
		end
	end
end

-- A peek he can see for long enough gives the place away (Logic/HideRules):
-- his head snaps to it, and he knows where you are, as if he'd heard you.
function HidingService:_peekSeen(player: Player, state, stalker, now: number)
	local eye, facing = stalker:Gaze()
	if not eye then
		return
	end
	local spot = state.spot
	local gap = spot.peekCFrame.Position
	local offset = gap - eye
	local flat = Vector3.new(offset.X, 0, offset.Z)
	local look = Vector3.new(facing.X, 0, facing.Z)
	local angle = (flat.Magnitude > 0.1 and look.Magnitude > 0.1)
			and math.deg(math.acos(math.clamp(flat.Unit:Dot(look.Unit), -1, 1)))
		or 0
	local ignore = { spot.model }
	local ok = HideRules.noticed({
		peekFor = now - state.peekSince,
		tier = stalker.tier,
		hunting = stalker:IsHunting(),
		distance = offset.Magnitude,
		angle = angle,
		lineOfSight = self.services.WitnessService:ClearLine(eye, gap, ignore),
	}, Config.Hide)
	if ok then
		state.noticed = true
		stalker:NoticePeek(player, spot)
	end
end

return HidingService
