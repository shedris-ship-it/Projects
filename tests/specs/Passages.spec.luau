-- Servants' passages (docs/plans/level-design.md section 10.4): a narrow way
-- along two rooms of one wing, joined to each by a hidden door, where it
-- saves real walking. Not part of the house the escape is planned on: the
-- house is whole and fair without it.
return function(test, check, Shared, require)
	local Config = require(Shared.Config)
	local Rooms = require(Shared.Data.Rooms)
	local FloorPlan = require(Shared.Logic.FloorPlan)
	local HouseSize = require(Shared.Logic.HouseSize)
	local LayoutValidator = require(Shared.Logic.LayoutValidator)
	local MansionGen = require(Shared.Logic.MansionGen)
	local MansionHouse = require(Shared.Logic.MansionHouse)
	local NavGraph = require(Shared.Logic.NavGraph)
	local RoomRects = require(Shared.Logic.RoomRects)

	local mansion = HouseSize.config(Config.Mansion, Config.Progression, 4)
	local cfg = Config.Mansion.Passages
	local houses = {}
	for seed = 1, 60 do
		local layout = MansionGen.generate(seed * 19 + 4, Rooms.Mansion, mansion)
		if not layout.fallback then
			table.insert(houses, layout)
		end
	end

	test("a passage: on free ground beside the house, two hidden doors into one wing, real walking saved", function()
		local with = 0
		for _, layout in houses do
			for _, passage in layout.passages or {} do
				with += 1
				local where = "seed " .. tostring(layout.seed)
				check.truthy(math.min(passage.w, passage.d) == cfg.Width, where .. ": narrow")
				check.truthy(passage.z + passage.d <= mansion.FrontLine, where .. ": behind the front line")
				for _, room in layout.rooms do
					if MansionHouse.onFloor(room, passage.floor) then
						check.truthy(not RoomRects.overlaps(room, passage), where .. ": overlaps room " .. room.id)
					end
				end
				check.equal(#passage.seams, 2, where .. ": two doors")
				local regions = {}
				for _, seam in passage.seams do
					check.truthy(seam.hidden and seam.connected, where .. ": a hidden door")
					check.equal(seam.b, passage.id, where .. ": the passage is the door's far side")
					local room = layout.rooms[seam.a]
					local c = RoomRects.contact(room, passage)
					check.truthy(
						c ~= nil and c.dir == seam.dir and c.line == seam.line,
						where .. ": in their shared wall"
					)
					check.truthy(seam.along >= c.from + 3 and seam.along <= c.to - 3, where .. ": the doorway fits")
					check.truthy(cfg.Zones[room.zone] ~= nil, where .. ": not into a " .. tostring(room.zone))
					table.insert(regions, layout.wings.roomRegion[seam.a])
				end
				-- In one wing; or, between two, the later wing's door is barred
				-- from the passage (a shortcut home, not a way round a lock).
				if regions[1] ~= regions[2] then
					local opensAt = { [0] = 0 }
					for i, r in layout.wings.order do
						opensAt[r] = i
					end
					local later = opensAt[regions[1]] > opensAt[regions[2]] and 1 or 2
					check.truthy(passage.seams[later].barred, where .. ": the later wing's door is barred")
					check.truthy(not passage.seams[3 - later].barred, where .. ": the earlier wing's isn't")
				end
				check.atLeast(passage.saves, cfg.MinSaves, where .. ": saves walking")
				-- The house without it is the house: valid on its own.
				local ok, problems = LayoutValidator.validate(layout, Rooms.Mansion, mansion)
				check.truthy(ok, where .. ": " .. table.concat(problems, "; "))
			end
		end
		check.truthy(with >= #houses * 0.2, ("%d of %d houses have a passage"):format(with, #houses))
	end)

	test("the walkers' graph takes the passage only when asked, and through its doors", function()
		local options = NavGraph.options(Config)
		local tested = 0
		for _, layout in houses do
			local passage = layout.passages and layout.passages[1]
			if passage and tested < 4 then
				tested += 1
				local plain = NavGraph.build(layout, options)
				check.equal(plain.rooms[passage.id], nil, "no passage without asking")
				local withOptions = table.clone(options)
				withOptions.passages = true
				local graph = NavGraph.build(layout, withOptions)
				check.truthy(graph.rooms[passage.id] ~= nil, "the passage is walked")
				for _, seam in passage.seams do
					check.truthy(graph.seams[seam.id] ~= nil, "its hidden door is a doorway")
				end
				-- From one room to the other through it, when nothing else may pass.
				local a, b = layout.rooms[passage.seams[1].a], layout.rooms[passage.seams[2].a]
				local hidden = { [passage.seams[1].id] = true, [passage.seams[2].id] = true }
				local ax, az = RoomRects.center(a)
				local bx, bz = RoomRects.center(b)
				local route = NavGraph.route(
					graph,
					{ x = ax, y = (a.floor or 0) * options.pitch, z = az },
					a.id,
					{ x = bx, y = (b.floor or 0) * options.pitch, z = bz },
					b.id,
					{
						doorCost = function(seamId)
							return hidden[seamId] and 0 or nil
						end,
					}
				)
				check.truthy(route ~= nil, "a way through the passage")
			end
		end
		check.truthy(tested > 0, "houses with a passage to walk")
	end)

	test("the plan printer shows the passage and its hidden doors", function()
		for _, layout in houses do
			if layout.passages then
				local text = FloorPlan.render(layout, mansion)
				check.truthy(string.find(text, "servants_passage", 1, true) ~= nil, "listed")
				check.truthy(string.find(text, "H", 1, true) ~= nil, "hidden doors drawn")
				return
			end
		end
	end)
end
