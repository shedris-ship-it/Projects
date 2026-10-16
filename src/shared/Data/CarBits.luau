-- The party cars' bits (LB4; docs/plans/lobby-rework.md, "The garage"): the
-- pegboard sells them for Marks (Services/ShopService), and a car shows its
-- driver's while they drive it, to the whole lobby (Services/CarService,
-- World/CarDress). The windows are dark glass with nothing behind, so every
-- bit is on the outside. Claude's proposal, kept by the owner for now
-- ("I'll go with your suggestions for now", 2026-10-16).
--
-- Kinds: a paint (one at a time; maroon is everyone's), bits (fit any
-- number), a radio station (one at a time, while you're in your car; off is
-- everyone's). Prices in Marks.

return {
	Paints = {
		Maroon = { name = "Maroon", color = { 96, 42, 36 }, free = true },
		Cream = { name = "Cream", color = { 222, 208, 172 }, price = 600 },
		SkyBlue = { name = "Sky blue", color = { 112, 152, 184 }, price = 600 },
		ForestGreen = { name = "Forest green", color = { 42, 74, 54 }, price = 600 },
		Black = { name = "Black", color = { 24, 24, 26 }, price = 600 },
	},
	PaintOrder = { "Maroon", "Cream", "SkyBlue", "ForestGreen", "Black" },
	Bits = {
		-- (Every car had woodgrain sides until LB4: now a bit, the free car plain.)
		Woodgrain = { name = "Woodgrain sides", price = 400 },
		Whitewalls = { name = "Whitewall tyres", price = 400 },
		RoofRack = { name = "Roof rack and luggage", price = 800 },
		Spotlight = { name = "Spotlight and CB aerial", price = 1000 },
		Sticker = { name = "Bumper sticker", price = 300, text = "I BRAKE FOR GHOSTS" },
	},
	BitOrder = { "Woodgrain", "Whitewalls", "RoofRack", "Spotlight", "Sticker" },
	-- What plays in your car while you're in it (Assets.Mall.Stations, picked
	-- by ear). (No talk station: the libraries have no talk radio that's
	-- free to use, so the third is static between stations.)
	Radio = {
		Off = { name = "Radio off", free = true },
		Hits = { name = "WKND 104, the hits", price = 300 },
		Oldies = { name = "Gold 98, the oldies", price = 300 },
		Night = { name = "Night 1210, between stations", price = 300 },
	},
	RadioOrder = { "Off", "Hits", "Oldies", "Night" },
}
