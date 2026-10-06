-- The bot's next step (Logic/BotPlan): the plan walked the way a player who
-- knows it would walk it, cranks, nailed chests, tools and puzzle-made
-- heirlooms included, on a hand-made plan and on real houses.
return function(test, check, Shared, require)
	local BotPlan = require(Shared.Logic.BotPlan)
	local Config = require(Shared.Config)
	local LockPlanner = require(Shared.Logic.LockPlanner)
	local MansionGen = require(Shared.Logic.MansionGen)
	local Rng = require(Shared.Lib.Rng)
	local Rooms = require(Shared.Data.Rooms)

	-- Rooms 1-2 open; 3 behind a key kept in 2; 4 behind a crank worked from
	-- 3; 5 behind boards (the crowbar in 3); the second heirloom in a chest
	-- chained shut in 4 (the bolt cutters in 5); a power door to 6 off the
	-- fuse box in 2, holding the first heirloom in a drawer.
	local plan = {
		regions = {
			[0] = { rooms = { 1, 2 } },
			[1] = { rooms = { 3 } },
			[2] = { rooms = { 4 } },
			[3] = { rooms = { 5 } },
			[4] = { rooms = { 6 } },
		},
		roomRegion = { 0, 0, 1, 2, 3, 4 },
		order = { 1, 2, 3, 4 },
		locks = {
			["seam:2-3"] = { kind = "key", needs = { "key:1" }, inside = 3 },
			["seam:3-4"] = { kind = "crank", side = 3, inside = 4 },
			["seam:3-5"] = { kind = "boards", needs = { "tool:Crowbar" }, inside = 5 },
			["seam:2-6"] = { kind = "power", needs = { "power:1" }, inside = 6 },
			["seam:1-7"] = { kind = "power", needs = { "power:safe" }, optional = true, vault = true, inside = 7 },
			["seam:4-1"] = { kind = "bolt", side = 4 },
		},
		pieces = {
			["piece:chest"] = { kind = "chain", needs = { "tool:BoltCutters" }, room = 4, prop = "prop:4:1" },
		},
		tokens = {
			["key:1"] = { kind = "key", producer = { kind = "container", room = 2 } },
			["tool:Crowbar"] = { kind = "tool", tool = "Crowbar", producer = { kind = "container", room = 3 } },
			["tool:BoltCutters"] = { kind = "tool", tool = "BoltCutters", producer = { kind = "container", room = 5 } },
			["power:1"] = { kind = "power", producer = { kind = "puzzle", id = "breaker:1" } },
			["power:safe"] = { kind = "power", producer = { kind = "puzzle", id = "breaker:1" } },
			["heirloom:1"] = { kind = "bulky", producer = { kind = "container", room = 6 } },
			["heirloom:2"] = { kind = "bulky", producer = { kind = "container", room = 4, piece = "piece:chest" } },
		},
		puzzles = { ["breaker:1"] = { kind = "breaker", room = 2 } },
		finale = { table = 1, heirlooms = { "heirloom:1", "heirloom:2" }, cut = {} },
	}
	local seams = {
		["seam:2-3"] = { a = 2, b = 3 },
		["seam:3-4"] = { a = 3, b = 4 },
		["seam:3-5"] = { a = 3, b = 5 },
		["seam:2-6"] = { a = 2, b = 6 },
		["seam:1-7"] = { a = 1, b = 7 },
		["seam:4-1"] = { a = 4, b = 1 },
	}

	test(
		"the hand-made plan: key, door, fuse box, heirloom, crank, crowbar, boards, cutters, chest, heirloom, out",
		function()
			local steps, tableSet, state = BotPlan.walk(plan, seams, { 1, 2 })
			local kinds = {}
			for _, step in steps do
				local what = step.seam or step.piece or step.token
				table.insert(kinds, step.kind .. (what and ("(" .. what .. ")") or ""))
			end
			local line = table.concat(kinds, " > ")
			check.truthy(tableSet, "the table gets set: " .. line)
			check.equal(steps[1].kind, "look", "first: look for the key (" .. line .. ")")
			check.equal(steps[1].token, "key:1", "the key")
			check.equal(steps[2].kind, "door", "then its door")
			check.truthy(string.find(line, "puzzle(power:1)", 1, true), "the fuse box is solved on the way")
			check.truthy(string.find(line, "crank(seam:3-4)", 1, true), "the crank door is worked")
			check.truthy(string.find(line, "toolDoor(seam:3-5)", 1, true), "the boards are pried with the crowbar")
			check.truthy(string.find(line, "piece(piece:chest)", 1, true), "the chained chest is cut open")
			check.truthy(string.find(line, "take(heirloom:", 1, true), "an heirloom lying there is taken")
			check.equal(steps[#steps].kind, "extract", "last: out of the front door")
			check.truthy(state.opened["seam:4-1"], "the bolt opened from inside as reach grew")
			check.equal(state.opened["seam:1-7"], nil, "the optional safe room is never the bot's business")
			-- No step repeats.
			local seen = {}
			for _, step in steps do
				check.equal(seen[step.key], nil, "step twice: " .. step.key)
				seen[step.key] = true
			end
		end
	)

	test("a blocked step is never offered again, and the next thing comes instead", function()
		local state = {
			reachable = { [1] = true, [2] = true },
			had = {},
			made = {},
			opened = {},
			pieceOpen = {},
			set = {},
			seams = seams,
			blocked = {},
		}
		local first = BotPlan.next(plan, state)
		check.equal(first.token, "key:1", "the key first")
		state.blocked[first.key] = true
		local second = BotPlan.next(plan, state)
		check.truthy(second ~= nil and second.key ~= first.key, "something else")
		check.equal(second.kind, "puzzle", "the fuse box, in reach")
	end)

	test("a chest's heirloom waits for its tool; an heirloom in hand goes to the table first", function()
		local state = {
			reachable = { [1] = true, [2] = true, [3] = true, [4] = true },
			had = { ["key:1"] = true },
			made = {},
			opened = { ["seam:2-3"] = true, ["seam:3-4"] = true },
			pieceOpen = {},
			set = {},
			seams = seams,
			blocked = {},
		}
		local step = BotPlan.next(plan, state)
		check.truthy(step.token ~= "heirloom:2", "not the chest's heirloom without the cutters: " .. tostring(step.key))
		state.held = "heirloom:1"
		state.had["heirloom:1"] = true
		check.equal(BotPlan.next(plan, state).kind, "set", "an heirloom in hand goes to the table")
		state.served = true
		check.equal(BotPlan.next(plan, state).kind, "extract", "served: out")
	end)

	test("a pocket waits for the house key: the key first, then its door, then the heirloom", function()
		-- Rooms 1-2 open; 3 is a pocket off 2 behind key:house, kept in 1,
		-- holding the only heirloom.
		local pocketPlan = {
			regions = { [0] = { rooms = { 1, 2, 3 } } },
			roomRegion = { 0, 0, 0 },
			order = {},
			locks = {
				["seam:2-3"] = { kind = "pocket", needs = { "key:house" }, inside = 3, pocket = true },
			},
			pockets = { [3] = { seam = "seam:2-3", opener = "key:house" } },
			tokens = {
				["key:house"] = { kind = "key", reusable = true, producer = { kind = "container", room = 1 } },
				["heirloom:1"] = { kind = "heirloom", producer = { kind = "container", room = 3 } },
			},
			puzzles = {},
			finale = { table = 1, heirlooms = { "heirloom:1" }, cut = {} },
		}
		local pocketSeams = { ["seam:2-3"] = { a = 2, b = 3 } }
		local steps, tableSet = BotPlan.walk(pocketPlan, pocketSeams, { 1, 2 })
		local kinds = {}
		for _, step in steps do
			table.insert(kinds, step.kind .. "(" .. tostring(step.seam or step.token) .. ")")
		end
		local line = table.concat(kinds, " > ")
		check.truthy(tableSet, "the table gets set: " .. line)
		check.equal(
			line,
			"look(key:house) > door(seam:2-3) > look(heirloom:1) > take(heirloom:1) > set(heirloom:1) > extract(nil)",
			"the key, the pocket's door, the heirloom, the table, out"
		)
	end)

	test("real houses: the bot walks every plan to the dinner and out", function()
		local squads = { 1, 2, 4 }
		for i, seed in { 61, 1, 7, 21, 165547210, 3, 11 } do
			local squad = squads[(i % #squads) + 1]
			local layout = MansionGen.generate(seed * 13 + 5, Rooms.Mansion, Config.Mansion)
			local real = LockPlanner.plan(
				layout,
				Rooms.MansionById,
				Rng.new(seed):Fork("progression"),
				Config.Progression,
				Config.Mansion,
				squad >= 3 and 1 or 0
			)
			local realSeams = {}
			for _, seam in layout.seams do
				realSeams[seam.id] = { a = seam.a, b = seam.b }
			end
			local steps, tableSet = BotPlan.walk(real, realSeams, real.regions[0].rooms, 120)
			check.truthy(tableSet, string.format("seed %d: the table set in %d steps", seed, #steps))
			check.equal(steps[#steps].kind, "extract", string.format("seed %d: ends with the way out", seed))
		end
	end)
end
