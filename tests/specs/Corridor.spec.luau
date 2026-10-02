return function(test, check, Shared, require)
	local Config = require(Shared.Config)
	local Rooms = require(Shared.Data.Rooms)
	local Props = require(Shared.Data.Props)
	local Corridor = require(Shared.Logic.Corridor)
	local LevelGraph = require(Shared.Logic.LevelGraph)

	local level = Config.Level

	test("arms: positions in the strips and on closet faces belong to the arm they line", function()
		check.equal(Corridor.armOf(7, 5.75, -13), "N", "north strip")
		check.equal(Corridor.armOf(7, -13, 5.75), "W", "west strip")
		check.equal(Corridor.armOf(7, 0, 0), nil, "junction")
		check.equal(Corridor.armOfWall(7, { x = 13, z = -7, face = "S" }), "E", "closet face in the east arm")
		check.equal(Corridor.armOfWall(7, { x = -7, z = -13, face = "E" }), "N", "closet face in the north arm")
		check.equal(Corridor.armOfWall(7, { side = "S", along = 0 }), "S", "the end of the south arm")
	end)

	test("every corridor template's contents sit in an arm or the junction, never in a closet", function()
		for _, template in Rooms.List do
			if template.corridor then
				local h = template.corridor.halfWidth
				for _, prop in template.props do
					local kind = Props.Kinds[prop.kind]
					if kind.collide ~= false then
						check.truthy(
							Corridor.armOf(h, prop.x, prop.z) ~= nil,
							template.id .. "." .. prop.id .. " is not in an arm"
						)
					end
				end
				for _, list in { template.wallSlots, template.decor } do
					for _, slot in list do
						check.truthy(Corridor.armOfWall(h, slot) ~= nil, template.id .. " wall position outside an arm")
					end
				end
			end
		end
	end)

	test("1000 seeds: arms are filled only at outside walls, never where something must stay", function()
		local corridors, filled, houses, withCorridor = 0, 0, 0, 0
		for seed = 1, 1000 do
			local layout = LevelGraph.generate(seed * 11 + 5, Rooms.List, level)
			houses += 1
			local any = false
			for _, room in layout.rooms do
				local template = Rooms.ById[room.template]
				if template.corridor then
					any = true
					corridors += 1
					local h = template.corridor.halfWidth
					local arms = Corridor.filledArms(template, room, layout.cells)
					local open = 0
					for _, side in LevelGraph.DirOrder do
						local world = LevelGraph.worldSide(side, room.rotation)
						if arms[side] then
							filled += 1
							check.truthy(
								LevelGraph.isOuterSide(room, layout.cells, world),
								"filled an arm that leads to another room"
							)
						else
							open += 1
						end
					end
					check.atLeast(open, 1, "a corridor with every arm filled")
					for _, prop in template.props do
						local arm = Corridor.armOf(h, prop.x, prop.z)
						if arm and Props.Kinds[prop.kind].hide then
							check.truthy(not arms[arm], "filled an arm holding a hiding spot")
						end
					end
					for _, decor in template.decor do
						if decor.kind == "Window" then
							check.truthy(not arms[Corridor.armOfWall(h, decor)], "filled an arm holding a window")
						end
					end
					if room.lantern then
						local arm = Corridor.armOf(h, template.shrine.x, template.shrine.z)
						check.truthy(not arm or not arms[arm], "filled the arm holding a Lantern shrine")
					end
				end
			end
			if any then
				withCorridor += 1
			end
		end
		print(
			string.format(
				"      %.1f%% of houses have a corridor; %.2f corridors per house, %.2f arms filled each",
				withCorridor / houses * 100,
				corridors / houses,
				filled / math.max(corridors, 1)
			)
		)
	end)
end
