-- The fairness contract (doc section 3). A layout is only used if every check
-- passes; otherwise the generator retries with the next seed.

local Graph = require(script.Parent.Graph)
local Props = require(script.Parent.Parent.Data.Props)

local LayoutValidator = {}

local function cellKey(x, z)
	return x .. "," .. z
end

-- Count hiding spots a layout's templates provide.
function LayoutValidator.hidingSpots(layout, templatesById): number
	local total = 0
	for _, room in layout.rooms do
		local template = templatesById[room.template]
		if template then
			for _, prop in template.props do
				local kind = Props.Kinds[prop.kind]
				if kind and kind.hide then
					total += 1
				end
			end
		end
	end
	return total
end

-- Returns ok, problems, metrics.
function LayoutValidator.validate(layout, templates, config)
	local templatesById = {}
	for _, template in templates do
		templatesById[template.id] = template
	end

	local problems = {}
	local function fail(message)
		table.insert(problems, message)
	end

	local ids = {}
	for _, room in layout.rooms do
		table.insert(ids, room.id)
	end
	local adj = Graph.adjacency(ids, layout.edges)
	local roomCount = #ids
	local metrics = { rooms = roomCount, edges = #layout.edges }

	if roomCount < config.RoomCount[1] or roomCount > config.RoomCount[2] then
		if not layout.fallback then
			fail(("room count %d outside %d-%d"):format(roomCount, config.RoomCount[1], config.RoomCount[2]))
		end
	end

	-- A true route exists between all rooms (divergent geometry is never in
	-- layout.edges, so this is the real graph).
	if not Graph.isConnected(adj, ids) then
		fail("not every room is reachable")
	end

	-- At least two loops, the shortest four or more rooms.
	local independentLoops = #layout.edges - roomCount + 1
	metrics.independentLoops = independentLoops
	if independentLoops < config.MinLoops then
		fail(("only %d independent loops"):format(independentLoops))
	end
	local girth = Graph.girth(adj, layout.edges)
	metrics.girth = girth
	if girth == nil or girth < config.LoopLength[1] then
		fail("shortest loop is too short: " .. tostring(girth))
	end
	local chaseLoops = 0
	for _, cycle in Graph.fundamentalCycles(adj, ids, layout.edges) do
		local length = Graph.cycleThroughEdge(adj, cycle[1], cycle[#cycle])
		if length and length >= config.LoopLength[1] and length <= config.LoopLength[2] then
			chaseLoops += 1
		end
	end
	metrics.chaseLoops = chaseLoops
	if chaseLoops < config.MinLoops then
		fail(("only %d loops of %d-%d rooms"):format(chaseLoops, config.LoopLength[1], config.LoopLength[2]))
	end

	-- No room is more than MaxDeadEndChain rooms from a loop.
	local _, deepest = Graph.deadEndDepths(adj, ids, layout.edges)
	metrics.deadEndDepth = deepest
	if deepest > config.MaxDeadEndChain then
		fail(("dead end %s rooms deep"):format(tostring(deepest)))
	end

	-- Roughly one hiding spot per two rooms.
	local spots = LayoutValidator.hidingSpots(layout, templatesById)
	metrics.hidingSpots = spots
	if spots < math.ceil(roomCount / 2) then
		fail(("only %d hiding spots for %d rooms"):format(spots, roomCount))
	end

	-- Roles.
	for _, room in layout.rooms do
		if not templatesById[room.template] then
			fail("room " .. room.id .. " has no template")
		end
	end
	if not layout.exit or layout.exit == layout.start then
		fail("no exit room")
	else
		local exitRoom
		for _, room in layout.rooms do
			if room.id == layout.exit then
				exitRoom = room
			end
		end
		local outer = false
		for _, offset in { { 0, -1 }, { 1, 0 }, { 0, 1 }, { -1, 0 } } do
			if not layout.cells[cellKey(exitRoom.gx + offset[1], exitRoom.gz + offset[2])] then
				outer = true
			end
		end
		if not outer then
			fail("exit room has no outside wall")
		end
	end
	if not layout.deliberation then
		fail("no room for the Deliberation Table")
	elseif layout.exit then
		local fromStart = Graph.bfs(adj, layout.start)
		local fromExit = Graph.bfs(adj, layout.exit)
		local d = layout.deliberation
		if (fromStart[d] or math.huge) + (fromExit[d] or math.huge) ~= fromStart[layout.exit] then
			fail("Deliberation Table is not on the critical path")
		end
	end
	if #layout.lanterns < 1 then
		fail("no Lantern room")
	end

	return #problems == 0, problems, metrics
end

return LayoutValidator
