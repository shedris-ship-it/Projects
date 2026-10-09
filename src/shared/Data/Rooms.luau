-- Room templates for The Halfway House (doc: "hand-built rooms, procedural
-- arrangement"). Rooms are 40x40 studs with a doorway at the middle of each
-- side, so the generator can rotate any template by 90 degrees.
--
-- Layout rules every template follows (checked by tests/specs/Rooms.spec):
--   * collidable furniture lives in the 7.5-stud band along the walls, so the
--     centre of the room and the four doorway-to-centre lanes stay clear for
--     the stalker's navigation and for chases;
--   * furniture never overlaps other furniture or the Lantern shrine spot;
--   * wall slots (where wall tells and Sources go) avoid the doorways.
--
-- Coordinates are local: x east, z south, origin at the floor centre.
-- Wall "along" is x for N/S walls and z for E/W walls.
-- "family" picks the lighting recipe in Config.Lighting.Families (docs/ART.md).
-- floor and wall "material" name a surface: one of the house's MaterialVariants
-- (Data/Materials) or a built-in material. The colour tints it.
-- "wainscot" panels the lower third of the walls (formal rooms).
-- "corridor" (optional) fills the corners with closets, leaving a plus-shaped
-- hallway halfWidth studs either side of the centre lines. Its furniture,
-- shrine and floor slots go in the strips between the lanes and the closets,
-- and its wall slots and decor use { x, z, face } on the closet faces.
--
-- To use a hand-built prefab instead of the grey-box, put a Model named after
-- the template id in ServerStorage.RoomPrefabs (see README).

local Rooms = {
	{
		id = "foyer",
		name = "Foyer",
		mood = "open",
		family = "living",
		weight = 0,
		max = 1,
		roles = { start = true },
		floor = { material = "OakFloor", color = { 120, 88, 60 } },
		wall = { material = "WallpaperStripe", color = { 150, 134, 106 } },
		reverb = "Room",
		props = {
			{ id = "coatrack", kind = "CoatRack", x = -17, z = -17 },
			{ id = "bench", kind = "Bench", x = 12, z = -18.25 },
			{ id = "closet", kind = "Cabinet", x = -18, z = 10, ry = 90 },
			{ id = "coats", kind = "TallCupboard", x = -8, z = 17.5, ry = 180 },
			{ id = "plant", kind = "Plant", x = 17, z = 17 },
			{ id = "lamp", kind = "FloorLamp", x = -17, z = 17, key = true },
			{ id = "rug", kind = "Rug", x = 0, z = 0 },
		},
		decor = {
			{ id = "painting", kind = "Painting", side = "E", along = -10, y = 6.5 },
		},
		caseBoard = { side = "E", along = 10 },
		spawns = { { x = -4, z = -4 }, { x = 4, z = -4 }, { x = -4, z = 4 }, { x = 4, z = 4 } },
		wallSlots = { { side = "N", along = -10 }, { side = "W", along = -10 }, { side = "S", along = 10 } },
		floorSlots = { { x = 8, z = 8 }, { x = -8, z = -8 }, { x = 8, z = -8 } },
		shrine = { x = -17, z = -8 },
	},
	{
		id = "hallway",
		name = "Hallway",
		mood = "watched",
		family = "corridor",
		weight = 3,
		max = 3,
		-- Corridor prototype (docs/ART.md, Scale): closets fill the four corners,
		-- leaving a plus-shaped hallway 14 studs wide. Furniture sits in the
		-- strips between the doorway lanes and the closet walls. Wall slots and
		-- paintings hang on closet faces: x, z on the face and the way it faces.
		corridor = { halfWidth = 7 },
		floor = { material = "OakFloor", color = { 104, 76, 54 } },
		wall = { material = "OldPlaster", color = { 168, 158, 132 } },
		reverb = "CarpettedHallway",
		light = { brightness = 0.9, range = 22 },
		props = {
			{ id = "clock", kind = "GrandfatherClock", x = 6, z = -13, ry = 270 },
			{ id = "bench", kind = "Bench", x = -5.75, z = 13, ry = 90 },
			{ id = "plant", kind = "Plant", x = 13, z = 5.75 },
		},
		decor = {
			{ id = "painting1", kind = "Painting", x = -7, z = -13, face = "E", y = 6.5 },
			{ id = "painting2", kind = "Painting", x = 7, z = 13, face = "W", y = 6.5 },
		},
		wallSlots = {
			{ x = 13, z = -7, face = "S" },
			{ x = -13, z = 7, face = "N" },
			{ x = -13, z = -7, face = "S" },
			{ x = 13, z = 7, face = "N" },
		},
		floorSlots = { { x = -5.5, z = -13 }, { x = 5.5, z = 13 }, { x = -13, z = 5.5 }, { x = 13, z = -5.5 } },
		shrine = { x = -13, z = -5.5 },
	},
	{
		id = "hallway_runner",
		name = "Back Hall",
		mood = "watched",
		family = "corridor",
		weight = 2,
		max = 2,
		corridor = { halfWidth = 7 },
		floor = { material = "OakFloor", color = { 112, 82, 58 } },
		wall = { material = "OldPlaster", color = { 156, 150, 126 } },
		reverb = "CarpettedHallway",
		light = { brightness = 0.85, range = 22 },
		props = {
			{ id = "dresser", kind = "Dresser", x = 5.75, z = -13, ry = 270 },
			{ id = "plant", kind = "Plant", x = -5.5, z = 17 },
			{ id = "bench", kind = "Bench", x = -13, z = 5.75, ry = 180 },
			{ id = "runner", kind = "Rug", x = 0, z = 0 },
		},
		decor = {
			{ id = "mirror", kind = "Mirror", x = -7, z = 13, face = "E", y = 6 },
			{ id = "painting", kind = "Painting", x = 13, z = 7, face = "N", y = 6.5 },
		},
		wallSlots = {
			{ x = 13, z = -7, face = "S" },
			{ x = -13, z = -7, face = "S" },
			{ x = 7, z = 13, face = "W" },
			{ x = -7, z = -13, face = "E" },
		},
		floorSlots = { { x = -5.5, z = -13 }, { x = 5.5, z = 13 }, { x = 13, z = 5.5 }, { x = -13, z = -5.5 } },
		shrine = { x = 13, z = -5.5 },
	},
	{
		id = "living_room",
		name = "Living Room",
		mood = "open",
		family = "living",
		weight = 2,
		max = 1,
		floor = { material = "PileCarpet", color = { 112, 96, 72 } },
		wall = { material = "OldPlaster", color = { 150, 132, 104 } },
		reverb = "LivingRoom",
		props = {
			{ id = "sofa", kind = "Sofa", x = 11, z = -17.5 },
			{ id = "armchair", kind = "Armchair", x = 17, z = -8 },
			{ id = "tv", kind = "TVStand", x = 10, z = 18.5, ry = 180, key = true },
			{ id = "books", kind = "Shelf", x = -18.5, z = -10, ry = 90 },
			{ id = "curtain", kind = "Curtain", x = -18.75, z = 12, ry = 90 },
			{ id = "rug", kind = "Rug", x = 0, z = 0 },
		},
		decor = {
			{ id = "window", kind = "Window", side = "S", along = -12, y = 6 },
		},
		wallSlots = { { side = "N", along = -12 }, { side = "E", along = 10 }, { side = "S", along = -6 } },
		floorSlots = { { x = 8, z = 8 }, { x = -8, z = 8 }, { x = 8, z = -8 }, { x = -8, z = -8 } },
		shrine = { x = -14, z = 17 },
	},
	{
		id = "kitchen",
		name = "Kitchen",
		mood = "tight",
		family = "utility",
		weight = 2,
		max = 1,
		floor = { material = "CheckerLino", color = { 146, 142, 124 } },
		wall = { material = "OldPlaster", color = { 168, 164, 136 } },
		reverb = "Room",
		light = { brightness = 1.1, range = 24 },
		props = {
			{ id = "counter", kind = "Counter", x = -11, z = -18 },
			{ id = "fridge", kind = "Fridge", x = 17, z = -17.75 },
			{ id = "stove", kind = "Stove", x = 10, z = -17.75 },
			{ id = "table", kind = "Table", x = 12, z = 16 },
			{ id = "chair1", kind = "Chair", x = 17.5, z = 15 },
			{ id = "chair2", kind = "Chair", x = 9, z = 11.5 },
			{ id = "sink", kind = "Sink", x = -18.25, z = 10, ry = 90 },
		},
		decor = {
			{ id = "window", kind = "Window", side = "S", along = 9, y = 6 },
			{ id = "painting", kind = "Painting", side = "E", along = 9, y = 6.5 },
		},
		wallSlots = { { side = "E", along = -10 }, { side = "S", along = -10 }, { side = "W", along = -10 } },
		floorSlots = { { x = 8, z = 8 }, { x = -8, z = 8 }, { x = 8, z = -8 }, { x = -8, z = -8 } },
		shrine = { x = -16, z = 16 },
	},
	{
		id = "dining_room",
		name = "Dining Room",
		mood = "open",
		family = "living",
		weight = 0,
		max = 1,
		roles = { deliberation = true },
		floor = { material = "OakFloor", color = { 98, 68, 50 } },
		wall = { material = "WallpaperStripe", color = { 150, 116, 116 } },
		wainscot = true,
		reverb = "LivingRoom",
		-- The table at the room's heart, lit from above, its candles a beacon
		-- (the owner, 2026-10-06; docs/progress/2026-10-07-loop/REPORT.md
		-- WP5): `middle` lets it sit where solid furniture never goes
		-- (Logic/RoomFit), and the walkers' graph rings it (Logic/NavGraph).
		light = { brightness = 2.2, range = 34 },
		props = {
			-- (Its long side along the room's long side, x in this 40x30 frame,
			-- so the doorway lanes from the long walls never reach it; the chairs
			-- sit at 4.5: clear of the table's own margin, and dropped only where a
			-- short wall's doorway lane reaches them.)
			{ id = "table", kind = "DiningTable", x = 0, z = 0, ry = 90, deliberation = true, middle = true },
			{ id = "chair1", kind = "Chair", x = -4, z = -4.5, ry = 0 },
			{ id = "chair2", kind = "Chair", x = 0, z = -4.5, ry = 0 },
			{ id = "chair3", kind = "Chair", x = 4, z = -4.5, ry = 0 },
			{ id = "chair4", kind = "Chair", x = -4, z = 4.5, ry = 180 },
			{ id = "chair5", kind = "Chair", x = 0, z = 4.5, ry = 180 },
			{ id = "chair6", kind = "Chair", x = 4, z = 4.5, ry = 180 },
			{ id = "cabinet", kind = "Cabinet", x = -10, z = -18 },
			{ id = "china", kind = "Shelf", x = 18.5, z = -10, ry = 270 },
			-- Floor-length drapes to hide behind (the china cabinet has shelves).
			{ id = "drapes", kind = "Curtain", x = -18.75, z = 10, ry = 90 },
			{ id = "plant", kind = "Plant", x = 17, z = 17 },
		},
		decor = {
			{ id = "painting", kind = "Painting", side = "N", along = 10, y = 6.5 },
			{ id = "window", kind = "Window", side = "E", along = 10, y = 6 },
		},
		wallSlots = { { side = "S", along = 10 }, { side = "W", along = -10 }, { side = "N", along = -12 } },
		floorSlots = { { x = 8, z = 8 }, { x = -8, z = 8 }, { x = 8, z = -8 }, { x = -8, z = -8 } },
		shrine = { x = 16, z = -16 },
	},
	{
		id = "master_bedroom",
		name = "Master Bedroom",
		mood = "tight",
		family = "bedroom",
		weight = 2,
		max = 1,
		floor = { material = "PileCarpet", color = { 104, 88, 96 } },
		wall = { material = "Wallpaper", color = { 150, 118, 120 } },
		reverb = "Room",
		props = {
			{ id = "bed", kind = "Bed", x = -16, z = -14.5 },
			{ id = "wardrobe", kind = "Closet", x = 17.5, z = -10, ry = 270 },
			{ id = "dresser", kind = "Dresser", x = 10, z = 18.25, ry = 180 },
			{ id = "lamp", kind = "FloorLamp", x = -17, z = -6, key = true },
			{ id = "chair", kind = "Chair", x = 8, z = 14 },
		},
		decor = {
			{ id = "window", kind = "Window", side = "N", along = 10, y = 6 },
			{ id = "painting", kind = "Painting", side = "S", along = -10, y = 6.5 },
		},
		wallSlots = { { side = "E", along = 10 }, { side = "W", along = 12 }, { side = "N", along = -8 } },
		floorSlots = { { x = 8, z = 8 }, { x = -8, z = 8 }, { x = 8, z = -8 } },
		shrine = { x = -16, z = 16 },
	},
	{
		id = "kids_bedroom",
		name = "Child's Bedroom",
		mood = "tight",
		family = "bedroom",
		weight = 2,
		max = 1,
		floor = { material = "PileCarpet", color = { 88, 104, 122 } },
		wall = { material = "Wallpaper", color = { 96, 108, 132 } },
		reverb = "Room",
		props = {
			{ id = "bed", kind = "Bed", x = 16, z = 14.5 },
			{ id = "wardrobe", kind = "Closet", x = -10, z = -17.5 },
			{ id = "toys", kind = "Boxes", x = -16.5, z = 16.5 },
			{ id = "chest", kind = "Chest", x = -8, z = 18, ry = 180 },
			{ id = "lamp", kind = "FloorLamp", x = 17, z = -17, key = true },
		},
		decor = {
			{ id = "window", kind = "Window", side = "W", along = -10, y = 6 },
			{ id = "painting", kind = "Painting", side = "E", along = -10, y = 6.5 },
		},
		wallSlots = { { side = "N", along = 12 }, { side = "S", along = 12 }, { side = "W", along = 10 } },
		floorSlots = { { x = 8, z = -8 }, { x = -8, z = -8 }, { x = -8, z = 8 } },
		shrine = { x = -16, z = -8 },
	},
	{
		id = "guest_room",
		name = "Guest Room",
		mood = "watched",
		family = "bedroom",
		weight = 2,
		max = 1,
		floor = { material = "OakFloor", color = { 114, 88, 66 } },
		wall = { material = "Wallpaper", color = { 122, 128, 108 } },
		reverb = "Room",
		props = {
			{ id = "bed", kind = "Bed", x = -16, z = 12, ry = 180 },
			{ id = "dresser", kind = "Dresser", x = 18.25, z = 10, ry = 270 },
			{ id = "armchair", kind = "Armchair", x = 17, z = -16 },
		},
		decor = {
			{ id = "mirror", kind = "Mirror", side = "E", along = -8, y = 6 },
			{ id = "window", kind = "Window", side = "N", along = -10, y = 6, key = true },
		},
		wallSlots = { { side = "S", along = 10 }, { side = "W", along = -10 }, { side = "N", along = 10 } },
		floorSlots = { { x = 8, z = 8 }, { x = 8, z = -8 }, { x = -8, z = -8 } },
		shrine = { x = -16, z = -16 },
	},
	{
		id = "nursery",
		name = "Nursery",
		mood = "tight",
		family = "bedroom",
		weight = 1,
		max = 1,
		floor = { material = "PileCarpet", color = { 132, 122, 106 } },
		wall = { material = "WallpaperStripe", color = { 100, 112, 134 } },
		reverb = "Room",
		props = {
			{ id = "crib", kind = "Crib", x = 10, z = -18 },
			{ id = "wardrobe", kind = "Closet", x = -17.5, z = -10, ry = 90 },
			{ id = "rocker", kind = "Chair", x = -14, z = 14 },
			{ id = "chest", kind = "Chest", x = 10, z = 18, ry = 180 },
		},
		decor = {
			{ id = "window", kind = "Window", side = "E", along = -10, y = 6, key = true },
		},
		wallSlots = { { side = "N", along = -10 }, { side = "S", along = -10 }, { side = "E", along = 12 } },
		floorSlots = { { x = 8, z = 8 }, { x = -8, z = 8 }, { x = -8, z = -8 } },
		shrine = { x = 16, z = 10 },
	},
	{
		id = "bathroom",
		name = "Bathroom",
		mood = "tight",
		family = "utility",
		weight = 2,
		max = 1,
		floor = { material = "HexTile", color = { 212, 216, 214 } },
		wall = { material = "CeramicTiles", color = { 160, 176, 172 } },
		reverb = "Bathroom",
		light = { brightness = 1, range = 22 },
		props = {
			{ id = "tub", kind = "Bathtub", x = -11, z = -17.5 },
			{ id = "sink", kind = "Sink", x = 18.25, z = -10, ry = 270 },
			{ id = "toilet", kind = "Toilet", x = 17.75, z = 8, ry = 270 },
		},
		decor = {
			{ id = "mirror", kind = "Mirror", side = "E", along = -10, y = 6 },
		},
		wallSlots = { { side = "S", along = 10 }, { side = "W", along = -10 }, { side = "W", along = 10 } },
		floorSlots = { { x = 8, z = 8 }, { x = -8, z = 8 }, { x = 8, z = -8 } },
		shrine = { x = -16, z = 16 },
	},
	{
		id = "study",
		name = "Study",
		mood = "watched",
		family = "living",
		weight = 2,
		max = 1,
		floor = { material = "OakFloor", color = { 84, 60, 44 } },
		wall = { material = "WallpaperStripe", color = { 112, 122, 102 } },
		wainscot = true,
		reverb = "Room",
		props = {
			{ id = "desk", kind = "Desk", x = 10, z = -17.75 },
			{ id = "books1", kind = "Shelf", x = -18.5, z = -10, ry = 90 },
			{ id = "books2", kind = "Shelf", x = -18.5, z = 10, ry = 90 },
			{ id = "armchair", kind = "Armchair", x = 17, z = 15 },
			{ id = "lamp", kind = "FloorLamp", x = 17, z = -10, key = true },
			{ id = "chair", kind = "Chair", x = 10, z = -13.5 },
		},
		decor = {
			{ id = "painting1", kind = "Painting", side = "S", along = -10, y = 6.5 },
			{ id = "painting2", kind = "Painting", side = "E", along = 10, y = 7 },
		},
		wallSlots = { { side = "S", along = 10 }, { side = "N", along = -10 }, { side = "E", along = -15 } },
		floorSlots = { { x = 8, z = 8 }, { x = -8, z = 8 }, { x = 8, z = -8 }, { x = -8, z = -8 } },
		shrine = { x = -8, z = 16 },
	},
	{
		id = "laundry",
		name = "Laundry",
		mood = "tight",
		family = "utility",
		weight = 1,
		max = 1,
		floor = { material = "CheckerLino", color = { 138, 136, 126 } },
		wall = { material = "OldPlaster", color = { 152, 156, 142 } },
		reverb = "StoneRoom",
		light = { brightness = 0.9, range = 22 },
		props = {
			{ id = "washer", kind = "Washer", x = -14, z = -17.75 },
			{ id = "dryer", kind = "Washer", x = -9.5, z = -17.75 },
			{ id = "shelf", kind = "Shelf", x = 18.5, z = -10, ry = 270 },
			{ id = "locker1", kind = "Locker", x = 10, z = 18, ry = 180 },
			{ id = "locker2", kind = "Locker", x = 14, z = 18, ry = 180 },
			{ id = "heater", kind = "WaterHeater", x = -17, z = 17 },
		},
		decor = {
			{ id = "window", kind = "Window", side = "S", along = -9, y = 6 },
		},
		wallSlots = { { side = "W", along = -10 }, { side = "W", along = 10 }, { side = "N", along = 10 } },
		floorSlots = { { x = 8, z = 8 }, { x = -8, z = 8 }, { x = 8, z = -8 }, { x = -8, z = -8 } },
		shrine = { x = 16, z = 8 },
	},
	{
		id = "garage",
		name = "Garage",
		mood = "open",
		family = "utility",
		weight = 0,
		max = 1,
		roles = { exit = true },
		floor = { material = "StainedConcrete", color = { 112, 112, 108 } },
		wall = { material = "StainedConcrete", color = { 132, 130, 124 } },
		reverb = "StoneRoom",
		light = { brightness = 1.1, range = 28 },
		props = {
			{ id = "car", kind = "Car", x = 16, z = 11 },
			{ id = "bench", kind = "Workbench", x = -10, z = -17.75 },
			{ id = "shelf", kind = "Shelf", x = -18.5, z = 10, ry = 90 },
			{ id = "locker1", kind = "Locker", x = 18, z = -8, ry = 270 },
			{ id = "locker2", kind = "Locker", x = 18, z = -12, ry = 270 },
			{ id = "boxes", kind = "Boxes", x = -16.5, z = -8 },
		},
		decor = {
			{ id = "window", kind = "Window", side = "W", along = -8, y = 6.5 },
		},
		wallSlots = { { side = "N", along = 10 }, { side = "S", along = -10 }, { side = "W", along = -15 } },
		floorSlots = { { x = -8, z = 8 }, { x = 8, z = -8 }, { x = -8, z = -8 } },
		shrine = { x = -14, z = 17 },
	},
	{
		id = "mudroom",
		name = "Mudroom",
		mood = "tight",
		family = "utility",
		weight = 0,
		max = 1,
		roles = { exit = true },
		floor = { material = "Slate", color = { 80, 80, 78 } },
		wall = { material = "Panelling", color = { 112, 88, 64 } },
		reverb = "Room",
		props = {
			{ id = "bench", kind = "Bench", x = -18.25, z = -10, ry = 90 },
			{ id = "coatrack", kind = "CoatRack", x = -17, z = 10 },
			{ id = "locker1", kind = "Locker", x = 10, z = -18 },
			{ id = "locker2", kind = "Locker", x = 14, z = -18 },
			{ id = "boxes", kind = "Boxes", x = 16.5, z = 16.5 },
			{ id = "plant", kind = "Plant", x = -17, z = 17 },
		},
		decor = {
			{ id = "window", kind = "Window", side = "N", along = -10, y = 6 },
			{ id = "painting", kind = "Painting", side = "S", along = 10, y = 6.5 },
		},
		wallSlots = { { side = "E", along = -10 }, { side = "S", along = -10 }, { side = "E", along = 10 } },
		floorSlots = { { x = 8, z = 8 }, { x = -8, z = -8 }, { x = -8, z = 8 } },
		shrine = { x = -10, z = 17 },
	},
	{
		id = "sunroom",
		name = "Sunroom",
		mood = "open",
		family = "windows",
		weight = 1,
		max = 1,
		floor = { material = "CeramicTiles", color = { 150, 130, 110 } },
		wall = { material = "OldPlaster", color = { 178, 174, 154 } },
		reverb = "Room",
		props = {
			{ id = "armchair1", kind = "Armchair", x = -16, z = 16 },
			{ id = "armchair2", kind = "Armchair", x = 16, z = 16 },
			{ id = "plant1", kind = "Plant", x = -17, z = -17 },
			{ id = "plant2", kind = "Plant", x = 17, z = -17 },
			{ id = "curtain", kind = "Curtain", x = -18.75, z = -10, ry = 90 },
			{ id = "bench", kind = "Bench", x = -9, z = 18.25, ry = 180 },
		},
		decor = {
			{ id = "window1", kind = "Window", side = "N", along = -10, y = 6 },
			{ id = "window2", kind = "Window", side = "N", along = 10, y = 6 },
			{ id = "window3", kind = "Window", side = "E", along = -10, y = 6, key = true },
		},
		wallSlots = { { side = "E", along = 10 }, { side = "S", along = 10 }, { side = "W", along = 10 } },
		floorSlots = { { x = 8, z = 8 }, { x = -8, z = 8 }, { x = 8, z = -8 }, { x = -8, z = -8 } },
		shrine = { x = 16, z = 6.5 },
	},
	{
		id = "den",
		name = "Den",
		mood = "tight",
		family = "living",
		weight = 2,
		max = 1,
		floor = { material = "PileCarpet", color = { 92, 76, 62 } },
		wall = { material = "Panelling", color = { 98, 72, 52 } },
		reverb = "LivingRoom",
		props = {
			{ id = "sofa", kind = "Sofa", x = -17.5, z = -9, ry = 90 },
			{ id = "tv", kind = "TVStand", x = 18.5, z = -9, ry = 270, key = true },
			{ id = "cabinet", kind = "Cabinet", x = 10, z = 18, ry = 180 },
			{ id = "desk", kind = "Desk", x = -8, z = -17.75 },
			{ id = "armchair", kind = "Armchair", x = -16, z = 16 },
			{ id = "rug", kind = "Rug", x = 0, z = 0, ry = 90 },
		},
		decor = {
			{ id = "painting", kind = "Painting", side = "W", along = 12, y = 6.5 },
			{ id = "window", kind = "Window", side = "E", along = 12, y = 6 },
		},
		wallSlots = { { side = "N", along = -10 }, { side = "N", along = 10 }, { side = "S", along = -10 } },
		floorSlots = { { x = 8, z = 8 }, { x = 8, z = -8 }, { x = -8, z = 8 } },
		shrine = { x = 16, z = 14 },
	},
	{
		id = "pantry",
		name = "Pantry",
		mood = "tight",
		family = "utility",
		weight = 1,
		max = 1,
		floor = { material = "Slate", color = { 90, 86, 80 } },
		wall = { material = "OldPlaster", color = { 152, 142, 118 } },
		reverb = "Room",
		light = { brightness = 0.8, range = 22 },
		props = {
			{ id = "shelf1", kind = "Shelf", x = -10, z = -18.5 },
			{ id = "shelf2", kind = "Shelf", x = 10, z = -18.5 },
			{ id = "shelf3", kind = "Shelf", x = 18.5, z = 10, ry = 270 },
			{ id = "cupboard", kind = "Cabinet", x = -18, z = 10, ry = 90 },
			{ id = "brooms", kind = "TallCupboard", x = 17.5, z = -14, ry = 270 },
			{ id = "boxes", kind = "Boxes", x = 16.5, z = -8 },
		},
		decor = {
			{ id = "painting", kind = "Painting", side = "W", along = -15, y = 6.5 }, -- clear of the tell slot at -10
		},
		wallSlots = { { side = "S", along = -10 }, { side = "S", along = 10 }, { side = "W", along = -10 } },
		floorSlots = { { x = 8, z = 8 }, { x = -8, z = -8 }, { x = 8, z = -8 } },
		shrine = { x = -16, z = -8 },
	},
	{
		id = "playroom",
		name = "Playroom",
		mood = "open",
		family = "windows",
		weight = 1,
		max = 1,
		floor = { material = "PileCarpet", color = { 112, 130, 100 } },
		wall = { material = "WallpaperStripe", color = { 170, 160, 128 } },
		reverb = "Room",
		props = {
			{ id = "table", kind = "Table", x = 12, z = -16 },
			{ id = "boxes1", kind = "Boxes", x = -16.5, z = -16.5 },
			{ id = "boxes2", kind = "Boxes", x = -16.5, z = 16.5 },
			{ id = "chest", kind = "Chest", x = 10, z = 18, ry = 180 },
			{ id = "lamp", kind = "FloorLamp", x = 17, z = 8, key = true },
		},
		decor = {
			{ id = "painting", kind = "Painting", side = "W", along = -9, y = 6.5 },
		},
		wallSlots = { { side = "E", along = -10 }, { side = "S", along = -10 }, { side = "N", along = -10 } },
		floorSlots = { { x = 8, z = 8 }, { x = -8, z = 8 }, { x = 8, z = -8 }, { x = -8, z = -8 } },
		shrine = { x = 16, z = 16 },
	},
	{
		id = "sewing_room",
		name = "Sewing Room",
		mood = "watched",
		family = "living",
		weight = 1,
		max = 1,
		floor = { material = "OakFloor", color = { 122, 92, 68 } },
		wall = { material = "Wallpaper", color = { 156, 128, 136 } },
		reverb = "Room",
		props = {
			{ id = "dummy1", kind = "Mannequin", x = -16, z = -16 },
			{ id = "dummy2", kind = "Mannequin", x = -12.5, z = -16 },
			{ id = "table", kind = "Table", x = 17, z = -10, ry = 270 },
			{ id = "shelf", kind = "Shelf", x = -10, z = 18.5, ry = 180 },
			{ id = "chair", kind = "Chair", x = 11, z = -10 },
			{ id = "lamp", kind = "FloorLamp", x = 17, z = 17, key = true },
		},
		decor = {
			{ id = "window", kind = "Window", side = "W", along = -10, y = 6 },
			{ id = "painting", kind = "Painting", side = "N", along = -9, y = 6.5 },
			{ id = "painting2", kind = "Painting", side = "E", along = 10, y = 6.5 },
		},
		wallSlots = { { side = "N", along = 10 }, { side = "W", along = 10 }, { side = "S", along = 10 } },
		floorSlots = { { x = 8, z = 8 }, { x = -8, z = 8 }, { x = -8, z = -8 } },
		shrine = { x = -16, z = 12 },
	},
	{
		id = "attic_landing",
		name = "Attic Landing",
		mood = "tight",
		family = "corridor",
		weight = 1,
		max = 1,
		-- The window closes the end of the south arm, so when that arm faces
		-- outside the corridor ends in moonlight.
		corridor = { halfWidth = 7 },
		floor = { material = "OakFloor", color = { 132, 106, 78 } },
		wall = { material = "Panelling", color = { 122, 98, 72 } },
		reverb = "Room",
		light = { brightness = 0.8, range = 22 },
		props = {
			{ id = "wardrobe", kind = "Wardrobe", x = 5.5, z = -13, ry = 270 },
			{ id = "chest", kind = "Chest", x = -13, z = -5.5 },
			{ id = "dummy", kind = "Mannequin", x = 13, z = 5.5 },
		},
		decor = {
			{ id = "window", kind = "Window", side = "S", along = 0, y = 6, key = true },
			{ id = "painting", kind = "Painting", x = -7, z = -13, face = "E", y = 6.5 },
		},
		wallSlots = {
			{ x = 13, z = -7, face = "S" },
			{ x = -13, z = 7, face = "N" },
			{ x = 7, z = 13, face = "W" },
			{ x = -13, z = -7, face = "S" },
		},
		floorSlots = { { x = -5.5, z = -13 }, { x = 5.5, z = 13 }, { x = -13, z = 5.5 }, { x = 13, z = -5.5 } },
		shrine = { x = -5.5, z = 13 },
	},
	{
		id = "music_room",
		name = "Music Room",
		mood = "watched",
		family = "living",
		weight = 1,
		max = 1,
		floor = { material = "OakFloor", color = { 96, 64, 46 } },
		wall = { material = "WallpaperStripe", color = { 94, 102, 126 } },
		wainscot = true,
		reverb = "LivingRoom",
		props = {
			{ id = "piano", kind = "Piano", x = 10, z = -18 },
			{ id = "curtain", kind = "Curtain", x = -10, z = 18.75, ry = 180 },
			{ id = "clock", kind = "GrandfatherClock", x = 18.5, z = 10, ry = 270 },
			{ id = "armchair", kind = "Armchair", x = 16, z = -16 },
			{ id = "stool", kind = "Chair", x = 10, z = -14 },
			{ id = "lamp", kind = "FloorLamp", x = -17, z = -17, key = true },
		},
		decor = {
			{ id = "window", kind = "Window", side = "S", along = 10, y = 6 }, -- the curtain hangs at -10
		},
		wallSlots = { { side = "W", along = -10 }, { side = "W", along = 10 }, { side = "E", along = -8 } },
		floorSlots = { { x = 8, z = 8 }, { x = -8, z = 8 }, { x = -8, z = -8 } },
		shrine = { x = 16, z = 16 },
	},
}

-- The mansion (docs/plans/mansion-generation.md). Which of the templates
-- above it uses and how; the old generator never reads these blocks.
--   floors    floors the room can be on (-1 cellar, 0 ground, 1 upper, 2 attic)
--   zone      hall, public, dining, kitchen, service, private, bath, cellar
--             or attic; or one per floor ({ [0] = ..., [1] = ... }). Doors
--             only join zones that make sense together (MansionHouse.ZoneDoors).
--   reach     a stair that only reaches the cellar or the attic (not one of
--             the main stairs)
--   size      { w, d } in studs, w along the template's x
--   role      start, exit, deliberation, kitchen, stair or corridor; general
--             rooms have none
--   near      templates it likes to share a wall with
--   perFloor  most copies on one floor (a bathroom on each floor, not two downstairs)
--   maxSeams  most walls it can share with other rooms (busy small rooms)
--   sockets   per floor, the template sides that may hold a doorway
--   hides     hiding spots a generated-size room provides (corridor closets)
--   authored  its furniture is placed for its own size, not a 40x40 room
--             (Logic/RoomFit leaves it where it is)
local MansionUse = {
	living_room = { floors = { 0 }, zone = "public", size = { 40, 30 }, weight = 2 },
	study = { floors = { 0, 1 }, zone = { [0] = "public", [1] = "private" }, size = { 30, 20 }, weight = 2 },
	music_room = { floors = { 0 }, zone = "public", size = { 30, 30 }, weight = 1 },
	sunroom = { floors = { 0 }, zone = "public", size = { 30, 30 }, weight = 1 },
	den = { floors = { 0 }, zone = "public", size = { 30, 20 }, weight = 1 },
	pantry = {
		floors = { 0 },
		zone = "kitchen",
		size = { 20, 20 },
		weight = 2,
		near = { "kitchen", "dining_room" },
	},
	laundry = { floors = { 0 }, zone = "service", size = { 20, 30 }, weight = 1, near = { "kitchen" } },
	bathroom = {
		floors = { 0, 1 },
		zone = "bath",
		size = { 30, 20 },
		weight = 2,
		max = 2,
		perFloor = 1,
		maxSeams = 2,
		near = { "master_bedroom", "kids_bedroom", "guest_room" },
	},
	kitchen = { floors = { 0 }, zone = "kitchen", size = { 30, 30 }, role = "kitchen" },
	dining_room = { floors = { 0 }, zone = "dining", size = { 40, 30 }, role = "deliberation" },
	garage = { floors = { 0 }, zone = "service", size = { 40, 40 }, role = "exit" },
	mudroom = { floors = { 0 }, zone = "service", size = { 20, 30 }, role = "exit" },
	master_bedroom = { floors = { 1 }, zone = "private", size = { 30, 30 }, weight = 2, near = { "bathroom" } },
	kids_bedroom = { floors = { 1 }, zone = "private", size = { 30, 30 }, weight = 2 },
	guest_room = { floors = { 1 }, zone = "private", size = { 20, 30 }, weight = 2, max = 2 },
	nursery = { floors = { 1 }, zone = "private", size = { 20, 20 }, weight = 1, near = { "master_bedroom" } },
	playroom = { floors = { 1 }, zone = "private", size = { 30, 20 }, weight = 1 },
	sewing_room = { floors = { 1 }, zone = "private", size = { 30, 20 }, weight = 1 },
}

-- The cellar (docs/plans/level-design.md section 10.2): mansion-only rooms
-- under the ground floor, reached by the cellar stair off the kitchen side
-- and by the back stairs carried down. Stone and whitewash, bare bulbs and
-- joists overhead, no windows. Their furniture is authored for a 40x40 room
-- and fitted to theirs (Logic/RoomFit), like the old templates.
local CellarRooms = {
	{
		id = "boiler_room",
		name = "Boiler Room",
		mood = "tight",
		family = "utility",
		fixture = "bulb",
		joists = true,
		floor = { material = "StainedConcrete", color = { 98, 96, 92 } },
		wall = { material = "Brick", color = { 150, 138, 120 } },
		ceiling = { material = "WoodPlanks", color = { 84, 66, 50 } },
		reverb = "StoneRoom",
		light = { brightness = 1.1, range = 26, color = { 232, 194, 126 } },
		props = {
			{ id = "boiler", kind = "Boiler", x = -11, z = -16.5 },
			{ id = "heater", kind = "WaterHeater", x = -17.5, z = -8 },
			{ id = "shelf", kind = "Shelf", x = 18.5, z = 10, ry = 270 },
			{ id = "locker", kind = "Locker", x = 10, z = 17.5, ry = 180 },
			{ id = "boxes", kind = "Boxes", x = 15, z = -16 },
		},
		decor = {},
		wallSlots = { { side = "W", along = 10 }, { side = "E", along = -10 }, { side = "S", along = -10 } },
		floorSlots = { { x = 8, z = 8 }, { x = -8, z = 8 }, { x = 8, z = -8 } },
		shrine = { x = 16, z = 16 },
		mansion = { floors = { -1 }, zone = "cellar", size = { 30, 30 }, weight = 3 },
	},
	{
		id = "wine_cellar",
		name = "Wine Cellar",
		mood = "tight",
		family = "utility",
		fixture = "bulb",
		joists = true,
		floor = { material = "Slate", color = { 82, 78, 74 } },
		wall = { material = "Brick", color = { 128, 104, 88 } },
		ceiling = { material = "WoodPlanks", color = { 78, 60, 46 } },
		reverb = "StoneRoom",
		light = { brightness = 1, range = 24, color = { 232, 194, 126 } },
		props = {
			{ id = "rack1", kind = "WineRack", x = -11, z = -18.5 },
			{ id = "rack2", kind = "WineRack", x = 11, z = -18.5 },
			{ id = "rack3", kind = "WineRack", x = -18.5, z = 10, ry = 90 },
			{ id = "rack4", kind = "WineRack", x = 18.5, z = 10, ry = 270 },
			{ id = "cabinet", kind = "Cabinet", x = -11, z = 17.5, ry = 180 },
			{ id = "cupboard", kind = "TallCupboard", x = 6, z = 17.5, ry = 180 },
			{ id = "crate", kind = "Chest", x = 11, z = 17.5, ry = 180 },
		},
		decor = {},
		wallSlots = { { side = "W", along = -10 }, { side = "E", along = -10 }, { side = "S", along = -16 } },
		floorSlots = { { x = 8, z = 8 }, { x = -8, z = 8 }, { x = -8, z = -8 } },
		shrine = { x = 16, z = 16 },
		mansion = { floors = { -1 }, zone = "cellar", size = { 20, 30 }, weight = 2 },
	},
	{
		id = "storeroom",
		name = "Storeroom",
		mood = "tight",
		family = "utility",
		fixture = "bulb",
		joists = true,
		floor = { material = "StainedConcrete", color = { 108, 104, 98 } },
		wall = { material = "OldPlaster", color = { 168, 164, 150 } },
		ceiling = { material = "WoodPlanks", color = { 88, 70, 54 } },
		reverb = "StoneRoom",
		light = { brightness = 1.05, range = 26, color = { 232, 194, 126 } },
		props = {
			{ id = "shelf1", kind = "Shelf", x = -12, z = -18.5 },
			{ id = "shelf2", kind = "Shelf", x = 12, z = -18.5 },
			{ id = "wardrobe", kind = "Wardrobe", x = -18, z = 10, ry = 90 },
			{ id = "boxes1", kind = "Boxes", x = 15, z = 16 },
			{ id = "boxes2", kind = "Boxes", x = -10, z = 16 },
			{ id = "trunk", kind = "Chest", x = 18, z = -8, ry = 270 },
			{ id = "form", kind = "Mannequin", x = 17.5, z = 10 },
		},
		decor = {},
		wallSlots = { { side = "W", along = -10 }, { side = "E", along = 16 }, { side = "S", along = -16 } },
		floorSlots = { { x = 8, z = 8 }, { x = -8, z = 8 }, { x = 8, z = -8 } },
		shrine = { x = -16, z = -10 },
		mansion = { floors = { -1 }, zone = "cellar", size = { 30, 20 }, weight = 2 },
	},
	{
		id = "workshop",
		name = "Workshop",
		mood = "tight",
		family = "utility",
		fixture = "bulb",
		joists = true,
		floor = { material = "StainedConcrete", color = { 100, 98, 94 } },
		wall = { material = "Brick", color = { 140, 132, 118 } },
		ceiling = { material = "WoodPlanks", color = { 84, 66, 50 } },
		reverb = "StoneRoom",
		light = { brightness = 1.15, range = 26, color = { 232, 194, 126 } },
		props = {
			{ id = "bench", kind = "Workbench", x = -10, z = -17.75 },
			{ id = "shelf", kind = "Shelf", x = 18.5, z = -10, ry = 270 },
			{ id = "locker1", kind = "Locker", x = 10, z = 17.5, ry = 180 },
			{ id = "locker2", kind = "Locker", x = 14, z = 17.5, ry = 180 },
			{ id = "boxes", kind = "Boxes", x = -16, z = 16 },
			{ id = "trunk", kind = "Chest", x = -18, z = 9, ry = 90 },
		},
		decor = {},
		wallSlots = { { side = "E", along = 10 }, { side = "W", along = -10 }, { side = "N", along = 12 } },
		floorSlots = { { x = 8, z = 8 }, { x = -8, z = 8 }, { x = 8, z = -8 } },
		shrine = { x = 16, z = -16 },
		mansion = { floors = { -1 }, zone = "cellar", size = { 30, 20 }, weight = 2 },
	},
	{
		id = "cold_store",
		name = "Cold Store",
		mood = "tight",
		family = "utility",
		joists = true,
		floor = { material = "StainedConcrete", color = { 116, 118, 116 } },
		wall = { material = "OldPlaster", color = { 176, 180, 176 } },
		ceiling = { material = "WoodPlanks", color = { 88, 70, 54 } },
		reverb = "StoneRoom",
		light = { brightness = 1, range = 24 },
		props = {
			{ id = "shelf1", kind = "Shelf", x = -12, z = -18.5 },
			{ id = "shelf2", kind = "Shelf", x = 18.5, z = -10, ry = 270 },
			{ id = "cabinet", kind = "Cabinet", x = -18, z = 10, ry = 90 },
			{ id = "cupboard", kind = "TallCupboard", x = -17.5, z = -8, ry = 90 },
			{ id = "freezer", kind = "Chest", x = 11, z = 17.5, ry = 180 },
			{ id = "boxes", kind = "Boxes", x = -10, z = 16 },
		},
		decor = {},
		wallSlots = { { side = "N", along = 12 }, { side = "S", along = -16 }, { side = "E", along = 10 } },
		floorSlots = { { x = 8, z = 8 }, { x = -8, z = 8 }, { x = 8, z = -8 } },
		shrine = { x = 16, z = 16 },
		mansion = { floors = { -1 }, zone = "cellar", size = { 20, 20 }, weight = 1 },
	},
}

-- The attic (docs/plans/level-design.md section 10.3): mansion-only rooms
-- under the roof, reached by the attic stair from the upper floor and by the
-- back stairs carried up. Bare boards that creak (`creaks`: footsteps carry
-- further), a sloped roof on rafters (`rafters`), bare bulbs, the family's
-- old things. Nothing stands taller than the roof's low side (7 studs).
local AtticRooms = {
	{
		id = "box_room",
		name = "Box Room",
		mood = "tight",
		family = "attic",
		fixture = "bulb",
		rafters = true,
		creaks = 1.5,
		floor = { material = "WoodPlanks", color = { 96, 76, 58 } },
		wall = { material = "OldPlaster", color = { 146, 136, 118 } },
		ceiling = { material = "WoodPlanks", color = { 82, 64, 48 } },
		reverb = "Room",
		light = { brightness = 1.05, range = 26, color = { 232, 194, 126 } },
		props = {
			{ id = "table", kind = "Table", x = 11, z = 16.5, ry = 180 },
			{ id = "trunk1", kind = "Chest", x = -11, z = -17.5 },
			{ id = "trunk2", kind = "Chest", x = 11, z = -17.5 },
			{ id = "trunk3", kind = "Chest", x = -18, z = 10, ry = 90 },
			{ id = "boxes1", kind = "Boxes", x = 16, z = -8 },
			{ id = "crib", kind = "Crib", x = -16.5, z = -9, ry = 90 },
			{ id = "form", kind = "Mannequin", x = 17.5, z = 10 },
			{ id = "boxes2", kind = "Boxes", x = -10, z = 16 },
		},
		decor = {},
		wallSlots = { { side = "W", along = -16 }, { side = "E", along = 16 }, { side = "N", along = 16 } },
		floorSlots = { { x = 8, z = 8 }, { x = -8, z = 8 }, { x = 8, z = -8 } },
		shrine = { x = -16, z = -16 },
		mansion = { floors = { 2 }, zone = "attic", size = { 30, 30 }, weight = 3 },
	},
	{
		id = "servants_room",
		name = "Servants' Room",
		mood = "tight",
		family = "bedroom",
		fixture = "bulb",
		rafters = true,
		creaks = 1.5,
		floor = { material = "WoodPlanks", color = { 100, 80, 60 } },
		wall = { material = "Wallpaper", color = { 132, 120, 104 } },
		ceiling = { material = "WoodPlanks", color = { 86, 68, 50 } },
		reverb = "Room",
		light = { brightness = 1, range = 24, color = { 232, 194, 126 } },
		props = {
			{ id = "bed", kind = "Bed", x = -15.5, z = -12 },
			{ id = "dresser", kind = "Dresser", x = 11, z = -18.25 },
			{ id = "trunk", kind = "Chest", x = 18, z = 10, ry = 270 },
			{ id = "coatrack", kind = "CoatRack", x = -17.5, z = 16 },
			{ id = "lamp", kind = "FloorLamp", x = 17.5, z = -17.5 },
			{ id = "boxes", kind = "Boxes", x = 10, z = 16 },
		},
		decor = {},
		wallSlots = { { side = "E", along = -10 }, { side = "S", along = -12 }, { side = "N", along = -12 } },
		floorSlots = { { x = 8, z = 8 }, { x = -8, z = 8 }, { x = 8, z = -8 } },
		shrine = { x = 16, z = 16 },
		mansion = { floors = { 2 }, zone = "attic", size = { 20, 30 }, weight = 2 },
	},
	{
		id = "tank_room",
		name = "Water Tank Room",
		mood = "tight",
		family = "utility",
		fixture = "bulb",
		rafters = true,
		creaks = 1.5,
		floor = { material = "WoodPlanks", color = { 90, 72, 56 } },
		wall = { material = "OldPlaster", color = { 156, 150, 134 } },
		ceiling = { material = "WoodPlanks", color = { 80, 62, 46 } },
		reverb = "Room",
		light = { brightness = 1, range = 22, color = { 232, 194, 126 } },
		props = {
			{ id = "tank", kind = "WaterTank", x = -11, z = -17 },
			{ id = "table", kind = "Table", x = 11, z = 16.5, ry = 180 },
			{ id = "boxes", kind = "Boxes", x = 16, z = -8 },
			{ id = "trunk", kind = "Chest", x = -18, z = 10, ry = 90 },
		},
		decor = {},
		wallSlots = { { side = "W", along = -16 }, { side = "E", along = 10 }, { side = "S", along = -12 } },
		floorSlots = { { x = 8, z = 8 }, { x = -8, z = 8 }, { x = 8, z = -8 } },
		shrine = { x = -16, z = 16 },
		mansion = { floors = { 2 }, zone = "attic", size = { 20, 20 }, weight = 1 },
	},
	{
		id = "lumber_room",
		name = "Lumber Room",
		mood = "tight",
		family = "attic",
		fixture = "bulb",
		rafters = true,
		creaks = 1.5,
		floor = { material = "WoodPlanks", color = { 94, 74, 56 } },
		wall = { material = "OldPlaster", color = { 140, 132, 116 } },
		ceiling = { material = "WoodPlanks", color = { 80, 62, 46 } },
		reverb = "Room",
		light = { brightness = 1, range = 24, color = { 232, 194, 126 } },
		props = {
			{ id = "table", kind = "Table", x = -11, z = -17 },
			{ id = "boxes1", kind = "Boxes", x = 11, z = -16 },
			{ id = "boxes2", kind = "Boxes", x = 16, z = -16 },
			{ id = "chair", kind = "Armchair", x = -16, z = 10 },
			{ id = "crib", kind = "Crib", x = 17, z = 9, ry = 270 },
			{ id = "trunk", kind = "Chest", x = 10, z = 17.5, ry = 180 },
			{ id = "form", kind = "Mannequin", x = -10, z = 17 },
		},
		decor = {},
		wallSlots = { { side = "W", along = -10 }, { side = "E", along = -10 }, { side = "S", along = 15 } },
		floorSlots = { { x = 8, z = 8 }, { x = -8, z = 8 }, { x = 8, z = -8 } },
		shrine = { x = -16, z = -8 },
		mansion = { floors = { 2 }, zone = "attic", size = { 30, 20 }, weight = 2 },
	},
}

-- Rooms only the mansion has. Their furniture is a placeholder until the
-- furnishing phase (M4); corridors get their size from the generator.
local MansionExtras = {
	{
		id = "grand_hall",
		name = "Grand Hall",
		mood = "open",
		family = "living",
		-- Double height. A split staircase rises from the middle to a half landing
		-- on the north wall, then up both sides to a gallery along the north,
		-- east and west walls. The front door (south) shuts behind the squad.
		floor = { material = "OakFloor", color = { 92, 64, 46 } },
		wall = { material = "Panelling", color = { 104, 78, 56 } },
		wainscot = true,
		reverb = "Auditorium",
		light = { brightness = 1.2, range = 30 },
		props = {
			{ id = "curtain1", kind = "Curtain", x = -12, z = 23.75, ry = 180 },
			{ id = "curtain2", kind = "Curtain", x = 12, z = 23.75, ry = 180 },
			{ id = "clock", kind = "GrandfatherClock", x = -18.5, z = 10, ry = 90 },
			{ id = "coatrack", kind = "CoatRack", x = 17, z = 21 },
			{ id = "rug", kind = "Rug", x = 0, z = 13 },
		},
		decor = {
			{ id = "portrait", kind = "Painting", side = "E", along = 12, y = 6.5 },
		},
		caseBoard = { side = "W", along = 16 },
		spawns = { { x = -4, z = 15 }, { x = 4, z = 15 }, { x = -4, z = 19 }, { x = 4, z = 19 } },
		wallSlots = { { side = "E", along = -6 }, { side = "W", along = -6 }, { side = "S", along = -14 } },
		floorSlots = { { x = 10, z = 4 }, { x = -10, z = 4 }, { x = 10, z = 16 } },
		shrine = { x = -16, z = 18 },
		mansion = {
			role = "start",
			authored = true,
			tall = true,
			floors = { 0, 1 },
			zone = "hall",
			size = { 40, 50 },
			sockets = { [0] = { N = true, E = true, W = true }, [1] = { N = true, E = true, W = true } },
			frontDoor = "S",
		},
	},
	{
		id = "back_stairs",
		name = "Back Stairs",
		mood = "tight",
		family = "corridor",
		-- A dog-leg stair: both flights start and end at the south end, so the
		-- doorway on each floor is in the south wall.
		floor = { material = "OakFloor", color = { 96, 72, 52 } },
		wall = { material = "OldPlaster", color = { 150, 144, 120 } },
		reverb = "Hallway",
		light = { brightness = 0.8, range = 20 },
		props = {},
		decor = {},
		wallSlots = {},
		floorSlots = {},
		shrine = { x = 0, z = 10 },
		mansion = {
			role = "stair",
			authored = true,
			tall = true,
			-- (The generator carries it down to the cellar and up to the attic
			-- when the house has them.)
			floors = { 0, 1 },
			zone = { [-1] = "cellar", [0] = "service", [1] = "private", [2] = "attic" },
			size = { 20, 30 },
			sockets = {
				[-1] = { S = true },
				[0] = { S = true },
				[1] = { S = true },
				[2] = { S = true },
			},
		},
	},
	{
		id = "cellar_stair",
		name = "Cellar Stairs",
		mood = "tight",
		family = "corridor",
		fixture = "bulb",
		-- A dog-leg down from a door off the kitchen side to the cellar; its
		-- doorway on both storeys is in the south wall.
		floor = { material = "OakFloor", color = { 82, 62, 46 } },
		wall = { material = "Brick", color = { 146, 136, 118 } },
		reverb = "StoneRoom",
		light = { brightness = 1, range = 22, color = { 232, 194, 126 } },
		props = {},
		decor = {},
		wallSlots = {},
		floorSlots = {},
		shrine = { x = 0, z = 10 },
		mansion = {
			role = "stair",
			reach = "cellar",
			authored = true,
			tall = true,
			floors = { -1, 0 },
			zone = { [-1] = "cellar", [0] = "service" },
			size = { 20, 30 },
			sockets = { [-1] = { S = true }, [0] = { S = true } },
		},
	},

	{
		id = "attic_stair",
		name = "Attic Stairs",
		mood = "tight",
		family = "corridor",
		fixture = "bulb",
		-- A dog-leg up from a door off the upper floor to the attic; its
		-- doorway on both storeys is in the south wall.
		floor = { material = "WoodPlanks", color = { 92, 72, 54 } },
		wall = { material = "OldPlaster", color = { 150, 140, 122 } },
		reverb = "Hallway",
		light = { brightness = 1, range = 22, color = { 232, 194, 126 } },
		props = {},
		decor = {},
		wallSlots = {},
		floorSlots = {},
		shrine = { x = 0, z = 10 },
		mansion = {
			role = "stair",
			reach = "attic",
			authored = true,
			tall = true,
			floors = { 1, 2 },
			zone = { [1] = "private", [2] = "attic" },
			size = { 20, 30 },
			sockets = { [1] = { S = true }, [2] = { S = true } },
		},
	},
	{
		id = "stairwell",
		name = "Stairwell",
		mood = "tight",
		family = "corridor",
		floor = { material = "OakFloor", color = { 104, 78, 56 } },
		wall = { material = "WallpaperStripe", color = { 132, 120, 98 } },
		reverb = "Hallway",
		light = { brightness = 0.8, range = 20 },
		props = {},
		decor = {},
		wallSlots = {},
		floorSlots = {},
		shrine = { x = 0, z = 10 },
		mansion = {
			role = "stair",
			authored = true,
			tall = true,
			floors = { 0, 1 },
			zone = { [0] = "public", [1] = "private" },
			size = { 20, 30 },
			sockets = { [0] = { S = true }, [1] = { S = true } },
		},
	},
	{
		id = "servants_passage",
		name = "Servants' Passage",
		mood = "tight",
		family = "corridor",
		fixture = "bulb",
		-- A narrow way behind the walls (docs/plans/level-design.md section
		-- 10.4), entered only by hidden doors; the generator sizes it.
		floor = { material = "WoodPlanks", color = { 84, 66, 50 } },
		wall = { material = "OldPlaster", color = { 126, 118, 104 } },
		reverb = "Hallway",
		light = { brightness = 0.75, range = 18, color = { 232, 194, 126 } },
		props = {},
		decor = {},
		wallSlots = {},
		floorSlots = {},
		mansion = { role = "passage", floors = { 0, 1 }, zone = "passage" },
	},
	{
		id = "main_corridor",
		name = "Hallway",
		mood = "watched",
		family = "corridor",
		floor = { material = "OakFloor", color = { 104, 76, 54 } },
		wall = { material = "WallpaperStripe", color = { 150, 134, 106 } },
		wainscot = true,
		reverb = "CarpettedHallway",
		light = { brightness = 0.9, range = 22 },
		-- Two walk-in closets, one on each long wall and staggered, so the
		-- way narrows to about 12 and a hallway has somewhere to hide
		-- (docs/plans/level-design.md section 10.7). They were promised as
		-- `hides` since M1 and counted, but never built.
		props = {
			{ id = "closet1", kind = "Closet", x = -17.5, z = -9, ry = 90 },
			{ id = "closet2", kind = "Closet", x = 17.5, z = 9, ry = 270 },
		},
		decor = {},
		wallSlots = {},
		floorSlots = {},
		mansion = { role = "corridor", floors = { 0 }, zone = "public" },
	},
	{
		id = "service_corridor",
		name = "Service Passage",
		mood = "tight",
		family = "corridor",
		floor = { material = "CheckerLino", color = { 132, 128, 114 } },
		wall = { material = "OldPlaster", color = { 160, 156, 130 } },
		reverb = "Hallway",
		light = { brightness = 0.85, range = 22 },
		-- Two walk-in closets, one on each long wall and staggered, so the
		-- way narrows to about 12 and a hallway has somewhere to hide
		-- (docs/plans/level-design.md section 10.7). They were promised as
		-- `hides` since M1 and counted, but never built.
		props = {
			{ id = "closet1", kind = "Closet", x = -17.5, z = -9, ry = 90 },
			{ id = "closet2", kind = "Closet", x = 17.5, z = 9, ry = 270 },
		},
		decor = {},
		wallSlots = {},
		floorSlots = {},
		mansion = { role = "corridor", floors = { 0 }, zone = "service" },
	},
	{
		id = "upper_corridor",
		name = "Upper Hall",
		mood = "watched",
		family = "corridor",
		floor = { material = "PileCarpet", color = { 98, 74, 70 } },
		wall = { material = "Wallpaper", color = { 140, 118, 110 } },
		reverb = "CarpettedHallway",
		light = { brightness = 0.85, range = 22 },
		-- Two walk-in closets, one on each long wall and staggered, so the
		-- way narrows to about 12 and a hallway has somewhere to hide
		-- (docs/plans/level-design.md section 10.7). They were promised as
		-- `hides` since M1 and counted, but never built.
		props = {
			{ id = "closet1", kind = "Closet", x = -17.5, z = -9, ry = 90 },
			{ id = "closet2", kind = "Closet", x = 17.5, z = 9, ry = 270 },
		},
		decor = {},
		wallSlots = {},
		floorSlots = {},
		mansion = { role = "corridor", floors = { 1 }, zone = "private" },
	},
}

local byId = {}
for _, template in Rooms do
	template.roles = template.roles or {}
	byId[template.id] = template
end

local mansion, mansionById = {}, {}
for _, template in Rooms do
	template.mansion = MansionUse[template.id]
	if template.mansion then
		table.insert(mansion, template)
		mansionById[template.id] = template
	end
end
for _, list in { MansionExtras, CellarRooms, AtticRooms } do
	for _, template in list do
		template.roles = {}
		template.weight = 0
		template.max = 1
		table.insert(mansion, template)
		mansionById[template.id] = template
	end
end

return {
	List = Rooms,
	ById = byId,
	-- Every template the mansion generator can use, and the mansion-only ones.
	Mansion = mansion,
	MansionById = mansionById,
	MansionExtras = MansionExtras,
	-- The mansion's own general rooms (the cellar's and the attic's),
	-- furnished like the old templates and checked by the same rules
	-- (Rooms.spec).
	MansionRooms = table.move(AtticRooms, 1, #AtticRooms, #CellarRooms + 1, table.clone(CellarRooms)),
}
