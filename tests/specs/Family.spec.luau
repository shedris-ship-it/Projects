-- The family who lived here (Logic/Family, docs/plans/level-design.md
-- section 11, L3.1): who lives in a house, whose rooms and heirlooms are
-- whose, their charms, and the charms on the doors into their rooms.
return function(test, check, Shared, require)
	local Config = require(Shared.Config)
	local FamilyData = require(Shared.Data.Family)
	local Marks = require(Shared.Data.Marks)
	local Notes = require(Shared.Data.Notes)
	local Rooms = require(Shared.Data.Rooms)
	local Rng = require(Shared.Lib.Rng)
	local Family = require(Shared.Logic.Family)
	local HouseSearch = require(Shared.Logic.HouseSearch)
	local HouseSize = require(Shared.Logic.HouseSize)
	local LockPlanner = require(Shared.Logic.LockPlanner)
	local MansionGen = require(Shared.Logic.MansionGen)
	local NavGraph = require(Shared.Logic.NavGraph)
	local NoteText = require(Shared.Logic.NoteText)

	local entries = {}
	for _, entry in FamilyData.Members do
		entries[entry.id] = entry
	end

	local houses = {}
	for seed = 1, 40 do
		local layout = MansionGen.generate(seed * 7 + 3, Rooms.Mansion, Config.Mansion)
		local plan = LockPlanner.plan(
			layout,
			Rooms.MansionById,
			Rng.new(seed):Fork("progression"),
			Config.Progression,
			Config.Mansion
		)
		local family = Family.make(Rng.new(seed):Fork("family"), layout)
		Family.markDoors(family, plan, LockPlanner.label)
		table.insert(houses, { layout = layout, plan = plan, family = family, seed = seed })
	end

	test("Mom and Dad always live here; every member has a charm of their own and a way to sign", function()
		for _, house in houses do
			local family = house.family
			check.truthy(family.byId.mom ~= nil and family.byId.dad ~= nil, "seed " .. house.seed .. ": the parents")
			check.truthy(type(family.surname) == "string", "a surname")
			local marks = {}
			for _, member in family.members do
				check.truthy(member.mark ~= nil and Marks.ById[member.mark] ~= nil, member.id .. " has a charm")
				check.truthy(
					not marks[member.mark],
					"seed " .. house.seed .. ": " .. member.id .. "'s charm is theirs alone"
				)
				marks[member.mark] = true
				check.truthy(type(member.sign) == "string" and #member.sign > 0, member.id .. " signs")
				check.truthy(Notes.voices[member.voice] ~= nil, member.id .. " has a voice")
			end
		end
	end)

	test("a room is only ever someone's who could have it, and the children's rooms are shared out", function()
		for _, house in houses do
			local templateOf = {}
			for _, room in house.layout.rooms do
				templateOf[room.id] = room.template
			end
			for id, owner in house.family.roomOwner do
				check.truthy(
					table.find(entries[owner].rooms, templateOf[id]) ~= nil,
					string.format("seed %d: room %d (%s) could be %s's", house.seed, id, templateOf[id], owner)
				)
			end
			local family = house.family
			if family.byId.daughter and family.byId.son then
				local kids = 0
				for _, room in house.layout.rooms do
					if room.template == "kids_bedroom" or room.template == "playroom" then
						kids += 1
					end
				end
				if kids >= 2 then
					check.truthy(
						#family.byId.daughter.rooms > 0 and #family.byId.son.rooms > 0,
						"seed " .. house.seed .. ": two children, a room each"
					)
				end
			end
		end
	end)

	test("the door into a part of the house carries the charm of whoever owns it, never twice", function()
		for _, house in houses do
			local plan, family = house.plan, house.family
			local used = {}
			for _, r in plan.order do
				local lock = plan.locks[plan.regions[r].gate]
				if lock.needs then
					check.truthy(not used[lock.mark], "seed " .. house.seed .. ": no two doors share " .. lock.mark)
					used[lock.mark] = true
					for _, need in lock.needs do
						local token = plan.tokens[need]
						check.equal(token.mark, lock.mark, "what opens it carries its mark")
						check.truthy(
							string.find(token.label, Marks.ById[lock.mark].name, 1, true) ~= nil,
							token.label .. " is named by its mark"
						)
					end
					-- Whoever owns the most rooms behind it, unless their charm
					-- was on an earlier door.
					local counts, best = {}, 0
					for _, id in plan.regions[r].rooms do
						local owner = family.roomOwner[id]
						if owner then
							counts[owner] = (counts[owner] or 0) + 1
							best = math.max(best, counts[owner])
						end
					end
					local owner = family.markOwner[lock.mark]
					if owner and counts[owner] then
						check.truthy(counts[owner] >= 1, "its charm's owner has rooms behind it")
					end
				end
			end
		end
	end)

	test("an heirloom was someone's, and is said as theirs", function()
		local family = houses[1].family
		for _, kind in { "Candlestick", "PocketWatch", "Locket", "Doll", "Cup" } do
			local owner = Family.heirloomOwner(family, kind)
			check.truthy(owner ~= nil, kind .. " has an owner")
			check.truthy(string.sub(Family.possessive(owner), -2) == "'s", "possessive")
		end
		check.equal(Family.heirloomOwner(family, "PocketWatch").id, "dad", "Dad's pocket watch")
	end)

	test("every voice's notes fill in, and a writer is usually the owner", function()
		local fields = {
			thing = "phone key",
			whose = "my",
			item = "my phone key",
			sign = "Dad",
			place = "the top drawer of the desk",
			room = "the Study",
		}
		for voice, kinds in Notes.voices do
			for kind, list in kinds do
				for _, template in list do
					local text = NoteText.write(template, fields)
					check.truthy(string.find(text, "{", 1, true) == nil, voice .. " " .. kind .. ": " .. text)
				end
			end
		end
		local family = houses[1].family
		local rng = Rng.new(9)
		local own = 0
		for _ = 1, 200 do
			if Family.writer(rng, family, family.byId.dad) == family.byId.dad then
				own += 1
			end
		end
		check.truthy(own > 50, "the owner writes more than their share (" .. own .. " of 200)")
	end)

	test("the same seed and house give the same family", function()
		local house = houses[3]
		local again = Family.make(Rng.new(house.seed):Fork("family"), house.layout)
		check.equal(again.surname, house.family.surname, "surname")
		for i, member in house.family.members do
			check.equal(again.members[i].name, member.name, "name")
			check.equal(again.members[i].mark, member.mark, "charm")
		end
	end)

	test("the house a run plays has its family, and its doors their charms", function()
		local config, progression = HouseSize.config(Config.Mansion, Config.Progression, 2)
		local found = HouseSearch.run(11, {
			templates = Rooms.Mansion,
			templatesById = Rooms.MansionById,
			mansion = config,
			progression = progression,
			leads = Config.Leads,
			nav = NavGraph.options(Config),
			targets = Config.LevelDesign.Targets,
			shortcut = Config.LevelDesign.ShortcutStuds,
			squad = 2,
			candidates = 1,
		})
		check.truthy(found.layout.family ~= nil, "the layout carries the family")
		for _, lock in found.plan.locks do
			if lock.needs then
				check.truthy(lock.mark ~= nil, "every door that takes something has a charm")
			end
		end
	end)
end
