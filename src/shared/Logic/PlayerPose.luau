-- Players' poses, built in code like the Guest's (Logic/GuestPose): the squad
-- playtest (2026-10-08) found no crouch and "no down animation" (a downed
-- player stood up and walked at a crawl's speed). Nothing is uploaded: every
-- client writes these joint values over the default animation for every
-- character (Controllers/PoseController).
--
-- Values are per R15 joint: { rx, ry, rz, tx, ty, tz }, the joint's
-- Transform as CFrame.new(tx, ty, tz) * CFrame.Angles(rx, ry, rz), in the
-- parent part's frame (x right, y up, z back). +rx swings a hanging limb
-- forward and tips an upright part backwards. Pure (tests/specs/PlayerPose).

local PlayerPose = {}

-- The default R15 body (Roblox's own proportions, read off a character in
-- this place on 2026-10-08): where each joint sits on its parent (a0) and
-- its child (a1).
PlayerPose.Rig = {
	rootY = 3, -- the HumanoidRootPart's centre over the floor (HipHeight 2)
	Root = { parent = "HumanoidRootPart", child = "LowerTorso", a0 = { 0, -1, 0 }, a1 = { 0, -0.2, 0 } },
	Waist = { parent = "LowerTorso", child = "UpperTorso", a0 = { 0, 0.2, 0 }, a1 = { 0, -0.8, 0 } },
	Neck = { parent = "UpperTorso", child = "Head", a0 = { 0, 0.8, 0 }, a1 = { 0, -0.586, 0 } },
	LeftShoulder = { parent = "UpperTorso", child = "LeftUpperArm", a0 = { -1, 0.563, 0 }, a1 = { 0.5, 0.394, 0 } },
	RightShoulder = { parent = "UpperTorso", child = "RightUpperArm", a0 = { 1, 0.563, 0 }, a1 = { -0.5, 0.394, 0 } },
	LeftElbow = { parent = "LeftUpperArm", child = "LeftLowerArm", a0 = { 0, -0.334, 0 }, a1 = { 0, 0.259, 0 } },
	RightElbow = { parent = "RightUpperArm", child = "RightLowerArm", a0 = { 0, -0.334, 0 }, a1 = { 0, 0.259, 0 } },
	LeftWrist = { parent = "LeftLowerArm", child = "LeftHand", a0 = { 0, -0.501, 0 }, a1 = { 0, 0.125, 0 } },
	RightWrist = { parent = "RightLowerArm", child = "RightHand", a0 = { 0, -0.501, 0 }, a1 = { 0, 0.125, 0 } },
	LeftHip = { parent = "LowerTorso", child = "LeftUpperLeg", a0 = { -0.5, -0.2, 0 }, a1 = { 0, 0.421, 0 } },
	RightHip = { parent = "LowerTorso", child = "RightUpperLeg", a0 = { 0.5, -0.2, 0 }, a1 = { 0, 0.421, 0 } },
	LeftKnee = { parent = "LeftUpperLeg", child = "LeftLowerLeg", a0 = { 0, -0.401, 0 }, a1 = { 0, 0.379, 0 } },
	RightKnee = { parent = "RightUpperLeg", child = "RightLowerLeg", a0 = { 0, -0.401, 0 }, a1 = { 0, 0.379, 0 } },
	LeftAnkle = { parent = "LeftLowerLeg", child = "LeftFoot", a0 = { 0, -0.547, 0 }, a1 = { 0, 0.102, 0 } },
	RightAnkle = { parent = "RightLowerLeg", child = "RightFoot", a0 = { 0, -0.547, 0 }, a1 = { 0, 0.102, 0 } },
}

-- Joints from the root out (a parent before its children).
PlayerPose.Order = {
	"Root",
	"Waist",
	"Neck",
	"LeftShoulder",
	"RightShoulder",
	"LeftElbow",
	"RightElbow",
	"LeftWrist",
	"RightWrist",
	"LeftHip",
	"RightHip",
	"LeftKnee",
	"RightKnee",
	"LeftAnkle",
	"RightAnkle",
}

local THIGH = 0.421 + 0.401 -- hip to knee
local SHIN = 0.379 + 0.547 -- knee to ankle

-- How far the hips drop for legs bent `hip` (forward) and `knee` (back) so
-- the feet stay on the floor (the ankle keeps the foot level).
function PlayerPose.legDrop(hip: number, knee: number): number
	return (THIGH + SHIN) - (THIGH * math.cos(hip) + SHIN * math.cos(hip + knee))
end

PlayerPose.Crouch = { hip = 1.15, knee = -2.0, lean = -0.4, stride = 0.32 }
PlayerPose.Kneel = { hip = 1.45, knee = -2.4, lean = -0.3 }

local function zero()
	return { 0, 0, 0, 0, 0, 0 }
end

local function legs(values, hip: number, knee: number, swingL: number, swingR: number)
	-- The ankle keeps each foot level whatever the stride does.
	values.LeftHip = { hip + swingL, 0, 0, 0, 0, 0 }
	values.RightHip = { hip + swingR, 0, 0, 0, 0, 0 }
	values.LeftKnee = { knee - math.max(0, swingL) * 0.6, 0, 0, 0, 0, 0 }
	values.RightKnee = { knee - math.max(0, swingR) * 0.6, 0, 0, 0, 0, 0 }
	values.LeftAnkle = { -(hip + swingL + values.LeftKnee[1]), 0, 0, 0, 0, 0 }
	values.RightAnkle = { -(hip + swingR + values.RightKnee[1]), 0, 0, 0, 0, 0 }
end

-- Crouched, creeping: `phase` (radians) runs with the distance walked, so
-- standing still it holds; `moving` 0..1 scales the stride.
function PlayerPose.crouch(phase: number, moving: number)
	local c = PlayerPose.Crouch
	local values = {}
	local swing = math.sin(phase) * c.stride * moving
	legs(values, c.hip, c.knee, swing, -swing)
	local drop = PlayerPose.legDrop(c.hip, c.knee)
	values.Root = { 0, 0, 0, 0, -drop, 0.15 }
	values.Waist = { c.lean, 0, 0, 0, 0, 0 }
	values.Neck = { -c.lean * 0.8, 0, 0, 0, 0, 0 }
	-- Arms held in front, close to the body.
	values.LeftShoulder = { 0.45 - swing * 0.5, 0, 0.12, 0, 0, 0 }
	values.RightShoulder = { 0.45 + swing * 0.5, 0, -0.12, 0, 0, 0 }
	values.LeftElbow = { 0.7, 0, 0, 0, 0, 0 }
	values.RightElbow = { 0.7, 0, 0, 0, 0, 0 }
	values.LeftWrist, values.RightWrist = zero(), zero()
	return values
end

-- On one knee beside a friend (reviving them): hands reaching down.
function PlayerPose.kneel()
	local k = PlayerPose.Kneel
	local values = {}
	legs(values, k.hip, k.knee, 0, 0)
	-- The back leg's knee on the floor: its hip opens, the shin lies back.
	values.LeftHip = { 0.15, 0, 0, 0, 0, 0 }
	values.LeftKnee = { -1.55, 0, 0, 0, 0, 0 }
	values.LeftAnkle = { 0.9, 0, 0, 0, 0, 0 }
	local drop = PlayerPose.legDrop(k.hip, k.knee)
	values.Root = { 0, 0, 0, 0, -drop, 0.1 }
	values.Waist = { k.lean, 0, 0, 0, 0, 0 }
	values.Neck = { -0.4, 0, 0, 0, 0, 0 }
	values.LeftShoulder = { 1.1, 0, 0.1, 0, 0, 0 }
	values.RightShoulder = { 1.25, 0, -0.1, 0, 0, 0 }
	values.LeftElbow = { 0.35, 0, 0, 0, 0, 0 }
	values.RightElbow = { 0.3, 0, 0, 0, 0, 0 }
	values.LeftWrist, values.RightWrist = zero(), zero()
	return values
end

-- Face down on the floor, head the way they face, crawling: arms reach and
-- pull in turn, legs push. `phase` runs with the distance crawled.
PlayerPose.ProneDrop = 1.4 -- the body's middle comes down to just over its own half-depth (up on the forearms)
function PlayerPose.prone(phase: number, moving: number)
	local values = {}
	local s = math.sin(phase) * moving
	values.Root = { -math.pi / 2, 0, 0, 0, -PlayerPose.ProneDrop, 0 }
	values.Waist = { 0.08 * s, 0.1 * s, 0, 0, 0, 0 }
	-- The head lifted to look along the floor.
	values.Neck = { 1.25, 0, 0, 0, 0, 0 }
	-- Arms: one reaches out past the head while the other pulls back.
	values.LeftShoulder = { 3.0 + 0.3 * s, 0, 0.2, 0, 0, 0 }
	values.RightShoulder = { 3.0 - 0.3 * s, 0, -0.2, 0, 0, 0 }
	values.LeftElbow = { 0.35 - 0.3 * s, 0, 0, 0, 0, 0 }
	values.RightElbow = { 0.35 + 0.3 * s, 0, 0, 0, 0, 0 }
	values.LeftWrist, values.RightWrist = zero(), zero()
	-- Legs trail, a knee drawn up in turn.
	values.LeftHip = { 0.25 * math.max(0, -s), 0, -0.08, 0, 0, 0 }
	values.RightHip = { 0.25 * math.max(0, s), 0, 0.08, 0, 0, 0 }
	values.LeftKnee = { -0.5 * math.max(0, -s) - 0.1, 0, 0, 0, 0, 0 }
	values.RightKnee = { -0.5 * math.max(0, s) - 0.1, 0, 0, 0, 0, 0 }
	values.LeftAnkle = { 0.6, 0, 0, 0, 0, 0 }
	values.RightAnkle = { 0.6, 0, 0, 0, 0, 0 }
	return values
end

-- Blend two poses (a = 0: first, 1: second), joint by joint.
function PlayerPose.blend(a, b, t: number)
	local out = {}
	for _, name in PlayerPose.Order do
		local va, vb = a[name] or zero(), b[name] or zero()
		local v = {}
		for i = 1, 6 do
			v[i] = va[i] + (vb[i] - va[i]) * t
		end
		out[name] = v
	end
	return out
end

return PlayerPose
