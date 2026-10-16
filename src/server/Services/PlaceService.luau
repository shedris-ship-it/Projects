-- Where a run is played (docs/plans/lobby-rework.md, "One place, runs in
-- reserved servers"; the owner, 2026-10-15). A public server is a lobby: it
-- sends each squad to a reserved server of the same place, leaving the
-- run's contract in MemoryStore (teleport data passes through the client,
-- so it's never trusted for it). A reserved server is a run: it reads its
-- contract, waits for its squad, plays the run, and sends everyone back to
-- a lobby. Studio is both, as before (Logic/ServerRole); a Studio test can
-- ask for either role with ServerStorage's DebugRole attribute.

local MemoryStoreService = game:GetService("MemoryStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local TeleportService = game:GetService("TeleportService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Locations = require(Shared.Data.Locations)
local Homecoming = require(Shared.Logic.Homecoming)
local Net = require(Shared.Net)
local RunContract = require(Shared.Logic.RunContract)
local ServerRole = require(Shared.Logic.ServerRole)

-- Studio's run role has no reserved server to be keyed by.
local STUDIO_KEY = "studio"

local PlaceService = {}

function PlaceService:Init(services)
	self.services = services
	self.role = ServerRole.of({
		studio = RunService:IsStudio(),
		enabled = Config.Places.ReservedRuns,
		privateServerId = game.PrivateServerId,
		privateServerOwnerId = game.PrivateServerOwnerId,
		forced = ServerStorage:GetAttribute("DebugRole"),
	})
	print("[Consensus] server role: " .. self.role)
end

function PlaceService:Start()
	TeleportService.TeleportInitFailed:Connect(function(player, result, message)
		-- A teleport Roblox accepted and then couldn't do: the player stays.
		warn(string.format("[Consensus] teleport for %s failed: %s %s", player.Name, tostring(result), message))
		self.services.DataService:TakeBack(player)
		self:_tell({ player }, "The road was blocked. Try again in a moment.")
		-- (The car brings them back into the garage, still in their seats.)
		self.services.CarService:TeleportFailed(player)
	end)
	if self.role == ServerRole.Run then
		task.spawn(self._runServer, self)
	end
end

function PlaceService:Role(): string
	return self.role
end

-- Whether this server starts runs itself (a lobby sends squads off; a run
-- server starts only its own).
function PlaceService:StartsRunsHere(): boolean
	return ServerRole.startsRunsHere(self.role)
end

function PlaceService:IsLobby(): boolean
	return self.role == ServerRole.Lobby
end

function PlaceService:IsRun(): boolean
	return self.role == ServerRole.Run
end

function PlaceService:_tell(players: { Player }, text: string)
	for _, player in players do
		if player.Parent then
			Net.get("Notify"):FireClient(player, text, "info")
		end
	end
end

function PlaceService:_contracts()
	if not self.map then
		self.map = MemoryStoreService:GetHashMap(self.services.DataService.StoreName(Config.Places.ContractMap))
	end
	return self.map
end

local function userIds(players: { Player }): { number }
	local ids = {}
	for _, player in players do
		table.insert(ids, player.UserId)
	end
	return ids
end

-- Hands every profile off for a teleport; on any failure takes them all
-- back and says so.
function PlaceService:_handOff(players: { Player }): boolean
	local data = self.services.DataService
	for _, player in players do
		if not data:HandOff(player) then
			for _, other in players do
				data:TakeBack(other)
			end
			return false
		end
	end
	return true
end

function PlaceService:_teleport(players: { Player }, options: TeleportOptions?): boolean
	local tries = RunService:IsStudio() and 1 or Config.Places.TeleportTries
	for attempt = 1, tries do
		local ok, err = pcall(function()
			TeleportService:TeleportAsync(game.PlaceId, players, options)
		end)
		if ok then
			return true
		end
		warn(string.format("[Consensus] teleport (try %d) failed: %s", attempt, tostring(err)))
		if attempt < tries then
			task.wait(2 * attempt)
		end
	end
	return false
end

-- Lobby: sends a squad to a run of its own. settings = { difficulty,
-- location, night, lobby } (lobby: this server's JobId, to come back to).
-- Returns whether they're on their way; when not, they stay in the hub with
-- their profiles kept here.
function PlaceService:SendSquad(players: { Player }, settings): boolean
	local telemetry = self.services.Telemetry
	local reserved, code, serverId = pcall(TeleportService.ReserveServer, TeleportService, game.PlaceId)
	if not reserved then
		warn("[Consensus] couldn't reserve a server: " .. tostring(code))
		return false
	end
	local contract = RunContract.make(userIds(players), settings, os.time())
	local wrote, err = pcall(function()
		self:_contracts():SetAsync(serverId, contract, Config.Places.ContractSeconds)
	end)
	if not wrote then
		warn("[Consensus] couldn't leave the run's contract: " .. tostring(err))
		return false
	end
	if not self:_handOff(players) then
		warn("[Consensus] couldn't hand the squad's profiles over")
		return false
	end
	self:_tell(players, "Heading to the house...")
	local options = Instance.new("TeleportOptions")
	options.ReservedServerAccessCode = code
	if not self:_teleport(players, options) then
		for _, player in players do
			self.services.DataService:TakeBack(player)
		end
		return false
	end
	if telemetry then
		telemetry:Log("SquadSent", { squad = #players, difficulty = settings.difficulty, night = settings.night })
	end
	return true
end

-- Run: reads the contract, waits for the squad, starts the run.
function PlaceService:_runServer()
	local services = self.services
	local key = game.PrivateServerId
	if RunService:IsStudio() then
		-- Studio plays the lobby's part too: the first player in leaves a
		-- contract under Studio's key, as a lobby would.
		key = STUDIO_KEY
		local first = Players:GetPlayers()[1] or Players.PlayerAdded:Wait()
		local made = RunContract.make({ first.UserId }, {
			difficulty = "Normal",
			location = Locations.Default,
			night = services.RunOrchestrator:Night(),
		}, os.time())
		local ok, err = pcall(function()
			self:_contracts():SetAsync(key, made, Config.Places.ContractSeconds)
		end)
		print("[Consensus] Studio run role: contract left " .. (ok and "ok" or ("failed: " .. tostring(err))))
	end
	local known = { difficulty = {}, location = {} }
	for name in Config.Difficulty do
		known.difficulty[name] = true
	end
	for _, location in Locations.List do
		known.location[location.id] = true
	end
	local contract = nil
	for _ = 1, Config.Places.ContractReads do
		local ok, raw = pcall(function()
			return self:_contracts():GetAsync(key)
		end)
		contract = ok and RunContract.read(raw, known) or nil
		if contract then
			break
		end
		task.wait(1)
	end
	if not contract then
		-- No contract (expired, or MemoryStore down): play a run with the
		-- defaults for whoever is here, rather than strand them.
		warn("[Consensus] this run server has no contract; starting with the defaults")
		local here = Players:GetPlayers()
		if #here == 0 then
			here = { Players.PlayerAdded:Wait() }
		end
		contract = { squad = userIds(here) }
	end
	-- Wait for the squad: everyone, or whoever came in time.
	local deadline = os.clock() + Config.Places.SquadWaitSeconds
	while os.clock() < deadline do
		local present = userIds(Players:GetPlayers())
		if RunContract.arrived(contract, present) >= #contract.squad then
			break
		end
		task.wait(0.5)
	end
	local squad = {}
	for _, player in Players:GetPlayers() do
		if RunContract.expects(contract, player.UserId) then
			table.insert(squad, player)
		end
	end
	if #squad == 0 then
		squad = Players:GetPlayers()
	end
	pcall(function()
		self:_contracts():RemoveAsync(key)
	end)
	-- (Kept for the way back: the lobby they came from, the car's settings.)
	self.contract = contract
	print(string.format("[Consensus] run server: %d of %d of the squad here", #squad, #contract.squad))
	if contract.night then
		services.RunOrchestrator:SetNight(contract.night)
	end
	-- Each player's profile has to be in before the run hands out roles.
	for _, player in squad do
		services.DataService:WaitForProfile(player, 15)
	end
	services.RunOrchestrator:StartRun(squad, contract.difficulty or "Normal", contract.location or Locations.Default)
end

-- Run: after the run (RunOrchestrator), everyone goes back to a lobby once
-- the Dossier has had its time: the one they came from if it's still there
-- (any other if not), with their car's tape and settings and the run's
-- Marks for the receipt (Logic/Homecoming; Services/CarService seats them in
-- a car again). A teleport that fails leaves them here, and this server
-- becomes both, so they can play on. receipts: { [Player] = Marks }.
function PlaceService:ReturnSquad(players: { Player }, receipts)
	self:_tell(players, string.format("Back to the hub in %d seconds.", Config.Places.ReturnSeconds))
	task.delay(Config.Places.ReturnSeconds, function()
		local here = {}
		for _, player in players do
			if player.Parent then
				table.insert(here, player)
			end
		end
		if #here == 0 then
			return
		end
		local contract = self.contract or {}
		local byId = {}
		for player, marks in receipts or {} do
			byId[player.UserId] = marks
		end
		local data = Homecoming.make(game.JobId ~= "" and game.JobId or "studio", {
			tape = contract.location or Locations.Default,
			difficulty = contract.difficulty or "Normal",
			night = contract.night or self.services.RunOrchestrator:Night(),
		}, userIds(here), byId)
		if self:_handOff(here) then
			-- The lobby they came from first; any lobby if it's gone or full.
			if contract.lobby then
				local home = Instance.new("TeleportOptions")
				home.ServerInstanceId = contract.lobby
				home:SetTeleportData(data)
				if self:_teleport(here, home) then
					return
				end
			end
			local any = Instance.new("TeleportOptions")
			any:SetTeleportData(data)
			if self:_teleport(here, any) then
				return
			end
		end
		for _, player in here do
			self.services.DataService:TakeBack(player)
		end
		self.role = ServerRole.Both
		print("[Consensus] couldn't send the squad back; this server is a hub now")
		self:_tell(here, "Couldn't reach the hub. Your car's here: honk to play again.")
		self.services.CarService:Strand(here, contract, byId)
	end)
end

-- For F2 `role`.
function PlaceService:Describe(): string
	return string.format(
		"role %s · private server %s · owner %s · reserved runs %s",
		self.role,
		game.PrivateServerId ~= "" and game.PrivateServerId or "none",
		tostring(game.PrivateServerOwnerId),
		tostring(Config.Places.ReservedRuns)
	)
end

return PlaceService
