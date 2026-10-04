-- The fairness contract (doc section 3). A layout is only used if every check
-- passes; otherwise the generator retries with the next seed.

local Graph = require(script.Parent.Graph)
local MansionHouse = require(script.Parent.MansionHouse)
local Props = require(script.Parent.Parent.Data.Props)
local RoomRects = require(script.Parent.RoomRects)

local LayoutValidator = {}

local function cellKey(x, z)
	return x .. "," .. z
end

-- Count hiding spots a layout's templates provide. A mansion's generated-size
-- rooms (corridors) declare theirs (`mansion.hides`: their closets).
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
			if layout.mode == "Mansion" and template.mansion and template.mansion.hides then
				total += template.mansion.hides
			end
		end
	end
	return total
end

local function porchOf(door, l: number)
	local x, z = RoomRects.doorPoint(door.dir, door.line, door.along)
	if door.dir == "N" then
		return { x = x - l, z = z - 2 * l, w = 2 * l, d = 2 * l }
	elseif door.dir == "S" then
		return { x = x - l, z = z, w = 2 * l, d = 2 * l }
	elseif door.dir == "E" then
		return { x = x, z = z - l, w = 2 * l, d = 2 * l }
	end
	return { x = x - 2 * l, z = z - l, w = 2 * l, d = 2 * l }
end
LayoutValidator.porchOf = porchOf

-- The mansion's geometry rules (docs/plans/mansion-generation.md, section 4).
local function mansionRules(layout, templatesById, config, fail, metrics)
	local house = MansionHouse.new(config, templatesById)
	local l = config.Lattice
	for _, room in layout.rooms do
		for _, value in { room.x, room.z, room.w, room.d } do
			if value % l ~= 0 then
				fail("room " .. room.id .. " is off the lattice")
			end
		end
		local template = templatesById[room.template]
		local m = template and template.mansion
		if m and m.size then
			local w, d = MansionHouse.footprint(m.size, room.rotation or 0)
			if room.w ~= w or room.d ~= d then
				fail("room " .. room.id .. " is not its template's size")
			end
		elseif room.w < config.MinShared or room.d < config.MinShared then
			fail("room " .. room.id .. " is too narrow")
		end
		if room.z + room.d > config.FrontLine then
			fail("room " .. room.id .. " is past the front line")
		end
		for _, floor in MansionHouse.floorsOf(room) do
			if not house.index[floor]:Free(room) then
				fail("room " .. room.id .. " overlaps another room")
			end
		end
		house:Insert(room)
	end
	for _, room in layout.rooms do
		if not room.tall and room.floor == 1 and not house.index[0]:Covers(room) then
			fail("upper room " .. room.id .. " is not over the ground floor")
		end
		if room.tall then
			for _, floor in { 0, 1 } do
				for _, id in house:Neighbours(room, floor) do
					if house.byId[id].tall then
						fail("tall rooms " .. room.id .. " and " .. id .. " touch")
					end
				end
			end
		end
	end

	-- Seams: exactly the walls that can hold a doorway, one per pair.
	local expected = {}
	for _, seam in house:AllSeams() do
		expected[MansionHouse.pairKey(seam.a, seam.b)] = seam
	end
	local seamByPair = {}
	local seamCount = {}
	for _, seam in layout.seams do
		local key = MansionHouse.pairKey(seam.a, seam.b)
		local want = expected[key]
		if seamByPair[key] then
			fail("two seams for " .. key)
		elseif want == nil then
			fail("seam " .. key .. " has no doorway-sized wall")
		elseif want.floor ~= seam.floor or want.line ~= seam.line or want.along ~= seam.along then
			fail("seam " .. key .. " is not where its wall is")
		end
		seamByPair[key] = seam
		seamCount[seam.a] = (seamCount[seam.a] or 0) + 1
		seamCount[seam.b] = (seamCount[seam.b] or 0) + 1
	end
	for key in expected do
		if not seamByPair[key] then
			fail("rooms " .. key .. " share a wall without a seam")
		end
	end
	for _, room in layout.rooms do
		if (seamCount[room.id] or 0) > house:MaxSeams(room) then
			fail("room " .. room.id .. " has too many seams")
		end
	end

	-- Doors only where a seam is, between zones that go together.
	local edgeSet = {}
	for _, edge in layout.edges do
		local key = MansionHouse.pairKey(edge[1], edge[2])
		local seam = seamByPair[key]
		edgeSet[key] = true
		if seam == nil then
			fail("doorway " .. key .. " has no seam")
		elseif
			not MansionHouse.zonesMayJoin(
				MansionHouse.zoneOf(house.byId[seam.a], seam.floor),
				MansionHouse.zoneOf(house.byId[seam.b], seam.floor)
			)
		then
			fail("doorway " .. key .. " joins zones that don't go together")
		end
	end
	for _, seam in layout.seams do
		if seam.connected ~= (edgeSet[MansionHouse.pairKey(seam.a, seam.b)] == true) then
			fail("seam " .. seam.id .. " disagrees with the doorways")
		end
	end

	-- Each floor is one piece by its own doorways, and every stairwell opens
	-- on both floors, so two stairs always make a loop between the floors.
	for _, floor in { 0, 1 } do
		local ids, edges = {}, {}
		for _, room in layout.rooms do
			if MansionHouse.onFloor(room, floor) then
				table.insert(ids, room.id)
			end
		end
		for _, seam in layout.seams do
			if seam.connected and seam.floor == floor then
				table.insert(edges, { seam.a, seam.b })
			end
		end
		if #ids > 0 and not Graph.isConnected(Graph.adjacency(ids, edges), ids) then
			fail(floor == 0 and "the ground floor is not one piece" or "the upper floor is not one piece")
		end
	end
	for _, room in layout.rooms do
		if room.kind == "stair" then
			local opens = {}
			for _, seam in layout.seams do
				if seam.connected and (seam.a == room.id or seam.b == room.id) then
					opens[seam.floor] = true
				end
			end
			if not (opens[0] and opens[1]) then
				fail("stairwell " .. room.id .. " doesn't open on both floors")
			end
		end
	end

	-- Front and exit doors: in their room's wall, clear of its corners, with a
	-- clear porch outside; the exit on the ground floor and never at the front.
	local function checkDoor(door, name: string)
		if door == nil then
			fail("no " .. name)
			return
		end
		if not house.index[0]:Free(porchOf(door, l)) then
			fail(name .. " porch is built over")
		end
		local room = house.byId[door.room]
		if room == nil then
			fail(name .. " has no room")
			return
		end
		local across = door.dir == "N" or door.dir == "S"
		local from = across and room.x or room.z
		local to = from + (across and room.w or room.d)
		local line = (door.dir == "N" and room.z)
			or (door.dir == "S" and room.z + room.d)
			or (door.dir == "W" and room.x)
			or room.x + room.w
		if door.line ~= line then
			fail(name .. " is not in its room's wall")
		end
		if door.along - from < config.DoorCornerClear or to - door.along < config.DoorCornerClear then
			fail(name .. " is too close to a corner")
		end
	end
	checkDoor(layout.frontDoor, "front door")
	checkDoor(layout.exitDoor, "exit door")
	local ids0 = {}
	for _, room in layout.rooms do
		table.insert(ids0, room.id)
	end
	local fromStart = Graph.bfs(Graph.adjacency(ids0, layout.edges), layout.start)
	if (fromStart[layout.exit] or 0) < config.MinExitRooms then
		fail(("the exit is only %s doorways from the hall"):format(tostring(fromStart[layout.exit])))
	end
	if layout.exitDoor then
		if layout.exitDoor.room ~= layout.exit or (layout.exitDoor.floor or 0) ~= 0 or layout.exitDoor.dir == "S" then
			fail("the exit door is not in the exit room's side or back wall")
		end
	end

	-- Chase loops long enough in studs, not just in rooms: small rooms make
	-- short loops.
	local ids = {}
	for _, room in layout.rooms do
		table.insert(ids, room.id)
	end
	local adj = Graph.adjacency(ids, layout.edges)
	local studLoops, longest = 0, 0
	for _, cycle in Graph.fundamentalCycles(adj, ids, layout.edges) do
		if #cycle >= config.LoopLength[1] and #cycle <= config.LoopLength[2] then
			local studs = MansionHouse.routeStuds(cycle, seamByPair, config, true)
			if studs >= config.MinLoopStuds then
				studLoops += 1
				longest = math.max(longest, studs)
			end
		end
	end
	metrics.studLoops = studLoops
	metrics.longestLoop = longest
	if studLoops < config.MinLoops then
		fail(("only %d loops of %d+ studs"):format(studLoops, config.MinLoopStuds))
	end
	if longest < config.LongLoopStuds then
		fail(("no loop of %d+ studs"):format(config.LongLoopStuds))
	end
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
	elseif layout.mode == "Mansion" then
		mansionRules(layout, templatesById, config, fail, metrics)
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
