-- The run's journal (R2c): who opened which door and solved which puzzle,
-- who carried each heirloom and who set it at the table, when each act
-- began, the hunts, how often he put things back, and the closest he came to
-- someone carrying an heirloom. It writes the Dossier's "THE HOUSE" lines,
-- counts what the Marks pay for (Logic/Progression), and logs each step for
-- tuning (Services/Telemetry, doc section 12).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Constants = require(Shared.Constants)
local RunStats = require(Shared.Logic.RunStats)

local States = Constants.PlayerStates

local SAMPLE_SECONDS = 0.5 -- how often the closest call is measured
local CLOSE_CALL = 25 -- studs: nearer than this while carrying is worth telling

-- How the debrief names a lock or a puzzle.
local LOCKS = {
	key = "unlocked %s",
	padlock = "opened the padlock on %s",
	power = "powered the door to %s",
	bolt = "slid the bolt on %s",
	crank = "cranked up the door to %s",
}
local PUZZLES = {
	terminal = "the home computer",
	padlock = "a padlock",
	breaker = "the breaker panel",
	safe = "the safe",
	musicbox = "the music box",
	dumbwaiter = "the dumbwaiter",
}

local RunLogService = {}

function RunLogService:Init(services)
	self.services = services
	self.Telemetry = services.Telemetry
	self.log = nil
end

function RunLogService:Start()
	local services = self.services
	services.LockService.Unlocked:Connect(function(seamId, lock, player)
		self:_unlocked(seamId, lock, player)
	end)
	services.LockService.RegionEntered:Connect(function(region, player, rooms)
		local log = self.log
		if log then
			log.regions += 1
			local count = 0
			for _ in rooms or {} do
				count += 1
			end
			self.Telemetry:Log("RegionEntered", { at = self:_seconds(), rooms = count }, player)
			self:_progress("region", tostring(region))
		end
	end)
	services.PuzzleService.Solved:Connect(function(id, player)
		self:_solved(id, player)
	end)
	services.ItemService.HeirloomTaken:Connect(function(player, token)
		self:_taken(player, token)
	end)
	services.ItemService.Found:Connect(function(_player, token, kind)
		self:_progress("found", kind or token)
	end)
	services.PlayerStateService.Downed:Connect(function(player)
		if self.stats then
			self.stats:Down(os.clock(), player.DisplayName)
		end
	end)
	services.ItemService.Tidied:Connect(function(_token, label)
		if self.log then
			self.log.tidied += 1
			self.Telemetry:Log("Tidied", { at = self:_seconds(), heirloom = label })
		end
	end)
	services.ItemService.NoteRead:Connect(function(player, note)
		if self.log then
			self.Telemetry:Log("LeadRead", { at = self:_seconds(), token = note and note.token or nil }, player)
		end
	end)
	services.ItemService.CaseOpened:Connect(function(player, _case, how)
		if self.log then
			self.Telemetry:Log(how == "smashed" and "Smashed" or "CasePicked", { at = self:_seconds() }, player)
		end
	end)
	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed >= SAMPLE_SECONDS then
			elapsed = 0
			self:_sample()
		end
	end)
end

-- A new run: an empty journal.
function RunLogService:Begin()
	self.log = {
		started = os.clock(),
		opened = {}, -- { at, name, kind, room }
		regions = 0,
		solved = {}, -- { at, name, kind }
		carriers = {}, -- token -> { names in order }, carriedBy[token][name] = true
		carriedBy = {},
		set = {}, -- token -> name
		tidied = 0,
		hunts = 0,
		survived = {}, -- player -> hunts survived
		acts = {}, -- { act, at }
		closest = nil, -- { name, distance, label }
	}
	-- The run in numbers (Logic/RunStats): the overlay and the summary.
	self.stats = RunStats.new(os.clock(), Config.Stats)
end

function RunLogService:End()
	self.log = nil
	self.stats = nil
end

-- The numbers (Logic/RunStats) ----------------------------------------------------

function RunLogService:_progress(kind: string, detail: string?)
	if self.stats then
		self.stats:Progress(os.clock(), kind, detail)
	end
end

-- Something happened for the squad (a scare, a tell, a sighting...): the
-- quiet is broken.
function RunLogService:Beat(kind: string, detail: string?)
	if self.stats then
		self.stats:Beat(os.clock(), kind, detail)
	end
end

function RunLogService:Scare(id: string)
	if self.stats then
		self.stats:Scare(os.clock(), id)
	end
end

function RunLogService:Sighting(who: string?)
	if self.stats then
		self.stats:Sighting(os.clock(), who)
	end
end

function RunLogService:Arrived()
	if self.stats then
		self.stats:Arrived(os.clock())
	end
end

function RunLogService:FalseAlarm()
	if self.stats then
		self.stats:FalseAlarm(os.clock())
	end
end

function RunLogService:StareDown(inHunt: boolean)
	if self.stats then
		self.stats:StareDown(os.clock(), inHunt)
	end
end

function RunLogService:Catch(who: string?, how: string?)
	if self.stats then
		self.stats:Catch(os.clock(), who, how)
	end
end

-- The finish line's moments (Logic/RunStats.finishLine).
function RunLogService:Served()
	if self.stats then
		self.stats:Served(os.clock())
	end
end

function RunLogService:Extracted()
	if self.stats then
		self.stats:Extracted(os.clock())
	end
end

function RunLogService:TorchDead()
	if self.stats then
		self.stats:TorchDead(os.clock())
	end
end

function RunLogService:Hint()
	if self.stats then
		self.stats:Hint(os.clock())
	end
end

function RunLogService:F2(command: string?)
	if self.stats then
		self.stats:F2(os.clock(), command)
	end
end

function RunLogService:Summary()
	return self.stats and self.stats:Summary(os.clock()) or nil
end

-- For the F2 overlay (Services/DebugService).
function RunLogService:OverlayLines(): { string }
	local summary = self:Summary()
	return summary and RunStats.overlay(summary) or {}
end

-- For the Dossier, the Output window and F2 `summary`.
function RunLogService:SummaryLines(): { string }
	local summary = self:Summary()
	return summary and RunStats.lines(summary) or {}
end

function RunLogService:_seconds(): number
	return self.log and math.floor(os.clock() - self.log.started) or 0
end

local function clock(seconds: number): string
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

function RunLogService:_roomName(id: number?): string
	local room = id and self.services.WorldService:Room(id)
	return room and room.name and string.lower(room.name) or "a room"
end

function RunLogService:_unlocked(_seamId: string, lock, player: Player?)
	local log = self.log
	if not log or not player then
		return -- the dinner's unlock-all, or F2
	end
	local kind = lock and lock.kind or "key"
	table.insert(log.opened, {
		at = self:_seconds(),
		name = player.DisplayName,
		kind = kind,
		room = self:_roomName(lock and lock.inside),
	})
	self.Telemetry:Log("LockOpened", { at = self:_seconds(), kind = kind }, player)
	self:_progress("lock", kind)
end

function RunLogService:_solved(id: string, player: Player?)
	local log = self.log
	if not log then
		return
	end
	local session = self.services.PuzzleService.sessions[id]
	local kind = session and session.kind or "?"
	table.insert(log.solved, { at = self:_seconds(), name = player and player.DisplayName or "someone", kind = kind })
	self.Telemetry:Log("PuzzleSolved", { at = self:_seconds(), kind = kind }, player)
	self:_progress("puzzle", kind)
end

function RunLogService:_taken(player: Player, token: string)
	local log = self.log
	if not log then
		return
	end
	log.carriers[token] = log.carriers[token] or {}
	log.carriedBy[token] = log.carriedBy[token] or {}
	if not log.carriedBy[token][player.DisplayName] then
		log.carriedBy[token][player.DisplayName] = true
		table.insert(log.carriers[token], player.DisplayName)
		if #log.carriers[token] == 1 then
			self.Telemetry:Log("HeirloomTaken", { at = self:_seconds(), token = token }, player)
		end
	end
end

-- Laid at the table (Services/FinaleService).
function RunLogService:Set(token: string, player: Player)
	local log = self.log
	if log then
		log.set[token] = player.DisplayName
		self.Telemetry:Log("HeirloomSet", { at = self:_seconds(), token = token }, player)
		self:_progress("place", token)
	end
end

-- A new act (Stalker/Director).
function RunLogService:Act(act: number)
	local log = self.log
	if log then
		table.insert(log.acts, { act = act, at = self:_seconds() })
		self.Telemetry:Log("ActBegan", { act = act, at = self:_seconds() })
		if self.stats then
			self.stats:Act(os.clock(), act)
		end
	end
end

-- A hunt began (`reason`: what woke it) or ended (`how`: "survived", "stared
-- down", "escaped", "lost"; Stalker/Director). Everyone not lost by its end
-- survived it.
function RunLogService:Hunt(began: boolean, why: string?)
	local log = self.log
	if not log then
		return
	end
	if began then
		log.hunts += 1
		log.huntOpen = true
		if self.stats then
			self.stats:HuntBegan(os.clock(), why)
		end
		return
	end
	if not log.huntOpen then
		return -- nothing to end (the run ending between hunts)
	end
	log.huntOpen = false
	if self.stats then
		self.stats:HuntEnded(os.clock(), why)
	end
	local playerState = self.services.PlayerStateService
	for _, player in playerState:RunPlayers() do
		if playerState:State(player) ~= States.Lost then
			log.survived[player] = (log.survived[player] or 0) + 1
		end
	end
end

-- The closest call while carrying an heirloom: how near he came (walking).
function RunLogService:_sample()
	local log = self.log
	local services = self.services
	if not log or not services.StalkerService.active then
		return
	end
	if self.stats then
		local stalker = services.StalkerService
		self.stats:Tick(os.clock(), stalker:TierNow(), stalker:IsFrozen())
	end
	local guest = services.StalkerService:GetPosition()
	if not guest then
		return
	end
	for _, entry in services.ItemService:Heirlooms() do
		local holder = entry.holder
		local at = holder and services.PlayerStateService:Position(holder)
		if at and services.WorldService:RoomAt(guest) then
			local distance = services.WorldService:Separation(at, guest)
			if distance < CLOSE_CALL and (not log.closest or distance < log.closest.distance) then
				log.closest = {
					name = holder.DisplayName,
					distance = math.floor(distance * 10) / 10,
					label = string.lower(services.ItemService:Label(entry.token)),
				}
			end
		end
	end
end

-- What the Marks pay for, for one player (Logic/Progression.marksForRun).
function RunLogService:Rewards(player: Player)
	local log = self.log
	if not log then
		return { regionsOpened = 0, puzzlesSolved = 0, survivedHunts = 0 }
	end
	return {
		regionsOpened = log.regions,
		puzzlesSolved = #log.solved,
		survivedHunts = log.survived[player] or 0,
	}
end

-- The Dossier's lines about the house.
function RunLogService:Lines(): { string }
	local log = self.log
	if not log then
		return {}
	end
	local items = self.services.ItemService
	local lines = {}
	for _, entry in log.opened do
		local verb = LOCKS[entry.kind] or "opened %s"
		table.insert(
			lines,
			string.format("%s  %s %s", clock(entry.at), entry.name, string.format(verb, "the " .. entry.room))
		)
	end
	for _, entry in log.solved do
		table.insert(
			lines,
			string.format("%s  %s solved %s", clock(entry.at), entry.name, PUZZLES[entry.kind] or "a puzzle")
		)
	end
	table.sort(lines)
	for token, names in log.carriers do
		local line = string.format("The %s, carried by %s", string.lower(items:Label(token)), table.concat(names, ", "))
		if log.set[token] then
			line ..= "; set at the table by " .. log.set[token]
		end
		table.insert(lines, line)
	end
	if log.tidied > 0 then
		table.insert(
			lines,
			string.format(
				"He put things back where they belong %s.",
				log.tidied == 1 and "once" or log.tidied .. " times"
			)
		)
	end
	if #log.acts > 0 then
		local acts = {}
		for _, entry in log.acts do
			table.insert(
				acts,
				string.format("%s at %s", entry.act == 4 and "the dinner" or "act " .. entry.act, clock(entry.at))
			)
		end
		table.insert(lines, "The house turned: " .. table.concat(acts, ", ") .. ".")
	end
	if log.hunts > 0 then
		table.insert(lines, string.format("Hunted %d time%s.", log.hunts, log.hunts == 1 and "" or "s"))
	end
	if log.closest then
		table.insert(
			lines,
			string.format(
				"Closest call carrying: %s, %.1f studs from him with the %s.",
				log.closest.name,
				log.closest.distance,
				log.closest.label
			)
		)
	end
	return lines
end

return RunLogService
