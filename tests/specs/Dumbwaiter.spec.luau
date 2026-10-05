-- Where a dumbwaiter can run (Logic/Dumbwaiter): two rooms one above the
-- other on the same wall line, the spot on that wall, clear of doorways.
return function(test, check, Shared, require)
	local Config = require(Shared.Config)
	local Rooms = require(Shared.Data.Rooms)
	local Dumbwaiter = require(Shared.Logic.Dumbwaiter)
	local MansionGen = require(Shared.Logic.MansionGen)
	local RoomRects = require(Shared.Logic.RoomRects)

	local cfg = Config.Dumbwaiter

	test("every spot is on both rooms' shared wall, clear of every doorway", function()
		local found = 0
		for seed = 1, 40 do
			local layout = MansionGen.generate(seed, Rooms.Mansion, Config.Mansion)
			local byId = {}
			for _, room in layout.rooms do
				byId[room.id] = room
			end
			for _, pair in Dumbwaiter.pairs(layout, cfg) do
				local ground, upper = byId[pair.ground], byId[pair.upper]
				check.equal(ground.floor or 0, 0, "ground floor")
				check.equal(upper.floor, 1, "upper floor")
				for _, spot in Dumbwaiter.spots(layout, ground, upper, cfg) do
					found += 1
					-- On the edge of both rects, within their span.
					for _, room in { ground, upper } do
						local onX = spot.x >= room.x and spot.x <= room.x + room.w
						local onZ = spot.z >= room.z and spot.z <= room.z + room.d
						check.truthy(onX and onZ, "seed " .. seed .. ": inside both rooms' spans")
					end
					for _, seam in layout.seams do
						if seam.connected and seam.dir then
							local x, z = RoomRects.doorPoint(seam.dir, seam.line, seam.along)
							check.truthy(
								math.abs(x - spot.x) + math.abs(z - spot.z) >= cfg.DoorClear,
								"seed " .. seed .. ": clear of " .. seam.id
							)
						end
					end
				end
			end
		end
		check.truthy(found > 0, "some houses have one")
	end)

	test("never the hall, the stairs or the dining room", function()
		for seed = 1, 40 do
			local layout = MansionGen.generate(seed, Rooms.Mansion, Config.Mansion)
			for _, pair in Dumbwaiter.pairs(layout, cfg) do
				check.truthy(pair.ground ~= layout.start and pair.ground ~= layout.deliberation, "seed " .. seed)
				for _, room in layout.rooms do
					if room.id == pair.ground or room.id == pair.upper then
						check.truthy(not room.tall, "not a tall room")
					end
				end
			end
		end
	end)
end
