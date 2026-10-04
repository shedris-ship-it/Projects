return function(test, check, Shared, require)
	local Config = require(Shared.Config)
	local Rooms = require(Shared.Data.Rooms)
	local Graph = require(Shared.Logic.Graph)
	local LayoutValidator = require(Shared.Logic.LayoutValidator)
	local MansionGen = require(Shared.Logic.MansionGen)
	local MansionHouse = require(Shared.Logic.MansionHouse)
	local RoomRects = require(Shared.Logic.RoomRects)
	local FloorPlan = require(Shared.Logic.FloorPlan)

	local config = Config.Mansion
	local templates = Rooms.Mansion
	local byId = Rooms.MansionById

	-- Generated once and shared by the property tests below.
	local SEEDS = 250
	local layouts = {}
	local fallbacks, firstTry, attempts = 0, 0, 0
	for seed = 1, SEEDS do
		local layout = MansionGen.generate(seed * 7 + 3, templates, config)
		layouts[seed] = layout
		attempts += layout.attempts
		if layout.fallback then
			fallbacks += 1
		end
		if layout.attempts == 1 then
			firstTry += 1
		end
	end

	local function idsOf(layout)
		local ids = {}
		for _, room in layout.rooms do
			table.insert(ids, room.id)
		end
		return ids
	end

	test("mansion templates: every opt-in has zones, and a size on the lattice", function()
		for _, template in templates do
			local m = template.mansion
			check.truthy(m.floors and #m.floors > 0, template.id .. " floors")
			for _, floor in m.floors do
				check.truthy(MansionHouse.templateZone(template, floor) ~= nil, template.id .. " zone")
			end
			if m.role ~= "corridor" then
				check.truthy(m.size ~= nil, template.id .. " size")
				for _, value in m.size do
					check.equal(value % config.Lattice, 0, template.id .. " size on the lattice")
					check.atLeast(value, 20, template.id .. " narrowest side")
				end
				-- Only the grand entrance is bigger than 40 (owner, 2026-10-04).
				if m.role ~= "start" then
					check.atMost(math.max(m.size[1], m.size[2]), 40, template.id .. " larger than 40")
				end
			end
			for _, other in m.near or {} do
				check.truthy(byId[other] ~= nil, template.id .. " is near an unknown template " .. other)
			end
		end
		for _, role in { "start", "exit", "deliberation", "kitchen", "stair", "corridor" } do
			local found = false
			for _, template in templates do
				if template.mansion.role == role then
					found = true
				end
			end
			check.truthy(found, "no template for role " .. role)
		end
		-- The old generator never sees the mansion-only rooms.
		for _, template in Rooms.MansionExtras do
			check.equal(Rooms.ById[template.id], nil, template.id .. " leaked into Rooms.List")
		end
	end)

	test(SEEDS .. " seeds: every mansion passes the fairness contract and its own rules", function()
		for seed, layout in layouts do
			local ok, problems = LayoutValidator.validate(layout, templates, config)
			check.truthy(ok, "seed " .. seed .. ": " .. table.concat(problems, "; "))
		end
		print(
			string.format(
				"      first-try pass %.1f%%, mean attempts %.2f, fallbacks %d",
				firstTry / SEEDS * 100,
				attempts / SEEDS,
				fallbacks
			)
		)
		check.atMost(fallbacks, 2, "too many seeds fell back to the authored mansion")
	end)

	test("the authored fallback mansion passes the validator", function()
		local layout = MansionGen.fallback(1, templates, config)
		local ok, problems = LayoutValidator.validate(layout, templates, config)
		check.truthy(ok, table.concat(problems, "; "))
		check.truthy(layout.fallback, "marked as a fallback")
		-- A run can't change the frozen house.
		layout.rooms[1].x += 10
		check.truthy(MansionGen.fallback(1, templates, config).rooms[1].x ~= layout.rooms[1].x, "thawed copy")
	end)

	test("the same seed builds the same mansion", function()
		for _, seed in { 1, 99, 1800820264 } do
			local a = MansionGen.generate(seed, templates, config)
			local b = MansionGen.generate(seed, templates, config)
			check.equal(FloorPlan.fingerprint(a), FloorPlan.fingerprint(b), "seed " .. seed)
		end
		check.truthy(FloorPlan.hash(layouts[1]) ~= FloorPlan.hash(layouts[2]), "two seeds built the same mansion")
	end)

	test("a grand hall at the front, two floors, and room counts in range", function()
		for seed, layout in layouts do
			local hall = layout.rooms[layout.start]
			check.equal(hall.template, "grand_hall", "seed " .. seed .. " starts in the grand hall")
			check.truthy(hall.tall, "the hall is double height")
			check.equal(hall.z + hall.d, config.FrontLine, "the hall is at the front")
			check.equal(layout.frontDoor.dir, "S", "the front door faces the front")
			local upper, stairs = 0, 0
			for _, room in layout.rooms do
				if room.floor == 1 and not room.tall then
					upper += 1
				end
				if room.kind == "stair" then
					stairs += 1
				end
			end
			check.atLeast(upper, 3, "seed " .. seed .. " upstairs rooms")
			check.truthy(
				stairs >= config.Stairwells[1] and stairs <= config.Stairwells[2],
				"seed " .. seed .. " has " .. stairs .. " stairwells"
			)
			if not layout.fallback then
				check.truthy(
					#layout.rooms >= config.RoomCount[1] and #layout.rooms <= config.RoomCount[2],
					"seed " .. seed .. " has " .. #layout.rooms .. " rooms"
				)
			end
		end
	end)

	test("zones make sense: the service wing downstairs behind the dining room, bedrooms upstairs", function()
		local zoneFloors = { service = 0, kitchen = 0, dining = 0, public = 0, private = 1 }
		for seed, layout in layouts do
			for _, room in layout.rooms do
				if not room.tall and zoneFloors[room.zone] then
					check.equal(room.floor, zoneFloors[room.zone], ("seed %d: %s floor"):format(seed, room.template))
				end
			end
			-- On the ground floor the only way into the service wing is through the
			-- dining room: without it, the hall reaches none of the wing.
			local edges = {}
			for _, seam in layout.seams do
				local throughTable = seam.a == layout.deliberation or seam.b == layout.deliberation
				if seam.connected and seam.floor == 0 and not throughTable then
					table.insert(edges, { seam.a, seam.b })
				end
			end
			local reach = Graph.bfs(Graph.adjacency(idsOf(layout), edges), layout.start)
			for _, room in layout.rooms do
				if (room.zone == "kitchen" or room.zone == "service") and not room.tall then
					check.equal(
						reach[room.id],
						nil,
						("seed %d: %s reached around the dining room"):format(seed, room.template)
					)
				end
			end
		end
	end)

	test("every stairwell opens on both floors, and a loop runs through one", function()
		for seed, layout in layouts do
			local adj = Graph.adjacency(idsOf(layout), layout.edges)
			local vertical = false
			for _, room in layout.rooms do
				if room.kind == "stair" then
					local opens = {}
					for _, seam in layout.seams do
						if seam.connected and (seam.a == room.id or seam.b == room.id) then
							opens[seam.floor] = true
						end
					end
					check.truthy(opens[0] and opens[1], "seed " .. seed .. " stairwell opens on both floors")
					for _, other in adj[room.id] do
						if Graph.cycleThroughEdge(adj, room.id, other) then
							vertical = true
						end
					end
				end
			end
			check.truthy(vertical, "seed " .. seed .. " has no loop through a stairwell")
		end
	end)

	test("the exit is at the side or back, far from the hall, with a clear porch", function()
		for seed, layout in layouts do
			local exit = layout.rooms[layout.exit]
			check.equal(exit.floor, 0, "exit on the ground floor")
			check.truthy(layout.exitDoor.dir ~= "S", "seed " .. seed .. " exit at the front")
			local dist = Graph.bfs(Graph.adjacency(idsOf(layout), layout.edges), layout.start)
			check.atLeast(dist[layout.exit], config.MinExitRooms, "seed " .. seed .. " exit distance")
			local porch = LayoutValidator.porchOf(layout.exitDoor, config.Lattice)
			for _, room in layout.rooms do
				if room.floor == 0 or room.tall then
					check.truthy(not RoomRects.overlaps(porch, room), "seed " .. seed .. " porch built over")
				end
			end
		end
	end)

	test("seams: doors sit on the lattice inside the shared wall, clear of its ends", function()
		for seed, layout in layouts do
			for _, seam in layout.seams do
				local c = RoomRects.contact(layout.rooms[seam.a], layout.rooms[seam.b])
				check.truthy(c ~= nil, "seed " .. seed .. " " .. seam.id .. " rooms don't touch")
				check.equal(c.dir, seam.dir, seam.id .. " dir")
				check.equal(seam.along % config.Lattice, 0, seam.id .. " on the lattice")
				check.atLeast(seam.along - c.from, config.DoorCornerClear, seam.id .. " clear of one end")
				check.atLeast(c.to - seam.along, config.DoorCornerClear, seam.id .. " clear of the other end")
				if seam.door then
					check.truthy(seam.connected, seam.id .. " door slab on a solid wall")
				end
			end
		end
	end)

	test("the plan printer draws both floors", function()
		local text = FloorPlan.render(layouts[1], config)
		check.truthy(string.find(text, "Ground floor", 1, true) ~= nil, "ground floor")
		check.truthy(string.find(text, "Upper floor", 1, true) ~= nil, "upper floor")
		check.truthy(string.find(text, "FFF", 1, true) ~= nil, "front door")
		check.truthy(string.find(text, "grand_hall", 1, true) ~= nil, "legend")
	end)
end
