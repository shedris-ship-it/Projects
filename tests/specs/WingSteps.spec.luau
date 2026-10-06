-- Steps inside a wing (Logic/LockPlanner, docs/plans/level-design.md section
-- 11, L3.4): for three or four players, a wing's prize (a key to a later
-- door, else an heirloom) is shut away inside the wing, in a side room
-- boarded up or chained or in a chest (or the fridge) chained or nailed
-- shut, and the tool that opens it lies across the wing or in its sibling.
-- Over many houses for every squad size: none for one or two, every plan
-- still finishes, a step is opened by a tool and never a key, its tool is
-- never shut in with what it opens, and the walk goes back for it.
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
		for seed = 1, squad >= 3 and 24 or 10 do
			local layout = MansionGen.generate(seed * 13 + squad, Rooms.Mansion, mansion)
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
	-- Every step in a plan: { room, region, needs, piece? (its id), seam? }.
	local function stepsOf(plan)
		local steps = {}
		for seamId, lock in plan.locks do
			if lock.step then
				table.insert(steps, { room = lock.inside, region = lock.region, needs = lock.needs, seam = seamId })
			end
		end
		for id, piece in plan.pieces or {} do
			table.insert(steps, { room = piece.room, region = piece.region, needs = piece.needs, piece = id })
		end
		return steps
	end

	test("none for one or two players; for three or four, the squad's range, in most houses", function()
		local with, total = { 0, 0, 0, 0 }, { 0, 0, 0, 0 }
		for _, house in houses do
			local count = #stepsOf(house.plan)
			local range = house.progression.WingSteps
			check.truthy(count <= range[2], name(house) .. ": " .. count .. " steps, no more than " .. range[2])
			check.equal(house.plan.stats.wingSteps or 0, count, name(house) .. ": counted")
			total[house.squad] += 1
			if count > 0 then
				with[house.squad] += 1
			end
		end
		check.equal(with[1] + with[2], 0, "none for one or two")
		-- (Before the search picks the best house: it favours houses with one.)
		check.truthy(with[4] >= total[4] * 0.35, string.format("four: %d of %d houses", with[4], total[4]))
		check.truthy(with[3] > 0, "three: some houses (" .. with[3] .. ")")
	end)

	test("every plan with steps still finishes and passes its own checks", function()
		for _, house in houses do
			local result = LockPlanner.solve(house.layout, house.plan, templates)
			check.truthy(result.solvable, name(house) .. ": the table set and a way out")
			local problems = LockPlanner.check(house.layout, house.plan, templates, house.progression, house.mansion)
			check.truthy(#problems == 0, name(house) .. ": " .. table.concat(problems, "; "))
		end
	end)

	test("a step is in a big wing, opened by a tool (never a key), holding the wing's prize", function()
		local rooms, pieces = 0, 0
		for _, house in houses do
			local plan, layout = house.plan, house.layout
			local doorways = {}
			for _, seam in layout.seams do
				if seam.connected then
					doorways[seam.a] = (doorways[seam.a] or 0) + 1
					doorways[seam.b] = (doorways[seam.b] or 0) + 1
				end
			end
			for _, step in stepsOf(plan) do
				local where = name(house) .. " step in room " .. step.room
				check.equal(plan.roomRegion[step.room], step.region, where .. ": inside its wing")
				check.truthy(step.region ~= 0, where .. ": not in the part open from the start")
				check.truthy(
					#plan.regions[step.region].rooms >= house.progression.WingStepRooms,
					where .. ": a big wing"
				)
				check.equal(#step.needs, 1, where .. ": one thing opens it")
				local tool = plan.tokens[step.needs[1]]
				check.truthy(tool and tool.kind == "tool", where .. ": a tool, never a key")
				check.truthy(
					LockPlanner.tokenRoom(plan, tool) ~= step.room,
					where .. ": its tool isn't shut in with it"
				)
				local prizes = 0
				for id, token in plan.tokens do
					local inside = token.producer.kind == "container"
						and token.producer.room == step.room
						and token.producer.piece == step.piece
					if inside then
						check.truthy(
							token.kind == "key" or token.kind == "heirloom",
							where .. ": " .. id .. " is a prize"
						)
						check.truthy(token.kind ~= "tool", where .. ": no tool inside")
						prizes += 1
					end
				end
				check.truthy(prizes >= 1, where .. ": something the run needs inside")
				if step.seam then
					rooms += 1
					check.equal(doorways[step.room], 1, where .. ": a side room, one doorway")
					local pocket = plan.pockets and plan.pockets[step.room]
					check.truthy(pocket and pocket.step and pocket.opener == step.needs[1], where .. ": a side room")
					check.truthy(
						not (layout.chute and (layout.chute.ground == step.room or layout.chute.upper == step.room)),
						where .. ": no chute"
					)
				else
					pieces += 1
					local piece = plan.pieces[step.piece]
					check.truthy(
						Config.Progression.StepPieces[string.gsub(piece.thing, "^%l", string.upper)] ~= nil,
						where .. ": a chest or the like (" .. piece.thing .. ")"
					)
					check.truthy(not (plan.pockets and plan.pockets[step.room]), where .. ": not in a side room")
				end
			end
		end
		check.truthy(rooms > 0, "some side rooms (" .. rooms .. ")")
		check.truthy(pieces > 0, "some chests (" .. pieces .. ")")
	end)

	test("a step holds something the run needs: never opened, the squad can't finish", function()
		local tried = 0
		for _, house in houses do
			local plan = house.plan
			for _, step in stepsOf(plan) do
				local lock = step.seam and plan.locks[step.seam] or plan.pieces[step.piece]
				local was = lock.needs
				lock.needs = { "nothing" }
				local result = LockPlanner.solve(house.layout, plan, templates)
				lock.needs = was
				check.truthy(not result.solvable, name(house) .. ": room " .. step.room .. " holds what's needed")
				tried += 1
			end
		end
		check.truthy(tried > 0, "steps tried")
	end)

	test("the walk goes back for a step, nothing points into one too soon, side rooms keep the house key", function()
		local nav = NavGraph.options(Config)
		for _, house in houses do
			local plan, layout = house.plan, house.layout
			local steps = stepsOf(plan)
			if #steps > 0 then
				local m = HouseMetrics.measure(layout, plan, templates, { nav = nav, config = house.mansion })
				check.truthy(m.tableSet, name(house) .. ": the walk sets the table")
				check.equal(m.wingSteps, #steps, name(house) .. ": the metric counts them")
				local leads =
					Leads.plan(plan, Leads.rooms(layout, templates), Rng.new(house.seed):Fork("leads"), Config.Leads)
				for id, lead in leads.tokens do
					local token = plan.tokens[id]
					if token.producer.piece then
						check.truthy(
							lead.kind == "note" or lead.kind == "drawer",
							name(house) .. ": " .. id .. " stays in its chest"
						)
					end
					if lead.noteRoom then
						check.truthy(
							LockPlanner.stageOf(plan, lead.noteRoom)
								<= LockPlanner.stageOf(plan, LockPlanner.tokenRoom(plan, token)),
							name(house) .. ": the note for " .. id .. " can be read before it's needed"
						)
					end
				end
				for room, pocket in plan.pockets or {} do
					if not pocket.step then
						local key = plan.tokens[pocket.opener]
						local keyRoom = LockPlanner.tokenRoom(plan, key)
						check.truthy(key.kind == "key", name(house) .. ": side room " .. room .. " takes the house key")
						check.truthy(not plan.pockets[keyRoom], name(house) .. ": the house key isn't shut away")
						check.truthy(key.producer.piece == nil, name(house) .. ": nor in a chest")
					end
				end
			end
		end
	end)
end
