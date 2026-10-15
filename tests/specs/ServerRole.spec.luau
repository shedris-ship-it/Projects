-- Which job a server does (Logic/ServerRole): a public server is a lobby, a
-- reserved server a run, a paid private server a lobby, Studio both.
return function(test, check, Shared, require)
	local ServerRole = require(Shared.Logic.ServerRole)

	local function live(privateServerId, ownerId)
		return { studio = false, enabled = true, privateServerId = privateServerId, privateServerOwnerId = ownerId }
	end

	test("a public server is a lobby, a reserved one a run", function()
		check.equal(ServerRole.of(live("", 0)), "lobby", "public")
		check.equal(ServerRole.of(live("a1b2", 0)), "run", "reserved: a private server nobody paid for")
		check.equal(ServerRole.of(live("a1b2", 12345)), "lobby", "a paid private server is its owner's lobby")
	end)

	test("Studio is both unless a test asks for a role", function()
		check.equal(
			ServerRole.of({ studio = true, enabled = true, privateServerId = "", privateServerOwnerId = 0 }),
			"both"
		)
		check.equal(ServerRole.of({ studio = true, enabled = true, forced = "run" }), "run", "forced run")
		check.equal(ServerRole.of({ studio = true, enabled = true, forced = "lobby" }), "lobby", "forced lobby")
		check.equal(ServerRole.of({ studio = true, enabled = true, forced = "nonsense" }), "both", "an unknown role")
	end)

	test("the switch off puts runs back in the lobby's own server", function()
		check.equal(
			ServerRole.of({ studio = false, enabled = false, privateServerId = "", privateServerOwnerId = 0 }),
			"both"
		)
		check.truthy(ServerRole.startsRunsHere("both"), "both starts its own runs")
		check.truthy(not ServerRole.startsRunsHere("lobby"), "a lobby sends squads off")
		check.truthy(not ServerRole.startsRunsHere("run"), "a run server waits for its contract")
	end)

	test("a missing field reads as a public server", function()
		check.equal(ServerRole.of({ studio = false, enabled = true }), "lobby")
	end)
end
