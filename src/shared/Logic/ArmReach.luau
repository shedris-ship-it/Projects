-- Your arm reaching what your hand holds (Controllers/ViewModelController,
-- section 20; the owner, 2026-10-12: "your arm is actually your arm"): the
-- copy of your character's upper arm and forearm, from a shoulder just off the
-- screen to the wrist on the torch or the tool. Where the elbow goes, so both
-- bones keep their length and it bends outward and down, the way an arm does.
--
-- Pure maths on { x, y, z } tables (no engine types), so a spec can promise
-- the bones never stretch and the hand always gets there.

local ArmReach = {}

local function sub(a, b)
	return { a[1] - b[1], a[2] - b[2], a[3] - b[3] }
end
local function add(a, b)
	return { a[1] + b[1], a[2] + b[2], a[3] + b[3] }
end
local function scale(a, s: number)
	return { a[1] * s, a[2] * s, a[3] * s }
end
local function dot(a, b): number
	return a[1] * b[1] + a[2] * b[2] + a[3] * b[3]
end
local function length(a): number
	return math.sqrt(dot(a, a))
end
ArmReach.length = length

-- The elbow for a shoulder, a wrist, the upper arm `a` and the forearm `b`
-- long, bending towards `pole` (a direction). A wrist out of reach draws the
-- shoulder towards it, off-screen where nobody sees it move, so the hand never
-- falls short of what it holds; one too close pushes it back. Returns the
-- elbow and the shoulder used.
function ArmReach.solve(shoulder, wrist, a: number, b: number, pole)
	local d = sub(wrist, shoulder)
	local distance = length(d)
	local dir = distance > 1e-6 and scale(d, 1 / distance) or { 0, -1, 0 }
	local reach = math.clamp(distance, math.abs(a - b) + 1e-3, a + b - 1e-3)
	if reach ~= distance then
		shoulder = sub(wrist, scale(dir, reach))
	end
	-- How far along the line the elbow sits, and how far off it.
	local along = (a * a - b * b + reach * reach) / (2 * reach)
	local off = math.sqrt(math.max(0, a * a - along * along))
	-- Off the line towards the pole (whatever of it isn't along the line).
	local side = sub(pole, scale(dir, dot(pole, dir)))
	if length(side) < 1e-5 then
		side = math.abs(dir[2]) < 0.9 and { 0, -1, 0 } or { 1, 0, 0 }
		side = sub(side, scale(dir, dot(side, dir)))
	end
	side = scale(side, 1 / length(side))
	return add(add(shoulder, scale(dir, along)), scale(side, off)), shoulder
end

return ArmReach
