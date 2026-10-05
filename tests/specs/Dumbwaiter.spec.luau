-- Where a dumbwaiter can run (Logic/Dumbwaiter): two rooms one above the
-- other on the same wall line, the spot on that wall, clear of doorways and,
-- given the templates, of the furniture both rooms will have.
return function(test, check, Shared, require)
	local Config = require(Shared.Config)
	local Rooms = require(Shared.Data.Rooms)
	local Props = require(Shared.Data.Props)
	local Dumbwaiter = require(Shared.Logic.Dumbwaiter)
	local HouseSize = require(Shared.Logic.HouseSize)
	local MansionGen = require(Shared.Logic.MansionGen)
	local RoomFit = require(Shared.Logic.RoomFit)
	local RoomRects = require(Shared.Logic.RoomRects)

	local cfg = Config.Dumbwaiter
	local templates = Rooms.MansionById

	local function roomsById(layout)
		local byId = {}
		for _, room in layout.rooms do
			byId[room.id] = room
		end
		return byId
	end

	local function overlaps(a, b): boolean
		return a.x0 < b.x1 and b.x0 < a.x1 and a.z0 < b.z1 and b.z0 < a.z1
	end

	-- Houses 1 to 40, generated once for every test.
	local houses = {}
	local function house(seed: number)
		houses[seed] = houses[seed] or MansionGen.generate(seed, Rooms.Mansion, Config.Mansion)
		return houses[seed]
	end

	test("every spot is on both rooms' shared wall, clear of every doorway", function()
		local found = 0
		for seed = 1, 40 do
			local layout = house(seed)
			local byId = roomsById(layout)
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
			local layout = house(seed)
			for _, pair in Dumbwaiter.pairs(layout, cfg, templates) do
				check.truthy(pair.ground ~= layout.start and pair.ground ~= layout.deliberation, "seed " .. seed)
				for _, room in layout.rooms do
					if room.id == pair.ground or room.id == pair.upper then
						check.truthy(not room.tall, "not a tall room")
					end
				end
			end
		end
	end)

	test("a room's furniture: its fitted solid pieces, inside its walls", function()
		for seed = 1, 10 do
			local layout = house(seed)
			for _, room in layout.rooms do
				if not room.tall then
					local fitted = RoomFit.inMansion(layout, room, templates[room.template], cfg.Wall)
					local solid, area = 0, 0
					for _, prop in fitted.props do
						local info = Props.Kinds[prop.kind]
						if info == nil or info.collide ~= false then
							local ex, ez = RoomFit.footprint(prop.kind, prop.ry)
							solid += 1
							area += 4 * ex * ez
						end
					end
					if room.lantern then
						local ex, ez = RoomFit.footprint("Shrine", 0)
						solid += 1
						area += 4 * ex * ez
					end
					local boxes = Dumbwaiter.furniture(layout, room, templates, cfg.Wall)
					local label = "seed " .. seed .. " room " .. room.id
					check.equal(#boxes, solid, label .. ": one box per solid piece")
					local total = 0
					for _, b in boxes do
						total += (b.x1 - b.x0) * (b.z1 - b.z0)
						-- Turned with the room: inside its walls, not across them.
						check.truthy(
							b.x0 >= room.x + cfg.Wall - 0.01
								and b.x1 <= room.x + room.w - cfg.Wall + 0.01
								and b.z0 >= room.z + cfg.Wall - 0.01
								and b.z1 <= room.z + room.d - cfg.Wall + 0.01,
							label .. ": inside the walls"
						)
					end
					check.near(total, area, 1e-6, label .. ": the pieces' own sizes")
				end
			end
		end
	end)

	test("the casing's footprint: against the wall, the crank on its right downstairs", function()
		local pad = cfg.FurnitureClear
		-- The north wall (the room to its south): facing it you look north, with
		-- east on your right.
		local north = { x = 10, z = 0, into = { x = 0, z = 1 } }
		local up = Dumbwaiter.footprint(north, cfg, false)
		check.near(up.x0, 10 - cfg.Width / 2 - pad, 1e-9, "west edge")
		check.near(up.x1, 10 + cfg.Width / 2 + pad, 1e-9, "east edge")
		check.near(up.z0, cfg.Inset - pad, 1e-9, "its back, off the wall's line")
		check.near(up.z1, cfg.Inset + cfg.Depth + pad, 1e-9, "its front")
		local down = Dumbwaiter.footprint(north, cfg, true)
		check.near(down.x0, up.x0, 1e-9, "nothing more on the left")
		check.near(down.x1, up.x1 + cfg.CrankSide, 1e-9, "the crank to the east")
		-- The east wall (the room to its west): facing it, south is on your right.
		local east = Dumbwaiter.footprint({ x = 0, z = 10, into = { x = -1, z = 0 } }, cfg, true)
		check.near(east.x1, -cfg.Inset + pad, 1e-9, "its back, off the wall's line")
		check.near(east.x0, -cfg.Inset - cfg.Depth - pad, 1e-9, "its front")
		check.near(east.z0, 10 - cfg.Width / 2 - pad, 1e-9, "north edge")
		check.near(east.z1, 10 + cfg.Width / 2 + cfg.CrankSide + pad, 1e-9, "the crank to the south")
	end)

	test("with the templates, the box the build checks misses both rooms' furniture", function()
		local found = 0
		for seed = 1, 40 do
			local layout = house(seed)
			local byId = roomsById(layout)
			for _, pair in Dumbwaiter.pairs(layout, cfg, templates) do
				local ground, upper = byId[pair.ground], byId[pair.upper]
				local spots = Dumbwaiter.spots(layout, ground, upper, cfg, templates)
				check.truthy(#spots > 0, "seed " .. seed .. ": an offered pair has a spot")
				for _, spot in spots do
					found += 1
					-- server/Puzzles/Dumbwaiter's Kind._clear, flat.
					local reach = 0.6 + cfg.Depth / 2
					local cx, cz = spot.x + spot.into.x * reach, spot.z + spot.into.z * reach
					local half = (cfg.Depth - 0.2) / 2
					local ex = spot.into.x ~= 0 and half or cfg.Width / 2
					local ez = spot.into.z ~= 0 and half or cfg.Width / 2
					local casing = { x0 = cx - ex, x1 = cx + ex, z0 = cz - ez, z1 = cz + ez }
					for _, room in { ground, upper } do
						for _, piece in Dumbwaiter.furniture(layout, room, templates, cfg.Wall) do
							check.truthy(not overlaps(casing, piece), "seed " .. seed .. ": clear in room " .. room.id)
						end
					end
				end
			end
		end
		check.truthy(found > 0, "some houses still have one")
	end)

	test("the furniture only takes spots away, and takes some walls whole", function()
		local taken = 0
		for seed = 1, 40 do
			local layout = house(seed)
			local byId = roomsById(layout)
			local bare = {}
			for _, pair in Dumbwaiter.pairs(layout, cfg) do
				bare[pair.ground .. "/" .. pair.upper] = true
			end
			for _, pair in Dumbwaiter.pairs(layout, cfg, templates) do
				local key = pair.ground .. "/" .. pair.upper
				check.truthy(bare[key], "seed " .. seed .. ": " .. key .. " is a pair without furniture too")
				local wall = {}
				for _, spot in Dumbwaiter.spots(layout, byId[pair.ground], byId[pair.upper], cfg) do
					wall[spot.x .. "," .. spot.z] = true
				end
				for _, spot in Dumbwaiter.spots(layout, byId[pair.ground], byId[pair.upper], cfg, templates) do
					check.truthy(wall[spot.x .. "," .. spot.z], "seed " .. seed .. ": a spot on the bare wall")
				end
				bare[key] = nil
			end
			for _ in bare do
				taken += 1
			end
		end
		check.truthy(taken > 0, "some walls are taken by furniture")
	end)

	test("seed 10 for four: the den's wall under the master bedroom is taken", function()
		-- Build 2026-10-05.29 planned a dumbwaiter between seed 3's garage and
		-- the nursery over it, and the build found no room for it (seen in
		-- Studio). Since the cellar and the attic (L2.2, L2.3) that house has
		-- changed; this pins another pair whose shared wall the furniture
		-- fills. (If the generator changes, pin another such pair.)
		local mansion = HouseSize.config(Config.Mansion, Config.Progression, 4)
		local layout = MansionGen.generate(10, Rooms.Mansion, mansion)
		local byId = roomsById(layout)
		local ground, upper = byId[15], byId[21]
		check.equal(ground and ground.template, "den", "room 15")
		check.equal(upper and upper.template, "master_bedroom", "room 21")
		check.truthy(#Dumbwaiter.spots(layout, ground, upper, cfg) > 0, "the shared wall has spots")
		check.equal(#Dumbwaiter.spots(layout, ground, upper, cfg, templates), 0, "none clear of the furniture")
		for _, pair in Dumbwaiter.pairs(layout, cfg, templates) do
			check.truthy(not (pair.ground == 15 and pair.upper == 21), "not offered to the planner")
		end
	end)
end
