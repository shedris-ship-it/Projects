# The visual rework, V4 (part 5): the puzzle stations and the house's devices, and their light

The owner asked for this batch with one brief: "make sure the light sources from this new batch like from the computer and the fuse box and the radio ect ect look really good". They also reported from their test:
- they didn't reach an heirloom, because the Guest got them first;
- throwing things in general works.

Mid-pass they asked for a note: "eventually we should make the kettle function by putting it on the stove and turning the stove on". It's in CLAUDE.md's findings.

## The batch (`tools/blender/kit.py kit7`, `kitlib/devices`)

18 pieces, built in the game's own frame round what lights or moves (that stays the game's).

| Piece | For | Kept, the game's |
| --- | --- | --- |
| HomeComputer | `Puzzles/Terminal`: a beige CRT monitor on a swivel stand, the breadbin keyboard, a dot-matrix printer with paper curling over its tractor | the screen (text, glow, prompt) |
| FuseBox, BreakerModule, BreakerToggle, MainSwitch | `Puzzles/Breaker`: the open box, its dead-front panel, its door swung aside with the schedule card; a body where each breaker sits, its toggle, the red main switch | the lamps |
| Radio | `PropFactory`'s Radio: a walnut cabinet radio on its side table, a fretwork grille, a brass bezel, bakelite knobs, a leaning aerial | the dial, the needle and the scale |
| WallSafe, SafeDoor, SafePainting | `Puzzles/Safe`: the riveted box, the door with its spoked handle and bolt-work, an evening landscape in a gilt frame | the dial (it holds the prompt) |
| MusicBox | `Puzzles/MusicBox`'s box: walnut and inlay, a pinned brass cylinder, the lid thrown back on a mirror, the key | the comb and the coloured teeth |
| LeverPlate, LeverArm | `Puzzles/Levers`: a cast-iron plate with cheeks and a pin, an iron arm with a turned grip | the lamp, the door's mark |
| Kettle, RecordPlayer | `InteractService`: a red enamel kettle; a suitcase record player with its record and tone arm | |
| BabyMonitor, TinRobot | `MonitorService`, `ToyService` | the monitor's lamp, the robot's eyes |
| BellBoard, Bell | `BellBoardService`: a mahogany board and its rails; each bell on its spring | the flags and the rooms' labels |

**Before the import:** the computer's keycaps lost a bevel segment, taking it from 12,700 triangles to 8,100.

## The light (`Config.Devices`)

None of these lights count as a lit room for the Guest (WorldService's light rule decides that). "Reduce flicker" holds them steady.

**The computer's screen** (`Terminal.tube`, `Controllers/DeviceController`):
- it is now a lit tube: a dark phosphor green, brighter in the middle and falling off to rounded corners, fine scanlines over it, the text bleeding a halo of its own green;
- a green light out from the glass falls over the desk, the keyboard and whoever sits there, and wavers a little, as a CRT's does.

**The fuse box** (`Breaker.show`):
- an amber lamp over each breaker, lit while it's on (and nothing has tripped);
- the main's lamp, green when powered and red when tripped;
- the open panel's warm glow on the wall, warmer the more breakers are on;
- the toggles tip up (on) or down (off), and the main switch drops when the main trips (`Kit.repose`).

**The radio** (`DeviceController`): while it plays,
- the dial lights a deep amber, its scale printed on it (station numbers, ticks, "STANDARD BROADCAST KC");
- a warm light falls over its table, breathing with the static;
- the needle wanders as if someone were tuning.

Off, the dial is a dull amber you still see.

**Small glows:** the lever's lamp casts a little amber or green light when lit; the baby monitor's lamp glows green on the top it stands on; the robot's eyes glow faintly.

## In the game

**How each is dressed:**
- `World/Kit.dressThing` dresses the stations' models where their builders put them.
- `Kit.place` adds what the grey-box has no part for (a breaker's body).
- `Kit.repose` moves a placed piece with its part (a toggle, the main switch, a lever's arm).
- `Data/Kit` `query`: the radio, the kettle and the record player are built from parts that never collide. Hidden, the hands' aim would look past them, so their model catches the ray. `InteractService.mainPart` hangs a fixture's prompt on such a model.

**Fixed after seeing it in Studio:**
- **The radio's dial** was a lemon glare that washed out the needle. It's now a deeper amber, a little clearer, with its printed scale on a clear pane before the glass: a gui on the lit Neon itself was drowned.
- **The fuse box's lamps** read lemon too; they're now amber.
- **The safe's painting, swung aside,** showed the wall through its back (the canvas is one face). A dark board now backs it, swinging with it.

## Seen in Studio (build .188)

The owner imported `kit7.glb` (18 meshes); 128 kit meshes loaded and the console was clean. Seen on seed 2, built for a squad of four on a full night:
- **The computer** (1, 2): its tube, text and scanlines, and the green on the desk and the wall.
- **The fuse box** (3): three lamps lit over the breakers that were on, dark over those that weren't, their toggles tipped to match. After F2 `solve breaker` the lamps and toggles followed the new state.
- **The radio** (4, then 5): on, with its scale.
- **The safe** (6, before its painting's backing): its door and the game's dial; "Work the dial" found.
- **The rest:** the lever (7), the bell board (8), the kettle on the range ("Put the kettle on" found on its model, 9), the nursery's robot and monitors (10).
- **Gate A** unchanged: parts 2441, hash 1845087318.

**Not checked in Studio:**
- the music box (no house of these seeds had it);
- the record player up close;
- a lever pulled down by hand;
- the main tripping.

They're in TC-292.

## Something to know

The owner's C: drive filled up during this pass: 13 MB free of 223 GB, and a write to Claude's scratch folder failed. CLAUDE.md records it. Claude deleted only its own scratch images and logs, and moved its scripts to the repo's ignored `build/scratch`. What's filling C: is the owner's to look at.

## Checks

619 tests, compile, selene 0 errors and 0 warnings, `rojo build`. TC-292.
