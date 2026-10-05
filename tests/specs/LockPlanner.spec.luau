-- The escape's locks and keys (Logic/LockPlanner, docs/plans/gameplay-rework.md
-- section 5): over many houses, every plan can be finished, what opens a door
-- is always found before it, region 0 has somewhere to run and hide, and the
-- house itself is untouched.
return function(test, check, Shared, require)
	local Config = require(Shared.Config)
	local Rooms = require(Shared.Data.Rooms)
	local Rng = require(Shared.Lib.Rng)
	local FloorPlan = require(Shared.Logic.FloorPlan)
	local LevelGraph = require(Shared.Logic.LevelGraph)
	local LockPlanner = require(Shared.Logic.LockPlanner)
	local MansionGen = require(Shared.Logic.MansionGen)

	local cfg = Config.Progression

	local function planFor(layout, templates, config, seed)
		return LockPlanner.plan(layout, templates, Rng.new(seed):Fork("progression"), cfg, config)
	end

	-- Made once and shared by the tests below.
	local houses = {}
	for seed = 1, 100 do
		local layout = MansionGen.generate(seed * 13 + 5, Rooms.Mansion, Config.Mansion)
		table.insert(houses, {
			layout = layout,
			templates = Rooms.MansionById,
			config = Config.Mansion,
			plan = planFor(layout, Rooms.MansionById, Config.Mansion, seed),
			mansion = true,
		})
	end
	for seed = 1, 30 do
		local layout = LevelGraph.generate(seed * 17 + 1, Rooms.List, Config.Level)
		table.insert(houses, {
			layout = layout,
			templates = Rooms.ById,
			config = Config.Level,
			plan = planFor(layout, Rooms.ById, Config.Level, seed),
		})
	end
	local fallback = MansionGen.fallback(0, Rooms.Mansion, Config.Mansion)
	table.insert(houses, {
		layout = fallback,
		templates = Rooms.MansionById,
		config = Config.Mansion,
		plan = planFor(fallback, Rooms.MansionById, Config.Mansion, 1),
		mansion = true,
	})

	test("every plan can be finished: the table set, then out of the house", function()
		for i, house in houses do
			local result = LockPlanner.solve(house.layout, house.plan, house.templates)
			check.truthy(result.tableSet, "house " .. i .. ": the heirlooms are all reachable")
			check.truthy(result.out, "house " .. i .. ": a way out after the dinner")
		end
	end)

	test("every plan passes its own checks (or is the open house)", function()
		for i, house in houses do
			local problems = LockPlanner.check(house.layout, house.plan, house.templates, cfg, house.config)
			check.truthy(
				#problems == 0 or #house.plan.order == 0,
				"house " .. i .. ": " .. table.concat(problems, "; ")
			)
		end
	end)

	test("each region opens by one locked door; every other way in is bolted on its side", function()
		for i, house in houses do
			local plan = house.plan
			for _, r in plan.order do
				local gate = plan.regions[r].gate
				check.truthy(
					gate ~= nil and plan.locks[gate] ~= nil,
					"house " .. i .. ": region " .. r .. " has a gate"
				)
				local gates = 0
				for _, lock in plan.locks do
					if lock.region == r then
						if lock.kind == "bolt" then
							local side = plan.roomRegion[lock.side]
							check.equal(side, r, "a bolt opens from inside its region")
						else
							gates += 1
						end
					end
				end
				check.equal(gates, 1, "house " .. i .. ": one gate into region " .. r)
			end
		end
	end)

	test("locks are only on real doorways, never on the dinner's cut, never in region 0", function()
		for i, house in houses do
			local connected = {}
			for _, seam in house.layout.seams do
				connected[seam.id] = seam.connected
			end
			for id, lock in house.plan.locks do
				check.truthy(connected[id] == true, "house " .. i .. ": " .. id .. " is a doorway")
				check.truthy(lock.region ~= 0, "house " .. i .. ": nothing locked in region 0")
				check.truthy(not table.find(house.plan.finale.cut, id), "house " .. i .. ": the cut isn't locked")
			end
		end
	end)

	test("the hall and the dining room are open from the start", function()
		for i, house in houses do
			local plan = house.plan
			check.equal(plan.roomRegion[house.layout.start], 0, "house " .. i .. ": the hall")
			check.equal(plan.roomRegion[house.layout.deliberation], 0, "house " .. i .. ": the dining room")
			check.equal(plan.finale.table, house.layout.deliberation, "the dinner is in the dining room")
		end
	end)

	test("heirlooms lie in different regions when there are enough, never two in a room", function()
		for i, house in houses do
			local plan = house.plan
			local regions, rooms = {}, {}
			for _, id in plan.finale.heirlooms do
				local room = LockPlanner.tokenRoom(plan, plan.tokens[id])
				check.truthy(rooms[room] == nil, "house " .. i .. ": two heirlooms in room " .. room)
				rooms[room] = true
				regions[plan.roomRegion[room]] = true
			end
			-- A mansion region of nothing but corridors keeps no heirloom
			-- (docs/plans/level-design.md section 4).
			local byId = {}
			for _, room in house.layout.rooms do
				byId[room.id] = room
			end
			local keepable = 0
			for r = 0, #plan.order do
				for _, id in plan.regions[r].rooms do
					local room = byId[id]
					local template = house.templates[room.template]
					local corridor = room.corridor or room.kind == "stair" or template.family == "corridor"
					if id ~= plan.finale.table and not (house.mansion and corridor) then
						keepable += 1
						break
					end
				end
			end
			local spread, want = 0, math.min(#plan.finale.heirlooms, keepable)
			for _ in regions do
				spread += 1
			end
			check.equal(spread, want, "house " .. i .. ": heirlooms spread over the regions")
			local n = #plan.finale.heirlooms
			check.truthy(n >= cfg.FinaleItems[1] and n <= cfg.FinaleItems[2], "a few heirlooms")
		end
	end)

	test("the same house and seed give the same plan", function()
		local layout = houses[1].layout
		local a = planFor(layout, Rooms.MansionById, Config.Mansion, 1)
		local b = planFor(layout, Rooms.MansionById, Config.Mansion, 1)
		local function describe(plan)
			local out = {}
			for _, id in plan.order do
				table.insert(out, id .. ":" .. plan.regions[id].gate)
			end
			for id, token in plan.tokens do
				table.insert(out, id .. "@" .. tostring(token.producer.room or token.producer.id))
			end
			table.sort(out)
			return table.concat(out, ",")
		end
		check.equal(describe(a), describe(b), "deterministic")
	end)

	test("the plan doesn't change the house's fingerprint", function()
		local layout = MansionGen.generate(42, Rooms.Mansion, Config.Mansion)
		local before = FloorPlan.fingerprint(layout)
		layout.progression = planFor(layout, Rooms.MansionById, Config.Mansion, 42)
		check.equal(FloorPlan.fingerprint(layout), before, "nested, so the hash holds")
	end)

	test("most mansions get two or three regions; the old house gets one", function()
		local mansions, deep, cells, one, padlocks = 0, 0, 0, 0, 0
		for _, house in houses do
			local k = #house.plan.order
			if house.mansion then
				mansions += 1
				if k >= 2 then
					deep += 1
				end
				for _, lock in house.plan.locks do
					if lock.kind == "padlock" then
						padlocks += 1
					end
				end
			else
				cells += 1
				if k == 1 then
					one += 1
				end
			end
		end
		-- One house on its own; a run keeps the best of several (Logic/HouseSearch,
		-- HouseSearch.spec), which always has them.
		check.truthy(deep / mansions >= 0.8, string.format("%d of %d mansions with 2+ regions", deep, mansions))
		check.truthy(one / cells >= 0.85, string.format("%d of %d old houses with one", one, cells))
		check.truthy(padlocks / mansions >= 0.3, string.format("a padlock in %d of %d mansions", padlocks, mansions))
	end)

	test("a double lock wants two keys, kept in different rooms opened before it, and every plan finishes", function()
		local HouseSize = require(Shared.Logic.HouseSize)
		local mansion, progression = HouseSize.config(Config.Mansion, Config.Progression, 4)
		local saved = progression.Flavours
		progression.Flavours = { key = 0, padlock = 0, power = 0, crank = 0, double = 1 }
		local doubles = 0
		for seed = 1, 20 do
			local layout = MansionGen.generate(seed * 53 + 1, Rooms.Mansion, mansion)
			local plan =
				LockPlanner.plan(layout, Rooms.MansionById, Rng.new(seed):Fork("progression"), progression, mansion)
			check.truthy(LockPlanner.solve(layout, plan, Rooms.MansionById).solvable, "seed " .. seed .. " finishes")
			local position = { [0] = 0 }
			for i, r in plan.order do
				position[r] = i
			end
			for id, lock in plan.locks do
				if lock.kind == "double" then
					doubles += 1
					check.equal(#lock.needs, 2, id .. " needs two keys")
					local a = LockPlanner.tokenRoom(plan, plan.tokens[lock.needs[1]])
					local b = LockPlanner.tokenRoom(plan, plan.tokens[lock.needs[2]])
					check.truthy(a ~= b, id .. ": the keys are in different rooms")
					for _, room in { a, b } do
						check.truthy(position[plan.roomRegion[room]] < position[lock.region], id .. ": a key behind it")
					end
				end
			end
		end
		progression.Flavours = saved
		check.truthy(doubles > 0, "some double locks")
	end)

	test("a gate kind switched off never turns up; the key is always there to fall back on", function()
		local saved = cfg.Enabled
		cfg.Enabled = { key = true }
		for i = 1, 20 do
			local house = houses[i]
			local plan = planFor(house.layout, house.templates, house.config, i)
			for id, lock in plan.locks do
				check.truthy(
					lock.kind == "key" or lock.kind == "bolt",
					"house " .. i .. ": " .. id .. " is " .. lock.kind
				)
			end
			check.equal(next(plan.puzzles), nil, "no puzzles")
		end
		cfg.Enabled = saved
	end)

	test("a gate worked from its outer side (a crank) needs nothing found, and every plan still finishes", function()
		table.insert(LockPlanner.Gates, { id = "testcrank", side = true })
		LockPlanner.GateById.testcrank = LockPlanner.Gates[#LockPlanner.Gates]
		local savedEnabled, savedFlavours = cfg.Enabled, cfg.Flavours
		cfg.Enabled = { key = true, padlock = true, testcrank = true }
		cfg.Flavours = { key = 1, padlock = 1, testcrank = 4 }
		local cranks = 0
		for i = 1, 40 do
			local house = houses[i]
			local plan = planFor(house.layout, house.templates, house.config, i)
			for id, lock in plan.locks do
				if lock.kind == "testcrank" then
					cranks += 1
					check.equal(lock.needs, nil, "nothing to find")
					local seam
					for _, s in house.layout.seams do
						if s.id == id then
							seam = s
						end
					end
					check.truthy(lock.side == seam.a or lock.side == seam.b, "worked from one of its rooms")
					check.truthy(lock.side ~= lock.inside, "from the outside")
				end
			end
			check.truthy(LockPlanner.solve(house.layout, plan, house.templates).solvable, "house " .. i .. " finishes")
			local problems = LockPlanner.check(house.layout, plan, house.templates, cfg, house.config)
			check.truthy(#problems == 0 or #plan.order == 0, "house " .. i .. ": " .. table.concat(problems, "; "))
		end
		table.remove(LockPlanner.Gates)
		LockPlanner.GateById.testcrank = nil
		cfg.Enabled, cfg.Flavours = savedEnabled, savedFlavours
		check.truthy(cranks > 0, "some gates were cranks")
	end)

	test("a producer spanning two rooms needs both open before its token is had", function()
		for i, house in houses do
			local plan = house.plan
			-- An heirloom whose second room can never be reached: never had.
			local id = plan.finale.heirlooms[1]
			local token = plan.tokens[id]
			local saved = token.producer
			token.producer = { kind = "dumbwaiter", rooms = { saved.room, -1 } }
			local result = LockPlanner.solve(house.layout, plan, house.templates)
			check.truthy(not result.held[id] and not result.tableSet, "house " .. i .. ": not had")
			-- Both rooms open: had, and the plan finishes.
			token.producer = { kind = "dumbwaiter", rooms = { saved.room, house.layout.start } }
			check.truthy(LockPlanner.solve(house.layout, plan, house.templates).solvable, "house " .. i .. ": had")
			token.producer = saved
			-- A key made in two rooms, one behind the gate it opens: the check
			-- says so.
			if #plan.order >= 1 then
				local lock = plan.locks[plan.regions[plan.order[1]].gate]
				local key = lock.needs and plan.tokens[lock.needs[1]]
				if key and key.producer.kind == "container" then
					local before = key.producer
					key.producer =
						{ kind = "dumbwaiter", rooms = { before.room, plan.regions[plan.order[1]].rooms[1] } }
					local flagged = false
					for _, problem in LockPlanner.check(house.layout, plan, house.templates, cfg, house.config) do
						flagged = flagged or string.find(problem, "opened by something behind it", 1, true) ~= nil
					end
					check.truthy(flagged, "house " .. i .. ": half behind its own gate")
					key.producer = before
				end
			end
		end
	end)

	test("a house too small for regions is simply open, with heirlooms to find", function()
		local layout = houses[1].layout
		local saved = cfg.Regions
		cfg.Regions = { { upTo = 99, count = 0 } }
		local plan = planFor(layout, Rooms.MansionById, Config.Mansion, 3)
		cfg.Regions = saved
		check.equal(#plan.order, 0, "no regions")
		check.equal(next(plan.locks), nil, "no locks")
		check.truthy(LockPlanner.solve(layout, plan, Rooms.MansionById).solvable, "still a dinner and a way out")
	end)
end
