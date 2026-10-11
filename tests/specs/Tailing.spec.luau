-- Tailing him (Logic/StalkRules.tailing; the owner, 2026-10-11: "if the
-- player is following the guest around but not in range for the lunge I want
-- this to be punished"). He notices, turns and comes for you with a hand
-- out; it reaching you is a down (StalkRules.reachHits).
return function(test, check, Shared, require)
	local Config = require(Shared.Config)
	local StalkRules = require(Shared.Logic.StalkRules)
	local G = Config.Guest

	-- Following him: he walks away at his walk, you go after him at yours.
	local function follow(overrides)
		local ctx = {
			now = 0,
			distance = 18,
			facing = 10,
			away = G.WalkSpeed,
			along = Config.Player.WalkSpeed,
			tier = 2,
			hunting = false,
			seated = false,
			stunned = false,
			visibleToThem = true,
			lineOfSight = true,
			hidden = false,
			downed = false,
			graced = false,
			safeRoom = false,
			verticalGap = 0,
		}
		for k, v in overrides or {} do
			ctx[k] = v
		end
		return ctx
	end

	local function hold(state, ctx, seconds)
		for _ = 1, math.floor(seconds / 0.1 + 0.5) do
			local result = StalkRules.tailing(state, ctx, 0.1, G)
			if result then
				return result
			end
		end
		return nil
	end

	test("following him a while: he notices and reaches for you", function()
		local state = {}
		check.equal(hold(state, follow(), G.TailSeconds * 0.5), nil, "a moment is nothing")
		check.equal(hold(state, follow(), G.TailSeconds * 0.5 + 0.2), "reach", "then he turns on you")
		check.equal(state.boldness, 0, "and it starts again")
	end)

	test("stop-start following still adds up", function()
		local state = {}
		local result = nil
		for _ = 1, 6 do
			result = result or hold(state, follow(), G.TailSeconds / 3)
			result = result or hold(state, follow({ along = 0 }), 1.5)
		end
		check.equal(result, "reach", "pausing to let him get ahead doesn't hide it")
	end)

	test("after once, he notices sooner", function()
		local state = {}
		hold(state, follow(), G.TailSeconds + 0.2)
		check.atMost(G.TailAgain, G.TailSeconds, "sooner")
		check.equal(hold(state, follow({ now = 60 }), G.TailAgain + 0.2), "reach", "within the memory")
		check.equal(hold(state, follow({ now = 60 + G.TailMemory + 10 }), G.TailAgain + 0.2), nil, "forgotten")
	end)

	test("following him across a room is noticed before you'd crowd him", function()
		-- From 25 studs, gaining two a second (your walk 8, his 6).
		local state = {}
		local distance = 25
		local result = nil
		while not result and distance > G.CrowdRadius do
			result = StalkRules.tailing(state, follow({ distance = distance }), 0.1, G)
			distance -= (Config.Player.WalkSpeed - G.WalkSpeed) * 0.1
		end
		check.equal(result, "reach", "he turned")
		check.atLeast(distance, G.FollowRadius, "well before arm's reach")
	end)

	test("only following counts", function()
		for name, overrides in
			{
				["watching him go"] = { along = 0 },
				["he comes your way"] = { away = -G.WalkSpeed },
				["he makes way across you"] = { away = 0 },
				["he stands still"] = { away = 0, along = 0 },
				["not watching him"] = { facing = G.TailFacing + 20 },
				["far off"] = { distance = G.TailRadius + 5 },
			}
		do
			check.equal(hold({}, follow(overrides), G.TailSeconds * 2), nil, name)
		end
	end)

	test("never in a hunt, at the table, unseen, or for the protected", function()
		for _, overrides in
			{
				{ hunting = true },
				{ seated = true },
				{ tier = 0 },
				{ stunned = true },
				{ visibleToThem = false },
				{ lineOfSight = false },
				{ hidden = true },
				{ downed = true },
				{ graced = true },
				{ safeRoom = true },
				{ verticalGap = 8 },
			}
		do
			check.equal(hold({}, follow(overrides), G.TailSeconds * 2), nil, next(overrides))
		end
	end)

	test("the reach is fair: a walk away keeps ahead, and it only takes you up close", function()
		check.atLeast(Config.Player.WalkSpeed, G.ReachSpeed + 0.5, "backing off at a walk outpaces him")
		check.atLeast(G.TailRadius, G.FollowRadius + 10, "tailing is the far case; crowding the near")
		check.truthy(StalkRules.reachHits(G.ReachGrab - 0.2, 0, true, G), "his hand on you")
		check.truthy(not StalkRules.reachHits(G.ReachGrab + 0.5, 0, true, G), "just out of reach")
		check.truthy(not StalkRules.reachHits(2, 0, false, G), "not through a wall")
		check.truthy(not StalkRules.reachHits(2, 9, true, G), "not up the stairs")
	end)
end
