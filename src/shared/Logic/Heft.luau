-- How a carried thing moves in your hands (R2c, the physics feel pass; the
-- owner: "unnatural and somewhat laggy, momentum should be improved"). Pure
-- (tests/specs/Heft.spec), and generic over numbers and Vector3s, so the
-- client uses it for the hold point and the spec checks it with numbers.
--
-- The hold point follows your eye through a critically damped spring: a
-- light thing keeps up with a flick, a heavy one trails when you turn and
-- settles without wobbling. The force a class can use is limited in g
-- (Data/Physical `carry.forceG`), so a heavy thing whipped about sags, and it
-- leans the way it's being swung (`tilt`).

local Heft = {}

-- One step of a critically damped spring towards `target`: returns the new
-- position and velocity. `omega` (per second) is how keenly it follows.
-- Exact for any dt, so it never overshoots or blows up at a low frame rate.
function Heft.spring(x, v, target, omega: number, dt: number)
	local decay = math.exp(-omega * dt)
	local offset = x - target
	local push = (v + offset * omega) * dt
	return target + (offset + push) * decay, (v - push * omega) * decay
end

-- How far the thing leans (radians) for a hold point moving at `speed`
-- (studs a second, signed: along your right for a roll, along your view for
-- a pitch), within the class's `tilt`.
function Heft.lean(speed: number, tilt: number): number
	-- Most of the lean by a brisk sweep (12 studs a second).
	return math.clamp(-speed / 12, -1, 1) * tilt
end

-- A bulky thing carried while walking bobs with your stride: its height
-- offset at stride phase `phase` (radians), for a walking speed in studs a
-- second (none standing still).
function Heft.bob(phase: number, speed: number, amplitude: number): number
	local strength = math.clamp(speed / 8, 0, 1)
	return math.sin(phase * 2) * amplitude * strength
end

-- How hard the server lets a held thing move: the class's own top speed,
-- plus how fast its holder is moving, plus a margin for the network.
function Heft.speedCap(classMax: number, holderSpeed: number, margin: number): number
	return classMax + holderSpeed + margin
end

return Heft
