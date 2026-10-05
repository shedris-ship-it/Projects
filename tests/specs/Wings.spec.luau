-- The adventure decides the doors (Logic/Wings, docs/plans/level-design.md
-- section 5.3): over many mansions and squad sizes the wings are the right
-- size and shape, every beat is what it says, the planner keeps them, and a
-- seed always gives the same adventure.
return function(test, check, Shared, require)
	local Config = require(Shared.Config)
	local Rooms = require(Shared.Data.Rooms)
	local Rng = require(Shared.Lib.Rng)
	local Graph = require(Shared.Logic.Graph)
	local HouseSize = require(Shared.Logic.HouseSize)
	local LockPlanner = require(Shared.Logic.LockPlanner)
	local MansionGen = require(Shared.Logic.MansionGen)
	local Wings = require(Shared.Logic.Wings)

	local cfg = Config.Mansion.Wings

	-- Made once: 20 houses for each of squads 1 and 4.
	local houses = {}
	for _, squad in { 1, 4 } do
		local mansion, progression = HouseSize.config(Config.Mansion, Config.Progression, squad)
		for seed = 1, 20 do
			local layout = MansionGen.generate(seed * 37 + squad, Rooms.Mansion, mansion)
			table.insert(houses, {
				squad = squad,
				seed = seed,
				layout = layout,
				mansion = mansion,
				progression = progression,
				plan = LockPlanner.plan(
					layout,
					Rooms.MansionById,
					Rng.new(seed):Fork("progression"),
					progression,
					mansion
				),
			})
		end
	end

	test("the tree of doors: subtree sizes and who is under whom", function()
		--     1
		--    / \
		--   2   3
		--  / \
		-- 4   5
		local tree = Wings.tree({ 1, 2, 3, 4, 5 }, { { 1, 2 }, { 1, 3 }, { 2, 4 }, { 2, 5 } }, 1)
		check.equal(tree.size[1], 5)
		check.equal(tree.size[2], 3)
		check.equal(tree.parent[4], 2)
		check.truthy(Wings.isAncestor(tree, 2, 5), "5 is under 2")
		check.truthy(not Wings.isAncestor(tree, 3, 4), "4 isn't under 3")
		check.truthy(Wings.isAncestor(tree, 1, 1), "a room is under itself")
	end)

	test("most houses are planned as wings, and the planner keeps them", function()
		local planned, kept = 0, 0
		for _, house in houses do
			if house.layout.wings then
				planned += 1
				if house.plan.stats.wings then
					kept += 1
				end
			end
		end
		check.truthy(planned / #houses >= 0.75, ("%d of %d houses planned as wings"):format(planned, #houses))
		check.truthy(kept / math.max(1, planned) >= 0.9, ("%d of %d wings kept by the planner"):format(kept, planned))
	end)

	test("every wing is 3-7 rooms, holds together, and opens by its gate from somewhere open before it", function()
		for _, house in houses do
			local wings = house.layout.wings
			if wings then
				local where = ("squad %d seed %d"):format(house.squad, house.seed)
				local position = { [0] = 0 }
				for i, r in wings.order do
					position[r] = i
				end
				local edges = {}
				for _, seam in house.layout.seams do
					if seam.connected then
						table.insert(edges, { seam.a, seam.b })
					end
				end
				for _, r in wings.order do
					local rooms = wings.regions[r].rooms
					check.truthy(#rooms >= cfg.MinWing and #rooms <= cfg.MaxWing, where .. ": wing of " .. #rooms)
					check.truthy(Graph.isConnected(Graph.adjacency(rooms, edges), rooms), where .. ": wing in pieces")
					local gate
					for _, seam in house.layout.seams do
						if seam.id == wings.gates[r] then
							gate = seam
						end
					end
					check.truthy(gate and gate.connected, where .. ": the gate is a doorway")
					local ra, rb = wings.roomRegion[gate.a], wings.roomRegion[gate.b]
					local outer = ra == r and rb or ra
					check.truthy(position[outer] < position[r], where .. ": gate from a region opened before")
					local key = wings.keyRegion[r]
					check.truthy(key == nil or position[key] < position[r], where .. ": key kept before its door")
				end
				-- Region 0 holds the hall and the table.
				check.equal(wings.roomRegion[house.layout.start], 0)
				check.equal(wings.roomRegion[house.layout.deliberation], 0)
				check.equal(
					#LockPlanner.checkShape(
						house.layout,
						Wings.skeleton(wings, house.layout.seams),
						Rooms.MansionById,
						house.progression,
						house.mansion
					),
					0
				)
			end
		end
	end)

	test("each beat is what it says", function()
		local backtracks, shortcuts, parallels = 0, 0, 0
		for _, house in houses do
			local wings = house.layout.wings
			if wings then
				local where = ("squad %d seed %d"):format(house.squad, house.seed)
				local seams = {}
				for _, seam in house.layout.seams do
					seams[seam.id] = seam
				end
				local position = { [0] = 0 }
				for i, r in wings.order do
					position[r] = i
				end
				for _, r in wings.order do
					local beat = wings.beats[r]
					if beat.shortcut then
						shortcuts += 1
						local seam = seams[beat.shortcut]
						check.truthy(seam.connected, where .. ": the shortcut is a doorway")
						local ra, rb = wings.roomRegion[seam.a], wings.roomRegion[seam.b]
						check.truthy((ra == r) ~= (rb == r), where .. ": the shortcut leaves the wing")
						check.truthy(
							position[ra == r and rb or ra] < position[r],
							where .. ": to somewhere open before"
						)
						-- Opened from the wing's side only: a bolt.
						check.equal(house.plan.stats.wings and house.plan.locks[seam.id].kind or "bolt", "bolt")
					end
					if beat.backtrack then
						backtracks += 1
					end
					if beat.parallel then
						parallels += 1
						check.truthy(house.squad >= cfg.ParallelFrom, where .. ": wings side by side for a small squad")
					end
				end
			end
		end
		check.truthy(backtracks > 0, "some backtracks")
		check.truthy(shortcuts > 0, "some shortcuts")
		check.truthy(parallels > 0, "some wings side by side for the bigger squad")
	end)

	test("the same seed and squad give the same wings", function()
		local mansion = HouseSize.config(Config.Mansion, Config.Progression, 4)
		local a = MansionGen.generate(777, Rooms.Mansion, mansion).wings
		local b = MansionGen.generate(777, Rooms.Mansion, mansion).wings
		check.equal(a ~= nil, b ~= nil)
		if a and b then
			check.equal(table.concat(a.order, ","), table.concat(b.order, ","))
			for _, r in a.order do
				check.equal(a.gates[r], b.gates[r])
				check.equal(table.concat(a.regions[r].rooms, ","), table.concat(b.regions[r].rooms, ","))
			end
		end
	end)
end
