-- Everything players say is something the stalker can hear (doc section 5,
-- "Hearing"). Typed lines go through our own Say remote (Roblox's default chat
-- is switched off, so there is no silent channel) and are spoken aloud with
-- text-to-speech on nearby clients; microphone loudness arrives as VoiceLevel.
-- Both become NoiseService events at the speaker's real position. Hiding does
-- not muffle them: a loud mouth in a locker gets found.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Constants = require(Shared.Constants)
local Net = require(Shared.Net)
local VoiceNoise = require(Shared.Logic.VoiceNoise)

local States = Constants.PlayerStates

local V = Config.Voice

local ChatService = {}

local buckets: { [Player]: number } = {}

function ChatService:Init(services)
	self.Noise = services.NoiseService
	self.PlayerState = services.PlayerStateService
end

function ChatService:Start()
	Net.onServer("Say", { interval = V.SayInterval, burst = 2, types = { "string" } }, function(player, raw)
		self:_say(player, raw)
	end)
	Net.onServer("VoiceLevel", { interval = 0.2, burst = 8, types = { "number" } }, function(player, level)
		self:_voice(player, level)
	end)
	Players.PlayerRemoving:Connect(function(player)
		buckets[player] = nil
	end)
end

function ChatService:_voice(player: Player, level: number)
	local bucket = VoiceNoise.bucket(math.clamp(level, 0, 1), buckets[player] or 0, V)
	buckets[player] = bucket
	local root = self.PlayerState:Root(player)
	-- (An Echo makes no noise he can hear: the Lost are not in the house to him.)
	if bucket > 0 and root and self.PlayerState:State(player) ~= States.Lost then
		self.Noise:Emit(root.Position, VoiceNoise.radius(bucket, V), player, "voice")
	end
end

function ChatService:_say(player: Player, raw: string)
	local text, radius, whisper = VoiceNoise.fromText(raw, V)
	local root = self.PlayerState:Root(player)
	if not text or not root then
		return
	end
	local origin = root.Position
	if self.PlayerState:State(player) ~= States.Lost then
		self.Noise:Emit(origin, radius, player, "speech")
	end

	-- Roblox requires every shown line to be filtered, per reader.
	local ok, result = pcall(function()
		return TextService:FilterStringAsync(text, player.UserId, Enum.TextFilterContext.PublicChat)
	end)
	if not ok then
		return
	end
	for _, listener in Players:GetPlayers() do
		local listenerRoot = self.PlayerState:Root(listener)
		local near = listener == player or (listenerRoot and (listenerRoot.Position - origin).Magnitude <= V.HearRange)
		if near then
			local fine, filtered = pcall(function()
				return result:GetChatForUserAsync(listener.UserId)
			end)
			if fine and filtered ~= "" then
				Net.get("Spoke"):FireClient(listener, {
					userId = player.UserId,
					name = player.DisplayName,
					text = filtered,
					whisper = whisper,
				})
			end
		end
	end
end

return ChatService
