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
local Config = require(Shared.Config)
local Constants = require(Shared.Constants)
local Net = require(Shared.Net)

local Ui = require(script.Parent.Parent.Lib.Ui)

local player = Players.LocalPlayer

local EffectsController = {}

local FX = Config.PostFX

local lights = {} -- light -> { base brightness }
local flickering = {} -- light -> until
local dust = {} -- ParticleEmitter -> air-current phase
local photos = {} -- photo card -> its snapshot (Assets.Photos index)
local unshadowed = setmetatable({}, { __mode = "k" }) -- parts low-end mode stopped casting shadows
local photoState = "normal"
local hunt = { state = nil, started = 0, duration = 0 }
local huntMix = 0 -- 0 normal lamps, 1 hunt red
local HUNT_RED = Color3.fromRGB(table.unpack(Config.Lighting.HuntRed))

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
	-- Bloom and a gentle depth of field take the clinical edge off Roblox's
	-- rendering: practical lights halo, and the far room goes slightly soft.
	self.bloom = Instance.new("BloomEffect")
	self.bloom.Name = "ConsensusBloom"
	self.bloom.Intensity = FX.BloomIntensity
	self.bloom.Size = FX.BloomSize
	self.bloom.Threshold = FX.BloomThreshold
	self.bloom.Parent = camera
	self.dof = Instance.new("DepthOfFieldEffect")
	self.dof.Name = "ConsensusDof"
	self.dof.FarIntensity = FX.FarBlur
	self.dof.FocusDistance = FX.FocusDistance
	self.dof.InFocusRadius = FX.InFocusRadius
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
			ImageColor3 = Color3.fromRGB(FX.GrainShade, FX.GrainShade, FX.GrainShade),
			ScaleType = Enum.ScaleType.Tile,
			TileSize = UDim2.fromOffset(FX.GrainTile, FX.GrainTile),
			ImageTransparency = 1,
			Parent = gui,
		})
	end
end

local lowEnd = false

-- Dust drifting in the light (docs/ART.md): nested layers of motes around
-- each room's key light, dense and bright at the lamp and thinning out
-- towards the edge, so the dust fades with the light rather than ending at a
-- hard edge. The motes are soft blobs drawn additively and lit by the scene,
-- so they only show where light falls, like dust in a lamp beam.
local function dustEmitter(glow: number, rate: number): ParticleEmitter
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = Assets.DustTexture
	emitter.Shape = Enum.ParticleEmitterShape.Box
	emitter.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	emitter.Rate = rate
	emitter.Lifetime = NumberRange.new(FX.DustLifetime[1], FX.DustLifetime[2])
	emitter.Speed = NumberRange.new(0.02, 0.1)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Drag = 0.4
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, FX.DustSize, FX.DustSizeVariance),
		NumberSequenceKeypoint.new(1, FX.DustSize, FX.DustSizeVariance),
	})
	-- Fade in and out, glinting brighter and dimmer as each mote turns.
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.15, 1 - glow * 0.7, glow * 0.45),
		NumberSequenceKeypoint.new(0.5, 1 - glow, glow * 0.5),
		NumberSequenceKeypoint.new(0.85, 1 - glow * 0.7, glow * 0.45),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Color = ColorSequence.new(Color3.fromRGB(255, 244, 228))
	emitter.LightInfluence = 1
	emitter.LightEmission = 1
	emitter.Enabled = not lowEnd
	return emitter
end

local function addDust(part: Instance)
	local light = part:FindFirstChild("KeyLight")
	if not light then
		return
	end
	-- The room model sits directly under the level folder.
	local room = part.Parent
	while room and room.Parent and room.Parent.Name ~= "ConsensusLevel" do
		room = room.Parent
	end
	if not room or not room.Parent then
		return
	end
	-- The floor can replicate a moment after the light does.
	local floor = room:WaitForChild("Floor", 5)
	if not floor or room:FindFirstChild("Dust") then
		return
	end
	-- Dust gathers around a lamp; a window or TV throws its light into the
	-- room, so its dust gathers a little in front of it.
	local source = part :: BasePart
	local focus = source.Position
	if light:IsA("SurfaceLight") then
		local facing = light.Face == Enum.NormalId.Back and -source.CFrame.LookVector or source.CFrame.LookVector
		local flat = Vector3.new(facing.X, 0, facing.Z)
		if flat.Magnitude > 0.1 then
			focus += flat.Unit * FX.DustSurfaceReach
		end
	end
	-- Every layer stays inside the room, so no dust shows through a wall.
	local floorTop = floor.Position.Y + floor.Size.Y / 2
	local roomMin =
		Vector3.new(floor.Position.X - floor.Size.X / 2 + 1, floorTop + 0.3, floor.Position.Z - floor.Size.Z / 2 + 1)
	local roomMax = Vector3.new(
		floor.Position.X + floor.Size.X / 2 - 1,
		floorTop + FX.DustHeight,
		floor.Position.Z + floor.Size.Z / 2 - 1
	)
	local folder = Instance.new("Folder")
	folder.Name = "Dust"
	local phase = math.random() * 10 -- one air current per room
	for i, layer in FX.DustLayers do
		local reach = Vector3.new(layer.half, layer.half, layer.half)
		local lo = (focus - reach):Max(roomMin)
		local hi = (focus + reach):Min(roomMax)
		local size = hi - lo
		if size.X > 1 and size.Y > 1 and size.Z > 1 then
			local box = Instance.new("Part")
			box.Name = "DustLayer" .. i
			box.Anchored = true
			box.CanCollide = false
			box.CanQuery = false
			box.CanTouch = false
			box.CastShadow = false
			box.Transparency = 1
			box.Size = size
			box.CFrame = CFrame.new((lo + hi) / 2)
			local lifetime = (FX.DustLifetime[1] + FX.DustLifetime[2]) / 2
			local rate = layer.density / 1000 * size.X * size.Y * size.Z / lifetime
			local emitter = dustEmitter(layer.glow, rate)
			emitter.Parent = box
			box.Parent = folder
			dust[emitter] = phase
		end
	end
	folder.Parent = room
end

local function trackLight(part: Instance)
	local light = part:FindFirstChild("KeyLight") or part:FindFirstChildWhichIsA("Light")
	if not light then
		-- The house replicates in chunks, so the light can arrive a moment after
		-- its tagged part. Track it when it does.
		local connection
		connection = part.ChildAdded:Connect(function(child)
			if child:IsA("Light") then
				connection:Disconnect()
				trackLight(part)
			end
		end)
		return
	end
	-- Remember whether it was built to cast shadows.
	-- Lamps (point lights that light a room) turn hunt red during a hunt
	-- (docs/ART.md, reserved colours); windows, screens and bounce light don't.
	-- A fixture's glowing parts follow its light: they dim when it dims or goes
	-- out, and redden with it.
	local glows = {}
	local fixture = part.Parent
	if fixture and fixture:IsA("Model") then
		for _, d in fixture:GetDescendants() do
			if d:IsA("BasePart") and d:GetAttribute(Constants.Attributes.LampGlow) then
				glows[d] = d.Color
			end
		end
	end
	lights[light] = {
		base = light.Brightness,
		part = part,
		shadows = light.Shadows,
		dim = 1,
		color = light.Color,
		lamp = light:IsA("PointLight") and light.Name == "KeyLight",
		glows = glows,
	}
	task.spawn(addDust, part)
end

-- Family photos age with Drift (docs/ART.md, the run's arc): shared decay,
-- the same for every player at the same Drift (rule 6).
local function showPhoto(card: Instance)
	local set = Assets.Photos[photos[card]]
	local decal = card:FindFirstChild("Picture")
	if set and decal and decal:IsA("Decal") then
		decal.Texture = set[photoState] or set.normal
	end
end

local function trackPhoto(card: Instance)
	local set = card:GetAttribute("PhotoSet")
	if type(set) == "number" then
		photos[card] = set
		showPhoto(card)
	end
end

-- Where The Guest's body is, or nil while it's parked out of the house.
local function guestPosition(): Vector3?
	local level = Workspace:FindFirstChild("ConsensusLevel")
	local guest = level and level:FindFirstChild("Stalker")
	if not guest or not guest:IsA("Model") then
		return nil
	end
	local position = guest:GetPivot().Position
	return position.Y < 200 and position or nil
end

function EffectsController:Start()
	self:_createEffects()
	for _, part in CollectionService:GetTagged(Constants.Tags.RoomLight) do
		trackLight(part)
	end
	CollectionService:GetInstanceAddedSignal(Constants.Tags.RoomLight):Connect(function(part)
		task.defer(trackLight, part)
	end)
	for _, card in CollectionService:GetTagged(Constants.Tags.Photo) do
		trackPhoto(card)
	end
	CollectionService:GetInstanceAddedSignal(Constants.Tags.Photo):Connect(function(card)
		task.defer(trackPhoto, card)
	end)
	CollectionService:GetInstanceRemovedSignal(Constants.Tags.Photo):Connect(function(card)
		photos[card] = nil
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
	-- Low-end mode: drop shadows from small clutter (books, legs, decor), and
	-- give back only those shadows afterwards. Parts built without a shadow
	-- (glass, lamp trim, clock hands) stay that way.
	local level = Workspace:FindFirstChild("ConsensusLevel")
	if settings.lowEnd and level then
		for _, d in level:GetDescendants() do
			if d:IsA("BasePart") and d.CastShadow and d.Size.Magnitude < 3 then
				d.CastShadow = false
				unshadowed[d] = true
			end
		end
	elseif not settings.lowEnd then
		for part in unshadowed do
			part.CastShadow = true
		end
		table.clear(unshadowed)
	end
	for light, info in lights do
		if light:IsA("PointLight") or light:IsA("SpotLight") or light:IsA("SurfaceLight") then
			light.Shadows = info.shadows and not settings.lowEnd
		end
	end
	lowEnd = settings.lowEnd == true
	for emitter in dust do
		if emitter.Parent then
			emitter.Enabled = not lowEnd
		else
			dust[emitter] = nil
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

	-- Colour: the house starts on a sickly yellow-green grade (docs/ART.md,
	-- the P.T. reference), then loses colour and gains contrast as it drifts.
	-- The hub keeps a warm, neutral grade.
	local saturation = inRun and lerp(-0.22, -0.65, t) or 0.05
	local contrast = inRun and lerp(0.15, 0.3, t) or 0.05
	local tint = inRun and Color3.fromRGB(236, 236, 200):Lerp(Color3.fromRGB(205, 225, 215), t)
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

	self.bloom.Threshold = inRun and FX.BloomThreshold or FX.BloomThresholdHub

	for _, frame in self.vignette do
		frame.BackgroundTransparency = inRun and lerp(0.35, 0.05, t) or 0.6
	end
	if self.atmosphere then
		self.atmosphere.Density = inRun and lerp(0.32, 0.46, t) or 0.25
	end
	if self.grain then
		self.grain.ImageTransparency = settings.reduceGrain and 1
			or (inRun and lerp(FX.GrainCalm, FX.GrainCollapse, t) or 1)
		self.grain.Position = UDim2.fromOffset(-math.random(0, FX.GrainTile), -math.random(0, FX.GrainTile))
	end

	local dressing = Config.Dressing
	local state = drift >= dressing.PhotoFacelessAt and "faceless"
		or drift >= dressing.PhotoBlurAt and "blurred"
		or "normal"
	if state ~= photoState then
		photoState = state
		for card in photos do
			showPhoto(card)
		end
	end

	-- The air in each room drifts slowly, carrying its dust together.
	local clock = os.clock()
	for emitter, phase in dust do
		if emitter.Parent then
			emitter.Acceleration = Vector3.new(
				math.sin(clock * 0.11 + phase),
				math.sin(clock * 0.05 + phase * 2) * 0.4,
				math.cos(clock * 0.09 + phase)
			) * FX.DustCurrent
		end
	end

	-- Lights near The Guest's body sag, easing in and out, so you feel it
	-- before you see it. Shared decay: every player sees the same dimming
	-- (docs/ART.md rule 6). Flicker plays on top. Reduced-flicker mode dims
	-- smoothly instead of strobing.
	local guest = guestPosition()
	local ease = math.clamp(dt * FX.GuestDimEase, 0, 1)
	local now = os.clock()
	local huntTarget = (inRun and hunt.state == "hunt") and 1 or 0
	huntMix += (huntTarget - huntMix) * math.clamp(dt * Config.Lighting.HuntEase, 0, 1)
	for light, info in lights do
		if light.Parent then
			local target = 1
			if guest then
				local distance = (info.part.Position - guest).Magnitude
				local near = math.clamp((FX.GuestDimRadius - distance) / (FX.GuestDimRadius - FX.GuestDimFull), 0, 1)
				target = lerp(1, FX.GuestDimTo, near)
			end
			info.dim += (target - info.dim) * ease
			local base = info.base * info.dim
			local untilTime = flickering[light]
			if untilTime and now < untilTime then
				if settings.reduceFlicker then
					light.Brightness = base * 0.35
				else
					light.Brightness = math.random() < 0.45 and base * math.random() * 0.3 or base
				end
			else
				flickering[light] = nil
				light.Brightness = base
			end
			local red = info.lamp and huntMix or 0
			if info.lamp then
				light.Color = info.color:Lerp(HUNT_RED, red)
			end
			-- Glowing parts: as bright as their light, off when it's off.
			local level = light.Enabled and math.clamp(light.Brightness / math.max(info.base, 0.01), 0, 1) or 0
			local k = 0.12 + 0.88 * level
			for glow, color in info.glows do
				local c = color:Lerp(HUNT_RED, red)
				glow.Color = Color3.new(c.R * k, c.G * k, c.B * k)
			end
		end
	end
end

return EffectsController
