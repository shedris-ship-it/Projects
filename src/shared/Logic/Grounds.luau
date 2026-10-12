-- Where the grounds' plants stand round a mansion (the visual rework V2; the
-- owner, 2026-10-12, after seeing the night through the new windows: "I would
-- just want more dense foliage out there"). In layout coordinates; World/
-- Exterior builds them from parts and fills the lawn with terrain grass.
--
-- - The woods: a jittered grid of trees, most still in leaf (late October),
--   from a short lawn round the house to the edge of the grounds, thickest at
--   the back; undergrowth between them, a few bushes out on the lawn.
-- - The garden: low shrubs along the house's outside walls (courtyards too),
--   their tops under the windowsills, and tall narrow evergreens only between
--   windows, so every window still looks out.
-- - Nothing in or under the house, on the drive or before the front door.
--
-- Pure: rooms, the front door, window spots and a seeded Rng in, a list of
-- plants out. Grounds.spec checks the rules and the part budget.

local RoomRects = require(script.Parent.RoomRects)

local Grounds = {}

local DIRS = {
	N = { 0, -1 },
	E = { 1, 0 },
	S = { 0, 1 },
	W = { -1, 0 },
}

-- The most parts World/Exterior builds for each kind of plant, near the house
-- and far out in the fog, where a plant is a silhouette and fewer, bigger
-- masses read the same (the budget's arithmetic; Exterior keeps to these).
Grounds.Parts = {
	leafy = { near = 1 + 2 + 7, far = 1 + 1 + 4 }, -- a trunk, limbs, masses of leaves
	bare = { near = 1 + 7, far = 1 + 4 }, -- a trunk and branches
	conifer = { near = 1 + 3, far = 1 + 2 }, -- a trunk and tiers of needles
	bush = { near = 3, far = 2 },
	shrub = { near = 3, far = 3 },
	column = { near = 2, far = 2 },
}

-- The house's rectangles on the ground floor (rooms and passages that stand
-- on it), as { x0, z0, x1, z1 }.
function Grounds.footprint(rooms): { { number } }
	local rects = {}
	for _, room in rooms do
		local low, top = room.floor or 0, RoomRects.topOf(room)
		if low <= 0 and top >= 0 then
			table.insert(rects, { room.x, room.z, room.x + room.w, room.z + room.d })
		end
	end
	return rects
end

local function distanceTo(rect, x: number, z: number): number
	local dx = math.max(rect[1] - x, 0, x - rect[3])
	local dz = math.max(rect[2] - z, 0, z - rect[4])
	return math.sqrt(dx * dx + dz * dz)
end

-- Distance from (x, z) to the nearest part of the house (0 inside it).
function Grounds.distance(rects, x: number, z: number): number
	local best = math.huge
	for _, rect in rects do
		best = math.min(best, distanceTo(rect, x, z))
	end
	return best
end

-- The front door's point and the drive's direction, in layout coordinates.
function Grounds.door(front)
	if not front then
		return nil
	end
	local x, z = RoomRects.doorPoint(front.dir, front.line, front.along)
	local d = DIRS[front.dir]
	return { x = x, z = z, dx = d[1], dz = d[2] }
end

-- Whether (x, z) is on the drive (or within `pad` of it), from the front door
-- out to the streetlamp and a little past.
function Grounds.onDrive(door, cfg, x: number, z: number, pad: number): boolean
	if not door then
		return false
	end
	local rx, rz = x - door.x, z - door.z
	local ahead = rx * door.dx + rz * door.dz
	local across = math.abs(rx * -door.dz + rz * door.dx)
	return ahead > -4 and ahead < cfg.DriveLength + 12 and across < cfg.DriveWidth / 2 + pad
end

-- The plants: a list of { kind, x, z, size, far, clear }. `size` is a tree's height,
-- a bush's or shrub's scale (1 = the configured size), a column's height;
-- `far`: out past cfg.FarFrom, built plainer; `clear`: studs to the house,
-- which no part of the plant may reach.
-- house: { rooms, frontDoor }; windows: { { x, z } } (any storey); cfg:
-- Config.Exterior; rng: Lib/Rng.
function Grounds.plan(house, windows, cfg, rng)
	local rects = Grounds.footprint(house.rooms)
	local plants = {}
	if #rects == 0 then
		return plants, rects
	end
	local x0, z0, x1, z1 = math.huge, math.huge, -math.huge, -math.huge
	for _, r in rects do
		x0, z0 = math.min(x0, r[1]), math.min(z0, r[2])
		x1, z1 = math.max(x1, r[3]), math.max(z1, r[4])
	end
	local door = Grounds.door(house.frontDoor)

	-- The woods.
	local step = cfg.TreeSpacing
	for gx = x0 - cfg.Reach, x1 + cfg.Reach, step do
		for gz = z0 - cfg.Reach, z1 + cfg.Reach, step do
			local x = gx + rng:NextNumber(-step * 0.45, step * 0.45)
			local z = gz + rng:NextNumber(-step * 0.45, step * 0.45)
			local away = Grounds.distance(rects, x, z)
			local chance = math.clamp((away - cfg.LawnClear) / cfg.ThickAfter, 0, 1) * cfg.Density
			local roll = rng:NextNumber()
			-- What grows there: a dark conifer now and then, young trees under
			-- the old, the rest old trees mostly still in leaf (a skyline of
			-- many heights, never one row of crowns).
			local kindRoll = rng:NextNumber()
			local leafy = rng:NextNumber() < cfg.LeafShare
			local height = rng:NextNumber(cfg.TreeHeight[1], cfg.TreeHeight[2])
			local young = rng:NextNumber(cfg.YoungHeight[1], cfg.YoungHeight[2])
			local kind = leafy and "leafy" or "bare"
			if kindRoll < cfg.ConiferShare then
				kind, height = "conifer", height * 1.1
			elseif kindRoll < cfg.ConiferShare + cfg.YoungShare then
				kind, height = "leafy", young
			end
			if
				away >= cfg.LawnClear
				and away <= cfg.Reach
				and roll < chance
				and not Grounds.onDrive(door, cfg, x, z, 5)
			then
				table.insert(plants, {
					kind = kind,
					x = x,
					z = z,
					size = height,
					far = away > cfg.FarFrom,
					clear = away,
				})
			end
		end
	end

	-- The undergrowth: thick in the woods, a few bushes out on the lawn.
	local U = cfg.Undergrowth
	for gx = x0 - cfg.Reach, x1 + cfg.Reach, U.Spacing do
		for gz = z0 - cfg.Reach, z1 + cfg.Reach, U.Spacing do
			local x = gx + rng:NextNumber(-U.Spacing * 0.45, U.Spacing * 0.45)
			local z = gz + rng:NextNumber(-U.Spacing * 0.45, U.Spacing * 0.45)
			local away = Grounds.distance(rects, x, z)
			local ramp = math.clamp((away - U.From) / U.Ramp, 0, 1)
			local chance = U.Density * (U.Lawn + (1 - U.Lawn) * ramp)
			local roll = rng:NextNumber()
			local scale = 0.75 + 0.5 * ramp + rng:NextNumber(-0.15, 0.25)
			if away >= U.From and away <= cfg.Reach and roll < chance and not Grounds.onDrive(door, cfg, x, z, 2.5) then
				table.insert(
					plants,
					{ kind = "bush", x = x, z = z, size = scale, far = away > cfg.FarFrom, clear = away }
				)
			end
		end
	end

	-- The garden along the outside walls.
	local G = cfg.Garden
	local function nearWindow(x: number, z: number): boolean
		for _, w in windows do
			local dx, dz = w.x - x, w.z - z
			if dx * dx + dz * dz < G.WindowClear * G.WindowClear then
				return true
			end
		end
		return false
	end
	for _, r in rects do
		-- Each side: its start, its direction along, and outward.
		local sides = {
			{ r[1], r[2], 1, 0, 0, -1, r[3] - r[1] }, -- north
			{ r[1], r[4], 1, 0, 0, 1, r[3] - r[1] }, -- south
			{ r[1], r[2], 0, 1, -1, 0, r[4] - r[2] }, -- west
			{ r[3], r[2], 0, 1, 1, 0, r[4] - r[2] }, -- east
		}
		for _, s in sides do
			local sx, sz, ax, az, ox, oz, length = table.unpack(s)
			local t = rng:NextNumber(0.5, G.Step)
			while t < length - 0.5 do
				local x = sx + ax * t + ox * G.Gap
				local z = sz + az * t + oz * G.Gap
				local roll = rng:NextNumber()
				local tall = rng:NextNumber() < G.ColumnShare
				local size = tall and rng:NextNumber(G.ColumnHeight[1], G.ColumnHeight[2]) or rng:NextNumber(0.8, 1.15)
				local clear = Grounds.distance(rects, x, z)
				local outside = clear >= G.Gap - 0.3
				local clearOfDoor = not door or math.sqrt((x - door.x) ^ 2 + (z - door.z) ^ 2) > G.DoorClear
				if roll < G.Share and outside and clearOfDoor and not Grounds.onDrive(door, cfg, x, z, 1.5) then
					if tall and not nearWindow(x, z) then
						table.insert(plants, { kind = "column", x = x, z = z, size = size, clear = clear })
					else
						table.insert(plants, { kind = "shrub", x = x, z = z, size = tall and 1 or size, clear = clear })
					end
				end
				t += G.Step * rng:NextNumber(0.8, 1.2)
			end
		end
	end
	return plants, rects
end

-- How many parts the plants come to at most (World/Exterior's budget).
function Grounds.parts(plants): number
	local n = 0
	for _, plant in plants do
		local parts = Grounds.Parts[plant.kind]
		n += plant.far and parts.far or parts.near
	end
	return n
end

return Grounds
