-- Where clutter, photos and telephones can stand on a furniture top
-- (Logic/SurfaceSpots). Owner, 2026-10-04: new props clipped into each other.
return function(test, check, Shared, require)
	local Config = require(Shared.Config)
	local Props = require(Shared.Data.Props)
	local Rng = require(Shared.Lib.Rng)
	local SurfaceSpots = require(Shared.Logic.SurfaceSpots)

	local D = Config.Dressing

	local function plan(kindName: string, seed: number)
		local kind = Props.Kinds[kindName]
		return SurfaceSpots.plan(Rng.new(seed), kind, Props.Keepouts(kindName, kind.size), D), kind
	end

	test("spots stay on the top, off its edges, at the height of the top", function()
		for name, kind in Props.Kinds do
			if kind.top then
				local z0 = kind.topSpan and kind.topSpan[1] or -kind.size[3] / 2
				local z1 = kind.topSpan and kind.topSpan[2] or kind.size[3] / 2
				for seed = 1, 25 do
					for _, spot in (plan(name, seed)) do
						check.truthy(
							spot.z >= z0 + 0.5 - 1e-9 and spot.z <= z1 - 0.5 + 1e-9,
							name .. " spot z " .. spot.z .. " leaves the top"
						)
						check.truthy(
							math.abs(spot.x) <= kind.size[1] / 2 - 0.3 + 1e-9,
							name .. " spot x leaves the top"
						)
						check.equal(spot.y, kind.size[2], name .. " spot height")
					end
				end
			end
		end
	end)

	test("nothing is set down inside a counter's sink basin", function()
		local centre, basin = Props.CounterSink(Props.Kinds.Counter.size[1])
		local seen = 0
		for seed = 1, 40 do
			for _, spot in (plan("Counter", seed)) do
				seen += 1
				check.truthy(
					math.abs(spot.x - centre) >= basin / 2 + 0.5,
					string.format("counter spot at x=%.2f is over the basin (%.2f wide at %.2f)", spot.x, basin, centre)
				)
			end
		end
		check.truthy(seen > 0, "the counter still has places for things")
	end)

	test("nothing is set down on a workbench's vice", function()
		local size = Props.Kinds.Workbench.size
		local viceX = size[1] / 2 - 1
		local seen = 0
		for seed = 1, 40 do
			for _, spot in (plan("Workbench", seed)) do
				seen += 1
				check.truthy(
					math.abs(spot.x - viceX) >= 0.4 + 0.5,
					"workbench spot at x=" .. spot.x .. " is on the vice"
				)
			end
		end
		check.truthy(seen > 0, "the workbench still has places for things")
	end)

	test("a piano's things stay on the body, not over the keyboard end", function()
		for seed = 1, 40 do
			for _, spot in (plan("Piano", seed)) do
				check.truthy(spot.z <= 0 + 1e-9, "piano spot z " .. spot.z .. " overhangs the keyboard")
			end
		end
	end)

	test("the same seed plans the same spots", function()
		local a = plan("Dresser", 7)
		local b = plan("Dresser", 7)
		check.equal(#a, #b, "same count")
		for i = 1, #a do
			check.near(a[i].x, b[i].x, 1e-12, "x")
			check.near(a[i].z, b[i].z, 1e-12, "z")
			check.near(a[i].yaw, b[i].yaw, 1e-12, "yaw")
		end
	end)

	test("a keep-out takes spots away without changing the random draws that follow", function()
		local kind = Props.Kinds.Counter
		local free, blocked = Rng.new(99), Rng.new(99)
		local all = SurfaceSpots.plan(free, kind, {}, D)
		local some = SurfaceSpots.plan(blocked, kind, Props.Keepouts("Counter", kind.size), D)
		check.truthy(#some < #all, "the keep-out removes at least one spot")
		check.equal(free:NextInteger(1, 1000000), blocked:NextInteger(1, 1000000), "later draws are unchanged")
	end)
end
