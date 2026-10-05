# Architecture

How the code implements the design doc. The design reasons themselves live in [`DesignDoc.md`](DesignDoc.md); this file covers the mechanics.

## Principles

- **The server decides outcomes.** It owns verdicts, catches, ritual success, Drift, evidence and the stalker's position. Clients only change how their own player *sees* the world (doc section 7).
- **The server sends rules, not world state.** Each client gets a perception profile (a list of rules) and applies it to its own copy of the house. A client's changes to replicated parts don't replicate back, which is what makes per-player divergence cheap on Roblox.
- **Data-driven content.** Anomalies, tells, rooms, props, tactics, archetypes, tools and pings are data modules. Adding content mostly means adding data.
- **Pure logic is engine-free.** Everything in `src/shared/Logic` runs under Lune and is unit-tested: generation, validation, deduction, Drift, verdicts, AI scoring and pacing.
- **Determinism.** Every random choice in a run comes from one seeded RNG (`Lib/Rng`, Park–Miller) forked per subsystem. The seed is logged, shown in the debug overlay and Dossier, and can be forced with `seed <n>`.

## Server services

`Main.server.luau` requires every ModuleScript in `Services/`, calls `Init(services)` on each (in name order) and then `Start()`. Services hold references to each other and talk through methods and `Signal`s. There are no shared globals.

| Service | Owns |
| --- | --- |
| RunOrchestrator | The phase state machine, run setup and teardown, win/lose, extraction, rewards, resync for late clients |
| LobbyService | The hub: difficulty, ready-up countdown, character loading |
| WorldService | Builds and clears the house (`World/LevelBuilder`). Spatial queries: room at a position, doorways, lights, slots. Collision groups |
| PlayerStateService | Active / Downed / Lost (Echo) / Extracted. Revives, isolation for Drift, movement noise, the speed sanity check, flashlight and battery, AFK |
| WitnessService | Witnessable registry, Witness windows and anchoring, Focus, camera view reports, line-of-sight helpers, pings, callouts |
| DriftService | Wraps `Logic/DriftModel`, publishes Drift to `ReplicatedStorage.RunState` |
| DivergenceService | Runs `Logic/PerceptionPlanner`, sends per-player profiles, registers divergent targets, sends one-off scares |
| AnomalyService | Picks the anomaly, plans evidence (`Logic/EvidencePlanner`), places tell sites and base props, prepares the Source, runs the ritual, Witness Camera photos |
| CaseBoardService | Confirmed, debunked and claimed tells, suspects (`Logic/CaseBoard`), the physical corkboard |
| VerdictService | The Deliberation Table and vote rules (`Logic/Verdict`) |
| HidingService | Hiding spots, capacity, peek camera, hold breath and gasps, stalker inspections |
| DoorService | Doors by angle (`Logic/Articulation`: 0 shut, latching, locking, passable at 55°), stepped on the server and written with `BulkMoveTo`; `door.open` means walkable. Opening, closing, dragging by hand (held shut it braces; he forces it out of your hands), bracing by prompt; a swing into The Guest stops dead; stalker door delays (shorter when ajar); knocks |
| FurnitureService | Drawers, cupboard and fridge doors, chest lids (docs/plans/gameplay-rework.md section 4.5): pieces built by `World/PropFactory` with a joint on their main part (`Lib/Joint`), moved on the server like doors (`Logic/Articulation`, `BulkMoveTo`), by hand (through HandsService), by the E prompt, and when someone hides in (shut) or leaves (open) a wardrobe. Learns at build how far each opens before hitting something. Makes what's kept inside the first time a space is opened half way (`World/Junk`, or `Filler` for R2a's items) and carries it in and out with its drawer; lights the fridge |
| PushService | Pushing furniture (docs/plans/gameplay-rework.md section 4.6): every pushable kind's weight (`Data/Physical.Furniture`), pushers in the last 0.3 s (plus the Companion solo) turned into a speed by `Logic/Push`; each step checked against solid parts, bodies, the Guest's walking points and door swings; moves the parts, hiding spots, things on top, and (through `FurnitureService:Shift`/`Settle`) drawers, doors and their contents; scrape noise |
| HandsService | Your bare hands (docs/plans/gameplay-rework.md section 4): validates door and furniture drags (reach, line of sight); registers small things (`Data/Physical`), wakes them on the first grab (welded, unanchored, owned by the holder), checks held things every frame (put back and dropped if they jump or cross a wall), throws from the server's own hand point, lands them with a sound and a lure noise, re-anchors them once still. `Thrown`/`Moved` signals feed the stun |
| ToolService | Each player's four slots (`Logic/Inventory`: 1 the torch, 2 and 3 found tools, 4 bare hands; anything but the torch clips it to your shirt, `PA.TorchClipped`), the tools lying in the house (`Logic/ToolPlacement`, `World/ToolPickups`), pickups and drops, and what the Witness Camera, Lantern (and shrines), Radio and Plumb Line do. `PA.Tool` is the tool in your hands now; `Slot1..4` and `ActiveSlot` are what you carry |
| NoiseService | Noise events the stalker hears |
| SquadProfileService | Habit counters with decay (`Logic/SquadProfile`), each Witness's gaze habits (`Logic/GazeHabits`), and the end-of-run Dossier |
| StalkerService | The Guest's mode machine, arrival, lazy visibility, hunts and retreats. Uses `Stalker/Director` (pacing), `Stalker/Stalk` (between hunts: moves from `Data/StalkMoves`, rules from `Logic/StalkRules`), `Stalker/Tactician` (hunts), `Stalker/Body` (the physical body: facing, zoom, lunge, pose-aware head points), `Stalker/Sight` (who can see what, stealth steps), `Stalker/Perception`, `Stalker/Walker` (movement, below), `Stalker/Clearance` (body sweeps, no phasing), `Stalker/Retreat` (backing away, `Logic/RetreatPlan`), `Stalker/NavTest` (F2 `navtest`) and `Stalker/StalkerModel` |
| CompanionService | The solo Companion Witness |
| DataService | Session-locked DataStore profiles with versioned migrations, retry with backoff, autosave |
| Telemetry | Event log lines and AnalyticsService custom events |
| DebugService | Debug commands and the overlay feed |

## Client controllers

`Main.client.luau` mirrors the server: every module in `Controllers/` gets `Init(controllers)`, then `Start()`.

| Controller | Owns |
| --- | --- |
| StateController | RunState and player attributes as signals; layout, case board, lobby and profile snapshots; settings |
| PerceptionController | Applies and reverts perception rules: seam flips, phantom props, variant props, phantom sounds, unobserved shifts, ghost trails, hidden teammates, hidden writing, portrait eyes. Also scares, ritual flickers, key labels |
| GuestController | Everything about how The Guest looks and sounds here: procedural animation of every joint from `Logic/GuestPose`, his face and fingers (`Lib/GuestFace`), eye-shine, his visibility, footsteps from his real feet, the warnings, the jumpscare |
| WitnessController | Aiming, hold-to-Witness, 12 Hz view reports, ping and callout sending, world markers |
| ActionController | Input bindings (keyboard, gamepad, touch), sprint and stamina, camera modes (first person in the house, the peek camera when hidden), the camera flashlight (the full beam in slot 1, the clip light from your chest otherwise), plumb-line beams |
| HandsController | Your hands: hold the left button (RT) on a door to drag it (the view holds still; your hand moves with the mouse; the door follows; your copy moves at once) or on a small thing to carry it (local AlignPosition and AlignOrientation once the server hands it over; the wheel sets the distance; right button or LT throws). F2 `drag` |
| AudioController | Sound groups with volume settings, room reverb, Drift layers, ducking, positional one-shots, captions |
| EffectsController | Drift-driven colour, vignette and atmosphere; bloom, grain and depth of field; dust in each room's light; light flicker and dimming near The Guest; hunt tint; photo flash; low-end mode |
| UIController | Every screen in `UI/` |

## A run, end to end

1. **Lobby → Generating.** `LobbyService` starts the run when everyone in the hub is ready. `RunOrchestrator` picks a seed. `LevelGraph.generate` grows a layout and `LayoutValidator` checks it, retrying with the next seed up to 10 times, then falling back to an authored layout. Rooms with windows are turned so the windows face outside. `WorldService` builds the house unparented and parents it once; corridor rooms fill any arm that ends at an outside wall (`Logic/Corridor`), and a window still facing another room is left out.
2. **Setup.** `AnomalyService` picks an anomaly the location supports, lets its ritual reserve what it needs (`prepare`), plans 3–4 true tells and 1–2 red herrings, and places tell sites in wall, floor and seam slots. `DivergenceService` turns the sites into per-player rules. The planner guarantees two things: social tells look different to different Witnesses, and every Witness has something a teammate can disprove. Base props are then built showing the true state.
3. **Arrival → Investigation.** Witnessing a tell site with a second Witness anchors it: a true tell is confirmed (Drift −6), a herring is debunked. A lone Witness's observation becomes an unconfirmed claim. The Witness Camera confirms alone (Drift −3).
4. **Stalker.** Movement has three layers (docs/plans/mansion-generation.md, M3): the house graph (`Logic/NavGraph`, pure: doorways, lanes, the stairs and the gallery in studs) picks the way; `Stalker/Walker` walks each room on Roblox's navmesh and re-plans when blocked; `Stalker/Clearance` sweeps his body for every move that isn't a plain walk and puts him back if he ever crosses a wall. The Companion walks with the same walker. Distances to players are walking distances (`WorldService:Separation`), and floors muffle hearing and split company (`Logic/Storeys`). At 90 s The Guest knocks at the front door and is inside; from then on he is always physically somewhere in the house. At 1 Hz the Director turns Drift and run state into a target tier and hunt timing (`Logic/DirectorModel`) and plays the scare deck. At 15 Hz the body perceives and applies the observation rule; between hunts `Stalker/Stalk` picks moves (peek, doorway stand, creep up behind, shadow, stare down, roam) by utility from the squad's habits and each Witness's gaze habits, and reacts to being seen (the yank at tier 1, holding at tier 2, creeping on at tier 3, the lunge). During hunts the Tactician scores 13 tactics against the squad profile at about 1.5 Hz and picks one of the top three. Clients animate him from the `GuestPose`, `GuestGaze`, `GuestForm` and `GuestLean` attributes; the server's joints never move, so what Witnesses can see of him comes from the same pure pose maths.
5. **Verdict → Resolution.** A correct verdict starts the ritual and the final hunt. A wrong one costs Drift and forces a hunt.
6. **Extraction → Debrief.** The exit opens. Rewards are granted and the Dossier is sent. Everything is torn down and players return to the hub.

## Divergence model

Rules look like `{ id, kind, target, minDrift, params }`. A rule is active when Drift ≥ `minDrift` and its target isn't anchored. Anchoring broadcasts `PerceptionAnchor(target, seconds)`, and every client reverts rules on that target until the anchor expires, so the truth shows for everyone.

The layout makes this cheap. **Every wall between two rooms** is two wall pieces, a lintel and a doorway-sized seam panel. On a real doorway the panel is invisible and non-collidable; on a solid wall it is solid. A `SeamFlip` rule flips the panel for one client:

- *Phantom door:* a real wall the client sees as a doorway and can walk through. The server tolerates this (Witness line-of-sight checks skip seam panels).
- *Fake wall:* a real doorway the client sees as a wall. It is **visual only, never collidable**, so a divergence can't trap anyone in a chase (doc section 3, fairness contract).

## The observation rule

Clients report their camera CFrame at 12 Hz (`ReportView`, an UnreliableRemoteEvent). A player is "watching" the stalker when it's inside an 80° cone of their camera, within range, with a clear raycast, *and* it is visible to that player (tier 1 shows it to one Witness only), for 0.3 seconds or more.

The watch check uses where his head and chest really are for the pose clients are drawing (a peeking head sticks out of a doorway while his body is behind the wall).

| Watchers | Result |
| --- | --- |
| 0 | He moves freely: creeping, peeking, roaming. Visibility changes only now |
| 1 | Tier 1: yanked out of sight once you've seen him for ~0.45 s. Tier 2: holds and stares; backs away if stared at up close for 4 s. Tier 3: keeps creeping, very slowly |
| 2 or more | Frozen, and any lunge wind-up is cancelled. Holding the stare together for 3 seconds (draining Focus) makes him back away; during a normal hunt that ends the hunt |

The Companion Witness counts as a second watcher only while a real player is also watching.

## Remote protocol

Every client → server remote goes through `Net.onServer`, which applies a per-call interval, a sliding one-second burst cap, and a type schema (NaN and infinities are rejected).

| Remote | Direction | Payload | Limits |
| --- | --- | --- | --- |
| ReportView | C→S unreliable | `CFrame` | ≥1/30 s, must be within 30 studs of the head |
| Witness | C→S | `targetId: string?`, `position: Vector3` | 0.35 s, burst 4; range, line of sight and Focus checked |
| Ping | C→S | `type: string`, `position: Vector3` | 0.8 s, burst 3; Echoes once a minute |
| Callout | C→S | `type: string`, `position: Vector3` | 2 s |
| UseTool | C→S | `targetId: string?`, `position: Vector3?` | 0.25 s; film, cooldowns and range checked |
| SetFlashlight, HoldBreath, SetReady | C→S | `boolean` | 0.05–0.2 s |
| SetDifficulty, CastVote | C→S | `string` | 0.2–0.3 s; whitelisted values |
| SelectSlot | C→S | `number` | 0.08 s, burst 8; only 1 to 4, only while active and not hiding |
| DropItem | C→S | none | 0.4 s; puts the tool in your hands on the floor in front of you |
| Drag | C→S unreliable | `string` (door or piece id), `number` (angle, or studs for a drawer) | 1/40 s, burst 45; can act, the door or piece within 11 studs of the head, a clear line; not while he's forcing a door |
| Push | C→S unreliable | `string` (prop id), `Vector3` (the way you walk) | 1/14 s, burst 16; can act, within 4.5 studs of its footprint and facing it, nobody hiding in it |
| Grab | C→S | `string` (thing id) | 0.15 s, burst 6; can act, within reach, a clear line, nobody else holding it |
| Release | C→S | none | 0.1 s |
| Throw | C→S | `Vector3` (aim) | 0.3 s; only what you hold; the aim must be about unit length |
| LeaveHiding, RequestSync | C→S | none | 0.3 s / 2 s |
| RitualAction | C→S | `table?` | 0.2 s; only during Resolution |
| SaveSettings | C→S | `table` | 1 s; keys whitelisted, numbers range-checked |
| DebugCommand | C→S | `string` | 0.2 s; Studio or allow-listed users only |
| PerceptionProfile, PerceptionAnchor, StalkerVisibility, Scare, ItemLabels | S→C | per player | |
| Pinged, CalloutHeard, WitnessFeedback, Notify, HuntState, CaseBoard, VerdictState, Layout, LobbyState, RitualState, PlumbLine | S→C | broadcast | |
| PhotoResult, Dossier, ProfileData | S→C | per player | |
| DebugState | S→C unreliable | snapshot | 2 Hz to overlay users |

## Security model

- Clients can't decide outcomes: verdicts, catches, anchors, Drift, evidence and ritual progress are all server-side.
- Hidden truth is sent only when earned. Clients never learn which tells are red herrings, where the Source is, or which key is genuine. Fake stalker pings look identical to real ones.
- An exploiter *can* strip their own divergences (accepted in doc section 7). That never decides anyone else's outcome.
- Movement: characters are client-simulated, so the server snaps a character back if it covers ground at more than 2.2× sprint speed twice in a row. Server teleports grant a short grace period.
- Saves: a session lock prevents two servers writing the same profile. Values are clamped and reconciled on load.

## Performance notes

- The level is an estimated 1,500–3,000 parts for 10–16 rooms (bookshelves are the biggest share). Check the real count with the `perf` debug command. It is built unparented and parented once. Streaming is off: levels are small, and the doc calls for avoiding streaming complexity.
- Stalker body updates run at 15 Hz, the Tactician at about 1.5 Hz, the Director at 1 Hz, and Witness, Focus and player-state upkeep at 4–10 Hz.
- Navigation: the house graph (`Logic/NavGraph`) and Roblox's navmesh (`Stalker/Walker`); see "A run, end to end". Every route asks the passage model (`WorldService:SeamCost(seam, who)`) who may pass each doorway; nil means blocked, and the walker stands still rather than walk at a wall.
- Physical things stay anchored until someone grabs them, so the house builds the same every time and nothing settles at load; once still after a drop or throw they're anchored again. Collision groups keep them honest: Prop (resting or thrown) and Held (carried) never touch players or The Guest; Heavy (pushable furniture, R1b) does. Doors move only while they swing.
- One shadow-casting key light per room. Low-end mode turns off shadows from small clutter, depth of field and bloom.
- Measure with the debug overlay (FPS, memory, instances, server heartbeat) and with the MicroProfiler on a real phone.
