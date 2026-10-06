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
--   carry        in your hands (Logic/Heft, R2c): omega (how keenly the hold
--                point follows your eye; heavy things trail), forceG (the
--                force it may use, in g: heavy things sag when whipped),
--                maxSpeed (studs a second), tilt (radians it leans when
--                swung), bob (studs it bobs with your stride)

local Classes = {
	light = {
		density = 0.35,
		follow = 45,
		throwSpeed = 50,
		stun = 0.7,
		noise = 10,
		sound = "Stamp",
		pitch = 1.35,
		carry = { omega = 28, forceG = 10, maxSpeed = 60, tilt = 0.25, bob = 0 },
	},
	medium = {
		density = 0.7,
		follow = 30,
		throwSpeed = 42,
		stun = 1.2,
		noise = 16,
		sound = "Knock",
		pitch = 1,
		carry = { omega = 18, forceG = 7, maxSpeed = 45, tilt = 0.35, bob = 0.03 },
	},
	heavy = {
		density = 1,
		follow = 18,
		throwSpeed = 34,
		stun = 1.8,
		noise = 22,
		sound = "Thud",
		pitch = 0.8,
		carry = { omega = 11, forceG = 5, maxSpeed = 32, tilt = 0.45, bob = 0.06 },
	},
	-- Furniture you carry in both arms (a plant, a lamp, a mannequin): slow
	-- to follow, a short heavy throw.
	bulky = {
		density = 1.1,
		follow = 12,
		throwSpeed = 30, -- fast enough to stun (StunMinSpeed) when wound up
		stun = 2,
		noise = 28,
		sound = "Thud",
		pitch = 0.65,
		carry = { omega = 7, forceG = 4, maxSpeed = 24, tilt = 0.3, bob = 0.12 },
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
	-- The escape's items (World/Items, Services/ItemService); each one's own
	-- label rides on the model.
	Key = { class = "light", label = "Key" },
	Heirloom = { class = "medium", label = "Heirloom" },
	Printout = { class = "light", label = "Printout" },
	-- A board pried off a boarded door (docs/plans/level-design.md 11, L3.3).
	Plank = { class = "medium", label = "Plank" },
	WindUpToy = { class = "light", label = "Wind-up toy" }, -- a child's room's (Services/ToyService)
}

-- Every piece of furniture, by prop kind (section 4.6; the owner asked for
-- all of it to be physical, with varying weights, 2026-10-05). Either
-- carried like a small thing (`class`), or pushed (`weight`, in people: 1 is
-- what one player moves at full speed; Logic/Push). Kinds not listed are
-- fixed: built in or plumbed (Counter, Sink, Toilet, Bathtub, Stove,
-- WaterHeater, Boiler, WaterTank, Car, Curtain, Rug, Shrine).
local Furniture = {
	Chair = { class = "heavy", label = "Chair" },
	Plant = { class = "bulky", label = "Plant" },
	CoatRack = { class = "bulky", label = "Coat rack" },
	FloorLamp = { class = "bulky", label = "Lamp" },
	Mannequin = { class = "bulky", label = "Mannequin" },

	Boxes = { weight = 0.6, label = "Boxes" },
	Crib = { weight = 0.7, label = "Crib" },
	Armchair = { weight = 0.8, label = "Armchair" },
	Bench = { weight = 0.8, label = "Bench" },
	TVStand = { weight = 0.9, label = "Television" },
	Table = { weight = 1, label = "Table" },
	Chest = { weight = 1, label = "Chest" },
	Desk = { weight = 1.1, label = "Desk" },
	Dresser = { weight = 1.3, label = "Dresser" },
	Locker = { weight = 1.4, label = "Locker" },
	GrandfatherClock = { weight = 1.6, label = "Clock" },
	Washer = { weight = 1.6, label = "Washing machine" },
	Sofa = { weight = 1.8, label = "Sofa" },
	Shelf = { weight = 1.8, label = "Bookcase" },
	DiningTable = { weight = 1.8, label = "Dining table" },
	Bed = { weight = 2, label = "Bed" },
	Cabinet = { weight = 2, label = "Cabinet" },
	Workbench = { weight = 2, label = "Workbench" },
	WineRack = { weight = 2, label = "Wine rack" },
	Wardrobe = { weight = 2.2, label = "Wardrobe" },
	Fridge = { weight = 2.4, label = "Fridge" },
	Piano = { weight = 3.5, label = "Piano" },
}

return {
	Classes = Classes,
	Dressing = Dressing,
	Furniture = Furniture,
}
