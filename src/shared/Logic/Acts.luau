-- The run's arc (docs/plans/gameplay-rework.md, R2c "pacing"): how far the
-- squad has got, as acts. Progress, not Drift, says which act the run is in,
-- so a squad that does well still meets more of The Guest as the night goes
-- on, and a house with a single region (nothing locked) still has an arc.
--
--   act 1  the start: only what's open from the front door
--   act 2  real progress: a locked door opened, or an heirloom found
--   act 3  most of the way: past Config.Pacing.Act3At of everything
--   act 4  the dinner is served (the run out)
--
-- Pure (tests/specs/Acts.spec). facts = { gates, gatesOpened, heirlooms,
-- heirloomsFound, places, placesSet, served }; any may be missing.

local Acts = {}

-- 0..1: gates opened, heirlooms found (worth half) and places set, over all
-- there are to do.
function Acts.progress(facts): number
	local gates, heirlooms, places = facts.gates or 0, facts.heirlooms or 0, facts.places or 0
	local total = gates + heirlooms * 0.5 + places
	if total <= 0 then
		return 0
	end
	local done = math.min(facts.gatesOpened or 0, gates)
		+ math.min(facts.heirloomsFound or 0, heirlooms) * 0.5
		+ math.min(facts.placesSet or 0, places)
	return math.clamp(done / total, 0, 1)
end

function Acts.of(facts, cfg): number
	if facts.served then
		return 4
	end
	local progress = Acts.progress(facts)
	if progress >= cfg.Act3At then
		return 3
	end
	if (facts.gatesOpened or 0) > 0 or (facts.heirloomsFound or 0) > 0 or progress >= cfg.Act2At then
		return 2
	end
	return 1
end

-- How much an act adds to Drift when picking The Guest's tier (only the
-- tier: Drift itself still measures stalling).
function Acts.heat(act: number, cfg): number
	return cfg.ActHeat[act] or cfg.ActHeat[#cfg.ActHeat] or 0
end

return Acts
