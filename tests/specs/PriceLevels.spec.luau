-- Regional pricing and gifts (Logic/PriceLevels): a gift goes only from a
-- price level at least the friend's, and each player is shown their own price.
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

	test("the price shown is the one in Roblox's answer, or none", function()
		check.equal(PriceLevels.shown({ PriceInRobux = 90, UserBasePriceInRobux = 100 }), 90, "the player's own")
		check.equal(PriceLevels.shown({ PriceInRobux = 36.0 }), 36, "a whole number")
		check.equal(PriceLevels.shown({ PriceInRobux = nil, IsForSale = false }), nil, "off sale")
		check.equal(PriceLevels.shown({ PriceInRobux = 0 }), nil, "nothing's free")
		check.equal(PriceLevels.shown({ PriceInRobux = "90" }), nil, "not a number")
		check.equal(PriceLevels.shown({ PriceInRobux = 0 / 0 }), nil, "not a number at all")
		check.equal(PriceLevels.shown({ PriceInRobux = math.huge }), nil, "not a price")
		check.equal(PriceLevels.shown(nil), nil, "no answer")
	end)

	test("what's on sale is asked for, the listed price kept for when Roblox can't say", function()
		local products = {
			Products = {
				MarksSmall = { id = 11, robux = 100 },
				Unmade = { robux = 50 },
			},
			Passes = {
				Starter = { id = 22, robux = 99 },
				Supporter = {},
			},
		}
		local asks = PriceLevels.onSale(products)
		check.equal(#asks, 2, "only what has an id")
		check.equal(asks[1].name, "MarksSmall", "by name")
		check.equal(asks[1].id, 11, "its id")
		check.truthy(not asks[1].pass, "a developer product")
		check.equal(asks[2].name, "Starter", "then the pass")
		check.truthy(asks[2].pass, "asked as a pass")
		check.equal(PriceLevels.listed(products, "MarksSmall"), 100, "a product's listed price")
		check.equal(PriceLevels.listed(products, "Starter"), 99, "a pass's")
		check.equal(PriceLevels.listed(products, "Supporter"), nil, "none listed")
		check.equal(PriceLevels.listed(products, "Nothing"), nil, "not sold")
	end)

	test("every name on sale is one thing, product or pass", function()
		local Products = require(Shared.Data.Products)
		for name in Products.Passes do
			check.equal(Products.Products[name], nil, name .. " is a pass, not also a product")
		end
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
