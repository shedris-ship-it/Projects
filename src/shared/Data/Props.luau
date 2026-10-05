-- Furniture kinds used by room templates. size = { width (x), height, depth (z) }
-- before rotation; a prop's "front" faces +Z in its own frame, toward the room.
--
-- hide:     hiding spot category the stalker learns ("locker", "bed", ...)
-- capacity: Witnesses that fit at once (doc: 1-2)
-- noise:    noise radius when someone enters or leaves the spot
-- light:    the prop carries a light ("lamp", "tv")
-- collide = false props are decor the stalker and players can pass through.
-- top:      small things can stand on top (World/Dressing: photos, a telephone)
-- topSpan:  { front z, back z } of the flat top when it is shallower than the
--           prop (a piano's top ends at its keyboard); default is the full depth
-- reach:    how far the prop's foliage or fittings may stand out from its centre,
--           when that is less than the footprint (a plant must fit a corridor strip)
-- landmark: a piece you'd name to meet by ("at the clock"), which gives its room a
--           reason to go in (Logic/RoomPurpose, docs/plans/level-design.md section 4)

local Props = {
	Bed = { size = { 7, 3, 10 }, hide = "bed", capacity = 1, noise = 6, color = { 108, 88, 118 }, material = "Fabric" },
	Wardrobe = {
		size = { 6, 9, 3 },
		hide = "wardrobe",
		capacity = 2,
		noise = 12,
		color = { 92, 64, 44 },
		material = "Wood",
	},
	-- A walk-in closet (gameplay rework 4.8): walk in, slide its mirrored
	-- doors shut, and you're hidden (no teleport: Services/HidingService's
	-- physical spots). Built in.
	Closet = {
		size = { 6, 9, 4 },
		hide = "closet",
		physical = true,
		capacity = 2,
		noise = 6,
		color = { 214, 208, 194 },
		material = "Wood",
	},
	Cabinet = {
		size = { 6, 8, 3 },
		hide = "wardrobe",
		capacity = 2,
		noise = 12,
		color = { 80, 70, 58 },
		material = "Wood",
	},
	Locker = {
		size = { 3, 8, 3 },
		hide = "locker",
		capacity = 1,
		noise = 14,
		color = { 86, 98, 104 },
		material = "Metal",
	},
	Table = {
		size = { 8, 3.4, 5 },
		top = true,
		hide = "table",
		capacity = 2,
		noise = 4,
		color = { 104, 76, 52 },
		material = "Wood",
	},
	Desk = {
		size = { 7, 3.4, 3.5 },
		top = true,
		hide = "table",
		capacity = 1,
		noise = 4,
		color = { 74, 54, 40 },
		material = "Wood",
	},
	Curtain = {
		size = { 6, 10, 1.5 },
		hide = "curtain",
		capacity = 1,
		noise = 3,
		color = { 120, 40, 44 },
		material = "Fabric",
	},
	Bathtub = {
		size = { 8, 3, 4 },
		hide = "curtain",
		capacity = 1,
		noise = 8,
		color = { 214, 214, 206 },
		material = "Marble",
	},

	DiningTable = { size = { 6, 3.4, 12 }, landmark = true, color = { 90, 60, 40 }, material = "Wood" },
	Sofa = { size = { 9, 3.5, 4 }, color = { 70, 82, 96 }, material = "Fabric" },
	Armchair = { size = { 4, 4, 4 }, color = { 110, 70, 60 }, material = "Fabric" },
	Counter = { size = { 12, 3.6, 3 }, top = true, color = { 180, 176, 166 }, material = "Granite" },
	Fridge = { size = { 4, 8, 3.5 }, color = { 210, 210, 204 }, material = "SmoothPlastic" },
	Stove = { size = { 4, 3.6, 3.5 }, color = { 60, 60, 62 }, material = "Metal" },
	Shelf = { size = { 8, 9, 2 }, color = { 96, 70, 50 }, material = "Wood" },
	Sink = { size = { 3, 3.5, 2.5 }, color = { 220, 220, 214 }, material = "Marble" },
	Toilet = { size = { 2.5, 3, 3.5 }, color = { 226, 226, 220 }, material = "Marble" },
	Crib = { size = { 5, 4, 3 }, color = { 200, 190, 170 }, material = "Wood" },
	Washer = { size = { 3.5, 4, 3.5 }, color = { 220, 220, 216 }, material = "SmoothPlastic" },
	Boxes = { size = { 4, 4, 4 }, color = { 150, 120, 84 }, material = "Cardboard" },
	Workbench = { size = { 10, 3.6, 3.5 }, top = true, color = { 110, 86, 60 }, material = "WoodPlanks" },
	Car = { size = { 7, 5, 14 }, landmark = true, color = { 60, 72, 66 }, material = "Metal" },
	-- The body is d - 1 deep, set back half a stud, so its top is z -1.5 to 0.5.
	Piano = {
		size = { 7, 5, 3 },
		top = true,
		topSpan = { -1.5, 0.5 },
		landmark = true,
		color = { 24, 22, 22 },
		material = "SmoothPlastic",
	},
	TVStand = { size = { 6, 3, 2 }, light = "tv", color = { 50, 40, 34 }, material = "Wood" },
	-- Chest-high to a player (eye 4.5), so you can see into its top drawer.
	Dresser = { size = { 6, 3.6, 2.5 }, top = true, color = { 112, 82, 58 }, material = "Wood" },
	Plant = { size = { 2, 5, 2 }, reach = 1, color = { 54, 80, 50 }, material = "Grass" },
	GrandfatherClock = { size = { 2.5, 8, 2 }, landmark = true, color = { 70, 44, 30 }, material = "Wood" },
	CoatRack = { size = { 2, 7, 2 }, color = { 60, 44, 34 }, material = "Wood" },
	Bench = { size = { 8, 2.5, 2.5 }, top = true, color = { 96, 74, 54 }, material = "Wood" },
	WaterHeater = { size = { 3, 7, 3 }, color = { 190, 190, 184 }, material = "Metal" },
	-- The cellar's (docs/plans/level-design.md section 10.2): the boiler, a
	-- landmark you can call out ("by the boiler"), and racks of bottles.
	Boiler = { size = { 6, 8, 5 }, landmark = true, color = { 74, 70, 64 }, material = "Metal" },
	WineRack = { size = { 6, 8, 2 }, color = { 92, 66, 46 }, material = "Wood" },
	-- No `top`: its lid opens (World/PropFactory), and nothing should float.
	Chest = { size = { 5, 3, 3 }, color = { 86, 58, 38 }, material = "Wood" },
	Mannequin = { size = { 2, 6.5, 2 }, color = { 214, 200, 180 }, material = "SmoothPlastic" },
	FloorLamp = { size = { 1.5, 6, 1.5 }, light = "lamp", color = { 40, 36, 30 }, material = "Metal" },
	Shrine = { size = { 3, 4, 3 }, color = { 70, 60, 48 }, material = "Wood" },

	-- Decor that never blocks movement.
	Chair = { size = { 2.5, 4, 2.5 }, collide = false, color = { 96, 70, 50 }, material = "Wood" },
	Rug = { size = { 10, 0.1, 14 }, collide = false, color = { 110, 50, 44 }, material = "Fabric" },
}

-- Wall decor kinds, mounted flat on a wall.
local WallDecor = {
	Painting = { size = { 5, 4 } },
	Window = { size = { 6, 5 }, light = "window" },
	Mirror = { size = { 3, 5 } },
}

-- Where a long Counter's sink sits and how wide its basin is (centre x and
-- width, in the counter's own frame). The builder (World/PropFactory) and the
-- clutter planner (World/Dressing) both read this, so a mug can't be set down
-- inside the basin.
local function counterSink(width: number): (number, number)
	return -width / 4, math.min(2.6, width * 0.32)
end

-- Rectangles on a furniture top that small things must stay out of, as
-- { x0, x1 } spans in the prop's own frame (full depth).
local function keepouts(kindName: string, size)
	if kindName == "Counter" and size[1] >= 5 then
		local x, basin = counterSink(size[1])
		local margin = 0.55 -- the widest dish is about 1 wide, and it is jittered
		return { { x0 = x - basin / 2 - margin, x1 = x + basin / 2 + margin } }
	elseif kindName == "Workbench" then
		-- The vice stands at x = w/2 - 1, 0.8 wide (World/PropFactory).
		return { { x0 = size[1] / 2 - 1 - 0.4 - 0.55, x1 = size[1] / 2 } }
	end
	return {}
end

return {
	Kinds = Props,
	WallDecor = WallDecor,
	CounterSink = counterSink,
	Keepouts = keepouts,
}
