return function(test, check, Shared, require)
	local K = require(Shared.Logic.Kinematics)

	local function seeded()
		local x = 4242
		return function()
			x = (x * 1103515245 + 12345) % 2147483648
			return x / 2147483648
		end
	end

	-- Where a two-bone limb ends for the angles twoBone returned.
	local function limbEnd(rx, ry, rz, fold, l1, l2)
		local r = K.rot(rx, ry, rz)
		local shin = K.apply(K.rot(fold, 0, 0), { 0, -l2, 0 })
		return K.apply(r, { shin[1], shin[2] - l1, shin[3] })
	end

	test("Euler angles survive a round trip through a rotation", function()
		local random = seeded()
		for _ = 1, 200 do
			local rx, ry, rz = (random() - 0.5) * 6, (random() - 0.5) * 3, (random() - 0.5) * 6
			local m = K.rot(rx, ry, rz)
			local a, b, c = K.euler(m)
			local back = K.rot(a, b, c)
			for i = 1, 3 do
				for j = 1, 3 do
					check.near(back[i][j], m[i][j], 1e-9, "same rotation")
				end
			end
		end
	end)

	test("two-bone IK reaches every target in range, the middle joint towards its pole", function()
		local random = seeded()
		for _ = 1, 300 do
			local l1, l2 = 1.5 + random(), 1.5 + random()
			local dir = K.unit({ random() - 0.5, -random(), random() - 0.5 })
			local d = math.abs(l1 - l2) + 0.05 + random() * (l1 + l2 - math.abs(l1 - l2) - 0.1)
			local target = K.scale(dir, d)
			local pole = { 0, 0, -1 }
			local bend = random() < 0.5 and -1 or 1
			local rx, ry, rz, fold, r, short = K.twoBone(target, l1, l2, bend, pole)
			check.near(short, 0, 1e-9, "in range")
			local e = limbEnd(rx, ry, rz, fold, l1, l2)
			check.near(K.length(K.sub(e, target)), 0, 1e-6, "the end is on the target")
			-- The middle joint leans to the pole's side of the line to the target.
			local middle = K.apply(r, { 0, -l1, 0 })
			local across = K.sub(middle, K.scale(dir, K.dot(middle, dir)))
			local q = K.sub(pole, K.scale(dir, K.dot(pole, dir)))
			if K.length(across) > 1e-3 and K.length(q) > 1e-3 then
				check.atLeast(K.dot(across, q), -1e-6, "the middle joint points towards the pole")
			end
		end
	end)

	test("a knee folds back, an elbow forward", function()
		local _, _, _, knee = K.twoBone({ 0, -3.2, 0 }, 2, 1.95, -1, { 0, 0, -1 })
		check.atMost(knee, -0.1, "the knee's fold is negative (the shin back)")
		local _, _, _, elbow = K.twoBone({ 0, -3, -0.5 }, 2, 1.85, 1, { 0, 0, 1 })
		check.atLeast(elbow, 0.1, "the elbow's fold is positive (the forearm forward)")
	end)

	test("out of reach: the limb points straight at it, and says how far short", function()
		local target = { 1, -5, -1 }
		local rx, ry, rz, fold, _, short = K.twoBone(target, 2, 1.95, -1, { 0, 0, -1 })
		check.near(short, K.length(target) - 3.95, 1e-3, "how far short")
		local e = limbEnd(rx, ry, rz, fold, 2, 1.95)
		check.near(K.dot(K.unit(e), K.unit(target)), 1, 1e-6, "straight at it")
	end)

	test("frames: a point there and back is the same point", function()
		local f = K.child(K.frame(), { 0.3, -0.3, 0 }, { 0.4, -0.2, 0.3, 0.1, 0.2, -0.1 })
		local p = { 1, -2, 0.5 }
		local back = K.toLocal(f, K.point(f, p))
		check.near(K.length(K.sub(back, p)), 0, 1e-9, "round trip")
	end)

	test("basis: the columns are the axes asked for", function()
		local m = K.basis({ 0, 0, 1 }, { 1, 0, 0 })
		local x = K.apply(m, { 1, 0, 0 })
		local y = K.apply(m, { 0, 1, 0 })
		check.near(K.dot(x, { 0, 0, 1 }), 1, 1e-9, "x")
		check.near(K.dot(y, { 1, 0, 0 }), 1, 1e-9, "y")
	end)

	test("springs: no overshoot from rest, the same curve at any frame rate", function()
		for _, hz in { 15, 30, 60, 144, 240 } do
			local x, v = 0, 0
			local dt = 1 / hz
			local most = 0
			for _ = 1, math.floor(hz * 2) do
				x, v = K.spring(x, v, 1, 10, dt)
				most = math.max(most, x)
			end
			check.atMost(most, 1 + 1e-9, "never past the goal at " .. hz .. " fps")
			check.near(x, 1, 1e-3, "there within two seconds at " .. hz .. " fps")
		end
		local a, b = 0, 0
		local va, vb = 0, 0
		for _ = 1, 60 do
			a, va = K.spring(a, va, 1, 6, 1 / 60)
		end
		for _ = 1, 15 do
			b, vb = K.spring(b, vb, 1, 6, 1 / 15)
		end
		check.near(a, b, 1e-6, "frame-rate independent")
	end)
end
