-- The level-design metrics (Logic/HouseMetrics, docs/plans/level-design.md
-- section 5.1): on a ring of rooms built by hand the numbers come out as
-- walked, and over generated houses every plan is walked to the end.
return function(test, check, Shared, require)
	local Config = require(Shared.Config)
	local Rooms = require(Shared.Data.Rooms)
	local Rng = require(Shared.Lib.Rng)
	local HouseMetrics = require(Shared.Logic.HouseMetrics)
	local LockPlanner = require(Shared.Logic.LockPlanner)
	local MansionGen = require(Shared.Logic.MansionGen)
	local MansionHouse = require(Shared.Logic.MansionHouse)
	local NavGraph = require(Shared.Logic.NavGraph)

	local nav = NavGraph.options(Config)
	local templates = Rooms.MansionById

	-- Ten 20x20 rooms in a ring, numbered round it:
	--    1  2  3  4
	--   10        5
	--    9  8  7  6
	local SPOTS = {
		{ 0, 0 },
		{ 20, 0 },
		{ 40, 0 },
		{ 60, 0 },
		{ 60, 20 },
		{ 60, 40 },
		{ 40, 40 },
		{ 20, 40 },
		{ 0, 40 },
		{ 0, 20 },
	}
	local function ring(cut: string?)
		local house = MansionHouse.new(Config.Mansion, templates)
		for i, spot in SPOTS do
			house:Insert({
				id = i,
				template = i == 10 and "main_corridor" or "den",
				floor = 0,
				rotation = 0,
				x = spot[1],
				z = spot[2],
				w = 20,
				d = 20,
				zone = "public",
				corridor = i == 10 or nil,
			})
		end
		local seams = house:AllSeams()
		local edges = {}
		for _, seam in seams do
			seam.connected = seam.id ~= cut
			if seam.connected then
				table.insert(edges, { seam.a, seam.b })
			end
		end
		return {
			mode = "Mansion",
			rooms = house.rooms,
			seams = seams,
			edges = edges,
			start = 1,
			exit = 6,
			deliberation = 2,
			frontDoor = { room = 1, dir = "N", line = 0, along = 10, floor = 0 },
			lanterns = {},
		}
	end
	local function regionsOf(regions)
		local roomRegion = {}
		for r, region in regions do
			for _, id in region.rooms do
				roomRegion[id] = r
			end
		end
		return roomRegion
	end
	local function measure(layout, plan)
		return HouseMetrics.measure(layout, plan, templates, { nav = nav, config = Config.Mansion, shortcut = 30 })
	end
	local function near(value, expected, slack, what)
		check.truthy(
			math.abs(value - expected) <= slack,
			what .. ": " .. tostring(value) .. ", expected about " .. expected
		)
	end

	-- One region behind a key from room 10, its far end bolted back to room 9.
	local function onePlan()
		local regions = { [0] = { rooms = { 1, 2, 9, 10 } }, [1] = { rooms = { 3, 4, 5, 6, 7, 8 }, gate = "seam:2-3" } }
		return {
			regions = regions,
			roomRegion = regionsOf(regions),
			order = { 1 },
			locks = {
				["seam:2-3"] = { kind = "key", needs = { "key:1" }, region = 1, inside = 3 },
				["seam:8-9"] = { kind = "bolt", side = 8, region = 1 },
			},
			tokens = {
				["key:1"] = { kind = "key", producer = { kind = "container", room = 10 } },
				["heirloom:1"] = { kind = "heirloom", producer = { kind = "container", room = 6 } },
			},
			puzzles = {},
			finale = { table = 2, heirlooms = { "heirloom:1" }, cut = {}, goal = 1 },
		}
	end

	test("a ring with one locked region: the walk, the shortcut, the key and the carry", function()
		local m = measure(ring(), onePlan())
		check.truthy(m.tableSet, "the walk sets the table")
		check.equal(m.regions, 1)
		near(m.r0Share, 0.4, 1e-9, "region 0's share")
		check.equal(m.minRegion, 6)
		-- From the dining room the far end (room 8) is 6 rooms round one way and
		-- 4 the other: the bolt saves about two rooms' walk.
		near(m.shortcuts[1], 40, 6, "the bolt's saving")
		check.equal(m.shortcutShare, 1)
		near(m.keyWalkMin, 40, 6, "the key's walk to its door (room 10 to room 2)")
		near(m.carryMax, 80, 8, "the heirloom's carry (room 6 to the table, bolt open)")
		near(m.finaleRun, 20, 6, "the run out (the dining room to the hall)")
		check.equal(m.returns, 0)
		check.equal(m.corridorTokens, 1, "the key lies in the corridor (room 10)")
		check.equal(m.corridorHeirlooms, 0)
		check.truthy(m.revisit > 0 and m.revisit < 1, "some of the walk goes back over known rooms")
	end)

	test("without its far doorway the region has no shortcut and the carry goes the long way", function()
		local plan = onePlan()
		plan.locks["seam:8-9"] = nil
		local m = measure(ring("seam:8-9"), plan)
		check.truthy(m.tableSet, "the walk sets the table")
		check.equal(m.shortcutShare, 0)
		near(m.carryMax, 80, 8, "room 6 to the table is 4 rooms either way")
		check.equal(m.stageLoop, 0, "a broken ring has no loop at all")
	end)

	test("a door opened from an older region counts as a return", function()
		local regions = {
			[0] = { rooms = { 1, 2, 10 } },
			[1] = { rooms = { 3, 4, 5, 6 }, gate = "seam:2-3" },
			[2] = { rooms = { 7, 8, 9 }, gate = "seam:9-10" },
		}
		local plan = {
			regions = regions,
			roomRegion = regionsOf(regions),
			order = { 1, 2 },
			locks = {
				["seam:2-3"] = { kind = "key", needs = { "key:1" }, region = 1, inside = 3 },
				["seam:9-10"] = { kind = "key", needs = { "key:2" }, region = 2, inside = 9 },
				["seam:6-7"] = { kind = "bolt", side = 7, region = 2 },
			},
			tokens = {
				["key:1"] = { kind = "key", producer = { kind = "container", room = 10 } },
				["key:2"] = { kind = "key", producer = { kind = "container", room = 5 } },
				["heirloom:1"] = { kind = "heirloom", producer = { kind = "container", room = 8 } },
			},
			puzzles = {},
			finale = { table = 2, heirlooms = { "heirloom:1" }, cut = {}, goal = 1 },
		}
		local m = measure(ring(), plan)
		check.truthy(m.tableSet, "the walk sets the table")
		check.equal(m.returns, 1, "region 2's door is back in region 0")
		check.equal(m.minRegion, 3)
		check.equal(m.gateRepeats, 1, "two key doors in a row")
		near(m.keyWalkMin, 40, 6, "the nearer key (room 10) to its door")
	end)

	test("score: inside every band costs nothing; outside costs weight per scale missed", function()
		local targets = {
			a = { band = { 1, 2 }, weight = 2 },
			b = { band = { 0, 10 }, bySquad = { [1] = { 0, 4 } }, weight = 1, scale = 2 },
		}
		local score = HouseMetrics.score({ a = 1.5, b = 8 }, targets, 4)
		check.equal(score, 0)
		score = HouseMetrics.score({ a = 3, b = 8 }, targets, 1)
		check.equal(score, 2 * 1 + 1 * 4 / 2)
		local infinite = HouseMetrics.score({ a = math.huge }, targets, 4)
		check.truthy(infinite > 0 and infinite < math.huge, "an unreachable value costs a lot but stays a number")
		local _, card = HouseMetrics.score({ a = 3, b = 8 }, targets, 1)
		check.equal(#HouseMetrics.describe(card), 2)
	end)

	test("every generated house's plan is walked to the end: the table set and a way out", function()
		for seed = 1, 12 do
			local layout = MansionGen.generate(seed * 31 + 7, Rooms.Mansion, Config.Mansion)
			local plan = LockPlanner.plan(
				layout,
				templates,
				Rng.new(seed):Fork("progression"),
				Config.Progression,
				Config.Mansion
			)
			local m = HouseMetrics.measure(layout, plan, templates, { nav = nav, config = Config.Mansion })
			check.truthy(m.tableSet, "seed " .. seed .. ": the table is set")
			check.truthy(m.finaleRun < math.huge, "seed " .. seed .. ": a way out after the dinner")
			check.truthy(m.walk > 0 and m.revisit >= 0 and m.revisit <= 1, "seed " .. seed .. ": the walk adds up")
			check.truthy(m.hideReach < math.huge, "seed " .. seed .. ": every stage has a hiding spot within reach")
		end
	end)
end
