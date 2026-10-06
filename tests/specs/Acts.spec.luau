-- The run's arc (Logic/Acts): progress, not Drift, says which act it is.
return function(test, check, Shared, require)
	local Config = require(Shared.Config)
	local Acts = require(Shared.Logic.Acts)
	local P = Config.Pacing

	test("the start is act 1; a door opened or an heirloom found is act 2", function()
		local facts = { gates = 3, heirlooms = 3, places = 3 }
		check.equal(Acts.of(facts, P), 1, "nothing done")
		facts.gatesOpened = 1
		check.equal(Acts.of(facts, P), 2, "a door opened")
		check.equal(Acts.of({ gates = 3, heirlooms = 3, places = 3, heirloomsFound = 1 }, P), 2, "an heirloom found")
	end)

	test("most of the way is act 3; the dinner is act 4", function()
		local facts = { gates = 2, gatesOpened = 2, heirlooms = 2, heirloomsFound = 2, places = 2, placesSet = 1 }
		check.atLeast(Acts.progress(facts), P.Act3At, "most of the way")
		check.equal(Acts.of(facts, P), 3, "act 3")
		facts.served = true
		check.equal(Acts.of(facts, P), 4, "served")
	end)

	test("a house with nothing locked still has an arc", function()
		local facts = { gates = 0, heirlooms = 2, places = 2 }
		check.equal(Acts.of(facts, P), 1, "start")
		facts.heirloomsFound = 2
		facts.placesSet = 1
		check.equal(Acts.of(facts, P), 3, "found both and set one")
		check.equal(Acts.progress({}), 0, "an empty plan is no progress, not a crash")
	end)

	test("the dread floor only rises through the acts", function()
		local last = -1
		for act = 1, 4 do
			local floor = Acts.dread(act, P)
			check.atLeast(floor, last, "act " .. act)
			last = floor
		end
	end)
end
