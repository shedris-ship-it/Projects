-- Fixed camera spots for the visual rework's before-and-after shots (F2
-- `look <name>`, Services/DebugService). Each house is keyed by its layout
-- and seed; `at` is where your feet go, `look` the point your view rests on.
-- The six moments are the ones docs/reference/it-wants-in/NOTES.md compares
-- with IT WANTS IN. `look save <name>` prints a new line to paste here.
-- (Spots go stale if the generator changes the house: retake them then.)

return {
	["Mansion:1800820264"] = {
		spawn = { at = { -4, 3, -10 }, look = { 0, 6, -40 } }, -- the grand hall and its stair
		lit = { at = { 28, 3, -4 }, look = { 44, 3.5, -18 } }, -- the dining room, the table laid
		dark = { at = { -24, 3, -40 }, look = { -80, 2.5, -40 } }, -- the main corridor, its lights off
		window = { at = { 72, 3, -11 }, look = { 74.6, 6, -0.6 } }, -- the kitchen window
		guest = { at = { 28, 3, -4 }, look = { 44, 3.5, -18 }, guest = 16 }, -- the first sight of him
	},
	["Cells:1800820264"] = {
		-- Gate A's old house.
		spawn = { at = { 0, 3, 0 }, look = { 0, 4, -20 } },
	},
}
