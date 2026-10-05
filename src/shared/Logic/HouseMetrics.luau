-- How good a house and its escape plan are as a level (docs/plans/
-- level-design.md, section 5.1). A simulated squad walks the house over the
-- walking graph (Logic/NavGraph: real distances, stairs and the gallery
-- included) with each stage's locks shut, and the numbers that make a run
-- feel designed are measured: how far the walk is and how much of it goes
-- back over known ground, what each shortcut saves, whether every stage has
-- a loop to run and a hiding spot near, where the things the run needs lie.
-- `score` turns them into one number against bands (Config.LevelDesign),
-- so Logic/HouseSearch can keep the best of many houses. Pure.
--
-- The squad knows nothing in advance but searches well: it sweeps each
-- region as it opens (the way players explore a new wing), picks up what it
-- finds, opens the nearest lock it can, and goes to the table once every
-- heirloom is in hand, then out by the front door the long way round.

local Graph = require(script.Parent.Graph)
local LockPlanner = require(script.Parent.LockPlanner)
local MansionHouse = require(script.Parent.MansionHouse)
local NavGraph = require(script.Parent.NavGraph)
local RoomPurpose = require(script.Parent.RoomPurpose)
local RoomRects = require(script.Parent.RoomRects)

local HouseMetrics = {}

local function sortedKeys(t): { any }
	local keys = {}
	for key in t do
		table.insert(keys, key)
	end
	table.sort(keys, function(a, b)
		return tostring(a) < tostring(b)
	end)
	return keys
end

-- The node each room is walked to: an ordinary room's middle, a tall room's
-- point nearest its middle on the ground storey.
local function anchors(graph): { [number]: number }
	local out = {}
	for id, room in graph.rooms do
		local cx, cz = RoomRects.center(room.rect)
		local best, bestDistance = nil, math.huge
		for _, nodeId in room.nodes do
			local node = graph.nodes[nodeId]
			if node.kind == "centre" then
				best = nodeId
				break
			end
			if node.kind ~= "doorway" and math.abs(node.y) < 1 then
				local d = math.abs(node.x - cx) + math.abs(node.z - cz)
				if d < bestDistance then
					best, bestDistance = nodeId, d
				end
			end
		end
		out[id] = best or room.nodes[1]
	end
	return out
end

-- Studs walked in each room along the way from a search's source to `target`
-- (the search's parent links), source first.
local function pathRooms(graph, dist, parent, target: number): { { room: number, studs: number } }
	local steps = {}
	local node = target
	while parent[node] do
		local from = parent[node]
		table.insert(steps, 1, { room = graph.nodes[node].room, studs = dist[node] - dist[from] })
		node = from
	end
	return steps
end

-- A seam's two rooms.
local function ends(layout)
	local byId = {}
	for _, seam in layout.seams do
		byId[seam.id] = seam
	end
	return byId
end

-- The longest loop (in studs) and the deepest dead end among `open` rooms,
-- over connected seams between them.
local function stageShape(layout, open: { [number]: boolean }, seamByPair, config, mansion: boolean)
	local nodes, edges = {}, {}
	for id in open do
		table.insert(nodes, id)
	end
	table.sort(nodes)
	for _, seam in layout.seams do
		if seam.connected and open[seam.a] and open[seam.b] then
			table.insert(edges, { seam.a, seam.b })
		end
	end
	local adj = Graph.adjacency(nodes, edges)
	local longest = 0
	for _, cycle in Graph.fundamentalCycles(adj, nodes, edges) do
		local studs = mansion and MansionHouse.routeStuds(cycle, seamByPair, config, true)
			or #cycle * (config.CellSize or 40)
		longest = math.max(longest, studs)
	end
	local _, deepest = Graph.deadEndDepths(adj, nodes, edges)
	return longest, deepest
end

-- Measure a house and its plan. opts:
--   nav       NavGraph.options(Config)
--   config    the house's config (Config.Mansion or Config.Level)
--   shortcut  studs a bolt must save to count as a shortcut
--   purposes  every room's reasons (Logic/RoomPurpose.of): rooms without one
--             and regions short of their kit are counted
function HouseMetrics.measure(layout, plan, templatesById, opts)
	local mansion = layout.mode == "Mansion"
	local config = opts.config
	local graph = NavGraph.build(layout, opts.nav)
	local anchor = anchors(graph)
	local seamById = ends(layout)
	local seamByPair = {}
	for _, seam in layout.seams do
		seamByPair[MansionHouse.pairKey(seam.a, seam.b)] = seam
	end
	local roomById = {}
	for _, room in layout.rooms do
		roomById[room.id] = room
	end
	local function isCorridor(id: number): boolean
		local template = templatesById[roomById[id].template]
		return template ~= nil and template.family == "corridor"
	end

	local position = { [0] = 0 }
	for i, r in plan.order do
		position[r] = i
	end
	local regionOf = plan.roomRegion
	local dining, goal = plan.finale.table, plan.finale.goal

	-- Doors as they stand: a lock blocks until it's opened; `sealed` seams
	-- (the dinner's cut) block whatever.
	local function doorCost(opened: { [string]: boolean }, sealed: { [string]: boolean }?)
		return function(seamId: string): number?
			if sealed and sealed[seamId] then
				return nil
			end
			if plan.locks[seamId] and not opened[seamId] then
				return nil
			end
			return 0
		end
	end
	local function search(fromRoom: number, opened, sealed)
		return NavGraph.search(graph, { [anchor[fromRoom]] = 0 }, { doorCost = doorCost(opened, sealed) })
	end

	-- The walk ------------------------------------------------------------------------------
	local m = {
		rooms = #layout.rooms,
		regions = #plan.order,
		walk = 0,
		revisitStuds = 0,
		returns = 0,
		legs = {},
	}
	local opened, visited, had = {}, {}, {}
	local at = layout.start
	local newest = 0
	local gateKinds = {}
	local keyWalks = {}
	local tokenIds = sortedKeys(plan.tokens)
	local lockIds = sortedKeys(plan.locks)

	local function collect()
		for _, id in tokenIds do
			if not had[id] then
				local rooms = LockPlanner.producerRooms(plan, plan.tokens[id])
				local all = #rooms > 0
				for _, room in rooms do
					all = all and visited[room] == true
				end
				if all then
					had[id] = true
				end
			end
		end
	end
	local function enter(room: number)
		visited[room] = true
		-- A bolt slides back from its own side as you pass.
		for _, id in lockIds do
			local lock = plan.locks[id]
			if lock.kind == "bolt" and lock.side == room then
				opened[id] = true
			end
		end
	end
	-- Walk to a room; false if it can't be reached now.
	local function go(to: number, why: string): boolean
		if to == at then
			enter(to)
			collect()
			return true
		end
		local dist, parent = search(at, opened)
		local target = anchor[to]
		if dist[target] == nil then
			return false
		end
		local before = table.clone(visited)
		local studs = 0
		for _, step in pathRooms(graph, dist, parent, target) do
			studs += step.studs
			if before[step.room] then
				m.revisitStuds += step.studs
			end
			enter(step.room)
		end
		enter(to)
		m.walk += studs
		table.insert(m.legs, { to = to, why = why, studs = studs })
		at = to
		collect()
		return true
	end
	-- Explore every room of a region, nearest first.
	local function sweep(rooms: { number })
		while true do
			local dist = search(at, opened)
			local best, bestDistance = nil, math.huge
			for _, id in rooms do
				local d = dist[anchor[id]]
				if not visited[id] and d and d < bestDistance then
					best, bestDistance = id, d
				end
			end
			if not best then
				return
			end
			go(best, "explore")
		end
	end

	enter(at)
	collect()
	sweep(plan.regions[0].rooms)
	while true do
		-- The locks that can be opened now, from the side already open.
		local dist = search(at, opened)
		local best, bestDistance, bestFrom = nil, math.huge, nil
		for _, id in lockIds do
			local lock = plan.locks[id]
			local seam = seamById[id]
			if lock.kind ~= "bolt" and not opened[id] and seam then
				local from = lock.side or (lock.inside == seam.a and seam.b or seam.a)
				local ready = true
				for _, need in lock.needs or {} do
					ready = ready and had[need] == true
				end
				local d = dist[anchor[from]]
				if ready and d and d < bestDistance then
					best, bestDistance, bestFrom = id, d, from
				end
			end
		end
		if not best then
			break
		end
		local lock = plan.locks[best]
		if position[regionOf[bestFrom]] < newest then
			m.returns += 1
		end
		-- How far each thing it needed was from the door, found where it was.
		for _, need in lock.needs or {} do
			local room = LockPlanner.tokenRoom(plan, plan.tokens[need])
			if room then
				local d = search(room, opened)[anchor[bestFrom]]
				table.insert(keyWalks, d or math.huge)
			end
		end
		go(bestFrom, "open " .. best)
		opened[best] = true
		table.insert(gateKinds, lock.kind)
		newest = math.max(newest, position[lock.region] or 0)
		sweep(plan.regions[lock.region].rooms)
	end
	-- Anything still to fetch (a producer outside every region swept).
	for _, id in plan.finale.heirlooms do
		if not had[id] then
			for _, room in LockPlanner.producerRooms(plan, plan.tokens[id]) do
				go(room, "fetch " .. id)
			end
		end
	end
	local tableSet = go(dining, "set the table")
	for _, id in plan.finale.heirlooms do
		tableSet = tableSet and had[id] == true
	end
	m.tableSet = tableSet
	-- The run out: every lock open, the cut sealed.
	local all = {}
	for _, id in lockIds do
		all[id] = true
	end
	local sealed = {}
	for _, id in plan.finale.cut do
		sealed[id] = true
	end
	local out = search(dining, all, sealed)[anchor[goal]]
	m.finaleRun = out or math.huge
	m.walk += out or 0
	m.revisit = m.walk > 0 and m.revisitStuds / m.walk or 0

	-- Where things lie ------------------------------------------------------------------------
	local final = search(dining, all)
	local carries, floors, regions = {}, {}, {}
	m.corridorHeirlooms, m.corridorTokens = 0, 0
	-- Lying in a corridor: kept in no furniture (a puzzle there, like the
	-- dumbwaiter's hatch, is a set piece of its own).
	for _, id in tokenIds do
		local token = plan.tokens[id]
		local room = token.producer.kind == "container" and LockPlanner.tokenRoom(plan, token) or nil
		if room and isCorridor(room) then
			m.corridorTokens += 1
			if token.kind == "heirloom" then
				m.corridorHeirlooms += 1
			end
		end
	end
	for _, id in plan.finale.heirlooms do
		local room = LockPlanner.tokenRoom(plan, plan.tokens[id])
		if room then
			table.insert(carries, final[anchor[room]] or math.huge)
			floors[roomById[room].floor or 0] = true
			regions[regionOf[room]] = true
		end
	end
	local function count(t): number
		local n = 0
		for _ in t do
			n += 1
		end
		return n
	end
	m.heirloomFloors = count(floors)
	m.heirloomRegions = count(regions)
	m.carryMax = 0
	for _, c in carries do
		m.carryMax = math.max(m.carryMax, c)
	end
	m.keyWalkMin = math.huge
	for _, d in keyWalks do
		m.keyWalkMin = math.min(m.keyWalkMin, d)
	end
	if #keyWalks == 0 then
		m.keyWalkMin = nil
	end
	m.gateRepeats = 0
	for i = 2, #gateKinds do
		if gateKinds[i] == gateKinds[i - 1] then
			m.gateRepeats += 1
		end
	end
	m.gateKinds = gateKinds
	m.puzzles = count(plan.puzzles)

	-- Regions ------------------------------------------------------------------------------------
	m.r0Share = #plan.regions[0].rooms / math.max(1, #layout.rooms)
	m.minRegion, m.maxRegion = math.huge, 0
	for r = 1, #plan.order do
		local n = #plan.regions[r].rooms
		m.minRegion = math.min(m.minRegion, n)
		m.maxRegion = math.max(m.maxRegion, n)
	end
	if #plan.order == 0 then
		m.minRegion, m.maxRegion = nil, nil
	end

	-- Shortcuts: what each region's best bolt saves on the way back to the
	-- table from its farthest room, once the rest of the house before it is
	-- open. Only regions of four rooms or more are expected to have one (a
	-- wing of three is never far from its own door).
	local shortcut = opts.shortcut or 60
	m.shortcutRegions = 0
	m.shortcuts = {}
	local expected = 0
	for _, r in plan.order do
		local state = {}
		local bolts = {}
		for _, id in lockIds do
			local lock = plan.locks[id]
			local p = position[lock.region] or 0
			-- Gates up to this region open, bolts of the regions before it.
			if (lock.kind ~= "bolt" and p <= position[r]) or (lock.kind == "bolt" and p < position[r]) then
				state[id] = true
			elseif lock.kind == "bolt" and lock.region == r then
				table.insert(bolts, id)
			end
		end
		local closed = search(dining, state)
		local far, farDistance = nil, -1
		for _, id in plan.regions[r].rooms do
			local d = closed[anchor[id]]
			if d and d > farDistance then
				far, farDistance = id, d
			end
		end
		local best = 0
		if far then
			for _, id in bolts do
				state[id] = true
				local d = search(dining, state)[anchor[far]]
				state[id] = nil
				if d then
					best = math.max(best, farDistance - d)
				end
			end
		end
		m.shortcuts[r] = best
		if #plan.regions[r].rooms >= 4 then
			expected += 1
			if best >= shortcut then
				m.shortcutRegions += 1
			end
		end
	end
	m.shortcutShare = expected > 0 and m.shortcutRegions / expected or nil

	-- Every stage, once its bolts are open: a loop to run, no deep dead end,
	-- a hiding spot not far from any room.
	m.stageLoop, m.deadEnd, m.hideReach = math.huge, 0, 0
	local open = {}
	local stages = { 0 }
	for _, r in plan.order do
		table.insert(stages, r)
	end
	for _, r in stages do
		for _, id in plan.regions[r].rooms do
			open[id] = true
		end
		local longest, deepest = stageShape(layout, open, seamByPair, config, mansion)
		m.stageLoop = math.min(m.stageLoop, longest)
		m.deadEnd = math.max(m.deadEnd, deepest)
		local sources = {}
		for id in open do
			local offers = LockPlanner.offers(templatesById[roomById[id].template], mansion)
			if offers.hides > 0 then
				sources[anchor[id]] = 0
			end
		end
		local dist = NavGraph.search(graph, sources, {
			doorCost = function(seamId: string): number?
				local seam = seamById[seamId]
				return (seam and open[seam.a] and open[seam.b]) and 0 or nil
			end,
		})
		for id in open do
			m.hideReach = math.max(m.hideReach, dist[anchor[id]] or math.huge)
		end
	end

	-- Rooms with no reason to go in, and regions short of a hiding spot, a
	-- lure, or a landmark or Lantern (Logic/RoomPurpose).
	if opts.purposes then
		m.purposeless = 0
		for _, room in layout.rooms do
			local entry = opts.purposes[room.id]
			if entry and not RoomPurpose.hasReason(entry) then
				m.purposeless += 1
			end
		end
		m.kitGaps = RoomPurpose.kitGaps(opts.purposes, plan)
	end
	return m
end

-- How far a house falls outside its targets: { [metric] = { band = { lo, hi },
-- bySquad = { [n] = { lo, hi } }?, weight, scale } }. Each metric outside its
-- band adds weight per `scale` it misses by. Returns the total and the card:
-- every measured target with its value, band and penalty, in name order.
function HouseMetrics.score(m, targets, squad: number?)
	local total = 0
	local card = {}
	for _, name in sortedKeys(targets) do
		local target = targets[name]
		local band = (squad and target.bySquad and target.bySquad[squad]) or target.band
		local value = m[name]
		if value ~= nil and band then
			local miss = 0
			if value < band[1] then
				miss = band[1] - value
			elseif value > band[2] then
				miss = value - band[2]
			end
			-- An unreachable distance costs a lot, but stays a number.
			if miss == math.huge then
				miss = 1e4
			end
			local penalty = miss / (target.scale or 1) * (target.weight or 1)
			total += penalty
			table.insert(card, { name = name, value = value, band = band, penalty = penalty })
		end
	end
	return total, card
end

-- The card as lines of text, worst first (tools/plan, F2 `house`).
function HouseMetrics.describe(card): { string }
	local sorted = table.clone(card)
	table.sort(sorted, function(a, b)
		if a.penalty ~= b.penalty then
			return a.penalty > b.penalty
		end
		return a.name < b.name
	end)
	local lines = {}
	for _, line in sorted do
		local value = line.value == math.huge and "inf"
			or (math.floor(line.value) == line.value and tostring(line.value) or string.format("%.2f", line.value))
		table.insert(
			lines,
			string.format(
				"%s %-16s %8s  in %s-%s%s",
				line.penalty > 0 and "x" or " ",
				line.name,
				value,
				tostring(line.band[1]),
				tostring(line.band[2]),
				line.penalty > 0 and string.format("  (-%.1f)", line.penalty) or ""
			)
		)
	end
	return lines
end

return HouseMetrics
