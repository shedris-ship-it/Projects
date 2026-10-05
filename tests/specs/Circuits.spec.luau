-- The house's wiring (Logic/Circuits): every room on exactly one circuit,
-- the hall and dining room on their own, a believable number of breakers.
return function(test, check, Shared, require)
	local Config = require(Shared.Config)
	local Rooms = require(Shared.Data.Rooms)
	local Rng = require(Shared.Lib.Rng)
	local Circuits = require(Shared.Logic.Circuits)
	local MansionGen = require(Shared.Logic.MansionGen)

	local function roomsOf(layout)
		local list = {}
		for _, room in layout.rooms do
			local template = Rooms.MansionById[room.template]
			table.insert(list, {
				id = room.id,
				floor = room.floor or 0,
				x = (room.x or 0) + (room.w or 0) / 2,
				z = (room.z or 0) + (room.d or 0) / 2,
				name = template.name,
				corridor = template.family == "corridor",
			})
		end
		return list
	end

	test("every room is on exactly one circuit; the hall and dining room on the first", function()
		for seed = 1, 30 do
			local layout = MansionGen.generate(seed, Rooms.Mansion, Config.Mansion)
			local plan =
				Circuits.plan(roomsOf(layout), layout.start, layout.deliberation, Rng.new(seed), Config.Breaker)
			local seen = {}
			for i, circuit in plan.circuits do
				check.truthy(#circuit.rooms > 0, "seed " .. seed .. ": circuit " .. i .. " feeds something")
				check.truthy(type(circuit.label) == "string" and #circuit.label > 0, "labelled")
				for _, id in circuit.rooms do
					check.truthy(not seen[id], "seed " .. seed .. ": room " .. id .. " on one circuit")
					seen[id] = true
					check.equal(plan.roomCircuit[id], i, "the index agrees")
				end
			end
			for _, room in layout.rooms do
				check.truthy(seen[room.id], "seed " .. seed .. ": room " .. room.id .. " is wired")
			end
			check.equal(plan.roomCircuit[layout.start], 1, "the hall")
			check.equal(plan.roomCircuit[layout.deliberation], 1, "the dining room")
			local count = #plan.circuits
			check.truthy(
				count >= Config.Breaker.Count[1] and count <= Config.Breaker.Count[2],
				"seed " .. seed .. ": " .. count .. " breakers"
			)
		end
	end)

	test("a circuit stays on one floor", function()
		for seed = 1, 30 do
			local layout = MansionGen.generate(seed, Rooms.Mansion, Config.Mansion)
			local rooms = roomsOf(layout)
			local floorOf = {}
			for _, room in rooms do
				floorOf[room.id] = room.floor
			end
			local plan = Circuits.plan(rooms, layout.start, layout.deliberation, Rng.new(seed), Config.Breaker)
			local mixed = 0
			for i = 2, #plan.circuits do
				local floors = {}
				for _, id in plan.circuits[i].rooms do
					floors[floorOf[id]] = true
				end
				local n = 0
				for _ in floors do
					n += 1
				end
				if n > 1 then
					mixed += 1
				end
			end
			check.equal(mixed, 0, "seed " .. seed .. ": circuits that span floors")
		end
	end)
end
