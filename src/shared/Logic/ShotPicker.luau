-- Where a cutscene camera can stand (the visual rework V8; the owner,
-- 2026-10-15, after Threshold: "the camera would have to be smart enough to
-- avoid going somewhere you cant see the animation happen"). It tries a ring
-- of places round what it films, at a few distances and heights, and keeps
-- the best one that has a clear line to everything that must be seen and
-- that it could reach from the middle of the scene without passing through
-- a wall. The caller says what "clear" means (Controllers/CinemaController
-- sweeps a ball through the house); the shots cut between places, never
-- swing through walls.
--
-- Pure: points are { x, y, z } tables, and lune tests it with a made-up room.

local ShotPicker = {}

local sqrt, cos, sin, pi = math.sqrt, math.cos, math.sin, math.pi

local function sub(a, b)
	return { a[1] - b[1], a[2] - b[2], a[3] - b[3] }
end

local function len(a): number
	return sqrt(a[1] * a[1] + a[2] * a[2] + a[3] * a[3])
end

-- How close the segment a -> b passes to a point.
local function passes(a, b, p): number
	local ab = sub(b, a)
	local ap = sub(p, a)
	local l2 = ab[1] * ab[1] + ab[2] * ab[2] + ab[3] * ab[3]
	local t = l2 > 1e-9 and math.clamp((ap[1] * ab[1] + ap[2] * ab[2] + ap[3] * ab[3]) / l2, 0, 1) or 0
	return len(sub(p, { a[1] + ab[1] * t, a[2] + ab[2] * t, a[3] + ab[3] * t }))
end
ShotPicker.passes = passes

-- Whether a body (a blocker: { point, radius }) stands between a place and
-- what it must see: the people in the scene hide each other too.
function ShotPicker.hidden(from, subject, blockers): boolean
	for _, b in blockers or {} do
		local d = len(sub(b[1], subject))
		if d > b[2] and passes(from, subject, b[1]) < b[2] then
			return true
		end
	end
	return false
end

-- The places tried: `angles` bearings round `centre`, at each of `radii` and
-- `heights` (heights are absolute, kept between the floor and the ceiling).
function ShotPicker.ring(opts)
	local centre = opts.centre or opts.focus
	local list = {}
	local n = opts.angles or 16
	local floorY = opts.floor or -math.huge
	local ceilingY = opts.ceiling or math.huge
	for i = 0, n - 1 do
		local a = (i / n) * 2 * pi
		local bx, bz = sin(a), -cos(a)
		for _, r in opts.radii do
			for _, h in opts.heights do
				local y = math.clamp(h, floorY + 0.5, ceilingY - 0.6)
				table.insert(
					list,
					{ position = { centre[1] + bx * r, y, centre[3] + bz * r }, bearing = { bx, bz }, radius = r }
				)
			end
		end
	end
	return list
end

-- How good a place is (higher is better): the bearing we'd like most, then
-- the distance and height we'd like.
local function score(opts, c): number
	local s = 0
	local prefer = opts.prefer
	if prefer then
		local d = c.bearing[1] * prefer[1] + c.bearing[2] * prefer[2]
		s += 3 * d
	end
	if opts.preferRadius then
		s -= 0.6 * math.abs(c.radius - opts.preferRadius)
	end
	if opts.preferHeight then
		s -= 0.4 * math.abs(c.position[2] - opts.preferHeight)
	end
	return s
end

-- The best place, or nil if none sees everything. opts:
--   focus     what the camera looks at
--   subjects  points that must all be in clear sight (default: the focus)
--   centre    the ring's middle (default: the focus); the camera must be
--             able to get there from it in a straight line
--   radii, heights, angles, floor, ceiling: the ring
--   prefer    { x, z }: the bearing from the centre we'd most like
--   preferRadius, preferHeight
--   clear     function(a, b): true when nothing stands between a and b
--   avoid     { x, y, z }: never closer than `avoidRadius` to this (the
--             camera mustn't stand inside a body)
--   blockers  { { point, radius } }: bodies that mustn't stand between the
--             camera and a subject (one of them hiding the other's face)
--   cone      { x, z, cos }: only bearings within this cone (a face is
--             filmed from in front of it, never the back of the head)
function ShotPicker.pick(opts)
	local clear = opts.clear
	local centre = opts.centre or opts.focus
	local subjects = opts.subjects or { opts.focus }
	local candidates = ShotPicker.ring(opts)
	if opts.cone then
		local kept = {}
		for _, c in candidates do
			if c.bearing[1] * opts.cone[1] + c.bearing[2] * opts.cone[2] >= opts.cone[3] then
				table.insert(kept, c)
			end
		end
		candidates = kept
	end
	for _, c in candidates do
		c.score = score(opts, c)
	end
	table.sort(candidates, function(a, b)
		return a.score > b.score
	end)
	for _, c in candidates do
		local p = c.position
		local ok = true
		if opts.avoid and len(sub(p, opts.avoid)) < (opts.avoidRadius or 1.2) then
			ok = false
		end
		if ok and not clear(centre, p) then
			ok = false
		end
		if ok then
			for _, subject in subjects do
				if not clear(p, subject) or ShotPicker.hidden(p, subject, opts.blockers) then
					ok = false
					break
				end
			end
		end
		if ok then
			return { position = p, focus = opts.focus, score = c.score, bearing = c.bearing }
		end
	end
	return nil
end

-- The bearing (flat, unit) from `a` to `b`, turned `angle` radians (positive:
-- anticlockwise seen from above).
function ShotPicker.bearing(a, b, angle: number?)
	local x, z = b[1] - a[1], b[3] - a[3]
	local l = sqrt(x * x + z * z)
	if l < 1e-6 then
		x, z = 0, -1
	else
		x, z = x / l, z / l
	end
	local t = angle or 0
	local c, s = cos(t), sin(t)
	return { x * c + z * s, -x * s + z * c }
end

return ShotPicker
