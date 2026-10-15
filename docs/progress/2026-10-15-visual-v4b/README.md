# The visual rework, V4b: ceiling roses, coffered ceilings, radiators and pocket doors (build `2026-10-15.196`)

The owner: "Lets finish up V4 with V4b". For the plan's double doors, the owner picked **pocket doors in the archways** (2026-10-15, "Pocket doors (Recommended)"), and asked: "Make sure you check for bugs with the doors after, since when we redid the windows they had a bug to where they would appear where they shouldn't be". Mid-pass, about the ceiling light added to show the coffers: "Make sure the end result of that ceiling light isn't a square on the ceiling ... Unless the shadows are really just casting that way due to the ceiling design". Both are covered below. One import from the owner (`kit.py kit10`, 8 meshes).

This finishes the plan's V4: the house's architecture and every prop are Blender models.

## The pieces (`tools/blender/kitlib/ornament.py`, batch `kit10`)

Blender previews before baking: `0_preview_coffers_rose_arch.jpg`, `0b_preview_rose.jpg`, `0c_preview_radiator.jpg`, `0d_preview_pocket_door.jpg`.

| Piece | What it is | Triangles |
| --- | --- | --- |
| CeilingRose | a plaster medallion, 2.6 across: a ring of acanthus leaves round a boss, beaded and moulded rims | 3,344 |
| CeilingRoseLarge | the grand hall's, 4.8 across, two rings of leaves | 5,416 |
| CofferBeamWood / CofferBeamPaint | a coffer beam's moulded section (a cove each side), 4 long, stretched to each run (`fit`) | 110 |
| CofferBossWood / CofferBossPaint | the carved boss where two beams cross | 280 |
| Radiator | a 1920s cast-iron column radiator in old cream enamel: 16 sections of three tubes, a brass valve and its pipe, on feet | 5,344 |
| PocketDoor | a walnut leaf slid into its wall: the edge with a brass pull, the dark slot round it | 840 |

The first build was far too heavy (the radiator 45,000 triangles, the roses 13,000 and 27,000); they were rebuilt lighter before the import. A test of every piece from every angle a player can see it from found no hole: Roblox draws a face from the front only (`build/scratch/v4a/backface.py`).

## Where they go

- **Ceiling roses** over every hanging pendant, and the large one over the grand hall's chandelier (`World/LevelBuilder`'s fixture). None under the attic's rafters or the cellar's joists, and none over a bare bulb or a fluorescent fitting. The old house has them too.
- **Coffered ceilings** in the formal rooms (`Data/Rooms` `coffers`; `World/MansionBuilder`; `Config.Mansion.Coffers`): walnut in the dining room and study, painted cream in the living room and music room, over smooth plaster (those rooms' ceilings are plaster now, not popcorn). A grid every 6 studs, laid from the ceiling light so the lamp hangs in the middle of a coffer, 1.5 studs clear of the walls, with a boss at each crossing. Not in double-height rooms.
- **Radiators** under the real windows of the ground and upper floors (`World/PropFactory`'s window; not the attic). Windows only go where nothing stands within 3 studs of the wall below them (`Logic/Windows`), so a radiator never meets furniture. A radiator is solid, like furniture, but the hands' aim passes it.
- **Pocket doors** in each archway's jambs (`World/Trim`): a pair of walnut leaves slid into the wall, their edges and brass pulls showing. They never collide and stand outside the doorway's lanes. They're tagged like the archway's own lining, so they're shown exactly while the archway is a doorway.

Nothing is placed without its mesh (`Kit.place`, `Kit.swap`, `Kit.dressPart` do nothing for a mesh that isn't in), so nothing grey-box ever stood in for these.

## The ceiling glow (`Config.Lighting.CeilingGlow`, `Controllers/EffectsController`)

In the game the coffers didn't show at all (`1_dining_before_glow.jpg`). A ceiling lamp's light is a downward cone (`Config.Lighting.CeilingSpot`, since the owner's 2026-10-04 note about "a hard square patch on the ceiling"), so every ceiling is black above its lamp.

A real drum shade also throws light up out of its open top. Now a pendant or chandelier under a rose does the same: a soft upward light under it lights the rose and the ceiling around. Each client draws it from its lamp, so it dims, flickers, turns red in a hunt and goes out with the lamp. It never counts as light for the rules (`WorldService`'s light rule is unchanged).

**The square:**
- The 2026-10-04 square came from a light sitting just under the shade, inside the shadow map's near plane. A first try at 1.1 studs under the ceiling only grazed it, lighting the rose and none of the plaster round it.
- The glow sits 4 studs under the ceiling, below the pendant. A plain ceiling gets a round halo that fades into the dark, with no edge (`3_corridor_rose_glow.jpg`).
- On a coffered ceiling, the light reaches the lamp's coffer and the ones round it, and the walnut beams throw their own shadows between them (`2_dining_coffers_glow.jpg`). The edges you see are the beams', and no one coffer stands out as a bright square. At 3 studs down, the lamp's own coffer was much brighter than the rest, so it was moved down and made a little dimmer.
- The grand hall: the large rose, the chandelier's arms shadowed on the ceiling (`4_hall_chandelier_rose.jpg`).

It casts shadows, which keep it off the floor above, so it's only on presets where room lights cast shadows (Cinematic and Balanced). Performance has none.

## The owner's door check: "they would appear where they shouldn't be"

The window bug was a wall covering that hid an opening. Pocket doors could go wrong the same way. They could stand on a doorway that isn't an archway, show while the archway reads as a wall, sit out of their jamb, or poke through something. A check run in Studio on every pocket door in four houses: seed 7 for one player, seed 4 for one, seed 6 for four and seed 7 for four. These are the houses that build an archway on the default short night.

- Exactly two pocket doors per archway. None on any of the 18 to 29 plain doorways in those houses, and no archway without them.
- Each is shown exactly while its archway's lining is, tagged as the seam's doorway trim (role "door"). Nothing in the game changes seam trim after the house is built. Archways are only made between connected rooms in the same locked region (`Logic/MansionGen`), and no lock or crank shutter is ever put on one (`Logic/LockPlanner`). So an archway is always open, and its doors always show.
- Each is the kit mesh, never collides and never catches a ray. It is within 0.4 studs of its jamb's lining and 7.9 tall.
- Measured against the walls: each leaf reaches 0.04 studs into the end of its wall (its hidden end, as designed). It stays inside the wall's thickness, ±0.13 against 0.25 a side, so nothing shows through either room's wall.
- In the game: `5_archway_coffers_radiator.jpg` shows the living room's archway into the music room, its painted coffers, a radiator under the music room's window. `6_pocket_door_jamb.jpg` shows a leaf's edge, pull and slot in the jamb.

The same kind of check, for the radiators and coffers in the seed-7 house for four:
- **17 radiators:** each on its floor (within 0.05), its back to its window's glass, its front into the room, touching nothing.
- **106 coffer pieces in four rooms:** none touches anything but the ceiling.

## Gate A re-baselined

The roses are on the old house's pendants too. F2 `layout cells`, `seed 1800820264`, `gatea`, twice: **parts 2456, hash 116728396** (from 2451, 2057680657: five roses). The coffers, radiators and pocket doors are the mansion's only. The ceiling glow is drawn on each client, so it isn't counted.

## Checks

- stylua, selene (0/0), compile (267 files), the unit tests, `rojo build`.
- In Studio: the meshes loaded (254), the dining room and corridor before and after the glow (`2_dining_coffers_glow.jpg` with the final settings), the grand hall, the archway from both rooms, the door check on four houses, the radiators and coffers checked against everything round them, a clean console (Roblox's own network noise only).
- The glow follows its lamp, read every 3 s through a forced hunt (F2 `tier 4`): red with the lamp as the hunt began, warm again after, red again with the next. F2 `lights off` put it out with the lamp, and `lights on` brought it back. An early live test, before the glow was tied to its lamp, had it staying warm in a hunt; that's why it now takes the lamp's colour every frame.

## Not checked

- The glow's cost on a phone (one more shadow-casting light per pendant; Performance has none).
- An archway on the full night (`Config.Run.Night` is short by default). Archways are made the same way there, so the check should hold.
- The study's coffers by eye (they passed the touch check; the dining room shows the same walnut ones).
