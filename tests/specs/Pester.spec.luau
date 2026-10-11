-- Pestering him (Logic/StalkRules.pestering; "a Guest you can read",
-- 2026-10-11): rule two of three. Standing in his face, following him close
-- as he backs away and tailing him further off fill one meter. His head
-- turns first, then one warning, then he comes for you with his hands out
-- (the owner's choice). It joins the old crowding (the squad playtest,
-- 2026-10-08) and tailing (the owner, 2026-10-11) rules.
return function(test, check, Shared, require)
	local Config = require(Shared.Config)
	local StalkRules = require(Shared.Logic.StalkRules)
	local G = Config.Guest

	local function ctx(overrides)
		local c = {
			now = 0,
			distance = 20,
			facing = 10,
			closing = 0,
			backingAway = false,
			away = 0,
			along = 0,
			tailCounts = true,
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
			c[k] = v
		end
		return c
	end

	-- In his face, looking at him.
	local function face(overrides)
		local c = ctx({ distance = G.CrowdRadius - 1 })
		for k, v in overrides or {} do
			c[k] = v
		end
		return c
	end

	-- Tailing him: he walks away at his walk, you go after him at yours.
	local function tail(overrides)
		local c = ctx({ distance = 18, away = G.WalkSpeed, along = Config.Player.WalkSpeed })
		for k, v in overrides or {} do
			c[k] = v
		end
		return c
	end

	-- Hold a situation for `seconds`; the first warn or reach, if any, and
	-- whether he noticed on the way.
	local function hold(state, c, seconds)
		local noticed = false
		for _ = 1, math.floor(seconds / 0.1 + 0.5) do
			local result = StalkRules.pestering(state, c, 0.1, G)
			if result == "notice" then
				noticed = true
			elseif result then
				return result, noticed
			end
		end
		return nil, noticed
	end

	test("in his face: his head turns, then the warning; again soon after: the reach", function()
		local state = {}
		local result, noticed = hold(state, face(), G.CrowdSeconds * 0.5)
		check.equal(result, nil, "a moment is nothing yet")
		check.truthy(noticed, "but his head turns")
		check.equal(hold(state, face(), G.CrowdSeconds), "warn", "then he warns you")
		check.equal(StalkRules.pesterMeter(state), 0, "and it starts again")
		check.equal(hold(state, face({ now = 60 }), G.CrowdSeconds + 0.2), "reach", "again within the memory")
		check.equal(hold(state, face({ now = 90 }), G.CrowdSeconds + 0.2), "reach", "and again, while he remembers")
	end)

	test("long after, it's a warning again", function()
		local state = {}
		hold(state, face(), G.CrowdSeconds + 0.2)
		check.equal(hold(state, face({ now = G.PesterMemory + 10 }), G.CrowdSeconds + 0.2), "warn", "forgiven")
	end)

	test("notice comes before the warning, at PesterNotice", function()
		local state = {}
		local first = nil
		for i = 1, 100 do
			local result = StalkRules.pestering(state, face(), 0.02, G)
			if result then
				first = { result = result, meter = StalkRules.pesterMeter(state), step = i }
				break
			end
		end
		check.equal(first and first.result, "notice", "his head first")
		check.atLeast(first.meter, G.PesterNotice, "at the notice share")
		check.atMost(first.meter, G.PesterNotice + 0.05, "not later")
	end)

	test("following him close as he backs away counts; watching him go doesn't", function()
		local follow = ctx({ distance = G.FollowRadius - 1, facing = 60, backingAway = true, closing = 3 })
		check.equal(hold({}, follow, G.CrowdSeconds / G.FollowRate + 0.3), "warn", "following")
		local back = ctx({ distance = G.FollowRadius - 1, facing = 60, backingAway = true, closing = 0 })
		check.equal(hold({}, back, 5), nil, "watching him go")
	end)

	test("tailing him a while: the warning, then the reach", function()
		local state = {}
		check.equal(hold(state, tail(), G.TailSeconds * 0.5), nil, "a moment is nothing")
		check.equal(hold(state, tail(), G.TailSeconds * 0.5 + 0.2), "warn", "then he warns you")
		check.equal(hold(state, tail({ now = 60 }), G.TailSeconds + 0.2), "reach", "keep on and he comes for you")
	end)

	test("stop-start tailing still adds up", function()
		local state = {}
		local result = nil
		for _ = 1, 6 do
			result = result or hold(state, tail(), G.TailSeconds / 3)
			result = result or hold(state, tail({ along = 0 }), 1.5)
		end
		check.equal(result, "warn", "pausing to let him get ahead doesn't hide it")
	end)

	test("the parts add up: tail him a while, then step into his face", function()
		local state = {}
		check.equal(hold(state, tail(), G.TailSeconds * 0.6), nil, "tailing, not yet full")
		check.equal(hold(state, face(), G.CrowdSeconds * 0.5), "warn", "half a crowding on top of it fills the meter")
	end)

	test("tailing doesn't count when the caller says so (his own scare, leaving)", function()
		check.equal(hold({}, tail({ tailCounts = false }), G.TailSeconds * 2), nil, "not tailing then")
		check.equal(hold({}, face({ tailCounts = false }), G.CrowdSeconds + 0.2), "warn", "his face still counts")
	end)

	test("walking past him never fills it, twice in a row either", function()
		local state = {}
		-- A walk at 8 studs a second spends 2 * CrowdRadius / 8 seconds inside.
		local inside = 2 * G.CrowdRadius / Config.Player.WalkSpeed
		check.atMost(inside, G.CrowdSeconds * 0.8, "too brief to count")
		check.equal(hold(state, face(), inside), nil, "a pass")
		check.equal(hold(state, ctx({ distance = 9 }), 3), nil, "then away")
		check.equal(hold(state, face(), inside), nil, "and back past")
		check.equal(hold(state, ctx({ distance = 9 }), 3), nil, "away again")
		check.equal(StalkRules.pesterMeter(state), 0, "it drains")
	end)

	test("tailing across a room is noticed and warned before you'd be in his face", function()
		-- From 25 studs, gaining two a second (your walk 8, his 6).
		local state = {}
		local distance = 25
		local result = nil
		while not result or result == "notice" do
			result = StalkRules.pestering(state, tail({ distance = distance }), 0.1, G)
			distance -= (Config.Player.WalkSpeed - G.WalkSpeed) * 0.1
			if distance <= G.CrowdRadius then
				break
			end
		end
		check.equal(result, "warn", "he turned on you")
		check.atLeast(distance, G.FollowRadius, "well before arm's reach")
	end)

	test("only following counts when you're further off", function()
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
			check.equal(hold({}, tail(overrides), G.TailSeconds * 2), nil, name)
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
			local result, noticed = hold({}, face(overrides), 5)
			check.equal(result, nil, next(overrides))
			check.truthy(not noticed, "and no notice: " .. next(overrides))
			check.equal(hold({}, tail(overrides), G.TailSeconds * 2), nil, "tailing: " .. next(overrides))
		end
	end)

	test("looking away in his face isn't pestering", function()
		check.equal(hold({}, face({ facing = G.CrowdFacing + 20 }), 5), nil, "back turned")
	end)

	test("the reach is fair: a walk away keeps ahead, and it only takes you up close", function()
		check.atLeast(Config.Player.WalkSpeed, G.ReachSpeed + 0.5, "backing off at a walk outpaces him")
		-- Right in his face (2 studs), a walk back started within 0.3 s of his
		-- hands coming up clears them before the windup is over.
		check.atLeast(2 + Config.Player.WalkSpeed * (G.ReachWindup - 0.3), G.ReachGrab + 1, "the windup is a chance")
		check.atLeast(G.TailRadius, G.FollowRadius + 10, "tailing is the far case; crowding the near")
		check.truthy(G.PesterNotice > 0 and G.PesterNotice < 1, "the notice comes before the warning")
		check.truthy(StalkRules.reachHits(G.ReachGrab - 0.2, 0, true, G), "his hand on you")
		check.truthy(not StalkRules.reachHits(G.ReachGrab + 0.5, 0, true, G), "just out of reach")
		check.truthy(not StalkRules.reachHits(2, 0, false, G), "not through a wall")
		check.truthy(not StalkRules.reachHits(2, 9, true, G), "not up the stairs")
	end)
end
