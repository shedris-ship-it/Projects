# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

# Consensus: notes for Claude

Consensus is a 2–4 player co-op horror game for Roblox. A squad is locked in a generated 1988 mansion with The Guest, a stalker who learns their habits; two players watching him freeze him, and each player sees a slightly different house as atmosphere. This repo is a Rojo project holding the vertical slice: The Halfway House and The Guest. **The owner chose a gameplay rework on 2026-10-04** (`docs/plans/gameplay-rework.md`): a procedural escape with locks, keys, puzzles and a physical, hands-on house, ending in the dinner (heirlooms set at the table) and a run out of the front door. **Since 2026-10-05 (R2c) it is the only loop:** the anomalies, evidence, verdict and Witnessing are gone.

Read these before starting real work:
- `docs/DesignDoc.md`: the design and roadmap. It is the spec. Section numbers are cited throughout the code.
- `docs/plans/gameplay-rework.md`: the rework. Where it disagrees with the design doc, it wins. Sections 15 to 20 are the passes since 2026-10-06, newest last.
- `docs/plans/level-design.md`: the level design (2026-10-05): the adventure planned first, houses that follow the squad, every room with a reason, the best of many houses. Where it disagrees with the mansion plan about level design, it wins.
- `docs/ARCHITECTURE.md`: how the code implements it (every service and controller, run flow, divergence model, remote protocol, security).
- `docs/TESTING.md`: automated checks and the manual multi-client checklist (TC-01 to TC-283 as of 2026-10-12; new cases go at the end).
- `docs/ART.md`: the approved visual guide; its "How the visual pass will run" list is the work order.
- `docs/progress/<date>-<pass>/`: each pass's report and before/after screenshots. `docs/progress/ROADMAP-LOG.md` is the whole history, pass by pass.
- `README.md`: setup, controls, how a run plays, the F2 debug commands, how to add rooms and puzzles.

## Working with the owner

- The owner is a **solo developer** with no artist, sound designer or programmer. Claude is the whole team: code, art direction, assets, tuning and docs.
- They're on **Windows, using PowerShell**, and newer to command-line tools. Give exact commands to copy and say which folder to run them in. Explain errors in plain words.
- They test in Roblox Studio. Three squad playtests so far (2026-10-08, 2026-10-10, 2026-10-11) and several solo ones; each pass's report has their notes.
- **Their C: drive filled up on 2026-10-05** and Studio crashed (SQLite "disk full" errors in `%LOCALAPPDATA%\Roblox\logs`). If Studio vanishes mid-session, check free space on C: first; don't delete the owner's files to make room, tell them.
- The place is published (place id 81335718246692) and opened in Studio as a Team Create session. Studio's API access isn't on, so DataStore calls fail with 403 in play tests and the first-launch settings dialog appears each run (close it with Done at GUI ~961,636 since build .168, or set `PlayerGui.ConsensusSettings.Enabled = false` from the Client datamodel).
- Ask before decisions that are theirs: design changes, spending money, publishing, anything on their Roblox account.

## Session start checklist

1. Work in the repo clone at `A:\111- Projects\Github\Projects`. The owner's `Games\Concensus` folder is an old ZIP copy; don't edit it.
2. Start `tools/serve-mirror.sh` detached (the `Start-Process` line below), and ask the owner to click **Connect** (or **Okay → Connect**) in Studio's Rojo panel.
3. Check `list_roblox_studios` sees Studio.
4. Run the checks.
5. In play tests, confirm `seed 1800820264` with its on-screen reply before `start`, and wait about 6 s after moving the camera before `screen_capture`, or the lighting comes out black.

## Source of truth: the repo files, synced by Rojo

- Code lives in `src/` and is synced into Studio by Rojo. Run `rojo serve` in the repo folder, then click **Connect** in Studio's Rojo plugin.
- **Never edit scripts inside Studio** (including the MCP `multi_edit` tool). Rojo overwrites those edits. Edit the files.
- **2026-10-11: the Rojo plugin showed "connected" but stopped applying edits to existing scripts (new files still arrived), even after Okay → Connect and a restart of rojo.** Check a pushed file's length in Studio (`#script.Source`) against the repo after a sync; when they differ, push it through `execute_luau` (below).
- **2026-10-12: the mirror itself kept a stale file.** A save through a rename lands with the temporary file's earlier time, so a copy made just before the rename stayed old and looked newer than the source. Fixed in `tools/serve-mirror.sh` (copies carry their source's time; any difference copies again), and the fix takes effect when the script restarts. Before trusting a Studio check, `cmp` the changed files in `src/` against `.rojo-mirror/src/`. If one differs, `touch` the source file.
- Rojo 7.7.1 crashes (`change_processor.rs` line 172, "cannot find the file specified") when a file is saved through a temporary-file rename, which Claude's edit tools do. Each crash leaves the Studio plugin on an error that needs **Okay → Connect**. In Claude sessions, serve with **`tools/serve-mirror.sh`**, started detached (PowerShell: `Start-Process "A:\Git\bin\bash.exe" -ArgumentList "tools/serve-mirror.sh" -WorkingDirectory "A:\111- Projects\Github\Projects" -WindowStyle Minimized`), never as a Bash background task (those die when the session pauses, on a usage limit or after 30 min, and each death leaves the plugin needing Okay → Connect): it copies `src/` and `assets/` into `.rojo-mirror/` in place and serves that, so Rojo never sees a temp file. Zero crashes since. With the plugin down and nobody to click Connect, push a changed file verbatim through `execute_luau` on the Edit datamodel (its text in StringValues, then `Source`, length checked; HttpEnabled is off in this place, so the HTTP fallback below fails). The owner can keep using plain `rojo serve`, because normal editors save in place.
- `rojo build default.project.json -o Consensus.rbxlx` makes a **fresh** place. Anything made by hand in Studio that isn't in the Rojo tree is lost in that file.
- `MaterialService` is in the Rojo tree (`assets/materials/`, generated by `lune run tools/materials` from `Data/Materials.luau`). Game scripts can't create MaterialVariants at runtime.
- Studio's `generate_material` tool failed on every request (2026-10-02, an internal assert error). Textures are drawn by `tools/textures.py` instead (numpy + Pillow; make a venv in the scratchpad) and uploaded with `upload_image` from a local `python -m http.server`. Uploaded images can report "Failure" in `ContentProvider` checks while they still display fine. Ask before uploading anything to the owner's account.
- `ServerStorage` isn't in the Rojo tree yet. When you start making Studio-authored content (room prefabs for `ServerStorage.RoomPrefabs`, generated meshes):
  1. Save it into the repo as `.rbxm` files (for example under `assets/`).
  2. Map that folder in `default.project.json` so it's version-controlled.
  3. Record any uploaded asset ids in `src/shared/Assets.luau`.

## Roblox Studio MCP server

The owner connects Studio's built-in MCP server to Claude Code (tools show as `mcp__Roblox_Studio__*`). It only works in local sessions, with Studio open, the place loaded and the server enabled. If the tools are missing, ask the owner to check Studio: **Assistant → … → Manage MCP Servers**.

Use it for:
- **Seeing the game:** `screen_capture`, with a camera position and look-at target if needed. Use it for every visual change. Take before and after shots from the same angles, and judge the result at the in-game exposure.
- **Smoke tests:**
  - `start_stop_play` and `get_console_output` after each change; fix every red error.
  - Use `character_navigation` and keyboard and mouse input to walk through flows.
  - Use the F2 debug console commands to jump states (README has the list: `seed`, `start`, `drift`, `tier`, `hunt`, `act`, `arm`, `goto`, `unlock`, `give`, `items`, `leads`, `puzzle`, `solve`, `crank`, `barricade`, `resolve`, `perf`, `gatea`, ...). `botrun` plays the whole run on the server with your character and reports the numbers; `summary` prints the run in numbers; `inspect <Service.field...>` reads a live server table. From MCP, set ServerStorage's `DebugCommand` attribute and read `DebugReply` (the MCP can't press F2).
- **Inspecting and live-tuning:**
  - `execute_luau`, `inspect_instance` and `search_game_tree`.
  - Tune lighting and materials live, then **copy the final values into the code or `Config.luau`**. Live edits are lost on the next sync.
- **Assets:**
  - `generate_mesh` and `generate_material` for organic shapes and surfaces code can't make well, such as the stalker's body and wallpaper.
  - `search_asset` and `insert_asset` only for meshes, images and audio. **Never insert Creator Store models that contain scripts** (backdoor risk). Strip scripts from anything inserted.

Limits:
- Divergence bugs need two or more clients (**Test → Clients and Servers**). The MCP tools drive one Studio session, so ask the owner to run multi-client checks and report what each client saw.
- Saves need the place published with Studio API access on. Unpublished places use memory-only profiles.
- When the Rojo plugin can't be connected (the owner is away and Studio was relaunched), a fallback that still keeps the repo as the source: serve `src/` with `python -m http.server 8765 --bind 127.0.0.1` (Git Bash, in the background) and run an `execute_luau` snippet on the Edit datamodel that fetches each changed file with `HttpService:GetAsync` and sets the script's `Source` verbatim (never hand-edit in Studio). Stop play first; restart it after.

## Checks: run before every commit

From the repo root (`rokit install` sets up rojo, lune, selene and stylua):

```sh
stylua src tests          # format (tabs, 120 columns)
lune run tests/run        # unit tests (585 in 88 specs as of 2026-10-12; about 90-150 s, 2-4 minutes while Studio runs, 10-15 minutes while Studio is playing)
lune run tests/compile    # every .luau file compiles
selene src tests          # lint, must be 0 errors and 0 warnings
rojo build default.project.json -o Consensus.rbxlx
```

After a change to generation or the lock planner, also run `lune run tools/completable` (every squad, difficulty and night; all houses must finish; about 2-3 minutes).

To run one spec while iterating, pass part of its file name: `lune run tests/run LockPlanner` runs every `tests/specs/*.spec.luau` whose name contains `LockPlanner`. Run the full suite before committing, and don't edit `src` or `tests` while it runs: a spec loads its modules when the runner reaches it, so a mid-run edit mixes old and new code and gives false failures.

All must pass. When MCP is available, also start a play session and check the console for errors. Report results honestly: if something wasn't checked in Studio, say so.

**Gate A** (cited throughout the docs) is the regression check on the builder: the old house (F2 `layout cells`, `seed 1800820264`) must build the same part count and part hash, which F2 `gatea` prints in Studio. Run content goes in a `RunContent` folder it leaves out. A change that moves it needs the owner's OK to re-baseline (they gave a standing OK for gameplay fixes); record the new numbers here. Current: **parts 2290, hash 387097105** (since build .179: the kit's modelled doors and chairs in the old house; before, 2269 and 1553234744). `lune run tools/golden` (the old generator's plans, `tests/golden/`) is rerun only for an approved change too.

## Map of the code

`docs/ARCHITECTURE.md` has a table of every service and controller; this is the shape you need before reading it.

- **`src/shared`** (ReplicatedStorage.Shared) is used by both sides. `Logic/` is pure, engine-free rules run under Lune and spec'd in `tests/specs/` (generation, the lock planner, puzzles, his rules, physics feel). `Data/` is content. `Config.luau` is every tunable. `Net.luau` declares every remote. `Lib/Rng` is the seeded RNG. `Build.luau` is the build id.
- **`src/server`** (ServerScriptService.Server). `Main.server.luau` requires every module in `Services/`, runs `Init(services)` in name order, then each `Start()` in its own thread; a service that fails to load is warned and skipped, so read the console. `Stalker/` is The Guest's brain and body (Director, Stalk, Tactician, Walker, Sight), driven by `StalkerService`. `World/` builds the house (`LevelBuilder`, `MansionBuilder`, `PropFactory`). `Puzzles/<Kind>` is the server half of each puzzle, hosted by `PuzzleService`.
- **`src/client`** (StarterPlayerScripts.Client) mirrors it: `Controllers/` with `Init`/`Start`, `UI/` screens run by `UIController`. Clients draw The Guest themselves (`GuestController` animates every joint from `Logic/GuestPose`).
- **A run:** `RunOrchestrator` picks a seed; `Logic/HouseSearch` builds 12 candidate houses (`HouseSize` → `Programme` → `MansionGen` + `LayoutValidator` → `Wings` → `LockPlanner` → `Leads`), scores each with `HouseMetrics` and keeps the best; `WorldService` builds it; then locks, items, puzzles and the dinner's table are set up. The escape ends when the dinner opens the front door.
- **Passage:** every route, lock, door and barricade meets in `WorldService:SeamCost(seam, who)`; the Guest's walkers (`Logic/NavGraph`, `Stalker/Walker`) only ask it.
- **Tools outside the game:** `tools/*.luau` run with `lune run tools/<name>` (`plan <seed> mansion [locks]` prints a house, `housestats`, `lockstats`, `completable`). `tools/_*.luau` are local scratch scripts, each listed in `.git/info/exclude` (add a new one there too).

## Roblox skill

`.claude/skills/roblox-game-development` is the general Roblox skill the owner chose (MIT, from `greedychipmunk/agent-skills`). Use it for Roblox best practices, performance, debugging and doc templates. This project's own patterns win where they differ. Don't copy the skill's helper scripts (`DataManager`, `RemoteManager`, …) into `src/`; the project already has `DataService`, `Net.luau` and the rest.

## Code conventions

- **Services and controllers:**
  - Every ModuleScript in `src/server/Services` is a service table with optional `Init(services)` and `Start()`.
  - `Init` only stores references to other services, for example `self.World = services.WorldService`.
  - `Start` begins work.
  - Client controllers in `src/client/Controllers` follow the same pattern.
  - Services talk through methods and `Lib/Signal`; there are no globals.
- **Server authority:** the server decides outcomes (catches, locks and keys, puzzle answers, the dinner, Drift, stuns). It sends clients *rules*, not world state; clients only change what their own player sees.
- **Remotes:**
  - Declare them in `src/shared/Net.luau`.
  - Every client-to-server handler goes through `Net.onServer(name, { interval, burst, types }, handler)`, which rate-limits and type-checks. Every accepted remote counts as activity for the idle check (`Net.onActivity`).
  - Re-validate range, line of sight and state on the server.
  - Never send hidden truth before it's earned: a note's text before it's read, a puzzle's answer, a room or lock on the map nobody has seen.
- **Fairness contract:** this is design doc section 3, enforced by `Logic/LayoutValidator`.
  - Fake walls are visual only and never collidable.
  - Divergences must never trap a player.
  - Room centres and the four doorway lanes stay clear, because the walkers' graph (`Logic/NavGraph`, `Stalker/Walker`) relies on it; `Logic/RoomFit` also keeps solid furniture out of a room's middle.
  - The one exception is a barricade (`Logic/Barricade`): a pushed piece may fill a doorway's lane only if it then bars it, so routes know; anyone can squeeze past, and he shoves it clear within 8 s or slips past unseen.
- **Passage and physics (the rework):**
  - Every route and walking distance asks `WorldService:SeamCost(seam, who)` (nil = blocked). Locks, barricades and door/wall flips go there, not into the Guest's modules; call `WorldService:MarkPassageChanged` when one changes.
  - Physical things stay anchored until someone grabs them (`Services/HandsService`) and are anchored again once still. Carried and thrown things (collision groups Held and Prop) never touch players or The Guest; hits on him are worked out on the server.
  - Doors move by angle (`Logic/Articulation`); `door.open` means walkable.
- **Determinism:**
  - Generation, the lock plan, leads, puzzles and stalker decisions use the seeded `Lib/Rng`, forked per subsystem.
  - `math.random` is only for cosmetic client timing.
- **Data-driven:**
  - Content goes in `src/shared/Data/*` (rooms, props, physical things, notes, interactables, tactics, stalk moves, archetypes, tools, pings).
  - Tunable numbers go in `src/shared/Config.luau`; mark values taken from the design doc with `(doc)`.
- **Pure logic is tested:**
  - Engine-free rules go in `src/shared/Logic` with a spec in `tests/specs/*.spec.luau`.
  - A spec returns `function(test, check, Shared, require)`.
- **Prompts on a keyboard:** `HandsController` claims every E prompt: it sets the key to `NO_KEY` (World95) and fires the one you look at itself. Never give a prompt `KeyCode.Unknown`: Roblox matches it to mouse buttons, so every shown prompt fires on any click. Prompts are also clickable by default, so `ClickablePrompt` is off on a keyboard. A screen or note put away by a key or a click calls `Ui.dismissed()` so the same press doesn't reach the hands.
- **PropFactory names:** clients and services find prop parts by child name (`Dial/Face/Time`, `Paper/Writing/Text`, `EyeL`/`EyeR` on portraits, `Lid`, `DoorL`/`DoorR`, `Glass`, …). Keep those names when restyling props.
- **Style:** match the surrounding code. Write short comments that explain *why* and cite doc sections. Prefix private methods with an underscore (`_roomPath`, `_setup`). Use `Ui.modal` on menus so the mouse unlocks in first person.

## Roblox gotchas found in this project

- Only prompts Roblox shows can be fired, and only on-screen ones show. In MCP tests a prompt only shows (and `InputHoldBegin` only works) while the camera faces it.
- In first person a click can arrive already marked "processed" and never reach a ContextActionService binding; `HandsController:_click` and `_rightClick` take those while the mouse is locked.
- The player rig's joints are AnimationConstraints, so player poses are built in code (`Logic/PlayerPose`, `Controllers/PoseController`).
- Roblox's first-person eye sits half a stud *behind* your middle (`Logic/Feel.neckLean`, `FeelController:_neckRoom`).
- The Guest's replicated position arrives unevenly; clients draw him from a smoothed root (`GuestController:_drawnRoot`, `Config.Guest.DrawnFollow`).
- Roblox's fonts draw some glyphs as boxes or colour emoji (moon, chess pieces, anchor); `Data/Marks` keeps to plain glyphs drawn in one colour.
- Text that doesn't fit is silent: scan visible labels' `TextFits`, and measure long text (the Dossier) with TextService.
- Speech reuses Roblox's voice listener; a second listener doubled every voice.

## Git

- A cloud session works on the `claude/*` branch it is given, and the owner's clone only has that work after they `git fetch` and check the branch out (README, "Getting a Claude session's work into Studio"). Always tell the owner the branch name and the build id (`src/shared/Build.luau`) at the end of a session, and bump `Build.id` in every commit meant to reach Studio. If the owner reports old behaviour that a commit already removed, suspect their checkout or Rojo sync first: ask for the build id on the hub panel or in the F2 overlay.
- A local session works on the branch the owner has checked out, `claude/overnight-foundation` since 2026-10-06, unless the owner says otherwise. (`claude/quirky-gauss-cfc8my` is the repo's default branch but far behind; there is no `main`.)
- Commit after each verified chunk with a clear message, and push so the work is backed up.
- Don't force-push or rewrite history. Don't open pull requests unless asked.
- Each pass ends the same way: a report in `docs/progress/<date>-<pass>/`, a section in the plan doc it belongs to, new TC cases at the end of `docs/TESTING.md`, and a short update to "Where we are" below. Keep this file short: the detail goes in those docs, not here.

## The owner's standing decisions

These constrain every pass; the reasons and dates are in the plan docs and `docs/progress/ROADMAP-LOG.md`.

- **The escape is the only loop** (rework section 2): keys per player, divergence as atmosphere only, the dinner at the table and the run out of the front door.
- **Look and tone:** a 1988 suburban house, P.T. as the mood, the **Moderate** content rating (never Restricted), and "extremely scary" within it. The quality bar is to beat IT WANTS IN, visually and in the loop (`docs/reference/it-wants-in/NOTES.md`).
- **Physical, never overlays:** real hiding places you step into, real slats to look through, your own arms copied from your character (never stand-in hands). The Guest finds you only legitimately: by seeing, hearing or opening.
- **Solo-first:** everything must work for one player (there's no Companion since 2026-10-06); team puzzles stay solo-safe.
- **Level design** (`docs/plans/level-design.md` sections 10.0 and 11): never a key behind its own lock, no deeper dead ends, scaled by squad and measured. The cellar and the attic are each a locked wing of their own, added to the squad's wings, never the starting one, and must hold something the run needs.
- **The Guest:** his three rules (watch him; don't pester him; when he hunts, break his sight, hide or get to a lantern) are said word for word in the how-to, the tips and the README, so change them together. Eyes never stop him once he's after someone. He's rarer and deadlier.
- **Standing OK:** fix gameplay-loop problems that build on the foundation without asking, and record the decision in the pass's report; Gate A may be re-baselined for gameplay fixes.
- **Ask first:** anything uploaded to or generated on their account (images, meshes), spending money, publishing.
- Design doc section 10: don't pile content onto a core that hasn't passed **Gate 2** (the slice is fun with friends). Keep nudging the owner toward squad playtests, and have them ask testers *"Did it ever feel like it cheated?"*

## Where we are (2026-10-12)

Build `2026-10-12.179` on `claude/overnight-foundation`, 611 tests.

- **Built:** the escape loop (rework R0 to R2c); the mansion generator and its navigation (M1 to M3); the level design L1 to L3 except its last item; the foundation and loop passes (Dread, stuck-assist, the bot, the Reckoning, the short night); the Guest rework (moods, temperaments, the mask, his animations); the fixes from three squad playtests; the readable Guest (his three rules, pestering, the family's valuables); the torch on F with your own arms and legs. The visual pass's steps 1 to 6, the polish pass and visual audit round 1.
- **Now: the full visual rework** (the owner, 2026-10-12: "the gameplay is in a good spot"; P.T. on 35mm film, models made in Blender, a diegetic 1988 UI, PC-first presets, a building storm, a few cutscenes, standard bodies in modular 80s clothing for a later shop). The plan's phases V0 to V9 and their state are in the reports `docs/progress/2026-10-12-visual-v1/`, `-v2/`, `-v3/`.
  - Done: graphics presets; the 35mm lens (`Controllers/LensController`: grain, tonemapping, rack focus, eye adaptation, glare); light under doors; a hot core in the torch; real windows in outer walls (`Logic/Windows`; seam skins leave them open, `Trim` `skinAround`) with the night outside (`World/Exterior`: dense woods and a garden placed by `Logic/Grounds`, a terrain-grass lawn, a streetlamp, a sky ring, the run's moon; a clapboard facade on outer walls, `Config.Exterior.Facade`) and moonlight through them; the storm (`Logic/Storm`, `WeatherService`, `WeatherController`); the kit system (`World/Kit`, `Data/Kit`) and the Blender pipeline (`tools/blender/kit.py`, Blender 5.2.2 at `A:\Tools\blender-5.2.2-windows-x64\blender-5.2.2-windows-x64\blender.exe`) with the spike and the golden room's first batch built. **The import route (V0, settled 2026-10-12):** the owner imports a batch with Home → Import 3D (it uploads to their account); each mesh's asset id goes in `Data/Kit` (`id`) and the server builds it at start (`Kit.preload`, `AssetService:CreateMeshPartAsync`); its four maps go in `assets/kit/<name>.model.json`, a SurfaceAppearance Rojo syncs to `ReplicatedStorage.Kit` (game scripts can't set SurfaceAppearance maps; plugins can't set a MeshId). The importer turns glTF's front (+Z) to Roblox's (-Z): `World/Kit`'s `IMPORT_TURN`. In the game: the spike (chairs, floor lamps, doors).
  - Waiting on the owner: importing `build\kit\spike\spike.glb` again (now with the lamp shade's glow mask) and `build\kit\golden\golden.glb`; then the `Scene` models in Workspace can go. Also judging the lens, rain and moonlight by eye, and the tonemapper (Default or Retro).
  - Next in the rework: the golden room in Studio once it's imported; the rest of V2 (fireplaces, light recipes for PBR); V4 the kit by room family; V5 the Guest; V6 bodies, 80s clothing and the torch; V7 the UI; V8 cutscenes; V9 polish.
- **Waiting on the owner:** the manual checks in `docs/TESTING.md`, newest TC-254 to TC-286 (several need 2–3 clients); the music stems, the scream and his sounds, picked by ear (`Assets.luau` lists alternatives); whether the safe room gets deterrents or weapons (deferred).
- **Next, in order:**
  1. **Studio findings:** fix anything the owner reports, and any console errors in play mode.
  2. **The visual rework** (above).
  3. **The last of L3:** furniture laid out for play (the old M4; `Logic/RoomFurnish` doesn't exist yet; `docs/plans/level-design.md` section 3, part 4, and section 11.2).
  4. **L4, the house fights back** (the old R3, the living house: doors that become walls where nobody sees; rework section 10). The owner held it back on 2026-10-11, so ask before starting.
  5. A tutorial run that teaches the escape (never cut; today there's only a how-to-play screen).
  6. A hub place, MemoryStore matchmaking, reserved and private servers (the owner publishes the places in Creator Hub; walk them through it).
  7. A daily contract, and a harder Hard (more locked regions; `Config.Progression`).
  8. The second location: St. Odile Ward, with The Orderly (the archetype data exists).
- **Not built yet:** the Guest passing a lock between hunts (a lock is always a wall to him), touch controls for the hands, `navtest barricade`, the Director's scent hint. Watch: the bot still stops for him 15–24 times a run.

## Known limitations

- The furniture is still grey-box geometry, though lighting, trim, materials and grime are done; your arms and legs in first person are plain R15 blocks.
- Audio: the Guest's sounds, the heartbeat, gasps, the Drift layers, radio static, the hunt sting, the breath and the house hum are licensed library audio, and player footsteps are free community Creator Store samples (all in `Assets.luau`; swap any id that sounds wrong). The music states are wired for three stems (`Assets.Music`), but no music is picked yet.
- The Guest is built in code from primitives (coat, hands, mask); generated meshes for the coat and hands are plan B if he looks toy-like (they'd go on the owner's account: ask). Between hunts he tracks you honestly, from what he saw and heard (`Logic/BeliefMap`, `Stalk:Known`).
- Voice is plain proximity chat: no routing through the audio API, no radio or muffling.
- Hub and run share one place. Roblox's chat hint overlaps the hub title; hub sign text sizes vary.
