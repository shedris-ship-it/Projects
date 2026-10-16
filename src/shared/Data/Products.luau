-- What the game sells for Robux (docs/plans/lobby-rework.md, "What's sold";
-- Services/MonetizationService). Prices are set in Creator Hub, not here:
-- the owner makes each developer product and game pass there and its id
-- goes in `id`. An entry without an id can't be bought yet.
--
-- grant: what a developer product gives (Logic/Profile.applyPurchase):
-- `marks`, `arcadeCredits`, `starterPack`, `garment` (Data/Wardrobe).
-- `robux` is the starting price the owner sets in Creator Hub, shown on the
-- till's card (Roblox's own prompt shows the real one); `label` names it
-- there; `till` puts it on the boutique's till (LB3), in that order. A
-- product can be bought for a friend in the same lobby, a wrapped gift
-- (Services/MonetizationService), except a once-only one they already have.

return {
	Products = {
		MarksSmall = { grant = { marks = 1000 }, robux = 100, label = "1,000 Marks", till = 1 }, -- 10 Marks a Robux (the owner)
		MarksMedium = { grant = { marks = 4400 }, robux = 400, label = "4,400 Marks", till = 2 }, -- 10% bonus
		MarksLarge = { grant = { marks = 12000 }, robux = 1000, label = "12,000 Marks", till = 3 }, -- 20% bonus
		-- About 250 R of value; shown once, after your first run.
		StarterPack = {
			grant = { marks = 1000, starterPack = true, garment = "DenimJacket" },
			once = true,
			robux = 99,
			label = "Starter pack: the acid-wash denim jacket and 1,000 Marks",
		},
		ArcadePlay = { grant = { arcadeCredits = 1 }, robux = 5, label = "An arcade play" }, -- (the owner)
		ArcadeTen = { grant = { arcadeCredits = 10 }, robux = 40, label = "Ten arcade plays" },
	},
	Passes = {
		ArcadeUnlimited = {}, -- 250 R (the owner)
		Supporter = {}, -- 500-1,000 R
	},
}
