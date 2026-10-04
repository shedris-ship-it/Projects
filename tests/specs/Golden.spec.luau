return function(test, check, Shared, require)
	local fs = require("@lune/fs")
	local Config = require(Shared.Config)
	local Rooms = require(Shared.Data.Rooms)
	local LevelGraph = require(Shared.Logic.LevelGraph)
	local FloorPlan = require(Shared.Logic.FloorPlan)

	-- The old generator is the default until the owner approves the mansion
	-- (docs/plans/mansion-generation.md), so its houses must never change.
	test("the old generator builds exactly the recorded houses (tests/golden/LevelGraph.txt)", function()
		local changed = {}
		local count = 0
		for line in string.gmatch(fs.readFile("tests/golden/LevelGraph.txt"), "[^\n]+") do
			local seed, hash = string.match(line, "^(%d+) (%d+)$")
			if seed then
				count += 1
				local layout = LevelGraph.generate(tonumber(seed) :: number, Rooms.List, Config.Level)
				if FloorPlan.hash(layout) ~= tonumber(hash) then
					table.insert(changed, seed)
				end
			end
		end
		check.atLeast(count, 1000, "golden seeds")
		check.equal(
			#changed,
			0,
			"seeds whose layout changed (compare with `lune run tools/plan <seed>`): "
				.. table.concat(changed, ", ", 1, math.min(#changed, 10))
		)
	end)

	test("a fingerprint notices a changed door", function()
		local layout = LevelGraph.generate(4242, Rooms.List, Config.Level)
		local before = FloorPlan.hash(layout)
		local seam = layout.seams[1]
		seam.door = not seam.door
		check.truthy(FloorPlan.hash(layout) ~= before, "flipping a door left the hash unchanged")
	end)
end
