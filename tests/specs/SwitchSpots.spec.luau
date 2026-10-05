-- A room's light switch (Logic/SwitchSpots): beside the doorway, never in
-- it, never past the room's corner, on the room's own side of the wall.
return function(test, check, Shared, require)
	local SwitchSpots = require(Shared.Logic.SwitchSpots)
	local cfg = { DoorWidth = 6, WallFace = 0.55, Beside = 0.9, Margin = 0.8 }

	-- A 20x20 room from (0,0) to (20,20); a doorway in its north wall (z = 0)
	-- at x = 10, opening into the room (+z).
	local rect = { x0 = 0, z0 = 0, x1 = 20, z1 = 20 }

	test("beside the door, clear of the opening, just inside the room", function()
		local spot = SwitchSpots.place(rect, { x = 10, z = 0 }, { x = 0, z = 1 }, cfg)
		check.truthy(spot ~= nil, "a spot")
		check.near(math.abs(spot.x - 10), 3 + 0.9, 1e-6, "past the door's edge")
		check.near(spot.z, 0.55, 1e-6, "on the room's wall face")
	end)

	test("a door near a corner puts the switch on the other side", function()
		-- Doorway 3.5 from the west corner: the +side has no room.
		local spot = SwitchSpots.place(rect, { x = 3.5, z = 0 }, { x = 0, z = 1 }, cfg)
		check.truthy(spot ~= nil and spot.x > 3.5, "the side with wall to spare")
		local other = SwitchSpots.place(rect, { x = 16.5, z = 0 }, { x = 0, z = 1 }, cfg)
		check.truthy(other ~= nil and other.x < 16.5, "and the mirror case")
	end)

	test("a doorway filling its wall gets no switch", function()
		local narrow = { x0 = 0, z0 = 0, x1 = 8, z1 = 20 }
		check.equal(SwitchSpots.place(narrow, { x = 4, z = 0 }, { x = 0, z = 1 }, cfg), nil, "no room either side")
	end)

	test("walls running north-south work the same way", function()
		-- West wall (x = 0), door at z = 10, into the room (+x).
		local spot = SwitchSpots.place(rect, { x = 0, z = 10 }, { x = 1, z = 0 }, cfg)
		check.truthy(spot ~= nil, "a spot")
		check.near(spot.x, 0.55, 1e-6, "on the wall face")
		check.near(math.abs(spot.z - 10), 3.9, 1e-6, "beside the door")
	end)
end
