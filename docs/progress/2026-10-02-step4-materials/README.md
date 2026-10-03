# Visual pass step 4: materials and grime

Step 4 of [`docs/ART.md`](../../ART.md). Baseline seed (`seed 1800820264`) and camera spots. The "before" for each numbered file is the one of the same name in [step 3](../2026-10-02-step3-trim-and-doors/README.md), taken earlier the same day.

**What changed**
- **Ten house materials** (`Data/Materials.luau`): sprig wallpaper, striped wallpaper, old plaster, popcorn ceiling, oak boards, wood panelling, low-pile carpet, checkerboard linoleum, small hex tile and stained concrete. Each has a normal map, so it catches the light (see the dining room's floor and the corridor's walls).
- **Greyscale and tinted.** The part's colour tints each texture, so one wallpaper covers the sage, rose and blue rooms. Every room template now names its surfaces and colours from the ART.md palette (`Data/Rooms.luau`), and ceilings are one shared popcorn off-white with a hint of each room's wall colour.
- **Wainscot** (dark panelling under a dado rail on the lower third) in the formal rooms: dining room, study and music room. It splits around doorways and flips with seams like the baseboard.
- **A grime layer** (`World/Grime.luau`) placed from the seed, so every player sees the same aging:
  - water stains on about 40% of ceilings
  - rust under some windows and in utility rooms
  - scuffs low on walls
  - clean patches where a picture once hung
  
  In the baseline house that's 24 decals. Fairness: wall grime keeps 8 studs from every seam and 4 from every clue spot and wall decoration, so it never hints at a doorway or looks like evidence. Corridors only get ceiling stains. Checked in Studio: none within 8 studs of a seam, none collidable or hit by rays. `ceiling_water_stain.jpg` shows one, faint on purpose.

**Seams stay invisible.** Roblox starts a texture's pattern afresh on every part, so a patterned wall built from pieces would show a door-shaped outline around each hidden doorway panel, and players would learn to spot divergences by it (ART.md rule 3). Each seam now gets a thin skin over both wall faces: one unbroken piece while it reads as a wall, three around the opening while it reads as a doorway, flipping with the seam like the trim. `seam_skin_test_brick.jpg` is a test with Roblox's brick material on the kitchen wall: no outline where the panel sits.

**How the textures were made.** Studio's AI material generator failed on every request with an internal error, so `tools/textures.py` draws them from code: seeded, seamless, 1024 px, with the colour maps as JPEG and the normal maps at half size to keep the repository small. Sources are in `assets/textures/`; `texture_sheet.jpg` shows them tinted as they appear in the house. All 26 images were uploaded to the owner's account with their approval, and the ids are in `Assets.luau`.

**MaterialVariants live in the place, not in scripts.** Game scripts can't create MaterialVariants at runtime (Roblox blocks it), so `lune run tools/materials` writes one Rojo model file per material into `assets/materials/`, which `default.project.json` syncs into MaterialService. `tests/specs/Materials.spec.luau` fails if those files drift from `Data/Materials.luau`.

**Tuning along the way:** the linoleum squares started too small and busy, so they're now 1.4 studs across and the floor colour is toned down.

**Not checked:** fps with the new textures (please read F2 in the next playtest), and the low-graphics look. A few close-up captures inside the kitchen came out black. The same spot rendered fine earlier, the light was on and nothing blocked the camera, so it looks like a capture quirk rather than a game problem. Worth a glance when you play.
