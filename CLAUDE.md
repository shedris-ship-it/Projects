# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

# Consensus: notes for Claude

Consensus is a 2–4 player co-op horror game for Roblox. A squad is locked in a generated 1988 mansion with The Guest, a stalker who learns their habits; two players watching him freeze him, and each player sees a slightly different house as atmosphere. This repo is a Rojo project holding the vertical slice: The Halfway House and The Guest. **The owner chose a gameplay rework on 2026-10-04** (`docs/plans/gameplay-rework.md`): a procedural escape with locks, keys, puzzles and a physical, hands-on house, ending in the dinner (heirlooms set at the table) and a run out of the front door. **Since 2026-10-05 (R2c) it is the only loop:** the anomalies, evidence, verdict and Witnessing are gone.

Read these before starting real work:
- `docs/DesignDoc.md`: the design and roadmap. It is the spec. Section numbers are cited throughout the code.
- `docs/plans/gameplay-rework.md`: the rework. Where it disagrees with the design doc, it wins. Sections 15 to 20 are the passes since 2026-10-06, newest last.
- `docs/plans/level-design.md`: the level design (2026-10-05): the adventure planned first, houses that follow the squad, every room with a reason, the best of many houses. Where it disagrees with the mansion plan about level design, it wins.
- `docs/ARCHITECTURE.md`: how the code implements it (every service and controller, run flow, divergence model, remote protocol, security).
- `docs/TESTING.md`: automated checks and the manual multi-client checklist (TC-01 to TC-340 as of 2026-10-16; new cases go at the end).
- `docs/NEW-MAP.md`: everything in the lobby that names a map (the tapes, the standee, the case board's photos and plan, TONIGHT, the readables, the diner's boards), to update when a new map comes out; add a row for anything new that names one.
- `docs/ART.md`: the approved visual guide; its "How the visual pass will run" list is the work order.
- `docs/progress/<date>-<pass>/`: each pass's report and before/after screenshots. `docs/progress/ROADMAP-LOG.md` is the whole history, pass by pass.
- `README.md`: setup, controls, how a run plays, the F2 debug commands, how to add rooms and puzzles.

## Working with the owner

- The owner is a **solo developer** with no artist, sound designer or programmer. Claude is the whole team: code, art direction, assets, tuning and docs.
- They're on **Windows, using PowerShell**, and newer to command-line tools. Give exact commands to copy and say which folder to run them in. Explain errors in plain words.
- They test in Roblox Studio. Three squad playtests so far (2026-10-08, 2026-10-10, 2026-10-11) and several solo ones; each pass's report has their notes.
- **Their C: drive filled up on 2026-10-05** and Studio crashed (SQLite "disk full" errors in `%LOCALAPPDATA%\Roblox\logs`), **and again on 2026-10-13** (13 MB free of 223 GB; a write to Claude's scratch folder failed). If Studio vanishes mid-session, or a write fails with ENOSPC, check free space on C: first (`df -h /c`); don't delete the owner's files to make room, tell them. Claude's own scratch can go to the repo's ignored `build/scratch` on A:. The biggest thing on C: on 2026-10-13 was Windows' page file (`C:\pagefile.sys`, system-managed, 19 GB after 11 days without a restart, with Studio, the Roblox player, Blender and the Claude app all holding memory; a restart usually shrinks it). Claude's own share is small: session scratch in `%TEMP%\claude` (old sessions' moved to `build/scratch/old-sessions`) and session transcripts in `~/.claude/projects` (1.4 GB). A hung Blender run outlives its shell: check `tasklist` for a stray `blender.exe`.
- The place is published (place id 81335718246692) and opened in Studio as a Team Create session. Studio's API access is on since 2026-10-15 (the owner), so profiles save and load in play tests, and since build .199 Studio uses stores of its own (`ConsensusProfiles_v1_Studio`, `DataService.StoreName`; every new store goes through it), never the live game's. The owner's test profile there is user 10608525. Before that, DataStore calls failed with 403 and the first-launch settings dialog appeared each run; if it still does, close it with Done at GUI ~961,636 (since build .168) or set `PlayerGui.ConsensusSettings.Enabled = false` from the Client datamodel.
- Ask before decisions that are theirs: design changes, spending money, publishing, anything on their Roblox account.

## Session start checklist

1. Work in the repo clone at `A:\111- Projects\Github\Projects`. The owner's `Games\Concensus` folder is an old ZIP copy; don't edit it.
2. Start `tools/serve-mirror.sh` detached (the `Start-Process` line below), and ask the owner to click **Connect** (or **Okay → Connect**) in Studio's Rojo panel.
3. Check `list_roblox_studios` sees Studio.
4. Run the checks.
5. In play tests, confirm `seed 1800820264` with its on-screen reply before `start`, and wait about 6 s after moving the camera before `screen_capture`, or the lighting comes out black.

## Source of truth: the repo files, synced by Rojo

- Code lives in `src/` and is synced into Studio by Rojo; the owner clicks **Connect** in Studio's Rojo plugin.
- **Never edit scripts inside Studio** (including the MCP `multi_edit` tool). Rojo overwrites those edits. Edit the files.
- **In Claude sessions, serve with `tools/serve-mirror.sh`, started detached** (PowerShell: `Start-Process "A:\Git\bin\bash.exe" -ArgumentList "tools/serve-mirror.sh" -WorkingDirectory "A:\111- Projects\Github\Projects" -WindowStyle Minimized`). Rojo 7.7.1 crashes (`change_processor.rs` line 172, "cannot find the file specified") when a file is saved through a temporary-file rename, which Claude's edit tools do, and each crash leaves the plugin needing **Okay → Connect**; the mirror copies `src/` and `assets/` into `.rojo-mirror/` in place and serves that. Never run it as a Bash background task: those die when the session pauses (a usage limit, or after 30 min), with the same result. The owner can keep using plain `rojo serve`, because normal editors save in place.
- **Check a sync before trusting a Studio check:** `cmp` the changed files in `src/` against `.rojo-mirror/src/` (if one differs, `touch` the source; a rename save once left a stale copy), then compare `#script.Source` in Studio with the file's length (on 2026-10-11 the plugin showed "connected" but stopped applying edits to existing scripts).
- **When they differ, or the plugin is down and nobody can click Connect:** stop play, push the file verbatim through `execute_luau` on the Edit datamodel (its text in StringValues, then `Source`, length checked), and restart play. HttpEnabled is off in this place, so fetching files over HTTP from Studio fails.
- `rojo build default.project.json -o Consensus.rbxlx` makes a **fresh** place. Anything made by hand in Studio that isn't in the Rojo tree is lost in that file.
- `MaterialService` is in the Rojo tree (`assets/materials/`, generated by `lune run tools/materials` from `Data/Materials.luau`). Game scripts can't create MaterialVariants at runtime.
- Textures are drawn from code, seeded (numpy + Pillow; make a venv in the scratchpad): `tools/surfaces.py` the rooms' tiling surfaces with their PBR maps, `tools/textures.py` the grime decals, photos and the Guest's masks, `tools/paper.py` the interface's paper. Studio's `generate_material` failed on every request (2026-10-02). Images go up with `upload_image` from a local `python -m http.server`; uploaded images can report "Failure" in `ContentProvider` checks while they still display fine. Ask before uploading anything to the owner's account.
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
  - Models are made by Claude in Blender only (the owner's choice, `docs/plans/visual-rework.md`): no `generate_mesh`, code-built meshes or Creator Store packs. See "The kit" below.
  - `search_asset` and `insert_asset` only for images and audio. **Never insert Creator Store models that contain scripts** (backdoor risk). Strip scripts from anything inserted.

Limits:
- Divergence bugs need two or more clients (**Test → Clients and Servers**). The MCP tools drive one Studio session, so ask the owner to run multi-client checks and report what each client saw.
- Saves need the place published with Studio API access on. Unpublished places use memory-only profiles.

## Checks: run before every commit

From the repo root (`rokit install` sets up rojo, lune, selene and stylua):

```sh
stylua src tests          # format (tabs, 120 columns)
lune run tests/run        # unit tests (733 in 110 specs as of 2026-10-16; about 90-150 s, 2-4 minutes while Studio runs, 10-15 minutes while Studio is playing)
lune run tests/compile    # every .luau file compiles
selene src tests          # lint, must be 0 errors and 0 warnings
rojo build default.project.json -o Consensus.rbxlx
```

After a change to generation or the lock planner, also run `lune run tools/completable` (every squad, difficulty and night; all houses must finish; about 2-3 minutes).

To run one spec while iterating, pass part of its file name: `lune run tests/run LockPlanner` runs every `tests/specs/*.spec.luau` whose name contains `LockPlanner`. Run the full suite before committing, and don't edit `src` or `tests` while it runs: a spec loads its modules when the runner reaches it, so a mid-run edit mixes old and new code and gives false failures.

All must pass. When MCP is available, also start a play session and check the console for errors. Report results honestly: if something wasn't checked in Studio, say so.

**Gate A** (cited throughout the docs) is the regression check on the builder: the old house (F2 `layout cells`, `seed 1800820264`) must build the same part count and part hash, which F2 `gatea` prints in Studio. Run content goes in a `RunContent` folder it leaves out. A change that moves it needs the owner's OK to re-baseline (they gave a standing OK for gameplay fixes); record the new numbers here and why in the pass's report. Current: **parts 2456, hash 116728396** (since build .196, V4b's plaster roses over the old house's five pendants; before, 2451 and 2057680657 at .190; older baselines are in the visual reports). `lune run tools/golden` (the old generator's plans, `tests/golden/`) is rerun only for an approved change too.

## Map of the code

`docs/ARCHITECTURE.md` has a table of every service and controller; this is the shape you need before reading it.

- **`src/shared`** (ReplicatedStorage.Shared) is used by both sides. `Logic/` is pure, engine-free rules run under Lune and spec'd in `tests/specs/` (generation, the lock planner, puzzles, his rules, physics feel, the takedown and cutscene timelines). `Data/` is content. `Config.luau` is every tunable. `Net.luau` declares every remote. `Lib/Rng` is the seeded RNG. `Build.luau` is the build id. `World/` holds what both sides build: `PropFactory` (every prop's gameplay skeleton) and `Kit` (dresses it in its model).
- **`src/server`** (ServerScriptService.Server). `Main.server.luau` requires every module in `Services/`, runs `Init(services)` in name order, then each `Start()` in its own thread; a service that fails to load is warned and skipped, so read the console. `Stalker/` is The Guest's brain and body (Director, Stalk, Tactician, Walker, Sight, and `GuestSkin` for his model), driven by `StalkerService`. `World/` builds the house (`LevelBuilder`, `MansionBuilder`, `Trim`, `Exterior`, `Dressing`). `Puzzles/<Kind>` is the server half of each puzzle, hosted by `PuzzleService`.
- **`src/client`** (StarterPlayerScripts.Client) mirrors it: `Controllers/` with `Init`/`Start`, `UI/` screens run by `UIController`, `Lib/` (`Ui` for the 1988 paper interface, `ViewModel` for your own arms, `GuestMask` for his face). Clients draw The Guest themselves (`GuestController` animates every joint from `Logic/GuestPose`), and the cinema (`CinemaController`, `TakedownController`, `CutsceneController`) draws catches and cutscenes from the pure timelines.
- **A run:** in a live lobby `PlaceService` first sends the squad to a reserved server of the same place, which plays the run and sends them back (Studio plays it in place); `RunOrchestrator` picks a seed; `Logic/HouseSearch` builds 12 candidate houses (`HouseSize` → `Programme` → `MansionGen` + `LayoutValidator` → `Wings` → `LockPlanner` → `Leads`), scores each with `HouseMetrics` and keeps the best; `WorldService` builds it; then locks, items, puzzles and the dinner's table are set up. The escape ends when the dinner opens the front door.
- **Passage:** every route, lock, door and barricade meets in `WorldService:SeamCost(seam, who)`; the Guest's walkers (`Logic/NavGraph`, `Stalker/Walker`) only ask it.
- **Tools outside the game:** `tools/*.luau` run with `lune run tools/<name>` (`plan <seed> mansion [locks]` prints a house, `housestats`, `lockstats`, `completable`). `tools/_*.luau` are local scratch scripts, each listed in `.git/info/exclude` (add a new one there too).

## The kit: models from Blender

Every prop, the trim, the Guest, the clothes and the tools are Blender models (visual rework V0 to V8; how each batch went is in `docs/progress/<date>-visual-v<n>/`).
- **Skin over a skeleton:** `World/PropFactory` still builds each piece's grey-box skeleton (the parts, names, joints and collisions the server uses), and `World/Kit` welds the matching mesh on, non-colliding and non-queryable, and hides the block. Sight, the hands' aim, prompts and physics use the skeleton, so gameplay changes go there, not into the mesh. `Data/Kit` maps each kind and piece to its mesh.
- **Building:** Python builds every piece procedurally (`tools/blender/kit.py`, batches in `tools/blender/kitlib/`), run headless from the repo root: `blender.exe -b --factory-startup -P tools/blender/kit.py -- <batch> [Piece]` (Blender 5.2.2 at `A:\Tools\blender-5.2.2-windows-x64\blender-5.2.2-windows-x64\blender.exe`). It writes `build/kit/<batch>/` (git-ignored; only the scripts are kept). `--bounds` prints the `centre` a lopsided piece needs. The Guest is `tools/blender/guest.py` (skinned to `Data/GuestRig`, dressed by `Stalker/GuestSkin`; primitives until every mesh loads); the clothes are `kitlib/wardrobe` (`Data/KitWear`, welded pieces: layered clothing can't be scripted).
- **Import route:** the owner imports a batch with Home → Import 3D (it uploads to their account, so ask). Each mesh's asset id goes in `Data/Kit` (`id`) and the server builds it at start (`Kit.preload`, `AssetService:CreateMeshPartAsync`); its maps go in `assets/kit/<name>.model.json`, a SurfaceAppearance Rojo syncs to `ReplicatedStorage.Kit` (game scripts can't set SurfaceAppearance maps; plugins can't set a MeshId). The importer turns glTF's +Z front to Roblox's -Z (`Kit`'s `IMPORT_TURN`) and centres a mesh on its box.
- **Before any import:** Roblox draws a face from the front only and Blender from both, so a mesh that previews fine can come in inside out and see-through. Render the exported glb with `tools/blender/preview.py -- <batch> --backfaces` (any red is a hole in Roblox), and for clothes and tools run `tools/blender/wardrobe_visibility.py` (want 0).

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

## Where we are (2026-10-16)

Build `2026-10-16.218` on `claude/overnight-foundation`, 733 tests.

- **Built:** the escape loop (rework R0 to R2c); the mansion generator and its navigation (M1 to M3); the level design L1 to L3 except its last item; the foundation and loop passes (Dread, stuck-assist, the bot, the Reckoning, the short night); the Guest rework (moods, temperaments, the mask, his animations); the fixes from three squad playtests; the readable Guest (his three rules, pestering, the family's valuables); the torch on F with your own arms and legs. The visual pass's steps 1 to 6, the polish pass and visual audit round 1.
- **The full visual rework, V0 to V8 done, V9 paused** (the owner, 2026-10-12: "the gameplay is in a good spot"; P.T. on 35mm film, models made in Blender, a diegetic 1988 UI, PC-first presets, a building storm, a few cutscenes, standard bodies in modular 80s clothing for a later shop). The plan, V0 to V9, is `docs/plans/visual-rework.md`, which opens with a table of each phase's state; each phase's report (what was built, the owner's picks, the F2 commands it added) is in `docs/progress/<date>-visual-v<n>/`.
  - Done: graphics presets and the 35mm lens (V1, the owner's pick the Retro tonemapper); windows, the night outside, moonlight and the storm (V2); the golden area and the kit rolled out to every prop, trim, door and surface (V3, V4, V4a, V4b); the Guest remodelled with a porcelain mask that cracks (V5); the classic Boy or Girl body in 80s clothes, and the tools (V6); the diegetic 1988 interface (V7); the takedown in place of the jumpscare and three cutscenes (V8).
  - **Paused after V8 (the owner, 2026-10-15: "leave a note to pick up on the rest of the visual update later"); the lobby rework goes first, in its own session (below).** To pick up later, V9 polish without the hub (its hub part, ART.md step 7, goes into the lobby rework):
    - a performance pass on the three presets: F2 `perf` extended with texture and mesh memory (`Stats:GetMemoryUsageMbForTag`) and MeshPart and light counts; the owner runs the MicroProfiler in a focused Studio window and checks a phone; triangle and light budgets per room recorded in ART.md;
    - the six moments side by side with IT WANTS IN, judged by the owner (F2 `look <spot>`, `Data/LookSpots`; `docs/reference/it-wants-in/NOTES.md`);
    - `docs/ART.md` rewritten as v2 (the film look, the kit, the lens, the storm, the interface, the takedown and cutscenes), with its TCs.
    Also left: V7's photos in the Dossier, the ping wheel, tune strip and speak box as things; more clothes for the shop; the takedown's "pinned to the wall when you pester him" opening.
- **Waiting on the owner:** the manual checks in `docs/TESTING.md`, newest TC-254 to TC-338 (several need 2–3 clients or the live game; TC-303 to TC-338 are the lobby's, TC-314 to TC-319 its cars, TC-320 to TC-324 the boutique and Marks, TC-325 to TC-330 the torches and car bits, TC-331 to TC-338 the arcade and the diner's records; TC-288 to TC-302 judge the visual rework by eye and ear: the kit, the Guest, the interface, the clothes, the surfaces, the takedowns and cutscenes, and the lens, rain and moonlight; the garden's low shrubs may read as cushions); deleting the imported `Scene` models in Workspace (the game builds the kit from ids; two are the wardrobe's); whether to flatten the sleeves' tops (they sit a little above the shoulders); the music stems, the scream and his sounds, picked by ear (`Assets.luau` lists alternatives); importing LB3's and LB4's batches (`build\kit\wardrobe\wardrobe_lb3.glb`, `wardrobe_lb4.glb`, `build\kit\mall4\mall4.glb`); a review of LB4's picks and prices (built on Claude's proposal for now); the Robux products and passes in Creator Hub (their ids into `Data/Products`); whether the safe room gets deterrents or weapons (deferred).
- **Next, in order:**
  1. **Studio findings:** fix anything the owner reports, and any console errors in play mode.
     - **The piano puzzle doesn't work in play (the owner, 2026-10-13; to fix later, with them):** the piano shows only a push prompt, never "Play", so the music box's tune can't be played back. The owner has confirmed the computer and breaker puzzles work; the others are unconfirmed. Likely cause: `Puzzles/MusicBox`'s `Kind.piano` puts the Play prompt on the piano's thin `Keys` part, and the push prompt on its body wins the look ray (`HandsController` fires the prompt you look at).
     - **Curtains hang where there's no window (the owner, 2026-10-13; for later):** the hiding curtains (Data/Props `Curtain`, the rooms' `curtain*`/`drapes` items) stand against bare wall, which feels odd. They should hang in front of a window (`Logic/Windows` places the windows; `RoomFit` places the curtains on their own), or become something that belongs on a bare wall.
     - **The kettle should work on the stove (the owner, 2026-10-13; for later):** today you press E on it and it whistles; it should be put on the range's ring and the range turned on (Services/InteractService's Kettle, the Stove prop). "Bc that just makes sense."
     - **Placement oddities seen with kit5 (2026-10-13; for later, with the curtains):** the kitchen's lone `sink` (the `Sink` kind, a lure) is the bathroom's vanity standing by itself (a kitchen wants a utility sink, or the counter's own sink as the lure); the attic's Water Tank Room is built 20x20 and `RoomFit` drops its 8x5 tank when its doorways leave no room (seeds 6 and 9 for a squad of 4 keep it, 1 and 5 don't); the tank's rust streaks came out as even stripes (`kitlib/house` `water_tank`, for a later import).
  2. **The lobby rework** (the owner, 2026-10-15): `docs/plans/lobby-rework.md` (a corner of a dead mall behind a giant shutter; party cars in the garage; the boutique, video rental, arcade, electronics and the diner's records; Marks and the prices; immersive ads; phases LB0 to LB6, the owner's questions settled). Each phase's report is in `docs/progress/2026-10-1x-lobby-lb<n>/`; the owner's eye on each is TC-303 to TC-319.
     - **Done:** LB0, one place with runs in reserved servers (build .200: `Services/PlaceService`, `Logic/ServerRole`, `Logic/RunContract`, profile version 2, `Services/MonetizationService` with no product ids yet; Studio's own stores; ServerStorage's `DebugRole` attribute tests a role, remove it after); checked live by the owner, solo: "the teleporting works". LB1a, the grey-box mall (`Data/Mall`, `World/MallBuilder`, `Logic/MallLayout` spec'd; the story, its sounds picked by ear, lightning, brownouts, the two-storey grandeur pass; the ad lightboxes kept clear). LB1b, the mall modelled in three Blender batches the owner imported (`kitlib/mall.py`, `mall2.py`, `mall3.py`; the shops and the garage laid out by hand first, as the owner asked), its lighting, and a full lobby measured (60 fps with 49 dressed stand-ins on the owner's PC; a phone not yet).
     - **LB2, parties and the video rental (build .213):** rent the case on the video store's NEW RELEASES shelf (`Services/RentalService`), get in a car in the garage (`Services/CarService`, `Logic/Cars` spec'd): the first in drives a trip sheet on the dash (`UI/Dashboard`: Normal or Hard, the night, friends only), honks, a 5-second countdown anyone can get out of, and the car drives out to the run. Back in a car after it, with the tape and a receipt (`Logic/Homecoming`, display only); a squad stranded on its run server goes in a car there. Roblox parties are kept a car; the payphone invites. The cars are numbered (bay numbers over the doors): the wagon's paint is baked in, so colours wait for LB4's paint jobs. The Ready button, the majority timer (`Logic/LobbyRules`) and the contract table are gone. Checked in Studio solo; the owner picked the horn by ear (build .214); multi-client, parties, the payphone and the live round trip are the owner's (TC-314 to TC-319). Left for later: the teleport screen (the road at night through the windscreen).
     - **LB3, the boutique and Marks (build .215):** the six garments sketched on both bodies (`kitlib/wardrobe.py`; the sheet in `docs/progress/2026-10-16-lobby-lb3/`), built so none of the free eight changed: tops worn out, high-tops in place of the trousers' shins (`Data/Wardrobe` `over`). The fitting room at the changing booth or any rack (`Services/ShopService`, `UI/Boutique`, `Logic/Closet` spec'd): try on, buy for Marks, Done keeps on what's yours; everyone wears what they own and chose, in the run too (`OutfitService`). The till (Marks packs, for you or as a gift: a wrapped box at your friend's feet), the starter pack's slip once after your first run, profile version 3. Runs pay Marks as their own sum (`Config.Pay`: about 150 a strong escape, double on the first escape of the day), XP as before.
       The owner kept all six; the batch is baked and exported (`wardrobe_lb3.glb`) and waits on their import, then its ids go in `Data/Kit` Wear and the six are checked in Studio (TC-320 to TC-322).
     - **LB4, electronics and the car bits (build .216):** built on Claude's proposal (the owner: "I'll go with your suggestions for now, until I can review it all"): three torch looks (1,000 to 2,000 Marks) and the car bits (four paints, woodgrain now a bit, whitewalls, a roof rack, a spotlight and CB aerial, a sticker, radio stations; 300 to 1,000). `Logic/Catalog` spec'd, profile version 4, the electronics counter and the garage's pegboard (`ShopService`, `UI/Wares`), the torch you carry in your hand and into the run (`PA.TorchLook`), everyone else's in their hand (`HeldTorchController`), a car in its driver's bits with their station on (`World/CarDress`, `CarService`). Server side checked in Studio; the client side wasn't seen (the display was asleep). The batch (`wardrobe_lb4.glb`, the torches; `mall4.glb`, the car split into a tintable body, trim and woodgrain, and the bits) waits on the owner's import; its measures are filed, ids to add. Report: `docs/progress/2026-10-16-lobby-lb4/`.
     - **LB5, the arcade and the diner's records (build .217):** HOUSE CALL, the Guest's three rules as a maze game (`Logic/Arcade/HouseCall`, pure and seeded, tuned with bots), on its two cabinets (`Services/ArcadeService`, `Controllers/ArcadeController` on Heartbeat, `UI/Arcade`'s coin card): the free play a day, bought plays, 100 Marks (`Logic/Arcade/Credits`, profile version 5), attract screens, watching over a shoulder, and the server's replay check. Boards as one DataStore key each (`Services/BoardService`, `Logic/Leaderboard`): the arcade's week and all-time; the diner's two boards of real runs (`Services/RecordsService`, `Logic/Records`; never Studio or F2: `DebugService.used`). Checked in Studio by script, not by hand (the display was asleep). Report: `docs/progress/2026-10-16-lobby-lb5/`.
     - **The story's foundation (2026-10-16, the owner: "I want input on the story"):** things to read in the lobby (`Data/Lore`, `Services/LoreService`, F2 `lore`; five drafts in the garage, shown only in Studio until the owner settles the story), the owner's questions and Claude's picks in `docs/plans/lobby-story.md`, the story clutter sketched (`kitlib/clutter`, kit.py `story`; `docs/progress/2026-10-16-lobby-story/`), and `docs/NEW-MAP.md`. The case number is data now (`Data/Locations` `case`), and the diner's boards count only The Halfway House's runs (`Records.Location`).
     - **Next:** the owner's answers on the story and picks from the clutter sketches; the owner imports the two batches' three files; Claude files the ids (`Data/Kit`, `assets/kit/*.model.json`) and checks them in play. The owner reviews what was built while away (LB4's picks and prices, LB5's HOUSE CALL by hand). Then LB6, ads and the rest (most of it needs the owner's account: images, ad eligibility, products). The Robux side waits on the owner's products in Creator Hub (ids into `Data/Products`). A dressed player is about 40k triangles, unmeasured on a phone: measure a shop full of outfits (F2 `perf`, `crowd`). V9's hub polish (ART.md's Hub; the menu clear of Roblox's chat hint) still to do.
  3. **The rest of the visual rework:** V9 without the hub (above).
  4. **The last of L3:** furniture laid out for play (the old M4; `Logic/RoomFurnish` doesn't exist yet; `docs/plans/level-design.md` section 3, part 4, and section 11.2).
  5. **L4, the house fights back** (the old R3, the living house: doors that become walls where nobody sees; rework section 10). The owner held it back on 2026-10-11, so ask before starting.
  6. A tutorial run that teaches the escape (never cut; today there's only a how-to-play screen).
  7. A hub place, MemoryStore matchmaking, reserved and private servers (may come with the lobby rework; the owner publishes the places in Creator Hub; walk them through it).
  8. A daily contract, and a harder Hard (more locked regions; `Config.Progression`).
  9. The second location: St. Odile Ward, with The Orderly (the archetype data exists).
- **Not built yet:** the Guest passing a lock between hunts (a lock is always a wall to him), touch controls for the hands, `navtest barricade`, the Director's scent hint. Watch: the bot still stops for him 15–24 times a run.

## Known limitations

- Everything is a kit model now, down to the switches and the plants outside (see "The kit"); the bodies are the classic Boy and Girl. About 40k triangles per dressed player, unmeasured on a phone. Leaves are solid masses (no cut-out leaves in Studio).
- Audio: the Guest's sounds, the heartbeat, gasps, the Drift layers, radio static, the hunt sting, the breath and the house hum are licensed library audio, and player footsteps are free community Creator Store samples (all in `Assets.luau`; swap any id that sounds wrong). The music states are wired for three stems (`Assets.Music`), but no music is picked yet.
- The Guest is his Blender model (V5); until its meshes load he falls back to primitives. A viewport doesn't draw his mask's see-through crack shells, so his reflections show the mask without its cracks (its missing pieces, droop and jaw do show). Between hunts he tracks you honestly, from what he saw and heard (`Logic/BeliefMap`, `Stalk:Known`).
- Voice is plain proximity chat: no routing through the audio API, no radio or muffling.
- The hub is the dead mall, modelled (LB1b's three kit batches, build .211): a full lobby measured on a PC (build .212), not yet on a phone. The six party cars are one maroon wagon, numbered, not painted. Roblox's chat hint still overlaps the hub's case folder title.
