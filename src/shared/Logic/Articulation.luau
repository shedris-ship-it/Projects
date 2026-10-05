-- Things that swing or slide: doors, drawers, cupboard doors and lids
-- (docs/plans/gameplay-rework.md section 4.5). They are driven by the server,
-- not by physics: a physical hinge would fling the client-simulated
-- characters it touches and blur the one fact The Guest's code needs (can I
-- walk through?). Pure, so the rules are tests (tests/specs/Articulation.spec).
--
-- A state is { value, target, velocity, mode, min, max, rate, passAt,
-- latchAt, latched, locked, passing }: `value` in degrees for a hinge (0 shut)
-- or studs for a slide (0 in). It moves one of three ways (R2c, the physics
-- feel pass; the owner: "momentum should be improved"):
--
--   driven  towards `target` at `rate` (a prompt, The Guest, the house): the
--           timings the passage model and his door delays are built on
--   held    a hand has it: a spring towards `target` (where the hand wants
--           it), never faster than `rate`, so it has weight but follows
--   free    let go: it keeps its velocity, slowed by friction; it bounces
--           off the open stop with a knock; coming home fast it slams, slow
--           it clicks shut, and in between it can stop short, ajar
--
-- Coming back to within `latchAt` of shut it snaps shut and latches with a
-- click; a locked one stays shut and rattles. It is walkable from `passAt`,
-- and walkable until it falls below passAt - passHysteresis, so a door
-- bouncing about the line doesn't flicker the passage model.
--
-- Steps are taken in fixed substeps (Articulation.SUBSTEP) so the server and
-- a client predicting the same door agree.

local Articulation = {}

Articulation.SUBSTEP = 1 / 120

-- spec: { min?, max, rate, passAt?, latchAt?, value? (start), locked?,
--   passHysteresis?, friction?, restitution?, slamSpeed?, knockSpeed?,
--   stopSpeed?, stiffness? }
-- The free-swing numbers default to "no momentum" values, so a spec without
-- them behaves as before.
function Articulation.new(spec)
	local min = spec.min or 0
	local value = math.clamp(spec.value or min, min, spec.max)
	local latchAt = spec.latchAt or 0
	local passAt = spec.passAt or spec.max
	return {
		value = value,
		target = value,
		velocity = 0,
		mode = "driven",
		min = min,
		max = spec.max,
		rate = spec.rate,
		passAt = passAt,
		passHysteresis = spec.passHysteresis or 0,
		latchAt = latchAt,
		latched = value - min <= latchAt,
		locked = spec.locked == true,
		passing = value >= passAt,
		friction = spec.friction or spec.rate * 8,
		restitution = spec.restitution or 0,
		slamSpeed = spec.slamSpeed or math.huge,
		knockSpeed = spec.knockSpeed or math.huge,
		stopSpeed = spec.stopSpeed or spec.rate * 0.05,
		stiffness = spec.stiffness or 18,
		carry = 0,
	}
end

function Articulation.passable(state): boolean
	return state.passing == true
end

function Articulation.moving(state): boolean
	if state.mode == "free" or state.mode == "held" then
		return state.mode == "held" or math.abs(state.velocity) > 1e-6
	end
	return math.abs(state.target - state.value) > 1e-6
end

-- Aim it somewhere (clamped), driven at its rate. A locked one can't leave
-- shut: returns false (rattle) when asked to open it, true otherwise.
function Articulation.setTarget(state, target: number): boolean
	target = math.clamp(target, state.min, state.max)
	if state.locked and target > state.min + state.latchAt then
		state.target = state.min
		return false
	end
	state.target = target
	if state.mode ~= "held" then
		state.mode = "driven"
		state.velocity = 0
	end
	return true
end

-- Taken out of anyone's hands and moved at its rate (The Guest, the house).
function Articulation.drive(state, target: number): boolean
	state.mode = "driven"
	state.velocity = 0
	return Articulation.setTarget(state, target)
end

-- A hand takes hold: from now `target` is where the hand wants it.
function Articulation.hold(state)
	state.mode = "held"
end

-- Let go with this velocity (per second): it swings on by itself.
function Articulation.release(state, velocity: number?)
	state.mode = "free"
	local v = velocity or state.velocity
	local cap = state.rate * 1.5
	state.velocity = state.locked and 0 or math.clamp(v, -cap, cap)
end

-- Stop it dead where it is (a body in the way).
function Articulation.stop(state, at: number)
	state.value = math.clamp(at, state.min, state.max)
	state.target = state.value
	state.velocity = 0
	if state.mode == "free" then
		state.mode = "driven"
	end
end

local function settle(state, events)
	-- Walkable from passAt; walkable until below passAt - passHysteresis.
	local passing = state.passing
	if not passing and state.value >= state.passAt then
		state.passing = true
		table.insert(events, "pass")
	elseif passing and state.value < state.passAt - state.passHysteresis then
		state.passing = false
		table.insert(events, "block")
	end
end

local function substep(state, dt: number, rate: number, events)
	local before = state.value
	local value = before
	local mode = state.mode
	if mode == "driven" then
		local delta = state.target - before
		local reach = rate * dt
		value = math.abs(delta) <= reach and state.target or before + math.sign(delta) * reach
		state.velocity = (value - before) / dt
	elseif mode == "held" then
		-- A critically damped spring towards the hand, no faster than its rate.
		local k = state.stiffness
		local accel = k * k * (state.target - before) - 2 * k * state.velocity
		local v = math.clamp(state.velocity + accel * dt, -rate, rate)
		state.velocity = v
		value = before + v * dt
	else
		-- Free: momentum, slowed by friction.
		local v = state.velocity
		local slow = state.friction * dt
		v = math.abs(v) <= slow and 0 or v - math.sign(v) * slow
		state.velocity = v
		value = before + v * dt
	end
	-- The open stop: a free swing bounces off it.
	if value > state.max then
		value = state.max
		if mode == "free" then
			local hit = state.velocity
			state.velocity = -hit * state.restitution
			if hit >= state.knockSpeed then
				table.insert(events, "knock")
			end
		else
			state.velocity = 0
		end
	elseif value < state.min then
		value = state.min
	end
	if state.latched and value > state.min then
		state.latched = false
		table.insert(events, "unlatch")
	end
	-- Swinging shut: within the latch distance it snaps home and catches, or
	-- slams if it was moving fast.
	if value < before and value - state.min <= state.latchAt and not state.latched then
		local speed = math.abs(state.velocity)
		value = state.min
		state.target = state.min
		state.velocity = 0
		state.latched = true
		if mode == "free" then
			state.mode = "driven"
		end
		table.insert(events, (mode ~= "driven" and speed >= state.slamSpeed) and "slam" or "latch")
	end
	state.value = value
	-- A free swing that has nearly stopped comes to rest where it is.
	if state.mode == "free" and math.abs(state.velocity) < state.stopSpeed then
		state.velocity = 0
		state.target = value
		state.mode = "driven"
	end
	settle(state, events)
end

-- Move it for `dt` seconds (in fixed substeps; `rate`, if given, overrides its
-- rate for a driven move: a slam). Returns the events that happened, in
-- order: "unlatch", "latch", "slam" (shut hard), "knock" (hit the open stop
-- hard), "pass" (became walkable), "block" (stopped being walkable).
function Articulation.step(state, dt: number, rate: number?): { string }
	local events = {}
	local r = rate or state.rate
	if state.mode == "driven" then
		-- A driven move needs no substeps: it is exact at any step.
		substep(state, math.max(dt, 1e-6), r, events)
		return events
	end
	state.carry += dt
	local h = Articulation.SUBSTEP
	while state.carry >= h do
		state.carry -= h
		substep(state, h, r, events)
		if state.mode == "driven" then
			-- Came to rest (latched, or stopped): the rest of the step is idle.
			state.carry = 0
			break
		end
	end
	return events
end

-- Hinges seen from above -------------------------------------------------------
-- Vectors are flat { x, z } offsets from the hinge. Angles turn the way
-- CFrame.Angles(0, a, 0) does (from +X towards -Z), in degrees.

-- The signed angle from one flat vector to another, in degrees (-180..180).
function Articulation.flatAngle(from, to): number
	local cross = from.z * to.x - from.x * to.z
	local dot = from.x * to.x + from.z * to.z
	return math.deg(math.atan2(cross, dot))
end

-- The Amnesia mapping: the angle the hinge must turn to so the point you
-- grabbed (`grab`: where it sits when the door is shut) lies towards your
-- hand (`hand`, where your hand is now), clamped to the door's range.
-- Push or pull, from either side, falls out of the geometry. `sign` is -1
-- for a door that opens by turning the other way (a cupboard's left door).
function Articulation.hingeTarget(state, grab, hand, sign: number?): number
	return math.clamp(Articulation.flatAngle(grab, hand) * (sign or 1), state.min, state.max)
end

-- The same for things your hand moves straight (a drawer: studs pulled out
-- along it) or lifts (a lid: degrees of arc): where it was when you took
-- hold, plus how far your hand has moved since, clamped to its range.
function Articulation.alongTarget(state, start: number, moved: number): number
	return math.clamp(start + moved, state.min, state.max)
end

-- A body standing in the swing: the swing from `from` to `to` (degrees) of a
-- slab `length` long stops just short of a body of `radius` at flat offset
-- `body` from the hinge (`shut`: the slab's direction when shut). Returns the
-- angle to stop at, or nil if the swing is clear.
function Articulation.sweepStop(shut, body, length: number, radius: number, from: number, to: number): number?
	local distance = math.sqrt(body.x * body.x + body.z * body.z)
	if distance > length + radius or distance < 1e-6 then
		return nil
	end
	local at = Articulation.flatAngle(shut, body)
	local half = math.deg(math.asin(math.min(1, radius / distance)))
	local low, high = math.min(from, to), math.max(from, to)
	if at + half < low or at - half > high then
		return nil
	end
	-- Stop at the near edge of the body, never behind where it started.
	if to > from then
		return math.max(from, at - half)
	end
	return math.min(from, at + half)
end

-- The same for a hinge turning the other way (`sign` -1: a hidden door that
-- swings out into its room): the body seen in the mirror of the shut line.
function Articulation.sweepStopSigned(
	shut,
	body,
	length: number,
	radius: number,
	from: number,
	to: number,
	sign: number?
): number?
	if sign == -1 then
		local len = math.sqrt(shut.x * shut.x + shut.z * shut.z)
		if len > 1e-6 then
			local ux, uz = shut.x / len, shut.z / len
			local along = body.x * ux + body.z * uz
			body = { x = 2 * along * ux - body.x, z = 2 * along * uz - body.z }
		end
	end
	return Articulation.sweepStop(shut, body, length, radius, from, to)
end

-- Lock or unlock. Locking only takes when it is shut and latched.
function Articulation.setLocked(state, locked: boolean): boolean
	if locked and not state.latched then
		return false
	end
	state.locked = locked
	return true
end

return Articulation
