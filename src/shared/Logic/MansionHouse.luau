-- The mansion while it is being generated (docs/plans/mansion-generation.md):
-- rooms as lattice rects over its storeys, the rules for where a room may
-- go, and which shared walls can hold a doorway. Pure; Logic/MansionGen
-- builds with it and Logic/LayoutValidator checks a finished layout with the
-- same rules.
--
-- A room is { id, template, floor, tall, top, x, z, w, d, rotation, zone,
-- zoneUpper, zones, role, mood }. `floor` is its lowest storey (-1 the cellar
-- to 2 the attic; docs/plans/level-design.md section 10.1). Tall rooms (the
-- grand hall, stairwells) stand on `floor` up to `top` (one storey up unless
-- set); `zone` is their zone on `floor`, `zoneUpper` the one above, and
-- `zones` one per storey when they span more than two.

local RoomRects = require(script.Parent.RoomRects)

local MansionHouse = {}
MansionHouse.__index = MansionHouse

local DIR_ORDER = { "N", "E", "S", "W" }

-- Every storey a house can have, lowest first.
MansionHouse.Storeys = { -1, 0, 1, 2 }

-- Zones that may share a doorway (mansion-generation.md, section 2). Every
-- other shared wall is a solid seam.
-- The service wing is two zones: the kitchen and pantry ("kitchen"), which
-- the dining room opens into, and the passage, laundry, back stairs and exit
-- ("service") behind them.
local ZONE_DOORS = {
	hall = { public = true, dining = true, private = true },
	public = { hall = true, public = true, dining = true, bath = true },
	dining = { hall = true, public = true, kitchen = true },
	kitchen = { dining = true, kitchen = true, service = true },
	service = { kitchen = true, service = true },
	private = { hall = true, private = true, bath = true },
	bath = { public = true, private = true },
	-- Under the house: only the cellar's own rooms and the feet of its
	-- stairs (docs/plans/level-design.md section 10.2).
	cellar = { cellar = true },
	-- Under the roof, the same (section 10.3).
	attic = { attic = true },
}

function MansionHouse.zonesMayJoin(a: string?, b: string?): boolean
	return a ~= nil and b ~= nil and ZONE_DOORS[a] ~= nil and ZONE_DOORS[a][b] == true
end

function MansionHouse.zoneOf(room, floor: number): string
	if room.zones then
		return room.zones[floor] or room.zone
	end
	if room.tall and floor > (room.floor or 0) then
		return room.zoneUpper or room.zone
	end
	return room.zone
end

-- A template's zone on a floor (one zone, or one per floor).
function MansionHouse.templateZone(template, floor: number): string
	local zone = template.mansion.zone
	if type(zone) == "table" then
		return zone[floor] or zone[0]
	end
	return zone
end

-- The storeys a room stands on, lowest first.
function MansionHouse.floorsOf(room): { number }
	local floor = room.floor or 0
	if room.tall then
		local list = {}
		for f = floor, RoomRects.topOf(room) do
			table.insert(list, f)
		end
		return list
	end
	return { floor }
end

function MansionHouse.onFloor(room, floor: number): boolean
	return RoomRects.onFloor(room, floor)
end

-- Footprint of a template size turned by `rotation` quarter turns.
function MansionHouse.footprint(size, rotation: number): (number, number)
	if rotation % 2 == 0 then
		return size[1], size[2]
	end
	return size[2], size[1]
end

-- The template side that ends up facing world side `dir` (the inverse of
-- LevelGraph.worldSide, which LevelBuilder's CFrame.Angles turn matches).
function MansionHouse.localSide(dir: string, rotation: number): string
	local index = table.find(DIR_ORDER, dir) :: number
	return DIR_ORDER[(index - 1 + rotation) % 4 + 1]
end

-- The rooms that belong to the cellar or the attic: those standing only
-- under the ground or under the roof, and the stairs that reach only there.
-- { [room id] = "cellar" | "attic" }. Each is a wing of its own (owner,
-- 2026-10-05: "so they can be more important for progression").
function MansionHouse.storeyGroups(rooms, templatesById)
	local groups = {}
	for _, room in rooms do
		local template = templatesById[room.template]
		local reach = template and template.mansion and template.mansion.reach
		local floor = room.floor or 0
		if reach then
			groups[room.id] = reach
		elseif not room.tall and floor < 0 then
			groups[room.id] = "cellar"
		elseif not room.tall and floor > 1 then
			groups[room.id] = "attic"
		end
	end
	return groups
end

-- A layout's rooms and seams with its servants' passages and their hidden
-- doors (docs/plans/level-design.md section 10.4), for what builds and walks
-- the house; the escape's logic counts only the house's own.
function MansionHouse.withPassages(layout)
	if not layout.passages then
		return layout.rooms, layout.seams
	end
	local rooms, seams = table.clone(layout.rooms), table.clone(layout.seams)
	for _, passage in layout.passages do
		table.insert(rooms, passage)
		for _, seam in passage.seams do
			table.insert(seams, seam)
		end
	end
	return rooms, seams
end

-- How many rooms stand on the main floors: everything but the cellar's and
-- the attic's (the room band counts these).
function MansionHouse.mainRooms(rooms, templatesById): number
	local below = 0
	for _ in MansionHouse.storeyGroups(rooms, templatesById) do
		below += 1
	end
	return #rooms - below
end

-- A room's doorways in its own frame, as Logic/RoomFit takes them: its seams,
-- the exit and the front door, on the storey its furniture stands on (the
-- lowest storey of a double-height room).
function MansionHouse.fitDoors(layout, room)
	local storey = room.floor or 0
	local doors = {}
	local function add(side: string, x: number, z: number)
		local lx, lz = RoomRects.toLocal(room, room.rotation, x, z)
		local localSide = MansionHouse.localSide(side, room.rotation or 0)
		table.insert(doors, { side = localSide, along = (localSide == "N" or localSide == "S") and lx or lz })
	end
	-- (The hidden doors into a servants' passage too: furniture keeps out of
	-- their way like any other's.)
	local seams = layout.seams
	if layout.passages then
		seams = table.clone(seams)
		for _, passage in layout.passages do
			for _, seam in passage.seams do
				table.insert(seams, seam)
			end
		end
	end
	for _, seam in seams do
		if (seam.floor or 0) == storey and (seam.a == room.id or seam.b == room.id) then
			local side = seam.a == room.id and seam.dir or RoomRects.Opposite[seam.dir]
			add(side, RoomRects.doorPoint(seam.dir, seam.line, seam.along))
		end
	end
	if storey == 0 then
		for _, door in { layout.exitDoor or false, layout.frontDoor or false } do
			if door and door.room == room.id then
				add(door.dir, RoomRects.doorPoint(door.dir, door.line, door.along))
			end
		end
	end
	return doors
end

function MansionHouse.pairKey(a: number, b: number): string
	if a > b then
		a, b = b, a
	end
	return a .. "-" .. b
end

function MansionHouse.new(config, templatesById)
	return setmetatable({
		config = config,
		templates = templatesById,
		lattice = config.Lattice,
		rooms = {},
		byId = {},
		index = MansionHouse.indices(config.Lattice),
		keepOut = {}, -- ground-floor rects nothing may cover: the porches
	}, MansionHouse)
end

-- An empty lattice index for every storey.
function MansionHouse.indices(lattice: number)
	local index = {}
	for _, floor in MansionHouse.Storeys do
		index[floor] = RoomRects.newIndex(lattice)
	end
	return index
end

-- Whether a room stands on what is below it (or, under the ground, lies
-- under what is above it): an upper room on the storey below's footprint, a
-- cellar room under the ground floor's. A tall room's own storeys hold each
-- other up.
function MansionHouse:Supported(rect): boolean
	local low, top = rect.floor or 0, RoomRects.topOf(rect)
	if low > 0 and not self.index[low - 1]:Covers(rect) then
		return false
	end
	if top < 0 and not self.index[top + 1]:Covers(rect) then
		return false
	end
	return true
end

function MansionHouse:Add(room)
	room.id = #self.rooms + 1
	return self:Insert(room)
end

-- Take back the last room added (the generator trying a route).
function MansionHouse:RemoveLast()
	local room = table.remove(self.rooms)
	self.byId[room.id] = nil
	for _, floor in MansionHouse.floorsOf(room) do
		self.index[floor]:Remove(room)
	end
end

-- Add a room that already has its id (a finished layout being checked).
function MansionHouse:Insert(room)
	table.insert(self.rooms, room)
	self.byId[room.id] = room
	for _, floor in MansionHouse.floorsOf(room) do
		self.index[floor]:Add(room)
	end
	return room
end

-- Whether a room's template lets a doorway sit in its wall facing `dir`.
function MansionHouse:Socket(room, floor: number, dir: string): boolean
	local template = self.templates[room.template]
	local sockets = template and template.mansion and template.mansion.sockets
	if sockets == nil then
		return true
	end
	local sides = sockets[floor]
	return sides ~= nil and sides[MansionHouse.localSide(dir, room.rotation or 0)] == true
end

-- The seam two rooms would share on a floor: the wall (dir from a to b,
-- line) and the doorway spot along it, or nil if they don't share enough
-- wall for a doorway.
function MansionHouse:Seam(a, b, floor: number)
	local c = RoomRects.contact(a, b)
	if c == nil or c.to - c.from < self.config.MinShared then
		return nil
	end
	if not self:Socket(a, floor, c.dir) or not self:Socket(b, floor, RoomRects.Opposite[c.dir]) then
		return nil
	end
	local along = RoomRects.doorAlong(c.from, c.to, self.lattice, self.config.DoorCornerClear)
	if along == nil then
		return nil
	end
	return { dir = c.dir, line = c.line, along = along, from = c.from, to = c.to, floor = floor }
end

-- Ids of the rooms on a floor that share some wall with a rect.
function MansionHouse:Neighbours(rect, floor: number): { number }
	local index = self.index[floor]
	local l = self.lattice
	local found, list = {}, {}
	local function look(x, z)
		local id = index:At(x, z)
		if id and id ~= rect.id and not found[id] then
			found[id] = true
			table.insert(list, id)
		end
	end
	for x = rect.x, rect.x + rect.w - l, l do
		look(x, rect.z - l)
		look(x, rect.z + rect.d)
	end
	for z = rect.z, rect.z + rect.d - l, l do
		look(rect.x - l, z)
		look(rect.x + rect.w, z)
	end
	table.sort(list)
	return list
end

-- Every seam a rect has with the rooms already placed: { other, seam }.
function MansionHouse:SeamsOf(rect)
	local list = {}
	for _, floor in MansionHouse.floorsOf(rect) do
		for _, id in self:Neighbours(rect, floor) do
			local seam = self:Seam(rect, self.byId[id], floor)
			if seam then
				table.insert(list, { other = self.byId[id], seam = seam })
			end
		end
	end
	return list
end

function MansionHouse:MaxSeams(room): number
	local template = self.templates[room.template]
	return template and template.mansion and template.mansion.maxSeams or math.huge
end

-- Whether a rect is on the site: behind the front line, inside the site's
-- box, or (a house type's: docs/plans/level-design.md section 10.6) inside
-- its rectangles and off its courtyard.
function MansionHouse:InSite(rect): boolean
	local c = self.config
	if rect.z + rect.d > c.FrontLine then
		return false
	end
	if c.Courtyard and RoomRects.overlaps(rect, c.Courtyard) then
		return false
	end
	if not c.Site then
		return rect.x >= -c.SiteHalfWidth and rect.x + rect.w <= c.SiteHalfWidth and rect.z >= c.FrontLine - c.SiteDepth
	end
	-- Every lattice square of it inside one of the site's rectangles.
	local l = self.lattice
	for x = rect.x + l / 2, rect.x + rect.w, l do
		for z = rect.z + l / 2, rect.z + rect.d, l do
			local inside = false
			for _, s in c.Site do
				if x > s.x and x < s.x + s.w and z > s.z and z < s.z + s.d then
					inside = true
					break
				end
			end
			if not inside then
				return false
			end
		end
	end
	return true
end

-- Whether a candidate room can go where it is: on the site, on free floor,
-- off the porches, standing on the ground floor if it is upstairs, never
-- touching another tall room, and not giving any room more seams than its
-- template allows. Returns the seams it would have when it fits.
function MansionHouse:Fits(rect)
	if not self:InSite(rect) then
		return false
	end
	for _, floor in MansionHouse.floorsOf(rect) do
		if not self.index[floor]:Free(rect) then
			return false
		end
		if floor == 0 then
			for _, area in self.keepOut do
				if RoomRects.overlaps(rect, area) then
					return false
				end
			end
		end
	end
	if not self:Supported(rect) then
		return false
	end
	if rect.tall then
		for _, floor in MansionHouse.floorsOf(rect) do
			for _, id in self:Neighbours(rect, floor) do
				if self.byId[id].tall then
					return false
				end
			end
		end
	end
	local seams = self:SeamsOf(rect)
	if #seams > self:MaxSeams(rect) then
		return false
	end
	for _, entry in seams do
		local max = self:MaxSeams(entry.other)
		if max < math.huge and self:SeamCount(entry.other) + 1 > max then
			return false
		end
	end
	return true, seams
end

function MansionHouse:SeamCount(room): number
	return #self:SeamsOf(room)
end

-- Every seam in the finished house, one per pair of rooms, sorted by pair.
function MansionHouse:AllSeams()
	local seams = {}
	for _, floor in MansionHouse.Storeys do
		for _, room in self.rooms do
			if MansionHouse.onFloor(room, floor) then
				for _, id in self:Neighbours(room, floor) do
					if id > room.id then
						local seam = self:Seam(room, self.byId[id], floor)
						if seam then
							seam.a, seam.b = room.id, id
							seam.id = "seam:" .. room.id .. "-" .. id
							table.insert(seams, seam)
						end
					end
				end
			end
		end
	end
	table.sort(seams, function(p, q)
		if p.a ~= q.a then
			return p.a < q.a
		end
		return p.b < q.b
	end)
	return seams
end

-- Studs walked around a cycle (or along a path) of room ids: door to door
-- inside each room, plus a flight of stairs for each storey between the two
-- doorways.
function MansionHouse.routeStuds(ids: { number }, seamByPair, config, closed: boolean): number
	local total = 0
	local n = #ids
	for i = 1, n do
		local prev = ids[i - 1] or (closed and ids[n])
		local nextId = ids[i + 1] or (closed and ids[1])
		if prev and nextId then
			local s1 = seamByPair[MansionHouse.pairKey(prev, ids[i])]
			local s2 = seamByPair[MansionHouse.pairKey(ids[i], nextId)]
			if s1 and s2 then
				local x1, z1 = RoomRects.doorPoint(s1.dir, s1.line, s1.along)
				local x2, z2 = RoomRects.doorPoint(s2.dir, s2.line, s2.along)
				-- a flight a storey
				total += math.abs(x1 - x2) + math.abs(z1 - z2) + math.abs(s1.floor - s2.floor) * config.StairStuds
			end
		end
	end
	return total
end

-- Walking distances over a finished or half-made house, for the generator's
-- choices (Logic/Wings): door to door inside each room as routeStuds counts
-- it, from a room's middle to its doors, a flight of stairs wherever the way
-- changes floor. Returns distancesFrom(roomId, passable(seam) -> boolean) ->
-- { [room id] = studs to its middle }. Rough beside Logic/NavGraph, but
-- needs no build; Logic/HouseMetrics measures the real thing.
function MansionHouse.walker(rooms, seams, config)
	local byId = {}
	for _, room in rooms do
		byId[room.id] = room
	end
	-- Each room's doors, with their points.
	local doorsOf = {}
	for _, seam in seams do
		local x, z = RoomRects.doorPoint(seam.dir, seam.line, seam.along)
		local door = { seam = seam, x = x, z = z, floor = seam.floor or 0 }
		for _, id in { seam.a, seam.b } do
			doorsOf[id] = doorsOf[id] or {}
			table.insert(doorsOf[id], door)
		end
	end
	local stair = config.StairStuds
	-- A room's middle is on its own storey (the lowest for a tall room).
	local function toMiddle(room, door): number
		local cx, cz = RoomRects.center(room)
		local storey = room.floor or 0
		return math.abs(cx - door.x) + math.abs(cz - door.z) + math.abs(door.floor - storey) * stair
	end
	return function(from: number, passable: (any) -> boolean): { [number]: number }
		-- Dijkstra over doors (keyed by seam id), seeded from the room's middle.
		local dist, done = {}, {}
		local out = { [from] = 0 }
		for _, door in doorsOf[from] or {} do
			if passable(door.seam) then
				local d = toMiddle(byId[from], door)
				if dist[door.seam.id] == nil or d < dist[door.seam.id].d then
					dist[door.seam.id] = { d = d, door = door }
				end
			end
		end
		while true do
			local best, bestEntry = nil, nil
			for id, entry in dist do
				if
					not done[id]
					and (bestEntry == nil or entry.d < bestEntry.d or (entry.d == bestEntry.d and id < best))
				then
					best, bestEntry = id, entry
				end
			end
			if not best then
				break
			end
			done[best] = true
			local door = bestEntry.door
			for _, id in { door.seam.a, door.seam.b } do
				local room = byId[id]
				local middle = bestEntry.d + toMiddle(room, door)
				if out[id] == nil or middle < out[id] then
					out[id] = middle
				end
				for _, other in doorsOf[id] or {} do
					if not done[other.seam.id] and passable(other.seam) then
						local d = bestEntry.d
							+ math.abs(door.x - other.x)
							+ math.abs(door.z - other.z)
							+ math.abs(door.floor - other.floor) * stair
						if dist[other.seam.id] == nil or d < dist[other.seam.id].d then
							dist[other.seam.id] = { d = d, door = other }
						end
					end
				end
			end
		end
		return out
	end
end

return MansionHouse
