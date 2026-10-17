-- The lobby mall's layout (Logic/MallLayout over Data/Mall): walls cut by
-- their doors, and the rules that keep the mall quick to get round.
return function(test, check, Shared, require)
	local MallLayout = require(Shared.Logic.MallLayout)
	local Mall = require(Shared.Data.Mall)
	local Config = require(Shared.Config)

	test("a wall with a door is two pieces and a lintel", function()
		local pieces = MallLayout.segments(0, 30, { { from = 10, to = 20, height = 12 } }, 26)
		check.equal(#pieces, 3, "left, lintel, right")
		check.equal(pieces[1].to, 10, "left stops at the door")
		check.equal(pieces[2].bottom, 12, "the lintel starts at the door's head")
		check.equal(pieces[2].top, 26, "and goes to the ceiling")
		check.equal(pieces[3].from, 20, "right starts after it")
	end)

	test("a door as tall as the wall leaves no lintel, and one at a corner no stub", function()
		local pieces = MallLayout.segments(0, 30, { { from = 0, to = 30, height = 22 } }, 22)
		check.equal(#pieces, 0, "the whole wall is a doorway")
		local edge = MallLayout.segments(0, 30, { { from = 0, to = 10, height = 13 } }, 14)
		check.equal(#edge, 2, "the lintel and the rest")
		check.equal(edge[1].bottom, 13, "the lintel first")
	end)

	test("a door cuts both of its rooms' walls", function()
		local court = Mall.Rooms.court
		local north
		for _, side in MallLayout.sides(court.rect) do
			if side.side == "N" then
				north = side
			end
		end
		local cuts = MallLayout.cutsFor("court", north, Mall.Doors)
		check.equal(#cuts, 3, "the court's north wall: the boutique, the video store, the arcade")
		local video
		for _, side in MallLayout.sides(Mall.Rooms.video.rect) do
			if side.side == "S" then
				video = side
			end
		end
		check.equal(#MallLayout.cutsFor("video", video, Mall.Doors), 1, "the video store's front")
	end)

	test("the mall's layout keeps its rules", function()
		local problems = MallLayout.check(Mall, Config.Mall.FrontReach)
		check.equal(#problems, 0, table.concat(problems, "; "))
	end)

	test("the garage is reached only through the video store", function()
		local ways = MallLayout.neighbours(Mall, "garage")
		check.equal(#ways, 1, "one way in")
		check.equal(ways[1], "video", "through the back of the video store")
	end)

	test("the shutter and the diner close the hall's two ends", function()
		local shutter, diner
		for _, door in Mall.Doors do
			if door.b == "concourse" then
				shutter = door
			elseif door.b == "diner" then
				diner = door
			end
		end
		check.truthy(shutter and shutter.grille == "giant", "the shutter is the giant grille")
		check.equal(shutter.at, Mall.Rooms.court.rect[3], "on the court's east end")
		check.equal(diner.at, Mall.Rooms.court.rect[1], "the diner on its west end")
	end)

	test("nothing stands in front of an ad lightbox", function()
		check.truthy(#Mall.Ads >= 4, "the four ad slots are there")
		for _, ad in Mall.Ads do
			check.truthy(
				ad.w >= 8 and ad.h >= 4.5 and ad.w <= 32 and ad.h <= 18,
				ad.slot .. " is within Roblox's sizes"
			)
			local aspect = ad.w / ad.h
			check.truthy(aspect > 1.55 and aspect < 2, ad.slot .. " is near 16:9")
		end
		local blockers = MallLayout.adBlockers(Mall, 14)
		check.equal(#blockers, 0, table.concat(blockers, "; "))
		-- And it would see a column put in front of one.
		local moved = table.clone(Mall)
		moved.Galleries = { { room = "court", level = 22, columns = { { -42, -21 } } } }
		check.equal(#MallLayout.adBlockers(moved, 14), 1, "a column before the west-north box")
		-- Or beside one, where it hides the box from across the court.
		moved.Galleries = { { room = "court", level = 22, columns = { { -41, -13 } } } }
		check.equal(#MallLayout.adBlockers(moved, 14), 1, "a column off the west-north box's corner")
		moved.Galleries = { { room = "court", level = 22, columns = { { -30, -2 } } } }
		check.equal(#MallLayout.adBlockers(moved, 14), 0, "one well to the side is no trouble")
	end)

	test("the gallery's columns stand between the shopfronts, clear of everything", function()
		local clashes = MallLayout.columnClashes(Mall)
		check.equal(#clashes, 0, table.concat(clashes, "; "))
		local moved = table.clone(Mall)
		moved.Galleries = {
			{ room = "court", level = 22, depth = 9, sides = { "N", "W" }, columns = { { 30, -21 }, { 0, 0 } } },
		}
		local text = table.concat(MallLayout.columnClashes(moved), "; ")
		check.truthy(text:find("hides a front"), "one before the arcade: " .. text)
		check.truthy(text:find("Fountain"), "one in the fountain: " .. text)
	end)

	test("the shops and garage: nothing through a wall, in another, or in a doorway", function()
		local shops = { "boutique", "video", "arcade", "electronics", "diner", "garage" }
		local problems = MallLayout.misplaced(Mall, shops)
		check.equal(#problems, 0, table.concat(problems, "; "))
		-- And it sees each kind of mistake.
		local bad = table.clone(Mall)
		bad.Blocks = {
			{ room = "video", name = "Through", x = 15.5, y = 2, z = -45, size = { 3, 4, 3 } },
			{ room = "video", name = "A", x = 0, y = 2, z = -50, size = { 3, 4, 3 } },
			{ room = "video", name = "B", x = 1, y = 2, z = -50, size = { 3, 4, 3 } },
			{ room = "video", name = "Doorway", x = 0, y = 2, z = -32, size = { 2, 4, 2 } },
			{ room = "video", name = "Window", window = true, x = -10, y = 2, z = -32.5, size = { 2, 4, 2 } },
		}
		local text = table.concat(MallLayout.misplaced(bad, shops), "; ")
		check.truthy(text:find("Through at 15.5, %-45 goes through"), "through a wall: " .. text)
		check.truthy(text:find("stand in each other"), "in another: " .. text)
		check.truthy(text:find("Doorway at 0, %-32 stands in the way"), "in the doorway: " .. text)
		check.truthy(not text:find("Window"), "a window display is let be: " .. text)
	end)

	test("open floor is found clear of everything, room for a full lobby", function()
		local total = 0
		for _, room in { "court", "garage", "diner", "video", "arcade", "boutique", "electronics" } do
			local spots = MallLayout.openSpots(Mall, room, 4, 1.5)
			total += #spots
			for _, p in spots do
				for _, b in Mall.Blocks do
					if b.room == room and b.collide ~= false then
						local hx, hz = b.size[1] / 2, b.size[3] / 2
						if b.shape == "Cylinder" then
							hx, hz = b.size[2] / 2, b.size[3] / 2
						end
						check.truthy(
							b.rot ~= nil or math.abs(p[1] - b.x) >= hx or math.abs(p[2] - b.z) >= hz,
							string.format("%s's spot %g, %g is in its %s", room, p[1], p[2], b.name)
						)
					end
				end
			end
		end
		-- (Fifty players, and then some, can stand in the lit corner.)
		check.truthy(total >= 80, "spots for a full lobby: " .. total)
		check.truthy(#MallLayout.openSpots(Mall, "court", 4, 1.5) >= 40, "the court holds most of them")
	end)

	test("each party car has its own door to drive out of, and room to stand in", function()
		local garage = Mall.Rooms.garage.rect
		check.equal(#Mall.Cars.bays, 6, "six bays")
		for i, bay in Mall.Cars.bays do
			-- (A car is 7.45 x 14.4, its nose toward the door at the garage's north.)
			local x0, x1, z0, z1 = bay.x - 3.8, bay.x + 3.8, bay.z - 7.3, bay.z + 7.3
			check.truthy(x0 > garage[1] + 1 and x1 < garage[3] - 1, "bay " .. i .. " is inside the garage")
			local door
			for _, d in Mall.Doors do
				if d.a == "garage" and d.kind == "garage" and d.at == garage[2] and d.from <= x0 and d.to >= x1 then
					door = d
				end
			end
			check.truthy(door, "bay " .. i .. " has a door as wide as its car")
			check.truthy(door and door.height >= 5, "bay " .. i .. "'s door is tall enough for it")
			for _, b in Mall.Blocks do
				if b.room == "garage" and b.collide ~= false then
					local hx, hz = b.size[1] / 2, b.size[3] / 2
					check.truthy(
						b.x + hx <= x0 or b.x - hx >= x1 or b.z + hz <= z0 or b.z - hz >= z1,
						string.format("bay %d is clear of the %s", i, b.name)
					)
				end
			end
		end
	end)

	test("a broken layout is caught", function()
		local broken = {
			Rooms = {
				court = { rect = { -10, -10, 10, 10 } },
				shop = { rect = { 5, -30, 30, -10 } }, -- overlaps nothing, but its front is far
				lost = { rect = { 100, 100, 110, 110 } },
			},
			Doors = {
				{ a = "court", b = "shop", runs = "x", at = -10, from = 6, to = 9, height = 10, kind = "front" },
			},
			Fountain = { x = 0, z = 0 },
			Spawn = { room = "court", x = 50, z = 0 },
		}
		local problems = MallLayout.check(broken, 5)
		local text = table.concat(problems, "; ")
		check.truthy(text:find("lost has no way in"), "an unreachable room: " .. text)
		check.truthy(text:find("front is"), "a far front: " .. text)
		check.truthy(text:find("spawn"), "the spawn outside: " .. text)
	end)
end
