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
				local room = plan.tokens[id].producer.room
				check.truthy(rooms[room] == nil, "house " .. i .. ": two heirlooms in room " .. room)
				rooms[room] = true
				regions[plan.roomRegion[room]] = true
			end
			local spread, want = 0, math.min(#plan.finale.heirlooms, #plan.order + 1)
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
		check.truthy(deep / mansions >= 0.85, string.format("%d of %d mansions with 2+ regions", deep, mansions))
		check.truthy(one / cells >= 0.85, string.format("%d of %d old houses with one", one, cells))
		check.truthy(padlocks / mansions >= 0.3, string.format("a padlock in %d of %d mansions", padlocks, mansions))
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
