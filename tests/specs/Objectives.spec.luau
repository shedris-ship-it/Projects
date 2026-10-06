-- The escape's objective line (Logic/Objectives): built only from what the
-- squad has seen.
return function(test, check, Shared, require)
	local Objectives = require(Shared.Logic.Objectives)

	local function has(line: string, text: string): boolean
		return string.find(line, text, 1, true) ~= nil
	end

	test("at the start: the table and its empty places", function()
		local line = Objectives.line({ places = 3, placesLeft = 3 })
		check.truthy(has(line, "three empty places"), line)
		check.truthy(not has(line, "locked"), "nothing about locks nobody has tried")
	end)

	test("what's been seen is mentioned, and goes when it's dealt with", function()
		local computer = { kind = "terminal", room = "Study" }
		local doors = { { mark = "star", kind = "key", place = "the Upper Hall" } }
		local line = Objectives.line({ places = 2, placesLeft = 1, doors = doors, stations = { computer } })
		check.truthy(has(line, "One place"), "one place left")
		check.truthy(has(line, "The star door in the Upper Hall is locked."), line)
		check.truthy(has(line, "The computer in the Study is still on."), "the computer seen")
		computer.solved = true
		local later = Objectives.line({ places = 2, placesLeft = 0, stations = { computer } })
		check.truthy(has(later, "The table is set."), "set")
		check.truthy(not has(later, "computer"), "the cracked computer goes")
	end)

	test("of the stations seen, the newest one still to deal with is mentioned, one at a time", function()
		local stations = {
			{ kind = "terminal", room = "Study" },
			{ kind = "display", room = "Den" },
		}
		local line = Objectives.line({ places = 2, placesLeft = 2, stations = stations })
		check.truthy(has(line, "glass case in the Den"), "the newest")
		check.truthy(not has(line, "computer"), "one at a time")
		stations[2].solved = true
		line = Objectives.line({ places = 2, placesLeft = 2, stations = stations })
		check.truthy(has(line, "The computer in the Study"), "then the one before")
		for kind, say in Objectives.Stations do
			check.truthy(#say("Den") > 0, kind .. " has a line")
		end
	end)

	-- docs/plans/level-design.md section 11: a playtest held the right key and
	-- stood at the wrong door, the line naming only the last door tried.
	test("a key someone holds comes first: where its door is, or that nobody has found it", function()
		local doors = { { mark = "star", kind = "key", place = "the Upper Hall" } }
		local unseen = Objectives.line({ places = 2, placesLeft = 2, doors = doors, keys = { { mark = "phone" } } })
		check.truthy(has(unseen, "Somewhere there's a door with a phone on it."), unseen)
		check.truthy(not has(unseen, "star door"), "one sentence about locks")
		local seen = Objectives.line({
			places = 2,
			placesLeft = 2,
			doors = doors,
			keys = { { mark = "phone", place = "the Back Stairs, on the ground floor" } },
		})
		check.truthy(has(seen, "The phone key fits the door in the Back Stairs, on the ground floor."), seen)
	end)

	test("each kind of lock says what it wants, by its mark", function()
		local function door(kind: string, mark: string?)
			return Objectives.lockLine({ doors = { { mark = mark, kind = kind, place = "the Study" } } })
		end
		check.equal(door("key", "sun"), "The sun door in the Study is locked.", "a key")
		check.equal(door("double", "sun"), "The sun door in the Study is locked. It needs two keys.", "two")
		check.equal(door("padlock", "note"), "The note door in the Study has a padlock.", "a padlock")
		check.equal(door("power", "umbrella"), "The umbrella door in the Study has no power.", "power")
		check.equal(door("key"), "The door in the Study is locked.", "no mark")
		local two = Objectives.lockLine({ keys = { { mark = "heart", place = "the Den", two = true } } })
		check.equal(two, "The heart key fits the door in the Den. It needs two keys.", "a double lock's key")
		check.truthy(Objectives.lockLine({}) == nil, "nothing tried, nothing held")
		check.equal(
			Objectives.lockLine({ keys = { { mark = "scissors" } } }),
			"Somewhere there's a door with scissors on it.",
			"a mark said as it should be"
		)
		check.equal(
			Objectives.lockLine({ keys = { { mark = "umbrella" } } }),
			"Somewhere there's a door with an umbrella on it.",
			"an umbrella"
		)
		-- A tool someone carries: a door it works, or a step's chest (L3.4).
		check.equal(
			Objectives.lockLine({ tools = { { name = "crowbar", kind = "boards", place = "the Den" } } }),
			"The crowbar could pry the boards off the door in the Den.",
			"a boarded door"
		)
		check.equal(
			Objectives.lockLine({
				tools = { { name = "bolt cutters", kind = "chain", place = "the Nursery", thing = "chest" } },
			}),
			"The bolt cutters could cut the chain on the chest in the Nursery.",
			"a chained chest"
		)
		check.truthy(
			Objectives.lockLine({ tools = { { name = "crowbar", kind = "boards" } } }) == nil,
			"a tool with nothing seen to use it on says nothing"
		)
	end)

	test("once the dinner is served, only the way out", function()
		check.equal(
			Objectives.line({
				served = true,
				places = 3,
				placesLeft = 0,
				doors = { { mark = "star", kind = "key", place = "the Den" } },
			}),
			"The front door is open. Get out.",
			"out"
		)
	end)
end
