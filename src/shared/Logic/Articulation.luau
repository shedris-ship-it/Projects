-- Things that swing or slide: doors, drawers, cupboard doors and lids
-- (docs/plans/gameplay-rework.md section 4.5). They are driven by the server,
-- not by physics: a physical hinge would fling the client-simulated
-- characters it touches and blur the one fact The Guest's code needs (can I
-- walk through?). Pure, so the rules are tests (tests/specs/Articulation.spec).
--
-- A state is { value, target, min, max, rate, passAt, latchAt, latched,
-- locked }: `value` in degrees for a hinge (0 shut) or studs for a slide (0
-- in). It moves towards `target` at `rate` per second. Coming back to within
-- `latchAt` of shut it snaps shut and latches with a click; a locked one
-- stays shut and rattles. At `passAt` or more it is open enough to walk
-- through.

local Articulation = {}

-- spec: { min?, max, rate, passAt?, latchAt?, value? (start), locked? }
function Articulation.new(spec)
	local min = spec.min or 0
	local value = math.clamp(spec.value or min, min, spec.max)
	local latchAt = spec.latchAt or 0
	return {
		value = value,
		target = value,
		min = min,
		max = spec.max,
		rate = spec.rate,
		passAt = spec.passAt or spec.max,
		latchAt = latchAt,
		latched = value - min <= latchAt,
		locked = spec.locked == true,
	}
end

function Articulation.passable(state): boolean
	return state.value >= state.passAt
end

function Articulation.moving(state): boolean
	return math.abs(state.target - state.value) > 1e-6
end

-- Aim it somewhere (clamped). A locked one can't leave shut: returns false
-- (rattle) when asked to open it, true otherwise.
function Articulation.setTarget(state, target: number): boolean
	target = math.clamp(target, state.min, state.max)
	if state.locked and target > state.min + state.latchAt then
		state.target = state.min
		return false
	end
	state.target = target
	return true
end

-- Move towards the target for `dt` seconds at `rate` (or `rate` given).
-- Returns the events that happened, in order: "unlatch", "latch", "pass"
-- (became walkable), "block" (stopped being walkable).
function Articulation.step(state, dt: number, rate: number?): { string }
	local events = {}
	local before = state.value
	local wasPassable = Articulation.passable(state)
	local delta = state.target - before
	local reach = (rate or state.rate) * dt
	local value = math.abs(delta) <= reach and state.target or before + math.sign(delta) * reach
	if state.latched and value > state.min then
		state.latched = false
		table.insert(events, "unlatch")
	end
	-- Swinging shut: within the latch distance it snaps home and catches.
	if value < before and value - state.min <= state.latchAt and not state.latched then
		value = state.min
		state.target = state.min
		state.latched = true
		table.insert(events, "latch")
	end
	state.value = value
	local passable = Articulation.passable(state)
	if passable and not wasPassable then
		table.insert(events, "pass")
	elseif wasPassable and not passable then
		table.insert(events, "block")
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

-- Lock or unlock. Locking only takes when it is shut and latched.
function Articulation.setLocked(state, locked: boolean): boolean
	if locked and not state.latched then
		return false
	end
	state.locked = locked
	return true
end

return Articulation
