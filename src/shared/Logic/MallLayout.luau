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

-- Half a block's size along x, y and z, as built (a Cylinder stands upright:
-- its first size is its height). A turned block gives the box round it,
-- turned as MallBuilder turns it (CFrame.Angles: x of y of z).
local function halves(b)
	local s = b.size
	local h
	if b.shape == "Cylinder" then
		h = { s[2] / 2, s[1] / 2, s[3] / 2 }
	else
		h = { s[1] / 2, s[2] / 2, s[3] / 2 }
	end
	if not b.rot then
		return h[1], h[2], h[3]
	end
	local a, c, e = math.rad(b.rot[1] or 0), math.rad(b.rot[2] or 0), math.rad(b.rot[3] or 0)
	local ca, sa, cb, sb, cc, sc = math.cos(a), math.sin(a), math.cos(c), math.sin(c), math.cos(e), math.sin(e)
	local r = {
		{ cb * cc, -cb * sc, sb },
		{ ca * sc + sa * sb * cc, ca * cc - sa * sb * sc, -sa * cb },
		{ sa * sc - ca * sb * cc, sa * cc + ca * sb * sc, ca * cb },
	}
	local out = {}
	for i = 1, 3 do
		out[i] = math.abs(r[i][1]) * h[1] + math.abs(r[i][2]) * h[2] + math.abs(r[i][3]) * h[3]
	end
	return out[1], out[2], out[3]
end

-- What stands in front of an ad's face (Roblox serves an ad only to a face
-- nothing covers): every column, and every solid block or sign whose box
-- reaches into the space `depth` studs out from the face, as tall as it and
-- widening as it goes out (seen from up to 45 degrees off its face, or the
-- ad's own `fan`), in its own room and the one it's seen from (`through`).
-- Names, for a test to show; none for a good layout.
function MallLayout.adBlockers(mall, depth: number): { string }
	local found = {}
	local out = { E = { 1, 0 }, W = { -1, 0 }, N = { 0, -1 }, S = { 0, 1 } }
	for _, ad in mall.Ads or {} do
		local d = out[ad.face]
		local spread = math.tan(math.rad(ad.fan or 45)) -- sideways per stud out
		-- The box round the fan in front of the face, on the floor plan.
		local ax0, ax1, az0, az1
		if d[1] ~= 0 then
			ax0, ax1 = math.min(ad.x, ad.x + d[1] * depth), math.max(ad.x, ad.x + d[1] * depth)
			az0, az1 = ad.z - ad.w / 2 - depth * spread, ad.z + ad.w / 2 + depth * spread
		else
			az0, az1 = math.min(ad.z, ad.z + d[2] * depth), math.max(ad.z, ad.z + d[2] * depth)
			ax0, ax1 = ad.x - ad.w / 2 - depth * spread, ad.x + ad.w / 2 + depth * spread
		end
		local ay0, ay1 = ad.y - ad.h / 2, ad.y + ad.h / 2
		local function hit(x0, x1, y0, y1, z0, z1)
			if not (x1 > ax0 and x0 < ax1 and z1 > az0 and z0 < az1 and y1 > ay0 and y0 < ay1) then
				return false
			end
			-- How far out its far side is (the fan is widest there), and its
			-- sideways extent against the face's, widened by that.
			local far, s0, s1, f0, f1
			if d[1] ~= 0 then
				far = math.min(depth, d[1] > 0 and x1 - ad.x or ad.x - x0)
				s0, s1, f0, f1 = z0, z1, ad.z - ad.w / 2, ad.z + ad.w / 2
			else
				far = math.min(depth, d[2] > 0 and z1 - ad.z or ad.z - z0)
				s0, s1, f0, f1 = x0, x1, ad.x - ad.w / 2, ad.x + ad.w / 2
			end
			return s1 > f0 - far * spread and s0 < f1 + far * spread
		end
		local function near(room: string): boolean
			return room == ad.room or room == ad.through
		end
		for _, b in mall.Blocks or {} do
			if near(b.room) and b.collide ~= false then
				local hx, hy, hz = halves(b)
				if hit(b.x - hx, b.x + hx, b.y - hy, b.y + hy, b.z - hz, b.z + hz) then
					table.insert(found, string.format("%s in front of %s", b.name, ad.slot or "an ad"))
				end
			end
		end
		-- A sign's panel, flat against the way it faces (one on the floor is
		-- walked over, never in the way).
		for _, sign in mall.Signs or {} do
			if near(sign.room) and sign.face ~= "UP" then
				local across = (sign.face == "N" or sign.face == "S")
				local hx = across and sign.w / 2 or 0.1
				local hz = across and 0.1 or sign.w / 2
				local hy = sign.h / 2
				if hit(sign.x - hx, sign.x + hx, sign.y - hy, sign.y + hy, sign.z - hz, sign.z + hz) then
					table.insert(found, string.format("the sign %q in front of %s", sign.text, ad.slot or "an ad"))
				end
			end
		end
		for _, g in mall.Galleries or {} do
			if near(g.room) then
				for _, c in g.columns or {} do
					if hit(c[1] - 1, c[1] + 1, 0, g.level, c[2] - 1, c[2] + 1) then
						table.insert(found, string.format("a column in front of %s", ad.slot or "an ad"))
					end
				end
			end
		end
	end
	return found
end

-- Solid blocks a gallery's column stands in (a column is two studs across,
-- floor to gallery), and columns in front of a shopfront rather than on the
-- wall between two: a column before a sign hides it. Sentences; none for a
-- good layout.
function MallLayout.columnClashes(mall): { string }
	local found = {}
	for _, g in mall.Galleries or {} do
		local room = mall.Rooms[g.room]
		for _, c in g.columns or {} do
			local cx, cz = c[1], c[2]
			for _, b in mall.Blocks or {} do
				if b.room == g.room and b.collide ~= false then
					local hx, hy, hz = halves(b)
					if
						cx + 1 > b.x - hx
						and cx - 1 < b.x + hx
						and cz + 1 > b.z - hz
						and cz - 1 < b.z + hz
						and b.y - hy < g.level
					then
						table.insert(found, string.format("%s stands in the column at %d, %d", b.name, cx, cz))
					end
				end
			end
			-- The fronts on the wall behind the gallery edge it stands on.
			for _, side in room and MallLayout.sides(room.rect) or {} do
				local edge = side.at + side.inward * (g.depth or 0)
				local across, along = cz, cx
				if side.runs == "z" then
					across, along = cx, cz
				end
				if table.find(g.sides or {}, side.side) and math.abs(across - edge) < 1.5 then
					for _, door in mall.Doors do
						if
							door.runs == side.runs
							and same(door.at, side.at)
							and (door.a == g.room or door.b == g.room)
							and door.kind ~= "shutter"
							and along + 1 > door.from
							and along - 1 < door.to
						then
							table.insert(found, string.format("the column at %d, %d hides a front", cx, cz))
						end
					end
				end
			end
		end
	end
	return found
end

-- What's carelessly placed in `rooms` (the shops, laid out by hand; the
-- owner, 2026-10-15: "be very deliberate with placement in the shops"): a
-- solid block through its room's walls or the floor, two solid blocks in
-- one another (touching is fine: a TV on its counter), or one standing in
-- the way through a door, 3 studs in from the opening, unless it's a
-- `window` display put there on purpose. Sentences; none for a good layout.
function MallLayout.misplaced(mall, rooms: { string }): { string }
	local found = {}
	local t = mall.Wall or 1
	local eps = 0.05
	local boxes = {}
	for _, b in mall.Blocks do
		if table.find(rooms, b.room) and b.collide ~= false then
			local hx, hy, hz = halves(b)
			table.insert(boxes, {
				b = b,
				lo = { b.x - hx, b.y - hy, b.z - hz },
				hi = { b.x + hx, b.y + hy, b.z + hz },
			})
		end
	end
	local function where(b)
		return string.format("%s's %s at %g, %g", b.room, b.name, b.x, b.z)
	end
	for i, a in boxes do
		local r = mall.Rooms[a.b.room].rect
		if
			a.lo[1] < r[1] + t - eps
			or a.hi[1] > r[3] - t + eps
			or a.lo[3] < r[2] + t - eps
			or a.hi[3] > r[4] - t + eps
			or a.lo[2] < -eps
		then
			table.insert(found, where(a.b) .. " goes through a wall or the floor")
		end
		for j = i + 1, #boxes do
			local c = boxes[j]
			local inside = c.b.room == a.b.room
			for k = 1, 3 do
				inside = inside and math.min(a.hi[k], c.hi[k]) - math.max(a.lo[k], c.lo[k]) > eps
			end
			if inside then
				table.insert(found, where(a.b) .. " and " .. where(c.b) .. " stand in each other")
			end
		end
		if not a.b.window then
			for _, door in mall.Doors do
				if door.a == a.b.room or door.b == a.b.room then
					for _, side in MallLayout.sides(r) do
						if side.runs == door.runs and same(side.at, door.at) then
							-- The lane: the opening's width, from the wall's
							-- inner face 3 studs into the room.
							local near, far = side.at + side.inward * t, side.at + side.inward * (t + 3)
							local c0, c1 = math.min(near, far), math.max(near, far)
							local across, along = 3, 1
							if door.runs == "z" then
								across, along = 1, 3
							end
							if
								math.min(a.hi[across], c1) - math.max(a.lo[across], c0) > eps
								and math.min(a.hi[along], door.to) - math.max(a.lo[along], door.from) > eps
							then
								table.insert(found, where(a.b) .. " stands in the way through a door")
							end
						end
					end
				end
			end
		end
	end
	return found
end

-- Open floor in a room, as {x, z} points on a grid `spacing` apart: inside
-- its walls by `margin`, and at least `margin` from every solid block's box
-- and every gallery column. Where people can stand (F2 `crowd`, LB1b's
-- 50-player measurement), west to east, north to south.
function MallLayout.openSpots(mall, roomId: string, spacing: number, margin: number): { { number } }
	local rect = mall.Rooms[roomId].rect
	local t = mall.Wall or 1
	local boxes = {}
	for _, b in mall.Blocks do
		if b.room == roomId and b.collide ~= false then
			local hx, _, hz = halves(b)
			table.insert(boxes, { b.x - hx - margin, b.z - hz - margin, b.x + hx + margin, b.z + hz + margin })
		end
	end
	for _, g in mall.Galleries or {} do
		if g.room == roomId then
			for _, c in g.columns or {} do
				table.insert(
					boxes,
					{ c[1] - 1.4 - margin, c[2] - 1.4 - margin, c[1] + 1.4 + margin, c[2] + 1.4 + margin }
				)
			end
		end
	end
	local spots = {}
	local x0, z0, x1, z1 = rect[1] + t + margin, rect[2] + t + margin, rect[3] - t - margin, rect[4] - t - margin
	local x = x0
	while x <= x1 + 1e-6 do
		local z = z0
		while z <= z1 + 1e-6 do
			local clear = true
			for _, box in boxes do
				if x > box[1] and x < box[3] and z > box[2] and z < box[4] then
					clear = false
					break
				end
			end
			if clear then
				table.insert(spots, { x, z })
			end
			z += spacing
		end
		x += spacing
	end
	return spots
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
