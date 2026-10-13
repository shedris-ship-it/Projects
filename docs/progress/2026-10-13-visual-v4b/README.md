# The visual rework, V4 (part 2): the living rooms, the study and the bedrooms; the TV's static (build `2026-10-13.185`)

The owner, after the first rollout batch: "It looks better than before for sure, lets continue." This second batch, `kit4`, takes the living rooms', the study's and the bedrooms' furniture. Mid-batch the owner asked for one more thing: "make the TV so that when you turn it on it has white noise + the static ... the white noise should obviously have a lighting effect."

## The batch (`tools/blender/kit.py kit4`, `kitlib/living`)

| Piece | Size (studs) | Triangles | For |
| --- | --- | --- | --- |
| TV stand | 6 × 8.05 × 2 | 3,692 | a 1988 console set: wood-grain cabinet, dials, grille, rabbit ears; a VCR whose clock glows 12:00, a row of tapes |
| Table | 8.24 × 3.42 × 5.24 | 6,128 | a table under a long linen cloth, its hem 0.45 off the floor |
| Desk | 7 × 3.41 × 3.5 | 2,096 | a walnut writing desk with a leather inset and a pleated skirt across the kneehole |
| Desk drawers | 2 × 1.8 and 2 × 0.95 | 404 each | its deep and shallow drawers' fronts |
| Cabinet | 6.02 × 7.99 × 3.2 | 924 | a walnut linen press, two shelves inside |
| Cabinet doors (L, R) | 2.97 × 7.4 | 1,240 each | raised panels, a brass bar handle |
| Wardrobe | 6.02 × 8.99 × 3.2 | 1,292 | the same carcass with a hat shelf and a rail |
| Wardrobe doors (L, R) | 2.97 × 8.4 | 1,960 each | louvred at the eye |
| Curtain | 6.4 × 9.74 × 1.41 | 4,412 | oxblood velvet on a brass rod, parted in the middle |
| Piano | 7 × 5 × 3.03 | 7,356 | an upright in black lacquer, open keys, candle sconces |
| China cabinet | 8.1 × 8.92 × 2.13 | 7,928 | plates on their edges, cups, a cupboard below (a Shelf named `china*`) |
| Steel shelving | 8 × 9 × 2 | 4,396 | tins, jars, cartons and bottles (a Shelf named `shelf*`: the pantry, laundry, garage, storerooms, sewing room) |
| Dress form | 1.63 × 6.49 × 1.43 | 1,408 | a linen torso on a walnut tripod, a faceless egg of a head, a red lace collar (Mannequin) |
| Rocker | 2.39 × 3.98 × 2.44 | 4,088 | the nursery's rocking chair (a Chair named `rocker*`) |
| Stool | 1.82 × 2.2 × 1.75 | 2,340 | the music room's piano stool (a Chair named `stool*`) |

**The hiding pieces keep the game's gaps exactly:**
- **The tablecloth's and the desk skirt's hem:** at `PropFactory.ClothHem` (0.45), where you look out from under them.
- **The wardrobe's louvres:** a band 2 high round the standing eye, nine slats at the game's 35° tilt.
- **The curtains' parting:** 0.2 wide in the middle, the same as `FoldGapL` and `FoldGapR`. The cloth hangs over half a stud in front of where you stand behind it.
- **Seen from inside:** every cloth is solid, so it shows from inside too.

**Hanging points:**
- The doors and drawer fronts are built round the middle of the grey-box part they hang on.
- A wardrobe door hangs on its lower leaf, under the louvres, so its middle is 2.375 above that.

**Thinned before the import:** the tablecloth went from 12,200 triangles to 6,100, and the curtains from 10,800 to 4,400. Bounds checked against `Kit.spec`'s 8%: the armoire's cornice was trimmed and the shelving's clutter kept inside its uprights.

## In the game

**`World/Kit` and `Data/Kit`:**
- **One kind, many things (`others`):** a kind can stand for more than one thing. A Shelf is a bookcase (`books*`), a china cabinet (`china*`) or steel shelving (`shelf*`); a Chair is a dining chair, a rocker or a stool. An item wears the first entry that names it (`Kit.choose`).
- **`floor`:** a piece whose box starts above the floor; the curtains hang clear of it.
- **`rises`:** a piece taller than its kind. The TV stands on its stand, so `Kit.spec` holds it to the footprint only.

**Moving pieces:**
- the desk's two drawers (two meshes, matched by name);
- the cabinet's and the wardrobe's doors (left and right meshes, so the handle sits by the gap);
- the wardrobe's unseen pane, which stops his sight, stays as the game's.

## The TV's static (`Controllers/TVController`)

The TV already had a "Turn up the static" fixture, a hiss the Guest hears as a lure (he also works it himself). It now shows on the set:

- **What the server sends:** `Services/InteractService` marks a running fixture's model (`Running`).
- **The snow:** each client draws snow on the screen. It's one noise sheet, drawn once into an EditableImage (no upload) and shown a window at a time at a new place 30 times a second, with a dark band rolling slowly down.
- **The light:** a cold blue-white light jumps with the snow.
- **Asleep:** a set further than 70 studs away sleeps.
- **Reduce flicker:** 8 flips a second, and the light holds still.
- **The rules:** decoration only; nothing of it counts as lit.
- **The setting it needs:** EditableImage needs the experience's "Allow Mesh / Image APIs" (Game Settings → Security). The owner turned it on on 2026-10-13. Without it the set falls back to two layers of the lens's film-grain frames (`Assets.Lens.Grain`).

**The light, fixed in Studio:**
- **First try:** a SurfaceLight on the screen. Its cone missed everything near the set, and the room stayed black around a glowing screen (shot 1).
- **The check:** a test point light lit the room and showed the set itself (shot 2).
- **Now:** a PointLight 0.6 out from the glass, shadowed, so the set's own cabinet shades the wall behind it (shot 3): a cold glow over the carpet, the rug and the ceiling, and the stand's long shadow on the floor.

`World/PropFactory`'s TV is laid out to match the model: a 5.2 by 3.4 cabinet with its screen (3.6 by 2.6) left of the control panel. The screen is tagged `ConsensusTV`. `Config.TV` holds the tuning.

## Seen in Studio (seed 3, build `.185`)

- **`[Consensus] kit: 55 meshes loaded`**, no failures; the console was clean apart from the DataStore warnings.
- **What dressed in seed 3:**
  - the TV;
  - two clothed tables;
  - the desk and its drawers;
  - the cabinet and its doors;
  - the china cabinet;
  - the laundry's shelving;
  - four sets of curtains.
- **The TV's static** in the dark living room (shots 1 to 3), drawn from the EditableImage.
- **The kitchen's clothed table** (shot 4): the hem's gap under it, the lantern and radio on top.
- **The study's desk** (shot 5): both drawers out (F2 `furniture open`), the skirt across the kneehole.
- **The dining room's cabinet** (shot 6): opened, its doors swung wide, the shelves inside.
- **Not in seed 3** (not seen yet; TC-289): the wardrobe, the piano, the dress form, the rocker and the stool.

**Gate A re-baselined:** parts 2412, hash 1055006600 (2388 and 1667624079 before).

**Checks:** 616 tests, `tests/compile`, selene 0/0, `rojo build`.

## Not done yet

- **The rest of V4:**
  - the bedrooms' beds, closets and crib;
  - the lockers and tall cupboards;
  - the kitchen and bathroom (counter, fridge, stove, sink, toilet, bath, washer);
  - the utility rooms' boiler, water heater, tank and workbench, the car, the wine rack;
  - the front door.
- **The tablecloth:** it reads as a plain box from across the room. Deeper folds would help, in a later pass.

## Shots

- `0_kit4_blender.png`: the batch in Blender's preview.
- `1_static_first_light_missing.jpg`: the static on, its first light (a SurfaceLight) reaching nothing.
- `2_tv_under_a_test_light.jpg`: the set and its stand, under a test light.
- `3_static_lights_the_room.jpg`: fixed, the static lighting the living room.
- `4_kitchen_clothed_table.jpg`: the kitchen's table under its cloth.
- `5_study_desk_drawers_skirt.jpg`: the study's desk, its drawers out.
- `6_cabinet_doors_open.jpg`: the dining room's cabinet, opened, under the torch.
