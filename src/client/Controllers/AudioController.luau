-- Audio (doc section 8: "audio does at least half the work"). Sound groups
-- per category with player volume settings, room reverb, Drift layers, the
-- hunt heartbeat, silence as a weapon, positional one-shots for phantom
-- sounds, and subtitles for key cues.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Assets = require(Shared.Assets)
local Config = require(Shared.Config)
local Constants = require(Shared.Constants)
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

local function newSound(key: string, volume: number, pitch: number, groupName: string)
	local id = Assets.Sounds[key]
	if not id or id == "" then
		return nil
	end
	local sound = Instance.new("Sound")
	sound.SoundId = id
	sound.Volume = volume
	sound.PlaybackSpeed = pitch
	sound.SoundGroup = group(groupName)
	sound.RollOffMinDistance = 6
	sound.RollOffMaxDistance = 90
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
	group("UI").Volume = master * 0.8
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
	local radioSignal = player:GetAttribute("RadioSignal")
	fade("Radio", (inRun and radioSignal) and (0.08 + radioSignal * 0.6) or 0)
	if layers.Radio then
		layers.Radio.PlaybackSpeed = 0.9 + (radioSignal or 0) * 0.4
	end
	-- Silence as a weapon: the Director drops ambience before an intrusion.
	local ambient = group("Ambient")
	local target = os.clock() < duckUntil and 0.05 or (self.ambientBase or 0.8)
	ambient.Volume += (target - ambient.Volume) * math.clamp(dt * 6, 0, 1)
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

function AudioController:PlayUi(key: string, volume: number?)
	local sound = newSound(key, volume or 0.5, 1, "UI")
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
