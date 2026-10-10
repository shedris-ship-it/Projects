-- Where small things can stand on the top of a piece of furniture (World/
-- Dressing: photos, a telephone, clutter), worked out in the prop's own frame
-- so the rules are tests, not guesses (tests/specs/SurfaceSpots.spec.luau).
-- Owner, 2026-10-04: new props clipped into each other. Two causes this
-- fixes: spots over a counter's sink basin, and spots past the end of a top
-- that is shallower than its prop (a piano).

local SurfaceSpots = {}

local EDGE = 0.5 -- how far in from the edge of the top an object's middle stays

local function blocked(x: number, keepouts): boolean
	for _, k in keepouts do
		if x >= k.x0 and x <= k.x1 then
			return true
		end
	end
	return false
end

-- `kind` is a Data/Props entry ({ size, topSpan? }), `keepouts` a list of
-- { x0, x1 } spans to avoid, `cfg` is Config.Dressing (SpotWidth, Jitter).
-- Returns spots as { x, y, z, yaw } in the prop's frame, front facing +Z, in a
-- shuffled order. The random draws are the same with or without keep-outs, so
-- a keep-out on one prop never shifts what the rest of the house gets.
function SurfaceSpots.plan(rng, kind, keepouts, cfg)
	local w, h, d = kind.size[1], kind.size[2], kind.size[3]
	local near, far = -d / 2 + EDGE, d / 2 - EDGE
	if kind.topSpan then
		near, far = kind.topSpan[1] + EDGE, kind.topSpan[2] - EDGE
	end
	local count = math.max(1, math.floor((w - 0.6) / cfg.SpotWidth))
	local spots = {}
	for i = 1, count do
		local x = -w / 2 + 0.3 + (i - 0.5) * (w - 0.6) / count
		-- Towards the back half, away from the front edge.
		local z = math.clamp(rng:NextNumber(-d / 4, d / 8), near, far)
		-- Props face +Z in their own frame, so turn half round to face out.
		local yaw = math.pi + math.rad(rng:NextNumber(-cfg.Jitter, cfg.Jitter))
		table.insert(spots, { x = x, y = h, z = z, yaw = yaw })
	end
	rng:Shuffle(spots)
	-- Dropped last, after the shuffle, so a keep-out never changes how many
	-- random numbers were used.
	local kept = {}
	for _, spot in spots do
		if not blocked(spot.x, keepouts) then
			table.insert(kept, spot)
		end
	end
	return kept
end

-- Fitting things of their own size (the progression audit, 2026-10-10: the
-- home computer and the music box on the same spot of a desk; the house
-- plans' paper into a wall). A top keeps `used`, the stretches of its width
-- taken so far ({ x0, x1 } in the prop's frame, its keep-outs first).

SurfaceSpots.Gap = 0.12 -- studs kept between two things side by side

-- Does a thing `width` wide, centred at `x`, stand clear of everything on a
-- top `halfWidth` either side of its middle?
function SurfaceSpots.fits(x: number, width: number, used, halfWidth: number): boolean
	local x0, x1 = x - width / 2, x + width / 2
	if x0 < -halfWidth + 0.1 or x1 > halfWidth - 0.1 then
		return false
	end
	for _, u in used do
		if x1 + SurfaceSpots.Gap > u.x0 and x0 - SurfaceSpots.Gap < u.x1 then
			return false
		end
	end
	return true
end

-- Where along the top a thing `width` wide goes: the first of `candidates`
-- (spots' x, in the order they're handed out) where it fits, else the first
-- free stretch wide enough (left to right, hard against what's there), or nil.
function SurfaceSpots.findX(candidates: { number }, used, halfWidth: number, width: number): number?
	for _, x in candidates do
		if SurfaceSpots.fits(x, width, used, halfWidth) then
			return x
		end
	end
	local starts = { -halfWidth + 0.1 }
	for _, u in used do
		table.insert(starts, u.x1 + SurfaceSpots.Gap)
	end
	table.sort(starts)
	for _, start in starts do
		local x = start + width / 2
		if SurfaceSpots.fits(x, width, used, halfWidth) then
			return x
		end
	end
	return nil
end

-- Keep a thing `depth` deep on the top front to back: its middle `z` moved
-- just enough that it neither hangs off the front nor pokes into the wall
-- behind (`near`, `far`: the top's back and front edges in the prop's frame).
function SurfaceSpots.clampZ(z: number, depth: number, near: number, far: number): number
	local low, high = near + depth / 2 + 0.05, far - depth / 2 - 0.05
	if low > high then
		return (near + far) / 2
	end
	return math.clamp(z, low, high)
end

-- The top's back and front edges in the prop's frame.
function SurfaceSpots.depthSpan(kind): (number, number)
	local d = kind.size[3]
	if kind.topSpan then
		return kind.topSpan[1], kind.topSpan[2]
	end
	return -d / 2, d / 2
end

return SurfaceSpots
