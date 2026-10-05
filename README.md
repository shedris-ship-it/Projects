# Consensus

A 2–4 player co-op horror game for Roblox. A squad is locked inside a lived-in 1988 mansion with **The Guest**, who learns their habits. To get out they must open the house room by room (keys, notes, puzzles that want two people in two places) and lay the family's heirlooms at the dining table for him. When the last place is set, the dinner begins, every lock springs open, and they run for the front door while he hunts them. Each player still sees a slightly different house, but only as atmosphere; two people watching The Guest freeze him.

This repository is the vertical slice: one location (The Halfway House, generated as a mansion), its stalker (The Guest), and the escape loop from [`docs/plans/gameplay-rework.md`](docs/plans/gameplay-rework.md), which replaced the original clue hunt of [`docs/DesignDoc.md`](docs/DesignDoc.md). It's a Rojo project, so the code lives in files and in git; you build it into a place and open it in Roblox Studio.

> **Status (2026-10-05):** the escape loop is complete and runs in Studio: locks, keys and leads, six kinds of puzzle and lock, a hands-on physical house, barricades and closets, a Guest who wants his dinner, a map and journal, the dinner and the run out. Each house is now planned as an adventure (wings, shortcuts, going back), sized for the squad, and the best of 12 (`docs/plans/level-design.md`). The pure logic is unit-tested (389 tests). It has been played solo in Studio, but **it hasn't had a squad playtest yet**; that's next (`docs/TESTING.md`, TC-68 onward).

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
- **Communication → enable voice chat** if you want proximity voice. Text-only play is fully supported through pings, callouts and the say box.

### 4. Play it

- **Solo:** press **Play**. A Companion joins solo runs: it follows you, helps push, backs up a stare and revives you.
- **Squad:** **Test → Clients and Servers → 2–4 players → Start**. Several things (the dinner at the table, crank doors, the dumbwaiter, barricades, the shared map) only show their worth with two or more clients.

In the hub, set the contract's difficulty and press **Ready**. The run starts when everyone in the hub is ready. Tools (a Lantern, a Radio) are found in the house on tables, desks and dressers: walk up and press **E** to take one.

---

## Controls

| Action | Keyboard | Gamepad | Touch |
| --- | --- | --- | --- |
| Choose a slot (1 the flashlight, 2 and 3 found tools, 4 your bare hands; the torch clips to your shirt in 2 to 4) | **1 2 3 4** or mouse wheel | D-pad down (next) | Tap a slot |
| Drag a door, drawer, cupboard door, lid or closet door, or pick something up | hold **left mouse** | hold RT (right stick moves your hand) | none yet |
| Push furniture (heavy pieces need friends; walk backwards to pull) | hold **left mouse** on it and walk | hold RT and walk | none yet |
| Throw what you carry (tap: a lob; hold: wind up) / bring it nearer or further | **right mouse** / mouse wheel | LT | none yet |
| Doors, drawers, notes, keys at a lock, puzzles, fixtures, switches, hiding, revive, set a place at the table | **E** (prompts) | X | Tap the prompt |
| Crank ratchet, dumbwaiter jam box | **Q** (prompt) | LB | Tap the prompt |
| Squeeze past a barricade (hold) | **Q** (prompt) | R3 | Tap the prompt |
| Brace a door | **B** (prompt) | LB | Tap the prompt |
| Use the tool in your hands | **R** | RB | Tool button |
| Put the tool in your hands down | **X** | none | none |
| Flashlight | **F** | D-pad up | Light button |
| Sprint (walking is slow on purpose) | **Shift** | L3 | Run button |
| Map and journal | **Tab** | Y | Map button |
| Ping wheel (hold, aim, release) | **G** | D-pad left | Ping button |
| Structured callout | **C** | D-pad right | Call button |
| Say something aloud (he hears it) | **Enter** or **/** | | |
| Hold breath / leave a hiding spot | **Space** / **E** | A / B | buttons |
| Leave a puzzle screen or the note reader | **Esc** | B | |
| Settings and how to play | **F1** | | Lobby button |
| Debug overlay and console | **F2** (Studio) | | |

## How a run plays

1. **Arrival.** The front door locks behind you. Through the archway the dining table is laid for a guest, with an empty place for each heirloom you must find. The part of the house around the hall is open; the rest is behind locked doors. At about 90 s, three knocks: he's inside.
2. **Opening the house.** Keys, codes and power open the next part of the house, and each part holds the way into the next:
   - **Leads, not rummaging.** Notes (press E to read) say which drawer something is in; a keepsake box on a dresser, a locked glass case (pick its lock, or throw something through the glass) or a key rack hold the rest.
   - **Marks.** Every locked door that takes something has a mark on its plate (a star, a phone, scissors...), and its key, code or breaker carries the same mark: the phone key fits the door with a phone. A key is always found once its door can be seen. Holding the wrong key, a door says so ("Your umbrella key doesn't fit. This lock has a sun."), and the objective line says where a key you hold fits.
   - **Keys** go on your own ring and are used up at their door; drop one for a friend from the journal, which also says where each key's door is once someone has seen it. **Bolts** slide back only from their own side: shortcuts ("Bolted from the other side. There must be another way round.").
   - **Puzzles:** the home computer (a word-guessing terminal that prints a padlock's code), the breaker panel (power a door without tripping the main), the wall safe (listen for the click), the music box and the piano (play its tune back).
   - **Two-person locks:** a crank door (one cranks, one goes through; alone, the slow and loud ratchet) and the dumbwaiter (one cranks downstairs, one takes the heirloom out upstairs; alone, jam the crank).
   - The house is physical: pick things up and throw them (a hit staggers him), push furniture (beds need two), barricade a doorway, hide in a walk-in closet with the doors shut, flush a toilet or leave a tap running to send him the wrong way, switch lights off.
3. **He wants his dinner.** Each step forward wakes a hunt a minute or two later. While you carry an heirloom he knows which room you're in. Leave one lying and he puts it back where you found it. Carry them all and he waits at the head of the table.
4. **The dinner.** Set the last heirloom (carry it to its place, hold E): the lights die, he takes his seat, the way from the dining room to the hall seals, every other lock springs open and the front door opens. Run out the long way while he hunts you.
5. **Debrief.** The Dossier says who opened what, who carried what, the closest call, and what he learned about you.

Getting caught downs you: a teammate can revive you within 15 seconds (a 4-second hold). Caught again, you're **Lost** and play on as an **Echo**: you can talk, ping one hint a minute, and drift through doors (but not locked ones). The run fails if Drift reaches 100 or every player is Lost. Drift rises with time, noise and splitting up, faster when you stall; progress lowers it.

---

## Debug console (F2)

These commands work in Studio, or on live servers for user ids listed in `Config.Debug.AllowedUserIds`. In Studio, a command written to ServerStorage's `DebugCommand` attribute runs the same way (the reply lands in `DebugReply`).

```
help · overlay on|off · drift <0-100> · tier <0-4|off> · hunt · perf · lights on|off · gatea
seed <n> · layout cells|mansion|default · squad <1-4|auto>   (apply to the next run)
start · end · skip (end Arrival) · resolve (serve the dinner)
act (the run's act, and any woken hunt) · arm [seconds] (wake a hunt) · scent · table · tidy
goto <room> | goto <x> <y> <z> · plan (the house plan to Output) · where · chute [here] (down the laundry chute)
house (why this house: the search's scores, the scorecard, the wings, every room's reasons)
locks · unlock <seam|all> (all: every shutter latched up too) · try <seam> · give <token> · items · leads [go <token> [note]]
puzzle [kind] (stand at a station and open it) · solve [puzzle] · ui map|journal|close
switch [list] · crank [go|up] · barricade [here|squeeze|shove] · piece [id|show]
grab [id] · throwat [case] · stun [seconds] · lure [radius] · fling <room> <room> <speed>
push <dx> <dz> [people] [seconds] · drag <right> <away> · door <room> <room> <angle 0-100>
furniture open|shut [all] · block <room> <room> · block off
navtest [fast] · navtest room <id> [fast] · navtest retreat [n]
down [name] · revive [name] · steps · clip
guest here [studs] · guest walk · guest pose <name> · guest form <0-2> · guest smile <0-1>
guest lean <-1..1> · guest move <name> · guest peeks · guest arrive · guest window · guest scare · guest off
```

The overlay shows the seed, Drift and where it came from, the stalker's mode, tier, target, chosen tactic, top-three scores and memory, the squad-profile signals, and client and server performance numbers.

---

## Project structure

```
default.project.json     Rojo tree: Shared → ReplicatedStorage, Server → ServerScriptService,
                         Client → StarterPlayerScripts; MaterialService; Lighting/voice settings
src/shared/              ReplicatedStorage.Shared
  Config.luau            every tunable number (doc values are marked)
  Assets.luau            sound and texture ids
  Build.luau             the build id, shown in the hub, F2 and Output
  Constants.luau, Net.luau (remote list, rate limits, argument validation)
  Data/                  Rooms, Props, Physical (what's carried or pushed, and how heavy),
                         Notes, Interactables, Tactics, StalkMoves, Archetypes, Locations,
                         Tools, Pings, Words, ClockTimes, Atmosphere, Materials, Footsteps
  Logic/                 pure and unit-tested: the generators (LevelGraph, MansionGen, ...),
                         LockPlanner, Leads, NoteText, PuzzleKinds and Puzzles/*, Acts,
                         DirectorModel, DriftModel, Scent, StalkRules, NavGraph, Heft, Throw,
                         Articulation, Push, Barricade, Atmosphere, Progression, ...
  World/PropFactory      furniture and props, built from code
src/server/
  Main.server.luau       loads every service: Init(services) then Start()
  Services/              RunOrchestrator, WorldService, LockService, ItemService, PuzzleService,
                         FinaleService, CrankService, MapService, InteractService, DecorService,
                         HandsService, DoorService, FurnitureService, PushService, HidingService,
                         StalkerService, CompanionService, RunLogService, DriftService, ...
  Puzzles/               each puzzle's station in the house
  Stalker/               Director, Stalk, Tactician, Body, Sight, Perception, Walker,
                         Clearance, Retreat, NavTest, StalkerModel
  World/                 LevelBuilder, MansionBuilder, Trim, Dressing, Items, LeadProps, ...
src/client/
  Main.client.luau       loads every controller
  Controllers/           State, Action, Hands, Motion, Guest, Perception, Audio, Effects, UI, ...
  UI/                    Hud, Hotbar, Map, Reader, Puzzle and Puzzles/*, Dossier, Lobby,
                         Settings, Toasts, PingWheel, SpeakBox, DebugOverlay, ...
tests/                   Lune test runner, harness and specs
tools/                   plan, lockstats, golden, materials, textures.py, studio/partdump
docs/                    DesignDoc, plans/, ARCHITECTURE, TESTING, ART
```

See [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) for how the systems fit together, the remote schema and the security model.

---

## Making it yours

- **Tuning:** everything numeric is in `src/shared/Config.luau`. Values that come straight from the design doc are marked `(doc)`. The escape's mix is in `Config.Progression` (which gate kinds and keepers are on, and their weights), `Config.Leads`, `Config.Pacing` and `Config.Barricade`.
- **Audio:** `src/shared/Assets.luau`. Licensed Creator Store library audio by id; swap any that sounds wrong.
- **Notes:** the family's notes are templates in `Data/Notes.luau`, filled in by `Logic/NoteText`. Keep them within the Moderate content rating.
- **A new puzzle:** pure rules in `src/shared/Logic/Puzzles/<Kind>.luau` (generate, view, start, step, solved, public, parse, solve; `tests/specs/Puzzles.spec` holds every kind to it), a station in `src/server/Puzzles/<Kind>.luau`, a screen in `src/client/UI/Puzzles/<Kind>.luau`, an entry in `Logic/PuzzleKinds`, and a keeper or gate in `Logic/LockPlanner` switched on in `Config.Progression`.
- **New rooms:** add a template to `Data/Rooms.luau`. The tests check that furniture stays out of room middles and doorway lanes and doesn't overlap.
- **Print a house:** `lune run tools/plan <seed> mansion locks` prints the floor plan with its locks; `lune run tools/lockstats` prints how often each lock and puzzle turns up.

## Development checks

```sh
stylua src tests          # format
lune run tests/run        # unit tests
lune run tests/compile    # compiles every .luau file
selene src tests          # lint (uses roblox_lite.yml, so no internet is needed)
rojo build default.project.json -o Consensus.rbxlx
```

## What's in this build, and what's next

| Area | Built | Next |
| --- | --- | --- |
| Core loop | Hub, Arrival → Investigation → the dinner → Extraction → Dossier; locks, keys, leads, puzzles, heirlooms; acts and progress-woken hunts; win/lose, downs, revives, Echoes | **A squad playtest**, then the living house (R3: doors that become walls where nobody sees, house events), a tutorial run, a daily contract |
| The house | The mansion generator (two main floors, 15–22 rooms by squad size, plus a cellar and/or an attic, each a locked wing of its own on top of the squad's), the adventure planned first (wings, a loop in each, shortcuts, the backtrack, double locks), every room with a reason, the best of 12 houses; servants' passages behind hidden doors (bookcases, panels); a laundry chute; lighting, trim, materials, grime, fixtures, switches and circuits, walk-in closets | House types (L, U round a courtyard, H, a tower stair), narrow corridors with closets, archways and glass-panelled doors; **a squad playtest**; the family and furniture laid out for play (`docs/plans/level-design.md`) |
| Physics | Carry and throw with weight, doors and drawers with momentum, furniture by weight, barricades | Touch controls for hands |
| Stalker | Director with acts, Tactician (13 tactics over a learned squad profile), stalking between hunts, heirloom scent, errands (the table, tidying), navigation on both floors, barricades | The Orderly (St. Odile Ward) |
| Progression | Marks for outcome and progress, Clearance 1–50, the Dossier, session-locked saves | Store, private servers, season pass |
| Platform | Single place for hub and run | Hub/run places, MemoryStore matchmaking, reserved servers |

Known limitations:
- Furniture is still simple geometry; no music exists yet.
- The Guest can't pass a locked door between hunts yet (a lock is always a wall to him).
- Hands, pushing and throwing have no touch controls yet.
- Player voice is plain proximity chat.
