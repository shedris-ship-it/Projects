-- The devices' own light, as each client sees it (the owner, 2026-10-13:
-- "make sure the light sources from this new batch like from the computer
-- and the fuse box and the radio ... look really good"). Decoration only, as
-- the TV's static (Controllers/TVController): what counts as lit is still
-- WorldService's light rule. A device far from you sleeps; "Reduce
-- flicker" holds their light steady.
--
--   * A radio (World/PropFactory's Radio, tagged): while its fixture plays
--     (Services/InteractService marks the model Running) its dial's glass
--     lights a warm amber, a light out from it falls over its table and the
--     wall, breathing with the static, and the needle wanders as if someone
--     were tuning; off, the dial is a dull amber you still see.
--   * The home computer's screen (server/Puzzles/Terminal, tagged): its
--     green light and the tube's glow waver a little, as a CRT's does.
--
-- The fuse box's lamps, a lever's, the baby monitor's and the robot's eyes
-- are set by their stations (they follow the game's state).

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Constants = require(Shared.Constants)

local R = Config.Devices.Radio
local S = Config.Devices.Screen

local DeviceController = {}

function DeviceController:Init(controllers)
	self.state = controllers.StateController
end

local radios = {} -- model -> its dial, needle and light
local screens = {} -- screen part -> its lights

local function rgb(t): Color3
	return Color3.fromRGB(t[1], t[2], t[3])
end

local function addRadio(model: Instance)
	if not model:IsA("Model") or radios[model] then
		return
	end
	local dial = model:WaitForChild("Dial", 10)
	local needle = model:FindFirstChild("Needle")
	if not dial or not dial:IsA("BasePart") or not model.Parent then
		return
	end
	-- Its light, a little out from the glass (+Z, the radio's front).
	local at = Instance.new("Attachment")
	at.Name = "DialLightAt"
	at.Position = Vector3.new(0, 0, R.Out)
	at.Parent = dial
	local light = Instance.new("PointLight")
	light.Name = "DialLight"
	light.Color = rgb(R.Light)
	light.Range = R.Range
	light.Brightness = 0
	light.Shadows = false
	light.Enabled = false
	light.Parent = at
	radios[model] = {
		dial = dial,
		needle = needle,
		home = needle and needle.CFrame,
		light = light,
		on = nil,
		phase = math.random() * math.pi * 2, -- (cosmetic: client timing only)
		level = 1,
		nextBreath = 0,
	}
	model.Destroying:Connect(function()
		radios[model] = nil
	end)
end

local function addScreen(screen: Instance)
	if not screen:IsA("BasePart") or screens[screen] then
		return
	end
	local point = screen:FindFirstChild("ScreenLight", true)
	local surface = screen:FindFirstChildWhichIsA("SurfaceLight")
	screens[screen] = {
		point = point,
		surface = surface,
		base = point and point.Brightness or S.Brightness,
		surfaceBase = surface and surface.Brightness or 0,
		level = 1,
		nextBreath = 0,
	}
	screen.Destroying:Connect(function()
		screens[screen] = nil
	end)
end

-- A radio's dial and light, on or off.
local function switchRadio(radio, on: boolean)
	if radio.on == on then
		return
	end
	radio.on = on
	radio.dial.Color = rgb(on and R.DialOn or R.DialOff)
	radio.dial.Transparency = on and R.Clear[1] or R.Clear[2]
	radio.light.Enabled = on
	if not on and radio.needle and radio.home then
		radio.needle.CFrame = radio.home
	end
end

function DeviceController:Start()
	for _, model in CollectionService:GetTagged(Constants.Tags.Radio) do
		task.spawn(addRadio, model)
	end
	CollectionService:GetInstanceAddedSignal(Constants.Tags.Radio):Connect(function(model)
		task.spawn(addRadio, model)
	end)
	for _, screen in CollectionService:GetTagged(Constants.Tags.Screen) do
		addScreen(screen)
	end
	CollectionService:GetInstanceAddedSignal(Constants.Tags.Screen):Connect(addScreen)

	RunService.RenderStepped:Connect(function()
		if next(radios) == nil and next(screens) == nil then
			return
		end
		local camera = Workspace.CurrentCamera
		local from = camera and camera.CFrame.Position or Vector3.zero
		local steady = self.state.settings and self.state.settings.reduceFlicker == true
		local now = os.clock()
		for model, radio in radios do
			local near = radio.dial.Parent ~= nil and (radio.dial.Position - from).Magnitude < R.Near
			local playing = model:GetAttribute("Running") == true
			switchRadio(radio, playing and near)
			if not radio.on then
				continue
			end
			-- The static's breath in its light (held with Reduce flicker).
			if now >= radio.nextBreath then
				radio.nextBreath = now + 0.06 + math.random() * 0.1
				radio.level = steady and 1 or (1 - R.Flicker + math.random() * R.Flicker * 2)
			end
			radio.light.Brightness = R.Brightness * radio.level
			-- The needle drifting across the dial and back.
			if radio.needle and radio.home then
				local sway = math.sin(now * math.pi * 2 / R.SwaySeconds + radio.phase) * R.Sway
				radio.needle.CFrame = radio.home * CFrame.new(sway, 0, 0)
			end
		end
		for screen, glow in screens do
			if screen.Parent == nil or (screen.Position - from).Magnitude > S.Near then
				continue
			end
			if now >= glow.nextBreath then
				glow.nextBreath = now + 0.05 + math.random() * 0.12
				glow.level = steady and 1 or (1 - S.Breath + math.random() * S.Breath * 2)
			end
			if glow.point then
				glow.point.Brightness = glow.base * glow.level
			end
			if glow.surface then
				glow.surface.Brightness = glow.surfaceBase * glow.level
			end
		end
	end)
end

return DeviceController
