-- Crowding him (Logic/StalkRules.crowding; the squad playtest, 2026-10-08:
-- "players can get in his personal space while he's backing away without
-- consequences"). The owner's choice: a scare first, then a down.
return function(test, check, Shared, require)
	local Config = require(Shared.Config)
	local StalkRules = require(Shared.Logic.StalkRules)
	local G = Config.Guest

	local function face(overrides)
		local ctx = {
			now = 0,
			distance = G.CrowdRadius - 1,
			facing = 10,
			closing = 0,
			backingAway = false,
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

	-- Hold a situation for `seconds`; the first outcome, if any.
	local function hold(state, ctx, seconds)
		for _ = 1, math.floor(seconds / 0.1 + 0.5) do
			local result = StalkRules.crowding(state, ctx, 0.1, G)
			if result then
				return result
			end
		end
		return nil
	end

	test("in his face for a moment: the scare; again soon after: the grab", function()
		local state = {}
		check.equal(hold(state, face(), G.CrowdSeconds * 0.5), nil, "a moment is nothing")
		check.equal(hold(state, face(), G.CrowdSeconds), "scare", "then he turns on you")
		check.equal(hold(state, face({ now = 60 }), G.CrowdSeconds + 0.2), "grab", "again within the window")
	end)

	test("long after a scare, it's a scare again", function()
		local state = {}
		hold(state, face(), G.CrowdSeconds + 0.2)
		check.equal(hold(state, face({ now = G.GrabWindow + 10 }), G.CrowdSeconds + 0.2), "scare", "forgiven")
	end)

	test("following him as he backs away counts; standing back doesn't", function()
		local follow = face({ distance = G.FollowRadius - 1, facing = 60, backingAway = true, closing = 3 })
		check.equal(hold({}, follow, G.CrowdSeconds / G.FollowRate + 0.3), "scare", "following")
		local back = face({ distance = G.FollowRadius - 1, facing = 60, backingAway = true, closing = 0 })
		check.equal(hold({}, back, 5), nil, "watching him go")
	end)

	test("walking past him never fills it", function()
		local state = {}
		-- A walk at 8 studs a second spends 2 * CrowdRadius / 8 seconds inside.
		local inside = 2 * G.CrowdRadius / Config.Player.WalkSpeed
		check.atMost(inside, G.CrowdSeconds * 0.8, "too brief to count")
		check.equal(hold(state, face(), inside), nil, "a pass")
		check.equal(hold(state, face({ distance = 9 }), 3), nil, "then away")
		check.equal(state.pressure, 0, "and it drains")
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
			check.equal(hold({}, face(overrides), 5), nil, next(overrides))
		end
	end)

	test("looking away isn't crowding", function()
		check.equal(hold({}, face({ facing = G.CrowdFacing + 20 }), 5), nil, "back turned")
	end)
end
