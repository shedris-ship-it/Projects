-- The storm that builds (the visual rework V2, the owner's choice of
-- 2026-10-12): still and foggy at first, rain on the glass by the middle of
-- the night, thunder and lightning late. Shared by everyone, like the
-- house's decay (docs/ART.md rule 6). The server decides the stage and each
-- strike (Services/WeatherService); clients draw and play them
-- (Controllers/WeatherController). Pure; spec'd in Storm.spec. cfg is
-- Config.Storm.

local Storm = {}

Storm.Still, Storm.Rain, Storm.Thunder = 0, 1, 2

-- The stage for how bad the house is (Dread 0-100, Logic/Dread). The
-- Reckoning and the dinner's run out are always the storm's worst.
function Storm.stage(dread: number, finale: boolean?, cfg): number
	if finale or dread >= cfg.ThunderAt then
		return Storm.Thunder
	elseif dread >= cfg.RainAt then
		return Storm.Rain
	end
	return Storm.Still
end

-- Seconds to the next strike at a stage, or nil when there are none. In the
-- rain only far ones, now and then; in the storm, near and far.
function Storm.nextIn(rng, stage: number, cfg): number?
	if stage == Storm.Thunder then
		return rng:NextNumber(cfg.Every[1], cfg.Every[2])
	elseif stage == Storm.Rain then
		return rng:NextNumber(cfg.RainEvery[1], cfg.RainEvery[2])
	end
	return nil
end

-- One strike: how near (0 far to 1 overhead), its flashes (offset seconds
-- and strength 0-1) and when its thunder arrives after the first flash.
-- Sound travels about a kilometre in three seconds; a near strike is all
-- but at once, a far one rolls in seconds later.
function Storm.strike(rng, stage: number, cfg)
	local near = 0
	if stage == Storm.Thunder then
		near = rng:NextNumber() ^ cfg.NearBias
	else
		near = rng:NextNumber() * cfg.RainNear
	end
	local flashes = {}
	local count = rng:NextInteger(1, near > 0.5 and 3 or 2)
	local at = 0
	for i = 1, count do
		local strength = (0.35 + 0.65 * near) * (i == 1 and 1 or rng:NextNumber(0.4, 0.9))
		table.insert(flashes, { at = at, strength = strength, seconds = rng:NextNumber(0.05, 0.12) })
		at += rng:NextNumber(0.06, 0.22)
	end
	local delay = cfg.ThunderDelay[1] + (cfg.ThunderDelay[2] - cfg.ThunderDelay[1]) * (1 - near)
	return {
		near = near,
		flashes = flashes,
		thunder = delay,
		sound = near >= cfg.CrackAt and "near" or "far",
		variant = rng:NextInteger(1, 3),
		volume = cfg.ThunderVolume[1] + (cfg.ThunderVolume[2] - cfg.ThunderVolume[1]) * near,
	}
end

return Storm
