-- The mansion's storeys, for hearing and company (docs/plans/
-- mansion-generation.md, M3; owner decisions 2026-10-04):
--   * a floor muffles a noise to `scale` of its reach;
--   * two people on different storeys aren't together.
-- Inside a double-height room (the grand hall, a stairwell) the storeys share
-- their air, so neither rule applies there. In the old house everything is
-- on one storey and these change nothing.
--
-- Storeys run from -1 (the cellar) to 2 (the attic; docs/plans/
-- level-design.md section 10.1). Storey k starts half a stud below its floor,
-- so someone climbing counts as upstairs only near the top.
--
-- A place is { x, y, z, room, tall, storey? } in layout coordinates (y above
-- the ground floor); `room` and `tall` are the room it's in. Pure.

local Storeys = {}

-- The storey a height is on, kept within low..high when given (the storeys
-- the house has).
function Storeys.of(y: number, pitch: number, low: number?, high: number?): number
	local storey = math.floor((y + 0.5) / pitch)
	if low and storey < low then
		storey = low
	end
	if high and storey > high then
		storey = high
	end
	return storey
end

-- The lowest and highest storeys of a layout's rooms (the old house: the
-- ground floor and the one above, as it always counted).
function Storeys.range(layout): (number, number)
	if layout == nil or layout.mode ~= "Mansion" then
		return 0, 1
	end
	local low, high = 0, 1
	for _, room in layout.rooms do
		local floor = room.floor or 0
		local top = room.tall and (room.top or floor + 1) or floor
		low, high = math.min(low, floor), math.max(high, top)
	end
	return low, high
end

-- Whether two places share their air: the same storey, or the same
-- double-height room. A place may carry its `storey` already (the world
-- knows which storeys the house has).
function Storeys.open(a, b, pitch: number): boolean
	if a.room ~= nil and a.room == b.room and a.tall then
		return true
	end
	return (a.storey or Storeys.of(a.y, pitch)) == (b.storey or Storeys.of(b.y, pitch))
end

-- How far a noise made at `noise` carries for a listener at `listener`.
function Storeys.audibleRadius(radius: number, noise, listener, pitch: number, scale: number): number
	if Storeys.open(noise, listener, pitch) then
		return radius
	end
	return radius * scale
end

-- Whether two people count as together within `radius` studs.
function Storeys.together(a, b, radius: number, pitch: number): boolean
	if not Storeys.open(a, b, pitch) then
		return false
	end
	local dx, dy, dz = a.x - b.x, a.y - b.y, a.z - b.z
	return dx * dx + dy * dy + dz * dz <= radius * radius
end

return Storeys
