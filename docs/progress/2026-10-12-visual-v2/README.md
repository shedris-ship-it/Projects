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

## Next in V2

Moonlight through the windows with real shadows (the moon direction set to the run's moon), the storm (rain on the glass, lightning, a Guest beat), fireplaces, retuning the room lights for PBR.
