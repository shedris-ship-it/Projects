return function(test, check, Shared, require)
	local Config = require(Shared.Config)
	local Rooms = require(Shared.Data.Rooms)
	local Props = require(Shared.Data.Props)

	local half = Config.Level.CellSize / 2 - Config.Level.WallThickness
	local lane = Config.Level.LaneHalfWidth
	local inner = half - Config.Level.BandDepth + 0.5 -- 12 for a 40-stud room

	-- The eight rectangles of the wall band that sit outside the doorway lanes.
	local bands = {
		{ -half, -lane, -half, -inner },
		{ lane, half, -half, -inner },
		{ -half, -lane, inner, half },
		{ lane, half, inner, half },
		{ -half, -inner, -half, -lane },
		{ -half, -inner, lane, half },
		{ inner, half, -half, -lane },
		{ inner, half, lane, half },
	}

	local function footprint(kindName, x, z, ry)
		local kind = Props.Kinds[kindName]
		local w, d = kind.size[1], kind.size[3]
		ry = (ry or 0) % 360
		if ry == 90 or ry == 270 then
			w, d = d, w
		end
		return { x - w / 2, x + w / 2, z - d / 2, z + d / 2 }
	end

	local function inside(rect, band)
		local eps = 1e-6
		return rect[1] >= band[1] - eps
			and rect[2] <= band[2] + eps
			and rect[3] >= band[3] - eps
			and rect[4] <= band[4] + eps
	end

	local function overlaps(a, b)
		local eps = 1e-6
		return a[1] < b[2] - eps and b[1] < a[2] - eps and a[3] < b[4] - eps and b[3] < a[4] - eps
	end

	test("every prop kind used by a template exists", function()
		for _, template in Rooms.List do
			for _, prop in template.props do
				check.truthy(Props.Kinds[prop.kind], template.id .. " uses unknown prop " .. prop.kind)
			end
			for _, decor in template.decor do
				check.truthy(Props.WallDecor[decor.kind], template.id .. " uses unknown decor " .. decor.kind)
			end
		end
	end)

	test("collidable furniture stays in the wall band and out of the doorway lanes", function()
		for _, template in Rooms.List do
			for _, prop in template.props do
				local kind = Props.Kinds[prop.kind]
				if kind.collide ~= false then
					local rect = footprint(prop.kind, prop.x, prop.z, prop.ry)
					local ok = false
					for _, band in bands do
						if inside(rect, band) then
							ok = true
						end
					end
					check.truthy(
						ok,
						string.format(
							"%s.%s footprint %.1f..%.1f x %.1f..%.1f is not inside the wall band",
							template.id,
							prop.id,
							rect[1],
							rect[2],
							rect[3],
							rect[4]
						)
					)
				end
			end
		end
	end)

	test("furniture doesn't overlap other furniture or the shrine", function()
		for _, template in Rooms.List do
			local rects = {}
			for _, prop in template.props do
				if Props.Kinds[prop.kind].collide ~= false then
					table.insert(rects, { name = prop.id, rect = footprint(prop.kind, prop.x, prop.z, prop.ry) })
				end
			end
			table.insert(
				rects,
				{ name = "shrine", rect = footprint("Shrine", template.shrine.x, template.shrine.z, 0) }
			)
			for i = 1, #rects do
				for j = i + 1, #rects do
					check.truthy(
						not overlaps(rects[i].rect, rects[j].rect),
						template.id .. ": " .. rects[i].name .. " overlaps " .. rects[j].name
					)
				end
			end
		end
	end)

	test("shrine spots are in the band too", function()
		for _, template in Rooms.List do
			local rect = footprint("Shrine", template.shrine.x, template.shrine.z, 0)
			local ok = false
			for _, band in bands do
				if inside(rect, band) then
					ok = true
				end
			end
			check.truthy(ok, template.id .. " shrine blocks a lane or the centre")
		end
	end)

	test("wall slots and decor avoid doorways", function()
		local clearance = Config.Level.DoorWidth / 2 + 2.5
		for _, template in Rooms.List do
			for _, slot in template.wallSlots do
				check.truthy(math.abs(slot.along) >= clearance, template.id .. " wall slot too close to a doorway")
				check.truthy(math.abs(slot.along) <= half - 2, template.id .. " wall slot past the corner")
			end
			for _, decor in template.decor do
				local width = Props.WallDecor[decor.kind].size[1]
				check.truthy(
					math.abs(decor.along) - width / 2 >= Config.Level.DoorWidth / 2,
					template.id .. "." .. decor.id .. " overlaps a doorway"
				)
			end
		end
	end)

	test("every template has a lighting family with a fill colour", function()
		for _, template in Rooms.List do
			local family = Config.Lighting.Families[template.family or ""]
			check.truthy(family, template.id .. " has unknown lighting family " .. tostring(template.family))
			if family then
				check.truthy(Config.Lighting[family.fill], template.id .. " fill colour " .. family.fill)
			end
		end
	end)

	test("every template has at least 3 floor slots and 3 wall slots", function()
		for _, template in Rooms.List do
			check.atLeast(#template.floorSlots, 3, template.id .. " floor slots")
			check.atLeast(#template.wallSlots, 3, template.id .. " wall slots")
		end
	end)

	test("roles are covered", function()
		local roles = { start = 0, exit = 0, deliberation = 0 }
		for _, template in Rooms.List do
			for role in template.roles do
				roles[role] += 1
			end
		end
		check.atLeast(roles.start, 1, "start templates")
		check.atLeast(roles.exit, 1, "exit templates")
		check.atLeast(roles.deliberation, 1, "deliberation templates")
		local general = 0
		for _, template in Rooms.List do
			if next(template.roles) == nil then
				general += template.max or 1
			end
		end
		check.atLeast(general, Config.Level.RoomCount[2] - 3, "enough general rooms for the largest layout")
	end)
end
