# Visual pass step 1b: lighting v2 and the Companion

Second lighting pass, after the owner's playtest: *"more range, but a bigger brightness gradient that fades to darkness more."* Same seed and camera spots as the [baseline](../../baseline/2026-10-02/README.md) and [step 1](../2026-10-02-step1-lighting/README.md), so files with the same number compare directly. No flashlight in any shot.

**What changed since step 1**
- The flat ceiling-centre fill lights are gone. They lit rooms evenly, and because they cast no shadows they leaked through walls.
- Key lights reach much further and are brighter (lamps 44 studs at 2.4, windows and TVs 40, ceiling lights 1.5× their template range), so each one throws a pool that fades across the room.
- Window and TV rooms get one soft bounce light just in front of the window or screen: moonlight for windows, warm for TVs. It casts shadows, so it stays inside the room.
- Ambient light lowered to `(24, 26, 20)`, so darkness is real.
- The solo Companion no longer carries a light. It keeps 8–16 studs back instead of walking into you, walks instead of sprinting unless it's far behind, turns to look where you're looking, and if it gets lost it reappears behind you rather than beside you. Its Focus-sharing radius widened to 16 studs (`Config.Witness.CompanionRadius`), so solo Focus regeneration is unchanged.

**Result:** rooms now have a clear light source and a gradient into darkness, and materials show texture under the raking light (rug weave, tiles, plaster). The moonlit bedrooms are now the darkest rooms: in `08_nursery` the doorway on the right is lost without the flashlight. Door trim (step 3) should bring it back.

**Lessons for retakes**
- Wait about 6 seconds after moving the camera or changing lights before capturing. Future lighting rebuilds slowly, and early captures come out black.
- Confirm `seed` with its on-screen reply before `start`; the first command typed right after opening the console can be dropped.
