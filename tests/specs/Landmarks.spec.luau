-- Landmarks (Logic/Landmarks, docs/plans/level-design.md section 4, L3.6):
-- every corridor of a mansion gets one, all different while there are kinds
-- to go round, the same for the same house, never on a stair or a passage;
-- and they're their corridors' landmarks in Logic/RoomPurpose.
return function(test, check, Shared, require)
	local Config = require(Shared.Config)
	local Kinds = require(Shared.Data.Landmarks)
	local Rooms = require(Shared.Data.Rooms)
	local Landmarks = require(Shared.Logic.Landmarks)
	local MansionGen = require(Shared.Logic.MansionGen)
	local RoomPurpose = require(Shared.Logic.RoomPurpose)

	local templates = Rooms.MansionById

	test("every corridor gets one, different while kinds last, the same for the same house", function()
		local total = 0
		for seed = 1, 20 do
			local layout = MansionGen.generate(seed * 29, Rooms.Mansion, Config.Mansion)
			local plan = Landmarks.plan(layout, templates)
			local again = Landmarks.plan(layout, templates)
			local byRoom, used = {}, {}
			for i, entry in plan do
				check.equal(again[i].kind.id, entry.kind.id, "seed " .. seed .. ": the same again")
				byRoom[entry.room] = entry.kind.id
				used[entry.kind.id] = (used[entry.kind.id] or 0) + 1
				total += 1
			end
			for _, room in layout.rooms do
				local template = templates[room.template]
				local corridor = room.corridor or (template and template.family == "corridor")
				local wanted = corridor and room.kind ~= "stair" and room.kind ~= "passage" and not room.tall
				check.equal(byRoom[room.id] ~= nil, wanted == true, "seed " .. seed .. ": room " .. room.id)
			end
			if #plan <= #Kinds then
				for id, n in used do
					check.equal(n, 1, "seed " .. seed .. ": " .. id .. " once")
				end
			end
			local purposes = RoomPurpose.base(layout, templates)
			for _, entry in plan do
				check.truthy(purposes[entry.room].landmark, "seed " .. seed .. ": a landmark in RoomPurpose")
			end
		end
		check.truthy(total > 20, "corridors turn up (" .. total .. ")")
		check.equal(#Landmarks.plan({ mode = "Cells", rooms = {} }, templates), 0, "the old house has none")
	end)
end
