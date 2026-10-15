-- The Guest's takedown, in place of the catch's jumpscare (the visual rework
-- V8; the owner, 2026-10-15: "the camera goes into 3rd person and you watch
-- your character get mauled", after Threshold). The owner's picks:
--
--   * a down is "the taste": his hand clamps over your face and he lifts you
--     by the collar, legs kicking; his head tips, he sniffs; the grin tears
--     open and the jaw drops; he lunges at your shoulder, and your screen
--     cuts to black on the crunch. You come to on the floor, him standing
--     over you wiping his mouth.
--   * the last (you're Lost) is "the taking" (the owner's own, 2026-10-15:
--     "he could bend down and grab you by the ankle and slam you to the
--     ground and then drag you away"): he drops and takes your ankle, one
--     heave tears your feet from under you and you hang upside down from his
--     raised hand; he swings you up and drives you down flat on the floor,
--     then turns his back and drags you off by that ankle into the dark.
--   * how it starts depends on how he caught you: face to face, from behind
--     (his hand over your face, yanked back off your feet and turned round),
--     or out of a hiding place (hauled out by the collar).
--
-- Moderate (Roblox's content maturity): realistic but never graphic. No
-- hand round the throat (a hanging is 18+), no wound, nothing near the
-- camera: the brutality is force, sound, his face and the cut to black.
--
-- Alive, not keyframed (the owner: "make sure the animations look alive and
-- fluid"): every move eases in and out, the snaps overshoot and settle, hits
-- ring down like springs, a body falls as bodies fall, the struggle comes in
-- irregular bursts, and he breathes. Each beat starts exactly where the last
-- one left off, so nothing jumps (tests/specs/Takedown measures it).
--
-- Pure maths, no engine types: every client poses both bodies from the same
-- timeline (Controllers/TakedownController), the server times its holds from
-- it (StalkerService:_takedown), and lune tests it. Everything is in the
-- stage's frame: its origin on the floor under the one he caught, -Z towards
-- him, +Y up (CFrame.lookAt from the victim to him). A frame is Kinematics'
-- { r = rotation, p = { x, y, z } }; joint values are PlayerPose's (the
-- victim) and GuestPose's (him).

local GuestPose = require(script.Parent.GuestPose)
local Kinematics = require(script.Parent.Kinematics)
local PlayerPose = require(script.Parent.PlayerPose)

local K = Kinematics
local GRig = GuestPose.Rig
local PRig = PlayerPose.Rig

local Takedown = {}

Takedown.Kinds = { Taste = "taste", Taking = "taking" }
Takedown.Openings = { Front = "front", Behind = "behind", Hiding = "hiding" }

-- How far he holds you (his root to the spot under you): out at arm's length
-- (`distance`, or the spec's own `hold` where the room is too tight), then
-- stepping in to bring his face to yours (`look`), lunging in for the bite
-- (`bite`), and standing over you after (`after`). How high you're lifted,
-- and how far towards him.
Takedown.Hold = { distance = 4.3, look = 2.6, bite = 2.05, after = 3.9, lift = 1.3, pull = 0.25 }
-- The taking's drag: your ankle held at his side (`hold`: that far behind his
-- root, to its right, and high), the leg up to it, your hips hauled off the
-- floor (the trunk tipped `trunk` from upright, the leg `leg` from hanging),
-- your shoulders and head dragging; the body about `gap` behind his root. With
-- no way planned he walks this fast (studs/s) in surges with his steps, and
-- the body goes into the dark over `fade` seconds at the end.
Takedown.Drag = {
	gap = 1.7,
	speed = 3.0,
	surge = 0.16,
	steps = 1.6,
	fade = 0.6,
	hold = { 0.95, 0.45, 3.0 },
	trunk = math.rad(125),
	leg = math.rad(160),
}

-- Each opening's length, and the core's beats in seconds from the core's
-- start (the opening runs first). `black` is when your screen cuts out,
-- `wake` when you see again (on the floor).
local OPENING = { front = 0.4, behind = 0.8, hiding = 0.9 }
-- (Tight: you may see this two or three times a night; the owner, 2026-10-15:
-- "the take down scene is really long".)
local TASTE = {
	lift = { 0, 0.5 },
	look = { 0.5, 1.45 },
	sniffs = { 0.68, 0.84, 1.0 },
	tear = { 1.45, 1.82 },
	coil = { 1.75, 1.9 },
	bite = { 1.9, 2.02 },
	black = 2.0,
	worry = { 2.02, 2.32 },
	release = { 2.28, 2.42 },
	drop = { 2.38, 2.72 },
	wake = 2.85,
	wipe = { 2.85, 3.5 },
	length = 3.7,
}
-- (The owner, 2026-10-15, of the first: "the slam was actually too fast ...
-- I couldn't really feel the force behind it or the suspense", then "doesn't
-- really read like an overwhelming force that makes you feel helpless".) The
-- taking has no opening of its own face to face or from behind: his lunge for
-- your ankle is it. Out of a hiding place you're hauled out first.
local TAKING = {
	lunge = { 0, 0.3 }, -- he drops for your ankle; his hand on it at `grab`
	grab = 0.28,
	wrench = { 0.3, 0.86 }, -- your feet torn from under you, up to hang head down
	pivot = { 0.82, 1.4 }, -- turning, you hanging, to where you'll go down
	windup = { 1.3, 1.68 }, -- swung up and out, his other hand on your leg
	slam = { 1.68, 1.94 }, -- driven down, faster and faster, flat on the floor
	hit = 1.94,
	loom = { 1.94, 2.4 }, -- bent over you, looking down
	turn = { 2.4, 2.9 }, -- round, his back to you
	yank = { 2.5, 2.82 }, -- your leg hauled up to his side
	drag = 2.96,
}
local TAKING_OPENING = { front = 0, behind = 0, hiding = 0.75 }
-- (The hit-stop: everything holds this long as you hit the floor.)
local HIT = 0.07
Takedown.HitStop = HIT
-- Where he stands (studs from where you stood): crouched for your ankle
-- (`grab`), hanging you up (`stand`), the step into the slam, how far out
-- your pelvis lands, the step away as he turns; his hand as you hang (that
-- far ahead and right, that high: you hang head down at his waist, your
-- feet under a coffered ceiling's beams), and
-- swung up (`lift` ahead and right, `peak` high).
Takedown.Slam = {
	grab = 2.2,
	stand = 3.0,
	step = 0.7,
	land = 4.0,
	away = 0.6,
	reach = 1.7,
	side = 0.3,
	hang = 7.6,
	peak = 7.9,
	lift = { 0.95, 0.25 },
}
Takedown.Beats = { taste = TASTE, taking = TAKING, opening = OPENING, takingOpening = TAKING_OPENING }

local sin, cos, pi, exp = math.sin, math.cos, math.pi, math.exp

-- Curves -----------------------------------------------------------------------------

local function clamp01(x: number): number
	return math.clamp(x, 0, 1)
end

local function smooth(x: number): number
	x = clamp01(x)
	return x * x * (3 - 2 * x)
end

-- Eased progress through [a, b] (starts and stops gently).
local function seg(t: number, span): number
	local a, b = span[1], span[2]
	if b <= a then
		return t >= b and 1 or 0
	end
	return smooth((t - a) / (b - a))
end

local function lin(t: number, a: number, b: number): number
	return clamp01((t - a) / (b - a))
end

-- A snap that overshoots and settles (s: how far past).
local function backOut(x: number, s: number?): number
	x = clamp01(x)
	local k = s or 1.6
	local y = x - 1
	return 1 + y * y * ((k + 1) * y + k)
end

-- A hit that rings down: nothing before it, then a decaying swing.
local function ring(t: number, freq: number, decay: number): number
	if t <= 0 then
		return 0
	end
	return exp(-t * decay) * sin(t * freq)
end

-- Smooth and never repeating, about -1 .. 1: a living body's restlessness.
local function noise(t: number, seed: number): number
	return 0.5 * sin(t * 1.9 + seed) + 0.3 * sin(t * 3.7 + seed * 1.7) + 0.2 * sin(t * 6.1 + seed * 2.9)
end

local function lerp(a: number, b: number, k: number): number
	return a + (b - a) * k
end

-- A ring that eases in (no kick at its start).
local function ringIn(t: number, freq: number, decay: number, ramp: number): number
	return ring(t, freq, decay) * smooth(t / ramp)
end

-- Faster and faster through [a, b], stopping dead at b: a blow landing.
local function accel(t: number, span): number
	local x = lin(t, span[1], span[2])
	return x * x
end

-- A smooth curve through keys { { x, y }, ... } (x rising), level at both
-- ends (Catmull-Rom).
local function spline(keys, x: number): number
	local n = #keys
	if x <= keys[1][1] then
		return keys[1][2]
	elseif x >= keys[n][1] then
		return keys[n][2]
	end
	local i = 1
	while keys[i + 1][1] < x do
		i += 1
	end
	local function slope(j: number): number
		if j <= 1 or j >= n then
			return 0
		end
		return (keys[j + 1][2] - keys[j - 1][2]) / (keys[j + 1][1] - keys[j - 1][1])
	end
	local a, b = keys[i], keys[i + 1]
	local h = b[1] - a[1]
	local u = (x - a[1]) / h
	local u2, u3 = u * u, u * u * u
	return (2 * u3 - 3 * u2 + 1) * a[2]
		+ (u3 - 2 * u2 + u) * h * slope(i)
		+ (-2 * u3 + 3 * u2) * b[2]
		+ (u3 - u2) * h * slope(i + 1)
end

local function lerp3(a, b, k: number)
	return { lerp(a[1], b[1], k), lerp(a[2], b[2], k), lerp(a[3], b[3], k) }
end

local function zero()
	return { 0, 0, 0, 0, 0, 0 }
end

-- Between two joint values: the turn itself, along its shortest way (mixing
-- the three angles one by one swings a limb the wrong way round when the two
-- are far apart), and the offsets in a line.
local mixAxis -- (set below, once the rotation helpers are defined)
local function mix(va, vb, k: number)
	if k <= 0 then
		return va
	elseif k >= 1 then
		return vb
	end
	local ra, rb = K.rot(va[1], va[2], va[3]), K.rot(vb[1], vb[2], vb[3])
	local axis, angle = mixAxis(K.mul(K.transpose(ra), rb))
	local rx, ry, rz = K.euler(K.mul(ra, K.axisAngle(axis, angle * k)))
	return {
		rx,
		ry,
		rz,
		va[4] + (vb[4] - va[4]) * k,
		va[5] + (vb[5] - va[5]) * k,
		va[6] + (vb[6] - va[6]) * k,
	}
end

-- Blend two sets of joint values, joint by joint.
local function blend(a, b, k: number)
	if k <= 0 then
		return a
	elseif k >= 1 then
		return b
	end
	local out = {}
	for name, va in a do
		out[name] = mix(va, b[name] or zero(), k)
	end
	for name, vb in b do
		if not out[name] then
			local v = {}
			for i = 1, 6 do
				v[i] = vb[i] * k
			end
			out[name] = v
		end
	end
	return out
end
Takedown.blend = blend
Takedown.mix = mix

local function joint(rx: number, ry: number?, rz: number?)
	return { rx, ry or 0, rz or 0, 0, 0, 0 }
end

local function add(values, name: string, rx: number, ry: number?, rz: number?)
	local v = values[name]
	values[name] = { v[1] + rx, v[2] + (ry or 0), v[3] + (rz or 0), v[4], v[5], v[6] }
end

-- The facing yaw for a flat direction (CFrame.Angles(0, yaw, 0) looks along it).
local function yawOf(dx: number, dz: number): number
	return math.atan2(-dx, -dz)
end
Takedown.yawOf = yawOf

local function frame(yaw: number, pitch: number, x: number, y: number, z: number, roll: number?)
	return { r = K.mul(K.rot(0, yaw, 0), K.rot(pitch, 0, roll or 0)), p = { x, y, z } }
end

local function flatUnit(x: number, z: number)
	local l = math.sqrt(x * x + z * z)
	if l < 1e-6 then
		return 0, -1
	end
	return x / l, z / l
end

-- A rotation's axis and angle (the angle in [0, pi]).
local function axisAngleOf(m)
	local c = math.clamp((m[1][1] + m[2][2] + m[3][3] - 1) / 2, -1, 1)
	local angle = math.acos(c)
	if angle < 1e-6 then
		return { 0, 1, 0 }, 0
	end
	local x, y, z = m[3][2] - m[2][3], m[1][3] - m[3][1], m[2][1] - m[1][2]
	local l = math.sqrt(x * x + y * y + z * z)
	if l < 1e-6 then
		-- Half a turn: the axis from the diagonal.
		local xx = math.sqrt(math.max(0, (m[1][1] + 1) / 2))
		local yy = math.sqrt(math.max(0, (m[2][2] + 1) / 2))
		local zz = math.sqrt(math.max(0, (m[3][3] + 1) / 2))
		if xx >= yy and xx >= zz then
			return { xx, m[1][2] / (2 * xx), m[1][3] / (2 * xx) }, angle
		elseif yy >= zz then
			return { m[1][2] / (2 * yy), yy, m[2][3] / (2 * yy) }, angle
		end
		return { m[1][3] / (2 * zz), m[2][3] / (2 * zz), zz }, angle
	end
	return { x / l, y / l, z / l }, angle
end

-- From one frame to another along the shortest turn (`k` 0 .. 1; the turn
-- and the move may be eased apart with `kr`).
mixAxis = axisAngleOf

local function slerpFrame(a, b, k: number, kr: number?)
	local r = kr or k
	if k <= 0 and r <= 0 then
		return a
	elseif k >= 1 and r >= 1 then
		return b
	end
	local axis, angle = axisAngleOf(K.mul(K.transpose(a.r), b.r))
	return { r = K.mul(a.r, K.axisAngle(axis, angle * r)), p = lerp3(a.p, b.p, k) }
end
Takedown.slerpFrame = slerpFrame

-- Turn a frame by small angles about its own axes, and move it.
local function nudge(f, pitch: number, yaw: number, roll: number, dx: number?, dy: number?, dz: number?)
	return {
		r = K.mul(f.r, K.rot(pitch, yaw, roll)),
		p = { f.p[1] + (dx or 0), f.p[2] + (dy or 0), f.p[3] + (dz or 0) },
	}
end

-- Lying on your back on the way out (wx, wz the way): the head back the way
-- you came, the front to the ceiling, the back on the floor.
local function supine(x: number, z: number, wx: number, wz: number)
	local y = { -wx, 0, -wz }
	local back = { 0, -1, 0 }
	local side = K.cross(y, back)
	return {
		r = {
			{ side[1], y[1], back[1] },
			{ side[2], y[2], back[2] },
			{ side[3], y[3], back[3] },
		},
		p = { x, 0.55, z },
	}
end

-- The victim -----------------------------------------------------------------------

local victimArmTo

local VICTIM_JOINTS = {
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
Takedown.VictimJoints = VICTIM_JOINTS

local function stand()
	local v = {}
	for _, name in VICTIM_JOINTS do
		v[name] = zero()
	end
	return v
end

-- A flinch: shoulders up, hands half raised, weight back on the heels.
local function flinch()
	local v = stand()
	v.Neck = joint(0.2)
	v.Waist = joint(0.1)
	v.LeftShoulder = joint(1.2, 0, 0.35)
	v.RightShoulder = joint(1.35, 0, -0.35)
	v.LeftElbow = joint(1.7)
	v.RightElbow = joint(1.6)
	v.LeftHip = joint(0.12)
	v.RightHip = joint(-0.05)
	v.LeftKnee = joint(-0.3)
	v.RightKnee = joint(-0.15)
	return v
end

-- Held up by the face: legs kicking under you, both hands tearing at his
-- wrist, twisting. `fight` 1 thrashing .. 0 limp; `aside` is his hand
-- shoving your head over to bare the shoulder. The struggle comes in bursts,
-- never the same twice (global time `t`).
local function held(t: number, fight: number, aside: number)
	local v = stand()
	local burst = 0.55 + 0.45 * sin(t * 2.3 + 0.4) ^ 2
	local f = fight * burst
	local kickL = (0.6 * sin(t * 10.5) + 0.25 * sin(t * 16.9 + 1.3) + 0.3 * sin(t * 4.1 + 0.2)) * f
	local kickR = (0.6 * sin(t * 9.7 + 2.1) + 0.25 * sin(t * 15.3 + 0.4) + 0.3 * sin(t * 4.6 + 1.7)) * f
	-- (Kicking back more than forward: forward, the shins went into his coat.)
	v.LeftHip = joint(0.06 + 0.3 * kickL - 0.12 * math.max(0, -kickL), 0, -0.08 - 0.06 * fight)
	v.RightHip = joint(0.06 + 0.3 * kickR - 0.12 * math.max(0, -kickR), 0, 0.08 + 0.06 * fight)
	v.LeftKnee = joint(-0.3 - 0.55 * math.max(0, -kickL) - 0.15 * fight)
	v.RightKnee = joint(-0.3 - 0.55 * math.max(0, -kickR) - 0.15 * fight)
	v.LeftAnkle = joint(0.45 + 0.2 * kickL)
	v.RightAnkle = joint(0.45 + 0.2 * kickR)
	-- Both hands at his wrist, tugging in turn.
	local tug = (0.5 * sin(t * 7.3) + 0.25 * sin(t * 12.1 + 0.8)) * f
	v.LeftShoulder = joint(lerp(1.0, 2.3, fight) + 0.2 * tug, 0.1 * fight, lerp(0.15, 0.5, fight))
	v.RightShoulder = joint(lerp(0.9, 2.25, fight) - 0.2 * tug, -0.1 * fight, -lerp(0.15, 0.5, fight))
	v.LeftElbow = joint(lerp(0.25, 1.45, fight) + 0.3 * math.max(0, tug))
	v.RightElbow = joint(lerp(0.2, 1.45, fight) + 0.3 * math.max(0, -tug))
	v.LeftWrist = joint(0.35 * fight)
	v.RightWrist = joint(0.35 * fight)
	v.Waist = joint(0.05 + 0.05 * kickL, 0.16 * noise(t * 1.6, 1) * f, 0.07 * noise(t * 1.3, 2) * f)
	-- The head: a little back in his grip, shoved over to its left by the
	-- tear (baring the right shoulder he bites), jerking as you fight.
	v.Neck = joint(
		0.12 + 0.06 * noise(t * 2.2, 3) * f - 0.1 * aside,
		0.3 * aside + 0.08 * noise(t * 1.8, 4) * f,
		0.6 * aside + 0.06 * noise(t * 2.6, 5) * f
	)
	return v
end

-- Thrown about at the bite: everything flung out for a moment.
local function spasm(v, k: number)
	if k <= 0 then
		return v
	end
	local out = table.clone(v)
	add(out, "LeftShoulder", 0.5 * k, 0, 0.6 * k)
	add(out, "RightShoulder", 0.45 * k, 0, -0.6 * k)
	add(out, "LeftElbow", -0.6 * k)
	add(out, "RightElbow", -0.6 * k)
	add(out, "Waist", 0.3 * k)
	add(out, "LeftHip", 0.3 * k)
	add(out, "RightHip", 0.2 * k)
	add(out, "LeftKnee", -0.5 * k)
	add(out, "RightKnee", -0.3 * k)
	return out
end

-- Falling: limbs trailing up from a body dropping away.
local function falling()
	local v = stand()
	v.LeftShoulder = joint(2.4, 0, 0.6)
	v.RightShoulder = joint(2.2, 0, -0.7)
	v.LeftElbow = joint(0.5)
	v.RightElbow = joint(0.7)
	v.LeftHip = joint(0.6, 0, -0.15)
	v.RightHip = joint(0.3, 0, 0.12)
	v.LeftKnee = joint(-0.9)
	v.RightKnee = joint(-0.5)
	v.Neck = joint(-0.3)
	return v
end

-- Face down on the floor, as Controllers/PoseController lays a downed body
-- (so the hand-over is seamless).
local function proneJoints()
	local p = PlayerPose.prone(0, 0)
	p.Root = nil
	return p
end

-- Landed: limbs bouncing once and settling, then a few weak twitches that
-- die away by `still` (the downed pose exactly).
local function landed(since: number, still: number)
	local v = proneJoints()
	local b = ring(since, 17, 7)
	local twitch = math.max(0, 1 - since / math.max(still, 0.01)) ^ 2
	add(v, "LeftShoulder", 0.25 * b + 0.06 * noise(since * 4, 6) * twitch, 0, 0.15 * b)
	add(v, "RightShoulder", -0.2 * b + 0.06 * noise(since * 4, 7) * twitch, 0, -0.15 * b)
	add(v, "LeftHip", 0.2 * b + 0.05 * noise(since * 5, 8) * twitch)
	add(v, "RightHip", -0.15 * b)
	add(v, "LeftKnee", -0.3 * b)
	add(v, "Neck", -0.35 * b + 0.08 * noise(since * 3, 9) * twitch)
	return v
end

-- On your back, dragged by the left ankle (on his right, as you lie with
-- your feet to him: his right hand takes it without reaching across him):
-- the leg up in his hand, the other kicking, your arms clawing back over your
-- head at the boards, your head lifting to see where you're going.
local function dragged(t: number, fight: number, legUp: number)
	local v = stand()
	local claw = 0.7 * sin(t * 6.3) + 0.3 * sin(t * 9.1 + 1)
	local claw2 = 0.7 * sin(t * 5.7 + 2.2) + 0.3 * sin(t * 8.3 + 0.3)
	v.LeftHip = joint(lerp(0.25, 1.35, legUp), 0, -0.05)
	v.LeftKnee = joint(lerp(-0.5, -0.08, legUp))
	v.LeftAnkle = joint(0.1)
	v.RightHip = joint(0.3 + 0.35 * noise(t * 2.5, 11) * fight, 0, 0.12)
	v.RightKnee = joint(-0.7 - 0.4 * math.max(0, noise(t * 2.5, 12)) * fight)
	v.LeftShoulder = joint(2.6 + 0.5 * claw * fight, 0, 0.3 + 0.1 * claw2)
	v.RightShoulder = joint(2.6 + 0.5 * claw2 * fight, 0, -0.3 - 0.1 * claw)
	v.LeftElbow = joint(0.5 + 0.6 * math.max(0, -claw) * fight)
	v.RightElbow = joint(0.5 + 0.6 * math.max(0, -claw2) * fight)
	v.LeftWrist = joint(0.4)
	v.RightWrist = joint(0.4)
	v.Neck = joint(-0.5 - 0.2 * noise(t * 1.7, 13) * fight, 0.25 * noise(t * 1.2, 14) * fight)
	v.Waist = joint(-0.12, 0.15 * noise(t * 1.4, 15) * fight)
	return v
end

Takedown.dragged = dragged

-- A part one joint down: the parent part's frame, out to the joint (a0 on
-- the parent), turned by the joint's value, back to the child's centre (a1).
local function partChild(parent, a0, value, a1)
	local j = K.compose(K.compose(parent, K.frame(nil, a0)), K.joint(value))
	return K.compose(j, K.frame(nil, { -a1[1], -a1[2], -a1[3] }))
end

-- Where the victim's face, collar, right shoulder (the one he bites) and left
-- knee and ankle (the one he drags) are (stage space), for a pelvis frame
-- (the LowerTorso's) and joint values.
function Takedown.victimPoints(pelvis, joints)
	local upper = partChild(pelvis, PRig.Waist.a0, joints.Waist, PRig.Waist.a1)
	local head = partChild(upper, PRig.Neck.a0, joints.Neck, PRig.Neck.a1)
	local thigh = partChild(pelvis, PRig.LeftHip.a0, joints.LeftHip, PRig.LeftHip.a1)
	local shin = partChild(thigh, PRig.LeftKnee.a0, joints.LeftKnee, PRig.LeftKnee.a1)
	return {
		head = head.p,
		face = K.point(head, { 0, 0.05, -0.62 }),
		collar = K.point(upper, { 0, 0.45, -0.52 }),
		shoulder = K.point(upper, { 0.62, 0.78, -0.1 }),
		knee = K.point(thigh, PRig.LeftKnee.a0),
		ankle = K.point(shin, PRig.LeftAnkle.a0),
		up = K.apply(head.r, { 0, 1, 0 }),
		forward = K.apply(head.r, { 0, 0, -1 }),
		right = K.apply(head.r, { 1, 0, 0 }),
	}
end

-- A downed body's pelvis (face down) for a root part standing at `rootY` over
-- the floor, facing `yaw`, at (x, z): Logic/PlayerPose.prone's Root value
-- through the rig's root joint (a0 on the root, a1 on the LowerTorso).
function Takedown.proneRest(yaw: number, x: number, z: number, rootY: number?, a0, a1)
	a0 = a0 or PRig.Root.a0
	a1 = a1 or PRig.Root.a1
	local root = frame(yaw, 0, x, rootY or PRig.rootY, z)
	local value = PlayerPose.prone(0, 0).Root
	return partChild(root, a0, value, a1)
end

-- Where a flung arm's elbow points (shoulder space): carried by the shortest
-- turn from the arm held out to its side, the elbow down and back (only an
-- arm straight across the chest leaves it nowhere, and the arms are kept
-- from there).
local function swungPole(side: string, dir)
	local sign = side == "Left" and -1 or 1
	local r0 = K.unit({ sign * 0.95, 0, 0.3 })
	local e0 = K.unit({ -sign * 0.25, -0.6, 0.76 })
	local axis = K.cross(r0, dir)
	local sn, cs = K.length(axis), K.dot(r0, dir)
	if sn < 1e-6 then
		return e0
	end
	return K.apply(K.axisAngle(K.scale(axis, 1 / sn), math.atan2(sn, cs)), e0)
end

-- A victim's arm reaching so its palm is at `target` (stage space), blended
-- in by `weight` (`swung`: an arm flung about, its elbow wherever the swing
-- carries it). Solved exactly for the R15 arm, which hangs from the
-- shoulder joint's outer corner (the upper bone runs out and down from it,
-- the forearm and hand straight down from the elbow): the elbow's bend from
-- the reach, then the shortest turn onto the target, then a twist about it
-- so the elbow points down and out. Continuous, so it never hops.
function victimArmTo(joints, pelvis, side: string, target, weight: number, swung: boolean?)
	local upper = partChild(pelvis, PRig.Waist.a0, joints.Waist, PRig.Waist.a1)
	local sr, er, wr = PRig[side .. "Shoulder"], PRig[side .. "Elbow"], PRig[side .. "Wrist"]
	local pivot = K.compose(upper, K.frame(nil, sr.a0))
	local want = K.toLocal(pivot, target)
	local u0 = { er.a0[1] - sr.a1[1], er.a0[2] - sr.a1[2], er.a0[3] - sr.a1[3] }
	local L = (er.a1[2] - wr.a0[2]) + (wr.a1[2] + 0.15)
	local uu = K.dot(u0, u0)
	local lo = math.sqrt(math.max(0, uu + L * L - 2 * L * u0[2] * math.cos(0.15)))
	local hi = math.sqrt(math.max(0, uu + L * L - 2 * L * u0[2] * math.cos(2.5)))
	local dmin, dmax = math.min(lo, hi), math.max(lo, hi)
	-- (A target nearly on the shoulder can't be reached, and its direction
	-- swings wildly: the hand lets it go before it gets there. Nor one out of
	-- reach: the arm doesn't snap straight after it. A flung arm's reach is
	-- kept in range by its caller.)
	if not swung then
		weight *= smooth((K.length(want) - dmin) / 0.45)
		weight *= smooth((dmax + 0.2 - K.length(want)) / 0.5)
	end
	if weight <= 0 then
		return
	end
	local d = math.clamp(K.length(want), dmin + 1e-3, dmax - 1e-3)
	local c = math.clamp((d * d - uu - L * L) / (-2 * L * u0[2]), -1, 1)
	local fold = math.clamp(math.acos(c), 0.15, 2.5)
	local v = { u0[1], u0[2] - L * math.cos(fold), u0[3] - L * math.sin(fold) }
	-- The turn that lays the arm's own frame (the reach, and the way the
	-- elbow sits off it) onto the target's (the line to it, and the pole):
	-- built from both directions at once, so no reach flips it.
	local vh = K.unit(v)
	local wh = K.unit(K.sub(u0, K.scale(vh, K.dot(u0, vh))))
	local dir = K.unit(want)
	local pole = side == "Left" and { -0.6, -1, 0.35 } or { 0.6, -1, 0.35 }
	if swung then
		pole = swungPole(side, dir)
	end
	local q = K.sub(pole, K.scale(dir, K.dot(pole, dir)))
	if K.length(q) < 1e-3 then
		q = K.sub({ 0, 0, 1 }, K.scale(dir, dir[3]))
	end
	local ph = K.unit(q)
	local sx, tx = K.cross(vh, wh), K.cross(dir, ph)
	-- R = [dir ph tx] * [vh wh sx]^T
	local r = {}
	for i = 1, 3 do
		r[i] = {}
		for j = 1, 3 do
			r[i][j] = dir[i] * vh[j] + ph[i] * wh[j] + tx[i] * sx[j]
		end
	end
	local rx, ry, rz = K.euler(r)
	joints[side .. "Shoulder"] = mix(joints[side .. "Shoulder"], { rx, ry, rz, 0, 0, 0 }, weight)
	joints[side .. "Elbow"] = mix(joints[side .. "Elbow"], { fold, 0, 0, 0, 0, 0 }, weight)
end

-- Him ------------------------------------------------------------------------------

local GUEST_LEGS = { "Root", "LeftHip", "LeftKnee", "LeftAnkle", "RightHip", "RightKnee", "RightAnkle" }
local SHOULDER = GuestPose.ShoulderOffset
local WAIST = GuestPose.WaistOffset
local NECK = GuestPose.NeckOffset

local function guestFrame(root)
	return { r = K.rot(0, root.yaw, 0), p = { root.x, GRig.rootY, root.z } }
end

-- One of his arms reaching so its wrist is at `wrist` (stage space), the
-- fingers pointing along `fingers` and curling towards `curl`, the elbow
-- towards `pole` (his body space). Writes the shoulder, elbow and wrist.
local function armTo(values, side: string, root, wrist, curl, fingers, pole)
	local rf = guestFrame(root)
	local back = K.transpose(rf.r)
	local target = K.toLocal(rf, wrist)
	local pelvis = GuestPose.pelvisFrame(values.Root)
	local chest = K.child(pelvis, WAIST, values.Waist)
	local shoulder = K.compose(chest, K.frame(nil, SHOULDER[side]))
	local inShoulder = K.toLocal(shoulder, target)
	-- (Never locked straight: a straight arm leaves the elbow nowhere to
	-- point, and the solver flips it from one side to the other.)
	local most = (GRig.upperArm + GRig.lowerArm) * 0.95
	-- (Nor folded shut: a hand right at the shoulder leaves it nowhere either.)
	local least = 1.1
	local d = K.length(inShoulder)
	if d > most then
		inShoulder = K.scale(inShoulder, most / d)
	elseif d < least and d > 1e-4 then
		inShoulder = K.scale(inShoulder, least / d)
	end
	local poleL = K.apply(K.transpose(shoulder.r), pole)
	local rx, ry, rz, fold, r = K.twoBone(inShoulder, GRig.upperArm, GRig.lowerArm, 1, poleL)
	local inward = side == "Left" and 1 or -1
	local want = K.basis(K.scale(K.apply(back, curl), inward), K.scale(K.apply(back, fingers), -1))
	local arm = K.mul(K.mul(shoulder.r, r), K.rot(fold, 0, 0))
	local wx, wy, wz = K.euler(K.mul(K.transpose(arm), want))
	values[side .. "Shoulder"] = { rx, ry, rz, 0, 0, 0 }
	values[side .. "Elbow"] = { fold, 0, 0, 0, 0, 0 }
	values[side .. "Wrist"] = { wx, wy, wz, 0, 0, 0 }
end

-- An arm's values reaching, blended in by `weight` over what it was doing.
local function reach(values, side: string, root, wrist, curl, fingers, pole, weight: number)
	if weight <= 0 then
		return
	end
	local reached = table.clone(values)
	armTo(reached, side, root, wrist, curl, fingers, pole)
	for _, name in { side .. "Shoulder", side .. "Elbow", side .. "Wrist" } do
		values[name] = mix(values[name], reached[name], math.min(weight, 1))
	end
end

-- The angles that turn his head from its neck to look at `target` (stage
-- space), for his root and the spine he has.
local function aim(values, root, target): (number, number)
	local rf = guestFrame(root)
	local pelvis = GuestPose.pelvisFrame(values.Root)
	local chest = K.child(pelvis, WAIST, values.Waist)
	local neck = K.compose(chest, K.frame(nil, NECK))
	local rel = K.toLocal(neck, K.toLocal(rf, target))
	-- (Something right under his chin: look down at it, never flip round.)
	if rel[3] > -0.35 then
		rel = { rel[1], rel[2], -0.35 }
	end
	return GuestPose.gazeAngles(rel[1], rel[2], rel[3])
end

-- Where one of his elbows is (his root space) for joint values.
function Takedown.guestElbow(values, side: string)
	local pelvis = GuestPose.pelvisFrame(values.Root)
	local chest = K.child(pelvis, WAIST, values.Waist)
	local shoulder = K.child(chest, SHOULDER[side], values[side .. "Shoulder"])
	return K.point(shoulder, { 0, -GRig.upperArm, 0 })
end

-- One of his arms reaching a point given in his root's own space (x right,
-- y up from the root's centre, z back), blended in by `weight`: for the drag,
-- where he runs by his own legs (Controllers/TakedownController).
function Takedown.reachLocal(values, side: string, target, curl, fingers, pole, weight: number)
	local root = { x = 0, z = 0, yaw = 0 }
	reach(values, side, root, { target[1], target[2] + GRig.rootY, target[3] }, curl, fingers, pole, weight)
end

-- Where his face is (stage space) for a root and joint values.
function Takedown.guestFace(root, values)
	local _, middle = GuestPose.head(values)
	return K.point(guestFrame(root), middle)
end

-- The way out (the taking) ------------------------------------------------------------

-- A point and the way along a path of { x, z } points at distance `s` (the
-- way is the chord over a stud each side, so it turns round a corner rather
-- than snapping).
local function pointAt(path, s: number)
	local walked = 0
	for i = 1, #path - 1 do
		local a, b = path[i], path[i + 1]
		local dx, dz = b[1] - a[1], b[2] - a[2]
		local l = math.sqrt(dx * dx + dz * dz)
		if l > 1e-6 and (s <= walked + l or i == #path - 1) then
			local k = math.clamp((s - walked) / l, 0, 1)
			return a[1] + dx * k, a[2] + dz * k, dx / l, dz / l
		end
		walked += l
	end
	local last = path[#path] or { 0, 0 }
	return last[1], last[2], 0, -1
end

local function along(path, s: number)
	local x, z, tx, tz = pointAt(path, s)
	local ax, az = pointAt(path, s - 1)
	local bx, bz = pointAt(path, s + 1)
	local cx, cz = bx - ax, bz - az
	local l = math.sqrt(cx * cx + cz * cz)
	if l > 1e-3 then
		tx, tz = cx / l, cz / l
	end
	return x, z, tx, tz
end

function Takedown.pathLength(path): number
	local total = 0
	for i = 1, #(path or {}) - 1 do
		local a, b = path[i], path[i + 1]
		total += math.sqrt((b[1] - a[1]) ^ 2 + (b[2] - a[2]) ^ 2)
	end
	return total
end

-- The spec -------------------------------------------------------------------------

-- Fills a spec's gaps. A spec (from the server, sent to every client):
--   kind      "taste" or "taking"
--   opening   "front", "behind" or "hiding"
--   guest     { x, z }: his root at the catch, stage space (default in front)
--   from      { x, z }: where the victim starts (inside the hiding place)
--   yaw       the victim's facing at the catch (0: towards him; pi: away)
--   pelvis    the victim's standing pelvis height (the LowerTorso's centre)
--   rest      the downed pelvis frame where the taste leaves them (default:
--             face down at his feet)
--   slam      the taking: the way he slams you down ({ x, z }: where your head
--             goes; default straight on, away from him)
--   way       the taking: the way he drags you off ({ x, z }; default back the
--             way the slam came); `path` (the way out, from where the drag
--             starts) is made from it
--   live      the taking: the drag is his own run through the house
--   form      his form (0 Calm, 1 Fraying, 2 Breaking)
function Takedown.fill(spec)
	local s = table.clone(spec or {})
	s.kind = s.kind == "taking" and "taking" or "taste"
	s.opening = OPENING[s.opening or ""] and s.opening or "front"
	s.guest = s.guest or { 0, -Takedown.Hold.distance }
	s.hold = math.clamp(s.hold or Takedown.Hold.distance, Takedown.Hold.look, Takedown.Hold.distance)
	s.from = s.from or { 0, 0 }
	-- (Normalised, so a turn to face him is the short way round.)
	local yaw = s.yaw or (s.opening == "behind" and pi or 0)
	s.yaw = math.atan2(sin(yaw), cos(yaw))
	s.pelvis = s.pelvis or (PRig.rootY + PRig.Root.a0[2] - PRig.Root.a1[2])
	s.form = s.form or 0
	if s.kind == "taste" and not s.rest then
		-- Face down at his feet: the server turns the root part to face him
		-- (StalkerService:_takedown), so a downed body lies that way after.
		s.rest = Takedown.proneRest(0, 0, 0)
	end
	if s.kind == "taking" then
		s._geo = nil
		local dx, dz = flatUnit(s.guest[1], s.guest[2])
		local ux, uz = flatUnit((s.slam or { -dx, -dz })[1], (s.slam or { -dx, -dz })[2])
		s.slam = { ux, uz }
		local wx, wz = flatUnit((s.way or { -ux, -uz })[1], (s.way or { -ux, -uz })[2])
		s.way = { wx, wz }
		-- (The drag's start: yanked to his heels as he turns to go.)
		local Lp = Takedown.layout(s).Lp
		local reach = Takedown.Drag.gap + 4
		s.path = { Lp, { Lp[1] + wx * reach, Lp[2] + wz * reach } }
	end
	return s
end

function Takedown.openingLength(spec): number
	if spec.kind == "taking" then
		return TAKING_OPENING[spec.opening] or 0
	end
	return OPENING[spec.opening] or OPENING.front
end

function Takedown.dragSeconds(spec): number
	local d = Takedown.Drag
	return math.max(0, Takedown.pathLength(spec.path) - d.gap) / d.speed
end

-- How long it runs, all told.
function Takedown.length(spec): number
	local open = Takedown.openingLength(spec)
	if spec.kind == "taking" and spec.live then
		-- (From there he runs his own way through the house: StalkerService.)
		return open + TAKING.drag + HIT
	elseif spec.kind == "taking" then
		return open + TAKING.drag + HIT + Takedown.dragSeconds(spec) + 0.2
	end
	return open + TASTE.length
end

-- Named moments (seconds from the start): when your screen cuts and comes
-- back, when the camera changes, when the body has gone.
function Takedown.marks(spec)
	local open = Takedown.openingLength(spec)
	if spec.kind == "taking" then
		local finish = Takedown.length(spec)
		return {
			grab = open + TAKING.grab,
			slam = open + TAKING.hit,
			turn = open + TAKING.turn[1] + 0.12 + HIT,
			drag = open + TAKING.drag + HIT,
			fade = finish - Takedown.Drag.fade,
			finish = finish,
		}
	end
	return {
		close = open + TASTE.look[1] + 0.1,
		tear = open + TASTE.tear[1],
		bite = open + TASTE.bite[1],
		black = open + TASTE.black,
		wake = open + TASTE.wake,
		finish = open + TASTE.length,
	}
end

-- When the lens should jolt, and how hard (studs): { { t, size } }. His hand
-- landing on your face; or his hand on your ankle, the top of the heave, and
-- the slam into the floor (hard: the camera's own dip comes with it).
function Takedown.impacts(spec)
	if spec.kind == "taking" then
		local open = Takedown.openingLength(spec)
		return {
			{ open + TAKING.grab, 0.06 },
			{ open + TAKING.wrench[2] - 0.06, 0.05 },
			{ open + TAKING.hit, 0.45 },
		}
	end
	local grab = spec.opening == "front" and 0.16 or (spec.opening == "behind" and 0.18 or 0.24)
	return { { grab, 0.05 } }
end

-- What the victim's camera should be doing (Controllers/TakedownController
-- frames each from the scene): "pair" (the two of you), "face" (close on
-- his), "black", "floor" (from the floor, looking up at him), "grab" and
-- "slam" (low, from the side: the taking, side on to how you're torn off
-- your feet, then to how you're slammed), "drag" (low, watching you go),
-- and how black your screen is.
function Takedown.shot(spec, t: number): (string, number)
	local m = Takedown.marks(spec)
	if spec.kind == "taking" then
		-- (A live drag fades on its own time: Controllers/TakedownController.)
		local black = spec.live and 0 or clamp01((t - m.fade) / Takedown.Drag.fade)
		-- Dazed: your sight dims for a moment just after you hit the floor.
		local since = (t - m.slam - HIT) / 0.4
		if since > 0 and since < 1 then
			local dim = since < 0.2 and since / 0.2 or 1 - smooth((since - 0.2) / 0.8)
			black = math.max(black, 0.75 * dim)
		end
		-- (Cut to the low shot as he turns to go: his back to the lens, you
		-- behind him, would be hidden. If he turns you round before the slam,
		-- being torn off your feet has a shot of its own, side on to it; the
		-- cut comes as you hang, before he turns.)
		local layout = Takedown.layout(spec)
		-- (Slammed down along the way out, the slam's own shot sees him turn
		-- and haul you up side on; else his back would hide you from it.)
		local along = -(layout.way[1] * layout.u1[1] + layout.way[2] * layout.u1[2]) >= 0.8
		if t >= (along and m.drag or m.turn) then
			return "drag", black
		end
		local turned = layout.u0[1] * layout.u1[1] + layout.u0[2] * layout.u1[2] < 0.9
		return (turned and t < Takedown.openingLength(spec) + TAKING.wrench[2] + 0.04) and "grab" or "slam", black
	end
	-- (Wide for the grab and the lift; close on his face once he draws you
	-- up to it: that close, your head would hide his from the side.)
	if t < m.close then
		return "pair", 0
	elseif t < m.black then
		return "face", 0
	elseif t < m.wake then
		return "black", 1
	end
	return "floor", 1 - clamp01((t - m.wake) / 0.35)
end

-- What's heard and when: { t, key, at ("guest", "victim" or "mouth"),
-- volume, pitch, stop? (seconds it plays before it's cut) }. `voice` picks
-- the scream ("Male"/"Female").
function Takedown.cues(spec, voice: string?)
	local open = Takedown.openingLength(spec)
	local scream = "TakedownScream" .. (voice == "Female" and "Female" or "Male")
	local grab = spec.opening == "front" and 0.16 or (spec.opening == "behind" and 0.2 or 0.28)
	local list = {
		{ grab, "Thud", "victim", 0.55, 1.25 },
		{ 0.02, "GuestRasp", "guest", 0.75, 0.95 },
		{ grab + 0.04, "Gasp", "victim", 0.9, 1.1 },
	}
	if spec.opening == "hiding" then
		table.insert(list, { 0.1, "Drawer", "victim", 0.7, 0.8 })
		table.insert(list, { 0.75, "Thud", "victim", 0.5, 0.9 })
	elseif spec.opening == "behind" then
		table.insert(list, { 0.45, "Thud", "victim", 0.5, 1.1 })
	end
	if spec.kind == "taking" then
		-- (Beats after the floor come a hit-stop later.)
		local function at(beat: number): number
			return open + beat + (beat > TAKING.hit and HIT or 0)
		end
		local T = TAKING
		list = { { 0.02, "GuestRasp", "guest", 0.75, 0.95 } }
		if spec.opening == "hiding" then
			table.insert(list, { 0.1, "Drawer", "victim", 0.7, 0.8 })
		end
		table.insert(list, { at(T.grab), "Thud", "victim", 0.5, 1.35 })
		table.insert(list, { at(T.grab) + 0.03, "Gasp", "victim", 0.9, 1.1 })
		table.insert(list, { at(T.wrench[1]) + 0.12, "Thud", "victim", 0.45, 1.6 })
		table.insert(list, { at(T.wrench[1]) + 0.2, "GaspAlt", "victim", 0.9, 1.1 })
		-- (Screaming as you hang: cut off by the floor.)
		table.insert(list, { at(T.wrench[2]) - 0.05, scream, "victim", 1, 1, T.hit - T.wrench[2] + 0.06 })
		table.insert(list, { at(T.windup[1]) + 0.12, "GuestRasp", "guest", 0.95, 0.75 })
		-- The floor: a heavy thud on a deeper one, a crack under them, and a
		-- ringing in your ears (yours alone).
		table.insert(list, { at(T.hit), "Thud", "victim", 1, 0.55 })
		table.insert(list, { at(T.hit) + 0.005, "Thud", "victim", 0.9, 0.85 })
		table.insert(list, { at(T.hit) + 0.01, "TakedownCrunch", "victim", 0.5, 0.62 })
		table.insert(list, { at(T.hit) + 0.02, "DriftTinnitus", "ears", 0.45, 1, 2.6 })
		table.insert(list, { at(T.hit) + 0.45, "GaspAlt", "victim", 0.6, 0.72 })
		table.insert(list, { at(T.turn[1]) + 0.05, "GuestExhale", "guest", 0.6, 0.8 })
		table.insert(list, { at(T.yank[1]) + 0.05, scream, "victim", 0.75, 0.88, 2.2 })
		-- (On the body itself, so it travels with you.)
		local dragFor = spec.live and 8 or Takedown.dragSeconds(spec) + 0.2
		table.insert(list, { at(T.drag), "TakedownDrag", "body", 0.8, 1, dragFor })
		table.insert(list, { at(T.drag) + 1.4, "GaspAlt", "victim", 0.8, 0.9 })
	else
		table.insert(list, { open + 0.45, "GaspAlt", "victim", 0.8, 1.15 })
		for i, at in TASTE.sniffs do
			table.insert(list, { open + at, "GuestSniff", "guest", 0.55 + 0.15 * i, 1.15 - 0.1 * i })
		end
		table.insert(list, { open + 1.3, "Gasp", "victim", 0.6, 1.2 })
		table.insert(list, { open + TASTE.tear[1] + 0.02, "GuestCrack", "guest", 0.95, 0.85 })
		table.insert(list, { open + TASTE.coil[1], scream, "victim", 1, 1, TASTE.black - TASTE.coil[1] })
		table.insert(list, { open + TASTE.black, "TakedownBite", "mouth", 1, 1 })
		table.insert(list, { open + TASTE.black + 0.01, "TakedownCrunch", "mouth", 0.9, 0.9 })
		table.insert(list, { open + TASTE.drop[2] - 0.02, "Thud", "victim", 0.9, 0.8 })
		table.insert(list, { open + TASTE.wipe[1] + 0.3, "GuestExhale", "guest", 0.6, 0.8 })
	end
	table.sort(list, function(a, b)
		return a[1] < b[1]
	end)
	return list
end

-- The taking ------------------------------------------------------------------------
--
-- Your body hangs from the ankle in his hand (`A`): the left leg straight from
-- the hip to it along `phi` (0 down, pi/2 out towards him, pi up), the trunk
-- tipped back `theta` towards `u` (0 standing, pi/2 on your back with your
-- head that way, pi hanging head down) and twisted `psi` about itself, where
-- `u` is the way he faces. Your free limbs hang by what the body is doing
-- (gravity less its acceleration, a moment late), as a body's do: flung out
-- on the swing, trailing up through the slam, slapped down by it.

local LEG = (PRig.LeftHip.a1[2] - PRig.LeftKnee.a0[2]) + (PRig.LeftKnee.a1[2] - PRig.LeftAnkle.a0[2])
local GRAVITY = 60 -- what your free limbs hang by (studs/s^2; a stylised fall)
local PHI_IMPACT = math.rad(121) -- the held leg as you hit: up to his hand
local THETA_PEAK = math.rad(105) -- swung up: out in front of him, the head under level
-- Your free limbs: each a weight on a rod from where it hangs (pelvis space:
-- the hands from the shoulders, the foot from the free hip, the head from the
-- neck, the chest from the waist), swung by the body's moves and by gravity,
-- damped, and held towards where a body holds it (`tone`: the arms reach for
-- the floor, a little out to their sides, however you're turned).
local LIMBS = {
	Left = { at = { -1, 1.56, 0 }, length = 1.6, tone = 14, damp = 7, sign = -1 },
	Right = { at = { 1, 1.56, 0 }, length = 1.6, tone = 14, damp = 7, sign = 1 },
	Leg = { at = { 0.5, -0.2, 0 }, length = 1.75, rest = { 0.05, -1, -0.15 }, tone = 45, damp = 9 },
	Head = { at = { 0, 1.8, 0 }, length = 0.6, rest = { 0, 1, 0 }, tone = 110, damp = 16 },
	Chest = { at = { 0, 0.2, 0 }, length = 1.4, rest = { 0, 1, 0 }, tone = 170, damp = 22 },
}
local SWING_STEP = 1 / 240

-- Where your hands are as you brace (pelvis space): up before your face, or
-- (from behind) flung out at your sides; and hanging.
local BRACED = {
	front = { Left = { -0.85, 2.45, -0.95 }, Right = { 0.82, 2.35, -1.0 } },
	behind = { Left = { -1.45, 1.05, -0.25 }, Right = { 1.45, 1.1, -0.2 } },
	still = { Left = { -1.15, 0.45, 0 }, Right = { 1.15, 0.45, 0 } },
}

local SLAM_PIVOT = 6.2 -- (how high the arc his arm swings you down through turns about)
local LYING = 0.55 -- (the pelvis on its back on the floor; `supine`)

-- Ripped off your feet: the ankle's rise (a share of the way up to his raised
-- hand), its way across to him, the trunk's tip and the leg's swing, over the
-- wrench (0 .. 1). The leg goes first and the trunk falls after it, so you're
-- jackknifed for a moment rather than lifted upright.
local WRENCH_UP = { { 0, 0 }, { 0.25, 0.155 }, { 0.45, 0.39 }, { 0.72, 0.84 }, { 1, 1 } }
local WRENCH_OUT = { { 0, 0 }, { 0.3, 0.45 }, { 0.6, 0.85 }, { 1, 1 } }
local WRENCH_THETA = { { 0, 0 }, { 0.22, 0.7 }, { 0.45, 1.66 }, { 0.72, 2.8 }, { 1, pi } }
local WRENCH_PHI = { { 0, 0 }, { 0.22, 1.48 }, { 0.45, 2.18 }, { 0.72, 3.0 }, { 1, pi + 0.07 } }

local function wrapAngle(a: number): number
	return math.atan2(sin(a), cos(a))
end

-- The trunk tipped back `theta` towards (ux, uz) and twisted `psi` about itself.
local function trunk(ux: number, uz: number, theta: number, psi: number)
	return K.mul(K.mul(K.rot(0, math.atan2(ux, uz), 0), K.rot(theta, 0, 0)), K.rot(0, psi, 0))
end

-- The held leg's way from hip to ankle: down (phi 0), towards him (-u), up (pi).
local function legWay(ux: number, uz: number, phi: number)
	return { -sin(phi) * ux, -cos(phi), -sin(phi) * uz }
end

-- The body hung from its left ankle at `A`, the leg straight along `way`, the
-- trunk turned `R`: the pelvis frame, and the left hip's value (the thigh
-- turned from hanging straight down onto the way, the shortest turn).
local function hungFrom(A, way, R)
	local hip = K.sub(A, K.scale(way, LEG))
	local pelvis = { r = R, p = K.sub(hip, K.apply(R, PRig.LeftHip.a0)) }
	local d = K.apply(K.transpose(R), way)
	local from = { 0, -1, 0 }
	local axis = K.cross(from, d)
	local sn, cs = K.length(axis), K.dot(from, d)
	if sn < 1e-6 then
		return pelvis, zero()
	end
	local rx, ry, rz = K.euler(K.axisAngle(K.scale(axis, 1 / sn), math.atan2(sn, cs)))
	return pelvis, { rx, ry, rz, 0, 0, 0 }
end

-- Where a palm is (stage space) for a pelvis frame and joint values.
local function handOf(pelvis, joints, side: string)
	local sr, er, wr = PRig[side .. "Shoulder"], PRig[side .. "Elbow"], PRig[side .. "Wrist"]
	local upper = partChild(pelvis, PRig.Waist.a0, joints.Waist, PRig.Waist.a1)
	local arm = partChild(upper, sr.a0, joints[side .. "Shoulder"], sr.a1)
	local fore = partChild(arm, er.a0, joints[side .. "Elbow"], er.a1)
	return K.point(fore, { 0, wr.a0[2] - (wr.a1[2] + 0.15), 0 })
end

-- Dragged off by the ankle at `A` (in his hand at his side, any space), your
-- head away along (ux, uz): the leg up to his hand, your hips hauled off the
-- floor, your shoulders dragging and your arms clawing back at the boards.
-- The pelvis frame and joints (Controllers/TakedownController poses the live
-- drag with it too).
function Takedown.dragBody(A, ux: number, uz: number, t: number)
	local d = Takedown.Drag
	local theta = d.trunk + 0.05 * sin(t * 3.1)
	local phi = d.leg + 0.06 * sin(t * 2.7 + 1)
	local pelvis, hip = hungFrom(A, legWay(ux, uz, phi), trunk(ux, uz, theta, 0.12 * sin(t * 2.3 + 0.7)))
	local joints = dragged(t, 0.8, 1)
	joints.LeftHip = hip
	joints.LeftKnee = zero()
	joints.LeftAnkle = joint(0.35)
	-- (The trunk tips head down: the arms reach back over your head along
	-- the floor, not up into it.)
	local claw = 0.7 * sin(t * 6.3) + 0.3 * sin(t * 9.1 + 1)
	local claw2 = 0.7 * sin(t * 5.7 + 2.2) + 0.3 * sin(t * 8.3 + 0.3)
	joints.LeftShoulder = joint(2.0 + 0.35 * claw, 0, 0.75 + 0.1 * claw2)
	joints.RightShoulder = joint(2.0 + 0.35 * claw2, 0, -0.75 - 0.1 * claw)
	joints.Neck = joint(-0.55 - 0.15 * noise(t * 1.7, 13), 0.25 * noise(t * 1.2, 14))
	-- (The arms posed by where the hands are, as every arm in the taking is,
	-- so going from one to another never turns one the long way round.)
	for _, side in { "Left", "Right" } do
		victimArmTo(joints, pelvis, side, handOf(pelvis, joints, side), 1, true)
	end
	return pelvis, joints
end

-- Where your ankle is held as he drags you (his root `x`, `z` and facing yaw,
-- its height over his root's floor `y`).
local function dragHold(x: number, y: number, z: number, yaw: number)
	local h = Takedown.Drag.hold
	local fx, fz = -sin(yaw), -cos(yaw)
	return { x - fx * h[1] - fz * h[2], y + h[3], z - fz * h[1] + fx * h[2] }
end

-- A point beside a spot, along a facing yaw: `forward` ahead, `right` to its right.
local function beside(at, yaw: number, forward: number, right: number)
	local fx, fz = -sin(yaw), -cos(yaw)
	return { at[1] + fx * forward - fz * right, at[2] + fz * forward + fx * right }
end

-- Where everything goes, from the spec (stage space, { x, z } on the floor):
-- his stance as he grabs (Sg), hangs you up (S0) and slams (S1), and as he
-- turns to go (P); where your pelvis lands (L) and where the drag starts (Lp).
function Takedown.layout(spec)
	local S = Takedown.Slam
	local dx, dz = flatUnit(spec.guest[1], spec.guest[2])
	local ux, uz = flatUnit(spec.slam[1], spec.slam[2])
	local wx, wz = flatUnit(spec.way[1], spec.way[2])
	local S0 = { dx * S.stand, dz * S.stand }
	local S1 = { S0[1] + ux * S.step, S0[2] + uz * S.step }
	local P = { S1[1] + wx * S.away, S1[2] + wz * S.away }
	return {
		G = { spec.guest[1], spec.guest[2] },
		Sg = { dx * S.grab, dz * S.grab },
		S0 = S0,
		S1 = S1,
		P = P,
		L = { S1[1] + ux * S.land, S1[2] + uz * S.land },
		Lp = { P[1] - wx * Takedown.Drag.gap, P[2] - wz * Takedown.Drag.gap },
		u0 = { -dx, -dz },
		u1 = { ux, uz },
		way = { wx, wz },
	}
end

local function stanceAt(geo, tau: number): (number, number)
	local x, z = geo.G[1], geo.G[2]
	for _, step in geo.stance do
		local k = seg(tau, step.span)
		x, z = lerp(x, step.to[1], k), lerp(z, step.to[2], k)
	end
	return x, z
end

local function yawAt(geo, tau: number): number
	return geo.yaw0 + (geo.yaw1 - geo.yaw0) * seg(tau, TAKING.pivot) + (geo.yaw2 - geo.yaw1) * seg(tau, TAKING.turn)
end

-- A foot through its steps: where it is, which way it points, how high it's lifted.
local function footAt(foot, tau: number)
	local x, z, yaw, lift = foot.at[1], foot.at[2], foot.yaw, 0
	for _, step in foot.steps do
		local k = seg(tau, step.span)
		if k > 0 then
			x, z = lerp(x, step.to[1], k), lerp(z, step.to[2], k)
			yaw = lerp(yaw, step.yaw, k)
			lift = math.max(lift, sin(k * pi) * 0.45)
		end
	end
	return x, z, yaw, lift
end

-- Everything the taking's moments are worked out from (kept on the spec).
local function geometry(spec)
	if spec._geo then
		return spec._geo
	end
	local T = TAKING
	local S = Takedown.Slam
	local geo = Takedown.layout(spec)
	local u0x, u0z = geo.u0[1], geo.u0[2]
	local u1x, u1z = geo.u1[1], geo.u1[2]
	geo.yaw0 = yawOf(u0x, u0z)
	geo.yaw1 = geo.yaw0 + wrapAngle(yawOf(u1x, u1z) - geo.yaw0)
	-- (Turning to go, he turns to his left: your ankle in his right hand
	-- swings round outside him, never across him.)
	local turn = wrapAngle(yawOf(geo.way[1], geo.way[2]) - geo.yaw1)
	if turn < -0.6 * pi then
		turn += 2 * pi
	end
	geo.yaw2 = geo.yaw1 + turn
	geo.stance = {
		{ span = { 0.02, 0.24 }, to = geo.Sg },
		{ span = { 0.36, 0.78 }, to = geo.S0 },
		{ span = { T.windup[2] - 0.1, T.hit - 0.02 }, to = geo.S1 },
		{ span = { T.turn[1] + 0.08, T.turn[2] }, to = geo.P },
	}
	-- You, standing where he takes you: facing as you were (out of a hiding
	-- place, hauled round to him).
	geo.psi0 = spec.opening == "hiding" and 0 or wrapAngle(spec.yaw - math.atan2(u0x, u0z))
	geo.braced = BRACED[spec.opening == "behind" and "behind" or "front"]
	local standingR = trunk(u0x, u0z, 0, geo.psi0)
	local hipA0 = PRig.LeftHip.a0
	geo.grabAt = K.add(K.add({ 0, spec.pelvis, 0 }, K.apply(standingR, hipA0)), { 0, -LEG, 0 })
	-- Your ankle in his hand as you hit the floor: on your back at L, the leg
	-- up to him.
	local R = trunk(u1x, u1z, pi / 2, 0)
	local hip = K.add({ geo.L[1], LYING, geo.L[2] }, K.apply(R, hipA0))
	geo.impact = K.add(hip, K.scale(legWay(u1x, u1z, PHI_IMPACT), LEG))
	-- The slam's arc: from his hand raised high to the floor, about a point
	-- over his feet (in his slamming frame: ahead, up, right).
	local fx, fz = -sin(geo.yaw1), -cos(geo.yaw1)
	local function arcOf(point, x: number, z: number)
		local ox, oy, oz = point[1] - x, point[2] - SLAM_PIVOT, point[3] - z
		local h = ox * fx + oz * fz
		return math.sqrt(h * h + oy * oy), math.atan2(oy, h), ox * -fz + oz * fx
	end
	local x0, z0 = stanceAt(geo, T.slam[1])
	local peak = { x0 + fx * S.lift[1] - fz * S.lift[2], S.peak, z0 + fz * S.lift[1] + fx * S.lift[2] }
	local r0, a0, l0 = arcOf(peak, x0, z0)
	local r1, a1, l1 = arcOf(geo.impact, geo.S1[1], geo.S1[2])
	geo.arc = { r0 = r0, a0 = a0, l0 = l0, r1 = r1, a1 = a1, l1 = l1 }
	-- Your ankle at his side as the drag starts.
	geo.held = dragHold(geo.P[1], 0, geo.P[2], geo.yaw2)
	-- His feet: planted, stepping in for your ankle, back to hang you up,
	-- round with you, into the slam, round to go.
	local y0, y1, y2 = geo.yaw0, geo.yaw1, geo.yaw2
	local pv, tn, sl = T.pivot[1], T.turn[1], T.slam[1]
	geo.feet = {
		Right = {
			at = beside(geo.G, y0, 0, 0.36),
			yaw = y0,
			steps = {
				{ span = { 0.03, 0.2 }, to = beside(geo.Sg, y0, 0.75, 0.42), yaw = y0 },
				{ span = { 0.42, 0.66 }, to = beside(geo.S0, y0, 0.05, 0.38), yaw = y0 },
				{ span = { pv + 0.06, pv + 0.26 }, to = beside(geo.S0, y1, 0.05, 0.38), yaw = y1 },
				{ span = { sl - 0.12, sl + 0.1 }, to = beside(geo.S1, y1, 0.85, 0.42), yaw = y1 },
				{ span = { tn + 0.08, tn + 0.28 }, to = beside(geo.P, y2, 0, 0.38), yaw = y2 },
			},
		},
		Left = {
			at = beside(geo.G, y0, 0, -0.36),
			yaw = y0,
			steps = {
				{ span = { 0.1, 0.26 }, to = beside(geo.Sg, y0, -0.45, -0.42), yaw = y0 },
				{ span = { 0.54, 0.78 }, to = beside(geo.S0, y0, -0.05, -0.38), yaw = y0 },
				{ span = { pv + 0.28, pv + 0.48 }, to = beside(geo.S0, y1, -0.05, -0.38), yaw = y1 },
				{ span = { tn + 0.24, tn + 0.44 }, to = beside(geo.P, y2, 0, -0.38), yaw = y2 },
			},
		},
	}
	spec._geo = geo
	return geo
end

-- Your body hung from his hand at `tau` (between his grab and the floor):
-- the pelvis frame, the left hip's value.
local function hungBody(geo, tau: number)
	local T = TAKING
	local S = Takedown.Slam
	tau = math.clamp(tau, T.grab, T.hit)
	local gx, gz = stanceAt(geo, tau)
	local yaw = yawAt(geo, tau)
	local fx, fz = -sin(yaw), -cos(yaw)
	local rx, rz = -fz, fx
	local function held(height: number, forward: number, right: number)
		return { gx + fx * forward + rx * right, height, gz + fz * forward + rz * right }
	end
	-- Hanging from his raised hand: the weight settling into it, swinging on
	-- from the heave.
	local hang = held(S.hang - 0.14 * ringIn(tau - T.wrench[2] + 0.04, 9, 5, 0.06), S.reach, S.side)
	local swing = 0.38 * ringIn(tau - T.wrench[2] + 0.1, 6, 2.4, 0.12)
	local A, theta, phi
	local k = lin(tau, T.wrench[1], T.wrench[2])
	if k < 1 then
		local up, out = spline(WRENCH_UP, k), spline(WRENCH_OUT, k)
		local g = geo.grabAt
		A = { lerp(g[1], hang[1], out), lerp(g[2], hang[2], up), lerp(g[3], hang[3], out) }
		theta, phi = spline(WRENCH_THETA, k), spline(WRENCH_PHI, k)
	else
		A, theta, phi = hang, pi, pi + 0.07
	end
	theta += swing
	phi += swing
	-- Swung up and out in front of him, his arm drawn up and back.
	local kw = seg(tau, T.windup)
	if kw > 0 then
		A = lerp3(A, held(S.peak, S.lift[1], S.lift[2]), kw)
		theta = lerp(theta, THETA_PEAK, kw)
		phi = lerp(phi, THETA_PEAK + 0.14, kw)
	end
	-- Driven down through an arc, faster and faster: the head lags up behind
	-- the hand and then whips down after it, and you land flat.
	local ks = lin(tau, T.slam[1], T.slam[2])
	if ks > 0 then
		local kk = ks ^ 1.5
		local arc = geo.arc
		local r, a, l = lerp(arc.r0, arc.r1, kk), lerp(arc.a0, arc.a1, kk), lerp(arc.l0, arc.l1, kk)
		local h = r * cos(a)
		A = { gx + fx * h + rx * l, SLAM_PIVOT + r * sin(a), gz + fz * h + rz * l }
		theta = lerp(THETA_PEAK, pi / 2, kk * kk) - 0.32 * sin(pi * kk ^ 0.8)
		phi = theta + lerp(0.14, PHI_IMPACT - pi / 2, kk)
	end
	-- Turning as you hang (helpless), till you're on your back for the floor.
	local wobble = clamp01((tau - T.wrench[2]) / (T.windup[1] + 0.3 - T.wrench[2]))
	local psi = geo.psi0 * (1 - seg(tau, { 0.6, T.windup[1] + 0.25 }))
		+ 0.28 * sin((tau - T.wrench[2]) * 4.6) * sin(pi * wobble)
	local way = legWay(fx, fz, phi)
	return hungFrom(A, way, trunk(fx, fz, theta, psi))
end

-- An arm's way (body space, unit) held to what a shoulder allows: never far
-- across the chest (`sign`: the arm's side, +1 right).
local function shoulderRange(out, sign: number)
	local x, y, z = out[1], out[2], out[3]
	local function cap(limit: number, a: number, b: number)
		-- (Keep the rest of the way in proportion, so it stays a unit way.)
		local rest = math.sqrt(a * a + b * b)
		local want = math.sqrt(1 - limit * limit)
		if rest < 1e-4 then
			return limit, -want, 0
		end
		return limit, a * want / rest, b * want / rest
	end
	if -sign * x > 0.25 then
		local nx, ny, nz = cap(-sign * 0.25, y, z)
		x, y, z = nx, ny, nz
	end
	return { x, y, z }
end

-- The limbs swung, step by step, from his grab to the floor (worked out once
-- for the takedown, then looked up).
local function swings(geo)
	if geo.swings then
		return geo.swings
	end
	local T = TAKING
	local count = math.ceil((T.hit - T.grab) / SWING_STEP) + 2
	local out = { count = count }
	local state = {}
	for name in LIMBS do
		out[name] = table.create(count)
	end
	for i = 1, count do
		local pelvis = (hungBody(geo, T.grab + (i - 1) * SWING_STEP))
		for name, limb in LIMBS do
			local p = K.point(pelvis, limb.at)
			local rest = limb.sign and K.unit(K.add({ 0, -1, 0 }, K.apply(pelvis.r, { limb.sign * 0.3, 0, 0 })))
				or K.unit(K.apply(pelvis.r, limb.rest))
			local st = state[name]
			if not st then
				-- (The arms start where your braced hands are.)
				local braced = geo.braced[name]
				local n = braced and K.unit(K.sub(K.point(pelvis, braced), p)) or rest
				st = { n = n, v = { 0, 0, 0 }, p1 = p, p2 = p }
				state[name] = st
			end
			-- (How the point it hangs from is being thrown about.)
			local a = K.scale(K.add(K.sub(p, K.scale(st.p1, 2)), st.p2), 1 / (SWING_STEP * SWING_STEP))
			st.p2, st.p1 = st.p1, p
			local f = K.scale(K.sub({ 0, -GRAVITY, 0 }, a), 1 / limb.length)
			f = K.add(f, K.scale(K.sub(rest, st.n), limb.tone))
			f = K.sub(f, K.scale(st.v, limb.damp))
			f = K.sub(f, K.scale(st.n, K.dot(f, st.n)))
			st.v = K.add(st.v, K.scale(f, SWING_STEP))
			local n = K.unit(K.add(st.n, K.scale(st.v, SWING_STEP)))
			if limb.sign then
				-- (A shoulder stops the arm at its range, and it slides along it.)
				local back = K.transpose(pelvis.r)
				local inBody = K.apply(back, n)
				if -limb.sign * inBody[1] > 0.25 then
					n = K.apply(pelvis.r, shoulderRange(inBody, limb.sign))
				end
			end
			st.v = K.sub(st.v, K.scale(n, K.dot(st.v, n)))
			st.n = n
			out[name][i] = n
		end
	end
	geo.swings = out
	return out
end

-- Which way a free limb hangs at `tau` (world).
local function swingOf(geo, name: string, tau: number)
	local sw = swings(geo)
	local x = (math.clamp(tau, TAKING.grab, TAKING.hit) - TAKING.grab) / SWING_STEP
	local i = math.clamp(math.floor(x), 0, sw.count - 2)
	local list = sw[name]
	return K.unit(lerp3(list[i + 1], list[i + 2], clamp01(x - i)))
end

-- A braced hand's place (stage space), for a pelvis frame.
local function bracedHand(spec, pelvis, side: string, k: number)
	local set = BRACED[spec.opening == "behind" and "behind" or "front"]
	return K.point(pelvis, lerp3(BRACED.still[side], set[side], k))
end

-- Before his hand is on you: braced (face to face, the hands up, the left
-- leg still planted: it's the one he takes) or startled, looking back.
local function bracing(spec, pelvis, tau: number, t: number)
	local k = spec.opening == "hiding" and 1 or seg(tau, { 0, 0.18 })
	local v = flinch()
	v.LeftHip, v.LeftKnee, v.LeftAnkle = zero(), zero(), zero()
	if spec.opening == "behind" then
		v.Neck = joint(0.1, 0.9 + 0.05 * noise(t * 2, 50), 0)
		v.Waist = joint(0.05, 0.25, 0)
	end
	v = blend(stand(), v, k)
	-- (The arms by where the hands are, as they'll be hanging.)
	for _, side in { "Left", "Right" } do
		victimArmTo(v, pelvis, side, bracedHand(spec, pelvis, side, k), 1, true)
	end
	return v
end

-- Hanging: the held leg straight up to his hand, the rest of you hanging and
-- flung by the swing, fighting while you can (`fight`).
local function hungJoints(spec, geo, tau: number, t: number, pelvis, hip, fight: number)
	local T = TAKING
	local j = table.clone(bracing(spec, pelvis, T.grab, t))
	local w = seg(tau, { T.grab, T.grab + 0.16 })
	j.LeftHip = hip
	j.LeftKnee = zero()
	j.LeftAnkle = mix(j.LeftAnkle, joint(0.35), w)
	local back = K.transpose(pelvis.r)
	-- The chest and head thrown about by the swing (and, once you're flung
	-- flat, never bent back into the floor); curling up to reach your own
	-- leg, again and again, while you can.
	local flat = 1 - seg(tau, { T.slam[1], T.slam[1] + 0.12 })
	local chest = K.apply(back, swingOf(geo, "Chest", tau))
	local head = K.apply(back, swingOf(geo, "Head", tau))
	-- (Each read as the sine of its tilt: smooth however far it swings.)
	local bend = 0.45 * sin(math.atan2(chest[3], chest[2])) * flat
	j.Waist = mix(
		j.Waist,
		joint(
			bend - 0.22 * fight * (0.5 + 0.5 * sin(t * 2.3)),
			0.12 * noise(t * 1.4, 73) * fight,
			-0.3 * sin(math.atan2(chest[1], chest[2])) * flat
		),
		w
	)
	j.Neck = mix(
		j.Neck,
		joint(
			(0.85 * sin(math.atan2(head[3], head[2])) - bend) * flat - 0.25 * fight,
			0.3 * noise(t * 1.7, 75) * fight,
			-0.45 * sin(math.atan2(head[1], head[2])) * flat
		),
		w
	)
	-- The free leg falls as far as the hip lets it, kicking (a smooth reach
	-- round the hip's range, so it never snaps from one end of it to the other).
	local gl = K.apply(back, swingOf(geo, "Leg", tau))
	local want = math.atan2(-gl[3], -gl[2]) - 0.7
	local kick = fight * noise(t * 4.3, 77)
	j.RightHip = mix(j.RightHip, joint(0.7 + 1.2 * sin(want) + 0.3 * kick, 0, 0.18 + 0.08 * noise(t * 2.1, 79)), w)
	j.RightKnee = mix(
		j.RightKnee,
		joint(-0.2 - 0.45 * (0.5 - 0.5 * cos(want)) - 0.35 * fight * (0.5 + 0.5 * noise(t * 3.1, 78))),
		w
	)
	j.RightAnkle = mix(j.RightAnkle, joint(0.35), w)
	-- The arms hang the way you're thrown, clawing at the air.
	local upper = partChild(pelvis, PRig.Waist.a0, j.Waist, PRig.Waist.a1)
	-- (Always within reach: an arm reaching past it lets go, and swings back
	-- the long way round.)
	for i, side in { "Left", "Right" } do
		local shoulder = K.point(upper, PRig[side .. "Shoulder"].a0)
		local g = swingOf(geo, side, tau)
		local f = 0.35 * fight * w
		local seed = 80 + i * 3
		local out = K.apply(K.transpose(upper.r), {
			g[1] + f * noise(t * 3.3, seed),
			g[2] + f * noise(t * 2.9, seed + 1),
			g[3] + f * noise(t * 3.7, seed + 2),
		})
		out = shoulderRange(K.unit(out), side == "Left" and -1 or 1)
		local reachOut = lerp(K.length(K.sub(bracedHand(spec, pelvis, side, 1), shoulder)), 1.72, w)
		victimArmTo(j, pelvis, side, K.add(shoulder, K.apply(upper.r, K.scale(out, reachOut))), 1, true)
	end
	j.LeftWrist = mix(j.LeftWrist, joint(0.4 * fight), w)
	j.RightWrist = mix(j.RightWrist, joint(0.4 * fight), w)
	return j
end

-- Slammed flat on your back: everything flung out on the boards, bounced
-- once, the breath knocked out of you; then the first weak stir.
local function slammed(t: number, since: number)
	local v = stand()
	local b = math.max(0, ring(since, 15, 7))
	local stir = smooth((since - 0.3) / 0.5)
	local gasp = sin(clamp01((since - 0.2) / 0.6) * pi)
	v.LeftShoulder = joint(2.45 + 0.3 * b - 0.35 * stir, 0, 0.6 + 0.25 * b)
	v.RightShoulder = joint(2.3 - 0.25 * b - 0.4 * stir + 0.12 * noise(t * 2.3, 71) * stir, 0, -0.65 - 0.25 * b)
	v.LeftElbow = joint(0.3 + 0.5 * stir)
	v.RightElbow = joint(0.45 + 0.45 * stir)
	v.LeftWrist = joint(0.3)
	v.RightWrist = joint(0.3)
	v.RightHip = joint(0.4 + 0.35 * b + 0.25 * stir, 0, 0.3)
	v.RightKnee = joint(-0.7 - 0.4 * b - 0.35 * stir)
	v.RightAnkle = joint(0.3)
	v.Waist = joint(-0.12 * b - 0.15 * gasp)
	-- The head bounces off the floor, lolls, lifts a little as you come to.
	v.Neck = joint(-0.05 - 0.45 * b - 0.25 * stir, 0.35 * noise(since * 1.3, 72), 0.1 * noise(since * 1.7, 70))
	return v
end

-- How low he crouches (0 standing, 1 down on your ankle or into the slam).
local function crouchAt(tau: number): number
	local T = TAKING
	return 0.95 * seg(tau, { 0.02, 0.24 })
		- 0.95 * seg(tau, { 0.32, 0.66 })
		- 0.1 * seg(tau, { T.windup[1] + 0.02, T.windup[2] - 0.06 })
		+ 1.1 * accel(tau, { T.windup[2] - 0.06, T.hit })
		- 0.2 * seg(tau, { T.hit + 0.12, T.loom[2] })
		- 0.8 * seg(tau, { T.turn[1] - 0.02, T.turn[1] + 0.33 })
end

-- How far he bends at the waist (forward < 0).
local function leanAt(tau: number): number
	local T = TAKING
	return -0.12
		- 0.98 * seg(tau, { 0, 0.24 }) -- down for your ankle
		+ 1.25 * seg(tau, { 0.3, 0.7 }) -- the heave, leaning back into it
		- 0.2 * seg(tau, { 0.82, 1.25 }) -- over you as you hang
		+ 0.32 * seg(tau, { T.windup[1], T.windup[2] - 0.06 }) -- reared back for the swing
		- 1.25 * accel(tau, { T.windup[2] - 0.04, T.hit }) -- down with you, all his weight
		+ 0.15 * seg(tau, { T.hit + 0.12, T.loom[2] }) -- still bent over you
		+ 0.58 * seg(tau, { T.turn[1] - 0.02, T.turn[1] + 0.33 }) -- up, and round to go
end

-- Out of a hiding place: his left hand in for your collar and you're hauled
-- out stumbling to where you'll stand; let go, braced. The pelvis, joints,
-- and how far his hand is on your collar.
local function hauled(spec, t: number, standing)
	local length = TAKING_OPENING.hiding
	local collar = 0.22
	local haul = seg(t, { collar, length - 0.1 })
	local fx, fz = spec.from[1], spec.from[2]
	local fyaw = 0
	if math.abs(fx) + math.abs(fz) >= 0.5 then
		fyaw = yawOf(-fx, -fz)
	end
	local stumble = sin(haul * pi) * 0.4
	local start = frame(fyaw, 0, fx, spec.pelvis, fz)
	local moving =
		frame(lerp(fyaw, 0, haul), -stumble, lerp(fx, 0, haul), spec.pelvis - 0.12 * stumble, lerp(fz, 0, haul))
	local pelvis =
		slerpFrame(slerpFrame(start, moving, seg(t, { collar, collar + 0.1 })), standing, seg(t, { 0.5, length }))
	local legs = stand()
	local stride = sin(t * 15) * 0.55 * sin(haul * pi)
	legs.LeftHip = joint(stride)
	legs.RightHip = joint(-stride)
	legs.LeftKnee = joint(-0.4 - math.max(0, stride))
	legs.RightKnee = joint(-0.4 - math.max(0, -stride))
	legs.LeftShoulder = joint(0.8, 0, 0.3)
	legs.RightShoulder = joint(0.6, 0, -0.3)
	local joints = blend(
		blend(stand(), legs, seg(t, { collar, collar + 0.15 })),
		bracing(spec, standing, 0, t),
		seg(t, { 0.5, length })
	)
	return pelvis, joints, seg(t, { 0.02, collar }) * (1 - seg(t, { length - 0.2, length - 0.05 }))
end

local function takingSample(spec, t: number)
	local T = TAKING
	local d = Takedown.Drag
	local open = Takedown.openingLength(spec)
	local t0 = t
	-- (The hit-stop: everything holds a moment as you hit the floor.)
	t -= math.clamp(t - (open + T.hit), 0, HIT)
	local tau = t - open
	local geo = geometry(spec)

	-- Him: where he stands, which way he faces.
	local gx, gz = stanceAt(geo, tau)
	local yaw = yawAt(geo, tau)
	local dragK = tau - T.drag
	local s = 0
	if dragK > 0 then
		-- (Dragged with no way planned: along the way out a little, him ahead.)
		local surge = d.surge * sin(dragK * d.steps * 2 * pi)
		s = math.max(0, dragK * d.speed + surge * seg(dragK, { 0, 0.3 }))
		local x, z, tx, tz = along(spec.path, s + d.gap)
		gx, gz, yaw = x, z, geo.yaw2 + wrapAngle(yawOf(tx, tz) - geo.yaw2)
	end
	local root = { x = gx, z = gz, yaw = yaw, y = GRig.rootY }

	-- You.
	local fight = 1 - 0.5 * seg(tau, T.windup) - 0.3 * seg(tau, T.slam)
	local standing = (hungBody(geo, T.grab))
	local pelvis, joints
	local collarK = 0
	local yank = seg(tau, T.yank)
	if t < open then
		pelvis, joints, collarK = hauled(spec, t, standing)
	elseif tau < T.grab then
		pelvis, joints = standing, bracing(spec, standing, tau, t)
	elseif tau < T.hit then
		local hip
		pelvis, hip = hungBody(geo, tau)
		joints = hungJoints(spec, geo, tau, t, pelvis, hip, fight)
	elseif dragK <= 0 then
		-- Down: bounced once, flat; then hauled up by the ankle to his side.
		local since = tau - T.hit
		local hitPelvis, hitHip = hungBody(geo, T.hit)
		local atHit = hungJoints(spec, geo, T.hit, open + T.hit, hitPelvis, hitHip, 0.7)
		local b = math.max(0, ring(since, 14, 7.5))
		local L = geo.L
		pelvis = supine(L[1], L[2], -geo.u1[1], -geo.u1[2])
		pelvis = nudge(
			pelvis,
			0.12 * ring(since, 17, 8) + 0.03 * sin(t * 5.5) * smooth(since / 0.4),
			0,
			0.1 * ring(since - 0.03, 13, 7),
			0,
			0.22 * b,
			0
		)
		local down = slammed(t, since)
		down.LeftHip = { hitHip[1] + 0.15 * b, hitHip[2], hitHip[3], 0, 0, 0 }
		down.LeftKnee = joint(-0.04 - 0.1 * b)
		down.LeftAnkle = joint(0.35)
		local flung = seg(since, { 0, 0.1 })
		joints = blend(atHit, down, flung)
		-- (The hands, in the body's own space, from where they were to where
		-- they're flung, then to where they claw as you're dragged.)
		local hands = {}
		for _, side in { "Left", "Right" } do
			local a = K.toLocal(hitPelvis, handOf(hitPelvis, atHit, side))
			hands[side] = lerp3(a, K.toLocal(pelvis, handOf(pelvis, down, side)), flung)
		end
		if yank > 0 then
			local dragPelvis, dragJoints = Takedown.dragBody(geo.held, -geo.way[1], -geo.way[2], t)
			local haul = seg(tau, { T.yank[1], T.yank[2] + 0.05 })
			for _, side in { "Left", "Right" } do
				hands[side] = lerp3(hands[side], K.toLocal(dragPelvis, handOf(dragPelvis, dragJoints, side)), haul)
			end
			pelvis = slerpFrame(pelvis, dragPelvis, backOut(lin(tau, T.yank[1], T.yank[2]), 0.6), yank)
			joints = blend(joints, dragJoints, haul)
		end
		for _, side in { "Left", "Right" } do
			victimArmTo(joints, pelvis, side, K.point(pelvis, hands[side]), 1, true)
		end
	else
		local _, _, tx, tz = along(spec.path, s + d.gap)
		pelvis, joints = Takedown.dragBody(dragHold(gx, 0, gz, yaw), -tx, -tz, t)
	end
	local vp = Takedown.victimPoints(pelvis, joints)

	-- His body: the base pose; down into his crouch; his feet planted where
	-- they step; his spine; his head aimed; then his hands.
	local base = GuestPose.target({ pose = "Hold", phase = 0, breath = 0, tilt = 0, form = spec.form })
	local c = crouchAt(tau)
	local breath = sin(t * 2.4)
		+ 0.8 * sin(t * 4.1) * seg(tau, { T.hit, T.hit + 0.3 }) * (1 - seg(tau, { T.turn[2], T.drag + 1 }))
	base.Root = {
		base.Root[1] - 0.2 * c,
		base.Root[2],
		base.Root[3] + 0.03 * noise(t * 0.6, 43),
		base.Root[4] + 0.05 * noise(t * 0.5, 44),
		base.Root[5] - 1.3 * c + 0.015 * breath + 0.06 * ring(tau - T.hit, 16, 9),
		base.Root[6] + 0.25 * c,
	}
	local rf = guestFrame(root)
	local pelvisG = GuestPose.pelvisFrame(base.Root)
	for _, side in { "Left", "Right" } do
		for _, part in { "Hip", "Knee", "Ankle" } do
			base[side .. part] = table.clone(base[side .. part])
		end
		local fx, fz, fyaw, lift = footAt(geo.feet[side], tau)
		local ankle = K.toLocal(rf, { fx, GRig.ankleY + lift, fz })
		GuestPose.bendLeg(base, side, pelvisG, ankle, fyaw - yaw, 0, false)
	end
	if dragK > 0 then
		local walking =
			GuestPose.target({ pose = "Walk", phase = (s + d.gap) / 2.0, breath = 0, tilt = 0, form = spec.form })
		for _, name in GUEST_LEGS do
			base[name] = mix(base[name], walking[name], seg(dragK, { 0, 0.25 }))
		end
	end
	-- His back: bent for your ankle, reared back with you, coiled to his
	-- right and unwound through the slam.
	local twist = -0.3 * seg(tau, { T.windup[1], T.windup[2] - 0.06 })
		+ 0.42 * accel(tau, { T.windup[2] - 0.04, T.hit })
		- 0.12 * seg(tau, { T.hit + 0.14, T.hit + 0.54 })
	base.Waist = {
		base.Waist[1] + leanAt(tau) + 0.08 * ring(tau - T.hit, 16, 9) + 0.025 * breath,
		base.Waist[2] + twist + 0.05 * noise(t * 0.9, 41),
		base.Waist[3] + 0.035 * noise(t * 0.7, 42),
		0,
		0,
		0,
	}
	-- His head: on your ankle as he goes for it, then on your face (cocked,
	-- as you hang), on you as he swings you and after; ahead as he goes.
	local look = lerp3(vp.face, vp.ankle, seg(tau, { -0.1, 0.1 }) * (1 - seg(tau, { 0.3, 0.55 })))
	look = lerp3(
		look,
		pelvis.p,
		seg(tau, { T.windup[1], T.windup[1] + 0.2 }) * (1 - seg(tau, { T.hit + 0.08, T.hit + 0.28 }))
	)
	local fwd = { -sin(yaw), 0, -cos(yaw) }
	look = lerp3(look, { gx + fwd[1] * 6, 6.5, gz + fwd[3] * 6 }, seg(tau, { T.turn[1] + 0.05, T.turn[1] + 0.3 }))
	local roar = seg(tau, { T.slam[1] - 0.06, T.slam[2] - 0.06 }) * (1 - seg(tau, { T.hit + 0.08, T.hit + 0.58 }))
	local headYaw, headPitch = aim(base, root, look)
	local tilt = 0.35
		+ 0.55 * seg(tau, { 0.88, 1.06 }) * (1 - seg(tau, { T.windup[1] - 0.02, T.windup[1] + 0.12 }))
		+ 0.4 * seg(tau, { T.hit + 0.08, T.hit + 0.28 }) * (1 - seg(tau, { T.turn[1] - 0.02, T.turn[1] + 0.18 }))
	base.Neck = {
		math.clamp(headPitch + 0.04 * noise(t * 1.3, 45), -1.1, 0.8),
		math.clamp(headYaw + 0.05 * noise(t * 1.1, 46), -1.2, 1.2),
		tilt + 0.04 * noise(t * 0.8, 47),
		0,
		0.25 + 0.25 * roar,
		0,
	}
	-- His right hand on your ankle, from above; his left on your shin for the
	-- slam (or, out of a hiding place, on your collar first).
	local legDir = K.unit(K.sub(vp.ankle, vp.knee))
	local grip = K.sub(vp.ankle, K.scale(legDir, 0.2 * (1 - yank)))
	local ahead = { grip[1] - gx, 0, grip[3] - gz }
	ahead = K.length(ahead) > 0.05 and K.unit(ahead) or fwd
	local rightW = t < open and 0 or seg(tau, { 0.06, T.grab })
	reach(base, "Right", root, { grip[1], grip[2] + 0.5, grip[3] }, ahead, { 0, -1, 0 }, { 0.7, -1, 0.3 }, rightW)
	local leftW = seg(tau, { T.windup[1] + 0.08, T.windup[1] + 0.26 }) * (1 - seg(tau, { T.hit + 0.06, T.hit + 0.24 }))
	if collarK > 0 then
		local collar = { vp.collar[1] - fwd[1] * 0.35, vp.collar[2] - 0.35, vp.collar[3] - fwd[3] * 0.35 }
		reach(base, "Left", root, collar, fwd, { 0, 1, 0 }, { -0.7, -1, 0.3 }, collarK)
	elseif leftW > 0 then
		local shin = K.sub(vp.ankle, K.scale(legDir, 0.75))
		reach(base, "Left", root, { shin[1], shin[2] + 0.45, shin[3] }, ahead, { 0, -1, 0 }, { -0.7, -1, 0.3 }, leftW)
	end

	local length = Takedown.length(spec)
	return {
		victim = {
			pelvis = pelvis,
			joints = joints,
			fade = spec.live and 0 or clamp01((t0 - (length - d.fade)) / d.fade),
		},
		guest = {
			root = root,
			joints = base,
			smile = 1,
			open = 0.38 + 0.08 * sin(t * 3) + 0.55 * roar,
			catch = true,
			curl = {
				Left = lerp(0.5, 1.1, math.max(leftW, collarK)) + 0.12 * noise(t * 1.7, 48),
				Right = lerp(0.6, 1.15, rightW) + 0.08 * noise(t * 1.9, 49),
			},
			spread = { Left = lerp(0.75, 0.35, math.max(leftW, collarK)), Right = lerp(0.8, 0.35, rightW) },
			face = Takedown.guestFace(root, base),
		},
		points = vp,
	}
end

-- What has to be clear for a taking laid out this way (stage space): from
-- his chest out to your head and middle at its widest moments, and the floor
-- where you land. { { from, to, radius } }, and the landing's pelvis and head
-- (StalkerService picks the way the slam goes by them; cheap: the body's
-- path only, not its limbs).
function Takedown.slamChecks(spec)
	local geo = geometry(Takedown.fill(spec))
	local T = TAKING
	local list = {}
	for _, beat in { 0.5, 0.62, 1.05, T.windup[2], T.slam[1] + 0.12, T.hit } do
		local pelvis = (hungBody(geo, beat))
		local gx, gz = stanceAt(geo, beat)
		local chest = { gx, 5.2, gz }
		table.insert(list, { chest, K.point(pelvis, { 0, 2.4, 0 }), 0.45 })
		table.insert(list, { chest, pelvis.p, 0.45 })
	end
	local L, u = geo.L, geo.u1
	local p = { L[1], LYING, L[2] }
	local h = { L[1] + u[1] * 2.4, LYING, L[2] + u[2] * 2.4 }
	table.insert(list, { { p[1], 0.9, p[3] }, { h[1], 0.9, h[3] }, 0.45 })
	return list, { p, h }
end

-- Sampling -------------------------------------------------------------------------

-- The opening: how he takes hold. Returns the victim's pelvis frame and
-- joints, his root, and how far each hand has reached, for `t` in
-- [0, opening]; at its end everything is exactly where the core begins
-- (`held`: the pelvis frame the core starts from).
local function opening(spec, t: number, heldFrame)
	local length = Takedown.openingLength(spec)
	local gx, gz = spec.guest[1], spec.guest[2]
	local dx, dz = flatUnit(gx, gz)
	local ph = spec.pelvis
	local out = {}
	local toHeld = seg(t, { length * 0.55, length })
	if spec.opening == "behind" then
		-- His hand comes over your face from behind; you're yanked back off
		-- your feet towards him, then spun round to face him as he lifts.
		local grab = 0.18
		local yank = seg(t, { grab, 0.42 })
		local jolt = ring(t - grab, 18, 8) * 0.15
		local turn = seg(t, { 0.42, length })
		local back = yank * 0.5
		local start = frame(spec.yaw, 0, 0, ph, 0)
		local pulled = frame(spec.yaw, 0.38, dx * back, ph + 0.05, dz * back)
		local f = slerpFrame(start, pulled, yank)
		-- (Tipping back towards him: for a body facing away, its back is his way.)
		f = nudge(f, jolt, 0, 0)
		out.pelvis = slerpFrame(f, heldFrame, turn)
		local legs = stand()
		legs.LeftHip = joint(-0.3 * yank)
		legs.RightHip = joint(-0.12 * yank)
		legs.LeftKnee = joint(-0.2 * yank)
		out.joints =
			blend(blend(blend(stand(), flinch(), seg(t, { grab, grab + 0.12 })), legs, 0.5 * yank), held(t, 1, 0), turn)
		local stepIn = seg(t, { 0.05, length * 0.8 })
		out.root = { x = lerp(gx, dx * spec.hold, stepIn), z = lerp(gz, dz * spec.hold, stepIn) }
		out.step = math.abs(spec.hold - math.sqrt(gx * gx + gz * gz)) > 0.2 and sin(stepIn * pi) or 0
		out.right = backOut(lin(t, 0, grab), 1.2)
		out.left = seg(t, { 0.42, length * 0.85 })
	elseif spec.opening == "hiding" then
		-- His left hand reaches in for your collar, and you're hauled out
		-- stumbling to where he stands; then the hand over your face.
		local collar = 0.24
		local haul = seg(t, { collar, 0.66 })
		local fx, fz = spec.from[1], spec.from[2]
		local fyaw = 0
		if math.abs(fx) + math.abs(fz) >= 0.5 then
			fyaw = yawOf(-fx, -fz)
		end
		local stumble = sin(haul * pi) * 0.4
		local start = frame(fyaw, 0, fx, ph, fz)
		local out1 = frame(lerp(fyaw, 0, haul), -stumble, lerp(fx, 0, haul), ph - 0.12 * stumble, lerp(fz, 0, haul))
		out.pelvis = slerpFrame(slerpFrame(start, out1, seg(t, { collar, collar + 0.1 })), heldFrame, toHeld)
		local legs = stand()
		local stride = sin(t * 15) * 0.55 * sin(haul * pi)
		legs.LeftHip = joint(stride)
		legs.RightHip = joint(-stride)
		legs.LeftKnee = joint(-0.4 - math.max(0, stride))
		legs.RightKnee = joint(-0.4 - math.max(0, -stride))
		legs.LeftShoulder = joint(0.8, 0, 0.3)
		legs.RightShoulder = joint(0.6, 0, -0.3)
		out.joints = blend(blend(stand(), legs, seg(t, { collar, collar + 0.15 })), held(t, 1, 0), toHeld)
		out.root = { x = gx, z = gz }
		local back = seg(t, { 0.5, length })
		out.root = { x = lerp(gx, dx * spec.hold, back), z = lerp(gz, dz * spec.hold, back) }
		out.step = sin(back * pi)
		out.left = seg(t, { 0.02, collar })
		out.right = backOut(lin(t, 0.62, 0.78), 1.2)
	else
		-- Face to face: his hand over your face before you can move. You
		-- flinch, the hand lands (a knock through you), you're turned square
		-- to him and up on your toes.
		local grab = 0.16
		local jolt = ring(t - grab, 18, 9) * 0.12
		local turn = seg(t, { 0, 0.22 })
		local start = frame(spec.yaw, 0, 0, ph, 0)
		local f = frame(spec.yaw * (1 - turn), 0.04 * seg(t, { 0, grab }), 0, ph - 0.04 * sin(lin(t, 0, grab) * pi), 0)
		f = nudge(f, jolt, 0, 0)
		out.pelvis = slerpFrame(slerpFrame(start, f, 1), heldFrame, toHeld)
		out.joints = blend(blend(stand(), flinch(), seg(t, { 0, grab })), held(t, 1, 0), seg(t, { grab, length }))
		local stepIn = seg(t, { 0, length * 0.9 })
		out.root = { x = lerp(gx, dx * spec.hold, stepIn), z = lerp(gz, dz * spec.hold, stepIn) }
		out.step = math.abs(spec.hold - math.sqrt(gx * gx + gz * gz)) > 0.2 and sin(stepIn * pi) or 0
		out.right = backOut(lin(t, 0, grab), 1.3)
		out.left = seg(t, { 0.12, length * 0.9 })
	end
	out.dir = { dx, dz }
	return out
end

-- Everything at time `t` (seconds from the start):
--   victim = { pelvis = frame, joints, fade (0 .. 1: gone into the dark) }
--   guest  = { root = { x, y, z, yaw }, joints, smile (0 .. 1), open (0 .. 1),
--              catch (the torn face), curl = { Left, Right },
--              spread = { Left, Right }, face (where his face is) }
--   points = the victim's face, collar, shoulder, ankle (Takedown.victimPoints)
function Takedown.sample(spec, t: number)
	if spec.kind == "taking" then
		return takingSample(spec, t)
	end
	local hold = Takedown.Hold
	local open = Takedown.openingLength(spec)
	local ph = spec.pelvis
	local gx, gz = spec.guest[1], spec.guest[2]
	local dx, dz = flatUnit(gx, gz)
	local tau = t - open
	-- Where the core takes over from the opening: up on your toes, a little
	-- towards him, square to him.
	local heldFrame = frame(0, 0.05, dx * 0.1, ph + 0.15, dz * 0.1)

	local victim, root
	local reachRight, reachLeft = 0, 0
	local rightTarget = nil
	local legsPose, legsPhase, gaitW = "Hold", 0, 0
	-- His spine and head, from a slight hunch (breathing always).
	local lean = -0.12 + 0.02 * sin(t * 2.4)
	local stretch = 0.1
	local look = nil -- what his head turns to (stage space), nil for straight on
	local pitchAdd, yawAdd, tilt = 0, 0, 0.15
	local smile, openMouth, catch = 0.45, 0, false
	local curl = { Left = 0.45, Right = 0.45 }
	local spread = { Left = 0.7, Right = 0.7 }

	if t < open then
		local length0 = open
		local o = opening(spec, t, heldFrame)
		-- (Your hands go to his arm once you can: face to face at once; from
		-- behind, once he's turned you; out of a hiding place, once his hand
		-- is on your face.)
		local from = spec.opening == "behind" and 0.6 or (spec.opening == "hiding" and 0.66 or 0.1)
		victim = { pelvis = o.pelvis, joints = o.joints, lookAt = "face", clutch = seg(t, { from, length0 }) }
		root = { x = o.root.x, z = o.root.z }
		reachRight, reachLeft = o.right, o.left
		legsPose, legsPhase, gaitW = "BackAway", t * 1.6, (o.step or 0) * 0.8
		lean += -0.2 * math.max(reachRight, reachLeft)
		tilt = 0.15 + 0.15 * math.max(reachRight, reachLeft) + 0.02 * sin(t * 2.0)
		curl.Right = lerp(0.35, 0.95, clamp01(reachRight))
		curl.Left = lerp(0.35, 1.05, clamp01(reachLeft))
		spread.Right = lerp(0.9, 0.6, clamp01(reachRight))
	else
		local T = TASTE
		-- How hard you fight: hard as you go up, giving out as he looks you
		-- over, a last panic at the tear, a spasm at the bite, then nothing.
		local fight = lerp(1, 0.45, seg(tau, { 0.3, T.look[2] }))
		fight = lerp(fight, 1, seg(tau, { T.tear[1], T.tear[1] + 0.15 }))
		fight = lerp(fight, 0.15, seg(tau, { T.bite[1], T.worry[2] }))
		local aside = seg(tau, { T.tear[1], T.tear[2] })
		-- The body: hoisted (a heave, then the rest), swinging as you fight.
		local heave = 0.72 * seg(tau, { 0, 0.24 }) + 0.28 * seg(tau, { 0.18, T.lift[2] })
		-- (You stay over the spot you'll fall to; he moves. A tug into the bite.)
		local pull = lerp(0.1, hold.pull, heave)
			+ 0.15 * backOut(lin(tau, T.bite[1], T.bite[2]), 1.2) * (1 - seg(tau, { T.worry[2] - 0.1, T.drop[1] }))
		-- (Raised to his face as he looks you over.)
		local y = lerp(ph + 0.15, ph + hold.lift, heave)
			+ 0.45 * seg(tau, { T.look[1], T.look[1] + 0.45 }) * (1 - seg(tau, { T.drop[1] - 0.1, T.drop[1] + 0.1 }))
			+ 0.1 * seg(tau, T.bite)
		-- (The swing comes in over the first moments: the opening had none.)
		local f = fight * seg(tau, { 0, 0.3 })
		local swayX = 0.07 * noise(t * 1.7, 21) * f
		local swayZ = 0.05 * noise(t * 1.3, 22) * f
		local base = frame(0, 0.05 + 0.06 * heave, dx * pull, y, dz * pull)
		base = nudge(
			base,
			0.06 * noise(t * 2.1, 23) * f + 0.18 * ring(tau - T.bite[1], 20, 9),
			0.1 * noise(t * 1.5, 24) * f + 0.1 * ring(tau - T.worry[1], 26, 5),
			0.08 * noise(t * 1.9, 25) * f + 0.12 * ring(tau - T.worry[1] - 0.1, 24, 5),
			swayX,
			0,
			swayZ
		)
		-- Released: you fall as a body falls (faster and faster), turning face
		-- down as you go, and land with a bounce.
		local fall = lin(tau, T.drop[1], T.drop[2])
		local fallen = fall * fall
		local rest = spec.rest
		local pelvis = slerpFrame(base, rest, fallen, smooth(fall))
		local land = tau - T.drop[2]
		if land > 0 then
			pelvis = nudge(pelvis, 0, 0, 0, 0, math.max(0, ring(land, 16, 8)) * 0.08, 0)
			-- (Settled exactly onto the downed pose by the end.)
			pelvis = slerpFrame(pelvis, rest, seg(tau, { T.drop[2] + 0.3, T.length - 0.2 }))
		end
		local heldJoints = spasm(held(t, fight, aside), math.max(0, ring(tau - T.bite[1], 12, 6)) * 0.85)
		-- (Letting go: his hands stay where your face and collar were and
		-- open, rather than following you down.)
		local releasedAt = fall > 0 and Takedown.victimPoints(base, heldJoints) or nil
		local joints = heldJoints
		if fall > 0 then
			joints = blend(heldJoints, falling(), seg(tau, { T.drop[1], T.drop[1] + 0.15 }))
		end
		if land > 0 then
			joints = blend(joints, landed(land, T.length - T.drop[2] - 0.25), seg(land, { 0, 0.12 }))
		end
		-- (Your grip on his arm: tight while you fight, gone at the bite.)
		-- (Let go as he coils to bite: then they flail.)
		local clutch = (1 - seg(tau, { T.coil[1] - 0.05, T.bite[1] })) * lerp(0.6, 1, fight)
		victim = { pelvis = pelvis, joints = joints, released = releasedAt, clutch = clutch }
		-- Him: holding you out at arm's length; two slow steps in to bring
		-- his face to yours; the lunge; then back a step, looking down at you.
		local inK = seg(tau, { T.look[1] - 0.12, T.look[1] + 0.4 })
		local biteIn = backOut(lin(tau, T.coil[1] + 0.05, T.bite[2]), 1.1) * (1 - seg(tau, { T.worry[2], T.drop[2] }))
		-- (He shoves you down and steps back as he lets go: clear of you by
		-- the time you land, at your head, looking down.)
		local outK = seg(tau, { T.release[1] + 0.05, T.drop[2] + 0.2 })
		local reachOut = lerp(spec.hold, hold.look, inK)
		reachOut = lerp(reachOut, hold.bite, biteIn)
		reachOut = lerp(reachOut, math.min(hold.after, spec.hold + 0.4), outK)
		root = { x = dx * reachOut, z = dz * reachOut }
		-- (Each step: the gait comes and goes with it.)
		legsPose, legsPhase = "Walk", inK * 1.0 + outK * 0.5
		gaitW = math.max(sin(inK * pi), sin(outK * pi) * 0.8) * (spec.hold > hold.look + 0.2 and 1 or 0.4)
		-- (He lets go first, then steps back.)
		reachRight = 1 - seg(tau, T.release)
		reachLeft = 1 - seg(tau, { T.release[1] - 0.05, T.release[2] - 0.05 })
		-- His head: drawn in to your face and tipping over as he looks you
		-- over (a sniff, a sniff, a sniff); rearing back as the grin tears; a
		-- coil, the snap at your shoulder, worrying at it; then upright,
		-- looking down at you.
		local lookK = seg(tau, T.look)
		local tearK = seg(tau, T.tear)
		local coilK = seg(tau, T.coil)
		local biteK = backOut(lin(tau, T.bite[1], T.bite[2]), 1.4) * (1 - seg(tau, { T.worry[2], T.drop[2] }))
		local release = seg(tau, { T.drop[1], T.drop[2] + 0.3 })
		lean += -0.2 * (1 - release) - 0.2 * lookK + 0.12 * coilK * (1 - biteK) - 0.38 * biteK
		lean += -0.12 * release
		stretch = 0.1 + 0.3 * lookK * (1 - biteK) + 0.55 * biteK
		tilt = lerp(0.3, 0.75, backOut(lookK, 1.1)) * (1 - 0.6 * tearK) * (1 - biteK)
		tilt += 0.02 * sin(t * 2.0) + 0.035 * sin(t * 147) * tearK * (1 - biteK)
		pitchAdd = 0.22 * tearK * (1 - coilK) + 0.12 * coilK * (1 - biteK)
		for _, at in T.sniffs do
			pitchAdd += -0.07 * math.max(0, ring(tau - at, 26, 14))
		end
		-- Worrying: the head shaken side to side, dying away.
		local worry = tau - T.worry[1]
		if worry > 0 then
			local k = exp(-worry * 3.5) * (1 - seg(tau, { T.worry[2] - 0.05, T.drop[1] + 0.1 }))
			yawAdd += 0.16 * sin(worry * 31) * k
			tilt += 0.12 * sin(worry * 27 + 1) * k
			pitchAdd += -0.06 * math.abs(sin(worry * 15)) * k
		end
		-- After: looking down at you, the head tipped (a craftsman's look).
		tilt += 0.45 * release
		smile = lerp(0.5, 0.85, lookK) + 0.15 * tearK
		openMouth = math.max(tearK, biteK)
		openMouth = lerp(openMouth, 0.55, release)
		catch = tau >= T.tear[1] - 0.05 and tau < T.wipe[2]
		curl.Right = lerp(0.95, 0.5, release)
		curl.Left = lerp(1.05, 0.55, release)
		spread.Right = lerp(0.6, 0.85, release)
		spread.Left = lerp(0.35, 0.8, release)
		-- (Fingers tightening at the bite.)
		curl.Right += 0.25 * biteK
		curl.Left += 0.2 * biteK
		victim.lookAt = "face"
		victim.lookDown = seg(tau, { T.drop[1] - 0.05, T.drop[2] + 0.2 })
		victim.bite = biteK > 0.01 and biteK or nil
		victim.shove = tearK * (1 - seg(tau, T.release))
		-- The wipe: his hand drawn slowly across his mouth.
		local wipe = seg(tau, T.wipe)
		if wipe > 0 and wipe < 1 then
			victim.wipe = wipe
		end
		openMouth = lerp(openMouth, 0.15, wipe)
	end

	-- His facing: always at you.
	local fx, fz = victim.pelvis.p[1] - root.x, victim.pelvis.p[3] - root.z
	if fx * fx + fz * fz < 0.04 then
		fx, fz = -dx, -dz
	end
	local ux, uz = flatUnit(fx, fz)
	root.yaw = yawOf(ux, uz)
	root.y = GRig.rootY

	-- His body: the base pose and legs, then the spine, then the head aimed,
	-- then the hands.
	-- (The upper body is always his standing one, so his arms never jump
	-- when his legs start or stop walking; the gait fades in on the legs.)
	local base = GuestPose.target({ pose = "Hold", phase = 0, breath = 0, tilt = 0, form = spec.form })
	if gaitW > 0 then
		local walking = GuestPose.target({ pose = legsPose, phase = legsPhase, breath = 0, tilt = 0, form = spec.form })
		for _, name in GUEST_LEGS do
			base[name] = mix(base[name], walking[name], gaitW)
		end
	end
	-- Never still (the owner: "less stiff"): his weight shifting from hip to
	-- hip, his back and shoulders rising with each slow breath, a twist that
	-- comes and goes.
	local breath = sin(t * 2.4)
	base.Waist = {
		base.Waist[1] + lean + 0.025 * breath,
		base.Waist[2] + 0.05 * noise(t * 0.9, 41),
		base.Waist[3] + 0.035 * noise(t * 0.7, 42),
		0,
		0,
		0,
	}
	base.Root = {
		base.Root[1],
		base.Root[2],
		base.Root[3] + 0.03 * noise(t * 0.6, 43),
		base.Root[4] + 0.05 * noise(t * 0.5, 44),
		base.Root[5] + 0.015 * breath,
		base.Root[6],
	}
	local vp = Takedown.victimPoints(victim.pelvis, victim.joints)
	-- (What his hands hold: where you were, once he's let go.)
	local held = victim.released or vp
	if victim.lookAt == "face" then
		look = victim.bite and lerp3(vp.face, vp.shoulder, clamp01(victim.bite)) or vp.face
		if victim.lookDown and victim.lookDown > 0 then
			look = lerp3(look, lerp3(vp.head, victim.pelvis.p, 0.4), victim.lookDown)
		end
	elseif victim.lookAt == "pelvis" then
		look = lerp3(vp.head, victim.pelvis.p, 0.4)
	end
	local yaw, pitch = 0, -0.15
	if look then
		yaw, pitch = aim(base, root, look)
	end
	-- (His head is never quite still either: small, slow, bird-like.)
	base.Neck = {
		math.clamp(pitch + pitchAdd + 0.04 * noise(t * 1.3, 45), -1.1, 0.8),
		math.clamp(yaw + yawAdd + 0.05 * noise(t * 1.1, 46), -1.2, 1.2),
		tilt + 0.04 * noise(t * 0.8, 47),
		0,
		stretch,
		0,
	}
	local toward = { -dx, 0, -dz } -- from him to you
	local up = { 0, 1, 0 }
	-- His right hand: palm over your face, fingers up across it.
	local faceTarget = {
		held.face[1] - toward[1] * 0.05 - held.up[1] * 0.4,
		held.face[2] - held.up[2] * 0.4,
		held.face[3] - toward[3] * 0.05 - held.up[3] * 0.4,
	}
	-- (The strain of holding you out: a fine tremor in the hand.)
	local strain = clamp01(reachRight) * (victim.wipe and 0 or 1)
	faceTarget = {
		faceTarget[1] + 0.025 * sin(t * 31) * strain,
		faceTarget[2] + 0.02 * sin(t * 27 + 1) * strain,
		faceTarget[3] + 0.02 * sin(t * 23 + 2) * strain,
	}
	local rightCurl, rightFingers = toward, held.up
	local wipePole = nil
	if victim.shove and victim.shove > 0 then
		-- From the tear: his hand off your face to the side of your head,
		-- shoving it over to bare your shoulder (the elbow out to his side).
		local k = victim.shove
		local side = {
			held.head[1] - held.right[1] * 0.85 + held.up[1] * 0.05,
			held.head[2] - held.right[2] * 0.85 - 0.2,
			held.head[3] - held.right[3] * 0.85 + held.up[3] * 0.05,
		}
		faceTarget = lerp3(faceTarget, side, k)
		rightCurl = K.unit(lerp3(rightCurl, held.right, k))
		rightFingers = K.unit(lerp3(rightFingers, held.up, k))
	end
	if victim.wipe then
		-- Across his own mouth, slowly: the back of the hand to you.
		local face = Takedown.guestFace(root, base)
		local sideX, sideZ = -dz, dx
		local w = victim.wipe
		local across = lerp(0.5, -0.5, smooth((w - 0.2) / 0.6))
		-- (His arms are long: the elbow hangs, the forearm comes up from
		-- below, and the long fingers drag across the mouth.)
		rightTarget = {
			face[1] + sideX * across * 0.6 + toward[1] * 0.35,
			face[2] - 0.85,
			face[3] + sideZ * across * 0.6 + toward[3] * 0.35,
		}
		rightCurl, rightFingers = { -toward[1], 0, -toward[3] }, { -sideX * 0.25, 1, -sideZ * 0.25 }
		reachRight = math.max(reachRight, smooth(sin(w * pi) * 1.4))
		faceTarget = rightTarget
		base.Neck[3] += 0.25 * sin(w * pi)
		wipePole = { 0.35, -1, -0.45 }
	end
	-- (Elbows down and out, each to its own side: +X is his right.)
	reach(base, "Right", root, faceTarget, rightCurl, rightFingers, wipePole or { 0.7, -1, 0.3 }, clamp01(reachRight))
	-- (Your hands, tearing at his forearm, while he has you by the face.)
	local clutch = (victim.clutch or 0) * smooth(clamp01(reachRight))
	if clutch > 0.001 then
		local rf = guestFrame(root)
		local wrist = K.point(rf, GuestPose.wrist(base, "Right"))
		local elbow = K.point(rf, Takedown.guestElbow(base, "Right"))
		local slide = 0.08 * sin(t * 7.3)
		victimArmTo(victim.joints, victim.pelvis, "Left", lerp3(wrist, elbow, 0.3 + slide), clutch)
		victimArmTo(victim.joints, victim.pelvis, "Right", lerp3(wrist, elbow, 0.55 - slide), clutch)
	end
	-- His left hand: a fistful of your collar.
	local collarTarget = { held.collar[1] - toward[1] * 0.35, held.collar[2] - 0.35, held.collar[3] - toward[3] * 0.35 }
	reach(base, "Left", root, collarTarget, toward, up, { -0.7, -1, 0.3 }, clamp01(reachLeft))

	-- (His fingers are never still: a slow flex, a twitch now and then.)
	curl.Left += 0.12 * noise(t * 1.7, 48)
	curl.Right += 0.08 * noise(t * 1.9, 49)
	return {
		victim = { pelvis = victim.pelvis, joints = victim.joints, fade = 0 },
		guest = {
			root = root,
			joints = base,
			smile = smile,
			open = openMouth,
			catch = catch,
			curl = curl,
			spread = spread,
			face = Takedown.guestFace(root, base),
		},
		points = vp,
	}
end

return Takedown
