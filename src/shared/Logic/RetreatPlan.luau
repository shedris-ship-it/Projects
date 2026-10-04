-- Where The Guest backs away to (docs/plans/mansion-generation.md, M3; owner
-- 2026-10-04: "when the guest retreats he commonly backs up into a wall ... I
-- want him to feel smart and aware"). He weighs every point of the house he
-- could reach within his back-away budget (Logic/NavGraph): how far everyone
-- would have to walk to reach it, whether he'd get there first, whether it's
-- a dead end, and whether the way there passes someone. Nothing better than
-- where he stands means he's cornered: he holds your stare instead of
-- grinding into a wall. Pure.

local NavGraph = require(script.Parent.NavGraph)

local RetreatPlan = {}

RetreatPlan.Weights = {
	Safety = 1, -- per stud the nearest player would walk to reach the spot
	SafetyCap = 60, -- beyond this, further makes no difference
	Lead = 0.5, -- per stud he'd arrive ahead of them
	LeadCap = 30,
	DeadEnd = 14, -- a room with one doorway (a stairwell doesn't count: it climbs)
	Toward = 18, -- his first step heads towards a player (per unit of cosine)
	Walk = 0.15, -- per stud he walks
	PassClear = 5, -- a way that passes closer than this to anyone isn't a way out
	Cornered = 4, -- the best spot must beat standing still by this much
}

-- The node a route to `node` starts from (one of the searched sources).
local function firstNode(parent, node: number): number
	while parent[node] do
		node = parent[node]
	end
	return node
end

-- How many open doorways each room has.
function RetreatPlan.doorways(graph)
	local count = {}
	for _, seam in graph.seams do
		if seam.connected then
			count[seam.a] = (count[seam.a] or 0) + 1
			count[seam.b] = (count[seam.b] or 0) + 1
		end
	end
	return count
end

-- me:      { point, room, dist, parent } (dist and parent from NavGraph.search
--          from him)
-- players: { { point, room, dist } } (dist from NavGraph.distancesFrom)
-- options: { budget (studs he may walk), doorways = RetreatPlan.doorways(graph) }
-- Returns { node, score, safety, here, cornered }, or nil if he can't move.
function RetreatPlan.choose(graph, me, players, options)
	local W = RetreatPlan.Weights
	local doorways = options.doorways or RetreatPlan.doorways(graph)
	local function safetyOf(node: number): number
		local best = W.SafetyCap
		for _, p in players do
			local d = p.dist[node]
			if d then
				best = math.min(best, d)
			end
		end
		return best
	end
	local here = W.SafetyCap
	for _, p in players do
		here = math.min(here, NavGraph.costAt(graph, p.dist, me.point, me.room))
	end
	-- The nearest player's direction, for "don't walk past them".
	local nearest, nearestDistance = nil, math.huge
	for _, p in players do
		local d = NavGraph.flatDistance(me.point, p.point)
		if d < nearestDistance then
			nearest, nearestDistance = p, d
		end
	end
	-- The closest anyone is to his way to a node (the way follows me.parent).
	local function nearestPlayer(node: number): number
		local best = math.huge
		for _, p in players do
			local d = p.dist[node]
			if d then
				best = math.min(best, d)
			end
		end
		return best
	end
	local pinch = {}
	local function pinchOf(node: number): number
		local known = pinch[node]
		if known then
			return known
		end
		local value = nearestPlayer(node)
		local up = me.parent[node]
		if up then
			value = math.min(value, pinchOf(up))
		end
		pinch[node] = value
		return value
	end
	local best = nil
	for node, walked in me.dist do
		local n = graph.nodes[node]
		-- Not a doorway, nor in front of a solid wall's seam (that's backing
		-- up against a wall, not getting away).
		local usable = n.kind ~= "doorway" and not (n.kind == "approach" and not graph.seams[n.seam].connected)
		if usable and walked > 1.5 and walked <= options.budget and pinchOf(node) >= W.PassClear then
			local safety = safetyOf(node)
			local lead = W.LeadCap
			for _, p in players do
				local d = p.dist[node]
				if d then
					lead = math.min(lead, d - walked)
				end
			end
			lead = math.clamp(lead, -W.LeadCap, W.LeadCap)
			local deadEnd = n.room ~= me.room and not graph.rooms[n.room].tall and (doorways[n.room] or 0) <= 1
			local toward = 0
			if nearest and nearestDistance > 0.1 then
				local first = graph.nodes[firstNode(me.parent, node)]
				local fx, fz = first.x - me.point.x, first.z - me.point.z
				local length = math.sqrt(fx * fx + fz * fz)
				if length > 0.1 then
					local px, pz = nearest.point.x - me.point.x, nearest.point.z - me.point.z
					toward = math.max(0, (fx * px + fz * pz) / (length * nearestDistance))
				end
			end
			local score = W.Safety * safety
				+ W.Lead * lead
				- (deadEnd and W.DeadEnd or 0)
				- W.Toward * toward
				- W.Walk * walked
			if
				best == nil
				or score > best.score + 1e-9
				or (math.abs(score - best.score) <= 1e-9 and node < best.node)
			then
				best = { node = node, score = score, safety = safety }
			end
		end
	end
	if not best then
		return nil
	end
	best.here = here
	best.cornered = best.safety < here + W.Cornered
	return best
end

return RetreatPlan
