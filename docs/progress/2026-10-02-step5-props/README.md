# Visual pass step 5: hero props and fixtures

Step 5 of [`docs/ART.md`](../../ART.md). Baseline seed (`seed 1800820264`) and camera spots; the "before" for each numbered file is the one of the same name in [step 4](../2026-10-02-step4-materials/README.md). The seed still builds the same house with the same evidence (`failing_key@10, repeating_painting@8, rewritten_note@13, ~looping_sound@9`).

**A fairness fix came first.** The only wall clocks in the house were "Clocks disagree" clue clocks, and the only radio was the "Radio only some can hear" clue radio, so spotting either one gave the clue away. Now three decorative wall clocks and two decorative radios go into spots no clue used. They're built by the same builders with the same attributes as the clue versions, and the clocks show times from the same pool, so a clock or a radio on its own is never the clue. They're placed after the clues, so evidence placement is unchanged for every seed.

**What changed**
- **Clocks** show the time with hands (`Logic/ClockFace`, tested): a 1980s wall clock with a wooden rim, cream dial, ticks and hands (`wall_clock.jpg`, reading 7:40). The grandfather clock gets the same face, a hood, a glass door and a pendulum (`grandfather_clock.jpg`; it used to say "XII"). A clue clock that shows a different time to each player moves its hands.
- **Radio:** a 1970s cabinet radio on a side table, with a fabric grille, a faintly lit tuning dial, knobs and an aerial (`radio.jpg`).
- **Telephone:** a beige rotary phone on a hall or foyer surface (`telephone.jpg`).
- **Family photos** in standing frames on dressers, chests, desks and the piano: three faded snapshots drawn in code (`photo_sheet.jpg`). They age with Drift for everyone at once: the faces blur from 60 and are gone from 80 (`photo_normal.jpg`, `photo_faceless_drift85.jpg`). Photos are never Witnessable, so they're never mistaken for clues.
- **Ceiling lights:** a hanging drum pendant replaces the flat glowing slab everywhere except utility rooms, which get a flush fluorescent tube (`06_dining_room.jpg`, `07_kitchen.jpg`, `corridor_pendant.jpg`). The pendant's shade stops above The Guest's height.
- **Floor lamps:** a fabric drum shade glowing from inside, trim bands and a finial.
- **Hunt red:** during a hunt the house's lamps ease to the reserved hunt red, and back again afterwards; windows and TVs don't (`hunt_red_corridor.jpg`, taken just after the stalker caught the tester, hence the downed tint). Lamp shades and bulbs also dim and go out with their light now, so a room blackout no longer leaves glowing shades.

**Bug fixed along the way:** applying settings (for example closing the settings dialog) switched shadows on for every small part in the house, including parts built not to cast shadows: window glass, lamp trim, clock hands. It showed as dark ovals on the ceiling and floor around the new lamps. The low-graphics toggle now only restores shadows it removed itself (`09_master_bedroom.jpg`).

**Tried and dropped:** window light shafts. A soft beam from each moonlit window barely showed from the side and looked like a flat card from the front. Without volumetric light, this trick needs a purpose-made soft texture to read, so it's left out for now (`nursery_window.jpg` shows the room without one). It can be revisited with one extra texture upload.

**Not checked:** fps with the new props (about 40 parts per pendant, clock and radio). Please read F2 in your next playtest.
