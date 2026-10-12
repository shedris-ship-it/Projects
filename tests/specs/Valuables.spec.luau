-- The family's valuables (Logic/Valuables; push your luck, the owner's
-- choice of 2026-10-11): optional loot, kept in rooms off the way (side
-- rooms first, then the cellar and the attic, then the far rooms), one a
-- room, spread across the wings, never anywhere that's the run's own (the
-- hall, the dining room, the way out, corridors, stairs, lantern rooms, the
-- safe room). Over many houses for every squad size; and the Marks they pay.
return function(test, check, Shared, require)
	local Config = require(Shared.Config)
	local Rooms = require(Shared.Data.Rooms)
	local Rng = require(Shared.Lib.Rng)
	local HouseSize = require(Shared.Logic.HouseSize)
	local LockPlanner = require(Shared.Logic.LockPlanner)
	local MansionGen = require(Shared.Logic.MansionGen)
	local Progression = require(Shared.Logic.Progression)
	local Valuables = require(Shared.Logic.Valuables)
	local ValuableData = require(Shared.Data.Valuables)

	local houses = {}
	for squad = 1, 4 do
		local mansion, progression = HouseSize.config(Config.Mansion, Config.Progression, squad)
		for seed = 1, 12 do
			local layout = MansionGen.generate(seed * 13 + squad, Rooms.Mansion, mansion)
			local plan =
				LockPlanner.plan(layout, Rooms.MansionById, Rng.new(seed):Fork("progression"), progression, mansion)
			table.insert(
				houses,
				{ layout = layout, plan = plan, squad = squad, seed = seed, progression = progression }
			)
		end
	end
	local function name(house): string
		return string.format("squad %d seed %d", house.squad, house.seed)
	end

	test("every squad's house keeps some, by its size", function()
		for squad = 1, 4 do
			local _, progression = HouseSize.config(Config.Mansion, Config.Progression, squad)
			local range = progression.Valuables
			check.truthy(range and range[1] >= 1 and range[2] >= range[1], "squad " .. squad .. " has a range")
		end
		local _, short = HouseSize.config(Config.Mansion, Config.Progression, 4, 0, "short")
		check.truthy(short.Valuables and short.Valuables[1] >= 1, "the short night keeps some too")
	end)

	test("one a room, never the run's own rooms, as many as asked for when there's room", function()
		for _, house in houses do
			local layout, plan = house.layout, house.plan
			local byId = {}
			for _, room in layout.rooms do
				byId[room.id] = room
			end
			local count = house.progression.Valuables[2]
			local picked = Valuables.pick(layout, plan, Rng.new(house.seed):Fork("valuables"), count)
			check.equal(#picked, math.min(count, #Valuables.candidates(layout, plan)), name(house) .. ": how many")
			local seen = {}
			for _, id in picked do
				local room = byId[id]
				check.truthy(not seen[id], name(house) .. ": one a room")
				seen[id] = true
				check.truthy(
					id ~= layout.start and id ~= layout.deliberation and id ~= layout.exit,
					name(house) .. ": not the run's own"
				)
				check.truthy(not room.corridor and room.kind ~= "stair", name(house) .. ": a room, not a way through")
				check.truthy(not room.lantern, name(house) .. ": not a lantern room")
				check.truthy(not (plan.safeRoom and plan.safeRoom.room == id), name(house) .. ": not the safe room")
			end
		end
	end)

	test("off the way: side rooms first, then the furthest room in each wing", function()
		for _, house in houses do
			local layout, plan = house.layout, house.plan
			local picked = Valuables.pick(layout, plan, Rng.new(house.seed):Fork("valuables"), 2)
			-- Side rooms (the house key's, or a wing's step behind boards or a
			-- chain) are off the way by their locks.
			-- (Only side rooms that may keep one at all: not a lantern room.)
			local options = Valuables.candidates(layout, plan)
			local pockets = {}
			for _, option in options do
				if plan.pockets and plan.pockets[option.room] then
					pockets[option.room] = true
				end
			end
			if next(pockets) then
				check.truthy(pockets[picked[1]], name(house) .. ": a side room is the first choice")
			end
			-- Each one is the best of its wing: no room left in that wing is
			-- further off the way (but for the tie-breaking jitter).
			local scoreOf, isPicked = {}, {}
			for _, option in options do
				scoreOf[option.room] = option
			end
			for _, id in picked do
				isPicked[id] = true
			end
			for _, id in picked do
				local mine = scoreOf[id]
				for _, other in options do
					if other.region == mine.region and not isPicked[other.room] then
						check.atMost(
							other.score,
							mine.score + 0.051,
							name(house) .. ": room " .. id .. " is its wing's furthest"
						)
					end
				end
			end
		end
	end)

	test("spread across the wings while there are wings to spread over", function()
		for _, house in houses do
			local layout, plan = house.layout, house.plan
			local regions = {}
			for _, option in Valuables.candidates(layout, plan) do
				regions[option.region] = true
			end
			local wings = 0
			for _ in regions do
				wings += 1
			end
			local want = math.min(3, wings)
			local picked = Valuables.pick(layout, plan, Rng.new(house.seed):Fork("valuables"), want)
			local used = {}
			for _, id in picked do
				used[plan.roomRegion[id] or 0] = true
			end
			local spread = 0
			for _ in used do
				spread += 1
			end
			check.equal(spread, #picked, name(house) .. ": each in a wing of its own")
		end
	end)

	test("the same seed keeps them in the same rooms", function()
		local house = houses[5]
		local a = Valuables.pick(house.layout, house.plan, Rng.new(9), 3)
		local b = Valuables.pick(house.layout, house.plan, Rng.new(9), 3)
		check.equal(table.concat(a, ","), table.concat(b, ","), "same rooms")
	end)

	test("they pay only once carried out, for everyone, and look like nothing of his", function()
		local base = { won = true, extracted = true, drift = 20 }
		local haul = { won = true, extracted = true, drift = 20, valuables = 2, valuableMarks = Config.Valuables.Marks }
		check.equal(
			Progression.marksForRun(haul) - Progression.marksForRun(base),
			2 * Config.Valuables.Marks,
			"each one's Marks"
		)
		check.equal(
			Progression.marksForRun({ won = false, drift = 100, valuables = 0, valuableMarks = 25 }),
			Progression.marksForRun({ won = false, drift = 100 }),
			"none, nothing"
		)
		local heirlooms = { Candlestick = true, PocketWatch = true, Locket = true, Doll = true, Cup = true }
		for _, v in ValuableData do
			check.truthy(not heirlooms[v.id], v.id .. " isn't an heirloom's look")
			check.truthy(type(v.label) == "string" and #v.label > 3, v.id .. " has a label")
			check.truthy(v.size and v.size[1] > 0 and v.size[2] > 0, v.id .. " has a footprint")
		end
	end)
end
