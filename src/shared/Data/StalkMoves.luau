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
		counter = "Get a second Witness on him instead of running.",
	},
	{
		id = "DistantRoam",
		tiers = { 0, 1, 2, 3 },
		base = 0.3,
		signal = nil,
		cooldown = 0,
		description = "Walks the far rooms, so you can hear where he is.",
		counter = "Listen: his footsteps are real.",
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
