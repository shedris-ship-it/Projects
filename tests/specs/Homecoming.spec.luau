-- A squad coming back from its run (Logic/Homecoming; LB2): what rides in
-- the teleport's data, and what's believed of it on arrival.
return function(test, check, Shared, require)
	local Homecoming = require(Shared.Logic.Homecoming)
	local known = {
		difficulty = { Normal = true, Hard = true },
		location = { HalfwayHouse = true },
		night = { short = true, full = true },
	}

	test("a squad's car and receipts go there and back", function()
		local sent = Homecoming.make(
			"run-1",
			{ tape = "HalfwayHouse", difficulty = "Hard", night = "full" },
			{ 10, 20 },
			{ [10] = 150, [20] = 75.6 }
		)
		check.equal(sent.receipts["10"], 150, "string keys (teleport data is JSON)")
		local back = Homecoming.read(sent, known)
		check.truthy(back, "read back")
		check.equal(back.token, "run-1", "the run")
		check.equal(back.tape, "HalfwayHouse", "the tape still in the car")
		check.equal(back.difficulty, "Hard", "the dashboard as it was")
		check.equal(back.night, "full", "the night")
		check.equal(#back.squad, 2, "the squad")
		check.equal(back.receipts[20], 75, "whole Marks")
	end)

	test("what a client could have changed is checked, never trusted", function()
		check.equal(Homecoming.read(nil, known), nil, "nothing")
		check.equal(Homecoming.read({ v = 99, token = "x", squad = { 1 } }, known), nil, "another version")
		check.equal(Homecoming.read({ v = 1, token = "x", squad = {} }, known), nil, "no squad")
		local back = Homecoming.read({
			v = 1,
			token = "x",
			tape = "Elsewhere",
			difficulty = "Godlike",
			night = 3,
			squad = { 1, "two", 2.5 },
			receipts = { ["1"] = 1e12, ["9"] = 50 },
		}, known)
		check.equal(back.tape, nil, "an unknown tape")
		check.equal(back.difficulty, nil, "an unknown difficulty")
		check.equal(back.night, nil, "a bad night")
		check.equal(#back.squad, 1, "only whole user ids")
		check.equal(back.receipts[1], 100000, "a receipt is bounded")
		check.equal(back.receipts[9], nil, "only the squad's receipts")
	end)
end
