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

	-- A flat offset turned the way CFrame.Angles(0, a, 0) turns it.
	local function turned(v, degrees: number)
		local a = math.rad(degrees)
		return { x = v.x * math.cos(a) + v.z * math.sin(a), z = -v.x * math.sin(a) + v.z * math.cos(a) }
	end

	test("flat angles turn the way CFrame.Angles does", function()
		check.near(Articulation.flatAngle({ x = 1, z = 0 }, { x = 0, z = -1 }), 90, 1e-9, "a quarter turn")
		local shut = { x = -3, z = 0 }
		for _, degrees in { -60, 0, 25, 90, 150 } do
			check.near(Articulation.flatAngle(shut, turned(shut, degrees)), degrees, 1e-6, "turned " .. degrees)
		end
	end)

	test("dragging: the door turns to follow your hand, within its range", function()
		local d = door()
		local grab = { x = -3, z = 0 } -- the point you took hold of, with the door shut
		check.near(Articulation.hingeTarget(d, grab, turned({ x = -4, z = 0 }, 45)), 45, 1e-6, "follows the hand")
		check.equal(Articulation.hingeTarget(d, grab, turned(grab, -30)), 0, "can't go past shut")
		check.equal(Articulation.hingeTarget(d, grab, turned(grab, 140)), 100, "or past fully open")
	end)

	test("a door that opens the other way (a cupboard's left door) follows the hand too", function()
		local d = door()
		local grab = { x = 2, z = 0 }
		check.near(Articulation.hingeTarget(d, grab, turned(grab, -70), -1), 70, 1e-6, "turning the other way opens it")
		check.equal(Articulation.hingeTarget(d, grab, turned(grab, 30), -1), 0, "turning its way shuts it")
	end)

	test("drawers and lids follow how far your hand has moved since you took hold", function()
		local drawer = Articulation.new({ max = 1.7, rate = 6, latchAt = 0.06 })
		check.near(Articulation.alongTarget(drawer, 0, 0.8), 0.8, 1e-9, "pulled out")
		check.near(Articulation.alongTarget(drawer, 1, -0.4), 0.6, 1e-9, "pushed part way back")
		check.equal(Articulation.alongTarget(drawer, 0.5, 4), 1.7, "no further than it goes")
		check.equal(Articulation.alongTarget(drawer, 0.5, -4), 0, "or further in than shut")
	end)

	test("a body in the swing stops the door just short of it", function()
		local shut = { x = -6, z = 0 }
		local body = turned({ x = -3, z = 0 }, 60)
		local stop = Articulation.sweepStop(shut, body, 6, 1, 0, 100)
		check.near(stop, 60 - math.deg(math.asin(1 / 3)), 1e-6, "at the near edge")
		check.equal(Articulation.sweepStop(shut, body, 6, 1, 0, 30), nil, "a short swing misses")
		check.equal(Articulation.sweepStop(shut, turned({ x = -10, z = 0 }, 60), 6, 1, 0, 100), nil, "out of reach")
		check.equal(Articulation.sweepStop(shut, turned({ x = -3, z = 0 }, -40), 6, 1, 0, 100), nil, "behind the door")
		local closing = Articulation.sweepStop(shut, body, 6, 1, 100, 0)
		check.near(closing, 60 + math.deg(math.asin(1 / 3)), 1e-6, "swinging shut, it stops on the other side")
	end)

	-- Momentum (R2c, the physics feel pass).
	local function swinging(value: number?)
		return Articulation.new({
			max = 100,
			rate = 285,
			passAt = 55,
			passHysteresis = 10,
			latchAt = 3,
			value = value,
			friction = 260,
			restitution = 0.25,
			slamSpeed = 160,
			knockSpeed = 120,
			stopSpeed = 8,
		})
	end

	test("let go mid-swing, a door keeps going and slows to a stop", function()
		local d = swinging(30)
		Articulation.release(d, 150)
		run(d, 0.2)
		check.truthy(d.value > 50, "still swinging after you let go")
		run(d, 3)
		check.truthy(not Articulation.moving(d), "friction stops it")
		check.truthy(d.value > 60 and d.value <= 100, "where its momentum took it")
	end)

	test("flung hard, it bounces off the open stop with a knock", function()
		local d = swinging(60)
		Articulation.release(d, 280)
		local events = run(d, 1)
		check.truthy(table.find(events, "knock") ~= nil, "knocks against the stop")
		check.truthy(d.value < 100, "bounced back a little")
	end)

	test("flung shut it slams; eased shut it only clicks", function()
		local fast = swinging(80)
		Articulation.release(fast, -280)
		local events = run(fast, 1)
		check.truthy(table.find(events, "slam") ~= nil, "a slam")
		check.truthy(fast.latched, "shut")
		local slow = swinging(8)
		Articulation.release(slow, -60)
		events = run(slow, 1)
		check.truthy(table.find(events, "slam") == nil, "no slam when eased")
		check.truthy(table.find(events, "latch") ~= nil and slow.latched, "a click")
	end)

	test("a gentle push leaves it ajar", function()
		local d = swinging(20)
		Articulation.release(d, -40)
		run(d, 2)
		check.truthy(not d.latched and d.value > 3, "stopped short of shut")
	end)

	test("held, it follows your hand with weight, never faster than its rate", function()
		local d = swinging(0)
		Articulation.hold(d)
		Articulation.setTarget(d, 90)
		Articulation.step(d, 0.05)
		check.truthy(d.value > 0 and d.value < 90, "on its way, not there at once")
		check.atMost(math.abs(d.velocity), 285 + 1e-6, "no faster than its rate")
		run(d, 1)
		check.near(d.value, 90, 1, "arrives where the hand is")
	end)

	test("walkable from 55, and stays walkable until it falls below 45", function()
		local d = swinging(60)
		check.truthy(Articulation.passable(d), "open")
		Articulation.setTarget(d, 50)
		run(d, 1)
		check.truthy(Articulation.passable(d), "50 is still walkable: no flicker")
		Articulation.setTarget(d, 40)
		local events = run(d, 1)
		check.truthy(not Articulation.passable(d), "below 45 it blocks")
		check.equal(events[#events], "block", "once")
	end)

	test("a locked door can't be flung open", function()
		local d = swinging(0)
		Articulation.setLocked(d, true)
		Articulation.release(d, 250)
		run(d, 1)
		check.equal(d.value, 0, "still shut")
	end)

	test("stopping it dead (a body in the way) holds it there", function()
		local d = swinging(30)
		Articulation.release(d, 200)
		Articulation.step(d, 0.05)
		Articulation.stop(d, 38)
		run(d, 1)
		check.near(d.value, 38, 1e-6, "stays where it hit")
	end)

	test("a faster rate can be given for one step (a slam)", function()
		local d = door(100)
		Articulation.setTarget(d, 0)
		Articulation.step(d, 0.1, 600)
		check.near(d.value, 40, 1e-6, "600 a second")
	end)
end
