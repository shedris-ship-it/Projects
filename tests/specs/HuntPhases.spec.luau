-- A hunt in phases (Logic/HuntPhases): prowl, chase on sight, lost when he
-- loses you, back to prowling once he has looked; his pace by phase and kind.
return function(test, check, Shared, require)
	local HuntPhases = require(Shared.Logic.HuntPhases)
	local Tactics = require(Shared.Data.Tactics)
	local cfg = { ChaseGrace = 0.6, WidenAfter = 30 }

	test("he prowls, chases on sight, and is lost a moment after he loses you", function()
		local s = HuntPhases.new("prowl", 0)
		check.equal(s.phase, "prowl", "starts prowling")
		local phase, entered = HuntPhases.step(s, 1, true, cfg)
		check.equal(phase, "chase", "seen: the chase")
		check.truthy(entered, "entered now (the spotted cue)")
		phase, entered = HuntPhases.step(s, 1.2, true, cfg)
		check.equal(entered, false, "still chasing is not a new chase")
		phase = HuntPhases.step(s, 1.5, false, cfg)
		check.equal(phase, "chase", "a moment out of sight is still the chase")
		phase, entered = HuntPhases.step(s, 1.2 + cfg.ChaseGrace + 0.01, false, cfg)
		check.equal(phase, "lost", "lost you")
		check.truthy(entered, "entered now (he goes to where he saw you)")
		phase, entered = HuntPhases.step(s, 3, true, cfg)
		check.equal(phase, "chase", "seen again while lost: the chase again")
		check.equal(s.sightings, 2, "two sightings")
		HuntPhases.step(s, 5, false, cfg)
		HuntPhases.done(s, 9)
		check.equal(s.phase, "prowl", "done looking: prowling")
		check.equal(s.losses, 2, "lost twice")
	end)

	test("his pace: full in a chase, slower while prowling, slowest in a silent hunt", function()
		local prowl = HuntPhases.new("prowl", 0)
		local silent = HuntPhases.new("silent", 0)
		local sweep = HuntPhases.new("sweep", 0)
		check.truthy(HuntPhases.speed(prowl) < 1, "prowling is not running")
		check.truthy(HuntPhases.speed(silent) < HuntPhases.speed(prowl), "silent is slower")
		check.truthy(HuntPhases.speed(sweep) >= HuntPhases.speed(prowl), "a sweep moves on")
		HuntPhases.step(silent, 1, true, cfg)
		check.equal(HuntPhases.speed(silent), 1, "seen, even a silent hunt runs")
		check.equal(HuntPhases.new("nonsense", 0).kind, "prowl", "an unknown kind is a prowl")
	end)

	test("thirty seconds seeing nobody widens his options; every weight names a real tactic", function()
		local s = HuntPhases.new("sweep", 0)
		check.equal(HuntPhases.widened(s, 20, cfg), false, "not yet")
		check.truthy(HuntPhases.widened(s, 31, cfg), "half a minute of nobody")
		local w = HuntPhases.weights(s, 31, cfg)
		check.truthy(w.KillLights and w.KillLights > 1, "the lights go")
		check.truthy(w.SweepRooms and w.SweepRooms > 1, "a sweep sweeps")
		HuntPhases.step(s, 32, true, cfg)
		check.equal(HuntPhases.widened(s, 40, cfg), false, "seeing someone resets it")
		for kind, weights in HuntPhases.Tactics do
			for id, weight in weights do
				check.truthy(Tactics.ById[id], kind .. ": no tactic " .. id)
				check.truthy(weight > 0, kind .. ": weight for " .. id)
			end
			check.truthy(HuntPhases.Prowl[kind], kind .. " has a pace")
		end
		for id in HuntPhases.Widen do
			check.truthy(Tactics.ById[id], "widen: no tactic " .. id)
		end
	end)
end
