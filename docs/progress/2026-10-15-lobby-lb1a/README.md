# The lobby rework, LB1a: the grey-box mall (build `2026-10-15.201`)

The owner: "Start LB1a: build the walkable grey-box mall (court, four shopfronts with grilles, the diner, the video store into the garage, the closed shutter, rough warm light, the Ready table in the garage for now), and show me screenshots." The point is to walk the layout and judge distances, sight lines and whether it feels intuitive and not annoying, while changes are still cheap, before LB1b models it.

## What was built

The old 56 x 56 hub room is gone; the lobby is now a closed-off corner of a dead mall (`Data/Mall`, built by `World/MallBuilder`, its rules in `Logic/MallLayout`).
- **The court:** about 100 x 60 studs, with a fountain, four benches, planters, the mall directory, the photo booth, four hanging pendants and a skylight (night sky; rain sounds on it, `Config.Mall.Rain`). You arrive by the fountain facing the video store.
- **Its north side:** the boutique (racks, changing booth, till), the video store (shelves along the walls, a counter, a clear aisle to "STAFF ONLY · GARAGE") and the arcade (six cabinets, the prize counter marked "PRIZES · CLOSED"). Each shopfront is open, its roll-up grille's box over the opening, a neon sign on the bulkhead.
- **Its south side:** electronics (the TV wall in its window), the mall's main glass doors, chained and marked "MALL CLOSED", with the parking lot under a sodium lamp outside, and a dead shop behind a closed grille, "FOR LEASE" (a slot for a later shop).
- **The two ends of the hall:** the diner at the west end (counter, stools, booths, the menu board "MENU · NORMAL" and the specials board "SPECIALS · HARD" for the records), and the giant shutter at the east end, a padlocked grille with the dead mall going on in the dark behind it (dim emergency lamps, closed shopfronts, a green EXIT sign far off). The shutter stays closed until the owner decides what it becomes.
- **The garage,** reached only through the video store's back door: fluorescent strips, six bays, the closed roll-up door marked "CARS (LB2)", two stand-in cars, the case board, the Dossier desk, the car-bits pegboard (LB4), the payphone, and the hub's contract table by the door (until LB2's cars). A squad back from a run stands by the bays.
- **A run server** builds only the garage, as the squad's waiting room, with its door to the video store walled up.
- **The layout's rules are tested** (`tests/specs/MallLayout.spec.luau`, 7 tests): no rooms overlap; every door stands on its rooms' walls; every shopfront is within 52 studs of the fountain (4 s at the hub's 12 studs a second); every room has a way in; the spawn is in the court; the garage's only way in is the video store; the diner and the shutter close the hall's two ends.
- **Cost:** 408 parts and 25 lights; no errors or warnings in play.

## Screenshots (Studio, at the game's lens)

| | |
| --- | --- |
| `1_from_the_spawn.jpg` | What you see on arrival: the boutique, the video store and the arcade, the fountain, the pendants, the skylight. Through the video store, the garage door |
| `2_west_to_the_diner.jpg` | Down the hall to the diner at its west end, its menu boards and stools; the chained glass doors and "MALL CLOSED" on the left |
| `3_east_to_the_shutter.jpg` | The other way: the giant shutter closing the hall, the dead mall dark behind it; "FOR LEASE" behind its grille on the right |
| `4_video_to_the_garage.jpg` | Through the video store: the aisle straight to "STAFF ONLY · GARAGE" |
| `5_the_garage.jpg` | The garage: the bays, the roll-up door, the stand-in cars, the contract table by the door |
| `6_the_diner.jpg` | The diner: counter, stools, a booth, the two boards for the records |
| `7_plan_from_above.jpg` | The whole layout from above with the ceilings hidden (north up): the garage, the three shops, the court, the diner (left), electronics and the dead shop (bottom), the dead mall behind the shutter (right) |

## Walked in play (a character walking at the hub's 12 studs a second)

- From the spawn to the garage, round the fountain and through the video store: **7.9 s**.
- From the garage to the diner: **9.4 s**.
- The whole hall, from the diner to the shutter: **9.6 s**.

Nothing blocked the way, but the walker's first, straight route from the spawn to the video store ran into the fountain and climbed onto it: the fountain stands on that line.

## For the owner to judge

1. **The fountain sits on the straight line from where you arrive to the video store,** so everyone walks round it. It anchors the court and the view, but the plan wanted the way to a run to be straight. Keep it, or move it (or the spawn) aside?
2. **The giant shutter is a see-through grille** (you see the dark dead mall behind it). It could be a solid roll-down shutter instead.
3. **The garage is lit cool and plain** (fluorescents), against the warm mall. The investigators' room might want some warmth.
4. **The court is big and the bulkheads over the shops are bare** (LB1b's trim, signs and lightboxes fill them). Does the size feel right walking it, or should the court shrink?
5. **The rain on the skylight** plays in the hub now, at 60 % of the house's first stage; not judged by ear yet.

## Since the screenshots

The fountain's water sat just under the basin's rim and didn't show; it's lifted a little above it (build .201, not re-shot).

## The story pass (build `2026-10-15.202`, screenshots in `story/`)

The owner, on the first grey box: "it doesn't really read as an abandoned mall with a secret community of investigators in it ... dim the lights in there except from the stores and the ads, more environmental storytelling", for example "a generator to the garage ... that you can infer hooks up to the abandoned mall to provide power".

**The story the mall now tells** (`Data/Mall`'s header has it in full): the mall died and its lamps with it. The investigators came in through the loading dock, now their garage, and run a generator there. Its cables run through the video store's back door and out over the court's floor to the few places they've reopened, and up the walls to the mall's old ad lightboxes. Those, their strings of bulbs and their work lamps are the only light. The rest is as the mall was left.

- **The light** (`Config.Mall.Lights`):
  - The mall's own pendants hang dead (`off`), and the fountain's light went with its water.
  - Each lit shop throws its light out over the court (`spill`: warm, purple from the arcade, cool from the TV wall).
  - Four ad lightboxes glow either side of the diner and of the shutter (`Mall.Ads`; LB6's immersive ads go on their faces, each 8.4-8.5 x 5 studs, within Roblox's 8 x 4.5 minimum).
  - Strings of bulbs (`Mall.Strings`) hang over the video store's front, along the ways to the diner and the shutter end, down the video store's aisle and over the investigators' corner. Moonlight comes down through the skylight.
  - In the garage two fluorescents of four still work, plus two work lamps on stands. That also settles the garage's "cool and plain" note: it's warm now.
- **The generator's power** (`Mall.Cables`): the generator with its exhaust pipe up through the ceiling, fuel cans and a cable reel; a thick black cable to the power box, labelled "POWER TO THE MALL"; then orange and black runs:
  - through the back door, along the video store's aisle, and out to a junction in front of the video store;
  - from there to the boutique, the arcade, the diner and electronics, and up the walls to the ad boxes;
  - taped down every few studs, under a yellow cable ramp where they cross the way to the video store.
- **What the investigators left:**
  - cardboard signs in marker under the old neon ("CASES & CARS — THIS WAY", "STILL OPEN", "THEY STILL WORK!", "BATTERIES · GEAR", "CANTEEN");
  - tape on the floor pointing the way ("CASES & CARS ▲");
  - the shutter taped off with a yellow X and "DO NOT ENTER";
  - in the garage: cots and a sleeping bag, a folding table with coffee and thermoses, the whiteboard ("TONIGHT: THE HALFWAY HOUSE"), the case board with photos, red string and the house's plan, a desk with a CB radio, evidence boxes;
  - in the diner: a coffee machine and a hot plate; in electronics, a torch on the counter and a charger; a TV on the video store's counter.
- **What the mall left:**
  - the dry fountain with leaves, coins and a can in it;
  - benches under dust sheets, one knocked over; dead plants in the planters;
  - fallen ceiling tiles and papers; a shopping cart;
  - a bucket under a leak in the skylight, with a puddle;
  - the main doors boarded outside ("NO TRESPASSING") and chained inside;
  - "CLOSING DOWN — EVERYTHING MUST GO" on the dead shop; the arcade's prize counter under a dust sheet;
  - behind the shutter, a fallen sign, tiles and a cart on its side.
- **Cost:** 718 parts and 43 lights; no errors or warnings in play.

| | |
| --- | --- |
| `story/1_from_the_spawn.jpg` | The court dark but for the shops, the bulbs and two ad boxes; the dead pendants; the dry fountain; the tape on the floor |
| `story/2_west_to_the_diner.jpg` | The diner glowing at the hall's end between two ad boxes; the cables and the ramp on the floor |
| `story/3_east_to_the_shutter.jpg` | The shutter taped off, the dead mall dim behind; "CLOSING DOWN" on the right |
| `story/4_the_generator.jpg` | The generator, its exhaust, the cable reel, the fuel cans, the black cable to the power box, a work lamp, a dead fluorescent |
| `story/5_the_investigators_corner.jpg` | Cots, coffee, the whiteboard, the case board with its red string, evidence boxes, bulbs |
| `story/6_plan_from_above.jpg` | The layout from above, dark in the middle, lit at the edges |

## The mall alive: sounds, lightning, brownouts (build `2026-10-15.203`)

The owner picked ideas 1 to 3 of the list after the story pass: "the sounds (I'll pick them by ear from your shortlist), lightning through the skylight and doors, and the generator's brownouts".

- **Sounds** (`Controllers/MallController`, `Data/Mall` `Sounds`, `Config.Mall.Sounds`):
  - the generator idling in the garage, carrying faintly into the video store;
  - the buzz of the two fluorescents still working;
  - the leak dripping into its bucket, a drop every 1.4-4 s at a slightly different pitch each time;
  - CB radio chatter in the investigators' corner;
  - the arcade's cabinets.

  Each role has a shortlist of three in `Assets.Mall`, chosen by description. **The owner picks by ear in Studio:** F2 `mallsound <role> <n>` switches every sound of that role to its n-th candidate at once (Hum, Buzz, Drip, Radio, Arcade, Sputter; Sputter also sets off a brownout so the cough can be heard). Then the pick moves to the front of its list. The arcade has no real arcade loop in the free libraries: two chiptune tracks and a casino loop (which has crowd voices) are its candidates. Silence is a fine answer too.
- **Lightning over the mall** (`Services/MallService`, `Controllers/WeatherController`):
  - Every 40-100 s while it's the hub, a strike from the house's own storm logic (`Logic/Storm`), marked `hub`, with its thunder at 75 %.
  - Only players in the hub see and hear it; the house's strikes stay the run's.
  - The flash burns the moonlight down through the skylight and a new light in through the main doors (both tagged as moon beams, which the flash already brightens), and lifts the sky's light over the court.
  - "Reduce flicker" gets the house's soft swell.
- **Brownouts** (`Logic/Brownout`, spec'd; `Services/MallService`; `Controllers/MallController`):
  - Every 150-300 s the generator coughs (the Sputter sound from the generator).
  - Everything on its power dips at once and stutters for a couple of seconds before coming back with one last falter: the shops' and diner's lights and their spill, the bulb strings, the work lamps, the working fluorescents, the ad lightboxes, the neon signs.
  - The mall's own dead lamps, the moon, the lot's lamp and the dead mall's battery emergency lamps and EXIT don't change, which shows what runs on the generator without a word.
  - Every client sees the same stutter (it comes from the brownout's time); "Reduce flicker" gets one smooth dip.
- **Checked in Studio:**
  - all six sounds loaded and played (123 things tagged as on the generator), no errors;
  - a brownout took a shop's light down to 18 % in a stutter (60 36 27 44 23 31 47 ... %) and back to 100 % in about 2.4 s, the moonlight untouched;
  - a strike flashed the door light from 0.25 to 1.25 and the moonlight from 0.9 to 4.5, the thunder played, and both settled back.

  `story/7_brownout.jpg` is caught in the middle of one. Not judged by ear: the sounds themselves (the owner's job, with `mallsound`).
- **The owner's picks** (2026-10-15, by ear on Roblox's store pages, through a sound board in the chat; build .204), now first in `Assets.Mall`:
  - the generator: the diesel idle loop;
  - the fluorescents: Light Bulb Buzz 2;
  - the drip: the tin bucket (117);
  - the CB radio: Walkie Talkie 7;
  - the arcade: "Save Game";
  - the cough: the 1988 pickup's rough start.

  The two that changed place (the walkie-talkie, Save Game) were loaded and played in Studio before the build.

## The grandeur pass (build `2026-10-15.205`, screenshots in `grandeur/`)

The owner, after walking .204: the mall "felt a little small for a mall, it doesn't really have that encapsulating grandeur you would usually expect from malls". They settled two of the calls left: the fountain stays in the middle, in front of the video store, and the shutter stays a see-through grille ("I like how that looks with the dark hallway beyond it"). Mid-pass they added: "Make sure that the areas for ads are intact and not messed up looking while still looking good and on theme".

**The choice: grow it up, not out.** The floor plan is unchanged, so every shop is still a few seconds from the fountain (their "not annoying or redundant"). The height and the view do the work.

- **Two storeys round the court** (`Mall.Galleries`, `MallBuilder` `buildGallery`):
  - The court is now 48 studs to the eaves (was 26).
  - A gallery 22 studs up runs round the north, south and west sides, with a parapet, a handrail and columns.
  - The floor above is the dead mall's: out of reach and dark, its shops shuttered or grilled under empty bulkheads, two marked FOR LEASE (`Mall.UpperFronts`, `buildUpperFront`).
- **A glass barrel vault over the court** (`Mall.Vaults`, `buildVault`): a half-ellipse of glass bands on ribs, with stepped gables, over the old skylight's whole void. The moon comes through it.
- **The dead mall's own things up high:**
  - a chandelier, dead, on its cord: a ring and six globes;
  - the SALE and SAVE banners hanging in the void;
  - the clock over the diner, stopped at 9:47.
- **The east end is a two-storey grille, 44 studs high**, taped across. Behind it the dead concourse is two storeys too, and longer (180 studs, was 112), with a gallery on both sides, four more dead fronts, a stopped pair of escalators up to a landing, and the battery EXIT sign far off. It is seen, never walked.
- **Light:**
  - The moon couldn't reach the floor from 58 studs up (Roblox lights reach at most 60 studs), and the court came out black.
  - It now hangs at 46 studs with a wide cone (95 degrees, range 60).
  - Three soft sky lights glow under the vault (`Config.Mall.Lights.skyglow`). They aren't on the generator, so a brownout leaves them.

**The ad lightboxes, kept intact and on theme:**

- **Nothing stands in front of one, or just beside one.**
  - The gallery's corner columns stood before the west boxes, so they went.
  - The new spec then caught two east columns before the east boxes.
  - Once those moved, a later check caught one of them half hiding the ARCADE sign. Now every column stands on the wall between two shopfronts, never before a sign.
  - `Logic/MallLayout` has two checks, both in `tests/specs/MallLayout`:
    - `adBlockers`: any solid block or column in the space out from a box's face, widening to 45 degrees either side, so a column off its corner that hides it from across the court counts;
    - `columnClashes`: a column in furniture, or before a shopfront.
  - The spec also holds every box to Roblox's billboard sizes (8 x 4.5 to 32 x 18 studs, near 16:9).
  - The same check moved the dead concourse's columns onto its walls between fronts, and turned blocks are now measured by their real box (an escalator was a 44-stud cube before).
- **The west boxes are larger**, 11 x 6.2 studs, the size of a mall's backlit poster case.
- **The placeholder reads now** (`4a_ad_before.jpg`, `4b_ad_after.jpg`):
  - The face was Neon, and its bloom burned the whole box to plain white.
  - It's an unlit panel now, a little bright (`Config.Mall.Lights.ad.face`): a diffuser yellowed with age, brightest where its tubes are, reading "THIS SPACE AVAILABLE · LEASING · ENQUIRE AT THE MALL OFFICE" in dark brown.
  - A brownout dims it with everything else on the generator (checked: down to 0.34 and back to 1.1).
  - LB6 puts the AdGui on the same face (`AdSlot` attribute).

**Checked in Studio** (build .205 synced, file lengths matched): no console errors in play.

| Shot | What it shows |
| --- | --- |
| `1_spawn.jpg` | From the spawn: the boutique, the video store and the arcade clear between the columns; the gallery and its dead upper fronts; a west lightbox |
| `2_vault.jpg` | Looking up: the vault's glass and ribs in moonlight, the chandelier, the upper fronts, the grille's top |
| `3_east_grille.jpg` | East: the two-storey grille over the fountain, two lightboxes either side |
| `4a_ad_before.jpg`, `4b_ad_after.jpg` | An east lightbox before and after the placeholder fix |
| `5_west_diner.jpg` | West: the diner and the boutique, both west lightboxes clear |
| `6_dead_hall.jpg` | Inside the dead concourse: the columns, the stopped escalators, the emergency lamps, the EXIT far off |

**For the owner:**

- Walk it (TC-309).
- Is the height enough, or does it want the floor plan wider too? A wider court lengthens every walk, so try the height first.
- The vault is dark at night by design (the moon and the storm light it), and lightning lights it best.

Everything new is grey-box until LB1b's Blender batch. The 50-player measurement is still LB1b's.
