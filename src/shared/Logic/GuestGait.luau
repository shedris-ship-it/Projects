-- Where The Guest's feet are (the animation pass, 2026-10-11; the owner:
-- "make the movement more smooth", and his walk "heavy and lurching": a
-- slow, weighty, slightly uneven gait, something too tall for its own legs).
--
-- A foot that carries him stays where it landed, in the world, so nothing
-- slides; the other swings, heel to toe, to where it will be under him at
-- the middle of its next stance. A clock sets the rhythm from his speed;
-- the direction is wherever he's going, so backing away and moving sideways
-- are steps too. Standing, a foot that has drifted from where the pose
-- wants it (he turned, leaned, stopped mid-stride) takes a step of its own,
-- one foot at a time. Logic/GuestPose bends his legs onto these feet
-- (Logic/Kinematics) and drops his hips as far as the stance legs need: the
-- bob and the lurch.
--
-- Pure maths on the floor plane (x, z) with heights: no engine types.

local GuestGait = {}

local sqrt, sin, cos = math.sqrt, math.sin, math.cos
local PI = math.pi

-- step:   studs from one foot's landing to the other's at `speed`
-- stance: the share of the cycle a foot carries him (over 0.5: both feet
--         down a while, heavy; under: a run's flight)
-- lift:   how high a swinging foot comes up
-- width:  feet apart, side to side
-- uneven: the right side's stance is this much longer, its step this much
--         shorter and its lift lower (a drag: the lurch's limp)
GuestGait.Specs = {
	Walk = { step = 3.0, speed = 6, stance = 0.62, lift = 0.6, width = 0.78, uneven = 0.07 },
	Run = { step = 4.8, speed = 17, stance = 0.4, lift = 1.1, width = 0.6, uneven = 0.03 },
	Creep = { step = 1.7, speed = 2.4, stance = 0.7, lift = 0.45, width = 0.95, uneven = 0.05 },
	BackAway = { step = 2.1, speed = 3.5, stance = 0.66, lift = 0.4, width = 0.8, uneven = 0.06 },
}

-- Standing, a foot steps back to its place once it's this far off it.
GuestGait.SettleDistance = 0.45
GuestGait.SettleSeconds = 0.42
GuestGait.SettleLift = 0.32
-- Below this speed he's standing; above it, walking.
GuestGait.MoveSpeed = 0.5
-- Walking, a planted foot this much further off than a stride takes it
-- steps at once.
GuestGait.ReachSlack = 0.3

local FEET = { "Left", "Right" }
local SIDE = { Left = -1, Right = 1 }
local OFFSET = { Left = 0, Right = 0.5 }

local function flatDist(ax: number, az: number, bx: number, bz: number): number
	local dx, dz = ax - bx, az - bz
	return sqrt(dx * dx + dz * dz)
end

-- Where a foot belongs under him: the root's floor point, out to its side
-- (and forward, by the pose's stance), facing his way.
local function neutral(root, foot: string, stance)
	local fx, fz = root.fx, root.fz
	local rx, rz = -fz, fx -- his right
	local side = SIDE[foot]
	local spread = (stance and stance.width or 0.78) / 2
	local ahead = stance and stance[foot] or 0
	local x = root.x + rx * side * spread + fx * ahead
	local z = root.z + rz * side * spread + fz * ahead
	return x, z
end

local function yawOf(fx: number, fz: number): number
	return math.atan2(-fx, -fz)
end

-- A new gait, its feet planted under a root (see step for `root`).
function GuestGait.new(root, floor)
	local state = { phase = 0, moving = false, feet = {}, step = 3, landed = 0 }
	for _, foot in FEET do
		local x, z = neutral(root, foot, nil)
		state.feet[foot] = {
			stance = true,
			x = x,
			z = z,
			y = floor and floor(x, z) or root.floor,
			yaw = yawOf(root.fx, root.fz),
			pitch = 0,
			since = 0,
		}
	end
	return state
end

-- Put the feet where they are now (after a pose that moved them itself: a
-- lunge, a stagger, the crawl): planted there.
function GuestGait.plant(state, positions)
	for foot, p in positions do
		local f = state.feet[foot]
		if f then
			f.stance, f.swing = true, nil
			f.x, f.y, f.z = p.x, p.y, p.z
			f.yaw = p.yaw or f.yaw
			f.pitch = 0
		end
	end
	state.moving = false
end

local function startSwing(f, toX: number, toZ: number, duration: number, lift: number, settle: boolean)
	f.stance = false
	f.swing = {
		fromX = f.x,
		fromZ = f.z,
		fromY = f.y,
		fromYaw = f.yaw,
		toX = toX,
		toZ = toZ,
		t = 0,
		duration = math.max(duration, 0.08),
		lift = lift,
		settle = settle,
	}
end

-- Ease the swing out of the ground and down onto it: slow at both ends,
-- like a heavy foot.
local function smooth(u: number): number
	return u * u * (3 - 2 * u)
end

local function moveSwing(f, u: number, toYaw: number, floor)
	local s = f.swing
	-- (A swing taken over part way through runs from where it was then.)
	local u0 = s.u0 or 0
	u = math.clamp((u - u0) / (1 - u0), 0, 1)
	local e = smooth(u)
	f.x = s.fromX + (s.toX - s.fromX) * e
	f.z = s.fromZ + (s.toZ - s.fromZ) * e
	local toY = floor and floor(s.toX, s.toZ) or s.fromY
	f.y = s.fromY + (toY - s.fromY) * e + s.lift * sin(PI * u) ^ 0.8
	local d = (toYaw - s.fromYaw + PI) % (2 * PI) - PI
	f.yaw = s.fromYaw + d * e
	-- Toe down off the ground, heel down onto it.
	f.pitch = (u < 0.5) and (-0.35 * sin(PI * u * 2)) or (0.22 * sin(PI * (u - 0.5) * 2))
	if s.settle then
		f.pitch *= 0.4
	end
end

local function land(state, f, foot: string, events)
	local s = f.swing
	f.x, f.z = s.toX, s.toZ
	f.stance, f.swing = true, nil
	f.pitch = 0
	f.since = 0
	state.lastLanded = foot
	table.insert(events, foot)
end

-- One frame. input:
--   root      { x, y, z, fx, fz, floor }: his root's world centre, the flat
--             unit way he faces, and the floor's height under him
--   vx, vz    his velocity on the floor plane (studs/s)
--   spec      a GuestGait.Specs entry, or nil to stand
--   stance    standing poses' feet: { width, Left = ahead, Right = ahead }
--   floor     function(x, z) -> floor height there (optional)
-- Returns the feet that landed this frame.
function GuestGait.step(state, input, dt: number): { string }
	local root = input.root
	local floor = input.floor
	local events = {}
	local vx, vz = input.vx or 0, input.vz or 0
	local speed = sqrt(vx * vx + vz * vz)
	local spec = input.spec
	local moving = spec ~= nil and speed > GuestGait.MoveSpeed
	local yaw = yawOf(root.fx, root.fz)

	for _, foot in FEET do
		local f = state.feet[foot]
		f.since = (f.since or 0) + dt
	end

	if moving then
		-- The step lengthens with speed, slowly (a step already taken keeps
		-- its length: only the clock follows).
		local wanted = spec.step * math.clamp(0.55 + 0.45 * speed / spec.speed, 0.5, 1.25)
		state.step += (wanted - state.step) * math.min(1, dt * 3)
		if not state.moving then
			-- Setting off: the foot furthest behind the way he's going steps
			-- first; the other carries him, its clock set by where it is (under
			-- him, mid-stance; ahead, early; behind, late). A foot in the air
			-- that the clock says swings steps on with it, from where it is, to
			-- where he's going. (Left to land where he'd stopped, it was then
			-- kept down there a whole stance while he walked on, and his hips
			-- sank to the floor to reach it.)
			local dx, dz = vx / speed, vz / speed
			local l, r = state.feet.Left, state.feet.Right
			local back = ((l.x - root.x) * dx + (l.z - root.z) * dz) <= ((r.x - root.x) * dx + (r.z - root.z) * dz)
					and "Left"
				or "Right"
			local plant = back == "Left" and "Right" or "Left"
			local p = state.feet[plant]
			local plantShare = math.min(spec.stance + (plant == "Right" and spec.uneven or 0), 0.9)
			local ahead = (p.x - root.x) * dx + (p.z - root.z) * dz
			local clock = math.clamp(plantShare / 2 - ahead / (2 * state.step), 0, plantShare - 0.01)
			state.phase = (clock - OFFSET[plant]) % 1
			local f = state.feet[back]
			local backShare = math.min(spec.stance + (back == "Right" and spec.uneven or 0), 0.9)
			local now = (state.phase + OFFSET[back]) % 1
			if not f.stance and f.swing.settle and now >= backShare then
				local s = f.swing
				s.settle = false
				s.u0 = math.clamp((now - backShare) / (1 - backShare), 0, 0.95)
				s.fromX, s.fromZ, s.fromY, s.fromYaw = f.x, f.z, f.y, f.yaw
				s.lift *= 0.5
			end
			state.moving = true
		end
		local dx, dz = vx / speed, vz / speed
		-- A foot left down too far from him (he turned, went back the way he
		-- came, or stopped and set off on the wrong foot) steps now, and the
		-- rhythm starts again from it, while the other carries him. Left to
		-- the clock, it stayed down while he walked away from it and his
		-- hips sank to the floor to reach it.
		-- (With the other foot in the air, that one hurries down first.)
		local reach = spec.stance * state.step + GuestGait.ReachSlack
		local worst, worstD, strain = nil, 0, 0
		for _, foot in FEET do
			local f = state.feet[foot]
			local other = state.feet[foot == "Left" and "Right" or "Left"]
			if f.stance then
				-- (From its own side of him, so a sideways walk's spread isn't
				-- counted.)
				local spread = spec.width / 2 * SIDE[foot]
				local ox = f.x - (root.x - root.fz * spread)
				local oz = f.z - (root.z + root.fx * spread)
				local along = ox * dx + oz * dz
				local across = ox * -dz + oz * dx
				local off = math.max(-along - reach, along - reach, math.abs(across) - 0.9, 0)
				if off > 0 and other.stance and off > worstD then
					worst, worstD = foot, off
				elseif off > 0 and not other.stance then
					strain = math.max(strain, off)
				end
			end
		end
		if worst then
			local share = math.min(spec.stance + (worst == "Right" and spec.uneven or 0), 0.9)
			state.phase = (share - OFFSET[worst] + 0.001) % 1
		end
		local before = state.phase
		local hurry = 1 + math.min(strain * 4, 3)
		state.phase = (state.phase + hurry * speed * dt / (2 * state.step)) % 1
		local cycle = 2 * state.step / speed
		for _, foot in FEET do
			local f = state.feet[foot]
			local uneven = foot == "Right" and spec.uneven or 0
			local stanceShare = math.min(spec.stance + uneven, 0.9)
			local was = (before + OFFSET[foot]) % 1
			local now = (state.phase + OFFSET[foot]) % 1
			if f.stance and now >= stanceShare then
				-- Lift off: the clock says it swings. (The target is worked out
				-- as it swings; and from where the clock is, so a step that
				-- starts late doesn't jump part of the way at once.)
				startSwing(f, f.x, f.z, (1 - stanceShare) * cycle, spec.lift * (1 - uneven * 3), false)
				f.swing.u0 = math.clamp((now - stanceShare) / (1 - stanceShare), 0, 0.95)
			end
			if not f.stance then
				local s = f.swing
				local u
				if s.settle then
					s.t += dt
					u = math.min(1, s.t / s.duration)
				else
					-- Where the clock says the swing is.
					u = now >= stanceShare and (now - stanceShare) / (1 - stanceShare) or 1
					if was > now and now < stanceShare then
						u = 1 -- the clock went round: it's down
					end
				end
				do
					-- Down where he'll be at the middle of its stance: the time left
					-- in the swing, then half the stance, ahead of the root now. (A
					-- foot that was stepping into place as he stopped, too: left to
					-- land where he'd stopped, it came down far behind him.)
					local left = if s.settle then (1 - u) * s.duration else (1 - u) * (1 - stanceShare) * cycle
					local ahead = speed * (left + stanceShare * cycle / 2) * (1 - uneven)
					local rx, rz = -root.fz, root.fx
					local spread = spec.width / 2 * SIDE[foot]
					s.toX = root.x + dx * ahead + rx * spread
					s.toZ = root.z + dz * ahead + rz * spread
				end
				moveSwing(f, u, yaw, floor)
				if u >= 1 then
					land(state, f, foot, events)
				end
			end
		end
	else
		-- Standing: finish a swing under him, then bring a drifted foot back
		-- to its place, one at a time.
		state.moving = false
		local swinging = nil
		for _, foot in FEET do
			local f = state.feet[foot]
			if not f.stance then
				local s = f.swing
				if not s.settle then
					-- It was mid-stride: bring it down where it belongs.
					local x, z = neutral(root, foot, input.stance)
					local done = s.duration > 0 and math.clamp(s.t / s.duration, 0, 1) or 0
					s.settle = true
					s.t = 0
					s.duration = math.max(0.18, GuestGait.SettleSeconds * (1 - done * 0.5))
					s.fromX, s.fromZ, s.fromY, s.fromYaw = f.x, f.z, f.y, f.yaw
					s.lift = math.max(GuestGait.SettleLift, (f.y - s.fromY))
					s.toX, s.toZ = x, z
				end
				s.t += dt
				local u = math.min(1, s.t / s.duration)
				moveSwing(f, u, yaw, floor)
				if u >= 1 then
					land(state, f, foot, events)
				else
					swinging = foot
				end
			end
		end
		if not swinging then
			-- The foot furthest from its place steps first.
			local worst, worstD, wx, wz = nil, GuestGait.SettleDistance, 0, 0
			for _, foot in FEET do
				local f = state.feet[foot]
				local x, z = neutral(root, foot, input.stance)
				local d = flatDist(f.x, f.z, x, z)
				local turned = math.abs((yaw - f.yaw + PI) % (2 * PI) - PI)
				d += turned * 0.6
				if d > worstD and f.since > 0.12 then
					worst, worstD, wx, wz = foot, d, x, z
				end
			end
			if worst then
				local f = state.feet[worst]
				startSwing(f, wx, wz, GuestGait.SettleSeconds, GuestGait.SettleLift, true)
			end
		end
	end
	return events
end

-- His hips over his feet: the side-to-side sway towards the foot carrying
-- him, the drop of the hip on the swinging side (the lurch), and the turn
-- of the pelvis with the stride. Returns targets in body space (studs and
-- radians, the Root joint's px, rz, ry); Logic/GuestPose springs them.
function GuestGait.pelvis(state, root, spec)
	local rx, rz = -root.fz, root.fx
	local fx, fz = root.fx, root.fz
	local l, r = state.feet.Left, state.feet.Right
	local function lateral(f)
		return (f.x - root.x) * rx + (f.z - root.z) * rz
	end
	local function ahead(f)
		return (f.x - root.x) * fx + (f.z - root.z) * fz
	end
	local support
	if l.stance and not r.stance then
		support = l
	elseif r.stance and not l.stance then
		support = r
	elseif l.stance and r.stance then
		support = state.lastLanded == "Left" and l or r
	end
	local heavy = spec and 1 or 0.4
	local sway = support and math.clamp(lateral(support) * 0.42 * heavy, -0.32, 0.32) or 0
	-- The hip over the swinging leg drops (rz > 0 lowers his left side).
	local roll = 0
	if support then
		roll = (support == r and 1 or -1) * math.rad(7) * heavy
		if support == r and spec then
			roll *= 1 + (spec.uneven or 0) * 6 -- the limp's side drops further
		end
	end
	-- The pelvis turns with the legs: the right foot forward turns him left.
	local turn = math.clamp((ahead(r) - ahead(l)) * 0.07, -0.22, 0.22)
	return sway, roll, turn
end

-- Where a foot is for a stand-in root moving straight ahead (lune specs).
GuestGait._neutral = neutral
GuestGait._yawOf = yawOf

-- The unit flat direction a yaw faces (yaw 0 = -Z).
function GuestGait.facing(yaw: number): (number, number)
	return -sin(yaw), -cos(yaw)
end

return GuestGait
