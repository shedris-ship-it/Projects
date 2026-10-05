# Consensus

A 2–4 player co-op horror game for Roblox, built on one rule: **reality only holds when at least two people agree on it.** The house shows each Witness a slightly different version of itself. A stalker learns the squad's habits and exploits every disagreement. Find the anomaly, agree on what it is, end it, get out.

This repository is the code for the vertical slice described in [`docs/DesignDoc.md`](docs/DesignDoc.md): one location (The Halfway House), its stalker (The Guest), and three playable anomalies (Phantom Architecture, Counterfeit, Gaze). The Case Board deduction covers all 12 anomalies. It's a Rojo project, so the code lives in files and in git; you build it into a place and open it in Roblox Studio.

> **Status:** the full game loop is implemented and compiles. The pure game logic is unit-tested (39 tests, including 1,000 generated layouts). It builds and runs in Studio, but it hasn't had an in-engine tuning pass or a squad playtest yet. Art and audio are grey-box placeholders by design (doc section 10, Phase 1).

---

## Getting started

### 1. Install the tools

The project uses [Rojo](https://rojo.space) to sync files into Studio. The easiest way to get the toolchain is [Rokit](https://github.com/rojo-rbx/rokit):

```sh
rokit install          # installs rojo, lune, selene and stylua from rokit.toml
```

…or install them yourself (`cargo install rojo lune selene stylua --locked`). You also need the Rojo plugin in Studio for live sync (`rojo plugin install`).

### 2. Build or serve

```sh
rojo build default.project.json -o Consensus.rbxlx   # a place file to open in Studio
# or, for live editing:
rojo serve                                           # then click Connect in the Studio Rojo plugin
```

### 2b. Getting a Claude session's work into Studio

A Claude cloud session saves its work on its own branch on GitHub (named like `claude/ecstatic-noether-7skntv`), not on the branch you have checked out. Until you fetch that branch and switch to it, Studio keeps showing your old code. In PowerShell, in the repo folder:

```powershell
git status                       # stash or commit anything of yours first (git stash)
git fetch origin
git checkout claude/ecstatic-noether-7skntv     # the branch name Claude tells you
git pull
git log -1 --oneline             # should be the commit Claude names
```

Then stop `rojo serve` and start it again, press **Connect** (or **Okay → Connect**) in Studio's Rojo panel, **accept every change in its dialog**, and stop and restart Play. To check it worked, look for `build 2026-…` on the hub panel, press **F2** (the first line shows the client and server build ids, and says MISMATCH if the place is half-synced), or read `[Consensus] server build …` in the Output window. Compare the id with the one Claude tells you.

### 3. Studio settings

In **Game Settings** (after publishing the place once):

- **Security → Enable Studio Access to API Services** so progress saves. Without it the game still runs, with memory-only profiles.
- **Communication → enable voice chat** if you want proximity voice. Text-only play is fully supported through pings and callouts.

### 4. Play it

- **Solo:** press **Play**. A Companion Witness joins solo runs so you can still anchor things.
- **Squad:** **Test → Clients and Servers → 2–4 players → Start**. Divergence bugs only show up with two or more clients (doc section 7), so test like this daily.

In the hub, set the contract's difficulty and press **Ready**. The run starts when everyone in the hub is ready. Tools are found in the house, on tables, desks and dressers: walk up and press **E** to take one.

---

## Controls

| Action | Keyboard | Gamepad | Touch |
| --- | --- | --- | --- |
| Witness (hold) | **Q** | LB | Witness button |
| Use the tool in your hands | **R** | RB | Tool button |
| Choose a slot (1 is the flashlight, 2 and 3 are found tools) | **1 2 3** or mouse wheel | D-pad down (next) | Tap a slot |
| Put the tool in your hands down | **X** | none | none |
| Flashlight | **F** | D-pad up | Light button |
| Sprint (walking is slow on purpose) | **Shift** | L3 | Run button |
| Ping wheel (hold, aim, release) | **G** | D-pad left | Ping button |
| Structured callout | **C** | D-pad right | Call button |
| Case File (board, evidence, map) | **Tab** | Back | Case button |
| Doors, hide, revive, pick up, light shrine | **E** (prompts) | X | tap prompt |
| Brace a door | **B** | Y | prompt |
| Hold breath / leave hiding spot | **Space** / **E** | A / B | buttons |
| Settings and how to play | **F1** | | Lobby button |
| Debug overlay and console | **F2** (Studio) | | |

## How a run plays

1. **Arrival (3 min).** The house is quiet and the stalker is dormant. Small harmless divergences teach the core move: something looks odd, say so, then both of you hold **Q** on it within 4 seconds to **Anchor** it.
2. **Investigation.** True tells and red herrings are spread around the house. Anchoring a tell confirms it and pins it to the Case Board. Anchoring a herring debunks it. Drift rises: slowly by itself, faster when someone wanders off alone, sharply on mistakes. The stalker escalates from a figure only you can see, to something closer every time you look, to intrusions, to hunts.
3. **Verdict.** At the Dining Room table, call a deliberation and name the anomaly together. A wrong verdict costs 15 Drift and starts a hunt.
4. **Resolution.** Perform the anomaly's ritual while the stalker runs its final hunt:
   - *Phantom Architecture, Triangulate:* every Witness Witnesses the same flickering seam, three times. Some flickers are yours alone.
   - *Counterfeit, Cross-check:* find the key whose description reads the same to everyone and turn it in the strongbox with the whole squad present.
   - *Gaze, Stare-down:* everyone holds their eyes on the Source portrait while it comes for your backs.
5. **Extraction and Dossier.** Reach the exit, then read what the stalker learned about you.

Getting caught downs you rather than killing you: a teammate can revive you within 45 seconds. A second catch makes you **Lost**, and you play on as an **Echo**: you can still talk and can ping one hint a minute. The run fails if Drift reaches 100 or every Witness is Lost.

---

## Debug console (F2)

These commands work in Studio, or on live servers for user ids listed in `Config.Debug.AllowedUserIds`:

```
help · overlay on|off · drift <0-100> · tier <0-4|off> · hunt
seed <n> · anomaly <PhantomArchitecture|Counterfeit|Gaze|off>   (applies to the next run)
start · end · skip (end Arrival) · resolve (jump to the ritual) · reveal (anomaly + evidence)
lights on|off · focus · perf · steps (tests footstep sounds) · clip (lists overlapping props)
down [name] · revive [name]   (yourself if no name; any part of a display name works)
guest here [studs] · guest walk [studs] [speed] · guest pose <Idle|Hold|Walk|Run|Creep|BackAway|Peek|Zoom|Lunge|Bow>
guest form <0-2> · guest smile <0-1> · guest lean <-1..1> · guest off   (pose The Guest for screenshots)
guest arrive (knock now) · guest move <Peek|DoorwayStand|CreepBehind|ShadowBehind|StareDown|DistantRoam> · guest peeks · guest scare
layout cells|mansion|default (the next run's house) · plan (prints the house plan to Output) · where (your room and floor, and his)
navtest [fast] (the Guest walks every room; results in Output) · navtest room <id> [fast] (one room, traced) · navtest retreat [n] (back-aways from awkward spots)
```

The overlay shows the seed, Drift and where it came from, the stalker's mode, tier, target, chosen tactic, top-three scores and memory, the squad-profile signals, and client and server performance numbers.

---

## Project structure

```
default.project.json     Rojo tree: Shared → ReplicatedStorage, Server → ServerScriptService,
                         Client → StarterPlayerScripts; Lighting/voice/streaming settings
src/shared/              ReplicatedStorage.Shared
  Config.luau            every tunable number (doc values are marked)
  Assets.luau            sound and texture ids: swap placeholders for real audio here
  Constants.luau, Net.luau (remote list, rate limits, argument validation)
  Data/                  Anomalies (12), Tells (34), Rooms (22 templates), Props, Tactics (13),
                         Archetypes, Locations, Tools, Pings
  Logic/                 pure, unit-tested: LevelGraph, LayoutValidator, Graph, EvidencePlanner,
                         PerceptionPlanner, CaseBoard, DriftModel, Verdict, SquadProfile,
                         UtilityAI, ScareDeck, DirectorModel, Progression
  World/PropFactory      grey-box furniture and tell props (also used by clients for phantoms)
src/server/
  Main.server.luau       loads every service: Init(services) then Start()
  Services/              RunOrchestrator, WorldService, LobbyService, PlayerStateService,
                         WitnessService, DriftService, DivergenceService, AnomalyService,
                         CaseBoardService, VerdictService, HidingService, DoorService,
                         ToolService, NoiseService, SquadProfileService, StalkerService,
                         CompanionService, DataService, Telemetry, DebugService
  Stalker/               StalkerModel, Walker, Clearance, Retreat, Perception, Tactician, Director
  Rituals/               PhantomArchitecture, Counterfeit, Gaze
  World/LevelBuilder     layout → parts (rooms, flippable seams, doors, lights, hiding spots)
src/client/
  Main.client.luau       loads every controller
  Controllers/           State, Perception (divergence), Witness, Action (input/camera/tools),
                         Audio, Effects, UI
  UI/                    Hud, Toasts, PingWheel, CaseFile, Verdict, Lobby, Dossier,
                         Settings, Overlays, DebugOverlay
  Lib/                   Ui helpers, PhantomFactory
tests/                   Lune test runner, harness and specs
docs/                    DesignDoc, ARCHITECTURE, TESTING
```

See [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) for how the systems fit together, the remote schema and the security model.

---

## Making it yours

- **Tuning:** everything numeric is in `src/shared/Config.luau`. Values that come straight from the design doc are marked `(doc)`.
- **Audio:** `src/shared/Assets.luau`. The defaults are built-in `rbxasset://` sounds so the game makes noise out of the box. Room tone, the Drift layers, the heartbeat, radio static and the hunt sting are empty until you add real assets; that's the biggest quality jump per dollar (doc section 11).
- **Hand-built rooms:** put a Model named after a room template id (for example `kitchen`) in `ServerStorage.RoomPrefabs`. The generator still builds walls, floors, doors and seams; your model replaces the furniture. Conventions:
  - The model's pivot is the room's floor centre, with 40×40 studs of space.
  - Keep the centre and the four doorway lanes clear.
  - Tag one light `ConsensusRoomLight`; it becomes the key light.
  - Give each hiding-spot part a `HideCategory` attribute (`locker`, `wardrobe`, `bed`, `table`, `curtain`), with its front (LookVector) facing the room. Optional `Capacity` and `Noise` attributes.
  - Give the dining table a `Deliberation` attribute.
  - Slots for tells come from the template's `wallSlots` and `floorSlots`.
- **New rooms:** add a template to `Data/Rooms.luau`. The tests check that furniture stays out of the lanes and doesn't overlap.
- **A new anomaly:** its tells are already in `Data/Tells.luau`. Write `src/server/Rituals/<AnomalyId>.luau` (implement `prepare`, `new`, `Start`, `Update`, `Destroy` and a `Completed` signal, like the existing three), set `implemented = true` in `Data/Anomalies.luau`, and add it to the location in `Data/Locations.luau`.

## Development checks

```sh
lune run tests/run        # unit tests (generator fairness, deduction, Drift, verdicts, AI scoring…)
lune run tests/compile    # compiles every .luau file
selene src tests          # lint (uses roblox_lite.yml, so no internet is needed)
stylua src tests          # format
rojo build -o Consensus.rbxlx
```

## What's in this build, and what's next

| Area | Built | Next (from the design doc) |
| --- | --- | --- |
| Core loop | Hub, Arrival → Investigation → Verdict → Resolution → Extraction → Dossier, win/lose, downs, revives, Echoes | Tutorial run, daily contract |
| Witnessing | Anchoring windows, Focus, pings, callouts, Companion Witness for solo | Voice routing through the audio API (muffling, radio) |
| Divergence | Per-player rules, 34 tells across 9 presentation types, calibration, phantom and fake doors, rooms rearranging, false consensus | Voice-based tells (Dead Air) |
| Generation | Seeded 10–16 room layouts, loops, fairness validator, authored fallback, prefab override | 20+ hand-lit prefabs per location |
| Stalker | Director, Tactician (13 tactics, utility AI over a learned squad profile), Body (vision, hearing, memory), tiers 0–4, observation rule, hiding inspection, doors, retreat | Custom animations, The Orderly, bot-squad tests |
| Anomalies | Phantom Architecture, Counterfeit, Gaze playable; all 12 on the Case Board | Redaction, Dead Air, Mimic (Alpha), then Umbra and The Echo (Launch) |
| Tools | Witness Camera, Lantern (+ shrines), Radio, Plumb Line | Tool skins (cosmetics) |
| Progression | Marks, Clearance 1–50, Dossier entries, session-locked saves with migrations | Store, private servers, season pass |
| Polish | Drift-driven post-processing, flicker, captions, accessibility settings, low-end mode | Art, lighting, and audio passes |
| Platform | Single place for hub and run | Hub/run places, MemoryStore matchmaking, reserved servers |

Known limitations:
- The house is grey-box parts.
- The stalker uses default walk animations with a tilted head instead of a custom rig.
- Hard difficulty uses one anomaly, not two.
- Player voice isn't routed through the audio API yet, so voice is plain proximity chat.
