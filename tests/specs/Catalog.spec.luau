-- The lobby's other wares (LB4; Logic/Catalog): the torch's looks and the
-- cars' bits, owned, bought, carried and fitted.
return function(test, check, Shared, require)
	local Catalog = require(Shared.Logic.Catalog)
	local CarBits = require(Shared.Data.CarBits)
	local Profile = require(Shared.Logic.Profile)
	local TorchLooks = require(Shared.Data.TorchLooks)

	test("every kind lists its wares in order, the free ones free and the rest priced 300 to 2,000", function()
		for kind, k in Catalog.Kinds do
			local seen = 0
			for _, id in k.order do
				local item = k.items[id]
				check.truthy(item ~= nil, kind .. " " .. id .. " is a ware")
				check.truthy(type(item.name) == "string" and #item.name > 0, id .. " has a name")
				if not item.free then
					local price = Catalog.price(kind, id) :: number
					check.truthy(price >= 300 and price <= 2000, id .. "'s price in range")
				end
				seen += 1
			end
			local count = 0
			for _ in k.items do
				count += 1
			end
			check.equal(seen, count, kind .. ": the order lists them all")
			if k.default then
				check.truthy(k.items[k.default].free, kind .. "'s default is everyone's")
			end
		end
	end)

	test("the plan's torches and prices; each has its mesh and its colours till then", function()
		check.equal(Catalog.price("torch", "Rubber"), 1000, "yellow rubber")
		check.equal(Catalog.price("torch", "Brass"), 1500, "brass")
		check.equal(Catalog.price("torch", "Chrome"), 2000, "long chrome")
		for id, look in TorchLooks.Looks do
			check.truthy(type(look.mesh) == "string", id .. "'s mesh")
			check.truthy(look.free or (look.paint and look.paint.body and look.paint.head), id .. "'s colours")
		end
	end)

	test("buying spends once; a torch is carried only once it's yours", function()
		local data = Profile.new()
		data.Marks = 1200
		check.equal(Catalog.torchOf(data), TorchLooks.Default, "today's torch to start")
		local ok, why = Catalog.carry(data, "Rubber")
		check.truthy(not ok and why == "notOwned", "not before buying")
		ok, why = Catalog.buy(data, "torch", "Brass")
		check.truthy(not ok and why == "marks", "1,500 is more than 1,200")
		check.truthy(Catalog.buy(data, "torch", "Rubber"), "bought")
		check.equal(data.Marks, 200, "its price spent")
		ok, why = Catalog.buy(data, "torch", "Rubber")
		check.truthy(not ok and why == "owned", "not twice")
		ok, why = Catalog.buy(data, "torch", "Metal")
		check.truthy(not ok and why == "free", "today's isn't sold")
		check.truthy(Catalog.carry(data, "Rubber"), "carried")
		check.equal(Catalog.torchOf(data), "Rubber", "the one you carry")
		data.Owned.torch.Rubber = nil
		check.equal(Catalog.torchOf(data), TorchLooks.Default, "taken back: today's again")
	end)

	test("your car: paint, bits and a station, only what's yours shows", function()
		local data = Profile.new()
		data.Marks = 5000
		local plain = Catalog.carOf(data)
		check.equal(plain.paint, "Maroon", "maroon")
		check.equal(next(plain.bits), nil, "no bits")
		check.equal(plain.radio, "Off", "no radio")
		local ok, why = Catalog.paint(data, "Cream")
		check.truthy(not ok and why == "notOwned", "a paint is bought first")
		check.truthy(Catalog.buy(data, "paint", "Cream") and Catalog.paint(data, "Cream"), "painted")
		check.truthy(Catalog.buy(data, "carbit", "Whitewalls") and Catalog.fit(data, "Whitewalls", true), "fitted")
		check.truthy(Catalog.buy(data, "radio", "Oldies") and Catalog.tune(data, "Oldies"), "tuned")
		local mine = Catalog.carOf(data)
		check.equal(mine.paint, "Cream", "cream")
		check.truthy(mine.bits.Whitewalls, "whitewalls on")
		check.equal(mine.radio, "Oldies", "the oldies")
		check.truthy(Catalog.fit(data, "Whitewalls", false), "taken off")
		check.equal(Catalog.carOf(data).bits.Whitewalls, nil, "off")
		-- A bit you don't own never shows, whatever the profile says.
		data.Car.bits.RoofRack = true
		check.equal(Catalog.carOf(data).bits.RoofRack, nil, "not yours")
		check.equal(Catalog.price("carbit", "Woodgrain"), CarBits.Bits.Woodgrain.price, "woodgrain is a bit")
	end)

	test("a profile's car is cleaned on load: names only", function()
		local data = Profile.reconcile({
			Car = { paint = 4, radio = "Night", bits = { RoofRack = true, Junk = "x", [2] = true } },
		})
		check.equal(data.Car.paint, nil, "a paint is a name")
		check.equal(data.Car.radio, "Night", "kept")
		check.truthy(data.Car.bits.RoofRack, "a bit kept")
		check.equal(data.Car.bits.Junk, nil, "only true")
		check.equal(Catalog.carOf(data).radio, "Off", "a station you don't own stays off")
	end)
end
