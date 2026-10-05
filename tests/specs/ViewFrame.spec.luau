-- What you hold stays on screen (Logic/ViewFrame, Config.ViewModel.Poses).
return function(test, check, Shared, require)
	local Config = require(Shared.Config)
	local ViewFrame = require(Shared.Logic.ViewFrame)

	local VM = Config.ViewModel
	local SCALE = VM.Scale

	local fovs = { 60, 70, 90 } -- the Settings slider's range, give or take
	local aspects = { 4 / 3, 16 / 9, 21 / 9 }

	test("a point straight ahead is the middle of the screen", function()
		local x, y = ViewFrame.project(0, 0, 3, 70, 16 / 9)
		check.near(x, 0, 1e-9, "x")
		check.near(y, 0, 1e-9, "y")
	end)

	test("something at the edge of the field of view lands on the edge of the screen", function()
		local _, y = ViewFrame.project(0, math.tan(math.rad(35)) * 2, 2, 70, 16 / 9)
		check.near(y, 1, 1e-9, "top edge")
		local x = ViewFrame.project(math.tan(math.rad(35)) * 2 * (16 / 9), 0, 2, 70, 16 / 9)
		check.near(x, 1, 1e-9, "right edge")
	end)

	test("behind the camera is off the screen", function()
		local x = ViewFrame.project(0, 0, -1, 70, 16 / 9)
		check.equal(x, nil, "behind")
	end)

	test("every pose has what the viewmodel needs", function()
		for id, pose in VM.Poses do
			for _, key in { "at", "turn", "wrist" } do
				check.equal(#pose[key], 3, id .. "." .. key .. " is three numbers")
			end
			check.truthy(type(pose.yaw) == "number" and type(pose.tilt) == "number", id .. " has a forearm angle")
			check.truthy(pose.at[3] > 0.5, id .. " is held out in front of you")
		end
	end)

	test("each item and each hand stays on screen at every field of view and aspect ratio", function()
		for id, pose in VM.Poses do
			local points = { { "item", pose.at[1], pose.at[2], pose.at[3] } }
			local rx, ry, rz = ViewFrame.hand(pose, pose.wrist, 1, SCALE, VM.ArmHandForward)
			table.insert(points, { "right hand", rx, ry, rz })
			if pose.left then
				local lx, ly, lz = ViewFrame.hand(pose, pose.left, -1, SCALE, VM.ArmHandForward)
				table.insert(points, { "left hand", lx, ly, lz })
			end
			for _, point in points do
				for _, fov in fovs do
					for _, aspect in aspects do
						local x, y = ViewFrame.project(point[2], point[3], point[4], fov, aspect)
						local where = string.format("%s %s at fov %d aspect %.2f", id, point[1], fov, aspect)
						check.truthy(x ~= nil, where .. " is in front of you")
						if x and y then
							check.truthy(math.abs(x) <= 0.92, string.format("%s: x %.2f runs off the side", where, x))
							check.truthy(y >= -0.92, string.format("%s: y %.2f runs off the bottom", where, y))
							-- Held low, below the middle of the screen, not in front of your face.
							check.truthy(y <= 0, string.format("%s: y %.2f is up in your face", where, y))
						end
					end
				end
			end
		end
	end)

	test("hands reach their item: the right hand is on the right, the left on the left", function()
		-- Something held in both hands (no tool is, today; the maths is kept).
		local pose = {
			at = { 0.05, -0.3, 1.25 },
			turn = { 4, 0, 0 },
			wrist = { 0.38, -0.22, 0.28 },
			left = { -0.34, -0.24, 0.22 },
			yaw = 18,
			tilt = 22,
		}
		local rx = ViewFrame.hand(pose, pose.wrist, 1, SCALE, VM.ArmHandForward)
		local lx = ViewFrame.hand(pose, pose.left, -1, SCALE, VM.ArmHandForward)
		check.truthy(rx > pose.at[1] and lx < pose.at[1], "a two-handed item is held from both sides")
	end)
end
