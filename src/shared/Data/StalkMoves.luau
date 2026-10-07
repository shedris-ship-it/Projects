-- What The Guest does between hunts (owner, 2026-10-03). Scored like the
-- hunt tactics (Logic/UtilityAI): base weight x squad habit signal x
-- feasibility, then a random pick among the top three, so he's never fully
-- predictable. Every move is paired with a counter (doc section 5: every
-- adaptation has a counter-counter), and the Dossier names the moves he
-- leaned on.

local StalkMoves = {
	{
		id = "Peek",
		tiers = { 1, 2, 3 },
		base = 1.0,
		signal = "stareHabit", -- you look at things: he gives you something to look at
		cooldown = 6,
		description = "Peeks at you round a door frame.",
		counter = "Check doorways as you pass, and watch him together.",
	},
	{
		id = "DoorwayStand",
		tiers = { 1, 2 },
		base = 0.75,
		signal = "routeHabit",
		cooldown = 30,
		description = "Stands in the doorway you just walked through.",
		counter = "Look back after every doorway.",
	},
	{
		id = "CreepBehind",
		tiers = { 2, 3 },
		base = 1.0,
		signal = "blindBack",
		cooldown = 0,
		description = "Creeps up behind whoever looks back least.",
		counter = "Look behind you often, at uneven times; walk back to back.",
	},
	{
		id = "ShadowBehind",
		tiers = { 1, 2, 3 },
		base = 0.55,
		signal = "straggling",
		cooldown = 20,
		description = "Follows a straggler; his footsteps stop when yours do.",
		counter = "Stop and listen. Stay together.",
	},
	{
		id = "StareDown",
		tiers = { 2, 3 },
		base = 0.45,
		signal = "fleeHabit",
		cooldown = 35,
		description = "Stands in plain sight and smiles until you look away.",
		counter = "Get a second pair of eyes on him, with a light, instead of running.",
	},
	{
		id = "Search",
		tiers = { 1, 2, 3 },
		base = 1.0,
		signal = nil,
		cooldown = 0,
		description = "Checks the rooms you use most when he's lost you.",
		counter = "Change your route; stay quiet and out of sight.",
	},
	{
		id = "Investigate",
		tiers = { 1, 2, 3 },
		base = 1.4,
		signal = nil,
		cooldown = 5,
		description = "Goes to look at a noise nobody made: a thing that fell, a flush, a radio left on.",
		counter = "Throw something away from where you hide; he gets wise if you do it every time.",
	},
	{
		id = "DistantRoam",
		tiers = { 0, 1, 2, 3 },
		base = 0.3,
		signal = nil,
		cooldown = 0,
		description = "Walks the far rooms, unseen and unheard.",
		counter = "Listen for the creak and the breath behind you; he is closer than the quiet suggests.",
	},
	-- The Guest rework (2026-10-07): more ways, each with its tell.
	{
		id = "FingersPeek",
		tiers = { 1, 2, 3 },
		base = 0.7,
		signal = "stareHabit",
		cooldown = 20,
		description = "Curls his long fingers round a door frame; his face follows if you keep looking.",
		counter = "Fingers on a frame mean he's right behind it: back off, or watch it together.",
	},
	{
		id = "HallwayStand",
		tiers = { 1, 2, 3 },
		base = 0.6,
		signal = "routeHabit",
		cooldown = 40,
		description = "Stands at the far end of your corridor, facing you; closer each time you look back.",
		counter = "Don't look away and back; take another way round.",
	},
	{
		id = "BehindTheDoor",
		tiers = { 2, 3 },
		base = 0.5,
		signal = "routeHabit",
		cooldown = 45,
		description = "Waits behind the door you're about to open; his feet's shadow shows under it.",
		counter = "Look at the gap under a door, and listen, before you open it.",
	},
	{
		id = "HostAction",
		tiers = { 0, 1, 2, 3 },
		base = 0.35,
		signal = nil,
		cooldown = 50,
		description = "Busies himself about his house: the radio on, a light put out, a door eased ajar.",
		counter = "The sounds are his: while you hear them, you know where he is.",
	},
	{
		id = "MimicVoice",
		tiers = { 2, 3 },
		base = 0.3,
		signal = "straggling",
		cooldown = 120,
		description = "Speaks with a friend's voice from behind a shut door (Hard, in a squad).",
		counter = "Confirm by voice: ask them where they are.",
	},
	-- Errands (R2c): never picked by habit; StalkerService sets them.
	{
		id = "WaitAtTable",
		errand = true,
		tiers = {},
		base = 0,
		cooldown = 0,
		description = "Waits at the head of the table for his dinner.",
		counter = "Two of you hold his eyes while the third sets the place.",
	},
	{
		id = "Tidy",
		errand = true,
		tiers = {},
		base = 0,
		cooldown = 0,
		description = "Puts his things back where they were kept.",
		counter = "Don't leave an heirloom lying about; carry it, or set it.",
	},
}

local byId = {}
for _, move in StalkMoves do
	byId[move.id] = move
end

return {
	List = StalkMoves,
	ById = byId,
}
