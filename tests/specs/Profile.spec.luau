-- The saved profile (Logic/Profile): its shape, version 1's upgrade, and
-- purchases that count once.
return function(test, check, Shared, require)
	local Profile = require(Shared.Logic.Profile)

	test("a new profile has every field", function()
		local data = Profile.new()
		check.equal(data.Version, Profile.Version, "current version")
		check.equal(data.Marks, 0, "no Marks")
		check.equal(data.ArcadeCredits, 0, "no credits")
		check.equal(data.StarterPack, false, "no starter pack")
		check.equal(type(data.Owned), "table", "owns nothing yet")
		check.equal(#data.Receipts, 0, "no receipts")
	end)

	test("a version 1 profile keeps what it had and gains the new fields", function()
		local old = {
			Version = 1,
			Marks = 535,
			Xp = 535,
			RunsPlayed = 6,
			Wins = 2,
			Extractions = 3,
			Settings = { fov = 80 },
			Dossier = { ["stalker:TheGuest"] = true },
		}
		local data = Profile.reconcile(old)
		check.equal(data.Version, Profile.Version, "upgraded")
		check.equal(data.Marks, 535, "Marks kept")
		check.equal(data.RunsPlayed, 6, "runs kept")
		check.equal(data.Settings.fov, 80, "settings kept")
		check.truthy(data.Dossier["stalker:TheGuest"], "dossier kept")
		check.equal(data.ArcadeCredits, 0, "credits added")
		check.equal(type(data.Wearing), "table", "wearing added")
	end)

	test("a bad write is clamped back into range", function()
		local data = Profile.reconcile({
			Marks = -5,
			Xp = "lots",
			ArcadeCredits = 0 / 0,
			Tickets = 1e12,
			StarterPack = "yes",
			Owned = 3,
			Receipts = { "a", 4, "b" },
		})
		check.equal(data.Marks, 0, "negative Marks")
		check.equal(data.Xp, 0, "not a number")
		check.equal(data.ArcadeCredits, 0, "NaN")
		check.equal(data.Tickets, 1e9, "too many")
		check.equal(data.StarterPack, false, "only true is true")
		check.equal(type(data.Owned), "table", "a table again")
		check.equal(#data.Receipts, 2, "only string receipts")
	end)

	test("a purchase is granted once, and never adds XP", function()
		local data = Profile.new()
		local applied = Profile.applyPurchase(data, "p1", { marks = 1000 })
		check.truthy(applied, "first time")
		check.equal(data.Marks, 1000, "the Marks")
		check.equal(data.Xp, 0, "bought Marks are not Clearance")
		local again = Profile.applyPurchase(data, "p1", { marks = 1000 })
		check.truthy(not again, "Roblox asking again")
		check.equal(data.Marks, 1000, "not twice")
		Profile.applyPurchase(data, "p2", { arcadeCredits = 10, starterPack = true })
		check.equal(data.ArcadeCredits, 10, "credits")
		check.truthy(data.StarterPack, "starter pack")
	end)

	test("a purchase whose save failed is taken back whole", function()
		local data = Profile.new()
		data.Marks = 50
		local applied, undo = Profile.applyPurchase(data, "p1", { marks = 1000, arcadeCredits = 1 })
		check.truthy(applied, "applied")
		undo()
		check.equal(data.Marks, 50, "Marks back")
		check.equal(data.ArcadeCredits, 0, "credits back")
		check.truthy(not Profile.hasReceipt(data, "p1"), "receipt gone, so Roblox's next ask grants it")
	end)

	test("version 3 (LB3): the daily double, the starter slip, gifts; bad owned data cleaned", function()
		local data = Profile.reconcile({
			Version = 2,
			Marks = 10,
			Owned = { garment = { Biker = true, Junk = "yes", [4] = true }, frames = 7 },
			Wearing = { Top = "Biker", Bottom = 9 },
			Gifts = { { product = "MarksSmall", from = 12 }, "junk", { from = 3 } },
		})
		check.equal(data.Version, Profile.Version, "upgraded")
		check.equal(data.DoubleDay, 0, "no double yet")
		check.equal(data.StarterOffered, false, "not offered yet")
		check.truthy(data.Owned.garment.Biker, "a real garment kept")
		check.equal(data.Owned.garment.Junk, nil, "only true is owned")
		check.equal(data.Owned.frames, nil, "a kind must be a set")
		check.equal(data.Wearing.Top, "Biker", "wearing kept")
		check.equal(data.Wearing.Bottom, nil, "only names")
		check.equal(#data.Gifts, 1, "only real gifts")
	end)

	test("a purchase can grant a garment, and a gift waits wrapped", function()
		local data = Profile.new()
		Profile.applyPurchase(data, "p1", { marks = 1000, starterPack = true, garment = "DenimJacket" })
		check.truthy(data.Owned.garment.DenimJacket, "the starter pack's jacket")
		check.equal(data.Marks, 1000, "and its Marks")
		local applied, undo = Profile.applyPurchase(data, "p2", { marks = 4400 }, { product = "MarksMedium", from = 7 })
		check.truthy(applied, "a gift applied")
		check.equal(data.Marks, 5400, "granted at once")
		check.equal(#data.Gifts, 1, "its box waiting")
		undo()
		check.equal(data.Marks, 1000, "a failed save takes it back")
		check.equal(#data.Gifts, 0, "box too")
		check.truthy(data.Owned.garment.DenimJacket, "an earlier purchase stays")
		Profile.applyPurchase(data, "p3", { marks = 1000 }, { product = "MarksSmall", from = 7 })
		local gift = Profile.openGift(data)
		check.truthy(gift and gift.product == "MarksSmall" and gift.from == 7, "opened")
		check.equal(Profile.openGift(data), nil, "none left")
	end)

	test("only the newest receipts are kept", function()
		local data = Profile.new()
		for i = 1, Profile.MaxReceipts + 5 do
			Profile.applyPurchase(data, "p" .. i, { marks = 1 })
		end
		check.equal(#data.Receipts, Profile.MaxReceipts, "bounded")
		check.truthy(not Profile.hasReceipt(data, "p1"), "the oldest dropped")
		check.truthy(Profile.hasReceipt(data, "p" .. (Profile.MaxReceipts + 5)), "the newest kept")
	end)
end
