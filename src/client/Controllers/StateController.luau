-- Client-side view of the run: RunState attributes, the local player's
-- attributes, and snapshots the server pushes (layout, case board, lobby,
-- profile). Also owns the player's settings.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Constants = require(Shared.Constants)
local GraphicsPreset = require(Shared.Logic.GraphicsPreset)
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
		subtitles = true,
		colorblind = false,
		-- The visual rework (2026-10-12): presets in place of "Low-end graphics",
		-- three steps of grain in place of "Reduce grain" (Logic/GraphicsPreset).
		graphics = 0, -- 0 Auto, 1 Cinematic, 2 Balanced, 3 Performance
		grain = 2, -- 0 off, 1 fine, 2 film
		lensFlares = true, -- glare round lamps and lens dirt
		centerDot = false, -- opt-in aiming aid; the game has no crosshair
		fov = 70,
		cameraMotion = 1, -- head bob, sway, FOV kick and landing dip; 0 turns them off
		masterVolume = 1,
		sfxVolume = 1,
		ambientVolume = 0.8,
		musicVolume = 0.7,
		tips = true, -- teaching in the house (UI/Tips)
		crouchToggle = false, -- Ctrl toggles a crouch instead of holding it
		hideBody = false, -- your legs and feet stay hidden in first person (Controllers/BodyController)
		seenIntro = false,
	},
}

local player = Players.LocalPlayer

function StateController:Init()
	self.runState = ReplicatedStorage:WaitForChild("RunState")
	self:_watchQuality()
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
		local saved = profile.settings or {}
		for key, value in saved do
			if self.settings[key] ~= nil and type(value) == type(self.settings[key]) then
				self.settings[key] = value
			end
		end
		for key, value in GraphicsPreset.migrate(saved) do
			self.settings[key] = value
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

-- Hidden away by E (under a bed, behind a curtain): your body gone, your
-- view at the gap, E to get out. Hidden in a walk-in place (a closet, a
-- wardrobe, a locker) you're only standing there, shut in: your hands and
-- your eyes are your own (Services/HidingService's physical spots).
function StateController:IsTucked(): boolean
	return self:IsHidden() and player:GetAttribute("HidePhysical") ~= true
end

function StateController:Get(name: string): any
	return player:GetAttribute(name)
end

function StateController:SetSetting(key: string, value: any)
	self.settings[key] = value
	self.SettingsChanged:Fire(self.settings)
	Net.get("SaveSettings"):FireServer(table.clone(self.settings))
end

-- This device as Auto sees it: Roblox's own graphics quality (nil while it is
-- on Automatic), and whether it is a phone or a console.
local function device(): GraphicsPreset.Device
	local quality = nil
	local ok, level = pcall(function()
		return UserSettings():GetService("UserGameSettings").SavedQualityLevel
	end)
	if ok and level and level ~= Enum.SavedQualitySetting.Automatic then
		quality = level.Value
	end
	return {
		quality = quality,
		touchOnly = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled,
		console = UserInputService.GamepadEnabled and not UserInputService.KeyboardEnabled,
	}
end

-- The graphics preset in force: its name and its switches (Config.Graphics).
-- Worked out again when a setting changes or Roblox's own graphics quality
-- moves (which also fires SettingsChanged, so every controller re-applies).
local graphicsName = nil
function StateController:Graphics(): (string, { [string]: boolean })
	if not graphicsName then
		graphicsName = GraphicsPreset.resolve(self.settings.graphics, device(), Config.Graphics)
	end
	return graphicsName, Config.Graphics.Presets[graphicsName]
end

function StateController:_watchQuality()
	self.SettingsChanged:Connect(function()
		-- (Connected first, so the preset is fresh before anyone reads it.)
		graphicsName = nil
	end)
	pcall(function()
		local userSettings = UserSettings():GetService("UserGameSettings")
		userSettings:GetPropertyChangedSignal("SavedQualityLevel"):Connect(function()
			self.SettingsChanged:Fire(self.settings)
		end)
	end)
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
