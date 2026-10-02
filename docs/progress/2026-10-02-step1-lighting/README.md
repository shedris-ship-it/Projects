# Visual pass step 1: lighting, grade and ceilings

After-shots for step 1 of [`docs/ART.md`](../../ART.md). Same seed and camera spots as the [baseline](../../baseline/2026-10-02/README.md), so files with the same number compare directly. No flashlight in any shot.

**What changed**
- Ceilings dropped from 12 to 10 studs (`Config.Level.WallHeight`).
- Every room keeps one shadow-casting key light, now in the ART.md palette (`Config.Lighting`), and gains a shadowless fill under the ceiling centre. Its colour comes from the room's family (`family` in `Data/Rooms.luau`): tungsten for living rooms and corridors, moonlight for bedrooms and window rooms, fluorescent for utility rooms. Rooms lit by a window or TV get a stronger fill, standing in for a lamp.
- Global light: olive ambient and atmosphere `(35, 38, 30)` so shadows lean olive rather than black; exposure 0 (was −0.15).
- Grade in `EffectsController`: Calm starts at saturation −0.22, contrast 0.15, tint `(236, 236, 200)`, and still decays towards the green-grey decay tint as Drift rises.
- Room blackouts and flickers now take the fill with them; fills never cast shadows, including after low-end mode is toggled.

**Result:** every room passes ART.md rule 1. Doorways and furniture shapes read without the flashlight, where the baseline was more than half black in most rooms. The living room is still the darkest, mostly because of its near-black rug and sofa; the materials step fixes that.

**Tip for retakes:** Future lighting needs about a second to settle after the camera jumps. Point the camera first, wait 1.5 s, then capture, or the first shot comes out too dark.
