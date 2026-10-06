-- The safe room (Logic/LockPlanner addSafeRoom, Logic/SafeRoom, docs/plans/
-- level-design.md section 11.12): an optional objective. A side room behind
-- a steel door on an electric lock the fuse box powers, holding things that
-- help and never anything the run needs. Over many houses for every squad:
-- most have one, the run finishes without ever opening it, nothing points
-- into it, and its roll is the squad's size, each thing at most once.
return function(test, check, Shared, require)
	local Config = require(Shared.Config)
	local Loot = require(Shared.Data.SafeRoom)
	local Rooms = require(Shared.Data.Rooms)
	local Rng = require(Shared.Lib.Rng)
	local HouseMetrics = require(Shared.Logic.HouseMetrics)
	local HouseSize = require(Shared.Logic.HouseSize)
	local Leads = require(Shared.Logic.Leads)
	local LockPlanner = require(Shared.Logic.LockPlanner)
	local MansionGen = require(Shared.Logic.MansionGen)
	local NavGraph = require(Shared.Logic.NavGraph)
	local SafeRoom = require(Shared.Logic.SafeRoom)

	local templates = Rooms.MansionById
	local houses = {}
	for squad = 1, 4 do
		local mansion, progression = HouseSize.config(Config.Mansion, Config.Progression, squad)
		for seed = 1, 12 do
			local layout = MansionGen.generate(seed * 19 + squad, Rooms.Mansion, mansion)
			local plan = LockPlanner.plan(layout, templates, Rng.new(seed):Fork("progression"), progression, mansion)
			table.insert(houses, {
				layout = layout,
				plan = plan,
				squad = squad,
				seed = seed,
				mansion = mansion,
				progression = progression,
			})
		end
	end
	local function name(house): string
		return string.format("squad %d seed %d", house.squad, house.seed)
	end

	test("most houses have one: a side room with a door on an electric lock the fuse box powers", function()
		local with = 0
		for _, house in houses do
			local plan, layout = house.plan, house.layout
			local safe = plan.safeRoom
			if safe then
				with += 1
				local where = name(house) .. " room " .. safe.room
				local doorways = 0
				for _, seam in layout.seams do
					if seam.connected and (seam.a == safe.room or seam.b == safe.room) then
						doorways += 1
					end
				end
				check.equal(doorways, 1, where .. ": one doorway")
				local lock = plan.locks[safe.seam]
				check.truthy(
					lock and lock.kind == "power" and lock.optional and lock.vault,
					where .. ": a powered lock"
				)
				check.equal(lock.inside, safe.room, where .. ": on its door")
				local token = plan.tokens[lock.needs[1]]
				check.truthy(token and token.optional and token.producer.kind == "puzzle", where .. ": from a puzzle")
				check.equal(plan.puzzles[token.producer.id].kind, "breaker", where .. ": the fuse box")
				check.truthy(plan.puzzles[token.producer.id].room ~= safe.room, where .. ": not inside it")
				check.truthy(
					not (plan.pockets and plan.pockets[safe.room]),
					where .. ": not the house key's side room or a step"
				)
				local puzzles = 0
				for _ in plan.puzzles do
					puzzles += 1
				end
				check.truthy(puzzles <= house.progression.MaxPuzzles, where .. ": no more puzzles than allowed")
			end
		end
		check.truthy(with >= #houses * 0.6, with .. " of " .. #houses .. " houses")
	end)

	test("never needed: nothing the run needs inside, and the run finishes with it shut", function()
		for _, house in houses do
			local plan, safe = house.plan, house.plan.safeRoom
			if safe then
				for id, token in plan.tokens do
					for _, room in LockPlanner.producerRooms(plan, token) do
						check.truthy(room ~= safe.room, name(house) .. ": " .. id .. " isn't in it")
					end
				end
				local lock = plan.locks[safe.seam]
				local was = lock.needs
				lock.needs = { "nothing" }
				check.truthy(
					LockPlanner.solve(house.layout, plan, templates).solvable,
					name(house) .. ": finishes with it shut"
				)
				lock.needs = was
				local problems = LockPlanner.check(house.layout, plan, templates, house.progression, house.mansion)
				check.truthy(#problems == 0, name(house) .. ": " .. table.concat(problems, "; "))
			end
		end
	end)

	test("nothing points into it, and the walk never goes there", function()
		local nav = NavGraph.options(Config)
		for _, house in houses do
			local plan, layout, safe = house.plan, house.layout, house.plan.safeRoom
			if safe then
				check.equal(LockPlanner.stageOf(plan, safe.room), math.huge, name(house) .. ": never a stage")
				local leads =
					Leads.plan(plan, Leads.rooms(layout, templates), Rng.new(house.seed):Fork("leads"), Config.Leads)
				for id, lead in leads.tokens do
					check.truthy(lead.noteRoom ~= safe.room, name(house) .. ": no note for " .. id .. " in it")
				end
				for _, decoy in leads.decoys do
					check.truthy(decoy.room ~= safe.room, name(house) .. ": no decoy in it")
				end
				local m = HouseMetrics.measure(layout, plan, templates, { nav = nav, config = house.mansion })
				check.truthy(m.tableSet, name(house) .. ": the walk sets the table")
				check.equal(m.safeRooms, 1, name(house) .. ": counted")
				for _, leg in m.legs do
					check.truthy(leg.why ~= "open " .. safe.seam, name(house) .. ": the walk never opens it")
				end
			end
		end
	end)

	test("its roll: the squad's count, each thing at most once, the plans only with a floor to show", function()
		local cfg = Config.Progression.SafeRoom
		local seen = {}
		for squad = 1, 4 do
			for seed = 1, 60 do
				local roll = SafeRoom.roll(Rng.new(seed), squad, cfg, seed % 2 == 0 and 1 or nil)
				check.equal(#roll, SafeRoom.count(squad, cfg), "squad " .. squad .. " seed " .. seed .. ": count")
				local ids = {}
				for _, entry in roll do
					check.truthy(not ids[entry.id], "seed " .. seed .. ": " .. entry.id .. " once")
					ids[entry.id] = true
					seen[entry.id] = true
					if seed % 2 == 1 then
						check.truthy(entry.kind ~= "plans", "seed " .. seed .. ": no plans without a floor")
					end
				end
				local again = SafeRoom.roll(Rng.new(seed), squad, cfg, seed % 2 == 0 and 1 or nil)
				for i, entry in roll do
					check.equal(again[i].id, entry.id, "seed " .. seed .. ": the same from the same seed")
				end
			end
		end
		for _, entry in Loot do
			check.truthy(seen[entry.id], entry.id .. " turns up")
		end
	end)
end
