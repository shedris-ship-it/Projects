-- Barricades (gameplay rework 4.7): a heavy piece pushed into a doorway's
-- lane bars it. The lane is the doorway's width running a few studs into
-- the room from the wall; a piece covering enough of its width there makes
-- the doorway barricaded on that side. He bangs on it and shoves it clear
-- (a few seconds, never more than ShoveMax); a player can always squeeze
-- past, so nobody is ever shut in. Pure (tests/specs/Barricade.spec).
--
-- In plain x/z numbers: `lane` { x, z (the doorway's middle on the wall
-- line), ix, iz (unit, into the room), width, depth }; `piece` { x, z (its
-- middle), yaw (radians about up), w, d (its size along its own x and z) }.

local Barricade = {}

-- The piece's footprint in the lane's own axes: u along the wall (0 at the
-- doorway's middle), v into the room (0 at the wall line).
function Barricade.extent(lane, piece): (number, number, number, number)
	local tx, tz = -lane.iz, lane.ix
	local c, s = math.cos(piece.yaw), math.sin(piece.yaw)
	local umin, umax, vmin, vmax = math.huge, -math.huge, math.huge, -math.huge
	for _, corner in { { 1, 1 }, { 1, -1 }, { -1, 1 }, { -1, -1 } } do
		-- The piece's corner in the world (yaw turns +x toward -z, Roblox's way).
		local lx, lz = corner[1] * piece.w / 2, corner[2] * piece.d / 2
		local wx = piece.x + lx * c + lz * s
		local wz = piece.z - lx * s + lz * c
		local dx, dz = wx - lane.x, wz - lane.z
		local u, v = dx * tx + dz * tz, dx * lane.ix + dz * lane.iz
		umin, umax = math.min(umin, u), math.max(umax, u)
		vmin, vmax = math.min(vmin, v), math.max(vmax, v)
	end
	return umin, umax, vmin, vmax
end

-- The share (0..1) of the lane's width the piece covers within its depth.
function Barricade.cover(lane, piece): number
	local umin, umax, vmin, vmax = Barricade.extent(lane, piece)
	if vmax < 0 or vmin > lane.depth then
		return 0
	end
	local half = lane.width / 2
	local overlap = math.min(umax, half) - math.max(umin, -half)
	return math.clamp(overlap / lane.width, 0, 1)
end

-- Does it bar the doorway?
function Barricade.bars(lane, piece, cfg): boolean
	return Barricade.cover(lane, piece) >= cfg.Cover
end

-- Ways he could shove it clear, as { u, v } shifts in the lane's axes, the
-- likeliest first: away from him (deeper into the room when he's on the far
-- side of the doorway), then aside along the wall either way, then both.
-- Each leaves the lane covered less than cfg.Cover, so the doorway is open.
function Barricade.shoves(lane, piece, fromOutside: boolean, cfg): { { number } }
	local umin, umax, vmin = Barricade.extent(lane, piece)
	local half, margin = lane.width / 2, 0.3
	local deeper = math.max(0, lane.depth - vmin + margin)
	-- Aside: far enough that what's left in the lane is under the cover share.
	local keep = cfg.Cover * lane.width - margin
	local right = math.max(0, (half - keep) - umin)
	local left = math.min(0, (-half + keep) - umax)
	local list = {}
	local function add(u, v)
		table.insert(list, { u, v })
	end
	if fromOutside then
		add(0, deeper)
	end
	if math.abs(right) <= math.abs(left) then
		add(right, 0)
		add(left, 0)
	else
		add(left, 0)
		add(right, 0)
	end
	if not fromOutside then
		add(0, deeper)
	end
	add(right, deeper * 0.5)
	add(left, deeper * 0.5)
	return list
end

-- How long he bangs before he shoves it clear: heavier takes longer, he's
-- quicker hunting, never more than ShoveMax.
function Barricade.shoveSeconds(weight: number, hunting: boolean, cfg): number
	local t = cfg.ShoveSeconds[1] + (cfg.ShoveSeconds[2] - cfg.ShoveSeconds[1]) * math.clamp(weight - 1, 0, 1)
	if hunting then
		t *= cfg.HuntScale
	end
	return math.min(t, cfg.ShoveMax)
end

return Barricade
