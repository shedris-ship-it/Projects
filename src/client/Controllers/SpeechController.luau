-- Speech: typed lines and the microphone (doc section 5, "Hearing").
--   Typing:  Say sends a line; the server filters it and every nearby client
--            speaks it with text-to-speech from the speaker's head, so the
--            squad hears it (and so does the stalker).
--   Voice:   the local mic's loudness is reported while you talk, and the
--            server turns it into noise at your real position.
-- Roblox's default chat is turned off here and in default.project.json.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local StarterGui = game:GetService("StarterGui")
local TextChatService = game:GetService("TextChatService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Net = require(Shared.Net)
local VoiceNoise = require(Shared.Logic.VoiceNoise)

local V = Config.Voice
local player = Players.LocalPlayer

local SpeechController = {}

local listener: AudioListener? = nil

function SpeechController:Init(controllers)
	self.controllers = controllers
end

local function disableDefaultChat()
	pcall(function()
		TextChatService.ChatWindowConfiguration.Enabled = false
		TextChatService.ChatInputBarConfiguration.Enabled = false
	end)
	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Chat, false)
	end)
end

-- Emitters are only heard through an AudioListener, which sits on the camera.
local function ensureListener()
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	if listener and listener.Parent == camera then
		return
	end
	listener = Instance.new("AudioListener")
	listener.Parent = camera
	local output = Instance.new("AudioDeviceOutput")
	output.Parent = SoundService
	local wire = Instance.new("Wire")
	wire.SourceInstance = listener
	wire.TargetInstance = output
	wire.Parent = listener
end

local function speak(userId: number, text: string, whisper: boolean)
	local speaker = Players:GetPlayerByUserId(userId)
	local head = speaker and speaker.Character and speaker.Character:FindFirstChild("Head")
	if not head then
		return
	end
	ensureListener()
	local tts = Instance.new("AudioTextToSpeech")
	tts.Text = text
	tts.VoiceId = tostring(userId % 2 + 1)
	tts.Volume = whisper and 0.4 or 1
	tts.Parent = head
	local emitter = Instance.new("AudioEmitter")
	emitter.Parent = head
	pcall(function()
		emitter:SetDistanceAttenuation({ [0] = 1, [10] = 0.6, [V.HearRange] = 0 })
	end)
	local wire = Instance.new("Wire")
	wire.SourceInstance = tts
	wire.TargetInstance = emitter
	wire.Parent = emitter
	task.spawn(function()
		local ok = pcall(function()
			tts:LoadAsync()
			tts:Play()
		end)
		task.wait(ok and tts.TimeLength + 1 or 0)
		tts:Destroy()
		emitter:Destroy()
	end)
end

function SpeechController:Say(text: string)
	Net.get("Say"):FireServer(text)
end

-- Report the mic's loudness: when it changes bucket, and while talking.
function SpeechController:_watchMic()
	local input = player:WaitForChild("AudioDeviceInput", 30)
	if not input then
		return -- no voice chat for this player, so only typing makes noise
	end
	local analyzer = Instance.new("AudioAnalyzer")
	analyzer.Parent = input
	local wire = Instance.new("Wire")
	wire.SourceInstance = input
	wire.TargetInstance = analyzer
	wire.Parent = analyzer
	local bucket = 0
	while true do
		task.wait(V.ReportInterval)
		local level = input.Muted and 0 or analyzer.RmsLevel
		local nextBucket = VoiceNoise.bucket(level, bucket, V)
		if nextBucket > 0 or bucket > 0 then
			Net.get("VoiceLevel"):FireServer(nextBucket > 0 and math.clamp(level, 0, 1) or 0)
		end
		bucket = nextBucket
	end
end

function SpeechController:Start()
	disableDefaultChat()
	Net.get("Spoke").OnClientEvent:Connect(function(line)
		if type(line) ~= "table" or type(line.text) ~= "string" or type(line.userId) ~= "number" then
			return
		end
		local who = line.userId == player.UserId and "You" or tostring(line.name)
		self.controllers.UIController:Toast(string.format("%s: %s", who, line.text), "callout")
		speak(line.userId, line.text, line.whisper == true)
	end)
	task.spawn(function()
		local ok, err = pcall(self._watchMic, self)
		if not ok then
			warn("[Consensus] mic watch failed: " .. tostring(err))
		end
	end)
end

return SpeechController
