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

local GuestGait = require(script.Parent.GuestGait)
local Kinematics = require(script.Parent.Kinematics)

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
	Reach = "Reach", -- coming for whoever tailed him: walking at them, both hands out to grab them
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
	Reach = 3, -- the arm comes up slowly
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
local REVERSE_KNEES = { Walk = true, Run = true, Creep = true, BackAway = true, Reach = true }

-- And his neck draws out of his collar (studs): leaning round a frame,
-- creeping, lunging, listening; held, the longer the further.
local STRETCH = { Peek = 0.8, FingersPeek = 0.5, Creep = 0.6, Lunge = 1.0, Listen = 0.45, Reach = 0.7 }

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

-- How far a stare's hold wearing thin shakes his head, at its last (degrees,
-- each way's span; GuestPose.step `tremble`).
local TREMBLE_DEGREES = 7

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

-- Ducking under a door frame (stoop 0..1): his hips sink (the knees bend
-- onto his feet), the pelvis tips, he folds forward at the waist, the
-- shoulders hunch round and the head bows under it, his face still lifted
-- to you (the gaze adds that).
local function stoopInto(t, stoop: number)
	if stoop <= 0 then
		return
	end
	add(t, "Root", -d(6) * stoop, 0, 0, 0, -0.42 * stoop, 0)
	add(t, "Waist", -d(17) * stoop)
	add(t, "Neck", -d(12) * stoop)
	add(t, "LeftShoulder", d(8) * stoop, 0, d(-4) * stoop)
	add(t, "RightShoulder", d(8) * stoop, 0, d(4) * stoop)
	add(t, "LeftKnee", -d(14) * stoop)
	add(t, "RightKnee", -d(14) * stoop)
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
		elseif pose == P.Idle and mood == "Host" then
			-- Playing host: a little bow, as to a guest, his face still on you.
			add(t, "Waist", d(-11))
			add(t, "Neck", d(11))
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
	elseif pose == P.Reach then
		-- Coming for whoever tailed him (the owner, 2026-10-11): leaning in,
		-- the head cocked, both arms out at your face, closing in a little
		-- (the hands meet round your face, not either side of your head), the
		-- palms facing, the fingers spread and hooked to grab you
		-- (the owner: "make his hands spread like hes trying to grab you";
		-- GuestController's FINGER_SPREAD). They dip with his look down at
		-- you, about half as far (his shoulders are below his eyes), so from
		-- close the claws come at your face, neither over your head nor at
		-- your chest; they shake a little, each on its own.
		local clock = ctx.t or 0
		local down = math.clamp(ctx.gazePitch or 0, d(-45), 0)
		add(t, "Waist", d(-9))
		add(t, "Neck", d(8), 0, d(10))
		add(t, "RightShoulder", d(84) + down * 0.55 + d(1.2) * sin(clock * 11), 0, d(-5))
		add(t, "LeftShoulder", d(81) + down * 0.55 + d(1.2) * sin(clock * 9.1 + 1), 0, d(5))
		add(t, "RightElbow", d(5) + d(1.5) * sin(clock * 7.3))
		add(t, "LeftElbow", d(8) + d(1.5) * sin(clock * 6.1 + 2))
		add(t, "RightWrist", d(-24))
		add(t, "LeftWrist", d(-24))
		legs(t, ctx.phase, GAIT.Walk)
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
		-- The free arm dangles to the floor, not along his tilted body (it
		-- stuck out into the doorway like a stick).
		local free = lean >= 0 and "Left" or "Right"
		add(t, free .. "Shoulder", d(6), 0, lean * d(38))
		add(t, free .. "Elbow", d(22))
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
	stoopInto(t, ctx.stoop or 0)
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

-- Smoothing (the animation pass, 2026-10-11: "make the movement more
-- smooth"): every joint follows a critically damped spring, so a change of
-- pose eases in and out with no pop. Stiffness (1/s) by pose; about 4/k
-- seconds to settle. The fast ones (a lunge, a duck) are still a blink.
local SPRING = {}
for name, rate in RATE do
	SPRING[name] = rate * 1.35
end
GuestPose.Spring = SPRING

-- Poses whose legs the pose draws itself; every other pose stands on the
-- feet Logic/GuestGait plants.
local KEYED_LEGS = { Zoom = true, Lunge = true, Stagger = true, Duck = true, Crawl = true }
GuestPose.KeyedLegs = KEYED_LEGS

-- The gait each moving pose walks with; a standing pose that has to move
-- (he's pushed, he shuffles round) walks.
local WALKS = {
	Walk = GuestGait.Specs.Walk,
	Run = GuestGait.Specs.Run,
	Creep = GuestGait.Specs.Creep,
	BackAway = GuestGait.Specs.BackAway,
	Reach = GuestGait.Specs.Walk,
}

-- Standing feet, side to side (studs), by pose.
GuestPose.Stance = {
	Idle = { width = 0.74 },
	Hold = { width = 0.74 },
	Bow = { width = 0.6 },
	Usher = { width = 0.86 },
	Peek = { width = 1.2 },
	FingersPeek = { width = 0.82 },
	Listen = { width = 1.0 },
	Walk = { width = 0.78 },
	Run = { width = 0.7 },
	Creep = { width = 1.0 },
	BackAway = { width = 0.8 },
	Reach = { width = 0.78 },
}

-- A leg reaches this far from hip to ankle before it's straight: just short,
-- so a planted leg is never locked.
local LEG_REACH = (Rig.upperLeg + Rig.lowerLeg) * 0.985
-- The most his hips drop to reach a planted foot (studs).
GuestPose.MaxDrop = 1.2

-- Joint offsets in the rest pose, each from its parent joint.
local ROOT_JOINT = { 0, Rig.lowerTorsoY - Rig.rootY, 0 }
local WAIST_JOINT = { 0, Rig.waistY - Rig.lowerTorsoY, 0 }
local HIP = {
	Left = { -Rig.hipX, Rig.hipY - Rig.lowerTorsoY, 0 },
	Right = { Rig.hipX, Rig.hipY - Rig.lowerTorsoY, 0 },
}
local SHOULDER = {
	Left = { -Rig.shoulderX, Rig.shoulderY - Rig.waistY, 0 },
	Right = { Rig.shoulderX, Rig.shoulderY - Rig.waistY, 0 },
}
local KNEE = { 0, -Rig.upperLeg, 0 }
local ANKLE = { 0, -Rig.lowerLeg, 0 }
GuestPose.HipOffset = HIP
GuestPose.ShoulderOffset = SHOULDER
GuestPose.WaistOffset = WAIST_JOINT
GuestPose.NeckOffset = { 0, Rig.neckY - Rig.waistY, 0 }

local LEG_JOINTS = {
	"LeftHip",
	"LeftKnee",
	"LeftAnkle",
	"RightHip",
	"RightKnee",
	"RightAnkle",
}
local ARM_JOINTS = {
	Left = { "LeftShoulder", "LeftElbow", "LeftWrist" },
	Right = { "RightShoulder", "RightElbow", "RightWrist" },
}

function GuestPose.new()
	return {
		values = blank(), -- the springs' positions
		vel = blank(), -- and their velocities
		out = blank(), -- what's drawn: the springs, legs on the feet, a hand on the frame
		phase = 0,
		breath = 0,
		t = 0,
		twitch = nil, -- { joint, values, at }
		nextTwitch = 2,
		gait = nil, -- Logic/GuestGait, from the first frame with a root
		legWeight = 1, -- 1: legs on the planted feet; 0: the pose's own
		legVel = 0,
		drop = 0, -- how far his hips are down to reach his feet (studs)
		dropVel = 0,
		sway = { 0, 0 },
		roll = { 0, 0 },
		turn = { 0, 0 },
		lurch = { 0, 0 },
		grip = 0, -- 1: his hand is on the door frame
		gripVel = 0,
		sim = nil, -- a stand-in root for callers that give none (lune specs)
	}
end

-- Advance the phase the pose's own legs swing by (the crawl, and the
-- server's view of a walking pose). forward is the signed speed along his
-- facing; walking backwards runs it backwards. Returns the feet that landed.
function GuestPose.advance(state, pose: string, forward: number, dt: number): { string }
	local spec = GAIT[pose]
	local planted = {}
	if not spec or math.abs(forward) < 0.15 then
		return planted
	end
	local before = state.phase
	local after = before + forward * dt / (2 * spec.stride)
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

-- His pelvis (the Root joint's frame) in root space.
local function pelvisFrame(rootValue)
	return Kinematics.child(Kinematics.frame(), ROOT_JOINT, rootValue)
end
GuestPose.pelvisFrame = pelvisFrame

-- A world point in his root's space (x right, y up, z back).
local function toRoot(root, x: number, y: number, z: number)
	local dx, dy, dz = x - root.x, y - root.y, z - root.z
	local rx, rz = -root.fz, root.fx
	return { dx * rx + dz * rz, dy, -(dx * root.fx + dz * root.fz) }
end
GuestPose.toRoot = toRoot

-- And back.
local function toWorld(root, p)
	local rx, rz = -root.fz, root.fx
	return root.x + rx * p[1] - root.fx * p[3], root.y + p[2], root.z + rz * p[1] - root.fz * p[3]
end
GuestPose.toWorld = toWorld

-- Bend a leg so its ankle is at `ankle` (root space), the foot turned `yaw`
-- from his facing and pitched `pitch` (toe down < 0). The knee points the
-- way the foot does, or backwards at Breaking (`reverse`). Writes the hip,
-- knee and ankle into `out`.
local function bendLeg(out, side: string, pelvis, ankle, yaw: number, pitch: number, reverse: boolean)
	local hip = Kinematics.compose(pelvis, Kinematics.frame(nil, HIP[side]))
	local target = Kinematics.toLocal(hip, ankle)
	local ahead = { -math.sin(yaw), 0, -math.cos(yaw) }
	local pole = Kinematics.apply(Kinematics.transpose(hip.r), reverse and Kinematics.scale(ahead, -1) or ahead)
	local rx, ry, rz, fold, r = Kinematics.twoBone(target, Rig.upperLeg, Rig.lowerLeg, reverse and 1 or -1, pole)
	local h, k, a = out[side .. "Hip"], out[side .. "Knee"], out[side .. "Ankle"]
	h[1], h[2], h[3], h[4], h[5], h[6] = rx, ry, rz, 0, 0, 0
	k[1], k[2], k[3], k[4], k[5], k[6] = fold, 0, 0, 0, 0, 0
	local leg = Kinematics.mul(Kinematics.mul(hip.r, r), Kinematics.rot(fold, 0, 0))
	local want = Kinematics.mul(Kinematics.rot(0, yaw, 0), Kinematics.rot(pitch, 0, 0))
	local ax, ay, az = Kinematics.euler(Kinematics.mul(Kinematics.transpose(leg), want))
	a[1], a[2], a[3], a[4], a[5], a[6] = ax, ay, az, 0, 0, 0
end
GuestPose.bendLeg = bendLeg

-- The top of his head and the middle of his face for a set of joint values
-- (root space): what has to pass under a door frame.
function GuestPose.head(values)
	local pelvis = pelvisFrame(values.Root)
	local chest = Kinematics.child(pelvis, WAIST_JOINT, values.Waist)
	local neck = Kinematics.child(chest, { 0, Rig.neckY - Rig.waistY, 0 }, values.Neck)
	local top = Kinematics.point(neck, { 0, Rig.neckLength + Rig.headSize[2], 0 })
	local middle = Kinematics.point(neck, { 0, Rig.neckLength + Rig.headSize[2] / 2, 0 })
	return top, middle
end

-- Where a wrist is for a set of joint values (root space).
function GuestPose.wrist(values, side: string)
	local pelvis = pelvisFrame(values.Root)
	local chest = Kinematics.child(pelvis, WAIST_JOINT, values.Waist)
	local shoulder = Kinematics.child(chest, SHOULDER[side], values[side .. "Shoulder"])
	local elbow = Kinematics.child(shoulder, { 0, -Rig.upperArm, 0 }, values[side .. "Elbow"])
	return Kinematics.point(elbow, { 0, -Rig.lowerArm, 0 })
end

-- Where each ankle is for a set of joint values (root space).
function GuestPose.ankles(values)
	local pelvis = pelvisFrame(values.Root)
	local result = {}
	for _, side in { "Left", "Right" } do
		local hip = Kinematics.child(pelvis, HIP[side], values[side .. "Hip"])
		local knee = Kinematics.child(hip, KNEE, values[side .. "Knee"])
		result[side] = Kinematics.point(knee, ANKLE)
	end
	return result
end

-- Where his hand on the door frame goes and how it's turned: `grip` is the
-- frame's edge on the far side of the wall, yours (root space), `sign` the
-- way the doorway is from him (+1 his right). His hand comes through the
-- doorway against the frame, the fingers out past your side of the wall and
-- curled round onto it, the palm to the frame. Writes the shoulder, elbow
-- and wrist into `out`.
GuestPose.GripWrist = { 0.22, -0.05, 0.55 } -- the wrist from the edge: into the doorway, down, back towards him
local function reachFrame(out, side: string, pelvis, grip, sign: number, hidden: boolean?)
	local chest = Kinematics.child(pelvis, WAIST_JOINT, out.Waist)
	local shoulder = Kinematics.compose(chest, Kinematics.frame(nil, SHOULDER[side]))
	local at = GuestPose.GripWrist
	local wrist = { grip[1] + sign * at[1], grip[2] + at[2], grip[3] + at[3] }
	local target = Kinematics.toLocal(shoulder, wrist)
	-- Leaning out, the elbow hangs down by the frame, the forearm up along
	-- it (out to the side, it stuck into the doorway like a stick). Only
	-- his fingers round it, the elbow goes into the wall beside the frame,
	-- out of your sight (back or down, it showed in the doorway).
	local bend = if hidden then { -sign, 0.3, 0.3 } else { sign * 0.25, -1, 0 }
	local pole = Kinematics.apply(Kinematics.transpose(shoulder.r), bend)
	local rx, ry, rz, fold, r = Kinematics.twoBone(target, Rig.upperArm, Rig.lowerArm, 1, pole)
	local inward = side == "Left" and 1 or -1
	-- The fingers curl the way the hand's X axis (times `inward`) points:
	-- towards the frame. The hand's -Y (the fingers) points on, past the wall.
	local palm = { -sign * inward, 0, 0 }
	local fingers = { 0, 0, 1 }
	local want = Kinematics.basis(palm, fingers)
	local arm = Kinematics.mul(Kinematics.mul(shoulder.r, r), Kinematics.rot(fold, 0, 0))
	local wx, wy, wz = Kinematics.euler(Kinematics.mul(Kinematics.transpose(arm), want))
	return { rx, ry, rz }, fold, { wx, wy, wz }
end
GuestPose.reachFrame = reachFrame

local function lerp(a: number, b: number, t: number): number
	return a + (b - a) * t
end

local function springPair(pair, goal: number, k: number, dt: number): number
	pair[1], pair[2] = Kinematics.spring(pair[1], pair[2], goal, k, dt)
	return pair[1]
end

-- One frame. input:
--   pose, tilt, lean, stoop, gazeYaw, gazePitch, neckYawMax, mood
--   (Logic/GuestMood), heldFor (seconds held: "frozen but alive"),
--   snapNeck (the head snaps to a light this frame), unfold, form,
--   tremble (0 to 1: a stare's hold wearing thin, his head shaking; `shake`
--   a function -> 0..1 for it, else `random`),
--   random = function() -> 0..1 (cosmetic)
--   root      { x, y, z, fx, fz }: his root in the world and the flat way
--             he faces (if absent, a stand-in walks straight on `forward`)
--   vx, vz    his velocity on the floor plane; forward for the stand-in
--   floor     function(x, z) -> the floor's height there (optional)
--   grip      the door frame's edge he holds, in root space (Peek and
--             FingersPeek; Stalk publishes it)
-- Returns the joint values to draw and the feet that landed this frame.
function GuestPose.step(state, input, dt: number)
	local pose = GuestPose.Poses[input.pose] and input.pose or "Idle"
	dt = math.clamp(dt, 0, 0.1)
	state.t += dt
	state.breath = (state.breath + dt * 0.22) % 1

	-- Where he is. Without a root (the specs), a stand-in walks on `forward`.
	local root, vx, vz = input.root, input.vx or 0, input.vz or 0
	if not root then
		local sim = state.sim or { x = 0, y = Rig.rootY, z = 0, fx = 0, fz = -1 }
		state.sim = sim
		local forward = input.forward or 0
		sim.z -= forward * dt
		vx, vz = 0, -forward
		root = sim
	end
	local floor = input.floor
	local floorY = root.y - Rig.rootY
	if not floor then
		floor = function()
			return floorY
		end
	end
	local forward = vx * root.fx + vz * root.fz
	local planted = GuestPose.advance(state, pose, forward, dt)

	-- The duck has a spring of its own: quick down, slow up.
	local wantStoop = math.clamp(input.stoop or 0, 0, 1)
	state.stoop, state.stoopVel = Kinematics.spring(
		state.stoop or 0,
		state.stoopVel or 0,
		wantStoop,
		wantStoop > (state.stoop or 0) and 18 or 4,
		dt
	)
	local target = GuestPose.target({
		pose = pose,
		phase = state.phase,
		breath = state.breath,
		tilt = input.tilt,
		lean = input.lean,
		stoop = 0,
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
	-- snaps in and eases away. Cosmetic, so math.random is fine here.
	local random = input.random
	local still = pose == "Idle" or pose == "Hold" or pose == "BackAway" or pose == "Peek"
	if random and still and state.t >= state.nextTwitch and not state.twitch then
		local joint = random() < 0.7 and "Neck" or (random() < 0.5 and "LeftShoulder" or "RightShoulder")
		local size = joint == "Neck" and 16 or 9
		state.twitch = {
			joint = joint,
			values = { d((random() - 0.5) * size), d((random() - 0.5) * size), d((random() - 0.5) * size * 1.4) },
			at = state.t,
			hold = 0.12 + random() * 0.15,
		}
		-- An irritated Guest twitches far more often (Logic/GuestMood).
		local gap = input.mood == "Irritated" and (0.8 + random() * 1.6) or (2.5 + random() * 6)
		state.nextTwitch = state.t + gap
	end

	-- The springs.
	local k = SPRING[pose] or 8
	for joint, goal in target do
		local v, w = state.values[joint], state.vel[joint]
		for i = 1, 6 do
			v[i], w[i] = Kinematics.spring(v[i], w[i], goal[i], k, dt)
		end
	end
	if input.snapNeck then
		-- The head snaps to the light that found him.
		local v, w = state.values.Neck, state.vel.Neck
		for i = 1, 6 do
			v[i], w[i] = target.Neck[i], 0
		end
	end
	local out = state.out
	for joint, v in state.values do
		local o = out[joint]
		for i = 1, 6 do
			o[i] = v[i]
		end
	end
	stoopInto(out, math.clamp(state.stoop, 0, 1))
	-- A twitch jerks in at once and eases out.
	local twitch = state.twitch
	if twitch then
		local age = state.t - twitch.at
		local fade = age <= twitch.hold and 1 or math.max(0, 1 - (age - twitch.hold) / 0.25)
		if fade <= 0 then
			state.twitch = nil
		else
			local o = out[twitch.joint]
			for i = 1, 3 do
				o[i] += twitch.values[i] * fade
			end
		end
	end
	-- A stare's hold wearing thin (input.tremble, 0 to 1; "a Guest you can
	-- read", 2026-10-11): his head shakes, harder as it runs out. Drawn only,
	-- never sprung, so it never builds up.
	local tremble = math.clamp(input.tremble or 0, 0, 1)
	if tremble > 0 and out.Neck then
		local shake = input.shake or input.random or math.random
		local o, size = out.Neck, d(TREMBLE_DEGREES) * tremble
		for i = 1, 3 do
			o[i] += (shake() - 0.5) * size
		end
	end

	-- His legs: on the feet the gait plants, or (a lunge, a stagger, the
	-- crawl) the pose's own, blended between.
	local keyed = KEYED_LEGS[pose] == true
	state.legWeight, state.legVel = Kinematics.spring(state.legWeight, state.legVel, keyed and 0 or 1, 12, dt)
	state.legWeight = math.clamp(state.legWeight, 0, 1)
	local gait = state.gait
	-- Put somewhere outright (his arrival, the debug console): his feet go
	-- under him, not a stride across the house.
	local last = state.lastRoot
	if gait and last and ((root.x - last[1]) ^ 2 + (root.z - last[2]) ^ 2 > 25 or math.abs(root.y - last[3]) > 6) then
		gait = nil
	end
	state.lastRoot = { root.x, root.z, root.y }
	if not gait then
		gait = GuestGait.new({ x = root.x, y = root.y, z = root.z, fx = root.fx, fz = root.fz, floor = floorY }, floor)
		state.gait = gait
	end
	local reverse = (input.form or 0) >= 2 and REVERSE_KNEES[pose] == true
	local spec = WALKS[pose]
	if keyed then
		-- Wherever the pose has put them, the feet are planted there for
		-- when the gait takes over again.
		local ankles = GuestPose.ankles(out)
		local now = {}
		for side, a in ankles do
			local x, y, z = toWorld(root, a)
			now[side] = { x = x, y = y - Rig.ankleY, z = z }
		end
		GuestGait.plant(gait, now)
	else
		local moving = spec or ((vx * vx + vz * vz) > GuestGait.MoveSpeed ^ 2 and GuestGait.Specs.Walk or nil)
		local events = GuestGait.step(gait, {
			root = root,
			vx = vx,
			vz = vz,
			spec = moving,
			stance = GuestPose.Stance[pose],
			floor = floor,
		}, dt)
		planted = events
		for _ = 1, #events do
			-- A heavy step: the hips sink a little more as the foot takes him.
			state.dropVel += 1.1
		end
	end

	-- The hips over the feet: sway, the hip's drop on the swinging side, the
	-- turn with the stride (Logic/GuestGait.pelvis), sprung.
	local sway, roll, turn = GuestGait.pelvis(gait, root, spec)
	local w = state.legWeight
	sway = springPair(state.sway, sway * w, 8, dt)
	roll = springPair(state.roll, roll * w, 8, dt)
	turn = springPair(state.turn, turn * w, 9, dt)
	local rootValue = out.Root
	rootValue[4] += sway
	rootValue[3] += roll
	rootValue[2] += turn

	-- Down as far as the legs carrying him need to reach their feet: the bob,
	-- and the lurch onto each step. It falls at once, and rises slowly.
	local feetRoot = {}
	local need = 0
	if w > 0 then
		local pelvis = pelvisFrame(rootValue)
		for _, side in { "Left", "Right" } do
			local f = gait.feet[side]
			local ankle = toRoot(root, f.x, f.y + Rig.ankleY, f.z)
			feetRoot[side] = ankle
			if f.stance then
				local hip = Kinematics.point(pelvis, HIP[side])
				local dx, dz = hip[1] - ankle[1], hip[3] - ankle[3]
				local across = math.min(math.sqrt(dx * dx + dz * dz), LEG_REACH - 0.05)
				local high = math.sqrt(LEG_REACH * LEG_REACH - across * across)
				need = math.max(need, (hip[2] - ankle[2]) - high)
			end
		end
	end
	-- (Never more than a deep knee bend: a foot somehow left far off
	-- straightens his leg towards it rather than sinking him to the floor.)
	need = math.min(need, GuestPose.MaxDrop) * w
	state.drop, state.dropVel = Kinematics.spring(state.drop, state.dropVel, need, 6, dt)
	if state.drop < need then
		state.drop = need
		state.dropVel = math.max(state.dropVel, 0)
	end
	rootValue[5] -= state.drop

	-- The upper body rides it: a lurch forward as the hips fall, the
	-- shoulders and head rolling back against the hips (he keeps his face on
	-- you).
	local lurch = springPair(state.lurch, math.clamp(-state.dropVel * 0.07, -0.22, 0.06) * w, 10, dt)
	out.Waist[1] += lurch
	out.Waist[3] -= roll * 0.6
	out.Neck[3] -= roll * 0.35
	out.Neck[1] -= lurch * 0.6

	-- The legs onto the feet.
	if w > 0 then
		local pelvis = pelvisFrame(rootValue)
		local yaw = GuestGait._yawOf(root.fx, root.fz)
		local keyedLegs = {}
		if w < 1 then
			for _, joint in LEG_JOINTS do
				keyedLegs[joint] = table.clone(out[joint])
			end
		end
		for _, side in { "Left", "Right" } do
			local f = gait.feet[side]
			local rel = (f.yaw - yaw + math.pi) % (2 * math.pi) - math.pi
			bendLeg(out, side, pelvis, feetRoot[side], rel, f.pitch or 0, reverse)
		end
		if w < 1 then
			for _, joint in LEG_JOINTS do
				local o, kv = out[joint], keyedLegs[joint]
				for i = 1, 6 do
					o[i] = lerp(kv[i], o[i], w)
				end
			end
		end
	end

	-- A hand on the door frame as he peeks round it.
	local grip = input.grip
	local gripping = grip ~= nil and (pose == "Peek" or pose == "FingersPeek")
	state.grip, state.gripVel = Kinematics.spring(state.grip, state.gripVel, gripping and 1 or 0, 7, dt)
	state.grip = math.clamp(state.grip, 0, 1)
	if grip and state.grip > 0.001 then
		state.lastGrip = grip
	end
	local held = state.lastGrip
	if held and state.grip > 0.001 then
		local sign = held[1] >= 0 and 1 or -1
		local side = sign > 0 and "Right" or "Left"
		local hidden = pose == "FingersPeek"
		local shoulder, elbow, wrist = reachFrame(out, side, pelvisFrame(rootValue), held, sign, hidden)
		local names = ARM_JOINTS[side]
		local g = state.grip
		for i, angles in { shoulder, { elbow, 0, 0 }, wrist } do
			local o = out[names[i]]
			for axis = 1, 3 do
				o[axis] = lerp(o[axis], angles[axis], g)
			end
		end
	end
	return out, planted
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

-- Ducking for a doorway (the animation pass, 2026-10-11: he's 8.4 studs
-- tall and the openings are 8, and "ducking under doorways" was the owner's
-- note). He sees the frame coming: down before his head gets there (it
-- reaches 2.3 studs ahead of his middle, ducked), and up again once his
-- shoulders are through. openings: { x, z, top (the frame's underside),
-- floor, along ("x" if the opening runs along x, else "z"), half (half its
-- width), depth (half the wall's thickness) }; root: { x, y, z }; vx, vz his
-- velocity. Returns how far to duck, 0..1.
GuestPose.DuckReach = 2.3
GuestPose.DuckBehind = 1.0
function GuestPose.doorStoop(openings, root, vx: number, vz: number): number
	local speed = math.sqrt(vx * vx + vz * vz)
	local feet = root.y - Rig.rootY
	local best = 0
	for _, o in openings do
		if math.abs(feet - o.floor) < 2 and o.top - o.floor < Rig.height + 0.3 then
			local lateral, s, vn
			if o.along == "x" then
				lateral, s, vn = math.abs(root.x - o.x), root.z - o.z, vz
			else
				lateral, s, vn = math.abs(root.z - o.z), root.x - o.x, vx
			end
			local beside = math.clamp((o.half + 1.3 - lateral) / 0.9, 0, 1)
			if beside > 0 then
				local d = math.abs(s) - o.depth
				local want
				if speed < 0.3 then
					want = math.clamp((2.8 - d) / 1.0, 0, 1)
				elseif s * vn < 0 then
					-- Coming towards it: down before his head reaches it.
					local ahead = 1.2 + speed * 0.35
					want = math.clamp((GuestPose.DuckReach + ahead - d) / ahead, 0, 1)
				else
					-- Going away: up once his shoulders are clear.
					want = math.clamp((GuestPose.DuckBehind + 0.8 - d) / 0.8, 0, 1)
				end
				best = math.max(best, want * beside)
			end
		end
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
