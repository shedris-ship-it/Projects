-- What each Witness's own copy of the house may show them that nobody else
-- sees (Logic/Atmosphere; owner, 2026-10-04: divergence stays, as atmosphere
-- only, never as something to solve).

return {
	-- Words on a wall that show only in your own torch beam.
	Writing = {
		"IT COUNTS YOU",
		"NOT ALL OF YOU CAME IN",
		"DON'T LOOK AWAY",
		"WE AGREED",
		"SET A PLACE FOR HIM",
		"HE LIKES THE DINING ROOM",
		"DON'T LET HIM IN",
		"YOU WERE NEVER FOUR",
	},
	-- Sounds from somewhere they can't have come from (PerceptionController's
	-- PhantomSound handler).
	Sounds = { "Footsteps", "Knock", "DoorSlam", "Drip" },
	-- Colours an ornament may take for one Witness.
	Colors = {
		{ 150, 40, 40 },
		{ 40, 90, 150 },
		{ 60, 120, 60 },
		{ 170, 150, 60 },
		{ 120, 60, 140 },
	},
}
