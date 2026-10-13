-- A fireplace's fire (the visual rework V3: the living room's lit brick
-- fireplace, the owner's pick of 2026-10-12). For each firebox (World/
-- PropFactory's Fireplace, tagged Fire): a warm light that flickers, flames
-- and the odd spark, the embers glowing through the kit mesh's mask, and a
-- crackle. Each client's own, decoration only: what counts as lit for the
-- rules is still WorldService's light rule. A fire far from you sleeps.
-- "Reduce flicker" holds the light steady.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Assets = require(Shared.Assets)
local Config = require(Shared.Config)
local Constants = require(Shared.Constants)

local F = Config.Fire

local FireController = {}

function FireController:Init(controllers)
	self.state = controllers.StateController
end

local fires = {} -- firebox -> its fire

local function rgb(t)
	return Color3.fromRGB(t[1], t[2], t[3])
end

local function emitter(name: string, texture: string): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Name = name
	e.Texture = texture
	e.EmissionDirection = Enum.NormalId.Top
	e.LightEmission = 1
	e.LightInfluence = 0
	e.Orientation = Enum.ParticleOrientation.FacingCamera
	e.Enabled = false
	return e
end

local function kindle(firebox: BasePart)
	local fire = { firebox = firebox, level = 0.5, target = 0.5, nextTarget = 0, awake = false }
	local at = Instance.new("Attachment")
	at.Name = "FireLightAt"
	at.Position = Vector3.new(F.LightAt[1], F.LightAt[2], F.LightAt[3])
	at.Parent = firebox
	local light = Instance.new("PointLight")
	light.Name = "FireLight"
	light.Color = rgb(F.Colour)
	light.Range = F.Range
	light.Brightness = 0
	light.Shadows = true
	light.Parent = at
	fire.light = light
	-- The bounce onto the surround and the mantel.
	local B = F.Bounce
	local bounceAt = Instance.new("Attachment")
	bounceAt.Name = "FireBounceAt"
	bounceAt.CFrame = CFrame.lookAt(Vector3.new(0, B.Height - 0.85, B.Ahead), Vector3.new(0, B.Height - 0.85, 0))
	bounceAt.Parent = firebox
	local bounce = Instance.new("SpotLight")
	bounce.Name = "FireBounce"
	bounce.Face = Enum.NormalId.Front
	bounce.Angle = B.Angle
	bounce.Range = B.Range
	bounce.Color = rgb(F.Colour)
	bounce.Brightness = 0
	bounce.Shadows = true
	bounce.Parent = bounceAt
	fire.bounce = bounce

	-- Flames: soft orange tongues licking up off the logs.
	local flames = emitter("Flames", "rbxasset://textures/particles/fire_main.dds")
	flames.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 196, 110)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 118, 40)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(120, 24, 8)),
	})
	flames.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.9),
		NumberSequenceKeypoint.new(0.5, 0.75),
		NumberSequenceKeypoint.new(1, 0.1),
	})
	flames.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.6),
		NumberSequenceKeypoint.new(0.2, 0.15),
		NumberSequenceKeypoint.new(1, 1),
	})
	flames.Lifetime = NumberRange.new(0.5, 0.9)
	flames.Speed = NumberRange.new(1.2, 2.4)
	flames.SpreadAngle = Vector2.new(12, 12)
	flames.Acceleration = Vector3.new(0, 1.5, 0)
	flames.RotSpeed = NumberRange.new(-40, 40)
	flames.Rotation = NumberRange.new(0, 360)
	flames.Parent = firebox
	fire.flames = flames

	-- A spark now and then.
	local sparks = emitter("Sparks", "rbxasset://textures/particles/sparkles_main.dds")
	sparks.Color = ColorSequence.new(Color3.fromRGB(255, 170, 80))
	sparks.Size = NumberSequence.new(0.06)
	sparks.Lifetime = NumberRange.new(0.6, 1.2)
	sparks.Speed = NumberRange.new(2, 4)
	sparks.SpreadAngle = Vector2.new(25, 25)
	sparks.Acceleration = Vector3.new(0, 1, 0)
	sparks.Rate = 3
	sparks.Parent = firebox
	fire.sparks = sparks

	local crackle = Instance.new("Sound")
	crackle.Name = "Crackle"
	crackle.SoundId = Assets.Sounds.FireCrackle
	crackle.Looped = true
	crackle.Volume = F.Volume
	crackle.RollOffMode = Enum.RollOffMode.InverseTapered
	crackle.RollOffMinDistance = 4
	crackle.RollOffMaxDistance = F.Reach
	crackle.SoundGroup = SoundService:FindFirstChild("ConsensusAmbient") :: SoundGroup?
	crackle.Parent = firebox
	fire.crackle = crackle

	-- The embers glow through the kit mesh's mask (World/Kit, Data/Kit's
	-- Fireplace): the mesh arrives with the house, so it's looked up lazily.
	fire.model = firebox.Parent
	fires[firebox] = fire
	firebox.Destroying:Connect(function()
		fires[firebox] = nil
	end)
end

local function embersOf(fire)
	if fire.embers ~= nil then
		return fire.embers or nil
	end
	local body = fire.model and fire.model:FindFirstChild("KitBody")
	local look = body and body:FindFirstChildOfClass("SurfaceAppearance")
	if look and look.EmissiveMaskContent.SourceType ~= Enum.ContentSourceType.None then
		look.EmissiveTint = rgb(F.EmberTint)
		fire.embers = look
		return look
	end
	if body then
		fire.embers = false -- a mesh with no mask: nothing to light
	end
	return nil
end

local function wake(fire, awake: boolean, preset)
	if fire.awake == awake then
		return
	end
	fire.awake = awake
	fire.flames.Enabled = awake
	fire.sparks.Enabled = awake
	fire.light.Enabled = awake
	fire.bounce.Enabled = awake
	if awake then
		fire.flames.Rate = preset.dust and F.Flames or F.Flames / 2
		fire.light.Shadows = preset.lightShadows ~= false
		fire.bounce.Shadows = preset.lightShadows ~= false
		fire.crackle:Play()
	else
		fire.crackle:Stop()
	end
end

function FireController:Start()
	for _, firebox in CollectionService:GetTagged(Constants.Tags.Fire) do
		kindle(firebox)
	end
	CollectionService:GetInstanceAddedSignal(Constants.Tags.Fire):Connect(kindle)

	RunService.RenderStepped:Connect(function(dt)
		if next(fires) == nil then
			return
		end
		local camera = Workspace.CurrentCamera
		local from = camera and camera.CFrame.Position or Vector3.zero
		local _, preset = self.state:Graphics()
		local steady = self.state.settings and self.state.settings.reduceFlicker == true
		local now = os.clock()
		for firebox, fire in fires do
			local near = firebox.Parent ~= nil and (firebox.Position - from).Magnitude < F.Near
			wake(fire, near, preset)
			if near then
				if steady then
					fire.target = 0.5
				elseif now >= fire.nextTarget then
					fire.nextTarget = now + (0.5 + math.random()) / F.Flicker -- (cosmetic: client timing only)
					fire.target = math.random() ^ 0.7
				end
				fire.level += (fire.target - fire.level) * math.clamp(dt * 12, 0, 1)
				local b = F.Brightness
				fire.light.Brightness = b[1] + (b[2] - b[1]) * fire.level
				local bb = F.Bounce.Brightness
				fire.bounce.Brightness = bb[1] + (bb[2] - bb[1]) * fire.level
				local embers = embersOf(fire)
				if embers then
					local e = F.Embers
					embers.EmissiveStrength = e[1] + (e[2] - e[1]) * fire.level
				end
			end
		end
	end)
end

return FireController
