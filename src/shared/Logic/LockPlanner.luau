-- The escape's progression (docs/plans/gameplay-rework.md section 5): which
-- doors are locked, what opens them, and where it all is. Resident Evil
-- made procedural: the house is cut into regions opened one after another,
-- each behind one locked door (a gate) whose key, or code, lies in a region
-- opened before it; every other doorway into a region is bolted on its far
-- side, a shortcut back once you're through. The heirlooms the dinner needs
-- (section 6) lie in different regions.
--
-- Pure, so every plan is proven by tests (tests/specs/LockPlanner.spec). It
-- runs after generation on any house and never rejects one: it lowers the
-- number of regions until a plan passes its checks, and with none (the
-- whole house open, only the heirlooms to find) it always does. The plan
-- goes in `layout.progression`, a nested table, so the layout's fingerprint
-- (scalar fields only) and the golden hashes don't change. It is never sent
-- to clients; puzzle answers aren't in it at all.
--
--   regions    [0..K] = { rooms = { ids }, gate = seam id? }
--   roomRegion [room id] = region
--   order      the regions in the order they open (not counting 0)
--   locks      [seam id] = { kind = "key" | "padlock" | "bolt", needs = { token }?,
--              side = room id (a bolt opens from there), region }
--   tokens     [token id] = { kind = "key" | "code" | "heirloom", opens = seam id?,
--              label, producer = { kind = "container", room } | { kind = "puzzle", id } }
--   puzzles    [puzzle id] = { kind = "terminal", room, seed }
--   finale     { table = room id, heirlooms = { token ids }, cut = { seam ids }, goal = room id }
--   stats      { regions, backtracks, puzzles, attempts }

local Graph = require(script.Parent.Graph)
local MansionHouse = require(script.Parent.MansionHouse)
local Props = require(script.Parent.Parent.Data.Props)

local LockPlanner = {}

-- Furniture with somewhere to keep things (World/PropFactory pieces).
LockPlanner.Containers = {
	Dresser = true,
	Desk = true,
	Wardrobe = true,
	Cabinet = true,
	Locker = true,
	Counter = true,
	Fridge = true,
	Chest = true,
}

-- What a room's template offers: hiding spots, places to keep things, a desk
-- for the computer.
function LockPlanner.offers(template, mansion: boolean)
	local hides, containers, desk = 0, 0, false
	for _, prop in template and template.props or {} do
		local kind = Props.Kinds[prop.kind]
		if kind and kind.hide then
			hides += 1
		end
		if LockPlanner.Containers[prop.kind] then
			containers += 1
		end
		if prop.kind == "Desk" then
			desk = true
		end
	end
	if mansion and template and template.mansion and template.mansion.hides then
		hides += template.mansion.hides
	end
	return { hides = hides, containers = containers, desk = desk }
end

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

-- The house as the planner sees it.
local function context(layout, templatesById, config)
	local ids, byId = {}, {}
	for _, room in layout.rooms do
		table.insert(ids, room.id)
		byId[room.id] = room
	end
	table.sort(ids)
	local seams, seamById, seamByPair = {}, {}, {}
	for _, seam in layout.seams do
		seamByPair[MansionHouse.pairKey(seam.a, seam.b)] = seam
		if seam.connected then
			table.insert(seams, seam)
			seamById[seam.id] = seam
		end
	end
	table.sort(seams, function(p, q)
		return p.id < q.id
	end)
	local edges = {}
	for _, seam in seams do
		table.insert(edges, { seam.a, seam.b })
	end
	local mansion = layout.mode == "Mansion"
	local offers = {}
	for _, id in ids do
		offers[id] = LockPlanner.offers(templatesById[byId[id].template], mansion)
	end
	local adj = Graph.adjacency(ids, edges)
	-- The house's loops through the hall or the dining room, with their length.
	local loops = {}
	for _, cycle in Graph.fundamentalCycles(adj, ids, edges) do
		if table.find(cycle, layout.start) or table.find(cycle, layout.deliberation) then
			local studs = mansion and config and MansionHouse.routeStuds(cycle, seamByPair, config, true)
				or #cycle * (config and config.CellSize or 40)
			table.insert(loops, { rooms = cycle, studs = studs })
		end
	end
	return {
		layout = layout,
		templatesById = templatesById,
		config = config,
		mansion = mansion,
		ids = ids,
		byId = byId,
		seams = seams,
		seamById = seamById,
		seamByPair = seamByPair,
		edges = edges,
		adj = adj,
		loops = loops,
		offers = offers,
		start = layout.start,
		dining = layout.deliberation,
		-- Where the run ends: the front door is on the hall in the mansion; the
		-- old house leaves by its exit room.
		goal = layout.frontDoor and layout.frontDoor.room or layout.exit,
	}
end

-- Rooms reachable from `from` over seams `open(seam)` allows, inside `allowed`
-- (any room when nil).
local function reach(ctx, from: number, open: (any) -> boolean, allowed): { [number]: boolean }
	local seen = { [from] = true }
	local queue = { from }
	local head = 1
	while head <= #queue do
		local room = queue[head]
		head += 1
		for _, seam in ctx.seams do
			local other = (seam.a == room and seam.b) or (seam.b == room and seam.a) or nil
			if other and not seen[other] and (allowed == nil or allowed[other]) and open(seam) then
				seen[other] = true
				table.insert(queue, other)
			end
		end
	end
	return seen
end

-- Planning -----------------------------------------------------------------------

-- Region 0: the hall, the dining room and the way between, grown into a
-- share of the house. Ground-floor public rooms come first, and a room that
-- closes a loop (two neighbours already in) most of all: region 0 must have
-- somewhere to run round.
local function growStart(ctx, rng, cfg)
	local share = rng:NextNumber(cfg.R0Share[1], cfg.R0Share[2])
	local target = math.max(2, math.floor(#ctx.ids * share + 0.5))
	local inside, count = {}, 0
	local function take(id)
		if not inside[id] then
			inside[id] = true
			count += 1
		end
	end
	for _, id in Graph.path(ctx.adj, ctx.start, ctx.dining) or { ctx.start } do
		take(id)
	end
	-- A loop through the hall or the dining room, long enough to run round
	-- and small enough to fit, comes first.
	local loops = {}
	for _, loop in ctx.loops do
		if #loop.rooms <= target and loop.studs >= cfg.Stage0Loop then
			table.insert(loops, loop)
		end
	end
	if #loops > 0 then
		for _, id in rng:Pick(loops).rooms do
			take(id)
		end
	end
	while count < target do
		local candidates = {}
		for _, id in ctx.ids do
			if not inside[id] then
				local touching = 0
				for _, other in ctx.adj[id] do
					if inside[other] then
						touching += 1
					end
				end
				if touching > 0 then
					local room = ctx.byId[id]
					local weight = 1
					if (room.floor or 0) == 0 then
						weight += 1
					end
					if room.zone == "public" or room.zone == "hall" then
						weight += 1
					end
					if touching >= 2 then
						weight += cfg.LoopBonus
					end
					table.insert(candidates, { id = id, weight = weight })
				end
			end
		end
		if #candidates == 0 then
			break
		end
		local pick = rng:WeightedPick(candidates, function(c)
			return c.weight
		end)
		inside[pick.id] = true
		count += 1
	end
	return inside
end

-- K anchors far from region 0 and from each other, in different zones where
-- possible, each grown into a region over the rooms left (a breadth-first
-- race, so every region is connected). Rooms only reachable through region
-- 0 join it.
local function growRegions(ctx, rng, start, k: number)
	local roomRegion = {}
	for id in start do
		roomRegion[id] = 0
	end
	local rest = {}
	for _, id in ctx.ids do
		if not start[id] then
			table.insert(rest, id)
		end
	end
	if k <= 0 or #rest == 0 then
		for _, id in rest do
			roomRegion[id] = 0
		end
		return roomRegion, 0
	end
	-- Hops from region 0 and from each anchor chosen so far.
	local function hopsFrom(sources: { number })
		local dist, queue, head = {}, {}, 1
		for _, id in sources do
			dist[id] = 0
			table.insert(queue, id)
		end
		while head <= #queue do
			local room = queue[head]
			head += 1
			for _, other in ctx.adj[room] do
				if dist[other] == nil then
					dist[other] = dist[room] + 1
					table.insert(queue, other)
				end
			end
		end
		return dist
	end
	local startIds = sortedKeys(start)
	local nearest = hopsFrom(startIds)
	local anchors, zones = {}, {}
	for _ = 1, math.min(k, #rest) do
		local best, bestScore = nil, -math.huge
		for _, id in rest do
			if roomRegion[id] == nil then
				local zone = ctx.byId[id].zone or ""
				local score = (nearest[id] or 0) + (zones[zone] and 0 or 1) + rng:NextNumber() * 0.9
				if score > bestScore then
					best, bestScore = id, score
				end
			end
		end
		if not best then
			break
		end
		table.insert(anchors, best)
		roomRegion[best] = #anchors
		zones[ctx.byId[best].zone or ""] = true
		local fromAnchor = hopsFrom({ best })
		for id, d in fromAnchor do
			nearest[id] = math.min(nearest[id] or math.huge, d)
		end
	end
	-- The race: each region takes the free rooms next to it in turn.
	local frontier = {}
	for i, id in anchors do
		frontier[i] = { id }
	end
	local growing = true
	while growing do
		growing = false
		for i = 1, #anchors do
			local nextFrontier = {}
			for _, room in frontier[i] do
				for _, other in ctx.adj[room] do
					if roomRegion[other] == nil then
						roomRegion[other] = i
						table.insert(nextFrontier, other)
						growing = true
					end
				end
			end
			frontier[i] = nextFrontier
		end
	end
	for _, id in rest do
		if roomRegion[id] == nil then
			roomRegion[id] = 0
		end
	end
	return roomRegion, #anchors
end

-- The regions that touch each region (through any doorway).
local function regionNeighbours(ctx, roomRegion)
	local neighbours = {}
	for _, seam in ctx.seams do
		local ra, rb = roomRegion[seam.a], roomRegion[seam.b]
		if ra ~= rb then
			neighbours[ra] = neighbours[ra] or {}
			neighbours[rb] = neighbours[rb] or {}
			neighbours[ra][rb] = true
			neighbours[rb][ra] = true
		end
	end
	return neighbours
end

local function roomName(ctx, id: number): string
	local template = ctx.templatesById[ctx.byId[id].template]
	return template and template.name or ("room " .. id)
end

-- A room in `region` to keep something in, favouring rooms with furniture to
-- keep it in, never the dining room.
local function keepingRoom(ctx, rng, rooms: { number }, avoid: { [number]: boolean }?)
	local candidates = {}
	for _, id in rooms do
		if id ~= ctx.dining and not (avoid and avoid[id]) then
			table.insert(candidates, { id = id, weight = 0.3 + ctx.offers[id].containers })
		end
	end
	if #candidates == 0 then
		for _, id in rooms do
			table.insert(candidates, { id = id, weight = 1 })
		end
	end
	return rng:WeightedPick(candidates, function(c)
		return c.weight
	end).id
end

local function attempt(ctx, rng, cfg, k: number)
	local start = growStart(ctx, rng, cfg)
	local roomRegion, count = growRegions(ctx, rng, start, k)
	local regions = {}
	for r = 0, count do
		regions[r] = { rooms = {} }
	end
	for _, id in ctx.ids do
		table.insert(regions[roomRegion[id]].rooms, id)
	end

	-- The order regions open in: a random walk outward from region 0.
	local neighbours = regionNeighbours(ctx, roomRegion)
	local position = { [0] = 0 }
	local order = {}
	while #order < count do
		local frontier = {}
		for r = 1, count do
			if position[r] == nil then
				for other in neighbours[r] or {} do
					if position[other] ~= nil then
						table.insert(frontier, r)
						break
					end
				end
			end
		end
		if #frontier == 0 then
			return nil -- a region touching nothing opened (can't happen in a connected house)
		end
		local pick = rng:Pick(frontier)
		table.insert(order, pick)
		position[pick] = #order
	end

	local plan = {
		regions = regions,
		roomRegion = roomRegion,
		order = order,
		locks = {},
		tokens = {},
		puzzles = {},
		stats = { regions = count, backtracks = 0, puzzles = 0 },
	}
	local keys, codes = 0, 0
	local deskRooms = {}
	for _, id in ctx.ids do
		if ctx.offers[id].desk and id ~= ctx.dining then
			table.insert(deskRooms, id)
		end
	end
	for index, r in order do
		local previous = index == 1 and 0 or order[index - 1]
		local boundary, older, recent = {}, {}, {}
		for _, seam in ctx.seams do
			local ra, rb = roomRegion[seam.a], roomRegion[seam.b]
			local other = (ra == r and rb) or (rb == r and ra) or nil
			if other ~= nil and other ~= r and position[other] < index then
				table.insert(boundary, seam)
				table.insert(other == previous and recent or older, seam)
			end
		end
		if #boundary == 0 then
			return nil
		end
		-- One gate: usually from the region just opened, sometimes from an
		-- older one (backtracking), a doorway with a door by preference.
		local pool = #recent > 0 and recent or older
		if #older > 0 and #recent > 0 and rng:Chance(cfg.BacktrackChance) then
			pool = older
			plan.stats.backtracks += 1
		end
		local gate = rng:WeightedPick(pool, function(seam)
			return seam.door and cfg.DoorWeight or 1
		end)
		local inside = roomRegion[gate.a] == r and gate.a or gate.b
		regions[r].gate = gate.id
		-- What opens it, made somewhere already open (the region just before by
		-- preference).
		local earlier = {}
		for _, id in ctx.ids do
			if position[roomRegion[id]] < index then
				table.insert(earlier, id)
			end
		end
		local nearRooms = rng:Chance(cfg.NearProducer) and regions[previous].rooms or earlier
		local flavour = "key"
		if cfg.Puzzles.terminal and plan.stats.puzzles < cfg.MaxPuzzles and next(plan.puzzles) == nil then
			local desks = {}
			for _, id in deskRooms do
				if position[roomRegion[id]] < index then
					table.insert(desks, id)
				end
			end
			if #desks > 0 then
				local weights = cfg.Flavours
				if rng:NextNumber() * (weights.key + weights.padlock) >= weights.key then
					flavour = "padlock"
					local room = rng:Pick(desks)
					plan.puzzles["terminal:1"] = { kind = "terminal", room = room, seed = rng:NextInteger(1, 2 ^ 30) }
					plan.stats.puzzles += 1
				end
			end
		end
		local token
		if flavour == "padlock" then
			codes += 1
			token = "code:" .. codes
			plan.tokens[token] = {
				kind = "code",
				opens = gate.id,
				label = "The code for the padlock on the " .. roomName(ctx, inside) .. " door",
				producer = { kind = "puzzle", id = "terminal:1" },
			}
		else
			keys += 1
			token = "key:" .. keys
			plan.tokens[token] = {
				kind = "key",
				opens = gate.id,
				label = roomName(ctx, inside) .. " key",
				producer = { kind = "container", room = keepingRoom(ctx, rng, nearRooms) },
			}
		end
		plan.locks[gate.id] = { kind = flavour, needs = { token }, region = r, inside = inside }
		-- Every other way in is bolted on this side: a shortcut once you're in.
		for _, seam in boundary do
			if seam ~= gate then
				local side = roomRegion[seam.a] == r and seam.a or seam.b
				plan.locks[seam.id] = { kind = "bolt", side = side, region = r }
			end
		end
	end

	-- The heirlooms: in different regions, later ones first, never two in a room.
	local wanted = rng:NextInteger(cfg.FinaleItems[1], cfg.FinaleItems[2])
	local pool = {}
	for r = 0, count do
		table.insert(pool, { region = r, weight = 1 + (position[r] or 0) * 1.5 })
	end
	local heirlooms, used = {}, {}
	for i = 1, wanted do
		local choices = {}
		for _, entry in pool do
			if not entry.taken then
				table.insert(choices, entry)
			end
		end
		if #choices == 0 then
			-- Fewer regions than heirlooms: share them, a different room each time.
			for _, entry in pool do
				entry.taken = false
			end
			choices = pool
		end
		local entry = rng:WeightedPick(choices, function(e)
			return e.weight
		end)
		entry.taken = true
		local room = keepingRoom(ctx, rng, regions[entry.region].rooms, used)
		used[room] = true
		local id = "heirloom:" .. i
		plan.tokens[id] =
			{ kind = "heirloom", label = "Heirloom " .. i, producer = { kind = "container", room = room } }
		table.insert(heirlooms, id)
	end

	-- The dinner seals the dining room's doors to the hall, if the squad can
	-- still get round to the front door the long way.
	local cut = {}
	for _, seam in ctx.seams do
		if (seam.a == ctx.dining and seam.b == ctx.start) or (seam.b == ctx.dining and seam.a == ctx.start) then
			table.insert(cut, seam.id)
		end
	end
	local sealed = {}
	for _, id in cut do
		sealed[id] = true
	end
	local out = reach(ctx, ctx.dining, function(seam)
		return not sealed[seam.id]
	end)
	if not out[ctx.goal] then
		cut = {}
	end
	plan.finale = { table = ctx.dining, heirlooms = heirlooms, cut = cut, goal = ctx.goal }
	return plan
end

-- Solving ---------------------------------------------------------------------------

-- Play the plan out: from the start, open what you can reach (bolts from
-- their side, gates with what you hold), pick up what you can reach, until
-- nothing changes. Returns { solvable, held, opened, gates (in the order they
-- opened), tableSet, out }.
function LockPlanner.solve(layout, plan, templatesById)
	local ctx = context(layout, templatesById or {}, nil)
	local opened, held, gates = {}, {}, {}
	local function open(seam)
		return plan.locks[seam.id] == nil or opened[seam.id] == true
	end
	local function producerRoom(token)
		local producer = token.producer
		if producer.kind == "container" then
			return producer.room
		end
		local puzzle = plan.puzzles[producer.id]
		return puzzle and puzzle.room
	end
	local reachable = reach(ctx, ctx.start, open)
	local tokenIds, lockIds = sortedKeys(plan.tokens), sortedKeys(plan.locks)
	local changed = true
	while changed do
		changed = false
		for _, id in tokenIds do
			local room = producerRoom(plan.tokens[id])
			if not held[id] and room and reachable[room] then
				held[id] = true
				changed = true
			end
		end
		for _, id in lockIds do
			local lock = plan.locks[id]
			local seam = ctx.seamById[id]
			if not opened[id] and seam then
				if lock.kind == "bolt" then
					if reachable[lock.side] then
						opened[id] = true
						changed = true
					end
				elseif reachable[seam.a] or reachable[seam.b] then
					local ready = true
					for _, need in lock.needs or {} do
						ready = ready and held[need] == true
					end
					if ready then
						opened[id] = true
						table.insert(gates, id)
						changed = true
					end
				end
			end
		end
		if changed then
			reachable = reach(ctx, ctx.start, open)
		end
	end
	local tableSet = reachable[ctx.dining] == true
	for _, id in plan.finale.heirlooms do
		tableSet = tableSet and held[id] == true
	end
	-- The run out: every lock springs open, the cut seals.
	local sealed = {}
	for _, id in plan.finale.cut do
		sealed[id] = true
	end
	local out = reach(ctx, ctx.dining, function(seam)
		return not sealed[seam.id]
	end)[ctx.goal] == true
	return {
		solvable = tableSet and out,
		tableSet = tableSet,
		out = out,
		held = held,
		opened = opened,
		gates = gates,
		reachable = reachable,
	}
end

-- Checking ---------------------------------------------------------------------------

-- The problems with a plan, or an empty list. `config` is the house's
-- (Config.Level or Config.Mansion), for walking distances.
function LockPlanner.check(layout, plan, templatesById, cfg, config): { string }
	local ctx = context(layout, templatesById, config)
	local problems = {}
	local result = LockPlanner.solve(layout, plan, templatesById)
	if not result.solvable then
		table.insert(problems, result.tableSet and "no way out after the dinner" or "the table can't be set")
	end
	-- Each region holds together on its own.
	for r = 0, #plan.order do
		local rooms = plan.regions[r].rooms
		local allowed = {}
		for _, id in rooms do
			allowed[id] = true
		end
		if #rooms > 0 and Graph.isConnected(Graph.adjacency(rooms, ctx.edges), rooms) == false then
			table.insert(problems, "region " .. r .. " is in pieces")
		end
	end
	-- What opens a gate is made before it.
	local position = { [0] = 0 }
	for i, r in plan.order do
		position[r] = i
	end
	for _, seamId in sortedKeys(plan.locks) do
		local lock = plan.locks[seamId]
		for _, need in lock.needs or {} do
			local token = plan.tokens[need]
			local producer = token and token.producer
			local room = producer
				and (producer.kind == "container" and producer.room or (plan.puzzles[producer.id] or {}).room)
			if not room or position[plan.roomRegion[room]] >= position[lock.region] then
				table.insert(problems, seamId .. " is opened by something behind it")
			end
		end
	end
	-- Region 0: somewhere to run round, and somewhere to hide.
	local startRooms = plan.regions[0].rooms
	local hides = 0
	for _, id in startRooms do
		hides += ctx.offers[id].hides
	end
	if hides < cfg.Stage0Hides then
		table.insert(problems, "region 0 has " .. hides .. " hiding spots")
	end
	local inStart = {}
	for _, id in startRooms do
		inStart[id] = true
	end
	local startEdges = {}
	for _, seam in ctx.seams do
		if inStart[seam.a] and inStart[seam.b] then
			table.insert(startEdges, { seam.a, seam.b })
		end
	end
	local startAdj = Graph.adjacency(startRooms, startEdges)
	local longest = 0
	for _, cycle in Graph.fundamentalCycles(startAdj, startRooms, startEdges) do
		local studs = ctx.mansion and MansionHouse.routeStuds(cycle, ctx.seamByPair, config, true)
			or #cycle * (config and config.CellSize or 40)
		longest = math.max(longest, studs)
	end
	if longest < cfg.Stage0Loop then
		table.insert(problems, string.format("region 0's longest loop is %d studs", longest))
	end
	-- At every stage, once its bolts are open, no dead end runs too deep. Just
	-- through a gate, with its bolts still shut, a new region is a dead end
	-- of its own until you open a way back (that's the risk of going in), so
	-- it only has to stay within RegionDepth rooms of its gate.
	local open = {}
	for _, id in startRooms do
		open[id] = true
	end
	local stages = { 0 }
	for _, r in plan.order do
		table.insert(stages, r)
	end
	for _, r in stages do
		for _, id in plan.regions[r].rooms do
			open[id] = true
		end
		local nodes, edges = {}, {}
		for id in open do
			table.insert(nodes, id)
		end
		table.sort(nodes)
		for _, seam in ctx.seams do
			if open[seam.a] and open[seam.b] then
				table.insert(edges, { seam.a, seam.b })
			end
		end
		local _, deepest = Graph.deadEndDepths(Graph.adjacency(nodes, edges), nodes, edges)
		if deepest > cfg.MaxDeadEnd then
			table.insert(problems, string.format("stage %d has a dead end %s deep", r, tostring(deepest)))
		end
		local gate = plan.regions[r].gate
		local lock = gate and plan.locks[gate]
		if lock then
			local rooms = plan.regions[r].rooms
			local inside = {}
			for _, id in rooms do
				inside[id] = true
			end
			local regionEdges = {}
			for _, seam in ctx.seams do
				if inside[seam.a] and inside[seam.b] then
					table.insert(regionEdges, { seam.a, seam.b })
				end
			end
			local depths = Graph.bfs(Graph.adjacency(rooms, regionEdges), lock.inside)
			local far = 0
			for _, id in rooms do
				far = math.max(far, depths[id] or math.huge)
			end
			if far > cfg.RegionDepth then
				table.insert(problems, string.format("region %d runs %s rooms past its gate", r, tostring(far)))
			end
		end
	end
	return problems
end

-- How many regions a house of `rooms` rooms is cut into.
function LockPlanner.regionCount(rooms: number, cfg): number
	for _, band in cfg.Regions do
		if rooms <= band.upTo then
			return band.count
		end
	end
	return cfg.Regions[#cfg.Regions].count
end

-- The plan for a house: the most regions that pass every check, down to none.
-- `config` is the house's config (walking distances); `extra` adds regions
-- (Hard).
function LockPlanner.plan(layout, templatesById, rng, cfg, config, extra: number?)
	local ctx = context(layout, templatesById, config)
	local target = LockPlanner.regionCount(#ctx.ids, cfg) + (extra or 0)
	local tries = 0
	local lastProblems = {}
	local rejected = {} -- why attempts failed, for tools/lockstats
	for k = target, 0, -1 do
		for i = 1, (k == 0 and 1 or cfg.Attempts) do
			tries += 1
			local plan = attempt(ctx, rng:Fork("plan " .. k .. ":" .. i), cfg, k)
			if plan then
				local problems = LockPlanner.check(layout, plan, templatesById, cfg, config)
				if #problems == 0 or k == 0 then
					plan.stats.attempts = tries
					plan.stats.problems = #problems > 0 and problems or nil
					plan.stats.rejected = rejected
					return plan
				end
				for _, problem in problems do
					local key = string.gsub(problem, "%d+", "#")
					rejected[key] = (rejected[key] or 0) + 1
				end
				lastProblems = problems
			else
				rejected["no attempt"] = (rejected["no attempt"] or 0) + 1
			end
		end
	end
	error("LockPlanner: no plan at all (" .. table.concat(lastProblems, "; ") .. ")")
end

return LockPlanner
