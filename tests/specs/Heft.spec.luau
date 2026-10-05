-- How a carried thing moves in your hands (Logic/Heft): it follows your eye
-- with its class's weight.
return function(test, check, Shared, require)
	local Heft = require(Shared.Logic.Heft)
	local Physical = require(Shared.Data.Physical)

	local function follow(omega: number, seconds: number, dt: number)
		local x, v = 0, 0
		for _ = 1, math.floor(seconds / dt) do
			x, v = Heft.spring(x, v, 1, omega, dt)
		end
		return x, v
	end

	test("it gets where your eye is, and never overshoots", function()
		local peak = 0
		local x, v = 0, 0
		for _ = 1, 120 do
			x, v = Heft.spring(x, v, 1, 18, 1 / 60)
			peak = math.max(peak, x)
		end
		check.near(x, 1, 1e-3, "arrived")
		check.atMost(peak, 1 + 1e-6, "no wobble past the target")
	end)

	test("heavy things trail: after a quick turn a light thing is further along", function()
		local C = Physical.Classes
		local light = follow(C.light.carry.omega, 0.1, 1 / 60)
		local heavy = follow(C.heavy.carry.omega, 0.1, 1 / 60)
		local bulky = follow(C.bulky.carry.omega, 0.1, 1 / 60)
		check.truthy(light > heavy and heavy > bulky, "the heavier, the further behind")
	end)

	test("the same at any frame rate", function()
		local fast = follow(18, 0.5, 1 / 240)
		local slow = follow(18, 0.5, 1 / 20)
		check.near(fast, slow, 0.02, "30 fps or 240 fps, it moves the same")
	end)

	test("swung, it leans the other way, never past its class's tilt", function()
		check.truthy(Heft.lean(10, 0.4) < 0, "leans against the swing")
		check.near(Heft.lean(1000, 0.4), -0.4, 1e-9, "no further than its tilt")
		check.equal(Heft.lean(0, 0.4), 0, "still: upright")
	end)

	test("every class can carry and be told apart", function()
		for name, class in Physical.Classes do
			local c = class.carry
			check.truthy(c and c.omega > 0 and c.forceG > 0 and c.maxSpeed > 0, name .. " has carry numbers")
		end
		check.truthy(Heft.speedCap(45, 19, 20) > 45 + 19, "the server's cap leaves room for the holder and the network")
	end)
end
