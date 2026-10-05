-- Where a dumbwaiter can run (R2c, the two-person locks): a room on the
-- ground floor and the room above it that share a stretch of the same wall
-- line (the service corridor stacked over its twin, or any two rooms that
-- line up), with a spot on it well clear of both floors' doorways. Its
-- casing stands against that wall in both rooms; no hole in any floor.
-- Pure (tests/specs/Dumbwaiter.spec), in layout coordinates (studs from
-- Config.Level.Origin, x east, z south). Mansion layouts only.

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

-- Spots for a dumbwaiter between `ground` (floor 0) and `upper` (floor 1),
-- best first: { x, z, side, into }. Empty when they share no wall.
function Dumbwaiter.spots(layout, ground, upper, cfg)
	local doors = doorways(layout)
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
				if clear then
					table.insert(spots, { x = x, z = z, side = name, into = a.into, score = math.abs(t - middle) })
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

-- Every pair of rooms a dumbwaiter could join: { ground, upper } ids, in a
-- fixed order. Not the tall rooms (the hall, stairwells).
function Dumbwaiter.pairs(layout, cfg)
	if layout.mode ~= "Mansion" then
		return {}
	end
	local grounds, uppers = {}, {}
	for _, room in layout.rooms do
		if not room.tall and room.w and room.d then
			if (room.floor or 0) == 0 then
				table.insert(grounds, room)
			else
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
				if #Dumbwaiter.spots(layout, ground, upper, cfg) > 0 then
					table.insert(list, { ground = ground.id, upper = upper.id })
				end
			end
		end
	end
	return list
end

return Dumbwaiter
