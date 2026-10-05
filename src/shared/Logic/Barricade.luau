-- Barricades (gameplay rework 4.7): a heavy piece pushed into a doorway's
-- lane bars it. The lane is the doorway's width running a few studs into
-- the room from the wall. A piece bars the doorway on its side when it
-- covers enough of the lane's width, or when it stands on either of The
-- Guest's walking points there (the doorway itself, and the approach in
-- front of it): pushing a piece in from the side reaches the approach long
-- before it covers much of the width, and he can't walk to a point under a
-- dresser. He bangs on it and shoves it clear (a few seconds, never more
-- than ShoveMax); a player can always squeeze past, so nobody is ever shut
-- in. Pure (tests/specs/Barricade.spec).
--
-- In plain x/z numbers: `lane` { x, z (the doorway's middle on the wall
-- line), ix, iz (unit, into the room), width, depth, approach (how far into
-- the room his approach point is) }; `piece` { x, z (its middle), yaw
-- (radians about up), w, d (its size along its own x and z) }.

local Barricade = {}

-- A footprint grown by `margin` reaches this far along any direction past
-- its own extent, whatever way it's turned (the diagonal of a unit square).
local TURNED = math.sqrt(2)

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

-- Whether the point (u, v) of the lane is on the piece's footprint grown by
-- `margin`, measured in the piece's own axes (as Services/PushService keeps
-- furniture off his walking points).
function Barricade.covers(lane, piece, u: number, v: number, margin: number): boolean
	local tx, tz = -lane.iz, lane.ix
	local dx = lane.x + tx * u + lane.ix * v - piece.x
	local dz = lane.z + tz * u + lane.iz * v - piece.z
	local c, s = math.cos(piece.yaw), math.sin(piece.yaw)
	local lx, lz = dx * c - dz * s, dx * s + dz * c
	return math.abs(lx) <= piece.w / 2 + margin and math.abs(lz) <= piece.d / 2 + margin
end

-- Points round the piece's footprint about `spacing` apart, as { x, z }:
-- what a door swinging into it would touch.
function Barricade.edgePoints(piece, spacing: number): { { x: number, z: number } }
	local c, s = math.cos(piece.yaw), math.sin(piece.yaw)
	local points = {}
	local function add(lx, lz)
		table.insert(points, { x = piece.x + lx * c + lz * s, z = piece.z - lx * s + lz * c })
	end
	local nx = math.max(1, math.ceil(piece.w / spacing))
	local nz = math.max(1, math.ceil(piece.d / spacing))
	for i = 0, nx do
		local lx = (i / nx - 0.5) * piece.w
		add(lx, piece.d / 2)
		add(lx, -piece.d / 2)
	end
	for i = 1, nz - 1 do
		local lz = (i / nz - 0.5) * piece.d
		add(piece.w / 2, lz)
		add(-piece.w / 2, lz)
	end
	return points
end

-- Does it bar the doorway? Enough of the width, or on his walking points.
function Barricade.bars(lane, piece, cfg): boolean
	return Barricade.cover(lane, piece) >= cfg.Cover
		or Barricade.covers(lane, piece, 0, lane.approach, cfg.NodeClear)
		or Barricade.covers(lane, piece, 0, 0, cfg.NodeClear)
end

-- Ways he could shove it clear, as { u, v } shifts in the lane's axes, the
-- likeliest first: away from him (deeper into the room when he's on the far
-- side of the doorway), then aside along the wall either way, then both.
-- Each leaves the doorway open: the lane covered less than cfg.Cover and his
-- walking points clear.
function Barricade.shoves(lane, piece, fromOutside: boolean, cfg): { { number } }
	local umin, umax, vmin = Barricade.extent(lane, piece)
	local half, margin = lane.width / 2, 0.3
	local reach = cfg.NodeClear * TURNED + margin
	local deeper = math.max(0, math.max(lane.depth, lane.approach + reach) + margin - vmin)
	-- Aside: far enough that what's left in the lane is under the cover share
	-- and clear of the middle of the lane, where he walks.
	local edge = math.max(half - (cfg.Cover * lane.width - margin), reach)
	local right = math.max(0, edge - umin)
	local left = math.min(0, -edge - umax)
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
