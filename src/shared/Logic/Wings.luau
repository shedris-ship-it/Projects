-- Plan the adventure, then lay the doors to make it happen (docs/plans/
-- level-design.md section 5.3). Rooms are packed first (Logic/MansionGen);
-- which shared walls become doorways, and so the loops, the wings and the
-- shortcuts, is then decided here, before the planner (Logic/LockPlanner)
-- says what each lock is:
--
--   wings      region 0 is the hall, the dining room and a loop through one
--              of them to run round, about a third of the house; the other
--              regions are branches of
--              the tree of doors that joined every room, cut where a wing
--              naturally starts (a corridor's mouth, a stairwell, the kitchen
--              door, a change of floor), 3-7 rooms each; the cellar and the
--              attic are always a wing each of their own (owner, 2026-10-05:
--              "so they can be more important for progression")
--   the order  a region opens after the one its door is in; for a squad of
--              three or four, two wings off the same region open one after
--              the other with both keys kept before them (split up)
--   beats      a loop inside each wing; a shortcut, a doorway from the wing's
--              far end back to somewhere open before it that saves the most
--              walking to the table; sometimes the backtrack: the wing's way
--              in is from another region opened before it, and the obvious
--              door is bolted from the far side
--
-- Every doorway it adds goes through the generator's own `accept` (the table
-- stays on a shortest path, a loop is long enough), so the fairness
-- contract holds. Pure; the result goes in `layout.wings`, a nested table.

local Graph = require(script.Parent.Graph)
local MansionHouse = require(script.Parent.MansionHouse)

local Wings = {}

local pairKey = MansionHouse.pairKey

-- The tree of doors the house was joined by, from the hall: parent and
-- children, breadth-first order, subtree sizes and entry/exit times (for
-- "is this room under that one"). `groups` ({ [room id] = name }) are
-- rooms that must hang together as one branch with nothing else below them
-- (the cellar, the attic): entered once, by the first door reached, and
-- never the way on to a room outside them.
function Wings.tree(ids: { number }, edges, root: number, groups: { [number]: string }?)
	local adj = Graph.adjacency(ids, edges)
	groups = groups or {}
	local parent, children, order = {}, {}, { root }
	local seen = { [root] = true }
	local entered = {}
	local head = 1
	while head <= #order do
		local node = order[head]
		head += 1
		children[node] = {}
		local mine = groups[node]
		for _, nextNode in adj[node] do
			local theirs = groups[nextNode]
			local allowed
			if mine then
				allowed = theirs == mine
			else
				allowed = theirs == nil or not entered[theirs]
			end
			if allowed and not seen[nextNode] then
				seen[nextNode] = true
				if theirs and theirs ~= mine then
					entered[theirs] = true
				end
				parent[nextNode] = node
				table.insert(children[node], nextNode)
				table.insert(order, nextNode)
			end
		end
	end
	local size, tin, tout = {}, { [root] = 0 }, {}
	local clock = 0
	local stack = { { root, 1 } }
	while #stack > 0 do
		local top = stack[#stack]
		local node, i = top[1], top[2]
		local kids = children[node]
		if i <= #kids then
			top[2] = i + 1
			clock += 1
			tin[kids[i]] = clock
			table.insert(stack, { kids[i], 1 })
		else
			size[node] = 1
			for _, child in kids do
				size[node] += size[child]
			end
			tout[node] = clock
			table.remove(stack)
		end
	end
	return { root = root, parent = parent, children = children, order = order, size = size, tin = tin, tout = tout }
end

function Wings.isAncestor(tree, a: number, b: number): boolean
	return tree.tin[a] ~= nil and tree.tin[b] ~= nil and tree.tin[a] <= tree.tin[b] and tree.tin[b] <= tree.tout[a]
end

-- How naturally a wing starts at the door from `p` into `c`.
function Wings.natural(ctx, p: number, c: number): number
	local a, b = ctx.byId[p], ctx.byId[c]
	local seam = ctx.seamByPair[pairKey(p, c)]
	local floor = seam and seam.floor or 0
	local bonus = 0
	if b.corridor then
		bonus += 2 -- a corridor's mouth
	end
	if b.kind == "stair" then
		bonus += 2
	end
	if a.tall and floor ~= 0 then
		bonus += 1.5 -- off the gallery or a stair: another floor
	end
	if a.kind == "deliberation" and b.kind == "kitchen" then
		bonus += 2 -- the service wing behind the kitchen door
	end
	if MansionHouse.zoneOf(a, floor) ~= MansionHouse.zoneOf(b, floor) then
		bonus += 1
	end
	return bonus
end

-- Rooms one doorway apart, now: a door between them closes a loop this many
-- rooms long.
local function loopRooms(ctx, pair): number
	local adj = Graph.adjacency(ctx.ids, ctx.edges)
	local dist = Graph.bfs(adj, pair[1])[pair[2]]
	return dist and dist + 1 or math.huge
end

-- Whether a new doorway on this seam may go in: zones that may share a door,
-- a loop long enough in rooms and in studs, the table still on the way out.
-- `short` lets a loop be any length in studs (one that only rescues a dead
-- end: four rooms round is still somewhere to run).
local function mayAdd(ctx, seam, short: boolean?): boolean
	local pair = { seam.a, seam.b }
	if ctx.edgeSet[pairKey(seam.a, seam.b)] or not ctx.mayJoin(seam) then
		return false
	end
	if loopRooms(ctx, pair) < ctx.config.LoopLength[1] then
		return false
	end
	if short then
		return ctx.keepsTable(pair, ctx.edges)
	end
	return ctx.accept(pair, ctx.edges)
end

local function addDoor(ctx, seam)
	table.insert(ctx.edges, { seam.a, seam.b })
	ctx.edgeSet[pairKey(seam.a, seam.b)] = true
end

-- Loops region 0 could be built round: cycles through the hall or the dining
-- room over the doors there are and the ones that could be added, 4 rooms to
-- region 0's share of the house (CoreMax at least) and at least Stage0Loop
-- studs long; the smallest first (region 0 stays about a third of the
-- house), then the fewest new doorways. Each is { rooms, studs, missing =
-- { seams } }.
function Wings.coreLoops(ctx)
	local present = {}
	local edges = {}
	for _, edge in ctx.edges do
		present[pairKey(edge[1], edge[2])] = true
		table.insert(edges, edge)
	end
	for _, seam in ctx.seams do
		if not present[pairKey(seam.a, seam.b)] and ctx.mayJoin(seam) then
			table.insert(edges, { seam.a, seam.b })
		end
	end
	local adj = Graph.adjacency(ctx.ids, edges)
	local most = math.max(ctx.cfg.CoreMax, math.floor(#ctx.ids * ctx.cfg.R0Share[2]))
	local loops = {}
	for _, cycle in Graph.fundamentalCycles(adj, ctx.ids, edges) do
		local through = table.find(cycle, ctx.start) or table.find(cycle, ctx.dining)
		if through and #cycle >= ctx.config.LoopLength[1] and #cycle <= most then
			local studs = MansionHouse.routeStuds(cycle, ctx.seamByPair, ctx.config, true)
			if studs >= ctx.stage.Stage0Loop then
				local missing = {}
				for i, id in cycle do
					local nextId = cycle[i % #cycle + 1]
					if not present[pairKey(id, nextId)] then
						table.insert(missing, ctx.seamByPair[pairKey(id, nextId)])
					end
				end
				table.insert(loops, { rooms = cycle, studs = studs, missing = missing })
			end
		end
	end
	table.sort(loops, function(a, b)
		if #a.rooms ~= #b.rooms then
			return #a.rooms < #b.rooms
		end
		if #a.missing ~= #b.missing then
			return #a.missing < #b.missing
		end
		return a.studs > b.studs
	end)
	-- Only loops whose missing doorways can all go in (no loop of three, the
	-- table still on the way out), tried on the doors as they stand.
	local closable = {}
	for _, loop in loops do
		local added, ok = 0, true
		for _, seam in loop.missing do
			if
				ctx.edgeSet[pairKey(seam.a, seam.b)]
				or loopRooms(ctx, { seam.a, seam.b }) < ctx.config.LoopLength[1]
				or not ctx.keepsTable({ seam.a, seam.b }, ctx.edges)
			then
				ok = false
				break
			end
			addDoor(ctx, seam)
			added += 1
		end
		for _ = 1, added do
			local edge = table.remove(ctx.edges)
			ctx.edgeSet[pairKey(edge[1], edge[2])] = nil
		end
		if ok then
			table.insert(closable, loop)
		end
	end
	return closable
end

-- The rooms where each group (Wings.tree) hangs from the rest: the wings
-- every partition must cut, in tree order.
function Wings.groupRoots(tree, groups: { [number]: string }?): { number }
	local roots = {}
	for _, id in tree.order do
		local name = groups and groups[id]
		if name and tree.parent[id] and groups[tree.parent[id]] ~= name then
			table.insert(roots, id)
		end
	end
	return roots
end

-- Every way to cut `k` wings from the tree, keeping the rooms in `keep` (the
-- core loop) in region 0, scored: wings of MinWing-MaxWing
-- rooms (a hard rule), region 0's share near its band, wings of even size,
-- natural boundaries. Best first, with a little jitter so seeds differ.
-- Each of `forced` (Wings.groupRoots: the cellar, the attic) is always a
-- wing of its own, whatever its size, and nothing inside it is cut.
function Wings.partitions(ctx, tree, k: number, keep: { number }?, forced: { number }?)
	local cfg = ctx.cfg
	local n = #tree.order
	forced = forced or {}
	if #forced > k then
		return {}
	end
	local inForced = {}
	for _, root in forced do
		inForced[root] = true
	end
	local function insideForced(c: number): boolean
		for _, root in forced do
			if Wings.isAncestor(tree, root, c) then
				return true
			end
		end
		return false
	end
	local candidates = {}
	for _, c in tree.order do
		local keeps = false
		for _, id in keep or {} do
			keeps = keeps or Wings.isAncestor(tree, c, id)
		end
		if
			tree.parent[c]
			and not keeps
			and not Wings.isAncestor(tree, c, ctx.dining)
			and tree.size[c] >= cfg.MinWing
			and not insideForced(c)
		then
			table.insert(candidates, c)
		end
	end
	table.sort(candidates, function(a, b)
		return tree.tin[a] < tree.tin[b]
	end)
	local lo, hi = cfg.R0Share[1], cfg.R0Share[2]
	local ideal = n * (1 - (lo + hi) / 2) / math.max(1, k)
	local results = {}
	local chosen = {}
	local combo = {}
	local function evaluate()
		-- The forced wings with the chosen ones, in tree order.
		table.clear(combo)
		for _, c in chosen do
			table.insert(combo, c)
		end
		for _, c in forced do
			table.insert(combo, c)
		end
		table.sort(combo, function(a, b)
			return tree.tin[a] < tree.tin[b]
		end)
		-- Each wing is its branch less the wings cut further down it.
		local sizes, stack = {}, {}
		for i, c in combo do
			while #stack > 0 and not Wings.isAncestor(tree, combo[stack[#stack]], c) do
				table.remove(stack)
			end
			sizes[i] = tree.size[c]
			if #stack > 0 then
				sizes[stack[#stack]] -= tree.size[c]
			end
			table.insert(stack, i)
		end
		local inWings = 0
		for i = 1, #combo do
			inWings += sizes[i]
		end
		for i = 1, #combo do
			if not inForced[combo[i]] and (sizes[i] < cfg.MinWing or sizes[i] > cfg.MaxWing) then
				return
			end
		end
		local share = (n - inWings) / n
		local score = 0
		for _, c in combo do
			score += Wings.natural(ctx, tree.parent[c], c)
		end
		for i = 1, #combo do
			if not inForced[combo[i]] then
				score -= math.abs(sizes[i] - ideal) * 0.5
			end
		end
		if share < lo then
			score -= (lo - share) * 80
		elseif share > hi then
			score -= (share - hi) * 80
		end
		table.insert(results, { cuts = table.clone(combo), sizes = sizes, share = share, score = score })
	end
	local function choose(from: number, left: number)
		if left == 0 then
			evaluate()
			return
		end
		for i = from, #candidates - left + 1 do
			table.insert(chosen, candidates[i])
			choose(i + 1, left - 1)
			table.remove(chosen)
		end
	end
	choose(1, k - #forced)
	for _, result in results do
		result.score += ctx.rng:NextNumber()
	end
	table.sort(results, function(a, b)
		if a.score ~= b.score then
			return a.score > b.score
		end
		for i = 1, math.min(#a.cuts, #b.cuts) do
			if a.cuts[i] ~= b.cuts[i] then
				return a.cuts[i] < b.cuts[i]
			end
		end
		return false
	end)
	return results
end

-- The longest loop (studs) inside a set of rooms over the doors so far.
local function longestLoop(ctx, inside: { [number]: boolean }): number
	local nodes, edges = {}, {}
	for id in inside do
		table.insert(nodes, id)
	end
	table.sort(nodes)
	for _, edge in ctx.edges do
		if inside[edge[1]] and inside[edge[2]] then
			table.insert(edges, edge)
		end
	end
	local longest = 0
	for _, cycle in Graph.fundamentalCycles(Graph.adjacency(nodes, edges), nodes, edges) do
		longest = math.max(longest, MansionHouse.routeStuds(cycle, ctx.seamByPair, ctx.config, true))
	end
	return longest
end

-- Lay one partition out: the regions, their order, gates and beats. Adds
-- the beats' doorways to ctx.edges. `core` is region 0's loop, its missing
-- doorways added first. Returns the wings, or nil if the core can't be
-- closed (a doorway would cut the table off the way out, or make a loop of
-- three).
function Wings.realise(ctx, tree, partition, core)
	local cfg, rng = ctx.cfg, ctx.rng
	for _, seam in core and core.missing or {} do
		if
			ctx.edgeSet[pairKey(seam.a, seam.b)]
			or loopRooms(ctx, { seam.a, seam.b }) < ctx.config.LoopLength[1]
			or not ctx.keepsTable({ seam.a, seam.b }, ctx.edges)
		then
			return nil
		end
		addDoor(ctx, seam)
	end
	local cuts = partition.cuts
	local k = #cuts
	local index = {}
	for i, c in cuts do
		index[c] = i
	end
	local roomRegion = {}
	for _, id in tree.order do
		roomRegion[id] = index[id] or (tree.parent[id] and roomRegion[tree.parent[id]]) or 0
	end
	local parentRegion = {}
	for i, c in cuts do
		parentRegion[i] = roomRegion[tree.parent[c]]
	end
	local regions = {}
	for r = 0, k do
		regions[r] = { rooms = {} }
	end
	for _, id in ctx.ids do
		table.insert(regions[roomRegion[id]].rooms, id)
	end

	-- The order: a region after the one its door is in; for a big squad, the
	-- second of two wings off the same region straight after the first.
	local parallel = (ctx.squad or 4) >= cfg.ParallelFrom
	local order, opened, position = {}, { [0] = true }, { [0] = 0 }
	while #order < k do
		local available = {}
		for r = 1, k do
			if not opened[r] and opened[parentRegion[r]] then
				table.insert(available, r)
			end
		end
		local pick = nil
		local last = order[#order]
		if parallel and last then
			local siblings = {}
			for _, r in available do
				if parentRegion[r] == parentRegion[last] then
					table.insert(siblings, r)
				end
			end
			if #siblings > 0 and rng:Chance(0.8) then
				pick = rng:Pick(siblings)
			end
		end
		pick = pick or rng:Pick(available)
		table.insert(order, pick)
		opened[pick] = true
		position[pick] = #order
	end

	local gates, keyRegion, beats = {}, {}, { [0] = { core = core and #core.rooms or nil } }
	for i, r in order do
		beats[r] = {}
		gates[r] = ctx.seamByPair[pairKey(tree.parent[cuts[r]], cuts[r])].id
		local previous = order[i - 1]
		if i == 1 then
			keyRegion[r] = 0
		elseif parallel and parentRegion[r] == parentRegion[previous] then
			-- Both keys before either door: one group each way.
			keyRegion[r] = parentRegion[r]
			beats[r].parallel = true
		elseif rng:Chance(cfg.NearKey) then
			keyRegion[r] = previous
		end
	end

	-- The backtrack: the way in is from another region opened before it, and
	-- the door from the region beside it is bolted from the far side (you
	-- find it shut early, and come round another way).
	for i, r in order do
		if i >= 2 and rng:Chance(cfg.BacktrackChance) then
			local options = {}
			for _, seam in ctx.seams do
				local ra, rb = roomRegion[seam.a], roomRegion[seam.b]
				local other = (ra == r and rb) or (rb == r and ra) or nil
				if other and other ~= r and other ~= parentRegion[r] and position[other] < position[r] then
					if ctx.edgeSet[pairKey(seam.a, seam.b)] then
						table.insert(options, { seam = seam, weight = 3 })
					elseif mayAdd(ctx, seam) then
						table.insert(options, { seam = seam, weight = 1 })
					end
				end
			end
			if #options > 0 then
				local choice = rng:WeightedPick(options, function(o)
					return o.weight
				end)
				if not ctx.edgeSet[pairKey(choice.seam.a, choice.seam.b)] then
					addDoor(ctx, choice.seam)
				end
				gates[r] = choice.seam.id
				-- Found bolted from the region beside it: its key lies there.
				keyRegion[r] = parentRegion[r]
				beats[r].backtrack = true
				beats[r].parallel = nil
			end
		end
	end

	-- A loop in every region big enough for one (region 0's long enough to
	-- run round, as LockPlanner.checkShape asks).
	for r = 0, k do
		local inside = {}
		for _, id in regions[r].rooms do
			inside[id] = true
		end
		local want = r == 0 and ctx.stage.Stage0Loop or ctx.config.MinLoopStuds
		if #regions[r].rooms >= ctx.config.LoopLength[1] and longestLoop(ctx, inside) < want then
			local best, bestScore = nil, -math.huge
			for _, seam in ctx.seams do
				if inside[seam.a] and inside[seam.b] and mayAdd(ctx, seam) then
					addDoor(ctx, seam)
					local studs = longestLoop(ctx, inside)
					table.remove(ctx.edges)
					ctx.edgeSet[pairKey(seam.a, seam.b)] = nil
					if studs >= want then
						local score = -math.abs(studs - want * 1.8) + rng:NextNumber() * 20
						if score > bestScore then
							best, bestScore = seam, score
						end
					end
				end
			end
			if best then
				addDoor(ctx, best)
				beats[r].loop = best.id
			end
		end
	end

	-- The shortcut: from the wing's far end back to somewhere open before it,
	-- the doorway that saves the most walking to the table, if it saves
	-- enough. A bolt the house already has may be it.
	for _, r in order do
		local function passable(extra)
			return function(seam): boolean
				if not ctx.edgeSet[pairKey(seam.a, seam.b)] then
					return false
				end
				local ra, rb = roomRegion[seam.a], roomRegion[seam.b]
				if position[ra] > position[r] or position[rb] > position[r] then
					return false
				end
				-- Into this wing only by its gate (or the doorway being weighed).
				if (ra == r) ~= (rb == r) then
					return seam.id == gates[r] or seam.id == extra
				end
				return true
			end
		end
		local closed = ctx.walk(ctx.dining, passable(nil))
		local far, farStuds = nil, -1
		for _, id in regions[r].rooms do
			local d = closed[id]
			if d and d > farStuds then
				far, farStuds = id, d
			end
		end
		if far then
			-- A wing with no loop of its own, deeper than a dead end may be,
			-- takes the best way home whatever it saves.
			local inside = {}
			for _, id in regions[r].rooms do
				inside[id] = true
			end
			local needed = #regions[r].rooms > ctx.stage.MaxDeadEnd and longestLoop(ctx, inside) == 0
			local threshold = needed and 0.001 or cfg.ShortcutStuds
			local best, bestSaving, existing = nil, 0, false
			for _, seam in ctx.seams do
				local ra, rb = roomRegion[seam.a], roomRegion[seam.b]
				local other = (ra == r and rb) or (rb == r and ra) or nil
				if other and other ~= r and position[other] < position[r] and seam.id ~= gates[r] then
					local present = ctx.edgeSet[pairKey(seam.a, seam.b)] == true
					if present or mayAdd(ctx, seam) then
						if not present then
							addDoor(ctx, seam)
						end
						local d = ctx.walk(ctx.dining, passable(seam.id))[far]
						if not present then
							table.remove(ctx.edges)
							ctx.edgeSet[pairKey(seam.a, seam.b)] = nil
						end
						local saving = d and farStuds - d or 0
						-- A doorway already there is worth a little more: no new hole.
						local score = saving + (present and 10 or 0)
						if saving >= threshold and score > bestSaving then
							best, bestSaving, existing = seam, score, present
						end
					end
				end
			end
			if best then
				if not existing then
					addDoor(ctx, best)
				end
				beats[r].shortcut = best.id
			end
		end
	end

	-- No stage leaves a dead end deeper than the planner allows (its
	-- checkShape): a doorway from the deepest room to one that closes a loop,
	-- inside its own wing where it can be.
	local opened = {}
	local stages = { 0 }
	for _, r in order do
		table.insert(stages, r)
	end
	local patched = 0
	for _, s in stages do
		for _, id in regions[s].rooms do
			opened[id] = true
		end
		for _ = 1, 4 do
			local nodes, edges = {}, {}
			for _, id in ctx.ids do
				if opened[id] then
					table.insert(nodes, id)
				end
			end
			for _, edge in ctx.edges do
				if opened[edge[1]] and opened[edge[2]] then
					table.insert(edges, edge)
				end
			end
			local depths, deepest = Graph.deadEndDepths(Graph.adjacency(nodes, edges), nodes, edges)
			if deepest <= ctx.stage.MaxDeadEnd then
				break
			end
			local best, bestScore = nil, -math.huge
			for _, seam in ctx.seams do
				if opened[seam.a] and opened[seam.b] and mayAdd(ctx, seam, true) then
					local depth = math.max(depths[seam.a] or 0, depths[seam.b] or 0)
					local score = math.min(depth, 9) * 3
						+ (roomRegion[seam.a] == roomRegion[seam.b] and 2 or 0)
						+ rng:NextNumber()
					if depth > 0 and score > bestScore then
						best, bestScore = seam, score
					end
				end
			end
			if not best then
				break
			end
			addDoor(ctx, best)
			patched += 1
		end
	end

	local stats = { backtracks = 0, parallel = 0, loops = 0, shortcuts = 0, patched = patched }
	for _, r in order do
		local beat = beats[r]
		stats.backtracks += beat.backtrack and 1 or 0
		stats.parallel += beat.parallel and 1 or 0
		stats.shortcuts += beat.shortcut and 1 or 0
	end
	for r = 0, k do
		stats.loops += beats[r] and beats[r].loop and 1 or 0
	end
	for r = 1, k do
		regions[r].gate = gates[r]
	end
	return {
		regions = regions,
		roomRegion = roomRegion,
		order = order,
		gates = gates,
		keyRegion = keyRegion,
		beats = beats,
		keyStuds = cfg.KeyStuds,
		stats = stats,
	}
end

-- A plan with only the wings' shape (gates and bolts, nothing behind them),
-- for LockPlanner.checkShape.
function Wings.skeleton(wings, seams)
	local position = { [0] = 0 }
	for i, r in wings.order do
		position[r] = i
	end
	local locks = {}
	for _, r in wings.order do
		for _, seam in seams do
			if seam.connected then
				local ra, rb = wings.roomRegion[seam.a], wings.roomRegion[seam.b]
				local other = (ra == r and rb) or (rb == r and ra) or nil
				if other and other ~= r and position[other] < position[r] then
					local inside = ra == r and seam.a or seam.b
					if seam.id == wings.gates[r] then
						locks[seam.id] = { kind = "key", region = r, inside = inside }
					else
						locks[seam.id] = { kind = "bolt", side = inside, region = r }
					end
				end
			end
		end
	end
	return { regions = wings.regions, roomRegion = wings.roomRegion, order = wings.order, locks = locks }
end

return Wings
