-- Regional pricing and gifts (Logic/PriceLevels): a gift goes only from a
-- price level at least the friend's.
return function(test, check, Shared, require)
	local PriceLevels = require(Shared.Logic.PriceLevels)

	test("a gift goes from a level at least the friend's, never up", function()
		check.truthy(PriceLevels.canGift(1000, 1000), "full price to full price")
		check.truthy(PriceLevels.canGift(1000, 400), "full price to a cheaper country")
		check.truthy(PriceLevels.canGift(400, 400), "the same level")
		local ok, why = PriceLevels.canGift(400, 1000)
		check.truthy(not ok, "a cheaper country can't gift to a dearer one")
		check.equal(why, "region", "and says why")
	end)

	test("a level not known yet refuses the gift", function()
		local ok, why = PriceLevels.canGift(nil, 1000)
		check.truthy(not ok, "the buyer's unknown")
		check.equal(why, "unknown", "and says so")
		check.truthy(not PriceLevels.canGift(1000, nil), "the friend's unknown")
	end)

	test("Roblox's answer is read by user, anything malformed left out", function()
		local levels = PriceLevels.read({
			{ UserId = 1, PriceLevel = 1000 },
			{ UserId = 2, PriceLevel = 350 },
			{ UserId = 3, PriceLevel = 5000 },
			{ UserId = "4", PriceLevel = 10 },
			"junk",
		})
		check.equal(levels[1], 1000, "a full-price player")
		check.equal(levels[2], 350, "a cheaper one")
		check.equal(levels[3], 1000, "clamped")
		check.equal(levels["4"], nil, "a bad id left out")
		check.equal(next(PriceLevels.read(nil)), nil, "nothing from nothing")
	end)
end
