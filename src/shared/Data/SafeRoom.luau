-- What a safe room may hold (docs/plans/level-design.md section 11.12; the
-- owner's idea, 2026-10-05): things that help, never anything the run needs.
-- Logic/SafeRoom rolls from this table with the run's seed, each entry at
-- most once. It's a table so more can join it later: deterrents of varying
-- reliability (a flare, a flash camera, a fire extinguisher), or the weapons
-- the owner wondered about, a design decision for another session.
--
--   kind  "batteries": a box of torch batteries, one refill a player
--         "tool":      a tool for slot 2 or 3 (Data/Tools)
--         "plans":     the house plans of a floor nobody has them for yet
--   weight  how likely, against the others

return {
	{ id = "batteries", kind = "batteries", weight = 4, label = "Batteries" },
	{ id = "lantern", kind = "tool", tool = "Lantern", weight = 2, label = "Lantern" },
	{ id = "radio", kind = "tool", tool = "Radio", weight = 2, label = "Radio" },
	{ id = "plans", kind = "plans", weight = 3, label = "House plans" },
}
