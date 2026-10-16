-- The generator's brownout (Logic/Brownout): a cough, a stutter, the power
-- back; the same stutter for everyone; one smooth dip for "Reduce flicker".
return function(test, check, Shared, require)
	local Brownout = require(Shared.Logic.Brownout)
	local cfg = { Low = 0.15, StutterHigh = 0.6, Step = 0.07 }

	test("full power before and after, low at the cough", function()
		check.equal(Brownout.level(0, 2.4, 1, cfg), 1, "before")
		check.equal(Brownout.level(2.4, 2.4, 1, cfg), 1, "after")
		check.equal(Brownout.level(5, 2.4, 1, cfg), 1, "long after")
		check.truthy(Brownout.level(0.15, 2.4, 1, cfg) < 0.65, "down in the stutter")
	end)

	test("the stutter stays between its bounds and changes", function()
		local seen = {}
		for t = 0.2, 1.7, 0.05 do
			local level = Brownout.level(t, 2.4, 7, cfg)
			check.truthy(level >= cfg.Low - 1e-6 and level <= cfg.StutterHigh + 1e-6, "in bounds at " .. t)
			seen[math.floor(level * 20)] = true
		end
		local kinds = 0
		for _ in seen do
			kinds += 1
		end
		check.truthy(kinds >= 3, "it flickers, not one level")
	end)

	test("every client sees the same stutter for the same brownout", function()
		for t = 0.2, 1.7, 0.1 do
			check.equal(Brownout.level(t, 2.4, 42, cfg), Brownout.level(t, 2.4, 42, cfg), "same at " .. t)
		end
	end)

	test("Reduce flicker gets one smooth dip", function()
		local last = 1
		for t = 0.05, 1.2, 0.05 do
			local level = Brownout.level(t, 2.4, 3, cfg, true)
			check.truthy(level <= last + 1e-9, "only down to the middle")
			last = level
		end
		check.truthy(math.abs(last - cfg.Low) < 0.05, "down to Low at the middle")
		for t = 1.25, 2.35, 0.05 do
			local level = Brownout.level(t, 2.4, 3, cfg, true)
			check.truthy(level >= last - 1e-9, "only up after it")
			last = level
		end
	end)
end
