-- Small things your hands can pick up, carry and throw (docs/plans/
-- gameplay-rework.md sections 4.3 and 4.4), by the model name their builders
-- give them (World/Dressing, Data/Props). Everything stays anchored until
-- someone grabs it; then it's a real physics object until it settles again.
--
-- A class sets how heavy it feels and what a throw does:
--   density      for CustomPhysicalProperties (how it falls and tumbles)
--   follow       how keenly it follows your hand (heavier lags behind)
--   throwSpeed   studs a second out of your hand
--   stun         seconds a hit on The Guest stops him (Logic/Throw shrinks repeats)
--   noise        how far its landing carries (a lure: nobody's position)
--   sound, pitch what its landing sounds like

local Classes = {
	light = {
		density = 0.35,
		follow = 45,
		throwSpeed = 50,
		stun = 0.7,
		noise = 10,
		sound = "Stamp",
		pitch = 1.35,
	},
	medium = {
		density = 0.7,
		follow = 30,
		throwSpeed = 42,
		stun = 1.2,
		noise = 16,
		sound = "Knock",
		pitch = 1,
	},
	heavy = {
		density = 1,
		follow = 18,
		throwSpeed = 34,
		stun = 1.8,
		noise = 22,
		sound = "Thud",
		pitch = 0.8,
	},
}

-- The class of each thing and the name shown when you look at it. Dressing
-- is found by model name (World/Dressing names its models); furniture by its
-- prop kind (furniture models are named after their template id).
local Dressing = {
	Mug = { class = "light", label = "Mug" },
	Plate = { class = "light", label = "Plate" },
	Magazine = { class = "light", label = "Magazine" },
	PhotoFrame = { class = "light", label = "Photograph" },
	Books = { class = "medium", label = "Books" },
	Vase = { class = "medium", label = "Vase" },
	Telephone = { class = "medium", label = "Telephone" },
	-- Kept in drawers and cupboards (World/Junk).
	Cassette = { class = "light", label = "Cassette tape" },
	Matchbox = { class = "light", label = "Matches" },
	Letters = { class = "light", label = "Letters" },
	Candle = { class = "light", label = "Candle" },
	Spool = { class = "light", label = "Thread" },
	PillBottle = { class = "light", label = "Pill bottle" },
}

local Furniture = {
	Chair = { class = "heavy", label = "Chair" },
}

return {
	Classes = Classes,
	Dressing = Dressing,
	Furniture = Furniture,
}
