# Monetization: the products on sale

The owner, 2026-10-16: "could we work on monetization?" Everything for the first products was built in LB0 to LB5 (`Services/MonetizationService`, `Data/Products`, the boutique's till, the arcade's coin card, the starter pack's slip) and waited only on ids. So the owner made them in Creator Hub, walked through it step by step, and Claude filed them and tested them.

## What's on sale

| Kind | Name in Creator Hub | Id | Price | Key in `Data/Products` |
| --- | --- | --- | --- | --- |
| Developer product | 1,000 Marks | 3719095841 | 100 R | MarksSmall |
| Developer product | 4,400 Marks | 3719096140 | 400 R | MarksMedium |
| Developer product | 12,000 Marks | 3719096203 | 1,000 R | MarksLarge |
| Developer product | ARCADE Play | 3719096497 | 5 R | ArcadePlay |
| Developer product | ARCADE Bundle (ten plays) | 3719096570 | 40 R | ArcadeTen |
| Game pass | ARCADE Unlimited | 2038137055 | 300 R | ArcadeUnlimited |
| Game pass | Starter Pack | 2036805120 | 99 R | StarterPack |

- **The owner's changes:**
  - The arcade's products and pass are named for the arcade, not HOUSE CALL: "I don't plan on just having house call forever". The game already treats them as the arcade's.
  - The unlimited pass is 300 R, not the plan's 250.
- **The starter pack is a pass,** the owner's call ("Wouldn't the starter pack be a gamepass too?"):
  - Roblox sells it once, and it shows in the game's Store tab.
  - A pass gives nothing by itself, so the game gives its jacket and 1,000 Marks the first time it sees you own it: at join, or as you buy it (even from the game's page). It's marked in the profile (`Owned.pass`), so it never comes twice.
  - A "Starter pack" developer product (3719096408) was made too, before the switch; it's never offered.
- **Not made:** the Supporter pass. It gives nothing until what it contains is built.

The two passes' icons were drawn by Claude for the owner to upload (`docs/monetization/`; `tools/pass_icon.py`, `tools/starter_icon.py`).

## Regional pricing and gifts

Creator Hub asked when the products were made: allowing gifting can lose revenue if players exploit regional price differences. The game does allow gifts (the till buys Marks or arcade plays for a friend in the lobby). So a gift now goes only from a player whose price level is at least the friend's, which is Roblox's own recommended rule (`Logic/PriceLevels`, spec'd).
- Each player's level is asked for at join, as the docs advise (`MarketplaceService:GetUsersPriceLevelsAsync`), and again if unknown when a gift is bought.
- The receipt checks once more before granting to the friend.
- A refused buyer is told: "Roblox prices change by country, so a gift can only go to someone whose prices are the same as yours or lower."
- The owner could then truthfully pick "My experience implements the appropriate checks".

## Checked in Studio

- Roblox's price-level call answers (the owner's account: 1000, full price), and the products' info reads back from Roblox.
- **F2 `buy`** sends a test receipt through the game's own handling (what Roblox calls after "Buy", no Robux):
  - the three Marks packs gave +1,000, +4,400 and +12,000;
  - the arcade plays gave +1 and +10;
  - the starter pack was given at join (the creator owns their own passes), and buying it again gave nothing.
- **A fix found doing it:** a Studio session without DataStores held every purchase back, as the game does when it can't save. In Studio only, a memory-only profile now counts as saved; a live server that can't save still holds a purchase back for one that can.
- **Not seen:** Roblox's own purchase prompt (it draws above the game, out of the screenshots), a real purchase, and gifts with two players. TC-342 to TC-344.

## Each player's own price (build .229)

- **The labels show what Roblox will charge you,** not Data/Products' figure: the till's rows, the starter pack's slip and the arcade's coin card. Each client asks Roblox once a session (`MarketplaceService:GetProductInfoAsync`, which answers a client with its own player's price; client `Lib/Prices`, `Logic/PriceLevels.shown`, spec'd). Until it answers, or if it can't, the listed figure shows. The server is unchanged: it never takes a price from a client, and the prompt is Roblox's.
- **The 90 R wasn't a wrong price.** Creator Hub's base prices match the data (100, 400, 1,000, 5, 40, 99, 300: `UserBasePriceInRobux`). The owner's account gets 10% off everything as a Roblox Plus subscriber (`PriceDiscountDetails`: `RobloxPlusSubscription`, 10%), so its prices are 90, 360, 900, 5, 36, 90 and 270, which is what Roblox's prompt charges it. A player in a cheaper country gets their regional figure the same way. TC-345.
- **The coin card's prices were cut off** (before and after the change: "Ten arcade plays: 36", "Unlimited arcade", no price at all). Each price is now pencilled under its label, as on the till.
- **Checked in Studio** (build .229, the owner's account): the client's own `GetProductInfoAsync` answers 90 R (base 100). The till, the starter slip and the coin card, opened with the payloads the server sends, read 90 / 360 / 900, 90, and 5 / 36 / 270 Robux, and every label fits. No errors. Before, the cut-off coin card: `prices-coin-card-before.jpg`; after, all three: `prices-after.jpg`. Not seen: a player in another country, or offline (the listed prices show then; spec'd, not seen).

## For the owner

- **Roblox reported 90 Robux** for the 1,000 Marks product, not 100: that's your Roblox Plus discount (above). Creator Hub's price is right, and since build .229 the till shows each player what their prompt will charge.
- **Test one real prompt** in Studio: E "Pay" at the boutique's till and buy 1,000 Marks. Roblox's test prompt charges nothing; after Buy, the Marks arrive.
- **Publish** when ready: the products only sell in the live game once this build is published.
