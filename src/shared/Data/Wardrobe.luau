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
--
-- Hair and faces (2026-10-17; docs/progress/2026-10-17-hair-faces/): three
-- more slots in the same wardrobe, bought and worn the same way. Hair is
-- eight styles modelled in Blender (tools/blender/hair.py), each a piece on
-- the Head (Data/KitHair its fit); a ponytail's scrunchie is a piece of its
-- own (`tie`), so the hair's colour never reaches it. Colour: the hair's,
-- nine natural shades, all free (`colour`, what it should look like; the
-- game tints the grey map to it, Logic/Closet.hairTint). Face: six of
-- Roblox's free dynamic heads (`head`, the head's asset id), all with the
-- classic head's shape, so every style fits every face; they blink and move
-- with voice chat by themselves, and react in a run (Controllers/
-- FaceController). A face changes only the head: the Boy and Girl bodies
-- stay for every garment (the owner, 2026-10-17).

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

		-- Hair: four free, four for Marks (the owner, 2026-10-17).
		Crew = { slot = "Hair", name = "Crew cut", pieces = { Head = "HairCrew" }, free = true },
		SidePart = { slot = "Hair", name = "Side part", pieces = { Head = "HairSidePart" }, free = true },
		Shoulder = { slot = "Hair", name = "Shoulder length", pieces = { Head = "HairShoulder" }, free = true },
		Ponytail = {
			slot = "Hair",
			name = "High ponytail",
			pieces = { Head = "HairPonytail" },
			tie = "HairPonytailScrunchie",
			free = true,
		},
		Feathered = { slot = "Hair", name = "Feathered flip", pieces = { Head = "HairFeathered" }, price = 800 },
		SidePony = {
			slot = "Hair",
			name = "Side ponytail",
			pieces = { Head = "HairSidePony" },
			tie = "HairSidePonyScrunchie",
			price = 1000,
		},
		Mullet = { slot = "Hair", name = "Mullet", pieces = { Head = "HairMullet" }, price = 1500 },
		Perm = { slot = "Hair", name = "Big perm", pieces = { Head = "HairPerm" }, price = 2000 },

		-- The hair's colour (sRGB): natural 1988 shades, all free.
		HairBlack = { slot = "Colour", name = "Black", colour = { 30, 26, 24 }, pieces = {}, free = true },
		HairDarkBrown = { slot = "Colour", name = "Dark brown", colour = { 62, 42, 30 }, pieces = {}, free = true },
		HairChestnut = { slot = "Colour", name = "Chestnut", colour = { 104, 64, 40 }, pieces = {}, free = true },
		HairAuburn = { slot = "Colour", name = "Auburn", colour = { 128, 54, 32 }, pieces = {}, free = true },
		HairGinger = { slot = "Colour", name = "Ginger", colour = { 176, 90, 44 }, pieces = {}, free = true },
		HairDirtyBlonde = {
			slot = "Colour",
			name = "Dirty blonde",
			colour = { 156, 124, 80 },
			pieces = {},
			free = true,
		},
		HairGoldenBlonde = {
			slot = "Colour",
			name = "Golden blonde",
			colour = { 212, 170, 104 },
			pieces = {},
			free = true,
		},
		HairPlatinum = { slot = "Colour", name = "Platinum", colour = { 232, 222, 196 }, pieces = {}, free = true },
		HairGrey = { slot = "Colour", name = "Grey", colour = { 156, 154, 150 }, pieces = {}, free = true },

		-- Faces: Roblox's free dynamic heads (their head asset ids), all free.
		Dennis = { slot = "Face", name = "Dennis", head = 11822635053, pieces = {}, free = true },
		Kenneth = { slot = "Face", name = "Kenneth", head = 15093144795, pieces = {}, free = true },
		ManFace = { slot = "Face", name = "Man Face", head = 10725826963, pieces = {}, free = true },
		Lindsey = { slot = "Face", name = "Lindsey", head = 12945228337, pieces = {}, free = true },
		Cindy = { slot = "Face", name = "Cindy", head = 13253943097, pieces = {}, free = true },
		WomanFace = { slot = "Face", name = "Woman Face", head = 10725626210, pieces = {}, free = true },
	},
	-- Every slot the fitting room flips through (Logic/Closet); Clothes are the
	-- ones worn on the body's parts, which the squad's outfits fill.
	Slots = { "Top", "Bottom", "Shoes", "Hair", "Colour", "Face" },
	Clothes = { "Top", "Bottom", "Shoes" },
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
		"Crew",
		"SidePart",
		"Shoulder",
		"Ponytail",
		"Feathered",
		"SidePony",
		"Mullet",
		"Perm",
		"HairBlack",
		"HairDarkBrown",
		"HairChestnut",
		"HairAuburn",
		"HairGinger",
		"HairDirtyBlonde",
		"HairGoldenBlonde",
		"HairPlatinum",
		"HairGrey",
		"Dennis",
		"Kenneth",
		"ManFace",
		"Lindsey",
		"Cindy",
		"WomanFace",
	},

	-- The squad's looks by the order they arrived (Logic/Outfit.wear): the
	-- first four all different at a glance.
	Outfits = {
		{ Top = "Flannel", Bottom = "Jeans", Shoes = "Sneaker" },
		{ Top = "Varsity", Bottom = "Jeans", Shoes = "Sneaker" },
		{ Top = "Windbreaker", Bottom = "Cords", Shoes = "Sneaker" },
		{ Top = "Cardigan", Bottom = "Cords", Shoes = "Loafer" },
	},
	-- Their hair and faces by body (Logic/Outfit.look), in the same turn: the
	-- free styles, faces and colours, the four all different.
	Looks = {
		Boy = {
			{ Hair = "SidePart", Colour = "HairDarkBrown", Face = "Dennis" },
			{ Hair = "Crew", Colour = "HairBlack", Face = "Kenneth" },
			{ Hair = "Shoulder", Colour = "HairDirtyBlonde", Face = "ManFace" },
			{ Hair = "Crew", Colour = "HairChestnut", Face = "Dennis" },
		},
		Girl = {
			{ Hair = "Shoulder", Colour = "HairGoldenBlonde", Face = "Lindsey" },
			{ Hair = "Ponytail", Colour = "HairChestnut", Face = "Cindy" },
			{ Hair = "Shoulder", Colour = "HairBlack", Face = "WomanFace" },
			{ Hair = "Ponytail", Colour = "HairAuburn", Face = "Lindsey" },
		},
	},
}
