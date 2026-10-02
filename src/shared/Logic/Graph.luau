-- Graph helpers over room graphs. Nodes are integer room ids, edges are
-- undirected { a, b } pairs. Everything returns deterministic orderings so
-- seeded generation stays reproducible.

local Graph = {}

function Graph.edgeKey(a: number, b: number): string
	if a > b then
		a, b = b, a
	end
	return a .. "-" .. b
end

-- Build sorted adjacency lists. nodes is a list of ids.
function Graph.adjacency(nodes: { number }, edges: { { number } }): { [number]: { number } }
	local adj = {}
	for _, id in nodes do
		adj[id] = {}
	end
	for _, edge in edges do
		local a, b = edge[1], edge[2]
		if adj[a] and adj[b] and not table.find(adj[a], b) then
			table.insert(adj[a], b)
			table.insert(adj[b], a)
		end
	end
	for _, list in adj do
		table.sort(list)
	end
	return adj
end

-- Breadth-first distances from start. skipA/skipB optionally remove one edge.
function Graph.bfs(adj, start: number, skipA: number?, skipB: number?)
	local dist = { [start] = 0 }
	local parent = {}
	local queue = { start }
	local head = 1
	while head <= #queue do
		local node = queue[head]
		head += 1
		for _, nextNode in adj[node] do
			local skipped = (node == skipA and nextNode == skipB) or (node == skipB and nextNode == skipA)
			if not skipped and dist[nextNode] == nil then
				dist[nextNode] = dist[node] + 1
				parent[nextNode] = node
				table.insert(queue, nextNode)
			end
		end
	end
	return dist, parent
end

-- Shortest node path from a to b inclusive, or nil if unreachable.
function Graph.path(adj, a: number, b: number): { number }?
	if a == b then
		return { a }
	end
	local dist, parent = Graph.bfs(adj, a)
	if dist[b] == nil then
		return nil
	end
	local path = { b }
	local node = b
	while node ~= a do
		node = parent[node]
		table.insert(path, 1, node)
	end
	return path
end

function Graph.isConnected(adj, nodes: { number }): boolean
	if #nodes == 0 then
		return true
	end
	local dist = Graph.bfs(adj, nodes[1])
	for _, id in nodes do
		if dist[id] == nil then
			return false
		end
	end
	return true
end

-- Length (in rooms) of the shortest cycle that uses edge a-b, or nil if the
-- edge is a bridge.
function Graph.cycleThroughEdge(adj, a: number, b: number): number?
	local dist = Graph.bfs(adj, a, a, b)
	if dist[b] == nil then
		return nil
	end
	return dist[b] + 1
end

-- Shortest cycle length in the whole graph (its girth), or nil if acyclic.
function Graph.girth(adj, edges): number?
	local best = nil
	for _, edge in edges do
		local length = Graph.cycleThroughEdge(adj, edge[1], edge[2])
		if length and (best == nil or length < best) then
			best = length
		end
	end
	return best
end

-- Set of nodes that lie on at least one cycle.
function Graph.cycleNodes(adj, edges): { [number]: boolean }
	local result = {}
	for _, edge in edges do
		if Graph.cycleThroughEdge(adj, edge[1], edge[2]) then
			result[edge[1]] = true
			result[edge[2]] = true
		end
	end
	return result
end

-- For every node, the distance to the nearest node on a cycle. Nodes in a
-- tree hanging off a loop get their depth into the dead end; loop nodes get 0.
-- Returns depths and the deepest value. With no cycles at all every node is
-- treated as maximally deep.
function Graph.deadEndDepths(adj, nodes: { number }, edges)
	local onCycle = Graph.cycleNodes(adj, edges)
	local depths = {}
	local queue = {}
	for _, id in nodes do
		if onCycle[id] then
			depths[id] = 0
			table.insert(queue, id)
		end
	end
	if #queue == 0 then
		for _, id in nodes do
			depths[id] = math.huge
		end
		return depths, math.huge
	end
	local head = 1
	while head <= #queue do
		local node = queue[head]
		head += 1
		for _, nextNode in adj[node] do
			if depths[nextNode] == nil then
				depths[nextNode] = depths[node] + 1
				table.insert(queue, nextNode)
			end
		end
	end
	local deepest = 0
	for _, id in nodes do
		deepest = math.max(deepest, depths[id] or math.huge)
	end
	return depths, deepest
end

-- Weighted shortest path (Dijkstra) where cost(a, b) returns the cost of
-- stepping from a to b, or nil if the step is not allowed. Used by the
-- stalker's strategic layer so it can prefer or avoid routes.
function Graph.weightedPath(adj, a: number, b: number, cost: (number, number) -> number?): { number }?
	local dist = { [a] = 0 }
	local parent = {}
	local visited = {}
	while true do
		local best, bestDist = nil, math.huge
		for node, d in dist do
			if not visited[node] and (d < bestDist or (d == bestDist and best ~= nil and node < best)) then
				best, bestDist = node, d
			end
		end
		if best == nil then
			return nil
		end
		if best == b then
			break
		end
		visited[best] = true
		for _, nextNode in adj[best] do
			if not visited[nextNode] then
				local stepCost = cost(best, nextNode)
				if stepCost then
					local candidate = bestDist + stepCost
					if dist[nextNode] == nil or candidate < dist[nextNode] then
						dist[nextNode] = candidate
						parent[nextNode] = best
					end
				end
			end
		end
	end
	local path = { b }
	local node = b
	while node ~= a do
		node = parent[node]
		table.insert(path, 1, node)
	end
	return path
end

-- All simple cycles found by closing each non-tree edge of a BFS tree with
-- the tree path. Not a full cycle basis algorithm, but stable and plenty for
-- "which loop does the squad keep running".
function Graph.fundamentalCycles(adj, nodes: { number }, edges): { { number } }
	if #nodes == 0 then
		return {}
	end
	local _, parent = Graph.bfs(adj, nodes[1])
	local treeEdges = {}
	for child, par in parent do
		treeEdges[Graph.edgeKey(child, par)] = true
	end
	local cycles = {}
	for _, edge in edges do
		local a, b = edge[1], edge[2]
		if not treeEdges[Graph.edgeKey(a, b)] then
			-- path a -> root and b -> root, joined at the lowest common ancestor
			local ancestorsOfA = {}
			local node = a
			local chainA = { a }
			ancestorsOfA[a] = 1
			while parent[node] do
				node = parent[node]
				table.insert(chainA, node)
				ancestorsOfA[node] = #chainA
			end
			local chainB = { b }
			node = b
			while ancestorsOfA[node] == nil and parent[node] do
				node = parent[node]
				table.insert(chainB, node)
			end
			local meet = node
			local cycle = {}
			for i = 1, ancestorsOfA[meet] do
				table.insert(cycle, chainA[i])
			end
			for i = #chainB - 1, 1, -1 do
				table.insert(cycle, chainB[i])
			end
			table.insert(cycles, cycle)
		end
	end
	return cycles
end

return Graph
