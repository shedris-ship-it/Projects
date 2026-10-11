-- The Director's scare deck (Stalker/Director, Logic/ScareDeck; doc section
-- 3: pacing, not randomness). Shared so the night's temperament can lean the
-- deck (Data/Temperaments `cards`) and its spec can check every id is real.
--   weight    copies in the deck
--   big       a big scare: at least the deck's gap between big ones
--   cooldown  seconds before the same card again
--   minDrift  a Dread threshold (since 2026-10-06)
--   minAct    the run's act (Logic/Acts) it waits for
--   once      once a run
--   house     a house event (Services/HouseEventService), not a Director scare

return {
	{ id = "knock", weight = 3, cooldown = 40 },
	{ id = "distantSteps", weight = 3, cooldown = 30 },
	{ id = "flicker", weight = 3, cooldown = 20 },
	{ id = "coldSpot", weight = 2, cooldown = 60 },
	{ id = "doorSlam", weight = 1, cooldown = 70, minDrift = 30, big = true },
	{ id = "whisper", weight = 1, cooldown = 90, minDrift = 40, big = true },
	-- No phantom "figure" card (owner, 2026-10-03): the only Guest you see is
	-- the real one, always somewhere in the house. The one exception, chosen
	-- by the owner: early on, one Witness may see his face at a window while
	-- he's elsewhere. Something to argue about.
	{ id = "windowFace", weight = 1, cooldown = 120, minDrift = 5, big = true },
	-- A scare he sets up on purpose, for whoever he has frightened least
	-- lately (StalkerService:_beat; the squad playtest, 2026-10-08).
	{ id = "guestBeat", weight = 2, cooldown = 90, minDrift = 20, minAct = 2, big = true },
	-- His disguise: a friend's look, late in a bad night (StalkerService:_disguise).
	{ id = "disguise", weight = 1, cooldown = 200, minDrift = 60, minAct = 3, big = true },
	-- The house's own scares (Services/HouseEventService), by act: the deeper
	-- the squad goes, the more the house does. minDrift is a Dread threshold.
	{ id = "doorAjar", weight = 2, cooldown = 45, house = true },
	{ id = "radioOn", weight = 2, cooldown = 90, minDrift = 10, house = true },
	{ id = "overhead", weight = 2, cooldown = 50, minAct = 2, house = true },
	{ id = "knockInside", weight = 2, cooldown = 80, minAct = 2, house = true },
	{ id = "lightsDie", weight = 2, cooldown = 110, minAct = 2, big = true, house = true },
	{ id = "phoneRings", weight = 1, cooldown = 150, minAct = 2, big = true, house = true },
	{ id = "clockStrikes", weight = 1, cooldown = 60, minAct = 3, big = true, once = true, house = true },
}
