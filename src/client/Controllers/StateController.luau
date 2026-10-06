-- Client-side view of the run: RunState attributes, the local player's
-- attributes, and snapshots the server pushes (layout, case board, lobby,
-- profile). Also owns the player's settings.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared.Constants)
local Net = require(Shared.Net)
local Signal = require(Shared.Lib.Signal)
local Storeys = require(Shared.Logic.Storeys)

local RS = Constants.RunState
local PA = Constants.PlayerAttributes

local StateController = {
	PhaseChanged = Signal.new(),
	DriftChanged = Signal.new(),
	PlayerStateChanged = Signal.new(),
	LayoutChanged = Signal.new(),
	LobbyChanged = Signal.new(),
	ProfileChanged = Signal.new(),
	SettingsChanged = Signal.new(),
	AttributeChanged = Signal.new(), -- (name, value) for the local player
	RunAttributeChanged = Signal.new(), -- (name, value) for RunState

	layout = nil,
	lobby = nil,
	profile = nil,
	settings = {
		reduceFlicker = false,
		reduceGrain = false,
		subtitles = true,
		colorblind = false,
		lowEnd = false,
		centerDot = false, -- opt-in aiming aid; the game has no crosshair
		fov = 70,
		cameraMotion = 1, -- head bob, sway, FOV kick and landing dip; 0 turns them off
		masterVolume = 1,
		sfxVolume = 1,
		ambientVolume = 0.8,
		seenIntro = false,
	},
}

local player = Players.LocalPlayer

function StateController:Init()
	self.runState = ReplicatedStorage:WaitForChild("RunState")
end

function StateController:Start()
	local runState = self.runState
	runState.AttributeChanged:Connect(function(name)
		local value = runState:GetAttribute(name)
		self.RunAttributeChanged:Fire(name, value)
		if name == RS.Phase then
			self.PhaseChanged:Fire(value)
		elseif name == RS.Drift then
			self.DriftChanged:Fire(value or 0)
		end
	end)
	player.AttributeChanged:Connect(function(name)
		local value = player:GetAttribute(name)
		self.AttributeChanged:Fire(name, value)
		if name == PA.State then
			self.PlayerStateChanged:Fire(value)
		end
	end)
	Net.get("Layout").OnClientEvent:Connect(function(layout)
		self.layout = layout
		self.LayoutChanged:Fire(layout)
	end)
	Net.get("LobbyState").OnClientEvent:Connect(function(state)
		self.lobby = state
		self.LobbyChanged:Fire(state)
	end)
	Net.get("ProfileData").OnClientEvent:Connect(function(profile)
		self.profile = profile
		for key, value in profile.settings or {} do
			if self.settings[key] ~= nil and type(value) == type(self.settings[key]) then
				self.settings[key] = value
			end
		end
		self.ProfileChanged:Fire(profile)
		self.SettingsChanged:Fire(self.settings)
	end)
	self.PhaseChanged:Fire(self:Phase())
end

function StateController:Phase(): string
	return self.runState:GetAttribute(RS.Phase) or Constants.Phases.Lobby
end

function StateController:InRun(): boolean
	local phase = self:Phase()
	return phase ~= Constants.Phases.Lobby
		and phase ~= Constants.Phases.Generating
		and phase ~= Constants.Phases.Debrief
end

function StateController:Drift(): number
	return self.runState:GetAttribute(RS.Drift) or 0
end

-- How bad the house is (Logic/Dread: Drift or the act's floor): what every
-- escalation on this client reads.
function StateController:Dread(): number
	return self.runState:GetAttribute(RS.Dread) or self:Drift()
end

function StateController:Run(name: string): any
	return self.runState:GetAttribute(name)
end

function StateController:PlayerState(): string
	return player:GetAttribute(PA.State) or Constants.PlayerStates.Lobby
end

-- In the house and able to act (not downed, Lost or extracted).
function StateController:IsActive(): boolean
	return self:PlayerState() == Constants.PlayerStates.Active
end

function StateController:IsHidden(): boolean
	return player:GetAttribute(PA.Hidden) ~= nil
end

function StateController:Get(name: string): any
	return player:GetAttribute(name)
end

function StateController:SetSetting(key: string, value: any)
	self.settings[key] = value
	self.SettingsChanged:Fire(self.settings)
	Net.get("SaveSettings"):FireServer(table.clone(self.settings))
end

-- Which storey a height (a world Y) is on, within the storeys the house has
-- (Logic/Storeys: -1 the cellar to 2 the attic). The old house is all ground
-- floor.
function StateController:StoreyAt(y: number): number
	local layout = self.layout
	if not layout or layout.mode ~= "Mansion" then
		return 0
	end
	local range = layout.storeys or { 0, 1 }
	return Storeys.of(y - layout.origin[2], layout.pitch or 11, range[1], range[2])
end

-- World position -> room, using the layout snapshot. Rooms are rectangles
-- (x, z their north-west corner from the origin) on a storey; in the mansion,
-- a storey starts near its floor's level, and the hall and the stairwells
-- stand on several.
function StateController:RoomAt(position: Vector3)
	local layout = self.layout
	if not layout then
		return nil
	end
	local x = position.X - layout.origin[1]
	local z = position.Z - layout.origin[3]
	local floor = self:StoreyAt(position.Y)
	for _, room in layout.rooms do
		if room.x and x >= room.x and x < room.x + room.w and z >= room.z and z < room.z + room.d then
			local low = room.floor or 0
			local top = room.tall and (room.top or low + 1) or low
			if floor >= low and floor <= top then
				return room
			end
		end
	end
	return nil
end

return StateController
