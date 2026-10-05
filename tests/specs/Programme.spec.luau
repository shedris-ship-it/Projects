-- The adventure picks the rooms (Logic/Programme, docs/plans/level-design.md
-- section 5.4): the deck is a few different kinds, the rooms it needs come
-- first, the lists keep every template's limits, and in generated houses the
-- planner mostly uses the deck.
return function(test, check, Shared, require)
	local Config = require(Shared.Config)
	local Rooms = require(Shared.Data.Rooms)
	local Rng = require(Shared.Lib.Rng)
	local HouseSize = require(Shared.Logic.HouseSize)
	local LockPlanner = require(Shared.Logic.LockPlanner)
	local MansionGen = require(Shared.Logic.MansionGen)
	local Programme = require(Shared.Logic.Programme)

	local cfg = Config.Mansion.Programme
	local general = {}
	for _, template in Rooms.Mansion do
		if not template.mansion.role then
			table.insert(general, template)
		end
	end

	test("a deck is the squad's number of different kinds, only those switched on", function()
		for squad = 1, 4 do
			for seed = 1, 30 do
				local deck = Programme.deck(Rng.new(seed), cfg, Config.Progression.Enabled, cfg.DeckSize[squad])
				local n = 0
				for kind in deck do
					n += 1
					check.truthy(table.find(cfg.Kinds, kind) ~= nil, kind .. " is a deck kind")
				end
				check.equal(n, cfg.DeckSize[squad])
			end
		end
		local deck = Programme.deck(Rng.new(1), cfg, { padlock = true }, 3)
		local only = 0
		for _ in deck do
			only += 1
		end
		check.truthy(deck.padlock and only == 1, "only what's switched on")
	end)

	test("the rooms a deck needs come first; the lists keep max, per-floor and floors", function()
		local byId = Rooms.MansionById
		for seed = 1, 40 do
			local deck = { padlock = true, musicbox = true }
			local floors = Programme.rooms(Rng.new(seed), general, deck, cfg)
			check.equal(floors[0][1], "study", "the computer's desk first")
			check.equal(floors[0][2], "music_room", "then the piano")
			local counts = {}
			for floor = 0, 1 do
				local here = {}
				for _, id in floors[floor] do
					local m = byId[id].mansion
					check.truthy(table.find(m.floors, floor) ~= nil, id .. " on floor " .. floor)
					counts[id] = (counts[id] or 0) + 1
					here[id] = (here[id] or 0) + 1
					check.truthy(here[id] <= (m.perFloor or math.huge), id .. " per floor")
				end
			end
			for id, n in counts do
				check.truthy(n <= (byId[id].mansion.max or 1), id .. " at most max")
			end
		end
	end)

	test("in generated houses the deck's rooms are built and the planner mostly uses the deck", function()
		local mansion, progression = HouseSize.config(Config.Mansion, Config.Progression, 4)
		local wanted, built, used, kinds = 0, 0, 0, 0
		for seed = 1, 30 do
			local layout = MansionGen.generate(seed * 19 + 4, Rooms.Mansion, mansion)
			local deck = layout.programme and layout.programme.deck or {}
			for kind in deck do
				local need = Programme.Needs[kind]
				if need then
					wanted += 1
					for _, room in layout.rooms do
						if room.template == need then
							built += 1
							break
						end
					end
				end
			end
			local plan =
				LockPlanner.plan(layout, Rooms.MansionById, Rng.new(seed):Fork("progression"), progression, mansion)
			local present = {}
			for _, lock in plan.locks do
				present[lock.kind] = true
			end
			for _, puzzle in plan.puzzles do
				present[puzzle.kind] = true
			end
			for kind in deck do
				kinds += 1
				-- A padlock's puzzle is the computer; the rest go by their own name.
				if present[kind] or (kind == "padlock" and present.terminal) then
					used += 1
				end
			end
		end
		check.truthy(wanted == 0 or built / wanted >= 0.9, ("%d of %d needed rooms built"):format(built, wanted))
		check.truthy(used / kinds >= 0.6, ("%d of %d deck kinds in the plan"):format(used, kinds))
	end)
end
