-- Tools found around the house (doc section 6; owner, 2026-10-04: no more
-- picking one in the hub). Each gives different information, so nobody can
-- solve a run alone. `homes` are the furniture kinds (Data/Props) it makes
-- sense to find one on; Logic/ToolPlacement picks among them, from the seed.

local Tools = {
	{
		id = "Camera",
		name = "Witness Camera",
		description = "Photograph the true state of one object. Film is scarce: 6 shots (8 when you play alone). Found on a desk or dresser.",
		role = "Photographer",
		color = { 230, 220, 190 },
		homes = { "Desk", "Dresser", "Table", "Bench" },
	},
	{
		id = "Lantern",
		name = "Lantern",
		description = "A wide light. Lights Lantern shrines fast, making a safe room that recharges Focus.",
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
	{
		id = "PlumbLine",
		name = "Plumb Line",
		description = "Once two tells are confirmed, points roughly at the Source. Two lines triangulate it.",
		role = "Surveyor",
		color = { 170, 170, 230 },
		homes = { "Workbench", "Desk", "Chest" },
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
