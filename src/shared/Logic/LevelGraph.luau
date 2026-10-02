-- Seeded layout generator (doc section 3). Generates the arrangement, not the
-- art: which room templates appear, where they sit on a grid, and which walls
-- between neighbours are real doorways.
--
--   1. Grow a compact blob of 10-16 cells outward from the start room; each
--      new cell joins the blob through one doorway (a spanning tree).
--   2. Add 2-3 extra doorways that close loops of 4-8 rooms, preferring ones
--      that rescue deep dead ends. Loops are what make chases survivable.
--   3. Pick the exit (farthest room on the edge), the Deliberation Table on
--      the critical path, and 1-2 Lantern rooms.
--   4. Assign templates, avoiding three rooms of the same mood in a row, and
--      turn rooms with windows so the windows face outside.
--   5. Validate (Logic/LayoutValidator); retry with the next seed, then fall
--      back to an authored layout.

local Graph = require(script.Parent.Graph)
local LayoutValidator = require(script.Parent.LayoutValidator)
local Rng = require(script.Parent.Parent.Lib.Rng)

local LevelGraph = {}

LevelGraph.Dirs = {
	N = { dx = 0, dz = -1, opposite = "S" },
	E = { dx = 1, dz = 0, opposite = "W" },
	S = { dx = 0, dz = 1, opposite = "N" },
	W = { dx = -1, dz = 0, opposite = "E" },
}
LevelGraph.DirOrder = { "N", "E", "S", "W" }

local function cellKey(x: number, z: number): string
	return x .. "," .. z
end
LevelGraph.cellKey = cellKey

local function sortedPair(a: number, b: number)
	if a < b then
		return { a, b }
	end
	return { b, a }
end

-- Grow the blob. Returns rooms (id, gx, gz), a cell lookup and the tree edges.
local function growBlob(rng, count: number)
	local rooms = { { id = 1, gx = 0, gz = 0 } }
	local cells = { [cellKey(0, 0)] = 1 }
	local treeEdges = {}
	while #rooms < count do
		local candidates = {}
		local order = {}
		for _, room in rooms do
			for _, dirName in LevelGraph.DirOrder do
				local dir = LevelGraph.Dirs[dirName]
				local x, z = room.gx + dir.dx, room.gz + dir.dz
				local key = cellKey(x, z)
				if not cells[key] then
					if not candidates[key] then
						candidates[key] = { gx = x, gz = z, parents = {} }
						table.insert(order, candidates[key])
					end
					table.insert(candidates[key].parents, room.id)
				end
			end
		end
		-- Cells touching more of the blob are favoured, keeping it compact so
		-- extra doorways can close short loops. A small bias against straying
		-- far from the start keeps the house roughly square.
		local pick = rng:WeightedPick(order, function(c)
			local spread = math.abs(c.gx) + math.abs(c.gz)
			return (#c.parents) ^ 1.8 + 0.4 - spread * 0.04
		end)
		local id = #rooms + 1
		table.insert(rooms, { id = id, gx = pick.gx, gz = pick.gz })
		cells[cellKey(pick.gx, pick.gz)] = id
		table.sort(pick.parents)
		table.insert(treeEdges, sortedPair(rng:Pick(pick.parents), id))
	end
	return rooms, cells, treeEdges
end

-- Every pair of rooms that share a wall, whether or not it has a doorway.
local function adjacentPairs(rooms, cells)
	local pairsList = {}
	for _, room in rooms do
		for _, dirName in { "E", "S" } do
			local dir = LevelGraph.Dirs[dirName]
			local neighbour = cells[cellKey(room.gx + dir.dx, room.gz + dir.dz)]
			if neighbour then
				table.insert(pairsList, sortedPair(room.id, neighbour))
			end
		end
	end
	table.sort(pairsList, function(p, q)
		if p[1] ~= q[1] then
			return p[1] < q[1]
		end
		return p[2] < q[2]
	end)
	return pairsList
end

local function nodeIds(rooms)
	local ids = table.create(#rooms)
	for i, room in rooms do
		ids[i] = room.id
	end
	return ids
end

-- Close loops. Candidates are neighbouring rooms without a doorway; a
-- candidate closes a loop of (current distance + 1) rooms.
local function addLoops(rng, rooms, adjacent, edges, config)
	local ids = nodeIds(rooms)
	local edgeSet = {}
	for _, edge in edges do
		edgeSet[Graph.edgeKey(edge[1], edge[2])] = true
	end
	local minLoop, maxLoop = config.LoopLength[1], config.LoopLength[2]
	local wanted = rng:NextInteger(config.ExtraEdges[1], config.ExtraEdges[2])
	local added = 0

	local function candidatesWithin(maxLength: number)
		local adj = Graph.adjacency(ids, edges)
		local depths = Graph.deadEndDepths(adj, ids, edges)
		local list = {}
		for _, pair in adjacent do
			if not edgeSet[Graph.edgeKey(pair[1], pair[2])] then
				local dist = Graph.bfs(adj, pair[1])[pair[2]]
				local loopLength = dist and dist + 1 or math.huge
				if loopLength >= minLoop and loopLength <= maxLength then
					local depthA = depths[pair[1]] == math.huge and 3 or depths[pair[1]]
					local depthB = depths[pair[2]] == math.huge and 3 or depths[pair[2]]
					table.insert(list, { pair = pair, length = loopLength, depth = math.max(depthA, depthB) })
				end
			end
		end
		return list
	end

	local function addEdge(candidate)
		table.insert(edges, candidate.pair)
		edgeSet[Graph.edgeKey(candidate.pair[1], candidate.pair[2])] = true
		added += 1
	end

	-- The core loops: short, chase-friendly, weighted toward rescuing dead ends.
	while added < wanted do
		local list = candidatesWithin(maxLoop)
		if #list == 0 then
			break
		end
		addEdge(rng:WeightedPick(list, function(c)
			return 1 + c.depth * 2.5 + (c.length <= 6 and 1 or 0)
		end))
	end

	-- Then patch any room still more than MaxDeadEndChain rooms from a loop.
	while added < config.MaxExtraEdges do
		local adj = Graph.adjacency(ids, edges)
		local _, deepest = Graph.deadEndDepths(adj, ids, edges)
		if deepest <= config.MaxDeadEndChain then
			break
		end
		local list = candidatesWithin(maxLoop + 4)
		table.sort(list, function(p, q)
			if p.depth ~= q.depth then
				return p.depth > q.depth
			end
			if p.length ~= q.length then
				return p.length < q.length
			end
			return Graph.edgeKey(p.pair[1], p.pair[2]) < Graph.edgeKey(q.pair[1], q.pair[2])
		end)
		if #list == 0 or list[1].depth == 0 then
			break
		end
		addEdge(list[1])
	end
	return added
end

-- Whether a room's wall on a world side faces outside the house.
local function isOuterSide(room, cells, dirName: string): boolean
	local dir = LevelGraph.Dirs[dirName]
	return cells[cellKey(room.gx + dir.dx, room.gz + dir.dz)] == nil
end
LevelGraph.isOuterSide = isOuterSide

local function hasOuterSide(room, cells): boolean
	for _, dirName in LevelGraph.DirOrder do
		if isOuterSide(room, cells, dirName) then
			return true
		end
	end
	return false
end
LevelGraph.hasOuterSide = hasOuterSide

-- The world side a template's side ends up on once the room is turned by
-- `rotation` quarter turns (LevelBuilder turns rooms with CFrame.Angles, so
-- each turn takes N to W, W to S, and so on).
function LevelGraph.worldSide(side: string, rotation: number): string
	local index = table.find(LevelGraph.DirOrder, side) :: number
	return LevelGraph.DirOrder[(index - 1 - rotation) % 4 + 1]
end

-- A template's windows: wall decor of kind Window, on its outer walls.
function LevelGraph.windows(template)
	local list = {}
	for _, decor in template.decor or {} do
		if decor.kind == "Window" and decor.side then
			table.insert(list, decor)
		end
	end
	return list
end

-- Windows look outside (docs/ART.md, owner's playtest 2026-10-02): turn each
-- room that has windows so they land on outer walls. Tries the rolled
-- rotation first, then each further quarter turn, and keeps the first that
-- puts the most windows outside, the window that lights the room counting
-- most. Uses no randomness, so the rest of the house a seed builds is the
-- same. LevelBuilder leaves out any window still facing another room.
local function orientWindows(rooms, cells, templatesById)
	for _, room in rooms do
		local windows = LevelGraph.windows(templatesById[room.template])
		if #windows > 0 then
			local best, bestScore = room.rotation, -1
			for turn = 0, 3 do
				local rotation = (room.rotation + turn) % 4
				local score = 0
				for _, window in windows do
					if isOuterSide(room, cells, LevelGraph.worldSide(window.side, rotation)) then
						score += window.key and 10 or 1
					end
				end
				if score > bestScore then
					best, bestScore = rotation, score
				end
			end
			room.rotation = best
		end
	end
end

-- Choose exit, deliberation room and Lantern rooms.
local function assignRoles(rng, rooms, cells, adj, config)
	local start = 1
	local dist = Graph.bfs(adj, start)
	local farthest, best = {}, -1
	for _, room in rooms do
		if room.id ~= start and hasOuterSide(room, cells) then
			local d = dist[room.id] or -1
			if d > best then
				best = d
				farthest = { room.id }
			elseif d == best then
				table.insert(farthest, room.id)
			end
		end
	end
	table.sort(farthest)
	local exit = rng:Pick(farthest)
	local criticalPath = exit and Graph.path(adj, start, exit) or { start }
	local deliberation = criticalPath[math.max(2, math.ceil(#criticalPath / 2))]
	if deliberation == exit or deliberation == start then
		deliberation = nil
	end

	-- Lantern rooms: away from start/exit/deliberation and from each other.
	local lanternCount = rng:NextInteger(config.LanternRooms[1], config.LanternRooms[2])
	local lanterns = {}
	local candidates = {}
	for _, room in rooms do
		if room.id ~= start and room.id ~= exit and room.id ~= deliberation then
			table.insert(candidates, room.id)
		end
	end
	rng:Shuffle(candidates)
	for _, id in candidates do
		if #lanterns >= lanternCount then
			break
		end
		local farEnough = true
		for _, other in lanterns do
			local d = Graph.bfs(adj, id)[other]
			if d and d < 3 then
				farEnough = false
			end
		end
		if farEnough then
			table.insert(lanterns, id)
		end
	end
	if #lanterns == 0 and #candidates > 0 then
		table.insert(lanterns, candidates[1])
	end
	table.sort(lanterns)
	return {
		start = start,
		exit = exit,
		deliberation = deliberation,
		criticalPath = criticalPath,
		lanterns = lanterns,
		distances = dist,
	}
end

-- Assign a template to every room. Fixed roles first, then weighted picks
-- in BFS order that avoid three rooms of the same mood in a row.
local function assignTemplates(rng, rooms, adj, roles, templates)
	local counts = {}
	local byRole = { start = {}, exit = {}, deliberation = {} }
	local general = {}
	for _, template in templates do
		counts[template.id] = 0
		local roleTemplate = false
		for role in template.roles do
			if byRole[role] then
				table.insert(byRole[role], template)
				roleTemplate = true
			end
		end
		if not roleTemplate then
			table.insert(general, template)
		end
	end

	local function take(room, template)
		room.template = template.id
		room.mood = template.mood
		counts[template.id] += 1
	end

	local roomById = {}
	for _, room in rooms do
		roomById[room.id] = room
		room.rotation = rng:NextInteger(0, 3)
		room.lantern = table.find(roles.lanterns, room.id) ~= nil
	end

	take(roomById[roles.start], rng:Pick(byRole.start))
	roomById[roles.start].role = "start"
	if roles.exit then
		take(roomById[roles.exit], rng:Pick(byRole.exit))
		roomById[roles.exit].role = "exit"
	end
	if roles.deliberation then
		take(roomById[roles.deliberation], rng:Pick(byRole.deliberation))
		roomById[roles.deliberation].role = "deliberation"
	end

	local _, parent = Graph.bfs(adj, roles.start)
	local order = {}
	for _, room in rooms do
		table.insert(order, room)
	end
	table.sort(order, function(p, q)
		local dp, dq = roles.distances[p.id] or 0, roles.distances[q.id] or 0
		if dp ~= dq then
			return dp < dq
		end
		return p.id < q.id
	end)

	for _, room in order do
		if room.template == nil then
			-- moods of the two rooms leading here
			local p1 = parent[room.id] and roomById[parent[room.id]]
			local p2 = p1 and parent[p1.id] and roomById[parent[p1.id]]
			local avoidMood = (p1 and p2 and p1.mood == p2.mood) and p1.mood or nil
			local degree = #adj[room.id]
			local options = {}
			for _, template in general do
				if counts[template.id] < (template.max or 1) and template.mood ~= avoidMood then
					table.insert(options, template)
				end
			end
			if #options == 0 then
				for _, template in general do
					if counts[template.id] < (template.max or 1) then
						table.insert(options, template)
					end
				end
			end
			if #options == 0 then
				options = general
			end
			local pick = rng:WeightedPick(options, function(template)
				local w = template.weight or 1
				-- Hallways read best as junctions.
				if template.mood == "watched" and degree >= 3 then
					w *= 1.8
				end
				return w
			end)
			take(room, pick)
		end
	end
end

-- Build a full layout from rooms + doorway edges. Shared by the generator
-- and the authored fallback.
local function finish(rng, rooms, cells, edges, templates, config, extra)
	local ids = nodeIds(rooms)
	local adj = Graph.adjacency(ids, edges)
	local roles = assignRoles(rng, rooms, cells, adj, config)
	assignTemplates(rng, rooms, adj, roles, templates)
	local templatesById = {}
	for _, template in templates do
		templatesById[template.id] = template
	end
	orientWindows(rooms, cells, templatesById)

	local adjacent = adjacentPairs(rooms, cells)
	local edgeSet = {}
	for _, edge in edges do
		edgeSet[Graph.edgeKey(edge[1], edge[2])] = true
	end
	local seams = {}
	for _, pair in adjacent do
		local connected = edgeSet[Graph.edgeKey(pair[1], pair[2])] == true
		table.insert(seams, {
			id = "seam:" .. pair[1] .. "-" .. pair[2],
			a = pair[1],
			b = pair[2],
			connected = connected,
			door = connected and rng:Chance(config.DoorChance) or false,
		})
	end

	return {
		rooms = rooms,
		cells = cells,
		edges = edges,
		seams = seams,
		start = roles.start,
		exit = roles.exit,
		deliberation = roles.deliberation,
		criticalPath = roles.criticalPath,
		lanterns = roles.lanterns,
		extraEdges = extra,
	}
end

-- One generation attempt with a given RNG.
function LevelGraph.attempt(rng, templates, config)
	local count = rng:NextInteger(config.RoomCount[1], config.RoomCount[2])
	local rooms, cells, edges = growBlob(rng, count)
	local adjacent = adjacentPairs(rooms, cells)
	local extra = addLoops(rng, rooms, adjacent, edges, config)
	return finish(rng, rooms, cells, edges, templates, config, extra)
end

-- Known-good authored layout: 12 rooms on a 4x3 grid with three loops.
function LevelGraph.fallback(seed: number, templates, config)
	local rng = Rng.new(seed):Fork("fallback")
	local grid = {
		{ 0, 0 },
		{ 1, 0 },
		{ 2, 0 },
		{ 3, 0 },
		{ 0, 1 },
		{ 1, 1 },
		{ 2, 1 },
		{ 3, 1 },
		{ 0, 2 },
		{ 1, 2 },
		{ 2, 2 },
		{ 3, 2 },
	}
	local rooms, cells = {}, {}
	for i, pos in grid do
		rooms[i] = { id = i, gx = pos[1], gz = pos[2] }
		cells[cellKey(pos[1], pos[2])] = i
	end
	local edges = {
		{ 1, 2 },
		{ 2, 6 },
		{ 5, 6 },
		{ 1, 5 }, -- loop A (4 rooms)
		{ 7, 8 },
		{ 8, 12 },
		{ 11, 12 },
		{ 7, 11 }, -- loop B (4 rooms)
		{ 6, 7 },
		{ 2, 3 },
		{ 3, 4 },
		{ 5, 9 },
		{ 9, 10 },
		{ 10, 11 },
	}
	local layout = finish(rng, rooms, cells, edges, templates, config, 3)
	layout.fallback = true
	return layout
end

-- Generate a validated layout from a seed. Returns the layout plus a report
-- of how many attempts it took.
function LevelGraph.generate(seed: number, templates, config)
	local problems
	for attemptIndex = 0, config.MaxAttempts - 1 do
		local rng = Rng.new(seed + attemptIndex * 7919)
		local layout = LevelGraph.attempt(rng, templates, config)
		local ok, issues = LayoutValidator.validate(layout, templates, config)
		if ok then
			layout.seed = seed
			layout.attempts = attemptIndex + 1
			return layout
		end
		problems = issues
	end
	local layout = LevelGraph.fallback(seed, templates, config)
	layout.seed = seed
	layout.attempts = config.MaxAttempts
	layout.lastProblems = problems
	return layout
end

return LevelGraph
