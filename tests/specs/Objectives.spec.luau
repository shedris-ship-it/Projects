-- The escape's objective line (Logic/Objectives): built only from what the
-- squad has seen.
return function(test, check, Shared, require)
	local Objectives = require(Shared.Logic.Objectives)

	test("at the start: the table and its empty places", function()
		local line = Objectives.line({ places = 3, placesLeft = 3 })
		check.truthy(string.find(line, "three empty places", 1, true) ~= nil, line)
		check.truthy(string.find(line, "locked", 1, true) == nil, "nothing about locks nobody has tried")
	end)

	test("what's been seen is mentioned, and goes when it's dealt with", function()
		local line = Objectives.line({ places = 2, placesLeft = 1, locked = "Kitchen", computer = "Study" })
		check.truthy(string.find(line, "One place", 1, true) ~= nil, "one place left")
		check.truthy(string.find(line, "The Kitchen door is locked.", 1, true) ~= nil, "the lock tried")
		check.truthy(string.find(line, "The computer in the Study is still on.", 1, true) ~= nil, "the computer seen")
		local later = Objectives.line({ places = 2, placesLeft = 0, computer = "Study", computerSolved = true })
		check.truthy(string.find(later, "The table is set.", 1, true) ~= nil, "set")
		check.truthy(string.find(later, "computer", 1, true) == nil, "the cracked computer goes")
	end)

	test("once the dinner is served, only the way out", function()
		check.equal(
			Objectives.line({ served = true, places = 3, placesLeft = 0, locked = "Den" }),
			"The front door is open. Get out.",
			"out"
		)
	end)
end
