-- The run state machine (doc section 2, as reworked in docs/plans/
-- gameplay-rework.md): Lobby -> Generating -> Arrival -> Investigation ->
-- Extraction -> Debrief -> Lobby. The run is an escape: the house is planned
-- into locked regions (Logic/LockPlanner), and Investigation lasts until the
-- table is set (Services/FinaleService). Then the final hunt starts and the
-- front door opens: Extraction, out of the house. Owns win/lose: at least
-- one Witness gets out, or Drift reaches 100, or every Witness is Lost. (The
-- old clue loop of anomalies, evidence and a verdict retired in R2c.)

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
local LevelGraph = require(Shared.Logic.LevelGraph)
local HouseSearch = require(Shared.Logic.HouseSearch)
local HouseSize = require(Shared.Logic.HouseSize)
local Leads = require(Shared.Logic.Leads)
local LockPlanner = require(Shared.Logic.LockPlanner)
local NavGraph = require(Shared.Logic.NavGraph)

local Phases = Constants.Phases
local RS = Constants.RunState
local PS = Constants.PlayerStates

local RunOrchestrator = {}

function RunOrchestrator:Init(services)
	self.services = services
	self.phase = Phases.Lobby
	self.run = nil
	self.nextSeed = nil
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
		huntsSurvivedStart = 0,
		-- The house follows the squad (docs/plans/level-design.md section 5.2);
		-- F2 `squad` stands in for a bigger squad in a solo test.
		squad = HouseSize.clamp(self.squadSize or #players, Config.Mansion.BySquad),
	}
	self:_setPhase(Phases.Generating)
	ReplicatedStorage.RunState:SetAttribute(RS.Seed, seed)
	ReplicatedStorage.RunState:SetAttribute(RS.Difficulty, difficultyName)
	ReplicatedStorage.RunState:SetAttribute(RS.SquadSize, #players)
	services.Telemetry:SetRun(seed)

	local ok, err = pcall(function()
		-- The old house or the mansion (docs/plans/mansion-generation.md); F2
		-- `layout` overrides Config.Level.Mode for testing.
		local layout, plan, found
		local mansion = (self.layoutMode or Config.Level.Mode) == "Mansion"
		if mansion then
			-- The mansion is sized for the squad and is the best of several
			-- (docs/plans/level-design.md, sections 5.2 and 5.5); the server
			-- breathes between candidates.
			local houseConfig, progression = HouseSize.config(
				Config.Mansion,
				Config.Progression,
				self.run.squad,
				difficultyName == "Hard" and 1 or 0
			)
			local began = os.clock()
			found = HouseSearch.run(seed, {
				templates = Rooms.Mansion,
				templatesById = Rooms.MansionById,
				mansion = houseConfig,
				progression = progression,
				extra = difficultyName == "Hard" and 1 or 0,
				leads = Config.Leads,
				nav = NavGraph.options(Config),
				targets = Config.LevelDesign.Targets,
				shortcut = Config.LevelDesign.ShortcutStuds,
				squad = self.run.squad,
				candidates = Config.LevelDesign.Candidates,
			}, function()
				task.wait()
			end)
			found.seconds = os.clock() - began
			layout, plan = found.layout, found.plan
			self.run.house = found
			print(
				string.format(
					"[Consensus] house %d of %d kept (score %.1f) in %.2fs",
					found.index,
					#found.scores,
					found.score,
					found.seconds
				)
			)
			services.Telemetry:Log("HouseChosen", {
				candidate = found.index,
				candidates = #found.scores,
				score = math.floor(found.score * 10 + 0.5) / 10,
				squad = self.run.squad,
				seconds = math.floor(found.seconds * 100 + 0.5) / 100,
			})
		else
			-- The old house never changes.
			layout = LevelGraph.generate(seed, Rooms.List, Config.Level)
			-- The locks, keys and heirlooms, planned before the house is built so
			-- every locked doorway gets a door (nested: the fingerprint holds).
			plan = LockPlanner.plan(
				layout,
				Rooms.ById,
				rng:Fork("progression"),
				Config.Progression,
				Config.Level,
				difficultyName == "Hard" and 1 or 0
			)
		end
		if layout.fallback then
			warn("[Consensus] seed " .. seed .. " fell back to the authored layout")
		end
		layout.progression = plan
		for _, seam in layout.seams do
			local lock = plan.locks[seam.id]
			if lock then
				-- A crank door is a shutter in an open doorway (Services/CrankService).
				seam.door = lock.kind ~= "crank"
			end
		end
		print(
			string.format(
				"[Consensus] escape: %d regions, %d locks, %d heirlooms",
				#plan.order,
				#LockPlanner.lockIds(plan),
				#plan.finale.heirlooms
			)
		)
		services.WorldService:Build(layout, rng:Fork("build"))
		services.NoiseService:Clear()
		services.SquadProfileService:Reset()
		services.PlayerStateService:BeginRun(players)
		services.ToolService:BeginRun(players, rng:Fork("tools"))
		services.DriftService:Begin(difficulty)
		-- The "anomaly" fork keeps its old name so the house is dressed the
		-- same per seed as it was before the clue loop retired.
		services.DecorService:Begin(rng:Fork("anomaly"))
		-- Toilets, taps, TVs, radios and every room's light switch.
		services.InteractService:Begin()
		-- Wind-up toys in the children's rooms (docs/plans/level-design.md 4).
		services.ToyService:Begin(rng:Fork("toys"))
		-- A landmark in every corridor, then the servants' bell board.
		services.LandmarkService:Begin(rng:Fork("landmarks"))
		services.BellBoardService:Begin(rng:Fork("bell board"))
		services.LockService:Begin(plan)
		-- The crowbar and the bolt cutters where the plan keeps them (L3.3).
		services.ToolService:PlacePlanned(plan, rng:Fork("planned tools"))
		services.CrankService:Begin(plan)
		-- How each key and heirloom is found (Logic/Leads): its own fork.
		local templates = mansion and Rooms.MansionById or Rooms.ById
		-- (The search planned the mansion's with its candidate's own fork.)
		local leads = found and found.leads
			or Leads.plan(plan, Leads.rooms(layout, templates), rng:Fork("leads"), Config.Leads)
		services.ItemService:Begin(plan, rng:Fork("items"), leads)
		-- The nursery's baby monitor (on its tops, after the leads take theirs).
		services.MonitorService:Begin(rng:Fork("monitor"))
		services.PuzzleService:Begin(plan, rng:Fork("puzzles"))
		-- The optional safe room's contents (docs/plans/level-design.md 11.12).
		services.SafeRoomService:Begin(plan, rng:Fork("safe room"), self.run.squad)
		services.FinaleService:Begin(plan)
		-- Last, so the wall and floor spots each Witness's own atmosphere uses
		-- are the ones nothing else took.
		services.DivergenceService:Begin(players, rng:Fork("atmosphere"))
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
		runStart = os.clock(),
	})
	self.run.started = os.clock()
	services.RunLogService:Begin()
	self:_setPhase(Phases.Arrival, Config.Run.ArrivalSeconds)
	Net.get("Notify"):FireAllClients("The front door locks behind you. The table is laid for a guest.", "phase")
	local plan = world.layout.progression
	services.Telemetry:Log("RunStarted", {
		players = #players,
		squad = self.run.squad,
		difficulty = difficultyName,
		location = location.id,
		rooms = #world.layout.rooms,
		attempts = world.layout.attempts,
		regions = plan and #plan.order or 0,
		heirlooms = plan and #plan.finale.heirlooms or 0,
	})
end

-- The escape's dinner is served (Services/FinaleService): the final hunt,
-- and the front door is open. Out.
function RunOrchestrator:BeginEscape()
	local run = self.run
	if not run or self.phase ~= Phases.Investigation and self.phase ~= Phases.Arrival then
		return
	end
	run.resolved = true
	self:_setPhase(Phases.Extraction, Config.Run.ExtractionSeconds)
	self.services.StalkerService:StartFinalHunt()
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

function RunOrchestrator:_tick(_dt: number)
	local run = self.run
	if not run or run.ending then
		return
	end
	-- The house search breathes between candidates (Logic/HouseSearch); the
	-- squad only joins the run once the house is built.
	if self.phase == Phases.Generating then
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
	local drift = services.DriftService:Value()
	services.DriftService:Stop()
	local tactics = services.StalkerService:TacticsSummary()
	-- What he did between hunts goes in the same list: peeks, creeping, ...
	for _, entry in services.StalkerService:StalkSummary() do
		table.insert(tactics, { tactic = entry.move, count = entry.count, description = entry.description })
	end
	table.sort(tactics, function(a, b)
		return a.count > b.count
	end)
	local stalkLines = services.StalkerService:ErrandLines()
	-- A hunt still on when the run ends (the final one, or the squad lost in
	-- one) ends with the run, for the numbers.
	services.RunLogService:Hunt(false, won and "escaped" or "lost")
	services.StalkerService:Stop()
	self:_setPhase(Phases.Debrief, Config.Run.DebriefSeconds)

	local dossier = services.SquadProfileService:Dossier({ tactics = tactics, stalkLines = stalkLines })
	local duration = os.clock() - run.started
	local summary = {
		won = won,
		reason = reason,
		resolved = run.resolved == true,
		drift = math.floor(drift),
		minutes = math.floor(duration / 60),
		seconds = math.floor(duration % 60),
		seed = run.seed,
		difficulty = run.difficultyName,
		stalker = run.location.stalker,
		escape = services.FinaleService:Progress(),
	}
	if summary.escape then
		-- Who did what (Services/RunLogService).
		summary.escape.lines = services.RunLogService:Lines()
	end
	-- The night in numbers (Logic/RunStats): the Dossier, the Output window
	-- and Telemetry, so a playtest can be read back afterwards.
	local stats = services.RunLogService:Summary()
	if stats then
		summary.stats = services.RunLogService:SummaryLines()
		print("[Consensus:summary] seed " .. tostring(run.seed))
		for _, line in summary.stats do
			print("[Consensus:summary]   " .. line)
		end
		local hunts = {}
		for _, h in stats.hunts do
			table.insert(hunts, { at = math.floor(h.at), reason = h.reason, how = h.how, catches = h.catches })
		end
		services.Telemetry:Log("RunSummary", {
			seconds = math.floor(stats.seconds),
			act = stats.act,
			tierScore = math.floor(stats.tierScore * 100) / 100,
			highTierShare = math.floor(stats.highTierShare * 100) / 100,
			silentMinutes = math.floor(stats.silentTotal / 6) / 10,
			silentLongest = math.floor(stats.silentLongest),
			scares = stats.scareTotal,
			hunts = hunts,
			falseAlarms = stats.falseAlarms,
			stareDowns = stats.stareDowns,
			freezes = stats.freezes,
			downs = stats.downs,
			catches = stats.catches,
			firstProgressAt = stats.firstProgressAt and math.floor(stats.firstProgressAt) or nil,
		})
	end
	for _, player in run.players do
		if player.Parent then
			local extracted = run.extracted[player] == true
			local rewards = services.RunLogService:Rewards(player)
			local marks = services.DataService:GrantRunRewards(player, {
				won = won,
				extracted = extracted,
				drift = drift,
				survivedHunts = rewards.survivedHunts,
				regionsOpened = rewards.regionsOpened,
				puzzlesSolved = rewards.puzzlesSolved,
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
		drift = summary.drift,
		duration = math.floor(duration),
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
	services.RunLogService:End()
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
			RS.Objective,
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
	services.StalkerService:SyncPlayer(player)
	services.MapService:SyncPlayer(player)
end

-- Debug hooks ------------------------------------------------------------------------

function RunOrchestrator:SetNextSeed(seed: number?)
	self.nextSeed = seed
end

-- "Cells" (the old house), "Mansion", or nil for Config.Level.Mode.
function RunOrchestrator:SetLayoutMode(mode: string?)
	self.layoutMode = mode
end

-- The squad size the next mansions are built for (1-4), or nil for the
-- number of players.
function RunOrchestrator:SetSquadSize(size: number?)
	self.squadSize = size
end

function RunOrchestrator:Run()
	return self.run
end

function RunOrchestrator:SkipToResolution()
	if self.run and (self.phase == Phases.Arrival or self.phase == Phases.Investigation) then
		self.services.FinaleService:Serve()
	end
end

function RunOrchestrator:SkipArrival()
	if self.run and self.phase == Phases.Arrival then
		self.run.phaseEnds = os.clock()
	end
end

return RunOrchestrator
