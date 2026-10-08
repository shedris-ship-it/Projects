-- His disguise (Logic/Disguise; the squad playtest, 2026-10-08, the owner's
-- choice: a teammate): late, rare, to one player alone, far off.
return function(test, check, Shared, require)
	local Disguise = require(Shared.Logic.Disguise)
	local Config = require(Shared.Config)
	local D = Config.Guest.Disguise

	local function ok(overrides)
		local ctx = {
			dread = D.Dread + 5,
			act = D.Act,
			tier = 3,
			hunting = false,
			count = 0,
			observerHad = false,
			sinceLast = math.huge,
			observerAlone = true,
			teammateDistance = D.TeammateMin + 10,
			teammateSeen = false,
			guestDistance = (D.Near[1] + D.Near[2]) / 2,
			guestSeen = false,
		}
		for k, v in overrides or {} do
			ctx[k] = v
		end
		return ctx
	end

	test("late in a bad night, to someone alone, far off: yes", function()
		check.truthy(Disguise.can(ok(), D), "the moment")
	end)

	test("never early, never in a hunt, never at tier 2", function()
		check.equal(Disguise.can(ok({ dread = D.Dread - 1 }), D), false, "Dread")
		check.equal(Disguise.can(ok({ act = D.Act - 1 }), D), false, "act")
		check.equal(Disguise.can(ok({ tier = 2 }), D), false, "tier")
		check.equal(Disguise.can(ok({ hunting = true }), D), false, "hunt")
	end)

	test("rare: twice a night at most, once each, with a gap", function()
		check.equal(Disguise.can(ok({ count = D.MaxPerRun }), D), false, "enough")
		check.equal(Disguise.can(ok({ observerHad = true }), D), false, "once each")
		check.equal(Disguise.can(ok({ sinceLast = D.Gap - 1 }), D), false, "gap")
	end)

	test("only alone, the friend far off and out of sight, him far and unseen", function()
		check.equal(Disguise.can(ok({ observerAlone = false }), D), false, "company")
		check.equal(Disguise.can(ok({ teammateDistance = D.TeammateMin - 1 }), D), false, "friend close")
		check.equal(Disguise.can(ok({ teammateSeen = true }), D), false, "friend in sight")
		check.equal(Disguise.can(ok({ guestDistance = D.Near[1] - 1 }), D), false, "too close")
		check.equal(Disguise.can(ok({ guestDistance = D.Near[2] + 1 }), D), false, "too far")
		check.equal(Disguise.can(ok({ guestSeen = true }), D), false, "watched")
	end)

	test("the reveal comes well before arm's reach", function()
		check.atLeast(D.RevealAt, Config.Guest.CrowdRadius + 4, "time to back off")
	end)
end
