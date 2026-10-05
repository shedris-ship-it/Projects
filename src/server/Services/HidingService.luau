-- Hiding spots (doc section 5, "Hide mechanics"): lockers, wardrobes, beds,
-- curtains and tables. Capacity 1-2, a peek view, a noise value, spot heat
-- that the stalker learns from, and a hold-breath meter. You can't slip into
-- a spot while the stalker has direct line of sight to you.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Constants = require(Shared.Constants)
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
	end)
	Net.onServer("LeaveHiding", { interval = 0.3, types = {} }, function(player)
		self:Leave(player)
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
	root.Anchored = true
	root.CFrame = spot.insideCFrame
	setCharacterVisible(character, false)
	player:SetAttribute(PA.Hidden, spot.id)
	player:SetAttribute("HidePeek", spot.peekCFrame)
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
	player:SetAttribute("Breath", nil)
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
function HidingService:Inspect(spot): { Player }
	local found = table.clone(spot.occupants)
	for _, player in found do
		self:ForceLeave(player)
	end
	return found
end

function HidingService:_tick(dt: number)
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
	end
end

return HidingService
