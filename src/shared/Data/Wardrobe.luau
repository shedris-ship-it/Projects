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

local function top(prefix, hem)
	local pieces = {
		UpperTorso = prefix .. "Torso",
		LeftUpperArm = prefix .. "UpperSleeveL",
		RightUpperArm = prefix .. "UpperSleeveR",
		LeftLowerArm = prefix .. "LowerSleeveL",
		RightLowerArm = prefix .. "LowerSleeveR",
	}
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
		Flannel = { slot = "Top", name = "Flannel shirt", pieces = top("Flannel", false) },
		Cardigan = { slot = "Top", name = "Knit cardigan", pieces = top("Cardigan", true) },
		Varsity = { slot = "Top", name = "Varsity jacket", pieces = top("Varsity", true) },
		Windbreaker = { slot = "Top", name = "Windbreaker", pieces = top("Windbreaker", true) },
		Jeans = { slot = "Bottom", name = "Stonewashed jeans", pieces = bottom("Jeans") },
		Cords = { slot = "Bottom", name = "Corduroys", pieces = bottom("Cords") },
		Sneaker = { slot = "Shoes", name = "Leather sneakers", pieces = shoes("Sneaker") },
		Loafer = { slot = "Shoes", name = "Penny loafers", pieces = shoes("Loafer") },
	},
	Slots = { "Top", "Bottom", "Shoes" },

	-- The squad's looks by the order they arrived (Logic/Outfit.wear): the
	-- first four all different at a glance.
	Outfits = {
		{ Top = "Flannel", Bottom = "Jeans", Shoes = "Sneaker" },
		{ Top = "Varsity", Bottom = "Jeans", Shoes = "Sneaker" },
		{ Top = "Windbreaker", Bottom = "Cords", Shoes = "Sneaker" },
		{ Top = "Cardigan", Bottom = "Cords", Shoes = "Loafer" },
	},
}
