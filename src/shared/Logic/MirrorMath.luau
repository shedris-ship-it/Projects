-- Reflections in window glass and mirrors (owner, 2026-10-03: "peek from
-- windows"; doc section 5: tier 3 "appears in reflections"). Roblox's
-- reflectance never shows moving characters, so clients draw The Guest's
-- mirror image themselves (Lib/GuestReflection). This decides where that
-- image is and whether it would really show in the pane. Plain numbers:
-- points and vectors are { x, y, z }.

local MirrorMath = {}

local function dot(a, b)
	return a[1] * b[1] + a[2] * b[2] + a[3] * b[3]
end

local function sub(a, b)
	return { a[1] - b[1], a[2] - b[2], a[3] - b[3] }
end

-- Mirror a point across the plane through `origin` with unit `normal`.
function MirrorMath.reflectPoint(p, origin, normal)
	local d = dot(sub(p, origin), normal)
	return { p[1] - 2 * d * normal[1], p[2] - 2 * d * normal[2], p[3] - 2 * d * normal[3] }
end

-- Mirror a direction (no translation).
function MirrorMath.reflectVector(v, normal)
	local d = dot(v, normal)
	return { v[1] - 2 * d * normal[1], v[2] - 2 * d * normal[2], v[3] - 2 * d * normal[3] }
end

-- Signed distance from the plane (positive on the side the normal points).
function MirrorMath.side(p, origin, normal): number
	return dot(sub(p, origin), normal)
end

-- Would a viewer at `eye` see the reflection of `point` in the pane? The
-- pane is a rectangle centred on `origin`, facing `normal` (into the room),
-- with unit axes `right` and `up` and half sizes `halfW`, `halfH`. Both the
-- viewer and the point must be in front of it. Returns the hit position in
-- pane coordinates (u along right, v along up) when it does.
function MirrorMath.inPane(eye, point, origin, normal, right, up, halfW: number, halfH: number)
	if MirrorMath.side(eye, origin, normal) <= 0.05 or MirrorMath.side(point, origin, normal) <= 0.05 then
		return false
	end
	local image = MirrorMath.reflectPoint(point, origin, normal)
	local ray = sub(image, eye)
	local denom = dot(ray, normal)
	if math.abs(denom) < 1e-6 then
		return false
	end
	local t = dot(sub(origin, eye), normal) / denom
	if t <= 0 or t >= 1 then
		return false
	end
	local hit = { eye[1] + ray[1] * t, eye[2] + ray[2] * t, eye[3] + ray[3] * t }
	local offset = sub(hit, origin)
	local u, v = dot(offset, right), dot(offset, up)
	if math.abs(u) > halfW or math.abs(v) > halfH then
		return false
	end
	return true, u, v
end

return MirrorMath
