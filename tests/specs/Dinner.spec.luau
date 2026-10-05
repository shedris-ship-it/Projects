-- The dinner table (Logic/Dinner): whoever sets a place is out of his reach.
return function(test, check, Shared, require)
	local Config = require(Shared.Config)
	local Dinner = require(Shared.Logic.Dinner)
	local reach = Config.Guest.ContactRadius + Config.Scent.TableMargin

	test("every place is out of his close-contact reach, for any number of heirlooms", function()
		for _, size in { { 12, 6 }, { 10, 5 }, { 16, 6 } } do
			for count = 1, 4 do
				local layout =
					Dinner.layout(count, size[1], size[2], Config.Guest.ContactRadius, Config.Scent.TableMargin)
				check.equal(#layout.places, count, "a place each")
				check.atLeast(
					Dinner.closest(layout),
					reach - 1e-6,
					string.format("%d places on a %d table", count, size[1])
				)
				check.atMost(layout.head, -size[1] / 2, "his seat is past the end of the table")
			end
		end
	end)

	test("places alternate sides down the table", function()
		local layout = Dinner.layout(3, 12, 6, 5, 2)
		check.truthy(layout.places[1].side > 0 and layout.places[2].side < 0, "both sides")
		check.truthy(layout.places[1].along < layout.places[3].along, "down its length")
	end)
end
