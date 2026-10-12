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
		-- The spike (tools/blender/kit.py spike).
		Chair = { mesh = "Chair", size = { 2.5, 4.02, 2.42 } },
		FloorLamp = { mesh = "FloorLamp", size = { 1.5, 5.95, 1.5 } },
		-- The golden room (kit.py golden): the grand hall, the dining room, the
		-- living room.
		DiningTable = { mesh = "DiningTable", size = { 6, 3.4, 12 } },
		Sofa = { mesh = "Sofa", size = { 9, 3.5, 3.97 } },
		Armchair = { mesh = "Armchair", size = { 4, 4, 3.97 } },
		Shelf = { mesh = "Shelf", size = { 8.2, 9, 2.12 } },
		-- The case only: the face, hands, pendulum and glass are the game's own.
		GrandfatherClock = {
			mesh = "GrandfatherClock",
			size = { 2.66, 8.38, 2.14 },
			keep = { "Bezel", "Dial", "Tick", "HourHand", "MinuteHand", "Cap", "Pendulum", "Door" },
		},
		CoatRack = { mesh = "CoatRack", size = { 1.32, 7, 1.32 } },
		Bench = { mesh = "Bench", size = { 8, 2.6, 2.3 } },
		Rug = { mesh = "Rug", size = { 10, 0.06, 14.76 } },
	},
	-- Door slabs (World/LevelBuilder's "Slab"), fitted to the slab.
	Slabs = {
		Door = { mesh = "Door", size = { 5.8, 7.8, 0.43 } },
	},
}
