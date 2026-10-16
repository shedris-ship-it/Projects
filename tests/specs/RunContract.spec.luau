-- What a lobby tells the run server it sends a squad to (Logic/RunContract):
-- made by a server, read back field by field.
return function(test, check, Shared, require)
	local RunContract = require(Shared.Logic.RunContract)
	local known = { difficulty = { Normal = true, Hard = true }, location = { HalfwayHouse = true } }

	test("a contract made is read back the same", function()
		local made = RunContract.make(
			{ 11, 22, 33 },
			{ difficulty = "Hard", location = "HalfwayHouse", night = "short" },
			1000
		)
		local read = RunContract.read(made, known)
		check.truthy(read, "reads")
		check.equal(#read.squad, 3, "the squad")
		check.equal(read.squad[2], 22, "in order")
		check.equal(read.difficulty, "Hard", "difficulty")
		check.equal(read.location, "HalfwayHouse", "location")
		check.equal(read.night, "short", "night")
		check.equal(read.made, 1000, "when")
	end)

	test("anything that isn't a contract reads as nil", function()
		check.equal(RunContract.read(nil, known), nil, "nil")
		check.equal(RunContract.read("hello", known), nil, "a string")
		check.equal(RunContract.read({ v = 99, squad = { 1 } }, known), nil, "another version")
		check.equal(RunContract.read({ v = RunContract.Version, squad = {} }, known), nil, "no squad")
		check.equal(RunContract.read({ v = RunContract.Version, squad = { "x", 1.5 } }, known), nil, "no real ids")
	end)

	test("names this build doesn't know fall back to the run's defaults", function()
		local read =
			RunContract.read({ v = RunContract.Version, squad = { 7 }, difficulty = "Nightmare", location = 5 }, known)
		check.truthy(read, "still a contract")
		check.equal(read.difficulty, nil, "unknown difficulty")
		check.equal(read.location, nil, "a location that isn't a name")
	end)

	test("a squad is bounded, and its arrivals counted", function()
		local ids = {}
		for i = 1, 20 do
			table.insert(ids, i)
		end
		local made = RunContract.make(ids, { difficulty = "Normal" }, 0)
		check.truthy(#made.squad <= 8, "made bounded")
		local read = RunContract.read({ v = RunContract.Version, squad = ids }, known)
		check.truthy(#read.squad <= 8, "read bounded")
		check.truthy(RunContract.expects(read, 3), "3 is in it")
		check.truthy(not RunContract.expects(read, 99), "99 isn't")
		check.equal(RunContract.arrived(read, { 1, 2, 99 }), 2, "two of the squad here, one stranger")
	end)

	test("the lobby a squad came from rides along, so it can go back there", function()
		local made = RunContract.make({ 1 }, { difficulty = "Normal", lobby = "job-123" }, 0)
		local read = RunContract.read(made, { difficulty = { Normal = true } })
		check.equal(read.lobby, "job-123", "the lobby's JobId")
		made.lobby = string.rep("x", 200)
		check.equal(RunContract.read(made, {}).lobby, nil, "a bad one is dropped")
	end)
end
