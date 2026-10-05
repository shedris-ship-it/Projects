-- Pushing furniture (docs/plans/gameplay-rework.md section 4.6; the owner
-- asked for every piece of furniture to be physical, with varying weights).
-- Pure, so the feel is tests (tests/specs/Push.spec).
--
-- A piece's weight is counted in people: 1 is what one player moves at full
-- speed. Strength is how many push it right now. Below `CreepBelow` of its
-- weight it only creeps, scraping; from there it speeds up to `MaxSpeed` at
-- full strength. So one player creeps a bed and two move it; a dresser goes
-- slowly for one; the piano wants three.

local Push = {}

-- cfg: { CreepBelow, CreepSpeed, MaxSpeed }. Returns studs a second, and
-- whether it's only creeping.
function Push.speed(strength: number, weight: number, cfg): (number, boolean)
	if strength <= 0 or weight <= 0 then
		return 0, false
	end
	local ratio = strength / weight
	if ratio < cfg.CreepBelow then
		return cfg.CreepSpeed, true
	end
	local t = math.min(1, (ratio - cfg.CreepBelow) / (1 - cfg.CreepBelow))
	return cfg.CreepSpeed + (cfg.MaxSpeed - cfg.CreepSpeed) * t, false
end

-- The way several pushers move it together: flat { x, z } directions added
-- up. Pushes that mostly cancel (two people shoving from opposite sides)
-- move it nowhere. Returns a unit { x, z }, or nil.
function Push.direction(directions: { { x: number, z: number } })
	local x, z = 0, 0
	for _, d in directions do
		local length = math.sqrt(d.x * d.x + d.z * d.z)
		if length > 1e-6 then
			x += d.x / length
			z += d.z / length
		end
	end
	local length = math.sqrt(x * x + z * z)
	if #directions == 0 or length < 0.3 * #directions then
		return nil
	end
	return { x = x / length, z = z / length }
end

-- One step of a pushed piece's velocity (R2c, the physics feel pass): it
-- gathers speed towards `target` (a flat velocity, or zero when nobody
-- pushes) at cfg.Accel / weight, so a heavy piece is slow to get going, and
-- coasts to a stop at cfg.Friction. Turning blends the same way. Works on
-- Vector3s or plain numbers.
function Push.step(velocity, target, weight: number, dt: number, cfg)
	local gap = target - velocity
	local size = typeof(gap) == "number" and math.abs(gap) or gap.Magnitude
	if size < 1e-6 then
		return target
	end
	-- Speeding up (or turning) is pushing against its weight; slowing down
	-- with nobody pushing is friction.
	local pushing = typeof(target) == "number" and target ~= 0
		or (typeof(target) ~= "number" and target.Magnitude > 1e-6)
	local rate = pushing and cfg.Accel / math.max(weight, 0.25) or cfg.Friction
	local reach = rate * dt
	if size <= reach then
		return target
	end
	return velocity + gap * (reach / size)
end

-- How loud it scrapes: heavier is louder, and creeping (straining at
-- something too heavy) louder still.
function Push.noise(weight: number, creeping: boolean, perWeight: number): number
	return perWeight * weight * (creeping and 1.3 or 1)
end

return Push
