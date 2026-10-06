-- The house plans (Logic/HousePlans, docs/plans/level-design.md section 11,
-- L3.5): blueprints on a desk or a workbench somewhere the squad gets to
-- early, drawing that floor's rooms, never a servants' passage; a reason to
-- go into their room.
return function(test, check, Shared, require)
	local Config = require(Shared.Config)
	local Rooms = require(Shared.Data.Rooms)
	local Rng = require(Shared.Lib.Rng)
	local HousePlans = require(Shared.Logic.HousePlans)
	local HouseSize = require(Shared.Logic.HouseSize)
	local LockPlanner = require(Shared.Logic.LockPlanner)
	local MansionGen = require(Shared.Logic.MansionGen)
	local RoomPurpose = require(Shared.Logic.RoomPurpose)

	local templates = Rooms.MansionById
	local houses = {}
	for squad = 1, 4 do
		local mansion, progression = HouseSize.config(Config.Mansion, Config.Progression, squad)
		for seed = 1, 12 do
			local layout = MansionGen.generate(seed * 17 + squad, Rooms.Mansion, mansion)
			local plan = LockPlanner.plan(layout, templates, Rng.new(seed):Fork("progression"), progression, mansion)
			plan.housePlans = HousePlans.choose(layout, plan, templates, Rng.new(seed):Fork("plans"))
			table.insert(houses, { layout = layout, plan = plan, squad = squad, seed = seed })
		end
	end

	test("most houses have them, somewhere open early with a top to lie on", function()
		local with = 0
		for _, house in houses do
			local plans = house.plan.housePlans
			local where = string.format("squad %d seed %d", house.squad, house.seed)
			if plans then
				with += 1
				local room
				for _, r in house.layout.rooms do
					if r.id == plans.room then
						room = r
					end
				end
				check.truthy(room ~= nil, where .. ": a room")
				check.equal(plans.storey, room.floor or 0, where .. ": its own floor")
				check.truthy(
					LockPlanner.stageOf(house.plan, room.id) <= HousePlans.LatestStage,
					where .. ": open early"
				)
				check.truthy(
					room.id ~= house.layout.start and room.id ~= house.layout.deliberation,
					where .. ": not the hall or the table"
				)
				check.truthy(not room.corridor and room.kind ~= "stair" and room.kind ~= "passage", where .. ": a room")
				check.truthy(not (house.plan.pockets and house.plan.pockets[room.id]), where .. ": not shut away")
				local surface = false
				for _, prop in templates[room.template].props or {} do
					surface = surface or HousePlans.Surfaces[prop.kind] ~= nil
				end
				check.truthy(surface, where .. ": something to lay them on")
			end
		end
		check.truthy(with >= #houses * 0.8, with .. " of " .. #houses .. " houses")
	end)

	test("they draw every room on their floor but a servants' passage", function()
		local passages = 0
		for _, house in houses do
			for _, passage in house.layout.passages or {} do
				passages += 1
				for storey = -1, 2 do
					check.truthy(
						table.find(HousePlans.rooms(house.layout, storey), passage.id) == nil,
						"a passage is never drawn"
					)
				end
			end
			for storey = 0, 1 do
				local drawn = {}
				for _, id in HousePlans.rooms(house.layout, storey) do
					drawn[id] = true
				end
				for _, room in house.layout.rooms do
					local bottom = room.floor or 0
					local top = room.tall and (room.top or bottom + 1) or bottom
					local on = storey >= bottom and storey <= top
					if room.kind == "passage" then
						passages += 1
						check.truthy(not drawn[room.id], "a passage is never drawn")
					else
						check.equal(drawn[room.id] == true, on, "room " .. room.id .. " on storey " .. storey)
					end
				end
			end
		end
		check.truthy(passages > 0, "some houses have a passage to leave out")
	end)

	test("they're a reason to go into their room", function()
		for _, house in houses do
			local plans = house.plan.housePlans
			if plans then
				local purposes = RoomPurpose.of(house.layout, house.plan, templates, nil)
				check.truthy(
					table.find(purposes[plans.room].strong, "house plans") ~= nil,
					"room " .. plans.room .. " has the plans as a reason"
				)
			end
		end
	end)

	test("the old house has none", function()
		local layout = { mode = "Cells", rooms = {} }
		check.truthy(HousePlans.choose(layout, { tokens = {}, puzzles = {} }, templates, Rng.new(1)) == nil, "none")
	end)
end
