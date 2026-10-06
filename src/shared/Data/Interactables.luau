-- The house's fixtures you can work (R2c interactables; Services/
-- InteractService), by prop kind. Each makes a noise he hears as a lure
-- (Services/NoiseService, no source): something to send him the wrong way.
--   action, off   the prompt's words (off: while it runs, to stop it)
--   object        what the prompt calls it
--   sound         an Assets.Sounds key; loop: it plays until turned off
--   volume, pitch the sound's
--   lure          how far the noise carries (studs)
--   every         while it runs, the noise again this often (seconds)
--   once          a one-shot: noises at these seconds after use
--   cooldown      seconds before a one-shot can be used again
--   on            Assets key for the click of turning it on or off
--   runFor        a running one stops by itself after this long (a wash, a record)
--   delay, ring   a one-shot that goes off `delay` seconds after it's set, its
--                 sound looping for `ring` seconds (the kettle); `once` counts
--                 from when it goes off
--   uses          how many times a run (the car horn: once)
--   masks         while it runs, footsteps within `radius` carry only
--                 `factor` as far (the washing machine; Services/NoiseService)
--   placed        not furniture of its own: put there each run (Services/
--                 InteractService) `on` a prop kind (else on a top in `room`),
--                 or on a top in the first of `rooms` (template ids, in order)
--                 that has one (`one`: one a house); Logic/RoomPurpose counts
--                 it as a lure there

return {
	Toilet = {
		action = "Flush",
		object = "Toilet",
		sound = "Flush",
		volume = 0.7,
		lure = 30,
		once = { 1, 5 },
		cooldown = 14,
	},
	Sink = {
		action = "Turn on the tap",
		off = "Turn off the tap",
		object = "Sink",
		sound = "Tap",
		volume = 0.45,
		loop = true,
		lure = 14,
		every = 3,
	},
	Bathtub = {
		action = "Turn on the tap",
		off = "Turn off the tap",
		object = "Bathtub",
		sound = "Tap",
		volume = 0.55,
		pitch = 0.9,
		loop = true,
		lure = 16,
		every = 3,
	},
	TVStand = {
		action = "Turn up the static",
		off = "Turn it down",
		object = "Television",
		sound = "RadioStatic",
		volume = 0.5,
		loop = true,
		lure = 18,
		every = 4,
	},
	Radio = {
		action = "Turn on",
		off = "Turn off",
		object = "Radio",
		sound = "RadioStatic",
		volume = 0.4,
		pitch = 0.85,
		loop = true,
		lure = 20,
		every = 4,
		on = "FlashlightClick",
	},
	-- Rooms' own (docs/plans/level-design.md section 4, L3.6).
	-- The laundry's: a long rumble that also hides your footsteps near it.
	Washer = {
		action = "Start the machine",
		off = "Stop it",
		object = "Washing machine",
		sound = "WashingMachine",
		volume = 0.55,
		loop = true,
		lure = 22,
		every = 4,
		runFor = 60,
		masks = { radius = 16, factor = 0.35 },
		on = "LockClick",
	},
	-- The garage's: one huge lure a run.
	Car = {
		action = "Lean on the horn",
		object = "Car",
		sound = "CarHorn",
		volume = 1,
		lure = 70,
		once = { 0, 1.2 },
		uses = 1,
	},
	-- The kitchen's: set it on the stove and get away; it shrieks 20 s later.
	Kettle = {
		action = "Put the kettle on",
		object = "Kettle",
		sound = "KettleWhistle",
		volume = 0.55,
		pitch = 1.3,
		delay = 20,
		ring = 8,
		lure = 34,
		once = { 0, 3, 6 },
		cooldown = 45,
		on = "LockClick",
		placed = { on = "Stove", room = "kitchen" },
	},
	-- The living room's or the den's: a record plays one side, 40 s.
	RecordPlayer = {
		action = "Play a record",
		off = "Lift the needle",
		object = "Record player",
		sound = "Record",
		volume = 0.45,
		loop = true,
		lure = 24,
		every = 4,
		runFor = 40,
		on = "Cloth",
		placed = { rooms = { "living_room", "den", "sunroom", "music_room" }, one = true },
	},
	-- A child's room's: a tin robot to wind up and set walking, ticking
	-- (Services/ToyService runs it; `toy`: not a fixture).
	WindUpToy = {
		object = "Wind-up toy",
		toy = true,
		placed = { rooms = { "kids_bedroom", "playroom", "nursery" } },
	},
}
