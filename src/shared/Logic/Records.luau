-- The diner's run records (LB5; docs/plans/lobby-rework.md, "The diner"):
-- which runs count, which of the boards' lists a run goes on, and how an
-- entry reads. Services/RecordsService posts them (Services/BoardService
-- keeps them) and writes the two boards over the diner's back bar.
--
-- Two boards (the owner, 2026-10-15): the menu board is Normal, the specials
-- board Hard. Each holds four lists, top five each: the fastest solo, the
-- fastest squad, the longest solo, the longest squad. Solo is split from
-- squads because a solo house is smaller (Logic/HouseSize) and would top a
-- mixed fastest list. The short night only, to start.

local Records = {}

Records.Size = 5
Records.Difficulties = { "Normal", "Hard" }
Records.Night = "short"
-- The boards are this location's: a second location's runs need boards of
-- their own first (their keys have no location; docs/NEW-MAP.md).
Records.Location = "HalfwayHouse"

-- Each list: its key, its heading, whether lower is better, and who's on it.
Records.Lists = {
	{ id = "FastSolo", title = "FASTEST · SOLO", low = true, solo = true },
	{ id = "FastSquad", title = "FASTEST · SQUAD", low = true, solo = false },
	{ id = "LongSolo", title = "LONGEST · SOLO", low = false, solo = true },
	{ id = "LongSquad", title = "LONGEST · SQUAD", low = false, solo = false },
}

-- The saved board's name for a difficulty's list (Services/BoardService).
function Records.board(difficulty: string, list: string): string
	return "Records_" .. difficulty .. "_" .. list
end

-- Whether a finished run goes on the boards, and why not:
-- run = { won, extracted (how many got out), studio, debugged, location,
-- night, difficulty, seconds }. Only real runs count: never one from Studio, never
-- one an F2 command touched (or test runs would hold every record), only a
-- completed escape, only the short night.
function Records.counts(run): (boolean, string?)
	if run.studio then
		return false, "studio"
	elseif run.debugged then
		return false, "debug"
	elseif not run.won or (run.extracted or 0) < 1 then
		return false, "lost"
	elseif run.location ~= Records.Location then
		return false, "location"
	elseif run.night ~= Records.Night then
		return false, "night"
	elseif not table.find(Records.Difficulties, run.difficulty) then
		return false, "difficulty"
	elseif type(run.seconds) ~= "number" or run.seconds <= 0 then
		return false, "time"
	end
	return true, nil
end

-- The lists a counted run goes on: { board, low } for its fastest and its
-- longest (solo or squad by how many started it).
function Records.lists(run)
	local out = {}
	local solo = (run.size or 1) <= 1
	for _, list in Records.Lists do
		if list.solo == solo then
			table.insert(out, { board = Records.board(run.difficulty, list.id), low = list.low })
		end
	end
	return out
end

-- A run's entry: its time in tenths of a second (the value), the squad's
-- names as they started it and how many, and when.
function Records.entry(run)
	return {
		value = math.floor(run.seconds * 10 + 0.5),
		names = table.clone(run.names or {}),
		size = run.size or #(run.names or {}),
		at = run.at,
	}
end

-- A time as the board shows it: 12:04, or 1:02:09 past an hour.
function Records.clock(tenths: number): string
	local seconds = math.floor(tenths / 10)
	local h, m, s = math.floor(seconds / 3600), math.floor(seconds / 60) % 60, seconds % 60
	if h > 0 then
		return string.format("%d:%02d:%02d", h, m, s)
	end
	return string.format("%d:%02d", m, s)
end

-- One line of a list: "12:04  ALEX" solo, "18:41  x4  ALEX, SAM, JO, KAI"
-- for a squad; "--:--" for an empty place.
function Records.line(entry, solo: boolean): string
	if not entry then
		return "--:--"
	end
	local names = {}
	for _, name in entry.names or {} do
		table.insert(names, string.upper(tostring(name)))
	end
	if solo then
		return string.format("%s  %s", Records.clock(entry.value), names[1] or "?")
	end
	return string.format("%s  x%d  %s", Records.clock(entry.value), entry.size or #names, table.concat(names, ", "))
end

return Records
