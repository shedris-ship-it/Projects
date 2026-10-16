-- The kit: modelled pieces from Blender (tools/blender/kit.py) that dress
-- PropFactory's grey-box (the visual rework; World/Kit). A kind listed here
-- with an `id` wears its mesh; any other kind stays as blocks, so the kit can
-- arrive a batch at a time.
--
-- How a piece gets here (V0, settled 2026-10-12): the owner imports a batch
-- with Studio's 3D importer, which uploads its meshes and maps to their
-- account. The mesh's asset id goes in `id`: the server builds the mesh from
-- it at start (AssetService:CreateMeshPartAsync; Rojo can't set a MeshId).
-- Its four maps go in assets/kit/<mesh>.model.json, a SurfaceAppearance that
-- Rojo syncs as ReplicatedStorage.Kit.<mesh> (game scripts can't set a
-- SurfaceAppearance's maps; plugins and `rojo build` can).
--
-- mesh:  the piece's name (its SurfaceAppearance's in ReplicatedStorage.Kit)
-- id:    its mesh's asset id (none yet: the piece isn't imported)
-- size:  the size it was modelled at, in studs { x, y, z } (kit.py's
--        report): World/Kit fits it to the prop's own size, and Kit.spec
--        checks they agree, so nothing is stretched out of shape
-- centre: where the middle of its box sits in the prop's frame, { x, z } with
--        the front +Z (kit.py's report): the importer centres a mesh on its
--        box, so a lopsided one (a cornice overhanging the front) would sit
--        off the grey-box; none: { 0, 0 }
-- keep:  the grey-box parts that stay visible because the game draws on them
--        or animates them (a clock's face and hands, a screen)
-- names: the item names (Lua patterns, Data/Rooms ids) that wear it, when the
--        kind stands for more than one thing (a Shelf is also a china
--        cabinet and a pantry's shelving); none: every item of the kind
-- shadow: false for a piece that mustn't cast one (a lamp, whose shade would
--        hide its own bulb's light)
-- turn:  degrees about Y if a piece faces another way (0: its front is +Z in
--        kit.py, which World/Kit turns to meet the importer)
-- pieces: a prop's moving pieces' own meshes, each hung on its piece's main
--        part (a drawer's Front, a chest's Lid): `match` (the piece's model
--        name, a Lua pattern), `mesh`, `id`, `size`, `at` (where its box's
--        middle is from that part's middle, { x, y, z }: kit.py's report) and
--        `hide` (the piece's grey-box parts it stands for)
-- each:  instead of one mesh for the prop, one on each part whose name
--        matches (`match`), fitted to that part (the boxes in a stack)
-- others: more entries for the same kind, each with its own `names` (a Shelf
--        is a bookcase, a china cabinet or steel shelving): an item wears
--        the first that names it
-- floor: the bottom of its box above the floor (a curtain hangs clear of it)
-- rises: it stands taller than its kind (a TV on its stand: things stand on
--        tops, so only the footprint is held to the kind's size)
-- fit:   (Parts) "scale": the whole piece scaled to the part's width
-- query: (Things) its mesh catches the hands' ray, for a thing whose
--        grey-box never collides (a radio, a kettle)

return {
	Props = {
		-- The spike (tools/blender/kit.py spike; imported 2026-10-12, again
		-- with the lamp shade's glow mask).
		-- (Not the nursery's rocker or the music room's stool.)
		Chair = {
			mesh = "Chair",
			id = 94660495904035,
			size = { 2.5, 4.02, 2.42 },
			names = { "^chair" },
			centre = { 0, -0.042 },
			-- kit.py kit4: the nursery's rocking chair, the music room's stool.
			others = {
				{
					names = { "^rocker" },
					mesh = "Rocker",
					id = 102228877288522,
					size = { 2.39, 3.98, 2.44 },
					floor = 0.021,
				},
				{
					names = { "^stool" },
					mesh = "Stool",
					id = 98570492499744,
					size = { 1.82, 2.2, 1.75 },
					centre = { 0.081, 0 },
					floor = 0.03,
				},
			},
		},
		-- Its bulb shines through the linen all round, as the old block shade let
		-- it (the owner, 2026-10-12: a shade that shadows its own bulb only lets
		-- light out of the bottom): no shadow from the lamp itself.
		FloorLamp = { mesh = "FloorLamp", id = 115301339552852, size = { 1.5, 5.95, 1.5 }, shadow = false },
		-- The golden room (kit.py golden; imported 2026-10-12): the grand hall,
		-- the dining room, the living room.
		DiningTable = { mesh = "DiningTable", id = 89708986746860, size = { 6, 3.4, 12 } },
		Sofa = { mesh = "Sofa", id = 112802030819273, size = { 9, 3.5, 3.97 }, centre = { 0, -0.012 } },
		Armchair = { mesh = "Armchair", id = 79903202176202, size = { 4, 4, 3.97 }, centre = { 0, -0.012 } },
		-- The living room's and the study's bookcases only (the china cabinet and
		-- the utility rooms' shelving wait for their own).
		Shelf = {
			mesh = "Shelf",
			id = 76759148172076,
			size = { 8.2, 9, 2.12 },
			names = { "^books" },
			centre = { 0, 0.06 },
			-- kit.py kit4: the dining room's china cabinet; the utility rooms'
			-- steel shelving (the pantry, laundry, garage, storerooms).
			others = {
				{
					names = { "^china" },
					mesh = "ChinaCabinet",
					id = 85964663679049,
					size = { 8.1, 8.92, 2.13 },
					centre = { 0, 0.065 },
				},
				{ names = { "^shelf" }, mesh = "UtilityShelf", id = 133643658880042, size = { 8, 9, 2 } },
			},
		},
		-- The case only: the face, hands, pendulum and glass are the game's own.
		GrandfatherClock = {
			mesh = "GrandfatherClock",
			id = 87290908046199,
			size = { 2.66, 8.38, 2.14 },
			centre = { 0, 0.01 },
			keep = { "Bezel", "Dial", "Tick", "HourHand", "MinuteHand", "Cap", "Pendulum", "Door" },
		},
		CoatRack = { mesh = "CoatRack", id = 90933748796114, size = { 1.32, 7, 1.32 } },
		Bench = { mesh = "Bench", id = 137534368415543, size = { 8, 2.6, 2.3 } },
		Rug = { mesh = "Rug", id = 138678122533642, size = { 10, 0.06, 14.76 } },
		-- kit.py golden2: the living room's brick fireplace. Its embers glow (an
		-- emissive mask the fire drives: Controllers/FireController); it keeps
		-- its shadow, so the fire lights the room out of the opening only.
		Fireplace = { mesh = "Fireplace", id = 96892886241539, size = { 7, 4.42, 2.4 }, keep = { "Firebox" } },
		-- kit.py kit3 (the V4 rollout's first batch: the halls and bedrooms).
		Plant = { mesh = "Plant", id = 139600462191881, size = { 1.68, 4.48, 1.87 }, centre = { 0.031, -0.002 } },
		-- Its drawers' fronts are their own (they slide out); the dark slot
		-- behind an open one is the game's.
		Dresser = {
			mesh = "Dresser",
			id = 115378518543178,
			size = { 6, 3.6, 2.5 },
			keep = { "Slot" },
			pieces = {
				{
					match = "^Drawer%d",
					mesh = "DresserDrawer",
					id = 72312584490027,
					size = { 5.5, 0.88, 0.24 },
					at = { 0, 0, 0.068 },
					hide = { "Front", "Knob" },
				},
			},
		},
		Chest = {
			mesh = "Chest",
			id = 82192598903046,
			size = { 5.05, 2.4, 3 },
			pieces = {
				{
					match = "^Lid$",
					mesh = "ChestLid",
					id = 92806527760040,
					size = { 5.1, 0.95, 3.09 },
					at = { 0, -0.175, 0.02 },
					hide = { "Lid", "Latch" },
				},
			},
		},
		Boxes = { each = { match = "^Box%d", mesh = "Box", id = 79591403484128, size = { 4, 1.61, 4.02 } } },
		-- kit.py kit4 (V4c: the living rooms, the study, the bedrooms). The TV's
		-- glowing screen is the game's (its light, and its static:
		-- Controllers/TVController); the set stands on the stand.
		TVStand = { mesh = "TVStand", id = 80803329437718, size = { 6, 8.05, 2 }, rises = true, keep = { "Screen" } },
		-- Its cloth hangs to the hem you look out under (World/PropFactory's
		-- ClothHem), and shows from inside.
		Table = { mesh = "Table", id = 108062801152470, size = { 8.24, 3.42, 5.24 } },
		Desk = {
			mesh = "Desk",
			id = 103740615913609,
			size = { 7, 3.41, 3.5 },
			keep = { "Slot" },
			pieces = {
				{
					match = "^Drawer1$",
					mesh = "DeskDrawerDeep",
					id = 124630045896062,
					size = { 2, 1.8, 0.2 },
					at = { 0, 0, 0.05 },
					hide = { "Front", "Pull" },
				},
				{
					match = "^Drawer2$",
					mesh = "DeskDrawerShallow",
					id = 102473637137198,
					size = { 2, 0.95, 0.2 },
					at = { 0, 0, 0.05 },
					hide = { "Front", "Pull" },
				},
			},
		},
		Cabinet = {
			mesh = "Cabinet",
			id = 102191614656122,
			size = { 6.02, 7.99, 3.2 },
			centre = { 0, 0.1 },
			pieces = {
				{
					match = "^DoorL$",
					mesh = "CabinetDoorL",
					id = 105495898012377,
					size = { 2.97, 7.4, 0.31 },
					at = { 0, 0, 0.081 },
					hide = { "Door", "Handle" },
				},
				{
					match = "^DoorR$",
					mesh = "CabinetDoorR",
					id = 93193123209018,
					size = { 2.97, 7.4, 0.31 },
					at = { 0, 0, 0.081 },
					hide = { "Door", "Handle" },
				},
			},
		},
		-- Its doors' louvres are at the eye, as the game's (its unseen Screen
		-- still stops his sight); each door hangs on its leaf below them.
		Wardrobe = {
			mesh = "Wardrobe",
			id = 135053210081745,
			size = { 6.02, 8.99, 3.2 },
			centre = { 0, 0.1 },
			pieces = {
				{
					match = "^DoorL$",
					mesh = "WardrobeDoorL",
					id = 83824722833978,
					size = { 2.97, 8.4, 0.31 },
					at = { 0, 2.375, 0.081 },
					hide = { "Door", "DoorTop", "Stile", "Louvre", "Handle" },
				},
				{
					match = "^DoorR$",
					mesh = "WardrobeDoorR",
					id = 97677335504663,
					size = { 2.97, 8.4, 0.31 },
					at = { 0, 2.375, 0.081 },
					hide = { "Door", "DoorTop", "Stile", "Louvre", "Handle" },
				},
			},
		},
		-- Parted in the middle where you look out (World/PropFactory's gap).
		Curtain = {
			mesh = "Curtain",
			id = 80084167410172,
			size = { 6.4, 9.74, 1.41 },
			centre = { 0, -0.046 },
			floor = 0.12,
		},
		Piano = { mesh = "Piano", id = 112085447283801, size = { 7, 5, 3.03 }, centre = { 0, -0.013 } },
		Mannequin = {
			mesh = "DressForm",
			id = 75814638297274,
			size = { 1.63, 6.49, 1.43 },
			centre = { 0, -0.208 },
			floor = 0.005,
		},
		-- kit.py kit5 (V4c: the bedrooms, the bathroom, the kitchen, the utility
		-- rooms). The bed's spread falls to the hem you look out under.
		Bed = { mesh = "Bed", id = 130066686188423, size = { 7, 5.05, 10.14 }, rises = true, centre = { 0, 0.08 } },
		-- Its mirrored doors slide on their tracks; the mirror is the game's.
		Closet = {
			mesh = "Closet",
			id = 85190350209587,
			size = { 6, 9, 4 },
			pieces = {
				{
					match = "^Door[LR]$",
					mesh = "ClosetDoor",
					id = 77820573958168,
					size = { 3.1, 8.2, 0.18 },
					at = { 0, 0, 0.04 },
					hide = { "Door" },
				},
			},
		},
		Crib = { mesh = "Crib", id = 105189608991210, size = { 5, 4.1, 3 } },
		-- Step in and look out through the louvres at the eye; each door hangs
		-- on its leaf below them.
		Locker = {
			mesh = "Locker",
			id = 140204305999356,
			size = { 3, 8, 3 },
			pieces = {
				{
					match = "^Door$",
					mesh = "LockerDoor",
					id = 126570085011608,
					size = { 2.94, 7.7, 0.24 },
					at = { 0, 1.9, 0.06 },
					hide = { "Door", "DoorTop", "Stile", "Louvre", "Handle" },
				},
			},
		},
		TallCupboard = {
			mesh = "TallCupboard",
			id = 93183415257774,
			size = { 3, 8, 3 },
			pieces = {
				{
					match = "^Door$",
					mesh = "TallCupboardDoor",
					id = 123533743652438,
					size = { 2.94, 7.7, 0.25 },
					at = { 0, 1.9, 0.065 },
					hide = { "Door", "DoorTop", "Stile", "Louvre", "Handle" },
				},
			},
		},
		Toilet = {
			mesh = "Toilet",
			id = 127067426178832,
			size = { 2.4, 3.87, 3.38 },
			rises = true,
			centre = { 0, -0.059 },
		},
		Sink = { mesh = "Sink", id = 134567466420929, size = { 3, 4.1, 2.5 }, rises = true },
		-- Full of the game's still water; its curtain parted where you look out.
		Bathtub = {
			mesh = "Bathtub",
			id = 103438241652503,
			size = { 8.05, 10, 4.01 },
			rises = true,
			centre = { -0.025, 0.053 },
			keep = { "Water" },
		},
		Counter = {
			mesh = "Counter",
			id = 118602179795762,
			size = { 12.02, 4.8, 3.01 },
			rises = true,
			centre = { 0, 0.005 },
			pieces = {
				{
					match = "^Door%d$",
					mesh = "CounterDoor",
					id = 95617066024095,
					size = { 2.26, 2.89, 0.2 },
					at = { 0, 0, 0.05 },
					hide = { "Door", "Handle" },
				},
			},
		},
		-- Its lamps light inside while a door's open (Services/FurnitureService).
		Fridge = {
			mesh = "Fridge",
			id = 88266076504355,
			size = { 4, 8, 3.53 },
			centre = { 0, 0.015 },
			pieces = {
				{
					match = "^DoorTop$",
					mesh = "FridgeDoorTop",
					id = 107279767589394,
					size = { 3.85, 2.84, 0.83 },
					at = { 0, 0, -0.177 },
					hide = { "Door", "Handle", "Badge" },
				},
				{
					match = "^DoorBottom$",
					mesh = "FridgeDoorBottom",
					id = 134523509928603,
					size = { 3.85, 4.61, 0.83 },
					at = { 0, 0, -0.177 },
					hide = { "Door", "Handle" },
				},
			},
		},
		Stove = { mesh = "Stove", id = 76737929960354, size = { 4, 4.9, 3.75 }, rises = true, centre = { 0, 0.123 } },
		Washer = { mesh = "Washer", id = 82571608824181, size = { 3.5, 4, 3.7 }, centre = { 0, 0.1 } },
		WaterHeater = { mesh = "WaterHeater", id = 96079413552645, size = { 3.22, 7, 3.07 }, centre = { 0.19, 0.115 } },
		Workbench = { mesh = "Workbench", id = 129304846002547, size = { 10, 8.6, 3.5 }, rises = true },
		Car = { mesh = "Car", id = 87772743662583, size = { 7.45, 4.76, 14.4 } },
		-- The fire shows through its firebox's grille (the game's glowing bars).
		Boiler = {
			mesh = "Boiler",
			id = 78239211980577,
			size = { 6, 10.8, 5.09 },
			rises = true,
			centre = { 0, 0.045 },
			keep = { "Glow" },
		},
		WineRack = { mesh = "WineRack", id = 78014670704552, size = { 6, 8, 2 } },
		WaterTank = { mesh = "WaterTank", id = 126435964550762, size = { 8.1, 6.35, 5.1 } },
		-- The lantern's glass is the game's (its light).
		Shrine = { mesh = "Shrine", id = 101030413645979, size = { 3, 5, 3 }, rises = true, keep = { "Glass" } },
	},
	-- Door slabs (World/LevelBuilder's "Slab"), fitted to the slab.
	Slabs = {
		Door = { mesh = "Door", id = 120563615441757, size = { 5.8, 7.8, 0.48 } },
		-- A gate into a wing, glazed above its sill (kit.py kit3): over the
		-- whole door, its glass the game's.
		GlassDoor = { mesh = "GlassDoor", id = 92159403589343, size = { 5.8, 7.8, 0.48 } },
		-- The house's front door (World/MansionBuilder; World/Kit.dressFront):
		-- it swings open whole at the end. `at`: its box's middle, out toward
		-- the hall (the knob stands proud).
		FrontDoor = { mesh = "FrontDoor", id = 123000985042269, size = { 6, 8, 1.22 }, at = { 0, 0, 0.19 } },
	},
	-- The architecture's pieces (kit.py golden2), each in place of one
	-- grey-box part (World/MansionBuilder's railings and the grand staircase;
	-- World/Kit.dressPart). `fit`: sized to the part (a rail to its length);
	-- "y": to its height only (a baluster to its rail, on the stairs too).
	Parts = {
		Baluster = { mesh = "Baluster", id = 90124072108267, size = { 0.25, 3.1, 0.24 }, fit = "y" },
		Newel = { mesh = "Newel", id = 124411410635746, size = { 0.86, 3.8, 0.86 } },
		Handrail = { mesh = "Handrail", id = 131992520560699, size = { 0.45, 0.3, 4 }, fit = true },
		-- kit.py kit3: the trim, a moulding's section stretched along each run
		-- (World/Trim swaps its parts: World/Kit.swap). Their front is the
		-- part's -Z (toward the room), the other way to a prop's: `turn`.
		Baseboard = { mesh = "Baseboard", id = 130034150257135, size = { 4, 0.7, 0.14 }, fit = true, turn = 180 },
		Crown = { mesh = "Crown", id = 89075899246670, size = { 4, 0.45, 0.3 }, fit = true, turn = 180 },
		Casing = { mesh = "Casing", id = 87005014162128, size = { 4, 0.55, 0.18 }, fit = true, turn = 180 },
		DadoRail = { mesh = "DadoRail", id = 122725608496664, size = { 4, 0.2, 0.12 }, fit = true, turn = 180 },
		-- A step's walnut tread and cream riser (World/MansionBuilder's flight,
		-- World/Kit.place), fitted to each step.
		StairStep = { mesh = "StairStep", id = 118825365690466, size = { 6, 0.54, 1.12 }, fit = true },
		-- A door's knob set, through the door.
		Knob = { mesh = "Knob", id = 138656063626281, size = { 0.52, 0.52, 0.94 } },
		-- kit.py kit6: the locks' hardware (Services/LockService), in place of
		-- each grey-box plate on both faces of a locked door, its front out of
		-- the door (World/Kit.place). `at`: its box's middle from the plate's.
		KeyPlate = { mesh = "KeyPlate", id = 120854738275270, size = { 0.3, 0.6, 0.06 } },
		KeyPlateDouble = { mesh = "KeyPlateDouble", id = 100910471241381, size = { 0.3, 1.3, 0.06 } },
		Hasp = { mesh = "Hasp", id = 125760970342588, size = { 0.26, 0.6, 0.2 }, at = { 0, -0.02, 0 } },
		Bolt = { mesh = "Bolt", id = 130454074450521, size = { 1.28, 0.22, 0.1 }, at = { 0.04, 0.027, -0.012 } },
		PowerBox = { mesh = "PowerBox", id = 106778325120999, size = { 0.48, 0.79, 0.16 } },
		-- A chain's padlock as wide as the game's (`fit` "scale"), its shackle
		-- over the body (World/Kit.dressPart).
		Padlock = {
			mesh = "Padlock",
			id = 109213005676995,
			size = { 0.36, 0.66, 0.18 },
			fit = "scale",
			at = { 0, 0.12, 0 },
		},
		-- A plank nailed across a door or a chest, fitted to each (World/Kit.swap).
		Plank = { mesh = "Plank", id = 75844709919411, size = { 7.04, 0.55, 0.17 }, fit = true },
		-- A place at the dinner (Services/FinaleService): its plate and candle,
		-- round their middles; the card and the flame are the game's.
		DinnerPlate = { mesh = "DinnerPlate", id = 76849261321340, size = { 1.3, 0.08, 1.3 } },
		TableCandle = { mesh = "TableCandle", id = 101457396689717, size = { 0.28, 0.62, 0.28 } },
		-- kit.py kit7: the fuse box's breakers (server/Puzzles/Breaker): a body
		-- where each sits, its toggle and the main switch tipped up or down
		-- about their pivots (Kit.repose; `at`: the middle of each's box from
		-- its pivot).
		BreakerModule = { mesh = "BreakerModule", id = 110892485192315, size = { 0.15, 0.36, 0.08 } },
		BreakerToggle = {
			mesh = "BreakerToggle",
			id = 94343339870049,
			size = { 0.07, 0.15, 0.06 },
			at = { 0, 0.075, 0.005 },
		},
		MainSwitch = {
			mesh = "MainSwitch",
			id = 139126965297804,
			size = { 0.22, 0.33, 0.13 },
			at = { 0, 0.125, 0.025 },
		},
		-- A lever's plate and its arm (server/Puzzles/Levers): their front is
		-- the frame's -Z, into the room (`turn`); the plate's face a little
		-- behind the game's, where the door's mark is painted.
		LeverPlate = {
			mesh = "LeverPlate",
			id = 127747733849295,
			size = { 0.78, 1.58, 0.2 },
			turn = 180,
			at = { 0, 0, -0.04 },
		},
		LeverArm = { mesh = "LeverArm", id = 120988926462158, size = { 0.26, 1.15, 0.26 }, at = { 0, 0.095, 0 } },
		-- A servant's bell on its spring (Services/BellBoardService).
		Bell = { mesh = "Bell", id = 102349406132325, size = { 0.3, 0.37, 0.31 }, at = { 0, 0.053, 0 } },
		-- kit.py kit8 (kitlib/fittings): the moving fittings. A `turn = 180`
		-- piece's front is its part's -Z, into the room, and its `at` is in the
		-- part's frame.
		-- The dumbwaiter (server/Puzzles/Dumbwaiter): the casing on each floor
		-- (placed on its frame, its back on the floor), the stuck hatch (the
		-- glass is the game's), the car (in the car's model, so it rides), the
		-- jam box.
		DumbwaiterCasing = {
			mesh = "DumbwaiterCasing",
			id = 124814881680506,
			size = { 2.22, 10, 2.18 },
			at = { 0, 5, 0.77 },
		},
		DumbwaiterHatch = {
			mesh = "DumbwaiterHatch",
			id = 114012586090348,
			size = { 1.62, 1.4, 0.24 },
			at = { -0.01, 0, 0.07 },
		},
		DumbwaiterCar = {
			mesh = "DumbwaiterCar",
			id = 100011009305897,
			size = { 1.25, 3.65, 1.25 },
			at = { 0, 1.775, 0 },
		},
		JamBox = { mesh = "JamBox", id = 120262420027486, size = { 0.91, 2.04, 0.78 }, at = { -0.063, 0.77, 0 } },
		-- Both cranks' wheel, scaled to each's (the crank door's 1.1, the
		-- dumbwaiter's 0.8); turned about its axle as it winds (Kit.repose).
		HandWheel = {
			mesh = "HandWheel",
			id = 135257966268366,
			size = { 1.06, 1.06, 0.58 },
			at = { 0, 0, 0.107 },
			fit = "scale",
		},
		-- The crank doors (Services/CrankService): a slat of the shutter (stacked
		-- from the bar up as it rolls), the bottom bar, the roller box, the
		-- crank's plate, the latch inside.
		ShutterSlat = { mesh = "ShutterSlat", id = 120813956828415, size = { 6.6, 0.45, 0.22 }, at = { 0, 0, 0.01 } },
		ShutterBar = { mesh = "ShutterBar", id = 128719687524517, size = { 6.7, 0.31, 0.59 }, at = { 0, -0.005, 0 } },
		RollerBox = { mesh = "RollerBox", id = 137600998037512, size = { 7.16, 1.12, 1.14 } },
		CrankPlate = {
			mesh = "CrankPlate",
			id = 79751279101169,
			size = { 1.3, 1.3, 0.22 },
			turn = 180,
			at = { 0, 0, -0.037 },
		},
		ShutterLatch = {
			mesh = "ShutterLatch",
			id = 105812836210767,
			size = { 0.5, 0.9, 0.26 },
			turn = 180,
			at = { 0, 0, -0.068 },
		},
		-- The laundry chute (Services/ChuteService): the wall hatch, the mouth
		-- and the basket below it; the trapdoor and the ceiling's duct.
		ChuteHatch = {
			mesh = "ChuteHatch",
			id = 110584818448833,
			size = { 2.9, 2.5, 0.27 },
			turn = 180,
			at = { 0, 0, -0.074 },
		},
		ChuteMouth = {
			mesh = "ChuteMouth",
			id = 129040379089610,
			size = { 2.66, 1.47, 1.49 },
			turn = 180,
			at = { 0, 0.004, -0.143 },
		},
		LaundryBasket = {
			mesh = "LaundryBasket",
			id = 87057863494058,
			size = { 2.86, 2, 2.27 },
			turn = 180,
			at = { 0, 0.213, -0.079 },
		},
		ChuteTrapdoor = { mesh = "ChuteTrapdoor", id = 126328204106170, size = { 2.9, 0.1, 2.9 }, at = { 0, 0.042, 0 } },
		ChuteDuct = { mesh = "ChuteDuct", id = 86976548936175, size = { 2.96, 1.26, 2.96 }, at = { 0, -0.03, 0 } },
		-- kit.py kit9: a room's light switch (Services/InteractService), its
		-- plate (World/Kit.dressPrompted: its mesh catches the aim for the
		-- prompt) and its toggle, placed again as it flips (Kit.repose); the
		-- safe room's carton of batteries (Services/SafeRoomService), its
		-- label the game's on top.
		SwitchPlate = { mesh = "SwitchPlate", id = 82539235853651, size = { 0.38, 0.6, 0.06 }, at = { 0, 0, -0.005 } },
		SwitchToggle = {
			mesh = "SwitchToggle",
			id = 124128424801013,
			size = { 0.07, 0.19, 0.06 },
			at = { 0, 0.002, 0 },
		},
		BatteryBox = { mesh = "BatteryBox", id = 111372886674297, size = { 0.91, 0.45, 0.6 } },
		-- kit.py kit10 (kitlib/ornament, the visual rework V4b): the last of the
		-- architecture. A plaster rose over each pendant and the hall's
		-- chandelier (World/LevelBuilder's fixture); a coffered ceiling's beams,
		-- stretched along each run, and the bosses where they cross
		-- (World/MansionBuilder); a cast-iron radiator under a window
		-- (World/PropFactory); a pocket door in each jamb of an archway, which
		-- flips with the seam (World/Trim). The ceiling pieces are placed at the
		-- ceiling, their `at` hanging them under it. Nothing is placed without
		-- its mesh, so no grey-box stands in for them.
		CeilingRose = { mesh = "CeilingRose", id = 137240723249751, size = { 2.6, 0.32, 2.6 }, at = { 0, -0.16, 0 } },
		CeilingRoseLarge = {
			mesh = "CeilingRoseLarge",
			id = 118632789769919,
			size = { 4.8, 0.4, 4.8 },
			at = { 0, -0.2, 0 },
		},
		CofferBeamWood = {
			mesh = "CofferBeamWood",
			id = 135785825088795,
			size = { 4, 0.64, 0.83 },
			fit = true,
			at = { 0, -0.32, 0 },
		},
		CofferBeamPaint = {
			mesh = "CofferBeamPaint",
			id = 140344180525822,
			size = { 4, 0.64, 0.83 },
			fit = true,
			at = { 0, -0.32, 0 },
		},
		CofferBossWood = {
			mesh = "CofferBossWood",
			id = 110498620009624,
			size = { 0.87, 0.82, 0.87 },
			at = { 0, -0.41, 0 },
		},
		CofferBossPaint = {
			mesh = "CofferBossPaint",
			id = 98887705130058,
			size = { 0.87, 0.82, 0.87 },
			at = { 0, -0.41, 0 },
		},
		Radiator = { mesh = "Radiator", id = 132998574857921, size = { 4.01, 2.55, 0.6 } },
		PocketDoor = { mesh = "PocketDoor", id = 70798688994636, size = { 0.43, 7.9, 0.26 } },
		-- kit.py mall1: the lobby's mall, its court (docs/plans/lobby-rework.md,
		-- LB1b). World/MallBuilder dresses Data/Mall's blocks that name one
		-- (`kit`, stood upright where the block stands), the gallery's columns
		-- and parapet runs, the shopfronts' grille boxes and the ads' frames.
		-- `at`: the box's middle from the block's or part's.
		MallBench = { mesh = "MallBench", id = 83394269620171, size = { 8, 1.85, 2.4 }, at = { 0, 0.023, 0 } },
		MallPlanter = { mesh = "MallPlanter", id = 131959250346121, size = { 6, 3.05, 6 }, at = { 0, 0.023, 0 } },
		-- (Stretched to each dead stick's height.)
		DeadFicus = {
			mesh = "DeadFicus",
			id = 123889906349524,
			size = { 1.23, 2.38, 1.21 },
			fit = "y",
			at = { -0.1, -0.115, -0.121 },
		},
		FountainBasin = { mesh = "FountainBasin", id = 137189712520101, size = { 14.16, 1.6, 14.16 } },
		FountainCentre = { mesh = "FountainCentre", id = 94859923453898, size = { 3.96, 5, 3.96 } },
		MallDirectory = { mesh = "MallDirectory", id = 93895610643109, size = { 4, 7, 0.8 } },
		PhotoBooth = { mesh = "PhotoBooth", id = 109270209933523, size = { 5.04, 8, 5.35 }, at = { 0, 0, 0.155 } },
		-- Its wheels reach the floor under the basket the block stands for.
		ShoppingCart = {
			mesh = "ShoppingCart",
			id = 97957046143815,
			size = { 2.28, 3.32, 3.84 },
			at = { -0.002, -0.442, 0.172 },
		},
		-- An ad's poster case round its face (the AdFrame part; its front is the
		-- part's -Z), the bezel's inside edge on the face's.
		LightboxWide = {
			mesh = "LightboxWide",
			id = 106922432236650,
			size = { 11.6, 6.8, 0.85 },
			turn = 180,
			at = { 0, 0, -0.125 },
		},
		LightboxSmall = {
			mesh = "LightboxSmall",
			id = 99002061085247,
			size = { 9, 5.6, 0.85 },
			turn = 180,
			at = { 0, 0, -0.125 },
		},
		GrilleBox = { mesh = "GrilleBox", id = 76733238819606, size = { 29, 1.41, 1.4 }, fit = true, turn = 180 },
		MallColumn = { mesh = "MallColumn", id = 122698261005553, size = { 2.72, 20.8, 2.72 } },
		-- A gallery's edge in lengths of about 10, stretched to fit its run.
		GalleryParapet = {
			mesh = "GalleryParapet",
			id = 102483599194603,
			size = { 10, 5.1, 0.74 },
			fit = true,
			at = { 0, 0, 0.03 },
		},
		MallChandelier = {
			mesh = "MallChandelier",
			id = 126635343491717,
			size = { 13.8, 4.45, 12.4 },
			at = { 0, -1.325, 0 },
		},
		-- kit.py mall2: the shops, laid out by hand (LB1b; the owner, 2026-10-15:
		-- "be very deliberate with placement in the shops"). Data/Mall has
		-- where each stands, its front the block's +z.
		DinerBackbar = { mesh = "DinerBackbar", id = 90238971129468, size = { 30, 5, 2.21 }, at = { 0, 0.9, 0.005 } },
		DinerCounter = {
			mesh = "DinerCounter",
			id = 131386406382019,
			size = { 30.14, 5.1, 3.15 },
			at = { 0, 0.55, 0.075 },
		},
		DinerStool = { mesh = "DinerStool", id = 105937472757810, size = { 1.6, 2.5, 1.6 } },
		DinerBoothSeat = {
			mesh = "DinerBoothSeat",
			id = 83566470421230,
			size = { 5.09, 4.2, 1.73 },
			at = { 0, 0, -0.016 },
		},
		DinerTable = { mesh = "DinerTable", id = 129161862475557, size = { 4.46, 3.38, 2.96 }, at = { 0, 0.388, 0 } },
		-- A record board's frame round its felt; the board's face is its
		-- block's, where the records go (the diner's phase).
		MenuBoard = { mesh = "MenuBoard", id = 132114002978215, size = { 13.5, 4.5, 0.5 }, at = { 0, 0, 0.05 } },
		Jukebox = { mesh = "Jukebox", id = 92272029345995, size = { 2.6, 4.6, 1.88 }, at = { 0, 0, 0.04 } },
		-- Floors in panels, stretched to fill each room (Data/Mall `floorKit`).
		DinerFloor = { mesh = "DinerFloor", id = 135551791186441, size = { 10, 0.05, 10 }, fit = true },
		ArcadeCarpet = { mesh = "ArcadeCarpet", id = 112863397831603, size = { 10, 0.04, 10 }, fit = true },
		VideoShelf = { mesh = "VideoShelf", id = 140368521456665, size = { 7, 7, 2.7 }, at = { 0, 0, -0.15 } },
		VideoIsland = { mesh = "VideoIsland", id = 73982242912374, size = { 8, 5.2, 2 } },
		VideoCounter = { mesh = "VideoCounter", id = 135977298277871, size = { 6.1, 5.2, 3 }, at = { 0, 0.6, 0 } },
		CounterTV = { mesh = "CounterTV", id = 132542377202646, size = { 2.2, 1.62, 1.75 }, at = { 0, 0.011, 0.075 } },
		Standee = { mesh = "Standee", id = 125174088561632, size = { 2.6, 6, 1.35 }, at = { 0, 0, -0.25 } },
		-- The arcade's cabinets. Each screen is the mesh's for now; when a
		-- game runs on one, a screen part goes over it (1.9 x 1.3, 0.9 up
		-- from the middle and 1.0 out, tilted back 12 degrees).
		CabinetHouseCall = {
			mesh = "CabinetHouseCall",
			id = 75644640314821,
			size = { 3.17, 6, 3.08 },
			at = { 0, 0, 0.04 },
		},
		CabinetNightDrive = {
			mesh = "CabinetNightDrive",
			id = 86202329005102,
			size = { 3.17, 6, 3.08 },
			at = { 0, 0, 0.04 },
		},
		CabinetDead = { mesh = "CabinetDead", id = 117009881358562, size = { 3.17, 6, 3.08 }, at = { 0, 0, 0.04 } },
		PrizeCounter = { mesh = "PrizeCounter", id = 74677931266585, size = { 12, 4, 3 } },
		PrizeWall = { mesh = "PrizeWall", id = 96124784961305, size = { 12, 4, 0.65 }, at = { 0, 0, 0.124 } },
		ChangeMachine = { mesh = "ChangeMachine", id = 110487511259579, size = { 2.2, 5, 2.13 }, at = { 0, 0, 0.165 } },
		ShowroomTV = { mesh = "ShowroomTV", id = 91130493043046, size = { 4, 3, 1.36 }, at = { 0, 0, 0.08 } },
		TVStandLong = { mesh = "TVStandLong", id = 102753295131227, size = { 14, 2.6, 2 } },
		ElectronicsShelf = { mesh = "ElectronicsShelf", id = 93690343230952, size = { 7, 6, 2.4 }, at = { 0, 0, -0.3 } },
		DisplayCounter = { mesh = "DisplayCounter", id = 108092893102347, size = { 10, 4, 3 } },
		RoundRack = { mesh = "RoundRack", id = 105836005083492, size = { 5.2, 4.53, 5.2 }, at = { 0, -0.237, 0 } },
		RackTops = { mesh = "RackTops", id = 103691275191107, size = { 6.9, 4.68, 1.72 }, at = { 0, -0.162, 0 } },
		RackBottoms = { mesh = "RackBottoms", id = 118831530745912, size = { 6.9, 4.68, 1.5 }, at = { 0, -0.162, 0 } },
		ShoeWall = { mesh = "ShoeWall", id = 83444854916410, size = { 8, 6, 1.09 }, at = { 0, 0, -0.154 } },
		Slatwall = { mesh = "Slatwall", id = 88623917213234, size = { 10, 7, 0.8 }, at = { 0, 0, -0.1 } },
		-- Built hollow, its mirror inside; its block stays solid until the
		-- boutique's phase opens it.
		ChangingBooth = { mesh = "ChangingBooth", id = 116776276800428, size = { 6, 8, 6.01 }, at = { 0, 0, 0.003 } },
		CashWrap = { mesh = "CashWrap", id = 116327264017503, size = { 7.1, 5.1, 3 }, at = { 0, 0.55, 0 } },
		-- The house's own pieces, in the mall: the boutique's window, the
		-- diner's corner (already imported; Props.Mannequin, Props.CoatRack).
		MallDressForm = { mesh = "DressForm", id = 75814638297274, size = { 1.63, 6.49, 1.43 }, at = { 0, 0, -0.208 } },
		MallCoatRack = { mesh = "CoatRack", id = 90933748796114, size = { 1.32, 7, 1.32 } },
		-- kit.py mall3: the garage (laid out by hand, as the shops), the vault's
		-- ribs and ends, the escalators, the shops' neon. A group's piece
		-- (Data/Mall KitGroups) stands on the floor; a block's round its middle.
		Generator = {
			mesh = "Generator",
			id = 83264819376646,
			size = { 8.31, 5.65, 5.15 },
			at = { -0.055, 2.825, 0.077 },
		},
		JerryCan = { mesh = "JerryCan", id = 92940123080413, size = { 1.14, 1.62, 0.85 }, at = { 0, 0.011, 0 } },
		OilDrum = { mesh = "OilDrum", id = 87243150741358, size = { 2, 2.96, 2 }, at = { 0, 0.03, 0 } },
		OilDrumPump = { mesh = "OilDrumPump", id = 98814584349440, size = { 2, 4.18, 2 }, at = { 0, 0.642, 0 } },
		CableReel = { mesh = "CableReel", id = 95027190099653, size = { 3.02, 1.66, 3 }, at = { 0.008, 0, 0 } },
		MallPowerBox = {
			mesh = "MallPowerBox",
			id = 72624274447113,
			size = { 3.2, 4.06, 0.98 },
			at = { 0.2, -0.032, -0.01 },
		},
		CarPegboard = { mesh = "CarPegboard", id = 84036824643837, size = { 14, 6, 0.43 }, at = { 0, 0, 0.015 } },
		Payphone = { mesh = "Payphone", id = 76326765076379, size = { 2, 3, 1.2 } },
		TyreStack = {
			mesh = "TyreStack",
			id = 130386102470419,
			size = { 2.43, 3.12, 2.42 },
			at = { -0.004, 0, -0.002 },
		},
		CotBag = { mesh = "CotBag", id = 113791062318689, size = { 7, 2.17, 2.74 }, at = { 0, 1.102, 0 } },
		CotBlanket = { mesh = "CotBlanket", id = 114129725410606, size = { 7, 2.09, 2.74 }, at = { 0, 1.062, 0 } },
		CampTable = { mesh = "CampTable", id = 75776625463453, size = { 6, 4.41, 3 }, at = { 0, 2.216, 0 } },
		Whiteboard = { mesh = "Whiteboard", id = 99750380121198, size = { 7, 4.01, 0.47 }, at = { 0, -0.005, 0.087 } },
		CaseBoard = { mesh = "CaseBoard", id = 97869813750101, size = { 12, 6, 0.4 } },
		PhotoHouse = { mesh = "PhotoHouse", id = 129631039649815, size = { 1.3, 1, 0.14 }, at = { 0, 0, 0.052 } },
		PhotoFigure = { mesh = "PhotoFigure", id = 119403794029632, size = { 1.3, 1, 0.14 }, at = { 0, 0, 0.052 } },
		Blueprint = { mesh = "Blueprint", id = 97604225918880, size = { 2.4, 1.8, 0.14 }, at = { 0, 0, 0.052 } },
		InvestigatorDesk = {
			mesh = "InvestigatorDesk",
			id = 106326295772216,
			size = { 7, 3.55, 3.06 },
			at = { 0, 0.178, 0.03 },
		},
		DeskChair = {
			mesh = "DeskChair",
			id = 86857515841289,
			size = { 1.78, 3.71, 1.84 },
			at = { 0.06, -0.046, 0.011 },
		},
		CBRadio = { mesh = "CBRadio", id = 97863507933373, size = { 1.6, 0.98, 1.22 }, at = { 0, 0.087, 0.01 } },
		-- (Stretched to each stack's box.)
		BankersBox = { mesh = "BankersBox", id = 117066118610463, size = { 2.4, 2, 2.4 }, fit = true },
		-- At its light's point; a lit one's tubes are the game's Neon part.
		StripFixture = { mesh = "StripFixture", id = 116017797441154, size = { 8, 1.35, 0.94 }, at = { 0, 0.325, 0 } },
		-- On the floor, its head 7 up round the game's lit head.
		WorkLamp = {
			mesh = "WorkLamp",
			id = 121269284551865,
			size = { 2.57, 7.9, 2.57 },
			at = { 0.132, 3.952, -0.053 },
		},
		-- Stretched to each opening (the garage's door, the dead fronts); its
		-- front toward the frame's -Z, as a door's (`at` mirrored with it).
		RollUpShutter = {
			mesh = "RollUpShutter",
			id = 91919371563564,
			size = { 20, 12, 0.58 },
			fit = true,
			turn = 180,
			at = { 0, 0, -0.067 },
		},
		-- The vault's (Data/Mall Vaults `kit`), at its springing line: modelled
		-- for a span of 40 and a rise of 11.
		VaultRib = { mesh = "VaultRib", id = 129868060145307, size = { 0.8, 11.29, 40.4 }, at = { 0, 5.525, 0 } },
		VaultGable = { mesh = "VaultGable", id = 132439380895024, size = { 40, 11, 0.8 }, at = { 0, 5.5, 0.1 } },
		EscalatorPair = {
			mesh = "EscalatorPair",
			id = 78581731194780,
			size = { 44.08, 25.19, 8.2 },
			at = { 0, 12.544, 0 },
		},
		-- The shops' neon (Data/Mall Signs `neon`), on the sign's frame (its
		-- front the frame's -Z: turned, `at` mirrored); no maps, drawn Neon.
		NeonBoutique = {
			mesh = "NeonBoutique",
			id = 75345565348047,
			size = { 18.26, 3.21, 0.16 },
			turn = 180,
			at = { 0.034, -0.336, -0.45 },
		},
		NeonVideo = {
			mesh = "NeonVideo",
			id = 139997618642151,
			size = { 12.92, 4.64, 0.26 },
			turn = 180,
			at = { 0.038, -0.003, -0.45 },
		},
		NeonArcade = {
			mesh = "NeonArcade",
			id = 106531536177987,
			size = { 17.6, 3.01, 0.24 },
			turn = 180,
			at = { 0.049, 0, -0.45 },
		},
		NeonElectronics = {
			mesh = "NeonElectronics",
			id = 108763658037431,
			size = { 20.31, 2.75, 0.2 },
			turn = 180,
			at = { 0.037, -0.298, -0.45 },
		},
		NeonDiner = {
			mesh = "NeonDiner",
			id = 138568851489284,
			size = { 11.46, 3.79, 0.24 },
			turn = 180,
			at = { 0.072, -0.392, -0.45 },
		},
		SignRaceway = {
			mesh = "SignRaceway",
			id = 134759248282869,
			size = { 10, 0.7, 0.58 },
			fit = true,
			turn = 180,
			at = { 0, 0, -0.133 },
		},
		-- The house's own: its car in the bays (LB2's party cars), its
		-- workbench (Props.Car, Props.Workbench; already imported).
		MallCar = { mesh = "Car", id = 87772743662583, size = { 7.45, 4.76, 14.4 }, at = { 0, -0.12, 0 } },
		MallWorkbench = { mesh = "Workbench", id = 129304846002547, size = { 10, 8.6, 3.5 }, at = { 0, 2.3, 0 } },
	},
	-- Light fixtures (kit.py golden2; World/Kit.dressFixture). `floor`: the
	-- bottom of its box above where kit.py built it round; `scale`: shown that
	-- much bigger than modelled. Their shades glow
	-- (an emissive mask) and cast no shadow, or they'd hide their own bulb.
	Fixtures = {
		Pendant = { mesh = "Pendant", id = 123039045628887, size = { 2.24, 1.45, 2.24 }, shadow = false },
		Chandelier = {
			mesh = "Chandelier",
			id = 75925560212712,
			size = { 3.74, 2.7, 3.3 },
			floor = 0.5,
			scale = 1.5, -- (as modelled it was a small thing in a double-height hall)
			shadow = false,
		},
		Sconce = {
			mesh = "Sconce",
			id = 89083803782824,
			size = { 0.9, 1.15, 0.95 },
			floor = 0.15,
			centre = { 0, -0.025 },
			shadow = false,
		},
	},
	-- Wall decor (World/PropFactory.buildDecor; World/Kit.dressDecor), built
	-- out from the wall: `at` = { x, y, out } of its box's middle; `hide`: the
	-- grey-box parts it stands for (the glass, the night, curtains and blinds
	-- stay the game's); `variants`: one of these, by the decor's own seed.
	Decor = {
		-- A double-hung sash window, six panes over six (kit.py kit3).
		Window = {
			mesh = "Window",
			id = 101840155990362,
			size = { 6.3, 5, 0.5 },
			at = { 0, 0, 0.25 },
			hide = { "Frame", "Sill", "MuntinH", "MuntinV" },
		},
		-- Four old landscapes in gilt frames (kit.py kit3, kitlib/paintings).
		-- No shadow: a sconce on the same wall shines along it, and the frame
		-- standing 0.25 out put its own picture and a long stretch of wall in
		-- the dark (seen 2026-10-13).
		Painting = {
			variants = {
				{ mesh = "Painting1", id = 115264976402379 },
				{ mesh = "Painting2", id = 114887369258049 },
				{ mesh = "Painting3", id = 80018179966532 },
				{ mesh = "Painting4", id = 129743371634638 },
			},
			size = { 5, 4, 0.25 },
			at = { 0, 0, 0.125 },
			hide = { "Frame", "Canvas", "Horizon", "Shape" },
			shadow = false,
		},
		Mirror = {
			mesh = "Mirror",
			id = 136546360057247,
			size = { 3, 5, 0.3 },
			at = { 0, 0, 0.15 },
			hide = { "Frame" },
			shadow = false,
		},
	},
	-- The escape's things (kit.py kit6, kitlib/things; World/Kit.dressThing):
	-- each stands on the frame its builder was given (World/Items: where it
	-- lies; World/LeadProps: a box's place, a key rack's middle), `centre`,
	-- `floor`, `keep` and `pieces` as a prop's. The hands carry the grey-box
	-- (Services/HandsService), the mesh welded to it.
	Things = {
		-- Its paper tag is the game's, written on.
		Key = {
			mesh = "Key",
			id = 121353418041503,
			size = { 0.82, 0.07, 0.27 },
			centre = { -0.096, 0.007 },
			floor = -0.009,
			keep = { "Tag" },
		},
		-- The heirlooms, by World/Items.Heirlooms id.
		Candlestick = { mesh = "Candlestick", id = 131901863423276, size = { 0.6, 1.8, 0.6 } },
		PocketWatch = {
			mesh = "PocketWatch",
			id = 76337101598846,
			size = { 0.86, 0.14, 0.95 },
			centre = { 0.13, -0.176 },
			floor = -0.025,
		},
		Locket = {
			mesh = "Locket",
			id = 103040709172146,
			size = { 0.84, 0.13, 0.84 },
			centre = { 0.003, -0.205 },
			floor = -0.02,
		},
		Doll = { mesh = "Doll", id = 100647881429023, size = { 0.54, 1.02, 0.54 } },
		Cup = { mesh = "ChristeningCup", id = 90511645936859, size = { 0.61, 0.59, 0.47 }, centre = { 0.072, 0 } },
		-- The valuables, by Data/Valuables id.
		CarriageClock = { mesh = "CarriageClock", id = 123516832753045, size = { 0.66, 0.88, 0.46 } },
		JewelleryBox = {
			mesh = "JewelleryBox",
			id = 134664438972180,
			size = { 0.98, 0.47, 0.65 },
			centre = { 0, -0.005 },
		},
		SilverTeapot = {
			mesh = "SilverTeapot",
			id = 119028869629952,
			size = { 0.62, 0.68, 1.02 },
			centre = { 0, -0.054 },
		},
		CashBox = { mesh = "CashBox", id = 123282168571868, size = { 0.97, 0.49, 0.66 }, centre = { 0, -0.006 } },
		-- The keepsake boxes, by LeadProps.KeepsakeLooks, each with its lid.
		KeepsakeWood = {
			mesh = "KeepsakeWood",
			id = 88803256910229,
			size = { 1.15, 0.5, 0.81 },
			centre = { 0, 0.005 },
			pieces = {
				{
					match = "^Lid$",
					mesh = "KeepsakeWoodLid",
					id = 104370739716495,
					size = { 1.19, 0.12, 0.84 },
					hide = { "Lid", "Corner" },
				},
			},
		},
		KeepsakeTin = {
			mesh = "KeepsakeTin",
			id = 80727432939445,
			size = { 1.16, 0.5, 0.81 },
			pieces = {
				{
					match = "^Lid$",
					mesh = "KeepsakeTinLid",
					id = 126571458847268,
					size = { 1.2, 0.13, 0.84 },
					at = { 0, 0.015, 0 },
					hide = { "Lid", "Band" },
				},
			},
		},
		KeepsakeVelvet = {
			mesh = "KeepsakeVelvet",
			id = 84985523142103,
			size = { 1.17, 0.5, 0.82 },
			pieces = {
				{
					match = "^Lid$",
					mesh = "KeepsakeVelvetLid",
					id = 100739862925129,
					size = { 1.24, 0.23, 0.89 },
					at = { 0, -0.025, 0.007 },
					hide = { "Lid", "Clasp" },
				},
			},
		},
		-- Its glass is the game's; so is its lock plate, where the pick prompt
		-- hangs (the hands look past a hidden part that doesn't collide).
		DisplayCase = {
			mesh = "DisplayCase",
			id = 125621439553367,
			size = { 1.3, 0.24, 1.04 },
			centre = { 0, 0.019 },
			keep = { "Lock", "Keyhole" },
			pieces = {
				{
					match = "^Lid$",
					mesh = "DisplayCaseCover",
					id = 133623076628507,
					size = { 1.26, 0.87, 0.97 },
					at = { 0, -0.35, 0.005 },
					hide = { "Frame" },
				},
			},
		},
		Figurine = { mesh = "Figurine", id = 87832522154805, size = { 0.31, 0.64, 0.31 } },
		-- On a wall, round its board's middle, its back on the wall.
		KeyRack = {
			mesh = "KeyRack",
			id = 121990939714753,
			size = { 1.9, 0.8, 0.32 },
			centre = { 0, 0.158 },
			floor = -0.4,
		},
		-- kit.py kit7 (kitlib/devices): the puzzle stations and the house's
		-- devices. What lights or moves is the game's (`keep`).
		-- The computer's screen holds its text, its glow and its prompt.
		HomeComputer = {
			mesh = "HomeComputer",
			id = 92010587592416,
			size = { 4.26, 1.75, 2.15 },
			centre = { -0.02, 0.375 },
			keep = { "Screen" },
		},
		-- On a wall, round its frame; its pilot lamps and their glow are the
		-- game's (server/Puzzles/Breaker).
		FuseBox = {
			mesh = "FuseBox",
			id = 97724896695779,
			size = { 1.93, 2.62, 2.2 },
			centre = { -0.028, 1.1 },
			floor = -1.24,
			keep = { "Pilot", "MainLamp", "Glow" },
		},
		-- The tuning dial glows and its needle wanders (Controllers/
		-- DeviceController).
		Radio = {
			mesh = "Radio",
			id = 92548453921892,
			size = { 2.4, 5.03, 1.9 },
			keep = { "Dial", "Needle", "Scale" },
			query = true,
		},
		-- On a wall; the dial holds its prompt.
		WallSafe = {
			mesh = "WallSafe",
			id = 131554105237850,
			size = { 1.8, 1.8, 0.94 },
			centre = { 0, 0.469 },
			floor = -0.9,
			pieces = {
				{
					match = "^SafeDoor$",
					mesh = "SafeDoor",
					id = 99644366416978,
					size = { 1.72, 1.6, 0.2 },
					at = { 0, 0, 0.039 },
					hide = { "Door", "Handle" },
				},
				{
					match = "^Painting$",
					mesh = "SafePainting",
					id = 103039993549596,
					size = { 2.4, 2.2, 0.14 },
					hide = { "Frame", "Canvas" },
				},
			},
		},
		-- Its comb and its coloured teeth light as it plays.
		MusicBox = {
			mesh = "MusicBox",
			id = 98353203999751,
			size = { 1.37, 1.22, 1.04 },
			centre = { 0.072, -0.117 },
			keep = { "Comb", "Tooth1", "Tooth2", "Tooth3", "Tooth4", "Tooth5", "Tooth6", "Tooth7", "Tooth8" },
		},
		Kettle = {
			mesh = "Kettle",
			id = 140623888781772,
			size = { 1, 1.26, 1.24 },
			centre = { 0, 0.121 },
			query = true,
		},
		RecordPlayer = {
			mesh = "RecordPlayer",
			id = 88871371706856,
			size = { 1.5, 1.44, 1.38 },
			centre = { 0, -0.088 },
			query = true,
		},
		-- Their fronts are -Z as the game builds them; the monitor's lamp and
		-- the robot's eyes glow.
		BabyMonitor = {
			mesh = "BabyMonitor",
			id = 84427122794301,
			size = { 0.47, 0.95, 0.26 },
			centre = { 0.013, -0.004 },
			keep = { "Light" },
		},
		TinRobot = {
			mesh = "TinRobot",
			id = 99933363387283,
			size = { 0.61, 1.09, 0.43 },
			centre = { 0, 0.038 },
			keep = { "Eye" },
		},
		-- On a wall; its bells are each a Bell (Parts), its flags and labels
		-- the game's.
		BellBoard = {
			mesh = "BellBoard",
			id = 134195723361167,
			size = { 2.85, 3.1, 0.16 },
			centre = { 0, 0.08 },
			floor = -1.5,
			keep = { "Flag", "Label", "Bell" },
		},
		-- The atmosphere (kit.py kit9): the things on tops (World/Dressing, by
		-- the model's name or the look it wears: a plate with or without its
		-- crust, two stacks of books, a vase with or without stems, two
		-- magazines), each facing the room down its spot's -z as its blocks
		-- do; the mug and the vase are glazed pale for World/Dressing to tint.
		Telephone = { mesh = "Telephone", id = 102430298963553, size = { 1.15, 0.62, 0.83 }, centre = { -0.021, 0 } },
		-- (Its photo is the game's, aged by Drift.)
		PhotoFrame = {
			mesh = "PhotoFrame",
			id = 136846176816220,
			size = { 0.95, 1.22, 0.56 },
			centre = { 0, 0.092 },
			floor = -0.004,
			keep = { "Photo" },
		},
		Mug = { mesh = "Mug", id = 84994011186313, size = { 0.53, 0.42, 0.38 }, centre = { 0.075, 0 } },
		SidePlate = { mesh = "SidePlate", id = 133662375420617, size = { 0.95, 0.09, 0.95 } },
		SidePlateCrust = { mesh = "SidePlateCrust", id = 92344115296333, size = { 0.95, 0.09, 0.95 } },
		BooksA = { mesh = "BooksA", id = 99831365232436, size = { 1.05, 0.6, 0.82 }, centre = { 0.002, -0.008 } },
		BooksB = { mesh = "BooksB", id = 88800997869858, size = { 1.04, 0.32, 0.82 }, centre = { -0.001, -0.013 } },
		Vase = { mesh = "Vase", id = 121230759638449, size = { 0.58, 1.12, 0.58 } },
		VaseStems = {
			mesh = "VaseStems",
			id = 119679986810220,
			size = { 0.78, 2.01, 0.83 },
			centre = { -0.099, -0.002 },
		},
		MagazineA = { mesh = "MagazineA", id = 74532519601746, size = { 0.85, 0.04, 1.1 } },
		MagazineB = { mesh = "MagazineB", id = 133794080917818, size = { 0.85, 0.04, 1.1 } },
		-- And the finds in drawers (World/Junk, by Junk.Names), each lying where
		-- its blocks lie.
		Cassette = {
			mesh = "Cassette",
			id = 84253129536132,
			size = { 0.7, 0.08, 0.44 },
			centre = { 0, 0.001 },
			floor = 0.002,
		},
		Matchbox = { mesh = "Matchbox", id = 138271817970412, size = { 0.49, 0.14, 0.29 }, centre = { 0.033, 0 } },
		Letters = { mesh = "Letters", id = 134821022582396, size = { 0.85, 0.09, 0.54 }, floor = -0.012 },
		Candle = {
			mesh = "Candle",
			id = 126301794125458,
			size = { 0.62, 0.35, 0.51 },
			centre = { 0.055, 0 },
			floor = -0.013,
		},
		Spool = { mesh = "Spool", id = 77281914622617, size = { 0.57, 0.35, 0.34 }, centre = { 0.074, 0 } },
		PillBottle = { mesh = "PillBottle", id = 104829228625300, size = { 0.24, 0.44, 0.24 } },
		SpareBatteries = { mesh = "SpareBatteries", id = 101801539497954, size = { 0.53, 0.27, 0.57 }, floor = -0.017 },
	},
	-- The corridors' landmarks (kit.py kit8; World/LandmarkProps), by their
	-- Data/Landmarks id, dressed on the frame they're built on (World/
	-- Kit.dressLandmark): their back on the wall, `floor` the bottom of their
	-- box from it, `centre` { x, out }. The portrait's name plate is the game's.
	Landmarks = {
		stag = {
			mesh = "StagHead",
			id = 127754429400038,
			size = { 2.02, 2.98, 1.99 },
			centre = { 0, 0.952 },
			floor = -0.899,
		},
		portrait = {
			mesh = "FounderPortrait",
			id = 90631542408260,
			size = { 2.6, 3.4, 0.22 },
			centre = { 0, 0.11 },
			floor = -1.4,
			keep = { "Plate" },
		},
		tapestry = {
			mesh = "Tapestry",
			id = 139984054320495,
			size = { 3.44, 3.9, 0.25 },
			centre = { 0, 0.127 },
			-- (Hung 0.12 higher than modelled, so its fringe clears a corridor's
			-- dado rail: seen in Studio, 2026-10-13.)
			floor = -1.68,
		},
		clock = {
			mesh = "StoppedClock",
			id = 128016012919132,
			size = { 2.4, 2.4, 0.25 },
			centre = { 0, 0.122 },
			floor = -0.9,
		},
		wheel = {
			mesh = "ShipsWheel",
			id = 129286749743554,
			size = { 2.62, 2.62, 0.53 },
			centre = { 0, 0.265 },
			floor = -1.01,
		},
	},
	-- Outside (kit.py kit9; World/Exterior, World/Kit.placeOutside): the
	-- trees, bushes and arborvitae (World/Exterior picks one of a kind's for
	-- each plant and scales it to the plant, keeping it clear of the house),
	-- and the streetlamp (its arm toward its -z). Each stands on its foot:
	-- `floor` is its box's bottom (roots under the lawn), `centre` { x, z }
	-- its box's middle from its foot.
	Outside = {
		TreeOakA = {
			mesh = "TreeOakA",
			id = 125811147058903,
			size = { 13.6, 24.3, 15.07 },
			centre = { 0.266, -0.328 },
			floor = -0.5,
		},
		TreeOakB = {
			mesh = "TreeOakB",
			id = 134012809604702,
			size = { 14.99, 22.75, 12.78 },
			centre = { 0.951, -0.353 },
			floor = -0.5,
		},
		TreeTurning = {
			mesh = "TreeTurning",
			id = 99530640759836,
			size = { 15.55, 25.37, 13.63 },
			centre = { 0.555, 1.346 },
			floor = -0.5,
		},
		TreeBareA = {
			mesh = "TreeBareA",
			id = 106358727140238,
			size = { 15.11, 29.88, 19.82 },
			centre = { -0.379, 1.295 },
			floor = -0.5,
		},
		TreeBareB = {
			mesh = "TreeBareB",
			id = 115835912297892,
			size = { 15.55, 29.4, 16.06 },
			centre = { 0.437, 1.375 },
			floor = -0.5,
		},
		ConiferA = {
			mesh = "ConiferA",
			id = 80010507703410,
			size = { 9.96, 24.4, 9.39 },
			centre = { -0.04, -0.122 },
			floor = -0.4,
		},
		ConiferB = {
			mesh = "ConiferB",
			id = 117494225464469,
			size = { 7.82, 24.4, 7.67 },
			centre = { -0.189, 0.271 },
			floor = -0.4,
		},
		BushA = {
			mesh = "BushA",
			id = 88573365626003,
			size = { 4.01, 3.05, 3.64 },
			centre = { -0.083, -0.171 },
			floor = -0.394,
		},
		BushB = {
			mesh = "BushB",
			id = 111446692908313,
			size = { 4.87, 2.4, 3.28 },
			centre = { 0.071, -0.13 },
			floor = -0.285,
		},
		Arborvitae = {
			mesh = "Arborvitae",
			id = 100431676163808,
			size = { 3.13, 9.86, 3.31 },
			centre = { 0.13, 0.086 },
			floor = -0.4,
		},
		Streetlamp = {
			mesh = "Streetlamp",
			id = 137753370874907,
			size = { 0.68, 14.63, 3.52 },
			centre = { 0, -1.42 },
			floor = -0.4,
		},
	},
	-- The Guest (V5, the Guest remodelled; tools/blender/guest.py, imported
	-- 2026-10-14): his skinned pieces, which Stalker/GuestSkin dresses his rig
	-- in once every one is in (Data/GuestRig says where each goes and what it
	-- looks like; the looks are assets/kit/GuestBody, GuestMask, GuestMaskWorn
	-- and GuestMaskBroken).
	Guest = {
		GuestHead = { mesh = "GuestHead", id = 116464708084706 },
		GuestLeftHand = { mesh = "GuestLeftHand", id = 125633572685797 },
		GuestLeftLowerSleeve = { mesh = "GuestLeftLowerSleeve", id = 137034571852377 },
		GuestLeftShin = { mesh = "GuestLeftShin", id = 98935851798141 },
		GuestLeftSkirt = { mesh = "GuestLeftSkirt", id = 109765121139336 },
		GuestLeftTatters = { mesh = "GuestLeftTatters", id = 111789135661730 },
		GuestLeftThigh = { mesh = "GuestLeftThigh", id = 114857352052029 },
		GuestLeftUpperSleeve = { mesh = "GuestLeftUpperSleeve", id = 112478629883862 },
		GuestMask = { mesh = "GuestMask", id = 106585964550771 },
		GuestMaskBroken = { mesh = "GuestMaskBroken", id = 89138912418773 },
		GuestMaskVoid = { mesh = "GuestMaskVoid", id = 77142676741337 },
		GuestMaskWorn = { mesh = "GuestMaskWorn", id = 76708660426120 },
		GuestRightHand = { mesh = "GuestRightHand", id = 108105103868111 },
		GuestRightLowerSleeve = { mesh = "GuestRightLowerSleeve", id = 128531317848533 },
		GuestRightShin = { mesh = "GuestRightShin", id = 120434625202377 },
		GuestRightSkirt = { mesh = "GuestRightSkirt", id = 82539605710468 },
		GuestRightTatters = { mesh = "GuestRightTatters", id = 136964689550940 },
		GuestRightThigh = { mesh = "GuestRightThigh", id = 127672261399745 },
		GuestRightUpperSleeve = { mesh = "GuestRightUpperSleeve", id = 93719928384649 },
		GuestShardA = { mesh = "GuestShardA", id = 84659231066436 },
		GuestShardB = { mesh = "GuestShardB", id = 130187619749870 },
		GuestShardC = { mesh = "GuestShardC", id = 100941709935476 },
		GuestTorso = { mesh = "GuestTorso", id = 105058749637350 },
	},
	-- The wardrobe (V6, tools/blender/wardrobe.py, batch "wardrobe", imported
	-- again 2026-10-15, lined and baked piece by piece): every garment's pieces, worn on the body's parts
	-- (Data/Wardrobe says which goes where, Data/KitWear how each fits;
	-- World/Kit.wear). The right side's pieces wear the left's looks
	-- (assets/kit: the same maps under the right's name).
	Wear = {
		CardiganHem = { mesh = "CardiganHem", id = 104482260737307 },
		CardiganLowerSleeveL = { mesh = "CardiganLowerSleeveL", id = 109665340153242 },
		CardiganLowerSleeveR = { mesh = "CardiganLowerSleeveR", id = 89024426362957 },
		CardiganTorso = { mesh = "CardiganTorso", id = 99375058633191 },
		CardiganUpperSleeveL = { mesh = "CardiganUpperSleeveL", id = 91390746308572 },
		CardiganUpperSleeveR = { mesh = "CardiganUpperSleeveR", id = 98332155578377 },
		CordsLowerLegL = { mesh = "CordsLowerLegL", id = 82763034294303 },
		CordsLowerLegR = { mesh = "CordsLowerLegR", id = 139303812501813 },
		CordsUpperLegL = { mesh = "CordsUpperLegL", id = 106309933283122 },
		CordsUpperLegR = { mesh = "CordsUpperLegR", id = 135312650570306 },
		CordsWaist = { mesh = "CordsWaist", id = 107740005080928 },
		FlannelLowerSleeveL = { mesh = "FlannelLowerSleeveL", id = 81782971186395 },
		FlannelLowerSleeveR = { mesh = "FlannelLowerSleeveR", id = 134867154266093 },
		FlannelTorso = { mesh = "FlannelTorso", id = 109390503944159 },
		FlannelUpperSleeveL = { mesh = "FlannelUpperSleeveL", id = 84737655551936 },
		FlannelUpperSleeveR = { mesh = "FlannelUpperSleeveR", id = 92387140331997 },
		JeansLowerLegL = { mesh = "JeansLowerLegL", id = 98874085415483 },
		JeansLowerLegR = { mesh = "JeansLowerLegR", id = 86535003885257 },
		JeansUpperLegL = { mesh = "JeansUpperLegL", id = 133880423074960 },
		JeansUpperLegR = { mesh = "JeansUpperLegR", id = 104244316370045 },
		JeansWaist = { mesh = "JeansWaist", id = 93057008147757 },
		LoaferL = { mesh = "LoaferL", id = 97389437662340 },
		LoaferR = { mesh = "LoaferR", id = 118661961182274 },
		SneakerL = { mesh = "SneakerL", id = 118271941223667 },
		SneakerR = { mesh = "SneakerR", id = 130295937576954 },
		VarsityHem = { mesh = "VarsityHem", id = 104270832333578 },
		VarsityLowerSleeveL = { mesh = "VarsityLowerSleeveL", id = 140717475289011 },
		VarsityLowerSleeveR = { mesh = "VarsityLowerSleeveR", id = 78482775914576 },
		VarsityTorso = { mesh = "VarsityTorso", id = 73526780854097 },
		VarsityUpperSleeveL = { mesh = "VarsityUpperSleeveL", id = 113106966613655 },
		VarsityUpperSleeveR = { mesh = "VarsityUpperSleeveR", id = 72897877575382 },
		WindbreakerHem = { mesh = "WindbreakerHem", id = 109080177242873 },
		WindbreakerLowerSleeveL = { mesh = "WindbreakerLowerSleeveL", id = 114701867504005 },
		WindbreakerLowerSleeveR = { mesh = "WindbreakerLowerSleeveR", id = 76976727931786 },
		WindbreakerTorso = { mesh = "WindbreakerTorso", id = 91519662050938 },
		WindbreakerUpperSleeveL = { mesh = "WindbreakerUpperSleeveL", id = 124085663213815 },
		WindbreakerUpperSleeveR = { mesh = "WindbreakerUpperSleeveR", id = 124906416309368 },
	},
	-- The tools in your hand and on the tables (the same batch; World/ToolModel,
	-- World/Kit.dressTool).
	Tools = {
		ToolBoltCutters = { mesh = "ToolBoltCutters", id = 116390461494288 },
		ToolCrowbar = { mesh = "ToolCrowbar", id = 133944461991754 },
		ToolLantern = { mesh = "ToolLantern", id = 77703166803170 },
		ToolRadio = { mesh = "ToolRadio", id = 114854761143227 },
		ToolSalts = { mesh = "ToolSalts", id = 140453181174772 },
		ToolTorch = { mesh = "ToolTorch", id = 81344747482525 },
	},
}
