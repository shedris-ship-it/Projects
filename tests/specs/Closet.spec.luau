-- The boutique's rules (LB3; Logic/Closet): what you own and wear, buying
-- with Marks, the fitting room's try-ons.
return function(test, check, Shared, require)
	local Closet = require(Shared.Logic.Closet)
	local Outfit = require(Shared.Logic.Outfit)
	local Profile = require(Shared.Logic.Profile)
	local Wardrobe = require(Shared.Data.Wardrobe)

	test("the free set is everyone's; the paid line is nobody's until bought", function()
		local data = Profile.new()
		for id, garment in Wardrobe.Garments do
			check.equal(Closet.owns(data, id), garment.free == true, id)
			check.equal(Closet.price(id) ~= nil, not garment.free, id .. "'s price")
		end
		check.equal(Closet.owns(data, "NoSuchCoat"), false, "an unknown garment")
	end)

	test("buying spends the price once, and never what you don't have", function()
		local data = Profile.new()
		data.Marks = 600
		local ok, why = Closet.buy(data, "Biker")
		check.truthy(not ok and why == "marks", "2,000 Marks is more than 600")
		check.equal(data.Marks, 600, "nothing spent")
		ok = Closet.buy(data, "HighTop")
		check.truthy(ok, "the cheap first rung")
		check.equal(data.Marks, 600 - Closet.price("HighTop"), "its price spent")
		check.truthy(Closet.owns(data, "HighTop"), "owned")
		ok, why = Closet.buy(data, "HighTop")
		check.truthy(not ok and why == "owned", "not twice")
		ok, why = Closet.buy(data, "Flannel")
		check.truthy(not ok and why == "free", "the free set isn't sold")
		ok, why = Closet.buy(data, "NoSuchCoat")
		check.truthy(not ok and why == "unknown", "nor what isn't there")
	end)

	test("the plan's prices: shoes the cheap first rung, the biker jacket the dearest", function()
		local cheapest, dearest = math.huge, 0
		for id, garment in Wardrobe.Garments do
			if not garment.free then
				local price = Closet.price(id) :: number
				check.truthy(price >= 500 and price <= 2000, id .. " in the plan's range")
				cheapest = math.min(cheapest, price)
				dearest = math.max(dearest, price)
			end
		end
		check.equal(Closet.price("HighTop"), cheapest, "high-tops cheapest")
		check.equal(Closet.price("Biker"), dearest, "the biker jacket dearest")
	end)

	test("you wear what you own and chose; a slot you haven't chosen is your squad slot's", function()
		local data = Profile.new()
		check.equal(Closet.outfit(data, 2).Top, Outfit.wear(2).Top, "a new player: the squad's look")
		local ok, why = Closet.wear(data, "Biker")
		check.truthy(not ok and why == "notOwned", "not before it's bought")
		Closet.give(data, "Biker")
		check.truthy(Closet.wear(data, "Biker"), "bought: worn")
		local outfit = Closet.outfit(data, 2)
		check.equal(outfit.Top, "Biker", "the jacket")
		check.equal(outfit.Bottom, Outfit.wear(2).Bottom, "the rest still the squad's")
		-- (A choice that's no longer yours falls back to the squad's.)
		data.Owned.garment.Biker = nil
		check.equal(Closet.outfit(data, 2).Top, Outfit.wear(2).Top, "taken back")
		data.Wearing.Top = "Jeans"
		check.equal(Closet.outfit(data, 2).Top, Outfit.wear(2).Top, "never a garment in the wrong slot")
	end)

	test("the fitting room tries anything on; only what's yours leaves on you", function()
		local data = Profile.new()
		local outfit = Closet.outfit(data, 1)
		local tried = Closet.try(outfit, "Parachute")
		check.equal(tried.Bottom, "Parachute", "tried on")
		check.equal(outfit.Bottom, Outfit.wear(1).Bottom, "the outfit it came from untouched")
		check.truthy(not Closet.ownsAll(data, tried), "not yours yet")
		Closet.give(data, "Parachute")
		check.truthy(Closet.ownsAll(data, tried), "bought")
	end)

	test("each slot flips through its own garments, the free set first, round and round", function()
		for _, slot in Wardrobe.Slots do
			local list = Closet.slotList(slot)
			check.truthy(#list >= 2, slot .. " has a choice")
			local seenPaid = false
			for _, id in list do
				check.equal(Wardrobe.Garments[id].slot, slot, id .. " in " .. slot)
				if Wardrobe.Garments[id].free then
					check.truthy(not seenPaid, slot .. ": the free set first")
				else
					seenPaid = true
				end
			end
			check.equal(Closet.step(slot, list[#list], 1), list[1], slot .. " wraps forward")
			check.equal(Closet.step(slot, list[1], -1), list[#list], slot .. " wraps back")
		end
		local counted = 0
		for _ in Wardrobe.Garments do
			counted += 1
		end
		check.equal(#Wardrobe.Order, counted, "the booth's order lists every garment")
	end)
end
