-- Things that swing or slide: doors now, drawers and wardrobe doors next
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

-- Lock or unlock. Locking only takes when it is shut and latched.
function Articulation.setLocked(state, locked: boolean): boolean
	if locked and not state.latched then
		return false
	end
	state.locked = locked
	return true
end

return Articulation
