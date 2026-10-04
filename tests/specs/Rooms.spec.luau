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

	-- In a corridor the band is filled by closets; furniture goes in the eight
	-- strips between the doorway lanes and the closet walls.
	local function strips(h)
		return {
			{ lane, h, -half, -h },
			{ -h, -lane, -half, -h },
			{ lane, h, h, half },
			{ -h, -lane, h, half },
			{ h, half, lane, h },
			{ h, half, -h, -lane },
			{ -half, -h, lane, h },
			{ -half, -h, -h, -lane },
		}
	end

	local function zonesFor(template)
		return template.corridor and strips(template.corridor.halfWidth) or bands
	end

	-- A { x, z, face } wall position sits on a closet face, facing into the
	-- corridor, at least `margin` from the junction and the outer wall.
	local function onClosetFace(template, slot, margin)
		if not template.corridor then
			return false
		end
		local h = template.corridor.halfWidth
		local eps = 1e-6
		local function within(v)
			return math.abs(v) >= h + margin - eps and math.abs(v) <= half - margin + eps
		end
		if math.abs(math.abs(slot.z) - h) < eps then
			return slot.face == (slot.z < 0 and "S" or "N") and within(slot.x)
		elseif math.abs(math.abs(slot.x) - h) < eps then
			return slot.face == (slot.x < 0 and "E" or "W") and within(slot.z)
		end
		return false
	end

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
					for _, band in zonesFor(template) do
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
			for _, band in zonesFor(template) do
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
				if slot.face then
					check.truthy(onClosetFace(template, slot, 2.5), template.id .. " wall slot is not on a closet face")
				else
					check.truthy(math.abs(slot.along) >= clearance, template.id .. " wall slot too close to a doorway")
					check.truthy(math.abs(slot.along) <= half - 2, template.id .. " wall slot past the corner")
				end
			end
			for _, decor in template.decor do
				local width = Props.WallDecor[decor.kind].size[1]
				if decor.face then
					check.truthy(
						onClosetFace(template, decor, width / 2),
						template.id .. "." .. decor.id .. " is not on a closet face"
					)
				elseif template.corridor and decor.kind == "Window" then
					-- A corridor window closes the end of an arm. Windows are only
					-- built on outside walls, which never have a doorway, and
					-- corridors never take a role, so never hold the exit door.
					check.truthy(next(template.roles) == nil, template.id .. " corridor with a role")
					check.truthy(
						math.abs(decor.along) + width / 2 <= template.corridor.halfWidth,
						template.id .. "." .. decor.id .. " is wider than its corridor arm"
					)
				else
					check.truthy(
						math.abs(decor.along) - width / 2 >= Config.Level.DoorWidth / 2,
						template.id .. "." .. decor.id .. " overlaps a doorway"
					)
				end
			end
		end
	end)

	-- Owner, 2026-10-04: new props clipped. A painting hung on a tell's wall slot
	-- hid the tell, and a curtain stood in front of a window with its sill inside
	-- the folds.
	test("wall decor keeps clear of the wall slots on its wall", function()
		for _, template in Rooms.List do
			for _, decor in template.decor do
				if not decor.face then
					local width = Props.WallDecor[decor.kind].size[1]
					for _, slot in template.wallSlots do
						if not slot.face and slot.side == decor.side then
							check.truthy(
								math.abs(decor.along - slot.along) >= width / 2 + 1.5,
								template.id
									.. "."
									.. decor.id
									.. " covers the wall slot at "
									.. slot.side
									.. " "
									.. slot.along
							)
						end
					end
				end
			end
		end
	end)

	test("wall decor doesn't hang inside furniture", function()
		local depth = 0.6 -- how far a window sill or frame stands out from the wall
		for _, template in Rooms.List do
			for _, decor in template.decor do
				if not decor.face then
					local size = Props.WallDecor[decor.kind].size
					local lo, hi = decor.along - size[1] / 2, decor.along + size[1] / 2
					local bottom = decor.y - size[2] / 2 - (decor.kind == "Window" and 0.3 or 0)
					for _, prop in template.props do
						local kind = Props.Kinds[prop.kind]
						local r = footprint(prop.kind, prop.x, prop.z, prop.ry)
						local touches, a0, a1
						if decor.side == "N" then
							touches, a0, a1 = r[3] <= -half + depth, r[1], r[2]
						elseif decor.side == "S" then
							touches, a0, a1 = r[4] >= half - depth, r[1], r[2]
						elseif decor.side == "W" then
							touches, a0, a1 = r[1] <= -half + depth, r[3], r[4]
						else
							touches, a0, a1 = r[2] >= half - depth, r[3], r[4]
						end
						local along = a0 < hi - 1e-6 and lo < a1 - 1e-6
						check.truthy(
							not (touches and along and kind.size[2] > bottom),
							template.id .. "." .. decor.id .. " hangs inside " .. prop.id
						)
					end
				end
			end
		end
	end)

	test("a plant's foliage fits its own footprint", function()
		local plant = Props.Kinds.Plant
		check.truthy(
			plant.reach and plant.reach <= math.min(plant.size[1], plant.size[3]) / 2,
			"reach within the footprint"
		)
	end)

	test("corridors keep the lanes clear and their floor slots inside the corridor", function()
		for _, template in Rooms.List do
			if template.corridor then
				local h = template.corridor.halfWidth
				check.truthy(h > lane, template.id .. " corridor is narrower than the doorway lanes")
				check.truthy(h < inner, template.id .. " corridor is no narrower than an ordinary room")
				for _, slot in template.floorSlots do
					local ok = false
					for _, strip in strips(h) do
						if inside({ slot.x, slot.x, slot.z, slot.z }, strip) then
							ok = true
						end
					end
					check.truthy(
						ok,
						string.format("%s floor slot %.1f,%.1f is not in the corridor", template.id, slot.x, slot.z)
					)
				end
			end
		end
	end)

	test("every template has a lighting family with a ceiling colour", function()
		for _, template in Rooms.List do
			local family = Config.Lighting.Families[template.family or ""]
			check.truthy(family, template.id .. " has unknown lighting family " .. tostring(template.family))
			if family then
				check.truthy(Config.Lighting[family.ceiling], template.id .. " ceiling colour " .. family.ceiling)
			end
		end
	end)

	test("every surface is a house material or a built-in one", function()
		local Materials = require(Shared.Data.Materials)
		-- Built-in materials the templates may still use directly.
		local builtIn = {
			Plaster = true,
			CeramicTiles = true,
			Slate = true,
			WoodPlanks = true,
			Wood = true,
			Concrete = true,
			Carpet = true,
			Plastic = true,
		}
		local function known(name)
			return Materials.ByName[name] ~= nil or builtIn[name] == true
		end
		for _, template in Rooms.List do
			check.truthy(known(template.wall.material), template.id .. " wall " .. template.wall.material)
			check.truthy(known(template.floor.material), template.id .. " floor " .. template.floor.material)
		end
		check.truthy(known(Config.Ceiling.material), "ceiling " .. Config.Ceiling.material)
		check.truthy(known(Config.Trim.Wainscot.material), "wainscot " .. Config.Trim.Wainscot.material)
		for _, material in Materials.List do
			check.truthy(builtIn[material.base], material.name .. " has unknown base " .. material.base)
			check.truthy(material.maps and material.maps.color ~= nil, material.name .. " has no texture")
			check.truthy(material.studs and material.studs > 0, material.name .. " studs per tile")
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
