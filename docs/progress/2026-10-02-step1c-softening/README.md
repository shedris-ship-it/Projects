# Visual pass step 1c: softening and atmosphere

Same seed and camera spots as the [baseline](../../baseline/2026-10-02/README.md) and [step 1b](../2026-10-02-step1b-lighting-v2/README.md). Compare `07_kitchen` with step 1b's for the clearest before and after.

**What changed** (details in [ART.md, "Softening the image"](../../ART.md)):
- Bloom threshold lowered, so lamps, windows and screens halo. It's set just high enough that lit pale surfaces, such as a face, don't glow.
- Fine animated film grain, using the noise tile that ships with Roblox. It's darkened so it doesn't lift the blacks, it grows with Drift, and "Reduce grain" turns it off.
- Gentle depth of field: sharp to about 40 studs, soft beyond.
- Softer shadow edges (`ShadowSoftness` 0.6).
- Dust drifting in every room, visible only inside lamp and window light. Look for the specks in `05_foyer`.
- Lights within 30 studs of The Guest sag to as low as 55%, easing in and out. Measured in Studio: a lamp 18 studs from it dropped from 2.4 to 1.66 brightness.
- The flashlight's aim trails slightly behind quick turns.
- Fix: a room light whose light object replicated after its part was never tracked, so it couldn't flicker or dim. In this seed's mudroom that also meant no dust.

Tried and dropped: Atmosphere haze. Even at double density it barely shows across a 40-stud room.

In `05_foyer` the Companion's head no longer glows, and The Guest is standing in the left doorway.
