# Playtest fixes: windows and dust

Fixes from the owner's playtest notes (2026-10-02). Baseline seed (`seed 1800820264`) unless noted.

## Windows only on outside walls

**The bug:** a room template puts its window on a fixed side, and the generator turns rooms at random, so a window could end up on a wall shared with another room. In the owner's run the guest room's moonlit window backed onto the kitchen, and every one of that house's six windows faced another room.

**The fix:**
- After choosing templates, the generator turns each room with windows so they land on outside walls (`orientWindows` in `Logic/LevelGraph`). It uses no randomness, so the rest of the house a seed builds is unchanged.
- A window that still can't face outside (a room in the middle of the house) is left out. If it was the room's light, the room's ceiling lamp takes over.
- The "Sealed window" clue now only goes on outside walls too.
- Across 1,000 generated houses, 77% of windows face outside; the rest are left out. 14% of the rooms that are lit by their window lose it, because they have no outside wall.

In the baseline house all eight windows now face outside, and the Attic Landing (in the middle of the house) uses its ceiling lamp. `08_nursery.jpg` is the baseline nursery angle: the nursery has turned so its window is on the outside wall behind the camera, and the moonlight now picks out the doorway on the right, which was lost in [step 1b](../2026-10-02-step1b-lighting-v2/README.md).

## Dust fades with the light

**The bug:** each room's dust filled one box around its light, evenly bright, and stopped at the box's edge while the light kept fading (`dust_before_owner_run.jpg`, the owner's run, sewing room lamp).

**The fix:** four nested layers of dust around the light, each kept inside the room. They add up to thick, bright dust at the lamp that thins to faint at the edge, so there's no edge to see. Each layer is set by density (motes per cubic stud) rather than a fixed count, so a lamp in a corner, whose layers the walls cut short, doesn't pack its dust tighter. An early version did, and showed big blurry motes right in front of the camera beside a corner lamp. Values are in `Config.PostFX.DustLayers`.

- `dust_after_foyer_lamp.jpg`: the foyer lamp from across the room.
- `dust_after_foyer_lamp_closer.jpg`: closer, with the kitchen's ceiling-light dust through the doorway.
