-- Side rooms behind the house key (Logic/LockPlanner pockets, docs/plans/
-- level-design.md section 11, L3.2): one key a run that isn't used up opens
-- a side room or two in a part of the house the squad has been through, each
-- holding an heirloom. Over many houses for every squad size: every plan
-- still finishes, a side room is a dead end with nothing else in it, its door
-- is seen before the key is found, and nothing points into one before it can
-- be opened.
return function(test, check, Shared, require)
	local Config = require(Shared.Config)
	local Rooms = require(Shared.Data.Rooms)
	local Rng = require(Shared.Lib.Rng)
	local HouseMetrics = require(Shared.Logic.HouseMetrics)
	local HouseSize = require(Shared.Logic.HouseSize)
	local Leads = require(Shared.Logic.Leads)
	local LockPlanner = require(Shared.Logic.LockPlanner)
	local MansionGen = require(Shared.Logic.MansionGen)
	local NavGraph = require(Shared.Logic.NavGraph)

	local templates = Rooms.MansionById
	local houses = {}
	for squad = 1, 4 do
		local mansion, progression = HouseSize.config(Config.Mansion, Config.Progression, squad)
		for seed = 1, 20 do
			local layout = MansionGen.generate(seed * 11 + squad, Rooms.Mansion, mansion)
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

	test("every plan with side rooms still finishes and passes its own checks", function()
		for _, house in houses do
			local result = LockPlanner.solve(house.layout, house.plan, templates)
			check.truthy(result.solvable, name(house) .. ": the table set and a way out")
			local problems = LockPlanner.check(house.layout, house.plan, templates, house.progression, house.mansion)
			check.truthy(#problems == 0, name(house) .. ": " .. table.concat(problems, "; "))
		end
	end)

	test("a side room is a dead end, locked with the house key, holding an heirloom and nothing else", function()
		for _, house in houses do
			local plan, layout = house.plan, house.layout
			local doorways = {}
			for _, seam in layout.seams do
				if seam.connected then
					doorways[seam.a] = (doorways[seam.a] or 0) + 1
					doorways[seam.b] = (doorways[seam.b] or 0) + 1
				end
			end
			for room, pocket in plan.pockets or {} do
				local where = name(house) .. " room " .. room
				check.equal(doorways[room], 1, where .. ": one doorway")
				local lock = plan.locks[pocket.seam]
				check.truthy(lock and lock.kind == "pocket" and lock.inside == room, where .. ": locked")
				local key = plan.tokens[pocket.opener]
				check.truthy(key and key.reusable and key.kind == "key", where .. ": by a key that isn't used up")
				check.equal(lock.mark, key.mark, where .. ": carrying the key's mark")
				local heirlooms, others = 0, 0
				for _, token in plan.tokens do
					for _, at in LockPlanner.producerRooms(plan, token) do
						if at == room then
							if token.kind == "heirloom" then
								heirlooms += 1
							else
								others += 1
							end
						end
					end
				end
				check.equal(heirlooms, 1, where .. ": one heirloom inside")
				check.equal(others, 0, where .. ": nothing else the run needs")
				for _, puzzle in plan.puzzles do
					check.truthy(puzzle.room ~= room, where .. ": no puzzle inside")
				end
				check.truthy(
					room ~= layout.start and room ~= layout.deliberation,
					where .. ": not the hall or the table"
				)
				check.truthy(
					not (layout.chute and (layout.chute.ground == room or layout.chute.upper == room)),
					"no chute"
				)
			end
		end
	end)

	test("a side room's door is seen before the house key is found, so going back pays", function()
		local older = 0
		for _, house in houses do
			local plan = house.plan
			local position = { [0] = 0 }
			for i, r in plan.order do
				position[r] = i
			end
			for room, pocket in plan.pockets or {} do
				local keyRoom = LockPlanner.tokenRoom(plan, plan.tokens[pocket.opener])
				check.truthy(
					not (plan.pockets and plan.pockets[keyRoom]),
					name(house) .. ": the key isn't in a side room"
				)
				local here, there = position[plan.roomRegion[room]], position[plan.roomRegion[keyRoom]]
				check.truthy(here <= there, name(house) .. ": side room " .. room .. " is open before its key")
				if here < there then
					older += 1
				end
			end
		end
		check.truthy(older > 0, "some side rooms are in a part of the house left behind")
	end)

	test("how many: the squad's range, and most houses for two or more have one (before the search picks)", function()
		local with, total = { 0, 0, 0, 0 }, { 0, 0, 0, 0 }
		for _, house in houses do
			local count = 0
			for _ in house.plan.pockets or {} do
				count += 1
			end
			local range = house.progression.Pockets
			check.truthy(count <= range[2], name(house) .. ": no more than " .. range[2])
			total[house.squad] += 1
			if count > 0 then
				with[house.squad] += 1
			end
		end
		for squad = 2, 4 do
			check.truthy(
				with[squad] >= total[squad] * 0.6,
				string.format("squad %d: %d of %d", squad, with[squad], total[squad])
			)
		end
		check.truthy(with[1] > 0 and with[1] < total[1], "solo: some houses, not all (" .. with[1] .. ")")
	end)

	test("nothing points into a side room before it can be opened, and the walk opens it", function()
		local nav = NavGraph.options(Config)
		for _, house in houses do
			local plan, layout = house.plan, house.layout
			if plan.pockets then
				local leads =
					Leads.plan(plan, Leads.rooms(layout, templates), Rng.new(house.seed):Fork("leads"), Config.Leads)
				for id, lead in leads.tokens do
					local room = LockPlanner.tokenRoom(plan, plan.tokens[id])
					if lead.noteRoom then
						check.truthy(
							LockPlanner.stageOf(plan, lead.noteRoom) <= LockPlanner.stageOf(plan, room),
							name(house) .. ": the note for " .. id .. " can be read before it's needed"
						)
					end
				end
				for _, decoy in leads.decoys do
					check.truthy(not plan.pockets[decoy.room], name(house) .. ": no decoy in a side room")
				end
				local m = HouseMetrics.measure(layout, plan, templates, { nav = nav, config = house.mansion })
				check.truthy(m.tableSet, name(house) .. ": the walk sets the table")
				local count = 0
				for _ in plan.pockets do
					count += 1
				end
				check.equal(m.pockets, count, name(house) .. ": the metric counts them")
			end
		end
	end)

	test("without the squad's setting there are no side rooms (the old house, tests)", function()
		local layout = MansionGen.generate(31, Rooms.Mansion, Config.Mansion)
		local plan =
			LockPlanner.plan(layout, templates, Rng.new(1):Fork("progression"), Config.Progression, Config.Mansion)
		check.truthy(plan.pockets == nil, "none")
	end)
end
