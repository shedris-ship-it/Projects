# The gameplay rework: a hands-on haunted mansion

Status (2026-10-05): **R0, R1a, R2a and R2c done.** R2c, "the loop deepened" (section 9, builds `2026-10-05.6` to `.23`), took in nearly all of R1b and R2b plus the owner's fixes and extras of 2026-10-05: the escape is the only loop and the clue loop is gone; acts and hunts woken by progress; physics with weight and momentum; the Guest wants his dinner; leads instead of rummaging; the map and journal; puzzles as a registry with the breaker, the safe and the music box; crank doors and the dumbwaiter; walk-in closets and barricades; a run journal in the Dossier. **Next: the squad playtest** (`TESTING.md` TC-68, with TC-69 to TC-89 for the parts that need two clients), then R3 (the living house). This replaces the core loop of [`DesignDoc.md`](../DesignDoc.md) sections 1–4 and 6: no more evidence, Case Board, verdict or rituals. The Guest (section 5), Drift, the mansion generator ([`mansion-generation.md`](mansion-generation.md)) and the art direction ([`ART.md`](../ART.md)) stay. The work runs in four halves, **R1a → R2a → R1b → R2b** (section 9), so the new loop is playable about halfway through, with R3 (the living house) and R4 (variety) after it.

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
| Furniture | **All of it is physical, with varying weights** (2026-10-05): light pieces are carried like small things, the rest are pushed, and the heaviest need friends (section 4.6). |

Defaults Claude chose, open to the owner:
- The Guest can pass a locked door only between hunts, unseen, with nobody within 25 studs, and with a loud unlock click. **During a hunt a lock is a wall for him too**, so chases stay inside the part of the house the squad can reach.
- Stuns are short and shrink when repeated: 0.7 s (light things), 1.2 s (medium), 1.8 s (heavy), halved for each stun in the last minute, then 4 s of immunity, ×0.6 in the final hunt. Only a player he is visible to can stun him.
- A barricade delays him at most 8 s and never traps a player ("squeeze past").
- Lost players (Echoes) can't pass locks.
- Lantern rooms stay, as Resident Evil's save rooms.
- The phase names stay for now: Investigation is exploring, Resolution is the dinner.

**R2c decisions (2026-10-05).** The owner asked how to deepen the loop, and chose to do all of it: acts and progress-woken hunts (a good squad was never hunted before the dinner), a Guest who wants his dinner, leads instead of opening every drawer, locks and puzzles that want two places at once (with a solo way), and a map and journal. Extras chosen: he waits at the table, he visits his things, he tidies up; barricades and closets; a physics feel pass ("unnatural and somewhat laggy, momentum should be improved"). Both two-person mechanisms (the crank door and the dumbwaiter). Retire the old loop now, not after a playtest. One squad playtest after everything. Defaults Claude chose, open to the owner: a carried heirloom's scent pauses while its carrier hides; when nothing lets a barricade move, he slips past it only while nobody can see.

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
- Furniture uses the same logic. PropFactory builds each moving piece as a named sub-model (`Drawer1..n`, `DoorL`, `DoorR`, `Door1..n`, `DoorTop`, `Lid`) whose main part carries its joint (`Lib/Joint`), keeping the "find by child name" convention. **Container contents stay on the server**; an item is created inside a drawer only once it is more than half open.

### 4.6 Every piece of furniture, by weight
The owner asked for the physics to cover all furniture, with varying weights (2026-10-05). Each furniture kind gets a weight in `Data/Physical.Furniture`, counted in people: 1 is what one player moves at full speed.

| How it moves | Kinds (weight) |
| --- | --- |
| Carried, like small things (a class, section 4.3) | Chair, Plant, CoatRack, FloorLamp (still lit in your hands), Boxes, Mannequin |
| Pushed alone | Crib 0.7, Armchair 0.8, Bench 0.8, TVStand 0.9, Table 1, Chest 1, Desk 1.1, Dresser 1.3 (slowly), Locker 1.4 (slowly) |
| Pushed by two | GrandfatherClock 1.6, Washer 1.6, Sofa 1.8, Shelf 1.8, DiningTable 1.8, Bed 2, Cabinet 2, Workbench 2, Wardrobe 2.2, Fridge 2.4 |
| Takes the squad | Piano 3.5 |
| Fixed (built in or plumbed) | Counter, Sink, Toilet, Bathtub, Stove, WaterHeater, Car, Curtain, Rug, Shrine |

- Hold the mouse on a pushable piece and walk: you push it. The client sends `Push(direction)` at 10 Hz and your walk slows by its weight.
- `Logic/Push.speed(strength, weight)` (pure, with a spec). Strength is the players who pushed it in the last 0.3 s, within 4.5 studs and facing it; solo, the Companion helps as one. Below three quarters of its weight it only creeps (0.25 studs/s) and scrapes loudly; from there it speeds up to 2.2 studs/s at full strength. So a bed creeps for one and moves for two, a dresser moves slowly for one, and the piano wants three or four.
- Scraping is noise with the pushers as its source, louder for heavier pieces.
- The server moves it at 15 Hz and sweeps every step against the house (walls, door jambs, other furniture, players, the Guest): a bed can't go through a doorway, and nothing is ever crushed. Pieces slide only; turning them can come later.
- **What moves with it:** its drawers and doors (their joints are rewritten), what's kept inside, things standing on top, its light, and its hiding spot.
- **Until barricades land (R1b),** pushes stay out of doorway lanes and room middles (RoomFit's clear boxes), so the Guest's graph never breaks. Barricades then open the lanes to heavy pieces.

### 4.7 Barricades
- `Logic/Barricade` (pure, with a spec) reuses RoomFit's doorway lane (exported as `RoomFit.laneBox`). A heavy piece covering at least 40% of a lane's width in the first 5 studs from the wall makes `seam.barricade = { prop, side, weight }`.
- **The Guest:** Walker stands off in front of it and inserts a shove goal. He bangs every 1.1 s; after `ShoveSeconds` (3 s light to 6 s heavy, ×0.8 in hunts, never over 8 s) he shoves the piece 4 studs clear of the lane, along the wall if that's blocked. The stuck ladder gets a new rung, "shove the heavy piece in my sweep", which ends the loop a half-pushed bed would cause today.
- His retreat treats a barricaded doorway as shut, and his peek spots in that room are re-checked.
- **Nobody is ever trapped:** anyone can creep a piece alone, and "Squeeze past" (hold 1.5 s, noisy) gets you through.
- **As built (R2c.9b, section 9):** the lane is measured from the doorway's middle on the wall line, not RoomFit's box; the walker stops at a barricade itself (at the doorway, or up against the piece on his side), so there's no stuck-ladder rung; the shove takes the first of a few ways that leaves the doorway open (deeper into the room when he's outside it, else along the wall); his peek spots aren't re-checked yet.

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
| R1b | World physics: decor moved out, interactables, switches and circuits, walk-in closets, heavy push, barricades | **Done in R2c.** Studio: two-player push and barricades (owner, two clients) |
| R2b | The breaker, safe, music box, notes, the map, the Drift retune, **escape becomes the default**, then the old loop retires | **Done in R2c.** Full runs on 3 seeds; solo with the Companion |
| R2c | The loop deepened (the owner's choices of 2026-10-05, section 2): R1b and R2b plus acts, the Guest's errands, leads, two-person locks, the map, the physics feel pass, the run journal | **The squad playtest** (TC-68 to TC-89) |
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

**R1a, added (the owner's request of 2026-10-05, pulled forward from R1b.4)**
10. Every piece of furniture by weight (section 4.6): weights in `Data/Physical`, the light pieces carried, `Logic/Push` (spec), pushing on the server with the sweep, what rides along, the keep-clear rule, Companion help, the `Push` remote, F2 `push`.

**R1b: world physics**
1. `DecorService` (portraits, decor clocks and radios out of `AnomalyService`), `Data/ClockTimes`, the `RadioSignal` fix.
2. Interactables, `Logic/SwitchSpots`, switches, circuits and `IsLit`, the radio playing while carried.
3. Walk-in closets.
4. (Moved to R1a.10: furniture by weight.)
5. Barricades, the shove, the stuck-ladder rung, squeeze past, F2 `barricade`, `navtest barricade`.
6. Docs and TCs.

**R2b: puzzles, retune, retirements**
1. Breaker. 2. Safe. 3. Music box and piano. 4. Notes and the note reader. 5. The map (`MapService`, doorways in the layout snapshot, the Map tab with locks, bolts, items and key drops). 6. The Drift and Director retune, `survivedHunts`, the Dossier's progress section. 7. **Escape becomes the default.** 8. Retire Verdict and the Case Board. 9. Retire anomalies, evidence, rituals, the Camera and Plumb Line, the Phantom twist; `PerceptionPlanner` becomes atmosphere only. 10. Retire Witness windows, anchoring and Focus (section 11). 11. Docs.

### R1a as built (2026-10-04/05, builds `2026-10-04.11` to `2026-10-05.2`)
- **R1a.1 passage model:** `WorldService:SeamCost(seam, who)` for `player`, `guest`, `guestHunt` and `guestRetreat`; `NavGraph.search` treats a nil door cost as blocked (spec); `Route{who}`, `NavDistances{who}`; `MarkPassageChanged` and `passageVersion`; `Walker:Unreachable()` (he stands rather than walk at a wall, re-routes when a seam on his way changes, looks again once a second); hunt inspections only from where he stands; the Prop, Held and Heavy collision groups; F2 `block`. Studio: navtest fast on seeds 61, 1800820264 and 7: 0 failed, 0 phases; a blocked doorway gives NO WAY.
- **R1a.2 four slots:** `Logic/Inventory` (spec), the clip light (`Config.Hands.ClipLight`, `PA.TorchClipped`), hotbar, HUD. Bare hands draw nothing on screen (two primitive hands read as bricks). Fixed: Radio static that never stopped.
- **R1a.3 door angles:** `Logic/Articulation` (spec), DoorService stepping and `BulkMoveTo`, ajar doors quicker for him, F2 `door`.
- **R1a.4 drag:** `Controllers/HandsController`, `Services/HandsService`, the `Drag` remote. The view is held by re-aiming the camera right after the camera updates (it reads the mouse through `UserInputService`, so sinking input can't stop it). Holding a door shut braces it; he forces it out of your hands; a swing into him stops dead. F2 `drag` (Studio's input tool can't move a locked mouse).
- **R1a.6 carry and throw:** `Data/Physical`, `Logic/Throw` (spec), `Grab`/`Release`/`Throw`. Registered at build (queries on, still anchored: Gate A hashes `CanCollide`, not `CanQuery`), woken on the first grab, checked every frame (put back on a jump or a wall crossing: tested), re-anchored once still. Fixed: focus-marker rows swallowed clicks under the locked cursor (now only buttons on touch).
- **R1a.7 stun:** the hit test on each step's path, `StalkerService:Stun`, the Stagger pose, `StalkRules` "stunned" (spec), F2 `stun`, `throwat`. Studio: 1.8 s, then 0.9 s for a repeat.
- **R1a.8 lures:** Perception keeps sourceless impact and lure noises; the Investigate move and tactic; wariness after repeats; F2 `lure`. Not done: things clattering as he passes.
- **R1a.10 furniture by weight (build `2026-10-05.2`):** every furniture kind is carried (`bulky`: plant, coat rack, floor lamp, mannequin; held by the middle, off to one side, never into the floor; a lamp stays lit) or pushed (`Data/Physical.Furniture` weights; `Logic/Push`, spec; `Services/PushService`; the `Push` remote; `Config.Push`), or fixed on purpose (a spec checks every kind). Pushes are checked every step against walls, furniture and bodies, keep clear of the Guest's walking points and of door swings (until barricades, R1b.5), scrape (noise by weight), and carry drawers, contents, things on top and hiding spots along; drawers and doors re-measure how far they open once it stops. Studio, old house: one person creeps a bed (0.25 studs/s) and two move it at 2.2; three stopped it against a wardrobe; a dresser goes 1.08 studs/s for one and its drawers open at the new spot with their contents; pushing it at a doorway stopped it outside the door's swing; a client holding the mouse on the bed and walking moved it; a lamp carried lit and dropped upright. Gate A unchanged. F2 `push`. Not done: the Companion actually walking over to help (it helps when within 10 studs), turning pieces, pushing on touch.
- **Not checked yet:** the feel of dragging with a real mouse; holding a door against him in a hunt; a door stopping against him; two clients watching a carried thing (TC-51 to TC-58).
- **R1a.5 furniture that opens (build `2026-10-05.1`):** dressers and desks have drawers; wardrobes, cabinets, lockers, kitchen cupboards and the fridge have hinged doors over hollow insides; chests have a lid (`World/PropFactory`, `Lib/Joint`, `Services/FurnitureService`, `Config.Furniture`). Dragged by hand like doors, or E. Each learns at build how far it opens before hitting a wall. The first time one is opened half way, the server puts what's kept inside there: an odd small thing from `World/Junk` about half the time, carried and thrown like any other; R2a's items arrive through `FurnitureService.Filler`. Things in a drawer ride it in and out. Hiding in a wardrobe or locker pulls its doors shut, and leaving (or being found) swings them open. The fridge lights inside. Small things are forgiving to aim at (looking just past one picks it up), and the dresser is now 3.6 high so you can see into its top drawer. Studio, old house and mansion seed 61: clean consoles; drawers, doors and lids by hand and by E; a pill bottle taken out of a top drawer; hiding shuts the wardrobe. **Gate A re-baselined (owner's OK, 2026-10-05):** the old house is now parts 2272, hash 1308511249 (two fresh runs).

### R2a as built (2026-10-05 on)
- **R2a.1 the lock planner:** `Logic/LockPlanner` (plan, solve, check; spec over 100 mansions, 30 old houses and the fallback), `Config.Progression`, `lune run tools/plan <seed> mansion locks` (the plan beside the floor plan) and `lune run tools/lockstats [n] [mode]`. Changes from 5.3, found tuning: region 0 starts from a loop through the hall or the dining room (otherwise a third of attempts had nowhere to run); the dead-end limit is measured with each stage's bolts open, and a newly opened region instead may run at most `RegionDepth` (4) rooms past its gate (with bolts shut a whole region is one dead end, so the old rule failed nearly every attempt). On 60 mansions: 2 regions 28, 3 regions 30, 1 region 2; a padlock (the computer) in about half; all solvable. Old house: one region in 59 of 60.
- **R2a.3 locks and keys in a run (build `2026-10-05.3`):** `Config.Run.Loop` ("Clues" stays the default) and F2 `loop escape`. An escape run plans its locks right after generation (every locked doorway gets a door), skips the anomaly, evidence, tells, divergence and the verdict (`AnomalyService:SetupAtmosphere` keeps portraits, clocks and radios), and starts `LockService` (locked doors shut and plated; E or a pull tries one: a key on your ring turns and is used up, a bolt slides back only from its side, otherwise it rattles and says why; `Unlocked`/`Tried` signals) and `ItemService` (each key and heirloom goes in a drawer or cupboard of its planned room and is made the first time that space is opened, or lies on the floor when the room has none; a key taken by hand goes on your ring, shown on the HUD; keys fall where you go down or leave). A locked door is a wall to everyone (`SeamCost` nil), and The Guest only arrives, or is moved for a hunt, where the squad can reach (`LockService:Reachable`). F2 `locks`, `unlock`, `give`, `items`. Studio, seed 61: 3 regions, 6 locks, as planned; a bolt refused from the wrong side and slid back from its own; a key taken from a dresser drawer opened its door; he arrived on the squad's side. Not yet: his unseen click-pass through locks between hunts (a default in section 2), so for now a lock is a wall to him always.
- **R2a.6 the dinner (build `2026-10-05.5`):** `FinaleService` lays the dining table with one empty place per heirloom (a plate, a place card, an unlit candle); carrying an heirloom there and holding E sets it (the card names it, the candle lights). The last one serves the dinner: every light dies, a chair scrapes and The Guest is standing at the head of the table (`StalkerService:PlaceAt`), then the plan's cut seals (`LockService:LockSeam`), every other lock springs open in a cascade, the front door swings open with its porch light on (the mansion's `world.exit` is now the front door, so his arrival knock is there too; the old house keeps its exit), the hall's light comes back, and `RunOrchestrator:BeginEscape` starts the final hunt in Extraction. The HUD's objective line (`Logic/Objectives`, spec) reads only what the squad has seen: the empty places, the last locked door tried, the computer once someone has been near it, then "The front door is open. Get out." The verdict table's prompt is hidden in escape runs. Studio, seed 1: a doll set at its place; F2 `resolve` served the dinner: only the dining room's door to the hall stayed locked, the front door opened, and walking out of it extracted and won the run. Old house: an escape run builds (one region, two locks). Fixed on the way: after you got out, the solo Companion kept chasing you into the hub (a shapecast over 1024 studs errored).
- **R2a.5 the computer in the house (build `2026-10-05.4`):** `PuzzleService` puts a beige 1988 computer (its screen glowing green) and a dot-matrix printer on a desk in the planned room, runs it for one operator at a time (range and operator re-checked on every input; the answer never leaves the server) and runs each padlocked door's padlock. `UI/Puzzle` draws the terminal (click words and bracket pairs; the log down the right; tries left) and the padlock (digit wheels, Pull). A lockout beeps loudly (noise 20, you as its source) and adds Drift; solving calms it (`PuzzleSolved`) and prints a page with the code ("don't let HIM in"), a thing anyone can pick up and read. Drift events `LockOpened`, `PuzzleSolved`, `ItemFound`, `PuzzleFailed` exist (section 8 values). F2 `solve`. Studio, seed 1: a wrong word said its likeness, a bracket gave tries back, the solved screen printed "8 7 5", and that code opened the padlocked door.
- **R2a.2 the computer and the padlock:** `Logic/Puzzles/Terminal` (a dump of 32 rows of junk with 10–13 words of 5–8 letters from `Data/Words`, likeness feedback, 4 tries, a 15 s lockout with the same password, 3–5 bracket pairs that remove a dud or give tries back; only sets a careful player can crack in 4 tries are kept, proven over 300 seeds) and `Logic/Puzzles/Padlock` (3–4 wheels; pulling a wrong code rattles). Spec: `Terminal.spec`.

### R2c as built (2026-10-05, builds `2026-10-05.6` to `.23`)
The plan was ten stages; each commit says what was checked in Studio and what wasn't. In order:
- **R2c.1 one loop.** The clue loop retired: anomalies, tells, evidence, rituals, the Case Board, the verdict, Witness windows, anchoring, Focus, the Witness Camera, the Plumb Line, the Phantom and Gaze twists, `Config.Run.Loop`. `DecorService` keeps the portraits, clocks and radios (same fork and draw order). Divergence is atmosphere only (`Logic/Atmosphere`, spec: never on a door, item, station or anything you carry). The two-watcher freeze and the 3 s co-stare stay, with no Focus. `ClearLine` no longer sees through solid seam panels. Run content builds into `RunContent`, which Gate A leaves out. Gate A re-baselined with the owner's OK.
- **R2c.2 acts and woken hunts.** `Logic/Acts` (spec) makes an act from progress; `Config.Pacing.ActHeat` (0/25/40/40) adds to his tier. The first step into a new region (`LockService.RegionEntered`), a new act and the first heirloom found arm a hunt 60–120 s later (`Director:Arm`, its own fork), behind every hunt rule plus a 180 s gap; a Lantern room holds it. While it wakes he drifts toward you and a door slams near him. Four minutes without progress and Drift climbs faster. `Pacing.spec` simulates whole runs. Changed from the plan: ActHeat and the 180 s gap were tuned on the pacing spec.
- **R2c.3 physics feel.** `Logic/Heft` (a spring hold point per class: light keeps up, heavy trails, sags and bobs), client-launched throws with a wind-up checked on the server (progress items taken back; stuns on the first arc only), `Logic/Articulation` with momentum (held, driven, free: bounce, slam, click, ajar; walkable 55° to 45°), `Controllers/MotionController` (the one writer of moving joints on a client, from 20 Hz motion snapshots), pushing that accelerates and coasts at 30 Hz.
- **R2c.4 the Guest wants his dinner.** Heirloom scent (`Logic/Scent`), visiting his things, errands: waiting at the head of the table while every unset heirloom is carried (`Logic/Dinner` keeps every place out of his reach), tidying a long-dropped heirloom back to where it was kept.
- **R2c.5 the planner as a registry, and leads.** `LockPlanner.Gates` and `Keepers`; side-worked gates and multi-room producers. `Logic/Leads`: notes (text only on reading, `UI/Reader`), keepsake boxes, display cases (pick or smash), key racks, decoys.
- **R2c.6 the map and journal.** `MapService` (only what someone has seen), `UI/Map` (Tab, gamepad Y), the journal with `DropKey`.
- **R2c.7 puzzles and the house's fixtures.** Puzzles as a registry (`Logic/PuzzleKinds`, `server/Puzzles`, `UI/Puzzles`), a telegraphed hunt closes every screen. Fixtures and switches (`InteractService`) and one light rule (`WorldService:SetLightCause`). The breaker panel and power doors (`Logic/Circuits`). The wall safe by ear. The music box and the piano.
- **R2c.8 two-person locks.** Crank doors (`CrankService`, a gate kind) and the dumbwaiter (a two-room keeper, mansions only).
- **R2c.9 survival kit.** Walk-in closets (physical hiding; Gate A re-baselined with the owner's OK). Barricades (section 4.7 as built below).
- **R2c.10 the debrief and fairness.** `RunLogService`: the Dossier's THE HOUSE lines (who opened, solved, carried and set what, acts, hunts, tidying, the closest call while carrying), Marks for progress (+10 a region, +10 a puzzle, +15 a hunt survived), telemetry for each step. Echoes collide with locked doors. The Brace prompt moved to LB (Y opens the map).

**Barricades as built (section 4.7).** Only real doorways count (a solid wall between rooms has walking points too, kept clear for R3). `Logic/Barricade` (spec) says a heavy piece (weight 1+: a table and up) bars a doorway on its side when it covers 40% of the lane's width (the doorway's width, 5 studs into the room), or stands on his walking points there (the doorway and the approach in front of it, within `Config.Push.KeepClear`): pushed in from the side, a piece reaches the approach long before it covers 40%, so that's what lets a barricade be pushed into place. PushService lets a piece onto those points only if it then bars the doorway; room middles and stair feet stay clear as before. Doors: a shut door's swing may be filled while the door can still open to walkable (55°; it stops against the piece), or by a heavy piece, which then bars the doorway; an open door's leaf is kept clear; any pushed piece stops a door's swing (`PushService:SwingStop`), and a door stopped short is solid again. Barred doorways cost a player 20, him 60 between hunts and 25 hunting (`SeamCost`), and he can't back away through one. A "Squeeze past" prompt (hold Q or R3 for 1.5 s, noisy; its own key, because Roblox shows one prompt per key and the door's own E prompt is right there) gets anyone through. At a barricade he bangs, then after 3–6 s by weight (×0.8 hunting, never over 8 s) shoves it clear along the first way that leaves the doorway open (`Barricade.shoves`, checked stud by stud); if nothing lets it move he slips past once nobody can see. A door swinging into a barricade stops against it. Not built: `navtest barricade` (F2 `barricade here` and `navtest room` cover it), map marks for barricades.

**Not built from the R2c plan, or changed:** the Guest's click-pass through locks between hunts (a lock is still always a wall to him); touch controls for the hands; client smoothing of pushes (not needed in Studio); `DumbwaiterUsed` telemetry (it's `PuzzleSolved` with kind `dumbwaiter`).

**Not checked by Claude (needs the owner):** anything with two clients (TC-69 to TC-89 mark which), sounds by ear (the safe's click, the music box, the flush), and the feel of carrying, throwing and dragging by hand. Checked in Studio after the owner freed disk space (seed 61, build `2026-10-05.24`): a cabinet pushed (F2 `push`) along the den's wall into its doorway bars it and its squeeze prompt appears; the prompt held from the client (with the camera on the doorway) squeezes you through, both ways; a door swinging into a barricade stops at 4° and stays solid; he came at a barricade from its own side, banged about 6 s, shoved it clear along the wall, swung the door open and walked in; locked doors collide with Echoes and unlocked ones don't; the Dossier's THE HOUSE lines and the Marks after a run with a puzzle solved and an heirloom carried; the new event lines; `navtest fast` with every lock open on seeds 61 (24 legs), 7 (21) and the old house 1800820264 (15): 0 failed, 0 stuck, 0 phases, and nothing bars a doorway at the start on any of them; Gate A unchanged (2134 parts, hash 1322547804); a whole run on seed 61 served by F2 `resolve` and walked out of the front door: won, extracted, 213 Marks; clean consoles.

## 10. Later: the living house (R3) and variety (R4)

> **R3 is now L4 of [`level-design.md`](level-design.md)** (2026-10-05), with the flips chosen by L1's simulator. The lock planner's regions now come from that document's wings and beats (L1).

**R3.**
- `Logic/HouseShift.check` applies a candidate flip to a copy of the layout and runs `LayoutValidator.validate` and `LockPlanner.solve` from the current state. It never flips a stairwell seam, a bridge (`Graph.cycleThroughEdge` returns nil), a gate, a bolt or the finale cut, and never lets a flip skip a lock.
- `WorldService:SetSeamConnected` swaps both seam panels, the trim (indexed at build time), the door slab (`LevelBuilder.seamDoor` and a public DoorService setup and teardown) and the truth tables, then fires `PassageChanged`.
- The unseen check counts a stale view as seeing, includes Echoes and the Companion, tests both faces of the seam, and wants nobody within two rooms, no hunt and nothing in the gap.
- Shifts start only after the squad has used `SquadProfileService:FavouriteLoop()` a few times; close one of its doors and open another wall, so the house keeps its loops. Cooldown 3–5 minutes, a cap per run.
- `Data/HouseEvents` through `Logic/ScareDeck`, never something to solve: the phone rings; the radio turns itself on; corridor lights die one by one; knocking from inside a closet; footsteps overhead; the hall clock strikes thirteen.

**R4.** Acts drive house shifts too (acts already drive hunts, R2c.2). More locks and puzzles: crowbar boards, a clock-hands puzzle (`Logic/ClockFace`), the telephone. More set pieces. Run modifiers (Blackout, Restless, Silent). The squad's recent puzzles in the profile, so runs don't repeat. Then M4 furnishing, merged with interactive props.

## 11. What retires, and when
| System | Fate | When |
| --- | --- | --- |
| Portraits, decor clocks and radios, the clock-time pool | Moved to `DecorService` and `Data/ClockTimes` | Done, R2c.1 |
| Walkable phantom doors and fake walls (`SeamFlip`) | Deleted: a phantom door is a real hole past a lock, and a way to push a prop through a wall | Done, R2c.1 |
| Verdict, Case Board, the Deliberation Table prompt | Retired. The `deliberation` role and its validator rule stay; the dining room hosts the dinner | Done, R2c.1 |
| Anomalies, tells, evidence, rituals, the Witness Camera, the Plumb Line | Retired. The tell prop builders (Clock, Note, KeyTag, Fusebox) are reused as props and puzzle stations | Done, R2c.1 |
| Witness windows, anchoring, Focus | Retired. **Kept** `ReportView`, `GetView`, `IsLookingAt`, `ClearLine`, pings, callouts, `FakePing`, the two-watcher freeze and the 3 s co-stare (no Focus cost) | Done, R2c.1 |
| Lantern, Radio (static near him) | Keep | |
| Phase names | Keep (Investigation = exploring, Resolution = the dinner); rename later if wanted | |

## 15. The foundation pass (2026-10-06, overnight; builds `2026-10-06.101` to `.108`)

The owner's audit of 2026-10-06 found that fear was gated behind failure (a clean run peaked at Drift 10), that the stare was a free win (two watchers froze him in hunts, the Companion always counted, the dark played no part), that a stalled squad got danger but no help, and that the walks were empty. The overnight pass (`docs/progress/2026-10-06-overnight/REPORT.md`) changed the rules, not the structure:

- **The run in numbers** (`Logic/RunStats`): the act, a tier score, silent minutes, scares by kind, each hunt and how it ended, stare-downs, freezes, downs, catches, time to first progress. F2 overlay and `summary`, the Dossier's THE NIGHT IN NUMBERS, a `RunSummary` event.
- **The stare has a cost** (`Config.Stare`, `Logic/StalkRules.litFor`/`huntHold`): a look counts only while he is in that player's light (the room, their beam within 42 studs and 28°, the clip light, a lit Lantern, arm's length); in a hunt two watchers hold him 4 s at a time (the clock pauses), then he comes on at about a walk while they watch; the co-stare backs him off only between hunts; the Companion no longer counts, and alone a steady full beam does, at three times the battery.
- **Dread** (`Logic/Dread`): the greater of Drift (still the failure clock) and the act's floor (`Config.Pacing.ActDread` 0/40/60/75, eased in over 90 s). His tier, face, the scare deck, the atmosphere rules, the flicker, grade, photos, blood, the drones and the HUD's word read it. A steady run meets tier 2 after its first door and tier 3 at minute 17.5 of 23 (`Pacing.spec`). Hard starts at Dread 20 with shorter telegraphs.
- **Hunts off the clock**: ArmDelay 45–150 s, the gap after a hunt drawn afresh (180 s ± 40%), false alarms (30%, only the telegraph; the real one 30–80 s later), returns (25%, straight back 40–75 s after a survived hunt).
- **The house's own scares** (`Services/HouseEventService`; section 10's list, built): a door ajar, a radio on, his footsteps through the floor where he really is, knocks from inside a wardrobe, the rooms ahead going dark one by one, the telephone (every house has one now), the clock striking thirteen; and an old wing changed when the squad comes back after 150 s. Cards drawn by the Director's deck by act and Dread; every noise a lure he hears too.
- **Stuck-assist** (`Logic/Assist`, `Config.Assist`): 150 s without progress and the objective line says the plan's next step (set the heirloom in hand; the door you hold the opener for; the station in reach; the room in reach where something needed is kept); 240 s and the lights there stutter and the map rings the room.
- **Teaching and words**: `UI/Tips` (one line when the thing first comes up), a three-bullet how-to, the lobby tagline and Hard blurb, HUD phases LOCKED IN / THE HOUSE / THE DINNER / GET OUT, "Nobody got out.", counters without "Witness".
- **Music states** (`Assets.Music`, `Config.Music`): calm / stalking / hunt stems crossfaded, ids empty until the owner chooses by ear. **The quiet catch** (`Config.Guest.Catch = "quiet"`) as an option.

Fairness additions: the stare's light rule is symmetric with his sight (lit 40 studs, dark 15); every house event is a sound or an unseen change, and he hears the noises; the hint never names a token only an optional lock wants; a false alarm obeys every hunt rule (it is a telegraph, nothing more).

## 12. Additions to the fairness contract (DesignDoc section 3)
- **Locks:** every plan is solvable; the area open at the start has a chase loop and hiding spots; a lock is a wall for the Guest; Echoes can't pass locks (a locked door's slab collides with them).
- **Barricades** delay the Guest by at most 8 s when there's room to shove the piece clear; when nothing lets it move he gets past only while nobody can see. Anyone can squeeze past one, so they never trap a player.
- **Scent:** while someone carries an heirloom he learns which room they're in (a declared rule, cued on every pickup: the chair at the table, the candle, the heirloom's music box). It pauses while the carrier hides and is gone 8 s after a drop.
- **Woken hunts** obey every hunt rule (3 minutes, revive, Lantern, retreat, telegraph, start out of sight and 25+ studs away) plus a 180 s gap.
- **Tidying:** only while he and the heirloom are both unseen and nobody is within 20 studs, never in a hunt or the dinner, and only back to where it was found (a puzzle never re-locks).
- **At the table** he's visible to everyone, follows the watch rules, can't reach any place (ContactRadius + 2) and leaves after 120 s.
- **Two-person locks:** a crank door never drops on a body and can always be latched from inside; the dumbwaiter never strands an item; a power door never re-locks.
- **No leaks:** a note's text is sent only on reading; the map shows only what someone has seen.
- **Flips (R3)** happen only where nobody could see, never close a stairwell or a bridge, never skip a lock, and keep every validator rule.
- **Throws** are decided on the server; stuns shrink when repeated.
- **Items can't be lost:** anything that leaves the world or a Lost player's hands returns to where it was found or where its holder fell.
- **The level design** ([`level-design.md`](level-design.md) section 7): every stage of the wings has somewhere to run round and no dead end deeper than 3 rooms; shortcuts open only from the far side; backtrack gates and double locks are always reachable with what the squad has; the house follows the squad's size.

## 13. Risks
1. **Engine unknowns,** each checked in the commit that needs it, each with a fallback flag in Config: does sinking mouse look stop the PlayerModule's camera (else a Scriptable camera)? Does a client-predicted door fight replication (else no prediction)? Is client-owned carrying smooth for others (else the server drives it)?
2. **The Guest's navigation.** Angled doors, locks, barricades and flips all touch it. `navtest fast` on seeds 61, 1800820264 and 7, `navtest retreat` and later `navtest barricade` run after every commit that touches passage.
3. **Exploits.** Client-owned props are validated; drags need reach and a clear line; pushes are aggregated and capped; puzzles count tries, lock out and make noise on the server.
4. **Fairness shrinks with locks.** Fewer loops are open early, so the stage checks matter, and the R2a playtest must say whether chases in region 0 feel fair.
5. **Solo play.** The Companion helps push; the breaker has a wiring diagram; the music box has a visual hint.
6. **Performance.** Props re-anchor once asleep; `BulkMoveTo` runs only while something moves; at most 4 held props are validated per Heartbeat; the R3 validator runs throttled.
7. **Tests and Gate A.** The planner is nested, so the golden and Mansion hashes hold. Gate A was re-baselined with the owner's OK three times on 2026-10-05: drawers and doors (parts 2272, hash 1308511249), the clue loop retiring (2134, 191543809) and walk-in closets (**now parts 2134, hash 1322547804**, `tools/studio/partdump.luau`). Ask again before the next one.
8. **Scope.** R1a, R2a and R2c were about 45 commits; the `Loop` flag kept the game playable until the old loop retired in R2c.1.
9. **Determinism.** The plan and puzzle answers come from the seed; shifts and events depend on players and are logged through Telemetry.
10. **Content and accessibility.** Notes stay within the Moderate rating. Two of the four puzzles are about sound; the visual hints matter.

## 14. New manual tests (now numbered in `TESTING.md`: TC-51 to TC-89)
- A carried prop and a dragged door look the same on two clients; a carried thing never flings its holder.
- A throw stuns him once, briefly; a second throw within a minute is shorter.
- A flush, a thrown bottle or a radio left on draws him to it.
- Two players push a bed together; one alone only creeps it; a dresser moves slowly for one.
- A bed in a doorway holds him for a few seconds of banging in a hunt, then he shoves it clear.
- Hiding in a closet by shutting the doors from inside; he slides them open.
- A key drops where its holder goes down; a teammate can pick it up.
- The radio and the music box are heard by everyone while someone carries them.
- A full escape run with 2–4 players: locks, a puzzle, the dinner, the run to the front door. "Did it ever feel like it cheated?"
