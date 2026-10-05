-- The Guest wants his dinner (Logic/Scent): he senses a carried heirloom's
-- room, a declared rule with its limits.
return function(test, check, Shared, require)
	local Config = require(Shared.Config)
	local Scent = require(Shared.Logic.Scent)
	local C = Config.Scent

	test("carried, he senses it; hidden, he doesn't; set, it's his and done", function()
		local carried = { holder = "Ann", position = 1 }
		local hiding = { holder = "Bo", hidden = true, position = 2 }
		local set = { holder = nil, set = true, position = 3 }
		local found = Scent.targets({ carried, hiding, set }, 100, C)
		check.equal(#found, 1, "only the one carried in the open")
		check.equal(found[1].player, "Ann", "the carrier")
	end)

	test("dropped, he knows where for a few seconds, then loses it", function()
		local dropped = { lastHolder = "Ann", droppedAt = 100, position = 5 }
		check.equal(#Scent.targets({ dropped }, 100 + C.Linger - 1, C), 1, "just let go")
		check.equal(#Scent.targets({ dropped }, 100 + C.Linger + 1, C), 0, "gone")
	end)

	test("he waits at the table once every heirloom still to set is in someone's hands", function()
		check.truthy(Scent.allInHand({ { holder = "Ann" }, { set = true } }), "the last one carried")
		check.truthy(not Scent.allInHand({ { holder = "Ann" }, { droppedAt = 1 } }), "one still lying about")
		check.truthy(not Scent.allInHand({ { set = true } }), "nothing left to set")
	end)

	test("he tidies only what's been left lying a while, with nobody near", function()
		local lying = { droppedAt = 0 }
		check.truthy(Scent.wantsTidy(lying, C.TidySeconds + 1, C.TidyClear + 5, C), "left a while, nobody near")
		check.truthy(not Scent.wantsTidy(lying, C.TidySeconds - 1, 100, C), "not yet")
		check.truthy(not Scent.wantsTidy(lying, C.TidySeconds + 1, C.TidyClear - 5, C), "someone close by")
		check.truthy(not Scent.wantsTidy({ holder = "Ann", droppedAt = 0 }, 1000, 100, C), "not from your hands")
		check.truthy(not Scent.wantsTidy({ set = true, droppedAt = 0 }, 1000, 100, C), "not from the table")
	end)

	test("a carrier is a carrier until it's set", function()
		check.truthy(Scent.carrying({ { holder = "Ann" } }, "Ann"), "carrying")
		check.truthy(not Scent.carrying({ { holder = "Ann", set = true } }, "Ann"), "set")
		check.truthy(not Scent.carrying({ { holder = "Bo" } }, "Ann"), "someone else's")
	end)
end
