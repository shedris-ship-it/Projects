-- Stalker archetypes (doc section 5): one AI framework, many configurations.
-- tacticWeights multiply the base weights in Data/Tactics.

local Archetypes = {
	TheGuest = {
		name = "The Guest",
		rule = "Watcher: moves only between sightlines, polite posture.",
		signature = "Mimics domestic sounds: knocks, and a voice behind a door.",
		counterplay = "Don't answer knocks. Watch the door together, in the light.",
		height = 8.4,
		bodyColor = { 18, 17, 20 },
		headColor = { 196, 190, 178 },
		hearingMultiplier = 1,
		speedMultiplier = 1,
		headTiltDegrees = 14,
		tacticWeights = {
			MimicKnock = 1.6,
			FakeLeaveReturn = 1.2,
			Ambush = 1.2,
		},
		-- Between hunts (Data/StalkMoves): a watcher who lives in doorways.
		stalkWeights = {
			Peek = 1.4,
			DoorwayStand = 1.3,
			StareDown = 1.1,
		},
	},
	TheOrderly = {
		name = "The Orderly",
		rule = "Patroller: follows a schedule it breaks as it learns.",
		signature = "Kills lights; checks rooms in order of your habits.",
		counterplay = "Learn the patrol; use Lantern rooms.",
		height = 8,
		bodyColor = { 200, 204, 196 },
		headColor = { 150, 156, 150 },
		hearingMultiplier = 1,
		speedMultiplier = 0.98,
		headTiltDegrees = 6,
		tacticWeights = {
			SweepRooms = 1.8,
			KillLights = 1.6,
		},
	},
}

return Archetypes
