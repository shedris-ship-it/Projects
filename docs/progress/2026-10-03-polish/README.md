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
