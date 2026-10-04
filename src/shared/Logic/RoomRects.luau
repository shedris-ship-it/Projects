-- Rectangle maths for room layouts (docs/plans/mansion-generation.md). A rect
-- is { id, x, z, w, d, floor, tall } in studs: x, z is the north-west corner
-- relative to Config.Level.Origin, x grows east and z grows south, and every
-- value sits on the lattice. Tall rooms (the grand hall, stairwells) stand on
-- both floors.
--
-- The old generator's 40x40 cells are rects too (fromCells), so the builder
-- and the tools can treat both layouts the same way.

local RoomRects = {}

RoomRects.Opposite = { N = "S", S = "N", E = "W", W = "E" }

function RoomRects.onFloor(rect, floor: number): boolean
	return (rect.floor or 0) == floor or (rect.tall == true and floor >= 0 and floor <= 1)
end

function RoomRects.center(rect): (number, number)
	return rect.x + rect.w / 2, rect.z + rect.d / 2
end

-- A room's own frame, as the builders turn it (CFrame.new(centre) *
-- CFrame.Angles(0, rotation * pi / 2, 0)): local x, z to layout x, z and back.
local COS = { 1, 0, -1, 0 } -- by rotation + 1
local SIN = { 0, 1, 0, -1 }

function RoomRects.toWorld(rect, rotation: number?, lx: number, lz: number): (number, number)
	local cx, cz = RoomRects.center(rect)
	local r = (rotation or 0) % 4 + 1
	local c, s = COS[r], SIN[r]
	return cx + lx * c + lz * s, cz - lx * s + lz * c
end

function RoomRects.toLocal(rect, rotation: number?, wx: number, wz: number): (number, number)
	local cx, cz = RoomRects.center(rect)
	local dx, dz = wx - cx, wz - cz
	local r = (rotation or 0) % 4 + 1
	local c, s = COS[r], SIN[r]
	return dx * c - dz * s, dx * s + dz * c
end

-- The inner faces of a room's walls, as half extents in its own frame.
function RoomRects.innerOf(rect, rotation: number?, wall: number)
	local hx, hz = rect.w / 2, rect.d / 2
	if (rotation or 0) % 2 == 1 then
		hx, hz = hz, hx
	end
	return { x = hx - wall, z = hz - wall }
end

-- Interiors intersect (touching walls is not an overlap). Floors are not
-- checked here.
function RoomRects.overlaps(a, b): boolean
	return a.x < b.x + b.w and b.x < a.x + a.w and a.z < b.z + b.d and b.z < a.z + a.d
end

-- Where two rects on the same floor touch: the side of `a` they share, the
-- wall line (an x for E/W, a z for N/S), and the shared span along it.
function RoomRects.contact(a, b)
	local function span(lo1, hi1, lo2, hi2)
		local from, to = math.max(lo1, lo2), math.min(hi1, hi2)
		if to > from then
			return from, to
		end
		return nil, nil
	end
	local from, to
	if a.x + a.w == b.x then
		from, to = span(a.z, a.z + a.d, b.z, b.z + b.d)
		if from then
			return { dir = "E", line = b.x, from = from, to = to }
		end
	elseif b.x + b.w == a.x then
		from, to = span(a.z, a.z + a.d, b.z, b.z + b.d)
		if from then
			return { dir = "W", line = a.x, from = from, to = to }
		end
	elseif a.z + a.d == b.z then
		from, to = span(a.x, a.x + a.w, b.x, b.x + b.w)
		if from then
			return { dir = "S", line = b.z, from = from, to = to }
		end
	elseif b.z + b.d == a.z then
		from, to = span(a.x, a.x + a.w, b.x, b.x + b.w)
		if from then
			return { dir = "N", line = a.z, from = from, to = to }
		end
	end
	return nil
end

-- The door spot on a shared span: the lattice point nearest its middle that is
-- at least `clear` studs from either end (door half-width plus lane
-- half-width), and passes `allowed` if given. Ties go to the lower coordinate.
function RoomRects.doorAlong(from: number, to: number, lattice: number, clear: number, allowed: ((number) -> boolean)?)
	local mid = (from + to) / 2
	local best, bestDistance = nil, math.huge
	local first = math.ceil((from + clear) / lattice) * lattice
	local p = first
	while p <= to - clear do
		if allowed == nil or allowed(p) then
			local distance = math.abs(p - mid)
			if distance < bestDistance then
				best, bestDistance = p, distance
			end
		end
		p += lattice
	end
	return best
end

-- The world point of a door on a wall: x, z.
function RoomRects.doorPoint(dir: string, line: number, along: number): (number, number)
	if dir == "N" or dir == "S" then
		return along, line
	end
	return line, along
end

-- Lattice occupancy for one floor: which room covers each lattice square.
local Index = {}
Index.__index = Index

function RoomRects.newIndex(lattice: number)
	return setmetatable({ lattice = lattice, cells = {} }, Index)
end

-- One number per lattice square (no strings: the generator asks millions of
-- times). Good for lattice coordinates within +-2048 squares of the origin.
local function key(ix: number, iz: number): number
	return (ix + 2048) * 4096 + iz + 2048
end

-- Calls fn(key) for every lattice square of a rect until it returns false.
function Index:_each(rect, fn: (number) -> boolean?): boolean
	local l = self.lattice
	for ix = rect.x / l, (rect.x + rect.w) / l - 1 do
		for iz = rect.z / l, (rect.z + rect.d) / l - 1 do
			if fn(key(ix, iz)) == false then
				return false
			end
		end
	end
	return true
end

function Index:Add(rect, id)
	local cells, value = self.cells, id or rect.id
	self:_each(rect, function(k)
		cells[k] = value
		return true
	end)
end

function Index:Remove(rect)
	local cells = self.cells
	self:_each(rect, function(k)
		cells[k] = nil
		return true
	end)
end

-- Whether no lattice square of the rect is taken.
function Index:Free(rect): boolean
	local cells = self.cells
	return self:_each(rect, function(k)
		return cells[k] == nil
	end)
end

-- Whether every lattice square of the rect is taken (an upper room standing
-- on the ground floor's footprint).
function Index:Covers(rect): boolean
	local cells = self.cells
	return self:_each(rect, function(k)
		return cells[k] ~= nil
	end)
end

-- The room at a point, or nil in the void. A point on a wall line belongs to
-- the room east or south of it.
function Index:At(x: number, z: number)
	local l = self.lattice
	return self.cells[key(math.floor(x / l), math.floor(z / l))]
end

-- Stretches of a rect's wall on one side that touch no other room on this
-- index: { from, to } spans along the wall.
function Index:OuterSpans(rect, dir: string)
	local l = self.lattice
	local spans = {}
	local from = nil
	local count = (dir == "N" or dir == "S") and rect.w / l or rect.d / l
	for i = 0, count do
		local outside = false
		if i < count then
			local x, z
			if dir == "N" then
				x, z = rect.x + i * l, rect.z - l
			elseif dir == "S" then
				x, z = rect.x + i * l, rect.z + rect.d
			elseif dir == "W" then
				x, z = rect.x - l, rect.z + i * l
			else
				x, z = rect.x + rect.w, rect.z + i * l
			end
			outside = self:At(x, z) == nil
		end
		local start = (dir == "N" or dir == "S") and rect.x or rect.z
		if outside and from == nil then
			from = start + i * l
		elseif not outside and from ~= nil then
			table.insert(spans, { from = from, to = start + i * l })
			from = nil
		end
	end
	return spans
end

-- An old cell layout's rooms as 40x40 rects (cell centres sit at gx * size).
function RoomRects.fromCells(layout, cellSize: number?)
	local size = cellSize or 40
	local rects = table.create(#layout.rooms)
	for i, room in layout.rooms do
		rects[i] = {
			id = room.id,
			x = room.gx * size - size / 2,
			z = room.gz * size - size / 2,
			w = size,
			d = size,
			floor = 0,
			room = room,
		}
	end
	return rects
end

-- A layout's rooms as rects, whichever generator made it.
function RoomRects.ofLayout(layout, config)
	if layout.mode == nil then
		return RoomRects.fromCells(layout, config and config.CellSize)
	end
	local rects = table.create(#layout.rooms)
	for i, room in layout.rooms do
		rects[i] = {
			id = room.id,
			x = room.x,
			z = room.z,
			w = room.w,
			d = room.d,
			floor = room.floor or 0,
			tall = room.tall,
			room = room,
		}
	end
	return rects
end

-- A copy of an old cell layout with each seam's wall geometry filled in, plus
-- the exit door on the first outer side in N, E, S, W order (as LevelBuilder
-- picks it). The layout itself is left untouched.
function RoomRects.seamsOfCells(layout, config)
	local size = config and config.CellSize or 40
	local lattice = config and config.Lattice or 10
	local rects = RoomRects.fromCells(layout, size)
	local byId = {}
	local index = RoomRects.newIndex(lattice)
	for _, rect in rects do
		byId[rect.id] = rect
		index:Add(rect)
	end
	local copy = table.clone(layout)
	copy.seams = {}
	for i, seam in layout.seams do
		local c = RoomRects.contact(byId[seam.a], byId[seam.b])
		local s = table.clone(seam)
		if c then
			s.dir, s.line, s.floor = c.dir, c.line, 0
			s.along = RoomRects.doorAlong(c.from, c.to, lattice, 7)
		end
		copy.seams[i] = s
	end
	local exit = layout.exit and byId[layout.exit]
	if exit then
		for _, dir in { "N", "E", "S", "W" } do
			if #index:OuterSpans(exit, dir) > 0 then
				local line = (dir == "N" and exit.z)
					or (dir == "S" and exit.z + exit.d)
					or (dir == "W" and exit.x)
					or exit.x + exit.w
				local along = (dir == "N" or dir == "S") and exit.x + exit.w / 2 or exit.z + exit.d / 2
				copy.exitDoor = { dir = dir, line = line, along = along, floor = 0 }
				break
			end
		end
	end
	return copy
end

return RoomRects
