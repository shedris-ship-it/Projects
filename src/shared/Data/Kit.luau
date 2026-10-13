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
	-- The Guest (V5, the Guest remodelled; tools/blender/guest.py): his skinned
	-- pieces, which Stalker/GuestSkin dresses his rig in once every one is
	-- in (Data/GuestRig says where each goes and what it looks like; the
	-- looks are assets/kit/GuestBody, GuestMask, GuestMaskWorn and
	-- GuestMaskBroken).
	Guest = {
		GuestHead = { mesh = "GuestHead" },
		GuestLeftHand = { mesh = "GuestLeftHand" },
		GuestLeftLowerSleeve = { mesh = "GuestLeftLowerSleeve" },
		GuestLeftShin = { mesh = "GuestLeftShin" },
		GuestLeftSkirt = { mesh = "GuestLeftSkirt" },
		GuestLeftTatters = { mesh = "GuestLeftTatters" },
		GuestLeftThigh = { mesh = "GuestLeftThigh" },
		GuestLeftUpperSleeve = { mesh = "GuestLeftUpperSleeve" },
		GuestMask = { mesh = "GuestMask" },
		GuestMaskBroken = { mesh = "GuestMaskBroken" },
		GuestMaskVoid = { mesh = "GuestMaskVoid" },
		GuestMaskWorn = { mesh = "GuestMaskWorn" },
		GuestRightHand = { mesh = "GuestRightHand" },
		GuestRightLowerSleeve = { mesh = "GuestRightLowerSleeve" },
		GuestRightShin = { mesh = "GuestRightShin" },
		GuestRightSkirt = { mesh = "GuestRightSkirt" },
		GuestRightTatters = { mesh = "GuestRightTatters" },
		GuestRightThigh = { mesh = "GuestRightThigh" },
		GuestRightUpperSleeve = { mesh = "GuestRightUpperSleeve" },
		GuestShardA = { mesh = "GuestShardA" },
		GuestShardB = { mesh = "GuestShardB" },
		GuestShardC = { mesh = "GuestShardC" },
		GuestTorso = { mesh = "GuestTorso" },
	},
}
