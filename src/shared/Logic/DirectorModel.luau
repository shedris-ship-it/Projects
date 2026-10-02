-- The Director's pacing rules (doc section 5, "Three layers" and
-- "Escalation tiers"). Pure: given the state of the run it answers which
-- tier the stalker should be at and whether a hunt should start now.

local DirectorModel = {}

-- Tier from Drift alone (doc section 2 table).
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

-- input = {
--   runTime, drift, now,
--   lastHuntEnded (time or nil), retreatUntil (time or nil),
--   lastRevive (time or nil), squadInLantern (bool),
--   stationary (0..1), forced (bool, e.g. wrong verdict),
--   difficulty = Config.Difficulty entry,
-- }
-- returns { tier, huntDue, reason }
function DirectorModel.evaluate(input, config)
	local runConfig, stalker = config.Run, config.Stalker
	local tier = DirectorModel.tierForDrift(input.drift)
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
	if input.drift < 60 then
		return { tier = tier, huntDue = false, reason = "drift below Breaking" }
	end
	if input.retreatUntil and input.now < input.retreatUntil then
		return { tier = tier, huntDue = false, reason = "retreating" }
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
