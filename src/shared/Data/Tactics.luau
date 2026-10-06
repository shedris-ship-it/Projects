-- The Tactician's menu (doc: 12-15 tactics scored by utility, then a random
-- pick among the top three). signal names a SquadProfile signal (0..1); a
-- tactic is weighted up when the squad shows that habit. Every tactic is
-- paired with a counter-counter so a learning stalker stays beatable.

local Tactics = {
	{
		id = "SearchLastKnown",
		base = 1.2,
		signal = nil,
		cooldown = 0,
		description = "Goes to where it last saw or heard you.",
		counter = "Move after it loses sight of you.",
	},
	{
		id = "Investigate",
		base = 1.3,
		signal = nil,
		cooldown = 4,
		description = "Runs to a noise nobody made, in case it was you.",
		counter = "Throw something to draw it off, then move while it looks.",
	},
	{
		id = "SweepRooms",
		base = 0.7,
		signal = "routeHabit",
		cooldown = 10,
		description = "Checks the rooms you use most, in order.",
		counter = "Use rooms you usually avoid.",
	},
	{
		id = "CheckHidingSpots",
		base = 0.9,
		signal = "hideHabit",
		cooldown = 8,
		description = "Inspects your favourite kind of hiding spot first.",
		counter = "Vary spots; bait with noise elsewhere.",
	},
	{
		id = "FakeLeaveReturn",
		base = 0.6,
		signal = "hideHabit",
		cooldown = 30,
		description = "Walks away loudly, then creeps back.",
		counter = "Wait longer before leaving a hiding spot.",
	},
	{
		id = "CutOffLoop",
		base = 0.7,
		signal = "loopHabit",
		cooldown = 18,
		description = "Waits on the far side of the loop you keep running.",
		counter = "Break the pattern; cross between loops.",
	},
	{
		id = "TargetStraggler",
		base = 0.8,
		signal = "cohesion",
		cooldown = 15,
		description = "Waits for a split, then goes for whoever is alone.",
		counter = "Rotate who scouts; use Lantern rooms.",
	},
	{
		id = "FlankBlindSpot",
		base = 0.6,
		signal = "gazeHabit",
		cooldown = 15,
		description = "Comes from behind, or from a teammate's blind spot.",
		counter = "Cover each other's blind spots.",
	},
	{
		id = "KillLights",
		base = 0.5,
		signal = "flashlightHabit",
		cooldown = 40,
		description = "Kills the lights near you and strikes from outside the beam.",
		counter = "Spot-check dark corners; save battery.",
	},
	{
		id = "FakePing",
		base = 0.4,
		signal = "pingHabit",
		cooldown = 35,
		description = "Fakes a teammate's ping to lure you.",
		counter = "Confirm pings by voice.",
	},
	{
		id = "Ambush",
		base = 0.6,
		signal = "stationary",
		cooldown = 20,
		description = "Waits in a doorway on your likely route.",
		counter = "Keep moving; take the other door.",
	},
	{
		id = "ListenStill",
		base = 0.5,
		signal = nil,
		cooldown = 20,
		description = "Stands perfectly still and listens.",
		counter = "Walk, don't run. Hold your breath.",
	},
	{
		id = "MimicKnock",
		base = 0.4,
		signal = "stationary",
		cooldown = 45,
		description = "Knocks on a door near you, and waits for you to open it.",
		counter = "Don't answer knocks; watch the door together, in the light.",
	},
}

local byId = {}
for _, tactic in Tactics do
	byId[tactic.id] = tactic
end

return {
	List = Tactics,
	ById = byId,
}
