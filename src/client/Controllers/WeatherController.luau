-- The storm on your screen and in your ears (the visual rework V2; the
-- server decides it: Services/WeatherService, Logic/Storm). By the storm's
-- stage (RunState Storm): rain drumming on the house and on the nearest
-- window's glass, and streaks falling just outside the nearest windows. On a
-- strike: the flash through the windows (the moon beams burn, the sky ring
-- lights, the outdoors brightens, the lens opens for an instant), then the
-- thunder, as long after as the strike is far. "Reduce flicker" turns each
-- strike into one soft swell. Looks and sound only.

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Assets = require(Shared.Assets)
local Config = require(Shared.Config)
local Constants = require(Shared.Constants)
local Net = require(Shared.Net)

local S = Config.Storm
local RS = Constants.RunState

local WeatherController = {}

local outdoorBase: Color3? = nil -- the outdoor ambient as the place has it

function WeatherController:Init(controllers)
	self.state = controllers.StateController
	self.lens = controllers.LensController
	self.audio = controllers.AudioController
end

local function ambientGroup(): SoundGroup?
	return SoundService:FindFirstChild("ConsensusAmbient") :: SoundGroup?
end

local function loop(id: string, name: string): Sound
	local sound = Instance.new("Sound")
	sound.Name = name
	sound.SoundId = id
	sound.Looped = true
	sound.Volume = 0
	return sound
end

-- The windows you could see rain through: those with a real opening.
local function openWindows()
	local list = {}
	for _, model in CollectionService:GetTagged(Constants.Tags.Window) do
		local glass = model:FindFirstChild("Glass")
		if glass and model:FindFirstChild("WindowBar") then
			table.insert(list, glass)
		end
	end
	return list
end

local function rainBox(glass: BasePart): Part
	-- A box just outside the glass (the window's +Z faces the room).
	local outward = -glass.CFrame.LookVector
	local box = Instance.new("Part")
	box.Name = "Rain"
	box.Anchored = true
	box.CanCollide = false
	box.CanQuery = false
	box.CanTouch = false
	box.CastShadow = false
	box.Transparency = 1
	box.Size = Vector3.new(14, 2, 7)
	box.CFrame = CFrame.lookAt(
		glass.Position + outward * 5 + Vector3.new(0, 8, 0),
		glass.Position + outward * 6 + Vector3.new(0, 8, 0)
	)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "Streaks"
	emitter.Shape = Enum.ParticleEmitterShape.Box
	emitter.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	emitter.EmissionDirection = Enum.NormalId.Bottom
	emitter.Speed = NumberRange.new(55, 70)
	emitter.SpreadAngle = Vector2.new(4, 4)
	emitter.Lifetime = NumberRange.new(0.35, 0.5)
	-- Upright to the camera and stretched tall (Squash above 0 stretches
	-- up and down; below 0, sideways): streaks, not dots. Faintly lit by
	-- themselves, or they vanish against the night (seen 2026-10-12).
	emitter.Size = NumberSequence.new(0.18)
	emitter.Squash = NumberSequence.new(3)
	emitter.Orientation = Enum.ParticleOrientation.FacingCameraWorldUp
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.15, 0.3),
		NumberSequenceKeypoint.new(0.85, 0.4),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Color = ColorSequence.new(Color3.fromRGB(205, 215, 235))
	emitter.LightInfluence = 0.15
	emitter.LightEmission = 1
	emitter.Rate = 0
	emitter.Parent = box
	box.Parent = Workspace.CurrentCamera -- client only
	return box
end

function WeatherController:Start()
	outdoorBase = Lighting.OutdoorAmbient
	local runState = ReplicatedStorage:WaitForChild("RunState")
	local bed = loop(Assets.Sounds.RainBed, "RainBed")
	bed.Parent = SoundService
	local glassSound = loop(Assets.Sounds.RainGlass, "RainGlass")
	local emitterPart = Instance.new("Part")
	emitterPart.Name = "RainOnGlass"
	emitterPart.Anchored = true
	emitterPart.CanCollide = false
	emitterPart.CanQuery = false
	emitterPart.CanTouch = false
	emitterPart.Transparency = 1
	emitterPart.Size = Vector3.new(0.2, 0.2, 0.2)
	emitterPart.Parent = Workspace.CurrentCamera
	glassSound.RollOffMinDistance = 6
	glassSound.RollOffMaxDistance = S.GlassReach
	glassSound.Parent = emitterPart
	local group = ambientGroup()
	bed.SoundGroup = group
	glassSound.SoundGroup = group

	local boxes = {} -- glass -> its rain box
	local nextScan = 0
	local stage = 0
	runState:GetAttributeChangedSignal(RS.Storm):Connect(function()
		stage = runState:GetAttribute(RS.Storm) or 0
	end)
	stage = runState:GetAttribute(RS.Storm) or 0

	RunService.RenderStepped:Connect(function(dt)
		local camera = Workspace.CurrentCamera
		if not camera then
			return
		end
		if not bed.SoundGroup then
			group = ambientGroup()
			bed.SoundGroup, glassSound.SoundGroup = group, group
		end
		local inRun = self.state:InRun()
		local wet = inRun and stage >= 1
		local k = stage >= 2 and 2 or 1
		local bedTarget = wet and S.RainVolume.bed[k] or 0
		if not inRun then
			-- The hub: rain on the mall's skylight, softer (Config.Mall.Rain).
			bedTarget = S.RainVolume.bed[1] * (Config.Mall.Rain or 0)
		end
		local glassTarget = wet and S.RainVolume.glass[k] or 0
		local ease = math.clamp(dt * 0.5, 0, 1) -- the rain comes on over a few seconds
		bed.Volume += (bedTarget - bed.Volume) * ease
		glassSound.Volume += (glassTarget - glassSound.Volume) * ease
		if bed.Volume > 0.005 and not bed.IsPlaying then
			bed:Play()
			glassSound:Play()
		elseif bed.Volume <= 0.005 and bed.IsPlaying and not wet then
			bed:Stop()
			glassSound:Stop()
		end

		local now = os.clock()
		if now < nextScan then
			return
		end
		nextScan = now + 1
		-- The nearest windows: the glass sound sits on the nearest, rain falls
		-- outside each of the few nearest (fewer on a weaker machine).
		local from = camera.CFrame.Position
		local windows = openWindows()
		table.sort(windows, function(a, b)
			return (a.Position - from).Magnitude < (b.Position - from).Magnitude
		end)
		if windows[1] then
			emitterPart.Position = windows[1].Position
		end
		local _, preset = self.state:Graphics()
		local count = wet and (preset.dust and S.RainNearWindows or 2) or 0
		local rate = wet and S.RainRate[k] or 0
		local wanted = {}
		for i = 1, math.min(count, #windows) do
			local glass = windows[i]
			if (glass.Position - from).Magnitude < 70 then
				wanted[glass] = true
				local box = boxes[glass] or rainBox(glass)
				boxes[glass] = box
				box.Streaks.Rate = rate
			end
		end
		for glass, box in boxes do
			if not wanted[glass] or not glass.Parent then
				box:Destroy()
				boxes[glass] = nil
			end
		end
	end)

	Net.get("Lightning").OnClientEvent:Connect(function(strike)
		self:_strike(strike)
	end)
end

-- What lights up in a flash: the moon beams through the windows (and so the
-- haze and dust they light in the air) and the sky ring, at their built
-- brightness.
local beamBase = {}
local function flashTargets()
	local beams = {}
	for _, part in CollectionService:GetTagged("ConsensusMoonLight") do
		local beam = part:FindFirstChildWhichIsA("SpotLight")
		if beam then
			beamBase[beam] = beamBase[beam] or beam.Brightness
			table.insert(beams, beam)
		end
	end
	local skies = {}
	local level = Workspace:FindFirstChild("ConsensusLevel")
	local exterior = level and level:FindFirstChild("Exterior")
	if exterior then
		for _, d in exterior:GetChildren() do
			local gui = d.Name == "SkyPanel" and d:FindFirstChild("Night")
			if gui then
				table.insert(skies, gui)
			end
		end
	end
	return beams, skies
end

function WeatherController:_flash(strength: number, seconds: number, soft: boolean)
	local beams, skies = flashTargets()
	local outdoor = outdoorBase or Lighting.OutdoorAmbient -- (as built: never a flash's own)
	local flashColour = Color3.fromRGB(table.unpack(S.FlashOutdoor))
	local function apply(t: number)
		for _, beam in beams do
			beam.Brightness = beamBase[beam] * (1 + S.FlashMoon * t)
		end
		for _, gui in skies do
			gui.Brightness = 1 + (S.FlashSky - 1) * t
		end
		Lighting.OutdoorAmbient = outdoor:Lerp(flashColour, t)
	end
	if self.lens then
		self.lens:Flash(S.FlashExposure * strength, soft and seconds * 3 or seconds)
	end
	if soft then
		-- One soft swell up and down, never a strobe.
		local value = Instance.new("NumberValue")
		value.Changed:Connect(apply)
		local up = TweenService:Create(value, TweenInfo.new(0.25, Enum.EasingStyle.Sine), { Value = strength * 0.5 })
		up:Play()
		up.Completed:Wait()
		local down = TweenService:Create(value, TweenInfo.new(0.6, Enum.EasingStyle.Sine), { Value = 0 })
		down:Play()
		down.Completed:Wait()
		value:Destroy()
		apply(0)
		Lighting.OutdoorAmbient = outdoor
		return
	end
	apply(strength)
	task.wait(seconds)
	apply(0)
	Lighting.OutdoorAmbient = outdoor
end

function WeatherController:_strike(strike)
	-- A strike over the lobby's mall (Services/MallService, marked `hub`) is
	-- for those in the hub, through its skylight and main doors (their lights
	-- are tagged as moon beams); the house's is for those in the run.
	if (strike.hub == true) == self.state:InRun() then
		return
	end
	local soft = self.state.settings.reduceFlicker == true
	for i, f in strike.flashes do
		if soft and i > 1 then
			break
		end
		task.delay(f.at, function()
			self:_flash(f.strength, f.seconds, soft)
		end)
	end
	task.delay(strike.thunder, function()
		local key = (strike.sound == "near" and "ThunderNear" or "ThunderFar") .. tostring(strike.variant or 1)
		local id = Assets.Sounds[key]
		if not id then
			return
		end
		local sound = Instance.new("Sound")
		sound.Name = "Thunder"
		sound.SoundId = id
		sound.Volume = strike.volume
		sound.PlaybackSpeed = 0.94 + 0.12 * math.random() -- (cosmetic: client timing only)
		sound.SoundGroup = ambientGroup()
		sound.Parent = SoundService
		sound:Play()
		sound.Ended:Connect(function()
			sound:Destroy()
		end)
		if self.audio and self.audio.Caption then
			self.audio:Caption(strike.sound == "near" and "[thunder, close]" or "[distant thunder]")
		end
	end)
end

return WeatherController
