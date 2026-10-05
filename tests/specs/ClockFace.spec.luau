return function(test, check, Shared, require)
	local ClockFace = require(Shared.Logic.ClockFace)
	local ClockTimes = require(Shared.Data.ClockTimes)

	test("hands: hours creep with the minutes, minutes go six degrees a minute", function()
		local h, m = ClockFace.angles("3:15")
		check.near(h, 97.5, 1e-9, "hour hand at 3:15")
		check.near(m, 90, 1e-9, "minute hand at 3:15")
		h, m = ClockFace.angles("12:00")
		check.near(h, 0, 1e-9, "hour hand at 12:00")
		check.near(m, 0, 1e-9, "minute hand at 12:00")
		h, m = ClockFace.angles("9:25")
		check.near(h, 282.5, 1e-9, "hour hand at 9:25")
		check.near(m, 150, 1e-9, "minute hand at 9:25")
	end)

	test("anything that isn't a time leaves the hands at twelve", function()
		for _, bad in { "", "XII", "25:00", "3:75", "noon" } do
			local h, m = ClockFace.angles(bad)
			check.equal(h + m, 0, "hands for " .. bad)
		end
		local h, m = ClockFace.angles(nil)
		check.equal(h + m, 0, "hands for nil")
	end)

	test("every time the house's clocks can show is readable on a clock face", function()
		for _, variant in ClockTimes do
			check.truthy(ClockFace.parse(variant) ~= nil, variant .. " does not parse")
		end
	end)
end
