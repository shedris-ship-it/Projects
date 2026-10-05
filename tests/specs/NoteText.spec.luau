-- The family's notes (Logic/NoteText, Data/Notes): every template fills in
-- completely, every drawer is named the way a person would, and a room is
-- never named ambiguously.
return function(test, check, Shared, require)
	local Config = require(Shared.Config)
	local Notes = require(Shared.Data.Notes)
	local Rooms = require(Shared.Data.Rooms)
	local Rng = require(Shared.Lib.Rng)
	local MansionGen = require(Shared.Logic.MansionGen)
	local NoteText = require(Shared.Logic.NoteText)

	test("every template fills in with nothing left over, and stays mild", function()
		local banned = { "blood", "kill", "dead", "murder", "corpse", "suicide" }
		local fields = {
			item = "pocket watch",
			thing = "pocket watch",
			whose = "Dad's",
			sign = "Mom",
			place = "the chest",
			room = "the Den",
		}
		local lists = { key = Notes.key, heirloom = Notes.heirloom }
		-- The family's own voices too (Data/Family, docs/plans/level-design.md 11).
		for voice, kinds in Notes.voices do
			for kind, list in kinds do
				lists[voice .. " " .. kind] = list
			end
		end
		for kind, list in lists do
			for _, template in list do
				local text = NoteText.write(template, fields)
				check.truthy(not string.find(text, "{", 1, true), kind .. ": " .. text)
				check.truthy(string.find(text, "pocket watch", 1, true) or string.find(text, "Pocket watch", 1, true))
				check.truthy(string.find(text, "the chest", 1, true) ~= nil, "says where")
				check.truthy(string.find(text, "the Den", 1, true) ~= nil, "says which room")
				local lower = string.lower(text)
				for _, word in banned do
					check.truthy(not string.find(lower, word, 1, true), "no '" .. word .. "'")
				end
			end
		end
	end)

	test("{Item} gets a capital, {item} keeps its own", function()
		check.equal(NoteText.write("{Item}: {item}", { item = "study key" }), "Study key: study key")
	end)

	test("drawers are named top to bottom, cupboards and the rest plainly", function()
		check.equal(NoteText.place("Dresser", "Drawer3"), "the top drawer of the dresser")
		check.equal(NoteText.place("Dresser", "Drawer2"), "the middle drawer of the dresser")
		check.equal(NoteText.place("Dresser", "Drawer1"), "the bottom drawer of the dresser")
		check.equal(NoteText.place("Desk", "Drawer2"), "the top drawer of the desk")
		check.equal(NoteText.place("Desk", "Drawer1"), "the bottom drawer of the desk")
		check.equal(NoteText.place("Wardrobe", "Main"), "the wardrobe")
		check.equal(NoteText.place("Counter", "Door2"), "a cupboard under the counter")
		check.equal(NoteText.place("Fridge", "Freezer"), "the freezer")
		check.equal(NoteText.place("Fridge", "Fridge"), "the fridge")
		check.equal(NoteText.place("Chest", "Main"), "the chest")
	end)

	test("a room's name in a note picks out one room only", function()
		local checked = 0
		for seed = 1, 40 do
			local layout = MansionGen.generate(seed, Rooms.Mansion, Config.Mansion)
			local rooms = NoteText.rooms(layout, Rooms.MansionById)
			local phrases = {}
			for id in rooms do
				local phrase = NoteText.roomPhrase(rooms, id)
				phrases[phrase] = (phrases[phrase] or 0) + 1
			end
			for id in rooms do
				-- A phrase that says it's unique is; the rest (two guest rooms
				-- off one bedroom) are never named in a note (Logic/Leads).
				local phrase, unique = NoteText.roomPhrase(rooms, id)
				if unique then
					checked += 1
					check.equal(phrases[phrase], 1, "seed " .. seed .. ": '" .. phrase .. "' is one room")
				end
			end
		end
		check.truthy(checked > 100, "checked many rooms")
	end)

	test("templates aren't repeated in a run while there are fresh ones", function()
		local used = {}
		local seen = {}
		local rng = Rng.new(5)
		for _ = 1, #Notes.key do
			local template = NoteText.pick(rng, "key", used)
			check.truthy(not seen[template], "fresh")
			seen[template] = true
		end
		check.truthy(NoteText.pick(rng, "key", used) ~= nil, "then repeats rather than failing")
	end)
end
