-- What is outside each window (owner, 2026-10-04: the painted night with a
-- disc moon in the same place in every window was "cartoony"). One moon per run
-- sits in a fixed compass direction; a window shows it only if it looks that
-- way, and where it sits in the pane follows the angle, so the house agrees
-- with itself. Each window also gets a covering (bare, sheer curtain, blinds or
-- boards) from the seed. Pure and seeded (tests/specs/WindowView.spec.luau).
--
-- Azimuths are compass degrees in the world: 0 is north (-Z), 90 east (+X),
-- 180 south, 270 west, growing clockwise seen from above.

local WindowView = {}

-- The compass direction of a horizontal vector (x, z), in degrees 0 to 360.
function WindowView.azimuth(x: number, z: number): number
	return math.deg(math.atan2(x, -z)) % 360
end

-- The signed difference `to - from`, folded into -180 to 180.
function WindowView.angleDiff(from: number, to: number): number
	return (to - from + 180) % 360 - 180
end

-- The run's moon: a compass direction and a height in the sky.
function WindowView.moon(rng, cfg)
	return {
		azimuth = rng:NextNumber(0, 360),
		elevation = rng:NextNumber(cfg.MoonElevation[1], cfg.MoonElevation[2]),
	}
end

-- Pick one of the weighted covers, in a fixed order so a seed is stable.
local COVER_ORDER = { "bare", "sheer", "blinds", "boards" }

local function pickCover(rng, weights): string
	local total = 0
	for _, name in COVER_ORDER do
		total += weights[name] or 0
	end
	local roll = rng:NextNumber(0, total)
	for _, name in COVER_ORDER do
		roll -= weights[name] or 0
		if roll <= 0 then
			return name
		end
	end
	return "bare"
end

-- What one window shows. `outward` is the compass direction it looks out
-- towards. Returns { cover, moonVisible, moonX, moonY } where moonX and moonY
-- are fractions of the pane (0 left/top to 1 right/bottom).
function WindowView.view(rng, outward: number, moon, cfg)
	local cover = pickCover(rng, cfg.Covers)
	local diff = WindowView.angleDiff(outward, moon.azimuth)
	local visible = math.abs(diff) <= cfg.MoonHalfView
	-- Looking out, a moon clockwise of straight ahead is on your right. Higher
	-- in the sky is higher in the pane.
	local x = 0.5 + (diff / cfg.MoonHalfView) * 0.38
	local y = 0.62 - (moon.elevation / 90) * 0.9
	return {
		cover = cover,
		moonVisible = visible,
		moonX = math.clamp(x, 0.08, 0.92),
		moonY = math.clamp(y, 0.1, 0.6),
	}
end

return WindowView
