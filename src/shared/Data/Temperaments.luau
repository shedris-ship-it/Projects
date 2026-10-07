-- The Guest's temperament for the night (the Guest rework, 2026-10-07): one
-- drawn per run from the seed, so no two nights meet the same Guest. It
-- leans his moods (Logic/GuestMood), his move and tactic weights, and a few
-- numbers. It never touches a tell, a cooldown or a fairness gate
-- (Logic/StalkRules). The Dossier names it.
--
--   moodOdds  how likely each mood is when he takes on a new one
--   stalk     multiplies Data/StalkMoves weights between hunts
--   tactics   multiplies Data/Tactics weights in hunts
--   numbers   creep (his creeping speed, kept within 0.8-1.2 with his mood),
--             linger (how long he stands where he stops), peekHold (how
--             long a peek lasts)

local Temperaments = {
	{
		id = "Patient",
		weight = 1,
		line = "Tonight he was patient. He waited where you were going to be.",
		moodOdds = { Patient = 3, Host = 2, Curious = 1, Stalking = 1, Playful = 0.6, Irritated = 0.5 },
		stalk = { DoorwayStand = 1.2, StareDown = 1.1, DistantRoam = 0.9, BehindTheDoor = 1.2, HallwayStand = 1.2 },
		tactics = { Ambush = 1.3, ListenStill = 1.2, CutOffLoop = 1.2 },
		numbers = { creep = 0.9, linger = 1.3, peekHold = 1.3 },
	},
	{
		id = "Restless",
		weight = 1,
		line = "Tonight he was restless. He never stood still for long.",
		moodOdds = { Curious = 2, Stalking = 2, Irritated = 1.5, Playful = 1, Host = 0.7, Patient = 0.4 },
		stalk = { ShadowBehind = 1.2, Search = 1.2, DistantRoam = 1.1, StareDown = 0.8, HallwayStand = 1.1 },
		tactics = { SweepRooms = 1.3, SearchLastKnown = 1.2, ListenStill = 0.7 },
		numbers = { creep = 1.1, linger = 0.7, peekHold = 0.8 },
	},
	{
		id = "Playful",
		weight = 1,
		line = "Tonight he was playful. He wanted you to know he was there.",
		moodOdds = { Playful = 3, Curious = 1.5, Host = 1.5, Stalking = 1, Patient = 0.7, Irritated = 0.6 },
		stalk = {
			Peek = 1.2,
			Investigate = 1.1,
			CreepBehind = 0.9,
			HostAction = 1.3,
			MimicVoice = 1.3,
			FingersPeek = 1.2,
		},
		tactics = { FakePing = 1.4, MimicKnock = 1.3, FakeLeaveReturn = 1.2 },
		numbers = { creep = 1.0, linger = 1.0, peekHold = 1.1 },
	},
	{
		id = "Hungry",
		weight = 1,
		line = "Tonight he was hungry. He wanted his dinner, and whoever carried it.",
		moodOdds = { Stalking = 3, Irritated = 1.4, Host = 1.2, Curious = 1, Patient = 0.7, Playful = 0.5 },
		stalk = { CreepBehind = 1.2, ShadowBehind = 1.2, Peek = 0.9, BehindTheDoor = 1.1 },
		tactics = { TargetStraggler = 1.3, FlankBlindSpot = 1.2, SearchLastKnown = 1.2 },
		numbers = { creep = 1.1, linger = 0.9, peekHold = 0.9 },
	},
}

local byId = {}
for _, temperament in Temperaments do
	byId[temperament.id] = temperament
end

return {
	List = Temperaments,
	ById = byId,
}
