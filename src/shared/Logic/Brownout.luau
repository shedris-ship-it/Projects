-- The generator's brownout, as a level of power over time (the owner's ask,
-- 2026-10-15; Controllers/MallController draws it on everything the
-- generator powers). It coughs: the power drops in an instant, stutters as
-- it catches and misses, then comes back with one last falter. Pure: the
-- stutter comes from the brownout's seed, so every client sees the same
-- one. "Reduce flicker" gets one smooth dip instead.

local Brownout = {}

local function smooth(x: number): number
	x = math.clamp(x, 0, 1)
	return x * x * (3 - 2 * x)
end

-- A cheap repeatable noise in [0, 1) for a step and a seed.
local function noise(step: number, seed: number): number
	local v = math.sin(step * 12.9898 + seed * 78.233) * 43758.5453
	return v - math.floor(v)
end

-- The power, 0 (out) to 1 (full), `t` seconds into a brownout that lasts
-- `seconds`. cfg = { Low, StutterHigh, Step } (Config.Mall.Brownout).
function Brownout.level(t: number, seconds: number, seed: number, cfg, gentle: boolean?): number
	if t <= 0 or t >= seconds then
		return 1
	end
	local low = cfg.Low
	if gentle then
		-- One soft dip down and back: never a flicker.
		local half = seconds / 2
		local x = t < half and smooth(t / half) or smooth((seconds - t) / half)
		return 1 - (1 - low) * x
	end
	local drop = seconds * 0.06 -- the cough: power falls away at once
	local recover = seconds * 0.72 -- the stutter ends here; then it comes back
	if t < drop then
		return 1 - (1 - low) * (t / drop)
	elseif t < recover then
		-- Catching and missing: a new level every Step seconds.
		local step = math.floor((t - drop) / cfg.Step)
		return low + (cfg.StutterHigh - low) * noise(step, seed)
	end
	-- Back up, with one last falter a third of the way.
	local x = (t - recover) / (seconds - recover)
	local level = low + (1 - low) * smooth(x)
	if x > 0.3 and x < 0.38 then
		level *= 0.55
	end
	return level
end

return Brownout
