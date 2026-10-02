# Consensus: notes for Claude

Consensus is a 2–4 player co-op horror game for Roblox. Reality only holds when two players agree on it: each player sees a slightly different house, and a learning stalker exploits the disagreements. This repo is a Rojo project holding the vertical slice from `docs/DesignDoc.md`: The Halfway House, The Guest, and three playable anomalies.

Read these before starting real work:
- `docs/DesignDoc.md`: the design and roadmap. It is the spec. Section numbers are cited throughout the code.
- `docs/ARCHITECTURE.md`: how the code implements it (services, run flow, divergence model, remote protocol, security).
- `docs/TESTING.md`: automated checks and the manual multi-client checklist (TC-01 to TC-15).
- `README.md`: setup, controls, debug commands, how to add rooms and anomalies.

## Working with the owner

- The owner is a **solo developer** with no artist, sound designer or programmer. Claude is the whole team: code, art direction, assets, tuning and docs.
- They're on **Windows, using PowerShell**, and newer to command-line tools. Give exact commands to copy and say which folder to run them in. Explain errors in plain words.
- They test in Roblox Studio. The game builds and runs there. Before this session no in-engine tuning pass had been done, and no squad playtest had happened.
- Ask before decisions that are theirs: design changes, spending money, publishing, anything on their Roblox account.

## Source of truth: the repo files, synced by Rojo

- Code lives in `src/` and is synced into Studio by Rojo. Run `rojo serve` in the repo folder, then click **Connect** in Studio's Rojo plugin.
- **Never edit scripts inside Studio** (including the MCP `multi_edit` tool). Rojo overwrites those edits. Edit the files.
- Rojo 7.7.1 can crash (`change_processor.rs` line 172, "cannot find the file specified") when a file is saved through a temporary-file rename, which Claude's edit tools do. Changes saved during a crash are missed. Run it in a restart loop from Git Bash (`while true; do rojo serve; sleep 1; done`), and restart it once after a batch of edits so Studio gets every change. The Studio plugin reconnects by itself.
- `rojo build default.project.json -o Consensus.rbxlx` makes a **fresh** place. Anything made by hand in Studio that isn't in the Rojo tree is lost in that file.
- `ServerStorage` isn't in the Rojo tree yet. When you start making Studio-authored content (room prefabs for `ServerStorage.RoomPrefabs`, generated meshes, materials):
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
  - Use the F2 debug console commands to jump states (see README: `drift`, `tier`, `hunt`, `seed`, `anomaly`, `skip`, `resolve`, `reveal`, `perf`).
- **Inspecting and live-tuning:**
  - `execute_luau`, `inspect_instance` and `search_game_tree`.
  - Tune lighting and materials live, then **copy the final values into the code or `Config.luau`**. Live edits are lost on the next sync.
- **Assets:**
  - `generate_mesh` and `generate_material` for organic shapes and surfaces code can't make well, such as the stalker's body and wallpaper.
  - `search_asset` and `insert_asset` only for meshes, images and audio. **Never insert Creator Store models that contain scripts** (backdoor risk). Strip scripts from anything inserted.

Limits:
- Divergence bugs need two or more clients (**Test → Clients and Servers**). The MCP tools drive one Studio session, so ask the owner to run multi-client checks and report what each client saw.
- Saves need the place published with Studio API access on. Unpublished places use memory-only profiles.

## Checks: run before every commit

From the repo root (`rokit install` sets up rojo, lune, selene and stylua):

```sh
stylua src tests          # format (tabs, 120 columns)
lune run tests/run        # unit tests (39 at handoff)
lune run tests/compile    # every .luau file compiles
selene src tests          # lint, must be 0 errors and 0 warnings
rojo build default.project.json -o Consensus.rbxlx
```

All must pass. When MCP is available, also start a play session and check the console for errors. Report results honestly: if something wasn't checked in Studio, say so.

## Roblox skill

`.claude/skills/roblox-game-development` is the general Roblox skill the owner chose (MIT, from `greedychipmunk/agent-skills`). Use it for Roblox best practices, performance, debugging and doc templates. This project's own patterns win where they differ. Don't copy the skill's helper scripts (`DataManager`, `RemoteManager`, …) into `src/`; the project already has `DataService`, `Net.luau` and the rest.

## Code conventions

- **Services and controllers:**
  - Every ModuleScript in `src/server/Services` is a service table with optional `Init(services)` and `Start()`.
  - `Init` only stores references to other services, for example `self.World = services.WorldService`.
  - `Start` begins work.
  - Client controllers in `src/client/Controllers` follow the same pattern.
  - Services talk through methods and `Lib/Signal`; there are no globals.
- **Server authority:** the server decides outcomes (verdicts, catches, anchors, Drift, evidence, ritual progress). It sends clients *rules*, not world state; clients only change what their own player sees.
- **Remotes:**
  - Declare them in `src/shared/Net.luau`.
  - Every client-to-server handler goes through `Net.onServer(name, { interval, burst, types }, handler)`, which rate-limits and type-checks.
  - Re-validate range, line of sight and state on the server.
  - Never send hidden truth before it's earned: herrings, the genuine key, the Source location.
- **Fairness contract:** this is design doc section 3, enforced by `Logic/LayoutValidator`.
  - Fake walls are visual only and never collidable.
  - Divergences must never trap a player.
  - Room centres and the four doorway lanes stay clear, because the stalker's `Navigator` relies on it.
- **Determinism:**
  - Generation, evidence and stalker decisions use the seeded `Lib/Rng`, forked per subsystem.
  - `math.random` is only for cosmetic client timing.
- **Data-driven:**
  - Content goes in `src/shared/Data/*` (anomalies, tells, rooms, props, tactics, archetypes, tools, pings).
  - Tunable numbers go in `src/shared/Config.luau`; mark values taken from the design doc with `(doc)`.
- **Pure logic is tested:**
  - Engine-free rules go in `src/shared/Logic` with a spec in `tests/specs/*.spec.luau`.
  - A spec returns `function(test, check, Shared, require)`.
- **PropFactory names:** the client finds tell-prop parts by child name (`Dial/Face/Time`, `Paper/Writing/Text`, `Badge/Card/Name`, `TellLight`, `EyeL`/`EyeR`, …). Keep those names when restyling props.
- **Style:** match the surrounding code. Write short comments that explain *why* and cite doc sections. Prefix private methods with an underscore (`_roomPath`, `_setup`). Use `Ui.modal` on menus so the mouse unlocks in first person.

## Git

- Work on the current branch (`claude/quirky-gauss-cfc8my`; there is no `main` yet) unless the owner says otherwise.
- Commit after each verified chunk with a clear message, and push so the work is backed up.
- Don't force-push or rewrite history. Don't open pull requests unless asked.

## Roadmap: where we are and what's next

Done: design doc Phase 1, most of the code side of Phase 2, plus some of Phase 3 (13 tactics, the squad profile, Marks and Clearance).

The agreed plan, in order:
1. **Studio findings.** Fix anything the owner reports, and any console errors you find in play mode.
2. **Visual pass.** This is Claude's job, since there is no artist. Ask the owner whether this or step 3 comes first; it was still undecided at handoff.
   1. Write a short art-direction guide (`docs/ART.md`): palette, materials, lighting moods per room type, the stalker's silhouette. Section 8 of the design doc puts the budget into lighting and audio.
   2. Make textures and decals: wallpaper, floorboards, stains, grime, notes, portraits. Use `generate_material` and generated images; upload via Studio or Asphalt.
   3. Upgrade `World/LevelBuilder` and `World/PropFactory`: trim and moldings, real light fixtures, dust particles, light shafts, per-room lighting.
   4. Model the stalker (The Guest), probably with `generate_mesh`, and give it custom animations.
   5. Iterate with `screen_capture`.
3. **Three more anomalies: Redaction, Dead Air, Mimic.** That makes 6, which the design doc says must never be cut.
   - Their tells already exist in `Data/Tells.luau`.
   - For each one, write `src/server/Rituals/<Id>.luau` (`prepare`, `new`, `Start`, `Update`, `Destroy`, a `Completed` signal; follow the existing three).
   - Set `implemented = true` in `Data/Anomalies.luau`, add it to `Data/Locations.luau`, and add its stalker twist.
4. **Tutorial run**, also never cut. Currently there's only a how-to-play screen.
5. **Hub place, MemoryStore matchmaking, reserved and private servers.** The owner must publish the places in Creator Hub; walk them through it.
6. **Daily contract**, and **two anomalies on Hard** (currently one).
7. **Second location:** St. Odile Ward, with The Orderly. The archetype data already exists.

Design doc rule (section 10): don't pile content onto a core that hasn't passed **Gate 2**, meaning the slice is fun with friends. Keep nudging the owner to run a 2–4 person squad playtest and ask testers *"Did it ever feel like it cheated?"*

## Known limitations at handoff

- The house is grey-box parts. Audio is built-in `rbxasset://` placeholders; room tone, Drift layers and stingers are empty in `Assets.luau`.
- The stalker uses default walk animations.
- Voice is plain proximity chat: no routing through the audio API, no radio or muffling.
- Hub and run share one place.
