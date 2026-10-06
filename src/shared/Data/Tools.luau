-- Tools found around the house (doc section 6; owner, 2026-10-04: no more
-- picking one in the hub). `homes` are the furniture kinds (Data/Props) it
-- makes sense to find one on; Logic/ToolPlacement picks among them, from the
-- seed. (The Witness Camera and the Plumb Line retired with the clue loop.)

local Tools = {
	{
		id = "Lantern",
		name = "Lantern",
		description = "A wide light. Lights Lantern shrines fast, making a safe room he can't start a hunt in.",
		role = "Lightkeeper",
		color = { 255, 196, 110 },
		homes = { "Workbench", "Counter", "Bench", "Table" },
	},
	{
		id = "Radio",
		name = "Radio",
		description = "Static rises as it gets closer. Your pings carry through walls.",
		role = "Operator",
		color = { 150, 200, 170 },
		homes = { "Dresser", "Counter", "Piano", "Table" },
	},
	-- Tools that open tool locks (docs/plans/level-design.md section 11,
	-- L3.3): the escape plan puts them where they're found (`planned`), not
	-- the random supply above. Carry one and work the lock it opens.
	{
		id = "Crowbar",
		name = "Crowbar",
		description = "Pries the boards off a boarded door, one by one. Loud: keep a lookout.",
		color = { 150, 60, 50 },
		homes = { "Workbench", "Counter", "Table", "Desk" },
		planned = true,
	},
	{
		id = "BoltCutters",
		name = "Bolt cutters",
		description = "Cuts the chain on a chained door in one loud snap.",
		color = { 200, 120, 40 },
		homes = { "Workbench", "Counter", "Table", "Desk" },
		planned = true,
	},
	-- A second wind (docs/progress/2026-10-07-loop/REPORT.md, WP2): spent
	-- the moment you go down, you come round a few seconds later. Found in
	-- the safe room (Data/SafeRoom) or a keepsake box in a solo run
	-- (Config.Solo.SaltsChance), never lying about at random (`special`).
	{
		id = "Salts",
		name = "Smelling salts",
		description = "Spent the moment you go down: you come round a few seconds later. One use.",
		color = { 120, 80, 40 },
		homes = {},
		special = true,
	},
}

local byId = {}
for _, tool in Tools do
	byId[tool.id] = tool
end

-- The ids in list order, and each tool's homes by id, for Logic/ToolPlacement.
-- `Supply` is what the house leaves lying about at random; the planned ones
-- (the crowbar, the bolt cutters) go where the escape plan says.
local ids, supply, homes = {}, {}, {}
for _, tool in Tools do
	table.insert(ids, tool.id)
	if not tool.planned and not tool.special then
		table.insert(supply, tool.id)
	end
	homes[tool.id] = tool.homes
end

return {
	List = Tools,
	ById = byId,
	Ids = ids,
	Supply = supply,
	Homes = homes,
}
