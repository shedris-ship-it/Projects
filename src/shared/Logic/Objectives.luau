-- The escape's objective line (docs/plans/gameplay-rework.md section 7): one
-- short line on the HUD, made only from what the squad has seen, never from
-- the plan. Pure (tests/specs/Objectives.spec).
--
-- facts: {
--   served: the dinner is served (the run out)
--   places, placesLeft: places laid at the table, and how many are empty
--   locked: the name of the room behind the last locked door someone tried
--     and couldn't open (nil once it's open)
--   stations: the puzzles and locked cases someone has been near, in the
--     order they were first seen: { { kind, room, solved } }. The newest one
--     not yet dealt with is mentioned.
--   tidied: he put an heirloom back where it was kept (until it's found again)
-- }

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
}

local NUMBERS = { "One", "Two", "Three", "Four", "Five" }

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
	if facts.locked then
		table.insert(parts, "The " .. facts.locked .. " door is locked.")
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
