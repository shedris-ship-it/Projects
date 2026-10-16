-- What the squad wears (the visual rework V6; docs/progress/2026-10-14-visual-v6/).
-- Everyone is a standard Roblox body in 1980s clothes (the owner, 2026-10-12:
-- "standard bodies" with modular 80s clothing, built so a clothing shop in
-- the lobby can sell from this list later; no prices yet).
--
-- Bodies: the two classic Roblox bodies (the owner's pick, 2026-10-14), chosen
-- at first play and in Settings (`body`). Their parts are Roblox's free
-- bundles (ROBLOX Boy 109, ROBLOX Girl 108).
--
-- Garments: 3D clothes modelled in Blender (tools/blender/wardrobe.py), one
-- fitted piece on each body part a garment covers, so each turns with its
-- part as the body does (Services/OutfitService, World/Kit.wear). Every
-- piece is built round both bodies' measured shapes, and each layer over the
-- layers under it, so nothing comes through (the owner, 2026-10-15). A
-- garment is a top, a bottom or shoes; `pieces` says which mesh goes on which
-- body part (Data/KitWear has each mesh's fit, Data/Kit its id).
--
-- The boutique (LB3, docs/plans/lobby-rework.md, "Boutique"): the first
-- eight are the free starter set everyone owns (`free`); the rest are sold
-- for Marks (`price`, Logic/Closet; the server's prices are these). `paint`
-- is the colour a garment is painted in while its meshes aren't in yet.
-- `short`: short sleeves, the forearms bare. `over`: shoes worn in place of
-- the trousers' shins (high-tops: the shaft rises into the trousers' foot,
-- so the shins' pieces are left off).

local function top(prefix, hem, short)
	local pieces = {
		UpperTorso = prefix .. "Torso",
		LeftUpperArm = prefix .. "UpperSleeveL",
		RightUpperArm = prefix .. "UpperSleeveR",
	}
	if not short then
		pieces.LeftLowerArm = prefix .. "LowerSleeveL"
		pieces.RightLowerArm = prefix .. "LowerSleeveR"
	end
	if hem then
		pieces.LowerTorso = prefix .. "Hem"
	end
	return pieces
end

local function bottom(prefix)
	return {
		LowerTorso = prefix .. "Waist",
		LeftUpperLeg = prefix .. "UpperLegL",
		RightUpperLeg = prefix .. "UpperLegR",
		LeftLowerLeg = prefix .. "LowerLegL",
		RightLowerLeg = prefix .. "LowerLegR",
	}
end

local function shoes(prefix)
	return { LeftFoot = prefix .. "L", RightFoot = prefix .. "R" }
end

return {
	Bodies = {
		Boy = {
			name = "Boy",
			bundle = 109,
			parts = {
				Torso = 376532000,
				LeftArm = 376530220,
				RightArm = 376531012,
				LeftLeg = 376531300,
				RightLeg = 376531703,
			},
		},
		Girl = {
			name = "Girl",
			bundle = 108,
			parts = {
				Torso = 376547767,
				LeftArm = 376547633,
				RightArm = 376547341,
				LeftLeg = 376546668,
				RightLeg = 376547092,
			},
		},
	},
	-- The order the Settings choice steps through.
	BodyOrder = { "Boy", "Girl" },
	DefaultBody = "Boy",

	Garments = {
		-- The free starter set (V6).
		Flannel = { slot = "Top", name = "Flannel shirt", pieces = top("Flannel", false), free = true },
		Cardigan = { slot = "Top", name = "Knit cardigan", pieces = top("Cardigan", true), free = true },
		Varsity = { slot = "Top", name = "Varsity jacket", pieces = top("Varsity", true), free = true },
		Windbreaker = { slot = "Top", name = "Windbreaker", pieces = top("Windbreaker", true), free = true },
		Jeans = { slot = "Bottom", name = "Stonewashed jeans", pieces = bottom("Jeans"), free = true },
		Cords = { slot = "Bottom", name = "Corduroys", pieces = bottom("Cords"), free = true },
		Sneaker = { slot = "Shoes", name = "Leather sneakers", pieces = shoes("Sneaker"), free = true },
		Loafer = { slot = "Shoes", name = "Penny loafers", pieces = shoes("Loafer"), free = true },
		-- The first paid line (the owner, 2026-10-15, from Claude's picks; the
		-- plan's prices: shoes the cheap first rung, the biker the one people
		-- want). The denim jacket comes in the starter pack (Data/Products).
		HighTop = {
			slot = "Shoes",
			name = "High-top sneakers",
			pieces = shoes("HighTop"),
			price = 500,
			over = true,
			paint = { 234, 230, 222 },
		},
		Ringer = {
			slot = "Top",
			name = "Ringer tee",
			pieces = top("Ringer", true, true),
			price = 800,
			short = true,
			paint = { 228, 222, 206 },
		},
		Parachute = {
			slot = "Bottom",
			name = "Parachute pants",
			pieces = bottom("Parachute"),
			price = 900,
			paint = { 150, 32, 38 },
		},
		Sweatshirt = {
			slot = "Top",
			name = "Colour-block sweatshirt",
			pieces = top("Sweatshirt", true),
			price = 1000,
			paint = { 34, 52, 118 },
		},
		DenimJacket = {
			slot = "Top",
			name = "Acid-wash denim jacket",
			pieces = top("DenimJacket", true),
			price = 1500,
			paint = { 150, 170, 204 },
		},
		Biker = {
			slot = "Top",
			name = "Leather biker jacket",
			pieces = top("Biker", true),
			price = 2000,
			paint = { 30, 28, 30 },
		},
	},
	Slots = { "Top", "Bottom", "Shoes" },
	-- The order the changing booth flips through each slot (Logic/Closet):
	-- the free set first, then the paid line, cheapest first.
	Order = {
		"Flannel",
		"Cardigan",
		"Varsity",
		"Windbreaker",
		"Ringer",
		"Sweatshirt",
		"DenimJacket",
		"Biker",
		"Jeans",
		"Cords",
		"Parachute",
		"Sneaker",
		"Loafer",
		"HighTop",
	},

	-- The squad's looks by the order they arrived (Logic/Outfit.wear): the
	-- first four all different at a glance.
	Outfits = {
		{ Top = "Flannel", Bottom = "Jeans", Shoes = "Sneaker" },
		{ Top = "Varsity", Bottom = "Jeans", Shoes = "Sneaker" },
		{ Top = "Windbreaker", Bottom = "Cords", Shoes = "Sneaker" },
		{ Top = "Cardigan", Bottom = "Cords", Shoes = "Loafer" },
	},
}
