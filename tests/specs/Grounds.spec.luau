-- The grounds round a mansion (Logic/Grounds): dense woods and a garden, but
-- nothing in the house, on the drive or before the front door; tall
-- evergreens never in front of a window; within the part budget.
return function(test, check, Shared, require)
	local Config = require(Shared.Config)
	local Rooms = require(Shared.Data.Rooms)
	local Grounds = require(Shared.Logic.Grounds)
	local HouseSize = require(Shared.Logic.HouseSize)
	local MansionGen = require(Shared.Logic.MansionGen)
	local MansionHouse = require(Shared.Logic.MansionHouse)
	local Rng = require(Shared.Lib.Rng)

	local cfg = Config.Exterior

	-- A window in the middle of every ground-floor side (stand-ins for the
	-- builder's: only the rule against them is under test).
	local function windowsOf(rects)
		local list = {}
		for _, r in rects do
			local mx, mz = (r[1] + r[3]) / 2, (r[2] + r[4]) / 2
			table.insert(list, { x = mx, z = r[2] })
			table.insert(list, { x = mx, z = r[4] })
			table.insert(list, { x = r[1], z = mz })
			table.insert(list, { x = r[3], z = mz })
		end
		return list
	end

	local function houses(each)
		for _, squad in { 1, 4 } do
			local mansion = HouseSize.config(Config.Mansion, Config.Progression, squad)
			for seed = 1, 12 do
				local layout = MansionGen.generate(seed * 31 + squad, Rooms.Mansion, mansion)
				local rooms = MansionHouse.withPassages(layout)
				local house = { rooms = rooms, frontDoor = layout.frontDoor }
				local windows = windowsOf(Grounds.footprint(rooms))
				each(("squad %d seed %d"):format(squad, seed), house, windows, seed)
			end
		end
	end

	test("nothing in the house, on the drive or before the front door", function()
		houses(function(where, house, windows, seed)
			local plants, rects = Grounds.plan(house, windows, cfg, Rng.new(seed))
			local door = Grounds.door(house.frontDoor)
			check.truthy(door ~= nil, where .. ": a front door")
			for _, plant in plants do
				local away = Grounds.distance(rects, plant.x, plant.z)
				local least = (plant.kind == "leafy" or plant.kind == "bare" or plant.kind == "conifer")
						and cfg.LawnClear
					or plant.kind == "bush" and cfg.Undergrowth.From
					or cfg.Garden.Gap - 0.3
				check.atLeast(away, least, where .. ": a " .. plant.kind .. " clear of the house")
				check.truthy(
					not Grounds.onDrive(door, cfg, plant.x, plant.z, 0),
					where .. ": a " .. plant.kind .. " off the drive"
				)
				if plant.kind == "shrub" or plant.kind == "column" then
					local d = math.sqrt((plant.x - door.x) ^ 2 + (plant.z - door.z) ^ 2)
					check.atLeast(d, cfg.Garden.DoorClear, where .. ": the front door's way clear")
				end
			end
		end)
	end)

	test("tall evergreens only between windows; shrubs stay small", function()
		houses(function(where, house, windows, seed)
			local plants = Grounds.plan(house, windows, cfg, Rng.new(seed))
			for _, plant in plants do
				if plant.kind == "column" then
					for _, w in windows do
						local d = math.sqrt((plant.x - w.x) ^ 2 + (plant.z - w.z) ^ 2)
						check.atLeast(d, cfg.Garden.WindowClear, where .. ": a column clear of a window")
					end
					check.atMost(plant.size, cfg.Garden.ColumnHeight[2], where .. ": a column's height")
				elseif plant.kind == "shrub" then
					check.atMost(plant.size, 1.15, where .. ": a shrub's scale")
				end
			end
		end)
	end)

	test("dense woods and a garden, within the part budget", function()
		houses(function(where, house, windows, seed)
			local plants = Grounds.plan(house, windows, cfg, Rng.new(seed))
			local count = { leafy = 0, bare = 0, conifer = 0, bush = 0, shrub = 0, column = 0 }
			for _, plant in plants do
				count[plant.kind] += 1
			end
			check.atLeast(count.leafy + count.bare + count.conifer, 200, where .. ": a wood, not a few trees")
			check.atLeast(count.leafy, count.bare, where .. ": most trees still in leaf")
			check.atLeast(count.bush, 150, where .. ": undergrowth")
			check.atLeast(count.shrub + count.column, 12, where .. ": a garden along the walls")
			check.atMost(Grounds.parts(plants), cfg.PartBudget, where .. ": parts")
		end)
	end)

	test("the same seed, the same grounds", function()
		houses(function(where, house, windows, seed)
			if seed > 3 then
				return
			end
			local a = Grounds.plan(house, windows, cfg, Rng.new(seed))
			local b = Grounds.plan(house, windows, cfg, Rng.new(seed))
			check.equal(#a, #b, where)
			for i = 1, #a do
				check.equal(a[i].x, b[i].x, where)
				check.equal(a[i].kind, b[i].kind, where)
			end
		end)
	end)
end
