# The visual rework (V0 to V9)

The plan the owner approved on 2026-10-12, kept below the line (its headings one level down) so it can be picked up later. What was built differs from it in places (each phase's report in `docs/progress/<date>-visual-v<n>/` says what and why), and CLAUDE.md's "Where we are" has the short version.

## State on 2026-10-15 (build `2026-10-15.198`)

| Phase | State |
| --- | --- |
| V0 Setup and the look lab | Done |
| V1 The lens | Done |
| V2 Light, the outside and the storm | Done (its finish in V4a) |
| V3 The first room at full quality | Done; the owner approved its look on 2026-10-13 |
| V4 The kit, rolled out (V4a materials, V4b architecture, batches kit3 to kit10) | Done |
| V5 The Guest, remodelled | Done |
| V6 Bodies, clothing and the tools | Done. The clothes became fitted pieces welded on the classic Boy or Girl body, not Shirt/Pants textures. Left: more clothes for the shop. |
| V7 The interface, diegetic 1988 | Done. Left: photos in the Dossier; the ping wheel, tune strip and speak box as things. |
| V8 Cutscenes | Done, with the Guest's takedown added at the owner's ask. Left: the takedown's "pinned to the wall when you pester him" opening. |
| **V9 Polish** | **Paused** (the owner, 2026-10-15: "leave a note to pick up on the rest of the visual update later"). The lobby rework went first, in its own session, and takes V9's hub polish with it. Left here: the performance pass on the three presets, the six moments side by side with IT WANTS IN, ART.md v2 and its TCs. |

---

## The plan: P.T. on 35mm film

### Context

The owner thinks the gameplay loop is in a good spot and asked (2026-10-12) for the full visual rework that was waiting on it: cinematic, pushing Roblox graphics as far as they go, with new lighting, models, textures and UI, and better film grain. The reference is still P.T. The bar is to beat IT WANTS IN and every other Roblox horror game.

What the code and screenshots show today (`docs/progress/2026-10-12-torch-body/`, `docs/reference/it-wants-in/`):
- **Models are the biggest gap.** Every piece of furniture is plain blocks built in code (`src/shared/World/PropFactory.luau`, about 50 builders), so are the doors and trim (`src/server/World/Trim.luau`), the Guest (`src/server/Stalker/StalkerModel.luau`, a stick figure in the light) and your first-person arms (R15 blocks). IT WANTS IN has real modelled furniture with real materials.
- **The grain looks cheap.** It is Roblox's built-in 32 px noise tile, blown up 2×, darkened and jumped once a frame (`EffectsController:_createEffects`/`_update`, `Config.PostFX` Grain*). It only darkens, its repeat shows, and it is blotchy.
- **The lens is plain.** ColorCorrection, Bloom, a fixed-focus depth of field, and a vignette made of four gradient frames.
- **The light is good in principle** (ART.md rules), but the fixtures are flat glowing blocks, windows show a near-black sky, and there's no outside.
- **The UI looks generic:** Gotham, flat panels, a purple objective line, a key-hint bar.
- **Unused features in the owner's Studio (probed read-only):**
  - `ColorGradingEffect` (tonemapper presets Default and Retro).
  - `Lighting.LightingStyle` Realistic with `PrioritizeLightingQuality`.
  - `SurfaceAppearance` with emissive maps (`EmissiveMaskContent`, `EmissiveStrength`, `EmissiveTint`) and alpha modes.
  - `MaterialVariant` metalness maps.
  - Flipbook particles.
  - EditableImage and EditableMesh.
  - Fonts that ship with Roblox: Accanthis (a Garamond-style serif), Merriweather, Special Elite, Kalam, Inconsolata.

### The owner's choices (2026-10-12)

- **Look: P.T. on 35mm film.** P.T.'s sickly lamplight and silence, shot like a modern horror film:
  - filmic tonemapping and fine 35mm grain at 24 fps;
  - warm lamps against cold moonlight;
  - glow and flare around lamps;
  - focus that pulls to what you look at;
  - letterbox only for big moments.
- **Models: Claude in Blender only** (not AI meshes, code-built meshes or Creator Store packs). Blender scripts build each piece with bevels, curves, UVs and baked PBR textures in one style; the owner imports each batch with Studio's 3D importer (it uploads to their account).
- **UI: diegetic 1988.**
  - A nearly empty screen: the objective as a handwritten slip, captions as film subtitles, the torch's battery shown on the torch.
  - Menus as 1988 objects (a case folder, a notebook, a pencilled floor plan).
  - Period serif and typewriter type.
- **Devices: PC-first, lighter on phones:** Cinematic, Balanced and Performance presets, with Auto picking one.
- **Bodies:** players keep **standard Roblox bodies** with **modular 80s clothing textures**, built so the 80s clothing shop and customisation the owner plans for the lobby can plug in later. The shop, currency and monetisation are not part of this pass.
- **Cutscenes: a few short ones**, letterboxed and skippable (3–6 s each), never during danger: the front door locking on arrival, the lights dying as he takes his seat at the dinner, the run's last shot.
- **Weather: a storm that builds,** shared by everyone. Still and foggy at first, then rain on the glass in the middle of the night, then thunder and lightning late. A flash lights the house through the windows for a frame, and the Guest can use it as a scare.

### Rules that don't change

- **Gameplay stays as it is.** Light *for the rules* (lit rooms, the lantern, the stare's light) is still decided only by `WorldService:SetLightCause` and the existing light rule. New decorative light (fire, glare, moon shafts, lightning, light under doors) never changes what counts as lit.
- **Fairness art rules** (ART.md):
  - Tells stay readable at 6 studs.
  - Seams are invisible: kit pieces on a seam are identical across the flip.
  - Exits read.
  - The Guest reads at 30 studs (focus and grain never hide him).
  - The Moderate rating.
  - Decay is shared and divergence is personal (the weather is shared).
- **Comfort:** the camera stays the player's except in the three cutscenes, and the Camera motion setting still governs bob and roll. Grain, flares and flicker each have an off switch in Settings.
- **Names and pieces stay.** PropFactory piece names (`DoorL`, `Lid`, `Dial/Face/Time`, …), hiding eye positions (`Data/Props` `view`), cloth hems (`PropFactory.ClothHem`) and louvres all keep working.
- **Gate A** moves with visual geometry. Approving this plan is the owner's OK to re-baseline at each step that changes it; the new numbers get recorded in CLAUDE.md each time.

### How the models get into the game: a skin over the skeleton

PropFactory keeps building every piece's **gameplay skeleton**: the same parts, names, joints, sizes and collisions the server uses for pushing, hiding, doors, sight and prompts. A new shared module, **`src/shared/World/Kit.luau`**, then **dresses** each skeleton piece:
1. It clones the matching kit MeshPart.
2. It fits it to the piece's CFrame and size and welds it on, so drawers and doors carry their visuals as they move.
3. It makes the visual non-colliding, non-queryable and non-touchable, so sight, focus rays and physics still use the skeleton.
4. It hides the skeleton piece.

Kinds without a kit mesh yet stay as blocks, so the rollout can go batch by batch and the game always runs. `src/shared/Data/Kit.luau` maps each kind and piece to its mesh, its authored size and its pivot.

**Pipeline** (`tools/blender/`, run headless: `blender -b -P tools/blender/kit.py -- <batch>`):
1. Python builds each piece procedurally, as profile sweeps, lathes, bevelled boxes and subdivided cushions with folds.
2. Each moving piece is a separate object named and pivoted like the PropFactory piece.
3. It's UV-unwrapped, and 1024 px PBR maps (colour, normal, roughness, metalness, emissive mask) are baked from a high-poly to a low-poly mesh.
4. Each batch is exported as one FBX, within a triangle budget per kind.
5. The owner imports the FBX with Studio's 3D importer.
6. Claude files the result into the kit, via MCP.

Only the scripts go into git; the meshes and textures regenerate from them, so the big binaries stay out of the repo.

**Risk settled first (V0):** how the imported kit reaches the game and stays reproducible.
- Candidate (a): the kit published as an owner-owned model asset and loaded at server start with `InsertService:LoadAsset`, its id recorded in `Assets.luau`.
- Candidate (b): `.rbxm` files under `assets/kit/` mapped by Rojo. Rojo's live sync may refuse `MeshId` and SurfaceAppearance maps.
- Test both, and also check whether game scripts can set `SurfaceAppearance.ColorMapContent`. Pick the one that works in a fresh `rojo build` and a live server.

### Phases

The owner sees each step before it's committed: before and after shots from the same spots, at the in-game exposure.

#### V0. Setup and the look lab
- Install Blender (LTS) on A:, with the owner's OK. C: has only 13 GB free.
- Spike the import route (above) with three test pieces (a chair, a lamp, a door) and settle it.
- F2 **`look <moment>`** (`DebugService`) puts the character and camera at fixed reference shots on a fixed mansion seed. They are the six moments from `docs/reference/it-wants-in/NOTES.md` (the first room after spawning, a lit room, a dark hall, a window at night, the interface, the first sight of him), plus the Gate A old-house spots.
- A side-by-side baseline set goes into `docs/progress/<date>-visual-v0/`.
- **Graphics presets** in Settings: Auto, Cinematic, Balanced, Performance. They replace the `lowEnd` toggle and migrate it (`StateController` settings, `UI/Settings`, `EffectsController:_applyQuality`). Auto reads Roblox's quality level and whether the device is touch-only.
- `Grain` becomes Off, Fine or Film, replacing `reduceGrain`.

#### V1. The lens (no models needed; a quick, visible win)
- **Film grain, rebuilt:**
  - `tools/textures.py` draws 8 seamless 512 px frames of film grain, fine Gaussian specks with a little clumping.
  - Each frame comes in two layers, dark specks and light specks, so the grain both darkens and lightens like film instead of only darkening.
  - The frames are shown at about 1:1 screen pixels (sized from the viewport, so they stay crisp) and flipped at a steady 24 fps whatever the frame rate, with a random frame, offset and rotation each time so no pattern shows.
  - Strength follows the scene's darkness and Dread.
  - 16 uploads, with the owner's OK.
- **Tonemapping:** a `ColorGradingEffect`, comparing the Default and Retro presets by eye. The `ColorCorrectionEffect` grade and the Drift arc are re-tuned on top. Lighting.Ambient leans cool teal-olive, so the warm lamps against it give the film's warm/cool split.
- **Rack focus:** a ray from the centre of the view eases the depth of field's `FocusDistance` to what you look at. Reading a note close up blurs the room behind. A clamp keeps the Guest readable at 30 studs.
- **Eye adaptation:** `ExposureCompensation` eases with an estimate of the light at the camera, worked out from the light table `EffectsController` already keeps. Step from a lit room into a dark hall and your eyes adjust.
- **Glare and halation:** soft warm glow sprites with a reddish rim on practical lights, depth-tested and faded by distance and angle, plus an optional faint horizontal streak.
- **Lens dirt:** shows only while a bright light sits near the centre of your view.
- **Vignette:** one smooth oval vignette image replaces the four gradient frames.
- **Film flicker:** a faint flicker in exposure, on the Film grain setting only.
- New values in `Config.PostFX`/`Config.Lens`, code in `Controllers/EffectsController` (split into `Controllers/LensController` if it grows past about 900 lines).

#### V2. Light, the outside and the storm
- **Light under shut doors:** a thin strip of light on the floor where a shut door has a lit room behind it. Client-side, per door state (`DoorService` motion snapshots, room light state).
- **Moonlight with real shadows:** a shadow-casting SpotLight outside each window that faces the moon, so the frames, muntins and curtains throw shapes on the floor. Soft shaft Beams with a gradient texture drawn for them, where ART.md step 5 dropped flat ones. Shadows only near the camera, using the existing `Config.ShadowRadius` mechanism.
- **The torch, two beams:** a narrow hot core plus a wide soft spill, with a faint visible beam on *other* players' torches (an open item from the polish pass).
- **Fireplaces** (ambient only) in some living rooms, studies and master bedrooms: a flickering warm key light, flipbook embers and crackle. They dim along the Drift arc and never count for the light rule.
- **The outside** (`World/Exterior.luau`, new, server): ground, a gravel drive, a 1988 station wagon, a tree line, a streetlamp, fog banks between the trees, a sky with clouds and the moon. Low detail, seen only through windows. Placeholder blocks until their kit batch lands in V4.
- **The storm** (`Controllers/WeatherController`, new; the server sets a shared stage from the act and Dread, e.g. `RS.Storm`):
  - fog, then rain (flipbook streaks outside the panes, drops running down the glass, a rain bed through `AudioController` with `Config.Audio.ThroughFloor`), then thunder;
  - lightning flashes by brightness only, on lights that stay enabled (Future lighting is slow to switch lights on), with thunder delayed by distance;
  - a lightning beat for the Guest in `Data/ScareCards`/`Logic/ScareBeats`: the flash shows him where he really is, at a window or in a doorway, so it's honest.
- **The light recipes** per room family re-tuned for PBR. `EnvironmentSpecularScale` is raised as materials gain real roughness.

#### V3. The first room at full quality (the pipeline proven)
- One area taken all the way: the grand hall, one corridor and one living room. That means the materials (V4a), the architecture kit, their furniture and props, and the light.
- The owner approves the look before the rollout. This is where the style gets settled: bevel sizes, wear, colour, how much detail.

#### V4. The kit, rolled out in batches
Each batch ships on its own:

**a. Materials.**
- Rebuild the 10 MaterialVariants with real roughness variation and metalness. Today's roughness is one flat 8 px value per material.
- Add about 15 more: walnut, mahogany veneer, parquet, damask and 80s floral wallpapers, velvet, leather, linen, porcelain, brass, chrome, marble, brick, stone, cast iron, grimy glass.
- Tileable surfaces stay in `tools/textures.py` (seamless by construction); textures for individual pieces come from Blender bakes. `Data/Materials.luau`, `lune run tools/materials`.

**b. Architecture.**
- Doors: a 1988 six-panel interior door, the glazed gate door, double doors, the front door, the steel safe-room door, with knobs and hinges.
- Moulded casings, profiles for baseboards, crown and dado.
- Stairs with nosings, turned balusters, newel posts and handrails, plus the grand staircase.
- Sash windows; ceiling roses and cornices; coffered ceilings in formal rooms; cast-iron radiators under windows.
- Seam trim flips exactly as today (`World/Trim.luau`).

**c. Furniture by room family:** living, then bedroom, then kitchen and utility, then formal, then cellar and attic. All 50 PropFactory kinds, with walk-in closets, louvres and cloth hems kept.

**d. Hero and run props:**
- Clocks with hands, the radio, telephone, CRT TV (an emissive screen), the computer and printer.
- The fuse box, the wall safe and its painting, the music box, the piano.
- Keys by mark, heirlooms, valuables, tools, the lantern, notes and letters, photo frames.
- Paintings (painterly landscapes rendered in Blender), books and clutter.
- The exterior's trees, the car and the lamp.

The UI (V7) and cutscenes (V8) need no Blender, so they run in between whenever an import waits on the owner.

#### V5. The Guest, remodelled
- The same design (the porcelain mask over a black head, the long matte overcoat, bony hands), made in Blender as a **skinned R15-named rig**.
- `GuestController` keeps driving `Motor6D.Transform` from `Logic/GuestPose`, and the mesh deforms smoothly across the joints. The coat skirt joints become bones.
- The fingers are bones driven by the same curl math (`Lib/GuestFace` curlHand, the growth by form).
- The mask is a mesh with calm, worn and broken SurfaceAppearances (replacing the decals), black voids for the eye holes, and an emissive pinpoint in each eye.
- The silhouette is checked at 30 studs against a lit doorway; the reflections (`Lib/GuestReflection`), the catch's hands and the crawl are all re-checked.

#### V6. Bodies, clothing and the torch
- A standard R15 body for everyone: a smoother free Roblox body or the default. The owner picks from screenshots.
- **Modular 80s clothing as classic Shirt/Pants textures:**
  - drawn by a new `tools/clothing.py` at 585×559 with shading baked in: cardigan, varsity jacket, windbreaker, denim jacket, flannel, sweaters, jeans, cords, slacks;
  - each in colour variants;
  - listed in `src/shared/Data/Wardrobe.luau` as data the future shop can sell (slot, item id, variants; no prices yet).
- `OutfitService`/`Logic/Outfit` dress each player from it instead of painting part colours, still one tellable look per squad member.
- First-person arms (`Lib/ViewModel.armFrom`): copied arm parts outside a Humanoid don't show classic clothing, so the view-model arms get a Humanoid and the shirt (or another proven way). Checked with screenshots.
- A modelled 1980s torch (lens, reflector, a filament that glows), the crowbar and bolt cutters, and the held tools.

#### V7. The interface, diegetic 1988
- **`Ui.Theme` v2:** Accanthis for titles, Special Elite for typed text, Kalam for handwriting, Inconsolata for the CRT; paper and card textures (nine-slice) from `tools/textures.py`; the purple "ritual" colour retired. Brass `#C4965C` stays reserved for what matters.
- **HUD** (`UI/Hud`, `Hotbar`, `Toasts`, `FocusMarkers`, `Tips`):
  - The objective is a handwritten slip that fades in when it changes.
  - Captions are film subtitles.
  - Focus markers become a brass hairline and small caps.
  - The two tool slots show only while switching.
  - Stamina shows by breath and vignette; the torch's charge shows on the torch.
  - A "Show meters" setting is kept for accessibility.
  - The key-hint bar shows only at the start or on F1.
- **Screens:**
  - The journal is a notebook and the map a pencilled plan on graph paper (`UI/Map`).
  - The note reader is real paper.
  - Puzzle screens look like the object, e.g. the computer as a CRT with scanlines and phosphor glow.
  - The Dossier is a police case file with typed pages and photos.
  - The lobby and hub menus are a case folder.
  - The settings and how-to are typed sheets.
  - A title card starts each night ("THE HALFWAY HOUSE · 2:04 AM").
- Text fit is checked with `TextFits` on every label, at phone and PC sizes.

#### V8. Cutscenes
- `Controllers/CinemaController` (new): a letterbox, an eased camera path through a few keyframes, skippable on any input, and a "Skip cutscenes" setting. Never while a hunt is on, or the Guest is near or telegraphed.
- The server triggers it through a remote declared in `Net.luau`. The three shots:
  - the front door locking (`RunOrchestrator`, arrival);
  - the lights dying as he takes his seat (`FinaleService`, the dinner);
  - the last shot out of the front door into the storm.

#### V9. Polish
- Hub polish: ART.md step 7, the chat-hint overlap.
- A performance pass on all three presets:
  - F2 `perf` extended with texture and mesh memory (`Stats:GetMemoryUsageMbForTag`), MeshPart and light counts;
  - the owner runs the MicroProfiler in a focused Studio window, plus a phone check;
  - triangle and light budgets per room recorded in ART.md.
- The six moments side by side with IT WANTS IN, by the owner.
- `docs/ART.md` rewritten as v2 (the film look, kit, lens, storm, UI); TESTING TCs for each phase.

### Files at the centre

- Lens and grade: `src/client/Controllers/EffectsController.luau`, `src/shared/Config.luau` (`PostFX`, `Lighting`, `DriftArc`, new `Lens`, `Storm`, `Kit`), `default.project.json` (Lighting).
- Kit: new `src/shared/World/Kit.luau`, `src/shared/Data/Kit.luau`; `src/shared/World/PropFactory.luau` (calls `Kit.dress` at the end of `PropFactory.build`, `buildDecor`, `buildTellBase`), `src/server/World/Trim.luau`, `LevelBuilder.luau`, `MansionBuilder.luau`, `Dressing.luau`, `LeadProps.luau`, `Items.luau`, `LandmarkProps.luau`.
- Pipelines: new `tools/blender/` (kit.py and a library), `tools/textures.py` (grain, paper, shafts, glare, materials), new `tools/clothing.py`, `tools/materials.luau`, `src/shared/Assets.luau`.
- Light and weather: new `src/server/World/Exterior.luau`, new `src/client/Controllers/WeatherController.luau`, `src/shared/Data/ScareCards.luau`, `src/shared/Logic/ScareBeats.luau`.
- The Guest: `src/server/Stalker/StalkerModel.luau`, `src/client/Controllers/GuestController.luau`, `src/client/Lib/GuestFace.luau`.
- Bodies: `src/server/Services/OutfitService.luau`, `src/shared/Logic/Outfit.luau`, `src/client/Lib/ViewModel.luau`, `src/client/Controllers/ViewModelController.luau`, `src/shared/World/ToolModel.luau`.
- UI: `src/client/Lib/Ui.luau` and every `src/client/UI/*`; Settings and `StateController` for the presets.

Reused, not rebuilt: the shadow radius and light table in `EffectsController`, the Drift arc and Dread (`Logic/Dread`), the one light rule (`WorldService:SetLightCause`), `Lib/Sfx` captions, `tools/materials.luau`, `World/Grime.luau`, `Logic/WindowView` (windows and moon), the F2 `clip` scan, `hide`, the prompt audit and `gatea`.

### Verification, every phase

- **Checks:** `stylua src tests`, `lune run tests/run`, `lune run tests/compile`, `selene src tests`, `rojo build`. Also `lune run tools/completable` if anything touches generation.
- **New specs:**
  - `Kit.spec`: every kit entry names real PropFactory pieces, and authored sizes match `Data/Props` footprints within tolerance.
  - Grain: frame cadence is 24 fps whatever the frame rate.
  - Wardrobe data and the storm stages stay well-formed.
- **In Studio (MCP):** play `seed 1800820264` and the fixed mansion seed with a clean console; `look <moment>` shots before and after, wait about 6 s, then `screen_capture`.
- **Gameplay re-checks:**
  - F2 `clip`;
  - `hide` for every hiding kind (eye positions and cloth);
  - the prompt audit (no prompt hidden by its own prop);
  - `navtest fast`;
  - `botrun` (nothing the bot does breaks);
  - `gatea` re-baselined and recorded.
- **Fairness:** tells readable at 6 studs, the Guest at 30, seams invisible on both sides of a flip, exits readable, no new light changing what counts as lit.
- **Multi-client and by eye/ear (the owner):** the storm and other players' torch beams with two clients; the grain at 1080p and 1440p; the presets on a phone. New TCs at the end of `docs/TESTING.md`.
- **Each step:** a report in `docs/progress/<date>-visual-<step>/` with shots, `Build.id` bumped, committed and pushed, and CLAUDE.md's "Where we are" updated.

### What the owner will be asked along the way

- Each upload batch (grain and vignette images, textures, kit imports).
- The Blender install.
- The standard body.
- The tonemapper preset.
- The golden room's style.
- Each cutscene.
