-- Audio (doc section 8: "audio does at least half the work"). Sound groups
-- per category with player volume settings, room reverb, Drift layers, the
-- hunt heartbeat, silence as a weapon, positional one-shots for phantom
-- sounds, and subtitles for key cues.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Assets = require(Shared.Assets)
local Config = require(Shared.Config)
local Constants = require(Shared.Constants)
local Feel = require(Shared.Logic.Feel)
local Net = require(Shared.Net)

local player = Players.LocalPlayer

local AudioController = {}

local groups = {}
local layers = {}
local duckUntil = 0

local function group(name: string): SoundGroup
	if groups[name] then
		return groups[name]
	end
	local g = SoundService:FindFirstChild("Consensus" .. name) or Instance.new("SoundGroup")
	g.Name = "Consensus" .. name
	g.Parent = SoundService
	groups[name] = g
	return g
end

-- How far each kind of sound carries (studs); the rest use 90.
local ROLLOFF = { Drip = 30, FlashlightClick = 15, Cloth = 25, Drawer = 30, UIClick = 10, UIHover = 10, Knock = 70 }

local function newSound(key: string, volume: number, pitch: number, groupName: string)
	-- A key from Assets.Sounds, or a raw asset id (footsteps pass their own).
	local id = Assets.Sounds[key] or (string.find(key, "^rbxasset") and key or nil)
	if not id or id == "" then
		return nil
	end
	local sound = Instance.new("Sound")
	sound.SoundId = id
	sound.Volume = volume
	sound.PlaybackSpeed = pitch
	sound.SoundGroup = group(groupName)
	sound.RollOffMinDistance = 6
	sound.RollOffMaxDistance = ROLLOFF[key] or 90
	return sound
end

function AudioController:Init(controllers)
	self.controllers = controllers
	self.state = controllers.StateController
end

function AudioController:Start()
	group("SFX")
	group("Ambient")
	group("UI")
	self:_applyVolumes(self.state.settings)
	self.state.SettingsChanged:Connect(function(settings)
		self:_applyVolumes(settings)
	end)

	-- Drift layers: looped beds whose volume follows Drift.
	for key, info in
		{
			DriftBass = { group = "Ambient" },
			DriftTinnitus = { group = "Ambient" },
			RoomTone = { group = "Ambient" },
			Heartbeat = { group = "SFX" },
		}
	do
		local sound = newSound(key, 0, 1, info.group)
		if sound then
			sound.Looped = true
			sound.Parent = SoundService
			sound:Play()
			layers[key] = sound
		end
	end
	-- Your own breath, looped; its volume and pitch follow stamina.
	local breath = newSound("PlayerBreath", 0, 1, "SFX")
	if breath then
		breath.Looped = true
		-- Faster breathing must not mean a higher voice: a pitch-shift undoes
		-- what the playback speed would do to the pitch (see _ownBreath).
		local shift = Instance.new("PitchShiftSoundEffect")
		shift.Name = "HoldPitch"
		shift.Octave = Feel.breathOctave(Feel.breathTempo(1, Config.Feel), Config.Feel)
		shift.Parent = breath
		breath.Parent = SoundService
		breath:Play()
		layers.PlayerBreath = breath
	end
	-- The house holds its breath when he first shows himself to you.
	Net.get("StalkerVisibility").OnClientEvent:Connect(function(visible)
		if visible == true and self.state:InRun() then
			self:Duck(2.5)
		end
	end)
	local radio = newSound("RadioStatic", 0, 1, "SFX")
	if radio then
		radio.Looped = true
		radio.Parent = SoundService
		radio:Play()
		layers.Radio = radio
	end

	Net.get("HuntState").OnClientEvent:Connect(function(payload)
		if payload.state == "telegraph" then
			self:PlayUi("HuntSting", 1)
			self:Caption(payload.final and "[the house screams]" or "[a low hum rises]")
		elseif payload.state == "end" then
			self:Caption("[the hum fades]")
		end
	end)
	Net.get("PhotoResult").OnClientEvent:Connect(function()
		self:PlayUi("Shutter", 0.8)
	end)
	Net.get("Pinged").OnClientEvent:Connect(function()
		self:PlayUi("Ping", 0.35)
	end)
	-- Sounds the server asks for (doors, the stalker): played here so the
	-- sliders, wall muffling and rolloff apply (Lib/Sfx).
	Net.get("Sfx").OnClientEvent:Connect(function(key, position, volume, pitch)
		if type(key) == "string" and typeof(position) == "Vector3" then
			self:PlayAt(key, position, tonumber(volume), tonumber(pitch), self:_behindWall(position))
		end
	end)
	-- Hands and verdicts.
	Net.get("WitnessFeedback").OnClientEvent:Connect(function(fb)
		if fb.type == "anchored" then
			self:PlayUi("Stamp", 0.7, 1)
		elseif fb.type == "window" then
			self:PlayUi("UIClick", 0.25, 0.7)
		end
	end)
	Net.get("VerdictState").OnClientEvent:Connect(function(state)
		if state.active == false and state.result then
			self:PlayUi("Stamp", 0.8, 0.7)
		elseif state.active then
			self:PlayUi("UIClick", 0.4, 0.7)
		end
	end)
	player:GetAttributeChangedSignal("LanternOn"):Connect(function()
		if player:GetAttribute("LanternOn") == true then
			self:PlayUi("Match", 0.6, 1)
		else
			self:PlayUi("UIClick", 0.2, 0.8)
		end
	end)
	local wasExtracted = false
	self.state.PlayerStateChanged:Connect(function()
		local extracted = self.state:PlayerState() == Constants.PlayerStates.Extracted
		if extracted and not wasExtracted then
			self:PlayUi("DoorOpen", 0.6, 1)
		end
		wasExtracted = extracted
	end)
	-- As Drift rises the house sounds more muffled and wrong.
	local muffle = Instance.new("EqualizerSoundEffect")
	muffle.Name = "DriftMuffle"
	muffle.LowGain = 0
	muffle.MidGain = 0
	muffle.HighGain = 0
	muffle.Parent = group("Ambient")
	self.driftMuffle = muffle

	local lastRoom = nil
	RunService.Heartbeat:Connect(function(dt)
		self:_updateLayers(dt)
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if root then
			local room = self.state:RoomAt(root.Position)
			local name = room and room.reverb or (self.state:InRun() and "Room" or "LivingRoom")
			if name ~= lastRoom then
				lastRoom = name
				pcall(function()
					SoundService.AmbientReverb = (Enum.ReverbType :: any)[name]
				end)
			end
		end
	end)
end

function AudioController:_applyVolumes(settings)
	local master = settings.masterVolume or 1
	group("SFX").Volume = master * (settings.sfxVolume or 1)
	group("UI").Volume = master * Config.Audio.UiVolume
	self.ambientBase = master * (settings.ambientVolume or 0.8)
	group("Ambient").Volume = self.ambientBase
end

function AudioController:_updateLayers(dt: number)
	local inRun = self.state:InRun()
	local drift = inRun and self.state:Drift() or 0
	local hunting = inRun and self.state:Run(Constants.RunState.Hunting) == true
	local function fade(key, target)
		local sound = layers[key]
		if sound then
			sound.Volume += (target - sound.Volume) * math.clamp(dt * 1.5, 0, 1)
		end
	end
	fade("RoomTone", inRun and 0.3 or 0)
	fade("DriftBass", inRun and math.clamp((drift - 30) / 70, 0, 1) * 0.6 or 0)
	fade("DriftTinnitus", inRun and math.clamp((drift - 70) / 30, 0, 1) * 0.25 or 0)
	-- Bleeding out: your own heart, loud and slowing down (tempo matches the
	-- red rim in EffectsController).
	local bleed = inRun and self.controllers.EffectsController:BleedFraction() or nil
	fade("Heartbeat", bleed and 1.2 or hunting and 0.8 or (drift > 85 and 0.3 or 0))
	if layers.Heartbeat then
		local speeds = Config.Run.BleedHeartbeat
		layers.Heartbeat.PlaybackSpeed = bleed and speeds[1] + (speeds[2] - speeds[1]) * bleed or 1
	end
	if inRun then
		self:_gasps()
	end
	self:_ownBreath(dt, inRun)
	local radioSignal = player:GetAttribute("RadioSignal")
	fade("Radio", (inRun and radioSignal) and (0.08 + radioSignal * 0.6) or 0)
	if layers.Radio then
		layers.Radio.PlaybackSpeed = 0.9 + (radioSignal or 0) * 0.4
	end
	if self.driftMuffle then
		local target = Config.Audio.DriftMuffleDb * math.clamp((drift - 40) / 60, 0, 1)
		self.driftMuffle.HighGain += (target - self.driftMuffle.HighGain) * math.clamp(dt * 0.8, 0, 1)
	end
	-- Silence as a weapon: the Director drops ambience before an intrusion.
	local ambient = group("Ambient")
	local target = os.clock() < duckUntil and 0.05 or (self.ambientBase or 0.8)
	ambient.Volume += (target - ambient.Volume) * math.clamp(dt * 6, 0, 1)
end

-- Quiet when you're fresh, ragged and fast as stamina drains, a gasp when it
-- runs out, easing off as you recover (stamina comes from ActionController).
local wasExhausted = false
function AudioController:_ownBreath(dt: number, inRun: boolean)
	local sound = layers.PlayerBreath
	local actions = self.controllers.ActionController
	local alive = inRun and actions and self.state:PlayerState() == Constants.PlayerStates.Active
	local stamina = alive and actions.stamina or 1
	local start = Config.Feel.BreathStartStamina
	local target = alive and math.clamp((start - stamina) / start, 0, 1) * 0.9 or 0
	if alive and actions.sprinting then
		target = math.max(target, 0.12)
	end
	if sound then
		sound.Volume += (target - sound.Volume) * math.clamp(dt * 3, 0, 1)
		-- Tempo rises as stamina falls; the pitch stays at BreathPitch.
		local speed = Feel.breathTempo(stamina, Config.Feel)
		sound.PlaybackSpeed = speed
		local shift = sound:FindFirstChild("HoldPitch")
		if shift then
			shift.Octave = Feel.breathOctave(speed, Config.Feel)
		end
	end
	local exhausted = alive and actions.exhausted == true
	if exhausted and not wasExhausted then
		self:PlayUi("Gasp", Config.Feel.BreathGasp.volume, Config.Feel.BreathGasp.pitch)
	end
	wasExhausted = exhausted
end

-- Downed Witnesses gasp for breath where they lie, so the squad can find
-- them by ear (and so can the downed player).
local nextGasp = {}
function AudioController:_gasps()
	local now = os.clock()
	for _, other in Players:GetPlayers() do
		local downed = other:GetAttribute(Constants.PlayerAttributes.State) == Constants.PlayerStates.Downed
		local head = downed and other.Character and other.Character:FindFirstChild("Head")
		if head and head:IsA("BasePart") then
			if now >= (nextGasp[other] or 0) then
				nextGasp[other] = now + 2.2 + math.random() * 1.6
				self:PlayAt(math.random() < 0.5 and "Gasp" or "GaspAlt", head.Position, 0.7, 0.9 + math.random() * 0.15)
			end
		else
			nextGasp[other] = nil
		end
	end
end

function AudioController:Duck(seconds: number)
	duckUntil = os.clock() + seconds
end

-- Is a wall between the camera and this point?
function AudioController:_behindWall(position: Vector3): boolean
	local camera = Workspace.CurrentCamera
	if not camera then
		return false
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { player.Character or camera }
	return Workspace:Raycast(camera.CFrame.Position, position - camera.CFrame.Position, params) ~= nil
end

-- One-shot positional sound. `muffled` low-passes it, for sounds heard
-- through a wall.
function AudioController:PlayAt(key: string, position: Vector3, volume: number?, pitch: number?, muffled: boolean?)
	local sound = newSound(key, volume or 0.6, pitch or 1, "SFX")
	if not sound then
		return
	end
	if muffled then
		local eq = Instance.new("EqualizerSoundEffect")
		eq.LowGain = 2
		eq.MidGain = -12
		eq.HighGain = -30
		eq.Parent = sound
	end
	local attachment = Instance.new("Attachment")
	attachment.Parent = Workspace.Terrain
	attachment.WorldPosition = position
	sound.Parent = attachment
	sound:Play()
	task.delay(math.max(3, sound.TimeLength + 0.5), function()
		attachment:Destroy()
	end)
end

-- A long sound cut to its first `seconds` with a fade: positional when a
-- position is given, otherwise straight to the ears.
function AudioController:PlayFor(key: string, position: Vector3?, volume: number, pitch: number, seconds: number)
	local sound = newSound(key, volume, pitch, position and "SFX" or "UI")
	if not sound then
		return
	end
	local holder: Instance = SoundService
	if position then
		local attachment = Instance.new("Attachment")
		attachment.Parent = Workspace.Terrain
		attachment.WorldPosition = position
		holder = attachment
	end
	sound.Parent = holder
	sound:Play()
	task.delay(seconds, function()
		-- A smooth fade out, then clean up.
		local fade = TweenService:Create(sound, TweenInfo.new(Config.Audio.HuntFadeSeconds), { Volume = 0 })
		fade:Play()
		fade.Completed:Wait()
		if holder ~= SoundService then
			holder:Destroy()
		else
			sound:Destroy()
		end
	end)
end

function AudioController:PlayUi(key: string, volume: number?, pitch: number?)
	local sound = newSound(key, volume or 0.5, pitch or 1, "UI")
	if not sound then
		return
	end
	sound.Parent = SoundService
	sound:Play()
	task.delay(5, function()
		sound:Destroy()
	end)
end

-- A burst of footsteps; positionFn is called per step so steps can follow
-- the listener.
function AudioController:Steps(positionFn: () -> Vector3, count: number, interval: number)
	task.spawn(function()
		for i = 1, count do
			local pos = positionFn()
			if pos then
				self:PlayAt("Footstep", pos, 0.55, 0.78 + (i % 2) * 0.05)
			end
			task.wait(interval)
		end
	end)
end

function AudioController:Knock(position: Vector3)
	task.spawn(function()
		for _ = 1, 3 do
			self:PlayAt("Knock", position, 0.8, 1.15)
			task.wait(0.35)
		end
	end)
end

-- Looping positional sound; returns the attachment (Destroy to stop).
function AudioController:Loop(key: string, position: Vector3, volume: number)
	local sound = newSound(key, volume, 1, "SFX")
	if not sound then
		-- No asset: fall back to a low hiss from what we have.
		sound = newSound("Whoosh", volume * 0.5, 0.35, "SFX")
	end
	if not sound then
		return nil
	end
	sound.Looped = true
	local attachment = Instance.new("Attachment")
	attachment.WorldPosition = position
	attachment.Parent = Workspace.Terrain
	sound.Parent = attachment
	sound:Play()
	return attachment
end

-- Subtitles for key audio cues (accessibility, doc section 8).
function AudioController:Caption(text: string)
	if not self.state.settings.subtitles then
		return
	end
	local ui = self.controllers.UIController
	if ui then
		ui:Caption(text)
	end
end

return AudioController
