-- Players' poses (Logic/PlayerPose; the squad playtest, 2026-10-08: no crouch,
-- and no down animation). Forward kinematics over the default R15 body:
-- feet stay on the floor, a downed body lies on it.
return function(test, check, Shared, require)
	local roblox = require("@lune/roblox")
	local CFrame = roblox.CFrame
	local Vector3 = roblox.Vector3
	local PlayerPose = require(Shared.Logic.PlayerPose)
	local Rig = PlayerPose.Rig

	local function v3(t)
		return Vector3.new(t[1], t[2], t[3])
	end

	-- Every part's CFrame for joint `values`, the root standing at the origin.
	local function solve(values)
		local parts = { HumanoidRootPart = CFrame.new(0, Rig.rootY, 0) }
		for _, name in PlayerPose.Order do
			local joint = Rig[name]
			local v = values[name] or { 0, 0, 0, 0, 0, 0 }
			local transform = CFrame.new(v[4], v[5], v[6]) * CFrame.Angles(v[1], v[2], v[3])
			parts[joint.child] = parts[joint.parent]
				* CFrame.new(v3(joint.a0))
				* transform
				* CFrame.new(v3(joint.a1)):Inverse()
		end
		return parts
	end

	local function y(parts, name)
		return parts[name].Position.Y
	end

	test("standing still, the rig puts the feet on the floor", function()
		local parts = solve({})
		check.near(y(parts, "LeftFoot"), 0.15, 0.02, "left foot")
		check.near(y(parts, "RightFoot"), 0.15, 0.02, "right foot")
		check.near(y(parts, "Head"), 4.586, 0.02, "head")
	end)

	test("crouched: lower by most of a stud, feet still on the floor, at any step", function()
		for i = 0, 11 do
			local phase = i * math.pi / 6
			local parts = solve(PlayerPose.crouch(phase, 1))
			for _, foot in { "LeftFoot", "RightFoot" } do
				check.atLeast(y(parts, foot), 0.0, foot .. " not under the floor at phase " .. i)
				check.atMost(y(parts, foot), 0.75, foot .. " stays near the floor at phase " .. i)
			end
		end
		local still = solve(PlayerPose.crouch(0, 0))
		check.near(y(still, "LeftFoot"), 0.15, 0.08, "standing crouched: foot flat")
		check.atMost(y(still, "Head"), 4.586 - 0.6, "the head comes down")
	end)

	test("downed: the body lies on the floor, head up off it", function()
		for i = 0, 7 do
			local parts = solve(PlayerPose.prone(i * math.pi / 4, 1))
			for _, name in { "LowerTorso", "UpperTorso" } do
				check.atMost(y(parts, name), 1.0, name .. " on the floor")
				check.atLeast(y(parts, name), 0.2, name .. " not through it")
			end
			check.atMost(y(parts, "Head"), 1.6, "head low")
			check.atLeast(y(parts, "Head"), 0.5, "head lifted")
			for _, name in { "LeftFoot", "RightFoot", "LeftHand", "RightHand" } do
				check.atLeast(y(parts, name), -0.3, name .. " not deep in the floor")
			end
		end
		-- Head the way they face (-Z), the legs behind.
		local parts = solve(PlayerPose.prone(0, 0))
		check.truthy(parts.Head.Position.Z < parts.LowerTorso.Position.Z - 1.5, "head ahead")
		check.truthy(parts.LeftFoot.Position.Z > parts.LowerTorso.Position.Z + 1, "feet behind")
	end)

	test("kneeling: one foot flat, the other knee on the floor", function()
		local parts = solve(PlayerPose.kneel())
		check.near(y(parts, "RightFoot"), 0.15, 0.1, "front foot flat")
		local knee = parts.LeftUpperLeg * CFrame.new(0, -0.401, 0)
		check.atMost(knee.Position.Y, 0.35, "back knee down")
		check.atLeast(knee.Position.Y, -0.1, "not through the floor")
	end)

	test("every pose has finite values for every joint; blends end where they should", function()
		local poses = { PlayerPose.crouch(1.3, 0.7), PlayerPose.prone(2.2, 0.5), PlayerPose.kneel() }
		for _, pose in poses do
			for _, name in PlayerPose.Order do
				local v = pose[name]
				check.truthy(v ~= nil, name .. " present")
				for i = 1, 6 do
					check.truthy(v[i] == v[i] and math.abs(v[i]) < 10, name .. " finite")
				end
			end
		end
		local a, b = PlayerPose.crouch(0, 0), PlayerPose.prone(0, 0)
		check.near(PlayerPose.blend(a, b, 0).Root[5], a.Root[5], 1e-9, "start")
		check.near(PlayerPose.blend(a, b, 1).Root[1], b.Root[1], 1e-9, "end")
	end)
end
