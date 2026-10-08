-- Fits a room template's furniture into a room of another size (the mansion,
-- docs/plans/mansion-generation.md). Templates were authored for 40x40 rooms
-- with a doorway in the middle of each wall; a mansion room is 20-40 studs a
-- side with doorways wherever its seams fell. This is the stopgap until the
-- furnishing phase (M4) anchors props to walls properly:
--
--   * Every coordinate is remapped per axis. Things in the band along a wall
--     keep their distance from that wall, so wardrobes stay against walls and
--     corners stay corners; the middle of the room stretches or shrinks.
--   * Anything in a doorway's lane is slid along its wall until it clears,
--     else left out: the essentials (hiding spots, the Deliberation Table, the
--     key light) are placed first, so they get first pick of the space.
--   * Wall items (decor, tell slots, the Case Board) keep clear of doorways.
--   * Solid furniture never reaches into the room's clear middle (beyond the
--     wall band), where The Guest's routes cross the room (Logic/NavGraph).
--
-- All coordinates are in the template's own frame (x east, z south, origin
-- at the floor centre, before the room is turned). Pure: no engine calls.

local Props = require(script.Parent.Parent.Data.Props)
local MansionHouse = require(script.Parent.MansionHouse)
local RoomRects = require(script.Parent.RoomRects)

local RoomFit = {}

RoomFit.SourceInner = 19.5 -- a 40x40 template's walls, inner faces
RoomFit.Band = 8 -- furniture keeps its distance to a wall within this band
-- In a room with a `middle` prop (the dining table, WP5) wall furniture keeps
-- to this narrower band: the walk round the table needs the floor between
-- it and the walls (Logic/NavGraph islands read the same number).
RoomFit.IslandBand = 4
RoomFit.LaneHalfWidth = 4 -- (doc) doorway-to-centre lanes kept clear
RoomFit.LaneDepth = 9 -- how far into the room a doorway's lane runs
RoomFit.WallItemClear = 6.5 -- wall item centre to a doorway's centre, along the wall
-- Wall items keep this much bare wall between them (the squad playtest,
-- 2026-10-08: a clock hung over a window). Squeezing a template into a small
-- room pulls a window and a slot towards the middle of the same wall.
RoomFit.WallItemGap = 0.6
-- A wall slot's half width: the widest thing hung in one (a portrait, 3.6).
RoomFit.SlotHalf = 1.8

-- A prop's turn (degrees) to stand against each wall facing the room: its
-- front is +Z.
local WALL_TURN = { N = 0, S = 180, E = 270, W = 90 }

-- Offsets for a last-resort search over the floor, nearest first.
local SPIRAL = {}
for dx = -20, 20 do
	for dz = -20, 20 do
		table.insert(SPIRAL, { dx, dz })
	end
end
table.sort(SPIRAL, function(a, b)
	local da, db = math.abs(a[1]) + math.abs(a[2]), math.abs(b[1]) + math.abs(b[2])
	if da ~= db then
		return da < db
	end
	if a[1] ~= b[1] then
		return a[1] < b[1]
	end
	return a[2] < b[2]
end)

-- One axis: keep the distance to the nearer wall inside the band, scale the
-- middle.
function RoomFit.remap(v: number, from: number, to: number): number
	local band = RoomFit.Band
	local a = math.abs(v)
	if a >= from - band then
		local sign = v < 0 and -1 or 1
		return sign * (to - (from - a))
	end
	return v * (to - band) / (from - band)
end

-- Half extents of a prop's footprint, turned by its rotation in degrees.
function RoomFit.footprint(kind: string, ry: number?): (number, number)
	local info = Props.Kinds[kind]
	local w, d = info and info.size[1] or 2, info and info.size[3] or 2
	local turns = math.floor(((ry or 0) % 360) / 90 + 0.5) % 2
	if turns == 1 then
		return d / 2, w / 2
	end
	return w / 2, d / 2
end

local function overlaps(a, b, margin: number): boolean
	return a.x0 < b.x1 + margin and b.x0 < a.x1 + margin and a.z0 < b.z1 + margin and b.z0 < a.z1 + margin
end

local function box(x: number, z: number, ex: number, ez: number)
	return { x0 = x - ex, x1 = x + ex, z0 = z - ez, z1 = z + ez }
end

-- The lane in front of a doorway, as a box.
local function lane(door, inner)
	local h, depth = RoomFit.LaneHalfWidth, RoomFit.LaneDepth
	if door.side == "N" then
		return { x0 = door.along - h, x1 = door.along + h, z0 = -inner.z - 1, z1 = -inner.z + depth }
	elseif door.side == "S" then
		return { x0 = door.along - h, x1 = door.along + h, z0 = inner.z - depth, z1 = inner.z + 1 }
	elseif door.side == "W" then
		return { x0 = -inner.x - 1, x1 = -inner.x + depth, z0 = door.along - h, z1 = door.along + h }
	end
	return { x0 = inner.x - depth, x1 = inner.x + 1, z0 = door.along - h, z1 = door.along + h }
end

-- Whether a prop is something people need: a hiding spot, the table, the
-- room's own light.
local function essential(prop): boolean
	local kind = Props.Kinds[prop.kind]
	return prop.key == true or prop.deliberation == true or (kind ~= nil and kind.hide ~= nil)
end

-- Rugs lie flat: they can go under things and across doorways. Everything
-- else, chairs included, needs its own floor space.
local function blocks(kind: string): boolean
	local info = Props.Kinds[kind]
	return info == nil or info.size[2] > 0.3
end

-- What a chair (or stool) belongs to: it moves with that piece, so a table
-- keeps its chairs round it when the room is squeezed.
local ANCHORS = { Table = true, DiningTable = true, Desk = true, Workbench = true, Piano = true }
local ANCHOR_REACH = 6

-- How wide a wall item is, for keeping it off furniture against its wall.
local function wallItemHalfWidth(item): number
	local decor = Props.WallDecor[item.kind or ""]
	if decor then
		return decor.size[1] / 2
	end
	return item.width and item.width / 2 or RoomFit.SlotHalf
end

-- Fit a template into a room.
--   source: the template's inner half extents { x, z } (19.5 for the 40x40
--           templates; a mansion-only template is authored at its own size)
--   inner:  the room's inner half extents { x, z }, in the template's frame
--   doors:  the room's doorways { side, along } in the template's frame
-- Returns copies of props, decor, wallSlots, floorSlots, shrine, spawns and
-- caseBoard, plus `dropped`: ids of what didn't fit.
function RoomFit.fit(template, source, inner, doors)
	local lanes = {}
	for _, door in doors do
		table.insert(lanes, lane(door, inner))
	end
	local function point(x: number, z: number): (number, number)
		return RoomFit.remap(x, source.x, inner.x), RoomFit.remap(z, source.z, inner.z)
	end
	local kept = {} -- boxes of solid props placed so far
	local dropped = {}
	-- The clear middle: everything further than the band from every wall (a
	-- narrower band when something sits at the heart, RoomFit.IslandBand).
	local band = RoomFit.Band
	for _, prop in template.props or {} do
		if prop.middle then
			band = RoomFit.IslandBand
		end
	end
	local mx, mz = math.max(0, inner.x - band), math.max(0, inner.z - band)
	local middle = { x0 = -mx, x1 = mx, z0 = -mz, z1 = mz }

	local function clear(
		cx: number,
		cz: number,
		ex: number,
		ez: number,
		isSolid: boolean,
		allowMiddle: boolean?
	): boolean
		if math.abs(cx) + ex > inner.x + 0.01 or math.abs(cz) + ez > inner.z + 0.01 then
			return false
		end
		local b = box(cx, cz, ex, ez)
		for _, l in lanes do
			if overlaps(b, l, 0) then
				return false
			end
		end
		if isSolid then
			-- (A `middle` prop, the dining table and its chairs, may sit there:
			-- the walkers' graph goes round it, Logic/NavGraph islands.)
			if not allowMiddle and overlaps(b, middle, 0) then
				return false
			end
			for _, k in kept do
				if overlaps(b, k, 0.2) then
					return false
				end
			end
		end
		return true
	end

	-- Slide a box along a wall (or across the room) from x, z until it is
	-- inside the room and clear of the lanes and of what is already placed.
	local function slide(
		x: number,
		z: number,
		ex: number,
		ez: number,
		isSolid: boolean,
		alongX: boolean,
		allowMiddle: boolean?
	)
		local reach = 2 * math.ceil(alongX and inner.x or inner.z)
		for step = 0, 2 * reach do
			local shift = (step % 2 == 0 and 1 or -1) * math.ceil(step / 2)
			local cx, cz = x, z
			if alongX then
				cx += shift
			else
				cz += shift
			end
			if clear(cx, cz, ex, ez, isSolid, allowMiddle) then
				return cx, cz
			end
		end
		return nil
	end

	-- Where a prop goes: along its own wall first; an essential one may then
	-- move to another wall (turned to face the room), and last anywhere on
	-- the floor nearest where it was. Returns x, z and its turn in degrees.
	local function place(prop, x: number, z: number, isSolid: boolean, wide: boolean)
		local ry = prop.ry or 0
		local allowMiddle = prop.middle == true
		local ex, ez = RoomFit.footprint(prop.kind, ry)
		local alongX = math.abs(z) / inner.z >= math.abs(x) / inner.x
		local px, pz
		if allowMiddle then
			-- At the heart: slid along whichever axis moves it least (a lane
			-- that reaches a stride too far needs a stride, not a wall).
			local ax, az = slide(x, z, ex, ez, isSolid, true, true)
			local bx, bz = slide(x, z, ex, ez, isSolid, false, true)
			local da = ax and (math.abs(ax - x) + math.abs(az - z)) or math.huge
			local db = bx and (math.abs(bx - x) + math.abs(bz - z)) or math.huge
			if da <= db then
				px, pz = ax, az
			else
				px, pz = bx, bz
			end
		else
			px, pz = slide(x, z, ex, ez, isSolid, alongX, allowMiddle)
		end
		if px or not wide then
			return px, pz, ry
		end
		-- Another wall, at the same distance from it.
		local gap = alongX and (inner.z - math.abs(z) - ez) or (inner.x - math.abs(x) - ex)
		if gap < RoomFit.Band then
			-- Facing the room first, then lengthways along the wall (a bed too
			-- long to stand out from a small room's wall lies along it).
			for _, quarter in { 0, 90 } do
				for _, side in { "N", "E", "S", "W" } do
					local turn = (WALL_TURN[side] + quarter) % 360
					local wx, wz = RoomFit.footprint(prop.kind, turn)
					local cx, cz, onX
					if side == "N" or side == "S" then
						cz = (side == "N" and -1 or 1) * (inner.z - gap - wz)
						cx, onX = 0, true
					else
						cx = (side == "W" and -1 or 1) * (inner.x - gap - wx)
						cz, onX = 0, false
					end
					local sx, sz = slide(cx, cz, wx, wz, isSolid, onX, allowMiddle)
					if sx then
						return sx, sz, turn
					end
				end
			end
		end
		-- Anywhere, nearest first.
		for _, offset in SPIRAL do
			local cx, cz = x + offset[1], z + offset[2]
			if clear(cx, cz, ex, ez, isSolid, allowMiddle) then
				return cx, cz, ry
			end
		end
		return nil
	end

	-- Chairs near a table, desk, bench or piano follow it.
	local anchorOf = {}
	for i, prop in template.props or {} do
		if prop.kind == "Chair" then
			local best, bestDistance = nil, ANCHOR_REACH
			for j, other in template.props do
				if ANCHORS[other.kind] then
					local distance = math.max(math.abs(other.x - prop.x), math.abs(other.z - prop.z))
					if distance < bestDistance then
						best, bestDistance = j, distance
					end
				end
			end
			anchorOf[i] = best
		end
	end

	local order = {}
	for i, prop in template.props or {} do
		local rank = essential(prop) and 1 or (anchorOf[i] and 3 or 2)
		table.insert(order, { prop = prop, index = i, rank = rank })
	end
	table.sort(order, function(a, b)
		if a.rank ~= b.rank then
			return a.rank < b.rank
		end
		return a.index < b.index
	end)
	local props = {}
	for _, entry in order do
		local prop = entry.prop
		local isSolid = blocks(prop.kind)
		local px, pz, ry
		local anchor = anchorOf[entry.index] and props[anchorOf[entry.index]]
		if anchorOf[entry.index] then
			-- Where its piece went, at the same offset (turned with the piece).
			if anchor then
				local original = template.props[anchorOf[entry.index]]
				local turn = math.rad((anchor.ry or 0) - (original.ry or 0))
				local dx, dz = prop.x - original.x, prop.z - original.z
				local c, s = math.cos(turn), math.sin(turn)
				local x = anchor.x + dx * c + dz * s
				local z = anchor.z - dx * s + dz * c
				ry = (prop.ry or 0) + math.deg(turn)
				local ex, ez = RoomFit.footprint(prop.kind, ry)
				-- (Chairs round a `middle` table sit in the middle with it.)
				if clear(x, z, ex, ez, isSolid, original.middle == true) then
					px, pz = x, z
				end
			end
		else
			local x, z = point(prop.x, prop.z)
			px, pz, ry = place(prop, x, z, isSolid, entry.rank == 1)
		end
		if px then
			local copy = table.clone(prop)
			copy.x, copy.z = px, pz
			if ry ~= (prop.ry or 0) then
				copy.ry = ry
			end
			props[entry.index] = copy
			if isSolid then
				local ex, ez = RoomFit.footprint(prop.kind, ry)
				table.insert(kept, box(px, pz, ex, ez))
			end
		else
			table.insert(dropped, prop.id)
		end
	end
	local propList = {}
	for i = 1, #(template.props or {}) do
		if props[i] then
			table.insert(propList, props[i])
		end
	end

	-- The Lantern shrine is a piece of furniture too.
	local shrine = nil
	if template.shrine then
		local ex, ez = RoomFit.footprint("Shrine", 0)
		local x, z = point(template.shrine.x, template.shrine.z)
		local px, pz = place({ kind = "Shrine" }, x, z, true, true)
		if px then
			shrine = { x = px, z = pz }
			table.insert(kept, box(px, pz, ex, ez))
		else
			table.insert(dropped, "shrine")
		end
	end

	-- Wall items: along their wall, clear of that wall's doorways and of
	-- each other (windows and decor first, so slots give way to them).
	local hung = { N = {}, S = {}, E = {}, W = {} }
	local function wallItem(item)
		if item.side == nil then
			return nil -- closet faces belong to the 40x40 corridors only
		end
		local copy = table.clone(item)
		local acrossX = item.side == "N" or item.side == "S"
		local half = wallItemHalfWidth(item)
		local limit = (acrossX and inner.x or inner.z) - math.max(3, half + 0.5)
		local function free(along: number): boolean
			if math.abs(along) > limit then
				return false
			end
			for _, door in doors do
				if door.side == item.side and math.abs(door.along - along) < RoomFit.WallItemClear then
					return false
				end
			end
			for _, other in hung[item.side] do
				if math.abs(other.along - along) < half + other.half + RoomFit.WallItemGap then
					return false
				end
			end
			-- Furniture standing against this wall, within the item's width.
			for _, k in kept do
				local near
				if item.side == "N" then
					near = k.z0 <= -inner.z + 3
				elseif item.side == "S" then
					near = k.z1 >= inner.z - 3
				elseif item.side == "W" then
					near = k.x0 <= -inner.x + 3
				else
					near = k.x1 >= inner.x - 3
				end
				local lo, hi = acrossX and k.x0 or k.z0, acrossX and k.x1 or k.z1
				if near and along + half + 0.3 > lo and along - half - 0.3 < hi then
					return false
				end
			end
			return true
		end
		local start = RoomFit.remap(item.along, acrossX and source.x or source.z, acrossX and inner.x or inner.z)
		start = math.clamp(start, -limit, limit)
		for step = 0, 2 * math.ceil(2 * limit) do
			local along = start + (step % 2 == 0 and 1 or -1) * math.ceil(step / 2) * 0.5
			if free(along) then
				copy.along = along
				table.insert(hung[item.side], { along = along, half = half })
				return copy
			end
		end
		return nil
	end
	local decor, wallSlots = {}, {}
	for _, item in template.decor or {} do
		local copy = wallItem(item)
		if copy then
			table.insert(decor, copy)
		else
			table.insert(dropped, item.id)
		end
	end
	for _, slot in template.wallSlots or {} do
		local copy = wallItem(slot)
		if copy then
			table.insert(wallSlots, copy)
		end
	end

	-- Floor points: clear of lanes and solid furniture.
	local function floorPoint(p, clearance: number)
		local x, z = point(p.x, p.z)
		local px, pz = slide(x, z, clearance, clearance, false, math.abs(z) / inner.z >= math.abs(x) / inner.x)
		if px == nil then
			return nil
		end
		local b = box(px, pz, clearance, clearance)
		for _, k in kept do
			if overlaps(b, k, 0) then
				return nil
			end
		end
		local copy = table.clone(p)
		copy.x, copy.z = px, pz
		return copy
	end
	local floorSlots = {}
	for _, slot in template.floorSlots or {} do
		local copy = floorPoint(slot, 1)
		if copy then
			table.insert(floorSlots, copy)
		end
	end
	local spawns = {}
	for _, spawn in template.spawns or {} do
		local x, z = point(spawn.x, spawn.z)
		table.insert(spawns, { x = x, z = z })
	end

	-- The Case Board must hang somewhere: its own spot if clear, else the
	-- nearest clear stretch of any wall.
	local caseBoard = nil
	if template.caseBoard then
		caseBoard = wallItem(template.caseBoard)
		local sides = { template.caseBoard.side, "N", "E", "S", "W" }
		for _, side in sides do
			if caseBoard then
				break
			end
			local acrossX = side == "N" or side == "S"
			local limit = (acrossX and inner.x or inner.z) - 5
			for step = 0, math.floor(2 * limit) do
				local along = (step % 2 == 0 and 1 or -1) * math.ceil(step / 2)
				local free = math.abs(along) <= limit
				for _, door in doors do
					if door.side == side and math.abs(door.along - along) < RoomFit.WallItemClear + 2 then
						free = false
					end
				end
				if free then
					caseBoard = { side = side, along = along }
					break
				end
			end
		end
	end

	return {
		props = propList,
		decor = decor,
		wallSlots = wallSlots,
		floorSlots = floorSlots,
		spawns = spawns,
		shrine = shrine,
		caseBoard = caseBoard,
		dropped = dropped,
	}
end

-- A mansion room's furniture as World/MansionBuilder lays it out: its
-- template fitted inside walls `wall` thick and clear of its doorways
-- (MansionHouse.fitDoors). Planners read the same fit (Logic/Dumbwaiter), so
-- they see the furniture the house will have. Returns the fit and the room's
-- inner half extents, in its own frame.
function RoomFit.inMansion(layout, room, template, wall: number)
	local inner = RoomRects.innerOf(room, room.rotation, wall)
	local source = template.mansion and template.mansion.authored and inner
		or { x = RoomFit.SourceInner, z = RoomFit.SourceInner }
	return RoomFit.fit(template, source, inner, MansionHouse.fitDoors(layout, room)), inner
end

return RoomFit
