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
	},
	-- Door slabs (World/LevelBuilder's "Slab"), fitted to the slab.
	Slabs = {
		Door = { mesh = "Door", id = 120563615441757, size = { 5.8, 7.8, 0.48 } },
		-- A gate into a wing, glazed above its sill (kit.py kit3): over the
		-- whole door, its glass the game's.
		GlassDoor = { mesh = "GlassDoor", id = 92159403589343, size = { 5.8, 7.8, 0.48 } },
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
}
