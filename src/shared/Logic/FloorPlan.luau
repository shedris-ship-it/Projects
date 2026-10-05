-- Plain-text views of a layout: a fingerprint (to prove a generator's output
-- never changed) and an ASCII floor plan per floor (`lune run tools/plan`,
-- and the F2 `plan` command later). Works for the old cell layouts and the
-- mansion's rectangles (docs/plans/mansion-generation.md).

local RoomRects = require(script.Parent.RoomRects)
local Rng = require(script.Parent.Parent.Lib.Rng)

local FloorPlan = {}

-- Every scalar field of a record, sorted by key, so a new field or a changed
-- value always changes the text.
local function scalars(record): string
	local keys = {}
	for key, value in record do
		local kind = type(value)
		if kind == "string" or kind == "number" or kind == "boolean" then
			table.insert(keys, tostring(key))
		end
	end
	table.sort(keys)
	local parts = table.create(#keys)
	for i, key in keys do
		parts[i] = key .. "=" .. tostring(record[key])
	end
	return table.concat(parts, ",")
end

local function list(values): string
	local parts = {}
	for i, value in values or {} do
		parts[i] = tostring(value)
	end
	return table.concat(parts, ",")
end

-- Everything a generator decided, as one line per part.
function FloorPlan.fingerprint(layout): string
	local lines = { "layout " .. scalars(layout) }
	for _, room in layout.rooms do
		table.insert(lines, "room " .. scalars(room))
	end
	for _, edge in layout.edges do
		table.insert(lines, "edge " .. edge[1] .. "-" .. edge[2])
	end
	for _, seam in layout.seams do
		table.insert(lines, "seam " .. scalars(seam))
	end
	table.insert(lines, "lanterns " .. list(layout.lanterns))
	table.insert(lines, "path " .. list(layout.criticalPath))
	return table.concat(lines, "\n")
end

function FloorPlan.hash(layout): number
	return Rng.hash(FloorPlan.fingerprint(layout))
end

-- What each storey is called.
FloorPlan.StoreyNames = { [-1] = "Cellar", [0] = "Ground floor", [1] = "Upper floor", [2] = "Attic" }

-- A tall room's storeys, lowest first.
local function storeysOf(rect): { number }
	local list = {}
	for f = rect.floor or 0, RoomRects.topOf(rect) do
		table.insert(list, f)
	end
	return list
end

-- ASCII plan. Each 10-stud lattice step is 4 columns wide and 2 rows tall.
local COLS, ROWS = 4, 2

local ROLE_MARK = { start = "S", exit = "E", deliberation = "T" }

local function shortName(template: string?): string
	return string.sub(string.gsub(template or "?", "_", ""), 1, 4)
end

-- Lines of text for one floor of a rectangle layout.
local function renderFloor(layout, rects, floor: number, bounds, lattice: number)
	local width = (bounds.maxX - bounds.minX) / lattice * COLS + 1
	local height = (bounds.maxZ - bounds.minZ) / lattice * ROWS + 1
	local grid = table.create(height)
	for row = 1, height do
		grid[row] = table.create(width, " ")
	end
	local function col(x)
		return math.floor((x - bounds.minX) / lattice * COLS + 0.5) + 1
	end
	local function row(z)
		return math.floor((z - bounds.minZ) / lattice * ROWS + 0.5) + 1
	end
	local function put(r, c, char)
		if grid[r] and c >= 1 and c <= width then
			grid[r][c] = char
		end
	end

	local onFloor = {}
	for _, rect in rects do
		if RoomRects.onFloor(rect, floor) then
			table.insert(onFloor, rect)
		end
	end
	for _, rect in onFloor do
		local c0, c1 = col(rect.x), col(rect.x + rect.w)
		local r0, r1 = row(rect.z), row(rect.z + rect.d)
		for c = c0, c1 do
			put(r0, c, "-")
			put(r1, c, "-")
		end
		for r = r0, r1 do
			put(r, c0, "|")
			put(r, c1, "|")
		end
		put(r0, c0, "+")
		put(r0, c1, "+")
		put(r1, c0, "+")
		put(r1, c1, "+")
	end
	for _, rect in onFloor do
		local c0, c1 = col(rect.x), col(rect.x + rect.w)
		local r0, r1 = row(rect.z), row(rect.z + rect.d)
		-- Tall rooms are shaded so stairs and the hall stand out.
		if rect.tall then
			for r = r0 + 1, r1 - 1 do
				for c = c0 + 1, c1 - 1 do
					if (r + c) % 4 == 0 then
						put(r, c, ".")
					end
				end
			end
		end
		local room = rect.room
		local label = tostring(rect.id) .. shortName(room and room.template)
		local marks = (room and ROLE_MARK[room.role or ""] or "") .. (room and room.lantern and "L" or "")
		local text = string.sub(label, 1, c1 - c0 - 1)
		for i = 1, #text do
			put(r0 + 1, c0 + i, string.sub(text, i, i))
		end
		for i = 1, #marks do
			put(r0 + 2 <= r1 - 1 and r0 + 2 or r0 + 1, c0 + i, string.sub(marks, i, i))
		end
	end

	-- Doors on this floor: an open doorway is a gap, a door slab "D", a solid
	-- seam ":" (where a phantom doorway can appear).
	local function mark(dir: string, line: number, along: number, char: string)
		if dir == "N" or dir == "S" then
			local r, c = row(line), col(along)
			for dc = -1, 1 do
				put(r, c + dc, char)
			end
		else
			put(row(along), col(line), char)
		end
	end
	for _, seam in layout.seams do
		if (seam.floor or 0) == floor and seam.line then
			local char = ":"
			if seam.connected then
				char = seam.door and "D" or " "
			end
			mark(seam.dir, seam.line, seam.along, char)
		end
	end
	for _, door in { layout.frontDoor, layout.exitDoor } do
		if door and (door.floor or 0) == floor then
			mark(door.dir, door.line, door.along, door == layout.frontDoor and "F" or "X")
		end
	end

	local lines = table.create(height)
	for r = 1, height do
		lines[r] = (string.gsub(table.concat(grid[r]), "%s+$", ""))
	end
	return lines
end

-- The whole plan as text: each floor, then a legend.
function FloorPlan.render(layout, config): string
	local lattice = config and config.Lattice or 10
	local rects = RoomRects.ofLayout(layout, config)
	local bounds = { minX = math.huge, maxX = -math.huge, minZ = math.huge, maxZ = -math.huge }
	-- The storeys the house has: -1 the cellar to 2 the attic.
	local low, high = 0, 0
	for _, rect in rects do
		bounds.minX = math.min(bounds.minX, rect.x)
		bounds.maxX = math.max(bounds.maxX, rect.x + rect.w)
		bounds.minZ = math.min(bounds.minZ, rect.z)
		bounds.maxZ = math.max(bounds.maxZ, rect.z + rect.d)
		low = math.min(low, rect.floor or 0)
		high = math.max(high, RoomRects.topOf(rect))
	end

	local out = {}
	local seamLayout = layout.mode and layout or RoomRects.seamsOfCells(layout, config)
	for floor = low, high do
		table.insert(out, high > low and (FloorPlan.StoreyNames[floor] or ("Floor " .. floor)) or "Plan")
		for _, line in renderFloor(seamLayout, rects, floor, bounds, lattice) do
			table.insert(out, line)
		end
		table.insert(out, "")
	end
	table.insert(
		out,
		"Legend: D door, gap open doorway, : solid seam, F front door, X exit; S start, E exit, T table, L lantern"
	)
	for _, rect in rects do
		local room = rect.room
		table.insert(
			out,
			string.format(
				"  %2d %-16s %2dx%-2d floor %s%s rot %d %s%s",
				rect.id,
				room.template or "?",
				rect.w,
				rect.d,
				rect.tall and table.concat(storeysOf(rect), "+") or tostring(rect.floor or 0),
				room.zone and (" " .. room.zone) or "",
				room.rotation or 0,
				room.role or "",
				room.lantern and " lantern" or ""
			)
		)
	end
	if layout.seed then
		table.insert(
			out,
			string.format(
				"seed %d, %d rooms, attempts %d%s, hash %d",
				layout.seed,
				#layout.rooms,
				layout.attempts or 1,
				layout.fallback and " (fallback)" or "",
				FloorPlan.hash(layout)
			)
		)
	end
	return table.concat(out, "\n")
end

return FloorPlan
