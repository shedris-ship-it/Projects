-- Where things in your hands land on the screen (Controllers/ViewModelController).
-- The held-item poses (Config.ViewModel.Poses) are camera-frame offsets, so the
-- projection is plain trigonometry and a test can promise the hands never fall
-- off the bottom of the screen again (owner, 2026-10-04: "the hands are wonky";
-- both wrists projected below the viewport). Pure: plain numbers, no Vector3.

local ViewFrame = {}

-- Where a point lands, as -1..1 from the centre of the screen (x right, y up),
-- for a vertical field of view in degrees and a width / height aspect. Nil if
-- it is behind the camera. `forward` is distance ahead, positive.
function ViewFrame.project(right: number, up: number, forward: number, fovDegrees: number, aspect: number)
	if forward <= 0.01 then
		return nil, nil
	end
	local halfHeight = math.tan(math.rad(fovDegrees) / 2) * forward
	return right / (halfHeight * aspect), up / halfHeight
end

-- The forearm's forward direction in the camera frame (x right, y up, z back):
-- the arm model points down -Z, swings out `yaw` degrees and rises `tilt` degrees.
local function armForward(yaw: number, tilt: number): (number, number, number)
	-- Rx(tilt) * (0, 0, -1), then Ry(yaw).
	local t, y = math.rad(tilt), math.rad(yaw)
	local ux, uy, uz = 0, math.sin(t), -math.cos(t)
	return uz * math.sin(y) + ux * math.cos(y), uy, uz * math.cos(y) - ux * math.sin(y)
end

-- The middle of a hand, in camera-frame studs, for a pose and a wrist offset
-- ({ right, up, back } from the item's middle). `scale` is the arm model's scale;
-- `handForward` is how far in front of the wrist the hand's middle sits, unscaled.
-- `side` is 1 for the right hand and -1 for the left (its forearm swings the other way).
function ViewFrame.hand(pose, wrist, side: number, scale: number, handForward: number)
	local fx, fy, fz = armForward(pose.yaw * side, pose.tilt)
	local reach = handForward * scale
	-- z in a pose is distance behind the item toward you, so it subtracts from `at`'s distance.
	return pose.at[1] + wrist[1] + fx * reach, pose.at[2] + wrist[2] + fy * reach, pose.at[3] - wrist[3] - fz * reach
end

return ViewFrame
