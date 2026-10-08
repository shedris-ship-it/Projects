-- Hiding spots (doc section 5, "Hide mechanics"): lockers, wardrobes, beds,
-- curtains and tables. Capacity 1-2, a peek view, a noise value, spot heat
-- that the stalker learns from, and a hold-breath meter. You can't slip into
-- a spot while the stalker has direct line of sight to you.
--
-- Walk-in closets (gameplay rework 4.8) are physical spots: no prompt, no
-- teleport, no invisibility. You're hidden while you stand inside with both
-- its sliding doors shut, and not the moment you step out or a door opens.
-- His inspection slides the doors open.

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
	prompt.Parent = spot.anchor
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
-- A closet's doors slide open on whoever is inside.
function HidingService:Inspect(spot): { Player }
	if spot.physical then
		self:_slideOpen(spot)
	end
	local found = table.clone(spot.occupants)
	for _, player in found do
		self:ForceLeave(player)
	end
	return found
end

-- A closet's doors (FurnitureService pieces of its model).
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

function HidingService:_slideOpen(spot)
	local furniture = self.services.FurnitureService
	for _, piece in self:_doors(spot) do
		furniture:SetOpen(piece, true, true)
	end
end

-- Walk-in closets: who stands inside with both doors shut is hidden; who
-- steps out, or opens a door, isn't.
function HidingService:_physical()
	for _, spot in self.physical or {} do
		if spot.model.Parent and spot.interior then
			local shut = true
			for _, piece in self:_doors(spot) do
				shut = shut and piece.state.value < 0.3
			end
			local box, size = spot.interior.cframe, spot.interior.size / 2
			for _, player in self.PlayerState:ActivePlayers() do
				local root = self.PlayerState:Root(player)
				local inside = false
				if root then
					local p = box:PointToObjectSpace(root.Position)
					inside = math.abs(p.X) <= size.X and math.abs(p.Y) <= size.Y and math.abs(p.Z) <= size.Z
				end
				local state = hidden[player]
				if inside and shut and not state and #spot.occupants < spot.capacity then
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
						self.SquadProfile:RecordHide(spot, os.clock())
					end
					self.Entered:Fire(player, spot)
				elseif state and state.spot == spot and (not inside or not shut) then
					self:Leave(player, true)
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
