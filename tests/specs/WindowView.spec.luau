-- What's outside each window (Logic/WindowView).
return function(test, check, Shared, require)
	local Config = require(Shared.Config)
	local Rng = require(Shared.Lib.Rng)
	local WindowView = require(Shared.Logic.WindowView)

	local W = Config.Window

	test("compass directions: north is -Z, east is +X, and they grow clockwise", function()
		check.near(WindowView.azimuth(0, -1), 0, 1e-9, "north")
		check.near(WindowView.azimuth(1, 0), 90, 1e-9, "east")
		check.near(WindowView.azimuth(0, 1), 180, 1e-9, "south")
		check.near(WindowView.azimuth(-1, 0), 270, 1e-9, "west")
	end)

	test("angle differences fold into -180 to 180", function()
		check.near(WindowView.angleDiff(10, 30), 20, 1e-9, "simple")
		check.near(WindowView.angleDiff(350, 10), 20, 1e-9, "across north")
		check.near(WindowView.angleDiff(10, 350), -20, 1e-9, "the other way")
		check.near(math.abs(WindowView.angleDiff(0, 180)), 180, 1e-9, "opposite")
	end)

	test("the moon is in range, and different seeds put it in different places", function()
		local seen = {}
		for seed = 1, 40 do
			local moon = WindowView.moon(Rng.new(seed), W)
			check.truthy(moon.azimuth >= 0 and moon.azimuth < 360, "azimuth in range")
			check.truthy(
				moon.elevation >= W.MoonElevation[1] and moon.elevation <= W.MoonElevation[2],
				"elevation in range"
			)
			seen[math.floor(moon.azimuth / 30)] = true
		end
		local count = 0
		for _ in seen do
			count += 1
		end
		check.truthy(count >= 6, "the moon turns up in many directions across seeds")
	end)

	test("only windows that look towards the moon show it", function()
		local moon = { azimuth = 90, elevation = 30 }
		local east = WindowView.view(Rng.new(1), 90, moon, W)
		local west = WindowView.view(Rng.new(1), 270, moon, W)
		local northEast = WindowView.view(Rng.new(1), 50, moon, W)
		check.truthy(east.moonVisible, "an east window sees an east moon")
		check.truthy(not west.moonVisible, "a west window doesn't")
		check.truthy(northEast.moonVisible, "a window within the view angle does")
	end)

	test("the moon sits on the right of a window that looks to the left of it", function()
		local moon = { azimuth = 90, elevation = 30 }
		local looksNorth = WindowView.view(Rng.new(1), 40, moon, W) -- moon is clockwise of straight out
		local looksSouth = WindowView.view(Rng.new(1), 140, moon, W) -- moon is counter-clockwise of it
		check.truthy(looksNorth.moonX > 0.5, "on the right")
		check.truthy(looksSouth.moonX < 0.5, "on the left")
		local straight = WindowView.view(Rng.new(1), 90, moon, W)
		check.near(straight.moonX, 0.5, 1e-9, "dead ahead is the middle")
	end)

	test("the moon stays inside the pane, and higher in the sky is higher in the pane", function()
		for azimuth = 0, 359, 10 do
			for _, elevation in { W.MoonElevation[1], W.MoonElevation[2] } do
				local v = WindowView.view(Rng.new(azimuth + 1), 0, { azimuth = azimuth, elevation = elevation }, W)
				check.truthy(v.moonX >= 0.08 and v.moonX <= 0.92, "x inside the pane")
				check.truthy(v.moonY >= 0.1 and v.moonY <= 0.6, "y inside the pane")
			end
		end
		local low = WindowView.view(Rng.new(1), 0, { azimuth = 0, elevation = W.MoonElevation[1] }, W)
		local high = WindowView.view(Rng.new(1), 0, { azimuth = 0, elevation = W.MoonElevation[2] }, W)
		check.truthy(high.moonY < low.moonY, "a higher moon is nearer the top of the pane")
	end)

	test("every window gets a known covering, with all of them turning up", function()
		local known = { bare = true, sheer = true, blinds = true, boards = true }
		local counts = {}
		for seed = 1, 400 do
			local v = WindowView.view(Rng.new(seed), 0, { azimuth = 0, elevation = 30 }, W)
			check.truthy(known[v.cover], "unknown cover " .. tostring(v.cover))
			counts[v.cover] = (counts[v.cover] or 0) + 1
		end
		for name in known do
			check.truthy((counts[name] or 0) > 10, name .. " turns up")
		end
		check.truthy(counts.bare > counts.boards, "boards are rarer than a bare window")
	end)

	test("the same seed gives the same view", function()
		local moon = { azimuth = 200, elevation = 33 }
		local a = WindowView.view(Rng.new(77), 120, moon, W)
		local b = WindowView.view(Rng.new(77), 120, moon, W)
		check.equal(a.cover, b.cover, "cover")
		check.near(a.moonX, b.moonX, 1e-12, "x")
	end)
end
