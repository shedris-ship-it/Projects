-- The house as a graph to walk (docs/plans/mansion-generation.md, M3): where
-- its doorways, stairs and gallery are, and how far apart in studs. This is
-- the strategy for The Guest and the Companion: it picks the way through the
-- house and which way round, and Stalker/Walker walks each room on the
-- navmesh. Pure: no engine calls.
--
-- Points are { x, y, z } in layout coordinates: relative to
-- Config.Level.Origin, y the height above the ground floor. Node kinds:
--   approach  a few studs into a room in front of a doorway
--   doorway   the middle of a doorway, on the wall line
--   foot      where a doorway's lane meets the room's clear middle
--   centre    the middle of an ordinary room
--   tall      a point of the hall's or a stairwell's walk shape (TallRooms)
-- Furniture stands within the wall band (Config.Level.BandDepth) and out of
-- the doorway lanes (Logic/RoomFit), so a doorway's lane and an ordinary
-- room's middle are clear: lane foot to lane foot is a straight walk.

local RoomRects = require(script.Parent.RoomRects)
local Storeys = require(script.Parent.Storeys)
local TallRooms = require(script.Parent.TallRooms)

local NavGraph = {}

local DIRS = { N = { 0, -1 }, E = { 1, 0 }, S = { 0, 1 }, W = { -1, 0 } }

-- The numbers the graph needs, from the game's Config.
function NavGraph.options(Config)
	return {
		wall = Config.Level.WallThickness,
		pitch = Config.Mansion.FloorPitch,
		band = Config.Level.BandDepth,
		cellSize = Config.Level.CellSize,
		lattice = Config.Mansion.Lattice,
		approach = Config.Nav.Approach,
		clearance = Config.Nav.Clearance,
		doorCost = Config.Nav.DoorCost,
		attachRise = Config.Nav.AttachRise,
	}
end

local function flatDistance(a, b): number
	local dx, dz = a.x - b.x, a.z - b.z
	return math.sqrt(dx * dx + dz * dz)
end
NavGraph.flatDistance = flatDistance

local function distance(a, b): number
	local dx, dy, dz = a.x - b.x, a.y - b.y, a.z - b.z
	return math.sqrt(dx * dx + dy * dy + dz * dz)
end
NavGraph.distance = distance

-- Which storey a height is on (the same rule as WorldService.FloorAt).
function NavGraph.storeyOf(graph, y: number): number
	return Storeys.of(y, graph.pitch, graph.low, graph.high)
end

local function roomIds(graph): { number }
	local ids = {}
	for id in graph.rooms do
		table.insert(ids, id)
	end
	table.sort(ids)
	return ids
end
NavGraph.roomIds = roomIds

-- Build the graph of a layout from either generator.
function NavGraph.build(layout, options)
	local mansion = layout.mode == "Mansion"
	if not mansion then
		layout = RoomRects.seamsOfCells(layout, { CellSize = options.cellSize, Lattice = options.lattice })
	end
	local graph = {
		nodes = {},
		links = {},
		rooms = {},
		seams = {},
		climbs = {},
		stairs = {}, -- { a, b, room }: the flights, for joining points halfway up one
		pitch = options.pitch,
		options = options,
	}
	graph.low, graph.high = Storeys.range(mansion and layout or nil)
	local function addNode(x: number, y: number, z: number, room: number, kind: string, region: string?): number
		table.insert(graph.nodes, { x = x, y = y, z = z, room = room, kind = kind, region = region or "room" })
		local id = #graph.nodes
		graph.nodes[id].id = id
		graph.links[id] = {}
		table.insert(graph.rooms[room].nodes, id)
		return id
	end
	local function addLink(a: number, b: number, extra)
		if a == b then
			return
		end
		local cost = distance(graph.nodes[a], graph.nodes[b])
		local ab = { to = b, cost = cost }
		local ba = { to = a, cost = cost }
		if extra then
			for key, value in extra do
				ab[key] = value
				ba[key] = value
			end
		end
		table.insert(graph.links[a], ab)
		table.insert(graph.links[b], ba)
	end

	local rects = mansion and RoomRects.ofLayout(layout) or RoomRects.fromCells(layout, options.cellSize)
	for _, rect in rects do
		local room = rect.room
		graph.rooms[rect.id] = {
			id = rect.id,
			rect = rect,
			rotation = mansion and room.rotation or 0,
			tall = TallRooms.kindOf(room),
			storey = mansion and (room.floor or 0) or 0, -- its lowest
			top = mansion and RoomRects.topOf(room) or 0,
			nodes = {},
			approaches = {},
		}
	end

	-- Doorways: an approach node each side, the doorway between.
	local ap = options.approach
	for _, seam in layout.seams do
		if seam.dir and seam.along then
			local x, z = RoomRects.doorPoint(seam.dir, seam.line, seam.along)
			local storey = seam.floor or 0
			local y = storey * options.pitch
			local n = DIRS[seam.dir]
			local inA = addNode(x - n[1] * ap, y, z - n[2] * ap, seam.a, "approach")
			local door = addNode(x, y, z, seam.a, "doorway")
			local inB = addNode(x + n[1] * ap, y, z + n[2] * ap, seam.b, "approach")
			graph.nodes[inA].seam, graph.nodes[door].seam, graph.nodes[inB].seam = seam.id, seam.id, seam.id
			graph.seams[seam.id] = {
				id = seam.id,
				a = seam.a,
				b = seam.b,
				connected = seam.connected,
				storey = storey,
				doorway = door,
				approach = { [seam.a] = inA, [seam.b] = inB },
			}
			addLink(inA, door, { seam = seam.id })
			addLink(door, inB, { seam = seam.id })
			table.insert(graph.rooms[seam.a].approaches, { node = inA, storey = storey })
			table.insert(graph.rooms[seam.b].approaches, { node = inB, storey = storey })
		end
	end

	-- Inside each room.
	for _, id in roomIds(graph) do
		local room = graph.rooms[id]
		local rect = room.rect
		if room.tall then
			NavGraph._tallRoom(graph, room, options, addNode, addLink)
		elseif not mansion then
			-- The old house: every lane runs to the room's middle (a corridor's
			-- junction is its middle).
			local cx, cz = RoomRects.center(rect)
			local centre = addNode(cx, 0, cz, id, "centre")
			for _, entry in room.approaches do
				addLink(entry.node, centre)
			end
		else
			-- An ordinary mansion room: its clear middle is the room inside the
			-- wall band, and a route keeps `clearance` inside that.
			local inner = RoomRects.innerOf(rect, room.rotation, options.wall)
			local keep = options.band + options.clearance
			local hx, hz = math.max(0, inner.x - keep), math.max(0, inner.z - keep)
			local y = room.storey * options.pitch
			local cx, cz = RoomRects.center(rect)
			local centre = addNode(cx, y, cz, id, "centre")
			local feet = {}
			for _, entry in room.approaches do
				local a = graph.nodes[entry.node]
				local lx, lz = RoomRects.toLocal(rect, room.rotation, a.x, a.z)
				lx, lz = math.clamp(lx, -hx, hx), math.clamp(lz, -hz, hz)
				local wx, wz = RoomRects.toWorld(rect, room.rotation, lx, lz)
				local foot = centre
				if math.abs(wx - cx) > 0.01 or math.abs(wz - cz) > 0.01 then
					foot = addNode(wx, y, wz, id, "foot")
					table.insert(feet, foot)
				end
				addLink(entry.node, foot)
			end
			for i, a in feet do
				addLink(a, centre)
				for j = i + 1, #feet do
					addLink(a, feet[j])
				end
			end
		end
	end
	return graph
end

-- A double-height room: its TallRooms shape turned into the house (its
-- heights from the room's lowest storey), and each doorway joined to the
-- nearest point of one of its storey's attach lines.
function NavGraph._tallRoom(graph, room, options, addNode, addLink)
	local rect = room.rect
	local inner = RoomRects.innerOf(rect, room.rotation, options.wall)
	local shape = TallRooms.walk(room.tall, inner, options.pitch, room.top - room.storey + 1)
	local base = room.storey * options.pitch
	local ids = {}
	for i, p in shape.nodes do
		local wx, wz = RoomRects.toWorld(rect, room.rotation, p.x, p.z)
		ids[i] = addNode(wx, base + p.y, wz, room.id, "tall", p.region)
	end
	for _, l in shape.links do
		addLink(ids[l.a], ids[l.b], l.stair and { stair = true } or nil)
		if l.stair then
			table.insert(graph.stairs, { a = ids[l.a], b = ids[l.b], room = room.id })
		end
	end
	-- Where each doorway joins: [storey][line index] = { { t, node } }, the
	-- storey counted from the room's lowest.
	local joins = {}
	for storey in shape.attach do
		joins[storey] = {}
	end
	for _, entry in room.approaches do
		local a = graph.nodes[entry.node]
		local lx, lz = RoomRects.toLocal(rect, room.rotation, a.x, a.z)
		local best, bestDistance, bestT = nil, math.huge, 0
		local storey = entry.storey - room.storey
		for index, line in shape.attach[storey] or {} do
			local p, q = shape.nodes[line[1]], shape.nodes[line[2]]
			local dx, dz = q.x - p.x, q.z - p.z
			local length2 = dx * dx + dz * dz
			local t = length2 > 0 and math.clamp(((lx - p.x) * dx + (lz - p.z) * dz) / length2, 0, 1) or 0
			local d = math.sqrt((lx - p.x - dx * t) ^ 2 + (lz - p.z - dz * t) ^ 2)
			if d < bestDistance then
				best, bestDistance, bestT = index, d, t
			end
		end
		if best then
			joins[storey][best] = joins[storey][best] or {}
			table.insert(joins[storey][best], { t = bestT, node = entry.node })
		end
	end
	-- The attach lines, each chained through its doorways' joining points.
	local storeys = {}
	for storey in shape.attach do
		table.insert(storeys, storey)
	end
	table.sort(storeys)
	for _, storey in storeys do
		for index, line in shape.attach[storey] do
			local a, b = ids[line[1]], ids[line[2]]
			local list = joins[storey][index]
			if list then
				table.sort(list, function(x, y)
					return x.t < y.t
				end)
				local p, q = graph.nodes[a], graph.nodes[b]
				local previous = a
				for _, join in list do
					local point = a
					if join.t >= 0.999 then
						point = b
					elseif join.t > 0.001 then
						point = addNode(
							p.x + (q.x - p.x) * join.t,
							p.y + (q.y - p.y) * join.t,
							p.z + (q.z - p.z) * join.t,
							room.id,
							"tall",
							p.region
						)
					end
					addLink(previous, point)
					addLink(join.node, point)
					previous = point
				end
				addLink(previous, b)
			else
				addLink(a, b)
			end
		end
	end
	-- One climb a storey: from its foot to the storey above.
	for k, climb in shape.climbs do
		local chain = {}
		for i, index in climb do
			chain[i] = ids[index]
		end
		local length = 0
		for i = 2, #chain do
			length += distance(graph.nodes[chain[i - 1]], graph.nodes[chain[i]])
		end
		table.insert(graph.climbs, {
			room = room.id,
			low = chain[1],
			high = chain[#chain],
			length = length,
			from = room.storey + k - 1,
		})
	end
end

-- Searching ----------------------------------------------------------------------

-- The nodes a point can walk straight to from inside its room, with the cost:
-- those at about its height (not doorways: a route goes through the approach).
function NavGraph.attach(graph, point, roomId: number?)
	local room = roomId and graph.rooms[roomId]
	local out = {}
	if not room then
		return out
	end
	local rise = graph.options.attachRise
	local nearest, nearestCost = nil, math.huge
	local any = false
	for _, id in room.nodes do
		local node = graph.nodes[id]
		if node.kind ~= "doorway" then
			local cost = distance(point, node)
			if math.abs(node.y - point.y) <= rise then
				out[id] = cost
				any = true
			elseif cost < nearestCost then
				nearest, nearestCost = id, cost
			end
		end
	end
	if not any and nearest then
		out[nearest] = nearestCost
	end
	-- Halfway up a flight: both ends, by way of the flight (the end above
	-- or below may be too far up or down to count on its own).
	for _, stair in graph.stairs do
		if stair.room == roomId then
			local a, b = graph.nodes[stair.a], graph.nodes[stair.b]
			local dx, dy, dz = b.x - a.x, b.y - a.y, b.z - a.z
			local length2 = dx * dx + dy * dy + dz * dz
			local t = math.clamp(((point.x - a.x) * dx + (point.y - a.y) * dy + (point.z - a.z) * dz) / length2, 0, 1)
			local p = { x = a.x + dx * t, y = a.y + dy * t, z = a.z + dz * t }
			-- Roots stand a few studs above the ramp: measure across, not up.
			local across = flatDistance(point, p)
			local above = point.y - p.y
			if t > 0 and t < 1 and across <= 3 and above >= -1 and above <= rise + 1 then
				local length = math.sqrt(length2)
				for _, end_ in { { stair.a, t * length }, { stair.b, (1 - t) * length } } do
					local cost = end_[2] + across
					if out[end_[1]] == nil or cost < out[end_[1]] then
						out[end_[1]] = cost
					end
				end
			end
		end
	end
	return out
end

-- A binary heap of { cost, node }, cheapest on top.
local function push(heap, cost: number, node: number)
	table.insert(heap, { cost, node })
	local i = #heap
	while i > 1 do
		local parent = i // 2
		if heap[parent][1] <= heap[i][1] then
			break
		end
		heap[parent], heap[i] = heap[i], heap[parent]
		i = parent
	end
end

local function pop(heap)
	local top = heap[1]
	local last = table.remove(heap)
	if #heap > 0 then
		heap[1] = last
		local i, n = 1, #heap
		while true do
			local l, r, smallest = 2 * i, 2 * i + 1, i
			if l <= n and heap[l][1] < heap[smallest][1] then
				smallest = l
			end
			if r <= n and heap[r][1] < heap[smallest][1] then
				smallest = r
			end
			if smallest == i then
				break
			end
			heap[smallest], heap[i] = heap[i], heap[smallest]
			i = smallest
		end
	end
	return top[1], top[2]
end

-- Dijkstra from several start nodes. opts:
--   avoid:    { [roomId] = true } rooms not to walk through (lit Lanterns)
--   allow:    { [roomId] = true } rooms walked through anyway (start, goal)

--   doorCost: function(seamId) -> extra studs for that doorway (a closed door),
--             or nil when nobody of this kind may pass it now (a lock; docs/
--             plans/gameplay-rework.md section 5.1). Charged on the way into
--             the doorway node, so it holds from both sides.
--   extra:    function(nodeId) -> extra studs for passing that node
function NavGraph.search(graph, sources, opts)
	opts = opts or {}
	local dist, parent, via = {}, {}, {}
	local heap = {}
	for node, cost in sources do
		dist[node] = cost
		push(heap, cost, node)
	end
	local nodes, seams = graph.nodes, graph.seams
	local avoid, allow = opts.avoid, opts.allow or {}

	while #heap > 0 do
		local cost, node = pop(heap)
		if cost <= dist[node] then
			for _, link in graph.links[node] do
				local to = link.to
				local step = link.cost
				local target = nodes[to]
				if link.seam then
					local seam = seams[link.seam]
					if not seam.connected then
						step = nil
					end
					if step and target.kind == "doorway" and opts.doorCost then
						local cost = opts.doorCost(link.seam)
						step = cost and step + cost or nil
					end
				end
				if step and avoid and target.kind ~= "doorway" and avoid[target.room] and not allow[target.room] then
					step = nil
				end
				if step then
					local total = cost + step + (opts.extra and opts.extra(to) or 0)
					if dist[to] == nil or total < dist[to] - 1e-9 then
						dist[to], parent[to], via[to] = total, node, link
						push(heap, total, to)
					end
				end
			end
		end
	end
	return dist, parent, via
end

-- The way from one point to another: { steps = { { node, seam?, stair? } },
-- cost }, where each step's seam or stair is the link walked into it. Steps
-- are empty when the two points are in the same room at the same height;
-- nil if there is no way.
function NavGraph.route(graph, from, fromRoom: number?, to, toRoom: number?, opts)
	if not fromRoom or not toRoom then
		return nil
	end
	local rise = graph.options.attachRise
	if fromRoom == toRoom and math.abs(from.y - to.y) <= rise then
		local room = graph.rooms[fromRoom]
		if not room.tall or NavGraph.storeyOf(graph, from.y) == NavGraph.storeyOf(graph, to.y) then
			return { steps = {}, cost = distance(from, to) }
		end
	end
	opts = table.clone(opts or {})
	opts.allow = { [fromRoom] = true, [toRoom] = true }
	local dist, parent, via = NavGraph.search(graph, NavGraph.attach(graph, from, fromRoom), opts)
	local best, bestCost = nil, math.huge
	for node, cost in NavGraph.attach(graph, to, toRoom) do
		local total = dist[node] and dist[node] + cost
		if total and (total < bestCost or (total == bestCost and best ~= nil and node < best)) then
			best, bestCost = node, total
		end
	end
	if not best then
		return nil
	end
	local steps = {}
	local node = best
	while node do
		local link = via[node]
		table.insert(steps, 1, { node = node, seam = link and link.seam, stair = link and link.stair })
		node = parent[node]
	end
	return { steps = steps, cost = bestCost }
end

-- Every node's walking distance from a point (for weighing where to go).
function NavGraph.distancesFrom(graph, point, roomId: number?, opts)
	return (NavGraph.search(graph, NavGraph.attach(graph, point, roomId), opts))
end

-- A point's distance in a table from distancesFrom.
function NavGraph.costAt(graph, dist, point, roomId: number?): number
	local best = math.huge
	for node, cost in NavGraph.attach(graph, point, roomId) do
		if dist[node] then
			best = math.min(best, dist[node] + cost)
		end
	end
	return best
end

-- How far apart two points are on foot, roughly and cheaply: on the flat on
-- one storey, otherwise by way of the nearest climb (the grand staircase or
-- a stairwell). Never less than the flat distance.
function NavGraph.separation(graph, a, b): number
	local sa, sb = NavGraph.storeyOf(graph, a.y), NavGraph.storeyOf(graph, b.y)
	if sa == sb then
		return flatDistance(a, b)
	end
	if sa > sb then
		a, b = b, a
		sa, sb = sb, sa
	end
	-- Storey by storey: from where you are to the foot of a climb, up it,
	-- and on from its top (the best climb over all of them when one storey
	-- apart; one by one, nearest each time, when more).
	local here, total = a, 0
	for storey = sa, sb - 1 do
		local best, bestHigh = math.huge, nil
		local last = storey == sb - 1
		for _, climb in graph.climbs do
			if climb.from == storey then
				local low, high = graph.nodes[climb.low], graph.nodes[climb.high]
				local cost = flatDistance(here, low) + climb.length + (last and flatDistance(high, b) or 0)
				if cost < best then
					best, bestHigh = cost, high
				end
			end
		end
		if bestHigh == nil then
			return distance(a, b)
		end
		total += best
		here = bestHigh
	end
	return total
end

return NavGraph
