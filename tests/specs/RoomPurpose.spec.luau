-- Every room has a reason (Logic/RoomPurpose, docs/plans/level-design.md
-- section 4): the tiers come out of the templates, the plan and the leads;
-- regions are checked for their kit; and in generated mansions what the
-- plan keeps goes to rooms that need a reason, never an heirloom to a
-- corridor.
return function(test, check, Shared, require)
	local Config = require(Shared.Config)
	local Rooms = require(Shared.Data.Rooms)
	local Rng = require(Shared.Lib.Rng)
	local Leads = require(Shared.Logic.Leads)
	local LockPlanner = require(Shared.Logic.LockPlanner)
	local MansionGen = require(Shared.Logic.MansionGen)
	local RoomPurpose = require(Shared.Logic.RoomPurpose)

	local templates = Rooms.MansionById

	local function room(id: number, template: string, extra)
		local r = { id = id, template = template, floor = 0, x = 0, z = 0, w = 20, d = 20, rotation = 0 }
		for key, value in extra or {} do
			r[key] = value
		end
		return r
	end

	local layout = {
		mode = "Mansion",
		rooms = {
			room(1, "grand_hall", { tall = true }),
			room(2, "dining_room"),
			room(3, "bathroom"),
			room(4, "study"),
			room(5, "main_corridor", { corridor = true }),
			room(6, "guest_room", { lantern = true }),
			room(7, "back_stairs", { kind = "stair", tall = true }),
		},
		seams = {},
		start = 1,
		deliberation = 2,
	}

	test("by itself: landmarks, lures, the start, the table, Lanterns, hiding spots, ways between", function()
		local base = RoomPurpose.base(layout, templates)
		check.truthy(table.find(base[1].strong, "the start"), "the hall is the start")
		check.truthy(table.find(base[1].strong, "landmark: GrandfatherClock"), "the hall's clock is a landmark")
		check.truthy(table.find(base[2].strong, "the table"), "the dining room has the table")
		check.truthy(base[3].lure, "the bathroom's toilet and taps are lures")
		check.truthy(table.find(base[6].strong, "Lantern"), "a Lantern room")
		check.truthy(table.find(base[4].survival, "hide"), "the study has somewhere to hide")
		check.truthy(not RoomPurpose.hasReason(base[4]), "an empty study has no reason to go in")
		check.truthy(RoomPurpose.hasReason(base[5]), "a corridor's reason is getting places")
		check.truthy(RoomPurpose.hasReason(base[7]), "and a stair's")
		check.truthy(string.find(RoomPurpose.describe(base[4]), "NO REASON") ~= nil, "describe says so")
	end)

	test("with the plan and the leads: what's kept, puzzles, notes and decoys give rooms reasons", function()
		local plan = {
			regions = { [0] = { rooms = { 1, 2, 3, 4, 5, 6, 7 } } },
			roomRegion = {},
			order = {},
			locks = {},
			tokens = {
				["key:1"] = { kind = "key", producer = { kind = "container", room = 4 } },
				["code:1"] = { kind = "code", producer = { kind = "puzzle", id = "terminal:1" } },
			},
			puzzles = { ["terminal:1"] = { kind = "terminal", room = 6 } },
			finale = { table = 2, heirlooms = {}, cut = {}, goal = 1 },
		}
		local leads =
			{ tokens = { ["key:1"] = { kind = "note", noteRoom = 3 } }, decoys = { { kind = "keepsake", room = 5 } } }
		local purposes = RoomPurpose.of(layout, plan, templates, leads)
		check.truthy(table.find(purposes[4].strong, "key"), "the study keeps the key")
		check.truthy(RoomPurpose.hasReason(purposes[4]), "so it has a reason now")
		check.truthy(table.find(purposes[6].strong, "puzzle: terminal"), "the computer's room")
		check.truthy(table.find(purposes[3].strong, "note"), "the note's room")
		check.truthy(table.find(purposes[5].strong, "keepsake box"), "an empty box still draws you in")
	end)

	test("a region's kit: a hiding spot, a lure, a landmark or a Lantern", function()
		local plan = {
			regions = { [0] = { rooms = { 1, 2, 3 } }, [1] = { rooms = { 4, 5 } } },
			order = { 1 },
		}
		local purposes = RoomPurpose.base(layout, templates)
		-- Region 0: hides, the bathroom's lures, the clock. Region 1 (the study
		-- and a corridor): hides, but no lure and no landmark.
		check.equal(RoomPurpose.kitGaps(purposes, plan), 2)
	end)

	test("every mansion template has somewhere to hide, unless it's a stair", function()
		for _, template in Rooms.Mansion do
			local offers = LockPlanner.offers(template, true)
			check.truthy(offers.hides > 0 or template.mansion.role == "stair", template.id .. " has no hiding spot")
		end
	end)

	test("generated mansions: no heirloom in a corridor, and what's kept mostly gives a room its reason", function()
		local filled, kept = 0, 0
		for seed = 1, 40 do
			local house = MansionGen.generate(seed * 7 + 3, Rooms.Mansion, Config.Mansion)
			local plan = LockPlanner.plan(
				house,
				templates,
				Rng.new(seed):Fork("progression"),
				Config.Progression,
				Config.Mansion
			)
			local base = RoomPurpose.base(house, templates)
			local byId = {}
			for _, r in house.rooms do
				byId[r.id] = r
			end
			-- (The dumbwaiter is a set piece in the service corridor: the one
			-- heirloom a corridor may give up.)
			for _, id in plan.finale.heirlooms do
				local where = plan.tokens[id].producer.kind == "container"
						and LockPlanner.tokenRoom(plan, plan.tokens[id])
					or nil
				check.truthy(
					where == nil or not (base[where].route[1] == "corridor" or byId[where].corridor),
					"seed " .. seed .. ": " .. id .. " in a corridor"
				)
			end
			for _, token in plan.tokens do
				if token.producer.kind == "container" then
					kept += 1
					if not RoomPurpose.hasReason(base[token.producer.room]) then
						filled += 1
					end
				end
			end
			local leads = Leads.plan(plan, Leads.rooms(house, templates), Rng.new(seed):Fork("leads"), Config.Leads)
			check.truthy(next(RoomPurpose.of(house, plan, templates, leads)) ~= nil, "purposes for every room")
		end
		-- Most of what's kept in drawers goes where nothing else draws you.
		check.truthy(filled / kept > 0.5, ("%d of %d kept things fill a room with no reason"):format(filled, kept))
	end)
end
