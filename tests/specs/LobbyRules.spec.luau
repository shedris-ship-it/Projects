-- The lobby's start (Logic/LobbyRules): everyone ready goes at once; half
-- the hub ready for long enough goes without the rest.
return function(test, check, Shared, require)
	local LobbyRules = require(Shared.Logic.LobbyRules)
	local cfg = { MinPlayers = 1, LobbyMajoritySeconds = 30 }

	test("everyone ready starts at once, whatever the clock", function()
		check.equal(LobbyRules.start(1, 1, nil, cfg), "all", "alone")
		check.equal(LobbyRules.start(4, 4, 0, cfg), "all", "four of four")
		check.equal(LobbyRules.start(3, 0, 100, cfg), nil, "nobody ready")
		check.equal(LobbyRules.start(0, 0, 100, cfg), nil, "an empty hub")
	end)

	test("half the hub ready for thirty seconds goes without the rest", function()
		check.equal(LobbyRules.start(4, 2, 29, cfg), nil, "two of four, too soon")
		check.equal(LobbyRules.start(4, 2, 30, cfg), "majority", "two of four, thirty seconds in")
		check.equal(LobbyRules.start(4, 1, 100, cfg), nil, "one of four is no majority")
		check.equal(LobbyRules.start(3, 2, 30, cfg), "majority", "two of three")
		check.equal(LobbyRules.start(3, 1, 30, cfg), nil, "one of three isn't")
		check.equal(LobbyRules.start(2, 1, 30, cfg), "majority", "one of two, after the wait")
		check.equal(LobbyRules.start(2, 1, nil, cfg), nil, "one of two, with no clock running")
		check.equal(LobbyRules.needed(4), 2, "two of four")
		check.equal(LobbyRules.needed(3), 2, "two of three")
	end)

	test("MinPlayers still holds", function()
		local two = { MinPlayers = 2, LobbyMajoritySeconds = 30 }
		check.equal(LobbyRules.start(1, 1, 100, two), nil, "one alone can't start a two-player contract")
		check.equal(LobbyRules.start(2, 2, 0, two), "all", "two can")
	end)
end
