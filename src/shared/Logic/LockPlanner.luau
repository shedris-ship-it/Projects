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
--              gate with `side` is worked from there), region, inside,
--              mark = a mark (Data/Marks) on a door that takes something found }
--   tokens     [token id] = { kind = "key" | "code" | "heirloom" | ..., opens = seam id?,
--              label, mark?, producer = { kind = "container", room } | { kind = "puzzle", id }
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
local RoomFit = require(script.Parent.RoomFit)
local Interactables = require(script.Parent.Parent.Data.Interactables)
local Marks = require(script.Parent.Parent.Data.Marks)
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
--   label      the token's label, from the door's mark (never the room behind
--              it, which nobody has seen: docs/plans/level-design.md section 11)
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
			return "The code for the " .. name .. " padlock"
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
	-- Tool locks (docs/plans/level-design.md section 11, L3.3; Logic/
	-- ToolLocks): one tool a kind a house, found before the first door it
	-- opens and used again at every later one; loud, slow work. Mansions only.
	{
		id = "boards",
		tool = "Crowbar",
		mansion = true,
		label = function()
			return "crowbar"
		end,
	},
	{
		id = "chain",
		tool = "BoltCutters",
		mansion = true,
		label = function()
			return "bolt cutters"
		end,
	},
}
LockPlanner.GateById = {}
for _, gate in LockPlanner.Gates do
	LockPlanner.GateById[gate.id] = gate
end

-- What opens a `kindId` gate, named by its door's mark ("phone key", "The
-- code for the note padlock"); `count` for a lock wanting several (the
-- double lock's keys).
function LockPlanner.label(kindId: string, markName: string, count: number?): string
	local kind = LockPlanner.GateById[kindId]
	local text = (kind and kind.label) and kind.label(markName) or (markName .. " key")
	return count and (text .. " (one of " .. count .. ")") or text
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

-- Side rooms behind a door the house key opens (pockets, docs/plans/
-- level-design.md section 11, L3.2). One plain key a run is the house key:
-- it opens its own gate and isn't used up, and the same mark is on the door
-- of a side room or two in a part of the house the squad has already been
-- through, each holding an heirloom. Going back pays.
--
-- A pocket is a room with one doorway (so nothing lies past it), inside its
-- region, with nothing else in it the run needs (no key, no puzzle, no note
-- or chute or servants' passage into it), not a corridor, a stair, the hall
-- or the dining room. Its door is seen before the house key is found: it
-- lies in a region opened no later than the key's (older ones first).
-- `cfg.Pockets` is { fewest, most } a house (by squad, Logic/HouseSize).
local function addPockets(ctx, rng, plan, cfg, position)
	local range = cfg.Pockets
	if not range or not ctx.mansion then
		return
	end
	local want = rng:NextInteger(range[1], range[2])
	if want <= 0 then
		return
	end
	-- Rooms that must stay open: what's kept in them, puzzles, the chute's
	-- and the servants' passages' rooms.
	local busy = { [ctx.dining] = true, [ctx.start] = true }
	if ctx.goal then
		busy[ctx.goal] = true
	end
	-- (An heirloom in a drawer may stay: it's what the side room is for.)
	local holds = {}
	local function shut(token): boolean
		return token.producer.piece ~= nil or (plan.pockets ~= nil and plan.pockets[token.producer.room] ~= nil)
	end
	for id, token in plan.tokens do
		if token.kind == "heirloom" and token.producer.kind == "container" and not shut(token) then
			holds[token.producer.room] = id
		else
			for _, room in LockPlanner.producerRooms(plan, token) do
				busy[room] = true
			end
		end
	end
	for _, puzzle in plan.puzzles do
		busy[puzzle.room] = true
		for _, room in puzzle.rooms or {} do
			busy[room] = true
		end
	end
	local layout = ctx.layout
	if layout.chute then
		busy[layout.chute.ground] = true
		busy[layout.chute.upper] = true
	end
	for _, passage in layout.passages or {} do
		for _, seam in passage.seams or {} do
			busy[seam.a] = true
			busy[seam.b] = true
		end
	end
	local doorways = {}
	for _, seam in ctx.seams do
		doorways[seam.a] = doorways[seam.a] or {}
		doorways[seam.b] = doorways[seam.b] or {}
		table.insert(doorways[seam.a], seam)
		table.insert(doorways[seam.b], seam)
	end
	local candidates = {}
	for _, id in ctx.ids do
		local seams = doorways[id] or {}
		local seam = seams[1]
		local room = ctx.byId[id]
		if
			#seams == 1
			and not busy[id]
			and not ctx.corridor[id]
			and room.kind ~= "stair"
			and not room.tall
			and not room.lantern
			and not seam.arch
			and plan.locks[seam.id] == nil
			and plan.roomRegion[seam.a] == plan.roomRegion[seam.b]
		then
			table.insert(candidates, { room = id, seam = seam, region = plan.roomRegion[id] })
		end
	end
	-- Region 0 keeps its hiding spots open.
	local startHides = 0
	for _, id in plan.regions[0].rooms do
		startHides += ctx.offers[id].hides
	end
	-- The house key: a gate opened by one key kept in a room, the one with
	-- the most older side rooms to send the squad back to.
	local best, bestScore = nil, -1
	for _, r in plan.order do
		local lock = plan.locks[plan.regions[r].gate]
		local token = lock.kind == "key" and lock.needs and #lock.needs == 1 and plan.tokens[lock.needs[1]]
		-- (Not a key a step inside a wing shuts away.)
		if token and token.producer.kind == "container" and not shut(token) then
			local at = position[plan.roomRegion[token.producer.room]]
			local older, same = {}, {}
			for _, c in candidates do
				local p = position[c.region]
				if p < at then
					table.insert(older, c)
				elseif p == at then
					table.insert(same, c)
				end
			end
			local score = #older * 10 + #same + at * 0.1
			if (#older + #same) > 0 and score > bestScore then
				best, bestScore = { lock = lock, token = lock.needs[1], older = older, same = same }, score
			end
		end
	end
	-- No plain-key gate to share (cranks, padlocks, power, double locks): a
	-- key of its own that opens only the side rooms, found later than any of
	-- them (below).
	if not best then
		local older = {}
		for _, c in candidates do
			if position[c.region] < #plan.order then
				table.insert(older, c)
			end
		end
		if #older == 0 then
			return
		end
		best = { standalone = true, older = older, same = {} }
	end
	-- What each cellar or attic wing holds that the run needs: one of its
	-- heirlooms may only leave for a side room if something else stays.
	local storeyHolds = {}
	local function holdIn(room)
		local group = ctx.storey[room]
		if group then
			storeyHolds[group] = (storeyHolds[group] or 0) + 1
		end
	end
	for _, token in plan.tokens do
		for _, room in LockPlanner.producerRooms(plan, token) do
			holdIn(room)
		end
	end
	for _, puzzle in plan.puzzles do
		holdIn(puzzle.room)
	end
	-- Heirlooms that can move into a side room (kept in furniture, not in
	-- one already).
	local movable = {}
	for _, id in plan.finale.heirlooms do
		local token = plan.tokens[id]
		if token.producer.kind == "container" and not shut(token) then
			table.insert(movable, id)
		end
	end
	local pockets = {}
	local regionsUsed, taken = {}, {}
	rng:Shuffle(best.older)
	rng:Shuffle(best.same)
	-- Older regions first, each a different region where it can be; then
	-- a second in a region that has one.
	local passes = {
		{ pool = best.older, spread = true },
		{ pool = best.same, spread = true },
		{ pool = best.older },
		{ pool = best.same },
	}
	for _, pass in passes do
		for _, c in pass.pool do
			if #pockets >= want or #movable == 0 then
				break
			end
			local hides = ctx.offers[c.room].hides
			local keepsHides = c.region ~= 0 or startHides - hides >= cfg.Stage0Hides
			if not taken[c.room] and not (pass.spread and regionsUsed[c.region]) and keepsHides then
				taken[c.room] = true
				-- Its heirloom: the one already in it, else one in this region
				-- (so the heirlooms stay spread), else one not keeping the
				-- cellar or the attic busy (they must hold something the run
				-- needs: section 10.0); none, no side room here.
				local pick = holds[c.room] and table.find(movable, holds[c.room])
				for _, rank in { 1, 2 } do
					for i, id in movable do
						local room = plan.tokens[id].producer.room
						local group = ctx.storey[room]
						local fits = (rank == 1 and plan.roomRegion[room] == c.region)
							or (rank == 2 and (not group or (storeyHolds[group] or 0) >= 2))
						if fits and pick == nil then
							pick = i
						end
					end
				end
				if pick == nil then
					taken[c.room] = nil
					continue
				end
				local heirloom = table.remove(movable, pick)
				local from = plan.tokens[heirloom].producer.room
				if ctx.storey[from] then
					storeyHolds[ctx.storey[from]] -= 1
				end
				holdIn(c.room)
				plan.tokens[heirloom].producer = { kind = "container", room = c.room }
				if c.region == 0 then
					startHides -= hides
				end
				regionsUsed[c.region] = true
				table.insert(pockets, c)
			end
		end
	end
	if #pockets == 0 then
		return
	end
	local tokenId = best.token
	if best.standalone then
		-- Found in a region opened after every side room's (going back is
		-- the point), the newest by preference; with a mark no door has.
		local newest = 0
		for _, c in pockets do
			newest = math.max(newest, position[c.region])
		end
		local later, same = {}, {}
		for _, id in ctx.ids do
			local p = position[plan.roomRegion[id]]
			if not taken[id] and p > newest then
				table.insert(later, id)
			elseif not taken[id] and p == newest then
				table.insert(same, id)
			end
		end
		local avoid = table.clone(taken)
		for side in plan.pockets or {} do
			avoid[side] = true
		end
		local room = keepingRoom(ctx, rng, #later > 0 and later or same, avoid)
		local used = {}
		for _, lock in plan.locks do
			if lock.mark then
				used[lock.mark] = true
			end
		end
		local mark = nil
		for _, id in rng:Shuffle(table.clone(Marks.Ids)) do
			if not used[id] then
				mark = id
				break
			end
		end
		mark = mark or Marks.Ids[1]
		tokenId = "key:house"
		plan.tokens[tokenId] = {
			kind = "key",
			opens = pockets[1].seam.id,
			mark = mark,
			label = LockPlanner.label("key", Marks.ById[mark].name),
			producer = { kind = "container", room = room },
			house = true,
		}
	end
	local key = plan.tokens[tokenId]
	key.reusable = true
	key.also = {}
	plan.pockets = plan.pockets or {}
	for _, c in pockets do
		plan.locks[c.seam.id] = {
			kind = "pocket",
			needs = { tokenId },
			region = c.region,
			inside = c.room,
			mark = key.mark,
			pocket = true,
		}
		plan.pockets[c.room] = { seam = c.seam.id, opener = tokenId }
		if c.seam.id ~= key.opens then
			table.insert(key.also, c.seam.id)
		end
	end
	plan.stats.pockets = #pockets
end

local solveWith -- (below: the solver, over a context already built)

-- Steps inside a wing (docs/plans/level-design.md section 11, L3.4): for
-- three or four players, a big wing's prize (the key to a later door, else
-- an heirloom) is shut away inside the wing, and the tool that opens it is
-- in the wing's other branch, or in the wing opened beside it straight
-- after. Shut away in a side room, its door boarded up or chained, or, with
-- no side room to spare, in a chest (or the fridge) chained or nailed shut
-- (`plan.pieces`). Someone goes for the tool while the rest carry on, and
-- whoever pries wants a lookout. What opens a step is never a key, so key
-- hunts don't multiply. Each step is played out by the solver and left out
-- if the squad couldn't finish with it. `cfg.WingSteps` is { fewest, most }
-- a house (by squad, Logic/HouseSize), in wings of `cfg.WingStepRooms`
-- rooms or more.
--
--   plan.pieces [lock id] = { kind = "boards" | "chain", needs = { tool },
--              room, prop = the template prop's id, thing = "chest", region,
--              step = true }; what's kept in it has `producer.piece` = its id
local function addWingSteps(ctx, rng, plan, cfg, position)
	local range = cfg.WingSteps
	if not range or not ctx.mansion or range[2] <= 0 then
		return
	end
	local want = rng:NextInteger(range[1], range[2])
	if want <= 0 then
		return
	end
	-- What may be shut away (a key to a gate, or an heirloom, kept in
	-- furniture), and the rooms that keep anything else or must stay open.
	local busy = { [ctx.dining] = true, [ctx.start] = true }
	if ctx.goal then
		busy[ctx.goal] = true
	end
	local prizes = {} -- room -> { token ids }
	for _, id in sortedKeys(plan.tokens) do
		local token = plan.tokens[id]
		local gate = token.opens and plan.locks[token.opens]
		local prize = token.producer.kind == "container"
			and (
				token.kind == "heirloom"
				or (token.kind == "key" and not token.reusable and gate ~= nil and not gate.pocket)
			)
		if prize then
			local room = token.producer.room
			prizes[room] = prizes[room] or {}
			table.insert(prizes[room], id)
		else
			for _, room in LockPlanner.producerRooms(plan, token) do
				busy[room] = true
			end
		end
	end
	for _, puzzle in plan.puzzles do
		busy[puzzle.room] = true
		for _, room in puzzle.rooms or {} do
			busy[room] = true
		end
	end
	local layout = ctx.layout
	if layout.chute then
		busy[layout.chute.ground] = true
		busy[layout.chute.upper] = true
	end
	-- (A side room with a servants' passage into it has another way in.)
	local passage = {}
	for _, way in layout.passages or {} do
		for _, seam in way.seams or {} do
			passage[seam.a] = true
			passage[seam.b] = true
		end
	end
	local doorways = {}
	for _, seam in ctx.seams do
		doorways[seam.a] = doorways[seam.a] or {}
		doorways[seam.b] = doorways[seam.b] or {}
		table.insert(doorways[seam.a], seam)
		table.insert(doorways[seam.b], seam)
	end
	-- Where each wing's door is seen from: wings off the same region opened
	-- one after the other are siblings (Logic/Wings: split up).
	local doorRegion = {}
	for _, r in plan.order do
		local gate = plan.regions[r].gate
		local seam = gate and ctx.seamById[gate]
		local lock = gate and plan.locks[gate]
		if seam and lock then
			doorRegion[r] = plan.roomRegion[seam.a == lock.inside and seam.b or seam.a]
		end
	end
	local function sibling(r: number): number?
		for _, s in plan.order do
			if s ~= r and doorRegion[s] == doorRegion[r] and position[s] == position[r] + 1 then
				return s
			end
		end
		return nil
	end
	-- The furniture a step can chain or nail shut in a room, as it will be
	-- furnished (Logic/RoomFit, as World/MansionBuilder lays it out).
	local pieceKinds = cfg.StepPieces or {}
	local fitted = {}
	local function piecesIn(id: number): { any }
		if fitted[id] == nil then
			local list = {}
			local room = ctx.byId[id]
			local template = ctx.templatesById[room.template]
			if template then
				for _, prop in RoomFit.inMansion(layout, room, template, cfg.PieceWall or 0.5).props do
					if (pieceKinds[prop.kind] or 0) > 0 then
						table.insert(list, prop)
					end
				end
			end
			fitted[id] = list
		end
		return fitted[id]
	end
	-- Somewhere a tool may lie: keeping nothing else (a prize is fine), and
	-- not shut away.
	local function free(id: number): boolean
		return (not busy[id] or prizes[id] ~= nil) and not (plan.pockets and plan.pockets[id])
	end
	local enabled = cfg.Enabled or {}
	-- Big wings, the biggest first.
	local wings = {}
	for _, r in plan.order do
		if #plan.regions[r].rooms >= (cfg.WingStepRooms or 5) then
			table.insert(wings, r)
		end
	end
	rng:Shuffle(wings)
	table.sort(wings, function(a, b)
		local na, nb = #plan.regions[a].rooms, #plan.regions[b].rooms
		if na ~= nb then
			return na > nb
		end
		return position[a] < position[b]
	end)

	-- Shut `prize` away at `spot` behind `kind`'s tool (`fresh`: a new tool,
	-- kept in a room of `rooms`), if the squad can still finish; else put
	-- everything back as it was.
	local function try(r: number, spot, prize: string, kind, fresh, rooms, walk): boolean
		local tokenId = "tool:" .. kind.tool
		local token = plan.tokens[prize]
		local was = token.producer
		local lockId = spot.seam and spot.seam.id or ("piece:" .. spot.room .. ":" .. spot.prop.id)
		local tool = plan.tokens[tokenId]
		if fresh then
			local avoid = { [spot.room] = true }
			for room in plan.pockets or {} do
				avoid[room] = true
			end
			tool = {
				kind = "tool",
				tool = kind.tool,
				-- (A tool that only opens furniture opens no door.)
				opens = spot.seam and spot.seam.id or nil,
				label = kind.label(),
				producer = {
					kind = "container",
					room = keepingRoom(ctx, rng, rooms, avoid, nil, walk, cfg.StepToolStuds),
				},
			}
			plan.tokens[tokenId] = tool
		elseif spot.seam then
			tool.also = tool.also or {}
			table.insert(tool.also, spot.seam.id)
		end
		if spot.seam then
			plan.locks[lockId] = {
				kind = kind.id,
				needs = { tokenId },
				region = r,
				inside = spot.room,
				pocket = true,
				step = true,
			}
			plan.pockets = plan.pockets or {}
			plan.pockets[spot.room] = { seam = lockId, opener = tokenId, step = true }
			token.producer = { kind = "container", room = spot.room }
		else
			plan.pieces = plan.pieces or {}
			plan.pieces[lockId] = {
				kind = kind.id,
				needs = { tokenId },
				room = spot.room,
				prop = spot.prop.id,
				thing = string.lower(spot.prop.kind),
				region = r,
				step = true,
			}
			token.producer = { kind = "container", room = spot.room, piece = lockId }
		end
		-- The squad can finish with it, and can't without opening it (what it
		-- holds is needed: never a chore for nothing).
		local step = spot.seam and plan.locks[lockId] or plan.pieces[lockId]
		local finishes = solveWith(ctx, plan).solvable
		local needed = false
		if finishes then
			step.needs = { "nothing" }
			needed = not solveWith(ctx, plan).solvable
			step.needs = { tokenId }
		end
		if needed then
			busy[spot.room] = true
			busy[LockPlanner.tokenRoom(plan, tool)] = true
			for _, list in prizes do
				local at = table.find(list, prize)
				if at then
					table.remove(list, at)
				end
			end
			return true
		end
		token.producer = was
		if spot.seam then
			plan.locks[lockId] = nil
			plan.pockets[spot.room] = nil
		else
			plan.pieces[lockId] = nil
		end
		if fresh then
			plan.tokens[tokenId] = nil
		elseif spot.seam then
			table.remove(tool.also)
		end
		return false
	end

	local steps = 0
	for _, r in wings do
		if steps >= want then
			break
		end
		local rooms = plan.regions[r].rooms
		-- Where: side rooms first (one doorway, inside the wing, with
		-- furniture to keep the prize in), then a chest or the like in any
		-- room; deepest from the wing's door first.
		local gateLock = plan.locks[plan.regions[r].gate]
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
		local depth = Graph.bfs(Graph.adjacency(rooms, regionEdges), gateLock.inside)
		local sideRooms, pieces = {}, {}
		for _, id in rooms do
			local seams = doorways[id] or {}
			local seam = seams[1]
			local room = ctx.byId[id]
			local open = not busy[id] and not ctx.corridor[id] and not (plan.pockets and plan.pockets[id])
			if
				open
				and #seams == 1
				and not passage[id]
				and room.kind ~= "stair"
				and not room.tall
				and not room.lantern
				and not seam.arch
				and plan.locks[seam.id] == nil
				and plan.roomRegion[seam.a] == plan.roomRegion[seam.b]
				and ctx.offers[id].containers > 0
			then
				table.insert(sideRooms, { room = id, seam = seam, depth = depth[id] or 0 })
			end
			local list = open and piecesIn(id) or {}
			if #list > 0 then
				local prop = rng:WeightedPick(list, function(p)
					return pieceKinds[p.kind]
				end)
				table.insert(pieces, { room = id, prop = prop, depth = depth[id] or 0 })
			end
		end
		local spots = {}
		for _, list in { sideRooms, pieces } do
			rng:Shuffle(list)
			table.sort(list, function(a, b)
				if a.depth ~= b.depth then
					return a.depth > b.depth
				end
				return a.room < b.room
			end)
			for _, spot in list do
				table.insert(spots, spot)
			end
		end
		-- What: a key first (it leads on), else an heirloom.
		local keys, heirlooms = {}, {}
		for _, id in rooms do
			for _, token in prizes[id] or {} do
				table.insert(plan.tokens[token].kind == "key" and keys or heirlooms, token)
			end
		end
		local choices = rng:Shuffle(keys)
		for _, token in rng:Shuffle(heirlooms) do
			table.insert(choices, token)
		end
		-- How: a tool the house doesn't have yet, in the sibling wing (opened
		-- just after) or across this one; else one it has, wherever it lies.
		local placed = false
		for _, spot in spots do
			for _, prize in choices do
				local have, fresh = 0, {}
				for _, kind in LockPlanner.Gates do
					if kind.tool then
						if plan.tokens["tool:" .. kind.tool] then
							have += 1
						elseif enabled[kind.id] and (cfg.Flavours[kind.id] or 0) > 0 then
							table.insert(fresh, kind)
						end
					end
				end
				if have < (cfg.MaxTools or 2) and #fresh > 0 then
					local kind = rng:Pick(fresh)
					local s = sibling(r)
					if s and rng:Chance(cfg.StepSibling or 0.5) then
						local there = {}
						for _, id in plan.regions[s].rooms do
							if free(id) then
								table.insert(there, id)
							end
						end
						placed = #there > 0 and try(r, spot, prize, kind, true, there)
					end
					if not placed then
						-- Across the wing: a walk from the step, never beside it.
						local door = spot.seam and (spot.seam.a == spot.room and spot.seam.b or spot.seam.a)
							or spot.room
						local walk = ctx.walker
							and ctx.walker(door, function(seam)
								return seam.connected == true
							end)
						local band = cfg.StepToolStuds or { 40, 400 }
						local across = {}
						for _, id in rooms do
							local far = walk == nil or (walk[id] or 0) >= band[1]
							if id ~= spot.room and free(id) and far then
								table.insert(across, id)
							end
						end
						placed = #across > 0 and try(r, spot, prize, kind, true, across, walk)
					end
				end
				for _, kind in LockPlanner.Gates do
					if not placed and kind.tool and plan.tokens["tool:" .. kind.tool] then
						placed = try(r, spot, prize, kind, false)
					end
				end
				if placed then
					break
				end
			end
			if placed then
				steps += 1
				break
			end
		end
	end
	plan.stats.wingSteps = steps
end

-- The safe room (docs/plans/level-design.md section 11.12; the owner's idea,
-- 2026-10-05): an optional objective. A small side room (a storeroom, a
-- pantry, a box room, by preference) behind a steel door on an electric
-- lock, powered from the fuse box: the house's own (a second door on its
-- panel), or one put in for it. Inside, things that help (Logic/SafeRoom),
-- never anything the run needs, so going for it is the squad's gamble: time
-- and noise at the panel for batteries, a lantern, the plans of a floor.
--
--   plan.safeRoom = { room, seam, puzzle = the fuse box's id, addDoor? }
--   its lock: kind "power", needs { "power:safe" }, optional, vault
local function addSafeRoom(ctx, rng, plan, cfg, position)
	local opts = cfg.SafeRoom
	-- (A house too small for wings stays simply open.)
	if not opts or not ctx.mansion or not (cfg.Enabled or {}).power or #plan.order == 0 then
		return
	end
	local busy = { [ctx.dining] = true, [ctx.start] = true }
	if ctx.goal then
		busy[ctx.goal] = true
	end
	for _, token in plan.tokens do
		for _, room in LockPlanner.producerRooms(plan, token) do
			busy[room] = true
		end
	end
	for _, puzzle in plan.puzzles do
		busy[puzzle.room] = true
		for _, room in puzzle.rooms or {} do
			busy[room] = true
		end
	end
	local layout = ctx.layout
	if layout.chute then
		busy[layout.chute.ground] = true
		busy[layout.chute.upper] = true
	end
	for _, way in layout.passages or {} do
		for _, seam in way.seams or {} do
			busy[seam.a] = true
			busy[seam.b] = true
		end
	end
	for room in plan.pockets or {} do
		busy[room] = true
	end
	for _, piece in plan.pieces or {} do
		busy[piece.room] = true
	end
	local doorways = {}
	for _, seam in ctx.seams do
		doorways[seam.a] = doorways[seam.a] or {}
		doorways[seam.b] = doorways[seam.b] or {}
		table.insert(doorways[seam.a], seam)
		table.insert(doorways[seam.b], seam)
	end
	-- A side room with a door to lock, in a wing (never the part open from
	-- the start), the first wing by preference, not one of its hiding spots
	-- by preference.
	local candidates = {}
	for _, id in ctx.ids do
		local seams = doorways[id] or {}
		local seam = seams[1]
		local room = ctx.byId[id]
		local template = ctx.templatesById[room.template]
		if
			#seams == 1
			and not seam.arch
			and not busy[id]
			and not ctx.corridor[id]
			and room.kind ~= "stair"
			and not room.tall
			and not room.lantern
			and plan.locks[seam.id] == nil
			and plan.roomRegion[seam.a] == plan.roomRegion[seam.b]
			and plan.roomRegion[id] ~= 0
			and template ~= nil
		then
			local weight = (opts.Templates or {})[template.id] or opts.OtherWeight or 0.3
			if position[plan.roomRegion[id]] <= 1 then
				weight *= opts.EarlyBonus or 1
			end
			if ctx.offers[id].hides > 0 then
				weight *= 0.3
			end
			table.insert(candidates, { id = id, seam = seam, weight = weight })
		end
	end
	if #candidates == 0 then
		return
	end
	local pick = rng:WeightedPick(candidates, function(c)
		return c.weight
	end)
	-- Its fuse box: the house's, else one in a service room of its own.
	local puzzleId = nil
	for id, puzzle in plan.puzzles do
		if puzzle.kind == "breaker" then
			puzzleId = id
		end
	end
	if not puzzleId then
		if plan.stats.puzzles >= cfg.MaxPuzzles then
			return
		end
		local rooms = {}
		for _, id in ctx.ids do
			local shut = plan.pockets and plan.pockets[id]
			if id ~= pick.id and id ~= ctx.dining and not shut and LockPlanner.Where.service(ctx, id) then
				table.insert(rooms, id)
			end
		end
		if #rooms == 0 then
			return
		end
		puzzleId = "breaker:1"
		plan.puzzles[puzzleId] =
			{ kind = "breaker", room = stationRoom(ctx, rng, rooms), seed = rng:NextInteger(1, 2 ^ 30) }
		plan.stats.puzzles += 1
	end
	local region = plan.roomRegion[pick.id]
	plan.tokens["power:safe"] = {
		kind = "power",
		opens = pick.seam.id,
		label = "the safe room's power",
		producer = { kind = "puzzle", id = puzzleId },
		optional = true,
	}
	plan.locks[pick.seam.id] = {
		kind = "power",
		needs = { "power:safe" },
		region = region,
		inside = pick.id,
		optional = true,
		vault = true,
	}
	-- (Which floor's plans it may hold is the run's to say: the one the
	-- house's own plans don't show, Services/SafeRoomService.)
	-- (A doorway with no door gets one, once this plan is the one kept.)
	plan.safeRoom = { room = pick.id, seam = pick.seam.id, puzzle = puzzleId, addDoor = not pick.seam.door or nil }
	plan.stats.safeRooms = 1
end

-- When a room can first be reached: its region's place in the order, or, for
-- a pocket, when the house key that opens it is found. Leads and notes go
-- only where the squad can already get.
function LockPlanner.stageOf(plan, room: number): number
	local position = { [0] = 0 }
	for i, r in plan.order do
		position[r] = i
	end
	local stage = position[plan.roomRegion[room]] or math.huge
	-- (The safe room is optional: nothing points into it.)
	if plan.safeRoom and plan.safeRoom.room == room then
		return math.huge
	end
	local pocket = plan.pockets and plan.pockets[room]
	if pocket then
		local key = plan.tokens[pocket.opener]
		local keyRoom = key and LockPlanner.tokenRoom(plan, key)
		stage = math.max(stage, keyRoom and position[plan.roomRegion[keyRoom]] or stage) + 0.5
	end
	return stage
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
	-- Marks (docs/plans/level-design.md section 11): every door that takes
	-- something found gets its own, drawn from a fork of their own so nothing
	-- else about the plan changes.
	local marks = rng:Fork("marks"):Shuffle(table.clone(Marks.Ids))
	local marked = 0
	local toolKinds = 0 -- tool kinds the house's tool locks use so far
	-- The regions that must be open before each one can be (its door's side
	-- and wherever what opens it lies, and theirs in turn).
	local behind = { [0] = {} }
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
		local outer = inside == gate.a and gate.b or gate.a
		regions[r].gate = gate.id
		-- What opens it, made somewhere already open (the region just before by
		-- preference; as the wings planned it), and never before the door can
		-- be seen: lock first (docs/plans/level-design.md section 11), so
		-- whoever finds it already knows a door it might fit. A key kept beside
		-- a backtrack's bolted door, with its real door in a wing not yet open,
		-- left a playtest stuck holding a key for a door nobody had seen. Only
		-- regions that can't open before the door's own do (not merely later
		-- in this order: a squad may open wings in another).
		local doorRegion = roomRegion[outer]
		local function seen(region: number): boolean
			return position[region] < index and (region == doorRegion or behind[region][doorRegion] == true)
		end
		local afterDoor = {}
		for _, id in ctx.ids do
			if seen(roomRegion[id]) then
				table.insert(afterDoor, id)
			end
		end
		local nearRooms, walk
		if wings then
			local keyRegion = wings.keyRegion[r]
			nearRooms = (keyRegion and seen(keyRegion)) and regions[keyRegion].rooms or afterDoor
			-- Walking studs from the door, over what's open by now.
			walk = ctx.walker(outer, function(seam)
				return seam.connected == true
					and position[roomRegion[seam.a]] < index
					and position[roomRegion[seam.b]] < index
			end)
		else
			nearRooms = (rng:Chance(cfg.NearProducer) and seen(previous)) and regions[previous].rooms or afterDoor
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
							-- Lock first: a puzzle that could only stand where its door
							-- can't be seen yet is drawn less (its code or power is for
							-- a door nobody knows; the mark still tells them later).
							local anySeen = false
							for _, id in rooms do
								anySeen = anySeen or seen(roomRegion[id])
							end
							if not anySeen then
								weight *= cfg.UnseenStation or 1
							end
							table.insert(options, { gate = kind, weight = weight, rooms = rooms })
						end
					end
				elseif kind.tool then
					-- A tool lock: a mansion's, and no more tool kinds than the
					-- squad's house has (its tool may already be in the house).
					local fresh = plan.tokens["tool:" .. kind.tool] == nil
					if ctx.mansion and (not fresh or toolKinds < (cfg.MaxTools or 2)) then
						table.insert(options, { gate = kind, weight = weight })
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
		local mark = nil
		if kind.token then
			marked += 1
			mark = marks[(marked - 1) % #marks + 1]
		end
		local markName = mark and Marks.ById[mark].name or "plain"
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
					n == 1 and nearRooms or afterDoor,
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
					mark = mark,
					label = LockPlanner.label(kind.id, markName, kind.count),
					producer = { kind = "container", room = room },
				}
				table.insert(needs, token)
			end
		elseif kind.tool then
			-- The tool (section 11, L3.3): found before the first door it opens
			-- (lock first, like a key), then carried to every later one.
			local token = "tool:" .. kind.tool
			local existing = plan.tokens[token]
			if existing then
				existing.also = existing.also or {}
				table.insert(existing.also, gate.id)
			else
				local room = keepingRoom(ctx, rng, nearRooms, nil, nil, walk, wings and wings.keyStuds)
				ctx.kept[room] = true
				toolKinds += 1
				plan.tokens[token] = {
					kind = "tool",
					tool = kind.tool,
					opens = gate.id,
					label = kind.label(),
					producer = { kind = "container", room = room },
				}
			end
			needs = { token }
		elseif kind.token then
			counts[kind.token] = (counts[kind.token] or 0) + 1
			local token = kind.token .. ":" .. counts[kind.token]
			local producer
			if kind.puzzle then
				local puzzleId = kind.puzzle .. ":1"
				-- Lock first for a puzzle too, where it has a choice.
				local suited = {}
				for _, id in choice.rooms do
					if seen(roomRegion[id]) then
						table.insert(suited, id)
					end
				end
				plan.puzzles[puzzleId] = {
					kind = kind.puzzle,
					room = stationRoom(ctx, rng, #suited > 0 and suited or choice.rooms),
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
				mark = mark,
				label = LockPlanner.label(kind.id, markName),
				producer = producer,
			}
			needs = { token }
		end
		plan.locks[gate.id] = {
			kind = kind.id,
			needs = needs,
			region = r,
			inside = inside,
			mark = mark,
			side = kind.side and outer or nil,
		}
		-- What must be open before this region can be.
		local before = table.clone(behind[doorRegion])
		before[doorRegion] = true
		for _, need in needs or {} do
			for _, room in LockPlanner.producerRooms(plan, plan.tokens[need]) do
				local t = roomRegion[room]
				before[t] = true
				for x in behind[t] do
					before[x] = true
				end
			end
		end
		behind[r] = before
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
	-- Steps inside the big wings, for three or four, then side rooms behind
	-- the house key in what's left (each its own fork: nothing else changes).
	addWingSteps(ctx, rng:Fork("steps"), plan, cfg, position)
	addPockets(ctx, rng:Fork("pockets"), plan, cfg, position)
	-- The safe room, an optional objective, in what's left (its own fork).
	addSafeRoom(ctx, rng:Fork("safe"), plan, cfg, position)
	return plan
end

-- Solving ---------------------------------------------------------------------------

-- Play the plan out: from the start, open what you can reach (bolts from
-- their side, gates with what you hold), pick up what you can reach, until
-- nothing changes. Returns { solvable, held, opened, gates (in the order they
-- opened), tableSet, out }.
function LockPlanner.solve(layout, plan, templatesById)
	return solveWith(context(layout, templatesById or {}, nil), plan)
end

function solveWith(ctx, plan)
	local opened, held, gates = {}, {}, {}
	local function open(seam)
		return plan.locks[seam.id] == nil or opened[seam.id] == true
	end
	local reachable = reach(ctx, ctx.start, open)
	local function made(token)
		-- Shut in furniture (a step: chained or nailed) until its tool is held.
		local piece = token.producer.piece and plan.pieces and plan.pieces[token.producer.piece]
		for _, need in piece and piece.needs or {} do
			if not held[need] then
				return false
			end
		end
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
		-- (A side room in an older region opens with a key found later: that's
		-- what it's for. The solver above proves it can be.)
		for _, need in not (lock.pocket or lock.optional) and lock.needs or {} do
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
	-- The plan kept: the safe room's doorway gets a door to lock, if it had
	-- none (so the builder and the walkers' graph both know of it).
	local function kept(plan)
		local safe = plan.safeRoom
		if safe and safe.addDoor and ctx.seamById[safe.seam] then
			ctx.seamById[safe.seam].door = true
		end
		return plan
	end
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
					return kept(plan)
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
					return kept(plan)
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
