-- The escape's objective line (docs/plans/gameplay-rework.md section 7): one
-- short line on the HUD, made only from what the squad has seen, never from
-- the plan. Pure (tests/specs/Objectives.spec).
--
-- facts: {
--   served: the dinner is served (the run out)
--   places, placesLeft: places laid at the table, and how many are empty
--   wanting: once someone has seen the table, what its empty places' cards
--     ask for ({ "Mom's locket", ... }): the line names them
--   keys: the keys someone holds, by token: { { mark, place?, two? } }; `place`
--     where its door is ("the Study") once someone has seen it
--   doors: the locked doors someone has tried and nobody has opened, oldest
--     first: { { mark?, kind, place } } (`place` the room it's seen from)
--   tools: the tools for tool locks someone carries: { { name, kind, place?,
--          thing? (a step's chest, not a door: "chest") } }
--     (`kind` the lock it works, `place` its next door someone has seen)
--   stations: the puzzles and locked cases someone has been near, in the
--     order they were first seen: { { kind, room, solved, optional?,
--     heard? } }. The newest one not yet dealt with is mentioned (an
--     optional one, the safe room's fuse box, says so). `heard`: the piano's
--     music box has played for someone.
--   tidied: he put an heirloom back where it was kept (until it's found again)
--   hint: stuck-assist's sentence (Logic/Assist), once the squad has stalled
-- }

local Marks = require(script.Parent.Parent.Data.Marks)

local Objectives = {}

-- What a station seen and not yet dealt with says, by kind (with the
-- station's entry, for lines that change as it's learned). Each new puzzle
-- or lead adds its line here.
Objectives.Stations = {
	terminal = function(room: string)
		return "The computer in the " .. room .. " is still on."
	end,
	display = function(room: string)
		return "A glass case in the " .. room .. " is locked."
	end,
	breaker = function(room: string)
		-- (Config.Breaker.PlateAtDoor: the panel shows numbers, the labels
		-- hang by the door it powers.)
		return "There's a fuse box in the " .. room .. ". Its labels are on a plate by the door it powers."
	end,
	safe = function(room: string)
		return "There's a safe in the " .. room .. "."
	end,
	-- The squad playtest (2026-10-08): nobody knew the piano was a puzzle, or
	-- what it wanted. It says so, and points at the box until it's heard.
	musicbox = function(room: string, station)
		if station and station.heard then
			return "Play the music box's tune on the piano in the "
				.. room
				.. ". Its keys wear the colours of the comb's teeth."
		end
		return "The piano in the " .. room .. " is shut on something. It wants the music box's tune."
	end,
	-- The box itself, seen before anyone has heard it.
	tunebox = function(room: string)
		return "There's a music box in the " .. room .. ". Wind it and watch its comb."
	end,
	crank = function(room: string)
		return "A shutter in the " .. room .. " won't stay up on its own."
	end,
	dumbwaiter = function(room: string)
		return "Something sits in the dumbwaiter in the " .. room .. "."
	end,
}

local NUMBERS = { "One", "Two", "Three", "Four", "Five" }

-- What a locked door tried says, by its lock (docs/plans/level-design.md
-- section 11: named by its mark and the room it's seen from, never the room
-- behind it).
local DOORS = {
	key = "is locked.",
	double = "is locked. It needs two keys.",
	padlock = "has a padlock.",
	power = "has no power.",
	pocket = "is locked.",
	boards = "is boarded up.",
	chain = "is chained shut.",
	-- The safe room's (docs/plans/level-design.md section 11.12): optional.
	vault = "is a steel safe-room door with no power. The fuse box, maybe.",
}

-- What a tool does to its door (Logic/ToolLocks).
local TOOL_VERBS = { boards = "pry the boards off", chain = "cut the chain on" }

-- One sentence about keys and locks: a key someone holds whose door has
-- been seen comes first (that's what to do next), then one whose door
-- nobody has found, then the newest locked door tried.
function Objectives.lockLine(facts): string?
	local keys = facts.keys or {}
	for i = #keys, 1, -1 do
		local key = keys[i]
		if key.place then
			return "The "
				.. key.mark
				.. " key fits the door in "
				.. key.place
				.. "."
				.. (key.two and " It needs two keys." or "")
		end
	end
	-- A tool someone carries, and a seen door (or chest) it works.
	local tools = facts.tools or {}
	for i = #tools, 1, -1 do
		local tool = tools[i]
		if tool.place then
			return "The "
				.. tool.name
				.. " could "
				.. (TOOL_VERBS[tool.kind] or "open")
				.. " the "
				.. (tool.thing or "door")
				.. " in "
				.. tool.place
				.. "."
		end
	end
	if #keys > 0 then
		return "Somewhere there's a door with " .. Marks.said(keys[#keys].mark) .. " on it."
	end
	local doors = facts.doors or {}
	local door = doors[#doors]
	if door then
		local name = door.mark and ("The " .. door.mark .. " door") or "The door"
		return name .. " in " .. door.place .. " " .. (DOORS[door.kind] or "is locked.")
	end
	return nil
end

-- "a", "a and b", "a, b and c".
function Objectives.list(items: { string }): string
	if #items <= 1 then
		return items[1] or ""
	end
	return table.concat(items, ", ", 1, #items - 1) .. " and " .. items[#items]
end

function Objectives.line(facts): string
	if facts.served then
		return "The front door is open. Get out."
	end
	local parts = {}
	local left = facts.placesLeft or 0
	local wanting = facts.wanting
	if left <= 0 then
		table.insert(parts, "The table is set.")
	elseif wanting and #wanting > 0 then
		-- The cards at the empty places say what each wants (the squad
		-- playtest, 2026-10-10: "you at least know what you're looking for").
		table.insert(parts, "The table still wants " .. Objectives.list(wanting) .. ".")
	elseif left == facts.places then
		table.insert(
			parts,
			"The table is laid for a guest, with " .. string.lower(NUMBERS[left] or tostring(left)) .. " empty places."
		)
	elseif left == 1 then
		table.insert(parts, "One place at the table is still empty.")
	else
		table.insert(parts, (NUMBERS[left] or tostring(left)) .. " places at the table are still empty.")
	end
	local locks = Objectives.lockLine(facts)
	if locks then
		table.insert(parts, locks)
	end
	local stations = facts.stations or {}
	for i = #stations, 1, -1 do
		local station = stations[i]
		local say = Objectives.Stations[station.kind]
		if not station.solved and say then
			table.insert(
				parts,
				say(station.room, station) .. (station.optional and " One of its breakers is for a safe room." or "")
			)
			break
		end
	end
	if facts.tidied then
		table.insert(parts, "Something has been put back where it belongs.")
	end
	if facts.hint then
		table.insert(parts, facts.hint)
	end
	return table.concat(parts, " ")
end

return Objectives
