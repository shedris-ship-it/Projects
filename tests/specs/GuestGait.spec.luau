return function(test, check, Shared, require)
	local GuestGait = require(Shared.Logic.GuestGait)

	local function flat()
		return 0
	end

	-- Walk a stand-in root along a path for `seconds`. path(t) -> x, z, yaw,
	-- vx, vz. Calls watch(state, root, t, events) each frame.
	local function walk(spec, seconds: number, path, watch, stance)
		local x, z, yaw = path(0)
		local fx, fz = GuestGait.facing(yaw)
		local root = { x = x, y = 4.6, z = z, fx = fx, fz = fz, floor = 0 }
		local state = GuestGait.new(root, flat)
		local dt = 1 / 60
		local t = 0
		while t < seconds do
			t += dt
			local px, pz, pyaw, vx, vz = path(t)
			root.x, root.z = px, pz
			root.fx, root.fz = GuestGait.facing(pyaw)
			local events = GuestGait.step(state, {
				root = root,
				vx = vx,
				vz = vz,
				spec = spec,
				stance = stance,
				floor = flat,
			}, dt)
			watch(state, root, t, events)
		end
		return state, root
	end

	local function straight(speed: number, dirX: number, dirZ: number, yaw: number?)
		return function(t)
			return dirX * speed * t, dirZ * speed * t, yaw or 0, dirX * speed, dirZ * speed
		end
	end

	-- What every gait must do: planted feet never move, the feet keep up
	-- with him, and they take turns.
	local function gaitChecks(name: string, spec, speed: number, dirX: number, dirZ: number, yaw: number?)
		local last = {}
		local landings = {}
		local farthest = 0
		local bothUp = 0
		walk(spec, 6, straight(speed, dirX, dirZ, yaw), function(state, root, _, events)
			local landed = {}
			for _, foot in events do
				landed[foot] = true
				table.insert(landings, foot)
			end
			for foot, f in state.feet do
				local prev = last[foot]
				if prev and prev.stance and f.stance and not landed[foot] then
					check.near(f.x, prev.x, 1e-9, name .. ": a planted foot never moves")
					check.near(f.z, prev.z, 1e-9, name .. ": a planted foot never moves")
				end
				last[foot] = { stance = f.stance, x = f.x, z = f.z }
				local dx, dz = f.x - root.x, f.z - root.z
				farthest = math.max(farthest, math.sqrt(dx * dx + dz * dz))
			end
			if not state.feet.Left.stance and not state.feet.Right.stance then
				bothUp += 1
			end
		end)
		check.atLeast(#landings, 4, name .. ": steps were taken")
		for i = 3, #landings do
			check.truthy(landings[i] ~= landings[i - 1], name .. ": the feet take turns")
		end
		return farthest, bothUp, #landings
	end

	test("walking: planted feet never move, the feet keep up and take turns, never both off the floor", function()
		local spec = GuestGait.Specs.Walk
		local farthest, bothUp, steps = gaitChecks("walk", spec, 6, 0, -1)
		check.atMost(farthest, spec.step * 1.05, "no foot is left far behind")
		check.equal(bothUp, 0, "a walk always has a foot down")
		-- 36 studs in 6 s at about a step length a step.
		check.near(steps, 36 / spec.step, 3, "about a step per step length")
	end)

	test("running has a flight between steps and still keeps up", function()
		local spec = GuestGait.Specs.Run
		local farthest, bothUp = gaitChecks("run", spec, 19, 0, -1)
		check.atLeast(bothUp, 10, "both feet off the floor for a moment each stride")
		check.atMost(farthest, spec.step * 1.4, "the feet keep up at a sprint")
	end)

	test("backing away and moving sideways are steps too", function()
		local back = GuestGait.Specs.BackAway
		local farthest = gaitChecks("back away", back, 3.5, 0, 1) -- facing -Z, moving +Z
		check.atMost(farthest, back.step * 1.3, "keeps up backing away")
		local walk = GuestGait.Specs.Walk
		local side = gaitChecks("sideways", walk, 4, 1, 0) -- facing -Z, moving +X
		check.atMost(side, walk.step * 1.3, "keeps up moving sideways")
	end)

	test("the creep is short careful steps", function()
		local spec = GuestGait.Specs.Creep
		local farthest = gaitChecks("creep", spec, 1.6, 0, -1)
		check.atMost(farthest, spec.step * 1.2, "keeps up creeping")
	end)

	test("a foot lands about where it'll be under him at the middle of its stance", function()
		local spec = GuestGait.Specs.Walk
		local stanceStart = {}
		local worst = 0
		walk(spec, 6, straight(6, 0, -1), function(state, root, t, events)
			for _, foot in events do
				stanceStart[foot] = t
			end
			for foot, f in state.feet do
				local began = stanceStart[foot]
				local share = spec.stance + (foot == "Right" and spec.uneven or 0)
				local half = share * 2 * state.step / 6 / 2
				if f.stance and began and math.abs(t - began - half) < 1 / 120 then
					-- Mid-stance: the foot is level with him along the way.
					worst = math.max(worst, math.abs(f.z - root.z))
				end
			end
		end)
		check.atMost(worst, 0.6, "mid-stance, the foot is under his hips")
	end)

	test("stopping mid-stride finishes the step: both feet end under him", function()
		local spec = GuestGait.Specs.Walk
		local path = function(t)
			local moving = math.min(t, 1.37)
			return 0, -6 * moving, 0, 0, t < 1.37 and -6 or 0
		end
		local state, root = walk(spec, 3, path, function() end)
		for foot, f in state.feet do
			check.truthy(f.stance, foot .. " is down")
			local x, z = GuestGait._neutral(root, foot, nil)
			local d = math.sqrt((f.x - x) ^ 2 + (f.z - z) ^ 2)
			check.atMost(d, GuestGait.SettleDistance + 0.01, foot .. " is in its place")
		end
	end)

	test("turning on the spot steps round, one foot at a time", function()
		local bothUp, steps = 0, 0
		local path = function(t)
			return 0, 0, math.min(t, 1.5) / 1.5 * math.pi, 0, 0
		end
		local state, root = walk(nil, 3, path, function(s, _, _, events)
			steps += #events
			if not s.feet.Left.stance and not s.feet.Right.stance then
				bothUp += 1
			end
		end)
		check.equal(bothUp, 0, "never both feet off the floor")
		check.atLeast(steps, 2, "he stepped round")
		for foot, f in state.feet do
			local x, z = GuestGait._neutral(root, foot, nil)
			local d = math.sqrt((f.x - x) ^ 2 + (f.z - z) ^ 2)
			check.atMost(d, GuestGait.SettleDistance + 0.6, foot .. " ends near its place")
		end
	end)

	test("standing still, the feet stay put", function()
		local moved = 0
		walk(nil, 2, function()
			return 0, 0, 0, 0, 0
		end, function(_, _, _, events)
			moved += #events
		end)
		check.equal(moved, 0, "no steps standing still")
	end)
end
