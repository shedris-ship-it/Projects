-- The Guest's temperament for the night (the Guest rework, 2026-10-07): one
-- drawn per run from the seed, so no two nights meet the same Guest. It
-- leans his moods (Logic/GuestMood), his move and tactic weights, the scare
-- deck and a few numbers. It never touches a tell, a cooldown or a fairness
-- gate (Logic/StalkRules). The Dossier names it, with its sign and how to
-- play him next time.
--
-- "A Guest you can read" (2026-10-11, the owner's choice): each is strongly
-- itself from the first five minutes, so a squad can tell which Guest they
-- have tonight and play him for it. No guessing for Marks (the owner's
-- answer): reading him is its own reward.
--
--   dominant  the mood he lives in tonight (moodOdds make it most of the
--             night; Temperaments.spec holds it to at least 40%)
--   sign      what you notice, in the Dossier's words ("The sign: ...")
--   counter   how to play him ("Next time: ...")
--   moodOdds  how likely each mood is when he takes on a new one
--   stalk     multiplies Data/StalkMoves weights between hunts
--   tactics   multiplies Data/Tactics weights in hunts
--   intro     multiplies the moves of the night's first minutes (only those
--             Config.Guest.Intro.Moves allows: far, brief glimpses still)
--   cards     multiplies the scare deck's cards (Data/ScareCards)
--   voice     his friend's-voice trick (Stalk MimicVoice) on any difficulty
--             (the owner, 2026-10-11: the playful Guest's, on Normal too);
--             Hard has it for every temperament (Config.Difficulty)
--   sniffs    he sniffs the air, loud enough to hear, as he starts a search
--             and as he smells a carried heirloom (StalkerService:Sniff)
--   numbers   creep (his creeping speed, kept within 0.8-1.2 with his mood),
--             linger (how long he stands where he stops), peekHold (how
--             long a peek lasts), park (his presence budget beside one of
--             you, StalkRules.parkBudget), scent (how often a carried
--             heirloom tells him its room, Config.Scent.Interval)

local Temperaments = {
	{
		id = "Patient",
		weight = 1,
		line = "Tonight he was patient. He waited where you were going to be.",
		sign = "you'd find him standing dead still where you were heading",
		counter = "take the other door, and move together",
		dominant = "Patient",
		moodOdds = { Patient = 6, Host = 1.5, Curious = 1, Stalking = 1, Playful = 0.5, Irritated = 0.5 },
		stalk = {
			DoorwayStand = 1.8,
			StareDown = 1.4,
			DistantRoam = 0.8,
			BehindTheDoor = 1.6,
			HallwayStand = 2,
			CreepBehind = 0.8,
		},
		tactics = { Ambush = 2, ListenStill = 1.5, CutOffLoop = 2 },
		intro = { HallwayStand = 3, Peek = 0.6 },
		cards = { doorAjar = 0.5, distantSteps = 0.6, radioOn = 0.5, knock = 0.6 },
		numbers = { creep = 0.9, linger = 1.8, peekHold = 1.5 },
	},
	{
		id = "Restless",
		weight = 1,
		line = "Tonight he was restless. He never stood still for long.",
		sign = "doors you'd shut stood open again, and footsteps went over your heads",
		counter = "hide and let him pass: he never waits long",
		dominant = "Curious",
		moodOdds = { Curious = 6, Stalking = 1.5, Irritated = 1.5, Playful = 1, Host = 0.5, Patient = 0.3 },
		stalk = {
			ShadowBehind = 1.2,
			Search = 1.4,
			DistantRoam = 1.4,
			StareDown = 0.6,
			HallwayStand = 0.8,
			Investigate = 1.3,
		},
		tactics = { SweepRooms = 1.8, SearchLastKnown = 1.3, ListenStill = 0.5 },
		intro = { DistantRoam = 3, Search = 1.5 },
		cards = { doorAjar = 3, overhead = 2, distantSteps = 2 },
		numbers = { creep = 1.1, linger = 0.5, peekHold = 0.6, park = 0.5 },
	},
	{
		id = "Playful",
		weight = 1,
		line = "Tonight he was playful. He wanted you to know he was there.",
		sign = "knocking inside the wardrobes, radios that switched themselves on, a friend's voice where your friend wasn't",
		counter = "don't chase every sound, and ask your friends where they are",
		dominant = "Playful",
		voice = true,
		moodOdds = { Playful = 6, Curious = 1.5, Host = 1.5, Stalking = 0.8, Patient = 0.5, Irritated = 0.5 },
		stalk = {
			Peek = 1.3,
			Investigate = 1.1,
			CreepBehind = 0.9,
			HostAction = 1.6,
			MimicVoice = 2,
			FingersPeek = 1.4,
		},
		tactics = { FakePing = 2, MimicKnock = 2, FakeLeaveReturn = 1.4 },
		intro = { HostAction = 3, Peek = 1.5 },
		cards = { knockInside = 3, radioOn = 3, knock = 2 },
		numbers = { creep = 1.0, linger = 1.0, peekHold = 1.2 },
	},
	{
		id = "Hungry",
		weight = 1,
		line = "Tonight he was hungry. He wanted his dinner, and whoever carried it.",
		sign = "a long, slow sniff somewhere near, and whoever carried an heirloom never had him far behind",
		counter = "pass the heirloom on, keep close to whoever carries it, and set it fast",
		dominant = "Stalking",
		moodOdds = { Stalking = 6, Irritated = 1.4, Host = 1, Curious = 1, Patient = 0.5, Playful = 0.4 },
		stalk = { CreepBehind = 1.3, ShadowBehind = 2, Peek = 0.9, BehindTheDoor = 1.1, Search = 1.4 },
		tactics = { TargetStraggler = 1.5, FlankBlindSpot = 1.3, SearchLastKnown = 1.4 },
		intro = { Search = 3, Investigate = 1.5 },
		cards = { distantSteps = 1.5 },
		sniffs = true,
		numbers = { creep = 1.1, linger = 0.9, peekHold = 0.9, scent = 0.5 },
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
