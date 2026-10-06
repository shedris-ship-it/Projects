-- Dread: how bad the house is right now, the one number every escalation
-- reads (the owner's audit of 2026-10-06, Finding 2: "fear is gated behind
-- failure"). It is the greater of
--   * Drift, the failure clock (stalling, splitting up, downs), and
--   * the act's floor (Config.Pacing.ActDread): progress. The deeper the squad
--     goes, the worse the house gets, as in Resident Evil, P.T. and Amnesia,
--     so a squad that plays well still meets the portrait's eyes, the
--     writing, his open smile and his tier 3 in the second half of its run.
-- The floor eases in over Config.Pacing.DreadRamp seconds after an act
-- begins, so nothing flips at once. Hard adds a floor of its own
-- (Config.Difficulty.Hard.DreadFloor). Drift itself still ends the run at
-- 100; Dread never does. Pure (tests/specs/Pacing.spec).
--
-- Who reads it: his tier (Logic/DirectorModel), his face (StalkerService),
-- the scare deck's gaps and cards (Stalker/Director), each player's
-- atmosphere rules (Logic/Atmosphere, Controllers/PerceptionController),
-- the flicker, grade, photos and blood (Controllers/EffectsController), the
-- drones (Controllers/AudioController) and the HUD's word.

local Dread = {}

-- The act's floor, eased in from the previous act's over DreadRamp seconds.
function Dread.floor(act: number, sinceAct: number, cfg): number
	local floors = cfg.ActDread
	local target = floors[act] or floors[#floors] or 0
	local previous = floors[act - 1] or 0
	if previous > target then
		previous = target
	end
	local ramp = cfg.DreadRamp or 0
	local t = ramp > 0 and math.clamp(sinceAct / ramp, 0, 1) or 1
	return previous + (target - previous) * t
end

function Dread.value(drift: number, act: number, sinceAct: number, cfg, difficulty): number
	local floor = Dread.floor(act, sinceAct, cfg)
	local hard = difficulty and difficulty.DreadFloor or 0
	return math.clamp(math.max(drift, floor, hard), 0, 100)
end

return Dread
