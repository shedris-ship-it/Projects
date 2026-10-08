-- His disguise (the squad playtest, 2026-10-08: "maybe the guest should
-- shapeshift"; the owner's choice: a teammate). Late in a bad night, to one
-- player alone, he wears a friend's look, far off: no torch, no name over
-- it, silent, standing wrong. Go to it and it's him (StalkerService
-- :_disguise, Controllers/GuestController). It is always his real body
-- under the look: the only Guest anyone sees is the real one.
--
-- When it may happen. ctx: dread, act, tier, hunting, count (disguises
-- this run), observerHad (this player has had one), sinceLast (seconds
-- since the last one), observerAlone (nobody within AloneRadius of them),
-- teammateDistance (the friend he copies, from the observer), teammateSeen
-- (the observer can see that friend), guestDistance (him, from the
-- observer), guestSeen (anyone can see him now). Pure (tests/specs/
-- Disguise.spec).

local Disguise = {}

function Disguise.can(ctx, cfg): (boolean, string?)
	if ctx.dread < cfg.Dread or ctx.act < cfg.Act then
		return false, "too early in the night"
	elseif ctx.tier < 3 then
		return false, "not bold enough"
	elseif ctx.hunting then
		return false, "hunting"
	elseif ctx.count >= cfg.MaxPerRun then
		return false, "enough for one night"
	elseif ctx.observerHad then
		return false, "they've seen it"
	elseif ctx.sinceLast < cfg.Gap then
		return false, "too soon"
	elseif not ctx.observerAlone then
		return false, "not alone"
	elseif ctx.teammateDistance < cfg.TeammateMin or ctx.teammateSeen then
		return false, "the friend is right there"
	elseif ctx.guestDistance < cfg.Near[1] or ctx.guestDistance > cfg.Near[2] then
		return false, "not at the right distance"
	elseif ctx.guestSeen then
		return false, "watched"
	end
	return true, nil
end

return Disguise
