-- Twin levers (Logic/Puzzles/Levers; the squad playtest, 2026-10-10): two
-- people pull together; one player left can still do it, slower and louder.
return function(test, check, Shared, require)
	local Config = require(Shared.Config)
	local Levers = require(Shared.Logic.Puzzles.Levers)
	local L = Config.Levers

	test("a squad's moment is short: it takes two at once", function()
		local window = Levers.window(2, 60, L)
		check.equal(window, L.Grace, "the grace")
		-- Too short to run from one to the other, however close they're placed.
		check.truthy(L.MinApart / Config.Player.SprintSpeed > L.Grace, "no running between them")
		local a = { held = false, releasedAt = 0, window = window }
		local b = { held = true, window = window }
		check.truthy(Levers.together(a, b, 0.5), "together, just after one let go")
		check.truthy(not Levers.together(a, b, L.Grace + 0.1), "too late")
	end)

	test("one player left: a lever stays down long enough to walk to its twin", function()
		for _, studs in { L.MinApart, 80, L.MaxApart } do
			local window = Levers.window(1, studs, L)
			check.atLeast(window, studs / Config.Player.WalkSpeed * 0.8, studs .. " studs at a brisk walk")
			check.atLeast(window, studs / L.SoloWalkSpeed + L.SoloMargin - 1e-6, "and a margin")
		end
		local a = { held = false, releasedAt = 0, window = Levers.window(1, 60, L) }
		check.truthy(Levers.ticking(a, 3), "on its catch it ticks")
		check.truthy(not Levers.ticking({ held = true, window = 1 }, 3), "held, it doesn't")
		check.truthy(Levers.together(a, { held = true, window = 1 }, 5), "the twin pulled in time")
	end)

	test("neither, or only one, never opens it", function()
		local up = { held = false, window = 2 }
		local down = { held = true, window = 2 }
		check.truthy(not Levers.together(up, up, 0), "neither")
		check.truthy(not Levers.together(up, down, 0), "one")
		check.truthy(not Levers.together(down, up, 0), "the other")
	end)
end
