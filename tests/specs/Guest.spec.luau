return function(test, check, Shared, require)
	local GuestPose = require(Shared.Logic.GuestPose)
	local Rig = GuestPose.Rig

	local function seeded()
		local x = 12345
		return function()
			x = (x * 1103515245 + 12345) % 2147483648
			return x / 2147483648
		end
	end

	test("rig: legs reach the floor, 8.4 studs tall, fingertips below the knees", function()
		check.near(Rig.hipY - Rig.upperLeg - Rig.lowerLeg, Rig.ankleY, 1e-9, "ankle height")
		check.near(Rig.rootY - Rig.rootSize[2] / 2, Rig.hipHeight, 1e-9, "HipHeight is the root's bottom")
		local top = Rig.headY + Rig.headSize[2] / 2
		check.near(top, 8.4, 0.05, "height")
		local fingertips = Rig.shoulderY - Rig.upperArm - Rig.lowerArm - Rig.hand - Rig.finger[1] - Rig.finger[2]
		local knee = Rig.hipY - Rig.upperLeg
		check.atMost(fingertips, knee, "arms reach past the knees")
		check.atLeast(top, 8.05, "taller than the 8-stud doorways")
	end)

	test("gait: the phase advances with distance and both feet land", function()
		local state = GuestPose.new()
		local landed = { Left = 0, Right = 0 }
		-- Walk 20 studs at 8 studs/s.
		for _ = 1, 150 do
			local _, planted = GuestPose.step(state, { pose = "Walk", forward = 8 }, 1 / 60)
			for _, foot in planted do
				landed[foot] += 1
			end
		end
		local stride = GuestPose.Gait.Walk.stride
		local steps = landed.Left + landed.Right
		check.near(steps, 20 / stride, 1.01, "about one step per stride length")
		check.atMost(math.abs(landed.Left - landed.Right), 1, "feet alternate")
	end)

	test("walking backwards runs the gait backwards", function()
		local state = GuestPose.new()
		state.phase = 0.5
		GuestPose.step(state, { pose = "BackAway", forward = -3 }, 0.1)
		check.truthy(state.phase < 0.5, "phase goes down when moving backwards")
		local planted = GuestPose.advance(state, "BackAway", -3, 2)
		check.atLeast(#planted, 1, "feet still land walking backwards")
	end)

	test("standing still never lands a foot", function()
		local state = GuestPose.new()
		local _, planted = GuestPose.step(state, { pose = "Walk", forward = 0 }, 1)
		check.equal(#planted, 0, "no steps when not moving")
	end)

	test("head holds its target beyond human range, the waist helps a little", function()
		-- Someone right behind him: 170 degrees round.
		local yaw = math.rad(170)
		local t = GuestPose.target({ pose = "BackAway", phase = 0, breath = 0, gazeYaw = yaw, neckYawMax = 160 })
		local neck, waist = t.Neck[2], t.Waist[2]
		check.atLeast(neck, math.rad(120), "the neck turns far past a person's ~80 degrees")
		check.atMost(neck, math.rad(160) + 1e-9, "but stops at the configured limit")
		check.atMost(math.abs(waist), math.rad(28) + 1e-9, "the waist turns only a little")
		check.near(neck + waist, yaw, math.rad(1), "together they reach the target")
	end)

	test("gaze angles: straight ahead, left, above", function()
		local yaw, pitch = GuestPose.gazeAngles(0, 0, -10)
		check.near(yaw, 0, 1e-9, "ahead")
		check.near(pitch, 0, 1e-9, "level")
		yaw = GuestPose.gazeAngles(-10, 0, 0)
		check.near(yaw, math.pi / 2, 1e-9, "to his left is positive")
		local _, up = GuestPose.gazeAngles(0, 5, -5)
		check.near(up, math.pi / 4, 1e-9, "up is positive pitch")
	end)

	test("stoops under door frames, not in the middle of a room", function()
		check.equal(GuestPose.stoop(0, 0, 40, 3), 0, "room centre")
		check.equal(GuestPose.stoop(10, 10, 40, 3), 0, "open floor")
		check.near(GuestPose.stoop(20, 0, 40, 3), 1, 1e-9, "right under an east doorway")
		check.near(GuestPose.stoop(0, -20, 40, 3), 1, 1e-9, "under a north doorway")
		check.equal(GuestPose.stoop(19, 12, 40, 3), 0, "by a wall but away from its doorway")
		check.truthy(GuestPose.stoop(18.5, 1, 40, 3) > 0.3, "ducks on the approach")
	end)

	test("joints stay within limits in every pose", function()
		local random = seeded()
		for pose in GuestPose.Poses do
			local state = GuestPose.new()
			for i = 1, 240 do
				local values = GuestPose.step(state, {
					pose = pose,
					forward = (pose == "BackAway") and -3 or 4,
					lean = (i % 2 == 0) and 1 or -1,
					stoop = (i % 3) / 2,
					gazeYaw = math.rad(-170 + i),
					gazePitch = math.rad(30),
					neckYawMax = 160,
					random = random,
					form = i % 3,
					heldFor = i / 10,
				}, 1 / 30)
				for joint, value in values do
					for axis = 1, 3 do
						local limit = joint == "Neck" and math.rad(185) or math.rad(150)
						check.atMost(math.abs(value[axis]), limit, pose .. " " .. joint .. " axis " .. axis)
					end
					for axis = 4, 6 do
						-- (On all fours his whole body drops and shifts back.)
						local most = (pose == "Crawl" and joint == "Root") and 2 or 1.2
						check.atMost(math.abs(value[axis]), most, pose .. " " .. joint .. " offset")
					end
				end
			end
		end
	end)

	test("at Breaking his knees bend the wrong way and his neck draws out", function()
		local calm = GuestPose.target({ pose = "Walk", phase = 0, breath = 0, tilt = 14 })
		local broken = GuestPose.target({ pose = "Walk", phase = 0, breath = 0, tilt = 14, form = 2 })
		check.truthy(calm.LeftKnee[1] < 0, "a knee bends back, as a person's does")
		check.truthy(broken.LeftKnee[1] > 0, "at Breaking it bends forward")
		local h0 = GuestPose.exposed("Peek", 1)
		local h2 = GuestPose.exposed("Peek", 1, nil, 2)
		local moved = math.sqrt((h2[1] - h0[1]) ^ 2 + (h2[2] - h0[2]) ^ 2 + (h2[3] - h0[3]) ^ 2)
		check.near(moved, GuestPose.neckStretch("Peek", 2), 1e-6, "the server knows the peeking head is further out")
		check.equal(GuestPose.neckStretch("Peek", 1), 0, "only at Breaking")
		check.equal(GuestPose.neckStretch("Walk", 2), 0, "not as he walks")
		check.near(GuestPose.neckStretch("Hold", 2, 8), 0.9, 1e-9, "held, it draws out over eight seconds")
	end)

	test("on all fours his hands and feet are on the floor, his head low", function()
		local values = GuestPose.target({ pose = "Crawl", phase = 0.25, breath = 0, tilt = 0 })
		local head = GuestPose.spine(values)
		local standing = GuestPose.spine(GuestPose.target({ pose = "Idle", phase = 0, breath = 0, tilt = 0 }))
		check.truthy(head[2] < standing[2] - 2.5, "his head is far lower than standing")
		check.truthy(math.abs(head[3]) < 2.5, "and over where he really is, not out ahead")
	end)

	test("smile grows with form and with closeness, and opens only from Fraying", function()
		local w0, o0 = GuestPose.smile(0, 0, false)
		local w1, o1 = GuestPose.smile(1, 0, false)
		local w2, o2 = GuestPose.smile(2, 0, false)
		check.equal(o0, 0, "closed at Calm")
		check.truthy(w0 > math.rad(55), "already far too wide at Calm")
		check.truthy(w1 > w0 and w2 > w1, "wider each form")
		check.truthy(o1 > 0 and o2 > o1, "opens from Fraying")
		check.atLeast(w1, math.rad(90), "ear to ear from Fraying")
		local wc, oc = GuestPose.smile(1, 1, false)
		check.truthy(wc > w1 and oc > o1, "wider and more open up close")
		local _, ob = GuestPose.smile(1, 0, true)
		check.truthy(ob > o1, "more open while backing away")
		local _, oCalmClose = GuestPose.smile(0, 1, false)
		check.atMost(oCalmClose, 0.15, "barely parts at Calm even up close")
	end)

	test("the mouth is shut at the corners and open in the middle; corners curl up", function()
		local cols = GuestPose.mouth(math.rad(96), 0.6, 24)
		check.equal(#cols, 25, "count + 1 columns")
		local first, middle = cols[1], cols[13]
		check.near(first.upper, first.lower, 1e-9, "corners closed")
		check.truthy(middle.upper - middle.lower > math.rad(5), "middle open")
		check.truthy(first.upper > middle.upper, "corners higher than the middle")
		check.near(first.theta, -math.rad(96), 1e-9, "spans the given width")
	end)

	test("mirror: reflecting across a plane, twice, is the identity", function()
		local MirrorMath = require(Shared.Logic.MirrorMath)
		local origin, normal = { 0, 5, 0 }, { 0, 0, 1 }
		local p = MirrorMath.reflectPoint({ 2, 6, 3 }, origin, normal)
		check.near(p[3], -3, 1e-9, "z mirrored")
		check.near(p[1], 2, 1e-9, "x kept")
		local back = MirrorMath.reflectPoint(p, origin, normal)
		check.near(back[3], 3, 1e-9, "and back")
		local v = MirrorMath.reflectVector({ 0, 0, -1 }, normal)
		check.near(v[3], 1, 1e-9, "a direction flips too")
	end)

	test("mirror: he shows in the pane only when he's behind you, in the room", function()
		local MirrorMath = require(Shared.Logic.MirrorMath)
		-- A 6 x 5 window at z = 0 facing into the room (+z), centre height 6.
		local origin, normal, right, up = { 0, 6, 0 }, { 0, 0, 1 }, { 1, 0, 0 }, { 0, 1, 0 }
		local eye = { 0, 5.6, 6 } -- you, 6 studs from the glass, looking at it
		-- He stands right behind you.
		check.truthy(MirrorMath.inPane(eye, { 0, 7.8, 12 }, origin, normal, right, up, 3, 2.5), "behind you")
		-- Off to one side behind you, far: outside the pane.
		check.equal(MirrorMath.inPane(eye, { 30, 7.8, 12 }, origin, normal, right, up, 3, 2.5), false, "far aside")
		-- Outside the window (the other side of the glass): no reflection.
		check.equal(MirrorMath.inPane(eye, { 0, 7.8, -4 }, origin, normal, right, up, 3, 2.5), false, "outside")
		-- You're outside: nothing either.
		check.equal(
			MirrorMath.inPane({ 0, 5.6, -6 }, { 0, 7.8, 12 }, origin, normal, right, up, 3, 2.5),
			false,
			"you outside"
		)
	end)

	test("face pieces lie on the head and face outwards", function()
		local a, b, c = 0.4, 0.575, 0.46
		local spec = GuestPose.piece(a, b, c, -0.1, -0.3, 0.1, -0.3)
		local p = spec.centre
		local onSurface = (p[1] / a) ^ 2 + (p[2] / b) ^ 2 + (p[3] / c) ^ 2
		check.near(onSurface, 1, 0.02, "centre on the ellipsoid")
		check.truthy(spec.normal[3] < -0.8, "front of the face points forward (-Z)")
		check.near(spec.up[2], 1, 0.15, "up is up")
		local dot = spec.right[1] * spec.normal[1] + spec.right[2] * spec.normal[2] + spec.right[3] * spec.normal[3]
		check.near(dot, 0, 0.05, "lies in the surface")
	end)
end
