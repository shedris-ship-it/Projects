-- Where a cutscene camera can stand (Logic/ShotPicker; the owner, 2026-10-15:
-- "smart enough to avoid going somewhere you cant see the animation
-- happen"), in made-up rooms of boxes.
return function(test, check, Shared, require)
	local ShotPicker = require(Shared.Logic.ShotPicker)

	-- Does the segment a -> b pass through an axis-aligned box?
	local function hits(a, b, box)
		local tmin, tmax = 0, 1
		for i = 1, 3 do
			local d = b[i] - a[i]
			if math.abs(d) < 1e-9 then
				if a[i] < box.min[i] or a[i] > box.max[i] then
					return false
				end
			else
				local t1 = (box.min[i] - a[i]) / d
				local t2 = (box.max[i] - a[i]) / d
				if t1 > t2 then
					t1, t2 = t2, t1
				end
				tmin = math.max(tmin, t1)
				tmax = math.min(tmax, t2)
				if tmin > tmax then
					return false
				end
			end
		end
		return true
	end

	local function room(boxes)
		return function(a, b)
			for _, box in boxes do
				if hits(a, b, box) then
					return false
				end
			end
			return true
		end
	end

	-- A 30 x 30 room, walls 1 thick, ceiling at 10.
	local walls = {
		{ min = { -16, 0, -16 }, max = { 16, 10, -15 } },
		{ min = { -16, 0, 15 }, max = { 16, 10, 16 } },
		{ min = { -16, 0, -16 }, max = { -15, 10, 16 } },
		{ min = { 15, 0, -16 }, max = { 16, 10, 16 } },
	}

	local function opts(extra, boxes)
		local o = {
			focus = { 0, 5, 0 },
			subjects = { { 0, 5, 0 }, { 0, 3, -2 } },
			radii = { 6, 8 },
			heights = { 5, 7 },
			floor = 0,
			ceiling = 10,
			prefer = { 1, 0 },
			preferRadius = 7,
			preferHeight = 5.5,
			clear = room(boxes),
		}
		for k, v in extra or {} do
			o[k] = v
		end
		return o
	end

	test("in an open room it takes the bearing it likes best", function()
		local shot = ShotPicker.pick(opts(nil, walls))
		check.truthy(shot ~= nil, "a shot")
		check.atLeast(shot.position[1], 5.5, "off to +X, as preferred")
	end)

	test("a wall on that side: it goes round to another clear place", function()
		local boxes = table.clone(walls)
		-- A wall across the room at x = 3: nothing on the +X side can see in.
		table.insert(boxes, { min = { 3, 0, -15 }, max = { 3.5, 10, 15 } })
		local shot = ShotPicker.pick(opts(nil, boxes))
		check.truthy(shot ~= nil, "a shot")
		check.atMost(shot.position[1], 3, "on the near side of the wall")
		check.truthy(room(boxes)(shot.position, { 0, 5, 0 }), "and it sees the focus")
		check.truthy(room(boxes)(shot.position, { 0, 3, -2 }), "and the other subject")
	end)

	test("a pillar in the way of one subject rules that place out", function()
		local boxes = table.clone(walls)
		-- A pillar between the preferred places and the second subject.
		table.insert(boxes, { min = { 2, 0, -3 }, max = { 3, 10, -1 } })
		local shot = ShotPicker.pick(opts(nil, boxes))
		check.truthy(shot ~= nil, "a shot")
		check.truthy(room(boxes)(shot.position, { 0, 3, -2 }), "it sees past the pillar")
	end)

	test("never outside the room, nor above its ceiling", function()
		local shot = ShotPicker.pick(opts({ radii = { 25 }, heights = { 14 } }, walls))
		check.truthy(shot == nil, "every place is beyond a wall")
		local inside = ShotPicker.pick(opts({ heights = { 14 } }, walls))
		check.truthy(inside ~= nil, "a shot")
		check.atMost(inside.position[2], 9.4, "kept under the ceiling")
	end)

	test("a cupboard with no room to stand: no shot (the caller falls back)", function()
		local boxes = {
			{ min = { -2, 0, -2 }, max = { 2, 10, -1.5 } },
			{ min = { -2, 0, 1.5 }, max = { 2, 10, 2 } },
			{ min = { -2, 0, -2 }, max = { -1.5, 10, 2 } },
			{ min = { 1.5, 0, -2 }, max = { 2, 10, 2 } },
		}
		local shot = ShotPicker.pick(opts({ subjects = { { 0, 5, 0 } } }, boxes))
		check.truthy(shot == nil, "nowhere fits")
	end)

	test("a body between the camera and a face rules that place out", function()
		-- Someone standing just +X of the face: the preferred side is hidden.
		local shot = ShotPicker.pick(opts({ blockers = { { { 1.2, 5, 0 }, 0.8 } } }, walls))
		check.truthy(shot ~= nil, "a shot")
		check.truthy(
			not ShotPicker.hidden(shot.position, { 0, 5, 0 }, { { { 1.2, 5, 0 }, 0.8 } }),
			"it sees round them"
		)
	end)

	test("a cone keeps the camera in front of a face", function()
		local shot = ShotPicker.pick(opts({ prefer = { -1, 0 }, cone = { 1, 0, math.cos(math.rad(70)) } }, walls))
		check.truthy(shot ~= nil, "a shot")
		check.atLeast(shot.position[1], 0, "never behind (-X), whatever it would prefer")
	end)

	test("it keeps out of a body it's told to avoid", function()
		local shot = ShotPicker.pick(opts({ avoid = { 7, 5.5, 0 }, avoidRadius = 2 }, walls))
		check.truthy(shot ~= nil, "a shot")
		local d = math.sqrt((shot.position[1] - 7) ^ 2 + (shot.position[2] - 5.5) ^ 2 + shot.position[3] ^ 2)
		check.atLeast(d, 2, "clear of it")
	end)
end
