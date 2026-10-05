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
}
