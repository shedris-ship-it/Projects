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
--   locks      [seam id] = { kind = a gate kind (LockPlanner.Gates) | "bolt",
--              needs = { token }?, side = room id (a bolt opens from there; a
--              gate with `side` is worked from there), region, inside }
--   tokens     [token id] = { kind = "key" | "code" | "heirloom" | ..., opens = seam id?,
--              label, producer = { kind = "container", room } | { kind = "puzzle", id }
--              | { kind = <a producer kind>, rooms = { room ids } } }
--   puzzles    [puzzle id] = { kind = "terminal" | ..., room, seed }
--   finale     { table = room id, heirlooms = { token ids }, cut = { seam ids }, goal = room id }
--   stats      { regions, backtracks, puzzles, attempts }
--
-- What a gate can be is a registry (LockPlanner.Gates): each later mechanism
-- (the breaker, the crank door) adds an entry and switches it on in
-- Config.Progression.Enabled. A producer may need several rooms (the
-- dumbwaiter: a crank downstairs, a hatch upstairs); all of them must be open
-- before what it makes is needed.

local Dumbwaiter = require(script.Parent.Dumbwaiter)
local Graph = require(script.Parent.Graph)
local MansionHouse = require(script.Parent.MansionHouse)
local Interactables = require(script.Parent.Parent.Data.Interactables)
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
-- for the computer, and whether it has a landmark or a fixture to lure him
-- with (a reason to go in by itself; Logic/RoomPurpose).
function LockPlanner.offers(template, mansion: boolean)
	local hides, containers, desk, piano = 0, 0, false, false
	local landmark, lure = false, false
	for _, prop in template and template.props or {} do
		local kind = Props.Kinds[prop.kind]
		if kind and kind.hide then
			hides += 1
		end
		if kind and kind.landmark then
			landmark = true
		end
		if Interactables[prop.kind] then
			lure = true
		end
		if LockPlanner.Containers[prop.kind] then
			containers += 1
		end
		if prop.kind == "Desk" then
			desk = true
		elseif prop.kind == "Piano" then
			piano = true
		end
	end
	if mansion and template and template.mansion and template.mansion.hides then
		hides += template.mansion.hides
	end
	return { hides = hides, containers = containers, desk = desk, piano = piano, landmark = landmark, lure = lure }
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
	-- In the mansion, rooms with no reason of their own to go in (no landmark,
	-- lure or Lantern, not the hall or the dining room) and the corridors:
	-- what's kept goes to the first and never an heirloom to the second
	-- (docs/plans/level-design.md section 4). The old house keeps its plans.
	local bare, corridor = {}, {}
	if mansion then
		for _, id in ids do
			local room = byId[id]
			local template = templatesById[room.template]
			corridor[id] = room.corridor == true
				or room.kind == "stair"
				or (template ~= nil and template.family == "corridor")
			bare[id] = not corridor[id]
				and not offers[id].landmark
				and not offers[id].lure
				and not room.lantern
				and id ~= layout.start
				and id ~= layout.deliberation
		end
	end
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
		bare = bare,
		corridor = corridor,
		-- The cellar's and the attic's rooms: wings of their own that hold
		-- something the run needs (owner, 2026-10-05: they should "tie into
		-- the gameplay loop"; docs/plans/level-design.md section 10).
		storey = mansion and MansionHouse.storeyGroups(layout.rooms, templatesById) or {},
		storeyKeep = config and config.Storeys and config.Storeys.Keep or 1,
		walker = mansion and config and MansionHouse.walker(layout.rooms, layout.seams, config) or nil,
		deckBoost = config and config.Programme and config.Programme.DeckBoost or 1,
		kept = {}, -- rooms something is kept in so far (an attempt's)
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

-- Registries ------------------------------------------------------------------------

-- Where a puzzle may stand, by the room's offers.
LockPlanner.Where = {
	desk = function(ctx, id)
		return ctx.offers[id].desk
	end,
	-- A service room for the fuse box: the kitchen, laundry, garage, mudroom
	-- or pantry (not a bathroom).
	service = function(ctx, id)
		local template = ctx.templatesById[ctx.byId[id].template]
		return template ~= nil and template.family == "utility" and template.id ~= "bathroom"
	end,
	-- A room with a piano (the music box's tune is played back on it).
	piano = function(ctx, id)
		return ctx.offers[id].piano
	end,
	-- A lived-in room for a wall safe behind a painting: a bedroom, the
	-- study, the den... (not the hall or the dining room).
	homely = function(ctx, id)
		local template = ctx.templatesById[ctx.byId[id].template]
		return template ~= nil
			and (template.family == "living" or template.family == "bedroom")
			and template.id ~= "grand_hall"
			and template.id ~= "foyer"
			and template.id ~= "dining_room"
	end,
}

-- What can keep an heirloom: a drawer or cupboard in its room (the first,
-- the default; Logic/Leads gives it a lead), or a puzzle that holds it,
-- standing in a room of the heirloom's region that suits it. Drawn against
-- each other by Config.Progression.Keepers weights, in this order.
--   second  a puzzle in two rooms: where its other half lies (the music
--           box, in a room open no later than the piano's)
LockPlanner.Keepers = {
	{ id = "container" },
	{ id = "safe", puzzle = "safe", where = "homely" },
	{ id = "musicbox", puzzle = "musicbox", where = "piano", second = "homely" },
	-- A dumbwaiter between two stacked rooms (Logic/Dumbwaiter): it's taken
	-- from the upper room; its crank is in the one below.
	{ id = "dumbwaiter", puzzle = "dumbwaiter", stacked = true },
}

-- What kind of lock a region's gate can be. The first is the plain key; the
-- rest are drawn against it by Config.Progression.Flavours weights, in this
-- order (new kinds go at the end, so a seed's plan only changes when a new
-- kind is switched on). Each entry:
--   token      the token kind that opens it (nil: nothing to find)
--   puzzle     the puzzle that makes the token, standing in a room `where` allows
--   label      the token's label, from the name of the room behind the gate
--   side       worked from its outer side (a crank), with no token
--   count      tokens it needs (the double lock: two keys, kept far apart)
--   available  (ctx, gate seam) -> boolean, for kinds that need a particular doorway
LockPlanner.Gates = {
	{
		id = "key",
		token = "key",
		label = function(name)
			return name .. " key"
		end,
	},
	{
		id = "padlock",
		token = "code",
		puzzle = "terminal",
		where = "desk",
		label = function(name)
			return "The code for the padlock on the " .. name .. " door"
		end,
	},
	-- An electric lock, powered from the fuse box (Logic/Puzzles/Breaker).
	{
		id = "power",
		token = "power",
		puzzle = "breaker",
		where = "service",
		label = function(name)
			return "Power for the " .. name .. " door"
		end,
	},
	-- A heavy shutter raised by a crank on its outer side (Services/
	-- CrankService): nothing to find, two people (or a slow, loud ratchet).
	{ id = "crank", side = true },
	-- Two keyholes, two keys kept far apart (docs/plans/level-design.md
	-- section 5.3): a squad of three or four splits up for them. Its weight
	-- comes from the squad's size (Config.Mansion.BySquad).
	{
		id = "double",
		token = "key",
		count = 2,
		label = function(name)
			return name .. " key"
		end,
	},
}
LockPlanner.GateById = {}
for _, gate in LockPlanner.Gates do
	LockPlanner.GateById[gate.id] = gate
end

-- The rooms a token's producer needs open: a container's room, a puzzle's
-- room, or every room of a producer that spans several.
function LockPlanner.producerRooms(plan, token): { number }
	local producer = token.producer
	if producer.rooms then
		return producer.rooms
	elseif producer.kind == "puzzle" then
		local puzzle = plan.puzzles[producer.id]
		return puzzle and (puzzle.rooms or { puzzle.room }) or {}
	end
	return { producer.room }
end

-- The room a token is found in (the first of its producer's rooms).
function LockPlanner.tokenRoom(plan, token): number?
	return LockPlanner.producerRooms(plan, token)[1]
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
-- keep it in, never the dining room. In the mansion, a room with no reason
-- of its own to go in comes first (what's kept there becomes its reason),
-- one already keeping something comes last, and an heirloom is never kept
-- in a corridor (a key may hang on a rack there). `walk` (walking studs from
-- the door it opens, with `band`) sends a key the long way round: never
-- right by its door, best a good walk away (docs/plans/level-design.md 5.3).
local function keepingRoom(
	ctx,
	rng,
	rooms: { number },
	avoid: { [number]: boolean }?,
	heirloom: boolean?,
	walk: { [number]: number }?,
	band: { number }?
)
	local candidates = {}
	for _, id in rooms do
		if id ~= ctx.dining and not (avoid and avoid[id]) and not (heirloom and ctx.corridor[id]) then
			local weight = 0.3 + ctx.offers[id].containers
			if ctx.bare[id] then
				weight *= 2.5
			end
			if ctx.corridor[id] then
				weight *= 0.3
			end
			if ctx.mansion and ctx.kept[id] then
				weight *= 0.4
			end
			if ctx.storey[id] then
				weight *= ctx.storeyKeep
			end
			if walk and band then
				local studs = walk[id] or math.huge
				if studs < band[1] then
					weight *= 0.1
				elseif studs > band[2] then
					weight *= 0.4
				else
					weight *= 1 + studs / 100
				end
			end
			table.insert(candidates, { id = id, weight = weight })
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

-- A puzzle station's room among those that suit it: one in the cellar or the
-- attic when there is one (the fuse box downstairs: go down to bring the
-- power back), else any.
local function stationRoom(ctx, rng, rooms: { number }): number
	local storey = {}
	for _, id in rooms do
		if ctx.storey[id] then
			table.insert(storey, id)
		end
	end
	return rng:Pick(#storey > 0 and storey or rooms)
end

-- One plan. Its regions are grown here, or, for a mansion planned as wings
-- (Logic/Wings, docs/plans/level-design.md section 5.3), taken from those:
-- the regions, the order they open in, each one's gate and where its key
-- is kept; only what each lock is and what keeps each heirloom is drawn.
local function attempt(ctx, rng, cfg, k: number, wings)
	ctx.kept = {}
	local regions, roomRegion, count = {}, nil, nil
	if wings then
		roomRegion, count = table.clone(wings.roomRegion), #wings.order
	else
		local start = growStart(ctx, rng, cfg)
		roomRegion, count = growRegions(ctx, rng, start, k)
	end
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
	if wings then
		for i, r in wings.order do
			order[i] = r
			position[r] = i
		end
	end
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
	local counts = {} -- token kind -> how many so far
	local usedPuzzles = {} -- puzzle kind -> true once one stands in the house
	local enabled = cfg.Enabled or {}
	-- What the run's adventure wants (a mansion's programme; nothing else).
	local deck = ctx.layout.programme and ctx.layout.programme.deck or {}
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
		local gate
		if wings then
			gate = ctx.seamById[wings.gates[r]]
			if gate == nil then
				return nil
			end
			if wings.beats[r] and wings.beats[r].backtrack then
				plan.stats.backtracks += 1
			end
		else
			-- One gate: usually from the region just opened, sometimes from an
			-- older one (backtracking), a doorway with a door by preference.
			local pool = #recent > 0 and recent or older
			if #older > 0 and #recent > 0 and rng:Chance(cfg.BacktrackChance) then
				pool = older
				plan.stats.backtracks += 1
			end
			gate = rng:WeightedPick(pool, function(seam)
				return seam.door and cfg.DoorWeight or 1
			end)
		end
		local inside = roomRegion[gate.a] == r and gate.a or gate.b
		regions[r].gate = gate.id
		-- What opens it, made somewhere already open (the region just before by
		-- preference; as the wings planned it).
		local earlier = {}
		for _, id in ctx.ids do
			if position[roomRegion[id]] < index then
				table.insert(earlier, id)
			end
		end
		local nearRooms, walk
		if wings then
			local keyRegion = wings.keyRegion[r]
			nearRooms = keyRegion and regions[keyRegion].rooms or earlier
			-- Walking studs from the door, over what's open by now.
			local outer = inside == gate.a and gate.b or gate.a
			walk = ctx.walker(outer, function(seam)
				return seam.connected == true
					and position[roomRegion[seam.a]] < index
					and position[roomRegion[seam.b]] < index
			end)
		else
			nearRooms = rng:Chance(cfg.NearProducer) and regions[previous].rooms or earlier
		end
		-- The kinds this gate could be: the key always, and every other kind
		-- switched on that fits here (its puzzle has somewhere already open to
		-- stand; one of each puzzle a house).
		local options = { { gate = LockPlanner.Gates[1], weight = cfg.Flavours.key } }
		for i = 2, #LockPlanner.Gates do
			local kind = LockPlanner.Gates[i]
			local weight = cfg.Flavours[kind.id] or 0
			-- The run's adventure deck (Logic/Programme) wants this kind.
			if deck[kind.id] and weight > 0 then
				weight *= ctx.deckBoost
			end
			if enabled[kind.id] and weight > 0 then
				if kind.puzzle then
					if not usedPuzzles[kind.puzzle] and plan.stats.puzzles < cfg.MaxPuzzles then
						local rooms = {}
						for _, id in ctx.ids do
							local fits = id ~= ctx.dining and LockPlanner.Where[kind.where](ctx, id)
							if fits and position[roomRegion[id]] < index then
								table.insert(rooms, id)
							end
						end
						if #rooms > 0 then
							table.insert(options, { gate = kind, weight = weight, rooms = rooms })
						end
					end
				elseif kind.available == nil or kind.available(ctx, gate) then
					table.insert(options, { gate = kind, weight = weight })
				end
			end
		end
		local choice = options[1]
		if #options > 1 then
			local total = 0
			for _, option in options do
				total += option.weight
			end
			local roll = rng:NextNumber() * total
			for _, option in options do
				choice = option
				if roll < option.weight then
					break
				end
				roll -= option.weight
			end
		end
		local kind = choice.gate
		local needs = nil
		if kind.token and kind.count then
			-- Several of one token, each kept somewhere else: the second a long
			-- walk from the first.
			needs = {}
			local first = nil
			for n = 1, kind.count do
				counts[kind.token] = (counts[kind.token] or 0) + 1
				local token = kind.token .. ":" .. counts[kind.token]
				local apart = first
						and ctx.walker
						and ctx.walker(first, function(seam)
							return seam.connected == true
								and position[roomRegion[seam.a]] < index
								and position[roomRegion[seam.b]] < index
						end)
					or walk
				local room = keepingRoom(
					ctx,
					rng,
					n == 1 and nearRooms or earlier,
					first and { [first] = true } or nil,
					nil,
					apart,
					wings and wings.keyStuds
				)
				first = first or room
				ctx.kept[room] = true
				plan.tokens[token] = {
					kind = kind.token,
					opens = gate.id,
					label = kind.label(roomName(ctx, inside)) .. " (one of " .. kind.count .. ")",
					producer = { kind = "container", room = room },
				}
				table.insert(needs, token)
			end
		elseif kind.token then
			counts[kind.token] = (counts[kind.token] or 0) + 1
			local token = kind.token .. ":" .. counts[kind.token]
			local producer
			if kind.puzzle then
				local puzzleId = kind.puzzle .. ":1"
				plan.puzzles[puzzleId] = {
					kind = kind.puzzle,
					room = stationRoom(ctx, rng, choice.rooms),
					seed = rng:NextInteger(1, 2 ^ 30),
				}
				plan.stats.puzzles += 1
				usedPuzzles[kind.puzzle] = true
				producer = { kind = "puzzle", id = puzzleId }
			else
				producer = {
					kind = "container",
					room = keepingRoom(ctx, rng, nearRooms, nil, nil, walk, wings and wings.keyStuds),
				}
			end
			for _, room in LockPlanner.producerRooms(plan, { producer = producer }) do
				ctx.kept[room] = true
			end
			plan.tokens[token] = {
				kind = kind.token,
				opens = gate.id,
				label = kind.label(roomName(ctx, inside)),
				producer = producer,
			}
			needs = { token }
		end
		plan.locks[gate.id] = {
			kind = kind.id,
			needs = needs,
			region = r,
			inside = inside,
			side = kind.side and (inside == gate.a and gate.b or gate.a) or nil,
		}
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
	local storeyHeirloom = ctx.config and ctx.config.Storeys and ctx.config.Storeys.Heirloom or 1
	for r = 0, count do
		local weight = 1 + (position[r] or 0) * 1.5
		-- The family's old things are kept down in the cellar and up in the
		-- attic.
		if regions[r].rooms[1] and ctx.storey[regions[r].rooms[1]] then
			weight *= storeyHeirloom
		end
		table.insert(pool, { region = r, weight = weight })
	end
	local heirlooms, used = {}, {}
	for i = 1, wanted do
		-- In the mansion, only regions with a room fit to keep one (not the
		-- dining room, not a corridor, not keeping another heirloom).
		local function keepable(entry): boolean
			if not ctx.mansion then
				return true
			end
			for _, id in regions[entry.region].rooms do
				if id ~= ctx.dining and not ctx.corridor[id] and not used[id] then
					return true
				end
			end
			return false
		end
		local choices = {}
		for _, entry in pool do
			if not entry.taken and keepable(entry) then
				table.insert(choices, entry)
			end
		end
		if #choices == 0 then
			-- Fewer regions than heirlooms: share them, a different room each time.
			for _, entry in pool do
				entry.taken = false
				if keepable(entry) then
					table.insert(choices, entry)
				end
			end
			if #choices == 0 then
				choices = pool
			end
		end
		local entry = rng:WeightedPick(choices, function(e)
			return e.weight
		end)
		entry.taken = true
		local room = keepingRoom(ctx, rng, regions[entry.region].rooms, used, true)
		-- What keeps it: a drawer there, or a puzzle switched on that has
		-- somewhere in its region to stand (one of each puzzle a house).
		local producer = { kind = "container", room = room }
		local keepers = { { keeper = LockPlanner.Keepers[1], weight = (cfg.Keepers or {}).container or 1 } }
		for k = 2, #LockPlanner.Keepers do
			local keeper = LockPlanner.Keepers[k]
			local weight = (cfg.Keepers or {})[keeper.id] or 0
			if deck[keeper.id] and weight > 0 then
				weight *= ctx.deckBoost
			end
			if enabled[keeper.id] and weight > 0 and not usedPuzzles[keeper.puzzle] then
				if plan.stats.puzzles < cfg.MaxPuzzles and keeper.stacked then
					-- Two stacked rooms, both open no later than this region,
					-- the upper one in it, with a spot their furniture leaves
					-- clear (found once a house).
					ctx.stacked = ctx.stacked or Dumbwaiter.pairs(ctx.layout, cfg.Dumbwaiter or {}, ctx.templatesById)
					local stacks = {}
					for _, pair in ctx.stacked do
						local upperRegion, groundRegion = roomRegion[pair.upper], roomRegion[pair.ground]
						if
							upperRegion == entry.region
							and position[groundRegion] <= position[entry.region]
							and not used[pair.upper]
						then
							table.insert(stacks, pair)
						end
					end
					if #stacks > 0 then
						table.insert(keepers, { keeper = keeper, weight = weight, stacks = stacks })
					end
				elseif plan.stats.puzzles < cfg.MaxPuzzles then
					local rooms = {}
					for _, id in regions[entry.region].rooms do
						if id ~= ctx.dining and not used[id] and LockPlanner.Where[keeper.where](ctx, id) then
							table.insert(rooms, id)
						end
					end
					if #rooms > 0 then
						table.insert(keepers, { keeper = keeper, weight = weight, rooms = rooms })
					end
				end
			end
		end
		if #keepers > 1 then
			local total = 0
			for _, option in keepers do
				total += option.weight
			end
			local roll = rng:NextNumber() * total
			local choice = keepers[1]
			for _, option in keepers do
				choice = option
				if roll < option.weight then
					break
				end
				roll -= option.weight
			end
			local keeper = choice.keeper
			if keeper.puzzle then
				local stack = choice.stacks and rng:Pick(choice.stacks)
				room = stack and stack.upper or rng:Pick(choice.rooms)
				local puzzleId = keeper.puzzle .. ":1"
				local puzzle = { kind = keeper.puzzle, room = room, seed = rng:NextInteger(1, 2 ^ 30) }
				if stack then
					puzzle.rooms = { stack.upper, stack.ground }
				end
				if keeper.second then
					-- Its other half: a room open no later than this one.
					local seconds = {}
					for _, id in ctx.ids do
						local fits = id ~= room and id ~= ctx.dining and LockPlanner.Where[keeper.second](ctx, id)
						if fits and position[roomRegion[id]] <= position[entry.region] then
							table.insert(seconds, id)
						end
					end
					local other = rng:Pick(seconds) or room
					puzzle.rooms = { room, other }
				end
				plan.puzzles[puzzleId] = puzzle
				plan.stats.puzzles += 1
				usedPuzzles[keeper.puzzle] = true
				producer = { kind = "puzzle", id = puzzleId }
			end
		end
		used[room] = true
		ctx.kept[room] = true
		local id = "heirloom:" .. i
		plan.tokens[id] = { kind = "heirloom", label = "Heirloom " .. i, producer = producer }
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
	local reachable = reach(ctx, ctx.start, open)
	local function made(token)
		local rooms = LockPlanner.producerRooms(plan, token)
		for _, room in rooms do
			if not reachable[room] then
				return false
			end
		end
		return #rooms > 0
	end
	local tokenIds, lockIds = sortedKeys(plan.tokens), sortedKeys(plan.locks)
	local changed = true
	while changed do
		changed = false
		for _, id in tokenIds do
			if not held[id] and made(plan.tokens[id]) then
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
				elseif lock.side and not lock.needs then
					-- Worked from its outer side (a crank): open once you're there.
					if reachable[lock.side] then
						opened[id] = true
						table.insert(gates, id)
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

-- The shape of a plan's regions, whatever is behind its locks: each region
-- holds together; region 0 has somewhere to run round and somewhere to hide;
-- at every stage no dead end runs too deep, and a new region stays within
-- reach of its gate. Logic/MansionGen checks a mansion's wings with this
-- before keeping them (docs/plans/level-design.md section 5.3).
function LockPlanner.checkShape(layout, plan, templatesById, cfg, config): { string }
	local ctx = context(layout, templatesById, config)
	local problems = {}
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

-- The problems with a plan, or an empty list. `config` is the house's
-- (Config.Level or Config.Mansion), for walking distances.
function LockPlanner.check(layout, plan, templatesById, cfg, config): { string }
	local problems = {}
	local result = LockPlanner.solve(layout, plan, templatesById)
	if not result.solvable then
		table.insert(problems, result.tableSet and "no way out after the dinner" or "the table can't be set")
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
			local rooms = token and LockPlanner.producerRooms(plan, token) or {}
			local behind = #rooms == 0
			for _, room in rooms do
				behind = behind or position[plan.roomRegion[room]] >= position[lock.region]
			end
			if behind then
				table.insert(problems, seamId .. " is opened by something behind it")
			end
		end
		if lock.side and lock.kind ~= "bolt" and position[plan.roomRegion[lock.side]] >= position[lock.region] then
			table.insert(problems, seamId .. " is worked from behind it")
		end
	end
	for _, problem in LockPlanner.checkShape(layout, plan, templatesById, cfg, config) do
		table.insert(problems, problem)
	end
	return problems
end

-- The locked seams' ids, sorted.
function LockPlanner.lockIds(plan): { string }
	return sortedKeys(plan.locks)
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
	-- A mansion planned as wings (Logic/Wings) keeps its regions, order and
	-- gates; only the locks' kinds and the keepers are drawn. Should none of
	-- those draws pass (or the wings be more than this plan wants), the
	-- regions are grown here as for any other house.
	local wings = layout.wings
	-- The cellar's and the attic's wings come on top of the house's own (a
	-- house with no locks at all stays open).
	if target > 0 then
		target += wings and wings.storeys or 0
	end
	if wings and #wings.order > 0 and #wings.order <= target then
		for i = 1, cfg.Attempts do
			tries += 1
			local plan = attempt(ctx, rng:Fork("wings " .. i), cfg, #wings.order, wings)
			if plan then
				local problems = LockPlanner.check(layout, plan, templatesById, cfg, config)
				if #problems == 0 then
					plan.stats.attempts = tries
					plan.stats.rejected = rejected
					plan.stats.wings = true
					return plan
				end
				for _, problem in problems do
					local key = "wings: " .. string.gsub(problem, "%d+", "#")
					rejected[key] = (rejected[key] or 0) + 1
				end
				lastProblems = problems
			else
				rejected["wings: no attempt"] = (rejected["wings: no attempt"] or 0) + 1
			end
		end
	end
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
