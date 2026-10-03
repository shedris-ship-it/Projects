-- Primary tools picked in the briefing (doc section 6). Each gives different
-- information, so nobody can solve a run alone.

local Tools = {
	{
		id = "Camera",
		name = "Witness Camera",
		description = "Photograph the true state of one object. Film is scarce: 6 shots (8 when you play alone).",
		role = "Photographer",
		color = { 230, 220, 190 },
	},
	{
		id = "Lantern",
		name = "Lantern",
		description = "A wide light. Lights Lantern shrines fast, making a safe room that recharges Focus.",
		role = "Lightkeeper",
		color = { 255, 196, 110 },
	},
	{
		id = "Radio",
		name = "Radio",
		description = "Static rises as it gets closer. Your pings carry through walls.",
		role = "Operator",
		color = { 150, 200, 170 },
	},
	{
		id = "PlumbLine",
		name = "Plumb Line",
		description = "Once two tells are confirmed, points roughly at the Source. Two lines triangulate it.",
		role = "Surveyor",
		color = { 170, 170, 230 },
	},
}

local byId = {}
for _, tool in Tools do
	byId[tool.id] = tool
end

return {
	List = Tools,
	ById = byId,
	Default = "Camera",
}
