return function(test, check, Shared, require)
	local Config = require(Shared.Config)
	local Rooms = require(Shared.Data.Rooms)
	local LevelGraph = require(Shared.Logic.LevelGraph)
	local LayoutValidator = require(Shared.Logic.LayoutValidator)
	local Graph = require(Shared.Logic.Graph)

	local level = Config.Level

	test("same seed gives the same layout", function()
		local a = LevelGraph.generate(12345, Rooms.List, level)
		local b = LevelGraph.generate(12345, Rooms.List, level)
		check.equal(#a.rooms, #b.rooms, "room count")
		for i, room in a.rooms do
			check.equal(room.gx, b.rooms[i].gx, "gx")
			check.equal(room.gz, b.rooms[i].gz, "gz")
			check.equal(room.template, b.rooms[i].template, "template")
			check.equal(room.rotation, b.rooms[i].rotation, "rotation")
		end
		check.equal(#a.edges, #b.edges, "edge count")
	end)

	test("different seeds give different layouts", function()
		local a = LevelGraph.generate(1, Rooms.List, level)
		local b = LevelGraph.generate(2, Rooms.List, level)
		local same = #a.rooms == #b.rooms
		if same then
			for i, room in a.rooms do
				if room.gx ~= b.rooms[i].gx or room.gz ~= b.rooms[i].gz or room.template ~= b.rooms[i].template then
					same = false
				end
			end
		end
		check.truthy(not same, "seeds 1 and 2 produced identical layouts")
	end)

	test("the authored fallback passes the validator", function()
		local layout = LevelGraph.fallback(99, Rooms.List, level)
		local ok, problems = LayoutValidator.validate(layout, Rooms.List, level)
		check.truthy(ok, table.concat(problems, "; "))
	end)

	test("1000 seeds: every generated layout satisfies the fairness contract", function()
		local fallbacks, totalAttempts, firstTry = 0, 0, 0
		local reasons = {}
		for seed = 1, 1000 do
			local layout = LevelGraph.generate(seed * 7 + 3, Rooms.List, level)
			local ok, problems = LayoutValidator.validate(layout, Rooms.List, level)
			check.truthy(ok, "seed " .. seed .. ": " .. table.concat(problems, "; "))
			if layout.fallback then
				fallbacks += 1
				for _, p in layout.lastProblems or {} do
					reasons[p] = (reasons[p] or 0) + 1
				end
			end
			if layout.attempts == 1 then
				firstTry += 1
			end
			totalAttempts += layout.attempts
		end
		print(
			string.format(
				"      first-try pass %.1f%%, mean attempts %.2f, fallbacks %d",
				firstTry / 10,
				totalAttempts / 1000,
				fallbacks
			)
		)
		check.atMost(fallbacks, 5, "too many seeds fell back to the authored layout")
	end)

	test("roles: exit is on the edge, table is on the critical path, lanterns are spread", function()
		for seed = 1, 200 do
			local layout = LevelGraph.generate(seed, Rooms.List, level)
			check.truthy(layout.exit ~= layout.start, "exit equals start")
			check.truthy(table.find(layout.criticalPath, layout.deliberation), "table off the critical path")
			check.atLeast(#layout.lanterns, 1, "lantern rooms")
			check.atMost(#layout.lanterns, 2, "lantern rooms")
			for _, id in layout.lanterns do
				check.truthy(
					id ~= layout.start and id ~= layout.exit and id ~= layout.deliberation,
					"lantern on a role room"
				)
			end
		end
	end)

	test("seams: one per pair of neighbouring rooms, doorways only on true edges", function()
		local layout = LevelGraph.generate(4242, Rooms.List, level)
		local edgeSet = {}
		for _, e in layout.edges do
			edgeSet[Graph.edgeKey(e[1], e[2])] = true
		end
		local connected = 0
		for _, seam in layout.seams do
			check.equal(seam.connected, edgeSet[Graph.edgeKey(seam.a, seam.b)] == true, "seam connectivity")
			if seam.connected then
				connected += 1
			end
			if seam.door then
				check.truthy(seam.connected, "door on a solid wall")
			end
		end
		check.equal(connected, #layout.edges, "every edge has a seam")
	end)

	test("no three rooms of one mood in a row along the BFS tree (when avoidable)", function()
		local violations = 0
		for seed = 1, 200 do
			local layout = LevelGraph.generate(seed, Rooms.List, level)
			local ids = {}
			local byId = {}
			for _, r in layout.rooms do
				table.insert(ids, r.id)
				byId[r.id] = r
			end
			local adj = Graph.adjacency(ids, layout.edges)
			local _, parent = Graph.bfs(adj, layout.start)
			for _, room in layout.rooms do
				local p1 = parent[room.id] and byId[parent[room.id]]
				local p2 = p1 and parent[p1.id] and byId[parent[p1.id]]
				if p1 and p2 and room.role == nil and room.mood == p1.mood and p1.mood == p2.mood then
					violations += 1
				end
			end
		end
		check.atMost(violations, 20, "mood runs")
	end)
end
