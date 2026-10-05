-- Throws decided on the server (Logic/Throw): did the path a thing flew this
-- step pass through his body, and how long does a hit stop him.
return function(test, check, Shared, require)
	local roblox = require("@lune/roblox")
	local Vector3 = roblox.Vector3
	local Throw = require(Shared.Logic.Throw)
	local Config = require(Shared.Config)

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
		local honest = Throw.predict(from, v, g, 0.3)
		check.truthy(Throw.onArc(from, v, g, 0.3, honest, H), "where it should be")
		check.truthy(
			Throw.onArc(from, v, g, 0.3, honest + Vector3.new(1.5, 0, 0), H),
			"a little off (spin, the network)"
		)
		check.truthy(not Throw.onArc(from, v, g, 0.3, honest + Vector3.new(8, 0, 0), H), "steered sideways")
	end)

	test("a throw leaves along the aim at the class's speed, plus your own motion", function()
		local v = Throw.velocity(Vector3.new(0, 0, -2), 40, Vector3.new(5, 0, 0))
		check.near(v.Z, -40, 1e-9, "along the aim")
		check.near(v.X, 5, 1e-9, "plus your run")
	end)
end
