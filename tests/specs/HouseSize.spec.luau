-- The house follows the squad (Logic/HouseSize, docs/plans/level-design.md
-- section 5.2): each squad size gets houses inside its room band and its
-- number of regions, and a seed and a squad size always give the same house.
return function(test, check, Shared, require)
	local Config = require(Shared.Config)
	local Rooms = require(Shared.Data.Rooms)
	local Rng = require(Shared.Lib.Rng)
	local FloorPlan = require(Shared.Logic.FloorPlan)
	local HouseSize = require(Shared.Logic.HouseSize)
	local LayoutValidator = require(Shared.Logic.LayoutValidator)
	local LockPlanner = require(Shared.Logic.LockPlanner)
	local MansionGen = require(Shared.Logic.MansionGen)

	test("a run's configs are copies: Config itself never changes", function()
		local before = Config.Mansion.RoomCount
		local mansion, progression = HouseSize.config(Config.Mansion, Config.Progression, 1)
		check.equal(Config.Mansion.RoomCount, before)
		check.truthy(mansion ~= Config.Mansion and progression ~= Config.Progression, "fresh tables")
		check.equal(mansion.RoomCount[1], Config.Mansion.BySquad[1].rooms[1])
		check.equal(HouseSize.clamp(9, Config.Mansion.BySquad), #Config.Mansion.BySquad)
		check.equal(HouseSize.clamp(0, Config.Mansion.BySquad), 1)
	end)

	test("each squad size: houses in its room band that pass the validator, with its regions", function()
		for squad = 1, #Config.Mansion.BySquad do
			local size = Config.Mansion.BySquad[squad]
			local mansion, progression = HouseSize.config(Config.Mansion, Config.Progression, squad)
			for seed = 1, 12 do
				local layout = MansionGen.generate(seed * 101 + squad, Rooms.Mansion, mansion)
				if not layout.fallback then
					local n = #layout.rooms
					check.truthy(
						n >= size.rooms[1] and n <= size.rooms[2],
						("squad %d seed %d: %d rooms"):format(squad, seed, n)
					)
					local ok, problems = LayoutValidator.validate(layout, Rooms.Mansion, mansion)
					check.truthy(ok, ("squad %d seed %d: %s"):format(squad, seed, table.concat(problems or {}, "; ")))
				end
				check.equal(LockPlanner.regionCount(#layout.rooms, progression), size.regions)
				local plan =
					LockPlanner.plan(layout, Rooms.MansionById, Rng.new(seed):Fork("progression"), progression, mansion)
				local heirlooms = #plan.finale.heirlooms
				check.truthy(
					heirlooms >= size.heirlooms[1] and heirlooms <= size.heirlooms[2],
					("squad %d seed %d: %d heirlooms"):format(squad, seed, heirlooms)
				)
			end
		end
	end)

	test("the same seed and squad give the same house; another squad size a different one", function()
		local one = HouseSize.config(Config.Mansion, Config.Progression, 1)
		local four = HouseSize.config(Config.Mansion, Config.Progression, 4)
		local a = FloorPlan.hash(MansionGen.generate(4242, Rooms.Mansion, one))
		local b = FloorPlan.hash(MansionGen.generate(4242, Rooms.Mansion, one))
		local c = FloorPlan.hash(MansionGen.generate(4242, Rooms.Mansion, four))
		check.equal(a, b)
		check.truthy(a ~= c, "a squad of four gets its own house")
	end)
end
