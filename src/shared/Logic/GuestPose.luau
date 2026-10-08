-- The Guest's body language (docs/ART.md "The Guest"; doc section 8:
-- "Wrongness through animation. Stillness, a head tilt slightly off human,
-- joints that bend a little too far, and movement in short bursts").
--
-- Pure maths with no engine types, so the server (where his head really is
-- while he peeks) and the client (which animates every joint each frame)
-- share one source of truth, and lune can test it.
--
-- Angles are radians. A joint value is { rx, ry, rz, px, py, pz }, used as
-- Motor6D.Transform = CFrame.new(px, py, pz) * CFrame.Angles(rx, ry, rz).
-- Body space: +Y up, -Z forward (where he faces), +X his right.
--   rx > 0 swings a hanging limb forward and tips a torso back
--   ry > 0 turns left
--   rz > 0 tips the top towards his left (+X end of a hanging limb inward
--          for the left arm)

local GuestPose = {}

local rad = math.rad
local sin, cos = math.sin, math.cos
local TAU = math.pi * 2

-- Proportions in studs, heights from the floor (8.4 tall, arms past the
-- knees, narrow shoulders, small head). The server builds the rig from these.
GuestPose.Rig = {
	height = 8.42,
	hipHeight = 3.9, -- Humanoid.HipHeight: floor to the bottom of the root
	rootSize = { 1.6, 1.4, 1.0 },
	rootY = 4.6, -- root centre; also the body's groundOffset
	lowerTorsoSize = { 1.15, 0.6, 0.7 },
	lowerTorsoY = 4.5,
	upperTorsoSize = { 1.35, 2.15, 0.72 },
	waistY = 4.8,
	neckY = 6.95,
	neckLength = 0.41, -- a long neck, carried forward (the vulture's neck of the mask, 2026-10-07)
	headSize = { 0.74, 1.06, 0.84 }, -- small, under the mask
	shoulderX = 0.78,
	shoulderY = 6.66, -- low, sloping shoulders
	upperArm = 2.0,
	lowerArm = 1.85,
	hand = 0.55,
	finger = { 0.38, 0.34 }, -- two segments, built on the client
	hipX = 0.3,
	hipY = 4.2,
	upperLeg = 2.0,
	lowerLeg = 1.95,
	ankleY = 0.25,
	footSize = { 0.4, 0.25, 1.05 },
}

local Rig = GuestPose.Rig
Rig.headY = Rig.neckY + Rig.neckLength + Rig.headSize[2] / 2

GuestPose.Joints = {
	"Root",
	"Waist",
	"Neck",
	"LeftShoulder",
	"LeftElbow",
	"LeftWrist",
	"RightShoulder",
	"RightElbow",
	"RightWrist",
	"LeftHip",
	"LeftKnee",
	"LeftAnkle",
	"RightHip",
	"RightKnee",
	"RightAnkle",
}

-- Pose names (published by the server as the GuestPose attribute).
GuestPose.Poses = {
	Idle = "Idle", -- polite: hands clasped, a slight bow, breathing
	Hold = "Hold", -- frozen stare: no breath at all
	Walk = "Walk",
	Run = "Run",
	Creep = "Creep",
	BackAway = "BackAway",
	Peek = "Peek",
	Zoom = "Zoom",
	Lunge = "Lunge",
	Bow = "Bow",
	Stagger = "Stagger", -- hit by something thrown: head snapped aside, hands up, knees buckled
	Usher = "Usher", -- making way: a slight bow, one open hand held out towards the way on ("after you")
	FingersPeek = "FingersPeek", -- behind the wall, only his long fingers curled round the frame (lean = side)
	Duck = "Duck", -- tier 1, seen: a sudden drop low, before he glides away
	Listen = "Listen", -- hunting, standing still: head cocked far over, listening
	Crawl = "Crawl", -- Breaking or the final hunt, prowling: on all fours, knees up, head twisted over
}

-- How quickly each pose is reached (1/s). Fast ones snap; the rest ease.
local RATE = {
	Idle = 5,
	Hold = 9,
	Walk = 7,
	Run = 10,
	Creep = 6,
	BackAway = 6,
	Peek = 7,
	Zoom = 30,
	Lunge = 28,
	Bow = 3,
	Stagger = 22,
	Usher = 5,
	FingersPeek = 6,
	Duck = 26,
	Listen = 4,
	Crawl = 9,
}

-- Steps: studs travelled per step, swing amplitude, knee bend and lift.
local GAIT = {
	Walk = { stride = 3.4, hip = 26, knee = 38 },
	Run = { stride = 5.2, hip = 46, knee = 75 },
	Creep = { stride = 1.5, hip = 16, knee = 30 },
	BackAway = { stride = 2.0, hip = 20, knee = 26 },
	Crawl = { stride = 2.2, hip = 22, knee = 30 },
}

-- Breaking (docs/ART.md "The Guest", grows wrong): his knees bend the wrong
-- way in these, like a bird's.
local REVERSE_KNEES = { Walk = true, Run = true, Creep = true, BackAway = true }

-- And his neck draws out of his collar (studs): leaning round a frame,
-- creeping, lunging, listening; held, the longer the further.
local STRETCH = { Peek = 0.8, FingersPeek = 0.5, Creep = 0.6, Lunge = 1.0, Listen = 0.45 }

function GuestPose.neckStretch(pose: string, form: number?, heldFor: number?): number
	if (form or 0) < 2 then
		return 0
	end
	if pose == "Hold" then
		return math.min(0.9, (heldFor or 0) / 8 * 0.9)
	end
	return STRETCH[pose] or 0
end

local HUNCHED = {
	Idle = true,
	Hold = true,
	Walk = true,
	BackAway = true,
	Usher = true,
	Listen = true,
	Peek = true,
	FingersPeek = true,
}

local function zero()
	return { 0, 0, 0, 0, 0, 0 }
end

local function blank()
	local t = {}
	for _, name in GuestPose.Joints do
		t[name] = zero()
	end
	return t
end

local function add(t, joint: string, rx: number?, ry: number?, rz: number?, px: number?, py: number?, pz: number?)
	local v = t[joint]
	v[1] += rx or 0
	v[2] += ry or 0
	v[3] += rz or 0
	v[4] += px or 0
	v[5] += py or 0
	v[6] += pz or 0
end

-- Degrees helper for readability in the pose tables.
local function d(x: number): number
	return rad(x)
end

-- Polite posture: hands clasped low in front, like an undertaker.
-- The upper arms hang straight; turning them inward makes the bent
-- forearms bring the hands together in front instead of crossing.
local function clasp(t)
	add(t, "LeftShoulder", d(6), d(-40), d(3))
	add(t, "RightShoulder", d(6), d(40), d(-3))
	add(t, "LeftElbow", d(42))
	add(t, "RightElbow", d(42))
	-- The hands turned so their backs face you, the long fingers folded over
	-- each other, left over right (the body pass, 2026-10-07: seen edge-on,
	-- the curled fingers read as splayed legs). Euler XYZ of a 75 degree turn
	-- then a bend inward.
	add(t, "LeftWrist", d(-72.9), d(-47.7), d(-67.4))
	add(t, "RightWrist", d(-64.0), d(58.5), d(60.3))
end

-- Arms hanging dead straight, a little away from the body.
local function hang(t)
	add(t, "LeftShoulder", d(4), 0, d(-4))
	add(t, "RightShoulder", d(4), 0, d(4))
	add(t, "LeftElbow", d(8))
	add(t, "RightElbow", d(8))
end

-- Keep a foot flat on the floor whatever the hip and knee are doing.
local function flatFeet(t)
	t.LeftAnkle[1] -= (t.LeftHip[1] + t.LeftKnee[1]) * 0.9
	t.RightAnkle[1] -= (t.RightHip[1] + t.RightKnee[1]) * 0.9
end

-- Legs for a gait phase (0..1). Knees bend only on the swing forward, and
-- a little too far.
local function legs(t, phase: number, spec)
	local s, c = sin(phase * TAU), cos(phase * TAU)
	local hip, knee = d(spec.hip), d(spec.knee)
	add(t, "LeftHip", hip * s)
	add(t, "RightHip", -hip * s)
	add(t, "LeftKnee", -knee * math.max(0, c))
	add(t, "RightKnee", -knee * math.max(0, -c))
end

-- The target pose before smoothing. ctx: { pose, phase, tilt, lean, stoop,
-- breath, gazeYaw, gazePitch, neckYawMax }
function GuestPose.target(ctx)
	local t = blank()
	local pose = ctx.pose
	local P = GuestPose.Poses

	if pose == P.Idle or pose == P.Hold or pose == P.Bow then
		local mood = ctx.mood
		if pose ~= P.Bow and mood == "Stalking" then
			-- Low and loose: knees soft, arms hanging long, fingers spread.
			hang(t)
			add(t, "Root", 0, 0, 0, 0, -0.25, 0)
			add(t, "LeftKnee", d(-14))
			add(t, "RightKnee", d(-14))
			add(t, "LeftHip", d(10))
			add(t, "RightHip", d(10))
		else
			clasp(t)
		end
		add(t, "Waist", d(pose == P.Bow and -48 or -6))
		if pose == P.Bow then
			-- The bow is deep but the face never leaves you.
			add(t, "Neck", d(52))
		end
		-- Breathing, unless he's patient (dead still) or held (no breath at all).
		if pose == P.Idle and mood ~= "Patient" then
			add(t, "Waist", d(1.2) * sin(ctx.breath * TAU))
		end
		local clock = ctx.t or 0
		if pose == P.Idle and mood == "Curious" then
			-- His head tips slowly one way, then the other.
			add(t, "Neck", 0, 0, d(16) * sin(clock * 0.8))
		elseif pose == P.Idle and mood == "Playful" then
			-- Nodding along to a tune only he hears.
			add(t, "Neck", d(5) * sin(clock * 4.4))
			add(t, "Waist", 0, 0, d(2.5) * sin(clock * 2.2))
		end
		if pose == P.Hold and (ctx.heldFor or 0) > 0 then
			-- Frozen but alive (the owner's choice, 2026-10-06): held, he never
			-- moves a stud, but his head tips further the longer you look,
			-- from 14 degrees to about 70: far past where a neck should stop.
			add(t, "Neck", 0, 0, d(math.min(56, ctx.heldFor * 7)))
		end
	elseif pose == P.Walk then
		clasp(t)
		add(t, "Waist", d(-5))
		legs(t, ctx.phase, GAIT.Walk)
	elseif pose == P.Run then
		add(t, "Waist", d(-20))
		add(t, "Neck", d(12))
		local s = sin(ctx.phase * TAU)
		add(t, "LeftShoulder", d(-12) - d(24) * s, 0, d(-6))
		add(t, "RightShoulder", d(-12) + d(24) * s, 0, d(6))
		add(t, "LeftElbow", d(18))
		add(t, "RightElbow", d(18))
		legs(t, ctx.phase, GAIT.Run)
	elseif pose == P.Creep then
		-- Hunched low, arms hanging long in front, head craned up at you.
		add(t, "Root", 0, 0, 0, 0, -0.7, 0)
		add(t, "Waist", d(-30))
		add(t, "Neck", d(26))
		add(t, "LeftShoulder", d(34), 0, d(4))
		add(t, "RightShoulder", d(34), 0, d(-4))
		add(t, "LeftElbow", d(10))
		add(t, "RightElbow", d(10))
		add(t, "LeftHip", d(28))
		add(t, "RightHip", d(28))
		add(t, "LeftKnee", d(-52))
		add(t, "RightKnee", d(-52))
		legs(t, ctx.phase, GAIT.Creep)
	elseif pose == P.BackAway then
		add(t, "Waist", d(5))
		hang(t)
		legs(t, ctx.phase, GAIT.BackAway)
	elseif pose == P.Peek then
		-- Leaning sideways out from behind a door frame; the near hand
		-- grips the jamb at head height.
		local lean = math.clamp(ctx.lean or 1, -1, 1)
		add(t, "Root", 0, 0, -lean * d(16), lean * 0.35, -0.15, 0)
		add(t, "Waist", d(-12), 0, -lean * d(24))
		add(t, "Neck", d(8), 0, -lean * d(26))
		hang(t)
		if lean >= 0 then
			add(t, "RightShoulder", d(96), 0, d(34))
			add(t, "RightElbow", d(70))
			add(t, "RightWrist", d(20))
		else
			add(t, "LeftShoulder", d(96), 0, d(-34))
			add(t, "LeftElbow", d(70))
			add(t, "LeftWrist", d(20))
		end
	elseif pose == P.Zoom then
		-- Yanked away like a puppet: rigid, gliding, arms trailing towards you.
		add(t, "LeftShoulder", d(42), 0, d(-10))
		add(t, "RightShoulder", d(42), 0, d(10))
		add(t, "LeftHip", d(10))
		add(t, "RightHip", d(10))
		add(t, "LeftAnkle", d(-30))
		add(t, "RightAnkle", d(-30))
	elseif pose == P.Stagger then
		-- Knocked off balance for a moment: rocked back, head thrown aside,
		-- hands come up, knees give. He still never turns his back.
		add(t, "Root", 0, 0, 0, 0, -0.45, 0.35)
		add(t, "Waist", d(14), d(-10), d(8))
		add(t, "Neck", d(-22), d(-34), d(18))
		add(t, "LeftShoulder", d(70), 0, d(-28))
		add(t, "RightShoulder", d(58), 0, d(30))
		add(t, "LeftElbow", d(80))
		add(t, "RightElbow", d(64))
		add(t, "LeftHip", d(16))
		add(t, "RightHip", d(6))
		add(t, "LeftKnee", d(-30))
		add(t, "RightKnee", d(-16))
	elseif pose == P.Usher then
		-- "After you": stepped aside against the wall, a slight bow, the left
		-- hand at his chest and the right held out, open, towards the way on.
		add(t, "Waist", d(-14))
		add(t, "Neck", d(10))
		add(t, "LeftShoulder", d(30), d(-40), d(3))
		add(t, "LeftElbow", d(84))
		add(t, "RightShoulder", d(52), 0, d(30))
		add(t, "RightElbow", d(14))
		add(t, "RightWrist", d(-22))
	elseif pose == P.FingersPeek then
		-- Behind the wall beside the doorway, upright and still; the near arm
		-- reaches up and out so only the hand curls round the frame at head
		-- height (GuestPose.fingers is where).
		local side = (ctx.lean or 1) >= 0 and 1 or -1
		add(t, "Waist", d(-4), 0, -side * d(4))
		add(t, "Neck", d(6), 0, -side * d(10))
		hang(t)
		if side > 0 then
			add(t, "RightShoulder", d(30), 0, d(100))
			add(t, "RightElbow", d(40))
			add(t, "RightWrist", d(10))
		else
			add(t, "LeftShoulder", d(30), 0, d(-100))
			add(t, "LeftElbow", d(40))
			add(t, "LeftWrist", d(10))
		end
	elseif pose == P.Duck then
		-- Dropped low in a blink, folded over his knees, head up at you.
		add(t, "Root", 0, 0, 0, 0, -0.8, 0)
		add(t, "Waist", d(-70))
		add(t, "Neck", d(50))
		add(t, "LeftShoulder", d(40), 0, d(6))
		add(t, "RightShoulder", d(40), 0, d(-6))
		add(t, "LeftHip", d(70))
		add(t, "RightHip", d(70))
		add(t, "LeftKnee", d(-120))
		add(t, "RightKnee", d(-120))
	elseif pose == P.Listen then
		-- Stopped dead in a hunt: bent a little forward, the head cocked far
		-- over to one side (the tilt adds to it), hands open at his sides.
		add(t, "Waist", d(-12))
		add(t, "Neck", d(-6), 0, d(26))
		hang(t)
		add(t, "LeftShoulder", 0, 0, d(-10))
		add(t, "RightShoulder", 0, 0, d(10))
	elseif pose == P.Crawl then
		-- On all fours (docs/ART.md "The Guest", 2026-10-07): knees drawn up
		-- high like a spider's, the long arms reaching ahead to the floor, the
		-- head twisted over. The body is shifted back over where he really is,
		-- so his hands don't reach through the walls ahead.
		local s = sin(ctx.phase * TAU)
		add(t, "Root", d(-30), 0, 0, 0, -1.6, 1.8)
		add(t, "Waist", d(-45))
		add(t, "Neck", d(60), 0, d(135))
		add(t, "LeftShoulder", d(120) - d(22) * s, 0, d(-6))
		add(t, "RightShoulder", d(120) + d(22) * s, 0, d(6))
		add(t, "LeftElbow", d(-20))
		add(t, "RightElbow", d(-20))
		add(t, "LeftWrist", d(-20))
		add(t, "RightWrist", d(-20))
		add(t, "LeftHip", d(100))
		add(t, "RightHip", d(100))
		add(t, "LeftKnee", d(-100))
		add(t, "RightKnee", d(-100))
		legs(t, ctx.phase, GAIT.Crawl)
	elseif pose == P.Lunge then
		add(t, "Root", 0, 0, 0, 0, -0.35, -0.6)
		add(t, "Waist", d(-34))
		add(t, "Neck", d(30))
		add(t, "LeftShoulder", d(108), 0, d(10))
		add(t, "RightShoulder", d(108), 0, d(-10))
		add(t, "LeftElbow", d(4))
		add(t, "RightElbow", d(4))
		add(t, "LeftHip", d(30))
		add(t, "RightHip", d(-24))
		add(t, "LeftKnee", d(-40))
		add(t, "RightKnee", d(-20))
	end

	-- His carriage (the mask over the dark): a slight hunch, the long neck
	-- carried forward and the face lifted to you.
	if HUNCHED[pose] then
		add(t, "Waist", d(-5))
		add(t, "Neck", d(6))
	end

	-- Unfolding to his full height once a door frame is behind him.
	local unfold = ctx.unfold or 0
	if unfold > 0 then
		add(t, "Waist", d(6) * unfold)
		add(t, "Neck", d(-5) * unfold)
	end

	-- Ducking under door frames: he is taller than every doorway.
	local stoop = ctx.stoop or 0
	if stoop > 0 then
		add(t, "Waist", -d(16) * stoop)
		add(t, "Neck", -d(12) * stoop)
		add(t, "Root", 0, 0, 0, 0, -0.35 * stoop, 0)
		add(t, "LeftKnee", -d(14) * stoop)
		add(t, "RightKnee", -d(14) * stoop)
	end
	if (ctx.form or 0) >= 2 and REVERSE_KNEES[pose] then
		if pose == P.Creep then
			-- Crouched the other way: thighs back, shins forward.
			add(t, "LeftHip", d(-56))
			add(t, "RightHip", d(-56))
		end
		t.LeftKnee[1] = -t.LeftKnee[1]
		t.RightKnee[1] = -t.RightKnee[1]
	end
	flatFeet(t)

	-- The head tilt (14 degrees for The Guest) is always there.
	add(t, "Neck", 0, 0, d(ctx.tilt or 14))

	-- Looking at someone: most of the turn is in the neck, far past what a
	-- person could do; the waist only helps a little.
	if ctx.gazeYaw then
		local yaw = ctx.gazeYaw
		local waistYaw = math.clamp(yaw * 0.2, -d(28), d(28))
		local neckMax = d(ctx.neckYawMax or 160)
		add(t, "Waist", 0, waistYaw)
		add(t, "Neck", math.clamp(ctx.gazePitch or 0, -d(50), d(60)), math.clamp(yaw - waistYaw, -neckMax, neckMax))
	end

	-- His neck drawn out along itself (the neck's own up: Rx * Ry * Rz of +Y).
	local stretch = GuestPose.neckStretch(pose, ctx.form, ctx.heldFor)
	if stretch > 0 then
		local n = t.Neck
		local x, y, z = n[1], n[2], n[3]
		n[4] += -sin(z) * cos(y) * stretch
		n[5] += (cos(z) * cos(x) - sin(z) * sin(y) * sin(x)) * stretch
		n[6] += (cos(z) * sin(x) + sin(z) * sin(y) * cos(x)) * stretch
	end
	return t
end

GuestPose.Gait = GAIT
GuestPose.Rate = RATE

function GuestPose.new()
	return {
		values = blank(),
		phase = 0,
		breath = 0,
		t = 0,
		twitch = nil, -- { joint, values, untilT }
		nextTwitch = 2,
	}
end

-- Advance the gait. forward is the signed speed along his facing (studs/s);
-- walking backwards runs the cycle backwards. Returns the feet that landed.
function GuestPose.advance(state, pose: string, forward: number, dt: number): { string }
	local spec = GAIT[pose]
	local planted = {}
	if not spec or math.abs(forward) < 0.15 then
		return planted
	end
	local before = state.phase
	local after = before + forward * dt / (2 * spec.stride)
	-- A foot lands when its hip reaches the front of the swing (or the back,
	-- walking backwards): left at a quarter cycle, right at three quarters.
	for _, mark in { { 0.25, "Left" }, { 0.75, "Right" } } do
		local lo, hi = math.min(before, after), math.max(before, after)
		local k = math.ceil(lo - mark[1])
		while mark[1] + k <= hi do
			if mark[1] + k > lo then
				table.insert(planted, mark[2])
			end
			k += 1
		end
	end
	state.phase = after % 1
	return planted
end

-- One frame. input: { pose, forward, tilt, lean, stoop, gazeYaw, gazePitch,
-- neckYawMax, mood (Logic/GuestMood), heldFor (seconds held, for "frozen
-- but alive"), snapNeck (the head snaps to a light this frame), random =
-- function() -> 0..1 (cosmetic) }.
-- Returns the smoothed joint values and the feet that landed this frame.
function GuestPose.step(state, input, dt: number)
	local pose = GuestPose.Poses[input.pose] and input.pose or "Idle"
	state.t += dt
	state.breath = (state.breath + dt * 0.22) % 1
	local planted = GuestPose.advance(state, pose, input.forward or 0, dt)
	local target = GuestPose.target({
		pose = pose,
		phase = state.phase,
		breath = state.breath,
		tilt = input.tilt,
		lean = input.lean,
		stoop = input.stoop,
		gazeYaw = input.gazeYaw,
		gazePitch = input.gazePitch,
		neckYawMax = input.neckYawMax,
		mood = input.mood,
		heldFor = input.heldFor,
		unfold = input.unfold,
		form = input.form,
		t = state.t,
	})

	-- Twitches while still: a sudden jerk of the head or a shoulder that
	-- snaps in and eases out. Cosmetic, so math.random is fine here.
	local random = input.random
	local still = pose == "Idle" or pose == "Hold" or pose == "BackAway" or pose == "Peek"
	if random and still and state.t >= state.nextTwitch and not state.twitch then
		local joint = random() < 0.7 and "Neck" or (random() < 0.5 and "LeftShoulder" or "RightShoulder")
		local size = joint == "Neck" and 16 or 9
		state.twitch = {
			joint = joint,
			values = { d((random() - 0.5) * size), d((random() - 0.5) * size), d((random() - 0.5) * size * 1.4) },
			untilT = state.t + 0.12 + random() * 0.15,
		}
		-- An irritated Guest twitches far more often (Logic/GuestMood).
		local gap = input.mood == "Irritated" and (0.8 + random() * 1.6) or (2.5 + random() * 6)
		state.nextTwitch = state.t + gap
	end
	local twitch = state.twitch
	if twitch then
		if state.t > twitch.untilT then
			state.twitch = nil
		else
			local v = target[twitch.joint]
			v[1] += twitch.values[1]
			v[2] += twitch.values[2]
			v[3] += twitch.values[3]
		end
	end

	local rate = RATE[pose] or 6
	local alpha = 1 - math.exp(-rate * dt)
	local snap = 1 - math.exp(-40 * dt)
	for joint, goal in target do
		local v = state.values[joint]
		-- Twitches and the legs' stepping snap; everything else eases.
		local a = (twitch and joint == twitch.joint) and snap or alpha
		if input.snapNeck and joint == "Neck" then
			a = 1
		end
		if GAIT[pose] and (string.find(joint, "Hip") or string.find(joint, "Knee") or string.find(joint, "Ankle")) then
			a = math.max(a, 1 - math.exp(-18 * dt))
		end
		for i = 1, 6 do
			v[i] += (goal[i] - v[i]) * a
		end
	end
	return state.values, planted
end

-- Spine kinematics ----------------------------------------------------------------
-- Where his chest and head are for a set of joint values, in body space
-- relative to the root's centre. The server uses this to know what you can
-- see of him while he leans round a door frame (its own joints never move).

local function rotation(rx: number, ry: number, rz: number)
	-- Rx * Ry * Rz, as CFrame.Angles composes them.
	local cx, sx, cy, sy, cz, sz = cos(rx), sin(rx), cos(ry), sin(ry), cos(rz), sin(rz)
	local x = { { 1, 0, 0 }, { 0, cx, -sx }, { 0, sx, cx } }
	local y = { { cy, 0, sy }, { 0, 1, 0 }, { -sy, 0, cy } }
	local z = { { cz, -sz, 0 }, { sz, cz, 0 }, { 0, 0, 1 } }
	local function mul(a, b)
		local m = {}
		for i = 1, 3 do
			m[i] = {}
			for j = 1, 3 do
				m[i][j] = a[i][1] * b[1][j] + a[i][2] * b[2][j] + a[i][3] * b[3][j]
			end
		end
		return m
	end
	return mul(mul(x, y), z), mul
end

local function apply(m, v)
	return {
		m[1][1] * v[1] + m[1][2] * v[2] + m[1][3] * v[3],
		m[2][1] * v[1] + m[2][2] * v[2] + m[2][3] * v[3],
		m[3][1] * v[1] + m[3][2] * v[2] + m[3][3] * v[3],
	}
end

function GuestPose.spine(values)
	local r = { { 1, 0, 0 }, { 0, 1, 0 }, { 0, 0, 1 } }
	local t = { 0, 0, 0 }
	local function joint(offset, value)
		local o = apply(r, offset)
		t = { t[1] + o[1], t[2] + o[2], t[3] + o[3] }
		local p = apply(r, { value[4], value[5], value[6] })
		t = { t[1] + p[1], t[2] + p[2], t[3] + p[3] }
		local rot, mul = rotation(value[1], value[2], value[3])
		r = mul(r, rot)
	end
	local function at(offset)
		local o = apply(r, offset)
		return { t[1] + o[1], t[2] + o[2], t[3] + o[3] }
	end
	joint({ 0, Rig.lowerTorsoY - Rig.rootY, 0 }, values.Root)
	joint({ 0, Rig.waistY - Rig.lowerTorsoY, 0 }, values.Waist)
	local chest = at({ 0, Rig.upperTorsoSize[2] / 2, 0 })
	joint({ 0, Rig.neckY - Rig.waistY, 0 }, values.Neck)
	local head = at({ 0, Rig.neckLength + Rig.headSize[2] / 2, 0 })
	return head, chest
end

-- Where the hand on the frame is in FingersPeek, in body space relative to
-- the root's centre (x right, y up, z back): what a Witness can see of him.
function GuestPose.fingers(lean: number?): { number }
	local side = (lean or 1) >= 0 and 1 or -1
	return { side * 2.5, Rig.headY - Rig.rootY - 0.25, -0.2 }
end

-- Head and chest offsets for a pose as the clients will settle into it
-- (form: at Breaking his neck draws out).
function GuestPose.exposed(pose: string, lean: number?, stoop: number?, form: number?)
	local values =
		GuestPose.target({ pose = pose, phase = 0, breath = 0, lean = lean, stoop = stoop, tilt = 14, form = form })
	return GuestPose.spine(values)
end

-- Gaze angles towards a point given in body space (x right, y up, z back),
-- measured from the neck.
function GuestPose.gazeAngles(x: number, y: number, z: number): (number, number)
	local yaw = math.atan2(-x, -z)
	local flat = math.sqrt(x * x + z * z)
	local pitch = math.atan2(y, math.max(flat, 1e-3))
	return yaw, pitch
end

-- How far to duck at a position, from its distance to the nearest doorway
-- line (rooms are cells of `cell` studs with doorways in the middle of each
-- side). x and z are relative to the grid origin.
function GuestPose.stoop(x: number, z: number, cell: number, doorHalfWidth: number): number
	local half = cell / 2
	local function along(v: number): number
		return math.abs(((v + half) % cell) - half)
	end
	-- Distance to the nearest wall line on each axis, and how central the
	-- doorway is on that wall.
	local dx = half - along(x) -- distance to a wall line crossing x
	local dz = half - along(z)
	local best = 0
	if along(z) <= doorHalfWidth + 1 then
		best = math.max(best, math.clamp(1 - dx / 3, 0, 1))
	end
	if along(x) <= doorHalfWidth + 1 then
		best = math.max(best, math.clamp(1 - dz / 3, 0, 1))
	end
	return best
end

-- The smile (owner, 2026-10-03): a thin, closed, far-too-wide line at Calm;
-- ear to ear and open on too many teeth from Fraying; wider still once the
-- porcelain cracks. It also widens and opens when he's close or backing
-- away. form: 0 Calm, 1 Fraying, 2 Breaking. closeness: 0 far .. 1 at arm's
-- length. Returns the half-width in radians (around the head) and how open
-- the mouth is (0..1).
function GuestPose.smile(form: number, closeness: number, backingAway: boolean): (number, number)
	local widths = { [0] = 62, [1] = 96, [2] = 104 }
	local opens = { [0] = 0, [1] = 0.4, [2] = 0.62 }
	local f = math.clamp(math.floor(form), 0, 2)
	local c = math.clamp(closeness, 0, 1)
	local width = widths[f] + 8 * c
	local open = opens[f] + (f > 0 and 0.3 * c or 0.12 * c) + ((backingAway and f > 0) and 0.18 or 0)
	return rad(math.min(width, 110)), math.clamp(open, 0, 1)
end

-- A point on the head (an ellipsoid with half-sizes a, b, c) at azimuth
-- theta (0 = the middle of the face, + towards his left) and elevation phi.
-- Returns the position and the surface's outward normal, in head space.
function GuestPose.surface(a: number, b: number, c: number, theta: number, phi: number)
	local x = -a * cos(phi) * sin(theta)
	local y = b * sin(phi)
	local z = -c * cos(phi) * cos(theta)
	local nx, ny, nz = x / (a * a), y / (b * b), z / (c * c)
	local n = math.sqrt(nx * nx + ny * ny + nz * nz)
	return { x, y, z }, { nx / n, ny / n, nz / n }
end

local function cross(u, v)
	return { u[2] * v[3] - u[3] * v[2], u[3] * v[1] - u[1] * v[3], u[1] * v[2] - u[2] * v[1] }
end

local function normalize(v)
	local m = math.sqrt(v[1] * v[1] + v[2] * v[2] + v[3] * v[3])
	if m < 1e-9 then
		return { 1, 0, 0 }
	end
	return { v[1] / m, v[2] / m, v[3] / m }
end

-- A flat piece lying on the head between two surface points: centre, the
-- right vector (along the piece) and the up vector (in the surface).
-- Used for the lips, mouth, teeth, cracks and blood.
function GuestPose.piece(a: number, b: number, c: number, t1: number, p1: number, t2: number, p2: number)
	local q1, n1 = GuestPose.surface(a, b, c, t1, p1)
	local q2, n2 = GuestPose.surface(a, b, c, t2, p2)
	local centre = { (q1[1] + q2[1]) / 2, (q1[2] + q2[2]) / 2, (q1[3] + q2[3]) / 2 }
	local normal = normalize({ n1[1] + n2[1], n1[2] + n2[2], n1[3] + n2[3] })
	local along = { q2[1] - q1[1], q2[2] - q1[2], q2[3] - q1[3] }
	local length = math.sqrt(along[1] ^ 2 + along[2] ^ 2 + along[3] ^ 2)
	local right = normalize(along)
	local up = normalize(cross(normal, right))
	return { centre = centre, right = right, up = up, normal = normal, length = length }
end

-- The mouth: `count` columns across the smile. Each column has the upper
-- lip's elevation and the lower lip's. A deep crescent: low in the middle,
-- the corners curling on up the cheeks towards the eyes (it reads as a
-- grin, not a puppet's mouth); one corner sits a little higher than the
-- other. Open, it's a crescent: tall in the middle, shut at the corners.
function GuestPose.mouth(halfWidth: number, open: number, count: number)
	local columns = {}
	local front = rad(60)
	for i = 0, count do
		local u = i / count * 2 - 1 -- -1 .. 1 across the mouth
		local theta = u * halfWidth
		local k = theta / front
		local taper = 1 - u * u
		-- A deep crescent (the owner, 2026-10-07: flatter, it looked like a
		-- muppet's): low in the middle, the corners climbing on up the cheeks
		-- towards the eyes instead of levelling off round them.
		local upper = rad(-30) + math.min(rad(26) * k * k, rad(44)) + rad(4) * u * u * u + rad(4) * open * taper
		local lower = upper - rad(26) * open * taper ^ 1.2
		table.insert(columns, { theta = theta, upper = upper, lower = lower })
	end
	return columns
end

-- Cracks across the porcelain and blood from the eyes, as polylines of
-- (theta, phi) in radians. Fixed shapes: everyone sees the same face.
GuestPose.Cracks = {
	{ { -0.05, 1.25 }, { 0.08, 0.95 }, { 0.02, 0.7 }, { 0.17, 0.45 }, { 0.3, 0.32 } },
	{ { 0.08, 0.95 }, { -0.12, 0.82 }, { -0.22, 0.62 } },
	{ { 0.02, 0.7 }, { 0.12, 0.62 } },
	{ { -0.62, 0.55 }, { -0.5, 0.35 }, { -0.42, 0.1 }, { -0.52, -0.1 } },
	{ { 0.55, -0.15 }, { 0.68, -0.32 }, { 0.62, -0.55 } },
}
GuestPose.Blood = {
	{ { 0.4, 0.12 }, { 0.41, -0.05 }, { 0.38, -0.25 }, { 0.4, -0.45 }, { 0.37, -0.62 } },
	{ { -0.4, 0.12 }, { -0.42, -0.08 }, { -0.4, -0.3 }, { -0.43, -0.5 } },
	{ { 0.33, 0.12 }, { 0.31, -0.02 }, { 0.32, -0.16 } },
}
GuestPose.Eyes = { { 0.4, 0.2 }, { -0.4, 0.2 } } -- (theta, phi) of each eye hollow

-- Where the mask has come away at Breaking (Lib/GuestFace): thick paths of
-- (theta, phi) that show the black beneath. One from the brow through the
-- left eye, one at the right of the jaw.
GuestPose.Shards = {
	{ width = 0.07, path = { { -0.66, 0.66 }, { -0.55, 0.52 }, { -0.46, 0.44 }, { -0.5, 0.3 } } },
	{ width = 0.05, path = { { -0.55, 0.52 }, { -0.62, 0.36 }, { -0.6, 0.18 }, { -0.66, 0.02 } } },
	{ width = 0.06, path = { { 0.3, -0.48 }, { 0.42, -0.4 }, { 0.55, -0.47 }, { 0.64, -0.62 } } },
	{ width = 0.04, path = { { 0.42, -0.4 }, { 0.47, -0.26 }, { 0.58, -0.2 } } },
}

return GuestPose
