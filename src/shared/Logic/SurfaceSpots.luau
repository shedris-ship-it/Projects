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

return SurfaceSpots
