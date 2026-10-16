# The lobby rework, LB3: the boutique and Marks (build `2026-10-16.215`)

The owner: "Lets do Lb3." The plan (`docs/plans/lobby-rework.md`, "Boutique", "Money"): owning and wearing clothes, the changing booth, buying with Marks, gifts, the Marks packs and the starter pack; the first paid line of six garments, sketched first for the owner to swap any, then one wardrobe batch; and runs paying about half the Marks they did.

## The six garments: sketches first

`sketch/sheet.jpg` has all six on both bodies, front and back, mixed with the free clothes, and a close-up of each. They're unbaked Blender sketches (`tools/blender/kitlib/wardrobe.py`), with faces drawn from the front only as Roblox does. They're built at full detail, so if the owner keeps them the batch is these, baked.

| Garment | Slot | Price | As sketched |
| --- | --- | --- | --- |
| High-top sneakers | Shoes | 500 | White leather, a padded navy collar, navy side panels and heel, laced to the top, a rubber cupsole and toe |
| Ringer tee | Top | 800 | Cream cotton, short sleeves, a red ribbed crew neck and red bands round the sleeves; the forearms bare |
| Parachute pants | Bottom | 900 | Red nylon, full round the knee, gathered at the ankle into an elastic cuff, zips slanting across the thighs, a zipped pocket and an ankle zip |
| Colour-block sweatshirt | Top | 1,000 | Navy fleece below, a yellow band across the chest, red over the shoulders; a ribbed neck, cuffs and waistband |
| Acid-wash denim jacket | Top | 1,500 | Pale bleached denim marbled over the blue; a point collar, copper buttons, flapped chest pockets, a buttoned waistband |
| Leather biker jacket | Top | 2,000 | Black leather, the zip from the left hip to the right shoulder, wide lapels on snaps, zipped pockets, a belt with a steel buckle, zips at the cuffs |

**What changed while sketching:**
- **The free clothes are untouched.** Each garment is built over every garment it can be worn with, so a new one can reshape an old one. The new tops are all worn out over the trousers, and the parachute pants stay slim where the jackets' hems cover their tops. A zip fly on the pants pushed three jackets' fronts out, so it went (parachute pants often hid theirs). Every one of the 37 old pieces' vertices hashes the same as before (`Data/KitWear`'s old entries unchanged, 29 new).
- **High-tops replace the trousers' shin.** The first sketch had the shaft go over the trouser hems: a wide bucket, worse with the jeans' rolled cuff (`sketch/first_boys_back.jpg`). On the classic leg only about 0.17 studs of shin shows between the thigh and the foot. So with high-tops the game leaves the trousers' short shin piece off (`Data/Wardrobe` `over`), and the shaft rises into the trouser thigh's foot. The trousers look bloused into the shoe, on both bodies. Every layer checks clean (`wardrobe.check`, worst 0.000).
- **Lace tabs and side panels.** These stood off the steep instep as loose flaps and jagged strips. Now they're a laced strip on the tongue and curved bands that follow the shoe.
- **The acid wash.** The first try bleached half of it white, and it read as a floral print. Now it's mostly blue with pale marbling.

**Next, the owner's:** swap any of the six, or keep them. Then Claude bakes and exports the batch (`build/kit/wardrobe/`, the new pieces only, checked with `preview.py --backfaces` and `wardrobe_visibility.py`), and the owner imports it with Home → Import 3D. Until then the six are worn in plain colours (each garment's `paint`).

## The boutique (`Services/ShopService`, `UI/Boutique`, `Logic/Closet`)

- **Cards on the racks** name what's new and its price in Marks: the ringer tee and sweatshirt on the tops rail, the two jackets on the round rack, the parachute pants on the bottoms rail, the high-tops on the shoe wall (`cards_after.jpg`). They're seated on the rails, wide enough that no price wraps (`cards_before.jpg`).
- **The fitting room.** E "Try on" at the changing booth:
  - You stand at its curtain, facing the shop, and the camera turns to face you from the shop, like a mirror.
  - The case folder goes away, no prompt works, and you can't walk off.
  - The card flips each slot through the free set, then the paid line, cheapest first, and dresses you at once.
  - The free ones say "Everyone's. On you.", yours "Yours. On you.", and the rest their price, with BUY when you can afford it.
  - BUY takes the Marks and keeps it on. Done (or Space) keeps on what's yours; anything you didn't buy goes back on the rack.
  - E "Try on" at any rack does the same where you stand (the booth takes one at a time).
  - Prices are only ever the server's (`Data/Wardrobe`).
- **Inside the booth didn't work** (`booth_inside_before.jpg`): its drawn curtain hid you, and leaving shoved you out through its back. Standing at the curtain fixes both (`booth_after.jpg`).
- **What you wear is yours everywhere.** `OutfitService` dresses each player in what they own and chose (`Logic/Closet.outfit`). That covers the run, first person (your arms are copied from your character), and the Guest's disguise (it clones a friend's character). A slot you haven't chosen is still your squad slot's, so a new squad still looks like four different people.
- **The till** (`till.jpg`): E "Pay" at the cash wrap.
  - It lists the three Marks packs at their starting Robux prices, each "Coming soon" until its product id is in `Data/Products`.
  - "For:" steps through everyone in the lobby: buying for someone makes it a gift.
  - "Get Marks" on the fitting room's card opens it too.
- **Gifts** (`MonetizationService`):
  - A pack bought for a friend is granted to them and saved with its receipt before Roblox is told; the buyer keeps the receipt too.
  - The friend gets a note and a wrapped box (red, a gold ribbon) on the floor in front of them (`gift_box.jpg`).
  - Opening it ("Open", theirs only) says what it was and from whom.
  - If they've left before Roblox confirms the purchase, the buyer has it instead.
  - A once-only product can't be gifted to someone who has it.
- **The starter pack:** the acid-wash denim jacket and 1,000 Marks, 99 Robux, offered once on a slip after your first run (`starter_slip.jpg`), only once its product exists.

## Marks (`Config.Pay`, `Logic/Progression`)

- **Two sums now.** Marks are about half of before (base 10; the dinner 60 plus (100 − Drift) / 5; out of the door 10; 5 a region opened or puzzle solved; 8 a hunt survived; 12 a valuable carried out). Clearance XP keeps the old sum exactly (25 a valuable), so levels come as fast as ever.
- **The spec's model runs:** a strong escape pays 130 to 175 Marks on the short night's two regions or the full house's four; a lost run that got somewhere 20 to 60; a collapse with nothing done 10.
- **Double Marks on your first escape of the day** (UTC), out of the front door; the Dossier's slip says "doubled: first out today". The profile keeps the day (`DoubleDay`).
- **A bot run** (F2 `botrun`, seed 1800820264, the short night): out at 3:57, Drift 3, two regions opened and puzzles solved between them, one hunt survived, no valuables. That paid **117 Marks, doubled to 234** as the day's first escape; the old single sum would have paid about 248. The bot knows the plan and skips most of the house, so a player's fuller escape lands near 150 (the spec's model runs).

## Profile version 3 (`Logic/Profile`)

- The day of your last double (`DoubleDay`), whether the starter pack's slip has been shown (`StarterOffered`), and gifts waiting to be opened (`Gifts`).
- A purchase can grant a garment (the starter pack's jacket).
- What you own and wear is cleaned on load (only names, only `true`).

## F2

- `marks <n>`: your Marks.
- `shop [booth|rack] [top|bottom|shoes]` and `shop done`: the fitting room from anywhere in the hub.
- `own [garment|none]`: lists, gives, or empties your wardrobe.
- `gift <product>`: a wrapped gift from yourself, granted, its box out.
- `starter [again]`: the starter slip, as after a first run.

## Checked in Studio (solo)

- The booth: try-on dresses you in each garment's colours at once.
- Buying the biker jacket took 2,000 of 3,000 Marks and kept it on.
- Done kept the jacket and put back the unbought parachute pants.
- The cards, the till's card, the starter slip, and a gift's box opened ("Shedris gave you 1,000 Marks", the box gone).
- No errors from the game's scripts.

Studio's play test here has no saves ("progress not saved here"), so nothing bought carried to the next play. Saving is the owner's check in the published place (TC-321).

**Not checked, the owner's** (TC-320 to TC-324):
- the six garments' look and fit once imported (TC-322 for the high-tops on both bodies);
- buying for Robux, live, once the products exist (Roblox's test purchases);
- a gift between two players;
- what others see you wear, with two clients.

## Shots

| Shot | What it shows |
| --- | --- |
| `sketch/sheet.jpg` | The sketch sheet, labelled |
| `sketch/*.jpg` | Each render, and the first try's high-tops (`first_*`) |
| `booth_inside_before.jpg`, `booth_after.jpg` | Inside the booth (hidden by the curtain), then at its curtain |
| `cards_before.jpg`, `cards_after.jpg` | The rack cards, first and seated |
| `till.jpg`, `starter_slip.jpg`, `gift_box.jpg` | The till, the starter slip, a gift waiting |
