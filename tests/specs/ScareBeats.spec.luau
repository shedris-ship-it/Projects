-- Scares he sets up on purpose (Logic/ScareBeats; the squad playtest,
-- 2026-10-08): the least-frightened player, never the protected, never
-- too often.
return function(test, check, Shared, require)
	local ScareBeats = require(Shared.Logic.ScareBeats)
	local Config = require(Shared.Config)
	local G = Config.Guest

	test("the player he has frightened least lately", function()
		local now = 1000
		local chosen = ScareBeats.pick({
			{ id = "a", scaredAt = now - G.BeatGap - 10 },
			{ id = "b", scaredAt = now - G.BeatGap - 200 },
			{ id = "c", scaredAt = nil },
		}, now, G)
		check.equal(chosen and chosen.id, "c", "never scared beats long ago")
		chosen = ScareBeats.pick({
			{ id = "a", scaredAt = now - G.BeatGap - 10 },
			{ id = "b", scaredAt = now - G.BeatGap - 200 },
		}, now, G)
		check.equal(chosen and chosen.id, "b", "the longest ago")
	end)

	test("not again too soon, and never the protected", function()
		local now = 1000
		check.equal(ScareBeats.pick({ { id = "a", scaredAt = now - 10 } }, now, G), nil, "just scared")
		for _, flag in { "hidden", "graced", "safeRoom", "nearDown" } do
			local p = { id = "a" }
			p[flag] = true
			check.equal(ScareBeats.pick({ p }, now, G), nil, flag)
		end
	end)

	test("a beat that fits", function()
		check.equal(ScareBeats.kind(false, false, 0.5), nil, "nothing fits")
		check.equal(ScareBeats.kind(false, true, 0.9), "dark", "only coming closer")
		for _, roll in { 0, 0.4, 0.99 } do
			local k = ScareBeats.kind(true, false, roll)
			check.truthy(k == "behind" or k == "hand", "behind you")
		end
	end)
end
