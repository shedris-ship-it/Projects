-- Geometry of being seen, in plain numbers (x, z on the floor plane) so the
-- stalker's stealth rules can be tested without the engine.

local SightMath = {}

-- Degrees between where someone looks (lookX, lookZ) and the direction from
-- them to a point (dx, dz): 0 = dead ahead, 180 = right behind them.
function SightMath.angle(lookX: number, lookZ: number, dx: number, dz: number): number
	local a = math.sqrt(lookX * lookX + lookZ * lookZ)
	local b = math.sqrt(dx * dx + dz * dz)
	if a < 1e-6 or b < 1e-6 then
		return 0
	end
	local dot = (lookX * dx + lookZ * dz) / (a * b)
	return math.deg(math.acos(math.clamp(dot, -1, 1)))
end

-- Which side of you a point is on: +1 to your left, -1 to your right
-- (Roblox: looking along -Z, +X is your right).
function SightMath.side(lookX: number, lookZ: number, dx: number, dz: number): number
	-- Cross product's Y: positive when the point is to the left.
	local cross = lookZ * dx - lookX * dz
	return cross >= 0 and 1 or -1
end

-- Your back is turned to a point when it's further round than `degrees`.
function SightMath.backTurned(lookX: number, lookZ: number, dx: number, dz: number, degrees: number): boolean
	return SightMath.angle(lookX, lookZ, dx, dz) > degrees
end

-- Inside a view cone (full angle in degrees)?
function SightMath.inCone(lookX: number, lookZ: number, dx: number, dz: number, coneDegrees: number): boolean
	return SightMath.angle(lookX, lookZ, dx, dz) <= coneDegrees / 2
end

-- Score a candidate step for sneaking up: progress towards the goal, minus
-- a heavy price for every Witness who would see him there, minus a little
-- for leaving cover. exposure = number of watchers who'd see the spot.
function SightMath.stealthScore(progress: number, exposure: number, blocked: boolean): number
	if blocked then
		return -math.huge
	end
	return progress - exposure * 30
end

-- The yaw (radians, Roblox: 0 = facing -Z, + turns left) for a look vector.
function SightMath.yaw(lookX: number, lookZ: number): number
	return math.atan2(-lookX, -lookZ)
end

-- Smallest signed difference between two yaws, in degrees (-180..180).
function SightMath.yawDelta(a: number, b: number): number
	local d = math.deg(a - b) % 360
	if d > 180 then
		d -= 360
	end
	return d
end

return SightMath
