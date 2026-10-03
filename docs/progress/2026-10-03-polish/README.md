# Polish pass (2026-10-03)

Owner: fix the exhausted voice and the bathroom reverb, then polish the base gameplay visuals and audio as far as possible. Stages: 0 bugs and baseline, 1 audio gaps, 2 period avatars, 3 first-person presence, 4 props and rooms, 5 Drift arc and lighting. The Guest's head, hands and jumpscare are left alone for now.

## Stage 0: bugs and baseline

- **Bathroom reverb.** Cause: `SoundService.AmbientReverb` already gives every sound its room's reverb, and footsteps also got a second `EchoSoundEffect` from `Data/Footsteps.Rooms` (wet about -3 dB). Fix: the per-sound echo is gone; the global preset is the only reverb. Verified in a play test: zero `EchoSoundEffect` instances on positional sounds.
- **High-pitched exhausted breath.** Cause: playback speed 0.9 to 1.35 raised the pitch by up to five semitones, and the exhaustion gasp played at pitch 1 on top. Fix: tempo now runs 0.9 to 1.25 but a `PitchShiftSoundEffect` holds the voice at 0.88 (`Feel.breathTempo`, `Feel.breathOctave`, tested); the exhaustion gasp plays at 0.82 and 0.4 volume. Verified in a play test with stamina spent: speed 1.219, octave 0.722, effective pitch 0.880, winded walk speed 10.
- Not verified: how either sounds by ear. The owner needs to listen.

## Baseline (before any new detail), seeds differ so room counts differ

| Run | Rooms | Workspace descendants | Parts | Lights | Shadow-casting lights | SurfaceGuis | Decals |
| --- | --- | --- | --- | --- | --- | --- | --- |
| first | 10 | 2810 | 1856 | 26 | 20 | 16 | 22 |
| second (seed 711255085) | 13 | 2551 | 1624 | 25 | 20 | 14 | 28 |

About 200 descendants and 125 parts per room. Frame rate can't be read through the MCP (unfocused Studio is throttled); the owner's F2 overlay numbers go here when available. Stages 4 and 5 are measured against this table.

## Stage 1: audio gaps

- **New sounds** (all free Creator Store audio, probed for load and length in Studio; ids and credits in `src/shared/Assets.luau`): door open, close, latch, slam and bang, a hollow knock, UI key presses, flashlight click, camera shutter, cloth and wardrobe sounds for hiding, a match for the Lantern, a stamp for verdicts and anchors, whisper and drip scares, a low drone, ear ringing, a radio static loop and a hunt sting.
- **Filled the four silent layers**: Drift bass, Drift tinnitus, radio static and the hunt sting now have audio, so the hunt telegraph and the radio phantom work. A play test showed every layer loaded and playing.
- **Replaced the placeholders**: `Thud` (a body on a mat), `Knock`, `DoorCreak` (a real squeaky door), `Groan` (whisper), `Drip`, `Whoosh` (the stock swoosh.wav was failing with "not approved"), and the Guest's and stalker's steps (a wooden step pitched down).
- **Server sounds go through the client** (`Lib/Sfx`, remote `Sfx`): doors and the stalker no longer make their own Sound instances, so the volume sliders, wall muffling and per-sound rolloff apply.
- **Hooks**: button hover and click, flashlight click, hiding in and out, Witness anchor and window, verdict, Lantern, extraction.
- **Mix**: per-sound rolloff, the UI volume constant in `Config.Audio`, a tweened fade in `PlayFor`, and a Drift-driven high-cut on the Ambient group (`DriftMuffle`, up to -18 dB at full Drift).
- Verified in Studio: layers playing, flashlight click playing, `Sfx` remote and `DriftMuffle` exist, console clean. Not verified: how any of it sounds, the door and stalker `Sfx` playback (the MCP can't fire game remotes), hide sounds, and the Drift muffle by ear.

## Stage 2: period avatars

- `LoadCharacterAppearance` is off, so nobody arrives as a modern avatar. `OutfitService` paints the plain R15 body in a faded 1980s shirt, jeans and dark shoes with a natural skin tone (`Logic/Outfit.palette`, tested: the first four shirts differ and slots wrap). Squad members get slots in join order; the Companion takes slot 2 (it only exists when you're alone).
- The Companion (built from a HumanoidDescription, so it has no Animate script) now plays Roblox's default R15 idle, walk and run animations that follow its speed (`CompanionService:_animate`).
- Verified in Studio: the player's parts are skin, mustard shirt, denim, dark shoes with no stray clothing instances; the Companion is teal shirt and corduroy with the idle track playing; the console is clean. The Companion is a dark silhouette in the dim room by design, so the clothes are hard to see in a screenshot. Flat colours, not textured shirts.
- Not verified: how teammates look to each other (needs two clients).

## Stage 3: first-person presence

- You now hold things (`Lib/ViewModel`, `Controllers/ViewModelController`): a torch in your right hand that trails quick turns (it hangs on the same lagged aim as the light), the tool you picked in your left (35mm Witness Camera, Lantern with a glowing core, Radio with dial and aerial, Plumb Line with a brass bob), and sleeved arms in your shirt colour reaching up to them. Roblox's own first-person arms are hidden (`LocalTransparencyModifier`). The torch lens glows when the light is on; the Lantern core glows when it's lit.
- The models tuck back and down against a wall (one ray ahead), dip while you switch tools, and counter-sway against the head bob. A faint warm fill on your hands keeps them readable in a dark room (without it they vanished).
- All local parts: anchored, no collision, no queries, no shadows, so aim, Witness raycasts and the server's views are untouched.
- Verified in Studio: models attached to the camera, stock body hidden, screenshots `stage3_torch_and_camera.jpg` and `stage3_torch_on.jpg` (the first try, `stage3_viewmodel_first_try.jpg`, was too big and too dark to read). Console clean.
- Not verified: the tuck against a wall and the tool swap animation (not exercised), the Lantern, Radio and Plumb Line models (only the Camera tool was on screen), touch and gamepad layouts, and how the arms look to the eye. Other players' torches are not modelled (their head light is unchanged).
