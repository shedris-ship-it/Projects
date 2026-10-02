-- Contracts (doc: location fixed per contract, anomaly varies per run).
-- Only The Halfway House is built for the vertical slice; St. Odile Ward is
-- listed so the hub can show what is coming next.

local Locations = {
	{
		id = "HalfwayHouse",
		name = "The Halfway House",
		blurb = "A suburban home that can't decide what it looks like.",
		stalker = "TheGuest",
		templates = "Rooms", -- Data module holding this location's room templates
		anomalies = { "PhantomArchitecture", "Counterfeit", "Gaze" },
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
		anomalies = { "PhantomArchitecture", "Counterfeit", "Gaze" },
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
