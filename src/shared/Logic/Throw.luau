-- Throwing things (docs/plans/gameplay-rework.md section 4.4). Pure, so the
-- rules are tests (tests/specs/Throw.spec.luau): it only uses the vectors it
-- is given (Roblox's in the game, @lune/roblox's in the tests), never the
-- Vector3 global. The server owns every throw: it gives the thing its speed
-- and decides, from the path it flew, whether it hit The Guest; the
-- thrower's client never says "I hit him".

local Throw = {}

-- How close a point is to a line segment.
local function pointSegment(p: Vector3, a: Vector3, b: Vector3): number
	local ab = b - a
	local length2 = ab:Dot(ab)
	if length2 < 1e-9 then
		return (p - a).Magnitude
	end
	local t = math.clamp((p - a):Dot(ab) / length2, 0, 1)
	return (p - (a + ab * t)).Magnitude
end
Throw.pointSegment = pointSegment

-- The shortest distance between two segments (p0-p1 and q0-q1).
function Throw.segmentSegment(p0: Vector3, p1: Vector3, q0: Vector3, q1: Vector3): number
	local d1, d2, r = p1 - p0, q1 - q0, p0 - q0
	local a, e, f = d1:Dot(d1), d2:Dot(d2), d2:Dot(r)
	local s, t
	if a < 1e-9 and e < 1e-9 then
		return r.Magnitude
	end
	if a < 1e-9 then
		s = 0
		t = math.clamp(f / e, 0, 1)
	else
		local c = d1:Dot(r)
		if e < 1e-9 then
			t = 0
			s = math.clamp(-c / a, 0, 1)
		else
			local b = d1:Dot(d2)
			local denom = a * e - b * b
			s = denom > 1e-9 and math.clamp((b * f - c * e) / denom, 0, 1) or 0
			t = (b * s + f) / e
			if t < 0 then
				t = 0
				s = math.clamp(-c / a, 0, 1)
			elseif t > 1 then
				t = 1
				s = math.clamp((b - c) / a, 0, 1)
			end
		end
	end
	return ((p0 + d1 * s) - (q0 + d2 * t)).Magnitude
end

-- Did a step from `from` to `to` pass through a box (`box` a CFrame at its
-- centre, `size` its full size), grown by `pad` all round (the thing's own
-- size)? A slab test in the box's frame. For glass a throw can break.
function Throw.segmentBox(from: Vector3, to: Vector3, box: CFrame, size: Vector3, pad: number): boolean
	local a = box:PointToObjectSpace(from)
	local b = box:PointToObjectSpace(to)
	local d = b - a
	local enter, leave = 0, 1
	for _, axis in { "X", "Y", "Z" } do
		local half = size[axis] / 2 + pad
		local start, delta = a[axis], d[axis]
		if math.abs(delta) < 1e-9 then
			if start < -half or start > half then
				return false
			end
		else
			local t0, t1 = (-half - start) / delta, (half - start) / delta
			if t0 > t1 then
				t0, t1 = t1, t0
			end
			enter, leave = math.max(enter, t0), math.min(leave, t1)
			if enter > leave then
				return false
			end
		end
	end
	return true
end

-- Did a thing flying from `from` to `to` this step pass through a body: a
-- capsule from `feet` to `head` of `radius` (plus the thing's own size)?
function Throw.hits(from: Vector3, to: Vector3, feet: Vector3, head: Vector3, radius: number): boolean
	return Throw.segmentSegment(from, to, feet, head) <= radius
end

-- How long a hit stops him: the class's stun, halved for every stun he took
-- in the last minute, and shorter in the final hunt. `recent` is how many.
function Throw.stunSeconds(base: number, recent: number, final: boolean, finalScale: number): number
	local seconds = base * (0.5 ^ math.max(0, recent))
	if final then
		seconds *= finalScale
	end
	return seconds
end

-- The velocity a throw leaves the hand with: along the aim at the class's
-- speed, plus whatever the thrower was already doing.
function Throw.velocity(aim: Vector3, speed: number, carried: Vector3?): Vector3
	local velocity = aim.Magnitude > 1e-6 and aim.Unit * speed or aim * 0
	if carried then
		velocity += carried
	end
	return velocity
end

-- How much of a throw's speed a wind-up gives (R2c): holding the button
-- `held` seconds before letting go. A tap still throws, softly.
function Throw.charge(held: number, cfg): number
	local t = math.clamp((held - cfg.ChargeMin) / (cfg.ChargeFull - cfg.ChargeMin), 0, 1)
	return cfg.ChargeLow + (1 - cfg.ChargeLow) * t
end

-- Where something launched from `from` at `velocity` is `t` seconds later,
-- if nothing touches it. `gravity` is the gravity vector (pointing down).
-- `lift` (0..1) of gravity is held off for its first `liftSeconds` (a throw
-- flies flatter at first: HandsController and HandsService add the force).
function Throw.predict(
	from: Vector3,
	velocity: Vector3,
	gravity: Vector3,
	t: number,
	lift: number?,
	liftSeconds: number?
): Vector3
	local l, tl = lift or 0, liftSeconds or 0
	if l <= 0 or tl <= 0 then
		return from + velocity * t + gravity * (0.5 * t * t)
	end
	local light = gravity * (1 - l)
	if t <= tl then
		return from + velocity * t + light * (0.5 * t * t)
	end
	-- The lifted stretch, then full gravity from where and how it left it.
	local at = from + velocity * tl + light * (0.5 * tl * tl)
	local v = velocity + light * tl
	local rest = t - tl
	return at + v * rest + gravity * (0.5 * rest * rest)
end

-- Is `at` where a validated throw could be, `t` seconds after it left the
-- hand? The tolerance grows with time (spin, air, network delay), so honest
-- throws pass and one steered off its arc doesn't (cfg: ArcSlack,
-- ArcSlackPerSecond).
function Throw.onArc(from: Vector3, velocity: Vector3, gravity: Vector3, t: number, at: Vector3, cfg): boolean
	local expected = Throw.predict(from, velocity, gravity, t, cfg.FlightLift, cfg.FlightLiftSeconds)
	return (at - expected).Magnitude <= cfg.ArcSlack + cfg.ArcSlackPerSecond * t
end

return Throw
