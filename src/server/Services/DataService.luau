-- Player data (doc section 7: "a session-locked profile store"). A small
-- session lock on top of DataStoreService: a profile is only loaded when no
-- other live server holds it, and every save renews the lock. When DataStores
-- are unavailable (Studio without API access) profiles live in memory only.
--
-- Swap this for ProfileStore once the project uses Wally; the API here
-- (WaitForProfile, Get, GrantRunRewards) is all the rest of the game needs.

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)
local Progression = require(Shared.Logic.Progression)

local STORE_NAME = "ConsensusProfiles_v1"
local LOCK_SECONDS = 300
local AUTOSAVE_SECONDS = 90

local CURRENT_VERSION = 1

local TEMPLATE = {
	Version = CURRENT_VERSION,
	Marks = 0,
	Xp = 0,
	RunsPlayed = 0,
	Wins = 0,
	Extractions = 0,
	Settings = {},
	Dossier = {}, -- discovered anomaly and stalker entries
}

local DataService = {}

local profiles: { [Player]: any } = {}
local loaded: { [Player]: boolean } = {}
local sessionId = HttpService:GenerateGUID(false)

function DataService:Init()
	local ok, store = pcall(function()
		return DataStoreService:GetDataStore(STORE_NAME)
	end)
	self.store = ok and store or nil
	if not ok then
		warn("[Consensus] DataStores unavailable; progress won't be saved this session.")
	end
end

-- Versioned migrations: add a step here whenever the saved shape changes.
local MIGRATIONS = {
	-- [1] = function(data) ... return data end, -- upgrades version 1 -> 2
}

local function reconcile(data)
	for key, value in TEMPLATE do
		if data[key] == nil then
			data[key] = type(value) == "table" and {} or value
		end
	end
	local version = data.Version or CURRENT_VERSION
	while version < CURRENT_VERSION do
		local step = MIGRATIONS[version]
		if step then
			data = step(data)
		end
		version += 1
	end
	data.Version = CURRENT_VERSION
	-- Clamp anything a bad write could have pushed out of range.
	data.Marks = math.clamp(tonumber(data.Marks) or 0, 0, 1e9)
	data.Xp = math.clamp(tonumber(data.Xp) or 0, 0, 1e9)
	return data
end

function DataService:_load(player: Player)
	local key = "player_" .. player.UserId
	local data = nil
	if self.store then
		for attempt = 1, 3 do
			local ok, result = pcall(function()
				return self.store:UpdateAsync(key, function(current)
					current = current or {}
					local lock = current.lock
					if lock and lock.session ~= sessionId and os.time() - lock.time < LOCK_SECONDS then
						return nil -- held by another live server: don't overwrite
					end
					current.lock = { session = sessionId, time = os.time() }
					current.data = reconcile(current.data or {})
					return current
				end)
			end)
			if ok and result and result.lock and result.lock.session == sessionId then
				data = result.data
				break
			end
			if not ok then
				warn("[Consensus] profile load failed: " .. tostring(result))
			end
			task.wait(2 * attempt)
		end
	end
	if not data then
		data = reconcile({})
		self.memoryOnly = self.memoryOnly or not self.store
	end
	profiles[player] = data
	loaded[player] = true
	self:Send(player)
end

function DataService:_save(player: Player, release: boolean)
	local data = profiles[player]
	if not data or not self.store then
		return
	end
	local key = "player_" .. player.UserId
	-- Retry with exponential backoff; DataStore budgets throttle rather than
	-- fail outright, so a short wait usually gets the write through.
	for attempt = 1, 3 do
		local ok, err = pcall(function()
			self.store:UpdateAsync(key, function(current)
				current = current or {}
				if current.lock and current.lock.session ~= sessionId then
					return nil
				end
				current.data = data
				current.lock = (not release) and { session = sessionId, time = os.time() } or nil
				return current
			end)
		end)
		if ok then
			return
		end
		warn(string.format("[Consensus] save for %s failed (attempt %d): %s", player.Name, attempt, tostring(err)))
		task.wait(2 ^ attempt)
	end
end

function DataService:Start()
	Players.PlayerAdded:Connect(function(player)
		self:_load(player)
	end)
	for _, player in Players:GetPlayers() do
		task.spawn(self._load, self, player)
	end
	Players.PlayerRemoving:Connect(function(player)
		self:_save(player, true)
		profiles[player] = nil
		loaded[player] = nil
	end)
	game:BindToClose(function()
		for _, player in Players:GetPlayers() do
			task.spawn(self._save, self, player, true)
		end
		task.wait(3)
	end)
	task.spawn(function()
		while true do
			task.wait(AUTOSAVE_SECONDS)
			for _, player in Players:GetPlayers() do
				task.spawn(self._save, self, player, false)
			end
		end
	end)
	Net.onServer("SaveSettings", { interval = 1, types = { "table" } }, function(player, settings)
		if type(settings) ~= "table" then
			return
		end
		local data = profiles[player]
		if not data then
			return
		end
		local clean = {}
		for _, key in
			{
				"reduceFlicker",
				"reduceGrain",
				"subtitles",
				"colorblind",
				"lowEnd",
				"centerDot",
				"fov",
				"cameraMotion",
				"masterVolume",
				"sfxVolume",
				"ambientVolume",
				"musicVolume",
				"tips",
				"seenIntro",
			}
		do
			local value = settings[key]
			if
				type(value) == "boolean" or (type(value) == "number" and value == value and value >= 0 and value <= 120)
			then
				clean[key] = value
			end
		end
		data.Settings = clean
	end)
end

function DataService:WaitForProfile(player: Player, timeout: number)
	local started = os.clock()
	while not loaded[player] and player.Parent and os.clock() - started < timeout do
		task.wait(0.1)
	end
	return profiles[player]
end

function DataService:Get(player: Player)
	return profiles[player]
end

function DataService:Send(player: Player)
	local data = profiles[player]
	if not data then
		return
	end
	local level, into, needed = Progression.levelFromXp(data.Xp)
	Net.get("ProfileData"):FireClient(player, {
		marks = data.Marks,
		clearance = level,
		xpInto = into,
		xpNeeded = needed,
		runs = data.RunsPlayed,
		wins = data.Wins,
		settings = data.Settings,
		dossier = data.Dossier,
		saved = self.store ~= nil,
	})
end

-- result = { won, extracted, drift, survivedHunts, regionsOpened, puzzlesSolved, stalker }
-- (old profiles may hold "anomaly:" Dossier entries from the retired clue loop; they stay readable)
function DataService:GrantRunRewards(player: Player, result): number
	local data = profiles[player]
	if not data then
		return 0
	end
	local marks = Progression.marksForRun(result)
	data.Marks += marks
	data.Xp += marks
	data.RunsPlayed += 1
	if result.won then
		data.Wins += 1
	end
	if result.extracted then
		data.Extractions += 1
	end
	if result.stalker then
		data.Dossier["stalker:" .. result.stalker] = true
	end
	self:Send(player)
	task.spawn(self._save, self, player, false)
	return marks
end

return DataService
