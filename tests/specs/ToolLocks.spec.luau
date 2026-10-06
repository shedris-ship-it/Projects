-- Tool locks (Logic/ToolLocks, docs/plans/level-design.md section 11, L3.3):
-- boards the crowbar pries off plank by plank and a chain the bolt cutters
-- cut, loud work that's kept if you let go; and in the planner, one tool a
-- kind a house, found before the first door it opens and good for every
-- later one, no more kinds than the squad's house has.
return function(test, check, Shared, require)
	local Config = require(Shared.Config)
	local Rooms = require(Shared.Data.Rooms)
	local Tools = require(Shared.Data.Tools)
	local Rng = require(Shared.Lib.Rng)
	local HouseSize = require(Shared.Logic.HouseSize)
	local LockPlanner = require(Shared.Logic.LockPlanner)
	local MansionGen = require(Shared.Logic.MansionGen)
	local ToolLocks = require(Shared.Logic.ToolLocks)

	test("boards take a hold a plank and a chain one; one player's work is shorter; both are loud", function()
		local solo = ToolLocks.work("boards", 1, Config.ToolLocks)
		local four = ToolLocks.work("boards", 4, Config.ToolLocks)
		check.truthy(solo.steps * solo.seconds < four.steps * four.seconds, "solo pries for less time")
		check.truthy(four.steps * four.seconds >= 5, "a squad's boards take a while")
		check.truthy(solo.noise > 0 and four.noise > 0, "loud")
		local chain = ToolLocks.work("chain", 2, Config.ToolLocks)
		check.equal(chain.steps, 1, "one cut")
		check.truthy(chain.noise > 0, "a loud snap")
		for kind, info in ToolLocks.Kinds do
			check.truthy(Tools.ById[info.tool] ~= nil, kind .. "'s tool exists")
			check.truthy(Tools.ById[info.tool].planned, kind .. "'s tool is placed by the plan")
			check.truthy(ToolLocks.is(kind), kind .. " is a tool lock")
		end
		check.truthy(not ToolLocks.is("key"), "a key isn't")
		-- On a chest (a step inside a wing): fewer planks, the same holds.
		local chest = ToolLocks.work("boards", 4, Config.ToolLocks, true)
		check.equal(chest.steps, Config.ToolLocks.Boards.PiecePlanks, "a chest's planks")
		check.truthy(chest.steps < four.steps, "fewer than a door's")
		check.equal(ToolLocks.kindOf("Crowbar"), "boards", "the crowbar's kind")
		check.equal(ToolLocks.kindOf("BoltCutters"), "chain", "the bolt cutters' kind")
	end)

	test("work is kept: each hold is a step, and the last opens it", function()
		local state = ToolLocks.start(ToolLocks.work("boards", 4, Config.ToolLocks))
		local holds = 0
		while not ToolLocks.step(state) do
			holds += 1
			check.truthy(holds < 10, "it ends")
		end
		check.equal(holds + 1, Config.ToolLocks.Boards.Planks[4], "a hold a plank")
		check.truthy(ToolLocks.step(state), "stays open")
	end)

	test(
		"in the plan: a tool is found before its first gate, opens every door of its kind, never too many kinds",
		function()
			local seen = 0
			for squad = 1, 4 do
				local mansion, progression = HouseSize.config(Config.Mansion, Config.Progression, squad)
				for seed = 1, 25 do
					local layout = MansionGen.generate(seed * 5 + squad, Rooms.Mansion, mansion)
					local plan = LockPlanner.plan(
						layout,
						Rooms.MansionById,
						Rng.new(seed):Fork("progression"),
						progression,
						mansion
					)
					local where = string.format("squad %d seed %d", squad, seed)
					check.truthy(LockPlanner.solve(layout, plan, Rooms.MansionById).solvable, where .. ": finishes")
					local position = { [0] = 0 }
					for i, r in plan.order do
						position[r] = i
					end
					local kinds = 0
					for id, token in plan.tokens do
						if token.kind == "tool" then
							kinds += 1
							seen += 1
							-- (A step inside a wing's tool may lie across that wing,
							-- or open no door at all: WingSteps.spec.)
							local room = token.producer.room
							local first = token.opens and plan.locks[token.opens]
							if first and not first.step then
								check.truthy(
									position[plan.roomRegion[room]] < position[first.region],
									where .. ": " .. id .. " is found before its first gate"
								)
							end
							for _, seamId in token.also or {} do
								check.truthy(
									plan.locks[seamId].needs[1] == id,
									where .. ": the same tool opens " .. seamId
								)
							end
						end
					end
					check.truthy(kinds <= progression.MaxTools, where .. ": " .. kinds .. " tool kinds")
					for seamId, lock in plan.locks do
						if ToolLocks.is(lock.kind) then
							local token = plan.tokens[lock.needs[1]]
							check.truthy(token and token.kind == "tool", where .. ": " .. seamId .. " needs its tool")
							check.equal(token.tool, ToolLocks.Kinds[lock.kind].tool, where .. ": the right tool")
						end
					end
				end
			end
			check.truthy(seen > 10, "tools turn up (" .. seen .. ")")
		end
	)
end
