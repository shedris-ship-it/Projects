-- A potted plant's leaves stay inside its footprint (Logic/PlantLeaves).
return function(test, check, Shared, require)
	local Config = require(Shared.Config)
	local Props = require(Shared.Data.Props)
	local Rng = require(Shared.Lib.Rng)
	local PlantLeaves = require(Shared.Logic.PlantLeaves)

	local C = Config.Plant
	local reach = Props.Kinds.Plant.reach

	test("no leaf reaches past the plant's footprint, for any seed", function()
		for seed = 1, 300 do
			for _, leaf in PlantLeaves.layout(Rng.new(seed), C, reach) do
				check.truthy(
					PlantLeaves.extent(leaf) <= reach - C.Margin + 1e-9,
					string.format("seed %d: a leaf reaches %.2f of %.2f", seed, PlantLeaves.extent(leaf), reach)
				)
			end
		end
	end)

	test("leaves lean out no more than the limit and are never shortened to fit", function()
		for seed = 1, 100 do
			for _, leaf in PlantLeaves.layout(Rng.new(seed), C, reach) do
				check.truthy(math.deg(leaf.tilt) <= C.Tilt[2] + 1e-9, "leans too far")
				check.truthy(leaf.tilt >= 0, "leans inwards")
				check.truthy(leaf.length >= C.Length[1] and leaf.length <= C.Length[2], "length in range")
				check.truthy(leaf.width >= C.Width[1] and leaf.width <= C.Width[2], "width in range")
			end
		end
	end)

	test("a plant has a handful of leaves, fanned right round it", function()
		for seed = 1, 100 do
			local leaves = PlantLeaves.layout(Rng.new(seed), C, reach)
			check.truthy(#leaves >= C.Count[1] and #leaves <= C.Count[2], "leaf count")
			-- Sorted by azimuth, no gap round the pot is wider than a third of a turn.
			local angles = {}
			for _, leaf in leaves do
				table.insert(angles, leaf.azimuth % (2 * math.pi))
			end
			table.sort(angles)
			for i = 1, #angles do
				local nextAngle = angles[i % #angles + 1] + (i == #angles and 2 * math.pi or 0)
				check.truthy(nextAngle - angles[i] <= 2 * math.pi / 3, "a bare side of the plant")
			end
		end
	end)

	test("a tight limit stands the leaves straighter instead of letting them poke out", function()
		local tight = {
			Count = { 8, 8 },
			Length = { 1.8, 1.8 },
			Width = { 0.5, 0.5 },
			Tilt = { 28, 28 },
			BaseRadius = { 0.2, 0.2 },
			Margin = 0.05,
		}
		for _, leaf in PlantLeaves.layout(Rng.new(3), tight, 0.6) do
			check.truthy(PlantLeaves.extent(leaf) <= 0.6 - 0.05 + 1e-9, "inside a small footprint")
		end
	end)

	test("the same seed grows the same plant", function()
		local a = PlantLeaves.layout(Rng.new(42), C, reach)
		local b = PlantLeaves.layout(Rng.new(42), C, reach)
		check.equal(#a, #b, "same leaf count")
		for i = 1, #a do
			check.near(a[i].azimuth, b[i].azimuth, 1e-12, "azimuth")
			check.near(a[i].tilt, b[i].tilt, 1e-12, "tilt")
		end
	end)
end
