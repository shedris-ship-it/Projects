return function(test, check, Shared, require)
	local Outfit = require(Shared.Logic.Outfit)

	local function same(a, b)
		return a[1] == b[1] and a[2] == b[2] and a[3] == b[3]
	end

	test("the first four squad members get different shirts", function()
		for a = 1, 4 do
			for b = a + 1, 4 do
				check.equal(
					same(Outfit.palette(a).shirt, Outfit.palette(b).shirt),
					false,
					"shirts " .. a .. " and " .. b
				)
			end
		end
	end)

	test("the Companion's outfit differs from the first player's", function()
		check.equal(same(Outfit.palette(1).shirt, Outfit.palette(2).shirt), false, "shirt")
	end)

	test("a palette is deterministic and every colour is a real 0..255 colour", function()
		for i = 1, 20 do
			local p, q = Outfit.palette(i), Outfit.palette(i)
			check.truthy(same(p.shirt, q.shirt) and same(p.pants, q.pants) and same(p.skin, q.skin), "same twice")
			for _, rgb in { p.shirt, p.pants, p.skin, p.shoes } do
				for c = 1, 3 do
					check.truthy(rgb[c] >= 0 and rgb[c] <= 255, "channel in range")
				end
			end
		end
	end)

	test("slots wrap rather than fail, and nonsense slots are clamped", function()
		check.truthy(Outfit.palette(0) ~= nil, "slot 0")
		check.truthy(
			same(Outfit.palette(1).shirt, Outfit.palette(1 + Outfit.ShirtCount).shirt),
			"wraps after the last shirt"
		)
	end)
end
