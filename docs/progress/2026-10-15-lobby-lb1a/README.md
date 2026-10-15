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
