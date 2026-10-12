-- Where a mansion room's windows go (the visual rework V2, 2026-10-12: you
-- can see outside, as in IT WANTS IN). A template's windows sit on the walls
-- it was authored with; fitted into the mansion, many of those walls face
-- another room, and World/MansionBuilder used to leave such a window out (a
-- house of 16 rooms had two windows). Here a window on an inner wall moves to
-- an outer one of the same room, and long outer walls get more, so the
-- house's outside walls have windows the way a real one does.
--
-- Builder only: the planners never read windows (they read RoomFit, which
-- this leaves alone). Every coordinate is in the template's own frame, as in
-- Logic/RoomFit. Pure; spec'd in Windows.spec.

local Props = require(script.Parent.Parent.Data.Props)
local RoomFit = require(script.Parent.RoomFit)

local Windows = {}

local SIDES = { "N", "E", "S", "W" }

local function halfOf(item): number
	local decor = Props.WallDecor[item.kind or ""]
	if decor then
		return decor.size[1] / 2
	end
	return item.width and item.width / 2 or RoomFit.SlotHalf
end

-- fit:   RoomFit.fit's result (props, decor, wallSlots)
-- inner: the room's inner half extents { x, z }
-- doors: its doorways { side, along }
-- outer: function(side, along, half) -> whether that stretch of wall faces
--        outside (World/MansionBuilder: the floor plan's outer spans)
-- cfg:   Config.Window.Openings
-- extras: whether to add windows beyond the template's own (not in a
--        double-height room)
-- Returns the room's decor with its windows where they should be: the other
-- decor untouched, then the windows.
function Windows.arrange(fit, inner, doors, outer, cfg, extras: boolean?)
	local half = Props.WallDecor.Window.size[1] / 2
	local hung = { N = {}, E = {}, S = {}, W = {} }
	local decor = {}
	local wanted = {}
	for _, item in fit.decor or {} do
		if item.kind == "Window" then
			table.insert(wanted, item)
		else
			table.insert(decor, item)
			if item.side then
				table.insert(hung[item.side], { along = item.along, half = halfOf(item) })
			end
		end
	end
	for _, slot in fit.wallSlots or {} do
		if slot.side then
			table.insert(hung[slot.side], { along = slot.along, half = halfOf(slot) })
		end
	end
	local boxes = {}
	for _, prop in fit.props or {} do
		local ex, ez = RoomFit.footprint(prop.kind, prop.ry)
		table.insert(boxes, { x0 = prop.x - ex, x1 = prop.x + ex, z0 = prop.z - ez, z1 = prop.z + ez })
	end

	local function limitOf(side: string): number
		local acrossX = side == "N" or side == "S"
		return (acrossX and inner.x or inner.z) - math.max(3, half + 0.5)
	end
	local function free(side: string, along: number): boolean
		if math.abs(along) > limitOf(side) then
			return false
		end
		for _, door in doors do
			if door.side == side and math.abs(door.along - along) < RoomFit.WallItemClear then
				return false
			end
		end
		for _, other in hung[side] do
			if math.abs(other.along - along) < half + other.half + RoomFit.WallItemGap then
				return false
			end
		end
		local acrossX = side == "N" or side == "S"
		for _, k in boxes do
			local near
			if side == "N" then
				near = k.z0 <= -inner.z + 3
			elseif side == "S" then
				near = k.z1 >= inner.z - 3
			elseif side == "W" then
				near = k.x0 <= -inner.x + 3
			else
				near = k.x1 >= inner.x - 3
			end
			local lo, hi = acrossX and k.x0 or k.z0, acrossX and k.x1 or k.z1
			-- (Tall furniture against the wall would stand in front of the glass.)
			if near and along + half + 0.3 > lo and along - half - 0.3 < hi then
				return false
			end
		end
		return outer(side, along, half)
	end
	-- The nearest free spot on a side to `from`, half a stud at a time.
	local function search(side: string, from: number): number?
		local limit = limitOf(side)
		if limit < 0 then
			return nil
		end
		local start = math.clamp(from, -limit, limit)
		for step = 0, 2 * math.ceil(2 * limit) do
			local along = start + (step % 2 == 0 and 1 or -1) * math.ceil(step / 2) * 0.5
			if free(side, along) then
				return along
			end
		end
		return nil
	end
	local placed = {}
	local function put(item, side: string, along: number)
		local copy = table.clone(item)
		copy.side, copy.along = side, along
		copy.y = copy.y or cfg.Y
		table.insert(hung[side], { along = along, half = half })
		table.insert(placed, copy)
		table.insert(decor, copy)
	end

	-- The template's own windows: where they are if that's an outer wall,
	-- else the nearest spot on its own wall, else another wall.
	for _, item in wanted do
		if #placed >= cfg.Max then
			break
		end
		local along = item.side and search(item.side, item.along)
		if along then
			put(item, item.side, along)
		else
			for _, side in SIDES do
				along = side ~= item.side and search(side, 0) or nil
				if along then
					put(item, side, along)
					break
				end
			end
		end
	end

	-- More along long outer walls: one per Every studs of wall, spaced out,
	-- never more than Max in a room.
	if extras then
		for _, side in SIDES do
			local limit = limitOf(side)
			local length = 2 * (limit + half)
			local count = 0
			for _, p in placed do
				if p.side == side then
					count += 1
				end
			end
			local want = math.floor(length / cfg.Every + 0.5)
			local candidates = {}
			for k = 0, math.floor(2 * limit) do
				table.insert(candidates, -limit + k * 0.5)
			end
			-- From the middle of the wall outwards, so a lone window is centred.
			table.sort(candidates, function(a, b)
				if math.abs(a) ~= math.abs(b) then
					return math.abs(a) < math.abs(b)
				end
				return a < b
			end)
			for _, along in candidates do
				if count >= want or #placed >= cfg.Max then
					break
				end
				local spaced = true
				for _, p in placed do
					if p.side == side and math.abs(p.along - along) < cfg.Spacing then
						spaced = false
						break
					end
				end
				if spaced and free(side, along) then
					put({ id = "window_" .. side .. "_" .. #placed + 1, kind = "Window", y = cfg.Y }, side, along)
					count += 1
				end
			end
		end
	end
	return decor, placed
end

return Windows
