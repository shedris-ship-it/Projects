-- The lobby mall's geometry rules (docs/plans/lobby-rework.md, "The place";
-- Data/Mall holds the layout, World/MallBuilder builds it). Engine-free:
-- rooms are rectangles on the floor plan, {x0, z0, x1, z1} in studs, x east
-- and z south; doors sit on the line two rooms share (or on a room's
-- outside wall) and cut both rooms' walls.

local MallLayout = {}

-- A room's four sides: which way the wall runs, the line it stands on, its
-- extent, and which way is into the room.
function MallLayout.sides(rect)
	local x0, z0, x1, z1 = rect[1], rect[2], rect[3], rect[4]
	return {
		{ side = "N", runs = "x", at = z0, from = x0, to = x1, inward = 1 },
		{ side = "S", runs = "x", at = z1, from = x0, to = x1, inward = -1 },
		{ side = "W", runs = "z", at = x0, from = z0, to = z1, inward = 1 },
		{ side = "E", runs = "z", at = x1, from = z0, to = z1, inward = -1 },
	}
end

local function same(a: number, b: number): boolean
	return math.abs(a - b) < 1e-3
end

-- The doors that cut one side of a room: those of this room that stand on
-- the side's line, run its way and overlap it, clipped to it, west or north
-- first.
function MallLayout.cutsFor(roomId: string, side, doors)
	local cuts = {}
	for _, door in doors do
		if (door.a == roomId or door.b == roomId) and door.runs == side.runs and same(door.at, side.at) then
			local from, to = math.max(door.from, side.from), math.min(door.to, side.to)
			if to > from then
				table.insert(cuts, { from = from, to = to, height = door.height, door = door })
			end
		end
	end
	table.sort(cuts, function(a, b)
		return a.from < b.from
	end)
	return cuts
end

-- A wall's pieces along a side, {from, to, bottom, top}: full height between
-- the cuts, and a lintel over each cut lower than the wall.
function MallLayout.segments(from: number, to: number, cuts, height: number)
	local pieces = {}
	local at = from
	for _, cut in cuts do
		if cut.from > at then
			table.insert(pieces, { from = at, to = cut.from, bottom = 0, top = height })
		end
		if cut.height < height then
			table.insert(pieces, { from = math.max(cut.from, at), to = cut.to, bottom = cut.height, top = height })
		end
		at = math.max(at, cut.to)
	end
	if to > at then
		table.insert(pieces, { from = at, to = to, bottom = 0, top = height })
	end
	return pieces
end

-- The middle of a door, on the floor plan.
function MallLayout.doorCentre(door): (number, number)
	local mid = (door.from + door.to) / 2
	if door.runs == "x" then
		return mid, door.at
	end
	return door.at, mid
end

local function onSide(rect, door): boolean
	for _, side in MallLayout.sides(rect) do
		if
			side.runs == door.runs
			and same(side.at, door.at)
			and door.from >= side.from - 1e-3
			and door.to <= side.to + 1e-3
		then
			return true
		end
	end
	return false
end

local function inside(rect, x: number, z: number): boolean
	return x > rect[1] and x < rect[3] and z > rect[2] and z < rect[4]
end

-- What's wrong with a layout, as sentences (none for a good one):
-- rooms that overlap, a door off its rooms' walls, a shopfront out of reach
-- of the fountain (`reach`, in studs), the spawn outside the court, a room
-- with no way in.
function MallLayout.check(mall, reach: number): { string }
	local problems = {}
	local ids = {}
	for id in mall.Rooms do
		table.insert(ids, id)
	end
	table.sort(ids)
	for i, a in ids do
		for j = i + 1, #ids do
			local b = ids[j]
			local ra, rb = mall.Rooms[a].rect, mall.Rooms[b].rect
			local w = math.min(ra[3], rb[3]) - math.max(ra[1], rb[1])
			local d = math.min(ra[4], rb[4]) - math.max(ra[2], rb[2])
			if w > 1e-3 and d > 1e-3 then
				table.insert(problems, string.format("%s and %s overlap", a, b))
			end
		end
	end
	local entered = {}
	for _, door in mall.Doors do
		for _, id in { door.a, door.b } do
			local room = id and mall.Rooms[id]
			if id and not room then
				table.insert(problems, "a door to an unknown room " .. tostring(id))
			elseif room and not onSide(room.rect, door) then
				table.insert(problems, string.format("a door of %s isn't on its wall", id))
			end
		end
		if door.a and door.b then
			entered[door.a] = true
			entered[door.b] = true
		end
		if door.kind == "front" then
			local x, z = MallLayout.doorCentre(door)
			local f = mall.Fountain
			local far = math.sqrt((x - f.x) ^ 2 + (z - f.z) ^ 2)
			if far > reach then
				table.insert(problems, string.format("%s's front is %d studs from the fountain", door.b, far))
			end
		end
	end
	for _, id in ids do
		if not entered[id] then
			table.insert(problems, id .. " has no way in")
		end
	end
	local court = mall.Rooms[mall.Spawn.room]
	if not court or not inside(court.rect, mall.Spawn.x, mall.Spawn.z) then
		table.insert(problems, "the spawn isn't inside its room")
	end
	return problems
end

-- The rooms a door joins to this one.
function MallLayout.neighbours(mall, roomId: string): { string }
	local list = {}
	for _, door in mall.Doors do
		if door.a == roomId and door.b then
			table.insert(list, door.b)
		elseif door.b == roomId and door.a then
			table.insert(list, door.a)
		end
	end
	table.sort(list)
	return list
end

return MallLayout
