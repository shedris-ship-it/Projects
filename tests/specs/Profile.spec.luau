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
		check.equal(data.Version, 2, "upgraded")
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
