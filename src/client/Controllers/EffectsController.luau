-- Post-processing and light behaviour driven by Drift (doc section 8:
-- "tie saturation, contrast, grain, light-flicker rate and audio filtering to
-- Drift so the world visibly decays"). Respects the reduce-flicker and
-- reduce-grain settings; nothing here tilts or shakes the camera.

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Assets = require(Shared.Assets)
local Constants = require(Shared.Constants)
local Net = require(Shared.Net)

local Ui = require(script.Parent.Parent.Lib.Ui)

local player = Players.LocalPlayer

local EffectsController = {}

local lights = {} -- light -> { base brightness }
local flickering = {} -- light -> until
local hunt = { state = nil, started = 0, duration = 0 }

function EffectsController:Init(controllers)
	self.controllers = controllers
	self.state = controllers.StateController
end

local function lerp(a, b, t)
	return a + (b - a) * t
end

function EffectsController:_createEffects()
	local camera = Workspace.CurrentCamera
	self.color = Instance.new("ColorCorrectionEffect")
	self.color.Name = "ConsensusColor"
	self.color.Parent = camera
	self.bloom = Instance.new("BloomEffect")
	self.bloom.Name = "ConsensusBloom"
	self.bloom.Intensity = 0.35
	self.bloom.Size = 22
	self.bloom.Threshold = 1.6
	self.bloom.Parent = camera
	self.dof = Instance.new("DepthOfFieldEffect")
	self.dof.Name = "ConsensusDof"
	self.dof.FarIntensity = 0.12
	self.dof.FocusDistance = 30
	self.dof.InFocusRadius = 40
	self.dof.NearIntensity = 0
	self.dof.Parent = camera
	self.atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")

	-- Vignette from four soft edges, and an optional grain overlay.
	local gui = Ui.screen("ConsensusEffects", -5, player:WaitForChild("PlayerGui"))
	self.vignette = {}
	for _, edge in
		{
			{ UDim2.new(0, 0, 0, 0), UDim2.new(1, 0, 0.35, 0), 90 },
			{ UDim2.new(0, 0, 0.65, 0), UDim2.new(1, 0, 0.35, 0), -90 },
			{ UDim2.new(0, 0, 0, 0), UDim2.new(0.3, 0, 1, 0), 0 },
			{ UDim2.new(0.7, 0, 0, 0), UDim2.new(0.3, 0, 1, 0), 180 },
		}
	do
		local frame = Ui.new("Frame", {
			Position = edge[1],
			Size = edge[2],
			BackgroundColor3 = Color3.new(0, 0, 0),
			BackgroundTransparency = 0,
			Parent = gui,
		})
		Ui.new("UIGradient", {
			Rotation = edge[3],
			Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) }),
			Parent = frame,
		})
		table.insert(self.vignette, frame)
	end
	self.tint = Ui.new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(120, 0, 0),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	self.flash = Ui.new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 1,
		ZIndex = 5,
		Parent = gui,
	})
	if Assets.GrainTexture ~= "" then
		self.grain = Ui.new("ImageLabel", {
			Size = UDim2.fromScale(2, 2),
			BackgroundTransparency = 1,
			Image = Assets.GrainTexture,
			ScaleType = Enum.ScaleType.Tile,
			TileSize = UDim2.fromOffset(256, 256),
			ImageTransparency = 1,
			Parent = gui,
		})
	end
end

local function trackLight(part: Instance)
	local light = part:FindFirstChild("KeyLight") or part:FindFirstChildWhichIsA("Light")
	if light then
		lights[light] = { base = light.Brightness, part = part }
	end
end

function EffectsController:Start()
	self:_createEffects()
	for _, part in CollectionService:GetTagged(Constants.Tags.RoomLight) do
		trackLight(part)
	end
	CollectionService:GetInstanceAddedSignal(Constants.Tags.RoomLight):Connect(function(part)
		task.defer(trackLight, part)
	end)
	CollectionService:GetInstanceRemovedSignal(Constants.Tags.RoomLight):Connect(function(part)
		for light, info in lights do
			if info.part == part then
				lights[light] = nil
				flickering[light] = nil
			end
		end
	end)
	Net.get("HuntState").OnClientEvent:Connect(function(payload)
		hunt = { state = payload.state, started = os.clock(), duration = payload.duration or 0 }
		if payload.state == "telegraph" then
			-- Every light near you stutters as it arrives.
			self:FlickerNear(60, payload.duration or 4)
		end
	end)
	Net.get("PhotoResult").OnClientEvent:Connect(function()
		self.flash.BackgroundTransparency = 0.1
		Ui.tween(self.flash, 0.6, { BackgroundTransparency = 1 })
	end)
	self.state.SettingsChanged:Connect(function(settings)
		self:_applyQuality(settings)
	end)
	self:_applyQuality(self.state.settings)

	local nextRandomFlicker = 0
	RunService.RenderStepped:Connect(function(dt)
		self:_update(dt)
		local drift = self.state:InRun() and self.state:Drift() or 0
		if drift >= 40 and os.clock() >= nextRandomFlicker then
			nextRandomFlicker = os.clock() + math.random(8, 20) * (1.4 - drift / 100)
			self:FlickerNear(35, 0.8 + drift / 100)
		end
	end)
end

function EffectsController:_applyQuality(settings)
	self.dof.Enabled = not settings.lowEnd
	self.bloom.Enabled = not settings.lowEnd
	local camera = Workspace.CurrentCamera
	camera.FieldOfView = settings.fov or 70
	-- Low-end mode: drop shadows from small clutter (books, legs, decor).
	local level = Workspace:FindFirstChild("ConsensusLevel")
	if level then
		for _, d in level:GetDescendants() do
			if d:IsA("BasePart") and d.Size.Magnitude < 3 then
				d.CastShadow = not settings.lowEnd
			end
		end
	end
	for light in lights do
		if light:IsA("PointLight") or light:IsA("SpotLight") or light:IsA("SurfaceLight") then
			light.Shadows = not settings.lowEnd
		end
	end
end

function EffectsController:FlickerRoom(roomId: number?, duration: number)
	for light, info in lights do
		if info.part:GetAttribute(Constants.Attributes.RoomId) == roomId then
			flickering[light] = os.clock() + duration
		end
	end
end

function EffectsController:FlickerNear(radius: number, duration: number)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	for light, info in lights do
		if info.part.Parent and (info.part.Position - root.Position).Magnitude < radius then
			flickering[light] = os.clock() + duration
		end
	end
end

function EffectsController:_update(dt: number)
	local settings = self.state.settings
	local inRun = self.state:InRun()
	local drift = inRun and self.state:Drift() or 0
	local t = drift / 100
	local playerState = self.state:PlayerState()
	local downed = playerState == Constants.PlayerStates.Downed
	local echo = playerState == Constants.PlayerStates.Lost

	-- Colour: the house loses colour and gains contrast as it drifts.
	local saturation = inRun and lerp(-0.05, -0.6, t) or 0.05
	local contrast = inRun and lerp(0.05, 0.28, t) or 0.05
	local tint = inRun and Color3.fromRGB(255, 250, 240):Lerp(Color3.fromRGB(205, 225, 215), t)
		or Color3.fromRGB(255, 240, 225)
	if downed then
		saturation = -0.9
		tint = Color3.fromRGB(255, 190, 190)
	elseif echo then
		saturation = -1
		tint = Color3.fromRGB(190, 210, 255)
	end
	local huntRed = 0
	if hunt.state == "telegraph" then
		huntRed = 0.25 + 0.15 * math.sin(os.clock() * 9)
	elseif hunt.state == "hunt" then
		huntRed = 0.12
	end
	local color = self.color
	color.Saturation += (saturation - color.Saturation) * math.clamp(dt * 2, 0, 1)
	color.Contrast += (contrast - color.Contrast) * math.clamp(dt * 2, 0, 1)
	color.TintColor = color.TintColor:Lerp(tint, math.clamp(dt * 2, 0, 1))
	color.Brightness = inRun and lerp(0.02, -0.04, t) or 0.02
	self.tint.BackgroundTransparency = 1 - math.clamp(huntRed, 0, 0.35)

	for _, frame in self.vignette do
		frame.BackgroundTransparency = inRun and lerp(0.35, 0.05, t) or 0.6
	end
	if self.atmosphere then
		self.atmosphere.Density = inRun and lerp(0.32, 0.46, t) or 0.25
	end
	if self.grain then
		self.grain.ImageTransparency = settings.reduceGrain and 1 or (inRun and lerp(0.92, 0.75, t) or 1)
		self.grain.Position = UDim2.fromOffset(-math.random(0, 256), -math.random(0, 256))
	end

	-- Light flicker. Reduced-flicker mode dims smoothly instead of strobing.
	local now = os.clock()
	for light, info in lights do
		if light.Parent then
			local untilTime = flickering[light]
			if untilTime and now < untilTime then
				if settings.reduceFlicker then
					light.Brightness = info.base * 0.35
				else
					light.Brightness = math.random() < 0.45 and info.base * math.random() * 0.3 or info.base
				end
			elseif untilTime then
				flickering[light] = nil
				light.Brightness = info.base
			end
		end
	end
end

return EffectsController
