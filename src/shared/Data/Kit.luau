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
		Chair = { mesh = "Chair", id = 94660495904035, size = { 2.5, 4.02, 2.42 }, names = { "^chair" } },
		-- Its bulb shines through the linen all round, as the old block shade let
		-- it (the owner, 2026-10-12: a shade that shadows its own bulb only lets
		-- light out of the bottom): no shadow from the lamp itself.
		FloorLamp = { mesh = "FloorLamp", id = 115301339552852, size = { 1.5, 5.95, 1.5 }, shadow = false },
		-- The golden room (kit.py golden; imported 2026-10-12): the grand hall,
		-- the dining room, the living room.
		DiningTable = { mesh = "DiningTable", id = 89708986746860, size = { 6, 3.4, 12 } },
		Sofa = { mesh = "Sofa", id = 112802030819273, size = { 9, 3.5, 3.97 } },
		Armchair = { mesh = "Armchair", id = 79903202176202, size = { 4, 4, 3.97 } },
		-- The living room's and the study's bookcases only (the china cabinet and
		-- the utility rooms' shelving wait for their own).
		Shelf = { mesh = "Shelf", id = 78480435296134, size = { 8.2, 9, 2.12 }, names = { "^books" } },
		-- The case only: the face, hands, pendulum and glass are the game's own.
		GrandfatherClock = {
			mesh = "GrandfatherClock",
			id = 87290908046199,
			size = { 2.66, 8.38, 2.14 },
			keep = { "Bezel", "Dial", "Tick", "HourHand", "MinuteHand", "Cap", "Pendulum", "Door" },
		},
		CoatRack = { mesh = "CoatRack", id = 90933748796114, size = { 1.32, 7, 1.32 } },
		Bench = { mesh = "Bench", id = 137534368415543, size = { 8, 2.6, 2.3 } },
		Rug = { mesh = "Rug", id = 138678122533642, size = { 10, 0.06, 14.76 } },
	},
	-- Door slabs (World/LevelBuilder's "Slab"), fitted to the slab.
	Slabs = {
		Door = { mesh = "Door", id = 76133714825437, size = { 5.8, 7.8, 0.43 } },
	},
}
