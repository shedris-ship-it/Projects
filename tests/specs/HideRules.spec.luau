-- Peeking out of a hiding place (Logic/HideRules; the squad playtest,
-- 2026-10-08): a peek he can see for long enough gives you away, fairly.
return function(test, check, Shared, require)
	local HideRules = require(Shared.Logic.HideRules)
	local Config = require(Shared.Config)
	local H = Config.Hide

	local function seen(overrides)
		local ctx = {
			peekFor = H.NoticeSeconds + 0.1,
			tier = 2,
			hunting = false,
			distance = H.NoticeRange - 2,
			angle = 10,
			lineOfSight = true,
		}
		for k, v in overrides or {} do
			ctx[k] = v
		end
		return ctx
	end

	test("a long peek he can see, close, while closing in: noticed", function()
		check.truthy(HideRules.noticed(seen(), H), "tier 2")
		check.truthy(HideRules.noticed(seen({ tier = 1, hunting = true }), H), "in a hunt")
	end)

	test("a quick glance, a far one, behind his back or through a wall: never", function()
		local ok, why = HideRules.noticed(seen({ peekFor = H.NoticeSeconds * 0.5 }), H)
		check.equal(ok, false, "a glance")
		check.equal(why, "not long enough", "reason")
		check.equal(HideRules.noticed(seen({ distance = H.NoticeRange + 1 }), H), false, "too far")
		check.equal(HideRules.noticed(seen({ angle = H.NoticeCone + 5 }), H), false, "behind him")
		check.equal(HideRules.noticed(seen({ lineOfSight = false }), H), false, "a wall between")
	end)

	test("before he closes in, peeking is free", function()
		local ok, why = HideRules.noticed(seen({ tier = 1 }), H)
		check.equal(ok, false, "tier 1")
		check.equal(why, "not closing in", "reason")
	end)

	test("every hiding kind has a slit", function()
		for _, kind in { "wardrobe", "closet", "locker", "bed", "table", "curtain" } do
			check.truthy(HideRules.Slits[kind] ~= nil, kind)
		end
		check.equal(HideRules.slit("bed"), "skirt", "under a bed")
		check.equal(HideRules.slit(nil), "louvre", "a default")
	end)
end
