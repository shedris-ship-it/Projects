-- The run state machine (doc section 2): Lobby -> Generating -> Arrival ->
-- Investigation -> (Verdict) -> Resolution -> Extraction -> Debrief -> Lobby.
-- Owns win/lose: the anomaly is resolved and at least one Witness extracts,
-- or Drift reaches 100, or every Witness is Lost.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Constants = require(Shared.Constants)
local Net = require(Shared.Net)
local Rng = require(Shared.Lib.Rng)
local Rooms = require(Shared.Data.Rooms)
local Locations = require(Shared.Data.Locations)
local Anomalies = require(Shared.Data.Anomalies)
local Tells = require(Shared.Data.Tells)
local LevelGraph = require(Shared.Logic.LevelGraph)

local Phases = Constants.Phases
local RS = Constants.RunState
local PS = Constants.PlayerStates

local RunOrchestrator = {}

function RunOrchestrator:Init(services)
	self.services = services
	self.phase = Phases.Lobby
	self.run = nil
	self.nextSeed = nil
	self.forcedAnomaly = nil
end

function RunOrchestrator:Phase(): string
	return self.phase
end

function RunOrchestrator:_setPhase(phase: string, duration: number?)
	self.phase = phase
	local runState = ReplicatedStorage.RunState
	runState:SetAttribute(RS.Phase, phase)
	runState:SetAttribute(RS.PhaseEndsAt, duration and (workspace:GetServerTimeNow() + duration) or nil)
	if self.run then
		self.run.phaseStarted = os.clock()
		self.run.phaseEnds = duration and (os.clock() + duration) or nil
	end
	self.services.LobbyService:Broadcast()
end

function RunOrchestrator:Start()
	local services = self.services
	self:_setPhase(Phases.Lobby)

	services.VerdictService.Decided:Connect(function(choice, correct)
		self:_onVerdict(choice, correct)
	end)
	services.AnomalyService.RitualCompleted:Connect(function()
		self:_onRitualComplete()
	end)
	services.DriftService.Collapsed:Connect(function()
		if self.run and not self.run.ending then
			Net.get("Notify"):FireAllClients("The house comes apart. Collapse.", "danger")
			self:EndRun(false, "Collapse")
		end
	end)
	services.PlayerStateService.Downed:Connect(function()
		services.DriftService:Apply("PlayerDowned")
	end)
	services.PlayerStateService.Extracted:Connect(function(player)
		self:_onExtracted(player)
	end)
	services.PlayerStateService.StateChanged:Connect(function()
		task.defer(function()
			self:_checkSquad()
		end)
	end)

	Net.onServer("RequestSync", { interval = 2, types = {} }, function(player)
		self:SyncPlayer(player)
	end)
	Net.onServer("RitualAction", { interval = 0.2, types = { "table?" } }, function(player, payload)
		if self.phase == Phases.Resolution then
			services.AnomalyService:HandleRitualAction(player, payload)
		end
	end)

	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function(character)
			self:_onCharacter(player, character)
		end)
	end)
	for _, player in Players:GetPlayers() do
		player.CharacterAdded:Connect(function(character)
			self:_onCharacter(player, character)
		end)
	end

	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt)
		accumulator += dt
		if accumulator >= 0.25 then
			local step = accumulator
			accumulator = 0
			local ok, err = pcall(self._tick, self, step)
			if not ok then
				warn("[Consensus] run tick failed: " .. tostring(err))
			end
		end
	end)
end

-- Respawned characters go back where they were.
function RunOrchestrator:_onCharacter(player: Player, character: Model)
	local run = self.run
	if not run or not table.find(run.players, player) then
		return
	end
	local state = self.services.PlayerStateService:State(player)
	if state == PS.Extracted then
		return
	end
	task.defer(function()
		local root = character:WaitForChild("HumanoidRootPart", 5)
		if root then
			self.services.PlayerStateService:MarkTeleport(player)
			local last = run.lastPositions[player]
			character:PivotTo(last and CFrame.new(last + Vector3.new(0, 3, 0)) or run.spawns[1])
		end
	end)
end

-- Run lifecycle ------------------------------------------------------------------

function RunOrchestrator:StartRun(players: { Player }, difficultyName: string, locationId: string)
	if self.phase ~= Phases.Lobby or #players == 0 then
		return
	end
	local services = self.services
	local difficulty = Config.Difficulty[difficultyName] or Config.Difficulty.Normal
	local location = Locations.ById[locationId] or Locations.ById[Locations.Default]
	local seed = self.nextSeed or Random.new():NextInteger(1, 2147483646)
	self.nextSeed = nil
	local rng = Rng.new(seed)

	self.run = {
		seed = seed,
		players = table.clone(players),
		difficulty = difficulty,
		difficultyName = difficultyName,
		location = location,
		rng = rng,
		started = os.clock(),
		lastPositions = {},
		extracted = {},
		wrongVerdicts = 0,
		huntsSurvivedStart = 0,
	}
	self:_setPhase(Phases.Generating)
	ReplicatedStorage.RunState:SetAttribute(RS.Seed, seed)
	ReplicatedStorage.RunState:SetAttribute(RS.Difficulty, difficultyName)
	ReplicatedStorage.RunState:SetAttribute(RS.SquadSize, #players)
	services.Telemetry:SetRun(seed)

	local ok, err = pcall(function()
		local layout = LevelGraph.generate(seed, Rooms.List, Config.Level)
		if layout.fallback then
			warn("[Consensus] seed " .. seed .. " fell back to the authored layout")
		end
		services.WorldService:Build(layout, rng:Fork("build"))
		services.NoiseService:Clear()
		services.SquadProfileService:Reset()
		services.CaseBoardService:Reset()
		services.VerdictService:Reset()
		services.PlayerStateService:BeginRun(players)
		services.WitnessService:ResetFocus(players)
		services.ToolService:BeginRun(players, rng:Fork("tools"))
		services.DriftService:Begin(difficulty)
		services.AnomalyService:Setup({
			players = players,
			rng = rng:Fork("anomaly"),
			locationId = location.id,
			forced = self.forcedAnomaly,
			difficulty = difficulty,
			squadSize = #players,
		})
		services.CaseBoardService:Broadcast()
	end)
	if not ok then
		warn("[Consensus] run setup failed: " .. tostring(err))
		Net.get("Notify"):FireAllClients("Something went wrong building the house. Back to the hub.", "danger")
		self:_returnToLobby()
		return
	end

	local world = services.WorldService.World
	self.run.spawns = world.spawns
	for i, player in players do
		local character = player.Character
		if character then
			services.PlayerStateService:MarkTeleport(player)
			character:PivotTo(world.spawns[((i - 1) % #world.spawns) + 1])
		end
	end
	services.CompanionService:Begin(players, world.spawns[1])
	services.StalkerService:Begin({
		archetype = location.stalker,
		rng = rng:Fork("stalker"),
		difficulty = difficulty,
		anomalyId = services.AnomalyService:Anomaly().id,
		runStart = os.clock(),
	})
	services.VerdictService:SetEnabled(true)
	self.run.started = os.clock()
	self:_setPhase(Phases.Arrival, Config.Run.ArrivalSeconds)
	Net.get("Notify")
		:FireAllClients(
			string.format("%s. Something here is wrong. Find it, agree on it, end it.", location.name),
			"phase"
		)
	services.Telemetry:Log("RunStarted", {
		players = #players,
		difficulty = difficultyName,
		anomaly = services.AnomalyService:Anomaly().id,
		rooms = #world.layout.rooms,
		attempts = world.layout.attempts,
	})
end

function RunOrchestrator:_onVerdict(choice: string, correct: boolean)
	local run = self.run
	if not run then
		return
	end
	local services = self.services
	local anomaly = Anomalies.ById[choice]
	services.Telemetry:Log("Verdict", { choice = choice, correct = correct, drift = services.DriftService:Value() })
	if correct then
		Net.get("Notify")
			:FireAllClients(string.format("Verdict: %s. The house shudders: you're right.", anomaly.name), "good")
		services.VerdictService:SetEnabled(false)
		self:_setPhase(Phases.Resolution)
		services.AnomalyService:StartRitual(services.PlayerStateService:RunPlayers(), run.rng:Fork("resolution"))
		services.StalkerService:StartFinalHunt()
	else
		run.wrongVerdicts += 1
		services.DriftService:Apply("WrongVerdict")
		Net.get("Notify"):FireAllClients(
			string.format(
				"Verdict: %s. Wrong. The house laughs, and something starts moving.",
				anomaly and anomaly.name or "?"
			),
			"danger"
		)
		services.StalkerService:ForceHunt("wrong verdict")
	end
end

function RunOrchestrator:_onRitualComplete()
	local run = self.run
	if not run or self.phase ~= Phases.Resolution then
		return
	end
	local services = self.services
	run.resolved = true
	services.StalkerService:EndFinalHunt()
	services.DriftService:Stop()
	local exit = services.WorldService.World.exit
	if exit then
		exit.door.CanCollide = false
		exit.door.Transparency = 0.85
		for _, detail in exit.door:GetChildren() do
			if detail:IsA("BasePart") then
				detail.Transparency = 0.85
			end
		end
		exit.light.Enabled = true
	end
	self:_setPhase(Phases.Extraction, Config.Run.ExtractionSeconds)
	Net.get("Notify"):FireAllClients(
		"It's done. Get out: the exit is open in the "
			.. (exit and services.WorldService:Room(exit.roomId).name or "house")
			.. ".",
		"good"
	)
end

function RunOrchestrator:_onExtracted(player: Player)
	local run = self.run
	if not run then
		return
	end
	run.extracted[player] = true
	local character = player.Character
	self.services.PlayerStateService:MarkTeleport(player)
	if character then
		character:PivotTo(self.services.LobbyService:SpawnCFrame(1))
	end
	self:_checkSquad()
end

-- End the run when nobody is left in the house.
function RunOrchestrator:_checkSquad()
	local run = self.run
	if not run or run.ending then
		return
	end
	if self.phase == Phases.Generating or self.phase == Phases.Lobby then
		return
	end
	local services = self.services
	local living = services.PlayerStateService:LivingPlayers()
	local extracted = 0
	for player in run.extracted do
		if player.Parent then
			extracted += 1
		end
	end
	if #living == 0 then
		if extracted > 0 then
			self:EndRun(true, "Extracted")
		else
			self:EndRun(false, #services.PlayerStateService:RunPlayers() == 0 and "Abandoned" or "AllLost")
		end
	elseif self.phase == Phases.Extraction then
		-- Everyone still standing has either left or is down: finish when the
		-- active ones are out.
		local active = services.PlayerStateService:ActivePlayers()
		if #active == 0 and extracted > 0 then
			self:EndRun(true, "Extracted")
		end
	end
end

function RunOrchestrator:_tick(dt: number)
	local run = self.run
	if not run or run.ending then
		return
	end
	local services = self.services
	local now = os.clock()
	ReplicatedStorage.RunState:SetAttribute(RS.RunTime, math.floor(now - run.started))

	for _, player in services.PlayerStateService:LivingPlayers() do
		local pos = services.PlayerStateService:Position(player)
		if pos and services.WorldService:RoomAt(pos) then
			run.lastPositions[player] = pos
		end
	end

	if self.phase == Phases.Arrival and run.phaseEnds and now >= run.phaseEnds then
		self:_setPhase(Phases.Investigation)
		Net.get("Notify"):FireAllClients("The house has noticed you.", "phase")
	elseif self.phase == Phases.Resolution then
		services.AnomalyService:UpdateRitual(dt)
	elseif self.phase == Phases.Extraction then
		local exit = services.WorldService.World.exit
		for _, player in services.PlayerStateService:ActivePlayers() do
			local pos = services.PlayerStateService:Position(player)
			if exit and pos and (pos - exit.zone.Position).Magnitude < 7 then
				services.PlayerStateService:Extract(player)
			end
		end
		if run.phaseEnds and now >= run.phaseEnds then
			for _, player in services.PlayerStateService:LivingPlayers() do
				services.PlayerStateService:MakeLost(player, "left behind")
			end
			self:_checkSquad()
		end
	end
	if #services.PlayerStateService:RunPlayers() == 0 then
		self:EndRun(false, "Abandoned")
	end
end

function RunOrchestrator:EndRun(won: boolean, reason: string)
	local run = self.run
	if not run or run.ending then
		return
	end
	run.ending = true
	local services = self.services
	local anomaly = services.AnomalyService:Anomaly()
	local drift = services.DriftService:Value()
	services.DriftService:Stop()
	services.VerdictService:SetEnabled(false)
	local tactics = services.StalkerService:TacticsSummary()
	-- What he did between hunts goes in the same list: peeks, creeping, ...
	for _, entry in services.StalkerService:StalkSummary() do
		table.insert(tactics, { tactic = entry.move, count = entry.count, description = entry.description })
	end
	table.sort(tactics, function(a, b)
		return a.count > b.count
	end)
	services.StalkerService:Stop()
	services.AnomalyService:StopRitual()
	self:_setPhase(Phases.Debrief, Config.Run.DebriefSeconds)

	local evidence = {}
	for _, site in services.AnomalyService:Sites() do
		table.insert(evidence, {
			name = Tells[site.tellId].name,
			room = site.roomName,
			herring = site.isRedHerring,
		})
	end
	local dossier = services.SquadProfileService:Dossier({ tactics = tactics })
	local duration = os.clock() - run.started
	local confirmed = #services.CaseBoardService:ConfirmedTells()
	local summary = {
		won = won,
		reason = reason,
		anomaly = anomaly and anomaly.name or "?",
		anomalyId = anomaly and anomaly.id,
		resolved = run.resolved == true,
		drift = math.floor(drift),
		minutes = math.floor(duration / 60),
		seconds = math.floor(duration % 60),
		seed = run.seed,
		difficulty = run.difficultyName,
		evidence = evidence,
		wrongVerdicts = run.wrongVerdicts,
		stalker = run.location.stalker,
	}
	for _, player in run.players do
		if player.Parent then
			local extracted = run.extracted[player] == true
			local marks = services.DataService:GrantRunRewards(player, {
				won = won,
				extracted = extracted,
				drift = drift,
				confirmedTells = confirmed,
				survivedHunts = 0,
				anomalyId = (run.resolved and anomaly) and anomaly.id or nil,
				stalker = run.location.stalker,
			})
			Net.get("Dossier"):FireClient(player, {
				summary = summary,
				dossier = dossier,
				marks = marks,
				extracted = extracted,
			})
		end
	end
	services.Telemetry:Log("RunEnded", {
		won = won,
		reason = reason,
		anomaly = summary.anomalyId,
		drift = summary.drift,
		duration = math.floor(duration),
		wrongVerdicts = run.wrongVerdicts,
		confirmed = confirmed,
	})
	task.delay(3, function()
		self:_returnToLobby()
	end)
end

function RunOrchestrator:_returnToLobby()
	local services = self.services
	local players = self.run and self.run.players or {}
	services.StalkerService:Stop()
	services.CompanionService:Stop()
	services.ToolService:EndRun()
	for _, player in players do
		if player.Parent then
			services.HidingService:ForceLeave(player)
		end
	end
	services.PlayerStateService:EndRun()
	services.WorldService:Clear()
	services.DivergenceService:Reset()
	self.run = nil
	local runState = ReplicatedStorage.RunState
	for _, key in
		{
			RS.Drift,
			RS.DriftState,
			RS.Tier,
			RS.StalkerMode,
			RS.Hunting,
			RS.RunTime,
			RS.RitualProgress,
			RS.RitualText,
			RS.ConfirmedCount,
		}
	do
		runState:SetAttribute(key, nil)
	end
	local alive = {}
	for _, player in players do
		if player.Parent then
			table.insert(alive, player)
		end
	end
	services.LobbyService:Return(alive)
	self:_setPhase(Phases.Lobby)
end

-- Bring a (re)loading client up to date.
function RunOrchestrator:SyncPlayer(player: Player)
	local services = self.services
	services.LobbyService:Broadcast()
	services.DataService:Send(player)
	if not self.run then
		return
	end
	services.WorldService:BroadcastLayout(player)
	services.DivergenceService:SendProfile(player)
	services.CaseBoardService:Broadcast(player)
	services.VerdictService:SyncPlayer(player)
	services.StalkerService:SyncPlayer(player)
	services.AnomalyService:SyncPlayer(player)
end

-- Debug hooks ------------------------------------------------------------------------

function RunOrchestrator:SetNextSeed(seed: number?)
	self.nextSeed = seed
end

function RunOrchestrator:SetForcedAnomaly(id: string?)
	self.forcedAnomaly = id
end

function RunOrchestrator:Run()
	return self.run
end

function RunOrchestrator:SkipToResolution()
	if self.run and (self.phase == Phases.Arrival or self.phase == Phases.Investigation) then
		self:_onVerdict(self.services.AnomalyService:Anomaly().id, true)
	end
end

function RunOrchestrator:SkipArrival()
	if self.run and self.phase == Phases.Arrival then
		self.run.phaseEnds = os.clock()
	end
end

return RunOrchestrator
