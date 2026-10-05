-- Contracts (doc: location fixed per contract; the house and its locks vary
-- per run).
-- Only The Halfway House is built for the vertical slice; St. Odile Ward is
-- listed so the hub can show what is coming next.

local Locations = {
	{
		id = "HalfwayHouse",
		name = "The Halfway House",
		blurb = "A family house that locks you in and lays a place for its guest.",
		stalker = "TheGuest",
		templates = "Rooms", -- Data module holding this location's room templates
		available = true,
		ambient = {
			fogColor = { 18, 16, 20 },
			fogEnd = 140,
		},
	},
	{
		id = "StOdileWard",
		name = "St. Odile Ward",
		blurb = "An abandoned hospital wing. Coming in the alpha.",
		stalker = "TheOrderly",
		templates = "Rooms",
		available = false,
	},
}

local byId = {}
for _, location in Locations do
	byId[location.id] = location
end

return {
	List = Locations,
	ById = byId,
	Default = "HalfwayHouse",
}
