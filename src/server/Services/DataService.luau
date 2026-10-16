-- Player data (doc section 7: "a session-locked profile store"). A small
-- session lock on top of DataStoreService: a profile is only loaded when no
-- other live server holds it, and every save renews the lock. When DataStores
-- are unavailable (Studio without API access) profiles live in memory only.
-- Studio's play tests use stores of their own (StoreName), so a test never
-- touches a live profile. Before a teleport (Services/PlaceService) a
-- profile is handed off: saved, its lock released, and no longer saved
-- here, so the server the player lands on can lock it at once. The
-- profile's shape and upgrades are Logic/Profile.
--
-- Swap this for ProfileStore once the project uses Wally; the API here
-- (WaitForProfile, Get, GrantRunRewards) is all the rest of the game needs.

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Net = require(Shared.Net)
local Profile = require(Shared.Logic.Profile)
local Progression = require(Shared.Logic.Progression)
local Signal = require(Shared.Lib.Signal)
local Wardrobe = require(Shared.Data.Wardrobe)

local STORE_NAME = "ConsensusProfiles_v1"
local LOCK_SECONDS = 300
local AUTOSAVE_SECONDS = 90

local DataService = {}

-- (player, settings) after a player's settings are saved: OutfitService
-- dresses them again when their body changes.
DataService.SettingsSaved = Signal.new()

local profiles: { [Player]: any } = {}
local loaded: { [Player]: boolean } = {}
local handedOff: { [Player]: boolean } = {} -- saved and released for a teleport: not saved here again
local sessionId = HttpService:GenerateGUID(false)

-- The name every store the game opens goes by. Since the owner turned on
-- Studio's API access (2026-10-15), a play test would otherwise write the
-- live game's profiles, and a live server's lock would hold the owner's
-- (docs/plans/lobby-rework.md, LB0).
function DataService.StoreName(base: string): string
	return base .. (RunService:IsStudio() and Config.Data.StudioSuffix or "")
end

function DataService:Init()
	local name = DataService.StoreName(STORE_NAME)
	local ok, store = pcall(function()
		return DataStoreService:GetDataStore(name)
	end)
	self.store = ok and store or nil
	if not ok then
		warn("[Consensus] DataStores unavailable; progress won't be saved this session.")
	elseif RunService:IsStudio() then
		print("[Consensus] profiles: " .. name)
	end
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
					current.data = Profile.reconcile(current.data or {})
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
		data = Profile.new()
		self.memoryOnly = self.memoryOnly or not self.store
	end
	profiles[player] = data
	loaded[player] = true
	self:Send(player)
end

-- Whether the profile was written (false when another server holds its
-- lock, when it was handed off for a teleport, or when every try failed).
function DataService:_save(player: Player, release: boolean): boolean
	local data = profiles[player]
	if not data or not self.store or handedOff[player] then
		return false
	end
	local key = "player_" .. player.UserId
	-- Retry with exponential backoff; DataStore budgets throttle rather than
	-- fail outright, so a short wait usually gets the write through.
	for attempt = 1, 3 do
		local wrote = false
		local ok, err = pcall(function()
			self.store:UpdateAsync(key, function(current)
				current = current or {}
				if current.lock and current.lock.session ~= sessionId then
					wrote = false
					return nil
				end
				current.data = data
				current.lock = (not release) and { session = sessionId, time = os.time() } or nil
				wrote = true
				return current
			end)
		end)
		if ok then
			return wrote
		end
		warn(string.format("[Consensus] save for %s failed (attempt %d): %s", player.Name, attempt, tostring(err)))
		task.wait(2 ^ attempt)
	end
	return false
end

-- Saves now, keeping the lock; for a purchase that must be kept before
-- Roblox is told it's granted (Services/MonetizationService).
function DataService:SaveNow(player: Player): boolean
	return self:_save(player, false)
end

-- Before a teleport: saves the profile, releases its lock, and stops saving
-- it here, so the server the player lands on can lock it at once. Returns
-- whether the save went through (a teleport shouldn't go ahead without it).
function DataService:HandOff(player: Player): boolean
	if handedOff[player] then
		return true
	end
	if not self.store or not profiles[player] then
		-- Memory-only profiles have nothing to hand over.
		handedOff[player] = true
		return true
	end
	local ok = self:_save(player, true)
	if ok then
		handedOff[player] = true
	end
	return ok
end

-- A teleport that didn't happen: lock the profile here again.
function DataService:TakeBack(player: Player)
	if not handedOff[player] then
		return
	end
	handedOff[player] = nil
	if player.Parent then
		self:_load(player)
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
		handedOff[player] = nil
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
				"reduceGrain", -- (before the visual rework; carried over once by Logic/GraphicsPreset)
				"subtitles",
				"colorblind",
				"lowEnd", -- (likewise)
				"graphics",
				"grain",
				"lensFlares",
				"crouchToggle",
				"hideBody",
				"showMeters", -- (V7: the stamina and torch meters, for accessibility)
				"skipCutscenes", -- (V8)
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
		-- The body you chose (V6): one of the wardrobe's, by name.
		if type(settings.body) == "string" and Wardrobe.Bodies[settings.body] then
			clean.body = settings.body
		end
		data.Settings = clean
		self.SettingsSaved:Fire(player, clean)
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

-- result = { won, extracted, drift, survivedHunts, regionsOpened, puzzlesSolved,
-- valuables, valuableMarks, valuableXp, stalker } (old profiles may hold
-- "anomaly:" Dossier entries from the retired clue loop; they stay
-- readable). Returns the Marks paid and whether they were the day's double
-- (LB3: Marks and Clearance XP are separate sums, Config.Pay).
function DataService:GrantRunRewards(player: Player, result): (number, boolean)
	local data = profiles[player]
	if not data then
		return 0, false
	end
	local today = Progression.day(os.time())
	local marks, doubled = Progression.withDaily(Progression.marksForRun(result), result, data.DoubleDay, today)
	if doubled then
		data.DoubleDay = today
	end
	data.Marks = math.min(data.Marks + marks, 1e9)
	data.Xp = math.min(data.Xp + Progression.xpForRun(result), 1e9)
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
	return marks, doubled
end

return DataService
