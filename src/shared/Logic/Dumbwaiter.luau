-- Where a dumbwaiter can run (R2c, the two-person locks): a room on the
-- ground floor and the room above it that share a stretch of the same wall
-- line (the service corridor stacked over its twin, or any two rooms that
-- line up), with a spot on it well clear of both floors' doorways. Its
-- casing stands against that wall in both rooms; no hole in any floor.
-- Given the room templates, a spot must also be clear of the furniture both
-- rooms will have once furnished (Logic/RoomFit), so the build never finds
-- the wall taken (server/Puzzles/Dumbwaiter still checks, last).
-- Pure (tests/specs/Dumbwaiter.spec), in layout coordinates (studs from
-- Config.Level.Origin, x east, z south). Mansion layouts only.

local Props = require(script.Parent.Parent.Data.Props)
local RoomFit = require(script.Parent.RoomFit)
local RoomRects = require(script.Parent.RoomRects)

local Dumbwaiter = {}

local SIDES = { "N", "S", "W", "E" }

-- The line a side of a rect lies on, and which way is into the room.
local function side(rect, name: string)
	if name == "N" then
		return { line = rect.z, from = rect.x, to = rect.x + rect.w, into = { x = 0, z = 1 }, axis = "x" }
	elseif name == "S" then
		return { line = rect.z + rect.d, from = rect.x, to = rect.x + rect.w, into = { x = 0, z = -1 }, axis = "x" }
	elseif name == "W" then
		return { line = rect.x, from = rect.z, to = rect.z + rect.d, into = { x = 1, z = 0 }, axis = "z" }
	end
	return { line = rect.x + rect.w, from = rect.z, to = rect.z + rect.d, into = { x = -1, z = 0 }, axis = "z" }
end

-- Every doorway's middle on a floor, in layout coordinates.
local function doorways(layout)
	local list = {}
	for _, seam in layout.seams do
		if seam.connected and seam.dir and seam.line and seam.along then
			local x, z
			if seam.dir == "N" or seam.dir == "S" then
				x, z = seam.along, seam.line
			else
				x, z = seam.line, seam.along
			end
			table.insert(list, { x = x, z = z, floor = seam.floor or 0 })
		end
	end
	return list
end

local function box(ax: number, az: number, bx: number, bz: number, pad: number)
	return {
		x0 = math.min(ax, bx) - pad,
		x1 = math.max(ax, bx) + pad,
		z0 = math.min(az, bz) - pad,
		z1 = math.max(az, bz) + pad,
	}
end

-- What will stand in a room once it's furnished: its fitted furniture
-- (RoomFit.inMansion, as World/MansionBuilder builds it) as boxes
-- { x0, x1, z0, z1 } in layout coordinates. Only solid pieces: chairs and
-- rugs, which you walk through, are left out.
function Dumbwaiter.furniture(layout, room, templatesById, wall: number)
	local template = templatesById[room.template]
	if template == nil then
		return {}
	end
	local fitted = RoomFit.inMansion(layout, room, template, wall)
	local boxes = {}
	local function add(kind: string, x: number, z: number, ry: number?)
		local ex, ez = RoomFit.footprint(kind, ry)
		local ax, az = RoomRects.toWorld(room, room.rotation, x - ex, z - ez)
		local bx, bz = RoomRects.toWorld(room, room.rotation, x + ex, z + ez)
		table.insert(boxes, box(ax, az, bx, bz, 0))
	end
	for _, prop in fitted.props do
		local info = Props.Kinds[prop.kind]
		if info == nil or info.collide ~= false then
			add(prop.kind, prop.x, prop.z, prop.ry)
		end
	end
	if room.lantern then
		local shrine = fitted.shrine or { x = 0, z = 0 }
		add("Shrine", shrine.x, shrine.z, 0)
	end
	return boxes
end

-- The casing's footprint at a spot (server/Puzzles/Dumbwaiter builds it
-- there), padded by cfg.FurnitureClear: `Width` along the wall, `Depth` out
-- from `Inset` past the wall's line. Downstairs (`ground`) the crank and its
-- jam box widen it on the right as you face it.
function Dumbwaiter.footprint(spot, cfg, ground: boolean)
	local ix, iz = spot.into.x, spot.into.z
	local rx, rz = iz, -ix -- your right, facing the wall from the room
	local left, right = -cfg.Width / 2, cfg.Width / 2 + (ground and cfg.CrankSide or 0)
	local near, far = cfg.Inset, cfg.Inset + cfg.Depth
	return box(
		spot.x + rx * left + ix * near,
		spot.z + rz * left + iz * near,
		spot.x + rx * right + ix * far,
		spot.z + rz * right + iz * far,
		cfg.FurnitureClear
	)
end

local function overlaps(a, b): boolean
	return a.x0 < b.x1 and b.x0 < a.x1 and a.z0 < b.z1 and b.z0 < a.z1
end

-- Is a footprint clear of every box?
local function clearOf(footprint, boxes): boolean
	for _, other in boxes do
		if overlaps(footprint, other) then
			return false
		end
	end
	return true
end

-- Each room's furniture, fitted once and kept: room -> boxes.
local function furnisher(layout, templatesById, cfg)
	local cache = {}
	return function(room)
		local boxes = cache[room.id]
		if boxes == nil then
			boxes = Dumbwaiter.furniture(layout, room, templatesById, cfg.Wall)
			cache[room.id] = boxes
		end
		return boxes
	end
end

-- The spots between two rooms; `furnitureOf` (a furnisher, or nil to skip
-- the furniture) is only asked once a spot clears the doorways.
local function spotsOf(layout, ground, upper, cfg, furnitureOf)
	local doors = doorways(layout)
	-- Clear of both floors' furniture: downstairs the crank's side too.
	local function furnished(spot): boolean
		if furnitureOf == nil then
			return true
		end
		return clearOf(Dumbwaiter.footprint(spot, cfg, true), furnitureOf(ground))
			and clearOf(Dumbwaiter.footprint(spot, cfg, false), furnitureOf(upper))
	end
	local spots = {}
	for _, name in SIDES do
		local a, b = side(ground, name), side(upper, name)
		if a.line == b.line then
			local from, to = math.max(a.from, b.from) + cfg.EndClear, math.min(a.to, b.to) - cfg.EndClear
			local middle = (from + to) / 2
			local t = from
			while t <= to do
				local x = a.axis == "x" and t or a.line
				local z = a.axis == "x" and a.line or t
				local clear = true
				for _, door in doors do
					if math.abs((door.x - x)) + math.abs((door.z - z)) < cfg.DoorClear then
						clear = false
						break
					end
				end
				local spot = { x = x, z = z, side = name, into = a.into, score = math.abs(t - middle) }
				if clear and furnished(spot) then
					table.insert(spots, spot)
				end
				t += cfg.Step
			end
		end
	end
	table.sort(spots, function(p, q)
		if p.score ~= q.score then
			return p.score < q.score
		end
		return p.x + p.z * 0.001 < q.x + q.z * 0.001
	end)
	return spots
end

-- Spots for a dumbwaiter between `ground` (floor 0) and `upper` (floor 1),
-- best first: { x, z, side, into }. Empty when they share no wall. With
-- `templatesById`, only spots whose casing misses both rooms' furniture.
function Dumbwaiter.spots(layout, ground, upper, cfg, templatesById)
	return spotsOf(layout, ground, upper, cfg, templatesById and furnisher(layout, templatesById, cfg))
end

-- Every pair of rooms a dumbwaiter could join: { ground, upper } ids, in a
-- fixed order. Not the tall rooms (the hall, stairwells). With
-- `templatesById`, only pairs with a spot clear of their furniture.
function Dumbwaiter.pairs(layout, cfg, templatesById)
	if layout.mode ~= "Mansion" then
		return {}
	end
	local furnitureOf = templatesById and furnisher(layout, templatesById, cfg)
	local grounds, uppers = {}, {}
	for _, room in layout.rooms do
		if not room.tall and room.w and room.d then
			if (room.floor or 0) == 0 then
				table.insert(grounds, room)
			elseif room.floor == 1 then
				table.insert(uppers, room)
			end
		end
	end
	table.sort(grounds, function(p, q)
		return p.id < q.id
	end)
	table.sort(uppers, function(p, q)
		return p.id < q.id
	end)
	local list = {}
	for _, ground in grounds do
		for _, upper in uppers do
			if ground.id ~= layout.start and ground.id ~= layout.deliberation then
				if #spotsOf(layout, ground, upper, cfg, furnitureOf) > 0 then
					table.insert(list, { ground = ground.id, upper = upper.id })
				end
			end
		end
	end
	return list
end

return Dumbwaiter
