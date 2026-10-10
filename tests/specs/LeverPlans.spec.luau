-- Twin levers in the lock planner (Logic/LockPlanner; the squad playtest,
-- 2026-10-10): never alone, never in the old house; the far lever stands in
-- another room already open when its door is seen, a walk from the door; and
-- a squad's houses have a team lock (twin levers, a crank door or a double
-- lock) more often than not.
return function(test, check, Shared, require)
	local Config = require(Shared.Config)
	local Rooms = require(Shared.Data.Rooms)
	local Rng = require(Shared.Lib.Rng)
	local HouseSize = require(Shared.Logic.HouseSize)
	local LockPlanner = require(Shared.Logic.LockPlanner)
	local MansionGen = require(Shared.Logic.MansionGen)
	local MansionHouse = require(Shared.Logic.MansionHouse)

	local templates = Rooms.MansionById
	local houses = {}
	for squad = 1, 3 do
		local mansion, progression = HouseSize.config(Config.Mansion, Config.Progression, squad)
		for seed = 1, 16 do
			local layout = MansionGen.generate(seed * 29 + squad, Rooms.Mansion, mansion)
			local plan = LockPlanner.plan(layout, templates, Rng.new(seed):Fork("progression"), progression, mansion)
			table.insert(houses, { layout = layout, plan = plan, squad = squad, seed = seed, mansion = mansion })
		end
	end

	local function leversOf(plan)
		local list = {}
		for seamId, lock in plan.locks do
			if lock.kind == "levers" then
				local token = plan.tokens[lock.needs[1]]
				local puzzle = token and token.producer.kind == "puzzle" and plan.puzzles[token.producer.id]
				table.insert(list, { seam = seamId, lock = lock, puzzle = puzzle })
			end
		end
		return list
	end

	test("never for one player", function()
		for _, house in houses do
			if house.squad == 1 then
				check.equal(#leversOf(house.plan), 0, "seed " .. house.seed)
			end
		end
	end)

	test("the far lever: in another room, a walk from the door", function()
		local seen = 0
		for _, house in houses do
			local walker = MansionHouse.walker(house.layout.rooms, house.layout.seams, house.mansion)
			for _, entry in leversOf(house.plan) do
				seen += 1
				local name = string.format("squad %d seed %d %s", house.squad, house.seed, entry.seam)
				check.truthy(entry.puzzle ~= nil and entry.puzzle.kind == "levers", name .. ": its station")
				check.truthy(entry.lock.side ~= nil, name .. ": a door side")
				check.truthy(entry.puzzle.room ~= entry.lock.side, name .. ": not in the door's room")
				local studs = walker(entry.lock.side, function()
					return true
				end)[entry.puzzle.room]
				check.truthy(studs ~= nil and studs >= 20, name .. ": a walk away (" .. tostring(studs) .. ")")
			end
		end
		check.atLeast(seen, 2, "some houses have them")
	end)

	test("a squad's houses mostly have a team lock", function()
		for squad = 2, 3 do
			local total, with = 0, 0
			for _, house in houses do
				if house.squad == squad then
					total += 1
					local any = false
					for _, lock in house.plan.locks do
						any = any or lock.kind == "levers" or lock.kind == "crank" or lock.kind == "double"
					end
					with += any and 1 or 0
				end
			end
			check.atLeast(with / total, 0.5, "squad " .. squad .. ": " .. with .. " of " .. total)
		end
	end)
end
