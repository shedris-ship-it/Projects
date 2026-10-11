-- Frames, forward kinematics and two-bone IK for code-built rigs (the
-- Guest's animation pass, 2026-10-11: feet that stay where they land, a hand
-- that finds the door frame). Pure maths with no engine types, so the server,
-- the client and lune share it.
--
-- A rotation is a 3x3 matrix of rows; a frame is { r = rotation, p = { x, y,
-- z } }. Joint values are Motor6D transforms, { rx, ry, rz, px, py, pz } =
-- CFrame.new(px, py, pz) * CFrame.Angles(rx, ry, rz), and CFrame.Angles is
-- Rx * Ry * Rz.

local Kinematics = {}

local sin, cos, sqrt = math.sin, math.cos, math.sqrt

function Kinematics.rot(rx: number, ry: number, rz: number)
	local cx, sx, cy, sy, cz, sz = cos(rx), sin(rx), cos(ry), sin(ry), cos(rz), sin(rz)
	return {
		{ cy * cz, -cy * sz, sy },
		{ cx * sz + sx * sy * cz, cx * cz - sx * sy * sz, -sx * cy },
		{ sx * sz - cx * sy * cz, sx * cz + cx * sy * sz, cx * cy },
	}
end

-- The Euler angles (Rx * Ry * Rz) of a rotation.
function Kinematics.euler(m): (number, number, number)
	local sy = math.clamp(m[1][3], -1, 1)
	local ry = math.asin(sy)
	if math.abs(sy) > 0.99999 then
		-- Gimbal lock: put it all in x.
		return math.atan2(m[3][2], m[2][2]), ry, 0
	end
	return math.atan2(-m[2][3], m[3][3]), ry, math.atan2(-m[1][2], m[1][1])
end

function Kinematics.mul(a, b)
	local m = {}
	for i = 1, 3 do
		local ai = a[i]
		m[i] = {
			ai[1] * b[1][1] + ai[2] * b[2][1] + ai[3] * b[3][1],
			ai[1] * b[1][2] + ai[2] * b[2][2] + ai[3] * b[3][2],
			ai[1] * b[1][3] + ai[2] * b[2][3] + ai[3] * b[3][3],
		}
	end
	return m
end

function Kinematics.transpose(m)
	return {
		{ m[1][1], m[2][1], m[3][1] },
		{ m[1][2], m[2][2], m[3][2] },
		{ m[1][3], m[2][3], m[3][3] },
	}
end

function Kinematics.apply(m, v)
	return {
		m[1][1] * v[1] + m[1][2] * v[2] + m[1][3] * v[3],
		m[2][1] * v[1] + m[2][2] * v[2] + m[2][3] * v[3],
		m[3][1] * v[1] + m[3][2] * v[2] + m[3][3] * v[3],
	}
end

-- Rotation by `angle` about a unit axis (Rodrigues).
function Kinematics.axisAngle(axis, angle: number)
	local x, y, z = axis[1], axis[2], axis[3]
	local c, s = cos(angle), sin(angle)
	local t = 1 - c
	return {
		{ t * x * x + c, t * x * y - s * z, t * x * z + s * y },
		{ t * x * y + s * z, t * y * y + c, t * y * z - s * x },
		{ t * x * z - s * y, t * y * z + s * x, t * z * z + c },
	}
end

-- Vectors ------------------------------------------------------------------------

local function add(a, b)
	return { a[1] + b[1], a[2] + b[2], a[3] + b[3] }
end
local function sub(a, b)
	return { a[1] - b[1], a[2] - b[2], a[3] - b[3] }
end
local function scale(a, k: number)
	return { a[1] * k, a[2] * k, a[3] * k }
end
local function dot(a, b): number
	return a[1] * b[1] + a[2] * b[2] + a[3] * b[3]
end
local function cross(a, b)
	return { a[2] * b[3] - a[3] * b[2], a[3] * b[1] - a[1] * b[3], a[1] * b[2] - a[2] * b[1] }
end
local function length(a): number
	return sqrt(dot(a, a))
end
local function unit(a)
	local l = length(a)
	return l > 1e-9 and scale(a, 1 / l) or { 0, 0, 0 }
end
Kinematics.add, Kinematics.sub, Kinematics.scale = add, sub, scale
Kinematics.dot, Kinematics.cross, Kinematics.length, Kinematics.unit = dot, cross, length, unit

-- Frames -------------------------------------------------------------------------

local IDENTITY = { { 1, 0, 0 }, { 0, 1, 0 }, { 0, 0, 1 } }

function Kinematics.frame(r, p)
	return { r = r or IDENTITY, p = p or { 0, 0, 0 } }
end

function Kinematics.compose(f, g)
	return { r = Kinematics.mul(f.r, g.r), p = add(f.p, Kinematics.apply(f.r, g.p)) }
end

-- A point given in f's space, in f's parent's space.
function Kinematics.point(f, v)
	return add(f.p, Kinematics.apply(f.r, v))
end

-- A point given in f's parent's space, in f's own space.
function Kinematics.toLocal(f, v)
	return Kinematics.apply(Kinematics.transpose(f.r), sub(v, f.p))
end

-- The frame of a joint value: CFrame.new(px, py, pz) * CFrame.Angles(rx, ry, rz).
function Kinematics.joint(value)
	return { r = Kinematics.rot(value[1], value[2], value[3]), p = { value[4], value[5], value[6] } }
end

-- The frame one joint down: the parent joint's frame, moved by the rest
-- offset between the two joints, then turned by this joint's value.
function Kinematics.child(parent, offset, value)
	return Kinematics.compose(Kinematics.compose(parent, { r = IDENTITY, p = offset }), Kinematics.joint(value))
end

-- Two-bone IK ----------------------------------------------------------------------

-- A limb of two bones hanging along -Y from its first joint (a hip, a
-- shoulder), in that joint's rest frame. `target` is where the end (the
-- ankle, the wrist) should be, `l1` and `l2` the bones, `bend` the way the
-- middle joint folds (-1: the shin back, a knee; +1: forward, an elbow or a
-- knee at Breaking), `pole` the direction the middle joint should point.
-- Returns the first joint's angles (rx, ry, rz), the middle joint's rx, the
-- first joint's rotation matrix, and how far short of the target it fell.
function Kinematics.twoBone(target, l1: number, l2: number, bend: number, pole)
	local d = length(target)
	local lo, hi = math.abs(l1 - l2) + 1e-4, l1 + l2 - 1e-4
	local reach = math.clamp(d, lo, hi)
	local short = d - reach
	local dir = d > 1e-6 and scale(target, 1 / d) or { 0, -1, 0 }
	-- The fold between the bones (0: straight).
	local cosK = math.clamp((reach * reach - l1 * l1 - l2 * l2) / (2 * l1 * l2), -1, 1)
	local fold = math.acos(cosK) * bend
	-- The limb with that fold, in its rest frame: thigh down -Y, shin turned
	-- by Rx(fold).
	local limb = { 0, -l1 - l2 * cos(fold), -l2 * sin(fold) }
	-- Turn the limb onto the target (the shortest arc)...
	local from = unit(limb)
	local axis = cross(from, dir)
	local s, c = length(axis), dot(from, dir)
	local r
	if s < 1e-6 then
		if c > 0 then
			r = IDENTITY
		else
			-- Straight back on itself: about any axis across it.
			local across = math.abs(from[1]) < 0.9 and { 1, 0, 0 } or { 0, 0, 1 }
			r = Kinematics.axisAngle(unit(cross(from, across)), math.pi)
		end
	else
		r = Kinematics.axisAngle(scale(axis, 1 / s), math.atan2(s, c))
	end
	-- ...then twist about the line to the target so the middle joint points
	-- towards the pole.
	if pole then
		local middle = Kinematics.apply(r, { 0, -l1, 0 })
		local m = sub(middle, scale(dir, dot(middle, dir)))
		local q = sub(pole, scale(dir, dot(pole, dir)))
		if length(m) > 1e-5 and length(q) > 1e-5 then
			local mu, qu = unit(m), unit(q)
			local twist = math.atan2(dot(cross(mu, qu), dir), dot(mu, qu))
			r = Kinematics.mul(Kinematics.axisAngle(dir, twist), r)
		end
	end
	local rx, ry, rz = Kinematics.euler(r)
	return rx, ry, rz, fold, r, short
end

-- A rotation whose local axes, in the parent's space, are the columns x, y, z
-- (each unit; z is made from x and y so the frame is right-handed).
function Kinematics.basis(x, y)
	local yu = unit(y)
	local zu = unit(cross(x, yu))
	local xu = cross(yu, zu)
	return {
		{ xu[1], yu[1], zu[1] },
		{ xu[2], yu[2], zu[2] },
		{ xu[3], yu[3], zu[3] },
	}
end

-- Critically damped springs ------------------------------------------------------

-- One step of a critically damped spring towards `goal` at stiffness `k`
-- (1/s, its natural frequency). Exact for a constant goal, so it's stable
-- at any frame rate and never overshoots a step change.
function Kinematics.spring(x: number, v: number, goal: number, k: number, dt: number): (number, number)
	if k <= 0 then
		return x, v
	end
	local e = x - goal
	local decay = math.exp(-k * dt)
	local nextE = (e + (v + k * e) * dt) * decay
	local nextV = (v - k * (v + k * e) * dt) * decay
	return goal + nextE, nextV
end

return Kinematics
