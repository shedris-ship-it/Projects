-- The lens's rules (the visual rework V1, 2026-10-12: P.T. on 35mm film).
-- Pure, so Controllers/LensController only draws what these say; spec'd in
-- Lens.spec. cfg is Config.Lens.

local Lens = {}

-- Grain ------------------------------------------------------------------

-- Film runs at 24 frames a second whatever the screen does: the grain
-- changes on a clock, not once a rendered frame (at 144 fps the old grain
-- boiled; at 30 it crawled).
function Lens.grainTick(clock: number, fps: number): number
	return math.floor(clock * fps)
end

-- Park-Miller steps (as Lib/Rng): every product stays well inside a double.
local MOD = 2147483647
local function step(n: number): number
	return (n * 48271) % MOD
end

-- Which frame, and where it is shifted to, for a tick: the same tick always
-- looks the same, and neighbouring ticks share nothing a player could see.
function Lens.grainPick(tick: number, frames: number, size: number): (number, number, number)
	local n = (math.abs(tick) % (MOD - 1)) + 1
	n = step(step(step(n)))
	local frame = n % frames + 1
	n = step(n)
	local x = n % size
	n = step(n)
	local y = n % size
	return frame, x, y
end

-- How strong the grain is (0-1, the label's opacity). grain is the setting
-- (0 off, 1 fine, 2 film); dread 0-100; darkness 0-1, how dark the view is
-- (film pushed in the dark shows more grain).
function Lens.grainOpacity(grain: number, dread: number, darkness: number, inRun: boolean, cfg): number
	if grain <= 0 then
		return 0
	end
	local opacity = grain >= 2 and cfg.GrainFilm or cfg.GrainFine
	if not inRun then
		return opacity * cfg.GrainHub
	end
	opacity += cfg.GrainDread * math.clamp(dread, 0, 100) / 100
	return math.clamp(opacity * (1 + cfg.GrainDark * math.clamp(darkness, 0, 1)), 0, 1)
end

-- How bright the grain's light specks are (the frame's tint, 0-1): weak in
-- the dark, where they would read as TV snow on black, fuller in the light.
-- The dark specks are untouched by the tint, so the grain still darkens.
function Lens.grainLight(darkness: number, cfg): number
	local lit = 1 - math.clamp(darkness, 0, 1)
	return cfg.GrainLightDark + (cfg.GrainLightLit - cfg.GrainLightDark) * lit
end

-- Rack focus -------------------------------------------------------------

-- Where the lens focuses, how deep the sharp zone is, and how soft the far
-- room goes. hit is the distance to what the middle of your view rests on
-- (nil when nothing is near); guest is the Guest's distance when he is in
-- view. He is always kept inside the sharp zone within GuestReadable studs:
-- he must read at 30 (doc section 8), and focus never hides him.
function Lens.focus(hit: number?, guest: number?, cfg): (number, number, number)
	local f = cfg.Focus
	local distance = math.clamp(hit or f.Far, f.Near, f.Far)
	local radius = math.max(f.MinRadius, distance * f.RadiusPerStud)
	-- The closer the focus, the softer the room beyond it (a note held up).
	local closeness = 1 - math.clamp((distance - f.Near) / (f.SoftUntil - f.Near), 0, 1)
	local farBlur = f.FarBlur + (f.FarBlurClose - f.FarBlur) * closeness
	if guest and guest <= f.GuestReadable then
		local reach = distance + radius
		if guest > reach then
			radius += guest - reach + f.GuestMargin
		end
	end
	return distance, radius, farBlur
end

-- Eases a value towards a target at rate per second.
function Lens.ease(current: number, target: number, rate: number, dt: number): number
	return current + (target - current) * math.clamp(rate * dt, 0, 1)
end

-- Eye adaptation -----------------------------------------------------------

-- How much light reaches the camera from one light: its brightness, falling
-- off to nothing at its range (roughly as Roblox's lights do).
function Lens.lightAt(brightness: number, range: number, distance: number): number
	if range <= 0 or distance >= range then
		return 0
	end
	local t = 1 - distance / range
	return brightness * t * t
end

-- The exposure to ease towards for that much light: a little brighter in the
-- dark (your eyes open), a little darker under many lamps. Clamped tight:
-- darkness stays dark (docs/ART.md rule 1).
function Lens.exposure(light: number, cfg): number
	local e = cfg.Exposure
	local stops = math.log(light + e.Floor, 2) - e.Key
	return math.clamp(-stops * e.Gain, e.Min, e.Max)
end

-- Eyes take longer to open in the dark than to close in the light.
function Lens.exposureRate(current: number, target: number, cfg): number
	return target > current and cfg.Exposure.ToDark or cfg.Exposure.ToLight
end

-- How dark the view is (0 lit to 1 black), from the same light estimate.
function Lens.darkness(light: number, cfg): number
	return 1 - math.clamp(light / cfg.Exposure.Lit, 0, 1)
end

-- Glare ------------------------------------------------------------------

-- A practical light's glare: its size in pixels and its opacity, from how far
-- it is, how bright it burns now (flicker, dimming), and how near the middle
-- of the view it sits (facing 1 dead ahead, 0 at the edge). viewHeight is the
-- screen's height in pixels.
function Lens.glare(distance: number, level: number, facing: number, viewHeight: number, cfg): (number, number)
	local g = cfg.Glare
	if distance >= g.MaxDistance or level <= 0 then
		return 0, 0
	end
	local size = math.clamp(g.Size / math.max(distance, 1) * viewHeight / 1000, g.MinPixels, g.MaxPixels)
	local fade = 1 - math.clamp((distance - g.FadeFrom) / (g.MaxDistance - g.FadeFrom), 0, 1)
	local opacity = g.Opacity * math.clamp(level, 0, 1) * fade * (g.Edge + (1 - g.Edge) * math.clamp(facing, 0, 1))
	return size, opacity
end

-- How much of the lens's dirt shows: only while a bright light sits near the
-- middle of the view. centre is 0-1 (1 dead centre) for the strongest light.
function Lens.dirt(centre: number, level: number, cfg): number
	local d = cfg.Dirt
	local t = math.clamp((centre - d.From) / (1 - d.From), 0, 1)
	return d.Opacity * t * t * math.clamp(level, 0, 1)
end

return Lens
