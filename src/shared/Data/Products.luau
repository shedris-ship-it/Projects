-- What the game sells for Robux (docs/plans/lobby-rework.md, "What's sold";
-- Services/MonetizationService). Prices are set in Creator Hub, not here:
-- the owner makes each developer product and game pass there and its id
-- goes in `id`. An entry without an id can't be bought yet.
--
-- grant: what a developer product gives (Logic/Profile.applyPurchase):
-- `marks`, `arcadeCredits`, `starterPack`. Items (the starter pack's
-- jacket) come with the shops.

return {
	Products = {
		MarksSmall = { grant = { marks = 1000 } }, -- 100 R (10 Marks a Robux, the owner)
		MarksMedium = { grant = { marks = 4400 } }, -- 400 R, 10% bonus
		MarksLarge = { grant = { marks = 12000 } }, -- 1,000 R, 20% bonus
		StarterPack = { grant = { marks = 1000, starterPack = true }, once = true }, -- 99 R; and a jacket, with the boutique
		ArcadePlay = { grant = { arcadeCredits = 1 } }, -- 5 R (the owner)
		ArcadeTen = { grant = { arcadeCredits = 10 } }, -- 40 R
	},
	Passes = {
		ArcadeUnlimited = {}, -- 250 R (the owner)
		Supporter = {}, -- 500-1,000 R
	},
}
