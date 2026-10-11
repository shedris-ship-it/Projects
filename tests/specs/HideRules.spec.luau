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

	test("every place you hide in by E has your eye in it, behind its cloth", function()
		local Props = require(Shared.Data.Props)
		local count = 0
		for name, kind in Props.Kinds do
			if kind.hide and not kind.physical then
				count += 1
				local view = kind.view
				check.truthy(view ~= nil, name .. " has a view")
				if view then
					-- Roblox draws nothing within half a stud of the eye: tucked in,
					-- the cloth in front (a curtain's folds are up to 0.4 deep) must
					-- stand further off than that, or you'd see straight through it.
					local cloth = kind.hide == "curtain" and name == "Curtain" and 0.4 or 0.1
					check.atMost(view.tuck, -(0.5 + cloth), name .. ": tucked in, the cloth is in sight")
					check.atMost(view.peek, -(0.45 + cloth), name .. ": peeking, the cloth is still drawn")
					check.atLeast(view.eye, 0.2, name .. ": the eye is above the floor")
					if kind.hide ~= "curtain" then
						-- Lying down, looking out under the hem.
						check.atMost(view.eye, 0.5, name .. ": low enough to see under the hem")
					end
				end
			end
		end
		check.atLeast(count, 5, "the bed, the table, the desk, the curtain, the bathtub")
	end)
end
