-- The kit: modelled pieces from Blender (tools/blender/kit.py) that dress
-- PropFactory's grey-box (the visual rework; World/Kit). A kind listed here
-- with its mesh in the place (ReplicatedStorage.Kit) wears it; any other
-- kind stays as blocks, so the kit can arrive a batch at a time.
--
-- mesh:  the MeshPart's name in ReplicatedStorage.Kit
-- size:  the size it was modelled at, in studs { x, y, z } (kit.py's
--        report): World/Kit fits it to the prop's own size, and Kit.spec
--        checks they agree, so nothing is stretched out of shape
-- keep:  the grey-box parts that stay visible because the game draws on them
--        or animates them (a clock's face and hands, a screen)
-- turn:  degrees about Y if the import faces another way (0: the front is +Z)

return {
	Props = {
		Chair = { mesh = "Chair", size = { 2.5, 4.02, 2.42 } },
		FloorLamp = { mesh = "FloorLamp", size = { 1.5, 5.95, 1.5 } },
	},
	-- Door slabs (World/LevelBuilder's "Slab"), fitted to the slab.
	Slabs = {
		Door = { mesh = "Door", size = { 5.8, 7.8, 0.43 } },
	},
}
