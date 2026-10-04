return function(test, check, Shared, require)
	local RoomRects = require(Shared.Logic.RoomRects)
	local LevelGraph = require(Shared.Logic.LevelGraph)
	local Rooms = require(Shared.Data.Rooms)
	local Config = require(Shared.Config)

	local function rect(id, x, z, w, d)
		return { id = id, x = x, z = z, w = w, d = d, floor = 0 }
	end

	test("contact finds the shared wall from either side", function()
		local a = rect(1, 0, 0, 30, 20)
		local b = rect(2, 30, -10, 20, 40) -- east of a, overlapping its whole east wall
		local c = RoomRects.contact(a, b)
		check.equal(c.dir, "E", "dir")
		check.equal(c.line, 30, "line")
		check.equal(c.from, 0, "from")
		check.equal(c.to, 20, "to")
		local back = RoomRects.contact(b, a)
		check.equal(back.dir, "W", "reverse dir")
		check.equal(back.line, 30, "reverse line")
		local below = RoomRects.contact(a, rect(3, 20, 20, 20, 20))
		check.equal(below.dir, "S", "south dir")
		check.equal(below.from, 20, "south from")
		check.equal(below.to, 30, "south to")
		-- Corners only touching, and gaps, are not contacts.
		check.equal(RoomRects.contact(a, rect(4, 30, 20, 10, 10)), nil, "corner")
		check.equal(RoomRects.contact(a, rect(5, 40, 0, 10, 10)), nil, "gap")
	end)

	test("overlaps ignores touching walls", function()
		check.truthy(not RoomRects.overlaps(rect(1, 0, 0, 20, 20), rect(2, 20, 0, 20, 20)), "touching")
		check.truthy(RoomRects.overlaps(rect(1, 0, 0, 20, 20), rect(2, 10, 10, 20, 20)), "overlapping")
	end)

	test("door spots sit on the lattice nearest the middle, clear of the corners", function()
		check.equal(RoomRects.doorAlong(0, 40, 10, 7), 20, "40 wall")
		check.equal(RoomRects.doorAlong(0, 20, 10, 7), 10, "20 wall")
		check.equal(RoomRects.doorAlong(0, 30, 10, 7), 10, "30 wall: tie goes low")
		check.equal(RoomRects.doorAlong(-20, 10, 10, 7), -10, "negative span")
		check.equal(RoomRects.doorAlong(0, 10, 10, 7), nil, "10 is too short")
		check.equal(
			RoomRects.doorAlong(0, 40, 10, 7, function(p)
				return p ~= 20
			end),
			10,
			"allowed filter"
		)
	end)

	test("roomAt finds rooms and returns nil in the void", function()
		local index = RoomRects.newIndex(10)
		index:Add(rect(1, 0, 0, 30, 20))
		index:Add(rect(2, 30, 0, 20, 20))
		check.equal(index:At(5, 5), 1, "inside 1")
		check.equal(index:At(29.9, 19.9), 1, "corner of 1")
		check.equal(index:At(30, 5), 2, "wall line goes east")
		check.equal(index:At(55, 5), nil, "void east")
		check.equal(index:At(5, -0.1), nil, "void north")
		check.truthy(index:Free(rect(3, 0, 20, 50, 10)), "free strip")
		check.truthy(not index:Free(rect(3, 20, 10, 20, 20)), "taken")
		check.truthy(index:Covers(rect(3, 10, 0, 30, 20)), "covered")
	end)

	test("outer spans skip walls shared with other rooms", function()
		local index = RoomRects.newIndex(10)
		local a = rect(1, 0, 0, 40, 30)
		index:Add(a)
		index:Add(rect(2, 10, 30, 20, 20)) -- under the middle of a's south wall
		local south = index:OuterSpans(a, "S")
		check.equal(#south, 2, "two stretches")
		check.equal(south[1].from, 0, "first from")
		check.equal(south[1].to, 10, "first to")
		check.equal(south[2].from, 30, "second from")
		check.equal(south[2].to, 40, "second to")
		local north = index:OuterSpans(a, "N")
		check.equal(#north, 1, "north is all outside")
		check.equal(north[1].to - north[1].from, 40, "north length")
	end)

	test("old cell layouts become 40x40 rects with doors at the middle of each wall", function()
		local layout = LevelGraph.generate(4242, Rooms.List, Config.Level)
		local rects = RoomRects.fromCells(layout, Config.Level.CellSize)
		local byId = {}
		for i, r in rects do
			check.equal(r.x, layout.rooms[i].gx * 40 - 20, "x")
			check.equal(r.z, layout.rooms[i].gz * 40 - 20, "z")
			byId[r.id] = r
		end
		local copy = RoomRects.seamsOfCells(layout, Config.Level)
		check.truthy(copy.seams ~= layout.seams, "the layout itself is untouched")
		check.equal(layout.seams[1].line, nil, "no geometry added to the original")
		for _, seam in copy.seams do
			local a = byId[seam.a]
			local cx, cz = RoomRects.center(a)
			local x, z = RoomRects.doorPoint(seam.dir, seam.line, seam.along)
			-- the middle of a's wall, as the old builder puts it
			check.equal(math.abs(x - cx) + math.abs(z - cz), 20, seam.id .. " door at a wall middle")
		end
		check.truthy(copy.exitDoor ~= nil, "exit door found")
	end)
end
