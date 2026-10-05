-- Barricades (Logic/Barricade): a piece across a doorway's lane bars it, one
-- off to the side or further into the room doesn't, and he's never held
-- longer than ShoveMax.
return function(test, check, Shared, require)
	local Config = require(Shared.Config)
	local Barricade = require(Shared.Logic.Barricade)

	local cfg = Config.Barricade
	-- A doorway in a wall along x, at (0, 0), the room to +z.
	local lane = { x = 0, z = 0, ix = 0, iz = 1, width = 6, depth = 5, approach = Config.Nav.Approach }

	test("a bed across the doorway bars it; one to the side or deep in the room doesn't", function()
		local bed = { x = 0, z = 3, yaw = 0, w = 7, d = 4 }
		check.near(Barricade.cover(lane, bed), 1, 1e-6, "right across")
		check.truthy(Barricade.bars(lane, bed, cfg), "bars it")
		local aside = { x = 6.5, z = 3, yaw = 0, w = 7, d = 4 }
		check.truthy(not Barricade.bars(lane, aside, cfg), "beside the doorway")
		local deep = { x = 0, z = 9, yaw = 0, w = 7, d = 4 }
		check.equal(Barricade.cover(lane, deep), 0, "past the lane's depth")
	end)

	test("turned a quarter round, its depth is what covers the lane", function()
		local dresser = { x = 0, z = 2, yaw = math.pi / 2, w = 6, d = 2.5 }
		-- Turned, its 2.5 depth runs along the wall: 2.5 of 6.
		check.near(Barricade.cover(lane, dresser), 2.5 / 6, 1e-6, "its depth across")
		check.truthy(Barricade.bars(lane, dresser, cfg), "still bars it")
	end)

	test("slid in along the wall, it bars the doorway once it's on his way", function()
		-- Pushing a dresser in from beside the doorway: it reaches the approach
		-- before it covers much of the width, and from then on it bars it, so
		-- PushService lets it go on in (it keeps pieces off his walking points
		-- unless they bar the doorway).
		local first = nil
		for i = 0, 40 do
			local x = 9 - i * 0.25
			local piece = { x = x, z = 1.6, yaw = 0, w = 6, d = 2.5 }
			local onWay = Barricade.covers(lane, piece, 0, lane.approach, cfg.NodeClear)
				or Barricade.covers(lane, piece, 0, 0, cfg.NodeClear)
			check.truthy(not onWay or Barricade.bars(lane, piece, cfg), "on his way means barred")
			if Barricade.bars(lane, piece, cfg) and not first then
				first = piece
			end
		end
		check.truthy(first ~= nil, "it ends up barring the doorway")
		check.truthy(Barricade.cover(lane, first) < cfg.Cover, "by his walking points, before the width")
	end)

	test("every shove leaves the doorway open", function()
		local pieces = {
			{ x = 0, z = 3, yaw = 0, w = 7, d = 4 },
			{ x = 1.5, z = 2, yaw = math.pi / 2, w = 6, d = 2.5 },
			{ x = -2, z = 1.4, yaw = 0.3, w = 4, d = 2 },
		}
		for _, piece in pieces do
			check.truthy(Barricade.bars(lane, piece, cfg), "it starts barring")
			for _, outside in { true, false } do
				local shoves = Barricade.shoves(lane, piece, outside, cfg)
				check.truthy(#shoves >= 4, "a few ways to try")
				for _, shove in shoves do
					-- The lane runs +z, so u is -x here (tx, tz = -iz, ix).
					local moved = table.clone(piece)
					moved.x -= shove[1]
					moved.z += shove[2]
					check.truthy(not Barricade.bars(lane, moved, cfg), "clear after the shove")
					check.truthy(math.abs(shove[1]) + math.abs(shove[2]) < 12, "not flung across the room")
				end
			end
		end
	end)

	test("a footprint's edge points go all the way round it", function()
		local piece = { x = 2, z = -1, yaw = math.pi / 2, w = 6, d = 2 }
		local points = Barricade.edgePoints(piece, 0.5)
		check.truthy(#points >= 2 * (12 + 4), "about every half stud")
		for _, point in points do
			-- Turned a quarter, its 6 runs along z and its 2 along x.
			check.truthy(math.abs(point.x - 2) <= 1 + 1e-6 and math.abs(point.z + 1) <= 3 + 1e-6, "on its footprint")
			local onEdge = math.abs(math.abs(point.x - 2) - 1) < 1e-6 or math.abs(math.abs(point.z + 1) - 3) < 1e-6
			check.truthy(onEdge, "on its edge")
		end
	end)

	test("he shoves it clear within ShoveMax, quicker when hunting", function()
		for _, weight in { 0.6, 1, 1.5, 2, 3.5, 10 } do
			local calm = Barricade.shoveSeconds(weight, false, cfg)
			local hunt = Barricade.shoveSeconds(weight, true, cfg)
			check.truthy(calm <= cfg.ShoveMax and hunt <= cfg.ShoveMax, "never over the cap")
			check.truthy(hunt <= calm, "quicker hunting")
		end
		check.truthy(
			Barricade.shoveSeconds(2, false, cfg) > Barricade.shoveSeconds(1, false, cfg),
			"heavier takes longer"
		)
	end)
end
