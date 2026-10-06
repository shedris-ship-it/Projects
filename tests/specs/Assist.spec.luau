-- Stuck-assist (Logic/Assist): the next thing the plan wants, from what the
-- squad has, one step at a time; and the sentence that says it.
return function(test, check, Shared, require)
	local Assist = require(Shared.Logic.Assist)
	local Config = require(Shared.Config)
	local LockPlanner = require(Shared.Logic.LockPlanner)
	local MansionGen = require(Shared.Logic.MansionGen)
	local Rng = require(Shared.Lib.Rng)
	local Rooms = require(Shared.Data.Rooms)

	-- A small hand-made plan: two regions, a key in room 2 for the door 2-3,
	-- a code from a computer in room 3 for the padlock 3-4, an heirloom in a
	-- drawer in room 4 and one behind a safe in room 1.
	local plan = {
		regions = { [0] = { rooms = { 1, 2 } }, [1] = { rooms = { 3 } }, [2] = { rooms = { 4 } } },
		roomRegion = { 0, 0, 1, 2 },
		order = { 1, 2 },
		locks = {
			["seam:2-3"] = { kind = "key", needs = { "key:1" }, inside = 3 },
			["seam:3-4"] = { kind = "padlock", needs = { "code:1" }, inside = 4 },
			["seam:1-5"] = { kind = "power", needs = { "power:safe" }, optional = true, vault = true, inside = 5 },
		},
		tokens = {
			["key:1"] = { kind = "key", producer = { kind = "container", room = 2 } },
			["code:1"] = { kind = "code", producer = { kind = "puzzle", id = "terminal:1" } },
			["heirloom:1"] = { kind = "bulky", producer = { kind = "container", room = 4 } },
			["heirloom:2"] = { kind = "bulky", producer = { kind = "puzzle", id = "safe:1" } },
			["power:safe"] = { kind = "power", producer = { kind = "puzzle", id = "breaker:1" } },
		},
		puzzles = {
			["terminal:1"] = { kind = "terminal", room = 3 },
			["safe:1"] = { kind = "safe", room = 1 },
			["breaker:1"] = { kind = "breaker", room = 2 },
		},
		finale = { table = 1, heirlooms = { "heirloom:1", "heirloom:2" }, cut = {} },
	}
	local seams = { ["seam:2-3"] = { a = 2, b = 3 }, ["seam:3-4"] = { a = 3, b = 4 }, ["seam:1-5"] = { a = 1, b = 5 } }

	local function state(overrides)
		local s = { reachable = { [1] = true, [2] = true }, had = {}, opened = {}, set = {}, seams = seams }
		for k, v in overrides or {} do
			s[k] = v
		end
		return s
	end

	test("at the start: look where the first key is kept, keys before heirlooms", function()
		local hint = Assist.next(plan, state())
		check.equal(hint.kind, "look", "look")
		check.equal(hint.room, 2, "in room 2")
		check.equal(hint.token, "key:1", "the key, not the safe's heirloom")
		check.truthy(
			string.find(Assist.phrase(hint, "the Study"), "still in the Study", 1, true),
			Assist.phrase(hint, "the Study")
		)
	end)

	test("holding the key: the door it opens, from the side you can reach", function()
		local hint = Assist.next(plan, state({ had = { ["key:1"] = true } }))
		check.equal(hint.kind, "door", "a door")
		check.equal(hint.seam, "seam:2-3", "the key's door")
		check.equal(hint.room, 2, "seen from room 2")
		check.truthy(string.find(Assist.phrase(hint, "the Hall"), "what opens a door in the Hall", 1, true), "phrase")
	end)

	test(
		"through the door: the computer makes the code; then its padlock; an optional lock is never the hint",
		function()
			local s = state({
				had = { ["key:1"] = true },
				opened = { ["seam:2-3"] = true },
				reachable = { [1] = true, [2] = true, [3] = true },
			})
			local hint = Assist.next(plan, s)
			check.equal(hint.kind, "puzzle", "a puzzle")
			check.equal(hint.puzzle, "terminal", "the computer")
			check.equal(hint.room, 3, "in room 3")
			check.truthy(
				string.find(Assist.phrase(hint, "the Study"), "Try the computer in the Study.", 1, true),
				"phrase"
			)
			s.had["code:1"] = true
			hint = Assist.next(plan, s)
			check.equal(hint.kind, "door", "the padlock next")
			check.equal(hint.seam, "seam:3-4", "the padlocked door")
		end
	)

	test("an heirloom in hand comes first; everything done says nothing", function()
		local s = state({
			had = { ["key:1"] = true, ["code:1"] = true, ["heirloom:1"] = true },
			opened = { ["seam:2-3"] = true, ["seam:3-4"] = true },
			reachable = { [1] = true, [2] = true, [3] = true, [4] = true },
		})
		local hint = Assist.next(plan, s)
		check.equal(hint.kind, "set", "set it")
		check.equal(hint.token, "heirloom:1", "the one in hand")
		check.truthy(string.find(Assist.phrase(hint, nil, "Mom's locket"), "Carry Mom's locket", 1, true), "phrase")
		s.set["heirloom:1"] = true
		hint = Assist.next(plan, s)
		check.equal(hint.kind, "puzzle", "then the safe")
		check.equal(hint.puzzle, "safe", "by ear")
		s.had["heirloom:2"] = true
		s.set["heirloom:2"] = true
		check.equal(Assist.next(plan, s), nil, "nothing left to say (the safe room is optional)")
	end)

	test("a real house: there is always a hint until the table is set", function()
		local layout = MansionGen.generate(61 * 13 + 5, Rooms.Mansion, Config.Mansion)
		local real = LockPlanner.plan(
			layout,
			Rooms.MansionById,
			Rng.new(61):Fork("progression"),
			Config.Progression,
			Config.Mansion
		)
		local realSeams = {}
		for _, seam in layout.seams do
			realSeams[seam.id] = { a = seam.a, b = seam.b }
		end
		-- Walk the plan as the solver would, taking each hint.
		local s = { reachable = {}, had = {}, opened = {}, set = {}, seams = realSeams }
		for _, room in real.regions[0].rooms do
			s.reachable[room] = true
		end
		-- Bolts and cranks open from their own side as the squad reaches it
		-- (the solver's rule), so a wing opened by one hint opens the next.
		local function expand()
			local changed = true
			while changed do
				changed = false
				for seamId, lock in real.locks do
					local seam = realSeams[seamId]
					if not s.opened[seamId] and seam and lock.side and not lock.needs and s.reachable[lock.side] then
						s.opened[seamId] = true
						changed = true
						for _, side in { seam.a, seam.b } do
							local region = real.regions[real.roomRegion[side]]
							for _, room in region and region.rooms or {} do
								s.reachable[room] = true
							end
						end
					end
				end
			end
		end
		expand()
		local steps = 0
		while steps < 60 do
			local hint = Assist.next(real, s)
			if not hint then
				break
			end
			steps += 1
			if hint.kind == "set" then
				s.set[hint.token] = true
			elseif hint.kind == "door" then
				s.opened[hint.seam] = true
				-- Through it: the wing on the other side opens up.
				local seam = realSeams[hint.seam]
				for _, side in { seam.a, seam.b } do
					local region = real.regions[real.roomRegion[side]]
					for _, room in region and region.rooms or {} do
						s.reachable[room] = true
					end
				end
				expand()
			else
				s.had[hint.token] = true
			end
		end
		check.truthy(steps > 0, "it had something to say")
		for _, token in real.finale.heirlooms do
			check.truthy(s.set[token], "the hints led to " .. token .. " being set")
		end
	end)
end
