-- Remote definitions. The server creates every remote at startup; clients
-- wait for them by name. Keeping the list here means a typo fails loudly.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local FOLDER_NAME = "ConsensusRemotes"

-- name -> class
local DEFINITIONS = {
	-- client -> server
	ReportView = "UnreliableRemoteEvent",
	Witness = "RemoteEvent",
	Ping = "RemoteEvent",
	Callout = "RemoteEvent",
	UseTool = "RemoteEvent",
	SetFlashlight = "RemoteEvent",
	HoldBreath = "RemoteEvent",
	LeaveHiding = "RemoteEvent",
	SelectTool = "RemoteEvent",
	SetReady = "RemoteEvent",
	SetDifficulty = "RemoteEvent",
	CastVote = "RemoteEvent",
	RitualAction = "RemoteEvent",
	SaveSettings = "RemoteEvent",
	DebugCommand = "RemoteEvent",
	RequestSync = "RemoteEvent",
	Say = "RemoteEvent", -- typed line: spoken aloud and heard by the stalker (Services/ChatService)
	VoiceLevel = "RemoteEvent", -- mic loudness 0..1 while talking (Controllers/SpeechController)

	-- server -> client
	Spoke = "RemoteEvent", -- a filtered line to speak with text-to-speech
	PerceptionProfile = "RemoteEvent",
	PerceptionAnchor = "RemoteEvent",
	StalkerVisibility = "RemoteEvent",
	GuestEvent = "RemoteEvent", -- server -> client: knock, tell, lunge, catch (Controllers/GuestController)
	Pinged = "RemoteEvent",
	CalloutHeard = "RemoteEvent",
	CaseBoard = "RemoteEvent",
	VerdictState = "RemoteEvent",
	Notify = "RemoteEvent",
	Scare = "RemoteEvent",
	HuntState = "RemoteEvent",
	WitnessFeedback = "RemoteEvent",
	Layout = "RemoteEvent",
	Dossier = "RemoteEvent",
	PhotoResult = "RemoteEvent",
	PlumbLine = "RemoteEvent",
	LobbyState = "RemoteEvent",
	RitualState = "RemoteEvent",
	DebugState = "UnreliableRemoteEvent",
	ProfileData = "RemoteEvent",
	ItemLabels = "RemoteEvent",
}

local Net = {}

local folder: Folder? = nil

local function getFolder(): Folder
	if folder then
		return folder
	end
	if RunService:IsServer() then
		local existing = ReplicatedStorage:FindFirstChild(FOLDER_NAME)
		if not existing then
			existing = Instance.new("Folder")
			existing.Name = FOLDER_NAME
			existing.Parent = ReplicatedStorage
		end
		folder = existing
	else
		folder = ReplicatedStorage:WaitForChild(FOLDER_NAME)
	end
	return folder :: Folder
end

-- Called once by the server bootstrap.
function Net.createAll()
	local parent = getFolder()
	for name, className in DEFINITIONS do
		if not parent:FindFirstChild(name) then
			local remote = Instance.new(className)
			remote.Name = name
			remote.Parent = parent
		end
	end
end

function Net.get(name: string): any
	assert(DEFINITIONS[name], "Unknown remote: " .. tostring(name))
	local parent = getFolder()
	if RunService:IsServer() then
		local remote = parent:FindFirstChild(name)
		assert(remote, "Remote not created yet: " .. name)
		return remote
	end
	return parent:WaitForChild(name)
end

-- Check argument types against a schema like { "string?", "Vector3" }.
-- A trailing "?" allows nil. Extra arguments are rejected.
function Net.validate(schema: { string }, ...): boolean
	local count = select("#", ...)
	if count > #schema then
		return false
	end
	for i, expected in schema do
		local value = select(i, ...)
		local optional = string.sub(expected, -1) == "?"
		local typeName = optional and string.sub(expected, 1, -2) or expected
		if value == nil then
			if not optional then
				return false
			end
		elseif typeof(value) ~= typeName then
			return false
		elseif typeName == "number" and (value ~= value or math.abs(value) == math.huge) then
			return false -- NaN and infinities never reach game logic
		end
	end
	return true
end

-- Server helper: connect a handler with per-player rate limiting and
-- argument validation (doc section 7: "validate the type, range and rate of
-- every remote").
--   options: a number (minimum seconds between calls), or a table
--     { interval = s, burst = calls per second window, types = schema }
-- Calls that break the limits or the schema are dropped silently.
function Net.onServer(name: string, options: any, handler: (Player, ...any) -> ())
	local remote = Net.get(name)
	local opts = type(options) == "number" and { interval = options } or options
	local interval = opts.interval or 0
	local burst = opts.burst or 20
	local schema = opts.types
	local last: { [Player]: number } = {}
	local history: { [Player]: { number } } = {}
	game:GetService("Players").PlayerRemoving:Connect(function(player)
		last[player] = nil
		history[player] = nil
	end)
	return remote.OnServerEvent:Connect(function(player, ...)
		local now = os.clock()
		if last[player] and now - last[player] < interval then
			return
		end
		-- Sliding one-second window, so a flood can't sneak under the
		-- per-call interval by spacing calls just right.
		local calls = history[player] or {}
		local recent = {}
		for _, t in calls do
			if now - t < 1 then
				table.insert(recent, t)
			end
		end
		if #recent >= burst then
			history[player] = recent
			return
		end
		table.insert(recent, now)
		history[player] = recent
		if schema and not Net.validate(schema, ...) then
			return
		end
		last[player] = now
		local ok, err = pcall(handler, player, ...)
		if not ok then
			warn(string.format("[Consensus] remote %s from %s failed: %s", name, player.Name, tostring(err)))
		end
	end)
end

return Net
