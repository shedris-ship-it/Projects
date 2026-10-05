return function(test, check, Shared, require)
	local Config = require(Shared.Config)
	local Rooms = require(Shared.Data.Rooms)
	local Props = require(Shared.Data.Props)
	local LevelGraph = require(Shared.Logic.LevelGraph)
	local MansionGen = require(Shared.Logic.MansionGen)
	local MansionHouse = require(Shared.Logic.MansionHouse)
	local NavGraph = require(Shared.Logic.NavGraph)
	local RoomFit = require(Shared.Logic.RoomFit)
	local RoomRects = require(Shared.Logic.RoomRects)
	local TallRooms = require(Shared.Logic.TallRooms)
	local Rng = require(Shared.Lib.Rng)

	local options = NavGraph.options(Config)
	local pitch = options.pitch

	-- Houses shared by the tests below: generated mansions and the fallback.
	local SEEDS = 120
	local houses = {}
	for seed = 1, SEEDS do
		local layout = MansionGen.generate(seed * 11 + 5, Rooms.Mansion, Config.Mansion)
		table.insert(houses, { layout = layout, graph = NavGraph.build(layout, options) })
	end
	local fallback = MansionGen.fallback(0, Rooms.Mansion, Config.Mansion)
	table.insert(houses, { layout = fallback, graph = NavGraph.build(fallback, options) })

	local function storeyOfRegion(region: string): number?
		if region == "ground" then
			return 0
		elseif region == "gallery" or region == "upper" then
			return 1
		end
		return nil
	end

	test("a house a storey lower walks the same, a storey lower", function()
		-- Storeys from the cellar to the attic (docs/plans/level-design.md
		-- section 10.1): moving every room and doorway down one storey moves
		-- every node down one pitch and changes nothing else.
		for i = 1, 6 do
			local layout = houses[i].layout
			local lowered = table.clone(layout)
			lowered.rooms, lowered.seams = {}, {}
			for _, room in layout.rooms do
				local copy = table.clone(room)
				copy.floor = (room.floor or 0) - 1
				table.insert(lowered.rooms, copy)
			end
			for _, seam in layout.seams do
				local copy = table.clone(seam)
				copy.floor = (seam.floor or 0) - 1
				table.insert(lowered.seams, copy)
			end
			local a, b = houses[i].graph, NavGraph.build(lowered, options)
			check.equal(#b.nodes, #a.nodes)
			for id, node in a.nodes do
				local other = b.nodes[id]
				check.near(other.y, node.y - pitch, 1e-6)
				check.near(other.x, node.x, 1e-6)
				check.equal(other.kind, node.kind)
			end
			check.equal(b.low, -1)
			check.equal(NavGraph.storeyOf(b, -pitch + 3), -1)
		end
	end)

	test("cellar rooms lie under the ground floor and attic rooms stand on the floor below", function()
		local config = Config.Mansion
		local house = MansionHouse.new(config, Rooms.MansionById)
		house:Add({ template = "living_room", floor = 0, x = 0, z = -40, w = 40, d = 30 })
		check.truthy(house:Supported({ floor = -1, x = 0, z = -40, w = 20, d = 20 }), "under the ground floor")
		check.truthy(not house:Supported({ floor = -1, x = 30, z = -40, w = 20, d = 20 }), "half under nothing")
		check.truthy(not house:Supported({ floor = 2, x = 0, z = -40, w = 20, d = 20 }), "no upper floor yet")
		house:Add({ template = "kids_bedroom", floor = 1, x = 0, z = -40, w = 30, d = 30 })
		check.truthy(house:Supported({ floor = 2, x = 0, z = -40, w = 20, d = 20 }), "on the upper floor")
		check.truthy(
			house:Supported({ floor = -1, tall = true, x = 50, z = -40, w = 20, d = 30 }),
			"a stair down holds itself up"
		)
		check.equal(#MansionHouse.floorsOf({ floor = -1, tall = true, top = 2 }), 4)
		check.truthy(RoomRects.onFloor({ floor = -1, tall = true }, 0), "a cellar stair reaches the ground")
		check.truthy(not RoomRects.onFloor({ floor = -1, tall = true }, 1))
	end)

	test("toWorld and toLocal turn a room as the builders' CFrame does", function()
		local roblox = require("@lune/roblox")
		local rect = { x = 30, z = -20, w = 20, d = 30 }
		for rotation = 0, 3 do
			local cx, cz = RoomRects.center(rect)
			local cf = roblox.CFrame.new(cx, 0, cz) * roblox.CFrame.Angles(0, rotation * math.pi / 2, 0)
			for _, p in { { 3, 7 }, { -9.5, 2 }, { 0, -14.5 } } do
				local world = cf:PointToWorldSpace(roblox.Vector3.new(p[1], 0, p[2]))
				local wx, wz = RoomRects.toWorld(rect, rotation, p[1], p[2])
				check.near(wx, world.X, 1e-6, "x, rotation " .. rotation)
				check.near(wz, world.Z, 1e-6, "z, rotation " .. rotation)
				local lx, lz = RoomRects.toLocal(rect, rotation, wx, wz)
				check.near(lx, p[1], 1e-6, "back to local x")
				check.near(lz, p[2], 1e-6, "back to local z")
			end
		end
	end)

	test("every node stands inside its room, on floor (not over the hall or a stair's well)", function()
		for _, house in houses do
			local graph = house.graph
			for _, node in graph.nodes do
				local room = graph.rooms[node.room]
				local rect = room.rect
				local inner = RoomRects.innerOf(rect, room.rotation, options.wall)
				local lx, lz = RoomRects.toLocal(rect, room.rotation, node.x, node.z)
				if node.kind ~= "doorway" then
					check.atMost(math.abs(lx), inner.x + 1e-6, "node past an east or west wall")
					check.atMost(math.abs(lz), inner.z + 1e-6, "node past a north or south wall")
				end
				if room.tall and node.kind == "tall" then
					local storey = storeyOfRegion(node.region)
					if storey then
						check.truthy(
							TallRooms.standable(room.tall, inner, pitch, storey, lx, lz),
							string.format("%s node at %.1f, %.1f storey %d is not on floor", room.tall, lx, lz, storey)
						)
					end
				end
			end
		end
	end)

	test("every doorway can be reached from the hall, on both floors", function()
		for _, house in houses do
			local graph = house.graph
			local start = nil
			for _, room in house.layout.rooms do
				if room.role == "start" then
					start = room
				end
			end
			local hall = graph.rooms[start.id]
			local dist = NavGraph.search(graph, { [hall.nodes[1]] = 0 })
			local storeys = {}
			for _, seam in graph.seams do
				if seam.connected then
					for _, node in seam.approach do
						check.truthy(dist[node] ~= nil, "unreachable doorway " .. seam.id)
					end
					storeys[seam.storey] = true
				end
			end
			check.truthy(storeys[0] and storeys[1], "doorways on both floors")
			-- Every room with an open doorway is reachable at its middle too.
			for id, room in graph.rooms do
				local any = false
				for _, node in room.nodes do
					if dist[node] then
						any = true
					end
				end
				check.truthy(any, "room " .. id .. " unreachable")
			end
		end
	end)

	test("stairs in the graph match the ramps the builder makes", function()
		for _, house in houses do
			local graph = house.graph
			local climbs = 0
			for id, links in graph.links do
				for _, link in links do
					if link.stair then
						local a, b = graph.nodes[id], graph.nodes[link.to]
						local room = graph.rooms[a.room]
						local inner = RoomRects.innerOf(room.rect, room.rotation, options.wall)
						local ax, az = RoomRects.toLocal(room.rect, room.rotation, a.x, a.z)
						local bx, bz = RoomRects.toLocal(room.rect, room.rotation, b.x, b.z)
						check.near(ax, bx, 1e-6, "a flight runs straight north-south")
						check.truthy(a.y ~= b.y, "a flight climbs")
						local low, high = math.min(az, bz), math.max(az, bz)
						if room.tall == "hall" then
							local h = TallRooms.hall(inner, pitch)
							check.near(ax, 0, 1e-6, "the grand stair is in the middle")
							check.truthy(low < h.edgeZ and high > TallRooms.Hall.StairFoot, "covers the grand stair")
						else
							local s = TallRooms.stairwell(inner, pitch)
							check.near(math.abs(ax), s.flightX, 1e-6, "on a flight")
							check.truthy(low < s.landingZ and high > s.upperZ, "covers the flight")
						end
						climbs += 1
					end
				end
			end
			check.atLeast(climbs, 2 * 2, "the grand stair and at least one stairwell, each way")
			check.atLeast(#graph.climbs, 2, "climbs")
		end
	end)

	test("halfway up a flight, a point joins both ends of it", function()
		for _, house in houses do
			local graph = house.graph
			for _, stair in graph.stairs do
				local a, b = graph.nodes[stair.a], graph.nodes[stair.b]
				-- A body's root halfway up: on the ramp's line, 4.6 above it.
				local mid = { x = (a.x + b.x) / 2, y = (a.y + b.y) / 2 + 4.6, z = (a.z + b.z) / 2 }
				local joined = NavGraph.attach(graph, mid, stair.room)
				check.truthy(joined[stair.a] ~= nil and joined[stair.b] ~= nil, "mid-flight joins both ends")
			end
		end
	end)

	test("routes: found between any two rooms, never shorter than the straight line", function()
		local rng = Rng.new(5)
		for _, house in houses do
			local graph = house.graph
			local ids = NavGraph.roomIds(graph)
			for _ = 1, 12 do
				local a = graph.rooms[rng:Pick(ids)]
				local b = graph.rooms[rng:Pick(ids)]
				local from = graph.nodes[a.nodes[#a.nodes]]
				local to = graph.nodes[b.nodes[1]]
				local route = NavGraph.route(graph, from, a.id, to, b.id)
				check.truthy(route ~= nil, "no route between rooms " .. a.id .. " and " .. b.id)
				check.atLeast(route.cost + 1e-6, NavGraph.distance(from, to), "a route shorter than the crow flies")
				-- Each step is linked to the one before it.
				for i = 2, #route.steps do
					local linked = false
					for _, link in graph.links[route.steps[i - 1].node] do
						if link.to == route.steps[i].node then
							linked = true
						end
					end
					check.truthy(linked, "a route jumps between unlinked nodes")
				end
			end
		end
	end)

	test("a door cost of nil blocks that doorway from both sides", function()
		local rng = Rng.new(17)
		for h = 1, 40 do
			local graph = houses[h].graph
			local open = {}
			for id, seam in graph.seams do
				if seam.connected then
					table.insert(open, id)
				end
			end
			table.sort(open)
			-- One doorway shut: no route between its rooms walks through it.
			local shut = rng:Pick(open)
			local seam = graph.seams[shut]
			local opts = {
				doorCost = function(id)
					return id ~= shut and 0 or nil
				end,
			}
			for _, pair in { { seam.a, seam.b }, { seam.b, seam.a } } do
				local a, b = graph.rooms[pair[1]], graph.rooms[pair[2]]
				local route = NavGraph.route(graph, graph.nodes[a.nodes[1]], a.id, graph.nodes[b.nodes[1]], b.id, opts)
				for _, step in route and route.steps or {} do
					check.truthy(step.seam ~= shut, "a route walked through a shut doorway")
				end
			end
			-- Every doorway of an ordinary room shut: no way in or out.
			local ids = NavGraph.roomIds(graph)
			local room
			repeat
				room = graph.rooms[rng:Pick(ids)]
			until not room.tall
			local sealed = {}
			for id, s in graph.seams do
				if s.a == room.id or s.b == room.id then
					sealed[id] = true
				end
			end
			local other
			repeat
				other = graph.rooms[rng:Pick(ids)]
			until other.id ~= room.id
			local route =
				NavGraph.route(graph, graph.nodes[other.nodes[1]], other.id, graph.nodes[room.nodes[1]], room.id, {
					doorCost = function(id)
						return not sealed[id] and 0 or nil
					end,
				})
			check.truthy(route == nil, "a route into a room whose every doorway is shut")
		end
	end)

	test("separation: symmetric, and at least the flat distance", function()
		local rng = Rng.new(9)
		for _, house in houses do
			local graph = house.graph
			for _ = 1, 20 do
				local a = graph.nodes[rng:NextInteger(1, #graph.nodes)]
				local b = graph.nodes[rng:NextInteger(1, #graph.nodes)]
				local ab, ba = NavGraph.separation(graph, a, b), NavGraph.separation(graph, b, a)
				check.near(ab, ba, 1e-6, "separation is symmetric")
				check.atLeast(ab + 1e-6, NavGraph.flatDistance(a, b), "separation below the flat distance")
				if NavGraph.storeyOf(graph, a.y) ~= NavGraph.storeyOf(graph, b.y) then
					check.atLeast(ab, 20, "a different floor is never right next to you")
				end
			end
		end
	end)

	test("fitted furniture keeps clear of every route through a room", function()
		local clearance = options.clearance - 0.01
		local problems = {}
		for h = 1, #houses, 2 do
			local house = houses[h]
			local graph = house.graph
			for _, room in house.layout.rooms do
				local template = Rooms.MansionById[room.template]
				local info = graph.rooms[room.id]
				local inner = RoomRects.innerOf(info.rect, info.rotation, options.wall)
				local source = template.mansion and template.mansion.authored and inner
					or { x = RoomFit.SourceInner, z = RoomFit.SourceInner }
				local fitted = RoomFit.fit(template, source, inner, MansionHouse.fitDoors(house.layout, room))
				local boxes = {}
				for _, prop in fitted.props do
					local kind = Props.Kinds[prop.kind]
					if kind == nil or kind.collide ~= false then
						local ex, ez = RoomFit.footprint(prop.kind, prop.ry)
						table.insert(
							boxes,
							{ prop = prop, x0 = prop.x - ex, x1 = prop.x + ex, z0 = prop.z - ez, z1 = prop.z + ez }
						)
					end
				end
				if fitted.shrine and room.lantern then
					local ex, ez = RoomFit.footprint("Shrine", 0)
					local s = fitted.shrine
					table.insert(
						boxes,
						{ prop = { id = "shrine" }, x0 = s.x - ex, x1 = s.x + ex, z0 = s.z - ez, z1 = s.z + ez }
					)
				end
				-- Furniture stands on the ground storey of a double-height room.
				local storeyY = info.tall and 0 or info.storey * pitch
				for _, a in info.nodes do
					for _, link in graph.links[a] do
						local na, nb = graph.nodes[a], graph.nodes[link.to]
						if
							a < link.to
							and not link.seam
							and nb.room == room.id
							and math.abs(na.y - storeyY) < 0.01
							and math.abs(nb.y - storeyY) < 0.01
						then
							local ax, az = RoomRects.toLocal(info.rect, info.rotation, na.x, na.z)
							local bx, bz = RoomRects.toLocal(info.rect, info.rotation, nb.x, nb.z)
							local steps = math.max(1, math.ceil(math.sqrt((bx - ax) ^ 2 + (bz - az) ^ 2) / 0.25))
							for _, b in boxes do
								local nearest = math.huge
								for k = 0, steps do
									local t = k / steps
									local px, pz = ax + (bx - ax) * t, az + (bz - az) * t
									local dx = math.max(b.x0 - px, 0, px - b.x1)
									local dz = math.max(b.z0 - pz, 0, pz - b.z1)
									nearest = math.min(nearest, math.sqrt(dx * dx + dz * dz))
								end
								if nearest < clearance then
									table.insert(
										problems,
										string.format(
											"%s %s %.2f from (%.1f, %.1f)-(%.1f, %.1f)",
											template.id,
											b.prop.id,
											nearest,
											ax,
											az,
											bx,
											bz
										)
									)
								end
							end
						end
					end
				end
			end
		end
		check.equal(#problems, 0, "furniture on a route: " .. table.concat(problems, "; ", 1, math.min(#problems, 6)))
	end)

	test("the old house: a graph through every room", function()
		for seed = 1, 60 do
			local layout = LevelGraph.generate(seed, Rooms.List, Config.Level)
			local graph = NavGraph.build(layout, options)
			local ids = NavGraph.roomIds(graph)
			local first = graph.rooms[ids[1]]
			local dist = NavGraph.search(graph, { [first.nodes[1]] = 0 })
			for _, id in ids do
				local any = false
				for _, node in graph.rooms[id].nodes do
					if dist[node] then
						any = true
					end
				end
				check.truthy(any, "old house room " .. id .. " unreachable, seed " .. seed)
			end
			check.equal(#graph.climbs, 0, "no stairs in the old house")
		end
	end)
end
