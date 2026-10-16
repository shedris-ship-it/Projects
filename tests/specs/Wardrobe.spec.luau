return function(test, check, Shared, require)
	local Wardrobe = require(Shared.Data.Wardrobe)
	local KitWear = require(Shared.Data.KitWear)
	local Outfit = require(Shared.Logic.Outfit)

	local PARTS = { "Torso", "LeftArm", "RightArm", "LeftLeg", "RightLeg" }
	local R15 = {
		UpperTorso = true,
		LowerTorso = true,
		LeftUpperArm = true,
		RightUpperArm = true,
		LeftLowerArm = true,
		RightLowerArm = true,
		LeftUpperLeg = true,
		RightUpperLeg = true,
		LeftLowerLeg = true,
		RightLowerLeg = true,
		LeftFoot = true,
		RightFoot = true,
	}

	test("every body names all five of its parts with a real asset id", function()
		for key, body in Wardrobe.Bodies do
			check.truthy(type(body.name) == "string" and body.name ~= "", key .. " has a name")
			for _, part in PARTS do
				local id = body.parts[part]
				check.truthy(type(id) == "number" and id > 0 and id % 1 == 0, key .. " " .. part)
			end
		end
	end)

	test("the choice's order lists each body once, and the default is one of them", function()
		local seen = {}
		for _, key in Wardrobe.BodyOrder do
			check.truthy(Wardrobe.Bodies[key] ~= nil, key .. " is a body")
			check.equal(seen[key], nil, key .. " listed once")
			seen[key] = true
		end
		for key in Wardrobe.Bodies do
			check.truthy(seen[key], key .. " can be chosen")
		end
		check.truthy(Wardrobe.Bodies[Wardrobe.DefaultBody] ~= nil, "the default body")
	end)

	test("every garment is a top, a bottom or shoes, dressing real body parts", function()
		local slots = {}
		for _, slot in Wardrobe.Slots do
			slots[slot] = true
		end
		for id, garment in Wardrobe.Garments do
			check.truthy(slots[garment.slot], id .. "'s slot")
			check.truthy(type(garment.name) == "string" and garment.name ~= "", id .. " has a name")
			local count = 0
			for part, mesh in garment.pieces do
				check.truthy(R15[part], id .. " dresses " .. part)
				check.truthy(type(mesh) == "string" and mesh ~= "", id .. "'s mesh on " .. part)
				count += 1
			end
			check.truthy(count >= 2, id .. " has its pieces")
		end
	end)

	test("a top covers the torso and both arms, a bottom the hips and legs, shoes both feet", function()
		local need = {
			Top = { "UpperTorso", "LeftUpperArm", "RightUpperArm", "LeftLowerArm", "RightLowerArm" },
			Bottom = { "LowerTorso", "LeftUpperLeg", "RightUpperLeg", "LeftLowerLeg", "RightLowerLeg" },
			Shoes = { "LeftFoot", "RightFoot" },
		}
		for id, garment in Wardrobe.Garments do
			for _, part in need[garment.slot] do
				-- (Short sleeves leave the forearms bare.)
				local bare = garment.short and (part == "LeftLowerArm" or part == "RightLowerArm")
				check.equal(garment.pieces[part] ~= nil, not bare, id .. " on " .. part)
			end
		end
	end)

	test("the boutique (LB3): the eight free, the rest priced, painted till their meshes are in", function()
		local free = 0
		for id, garment in Wardrobe.Garments do
			if garment.free then
				free += 1
				check.equal(garment.price, nil, id .. " isn't sold")
			else
				check.truthy(type(garment.price) == "number" and garment.price > 0, id .. " has a price")
				check.truthy(type(garment.paint) == "table" and #garment.paint == 3, id .. " has a colour to paint")
			end
			check.truthy(not garment.over or garment.slot == "Shoes", id .. ": only shoes go over the hems")
			check.truthy(not garment.short or garment.slot == "Top", id .. ": only tops are short-sleeved")
		end
		check.equal(free, 8, "today's eight are the free set")
		for _, look in Wardrobe.Outfits do
			for _, slot in Wardrobe.Slots do
				check.truthy(Wardrobe.Garments[look[slot]].free, "the squad's looks are all free")
			end
		end
	end)

	test("the squad's outfits name real garments in the right slots, the first four tops all different", function()
		local tops = {}
		for i, look in Wardrobe.Outfits do
			for _, slot in Wardrobe.Slots do
				local garment = Wardrobe.Garments[look[slot]]
				check.truthy(garment ~= nil and garment.slot == slot, "outfit " .. i .. "'s " .. slot)
			end
			if i <= 4 then
				check.equal(tops[look.Top], nil, "outfit " .. i .. "'s top is its own")
				tops[look.Top] = true
			end
		end
	end)

	test("every garment's piece has its fit (Data/KitWear), built for the part and side it's worn on", function()
		for id, garment in Wardrobe.Garments do
			for bodyPart, mesh in garment.pieces do
				local fit = KitWear.Wear[mesh]
				check.truthy(fit ~= nil, id .. "'s " .. mesh .. " is built")
				if fit then
					local side = string.match(bodyPart, "^Left") and "L"
						or string.match(bodyPart, "^Right") and "R"
						or nil
					local part = string.gsub(bodyPart, "^Left", "")
					part = string.gsub(part, "^Right", "")
					check.equal(fit.part, part, mesh .. "'s part")
					if side then
						check.equal(fit.side, side, mesh .. "'s side")
					end
					for axis = 1, 3 do
						check.truthy(fit.size[axis] > 0 and fit.base[axis] > 0, mesh .. "'s sizes")
						-- (A piece is a little bigger than its part, never far off it.)
						check.truthy(fit.size[axis] < fit.base[axis] * 2 + 0.5, mesh .. " fits its part")
					end
				end
			end
		end
	end)

	test("Outfit.wear hands every squad member an outfit, in turn", function()
		check.equal(Outfit.wear(1), Wardrobe.Outfits[1], "the first")
		check.equal(Outfit.wear(2), Wardrobe.Outfits[2], "the second")
		check.equal(Outfit.wear(#Wardrobe.Outfits + 1), Wardrobe.Outfits[1], "wraps")
		check.equal(Outfit.wear(0), Wardrobe.Outfits[1], "a nonsense slot")
	end)
end
