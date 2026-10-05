-- The escape's objective line (docs/plans/gameplay-rework.md section 7): one
-- short line on the HUD, made only from what the squad has seen, never from
-- the plan. Pure (tests/specs/Objectives.spec).
--
-- facts: {
--   served: the dinner is served (the run out)
--   places, placesLeft: places laid at the table, and how many are empty
--   locked: the name of the room behind the last locked door someone tried
--     and couldn't open (nil once it's open)
--   computer: the name of the room with the home computer, once someone has
--     been near it; computerSolved once it's cracked
-- }

local Objectives = {}

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
	if facts.computer and not facts.computerSolved then
		table.insert(parts, "The computer in the " .. facts.computer .. " is still on.")
	end
	return table.concat(parts, " ")
end

return Objectives
