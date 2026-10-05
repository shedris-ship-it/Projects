-- The escape's objective line (docs/plans/gameplay-rework.md section 7): one
-- short line on the HUD, made only from what the squad has seen, never from
-- the plan. Pure (tests/specs/Objectives.spec).
--
-- facts: {
--   served: the dinner is served (the run out)
--   places, placesLeft: places laid at the table, and how many are empty
--   keys: the keys someone holds, by token: { { mark, place?, two? } }; `place`
--     where its door is ("the Study") once someone has seen it
--   doors: the locked doors someone has tried and nobody has opened, oldest
--     first: { { mark?, kind, place } } (`place` the room it's seen from)
--   stations: the puzzles and locked cases someone has been near, in the
--     order they were first seen: { { kind, room, solved } }. The newest one
--     not yet dealt with is mentioned.
--   tidied: he put an heirloom back where it was kept (until it's found again)
-- }

local Marks = require(script.Parent.Parent.Data.Marks)

local Objectives = {}

-- What a station seen and not yet dealt with says, by kind. Each new puzzle
-- or lead adds its line here.
Objectives.Stations = {
	terminal = function(room: string)
		return "The computer in the " .. room .. " is still on."
	end,
	display = function(room: string)
		return "A glass case in the " .. room .. " is locked."
	end,
	breaker = function(room: string)
		return "There's a fuse box in the " .. room .. "."
	end,
	safe = function(room: string)
		return "There's a safe in the " .. room .. "."
	end,
	musicbox = function(room: string)
		return "The piano in the " .. room .. " is waiting for a tune."
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
}

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

function Objectives.line(facts): string
	if facts.served then
		return "The front door is open. Get out."
	end
	local parts = {}
	local left = facts.placesLeft or 0
	if left <= 0 then
		table.insert(parts, "The table is set.")
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
			table.insert(parts, say(station.room))
			break
		end
	end
	if facts.tidied then
		table.insert(parts, "Something has been put back where it belongs.")
	end
	return table.concat(parts, " ")
end

return Objectives
