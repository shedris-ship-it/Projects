-- The mansion's two storeys, for hearing and company (docs/plans/
-- mansion-generation.md, M3; owner decisions 2026-10-04):
--   * a floor muffles a noise to `scale` of its reach;
--   * two people on different storeys aren't together.
-- Inside a double-height room (the grand hall, a stairwell) the storeys share
-- their air, so neither rule applies there. In the old house everything is
-- on one storey and these change nothing.
--
-- A place is { x, y, z, room, tall } in layout coordinates (y above the
-- ground floor); `room` and `tall` are the room it's in. Pure.

local Storeys = {}

function Storeys.of(y: number, pitch: number): number
	return y >= pitch - 0.5 and 1 or 0
end

-- Whether two places share their air: the same storey, or the same
-- double-height room.
function Storeys.open(a, b, pitch: number): boolean
	if a.room ~= nil and a.room == b.room and a.tall then
		return true
	end
	return Storeys.of(a.y, pitch) == Storeys.of(b.y, pitch)
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
