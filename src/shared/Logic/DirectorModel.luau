-- The Director's pacing rules (doc section 5, "Three layers" and
-- "Escalation tiers"; docs/plans/gameplay-rework.md, R2c "pacing"). Pure:
-- given the state of the run it answers which tier the stalker should be at
-- and whether a hunt should start now.
--
-- Two things start hunts. Progress arms one (Stalker/Director:Arm, from a
-- newly entered region, a new act or the first heirloom found): it comes a
-- minute or two later, wherever the squad has got to. And Drift, which only
-- measures stalling, starts them on an interval once it reaches Breaking, so
-- a squad that stalls is hunted more and more. The act raises the tier too
-- (Logic/Acts.heat), so a good squad still meets more of him as the night
-- goes on.

local DirectorModel = {}

-- Tier from Drift (doc section 2 table), plus the act's heat.
function DirectorModel.tierForDrift(drift: number): number
	-- Tier 1 starts a couple of minutes in (after the 90-second calm), so the
	-- first "figure at the end of the hall" lands early in Arrival.
	if drift < 5 then
		return 0
	elseif drift < 40 then
		return 1
	elseif drift < 60 then
		return 2
	end
	return 3
end

-- How long a hunt lasts: longer the higher Drift is (full length at
-- Pacing.HuntDriftFull), within Stalker.HuntDuration. `jitter` is -1..1.
function DirectorModel.huntDuration(drift: number, jitter: number, config): number
	local range = config.Stalker.HuntDuration
	local t = math.clamp(drift / config.Pacing.HuntDriftFull, 0, 1)
	local seconds = range[1] + (range[2] - range[1]) * t + jitter * config.Pacing.HuntJitter
	return math.clamp(seconds, range[1], range[2])
end

-- input = {
--   runTime, drift, now, act (1-4, default 1),
--   lastHuntEnded (time or nil), retreatUntil (time or nil),
--   armedAt (time or nil): a hunt progress has woken, due at that time,
--   lastRevive (time or nil), squadInLantern (bool),
--   stationary (0..1), forced (bool, e.g. the debug console),
--   difficulty = Config.Difficulty entry,
-- }
-- returns { tier, huntDue, reason }
function DirectorModel.evaluate(input, config)
	local runConfig, stalker, pacing = config.Run, config.Stalker, config.Pacing
	local heat = pacing.ActHeat[input.act or 1] or 0
	local tier = DirectorModel.tierForDrift(input.drift + heat)
	if input.runTime < runConfig.StalkerDormantSeconds then
		tier = 0
	end
	if input.retreatUntil and input.now < input.retreatUntil then
		tier = math.min(tier, 1)
	end

	local function blocked(): string?
		if input.runTime < runConfig.NoHuntBeforeSeconds then
			return "too early"
		end
		if input.lastRevive and input.now - input.lastRevive < stalker.NoHuntAfterReviveSeconds then
			return "recent revive"
		end
		if input.squadInLantern then
			return "squad in a Lantern room"
		end
		return nil
	end

	local reason = blocked()
	if reason then
		return { tier = tier, huntDue = false, reason = reason }
	end
	if input.forced then
		return { tier = tier, huntDue = true, reason = "forced" }
	end
	if input.retreatUntil and input.now < input.retreatUntil then
		return { tier = tier, huntDue = false, reason = "retreating" }
	end
	-- Progress woke him: the hunt comes when it's due, never hard on the heels
	-- of the last one.
	if input.armedAt and input.now >= input.armedAt then
		if input.lastHuntEnded == nil or input.now - input.lastHuntEnded >= pacing.MinHuntGap then
			return { tier = tier, huntDue = true, reason = "armed" }
		end
		return { tier = tier, huntDue = false, reason = "armed, waiting out the gap" }
	end
	if input.drift < 60 then
		return { tier = tier, huntDue = false, reason = "drift below Breaking" }
	end

	local interval = input.drift >= 80 and stalker.HuntIntervalCollapsing or stalker.HuntIntervalBreaking
	interval *= (input.difficulty and input.difficulty.HuntIntervalMultiplier or 1)
	-- Camping squads are pressured sooner (doc: "escalates sooner against
	-- stationary squads").
	interval *= 1 - 0.25 * math.clamp(input.stationary or 0, 0, 1)
	if input.lastHuntEnded == nil or input.now - input.lastHuntEnded >= interval then
		return { tier = tier, huntDue = true, reason = "interval" }
	end
	return { tier = tier, huntDue = false, reason = "cooldown" }
end

return DirectorModel
