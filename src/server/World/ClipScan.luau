-- Debug scan for furniture and decor that clip (F2 console: "clip").
-- Owner, 2026-10-04: new props clipped into walls and each other, in more
-- places than anyone could find by reading data. This walks a built room and
-- lists every pair of boxes that overlap by more than a hair: prop against
-- prop, and prop against a wall. Only Block parts are compared (a ball or
-- cylinder is a loose box here), so a few reports are false alarms; the
-- depth in studs says how bad each one is. Cylinders count as loose boxes
-- too, and things hung on walls outside the room's model (clocks, portraits,
-- the fuse box) come in as `extras` (the squad playtest, 2026-10-08: a clock
-- over a window).

local ClipScan = {}

-- Never worth reporting: rugs lie under furniture, chairs tuck in, the
-- ceiling fixture and dust are overhead.
local SKIP = { Rug = true, Chair = true, Dust = true, CeilingFixture = true, Door = true }
local PROP_DEPTH = 0.15 -- props touching or resting on each other overlap by less than this
local WALL_DEPTH = 0.25 -- baseboards and flush backs sit this far into a wall by design

-- How deep two oriented boxes overlap along the axis where they overlap least
-- (the separating-axis test); 0 when they don't touch.
local function penetration(cfA: CFrame, sizeA: Vector3, cfB: CFrame, sizeB: Vector3): number
	local axesA = { cfA.RightVector, cfA.UpVector, cfA.LookVector }
	local axesB = { cfB.RightVector, cfB.UpVector, cfB.LookVector }
	local halfA, halfB = sizeA / 2, sizeB / 2
	local halves = { halfA.X, halfA.Y, halfA.Z }
	local halvesB = { halfB.X, halfB.Y, halfB.Z }
	local offset = cfB.Position - cfA.Position
	local least = math.huge
	local function separated(axis: Vector3): boolean
		if axis.Magnitude < 1e-4 then
			return false -- parallel edges: no new axis
		end
		axis = axis.Unit
		local reachA, reachB = 0, 0
		for i = 1, 3 do
			reachA += math.abs(axesA[i]:Dot(axis)) * halves[i]
			reachB += math.abs(axesB[i]:Dot(axis)) * halvesB[i]
		end
		local overlap = reachA + reachB - math.abs(offset:Dot(axis))
		if overlap <= 0 then
			return true
		end
		least = math.min(least, overlap)
		return false
	end
	for i = 1, 3 do
		if separated(axesA[i]) or separated(axesB[i]) then
			return 0
		end
	end
	for i = 1, 3 do
		for j = 1, 3 do
			if separated(axesA[i]:Cross(axesB[j])) then
				return 0
			end
		end
	end
	return least == math.huge and 0 or least
end

local function blocksOf(model: Instance): { BasePart }
	local list = {}
	for _, d in model:GetDescendants() do
		if
			d:IsA("Part")
			and (d.Shape == Enum.PartType.Block or d.Shape == Enum.PartType.Cylinder)
			and d.Transparency < 1
		then
			table.insert(list, d)
		end
	end
	return list
end

-- The worst overlap between two lists of parts, and which two parts it was.
local function worst(listA: { BasePart }, listB: { BasePart }, floor: number)
	local depth, a, b = floor, nil, nil
	for _, pa in listA do
		for _, pb in listB do
			local d = penetration(pa.CFrame, pa.Size, pb.CFrame, pb.Size)
			if d > depth then
				depth, a, b = d, pa, pb
			end
		end
	end
	return a and b and depth or nil, a, b
end

-- One room's report lines, worst first.
function ClipScan.room(roomName: string, room: Model, extras: { Model }?): { string }
	local models = {}
	local walls = {}
	for _, extra in extras or {} do
		local cf, size = extra:GetBoundingBox()
		table.insert(models, { model = extra, cf = cf, size = size, parts = blocksOf(extra) })
	end
	for _, child in room:GetChildren() do
		if child:IsA("Model") and not SKIP[child.Name] then
			local cf, size = child:GetBoundingBox()
			table.insert(models, { model = child, cf = cf, size = size, parts = blocksOf(child) })
		elseif child:IsA("Part") and child.Name == "Wall" then
			table.insert(walls, child)
		end
	end
	local found = {}
	for i = 1, #models do
		local a = models[i]
		-- Against the walls.
		local depth, pa, wall = worst(a.parts, walls, WALL_DEPTH)
		if depth and pa and wall then
			table.insert(
				found,
				{ depth = depth, text = string.format("%s: %s.%s into a wall", roomName, a.model.Name, pa.Name) }
			)
		end
		-- Against the other props and decor.
		for j = i + 1, #models do
			local b = models[j]
			if penetration(a.cf, a.size, b.cf, b.size) > 0 then
				local d, partA, partB = worst(a.parts, b.parts, PROP_DEPTH)
				if d and partA and partB then
					table.insert(found, {
						depth = d,
						text = string.format(
							"%s: %s.%s through %s.%s",
							roomName,
							a.model.Name,
							partA.Name,
							b.model.Name,
							partB.Name
						),
					})
				end
			end
		end
	end
	table.sort(found, function(x, y)
		return x.depth > y.depth
	end)
	local lines = {}
	for _, f in found do
		table.insert(lines, string.format("%.2f studs  %s", f.depth, f.text))
	end
	return lines
end

return ClipScan
