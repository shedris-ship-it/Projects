-- What drawers hold (Data/Finds, Logic/Finds): a weighted pick that keeps to
-- each kind's limit a run, and every kind is something World/Junk can build.
return function(test, check, Shared, require)
	local FindData = require(Shared.Data.Finds)
	local Finds = require(Shared.Logic.Finds)
	local Physical = require(Shared.Data.Physical)
	local Rng = require(Shared.Lib.Rng)

	test("most finds do something, and every one can be carried", function()
		local useful, total = 0, 0
		for _, entry in FindData do
			check.truthy(Physical.Dressing[entry.name] ~= nil, entry.name .. " has a class to carry it by")
			check.truthy(entry.weight > 0, entry.name .. " can come up")
			total += entry.weight
			if entry.use then
				check.truthy(entry.effect ~= nil, entry.name .. " does something when used")
				useful += entry.weight
			end
		end
		check.truthy(useful / total >= 0.6, "most drawers hold something useful")
	end)

	test("no kind goes past its limit for the squad, and the rest still come", function()
		for squad = 1, 4 do
			local rng = Rng.new(squad * 17)
			local counts = {}
			for _ = 1, 200 do
				local entry = Finds.pick(FindData, rng, counts, squad)
				check.truthy(entry ~= nil, "something to find")
				counts[entry.name] = (counts[entry.name] or 0) + 1
			end
			for _, entry in FindData do
				if entry.max then
					check.atMost(counts[entry.name] or 0, entry.max[squad], entry.name .. " for " .. squad)
				end
			end
			-- (Throwables have no limit, so a big house never runs dry.)
			check.truthy((counts.Cassette or 0) > 0, "throwables keep coming")
		end
	end)

	test("painkillers are rare: a down forgiven is worth finding", function()
		local entry = Finds.byName(FindData, "PillBottle")
		check.truthy(entry and entry.effect == "mend", "the pill bottle mends")
		check.atMost(entry.max[1], 1, "one alone")
		check.atMost(entry.max[4], 2, "two for four")
	end)

	test("with every kind used up but the unlimited ones, the pick still works", function()
		local counts = {}
		for _, entry in FindData do
			counts[entry.name] = entry.max and entry.max[2] or 0
		end
		local entry = Finds.pick(FindData, Rng.new(3), counts, 2)
		check.truthy(entry ~= nil and entry.max == nil, "an unlimited one")
	end)
end
