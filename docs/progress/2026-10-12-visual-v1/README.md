# The visual rework, V0 and V1: presets and the lens (build `2026-10-12.169`)

The owner asked on 2026-10-12 for the full visual rework (plan: P.T. on 35mm film, models made in Blender, a diegetic 1988 UI, PC-first presets, a building storm, a few short cutscenes, standard bodies in modular 80s clothing). This step is the part that needs no models: graphics presets and the lens. All shots are from Studio, one client, seed 1800820264 (the mansion), at the in-game exposure.

## What changed

**Graphics presets** (`Logic/GraphicsPreset`, `Config.Graphics`, Settings): Auto, Cinematic, Balanced, Performance.
- They replace the "Low-end graphics" toggle; old saves carry over once (low-end becomes Performance).
- Auto follows Roblox's own graphics quality, or, while that is on Automatic, the device: a phone gets Performance, a console Balanced, a PC Cinematic.
- Each preset switches depth of field, bloom, clutter shadows, room-light shadows, torch shadows, dust, glare, lens dirt and eye adaptation.
- "Hide your own body" and "Ctrl toggles crouch" were never saved (missing from `DataService`'s list); they are now.

**The lens** (`Controllers/LensController`, `Logic/Lens`, `Config.Lens`, images from `tools/lens.py`):
- **Film grain:** 8 frames of real grain (512 px, seamless), one texel to a screen pixel, flipped at 24 frames a second whatever the frame rate, with a fresh frame and shift each time. One image holds dark specks and fainter light specks.
  - The light specks fade with the light (each frame's tint). The first try lifted pure black by 3 levels of 255 into "TV snow" (shot 2); measured, then fixed (shot 3).
  - Settings: Film grain Off, Fine or Film (Film adds a faint exposure flicker, never with "Reduce flicker").
  - It replaces Roblox's 32 px noise tile, which was blown up 2×, only darkened and showed its repeat.
- **Tonemapping:** Roblox's `ColorGradingEffect` (Default). Retro measured almost the same in these dark rooms (shot 4); the owner chooses.
- **Rack focus:** the depth of field pulls to what the middle of your view rests on (a note held up blurs the room behind). The Guest is always kept inside the sharp zone within 40 studs (shot 8: the focus went to him at 16 studs).
- **Eye adaptation:** exposure eases with an estimate of the light at the camera: up to +0.35 stops in the dark (darkness stays dark), down to −0.3 under many lamps. Your own torch counts, so the dark round the beam stays deep.
- **Glare:** a warm halo with an amber body and a red rim (film halation) round the lamps you can see, depth-checked by a ray, plus a faint streak. Lens dirt shows only when a bright lamp is near the middle of the view. Off with "Lens flares and glare".
- **Vignette:** one smooth, dithered image (no banding), closing in with Dread. It replaces four gradient frames.
- **Letterbox:** `LensController:Letterbox(on)` (2.39:1) for the cutscenes (V8).
- Studio only: the player attribute `LensBypass` (true, or a list like `"grain,glare"`) takes the lens off for before-and-after shots.

## Shots

| | |
| --- | --- |
| `1_dining_before_no_lens.jpg` | The dining room with the lens bypassed |
| `2_dining_first_try_lifted_blacks.jpg` | The first try: light specks lifting the blacks |
| `3_dining_after.jpg` | After: the blacks stay black, grain in the lit areas, the halo and streak on the light |
| `4_dining_after_retro_tonemapper.jpg` | The same with the Retro tonemapper |
| `5_grand_hall.jpg` | Spawn: the glare on the gallery lights |
| `6_dark_corridor_torch.jpg` | The main corridor, lights off, torch up |
| `7_window_at_night.jpg` | The kitchen window: a flat dark pane (V2 brings the outside) |
| `8_first_sight_of_him.jpg` | The Guest at 16 studs, in focus |

## Found on the way

- The mansion on this seed has only **two windows** (the kitchen and the nursery), so the outside in V2 needs more windows to matter.
- Models (furniture, the torch and arm, the Guest) are the gap these shots show most: V3 to V6.

## Waiting on the owner

- Judge the grain, glare and vignette in a real play test (screenshots are compressed): the strengths are in `Config.Lens`.
- Default or Retro tonemapper.
- Blender 5.2.2 is in `A:\Tools\blender-5.2.2-windows-x64\blender-5.2.2-windows-x64\blender.exe` (checked headless).

Checks: 596 tests pass, compile, selene 0/0, rojo build. Gate A is unchanged (the lens is client-only).
