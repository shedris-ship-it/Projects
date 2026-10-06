-- How keys and heirlooms are found (Logic/Leads, R2c "leads, not
-- rummaging"): every kept token gets a lead that fits its room, notes lie
-- where you can already go, and decoys never sit on a find.
return function(test, check, Shared, require)
	local Config = require(Shared.Config)
	local Rooms = require(Shared.Data.Rooms)
	local Rng = require(Shared.Lib.Rng)
	local Leads = require(Shared.Logic.Leads)
	local LockPlanner = require(Shared.Logic.LockPlanner)
	local MansionGen = require(Shared.Logic.MansionGen)
	local LevelGraph = require(Shared.Logic.LevelGraph)

	local cfg = Config.Leads

	local houses = {}
	for seed = 1, 60 do
		local layout = MansionGen.generate(seed * 7 + 3, Rooms.Mansion, Config.Mansion)
		local plan = LockPlanner.plan(
			layout,
			Rooms.MansionById,
			Rng.new(seed):Fork("progression"),
			Config.Progression,
			Config.Mansion
		)
		local rooms = Leads.rooms(layout, Rooms.MansionById)
		table.insert(houses, {
			layout = layout,
			plan = plan,
			rooms = rooms,
			leads = Leads.plan(plan, rooms, Rng.new(seed):Fork("leads"), cfg),
		})
	end
	for seed = 1, 15 do
		local layout = LevelGraph.generate(seed * 11 + 2, Rooms.List, Config.Level)
		local plan =
			LockPlanner.plan(layout, Rooms.ById, Rng.new(seed):Fork("progression"), Config.Progression, Config.Level)
		local rooms = Leads.rooms(layout, Rooms.ById)
		table.insert(houses, {
			layout = layout,
			plan = plan,
			rooms = rooms,
			leads = Leads.plan(plan, rooms, Rng.new(seed):Fork("leads"), cfg),
		})
	end

	local function position(plan)
		local p = { [0] = 0 }
		for i, r in plan.order do
			p[r] = i
		end
		return p
	end

	test("every kept key and heirloom gets a lead that fits it and its room", function()
		for i, house in houses do
			for id, token in house.plan.tokens do
				local lead = house.leads.tokens[id]
				-- (A tool lies in plain sight: no lead. docs/plans/level-design.md 11.)
				if token.producer.kind == "container" and token.kind ~= "tool" then
					check.truthy(lead ~= nil, "house " .. i .. ": " .. id .. " has a lead")
					local room = token.producer.room
					if lead.kind == "hook" then
						check.equal(token.kind, "key", "only keys hang on a rack")
					elseif lead.kind == "keepsake" or lead.kind == "display" then
						check.truthy(house.rooms[room].tops > 0, "a box or case needs a top to stand on")
					end
				else
					check.equal(lead, nil, "a puzzle's token needs no lead")
				end
			end
		end
	end)

	test("a note lies where the squad can be no later than what it points at, never beside it", function()
		local notes, vague = 0, 0
		for i, house in houses do
			local p = position(house.plan)
			for id, lead in house.leads.tokens do
				if lead.kind == "note" then
					notes += 1
					local room = house.plan.tokens[id].producer.room
					check.truthy(lead.noteRoom ~= room, "house " .. i .. ": not in the same room")
					if not house.rooms[room].nameable then
						vague += 1
					end
					local noteAt = p[house.plan.roomRegion[lead.noteRoom]]
					local tokenAt = p[house.plan.roomRegion[room]]
					check.truthy(noteAt <= tokenAt, "house " .. i .. ": the note is reachable first")
				end
			end
		end
		check.truthy(notes > 0, "some notes")
		check.truthy(vague <= notes * 0.05, string.format("%d of %d notes can't name their room alone", vague, notes))
	end)

	test("one box and one case a room at most, decoys included, and never a decoy in the dining room", function()
		for i, house in houses do
			local boxes, cases = {}, {}
			local function add(kind, room)
				local seen = kind == "keepsake" and boxes or cases
				check.truthy(not seen[room], "house " .. i .. ": two " .. kind .. "s in room " .. room)
				seen[room] = true
			end
			for id, lead in house.leads.tokens do
				if lead.kind == "keepsake" or lead.kind == "display" then
					add(lead.kind, house.plan.tokens[id].producer.room)
				end
			end
			for _, decoy in house.leads.decoys do
				add(decoy.kind, decoy.room)
				check.truthy(decoy.room ~= house.layout.deliberation, "no decoy at the dinner")
				check.truthy(house.rooms[decoy.room].tops > 0, "a decoy stands on a top")
			end
		end
	end)

	test("over many houses every kind of lead turns up, and no kind takes them all", function()
		local counts, total = {}, 0
		for _, house in houses do
			for _, lead in house.leads.tokens do
				counts[lead.kind] = (counts[lead.kind] or 0) + 1
				total += 1
			end
		end
		for _, kind in { "note", "keepsake", "display", "hook" } do
			check.truthy((counts[kind] or 0) > 0, kind .. " turns up")
			check.truthy((counts[kind] or 0) < total * 0.6, kind .. " doesn't take over")
		end
		check.equal(counts.drawer or 0, 0, "no plain drawers by default")
	end)

	test("the same plan and seed give the same leads", function()
		local house = houses[3]
		local a = Leads.plan(house.plan, house.rooms, Rng.new(9):Fork("leads"), cfg)
		local b = Leads.plan(house.plan, house.rooms, Rng.new(9):Fork("leads"), cfg)
		local function describe(leads)
			local out = {}
			for id, lead in leads.tokens do
				table.insert(out, id .. "=" .. lead.kind .. "@" .. tostring(lead.noteRoom))
			end
			for _, decoy in leads.decoys do
				table.insert(out, decoy.kind .. ":" .. decoy.room)
			end
			table.sort(out)
			return table.concat(out, ",")
		end
		check.equal(describe(a), describe(b), "deterministic")
	end)
end
