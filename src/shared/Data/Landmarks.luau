-- Landmarks (docs/plans/level-design.md section 4, L3.6): one thing on a
-- corridor's wall you can't mistake for another, so the squad can say where
-- they are ("meet at the stag's head") and the map can show it once someone
-- has been by (Logic/Landmarks says which corridor gets which; server/World/
-- LandmarkProps builds them).
--   name   what it's called aloud, and on the map

return {
	{ id = "stag", name = "Stag's head" },
	{ id = "portrait", name = "Big portrait" },
	{ id = "tapestry", name = "Tapestry" },
	{ id = "clock", name = "Stopped clock" },
	{ id = "wheel", name = "Ship's wheel" },
}
