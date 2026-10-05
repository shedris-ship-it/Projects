-- Seeded mansion generator (docs/plans/mansion-generation.md). It lays out
-- architecture first, then rooms, so the house reads like a building:
--
--   1. The grand hall at the front, with its front door in the south wall.
--   2. The service wing on one side: dining room, kitchen, service corridor,
--      back stairs, and the exit at the rear. On the ground floor the dining
--      room is the only way in, which puts the Deliberation Table on the
--      critical path by construction.
--   3. A public corridor on the other side (it may turn once), and maybe one
--      behind the hall.
--   4. Upstairs: the gallery (the hall's upper half), the service corridor
--      repeated over its twin for the back stairs, other corridors by
--      chance, and maybe a second stairwell.
--   5. General rooms packed against walls, ground floor first; upstairs they
--      stand on the ground floor's footprint. With a programme (Logic/
--      Programme: the rooms the run's adventure needs, then rooms with
--      something in them), in its order.
--   6. Doors: the tree that joined every room, the doors that make the upper
--      floor one piece (each closes a loop through two stairs), then the
--      adventure's (Logic/Wings: wings, a loop in each, shortcuts, the
--      backtrack; docs/plans/level-design.md section 5.3), then extra loops
--      that make sense and keep the fairness contract.
--   7. Roles, Lantern rooms and window orientation; validate; retry the next
--      attempt, then fall back to an authored mansion.

local Dumbwaiter = require(script.Parent.Dumbwaiter)
local Graph = require(script.Parent.Graph)
local LayoutValidator = require(script.Parent.LayoutValidator)
local LevelGraph = require(script.Parent.LevelGraph)
local LockPlanner = require(script.Parent.LockPlanner)
local MansionHouse = require(script.Parent.MansionHouse)
local Programme = require(script.Parent.Programme)
local RoomRects = require(script.Parent.RoomRects)
local Wings = require(script.Parent.Wings)
local Rng = require(script.Parent.Parent.Lib.Rng)

local MansionGen = {}

local DIRS = { "N", "E", "S", "W" }
local OPPOSITE = RoomRects.Opposite
local LAYOUT_ROLES = { start = "start", exit = "exit", deliberation = "deliberation" }

-- Templates by mansion role, and the general ones (no role), in list order.
local function pools(templates)
	local p = { byId = {}, roles = {}, general = {} }
	for _, template in templates do
		local m = template.mansion
		if m then
			p.byId[template.id] = template
			if m.role then
				p.roles[m.role] = p.roles[m.role] or {}
				table.insert(p.roles[m.role], template)
			else
				table.insert(p.general, template)
			end
		end
	end
	return p
end

-- The first template on the list that stands on `floor` in `zone` (not one
-- that only reaches down to the cellar or up to the attic, like the cellar
-- stair).
local function withZone(list, floor: number, zone: string)
	for _, template in list or {} do
		if
			table.find(template.mansion.floors, floor)
			and MansionHouse.templateZone(template, floor) == zone
			and not template.mansion.reach
		then
			return template
		end
	end
	return list and list[1]
end

-- A room record for a template at a position. Corridors pass their size. A
-- tall room stands on every storey its template lists, from the lowest, or
-- on `span` ({ low, top }: the back stairs carried down to the cellar or up
-- to the attic).
local function newRoom(template, floor: number, rotation: number, x: number, z: number, w: number, d: number, span)
	local m = template.mansion
	local low, top = floor, floor
	if m.tall then
		low, top = math.huge, -math.huge
		for _, f in m.floors do
			low, top = math.min(low, f), math.max(top, f)
		end
		if span then
			low, top = span[1], span[2]
		end
	end
	local room = {
		template = template.id,
		floor = floor,
		rotation = rotation,
		x = x,
		z = z,
		w = w,
		d = d,
		zone = MansionHouse.templateZone(template, low),
		role = LAYOUT_ROLES[m.role or ""],
		kind = m.role,
		mood = template.mood,
	}
	if m.tall then
		room.tall = true
		room.floor = low
		room.zoneUpper = MansionHouse.templateZone(template, low + 1)
		if top ~= low + 1 then
			-- More than two storeys: its top and a zone for each.
			room.top = top
			room.zones = {}
			for f = low, top do
				room.zones[f] = MansionHouse.templateZone(template, f)
			end
		end
	end
	if m.role == "corridor" then
		room.corridor = true
	end
	return room
end

-- Footprints to try for a template: { w, d, rotation }. Rooms whose sides
-- matter (sockets) try all four turns; the rest try each shape once and are
-- turned for their windows later.
local function footprints(template)
	local m = template.mansion
	local w, d = m.size[1], m.size[2]
	if m.sockets then
		return { { w, d, 0 }, { d, w, 1 }, { w, d, 2 }, { d, w, 3 } }
	end
	if w == d then
		return { { w, d, 0 } }
	end
	return { { w, d, 0 }, { d, w, 1 } }
end

local function corridorFootprints(length: number, width: number)
	return { { length, width, 0 }, { width, length, 0 } }
end

local function centre(rooms, floor: number?)
	local sx, sz, n = 0, 0, 0
	for _, room in rooms do
		if floor == nil or MansionHouse.onFloor(room, floor) then
			local x, z = RoomRects.center(room)
			sx += x
			sz += z
			n += 1
		end
	end
	if n == 0 then
		return 0, 0
	end
	return sx / n, sz / n
end

local function distance(rect, x: number, z: number): number
	local cx, cz = RoomRects.center(rect)
	return math.abs(cx - x) + math.abs(cz - z)
end

local Builder = {}
Builder.__index = Builder

function Builder.new(rng, templates, config)
	local p = pools(templates)
	return setmetatable({
		rng = rng,
		config = config,
		p = p,
		house = MansionHouse.new(config, p.byId),
		edges = {},
		edgeFloor = {},
		counts = {},
	}, Builder)
end

function Builder:_link(a, b, floor: number)
	local edge = a.id < b.id and { a.id, b.id } or { b.id, a.id }
	table.insert(self.edges, edge)
	self.edgeFloor[MansionHouse.pairKey(a.id, b.id)] = floor
end

-- Every way a room can join the house through a doorway to one of
-- spec.parents on spec.floor (see MansionHouse:Fits for the rules).
function Builder:_candidates(spec)
	local house, config = self.house, self.config
	local l, share = house.lattice, config.MinShared
	local list = {}
	for _, parent in spec.parents do
		if MansionHouse.onFloor(parent, spec.floor) then
			for _, fp in spec.footprints do
				local w, d, rotation = fp[1], fp[2], fp[3]
				for _, side in spec.sides or DIRS do
					local from, to, fixed
					if side == "E" or side == "W" then
						fixed = side == "E" and parent.x + parent.w or parent.x - w
						from, to = parent.z - d + share, parent.z + parent.d - share
					else
						fixed = side == "S" and parent.z + parent.d or parent.z - d
						from, to = parent.x - w + share, parent.x + parent.w - share
					end
					for pos = from, to, l do
						local x, z = fixed, pos
						if side == "N" or side == "S" then
							x, z = pos, fixed
						end
						local rect = spec.make(x, z, w, d, rotation)
						local ok, seams = house:Fits(rect)
						if ok then
							local link = nil
							for _, entry in seams do
								local f = entry.seam.floor
								if
									entry.other == parent
									and f == spec.floor
									and MansionHouse.zonesMayJoin(
										MansionHouse.zoneOf(rect, f),
										MansionHouse.zoneOf(parent, f)
									)
								then
									link = entry.seam
								end
							end
							local candidate = { rect = rect, parent = parent, seams = seams, link = link }
							if link and (spec.filter == nil or spec.filter(candidate)) then
								table.insert(list, candidate)
							end
						end
					end
				end
			end
		end
	end
	return list
end

-- Score every candidate, then a weighted pick among the best few.
function Builder:_choose(rng, list, score)
	local placement = self.config.Placement
	for _, c in list do
		c.score = (score and score(c) or 0) + rng:NextNumber() * placement.Jitter
	end
	table.sort(list, function(p, q)
		if p.score ~= q.score then
			return p.score > q.score
		end
		local a, b = p.rect, q.rect
		if a.x ~= b.x then
			return a.x < b.x
		end
		if a.z ~= b.z then
			return a.z < b.z
		end
		if a.w ~= b.w then
			return a.w < b.w
		end
		if a.rotation ~= b.rotation then
			return a.rotation < b.rotation
		end
		return p.parent.id < q.parent.id
	end)
	local top = {}
	for i = 1, math.min(placement.Top, #list) do
		top[i] = list[i]
	end
	local floorScore = top[#top].score
	return rng:WeightedPick(top, function(c)
		return c.score - floorScore + 0.5
	end)
end

-- Place one room per spec: returns the room (added to the house and joined
-- to its parent) or nil if it fits nowhere.
function Builder:_place(spec)
	local list = self:_candidates(spec)
	if #list == 0 then
		return nil
	end
	local c = self:_choose(spec.rng or self.rng, list, spec.score)
	if spec.before then
		spec.before(c)
	end
	local room = self.house:Add(c.rect)
	self:_link(c.parent, room, c.link.floor)
	return room, c
end

local function maker(template, floor: number, span)
	return function(x, z, w, d, rotation)
		return newRoom(template, floor, rotation, x, z, w, d, span)
	end
end

local function touches(house, rect, other, floor: number): boolean
	return table.find(house:Neighbours(rect, floor), other.id) ~= nil
end

-- Where the exit's doorway can go: a wall facing away from the front with
-- free ground outside and a clear porch. Returns { dir, line, along, porch }.
function Builder:_exitDoor(rect)
	local house, config = self.house, self.config
	local l, clear = house.lattice, config.DoorCornerClear
	local index = house.index[0]
	local best = nil
	for _, dir in { "N", "E", "W" } do
		local line, from, to
		if dir == "N" then
			line, from, to = rect.z, rect.x, rect.x + rect.w
		elseif dir == "E" then
			line, from, to = rect.x + rect.w, rect.z, rect.z + rect.d
		else
			line, from, to = rect.x, rect.z, rect.z + rect.d
		end
		local along = RoomRects.doorAlong(from, to, l, clear, function(p)
			local porch
			if dir == "N" then
				porch = { x = p - l, z = line - 2 * l, w = 2 * l, d = 2 * l }
			elseif dir == "E" then
				porch = { x = line, z = p - l, w = 2 * l, d = 2 * l }
			else
				porch = { x = line - 2 * l, z = p - l, w = 2 * l, d = 2 * l }
			end
			return index:Free(porch)
		end)
		if along and best == nil then
			local porch
			if dir == "N" then
				porch = { x = along - l, z = line - 2 * l, w = 2 * l, d = 2 * l }
			elseif dir == "E" then
				porch = { x = line, z = along - l, w = 2 * l, d = 2 * l }
			else
				porch = { x = line - 2 * l, z = along - l, w = 2 * l, d = 2 * l }
			end
			best = { dir = dir, line = line, along = along, porch = porch, floor = 0 }
		end
	end
	return best
end

-- Steps 1-4: the hall, the service wing, the corridors, the upper skeleton.
function Builder:_spine(): boolean
	local house, config, p = self.house, self.config, self.p
	local rng = self.rng:Fork("spine")
	local hallTemplate = p.roles.start[1]
	local size = hallTemplate.mansion.size
	local hall = house:Add(newRoom(hallTemplate, 0, 0, config.Hall.x, config.Hall.z, size[1], size[2]))
	self.hall = hall
	self.frontDoor = {
		room = hall.id,
		dir = "S",
		line = hall.z + hall.d,
		along = hall.x + hall.w / 2,
		floor = 0,
	}
	local hx, hz = RoomRects.center(hall)
	local function away(c, weight)
		return distance(c.rect, hx, hz) * weight
	end

	-- (A house type may say which side: along the L's arm.)
	local serviceSide = config.ServiceSide or rng:Pick({ "E", "W" })
	local publicSide = OPPOSITE[serviceSide]

	-- Service wing.
	local diningTemplate = p.roles.deliberation[1]
	local dining = self:_place({
		rng = rng,
		floor = 0,
		parents = { hall },
		sides = { serviceSide },
		footprints = footprints(diningTemplate),
		make = maker(diningTemplate, 0),
	})
	if not dining then
		return false, "no room for the dining room"
	end
	self.dining = dining
	local kitchenTemplate = p.roles.kitchen[1]
	local kitchen = self:_place({
		rng = rng,
		floor = 0,
		parents = { dining },
		footprints = footprints(kitchenTemplate),
		make = maker(kitchenTemplate, 0),
		filter = function(c)
			return not touches(house, c.rect, hall, 0)
		end,
		score = function(c)
			return away(c, 0.05)
		end,
	})
	if not kitchen then
		return false, "no room for the kitchen"
	end
	local serviceTemplate = withZone(p.roles.corridor, 0, "service")
	local width = config.CorridorWidth
	local length = rng:NextInteger(config.CorridorLength[1] / 10, config.CorridorLength[2] / 10) * 10
	local service = self:_place({
		rng = rng,
		floor = 0,
		parents = { kitchen },
		footprints = corridorFootprints(length, width),
		make = maker(serviceTemplate, 0),
		filter = function(c)
			return not touches(house, c.rect, hall, 0) and not touches(house, c.rect, dining, 0)
		end,
		score = function(c)
			return away(c, 0.05)
		end,
	})
	if not service then
		return false, "no room for the service corridor"
	end
	-- The back stairs: the servants' stair, carried down to the cellar and
	-- up to the attic when the house has them (docs/plans/level-design.md
	-- section 10.2).
	local backTemplate = withZone(p.roles.stair, 0, "service")
	local storeys = self.storeys or {}
	local backStairs = self:_place({
		rng = rng,
		floor = 0,
		parents = { service },
		footprints = footprints(backTemplate),
		make = maker(backTemplate, 0, { storeys.cellar and -1 or 0, storeys.attic and 2 or 1 }),
		score = function(c)
			return away(c, 0.05)
		end,
	})
	if not backStairs then
		return false, "no room for the back stairs"
	end
	local exitTemplates = table.clone(p.roles.exit)
	rng:Shuffle(exitTemplates)
	local exit = nil
	for _, exitTemplate in exitTemplates do
		exit = self:_place({
			rng = rng,
			floor = 0,
			parents = { service },
			footprints = footprints(exitTemplate),
			make = maker(exitTemplate, 0),
			filter = function(c)
				c.exitDoor = self:_exitDoor(c.rect)
				return c.exitDoor ~= nil
			end,
			score = function(c)
				return away(c, 0.05) + (c.exitDoor.dir == "N" and 3 or 0)
			end,
			before = function(c)
				self.exitDoor = c.exitDoor
				table.insert(house.keepOut, c.exitDoor.porch)
			end,
		})
		if exit then
			break
		end
	end
	if not exit then
		return false, "no room for the exit"
	end
	self.exitDoor.room = exit.id
	self.exit = exit

	-- Public corridor (it may turn once) and maybe one behind the hall.
	local publicTemplate = withZone(p.roles.corridor, 0, "public")
	local corridors = {}
	length = rng:NextInteger(config.CorridorLength[1] / 10, config.CorridorLength[2] / 10) * 10
	local public = self:_place({
		rng = rng,
		floor = 0,
		parents = { hall },
		sides = { publicSide },
		footprints = corridorFootprints(length, width),
		make = maker(publicTemplate, 0),
		score = function(c)
			-- leaving the hall end-on reads as a wing
			return (c.link.to - c.link.from == width) and 1 or 0
		end,
	})
	if public then
		table.insert(corridors, public)
		if rng:Chance(config.TurnChance) then
			local turnLength = rng:NextInteger(config.TurnLength[1] / 10, config.TurnLength[2] / 10) * 10
			local turn = self:_place({
				rng = rng,
				floor = 0,
				parents = { public },
				footprints = corridorFootprints(turnLength, width),
				make = maker(publicTemplate, 0),
				filter = function(c)
					return not touches(house, c.rect, hall, 0)
				end,
				score = function(c)
					return away(c, 0.05)
				end,
			})
			if turn then
				table.insert(corridors, turn)
			end
		end
	end
	if rng:Chance(config.RearCorridorChance) then
		length = rng:NextInteger(config.TurnLength[1] / 10, config.TurnLength[2] / 10) * 10
		local rear = self:_place({
			rng = rng,
			floor = 0,
			parents = { hall },
			sides = { "N" },
			footprints = corridorFootprints(length, width),
			make = maker(publicTemplate, 0),
			score = function(c)
				return (c.link.to - c.link.from == width) and 1 or 0
			end,
		})
		if rear then
			table.insert(corridors, rear)
		end
	end

	-- Upstairs: the service corridor is repeated over its twin for the back
	-- stairs; the others by chance.
	local upperTemplate = withZone(p.roles.corridor, 1, "private")
	local function stack(corridor, parents)
		local twin = newRoom(upperTemplate, 1, 0, corridor.x, corridor.z, corridor.w, corridor.d)
		local ok, seams = house:Fits(twin)
		if not ok then
			return nil
		end
		for _, entry in seams do
			if
				table.find(parents, entry.other)
				and entry.seam.floor == 1
				and MansionHouse.zonesMayJoin(twin.zone, MansionHouse.zoneOf(entry.other, 1))
			then
				house:Add(twin)
				self:_link(entry.other, twin, 1)
				return twin
			end
		end
		return nil
	end
	local upperService = stack(service, { backStairs })
	if not upperService then
		return false, "the service corridor could not be repeated upstairs"
	end
	self.upperService = upperService
	-- A second stairwell (owner: 1-2 stairwells) needs a corridor upstairs as
	-- well as down: the last public corridor is always repeated for it.
	local secondStair = rng:NextInteger(config.Stairwells[1], config.Stairwells[2]) >= 2
	local twins = {}
	for i, corridor in corridors do
		if (secondStair and i == #corridors) or rng:Chance(config.StackChance) then
			local parents = { hall }
			for _, other in twins do
				table.insert(parents, other)
			end
			local twin = stack(corridor, parents)
			if twin then
				twins[corridor] = twin
				table.insert(twins, twin)
			end
		end
	end

	-- Maybe a second stairwell off a public corridor that is repeated
	-- upstairs: a second loop between the floors.
	self.stairJoins = {}
	if secondStair then
		local stairTemplate = withZone(p.roles.stair, 0, "public")
		local parents = {}
		for _, corridor in corridors do
			if twins[corridor] then
				table.insert(parents, corridor)
			end
		end
		local stairs = self:_place({
			rng = rng,
			floor = 0,
			parents = parents,
			footprints = footprints(stairTemplate),
			make = maker(stairTemplate, 0),
			filter = function(c)
				local twin = twins[c.parent]
				for _, entry in c.seams do
					if entry.other == twin and entry.seam.floor == 1 then
						return true
					end
				end
				return false
			end,
			score = function(c)
				return away(c, 0.05)
			end,
		})
		if stairs then
			for _, corridor in corridors do
				local twin = twins[corridor]
				if twin and touches(house, stairs, twin, 1) then
					table.insert(self.stairJoins, { stairs.id, twin.id })
				end
			end
		end
	end
	return true
end

-- Which storeys beyond the two main ones this house has, and how many rooms
-- each: { cellar = n?, attic = n? } (Config.Mansion.Storeys; docs/plans/
-- level-design.md section 10.3).
function Builder:_storeys()
	local cfg = self.config.Storeys
	local out = {}
	if not cfg then
		return out
	end
	local rng = self.rng:Fork("storeys")
	local cellar, attic
	if cfg.OnlyOne then
		-- Exactly one of the two, their chances as weights.
		local total = cfg.Cellar.Chance + cfg.Attic.Chance
		local pick = rng:NextNumber() * total
		cellar = total > 0 and pick < cfg.Cellar.Chance
		attic = total > 0 and not cellar
	else
		cellar = rng:Chance(cfg.Cellar.Chance)
		attic = rng:Chance(cfg.Attic.Chance)
	end
	if cellar then
		out.cellar = rng:NextInteger(cfg.Cellar.Rooms[1], cfg.Cellar.Rooms[2])
	end
	if attic then
		out.attic = rng:NextInteger(cfg.Attic.Rooms[1], cfg.Attic.Rooms[2])
	end
	return out
end

-- The cellar stair: from a cellar room up to a door off the kitchen side
-- (the kitchen, the pantry, the service passage, the laundry) right above
-- it, as far from the back stairs as it can be, so the cellar between them
-- makes a loop. Its door upstairs is one the house can't do without.
function Builder:_cellarStair(salt: string)
	local house = self.house
	local template = nil
	for _, t in self.p.roles.stair or {} do
		if t.mansion.reach == "cellar" then
			template = t
		end
	end
	if not template then
		return nil
	end
	local parents, back = {}, nil
	for _, room in house.rooms do
		if (room.floor or 0) == -1 and not room.tall then
			table.insert(parents, room)
		elseif room.kind == "stair" and (room.floor or 0) < 0 then
			back = room
		end
	end
	local function upstairs(c)
		for _, entry in c.seams do
			local other = entry.other
			if
				entry.seam.floor == 0
				and not other.tall
				and MansionHouse.zonesMayJoin(MansionHouse.zoneOf(c.rect, 0), MansionHouse.zoneOf(other, 0))
			then
				return entry
			end
		end
		return nil
	end
	local pull = self.config.Storeys.Cellar.StairPull
	local stair, c = self:_place({
		rng = self.rng:Fork("cellar stair" .. salt),
		floor = -1,
		parents = parents,
		footprints = footprints(template),
		make = maker(template, -1),
		filter = function(c)
			return upstairs(c) ~= nil
		end,
		score = function(c)
			if not back then
				return 0
			end
			local bx, bz = RoomRects.center(back)
			return distance(c.rect, bx, bz) * pull
		end,
	})
	if stair then
		local above = upstairs(c).other
		table.insert(self.stairJoins, { stair.id, above.id })
	end
	return stair
end

-- Whether every room on a storey could be joined by doorways on it (the
-- doors pass adds what's missing between zones that may share one).
function Builder:_joinable(floor: number): boolean
	local house = self.house
	local ids, edges = {}, {}
	for _, room in house.rooms do
		if MansionHouse.onFloor(room, floor) then
			table.insert(ids, room.id)
		end
	end
	for _, room in house.rooms do
		if MansionHouse.onFloor(room, floor) then
			for _, entry in house:SeamsOf(room) do
				local seam, other = entry.seam, entry.other
				if
					seam.floor == floor
					and other.id > room.id
					and MansionHouse.zonesMayJoin(MansionHouse.zoneOf(room, floor), MansionHouse.zoneOf(other, floor))
				then
					table.insert(edges, { room.id, other.id })
				end
			end
		end
	end
	return #ids > 0 and Graph.isConnected(Graph.adjacency(ids, edges), ids)
end

-- The rooms of the cellar or the attic, grown from the back stairs' foot,
-- and the second stair that makes them a loop: a few packings tried, the
-- first whose second stair fits (and whose rooms join into one piece) kept.
-- A packing that fails is taken back room by room.
function Builder:_storeyRooms(floor: number, quota: number)
	local house = self.house
	local tries = self.config.Storeys.Tries
	for try = 1, tries do
		local salt = try > 1 and (" try " .. try) or ""
		local rooms, edges, counts = #house.rooms, #self.edges, table.clone(self.counts)
		local joins = #self.stairJoins
		local done = false
		local placed = floor > 1 and self.atticStair
		if placed then
			-- The attic stair stands already (placed before the upper floor's
			-- rooms filled the space for it): the rooms grow to meet it.
			self:_roomsOn(floor, quota, salt)
			done = try == tries or self:_joinable(floor)
		elseif try == tries then
			-- The last try is ready to have no second stair: then two rooms at
			-- most, so the storey is no deeper a dead end than the contract
			-- allows.
			self:_roomsOn(floor, math.min(quota, self.config.MaxDeadEndChain), salt)
			done = true
		elseif try % 2 == 1 then
			-- The rooms, then the second stair beside one of them.
			self:_roomsOn(floor, quota, salt)
			local second = if floor < 0 then self:_cellarStair(salt) else self:_atticStair(salt)
			done = second ~= nil and self:_joinable(floor)
		else
			-- The second stair first, off the floor it leaves from, then the
			-- rooms grown to meet it.
			local second = self:_stairFirst(floor, salt)
			if second then
				self:_roomsOn(floor, quota, salt)
				done = self:_joinable(floor)
			end
		end
		if done then
			return
		end
		while #self.stairJoins > joins do
			table.remove(self.stairJoins)
		end
		while #self.edges > edges do
			local edge = table.remove(self.edges)
			self.edgeFloor[MansionHouse.pairKey(edge[1], edge[2])] = nil
		end
		while #house.rooms > rooms do
			house:RemoveLast()
		end
		self.counts = counts
	end
end

-- The attic stair: from an attic room down to a door off the upper floor
-- (a bedroom, the upper hall) right below it, as far from the back stairs as
-- it can be, so the attic between them makes a loop. Its door downstairs is
-- one the house can't do without.
function Builder:_atticStair(salt: string)
	local house = self.house
	local template = nil
	for _, t in self.p.roles.stair or {} do
		if t.mansion.reach == "attic" then
			template = t
		end
	end
	if not template then
		return nil
	end
	local parents, back = {}, nil
	for _, room in house.rooms do
		if (room.floor or 0) == 2 and not room.tall then
			table.insert(parents, room)
		elseif room.kind == "stair" and RoomRects.topOf(room) > 1 then
			back = room
		end
	end
	-- (Into the upper hall or a bedroom: not a bathroom.)
	local function downstairs(c)
		for _, entry in c.seams do
			local other = entry.other
			if entry.seam.floor == 1 and not other.tall and MansionHouse.zoneOf(other, 1) == "private" then
				return entry
			end
		end
		return nil
	end
	local pull = self.config.Storeys.Attic.StairPull
	local stair, c = self:_place({
		rng = self.rng:Fork("attic stair" .. salt),
		floor = 2,
		parents = parents,
		footprints = footprints(template),
		make = maker(template, 2),
		filter = function(c)
			return downstairs(c) ~= nil
		end,
		score = function(c)
			if not back then
				return 0
			end
			local bx, bz = RoomRects.center(back)
			return distance(c.rect, bx, bz) * pull
		end,
	})
	if stair then
		local below = downstairs(c).other
		table.insert(self.stairJoins, { stair.id, below.id })
	end
	return stair
end

-- The cellar's or the attic's second stair placed before its rooms: off a
-- kitchen-side room on the ground floor (going down) or a room of the upper
-- floor (going up), as far from the back stairs as it fits.
function Builder:_stairFirst(floor: number, salt: string, only: { any }?)
	local house = self.house
	local reach = floor < 0 and "cellar" or "attic"
	local template = nil
	for _, t in self.p.roles.stair or {} do
		if t.mansion.reach == reach then
			template = t
		end
	end
	if not template then
		return nil
	end
	local from = floor < 0 and 0 or 1
	local parents, back = {}, nil
	for _, room in house.rooms do
		local zone = MansionHouse.zoneOf(room, from)
		if
			MansionHouse.onFloor(room, from)
			and not room.tall
			and (if floor < 0 then zone == "kitchen" or zone == "service" else zone == "private")
		then
			table.insert(parents, room)
		elseif room.kind == "stair" and MansionHouse.onFloor(room, floor) then
			back = room
		end
	end
	if only then
		parents = only
	end
	-- Near enough the back stairs that a room or two between them joins
	-- them into a loop.
	local cfg = self.config.Storeys[floor < 0 and "Cellar" or "Attic"]
	return self:_place({
		rng = self.rng:Fork(reach .. " stair first" .. salt),
		floor = from,
		parents = parents,
		footprints = footprints(template),
		make = maker(template, from),
		score = function(c)
			if not back then
				return 0
			end
			local bx, bz = RoomRects.center(back)
			-- Up from the back stairs' own hall upstairs, an attic room over
			-- that hall can reach both stairs.
			local beside = (floor > 1 and c.parent == self.upperService) and cfg.Beside or 0
			return beside - math.abs(distance(c.rect, bx, bz) - cfg.FirstApart) * cfg.FirstPull
		end,
	})
end

-- The attic's loop, while the upper floor still has room: the attic stair
-- off the hall the back stairs open into upstairs, and one attic room over
-- that hall reaching both stairs. Tried a few ways; taken back if it can't
-- be done (the attic then grows from the back stairs alone, later).
function Builder:_atticLoop(): boolean
	local house = self.house
	local tries = self.config.Storeys.Tries
	for try = 1, tries do
		local salt = " loop " .. try
		local rooms, edges, counts = #house.rooms, #self.edges, table.clone(self.counts)
		-- Off the back stairs' own hall first; any upstairs room after.
		local only = (try <= tries / 2 and self.upperService) and { self.upperService } or nil
		local stair = self:_stairFirst(2, salt, only)
		if stair then
			-- One room between them, or two on the even tries.
			local between = try % 2 == 0 and 2 or 1
			self:_roomsOn(2, between, salt)
			if self:_joinable(2) then
				self.atticStair = stair
				self.atticPlaced = #house.rooms - rooms - 1
				return true
			end
		end
		while #self.edges > edges do
			local edge = table.remove(self.edges)
			self.edgeFloor[MansionHouse.pairKey(edge[1], edge[2])] = nil
		end
		while #house.rooms > rooms do
			house:RemoveLast()
		end
		self.counts = counts
	end
	return false
end

-- A storey's pieces: which rooms its own doorways already join.
function Builder:_components(floor: number)
	local ids, upperEdges = {}, {}
	for _, room in self.house.rooms do
		if MansionHouse.onFloor(room, floor) then
			table.insert(ids, room.id)
		end
	end
	for _, edge in self.edges do
		if self.edgeFloor[MansionHouse.pairKey(edge[1], edge[2])] == floor then
			table.insert(upperEdges, edge)
		end
	end
	local adj = Graph.adjacency(ids, upperEdges)
	local component = {}
	local count = 0
	for _, id in ids do
		if component[id] == nil then
			count += 1
			for node in Graph.bfs(adj, id) do
				component[node] = count
			end
		end
	end
	return component, count
end

-- The upper floor's pieces.
function Builder:_upperComponents()
	return self:_components(1)
end

-- Upstairs, the gallery and the back stairs' corridor must meet, so the two
-- stairs make a loop between the floors (hall, gallery, upper hall, back
-- stairs, service wing, dining room). A corridor of one or two straight
-- pieces over the service wing joins them.
function Builder:_bridge(): boolean
	local house, config = self.house, self.config
	local rng = self.rng:Fork("bridge")
	local target = self.upperService
	local hall = self.hall
	local template = withZone(self.p.roles.corridor, 1, "private")
	local width = config.CorridorWidth
	local shapes = {}
	for length = 20, 80, 10 do
		table.insert(shapes, { length, width, 0 })
		if length ~= width then
			table.insert(shapes, { width, length, 0 })
		end
	end
	local function joins(c)
		for _, entry in c.seams do
			if entry.other == target and entry.seam.floor == 1 then
				return true
			end
		end
		return false
	end
	local function from(parent)
		return self:_candidates({
			floor = 1,
			parents = { parent },
			footprints = shapes,
			make = maker(template, 1),
		})
	end
	local function shortest(c)
		return -(c.rect.w + c.rect.d) * 0.05
	end
	local function keep(c, parent)
		local room = house:Add(c.rect)
		self:_link(parent, room, 1)
		return room
	end

	-- Start from the gallery or any corridor already joined to it upstairs.
	local component = self:_upperComponents()
	local starts = {}
	for _, room in house.rooms do
		if MansionHouse.onFloor(room, 1) and component[room.id] == component[hall.id] then
			if room == hall or room.corridor then
				table.insert(starts, room)
			end
		end
	end
	local direct = {}
	for _, start in starts do
		for _, c in from(start) do
			if joins(c) then
				table.insert(direct, c)
			end
		end
	end
	if #direct > 0 then
		local c = self:_choose(rng, direct, shortest)
		local room = keep(c, c.parent)
		self:_link(room, target, 1)
		return true
	end
	local firsts = {}
	for _, start in starts do
		for _, c in from(start) do
			table.insert(firsts, c)
		end
	end
	table.sort(firsts, function(p, q)
		local a, b = p.rect, q.rect
		if a.w + a.d ~= b.w + b.d then
			return a.w + a.d < b.w + b.d
		end
		if a.x ~= b.x then
			return a.x < b.x
		end
		if a.z ~= b.z then
			return a.z < b.z
		end
		return a.w < b.w
	end)
	for _, first in firsts do
		local room = keep(first, first.parent)
		local seconds = {}
		for _, c in from(room) do
			if joins(c) then
				table.insert(seconds, c)
			end
		end
		if #seconds > 0 then
			local c = self:_choose(rng, seconds, shortest)
			local second = keep(c, room)
			self:_link(second, target, 1)
			return true
		end
		house:RemoveLast()
		table.remove(self.edges)
	end
	return false
end

-- Step 5: general rooms on one floor.
function Builder:_roomsOn(floor: number, quota: number, salt: string?)
	local house, config, p = self.house, self.config, self.p
	local rng = self.rng:Fork("rooms" .. floor .. (salt or ""))
	local flipRng = self.rng:Fork("rotation" .. floor .. (salt or ""))
	local placement = config.Placement
	local failed = {}
	local placed = 0
	local onFloor = {}
	local listed = self.programme and self.programme.floors[floor] or nil
	local nextListed = 1
	-- (The laundry, which the chute upstairs wants a room over.)
	local laundry = nil
	for _, room in house.rooms do
		if room.template == "laundry" then
			laundry = room
		end
	end
	local function allowed(template): boolean
		local m = template.mansion
		return not failed[template.id]
			and table.find(m.floors, floor) ~= nil
			and (self.counts[template.id] or 0) < (m.max or 1)
			and (onFloor[template.id] or 0) < (m.perFloor or math.huge)
	end
	while placed < quota do
		-- The programme's next room, else a weighted draw as before.
		local template = nil
		while listed and listed[nextListed] and not template do
			local candidate = p.byId[listed[nextListed]]
			nextListed += 1
			if candidate and allowed(candidate) then
				template = candidate
			end
		end
		if not template then
			local options = {}
			for _, t in p.general do
				if allowed(t) then
					table.insert(options, t)
				end
			end
			if #options == 0 then
				break
			end
			template = rng:WeightedPick(options, function(t)
				return t.mansion.weight or 1
			end)
		end
		local near = template.mansion.near or {}
		-- In the cellar and the attic the rooms grow from the stairs' feet.
		local fromStairs = floor < 0 or floor > 1
		local parents = {}
		for _, room in house.rooms do
			if MansionHouse.onFloor(room, floor) and (room.kind ~= "stair" or fromStairs) then
				table.insert(parents, room)
			end
		end
		local cx, cz = centre(house.rooms, floor)
		local components = floor ~= 0 and self:_components(floor) or nil
		-- How far apart two rooms are by doorways now: a new room touching
		-- both closes a loop that long plus two.
		local ids = {}
		for _, room in house.rooms do
			table.insert(ids, room.id)
		end
		local adj = Graph.adjacency(ids, self.edges)
		-- Rooms reached through other rooms make dead-end chains; how many
		-- rooms each room is from a corridor, the hall or a stairwell.
		local spine = {}
		for _, room in house.rooms do
			if room.corridor or room.tall then
				table.insert(spine, room.id)
			end
		end
		local depth = {}
		do
			local queue, head = {}, 1
			for _, id in spine do
				depth[id] = 0
				table.insert(queue, id)
			end
			while head <= #queue do
				local id = queue[head]
				head += 1
				for _, nextId in adj[id] do
					if depth[nextId] == nil then
						depth[nextId] = depth[id] + 1
						table.insert(queue, nextId)
					end
				end
			end
		end
		local distances = {}
		local function apart(a: number, b: number): number?
			distances[a] = distances[a] or Graph.bfs(adj, a)
			return distances[a][b]
		end
		local room = self:_place({
			rng = rng,
			floor = floor,
			parents = parents,
			footprints = footprints(template),
			make = maker(template, floor),
			score = function(c)
				local s = 0
				local joins = {}
				for _, entry in c.seams do
					local other = entry.other
					local f = entry.seam.floor
					local mayJoin =
						MansionHouse.zonesMayJoin(MansionHouse.zoneOf(c.rect, f), MansionHouse.zoneOf(other, f))
					if mayJoin and other ~= c.parent then
						local gap = apart(c.parent.id, other.id)
						if gap and gap + 2 >= config.LoopLength[1] and gap + 2 <= config.LoopLength[2] then
							s += placement.Loop
						else
							s += placement.Contact
						end
					end
					if mayJoin and components then
						joins[components[other.id] or 0] = true
					end
					local otherNear = p.byId[other.template].mansion.near
					if table.find(near, other.template) or (otherNear and table.find(otherNear, template.id)) then
						s += placement.Near
					end
				end
				if c.parent.corridor or c.parent.role == "start" then
					s += placement.Corridor
					-- corridors with nothing off them yet come first
					if #adj[c.parent.id] <= 2 then
						s += placement.Fill
					end
				elseif (depth[c.parent.id] or 0) >= 1 then
					s -= placement.Chain * depth[c.parent.id]
				end
				if components then
					local pieces = 0
					for _ in joins do
						pieces += 1
					end
					if pieces >= 2 then
						s += fromStairs and placement.Bridge * 3 or placement.Bridge
					end
				end
				if floor == 1 and laundry and config.Chute and config.Chute.Uppers[MansionHouse.zoneOf(c.rect, 1)] then
					-- Over the laundry, a bathroom or a room upstairs can have the
					-- laundry chute (section 10.5).
					local x0 = math.max(laundry.x, c.rect.x)
					local x1 = math.min(laundry.x + laundry.w, c.rect.x + c.rect.w)
					local z0 = math.max(laundry.z, c.rect.z)
					local z1 = math.min(laundry.z + laundry.d, c.rect.z + c.rect.d)
					if x1 - x0 >= 10 and z1 - z0 >= 10 then
						s += placement.Chute
					end
				end
				if floor < 0 then
					-- The cellar lies under the service wing, where its stair can
					-- come up into the kitchen side.
					local cx0, cz0 = RoomRects.center(c.rect)
					local above = house.index[0]:At(cx0, cz0)
					local zone = above and MansionHouse.zoneOf(house.byId[above], 0)
					if zone == "kitchen" or zone == "service" then
						s += placement.Under
					end
				end
				if fromStairs and components then
					-- Under the house or under the roof, grow towards the other
					-- stair's foot, so the storey joins up into a loop.
					local own = components[c.parent.id]
					local nearest = math.huge
					for _, other in house.rooms do
						local piece = components[other.id]
						if piece and piece ~= own then
							local ox, oz = RoomRects.center(other)
							nearest = math.min(nearest, distance(c.rect, ox, oz))
						end
					end
					if nearest < math.huge then
						return s - placement.Toward * nearest
					end
				end
				return s - placement.Spread * distance(c.rect, cx, cz)
			end,
			before = function(c)
				-- turn half the rooms the other way round: same footprint
				if not template.mansion.sockets and flipRng:Chance(0.5) then
					c.rect.rotation += 2
				end
			end,
		})
		if room then
			placed += 1
			self.counts[template.id] = (self.counts[template.id] or 0) + 1
			onFloor[template.id] = (onFloor[template.id] or 0) + 1
		else
			failed[template.id] = true
		end
	end
end

-- Whether the Deliberation Table is still on a shortest start-to-exit path
-- (doc section 3) with these edges, and the exit still far enough away.
local function tableOnPath(ids, edges, start, exit, deliberation, minExit: number): boolean
	local adj = Graph.adjacency(ids, edges)
	local fromStart = Graph.bfs(adj, start)
	local fromExit = Graph.bfs(adj, exit)
	return (fromStart[deliberation] or math.huge) + (fromExit[deliberation] or math.huge) == fromStart[exit]
		and fromStart[exit] >= minExit
end

-- Step 6: doors that make the upper floor one piece, then extra loops.
function Builder:_doors(seams)
	local house, config = self.house, self.config
	local rng = self.rng:Fork("doors")
	local ids = {}
	for _, room in house.rooms do
		table.insert(ids, room.id)
	end
	local start, exit, deliberation = self.hall.id, self.exit.id, self.dining.id
	local seamByPair = {}
	for _, seam in seams do
		seamByPair[MansionHouse.pairKey(seam.a, seam.b)] = seam
	end
	local edgeSet = {}
	for _, edge in self.edges do
		edgeSet[MansionHouse.pairKey(edge[1], edge[2])] = true
	end
	local function mayJoin(seam)
		return MansionHouse.zonesMayJoin(
			MansionHouse.zoneOf(house.byId[seam.a], seam.floor),
			MansionHouse.zoneOf(house.byId[seam.b], seam.floor)
		)
	end
	local function loopStuds(a: number, b: number, edges): number
		local path = Graph.path(Graph.adjacency(ids, edges), a, b)
		if path == nil then
			return math.huge
		end
		return MansionHouse.routeStuds(path, seamByPair, config, true)
	end
	local function accept(pair, edges)
		local trial = table.clone(edges)
		table.insert(trial, pair)
		return tableOnPath(ids, trial, start, exit, deliberation, config.MinExitRooms)
			and loopStuds(pair[1], pair[2], edges) >= config.MinLoopStuds
	end
	local function add(pair, floor)
		table.insert(self.edges, pair)
		edgeSet[MansionHouse.pairKey(pair[1], pair[2])] = true
		self.edgeFloor[MansionHouse.pairKey(pair[1], pair[2])] = floor
	end

	-- A second stairwell always opens upstairs too, and the cellar stair at
	-- the top (their loops may be short in studs; they only have to keep the
	-- table on the path).
	for _, pair in self.stairJoins do
		local seam = seamByPair[MansionHouse.pairKey(pair[1], pair[2])]
		local trial = table.clone(self.edges)
		table.insert(trial, pair)
		if
			seam
			and not edgeSet[MansionHouse.pairKey(pair[1], pair[2])]
			and tableOnPath(ids, trial, start, exit, deliberation, config.MinExitRooms)
		then
			add({ seam.a, seam.b }, seam.floor)
		end
	end

	-- Join the upper floor into one piece through the shortest-route doors
	-- that keep the contract, then the cellar and the attic (their loops run
	-- up and down two flights of stairs, so they only have to keep the table
	-- on the way out).
	local function keepsTable(pair, edges): boolean
		local trial = table.clone(edges)
		table.insert(trial, pair)
		return tableOnPath(ids, trial, start, exit, deliberation, config.MinExitRooms)
	end
	for _, floor in { 1, -1, 2 } do
		while true do
			local component, count = self:_components(floor)
			if count <= 1 then
				break
			end
			local options = {}
			for _, seam in seams do
				local pair = { seam.a, seam.b }
				if
					seam.floor == floor
					and not edgeSet[MansionHouse.pairKey(seam.a, seam.b)]
					and component[seam.a] ~= component[seam.b]
					and mayJoin(seam)
					and (if floor == 1 then accept(pair, self.edges) else keepsTable(pair, self.edges))
				then
					table.insert(options, seam)
				end
			end
			if #options == 0 then
				break
			end
			local pick = rng:Pick(options)
			add({ pick.a, pick.b }, floor)
		end
	end

	-- Extra loops: pairs that make sense together are likelier; with wings,
	-- inside a wing rather than across into another (a doorway between two
	-- wings is a bolt).
	local adjacent = {}
	for _, seam in seams do
		if mayJoin(seam) then
			table.insert(adjacent, { seam.a, seam.b })
		end
	end
	local rooms = {}
	for _, room in house.rooms do
		table.insert(rooms, room)
	end
	local function finish(loopRng, wings, beats: number)
		local loopConfig = config
		if beats > 0 then
			loopConfig = table.clone(config)
			loopConfig.ExtraEdges = {
				math.max(0, config.ExtraEdges[1] - beats),
				math.max(0, config.ExtraEdges[2] - beats),
			}
		end
		local extra = LevelGraph.addLoops(loopRng, rooms, adjacent, self.edges, loopConfig, {
			accept = accept,
			weight = function(pair)
				local seam = seamByPair[MansionHouse.pairKey(pair[1], pair[2])]
				local a = MansionHouse.zoneOf(house.byId[seam.a], seam.floor)
				local b = MansionHouse.zoneOf(house.byId[seam.b], seam.floor)
				local w = 1
				if a == b and a ~= "service" then
					w = 2
				elseif (a == "bath" or b == "bath") or a == b then
					w = 1.5
				end
				if wings then
					w *= wings.roomRegion[pair[1]] == wings.roomRegion[pair[2]] and 3 or 0.4
				end
				return w
			end,
		})
		table.clear(edgeSet)
		for _, edge in self.edges do
			edgeSet[MansionHouse.pairKey(edge[1], edge[2])] = true
		end
		local doorRng = self.rng:Fork("door slabs")
		for _, seam in seams do
			seam.from, seam.to = nil, nil
			seam.connected = edgeSet[MansionHouse.pairKey(seam.a, seam.b)] == true
			seam.door = seam.connected and doorRng:Chance(config.DoorChance) or false
		end
		-- Archways (docs/plans/level-design.md section 10.7): two rooms of a
		-- wing that belong together (the living room and the den, the kitchen
		-- and the pantry) opened into one by a wide arch, no door. Only inside
		-- a wing, so never where a lock or a bolt goes.
		local arches = config.Arches
		if wings and arches then
			local archRng = self.rng:Fork("arches")
			local made = 0
			for _, seam in seams do
				local a, b = house.byId[seam.a], house.byId[seam.b]
				local pair = arches.Pairs[a.template .. "+" .. b.template]
					or arches.Pairs[b.template .. "+" .. a.template]
				if
					made < arches.Most
					and seam.connected
					and pair
					and wings.roomRegion[seam.a] == wings.roomRegion[seam.b]
					and archRng:Chance(arches.Chance)
				then
					seam.arch, seam.door = true, false
					made += 1
				end
			end
		end
		return extra
	end

	-- The adventure (Logic/Wings): wings cut from the tree of doors so far, a
	-- loop in each, shortcuts and the backtrack, each tried partition checked
	-- the way the lock planner will check it; the first that holds is kept.
	local wcfg = config.Wings
	if wcfg then
		local base = table.clone(self.edges)
		local wctx = {
			ids = ids,
			byId = house.byId,
			seams = seams,
			seamByPair = seamByPair,
			edges = self.edges,
			edgeSet = {},
			start = start,
			dining = deliberation,
			rng = self.rng:Fork("wings"),
			cfg = wcfg,
			config = config,
			stage = wcfg.Stage,
			squad = config.Squad,
			mayJoin = mayJoin,
			accept = accept,
			keepsTable = function(pair, edges)
				local trial = table.clone(edges)
				table.insert(trial, pair)
				return tableOnPath(ids, trial, start, exit, deliberation, config.MinExitRooms)
			end,
			walk = MansionHouse.walker(house.rooms, seams, config),
		}
		-- The cellar and the attic are a wing each of their own, never part of
		-- the house open from the start (owner, 2026-10-05).
		local groups = MansionHouse.storeyGroups(house.rooms, self.p.byId)
		local tree = Wings.tree(ids, base, start, groups)
		local forced = Wings.groupRoots(tree, groups)
		self.wingLog = {}
		local layoutLike =
			{ mode = "Mansion", rooms = house.rooms, seams = seams, start = start, deliberation = deliberation }
		-- The cellar and the attic are wings on top of the house's own (owner,
		-- 2026-10-05: "additions to the existing wings").
		local k = (config.Regions or LockPlanner.regionCount(#ids, wcfg.Stage)) + #forced
		-- Region 0's loop: the first few that could be closed.
		for _, edge in base do
			wctx.edgeSet[MansionHouse.pairKey(edge[1], edge[2])] = true
		end
		local cores = {}
		for _, core in Wings.coreLoops(wctx) do
			local below = false
			for _, id in core.rooms do
				below = below or groups[id] ~= nil
			end
			if not below then
				table.insert(cores, core)
			end
		end
		for want = k, math.max(1, #forced), -1 do
			local tries = {}
			-- (With no loop to build on, region 0 is tried as it falls.)
			for c = 1, math.max(1, math.min(wcfg.Cores, #cores)) do
				local core = cores[c]
				local partitions = Wings.partitions(wctx, tree, want, core and core.rooms, forced)
				for t = 1, math.min(wcfg.Tries, #partitions) do
					table.insert(tries, { core = core, partition = partitions[t] })
				end
			end
			table.sort(tries, function(a, b)
				return a.partition.score > b.partition.score
			end)
			if #tries == 0 then
				table.insert(
					self.wingLog,
					("%d wings: no way to cut them (%d loops for region 0)"):format(want, #cores)
				)
			end
			for t = 1, math.min(wcfg.Tries, #tries) do
				self.edges = table.clone(base)
				wctx.edges = self.edges
				table.clear(wctx.edgeSet)
				for _, edge in self.edges do
					wctx.edgeSet[MansionHouse.pairKey(edge[1], edge[2])] = true
				end
				local wings = Wings.realise(wctx, tree, tries[t].partition, tries[t].core)
				if not wings then
					table.insert(self.wingLog, ("%d wings, try %d: region 0's loop can't be closed"):format(want, t))
					continue
				end
				local beats = #self.edges - #base
				local extra = finish(rng:Fork("loops " .. want .. ":" .. t), wings, beats)
				local problems =
					LockPlanner.checkShape(layoutLike, Wings.skeleton(wings, seams), self.p.byId, wcfg.Stage, config)
				if #problems == 0 then
					self.wings = wings
					wings.storeys = #forced
					return extra
				end
				-- Why each partition was turned down (tools/plan, tools/mansionstats).
				table.insert(self.wingLog, ("%d wings, try %d: %s"):format(want, t, table.concat(problems, "; ")))
			end
		end
		-- No wings held: the plain house, its regions grown by the planner.
		self.edges = base
	end
	return finish(rng, nil, 0)
end

-- Servants' passages (docs/plans/level-design.md section 10.4): a narrow
-- way along the outside of two rooms whose walls line up, each joined to it
-- by a hidden door, where it saves the most walking between them. The house
-- is whole and fair without it: it isn't one of the house's rooms or doors
-- (`layout.passages`), so the validator, the lock planner and the level's
-- measures never see it. Between two wings, the later wing's door opens
-- only from its room: a shortcut home, never a way round a lock.
function Builder:_passages(seams)
	local cfg = self.config.Passages
	local house = self.house
	local template = self.p.roles.passage and self.p.roles.passage[1]
	if not cfg or not self.wings or not template then
		return {}
	end
	local rng = self.rng:Fork("passages")
	if not rng:Chance(cfg.Chance) then
		return {}
	end
	local region = self.wings.roomRegion
	-- When each wing opens: a passage between two wings is a shortcut home
	-- from the later one (its door won't open from inside the passage).
	local opensAt = { [0] = 0 }
	for i, r in self.wings.order do
		opensAt[r] = i
	end
	local walk = MansionHouse.walker(house.rooms, seams, self.config)
	local function open(seam)
		return seam.connected == true
	end
	local joined = {}
	for _, seam in seams do
		if seam.connected then
			joined[MansionHouse.pairKey(seam.a, seam.b)] = true
		end
	end
	local distances = {}
	local function between(a: number, b: number): number
		distances[a] = distances[a] or walk(a, open)
		return distances[a][b] or math.huge
	end
	local id = #house.rooms + 1
	local l, width, share = house.lattice, cfg.Width, self.config.MinShared
	local function fits(rect): boolean
		if not house:InSite(rect) or not house.index[rect.floor]:Free(rect) then
			return false
		end
		if rect.floor == 0 then
			for _, area in house.keepOut do
				if RoomRects.overlaps(rect, area) then
					return false
				end
			end
		end
		return house:Supported(rect)
	end
	-- A hidden door between a room and the passage: in a shared stretch of
	-- wall a doorway fits in, the passage's narrow end included (the door
	-- in its middle).
	local function hiddenSeam(room, rect, floor: number)
		local c = RoomRects.contact(room, rect)
		if not c then
			return nil
		end
		if c.to - c.from >= share then
			return house:Seam(room, rect, floor)
		end
		if c.to - c.from < width or not house:Socket(room, floor, c.dir) then
			return nil
		end
		return { dir = c.dir, line = c.line, along = (c.from + c.to) / 2, floor = floor }
	end
	local function middleTo(room, x: number, z: number): number
		local cx, cz = RoomRects.center(room)
		return math.abs(cx - x) + math.abs(cz - z)
	end
	local best = nil
	for _, floor in { 0, 1 } do
		for _, a in house.rooms do
			if (a.floor or 0) == floor and not a.tall and cfg.Zones[MansionHouse.zoneOf(a, floor)] then
				for _, dir in DIRS do
					for _, span in house.index[floor]:OuterSpans(a, dir) do
						if span.to - span.from >= share then
							for _, length in cfg.Lengths do
								for start = span.from - length + share, span.to - share, l do
									local rect
									if dir == "N" then
										rect = { x = start, z = a.z - width, w = length, d = width }
									elseif dir == "S" then
										rect = { x = start, z = a.z + a.d, w = length, d = width }
									elseif dir == "W" then
										rect = { x = a.x - width, z = start, w = width, d = length }
									else
										rect = { x = a.x + a.w, z = start, w = width, d = length }
									end
									rect.id, rect.floor, rect.template, rect.rotation = id, floor, template.id, 0
									if fits(rect) then
										-- The rooms it reaches with a wall a doorway fits in.
										local reach = {}
										for _, otherId in house:Neighbours(rect, floor) do
											local other = house.byId[otherId]
											local seam = not other.tall
												and cfg.Zones[MansionHouse.zoneOf(other, floor)]
												and hiddenSeam(other, rect, floor)
											if seam then
												table.insert(reach, { room = other, seam = seam })
											end
										end
										for i = 1, #reach do
											for j = i + 1, #reach do
												local p, q = reach[i], reach[j]
												local ra, rb = p.room, q.room
												if
													region[ra.id] ~= nil
													and region[rb.id] ~= nil
													and not joined[MansionHouse.pairKey(ra.id, rb.id)]
												then
													local ax, az =
														RoomRects.doorPoint(p.seam.dir, p.seam.line, p.seam.along)
													local bx, bz =
														RoomRects.doorPoint(q.seam.dir, q.seam.line, q.seam.along)
													local through = middleTo(ra, ax, az)
														+ math.abs(ax - bx)
														+ math.abs(az - bz)
														+ middleTo(rb, bx, bz)
													local saves = between(ra.id, rb.id) - through
													local score = saves + rng:NextNumber() * cfg.Jitter
													if
														saves >= cfg.MinSaves and (best == nil or score > best.score)
													then
														best =
															{ rect = rect, p = p, q = q, saves = saves, score = score }
													end
												end
											end
										end
									end
								end
							end
						end
					end
				end
			end
		end
	end
	if not best then
		return {}
	end
	local rect = best.rect
	local passage = {
		id = id,
		template = template.id,
		floor = rect.floor,
		x = rect.x,
		z = rect.z,
		w = rect.w,
		d = rect.d,
		rotation = 0,
		zone = "passage",
		kind = "passage",
		passage = true,
		mood = template.mood,
		rooms = { best.p.room.id, best.q.room.id },
		saves = math.floor(best.saves + 0.5),
		seams = {},
	}
	local ra, rb = region[best.p.room.id], region[best.q.room.id]
	local later = opensAt[ra] > opensAt[rb] and best.p.room.id or opensAt[rb] > opensAt[ra] and best.q.room.id or nil
	for _, entry in { best.p, best.q } do
		local seam = entry.seam
		seam.from, seam.to = nil, nil
		seam.a, seam.b = entry.room.id, id
		seam.id = "seam:" .. entry.room.id .. "-" .. id
		seam.connected, seam.door, seam.hidden = true, true, true
		-- Into the later wing: found from its room only, never from the
		-- passage (a shortcut home, not a way round a lock).
		seam.barred = entry.room.id == later or nil
		table.insert(passage.seams, seam)
	end
	return { passage }
end

-- The laundry chute (docs/plans/level-design.md section 10.5): a hatch in
-- an upstairs room standing over the laundry, on a wall the two share, clear
-- of both rooms' doorways and furniture (Logic/Dumbwaiter's spots, with the
-- chute's own size); else a trapdoor in the floor where both rooms are
-- clear. A bathroom first, then the upper hall, then a bedroom.
-- { ground, upper, x, z, side, into } or { ground, upper, x, z, floor =
-- true }, or nil.
function MansionGen.chute(layout, templatesById, config)
	local cfg = config.Chute
	if not cfg then
		return nil
	end
	local laundry = nil
	for _, room in layout.rooms do
		if room.template == "laundry" and (room.floor or 0) == 0 then
			laundry = room
		end
	end
	if not laundry then
		return nil
	end
	local uppers = {}
	for _, room in layout.rooms do
		local rank = room.floor == 1 and not room.tall and cfg.Uppers[MansionHouse.zoneOf(room, 1)]
		if rank then
			table.insert(uppers, { room = room, rank = rank })
		end
	end
	table.sort(uppers, function(a, b)
		if a.rank ~= b.rank then
			return a.rank < b.rank
		end
		return a.room.id < b.room.id
	end)
	for _, entry in uppers do
		local spot = Dumbwaiter.spots(layout, laundry, entry.room, cfg, templatesById)[1]
		if spot then
			return {
				ground = laundry.id,
				upper = entry.room.id,
				x = spot.x,
				z = spot.z,
				side = spot.side,
				into = spot.into,
			}
		end
	end
	-- No wall they share: a trapdoor in the floor upstairs over the laundry,
	-- where both rooms are clear of walls, doorways and furniture.
	local doors = {}
	for _, seam in layout.seams do
		if seam.connected and (seam.floor or 0) <= 1 then
			local x, z = RoomRects.doorPoint(seam.dir, seam.line, seam.along)
			table.insert(doors, { x = x, z = z })
		end
	end
	local wall = config.Chute.Wall
	for _, entry in uppers do
		local upper = entry.room
		local margin = cfg.FloorMargin
		local x0 = math.max(laundry.x, upper.x) + margin
		local x1 = math.min(laundry.x + laundry.w, upper.x + upper.w) - margin
		local z0 = math.max(laundry.z, upper.z) + margin
		local z1 = math.min(laundry.z + laundry.d, upper.z + upper.d) - margin
		if x1 >= x0 and z1 >= z0 then
			local boxes = Dumbwaiter.furniture(layout, laundry, templatesById, wall)
			for _, b in Dumbwaiter.furniture(layout, upper, templatesById, wall) do
				table.insert(boxes, b)
			end
			local cx, cz = (x0 + x1) / 2, (z0 + z1) / 2
			local best, bestDistance = nil, math.huge
			local half = cfg.Width / 2 + cfg.FurnitureClear
			for x = x0, x1, cfg.Step do
				for z = z0, z1, cfg.Step do
					local clear = true
					for _, b in boxes do
						if x - half < b.x1 and b.x0 < x + half and z - half < b.z1 and b.z0 < z + half then
							clear = false
						end
					end
					for _, door in doors do
						if math.abs(door.x - x) + math.abs(door.z - z) < cfg.DoorClear + half then
							clear = false
						end
					end
					local distance = math.abs(x - cx) + math.abs(z - cz)
					if clear and distance < bestDistance then
						best, bestDistance = { x = x, z = z }, distance
					end
				end
			end
			if best then
				return { ground = laundry.id, upper = upper.id, x = best.x, z = best.z, floor = true }
			end
		end
	end
	return nil
end

-- Windows look outside: turn each room with windows (keeping its footprint)
-- so the most face out, the window that lights the room counting most.
function Builder:_orientWindows()
	local house = self.house
	for _, room in house.rooms do
		local template = self.p.byId[room.template]
		if not template.mansion.sockets and not room.tall and not room.corridor then
			local windows = LevelGraph.windows(template)
			if #windows > 0 then
				local turns = room.w == room.d and { 0, 1, 2, 3 } or { 0, 2 }
				local best, bestScore = room.rotation, -1
				for _, turn in turns do
					local rotation = (room.rotation + turn) % 4
					local score = 0
					for _, window in windows do
						local dir = LevelGraph.worldSide(window.side, rotation)
						if #house.index[room.floor]:OuterSpans(room, dir) > 0 then
							score += window.key and 10 or 1
						end
					end
					if score > bestScore then
						best, bestScore = rotation, score
					end
				end
				room.rotation = best
			end
		end
	end
end

-- The house's type (Config.Mansion.Types; docs/plans/level-design.md section
-- 10.6): a copy of the config with its site, courtyard and service side, and
-- the type's name.
function MansionGen.typed(rng, config)
	local types = config.Types
	if not types or #types == 0 then
		return config, nil
	end
	local kind = rng:WeightedPick(types, function(t)
		return t.weight or 1
	end)
	local mirror = kind.mirror and rng:Chance(0.5)
	local c = table.clone(config)
	if kind.site then
		c.Site = {}
		for _, r in kind.site do
			table.insert(c.Site, mirror and { x = -(r.x + r.w), z = r.z, w = r.w, d = r.d } or table.clone(r))
		end
	end
	if kind.courtyard then
		local r = kind.courtyard
		c.Courtyard = mirror and { x = -(r.x + r.w), z = r.z, w = r.w, d = r.d } or table.clone(r)
	end
	if kind.serviceSide then
		c.ServiceSide = mirror and RoomRects.Opposite[kind.serviceSide] or kind.serviceSide
	end
	return c, kind.name
end

-- One generation attempt with a given RNG.
function MansionGen.attempt(rng, templates, config)
	local houseType
	config, houseType = MansionGen.typed(rng:Fork("type"), config)
	local builder = Builder.new(rng, templates, config)
	local target = rng:Fork("count"):NextInteger(config.RoomCount[1], config.RoomCount[2])
	if config.Programme then
		builder.programme = Programme.draw(
			rng:Fork("programme"),
			builder.p.general,
			config.Programme,
			config.Programme.Enabled,
			config.Squad
		)
	end
	-- The cellar and the attic, when the house has them: their rooms are
	-- kept back from the main floors' share.
	-- The cellar and the attic, when the house has them. Their rooms come on
	-- top of the room band, which counts the main floors (so a small house
	-- still has its bedrooms).
	builder.storeys = builder:_storeys()
	local built, why = builder:_spine()
	if not built then
		return nil, why
	end
	if builder.storeys.cellar then
		-- Under the service wing, from the back stairs' foot, then the
		-- cellar stair up to the kitchen side (docs/plans/level-design.md
		-- section 10.2).
		builder:_storeyRooms(-1, builder.storeys.cellar)
	end
	local function main(): number
		return MansionHouse.mainRooms(builder.house.rooms, builder.p.byId)
	end
	local remaining = math.max(0, target - main())
	local upper = math.floor(remaining * config.UpperShare + 0.5)
	builder:_roomsOn(0, remaining - upper)
	-- Without a corridor, the upper rooms may still join the two sides.
	builder:_bridge()
	local atticRooms = builder.storeys.attic
	if atticRooms and builder:_atticLoop() then
		-- (One or two of its rooms are placed.)
		atticRooms -= builder.atticPlaced
	end
	builder:_roomsOn(1, math.max(0, target - main()))
	if atticRooms and atticRooms > 0 then
		-- Over the upper floor, from the back stairs' top (and the attic
		-- stair's, when it stands), then the attic stair down to the upper
		-- floor if it isn't there yet (section 10.3).
		builder:_storeyRooms(2, atticRooms)
	end
	local house = builder.house
	local seams = house:AllSeams()
	local extra = builder:_doors(seams)
	builder:_orientWindows()
	local passages = builder:_passages(seams)

	local ids = {}
	for _, room in house.rooms do
		table.insert(ids, room.id)
	end
	local adj = Graph.adjacency(ids, builder.edges)
	local start, exit, deliberation = builder.hall.id, builder.exit.id, builder.dining.id
	local lanterns = LevelGraph.pickLanterns(rng:Fork("lanterns"), house.rooms, adj, function(id)
		local room = house.byId[id]
		return id == start or id == exit or id == deliberation or room.kind == "stair"
	end, config)
	for _, room in house.rooms do
		room.lantern = table.find(lanterns, room.id) ~= nil
	end
	local exitDoor = table.clone(builder.exitDoor)
	exitDoor.porch = nil
	local layout = {
		mode = "Mansion",
		rooms = house.rooms,
		edges = builder.edges,
		seams = seams,
		start = start,
		exit = exit,
		deliberation = deliberation,
		criticalPath = Graph.path(adj, start, exit) or { start },
		lanterns = lanterns,
		extraEdges = extra,
		frontDoor = builder.frontDoor,
		exitDoor = exitDoor,
		wings = builder.wings,
		wingLog = builder.wingLog,
		passages = #passages > 0 and passages or nil,
		programme = builder.programme,
		houseType = houseType,
	}
	-- The laundry chute, once the layout is whole (it reads the doorways).
	layout.chute = MansionGen.chute(layout, builder.p.byId, config)
	return layout
end

-- The authored mansion used when ten attempts all fail (Data/MansionFallback,
-- frozen from a good seed with `lune run tools/plan <seed> mansion freeze`).
function MansionGen.fallback(_seed: number, _templates, _config)
	local frozen = require(script.Parent.Parent.Data.MansionFallback)
	local layout = MansionGen.thaw(frozen)
	layout.fallback = true
	return layout
end

-- A deep copy, so a frozen layout is never changed by a run.
function MansionGen.thaw(value)
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for k, v in value do
		copy[k] = MansionGen.thaw(v)
	end
	return copy
end

-- Generate a validated mansion from a seed.
function MansionGen.generate(seed: number, templates, config)
	local problems
	for attemptIndex = 0, config.MaxAttempts - 1 do
		local rng = Rng.new(seed + attemptIndex * 7919):Fork("mansion")
		local layout, why = MansionGen.attempt(rng, templates, config)
		if layout then
			local ok, issues = LayoutValidator.validate(layout, templates, config)
			if ok then
				layout.seed = seed
				layout.attempts = attemptIndex + 1
				return layout
			end
			problems = issues
		else
			problems = { why }
		end
	end
	local layout = MansionGen.fallback(seed, templates, config)
	layout.seed = seed
	layout.attempts = config.MaxAttempts
	layout.lastProblems = problems
	return layout
end

return MansionGen
