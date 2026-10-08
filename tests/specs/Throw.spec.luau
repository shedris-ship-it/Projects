-- Throws decided on the server (Logic/Throw): did the path a thing flew this
-- step pass through his body, and how long does a hit stop him.
return function(test, check, Shared, require)
	local roblox = require("@lune/roblox")
	local Vector3 = roblox.Vector3
	local Throw = require(Shared.Logic.Throw)
	local Config = require(Shared.Config)
	local Physical = require(Shared.Data.Physical)

	local feet, head = Vector3.new(0, 0, 0), Vector3.new(0, 6, 0)

	test("a throw straight through him hits, even when one step jumps right past", function()
		check.truthy(Throw.hits(Vector3.new(-5, 3, 0), Vector3.new(5, 3, 0), feet, head, 1.2), "through the chest")
		check.truthy(Throw.hits(Vector3.new(-30, 3, 0.5), Vector3.new(30, 3, 0.5), feet, head, 1.2), "a long fast step")
	end)

	test("a throw that passes by, over his head or stops short misses", function()
		check.truthy(not Throw.hits(Vector3.new(-5, 3, 3), Vector3.new(5, 3, 3), feet, head, 1.2), "beside him")
		check.truthy(not Throw.hits(Vector3.new(-5, 9, 0), Vector3.new(5, 9, 0), feet, head, 1.2), "over his head")
		check.truthy(not Throw.hits(Vector3.new(-9, 3, 0), Vector3.new(-3, 3, 0), feet, head, 1.2), "short of him")
	end)

	test("a throw through a glass case breaks it; one past it, over it or short of it doesn't", function()
		local CFrame = roblox.CFrame
		-- A case turned a quarter round, standing on a table at (10, 3, 0).
		local box = CFrame.new(10, 3.5, 0) * CFrame.Angles(0, math.pi / 2, 0)
		local size = Vector3.new(1.2, 0.75, 0.9)
		check.truthy(
			Throw.segmentBox(Vector3.new(0, 3.5, 0), Vector3.new(20, 3.5, 0), box, size, 0.2),
			"straight through"
		)
		check.truthy(
			Throw.segmentBox(Vector3.new(8, 3.6, 0), Vector3.new(9.6, 3.5, 0.1), box, size, 0.2),
			"a step ending in it"
		)
		check.truthy(not Throw.segmentBox(Vector3.new(0, 3.5, 2), Vector3.new(20, 3.5, 2), box, size, 0.2), "beside it")
		check.truthy(not Throw.segmentBox(Vector3.new(0, 5, 0), Vector3.new(20, 5, 0), box, size, 0.2), "over it")
		check.truthy(
			not Throw.segmentBox(Vector3.new(0, 3.5, 0), Vector3.new(8, 3.5, 0), box, size, 0.2),
			"short of it"
		)
		-- Turned, its width (1.2) runs along Z: 0.6 either side plus 0.2 of pad.
		check.truthy(
			not Throw.segmentBox(Vector3.new(0, 3.5, 0.85), Vector3.new(20, 3.5, 0.85), box, size, 0.2),
			"graze"
		)
		check.truthy(Throw.segmentBox(Vector3.new(0, 3.5, 0.75), Vector3.new(20, 3.5, 0.75), box, size, 0.2), "clip")
	end)

	test("segment distances", function()
		check.near(
			Throw.segmentSegment(Vector3.new(0, 0, 0), Vector3.new(1, 0, 0), Vector3.new(0, 1, 0), Vector3.new(1, 1, 0)),
			1,
			1e-9,
			"parallel"
		)
		check.near(
			Throw.segmentSegment(
				Vector3.new(-1, 0, 0),
				Vector3.new(1, 0, 0),
				Vector3.new(0, -1, 2),
				Vector3.new(0, 1, 2)
			),
			2,
			1e-9,
			"crossing at a distance"
		)
		check.near(
			Throw.segmentSegment(Vector3.new(2, 0, 0), Vector3.new(2, 0, 0), Vector3.new(0, 0, 0), Vector3.new(0, 5, 0)),
			2,
			1e-9,
			"a point and a segment"
		)
	end)

	test("stuns shrink when repeated, and are shorter in the final hunt", function()
		check.near(Throw.stunSeconds(1.2, 0, false, 0.6), 1.2, 1e-9, "a first hit")
		check.near(Throw.stunSeconds(1.2, 1, false, 0.6), 0.6, 1e-9, "halved")
		check.near(Throw.stunSeconds(1.2, 2, false, 0.6), 0.3, 1e-9, "and again")
		check.near(Throw.stunSeconds(1.2, 0, true, 0.6), 0.72, 1e-9, "final hunt")
	end)

	test("a wind-up: a tap throws softly, a full wind-up throws at full speed", function()
		local H = Config.Hands
		check.near(Throw.charge(0, H), H.ChargeLow, 1e-9, "a tap")
		check.near(Throw.charge(H.ChargeFull + 1, H), 1, 1e-9, "wound up")
		local mid = Throw.charge((H.ChargeMin + H.ChargeFull) / 2, H)
		check.truthy(mid > H.ChargeLow and mid < 1, "in between")
	end)

	test("a stun counts only on a throw's first arc: it can't be steered into him", function()
		local H = Config.Hands
		local from, v = Vector3.new(0, 5, 0), Vector3.new(0, 4, -40)
		local g = Vector3.new(0, -196.2, 0)
		local honest = Throw.predict(from, v, g, 0.3, H.FlightLift, H.FlightLiftSeconds)
		check.truthy(Throw.onArc(from, v, g, 0.3, honest, H), "where it should be")
		check.truthy(
			Throw.onArc(from, v, g, 0.3, honest + Vector3.new(1.5, 0, 0), H),
			"a little off (spin, the network)"
		)
		check.truthy(not Throw.onArc(from, v, g, 0.3, honest + Vector3.new(8, 0, 0), H), "steered sideways")
	end)

	-- The squad playtest (2026-10-08): "weak throws".
	test("a throw flies flatter at first, then falls as before, with no jump between", function()
		local H = Config.Hands
		local from, v = Vector3.new(0, 5, 0), Vector3.new(0, 0, -60)
		local g = Vector3.new(0, -196.2, 0)
		local plain = Throw.predict(from, v, g, 0.4)
		local lifted = Throw.predict(from, v, g, 0.4, H.FlightLift, H.FlightLiftSeconds)
		check.truthy(lifted.Y > plain.Y + 5, "higher after 0.4 s")
		local t = H.FlightLiftSeconds
		local before = Throw.predict(from, v, g, t - 1e-4, H.FlightLift, t)
		local after = Throw.predict(from, v, g, t + 1e-4, H.FlightLift, t)
		check.atMost((after - before).Magnitude, 0.05, "continuous where the lift ends")
		-- A full light throw at a wall 25 studs off arrives near head height.
		local speed = Physical.Classes.light.throwSpeed
		local flight = 25 / speed
		local at = Throw.predict(from, Vector3.new(0, speed * H.ThrowLift, -speed), g, flight, H.FlightLift, t)
		check.atLeast(at.Y, from.Y - 3, "drops under 3 studs over 25")
	end)

	test("every class stuns wound up; a tap stuns only with light and medium things", function()
		local H = Config.Hands
		for name, class in Physical.Classes do
			check.atLeast(class.throwSpeed, H.StunMinSpeed, name .. ": a full throw stuns")
		end
		local tap = Throw.charge(0, H)
		check.atLeast(Physical.Classes.light.throwSpeed * tap, H.StunMinSpeed, "a tapped bottle")
		check.atLeast(Physical.Classes.medium.throwSpeed * tap, H.StunMinSpeed, "a tapped vase")
		check.truthy(Physical.Classes.heavy.throwSpeed * tap < H.StunMinSpeed, "a heavy thing wants a wind-up")
	end)

	test("a throw leaves along the aim at the class's speed, plus your own motion", function()
		local v = Throw.velocity(Vector3.new(0, 0, -2), 40, Vector3.new(5, 0, 0))
		check.near(v.Z, -40, 1e-9, "along the aim")
		check.near(v.X, 5, 1e-9, "plus your run")
	end)
end
