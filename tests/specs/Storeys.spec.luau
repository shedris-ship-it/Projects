return function(test, check, Shared, require)
	local Storeys = require(Shared.Logic.Storeys)
	local Rooms = require(Shared.Data.Rooms)
	local Config = require(Shared.Config)
	local MansionGen = require(Shared.Logic.MansionGen)
	local NavGraph = require(Shared.Logic.NavGraph)
	local RetreatPlan = require(Shared.Logic.RetreatPlan)

	local PITCH = 11

	test("a floor muffles noise; the hall and stairwells carry it", function()
		local below = { x = 0, y = 0, z = 0, room = 1 }
		local above = { x = 0, y = 11, z = 0, room = 2 }
		check.equal(Storeys.audibleRadius(28, below, above, PITCH, 0.5), 14, "sprint through a floor")
		check.equal(Storeys.audibleRadius(28, below, { x = 9, y = 0, z = 0, room = 3 }, PITCH, 0.5), 28, "same floor")
		local galleryA = { x = 0, y = 11, z = 0, room = 5, tall = true }
		local hallFloor = { x = 0, y = 0, z = 0, room = 5, tall = true }
		check.equal(Storeys.audibleRadius(28, galleryA, hallFloor, PITCH, 0.5), 28, "the open hall")
		-- Halfway up a staircase still counts as the floor you came from.
		check.equal(Storeys.of(6, PITCH), 0, "mid-stair")
		check.equal(Storeys.of(11, PITCH), 1, "upstairs")
	end)

	test("people on different floors are apart, unless they share a double-height room", function()
		local a = { x = 0, y = 0, z = 0, room = 1 }
		check.truthy(not Storeys.together(a, { x = 0, y = 11, z = 0, room = 2 }, 25, PITCH), "straight above")
		check.truthy(Storeys.together(a, { x = 10, y = 0, z = 5, room = 3 }, 25, PITCH), "same floor, near")
		check.truthy(not Storeys.together(a, { x = 30, y = 0, z = 0, room = 3 }, 25, PITCH), "same floor, far")
		local gallery = { x = 4, y = 11, z = 0, room = 7, tall = true }
		check.truthy(Storeys.together({ x = 0, y = 0, z = 0, room = 7, tall = true }, gallery, 25, PITCH), "the hall")
	end)

	test("retreat: he backs away from you, and holds his ground when cornered", function()
		local options = NavGraph.options(Config)
		local W = RetreatPlan.Weights
		local planned, cornered = 0, 0
		for seed = 1, 40 do
			local layout = MansionGen.generate(seed * 13 + 1, Rooms.Mansion, Config.Mansion)
			local graph = NavGraph.build(layout, options)
			local doorways = RetreatPlan.doorways(graph)
			for _, id in NavGraph.roomIds(graph) do
				local room = graph.rooms[id]
				if not room.tall and (doorways[id] or 0) >= 1 then
					-- He stands in the room's middle; you come in through a doorway.
					local centre = nil
					for _, node in room.nodes do
						if graph.nodes[node].kind == "centre" then
							centre = graph.nodes[node]
						end
					end
					local entry = nil
					for _, candidate in room.approaches do
						if graph.seams[graph.nodes[candidate.node].seam].connected then
							entry = candidate
						end
					end
					local you = graph.nodes[entry.node]
					local mine, parent = NavGraph.search(graph, NavGraph.attach(graph, centre, id))
					local me = { point = centre, room = id, dist = mine, parent = parent }
					local players = {
						{ point = you, room = id, dist = NavGraph.distancesFrom(graph, you, id) },
					}
					local plan = RetreatPlan.choose(graph, me, players, { budget = 35, doorways = doorways })
					if plan and not plan.cornered then
						planned += 1
						check.atLeast(plan.safety, plan.here + W.Cornered, "a retreat that gains nothing")
						-- Never into the doorway you're standing in.
						check.truthy(plan.node ~= entry.node, "backs into you")
					elseif plan then
						cornered += 1
					end
					-- A room with one way in, and you in it: nowhere to go.
					if (doorways[id] or 0) == 1 then
						local seam = nil
						for _, s in graph.seams do
							if s.connected and (s.a == id or s.b == id) then
								seam = s
							end
						end
						local doorYou = graph.nodes[seam.approach[id]]
						local blocked = RetreatPlan.choose(graph, me, {
							{ point = doorYou, room = id, dist = NavGraph.distancesFrom(graph, doorYou, id) },
						}, { budget = 35, doorways = doorways })
						check.truthy(
							blocked == nil or blocked.cornered or graph.nodes[blocked.node].room == id,
							"a way out past you in a dead end"
						)
					end
				end
			end
		end
		check.atLeast(planned, 100, "retreats planned")
		check.atLeast(cornered + planned, planned, "counted")
	end)
end
