-- The three cutscenes' shots (Logic/Cutscene; the visual rework V8): each
-- covers its length with no gap, stands where it should (outside, then
-- inside; at the table; on the drive), and fits the game's timing.
return function(test, check, Shared, require)
	local Cutscene = require(Shared.Logic.Cutscene)
	local Config = require(Shared.Config)

	local function scenes()
		local door = { 10, 4, 0 }
		return {
			Cutscene.arrival({ door = door, floor = 0, outward = { 1, 0 }, hall = { -10, 0, 0 } }),
			Cutscene.dinner({ centre = { 0, 0, 0 }, head = { 0, 0, 7.5 } }),
			Cutscene.escape({ door = door, floor = 0, outward = { 1, 0 } }),
		}
	end

	test("every cutscene's shots cover it end to end, 3-6 s, the camera always somewhere", function()
		for _, scene in scenes() do
			check.truthy(scene.length >= 3 and scene.length <= 6, scene.kind .. " is short")
			check.equal(scene.shots[1].t[1], 0, scene.kind .. " starts at once")
			check.near(scene.shots[#scene.shots].t[2], scene.length, 1e-9, scene.kind .. " shots run to its end")
			for i = 2, #scene.shots do
				check.near(scene.shots[i].t[1], scene.shots[i - 1].t[2], 1e-9, scene.kind .. " no gap between shots")
			end
			for t = 0, scene.length, 0.1 do
				local at, look, fov = Cutscene.camera(scene, t)
				for k = 1, 3 do
					check.truthy(at[k] == at[k] and look[k] == look[k], scene.kind .. " a number")
				end
				local d = math.sqrt((at[1] - look[1]) ^ 2 + (at[2] - look[2]) ^ 2 + (at[3] - look[3]) ^ 2)
				check.atLeast(d, 0.5, scene.kind .. " the camera isn't on what it films")
				check.truthy(fov >= 40 and fov <= 70, scene.kind .. " a lens")
			end
			local last = -1
			for _, beat in scene.beats do
				check.atLeast(beat.t, last, scene.kind .. " beats in order")
				check.atMost(beat.t, scene.length, scene.kind .. " beats inside it")
				last = beat.t
			end
		end
	end)

	test("the arrival: from outside the front door, then the lock, then high over the hall", function()
		local scene = scenes()[1]
		local outside = Cutscene.camera(scene, 0.5)
		check.atLeast(outside[1] - 10, 5, "on the drive, out of the house")
		local lock = Cutscene.camera(scene, 2.5)
		check.atMost(lock[1] - 10, 0, "inside, at the lock")
		local hall = Cutscene.camera(scene, 4)
		check.atMost(hall[1] - 10, 0, "inside")
		check.atLeast(hall[2], 6, "high over the squad")
		check.equal(Cutscene.black(scene, 0), 1, "out of the dark")
		check.equal(Cutscene.black(scene, 2), 0, "then clear")
		check.truthy(scene.beats[1].door ~= nil, "the door swings shut first")
	end)

	test("the dinner ends before the final hunt is called, on him at the head", function()
		local scene = scenes()[2]
		-- (FinaleService:Serve opens the house and calls the hunt at 3.4 s.)
		check.atMost(scene.length, 3.4, "over before the hunt")
		local _, look = Cutscene.camera(scene, 2.5)
		check.atMost(math.abs(look[3] - 7.5), 0.01, "on his place")
		check.atLeast(look[2], 4.5, "at his face, seated")
	end)

	test("a blocked camera's other places: its own first, then the far side, then higher", function()
		local scene = scenes()[3]
		local shot = scene.shots[1]
		local list = Cutscene.variants(scene, shot)
		check.equal(#list, 4, "four places to try")
		check.equal(list[1].from, shot.from.at, "its own first")
		-- (Out along +x, the far side is the other sign of z, the same distance off.)
		check.near(list[2].from[3], -shot.from.at[3], 1e-9, "mirrored across the way out")
		check.near(list[2].from[1], shot.from.at[1], 1e-9, "as far out")
		check.near(list[3].from[2], shot.from.at[2] + 1.6, 1e-9, "higher")
	end)

	test("the last shot lasts as long as the server keeps you, and ends in the dark", function()
		local scene = scenes()[3]
		check.near(scene.length, Config.Cinema.EscapeSeconds, 1e-9, "as long as the wait before the hub")
		check.atLeast(scene.run[1] - 10, 10, "you run out past the lens")
		check.equal(Cutscene.black(scene, 3.5), 1, "black")
		local at = Cutscene.camera(scene, 1)
		check.atLeast(at[1] - 10, 10, "the lens out on the drive")
	end)
end
