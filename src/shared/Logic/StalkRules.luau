-- The rules The Guest plays by outside a hunt (owner, 2026-10-03; doc
-- section 5, "Escalation tiers" and "The observation rule"). Pure, so every
-- fairness promise is a test (tests/specs/Stalk.spec.luau).
--
--   tier 0  Dormant   in the house, unseen by anyone, far from the squad
--   tier 1  Watching  seen only by the Witness he's watching; peeks, and is
--                     yanked out of sight the moment you've clearly seen him
--   tier 2  Closing   seen by all; creeps closer only while nobody watches,
--                     never attacks unprovoked; may end up right behind you,
--                     breathing
--   tier 3  Intruding creeps even while one Witness watches; two freeze him;
--                     sneaks up behind turned backs; lunges when close
--
-- Everyone: he never turns his back on you, and never pops in or out of
-- existence in front of anyone (visibility only changes unseen). Walk up to
-- him from tier 1 and he lunges (StalkRules.contact).

local StalkRules = {}

-- Who can see him at this tier.
function StalkRules.visibleTo(tier: number, isTarget: boolean): boolean
	if tier <= 0 then
		return false
	elseif tier == 1 then
		return isTarget
	end
	return true
end

-- Two Witnesses (or one with the Companion) always freeze him.
function StalkRules.frozen(watchers: number): boolean
	return watchers >= 2
end

-- May he move closer right now?
function StalkRules.canCreep(tier: number, watchers: number): boolean
	if tier <= 1 then
		return false -- tier 1 never approaches; it only watches
	elseif tier == 2 then
		return watchers == 0
	end
	return watchers < 2
end

-- How fast he creeps (studs/s). Faster the more your back is turned
-- (backAngle: degrees between where you look and where he is, 0..180);
-- painfully slow while one Witness is staring at him at tier 3.
function StalkRules.creepSpeed(tier: number, backAngle: number, watchers: number, cfg): number
	local range = tier >= 3 and cfg.CreepSpeedTier3 or cfg.CreepSpeedTier2
	if watchers >= 1 then
		return cfg.CreepSpeedWatched
	end
	local t = math.clamp((backAngle - 90) / 90, 0, 1)
	return range[1] + (range[2] - range[1]) * t
end

-- Tier 1: once the Witness has clearly seen him, he's yanked out of sight.
function StalkRules.flees(tier: number, seenSeconds: number, cfg): boolean
	return tier <= 1 and seenSeconds >= cfg.SpottedFleeSeconds
end

-- At tier 2, watched by one Witness for long enough and close, he backs
-- away (still facing you) instead of holding.
function StalkRules.backsOff(tier: number, watchedSeconds: number, distance: number, cfg): boolean
	return tier == 2 and watchedSeconds >= cfg.StareBackAwaySeconds and distance <= cfg.StareBackAwayRange
end

-- Standing in a doorway blocks a route; only allowed while he can't attack.
function StalkRules.mayBlockDoorway(tier: number): boolean
	return tier <= 2
end

-- The lunge. ctx:
--   tier, runTime, watchers, distance, verticalGap, lineOfSight,
--   hidden, downed, safeRoom, sinceDownNearby, sincePlayerLunge,
--   sinceSquadLunge, warnedFor, sinceWarned
-- Returns ok and, when not ok, the first reason (for the debug overlay).
function StalkRules.canLunge(ctx, cfg): (boolean, string?)
	if ctx.tier < 3 then
		return false, "tier"
	elseif ctx.runTime < cfg.LungeMinRunSeconds then
		return false, "too early"
	elseif StalkRules.frozen(ctx.watchers) then
		return false, "frozen"
	elseif ctx.stunned then
		-- Something thrown just hit him (docs/plans/gameplay-rework.md 4.4).
		return false, "stunned"
	elseif ctx.hidden or ctx.downed or ctx.safeRoom then
		return false, "protected"
	elseif ctx.distance > cfg.LungeRadius or ctx.verticalGap > 4 then
		return false, "out of reach"
	elseif not ctx.lineOfSight then
		return false, "no line"
	elseif ctx.sinceDownNearby < cfg.NoLungeNearDownSeconds then
		return false, "someone just went down"
	elseif ctx.sincePlayerLunge < cfg.LungeCooldownPerPlayer or ctx.sinceSquadLunge < cfg.LungeCooldownSquad then
		return false, "cooldown"
	elseif ctx.warnedFor < cfg.LungeTellLeadSeconds or ctx.sinceWarned > cfg.WarningMemorySeconds then
		-- Fairness: you heard him (a breath, a creak) or saw him coming.
		return false, "no warning yet"
	end
	return true, nil
end

-- Close contact (owner, 2026-10-03): walk right up to a Guest you can see and
-- he lunges at once, at any tier from 1. Rushing him is your own choice, so
-- there's no run-time wait, no warning and none of the lunge cooldowns. Still
-- off while two Witnesses hold him (a buddy who stares is the counter), while
-- you're hidden, downed or safe, and just after someone nearby went down.
-- ctx: tier, visibleToVictim, distance, verticalGap, lineOfSight, watchers,
--   hidden, downed, safeRoom, sinceDownNearby, sinceContact
function StalkRules.contact(ctx, cfg): (boolean, string?)
	if ctx.tier < 1 then
		return false, "tier"
	elseif not ctx.visibleToVictim then
		return false, "not visible to them"
	elseif ctx.distance > cfg.ContactRadius or ctx.verticalGap > 4 then
		return false, "out of reach"
	elseif StalkRules.frozen(ctx.watchers) then
		return false, "frozen"
	elseif ctx.stunned then
		return false, "stunned"
	elseif ctx.hidden or ctx.downed or ctx.safeRoom then
		return false, "protected"
	elseif not ctx.lineOfSight then
		return false, "no line"
	elseif ctx.sinceDownNearby < cfg.NoLungeNearDownSeconds then
		return false, "someone just went down"
	elseif ctx.sinceContact < cfg.ContactCooldownPerPlayer then
		return false, "cooldown"
	end
	return true, nil
end

-- Did the lunge connect? Only if you're still within reach when it lands.
function StalkRules.lungeHits(distance: number, verticalGap: number, cfg): boolean
	return distance <= cfg.LungeReach and verticalGap <= 4
end

return StalkRules
