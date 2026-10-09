-- Peeking out of a hiding place (the squad playtest, 2026-10-08: "be able to
-- peek from the hiding spot instead of seeing everything perfectly"). Tucked
-- in, you see through a slit; hold to peek and you see more, and so can he:
-- a peek he can see for long enough gives the place away (Services/
-- HidingService turns that into what he heard, StalkerService:NoticePeek).
-- Fair both ways: he notices only while he's looking your way, close, with
-- a clear line, and only once he's closing in (tier 2) or hunting; you can
-- see him the whole time. Pure (tests/specs/HideRules.spec).

local HideRules = {}

-- ctx: peekFor (seconds peeking without a break), tier, hunting, distance
-- (studs from his eyes to the gap), angle (degrees off the way he faces),
-- lineOfSight. Returns noticed and, when not, why (for the debug overlay).
function HideRules.noticed(ctx, cfg): (boolean, string?)
	if (ctx.peekFor or 0) < cfg.NoticeSeconds then
		return false, "not long enough"
	elseif ctx.tier < 2 and not ctx.hunting then
		return false, "not closing in"
	elseif ctx.distance > cfg.NoticeRange then
		return false, "too far"
	elseif ctx.angle > cfg.NoticeCone then
		return false, "looking elsewhere"
	elseif not ctx.lineOfSight then
		return false, "no line"
	end
	return true, nil
end

-- The slit you see through, by the kind of hiding place (UI/HideView). A
-- wardrobe, a closet or a locker you walk into shows none: its louvres are
-- real (this is for one hidden in by E, like a prefab's).
HideRules.Slits = {
	wardrobe = "louvre",
	closet = "louvre",
	locker = "vents",
	bed = "skirt",
	table = "hem",
	curtain = "edge",
}

function HideRules.slit(category: string?): string
	return HideRules.Slits[category or ""] or "louvre"
end

return HideRules
