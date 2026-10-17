return function(test, check, Shared, require)
	local Wardrobe = require(Shared.Data.Wardrobe)
	local KitHair = require(Shared.Data.KitHair)
	local KitWear = require(Shared.Data.KitWear)
	local Outfit = require(Shared.Logic.Outfit)

	local CLOTHES = {}
	for _, slot in Wardrobe.Clothes do
		CLOTHES[slot] = true
	end

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

	test("every garment is clothes, hair, a hair colour or a face, each as its slot needs", function()
		local slots = {}
		for _, slot in Wardrobe.Slots do
			slots[slot] = true
		end
		for _, slot in Wardrobe.Clothes do
			check.truthy(slots[slot], slot .. " is a slot")
		end
		for id, garment in Wardrobe.Garments do
			check.truthy(slots[garment.slot], id .. "'s slot")
			check.truthy(type(garment.name) == "string" and garment.name ~= "", id .. " has a name")
			local count = 0
			for part, mesh in garment.pieces do
				check.truthy(type(mesh) == "string" and mesh ~= "", id .. "'s mesh on " .. part)
				if CLOTHES[garment.slot] then
					check.truthy(R15[part], id .. " dresses " .. part)
				else
					check.equal(part, "Head", id .. " is worn on the head")
				end
				count += 1
			end
			if CLOTHES[garment.slot] then
				check.truthy(count >= 2, id .. " has its pieces")
			elseif garment.slot == "Hair" then
				check.equal(count, 1, id .. " is one piece (and maybe its tie)")
			else
				check.equal(count, 0, id .. " has no pieces")
			end
			check.truthy(garment.tie == nil or garment.slot == "Hair", id .. ": only hair has a tie")
			if garment.slot == "Colour" then
				local c = garment.colour
				check.truthy(type(c) == "table" and #c == 3, id .. " is a colour")
				for i = 1, 3 do
					check.truthy(c[i] >= 0 and c[i] <= 255, id .. "'s channel " .. i)
				end
			end
			if garment.slot == "Face" then
				check.truthy(
					type(garment.head) == "number" and garment.head > 0 and garment.head % 1 == 0,
					id .. "'s head id"
				)
			end
		end
	end)

	test("a top covers the torso and both arms, a bottom the hips and legs, shoes both feet", function()
		local need = {
			Top = { "UpperTorso", "LeftUpperArm", "RightUpperArm", "LeftLowerArm", "RightLowerArm" },
			Bottom = { "LowerTorso", "LeftUpperLeg", "RightUpperLeg", "LeftLowerLeg", "RightLowerLeg" },
			Shoes = { "LeftFoot", "RightFoot" },
		}
		for id, garment in Wardrobe.Garments do
			for _, part in need[garment.slot] or {} do
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
				check.equal(garment.price, nil, id .. " isn't sold")
				if CLOTHES[garment.slot] then
					free += 1
				end
			else
				check.truthy(type(garment.price) == "number" and garment.price > 0, id .. " has a price")
				if CLOTHES[garment.slot] then
					check.truthy(type(garment.paint) == "table" and #garment.paint == 3, id .. " has a colour to paint")
				end
			end
			check.truthy(not garment.over or garment.slot == "Shoes", id .. ": only shoes go over the hems")
			check.truthy(not garment.short or garment.slot == "Top", id .. ": only tops are short-sleeved")
		end
		check.equal(free, 8, "today's eight clothes are the free set")
		for _, look in Wardrobe.Outfits do
			for _, slot in Wardrobe.Clothes do
				check.truthy(Wardrobe.Garments[look[slot]].free, "the squad's looks are all free")
			end
		end
	end)

	test("hair and faces (2026-10-17): the owner's list and prices, every face and colour free", function()
		local prices = { Feathered = 800, SidePony = 1000, Mullet = 1500, Perm = 2000 }
		local count = { Hair = 0, Colour = 0, Face = 0 }
		local heads = {}
		for id, garment in Wardrobe.Garments do
			if count[garment.slot] then
				count[garment.slot] += 1
			end
			if garment.slot == "Hair" then
				if prices[id] then
					check.equal(garment.price, prices[id], id .. "'s price")
				else
					check.truthy(garment.free, id .. " is one of the four free")
				end
			elseif garment.slot == "Colour" or garment.slot == "Face" then
				check.truthy(garment.free, id .. " is everyone's")
			end
			if garment.slot == "Face" then
				check.equal(heads[garment.head], nil, id .. "'s head is its own")
				heads[garment.head] = true
			end
		end
		check.equal(count.Hair, 8, "eight styles")
		check.equal(count.Colour, 9, "nine colours")
		check.equal(count.Face, 6, "six faces")
	end)

	test("each body's squad looks: free hair, colours and faces, the four all different", function()
		for _, body in Wardrobe.BodyOrder do
			local looks = Wardrobe.Looks[body]
			check.truthy(looks ~= nil and #looks >= 4, body .. " has its looks")
			local seen = {}
			for i, look in looks do
				for _, slot in { "Hair", "Colour", "Face" } do
					local garment = Wardrobe.Garments[look[slot]]
					check.truthy(
						garment ~= nil and garment.slot == slot and garment.free,
						body .. " look " .. i .. "'s " .. slot
					)
				end
				local key = look.Hair .. "/" .. look.Colour .. "/" .. look.Face
				check.equal(seen[key], nil, body .. " look " .. i .. " is its own")
				seen[key] = true
			end
		end
		check.equal(Outfit.look(1, "Girl"), Wardrobe.Looks.Girl[1], "the Girl's first")
		check.equal(Outfit.look(5, "Boy"), Wardrobe.Looks.Boy[1], "wraps")
		check.equal(Outfit.look(1, nil), Wardrobe.Looks[Wardrobe.DefaultBody][1], "no body: the default's")
	end)

	test("the squad's outfits name real garments in the right slots, the first four tops all different", function()
		local tops = {}
		for i, look in Wardrobe.Outfits do
			for _, slot in Wardrobe.Clothes do
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
			local pieces = table.clone(garment.pieces)
			if garment.tie then
				pieces.Tie = garment.tie
			end
			for bodyPart, mesh in pieces do
				if bodyPart == "Tie" then
					bodyPart = "Head"
				end
				local fit = KitWear.Wear[mesh] or KitHair.Wear[mesh]
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
