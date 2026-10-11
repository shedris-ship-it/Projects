return function(test, check, Shared, require)
	local GuestPose = require(Shared.Logic.GuestPose)
	local Rig = GuestPose.Rig

	-- Drive him along a straight line: facing (fx, fz), moving (vx, vz).
	-- Calls watch(values, root, state) every frame after the first second.
	local function drive(pose: string, seconds: number, start, fx, fz, vx, vz, extra, watch)
		local state = GuestPose.new()
		local root = { x = start[1], y = Rig.rootY, z = start[2], fx = fx, fz = fz }
		local dt = 1 / 60
		local t = 0
		while t < seconds do
			t += dt
			root.x += vx * dt
			root.z += vz * dt
			local input = { pose = pose, root = root, vx = vx, vz = vz, tilt = 14 }
			for key, value in extra and extra(root) or {} do
				input[key] = value
			end
			local values = GuestPose.step(state, input, dt)
			watch(values, root, state, t)
		end
		return state
	end

	test("walking, a foot he stands on stays put as it's drawn", function()
		for _, case in
			{
				{ "Walk", 0, -6 },
				{ "Run", 0, -17 },
				{ "Creep", 0, -2 },
				{ "BackAway", 0, 3.5 },
				{ "Walk", 4, 0 }, -- sideways
			}
		do
			local pose, vx, vz = case[1], case[2], case[3]
			local last = {}
			local worst, off = 0, 0
			drive(pose, 4, { 0, 0 }, 0, -1, vx, vz, nil, function(values, root, state, t)
				local ankles = GuestPose.ankles(values)
				for side, a in ankles do
					local x, y, z = GuestPose.toWorld(root, a)
					local f = state.gait.feet[side]
					local was = last[side]
					if t > 1 and state.legWeight > 0.99 and f.stance and was and was.stance and was.fx == f.x then
						local moved = math.sqrt((x - was.x) ^ 2 + (z - was.z) ^ 2) * 60
						worst = math.max(worst, moved)
					end
					if t > 1 then
						-- (In the air, a foot just lifting off may trail a little.)
						local miss = math.sqrt((x - f.x) ^ 2 + (y - (f.y + Rig.ankleY)) ^ 2 + (z - f.z) ^ 2)
						off = math.max(off, f.stance and miss or miss * 0.3)
					end
					last[side] = { x = x, z = z, stance = f.stance, fx = f.x }
				end
			end)
			check.atMost(worst, 0.3, pose .. ": a planted foot slides no faster than this (was 2.7 studs/s)")
			check.atMost(off, 0.12, pose .. ": the drawn foot is where the gait put it")
		end
	end)

	-- An 8-stud opening across the z = 0 line, 6 wide, in a half-stud wall.
	local OPENING = { x = 0, z = 0, top = 8, floor = 0, along = "x", half = 3, depth = 0.25 }

	test("stopping for a moment, turning or going back, his hips never sink to the floor", function()
		-- (Studio, 2026-10-11: the walker paused 0.1 s mid-walk, a foot was
		-- left down where he'd stopped, and his hips sank 3.5 studs to reach
		-- it as he walked on.)
		-- Straight on, no deeper than a heavy step; turned or sent back the
		-- way he came, a moment's lurch, never past the cap.
		for _, case in
			{
				{ "Walk", 6, 1, 0, 0.9 },
				{ "Walk", 6, -1, 0, GuestPose.MaxDrop + 0.1 },
				{ "Walk", 6, 0, 1, GuestPose.MaxDrop + 0.1 },
				{ "Run", 17, 1, 0, 0.9 },
				{ "BackAway", 3.5, 1, 0, 0.7 },
			}
		do
			local worst, at = 0, ""
			for stopAt = 0.4, 1.4, 0.1 do
				for _, stopFor in { 0.05, 0.15, 0.3, 0.6 } do
					local state = GuestPose.new()
					local root = { x = 0, y = Rig.rootY, z = 0, fx = 1, fz = 0 }
					local vx, vz = 0, 0
					local dt = 1 / 30
					local t = 0
					while t < 2.6 do
						t += dt
						local wx, wz = case[2], 0
						if t < 0.2 or (t > stopAt and t < stopAt + stopFor) then
							wx, wz = 0, 0
						elseif t >= stopAt + stopFor then
							wx, wz = case[3] * case[2], case[4] * case[2]
						end
						-- (The client steadies the replicated velocity like this.)
						vx += (wx - vx) * math.min(1, dt * 12)
						vz += (wz - vz) * math.min(1, dt * 12)
						root.x += wx * dt
						root.z += wz * dt
						local m = math.sqrt(wx * wx + wz * wz)
						if m > 0.1 and case[1] ~= "BackAway" then
							root.fx, root.fz = wx / m, wz / m
						end
						GuestPose.step(state, { pose = case[1], root = root, vx = vx, vz = vz, tilt = 14 }, dt)
						if state.drop > worst then
							worst = state.drop
							at = string.format(
								"%s to (%d, %d), stopped at %.1f s for %.2f s",
								case[1],
								case[3],
								case[4],
								stopAt,
								stopFor
							)
						end
					end
				end
			end
			check.atMost(worst, case[5], "the deepest his hips go (" .. at .. ")")
		end
	end)

	test("he never puts his head through a door frame, at any speed, either way", function()
		for _, case in
			{
				{ "Creep", 1.6, 1 },
				{ "Walk", 4, 1 },
				{ "Walk", 6, 1 },
				{ "Walk", 8, 1 },
				{ "Run", 17, 1 },
				{ "BackAway", 3.5, -1 }, -- facing back the way he came
				{ "Walk", 6, 1, 1.6 }, -- off-centre
			}
		do
			local pose, speed, facing, offset = case[1], case[2], case[3], case[4] or 0
			local worst = -math.huge
			drive(pose, 24 / speed, { offset, 12 }, 0, -facing, 0, -speed, function(root)
				return { stoop = GuestPose.doorStoop({ OPENING }, root, 0, -speed), gazeYaw = 0, gazePitch = -0.2 }
			end, function(values, root)
				local top, middle = GuestPose.head(values)
				local _, topY = GuestPose.toWorld(root, top)
				local hx, _, hz = GuestPose.toWorld(root, middle)
				-- Anywhere over the frame's thickness (the head is ~0.45 round).
				if math.abs(hz) < OPENING.depth + 0.45 and math.abs(hx) < OPENING.half then
					worst = math.max(worst, topY)
				end
			end)
			check.atMost(worst, OPENING.top - 0.05, pose .. " at " .. speed .. ": his head stays under the frame")
		end
	end)

	test("he doesn't duck in the open, only at the frame", function()
		local far = GuestPose.doorStoop({ OPENING }, { x = 0, y = Rig.rootY, z = 12 }, 0, -6)
		check.equal(far, 0, "12 studs off")
		local beside = GuestPose.doorStoop({ OPENING }, { x = 8, y = Rig.rootY, z = 0.5 }, 0, -6)
		check.equal(beside, 0, "by the wall, not at its opening")
		local under = GuestPose.doorStoop({ OPENING }, { x = 0, y = Rig.rootY, z = 0 }, 0, -6)
		check.equal(under, 1, "right under it")
		local upstairs = GuestPose.doorStoop({ OPENING }, { x = 0, y = Rig.rootY + 11, z = 0 }, 0, -6)
		check.equal(upstairs, 0, "not for a doorway on the floor below")
	end)

	test("peeking, his hand finds the frame and his head clears it", function()
		for _, sign in { 1, -1 } do
			-- The jamb's edge on the far side of the wall: 1.6 along, 2.2 ahead,
			-- at hand height.
			local grip = { sign * 1.6, 7.0 - Rig.rootY, -2.2 }
			local values
			drive("Peek", 2.5, { 0, 0 }, 0, -1, 0, 0, function()
				return { lean = sign, grip = grip, gazeYaw = 0 }
			end, function(v)
				values = v
			end)
			local side = sign > 0 and "Right" or "Left"
			local wrist = GuestPose.wrist(values, side)
			local at = GuestPose.GripWrist
			local want = { grip[1] + sign * at[1], grip[2] + at[2], grip[3] + at[3] }
			local miss = math.sqrt((wrist[1] - want[1]) ^ 2 + (wrist[2] - want[2]) ^ 2 + (wrist[3] - want[3]) ^ 2)
			check.atMost(miss, 0.12, side .. ": the wrist is at the frame")
			local _, middle = GuestPose.head(values)
			check.atLeast(middle[1] * sign, 1.6 + 0.25, side .. ": his face is out past the frame's edge")
		end
	end)
end
