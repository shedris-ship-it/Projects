# Consensus

A 2–4 player co-op horror game for Roblox. A squad is locked inside a lived-in 1988 mansion with **The Guest**, who learns their habits. To get out they must open the house room by room (keys, notes, puzzles that want two people in two places) and lay the family's heirlooms at the dining table for him. When the last place is set, the dinner begins, every lock springs open, and they run for the front door while he hunts them. Each player still sees a slightly different house, but only as atmosphere; two people watching The Guest freeze him.

This repository is the vertical slice: one location (The Halfway House, generated as a mansion), its stalker (The Guest), and the escape loop from [`docs/plans/gameplay-rework.md`](docs/plans/gameplay-rework.md), which replaced the original clue hunt of [`docs/DesignDoc.md`](docs/DesignDoc.md). It's a Rojo project, so the code lives in files and in git; you build it into a place and open it in Roblox Studio.

> **Status (2026-10-05):** the escape loop is complete and runs in Studio: locks, keys and leads, six kinds of puzzle and lock, a hands-on physical house, barricades and closets, a Guest who wants his dinner, a map and journal, the dinner and the run out. Each house is now planned as an adventure (wings, shortcuts, going back), sized for the squad, and the best of 12 (`docs/plans/level-design.md`). The pure logic is unit-tested (414 tests). It has been played solo in Studio, but **it hasn't had a squad playtest yet**; that's next (`docs/TESTING.md`, TC-68 onward).

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

- **Solo:** press **Play**. There is no companion (removed 2026-10-06). Alone, a lit Lantern room is safe ground and charges your torch; downed, you crawl to the light or into a hiding place's mouth to get up; smelling salts bring you round once; you push harder; after a catch he lets you go. Three downs and you're Lost (two on Hard).
- **Squad:** **Test → Clients and Servers → 2–4 players → Start**. Several things (the dinner at the table, crank doors, the dumbwaiter, barricades, the shared map) only show their worth with two or more clients.

In the hub, set the contract's difficulty and the night's length (**Night: Full** is the squad's house; **Short** is one wing and two heirlooms, a dinner in about ten minutes) and press **Ready**. The run starts when everyone in the hub is ready, or once half of you have been ready for thirty seconds: the ready go in, the rest stay in the hub. Tools (a Lantern, a Radio) are found in the house on tables, desks and dressers: walk up and press **E** to take one.

---

## Controls

| Action | Keyboard | Gamepad | Touch |
| --- | --- | --- | --- |
| Choose a slot (1 the flashlight, 2 and 3 found tools; the torch clips to your shirt in 2 and 3, an empty one is a free hand) | **1 2 3** or mouse wheel | D-pad down (next) | Tap a slot |
| Use what you're looking at (one marker says what E does: open, pick up, play the piano, hide, a switch) | tap **E** | X; hold RT to drag | Tap the prompt |
| Drag a door, drawer, cupboard door, lid or closet door | hold **E** (or **left mouse**) and move the mouse | hold RT (right stick moves your hand) | none yet |
| Push furniture (heavy pieces need friends; walk backwards to pull) | hold **E** (or **left mouse**) on it and walk | hold RT and walk | none yet |
| Throw what you carry (tap: a lob; hold: wind up) / put it down / nearer or further | **click** or **right mouse** / **E** / mouse wheel | LT | none yet |
| Notes, keys at a lock, puzzles, fixtures, switches, hiding (tap); revive, set a place at the table (hold) | **E** on it | X | Tap the prompt |
| Pry the boards off, cut a chain (the crowbar or the bolt cutters in your hands) | hold **left mouse** or **R** on it | hold RT or RB | Tool button |
| Crouch (a silent creep) | hold **Ctrl** (a setting makes it a toggle) | B | Crouch button |
| Hide in a wardrobe, a locker or a closet: open it, step in, pull the door shut (E on it); E on the door again to get out | **E** on the door | X | Tap the prompt |
| Peek out from under a bed, a table or a curtain (he may notice) | hold **right mouse** | hold LT | Peek button |
| Crank ratchet, dumbwaiter jam box | **Q** (prompt) | LB | Tap the prompt |
| Squeeze past a barricade (hold) | **Q** (prompt) | R3 | Tap the prompt |
| Brace a door | **B** (prompt) | LB | Tap the prompt |
| Bolt a bathroom door from inside | **V** (prompt) | X | Tap the prompt |
| Trace the fuse box's wiring (alone; hold 6 s) | **T** (prompt) | Y | Tap the prompt |
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
   - **Boards and chains.** A boarded door needs the crowbar, a chained one the bolt cutters; each lies in plain sight before its first door and opens every door of its kind. Take the tool in your hands (its slot), look at the boards or the chain and hold the click (or R): a plank comes away each stroke while you hold on, or the chain snaps. It's loud (he may come), so keep a lookout; work already done stays done.
   - **Steps inside a wing** (three or four players). In a bigger wing, what you came for (the next key, or an heirloom) may be shut away inside it: a side room boarded up or chained, or a chest or the fridge nailed or chained shut. The tool for it lies across the wing or in the wing next door, so someone goes to fetch it while the others carry on.
   - **The map saves time.** A room you've been in gets a pencil tick once nothing you need is left in it; what you've seen but not done (a lock, a safe, a chained chest) has a ring. Read the house plans (blueprints on a desk or a workbench) and that floor's rooms go on everyone's map. The journal says who carries which key and tool.
   - **The safe room (optional).** A steel door marked SAFE ROOM, powered from the fuse box. Inside: batteries (a fresh set each), a Lantern, a Radio or the plans of another floor. The run never needs it: it's a gamble of time and noise.
   - **The rooms' own lures.** A kettle that shrieks 20 s after you set it, a washing machine that also hides your footsteps, a record player, the car horn (once), wind-up toys that walk off ticking.
   - **Knowing where he is.** The servants' bell board rings and drops a flag when he walks into a room with a bell pull; the nursery's baby monitor lets you hear a room you've left the transmitter in. A bathroom door bolts from inside (V) and holds him a few seconds. Answer the ringing phone and he hears where you are.
   - **Landmarks.** Every corridor has something you can name on its wall (a stag's head, the big portrait, a tapestry, a stopped clock, a ship's wheel), on the map once you've been there. The children's crayon drawings say where they hid.
   - **Doors swing away from you.** Press E on a shut door from the side it opens towards and it swings the other way, into the next room.
   - **The house key.** One key a run isn't used up: its mark is also on a side room or two you passed earlier, each with an heirloom inside. Go back for them.
   - **Keys** go on your own ring and are used up at their door; drop one for a friend from the journal, which also says where each key's door is once someone has seen it. **Bolts** slide back only from their own side: shortcuts ("Bolted from the other side. There must be another way round.").
   - **Puzzles:** the home computer (a word-guessing terminal that prints a padlock's code), the breaker panel (power a door without tripping the main; its strips are numbered, and the names are on a brass plate by the door it powers, so one reads and one flips; alone, hold T on the panel to trace the wiring for 20 s), the wall safe (listen for the click), the music box and the piano (play its tune back).
   - **Two-person locks:** a crank door (one cranks, one goes through; alone, the slow and loud ratchet) and the dumbwaiter (one cranks downstairs, one takes the heirloom out upstairs; alone, jam the crank).
   - The house is physical: pick things up and throw them (a hit staggers him), push furniture (beds need two), barricade a doorway, shut yourself in a wardrobe, a locker or a walk-in closet and look out through its slats, flush a toilet or leave a tap running to send him the wrong way, switch lights off.
3. **He wants his dinner.** Each step forward wakes a hunt a minute or two later. While you carry an heirloom he knows which room you're in. Leave one lying and he puts it back where you found it. Carry them all and he waits at the head of the table.
4. **The dinner.** Set the last heirloom (each place's card names the one it wants; carry it up to the table and it's set): the lights die, he takes his seat, the way from the dining room to the hall seals, every other lock springs open and the front door opens. Run out the long way while he hunts you.
5. **Debrief.** The Dossier says who opened what, who carried what, the closest call, and what he learned about you.

Getting caught downs you: a teammate can revive you within 15 seconds (a 4-second hold), or you crawl into a lit Lantern room or to a hiding place's mouth and get up by yourself (alone you have 20 seconds). Smelling salts in a slot bring you round in 3 seconds. Just up, he leaves you alone for 8 seconds: run. A hunt that caught someone is never "survived". Three downs (two on Hard) and you're **Lost**: you play on as an **Echo** who can talk, ping one hint a minute (the ping knocks on the nearest shut door, and he hears it) and drift through doors (but not locked ones). Drift rises with time, noise and splitting up, faster when you stall; progress lowers it. At Drift 100 the house has had enough: **the Reckoning**, a hunt that never ends, in which no room protects anyone and the front door opens only for the dinner. The run ends when everyone is out, or everyone is Lost.

---

## Debug console (F2)

These commands work in Studio, or on live servers for user ids listed in `Config.Debug.AllowedUserIds`. In Studio, a command written to ServerStorage's `DebugCommand` attribute runs the same way (the reply lands in `DebugReply`).

```
help · overlay on|off · drift <0-100> · tier <0-4|off> · hunt · perf · lights on|off · gatea
watch (the stare right now: watchers, lit, dark, beam, the room, the hold) · summary (the run in numbers, to Output)
event <id> (a house event where you stand: radioOn, phoneRings, lightsDie, overhead, doorAjar, knockInside, clockStrikes)
seed <n> · layout cells|mansion|default · squad <1-4|auto> · night full|short   (apply to the next run)
start · end · skip (end Arrival) · resolve (serve the dinner)
act (the run's act, dread, and any woken hunt) · arm [seconds] [false] (wake a hunt, or only its telegraph) · scent · table · tidy
goto <room> | goto <x> <y> <z> · plan (the house plan to Output) · where · chute [here] (down the laundry chute)
house (why this house: the search's scores, the scorecard, the wings, every room's reasons)
locks · unlock <seam|all> (all: every shutter latched up too) · try <seam> · give <token> (a key, an heirloom, tool:Crowbar) · items · leads [go <token> [note]]
puzzle [kind] (stand at a station and open it) · solve [puzzle] · ui map|journal|close
switch [list] · crank [go|up] · barricade [here|squeeze|shove|burst] · piece [id|show]
grab [id] · throwat [case] · stun [seconds] · lure [radius] · fling <room> <room> <speed>
push <dx> <dz> [people] [seconds] · drag <right> <away> · door <room> <room> <angle 0-100|use> · doors [open]
furniture open|shut [all] · block <room> <room> · block off · plans [read] (the house plans: where, or read them) · saferoom · use [name] (the nearest fixture, or `use toy`) · bell [room] · monitor · landmarks
navtest [fast] · navtest room <id> [fast] · navtest retreat [n]   (navtest also counts moments he stood on furniture)
beat [behind|dark|hand] (a scare he sets up, on you) · disguise [name|self] (him wearing a friend's look, for you; again ends it)
botrun [fast] [flee|hide] (the bot plays the run with your character and reports the numbers; again stops it) · botrun plan
inspect <Service.field.key...> (a live server table, to Output: inspect LockService.reach)
down [name] · revive [name] · steps · clip
guest here [studs] · guest walk · guest pose <name> · guest form <0-2> · guest smile <0-1>
guest lean <-1..1> · guest move <name> · guest peeks · guest arrive · guest window · guest scare [quiet|rush] · guest off
guest mood [id|off] (his mood: Curious, Stalking, Host, Playful, Patient, Irritated) · guest temperament [id] (Patient, Restless, Playful, Hungry)
guest move MakeWay|FingersPeek|HallwayStand|BehindTheDoor|HostAction|MimicVoice|SlowWithdraw|Duck (his new ways)
```

The overlay shows the seed, Drift and where it came from, the stalker's mode, tier, target, chosen tactic, top-three scores and memory, the stare (who counts and in what light), the squad-profile signals, client and server performance numbers, and the run in numbers (act, tier score, silence, scares, hunts and how each ended, stare-downs, progress).

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
                         StalkerService, BotService, RunLogService, DriftService, ...
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
| Core loop | Hub, Arrival → Investigation → the dinner → Extraction → Dossier; locks, keys, leads, puzzles, heirlooms; acts and progress-woken hunts; win/lose; three downs and Lost, the revive grace, the crawl to the light, the Reckoning at Drift 100; the short night; F2 `botrun`, a bot that plays the run and reports the numbers | **A squad playtest** and the owner's three solo runs against the finish line, then **the Guest-AI and visual rework** (the owner, 2026-10-06), the living house (R3: doors that become walls where nobody sees, house events), a tutorial run, a daily contract |
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
