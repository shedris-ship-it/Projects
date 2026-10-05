# Architecture

How the code implements the design. The design itself lives in [`DesignDoc.md`](DesignDoc.md), as reworked by [`plans/gameplay-rework.md`](plans/gameplay-rework.md) (the escape: locks, keys, puzzles, heirlooms and the dinner; the clue loop retired in R2c). This file covers the mechanics.

## Principles

- **The server decides outcomes.** It owns catches, locks, keys, puzzle answers, the dinner, Drift and the stalker's position. Clients only change how their own player *sees* the world (doc section 7).
- **The server sends rules, not world state.** Each client gets a perception profile (a list of rules) and applies it to its own copy of the house. Since R2c the rules are atmosphere only (`Logic/Atmosphere`): never something to solve, never on anything you play with.
- **Hidden truth is sent only when earned.** A note's text goes only to the player who reads it; a puzzle's screen gets its view, never its answer; the map shows only what someone has seen.
- **Data-driven content.** Rooms, props, physical things, notes, interactables, tactics, archetypes, tools and pings are data modules. Adding content mostly means adding data.
- **Pure logic is engine-free.** Everything in `src/shared/Logic` runs under Lune and is unit-tested: generation, validation, the lock planner, leads and notes, every puzzle's rules, Drift, acts and pacing, AI scoring, physics feel (carrying, articulation, pushing, throws), barricades.
- **Determinism.** Every random choice in a run comes from one seeded RNG (`Lib/Rng`, Park–Miller) forked per subsystem (`progression`, `leads`, `leadplace`, `puzzles`, `arm`, `atmosphere`, `circuits`, ...). The seed is logged, shown in the debug overlay and Dossier, and can be forced with `seed <n>`.

## Server services

`Main.server.luau` requires every ModuleScript in `Services/`, calls `Init(services)` on each (in name order) and then `Start()`. Services hold references to each other and talk through methods and `Signal`s. There are no shared globals.

| Service | Owns |
| --- | --- |
| RunOrchestrator | The phase state machine, run setup (the house, the lock plan, leads, puzzles, the dinner, atmosphere) and teardown, win/lose, extraction, rewards, resync for late clients |
| LobbyService | The hub: difficulty, ready-up countdown, character loading |
| WorldService | Builds and clears the house (`World/LevelBuilder`, `World/MansionBuilder`); run content goes in a `RunContent` folder that Gate A leaves out. Spatial queries (room at a position, floors, doorways). **The passage model:** `SeamCost(seam, who)` for `player`, `guest`, `guestHunt` and `guestRetreat` (nil = blocked: a lock, a crank shutter down; a cost: a shut door, a barricade), `SetSeamBlocked`, `MarkPassageChanged`, `Route`, `Separation`. **The one light rule:** `SetLightCause(room, cause, dark)`: a room is lit only while nothing (its switch, its circuit, the main breaker, his KillLights, the dinner, F2) keeps it dark. Collision groups |
| PlayerStateService | Active / Downed / Lost (Echo) / Extracted. Revives, isolation for Drift, movement noise, the speed sanity check, flashlight and battery, AFK |
| WitnessService | Camera view reports (`ReportView`), `GetView`, `IsLookingAt`, `ClearLine` (solid seam panels block it), pings, callouts, fake pings |
| DriftService | Wraps `Logic/DriftModel` (with its per-minute `Caps`), publishes Drift to `ReplicatedStorage.RunState` |
| DivergenceService | Runs `Logic/Atmosphere`, sends per-player profiles, sends one-off scares |
| DecorService | Portraits, wall clocks and radios in wall and floor slots (`Data/ClockTimes`) |
| InteractService | Fixtures (`Data/Interactables`: toilets, taps, baths, TVs, radios; each a sourceless lure while it runs) and a light switch by the door of every room (`Logic/SwitchSpots`) |
| LockService | The locked doors of the plan (`Logic/LockPlanner`): a lock plate, a key from the player's own ring (`PA.Keys`, dropped where they go down, or left via the journal: `DropKey`), a bolt from its side, a padlock (PuzzleService), a power lock (the breaker). A locked door is a wall to everyone, and its slab collides with Echoes. `Reachable`: the rooms the squad can get to from every living player's room (crank doors count once raised), for The Guest's arrival and hunts. `Unlocked`, `Tried`, `RegionEntered` |
| CrankService | Crank doors (a gate kind): a roller shutter on an open doorway, a crank 7 studs away on its outer side. Held it rises at 2 studs/s, let go it drops at 6 but never onto a body; the ratchet winds it slowly and holds; a latch inside pins it open. The passage follows it with hysteresis (`SetSeamBlocked "crank"`) |
| ItemService | Keys and heirlooms, and how each is found (**leads**, `Logic/Leads`): a note naming its drawer (`Logic/NoteText`, `Data/Notes`; text sent only on reading, `NoteText` → `UI/Reader`), a keepsake box, a locked display case (pick it, or smash it with a throw on its first arc), a key rack; decoys. Each heirloom's state and home (`HomeOf`, `SetHome`, `Tidy`). `Found`, `HeirloomTaken`, `HeirloomDropped`, `Tidied`, `NoteRead`, `CaseOpened` |
| PuzzleService | The generic host for every puzzle kind (`Logic/PuzzleKinds` → `Logic/Puzzles/<Kind>`, `server/Puzzles/<Kind>`): sessions, one operator at a time, reach and inputs re-checked, answers kept here, `Solved`. Kinds: the home computer and printer, padlocks, the breaker panel (power doors, circuits), the wall safe by ear, the music box and piano, the dumbwaiter (no screen). A telegraphed hunt closes every open screen |
| FinaleService | The dinner: the places at the dining table, setting heirlooms, the set piece (lights out, he's at the head of the table, the cut seals, every other lock opens and every crank door latches, the front door opens) and the HUD's objective line (`Logic/Objectives`, `RS.Objective`), generic over stations |
| MapService | What the squad has seen (rooms entered, doorways looked at and their locks, notes read, items seen lying, stations, the table, downed friends), sent to everyone as `MapState` at most twice a second, only on change. Nothing unseen is sent |
| HandsService | Your bare hands (rework section 4): door and furniture drags (`Drag`, `DragRelease` with the hand's speed; within reach, a clear line); small things (`Data/Physical`) grabbed, carried by the client (`Logic/Heft`), thrown by the client with a wind-up (`Throw(aim, charge, pos, vel)`, checked against the class and the last valid state; keys, heirlooms and the music box taken back by the server), re-anchored once still; stuns counted only on a throw's first arc (`Throw.onArc`). `Grabbed`, `Thrown`, `Released`, `Moved` |
| DoorService | Doors by angle (`Logic/Articulation`: held, driven or free with momentum; passable from 55° until below 45°), stepped on the server and written with `BulkMoveTo`, motion snapshots for clients (`Lib/MotionState`). A swing stops against The Guest, a player or a barricade; a flung door slams (a lure if nobody held it). Bracing by prompt or by holding it shut; stalker door delays; locking (`SetLocked`) |
| FurnitureService | Drawers, cupboard and fridge doors, chest and box lids, closet doors: pieces with a joint (`Lib/Joint`), moved like doors, by hand or by E. Fills a space the first time it's opened (`World/Junk`, or ItemService). `AddProp` for run-time props, `SetLocked`, `Shift`/`Settle` for pushed pieces |
| PushService | Pushing furniture by weight (`Data/Physical.Furniture`, `Logic/Push`: acceleration, coasting, 30 Hz). Every step is checked against solid parts, bodies, the Guest's walking points and door swings. **Barricades** (`Logic/Barricade`): a heavy piece may fill a doorway's lane (and a shut door's swing) only if it then bars it; `seam.barricades` feeds `SeamCost`; a "Squeeze past" prompt on a barred doorway; `Shove` for The Guest |
| HidingService | Hiding spots (capacity, peek camera, hold breath and gasps, his inspections) and walk-in closets (physical: hidden while you stand inside with both doors shut) |
| ToolService | Each player's four slots (`Logic/Inventory`: 1 the torch, 2 and 3 found tools, 4 bare hands; anything but the torch clips it to your shirt), tools lying in the house (`Logic/ToolPlacement`), the Lantern (and shrines) and the Radio |
| NoiseService | Noise events the stalker hears (with a source player, or none: a lure) |
| ChatService | Typed lines spoken aloud by text-to-speech and heard by him; mic loudness as noise (`Logic/VoiceNoise`) |
| SquadProfileService | Habit counters with decay (`Logic/SquadProfile`), each Witness's gaze habits (`Logic/GazeHabits`), and the Dossier's habits, closest calls and catches |
| RunLogService | The run's journal: who opened which door and solved which puzzle, who carried and set each heirloom, acts, hunts (and who survived each), tidying, the closest call while carrying. Writes the Dossier's "THE HOUSE" lines, counts what the Marks pay for (`Logic/Progression`) and logs each step to Telemetry |
| StalkerService | The Guest's mode machine, arrival, lazy visibility, hunts and retreats. Uses `Stalker/Director` (pacing: Drift, acts, armed hunts), `Stalker/Stalk` (between hunts: moves from `Data/StalkMoves`, rules from `Logic/StalkRules`, **errands**: waiting at the table, tidying up; heirloom scent from `Logic/Scent`), `Stalker/Tactician` (hunts), `Stalker/Body`, `Stalker/Sight`, `Stalker/Perception`, `Stalker/Walker` (movement, below), `Stalker/Clearance`, `Stalker/Retreat`, `Stalker/NavTest` (F2 `navtest`) and `Stalker/StalkerModel` |
| CompanionService | The solo Companion: follows, helps push, counts as a watcher, revives |
| OutfitService | Period outfits for players and the Companion (`Logic/Outfit`) |
| DataService | Session-locked DataStore profiles with versioned migrations, retry with backoff, autosave |
| Telemetry | Event log lines and AnalyticsService custom events |
| DebugService | Debug commands (F2, and in Studio the `DebugCommand` attribute on ServerStorage) and the overlay feed |

## Client controllers

`Main.client.luau` mirrors the server: every module in `Controllers/` gets `Init(controllers)`, then `Start()`.

| Controller | Owns |
| --- | --- |
| StateController | RunState and player attributes as signals; layout, lobby and profile snapshots; settings |
| PerceptionController | Applies this Witness's atmosphere rules (a portrait's eyes, writing in your torch beam, a sound from nowhere, a friend glimpsed late, a colour) and one-off scares |
| GuestController | How The Guest looks and sounds here: procedural animation of every joint from `Logic/GuestPose`, his face and fingers (`Lib/GuestFace`), eye-shine, visibility, footsteps from his real feet, the warnings, the jumpscare |
| WitnessController | 12 Hz view reports, ping and callout sending, world markers |
| ActionController | Input bindings (keyboard, gamepad, touch), sprint and stamina, camera modes (first person in the house, the peek camera when hidden in a spot; your own camera in a closet), the flashlight (full beam in slot 1, the clip light otherwise), the map (Tab, gamepad Y) |
| HandsController | Your hands: hold the left button (RT) on a door, drawer or lid to drag it (the view holds still; your copy answers at once through MotionController) or on a small thing to carry it (a spring hold point from `Logic/Heft`); right button (LT) winds up and throws |
| MotionController | The one writer of moving joints on this client: steps each moving door, drawer and lid from the server's motion snapshot and draws it just before rendering, easing into each new one |
| FeelController, FootstepController | Head bob, sway, FOV kick and landing dip (Camera motion setting); our own footsteps by floor |
| ViewModelController | The torch and tools in your hands, sleeved arms |
| SpeechController | Mic loudness for `VoiceLevel` |
| AudioController | Sound groups and volume settings, room reverb, Drift layers, ducking, positional one-shots (`Sfx`), loops from the `SoundLoop` tag (taps, the music box), captions |
| EffectsController | Drift-driven colour, vignette and atmosphere; bloom, grain and depth of field; dust; light flicker and dimming near The Guest; hunt tint; low-end mode |
| UIController | Every screen in `UI/`: the HUD and objective line, hotbar, map and journal (`UI/Map`), the note reader (`UI/Reader`), puzzle screens (`UI/Puzzle` hosting `UI/Puzzles/<Kind>`), Dossier, lobby, settings, the say box, debug overlay |

## A run, end to end

1. **Lobby → Generating.** `LobbyService` starts the run when everyone in the hub is ready. `RunOrchestrator` picks a seed. The mansion generator (`Logic/MansionGen`, the default; F2 `layout cells` for the old house) makes a layout that `LayoutValidator` checks. `Logic/LockPlanner` then plans the locks on it (regions, gates, where each key and heirloom is kept, which puzzles), a post-pass that never rejects a house. `WorldService` builds the house unparented and parents it once.
2. **Setup.** Decor, fixtures and switches, then locks and crank doors, then leads (`Logic/Leads`, its own fork) and items, puzzles, the dinner's table, and last each Witness's atmosphere. Everything made at run time goes in `RunContent`.
3. **Arrival → Investigation.** The front door locks behind the squad; the table is laid with empty places. They explore, read notes, open drawers, boxes and cases, find keys (each on its finder's own ring), work puzzle stations and open the next region. `Logic/Acts` turns progress into an act; the Director arms a hunt 60–120 s after the first step into a new region, a new act or the first heirloom found.
4. **Stalker.** Movement has three layers (docs/plans/mansion-generation.md, M3): the house graph (`Logic/NavGraph`) picks the way through the passage model; `Stalker/Walker` walks each room on Roblox's navmesh and re-plans when blocked, waits at doors, and at a barricade bangs and shoves it clear; `Stalker/Clearance` sweeps his body for every move that isn't a plain walk. At 90 s he knocks at the front door and is inside; from then on he is always physically somewhere. At 1 Hz the Director turns Drift, the act and armed hunts into a target tier and hunt timing (`Logic/DirectorModel`) and plays the scare deck. Between hunts `Stalker/Stalk` picks moves by utility (peek, doorway stand, creep, shadow, stare down, roam, visit his things), follows heirloom scent, and runs errands (waiting at the head of the table while every unset heirloom is carried; putting a long-dropped heirloom back where it was kept, unseen). During hunts the Tactician scores 13 tactics against the squad profile.
5. **The dinner.** Setting the last heirloom serves it: lights out, he's at the head of the table, the cut between the dining room and the hall seals, every other lock opens, the front door opens, and the final hunt runs in Extraction.
6. **Extraction → Debrief.** Out of the front door. Rewards are granted (Marks for the outcome, regions opened, puzzles solved and hunts survived) and the Dossier is sent (the house's journal, habits, closest calls, how he stalked you). Everything is torn down and players return to the hub.

## Divergence model

Rules look like `{ id, kind, target, minDrift, params }`, made by `Logic/Atmosphere` for each Witness: a portrait's eyes following you, writing only you see, a mislocated sound (Drift 40+), a teammate glimpsed where they were a moment ago, a recoloured ornament. Its spec proves a rule never targets a door, item, note, station, the table or anything you carry or push. There are no fake walls, phantom doors or phantom figures any more: the only Guest you see is real.

Every wall between two rooms is still two wall pieces, a lintel and a doorway-sized seam panel (invisible and non-collidable on a doorway, solid on a wall); R3's house shifts will flip real seams through it.

## The observation rule

Clients report their camera CFrame at 12 Hz (`ReportView`, an UnreliableRemoteEvent). A player is "watching" the stalker when it's inside an 80° cone of their camera, within range, with a clear raycast, *and* it is visible to that player (tier 1 shows it to one Witness only), for 0.3 seconds or more. The watch check uses where his head and chest really are for the pose clients are drawing.

| Watchers | Result |
| --- | --- |
| 0 | He moves freely: creeping, peeking, roaming. Visibility changes only now |
| 1 | Tier 1: yanked out of sight once you've seen him for ~0.45 s. Tier 2: holds and stares; backs away if stared at up close for 4 s. Tier 3: keeps creeping, very slowly |
| 2 or more | Frozen, and any lunge wind-up is cancelled. Holding the stare together for 3 seconds makes him back away; during a normal hunt that ends the hunt. Not while he waits at the table |

The Companion counts as a second watcher only while a real player is also watching.

## Remote protocol

Every client → server remote goes through `Net.onServer`, which applies a per-call interval, a sliding one-second burst cap, and a type schema (NaN and infinities are rejected). Most world actions (doors, drawers, notes, fixtures, switches, cranks, keys at a lock, setting a place, squeezing past) are ProximityPrompts, handled on the server with the same checks.

| Remote | Direction | Payload | Limits |
| --- | --- | --- | --- |
| ReportView | C→S unreliable | `CFrame` | ≥1/30 s, must be within 30 studs of the head |
| Ping, Callout | C→S | `type`, `position` | Ping 0.8 s, burst 3 (Echoes once a minute); Callout 2 s |
| UseTool | C→S | none used | 0.25 s; the tool in your hands |
| SelectSlot | C→S | `number` | 0.08 s, burst 8; only 1 to 4, only while active and not hiding |
| DropItem | C→S | none | 0.4 s; puts the tool in your hands on the floor |
| DropKey | C→S | `token` | 0.3 s, burst 3; a key on your own ring, left at your feet |
| Drag | C→S unreliable | `id`, `value` (angle, or studs for a drawer) | 1/60 s, burst 60; can act, within about 11 studs, a clear line; not while he's forcing a door |
| DragRelease | C→S | `id`, `value`, `velocity` | 0.05 s, burst 10; it swings on at that speed |
| DragStop | S→C | `id`, `value` | what you held stopped in your hands |
| Push | C→S unreliable | `prop id`, `Vector3` (the way you walk) | ~1/14 s; can act, within reach of its footprint and facing it, nobody hiding in it |
| Grab | C→S | `thing id` | 0.15 s, burst 6; can act, within reach, a clear line, nobody else holding it |
| Release | C→S | none | 0.1 s |
| Throw | C→S | `aim`, `charge?`, `position?`, `velocity?` | 0.3 s, burst 3; only what you hold; the launch is checked against the class and its last valid state |
| PuzzleOpen / PuzzleState / PuzzleClose | S→C | `(id, kind, view, state)` / `(id, state, events)` / `(id)` | the operator only; never the answer |
| PuzzleInput | C→S | `(id, action, word?, a?, b?)` | 0.08 s, burst 14; the operator, within 9 studs, able to act |
| PuzzleLeave | C→S | `(id)` | 0.1 s |
| NoteText | S→C | `{ id, text, title? }` | only to the reader |
| MapState | S→C | the squad's map | at most 2 Hz, on change |
| Say | C→S | `string` | filtered, spoken by text-to-speech, heard by him |
| VoiceLevel | C→S | `number` | 0.2 s |
| SetFlashlight, HoldBreath, SetReady | C→S | `boolean` | 0.05–0.2 s |
| SetDifficulty | C→S | `string` | 0.3 s; whitelisted values |
| LeaveHiding, RequestSync | C→S | none | 0.3 s / 2 s |
| SaveSettings | C→S | `table` | 1 s; keys whitelisted, numbers range-checked |
| DebugCommand | C→S | `string` | 0.2 s; Studio or allow-listed users only |
| PerceptionProfile, StalkerVisibility, Scare, GuestEvent | S→C | per player | |
| Sfx, Spoke, Pinged, CalloutHeard, Notify, HuntState, Layout, LobbyState | S→C | broadcast | |
| Dossier, ProfileData | S→C | per player | |
| DebugState | S→C unreliable | snapshot | 2 Hz to overlay users |

## Security model

- Clients can't decide outcomes: catches, locks and keys, puzzle answers, the dinner, Drift and stuns are all server-side.
- Hidden truth is sent only when earned: note text on reading, a puzzle's view without its answer, the map only from what someone saw, keys and heirlooms only when their space is first opened. Fake stalker pings look identical to real ones.
- Thrown and carried things are client-simulated for feel, but the server checks every launch and every held position (speed against the class plus the holder's, wall crossings), takes back progress items on release, and decides stuns from the validated first arc.
- An exploiter *can* strip their own atmosphere rules (accepted in doc section 7). That never decides anyone else's outcome.
- Movement: characters are client-simulated, so the server snaps a character back if it covers ground at more than 2.2× sprint speed twice in a row. Server teleports (a squeeze past, F2) grant a short grace period.
- Saves: a session lock prevents two servers writing the same profile. Values are clamped and reconciled on load.

## Performance notes

- The mansion is 18–24 rooms on two floors. Check the real part count with the `perf` debug command. It is built unparented and parented once. Streaming is off.
- Stalker body updates run at 15 Hz, the Tactician at about 1.5 Hz, the Director at 1 Hz, player-state upkeep at 4–10 Hz, pushes at 30 Hz, door and drawer motion snapshots at 20 Hz while something moves.
- Navigation: the house graph (`Logic/NavGraph`) and Roblox's navmesh (`Stalker/Walker`); see "A run, end to end". Every route asks the passage model (`WorldService:SeamCost(seam, who)`) who may pass each doorway; nil means blocked, and the walker stands still rather than walk at a wall.
- Physical things stay anchored until someone grabs them, so the house builds the same every time and nothing settles at load; once still and grounded after a drop or throw they're anchored again. Collision groups: Prop (resting or thrown) and Held (carried) never touch players or The Guest; Heavy (pushable furniture) collides with everyone but Echoes; a locked door collides with Echoes too. Doors and drawers move only while they swing.
- One shadow-casting key light per room. Low-end mode turns off shadows from small clutter, depth of field and bloom.
- Measure with the debug overlay (FPS, memory, instances, server heartbeat) and with the MicroProfiler on a real phone.
