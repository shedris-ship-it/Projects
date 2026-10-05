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
}

local byId = {}
for _, tool in Tools do
	byId[tool.id] = tool
end

-- The ids in list order, and each tool's homes by id, for Logic/ToolPlacement.
local ids, homes = {}, {}
for _, tool in Tools do
	table.insert(ids, tool.id)
	homes[tool.id] = tool.homes
end

return {
	List = Tools,
	ById = byId,
	Ids = ids,
	Homes = homes,
}
