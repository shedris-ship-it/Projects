# The visual rework, V2 (part 1): light under doors, real windows, the night outside (builds `2026-10-12.171` and `.172`)

Studio, one client, seed 1800820264 (the mansion), at the in-game exposure.

## What changed

- **Light under shut doors** (`Controllers/DoorLightController`, `Config.DoorLight`): a shut door with a lit room behind it and a dark one in front shows a thin line of light in the gap and a small fan of light on the dark side's floor, in the lit room's own colour (hunt red during a hunt). Decoration only. A servants'-passage door never leaks: the builder marks its slab `HiddenDoor`, and attributes don't touch Gate A.
- **The torch's hot core:** your own torch adds a 30° core inside the 72° spill. The cone the stare rules use (`Config.Torch.Angle`) is unchanged.
- **Real windows** (`Logic/Windows`, spec'd; `World/MansionBuilder`; `Config.Window.Openings`):
  - A template's window on an inner wall moves to an outer wall of the same room.
  - Long outer walls get more: one per 14 studs, at least 10 apart, at most 3 a room. None in the cellar, the passages or the stairwells, and no extras in double-height rooms or the attic.
  - The outer wall gets a real hole: wall below the sill and above the head (`wallBand`).
  - The window drops its painted night. An invisible bar fills the opening so nobody climbs out; the window faces outside, where he never is, so it hides nothing from him.
  - Seed 1800820264 went from **2 windows to 16**. The planners read `RoomFit`, which is unchanged: the layout hash is the same (611557569).
- **The night outside** (`World/Exterior`, `Config.Exterior`):
  - a lawn and a gravel drive from the front door (both solid: the porch steps out onto them at the end);
  - a ring of bare autumn trees thinning into the fog (162 trees, about 1,100 parts);
  - a sodium streetlamp at the end of the drive, whose glare carries far (`ConsensusGlare` tag, `Config.Lens.Glare.Far`);
  - a **sky ring** of panels just past the trees, a moonlit gradient fading up into the real sky. Roblox's night sky is black, so dark trees against it showed nothing (shot 2); at radius 200 the fog swallowed the ring, at about 110 it reads (shot 5);
  - the run's moon (`Logic/WindowView`) with a halo, where the windows that face it would see it.
- Trees are stand-ins built from parts until the kit's Blender trees (V4d). Part-built pines read as snowmen (shot 6), so they're out for now.

## Shots

| | |
| --- | --- |
| `1_light_under_the_door.jpg` | The main corridor dark, the grand hall lit behind the door |
| `2_window_opening_no_outside_yet.jpg` | A real opening, before the outside existed |
| `3_window_onto_the_night.jpg` | The dining room's window: the moonlit sky and tree trunks behind sheer curtains |
| `4_outside_trees_moon.jpg` | From outside: tree silhouettes against the horizon, the moon |
| `5_sky_ring_first_test.jpg` | The sky ring's first test |
| `6_part_pines_read_as_snowmen.jpg` | Why the pines went |

## Checks

600 tests pass (Windows.spec new); compile; selene 0/0; rojo build. **Gate A unchanged: parts 2269, hash 1553234744** (checked in Studio, the old house). Clean consoles.

## Fixed later (build `.177`): the window that showed wallpaper

The owner's screenshot of seed 111612098: the dining room's window showed pink wallpaper behind the glass.

- **The cause:** the wall itself had its hole, but the seam's wall skin covered it. `Trim.seam` papers the wall either side of a doorway that can flip (a thin, opaque, non-queryable `WallSkin`), out to the corner or halfway to the next doorway. A window in that stretch of wall sat behind the paper. Rays skip non-queryable parts, so a raycast check showed nothing there.
- **The fix:** `MansionBuilder` remembers each room's windows per side (`windowsByRoom`) and hands them to the seam's faces (`holes`). `Trim`'s `skinAround` lays the skin around each hole: a strip beside it, a piece under the sill, a piece over the head. The fix applies to the wall pieces, the doorway pieces either side, and both seam states.
- **The outside walls got a facade** (`Config.Exterior.Facade`: grey-green clapboard, `WoodPlanks`). A courtyard house shows its own other wing through its windows, and it showed wallpaper on the outside of that wing. Now it shows the outside of a house.
- **Checked in Studio:**
  - Seeds 111612098, 165547210 and 1316117598: every open window (21, 19 and 22) checked for anything in the 3 studs behind its glass. Each test ran a segment against every part's box, so non-queryable parts count. None found.
  - Gate A unchanged: parts 2269, hash 1553234744.
- **Why the first Studio check still showed the bug:** `tools/serve-mirror.sh` had kept an older copy of `Trim.luau`. The editor saves through a temporary file and a rename, so the new file arrives with the temporary file's earlier time. The mirror copied the old file just before the rename and stamped its copy as newer, so it never copied again. Now each copy carries its source's time, read before copying, and any difference in time copies it again. This may also explain the 2026-10-11 note that Rojo "stopped applying edits to existing scripts".

| | |
| --- | --- |
| `7_window_covered_by_wall_skin.jpg` | Before: the dining room's window on seed 111612098, papered over |
| `8_window_onto_the_courtyard.jpg` | After: the courtyard, the other wing's clapboard and its window |

## Fixed later (build `.178`): denser foliage

The owner, after seeing the night through the new windows: "the outside of the windows definitely looks better, I would just want more dense foliage out there".

- **Placement:** a new pure module, `Logic/Grounds`, decides where every plant stands. `Grounds.spec` checks it over 24 houses: nothing in the house, on the drive or before the front door; tall evergreens never in front of a window; at least 200 trees and 150 bushes; within the part budget; the same seed gives the same grounds.
- **The woods**, about 440 trees instead of 162, starting 12 studs from the house instead of 16:
  - old trees, mostly still in leaf (`LeafShare` 0.7), with lumpy crowns of 4 to 7 masses of leaves at different heights;
  - young trees under them (8 to 14 studs tall);
  - dark conifers, built as tall narrow tiers so they read as spires;
  - the rest bare.
- **Under the trees:** undergrowth thick in the woods, and a few bushes out on the lawn.
- **The garden** along every outside wall, courtyards included: low shrubs whose tops stay under the ground floor's sills, and tall narrow evergreens (arborvitae, as 1988's gardens had) only between windows. Each plant knows its distance to the house and never reaches it, so no leaves poke through a wall.
- **The lawn is terrain grass**, which Roblox draws with blades. It's cut away under the house (where the blades would show through the ground floor) and under the drive, and `WorldService:Clear` takes it away between runs (`Exterior.clear`).
- **Cost:** about 3,800 parts on seed 1800820264 (the house itself is about 3,100). Plants out in the fog are built with fewer, bigger masses (`FarFrom`), and `Config.Exterior.PartBudget` is 5,500.
- **Still stand-ins** built from parts: the Blender trees replace them in V4d.

| | |
| --- | --- |
| `9_woods_before.jpg` | Before: bare trunks, an open black lawn |
| `10_woods_dense_first_pass.jpg` | After, the first pass: a wall of crowns against the sky, undergrowth below (it's raining by then). Their round undersides lined up like mushrooms, so the second pass added crowns at different heights, young trees and conifers |
| `11_woods_second_pass.jpg` | The second pass, the same spot: a ragged skyline, conifer spires, the sky only in gaps |

## Next in V2

Moonlight through the windows with real shadows (the moon direction set to the run's moon), the storm (rain on the glass, lightning, a Guest beat), fireplaces, retuning the room lights for PBR.
