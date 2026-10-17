-- What the game sells for Robux (docs/plans/lobby-rework.md, "What's sold";
-- Services/MonetizationService). Prices are set in Creator Hub, not here:
-- the owner makes each developer product and game pass there and its id
-- goes in `id`. An entry without an id can't be bought yet.
--
-- grant: what a developer product gives (Logic/Profile.applyPurchase):
-- `marks`, `arcadeCredits`, `starterPack`, `garment` (Data/Wardrobe). A pass
-- with a grant gives it once, the first time the game sees you own it (at
-- join, or as you buy it: Services/MonetizationService).
-- `robux` is the starting price the owner sets in Creator Hub, shown on the
-- till's card (Roblox's own prompt shows the real one); `label` names it
-- there; `till` puts it on the boutique's till (LB3), in that order. A
-- product can be bought for a friend in the same lobby, a wrapped gift
-- (Services/MonetizationService), except a once-only one they already have.

return {
	Products = {
		-- (Made by the owner in Creator Hub, 2026-10-16. The arcade's are the
		-- arcade's, not one game's: "I don't plan on just having house call
		-- forever".)
		MarksSmall = { id = 3719095841, grant = { marks = 1000 }, robux = 100, label = "1,000 Marks", till = 1 }, -- 10 Marks a Robux (the owner)
		MarksMedium = { id = 3719096140, grant = { marks = 4400 }, robux = 400, label = "4,400 Marks", till = 2 }, -- 10% bonus
		MarksLarge = { id = 3719096203, grant = { marks = 12000 }, robux = 1000, label = "12,000 Marks", till = 3 }, -- 20% bonus
		ArcadePlay = { id = 3719096497, grant = { arcadeCredits = 1 }, robux = 5, label = "An arcade play" }, -- (the owner)
		ArcadeTen = { id = 3719096570, grant = { arcadeCredits = 10 }, robux = 40, label = "Ten arcade plays" },
		-- (A developer product "Starter pack", 3719096408, was made too and is
		-- never offered: the starter pack is a pass.)
	},
	Passes = {
		-- About 250 R of value for 99; offered once, after your first run, and in the
		-- game's Store tab. A pass, the owner's call (2026-10-16): Roblox sells
		-- it only once.
		StarterPack = {
			id = 2036805120,
			grant = { marks = 1000, starterPack = true, garment = "DenimJacket" },
			robux = 99,
			label = "Starter pack: the acid-wash denim jacket and 1,000 Marks",
		},
		-- Every arcade game, as often as you like (the owner set 300 R).
		ArcadeUnlimited = { id = 2038137055, robux = 300, label = "Unlimited arcade plays" },
		Supporter = {}, -- 500-1,000 R
	},
}
