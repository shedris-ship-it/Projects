return function(test, check, Shared, require)
	local Rooms = require(Shared.Data.Rooms)
	local Props = require(Shared.Data.Props)
	local RoomFit = require(Shared.Logic.RoomFit)
	local Rng = require(Shared.Lib.Rng)

	local SIDES = { "N", "E", "S", "W" }

	-- Doorways on lattice points of the walls, at least 7 studs from a corner,
	-- as the mansion generator places them.
	local function randomDoors(rng, inner, count)
		local doors = {}
		for _ = 1, count do
			local side = SIDES[rng:NextInteger(1, 4)]
			local half = (side == "N" or side == "S") and inner.x + 0.5 or inner.z + 0.5
			local options = {}
			local p = -half + 10
			while p <= half - 10 do
				table.insert(options, p)
				p += 10
			end
			if #options > 0 then
				table.insert(doors, { side = side, along = rng:Pick(options) })
			end
		end
		return doors
	end

	local function sourceOf(template)
		local m = template.mansion
		if m.authored then
			return { x = m.size[1] / 2 - 0.5, z = m.size[2] / 2 - 0.5 }
		end
		return { x = 19.5, z = 19.5 }
	end

	test("remap keeps wall distances and scales the middle", function()
		check.near(RoomFit.remap(18.5, 19.5, 9.5), 8.5, 1e-9, "a wall prop stays 1 from the wall")
		check.near(RoomFit.remap(-17, 19.5, 14.5), -12, 1e-9, "the other wall")
		check.near(RoomFit.remap(0, 19.5, 9.5), 0, 1e-9, "the middle stays the middle")
		check.near(RoomFit.remap(11.5, 19.5, 14.5), 6.5, 1e-9, "the band's edge is continuous")
		check.near(RoomFit.remap(5, 19.5, 19.5), 5, 1e-9, "same size, same place")
	end)

	test("fitted rooms: furniture inside the walls, out of the doorway lanes and not overlapping", function()
		local rng = Rng.new(7)
		local essentialsLost, essentials, rooms = 0, 0, 0
		local droppedCount = 0
		for _, template in Rooms.Mansion do
			local m = template.mansion
			if m.size and #(template.props or {}) > 0 then
				for _, turned in { false, true } do
					local w, d = m.size[1], m.size[2]
					if turned then
						w, d = d, w
					end
					local inner = { x = w / 2 - 0.5, z = d / 2 - 0.5 }
					for _ = 1, 40 do
						rooms += 1
						local doors = randomDoors(rng, inner, rng:NextInteger(1, m.maxSeams or 3))
						local fitted = RoomFit.fit(template, sourceOf(template), inner, doors)
						droppedCount += #fitted.dropped
						local boxes = {}
						for _, prop in fitted.props do
							local ex, ez = RoomFit.footprint(prop.kind, prop.ry)
							check.atMost(
								math.abs(prop.x) + ex,
								inner.x + 0.01,
								template.id .. " " .. prop.id .. " past a wall"
							)
							check.atMost(
								math.abs(prop.z) + ez,
								inner.z + 0.01,
								template.id .. " " .. prop.id .. " past a wall"
							)
							local kind = Props.Kinds[prop.kind]
							if kind.size[2] > 0.3 then -- everything but rugs
								for _, b in boxes do
									local apart = math.abs(prop.x - b.x) >= ex + b.ex + 0.19
										or math.abs(prop.z - b.z) >= ez + b.ez + 0.19
									check.truthy(apart, template.id .. " " .. prop.id .. " overlaps " .. b.id)
								end
								table.insert(boxes, { x = prop.x, z = prop.z, ex = ex, ez = ez, id = prop.id })
							end
						end
						for _, item in fitted.decor do
							for _, door in doors do
								if door.side == item.side then
									check.atLeast(
										math.abs(door.along - item.along),
										RoomFit.WallItemClear,
										"decor by a door"
									)
								end
							end
							-- Not over furniture standing against the same wall.
							local half = Props.WallDecor[item.kind].size[1] / 2
							for _, b in boxes do
								local acrossX = item.side == "N" or item.side == "S"
								local near = (item.side == "N" and b.z - b.ez <= -inner.z + 3)
									or (item.side == "S" and b.z + b.ez >= inner.z - 3)
									or (item.side == "W" and b.x - b.ex <= -inner.x + 3)
									or (item.side == "E" and b.x + b.ex >= inner.x - 3)
								local centre, reach = acrossX and b.x or b.z, acrossX and b.ex or b.ez
								if near then
									check.truthy(
										math.abs(item.along - centre) >= half + reach + 0.29,
										template.id .. " " .. item.id .. " hangs over " .. b.id
									)
								end
							end
						end
						for _, prop in template.props do
							local kind = Props.Kinds[prop.kind]
							if prop.deliberation or (kind and kind.hide) then
								essentials += 1
								local found = false
								for _, p in fitted.props do
									if p.id == prop.id then
										found = true
									end
								end
								if not found then
									essentialsLost += 1
								end
							end
						end
						if template.caseBoard then
							check.truthy(fitted.caseBoard ~= nil, template.id .. " has nowhere for the Case Board")
						end
					end
				end
			end
		end
		print(
			string.format(
				"      %d rooms: %.1f%% of hiding spots and tables kept, %.1f props left out per room",
				rooms,
				100 - essentialsLost / math.max(essentials, 1) * 100,
				droppedCount / rooms
			)
		)
		check.atMost(essentialsLost / math.max(essentials, 1), 0.1, "too many hiding spots and tables left out")
	end)

	-- The squad playtest (2026-10-08): a clock hung over a window. Squeezed into
	-- a small room, a window and a wall slot slid towards the middle of the
	-- same wall; now every wall item keeps clear of the others on its wall.
	test("fitted wall items keep clear of each other: no clock over a window", function()
		local rng = Rng.new(11)
		local slotsKept, slotsAll = 0, 0
		for _, template in Rooms.Mansion do
			local m = template.mansion
			if m.size and (#(template.decor or {}) > 0 or #(template.wallSlots or {}) > 0) then
				for _, turned in { false, true } do
					local w, d = m.size[1], m.size[2]
					if turned then
						w, d = d, w
					end
					local inner = { x = w / 2 - 0.5, z = d / 2 - 0.5 }
					for _ = 1, 40 do
						local doors = randomDoors(rng, inner, rng:NextInteger(1, m.maxSeams or 3))
						local fitted = RoomFit.fit(template, sourceOf(template), inner, doors)
						local items = {}
						for _, item in fitted.decor do
							table.insert(items, {
								side = item.side,
								along = item.along,
								half = Props.WallDecor[item.kind].size[1] / 2,
								id = item.id,
							})
						end
						for _, slot in fitted.wallSlots do
							table.insert(
								items,
								{ side = slot.side, along = slot.along, half = RoomFit.SlotHalf, id = "slot" }
							)
						end
						slotsKept += #fitted.wallSlots
						slotsAll += #(template.wallSlots or {})
						for i, a in items do
							for j = i + 1, #items do
								local b = items[j]
								if a.side == b.side then
									check.truthy(
										math.abs(a.along - b.along) >= a.half + b.half + RoomFit.WallItemGap - 0.01,
										template.id .. " " .. a.id .. " and " .. b.id .. " overlap on wall " .. a.side
									)
								end
							end
						end
					end
				end
			end
		end
		-- Giving way must not strip the walls bare: most slots still fit.
		check.atLeast(slotsKept / math.max(1, slotsAll), 0.6, "share of wall slots kept")
	end)

	test("the Deliberation Table always fits the dining room, at its heart, with its chairs", function()
		local template = Rooms.MansionById.dining_room
		local rng = Rng.new(3)
		local chairsKept, chairsAll = 0, 0
		for _ = 1, 200 do
			local w, d = template.mansion.size[1], template.mansion.size[2]
			local inner = { x = w / 2 - 0.5, z = d / 2 - 0.5 }
			local fitted = RoomFit.fit(template, { x = 19.5, z = 19.5 }, inner, randomDoors(rng, inner, 3))
			local found = false
			for _, prop in fitted.props do
				if prop.deliberation then
					found = true
					-- The room's heart (WP5): a `middle` prop may sit where solid
					-- furniture never goes; a doorway's lane may slide it a stride.
					check.truthy(
						math.abs(prop.x) <= 6 and math.abs(prop.z) <= 6,
						string.format("the table left the middle: (%.1f, %.1f)", prop.x, prop.z)
					)
				elseif prop.kind == "Chair" then
					chairsKept += 1
				end
			end
			chairsAll += 6
			check.truthy(found, "the table was left out")
		end
		-- (A chair in a doorway's lane is left out, by design.)
		check.truthy(
			chairsKept >= chairsAll * 0.7,
			"most chairs stay round the table: " .. chairsKept .. "/" .. chairsAll
		)
	end)
end
