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
	},
	-- Door slabs (World/LevelBuilder's "Slab"), fitted to the slab.
	Slabs = {
		Door = { mesh = "Door", id = 76133714825437, size = { 5.8, 7.8, 0.43 } },
	},
	-- The architecture's pieces (kit.py golden2), each in place of one
	-- grey-box part (World/MansionBuilder's railings and the grand staircase;
	-- World/Kit.dressPart). `fit`: sized to the part (a rail to its length);
	-- "y": to its height only (a baluster to its rail, on the stairs too).
	Parts = {
		Baluster = { mesh = "Baluster", id = 90124072108267, size = { 0.25, 3.1, 0.24 }, fit = "y" },
		Newel = { mesh = "Newel", id = 124411410635746, size = { 0.86, 3.8, 0.86 } },
		Handrail = { mesh = "Handrail", id = 131992520560699, size = { 0.45, 0.3, 4 }, fit = true },
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
}
