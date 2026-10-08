-- The Director's pacing rules (doc section 5, "Three layers" and
-- "Escalation tiers"; docs/plans/gameplay-rework.md, R2c "pacing"). Pure:
-- given the state of the run it answers which tier the stalker should be at
-- and whether a hunt should start now.
--
-- Two things start hunts. Progress arms one (Stalker/Director:Arm, from a
-- newly entered region, a new act or the first heirloom found): it comes a
-- minute or two later, wherever the squad has got to. And Drift, which only
-- measures stalling, starts them on an interval once it reaches Breaking, so
-- a squad that stalls is hunted more and more. His tier follows Dread
-- (Logic/Dread: Drift or the act's floor, whichever is worse), so a good
-- squad still meets more of him as the night goes on.
--
-- The intro (the squad playtest, 2026-10-08: "guest should be more subtle
-- at beginning of the game"): for its first minutes a night stays at tier 1
-- at most and has no hunts, however fast the squad gets through its first
-- door; he is glimpsed, far off and briefly (Stalker/Stalk). Only a house
-- already Breaking (Drift 60) cuts it short.
--
-- Hunts never come on a clock (the owner's audit, 2026-10-06): the gap after
-- a hunt is drawn afresh each time, a woken hunt is sometimes only its
-- telegraph (a false alarm, with the real one soon after), and sometimes he
-- comes straight back after a hunt, gap or no gap.

local DirectorModel = {}

-- Tier from Dread (doc section 2 table).
function DirectorModel.tierFor(dread: number): number
	-- Tier 1 starts a couple of minutes in (after the 90-second calm), so the
	-- first "figure at the end of the hall" lands early in Arrival.
	if dread < 5 then
		return 0
	elseif dread < 40 then
		return 1
	elseif dread < 60 then
		return 2
	end
	return 3
end
DirectorModel.tierForDrift = DirectorModel.tierFor

-- How long a hunt lasts: longer the higher Dread is (full length at
-- Pacing.HuntDreadFull), within Stalker.HuntDuration. `jitter` is -1..1.
function DirectorModel.huntDuration(dread: number, jitter: number, config): number
	local range = config.Stalker.HuntDuration
	local t = math.clamp(dread / config.Pacing.HuntDreadFull, 0, 1)
	local seconds = range[1] + (range[2] - range[1]) * t + jitter * config.Pacing.HuntJitter
	return math.clamp(seconds, range[1], range[2])
end

-- The gap a woken hunt keeps after the last one: MinHuntGap give or take
-- HuntGapJitter, from a 0..1 roll made when that hunt ended.
function DirectorModel.huntGap(roll: number, config): number
	local pacing = config.Pacing
	local jitter = pacing.HuntGapJitter or 0
	return pacing.MinHuntGap * (1 - jitter + 2 * jitter * math.clamp(roll, 0, 1))
end

-- input = {
--   runTime, drift, dread (default drift), now, act (1-4, default 1),
--   lastHuntEnded (time or nil), retreatUntil (time or nil),
--   armedAt (time or nil): a hunt progress has woken, due at that time,
--   armedFalse (bool): that hunt is only a telegraph (a false alarm),
--   armedUrgent (bool): it waits for no gap (he comes straight back),
--   minGap (seconds, default Pacing.MinHuntGap): the gap after the last hunt,
--   lastRevive (time or nil), squadInLantern (bool),
--   stationary (0..1), forced (bool, e.g. the debug console),
--   difficulty = Config.Difficulty entry,
--   introSeconds (default Pacing.IntroSeconds): the night's intro, before
--     the difficulty's IntroScale,
-- }
-- returns { tier, huntDue, reason, falseAlarm?, intro }
function DirectorModel.evaluate(input, config)
	local runConfig, stalker, pacing = config.Run, config.Stalker, config.Pacing
	local tier = DirectorModel.tierFor(input.dread or input.drift)
	if input.runTime < runConfig.StalkerDormantSeconds then
		tier = 0
	end
	-- (The night's length picks it; Hard shortens it.)
	local introSeconds = (input.introSeconds or pacing.IntroSeconds or 0)
		* (input.difficulty and input.difficulty.IntroScale or 1)
	-- A house already Breaking (Drift, the failure clock) has earned him early.
	local intro = input.runTime < introSeconds and input.drift < 60
	if intro then
		tier = math.min(tier, 1)
	end
	if input.retreatUntil and input.now < input.retreatUntil then
		tier = math.min(tier, 1)
	end

	local function blocked(): string?
		if input.runTime < runConfig.NoHuntBeforeSeconds then
			return "too early"
		end
		if intro then
			return "the intro"
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
		return { tier = tier, huntDue = false, reason = reason, intro = intro }
	end
	if input.forced then
		return { tier = tier, huntDue = true, reason = "forced" }
	end
	if input.retreatUntil and input.now < input.retreatUntil then
		return { tier = tier, huntDue = false, reason = "retreating" }
	end
	-- Progress woke him: the hunt comes when it's due, never hard on the heels
	-- of the last one (unless he's coming straight back).
	if input.armedAt and input.now >= input.armedAt then
		local gap = input.minGap or pacing.MinHuntGap
		if input.armedUrgent or input.lastHuntEnded == nil or input.now - input.lastHuntEnded >= gap then
			if input.armedFalse then
				return { tier = tier, huntDue = true, reason = "false alarm", falseAlarm = true }
			end
			return { tier = tier, huntDue = true, reason = input.armedUrgent and "back again" or "armed" }
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
