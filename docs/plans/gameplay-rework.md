# The gameplay rework: a hands-on haunted mansion

Status (2026-10-04): **planned, R0 (this document) done.** This replaces the core loop of [`DesignDoc.md`](../DesignDoc.md) sections 1–4 and 6: no more evidence, Case Board, verdict or rituals. The Guest (section 5), Drift, the mansion generator ([`mansion-generation.md`](mansion-generation.md)) and the art direction ([`ART.md`](../ART.md)) stay. The work runs in four halves, **R1a → R2a → R1b → R2b** (section 9), so the new loop is playable about halfway through, with R3 (the living house) and R4 (variety) after it.

## 1. Why

The owner played the slice and found the loop a chore (2026-10-04): "instead of just finding random meaningless clues around the map ... I don't think that's a fun gameplay loop." Walking round pressing Q with friends to log discrepancies is Phasmophobia's repetitive motion. The game should be an *experience*, like P.T.:

- **A house you can touch.** Every object that can be interactive is: toilets flush (and make noise), closets are walked into and shut from inside, radios keep playing in your hands.
- **Physics.** Small things can be picked up, carried and thrown with a new 4th slot that is just your hands. A throw can stun the Guest for a moment. Heavy things like beds barely budge for one person and move with friends, and can barricade a doorway.
- **Resident Evil progression, procedural.** Locked wings, keys, backtracking and shortcuts, different every run.
- **Puzzles that are fun on their own.** "Fallout terminals were a fun puzzle because it took a fun simple concept and made it procedural." Not "find runes around the map and match them".
- **Changes that matter.** The house still changes, but a change either changes play (a door becomes a wall and closes a loop) or is genuinely unsettling.
- **Unpredictable and varied every run**, and immersive enough that you forget the controls.

## 2. The owner's decisions

| Topic | Decision |
| --- | --- |
| Run goal | **Escape, with a finale.** A procedural chain of locks, keys and puzzles; the finale is a set piece under a final hunt, then the run out. |
| Finale | **Set the table.** Two or three heirlooms hidden in different wings are laid at the dining-room table as a place for the Guest. When the last one is set, the dinner begins (section 6). |
| Way out | **The front door**, the one that slammed behind the squad at the start. |
| Keys | **Each player's own.** Whoever picks a key up holds it, and drops it where they go down. |
| Divergence | **Atmosphere only.** Each player still sees a slightly different house, but only as unsettling moments, never as something to solve. Q-witnessing, the Case Board and the verdict go. |
| Hands | **Amnesia-style.** Hold the mouse button to grab; move the mouse to drag doors, drawers and closet doors (from inside too); carry at arm's length and throw; push heavy things. A tap version for touch and gamepad. |
| Pressure | **Keep Drift, retuned.** Time, noise and splitting up raise it; progress lowers it. A squad that keeps making progress never collapses. |
| First puzzles | **All four:** the home computer (a Fallout terminal), the breaker panel, the safe by ear, the music box melody. |
| Torch | Slot 1 is the full beam. **In any other slot it clips to your shirt**: a weak, short light that points where your body faces. |

Defaults Claude chose, open to the owner:
- The Guest can pass a locked door only between hunts, unseen, with nobody within 25 studs, and with a loud unlock click. **During a hunt a lock is a wall for him too**, so chases stay inside the part of the house the squad can reach.
- Stuns are short and shrink when repeated: 0.7 s (light things), 1.2 s (medium), 1.8 s (heavy), halved for each stun in the last minute, then 4 s of immunity, ×0.6 in the final hunt. Only a player he is visible to can stun him.
- A barricade delays him at most 8 s and never traps a player ("squeeze past").
- Lost players (Echoes) can't pass locks.
- Lantern rooms stay, as Resident Evil's save rooms.
- The phase names stay for now: Investigation is exploring, Resolution is the dinner.

Open for later: **the name and the pillars.** With Witnessing gone, "consensus" lives on in the two-watcher rule (two people watching the Guest freeze him) and in the squad agreeing to split up or stick together. Pillar 2, "Talk is the mechanic", becomes "talk is how you survive": the breaker panel and the music box both play best with someone calling out from another room.

## 3. A run

Target: about 25–30 minutes.

1. **Arrival.** The squad enters the grand hall and the front door slams and locks behind them. Through the archway the dining table is laid for a dinner, with empty places that show how many heirlooms the run needs. **Region 0** is open: the hall, the dining room and a handful of rooms around them. It always has a chase loop and hiding spots. At 90 s, three knocks: the Guest is inside (unchanged).
2. **Exploring.** Pull drawers and open cabinets for keys, notes and items. Work the puzzle stations. Unlock a door into the next region; inside, bolted doors open from your side as shortcuts back. Each region holds the way into the next, and the heirlooms sit behind puzzles in different wings. Splitting up is faster and deadlier.
3. **The house turns (R3).** As Drift climbs, and once the squad has learned a loop, real doors become walls (and walls become doors) where nobody can see. P.T.-style events run alongside.
4. **The dinner.** Set the last heirloom: the lights die, a chair scrapes, he takes his place. The dining room's doors to the hall slam and seal, every other lock in the house springs open, the final hunt starts and the front door unlocks. The squad runs the long way round.
5. **Escape and the Dossier.** The Dossier's evidence section becomes progress: rooms opened, puzzles solved, closest calls.

## 4. Hands and physics

### 4.1 Four slots
`Logic/Inventory`: `SLOTS = 4`, `HANDS_SLOT = 4`, `TOOL_SLOTS = {2, 3}`.
- Slot 1 is the torch, always. Slots 2 and 3 hold found tools and bulky items (a fuse, the music box, an heirloom). Slot 4 is your hands, a permanent pseudo-item, so the wheel always has somewhere to go.
- The physics prop you're carrying belongs to `HandsService`, not to the inventory.
- **Keys** go on your own key ring, outside the slots. They drop where you go down, are Lost or leave the game, and each has a Drop button on the map screen so you can hand one over.
- **The torch** clips on in slots 2–4: a server `ClipLight` SpotLight on the upper torso that everyone sees, aimed by the body's yaw (`Config.Hands.ClipLight`, about range 16, angle 70). `PlayerStateService:SetFlashlight` allows the light when the torch is held or clipped.
- Holding the mouse on something grabbable with the torch in hand switches to slot 4 (the torch clips on if it was lit). Leaving slot 4 while carrying puts the thing down gently.

### 4.2 Collision groups
| | Default | Seam | Door | Players | Echo | Stalker | Prop | Held | Heavy |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| **Prop** (resting or thrown small things) | ✓ | ✓ | ✓ | ✗ | ✗ | ✗ | ✓ | ✓ | ✓ |
| **Held** (being carried) | ✓ | ✓ | ✓ | ✗ | ✗ | ✗ | ✓ | ✗ | ✓ |
| **Heavy** (pushable furniture) | ✓ | ✓ | ✓ | ✓ | ✗ | ✓ | ✓ | ✓ | ✓ |

- A carried thing can't fling its holder, shove a teammate or block the Guest.
- Thrown things don't touch the Guest physically: hits are decided in code (4.4), so he never trips over a bottle.
- Small props get a `PathfindingModifier` with `PassThrough`, so his navmesh never routes round them.

### 4.3 Small props: anchored until grabbed
Every prop is built anchored, as now, so building stays deterministic and nothing settles at load. On the first grab `HandsService` prepares it: welds the parts to a root, unanchors them, sets the mass class from `Data/Physical` and turns off `CanTouch`.

```
Resting (anchored, Prop group, server)
  --Grab-->          Held (unanchored, Held group, owned by the holder)
  --Release/Throw--> Free (Prop group, owned by the server)
  --asleep 1.5 s-->  Resting (re-anchored where the server has it)
```

- **Grab.** The server checks: can act, not hidden, within `Config.Hands.Reach` (8) of the head, a clear line from the head (`WitnessService:ClearLine`), nobody else holding it, not Heavy. It hands network ownership to the player. The client drives its own AlignPosition and AlignOrientation toward a point in front of the camera; the mouse wheel sets the hold distance (2.5–5) while carrying.
- **Validation**, every Heartbeat, for held props only:
  1. More than 6.5 studs from the head: dropped (Amnesia's "snagged on the door frame").
  2. A Blockcast from the last valid position to the current one hits a wall: snapped back, ownership taken back, dropped, and logged as `HeldRejected`.
  3. Faster than 80 studs/s: treated the same.

  An exploiter can at worst misplace a prop's picture for one tick. A held prop touches no player and no Guest, and stuns are decided on the server.
- **Release.** Ownership goes straight back to the server and the server simulates the fall.

### 4.4 Throws and the stun
- `Throw(dir, charge)`: the server re-checks the holder, moves the prop to the server's own hold point (head plus look direction, pulled clear of walls) to remove lag skew, takes ownership and sets the velocity from the mass class and the charge, plus the holder's own velocity and a little spin.
- **Hit test.** Every Heartbeat for 2.5 s, the server tests the segment the prop moved along against the Guest's capsule (feet to head from `Body:ExposedPoints()` and the root; radius 1.1 plus the prop's own) with `Logic/Throw.segmentCapsule`. It counts above `StunMinSpeed` (28 studs/s), once per flight, and only from a thrower he is visible to (tier 1 shows him to one player). The prop bounces off at 0.3× speed.
- **`StalkerService:Stun(seconds, thrower)`** uses the same branch as a freeze (`CancelSpecial`, no lunge, no contact lunge, the hunt's catch check skipped) with a new `Stagger` pose in `Logic/GuestPose`. In a hunt the hunt timer pauses. Afterwards he remembers the thrower at full confidence: a throw is a sacrifice play.
- **Impacts** play a sound for the material and emit sourceless "impact" noise, which is a lure (4.9).

### 4.5 Doors, drawers and closet doors: articulated, not physics
Physics hinges fling client-simulated characters and blur the Guest's door logic, so doors and drawers are driven by the server.
- `Logic/Articulation` (pure, with a spec) holds `{ value, min, max, latched, locked, holder }` (degrees for hinges, studs for slides) and the Amnesia mapping from mouse movement to angle, aware of which side you stand on. It rate-limits (240°/s, drawers 6 studs/s), latches below 3° with a click, rattles and stays shut when locked, and calls a door passable at 55° or more.
- The client sends `Drag(id, target)` (unreliable, 30 Hz). The server checks range (9 studs), a clear line and locks, then writes the parts' CFrames with `Workspace:BulkMoveTo` while it moves.
- `door.angle` is the truth; `door.open` becomes "passable", so Walker, Stalk, the Tactician and `Route` keep working. Doors built ajar start unlatched at the ajar angle and still aren't passable. `SetOpen` and `Toggle` still exist (they tween the angle) for the Guest and for the tap version.
- **Holding a door shut** against him counts as braced: he bangs every 1.2 s, then it jolts out of your hands. The B Brace prompt stays for touch and gamepad.
- **A door swinging into his body stops dead.** The server knows where he is; it's a cheap, strong scare.
- Your view is frozen while dragging (ContextActionService sinks mouse look; fallback: a pinned Scriptable camera). The dragging client predicts its own copy of the door each frame (fallback: no prediction; a round trip of lag reads as weight).
- Furniture uses the same logic. PropFactory builds each moving piece as a named sub-model (`Drawer1..n`, `DoorL`, `DoorR`, `Slider1`, `Slider2`), keeping the "find by child name" convention. **Container contents stay on the server**; an item is created inside a drawer only once it is more than half open.

### 4.6 Heavy push
| Piece | Pushers needed |
| --- | --- |
| Bed, Closet, Wardrobe, Sofa, Shelf, Fridge | 2 |
| Dresser | 1 (slow) |
| Piano | can't be moved |

- Hold the mouse on a heavy piece to push. The client sends `Push(direction)` at 10 Hz and your walk slows.
- `Logic/Push.speed(n, needed)`: with fewer pushers than needed it creeps (0.25 studs/s) and scrapes loudly (noise 12). At the count or more, up to 2.2 studs/s. Pushers are players who pushed in the last 0.3 s, within 4.5 studs and facing it; solo, the Companion helps as one.
- The server moves it at 15 Hz and sweeps every step with a Blockcast: door jambs stop it, so a bed can't go through a doorway, and it never crushes a player or the Guest. Pieces slide only; turning them can come later.

### 4.7 Barricades
- `Logic/Barricade` (pure, with a spec) reuses RoomFit's doorway lane (exported as `RoomFit.laneBox`). A heavy piece covering at least 40% of a lane's width in the first 5 studs from the wall makes `seam.barricade = { prop, side, weight }`.
- **The Guest:** Walker stands off in front of it and inserts a shove goal. He bangs every 1.1 s; after `ShoveSeconds` (3 s light to 6 s heavy, ×0.8 in hunts, never over 8 s) he shoves the piece 4 studs clear of the lane, along the wall if that's blocked. The stuck ladder gets a new rung, "shove the heavy piece in my sweep", which ends the loop a half-pushed bed would cause today.
- His retreat treats a barricaded doorway as shut, and his peek spots in that room are re-checked.
- **Nobody is ever trapped:** anyone can creep a piece alone, and "Squeeze past" (hold 1.5 s, noisy) gets you through.

### 4.8 Walk-in closets
- A new `Closet` prop (6 wide, 9 high, 4 deep, hollow, mirrored sliding doors, very 1988). Sliding doors need no swing space; the mirror is a Window-tagged pane, so his reflection works in it. Bedroom templates swap Wardrobe for Closet where it fits.
- **Hidden** = your root inside the interior box and both doors shut. No teleport, no anchoring, no invisibility: the doors block the view, and `Perception:CanSee` already ignores hidden players. If he watched you go in, his memory leads him there, which is fair by construction.
- His inspection slides the doors open. Space holds your breath.
- Under a bed or table and in the bath keep the E prompt and the peek camera.

### 4.9 Interactables, lights and lures
`Data/Interactables` with `InteractService` (server state in attributes) and `InteractController` (client sounds and lights).

| Thing | What it does |
| --- | --- |
| Toilet | Flush: a lure of radius 30 after 0.6 s, 10 s cooldown |
| Taps (sink, bath) | Running water, a lure of radius 14 every 4 s until turned off |
| TV | Static and a flickering glow, a lure of radius 18 every 5 s |
| Lamps | On and off |
| Light switches | One by each room's main doorway (`Logic/SwitchSpots`), never in a lane |
| Radio, music box | Play on every client from the prop itself, so they **keep playing while carried**; noise every 3 s, with the carrier as source while carried |

- `WorldService:IsLit(position)` follows switches, lamps, circuits (the breaker panel) and lit shrines, so light changes how far he sees: about 40 studs lit, 15 dark.
- **Lures.** A noise with no player behind it (a flush, a thrown bottle, a radio left on) goes on Perception's `lures` list. A new Stalk move and Tactician tactic, `Investigate`, sends him there when he sees nobody and the lure is fresher than his memory. The squad profile counts lures; a squad that leans on them finds him checking the hiding spots near the noise instead.

## 5. Progression: locks, keys and regions

### 5.1 The passage model
One function decides who can pass a seam right now: `WorldService:SeamCost(seamId, who) -> studs?`, where nil means blocked.

| who | Latched door | Ajar door | Locked / unopened bolt | Barricade |
| --- | --- | --- | --- | --- |
| player | 12 | 6 | nil | 20 (squeeze) |
| guest (between hunts) | 12 | 6 | 30, unseen and nobody within 25 studs | 60 |
| guestHunt | 12 | 6 | nil | 25 plus the shove |
| guestRetreat | 12 | 6 | nil | nil |

- `Logic/NavGraph.search` treats a nil door cost as a blocked step.
- `WorldService:Route(from, to, { who })`; `WorldService:Adjacency(who)` keeps graphs **updated in place** (`BeliefMap` holds the table); `PassageChanged(seamId, why)` tells Walker, Stalk, the Tactician and SquadProfileService.
- `Walker:Unreachable()`: when no route exists he stops and picks another goal, instead of walking a straight line through a wall.

Doors, locks, bolts, barricades and the R3 flips all go through this, so nothing patches the Guest's modules one by one.

### 5.2 The plan
`Logic/LockPlanner.plan(layout, templates, rng, cfg)` runs in `RunOrchestrator` after generation, on normal and fallback houses alike, with `rng:Fork("progression")`. It never rejects a house. It writes a nested `layout.progression` (so `FloorPlan.fingerprint`, which hashes scalar fields, and the golden and Mansion hashes don't change). It is never sent to clients; the builder reads it to put a door slab on every locked or bolted seam.

```lua
progression = {
	regions = { [0] = { rooms = { 1, 7, 10, 11, 12 } }, [1] = { rooms = { ... }, gate = "seam:2-3" }, ... },
	roomRegion = { [roomId] = regionIndex },
	locks = { -- by seam id
		["seam:2-3"] = { kind = "key", needs = { "key:1" } },
		["seam:5-8"] = { kind = "bolt", side = 5 }, -- a shortcut, opened from room 5's side
		["seam:3-13"] = { kind = "padlock", needs = { "code:2" } },
		["seam:4-6"] = { kind = "power", needs = { "power:3" } },
	},
	tokens = { -- every key, code, signal and item, and what produces it
		["key:1"] = { kind = "key", label = "Brass key, tag 'Pantry'", producer = { kind = "container", room = 11 } },
		["code:2"] = { kind = "code", producer = { kind = "puzzle", id = "terminal:1" } },
		["heirloom:1"] = { kind = "bulky", producer = { kind = "puzzle", id = "safe:1" } },
	},
	puzzles = { ["terminal:1"] = { kind = "terminal", room = 11, seed = 81231 } },
	finale = { table = 2, heirlooms = { "heirloom:1", "heirloom:2", "heirloom:3" }, cut = { "seam:1-2" } },
	order = { ... }, -- the solver's reference order
	stats = { regions = 3, puzzles = 3, backtracks = 1, depth = 6 },
}
```

Puzzle answers are not in the plan: each puzzle has its own seed and `PuzzleService` makes the answer when the run starts.

### 5.3 The algorithm: ordered regions, one gate each
Cutting one edge in a house full of loops separates nothing, so the planner works with region boundaries.
1. **Region 0** grows from the hall and always includes the dining room (the table must be visible from the start). It's a weighted frontier search: ground floor and public rooms first, and a bonus for rooms with two neighbours already inside, which is what puts chase loops into region 0. Size: `R0Share` (0.25–0.38) of the house.
2. **K anchor rooms** (2 for 18–20 rooms, 3 for 21–24, +1 on Hard) by farthest-point sampling, with zone variety (one service, one upstairs private, one far public). A multi-source BFS grows them into regions 1..K, connected by construction.
3. **Order:** a randomised Prim's search over the region graph from region 0.
4. **One gate per region.** Of its seams to regions already opened, one is the gate: with `BacktrackChance` (0.35) one from an *older* region (backtracking), and preferably one that already has a door. **Every other boundary seam becomes a bolt** opened from inside, Resident Evil's shortcut. The service wing's two entrances (dining → kitchen, and the back stairs upstairs) are just two boundary seams; no special case.
5. **Tokens.** Each gate has a flavour and consumes a token made by a producer in a region that opens earlier (preferably the one just before):

   | Lock | Token | Producer |
   | --- | --- | --- |
   | key | `key:i` | a container (drawer, cabinet), else a hook or a floor slot |
   | padlock | `code:i` | a note, or the terminal |
   | power | `power:i` | the breaker panel (which may need a fuse) |
   | board | `crowbar` | a bulky tool, reusable (R4) |

   Chains are at most 2 deep. At most one of each puzzle and `MaxPuzzles` (4) per run, given to heirlooms first, then gates.
6. **Heirlooms.** `FinaleItems` (2–3) from distinct regions and zones, each behind a puzzle (the safe, the music box) where one is available, otherwise in a container.
7. **The finale cut:** the seams that seal when the dinner starts. The dining room's doors to the hall, plus more if the way round is shorter than `FinaleRunStuds`. The planner checks that a route from the dining room to the front door survives, with every lock open.

**The solver** (`LockPlanner.solve`) is a fixed-point simulation: search the open and opened seams (a bolt opens when its inside room is reached), collect tokens whose producer room is reachable and whose inputs you hold, open every lock you can, repeat. A plan is solvable if the table can be set and the front door reached afterwards. It records the stages for the checks and for the objective line.

**Checks** (`LockPlanner.check`):
- Stage 0 has at least one chase loop of 100 studs or more (`Graph.fundamentalCycles`, `MansionHouse.routeStuds`) and at least 2 hiding spots.
- At every stage, with the newest region's bolts still shut, the dead-end depth is at most 3.
- Every region is connected inside itself.
- No lock on the front door; every lock seam gets a slab.

**Failure ladder:** for K down to 0, 24 attempts each with its own fork. K = 0 (the whole house open, only the heirlooms to find) always works.

### 5.4 Variety knobs (`Config.Progression`)
`Regions` by room count, `R0Share`, `BacktrackChance`, flavour weights (key 3, padlock 2, power 1, board 1), `Enabled` per puzzle (so R2a can ship with only the terminal), `MaxPuzzles`, `FinaleItems`, `FinaleRunStuds`, `ChainDepth`, `Stage0Loops`, `MaxDeadEndInStage`, `R0Hides`, `Attempts`. R4 adds the squad's recent puzzles to the weights.

### 5.5 The Guest and locks
- **Between hunts** he may pass a locked or unopened bolt, but only unseen and with nobody within 25 studs (players don't collide with him and could follow him through). You hear it: a heavy unlock click, the door opens, closes, relocks.
- **During hunts** a lock is a wall. At the hunt's telegraph, if he isn't in the part of the house the squad can reach, he is moved there unseen (the rules of `_forceArrive`: unseen spots, 15 studs from anyone).
- **At the dinner** every lock and bolt springs open, so the final hunt has the whole loop structure.

### 5.6 Keys and items
- Opening a container gives its key to the opener. Keys drop where their holder goes down, is Lost or leaves. A key that falls out of the world returns to where it was found.
- Bulky items (fuse, music box, heirlooms) go in slots 2–3 or are carried in your hands. Downed players drop them.
- Items are placed by `Logic/ItemPlacement`: containers first, then hooks and floor slots, with a run fork claimed at a fixed point in setup (`ToolPlacement.plan` is the model).

## 6. The dinner (the finale)
- From the start the dining table is set with plates, cutlery and candles, and **empty places**: one per heirloom, each with a place card showing the heirloom's silhouette.
- Carrying an heirloom to its place and holding to set it fills the place. The candles at that place light.
- **The last one:** the lights in the house die, a chair at the head of the table scrapes back, and he is sitting there. Then the dining room's doors to the hall slam and seal (the finale cut), every other lock springs open with a cascade of clicks, the final hunt starts (`StalkerService:StartFinalHunt`), and the front door unlocks with its porch light on.
- The front door replaces the rear exit as `world.exit`; the old exit room stays a room (its role stays in generation so the golden hashes hold).
- Extraction reuses `RunOrchestrator._onRitualComplete`.

## 7. Puzzles
Each kind is a pure module `Logic/Puzzles/<Kind>`:

```lua
generate(rng, ctx) -> spec            -- spec.answer stays on the server
view(spec) -> publicView              -- what clients may see
step(spec, state, input) -> state, events  -- events: feedback, noise?, solved?, failed?
solved(state) -> boolean
```

- `PuzzleService` builds stations from the plan (after RoomFit: the computer on a Desk top, the breaker panel and the wall safe in wall slots, the piano where it stands, the music box as a carriable item). One player operates at a time; others watch a SurfaceGui copy of the public state on the station.
- Remotes `PuzzleOpen`, `PuzzleInput`, `PuzzleState`, `PuzzleEvent`, `PuzzleClose`, each through `Net.onServer`, re-checking range (8 studs) and the operator on every input.
- Wrong or rushed input makes noise **with the player as source**: he learns where you are.
- On solve, the token goes to `ItemService` or `LockService`, and Drift gets `PuzzleSolved`.
- The client: `PuzzleController` and `UI/Puzzles/*`, each a `Ui.modal` screen, the camera eased to the station, with touch and gamepad layouts.

| Puzzle | Station | How it's made | How it plays | Spec proves |
| --- | --- | --- | --- | --- |
| **Terminal** | A 1988 home computer and a dot-matrix printer on a Desk (study first) | 5–8 letter words by difficulty, 10–14 from `Data/Words`, likeness spread out; bracket pairs remove a dud or reset tries | Pick a word, see how many letters are right in the right place. 4 tries; a lockout beeps (noise 8) for 15 s and keeps the same password. The printer prints the code for a **padlock** (`Puzzles/Padlock`, 3–4 wheels) | Always solvable in 4 tries (minimax over 500 seeds) |
| **Breaker** | Panel in a service room (laundry, mudroom, garage, pantry, kitchen) | 6–8 circuits grown by room per floor and wing; labels partly wrong; capacity C | Flipping a breaker turns **real house lights** on and off ("the nursery just went dark"). More than C on trips the main: every light out, a loud clunk (noise 30). The lock's lamp hums when powered. Solo: a wiring diagram and a clue note | A valid answer exists within C; the hints leave 3 or fewer candidates |
| **Safe by ear** | A wall safe behind a painting | 3 numbers on a 0–39 dial, alternating directions | Turn the dial with the mouse. Turned slowly, the right number clicks (the server sends the click, so the answer never leaves it). Spinning fast gives no clicks and rattles (noise 10) | A slow dial opens it; fast or out of order never does |
| **Music box** | A carriable music box and the piano | 4–7 notes on an 8-key pentatonic range, never three the same, the contour must change | Wind it and it plays on every client, even while carried to the piano. Play it back; a wrong note is a loud discord (noise 35) and a reset. Without a music room, set the box's pins instead. A visual hint setting lights the comb | The rules hold; the right sequence solves; any wrong note resets |

**The objective line** (`Logic/Objectives`, pure) is built from facts the squad has seen, never from the plan: "The kitchen door is locked. Find its key." "The computer in the study is still on." "Three places are still empty."

## 8. Drift
| Event | Change |
| --- | --- |
| Baseline | +2.5 per minute (unchanged) |
| Isolated player | +1 per minute each (unchanged) |
| PlayerDowned | +10 |
| HuntSurvived | −10 |
| LockOpened | −5 |
| RegionEntered | −4 |
| PuzzleSolved | −8 |
| ItemFound | −2, at most 3 per minute |
| PuzzleFailed | +3 |
| LoudNoise | +0.5, at most 2 per minute |

The evidence events go (WrongVerdict, EvidenceConfirmed, EvidencePhotographed, Anchor, CounterfeitUsed, RitualStage). `DriftModel`'s special anchor cap becomes a generic `Caps` table. The dinner stops Drift. `DirectorModel` gets an act input (R4). A pacing spec checks that a squad making steady progress stays under 85 and a stalled squad collapses before 45 minutes.

## 9. Phases

| Half | What | Gate |
| --- | --- | --- |
| R0 | This document, banners on `DesignDoc.md`, the `CLAUDE.md` roadmap | Owner approved the plan (2026-10-04) |
| R1a | Hands core: the passage model, 4 slots and the clip torch, door angles, drag, drawers, carry and throw, the stun, lures | Studio: drag, throw and stun by F2; navtest clean |
| R2a | The escape slice behind `Config.Run.Loop` (F2 `loop escape`): the planner, locks, keys, containers, the terminal and padlock, the dinner, the objective line | **A squad playtest of the slice** |
| R1b | World physics: decor moved out, interactables, switches and circuits, walk-in closets, heavy push, barricades | Studio: two-player push and barricades (owner, two clients) |
| R2b | The breaker, safe, music box, notes, the map, the Drift retune, **escape becomes the default**, then the old loop retires | Full runs on 3 seeds; solo with the Companion |
| R3 | The living house (section 10) | Playtest |
| R4 | Variety (section 10), then M4 furnishing merged with interactive props | Playtest |

### Commits
**R0**
1. This document; banners on `DesignDoc.md` sections 1–4 and 6; the `CLAUDE.md` roadmap.

**R1a: hands core**
1. Passage groundwork: `NavGraph` nil steps, `SeamCost`, `Route{who}`, `PassageChanged`, `Adjacency(who)`, `Walker` unreachable; the Prop, Held and Heavy collision groups.
2. Four slots and the clip torch: `Inventory`, `PA.Slot4`, `Hotbar`, `ActionController`, `ToolService`, the light rule and `ClipLight`, a `Hands` view pose, the how-to text.
3. Door angles: `Logic/Articulation`, `DoorService` angle state, `BulkMoveTo`, F2 `door`.
4. Drag: `HandsController`, the `Drag` remote, prediction and the look freeze (with fallbacks), held-door bracing, the door stopping at his body, a drag row in `FocusMarkers`.
5. Furniture: drawer and door sub-models in `PropFactory`, `FurnitureService`, containers with junk.
6. Carry and throw: `Data/Physical`, `Logic/Throw`, `HandsService`, re-anchoring, impact noise, F2 `grab` and `throw`.
7. The stun: the `Stagger` pose, `StalkerService:Stun`, the stunned gate in `StalkRules`, the paused hunt timer, F2 `throwat guest`.
8. Lures: Perception `lures`, the `Investigate` move and tactic, props that clatter as he passes, F2 `lure`.
9. Docs: `ARCHITECTURE.md`, `TESTING.md`, README controls.

**R2a: the escape slice**
1. `LockPlanner` (plan, solve, check), `Logic/Stations`, `Config.Progression`, the spec over 150 seeds, the `tools/plan` overlay, `tools/lockstats`.
2. `Puzzles/Terminal`, `Puzzles/Padlock`, `Data/Words`.
3. No `SeamFlip` or fake walls in escape mode.
4. `LockService`: the plan in `RunOrchestrator`, slabs on lock seams, rattles, unlock prompts, bolts, per-player key rings, the Guest's click-pass and relocation, `BeliefMap` on the player graph, F2 `locks`, `unlock`, `give`.
5. Items and containers: `Logic/ItemPlacement`, `ItemService`, the HUD key ring.
6. The terminal in the house: `PuzzleService`, the computer and printer, `UI/Puzzles/Terminal`, the printed note, the padlock, F2 `puzzle` and `solve`.
7. The dinner, v1: `FinaleService`, the table, the set piece, the finale cut, the front door as the exit, `Logic/Objectives` and the objective line.
8. Docs, TCs and the playtest request.

**R1b: world physics**
1. `DecorService` (portraits, decor clocks and radios out of `AnomalyService`), `Data/ClockTimes`, the `RadioSignal` fix.
2. Interactables, `Logic/SwitchSpots`, switches, circuits and `IsLit`, the radio playing while carried.
3. Walk-in closets.
4. Heavy push, with Companion help, F2 `push`.
5. Barricades, the shove, the stuck-ladder rung, squeeze past, F2 `barricade`, `navtest barricade`.
6. Docs and TCs.

**R2b: puzzles, retune, retirements**
1. Breaker. 2. Safe. 3. Music box and piano. 4. Notes and the note reader. 5. The map (`MapService`, doorways in the layout snapshot, the Map tab with locks, bolts, items and key drops). 6. The Drift and Director retune, `survivedHunts`, the Dossier's progress section. 7. **Escape becomes the default.** 8. Retire Verdict and the Case Board. 9. Retire anomalies, evidence, rituals, the Camera and Plumb Line, the Phantom twist; `PerceptionPlanner` becomes atmosphere only. 10. Retire Witness windows, anchoring and Focus (section 11). 11. Docs.

## 10. Later: the living house (R3) and variety (R4)
**R3.**
- `Logic/HouseShift.check` applies a candidate flip to a copy of the layout and runs `LayoutValidator.validate` and `LockPlanner.solve` from the current state. It never flips a stairwell seam, a bridge (`Graph.cycleThroughEdge` returns nil), a gate, a bolt or the finale cut, and never lets a flip skip a lock.
- `WorldService:SetSeamConnected` swaps both seam panels, the trim (indexed at build time), the door slab (`LevelBuilder.seamDoor` and a public DoorService setup and teardown) and the truth tables, then fires `PassageChanged`.
- The unseen check counts a stale view as seeing, includes Echoes and the Companion, tests both faces of the seam, and wants nobody within two rooms, no hunt and nothing in the gap.
- Shifts start only after the squad has used `SquadProfileService:FavouriteLoop()` a few times; close one of its doors and open another wall, so the house keeps its loops. Cooldown 3–5 minutes, a cap per run.
- `Data/HouseEvents` through `Logic/ScareDeck`, never something to solve: the phone rings; the radio turns itself on; corridor lights die one by one; knocking from inside a closet; footsteps overhead; the hall clock strikes thirteen.

**R4.** Acts drive the Director (calm, then hunts by interval, then shifts). More locks and puzzles: crowbar boards, a clock-hands puzzle (`Logic/ClockFace`), the telephone, the dumbwaiter. More set pieces. Run modifiers (Blackout, Restless, Silent). The squad's recent puzzles in the profile, so runs don't repeat. Then M4 furnishing, merged with interactive props.

## 11. What retires, and when
| System | Fate | When |
| --- | --- | --- |
| Portraits, decor clocks and radios, the clock-time pool | Move to `DecorService` and `Data/ClockTimes` | R1b.1 |
| Walkable phantom doors and fake walls (`SeamFlip`) | Off in escape mode, then deleted: a phantom door is a real hole past a lock, and a way to push a prop through a wall | R2a.3, R2b.9 |
| Verdict, Case Board, the Deliberation Table prompt | Retire. The `deliberation` role and its validator rule stay; the dining room hosts the dinner | R2b.8 |
| Anomalies, tells, evidence, rituals, the Witness Camera, the Plumb Line | Retire. The tell prop builders (Clock, Note, KeyTag, Fusebox) are reused as props and puzzle stations | R2b.9 |
| Witness windows, anchoring, Focus | Retire. **Keep** `ReportView`, `GetView`, `IsLookingAt`, `ClearLine`, pings, callouts, `FakePing`, the two-watcher freeze and the 3 s co-stare (no Focus cost) | R2b.10 |
| Lantern, Radio (static near him) | Keep | |
| Phase names | Keep (Investigation = exploring, Resolution = the dinner); rename later if wanted | |

## 12. Additions to the fairness contract (DesignDoc section 3)
- **Locks:** every plan is solvable; the area open at the start has a chase loop and hiding spots; a lock is a wall for the Guest during hunts; Echoes can't pass locks.
- **Barricades** delay the Guest by at most 8 s and never trap a player.
- **Flips (R3)** happen only where nobody could see, never close a stairwell or a bridge, never skip a lock, and keep every validator rule.
- **Throws** are decided on the server; stuns shrink when repeated.
- **Items can't be lost:** anything that leaves the world or a Lost player's hands returns to where it was found or where its holder fell.

## 13. Risks
1. **Engine unknowns,** each checked in the commit that needs it, each with a fallback flag in Config: does sinking mouse look stop the PlayerModule's camera (else a Scriptable camera)? Does a client-predicted door fight replication (else no prediction)? Is client-owned carrying smooth for others (else the server drives it)?
2. **The Guest's navigation.** Angled doors, locks, barricades and flips all touch it. `navtest fast` on seeds 61, 1800820264 and 7, `navtest retreat` and later `navtest barricade` run after every commit that touches passage.
3. **Exploits.** Client-owned props are validated; drags need reach and a clear line; pushes are aggregated and capped; puzzles count tries, lock out and make noise on the server.
4. **Fairness shrinks with locks.** Fewer loops are open early, so the stage checks matter, and the R2a playtest must say whether chases in region 0 feel fair.
5. **Solo play.** The Companion helps push; the breaker has a wiring diagram; the music box has a visual hint.
6. **Performance.** Props re-anchor once asleep; `BulkMoveTo` runs only while something moves; at most 4 held props are validated per Heartbeat; the R3 validator runs throttled.
7. **Tests and Gate A.** The planner is nested, so the golden and Mansion hashes hold. The old house's Gate A part hash changes once props gain drawers and closets: ask the owner before re-baselining it.
8. **Scope.** About 35 commits for R1 and R2. The `Loop` flag keeps the game playable throughout.
9. **Determinism.** The plan and puzzle answers come from the seed; shifts and events depend on players and are logged through Telemetry.
10. **Content and accessibility.** Notes stay within the Moderate rating. Two of the four puzzles are about sound; the visual hints matter.

## 14. New manual tests (to be numbered in `TESTING.md` as they land)
- A carried prop and a dragged door look the same on two clients; a carried thing never flings its holder.
- A throw stuns him once, briefly; a second throw within a minute is shorter.
- A flush, a thrown bottle or a radio left on draws him to it.
- Two players push a bed together; one alone only creeps it.
- A bed in a doorway holds him for a few seconds of banging in a hunt, then he shoves it clear.
- Hiding in a closet by shutting the doors from inside; he slides them open.
- A key drops where its holder goes down; a teammate can pick it up.
- The radio and the music box are heard by everyone while someone carries them.
- A full escape run with 2–4 players: locks, a puzzle, the dinner, the run to the front door. "Did it ever feel like it cheated?"
