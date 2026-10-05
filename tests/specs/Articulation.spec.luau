-- Doors and drawers driven by the server (Logic/Articulation): they move at a
-- rate, latch when swung nearly shut, stay shut when locked, and say when they
-- become walkable.
return function(test, check, Shared, require)
	local Articulation = require(Shared.Logic.Articulation)

	local function door(value: number?)
		return Articulation.new({ max = 100, rate = 200, passAt = 55, latchAt = 3, value = value })
	end

	local function run(state, seconds: number)
		local events = {}
		for _ = 1, math.ceil(seconds * 60) do
			for _, e in Articulation.step(state, 1 / 60) do
				table.insert(events, e)
			end
		end
		return events
	end

	test("a shut door starts latched and not walkable; an ajar one is neither", function()
		local shut = door()
		check.truthy(shut.latched, "shut is latched")
		check.truthy(not Articulation.passable(shut), "shut blocks")
		local ajar = door(16)
		check.truthy(not ajar.latched, "ajar is not latched")
		check.truthy(not Articulation.passable(ajar), "ajar still blocks")
	end)

	test("it moves at its rate, no faster, and stops at the target", function()
		local d = door()
		Articulation.setTarget(d, 100)
		Articulation.step(d, 0.1)
		check.near(d.value, 20, 1e-6, "200 a second for a tenth of one")
		run(d, 2)
		check.near(d.value, 100, 1e-6, "arrived")
		check.truthy(not Articulation.moving(d), "stopped")
	end)

	test("targets are clamped to its range", function()
		local d = door()
		Articulation.setTarget(d, 400)
		check.equal(d.target, 100, "no further than max")
		Articulation.setTarget(d, -50)
		check.equal(d.target, 0, "no further than shut")
	end)

	test("opening unlatches it and makes it walkable once, with events in order", function()
		local d = door()
		Articulation.setTarget(d, 100)
		local events = run(d, 1)
		check.equal(table.concat(events, ","), "unlatch,pass", "events")
		check.truthy(Articulation.passable(d), "walkable when open")
	end)

	test("swung nearly shut, it snaps home and latches", function()
		local d = door(40)
		Articulation.setTarget(d, 2)
		local events = run(d, 1)
		check.equal(d.value, 0, "snapped shut")
		check.truthy(d.latched, "latched")
		check.equal(events[#events], "latch", "with a click")
	end)

	test("closing an open door blocks it again", function()
		local d = door(100)
		Articulation.setTarget(d, 0)
		local events = run(d, 1)
		check.equal(table.concat(events, ","), "block,latch", "events")
	end)

	test("held part open it stays put and doesn't latch", function()
		local d = door(80)
		Articulation.setTarget(d, 30)
		run(d, 1)
		check.near(d.value, 30, 1e-6, "where it was left")
		check.truthy(not d.latched, "not latched")
		check.truthy(not Articulation.passable(d), "30 degrees still blocks")
	end)

	test("a locked door never opens: asking rattles it", function()
		local d = door()
		check.truthy(Articulation.setLocked(d, true), "locked")
		check.truthy(not Articulation.setTarget(d, 100), "rattles")
		run(d, 1)
		check.equal(d.value, 0, "still shut")
		check.truthy(Articulation.setLocked(d, false), "unlocked")
		check.truthy(Articulation.setTarget(d, 100), "opens now")
	end)

	test("only a shut, latched door can be locked", function()
		local d = door(30)
		check.truthy(not Articulation.setLocked(d, true), "can't lock it ajar")
		check.truthy(not d.locked, "not locked")
	end)

	test("a faster rate can be given for one step (a slam)", function()
		local d = door(100)
		Articulation.setTarget(d, 0)
		Articulation.step(d, 0.1, 600)
		check.near(d.value, 40, 1e-6, "600 a second")
	end)
end
