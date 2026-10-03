return function(test, check, Shared, require)
	local Graph = require(Shared.Logic.Graph)
	local BeliefMap = require(Shared.Logic.BeliefMap)
	local Rng = require(Shared.Lib.Rng)

	-- A line of five rooms: 1-2-3-4-5.
	local function line()
		return Graph.adjacency({ 1, 2, 3, 4, 5 }, { { 1, 2 }, { 2, 3 }, { 3, 4 }, { 4, 5 } })
	end

	local function total(map)
		local sum = 0
		for _, id in map.ids do
			sum += map:Get(id)
		end
		return sum
	end

	test("starts as the habit prior, and sums to 1", function()
		local map = BeliefMap.new(line(), { [4] = 10 })
		check.near(total(map), 1, 1e-9, "total")
		check.equal((map:Best()), 4, "most-used room")
	end)

	test("with no habits it starts uniform and ties go to the lowest id", function()
		local map = BeliefMap.new(line())
		check.near(map:Get(1), map:Get(5), 1e-9, "uniform")
		check.equal((map:Best()), 1, "tiebreak")
	end)

	test("seeing a player collapses the belief onto their room", function()
		local map = BeliefMap.new(line(), { [4] = 10 })
		map:Observe(2)
		check.equal((map:Best()), 2)
		check.near(map:Certainty(), 1, 1e-9, "certain")
	end)

	test("a noise pulls belief to its room and the neighbours, by distance", function()
		local map = BeliefMap.new(line())
		map:Hear(3, 0.8, 2)
		check.equal((map:Best()), 3)
		check.truthy(map:Get(2) > map:Get(1), "near room likelier than far room")
		check.near(total(map), 1, 1e-9, "total")
	end)

	test("a quiet noise only nudges a confident belief", function()
		local map = BeliefMap.new(line())
		map:Observe(1)
		map:Hear(5, 0.2, 1)
		check.equal((map:Best()), 1, "still thinks room 1")
	end)

	test("belief spreads out over time and certainty falls", function()
		local map = BeliefMap.new(line())
		map:Observe(1)
		local before = map:Certainty()
		for _ = 1, 20 do
			map:Step(0.5, 0.3, 0)
		end
		check.truthy(map:Certainty() < before, "less certain")
		check.truthy(map:Get(3) > 0, "reached room 3")
		check.near(total(map), 1, 1e-9, "mass is conserved")
	end)

	test("with no evidence it relaxes back to the squad's habits", function()
		local map = BeliefMap.new(line(), { [5] = 20 })
		map:Observe(1)
		for _ = 1, 200 do
			map:Step(0.5, 0.2, 0.2)
		end
		check.equal((map:Best()), 5, "heads for the favourite room")
	end)

	test("top lists rooms most likely first", function()
		local map = BeliefMap.new(line(), { [2] = 5, [4] = 3 })
		local top = map:Top(2)
		check.equal(#top, 2)
		check.equal(top[1].room, 2)
		check.equal(top[2].room, 4)
	end)

	test("sampling is deterministic for a seed and follows the belief", function()
		local map = BeliefMap.new(line())
		map:Observe(3)
		check.equal(map:Sample(Rng.new(9)), 3)
		local a, b = BeliefMap.new(line(), { [2] = 3 }), BeliefMap.new(line(), { [2] = 3 })
		check.equal(a:Sample(Rng.new(4)), b:Sample(Rng.new(4)), "same seed, same room")
	end)

	test("checking an empty room moves the belief elsewhere", function()
		local map = BeliefMap.new(line(), { [3] = 10 })
		check.equal((map:Best()), 3)
		map:Clear(3, 0.95)
		check.truthy(map:Get(3) < 0.8, "its share drops")
		map:Clear(3, 1)
		check.truthy((map:Best()) ~= 3, "looked there, not there")
		check.near(total(map), 1, 1e-9, "total")
	end)

	test("unknown rooms are ignored", function()
		local map = BeliefMap.new(line())
		map:Observe(99)
		map:Hear(99, 1, 1)
		check.near(total(map), 1, 1e-9, "total")
	end)
end
