-- Players collide, but nobody can body-block a doorway (Logic/Bodies; the
-- squad playtest, 2026-10-08).
return function(test, check, Shared, require)
	local roblox = require("@lune/roblox")
	local Vector3 = roblox.Vector3
	local Bodies = require(Shared.Logic.Bodies)
	local Config = require(Shared.Config)
	local B = Config.Bodies

	local function run(state, bodies, seconds)
		local ghosts
		for _ = 1, math.floor(seconds / 0.1 + 0.5) do
			ghosts = Bodies.step(state, bodies, 0.1, B)
		end
		return ghosts or {}
	end

	test("two players apart are both solid", function()
		local state = Bodies.new()
		local ghosts = run(state, {
			a = { position = Vector3.new(0, 3, 0) },
			b = { position = Vector3.new(10, 3, 0) },
		}, 3)
		check.equal(next(ghosts), nil, "no ghosts")
	end)

	test("a bump is solid; pressed together a moment, they give way", function()
		local state = Bodies.new()
		local bodies = {
			a = { position = Vector3.new(0, 3, 0) },
			b = { position = Vector3.new(2, 3, 0) },
		}
		local ghosts = run(state, bodies, B.ContactSeconds * 0.5)
		check.equal(next(ghosts), nil, "a bump: still solid")
		ghosts = run(state, bodies, B.ContactSeconds)
		check.truthy(ghosts.a and ghosts.b, "a blocked doorway gives way")
	end)

	test("a ghost turns solid again only once clear of everyone", function()
		local state = Bodies.new()
		local bodies = {
			a = { position = Vector3.new(0, 3, 0) },
			b = { position = Vector3.new(1, 3, 0) },
		}
		run(state, bodies, B.ContactSeconds + 0.2)
		-- Still inside each other after the ghost time: stays a ghost.
		local ghosts = run(state, bodies, B.GhostSeconds + 0.5)
		check.truthy(ghosts.a and ghosts.b, "never solid inside a friend")
		bodies.b.position = Vector3.new(B.ClearRadius + 1, 3, 0)
		ghosts = run(state, bodies, B.GhostSeconds + 0.5)
		check.equal(next(ghosts), nil, "apart: solid again")
	end)

	test("the downed and the hidden are never solid; another floor never touches", function()
		local state = Bodies.new()
		local ghosts = run(state, {
			a = { position = Vector3.new(0, 3, 0), always = true },
			b = { position = Vector3.new(30, 3, 0) },
		}, 0.5)
		check.truthy(ghosts.a, "downed: a ghost")
		check.equal(ghosts.b, nil, "the other is solid")
		local upstairs = Bodies.new()
		ghosts = run(upstairs, {
			a = { position = Vector3.new(0, 3, 0) },
			b = { position = Vector3.new(0.5, 13, 0) },
		}, 3)
		check.equal(next(ghosts), nil, "one above the other: no contact")
	end)

	test("someone who leaves is forgotten", function()
		local state = Bodies.new()
		local bodies = {
			a = { position = Vector3.new(0, 3, 0) },
			b = { position = Vector3.new(1, 3, 0) },
		}
		run(state, bodies, B.ContactSeconds + 0.2)
		bodies.b = nil
		local ghosts = run(state, bodies, B.GhostSeconds + 0.2)
		check.equal(ghosts.a, nil, "alone again: solid")
		check.equal(state.ghostUntil.b, nil, "b dropped")
	end)
end
