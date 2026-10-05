-- The laundry chute (docs/plans/level-design.md section 10.5): a hatch in an
-- upstairs room over the laundry, on a wall the two share, clear of both
-- rooms' doorways and furniture; never the dumbwaiter's too.
return function(test, check, Shared, require)
	local Config = require(Shared.Config)
	local Rooms = require(Shared.Data.Rooms)
	local Dumbwaiter = require(Shared.Logic.Dumbwaiter)
	local FloorPlan = require(Shared.Logic.FloorPlan)
	local HouseSize = require(Shared.Logic.HouseSize)
	local MansionGen = require(Shared.Logic.MansionGen)
	local MansionHouse = require(Shared.Logic.MansionHouse)

	local cfg = Config.Mansion.Chute

	test("the chute: laundry below, a bathroom or a room upstairs above, on a wall they share or a trapdoor", function()
		local with, houses = 0, 0
		for _, squad in { 1, 4 } do
			local mansion = HouseSize.config(Config.Mansion, Config.Progression, squad)
			for seed = 1, 30 do
				local layout = MansionGen.generate(seed * 23 + squad, Rooms.Mansion, mansion)
				if not layout.fallback then
					houses += 1
					-- (The plan printer takes either kind of chute.)
					check.truthy(#FloorPlan.render(layout, mansion) > 0, "the plan prints")
					local chute = layout.chute
					if chute then
						with += 1
						local where = ("squad %d seed %d"):format(squad, seed)
						local ground, upper = layout.rooms[chute.ground], layout.rooms[chute.upper]
						check.equal(ground.template, "laundry", where .. ": the laundry below")
						check.equal(ground.floor or 0, 0, where)
						check.equal(upper.floor, 1, where .. ": upstairs")
						check.truthy(not upper.tall, where)
						check.truthy(
							cfg.Uppers[MansionHouse.zoneOf(upper, 1)] ~= nil,
							where .. ": a bathroom or a room"
						)
						if chute.floor then
							-- A trapdoor: inside both rooms, clear of their furniture.
							for _, room in { ground, upper } do
								check.truthy(
									chute.x >= room.x + cfg.FloorMargin
										and chute.x <= room.x + room.w - cfg.FloorMargin
										and chute.z >= room.z + cfg.FloorMargin
										and chute.z <= room.z + room.d - cfg.FloorMargin,
									where .. ": the trapdoor is inside room " .. room.id
								)
								for _, b in Dumbwaiter.furniture(layout, room, Rooms.MansionById, cfg.Wall) do
									local half = cfg.Width / 2
									check.truthy(
										not (
												chute.x - half < b.x1
												and b.x0 < chute.x + half
												and chute.z - half < b.z1
												and b.z0 < chute.z + half
											),
										where .. ": the trapdoor is clear of furniture"
									)
								end
							end
						else
							-- On their wall: a spot the rooms' furniture leaves clear.
							local found = false
							for _, spot in Dumbwaiter.spots(layout, ground, upper, cfg, Rooms.MansionById) do
								if spot.x == chute.x and spot.z == chute.z and spot.side == chute.side then
									found = true
								end
							end
							check.truthy(found, where .. ": the spot is clear")
						end
						for _, pair in Dumbwaiter.pairs(layout, Config.Dumbwaiter, Rooms.MansionById) do
							check.truthy(
								not (pair.ground == chute.ground and pair.upper == chute.upper),
								where .. ": not the dumbwaiter's too"
							)
						end
					end
				end
			end
		end
		check.truthy(with >= houses * 0.5, ("%d of %d houses have a chute"):format(with, houses))
	end)
end
