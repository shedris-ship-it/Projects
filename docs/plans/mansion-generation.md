# The mansion: generation design

Status (2026-10-04): **M1 done, M2 mostly done.** Build `2026-10-04.4`: F2 `layout mansion` builds the mansion in Studio; the old house is still the default (`Config.Level.Mode = "Cells"`). Print a house with `lune run tools/plan <seed> mansion`, and see `mansion-examples.md`. M2's results and open items are in section 5. This supersedes the layout parts of [`variable-room-sizes.md`](variable-room-sizes.md). That plan's section 5 (the map of every file that assumes "one room = one 40×40 cell") and section 6 (invariants) still apply, and the builder, navigation and furnishing phases below lean on them.

## 1. The owner's decisions

The owner asked for this on 2026-10-04 ("I want really advanced procedural generation, it all needs to come together in a way that makes sense"). Decisions so far:

| Topic | Decision |
| --- | --- |
| Theme | An **old mansion, still lived in, in 1988**. It keeps every 1988 prop and outfit, and adds grand architecture: staircase, panelling, chandeliers, portraits. P.T. is still the mood reference. |
| Start | Every run starts in the **grand entrance**. The front door shuts behind the squad. |
| Floors | **Two floors.** The grand staircase in the entrance, plus **1–2 stairwells**. |
| Size | **18–24 rooms** in all, counting hallways and stairwells. |
| Room sizes | 20, 30 or 40 studs a side on a 10-stud lattice. **Only the grand entrance is bigger** (about 40×50, double height, with a split staircase up to a balcony gallery). |
| Old house | The old generator (`Logic/LevelGraph`) stays the default (`Config.Level.Mode = "Cells"`) until the owner approves the mansion. |

### Future gameplay the generator must leave room for (owner's notes, not built yet)
- Most objects interactable; small ones physical (pick up, throw, stun the Guest briefly); closets you physically get into and close.
- Procedural puzzles that are fun minigames in their own right (the owner's example: Fallout's terminals), not "find the runes".
- House changes that matter for play (a door becomes a wall and closes a loop) or are unsettling, and **the layout changing only after players are used to it, and only where nobody can see**.
- More variety and unpredictability per run.

How the generator leaves room for this:
- Every pair of rooms that share enough wall has a seam with a valid door spot, open or not. A later system can flip seams for everyone while unobserved, and the pure validator can check the new door set first.
- Rooms carry a `zone` (public, service, private), so puzzles and props have context.
- Seams can carry a future `locked` flag for key and lock puzzles; reachability is plain graph search.
- The furnishing solver (M4) reserves use-space in front of interactive and enterable furniture.

## 2. The house grammar

The house is generated as **architecture first, then rooms**, so it reads like a real building rather than a pile of boxes.

**Frame.**
- Rooms are rectangles on a 10-stud lattice: `{ id, floor, tall, x, z, w, d, template, rotation, zone, role, lantern, mood }`, with x and z the north-west corner in studs from `Config.Level.Origin`.
- Floor 0 is the ground floor and floor 1 the upper floor, `Config.Mansion.FloorPitch` apart.
- The front of the house faces south (+z). Nothing is built south of the front line.

**Tall rooms.**
- The grand hall and the stairwells span both floors as **one graph node**.
- Two tall rooms never touch, so any pair of rooms meets on at most one floor and has at most one seam.
- Every upper room stands on the ground floor's footprint.

**Steps:**
1. **Grand hall** (the start), front-centre.
   - The front door is on the south wall, with a porch kept clear.
   - Ground-floor doors can go on its other three walls; upper doors only where the gallery runs (north, east and west).
2. **Spine.**
   - A **public corridor** leaves the hall on one side and may turn once.
   - An optional **rear corridor** leaves the back.
   - Corridors are 20-wide strips, 30–60 long. Closets and alcoves (M4) narrow the walkway to about 10–14, like the corridors the owner likes, and give enterable hiding spots.
3. **Service wing**, on the hall's other side: **dining room → kitchen → service corridor**, then the **back stairs** and the **exit** (mudroom or garage) at the rear.
   - The dining room is the only ground-floor way into the service wing, which puts the Deliberation Table on the start→exit critical path (doc section 3) because the house is built that way, not by luck.
   - The exit has an outer wall facing away from the front, with a porch kept clear.
4. **Upper skeleton.**
   - The gallery is the hall's upper half.
   - The service corridor is always repeated upstairs (the back stairs serve both floors); other corridors are stacked by chance (`StackChance`, kept low so the house isn't mostly hallway).
   - **The upper floor must be connected on its own.** Two stairs into one connected upper floor always make a **vertical chase loop**: hall → gallery → upper rooms → back stairs → service wing → dining → hall.
   - A **bridge**, one or two straight corridor pieces over the service wing, joins the gallery's side to the back stairs' upper corridor. When no bridge fits, the upper rooms still try to join the two sides, and the validator rejects the attempt if they don't.
5. **Optional second stairwell** (about half the houses) at the end of a public or rear corridor. That corridor is always repeated upstairs, so the stairwell opens on both floors and makes a second vertical loop.
6. **Rooms.**
   - Each floor's programme (ground: public and service rooms; upper: bedrooms, baths, nursery, sewing room and so on) is packed flush against the hall, corridors and placed rooms.
   - Each new room joins by a door to an allowed neighbour (a tree edge).
   - Candidates are every lattice slide along every wall, in both orientations. Scoring (`Config.Mansion.Placement`) rewards:
     - a neighbour that a door would close a 4–8 room loop with (`Loop`, the strongest pull)
     - other neighbours (`Contact`)
     - `near` wishes (pantry by the kitchen and dining room, bath by the bedrooms)
     - opening off a corridor or the hall, especially an empty corridor (`Corridor`, `Fill`)
     - staying compact (`Spread`)
   - It penalises chains of rooms reached through rooms (`Chain`). The pick is weighted among the best few.
   - A bathroom goes at most once per floor.
7. **Doors and loops.**
   - Extra connections come from shared walls, weighted by how much sense the pair makes (public enfilades, the service chain, bedroom↔bath).
   - Each is accepted only if the fairness contract still holds (section 4): the table stays on a shortest path, the exit stays at least `MinExitRooms` doorways from the hall, and the new loop is at least `MinLoopStuds` long.
   - Doors only join allowed zone pairs. Every other shared wall is a solid seam, which a Phantom Architecture doorway can still use.
8. **Finish.**
   - Lantern rooms (never in a stairwell).
   - Window orientation per outer wall stretch, per floor.
   - Not done yet: mood pacing (the old generator avoids three rooms of one mood in a row). Add it as a pass that swaps same-size general templates if runs feel samey.

### Which zones may share a door
The service wing is two zones: the **kitchen** side (kitchen, pantry), which the dining room opens into, and the **service** side behind it (passage, laundry, back stairs, exit). Without the split, a loop door once joined the dining room straight to the garage, and the critical path became hall → dining → exit.

| | hall | public | dining | kitchen | service | private | bath |
| --- | --- | --- | --- | --- | --- | --- | --- |
| hall (gallery upstairs) | | ✓ | ✓ | | | ✓ | |
| public | ✓ | ✓ | ✓ | | | | ✓ |
| dining | ✓ | ✓ | | ✓ | | | |
| kitchen | | | ✓ | ✓ | ✓ | | |
| service | | | | ✓ | ✓ | | |
| private | ✓ | | | | | ✓ | ✓ |
| bath | | ✓ | | | | ✓ | |

Corridors and stairwells take the zone of their wing on each floor (for example, the back stairs are service downstairs and private upstairs).

### Seams
- Two rooms on the same floor are neighbours when they share at least 20 studs of wall and a valid door spot exists. One seam per pair: `{ id = "seam:a-b", a, b, floor, dir, line, along, connected, door }`.
- The door spot is the lattice point nearest the middle of the shared wall, at least 7 studs from either end (door half-width 3 plus lane half-width 4).
- `sockets` restrict which template sides can take a seam on each floor (the hall's front wall; a stairwell's foot and head).
- `maxSeams` caps busy small rooms (a bathroom has at most 2).

## 3. Data
- A template from `Data/Rooms.luau` joins the mansion with a `mansion = { ... }` block. The old generator never reads it, and `tests/golden/LevelGraph.txt` proves the old layouts never change. Fields:
  - `floors`, `zone` (or `{ [0] = ..., [1] = ... }`), `size = { w, d }`, `weight`, `max`
  - `near`, `perFloor`, `maxSeams`, `sockets`, `role`, `tall`
  - `hides`, for generated-size rooms (each corridor promises one enterable closet, built in M4)
- Mansion-only templates (the grand hall, stairwells, corridors) live in `Rooms.MansionExtras`, outside `Rooms.List`, so the old generator and the 40×40 template checks never see them.
- `Config.Mansion` holds every tunable: room count, lattice, floor pitch, minimum shared wall, door corner clearance, porch, minimum loop length in studs, stair length, number of stairwells, corridor lengths and placement weights.

## 4. Validator (`Logic/LayoutValidator`, mansion rules)
The existing graph rules still apply, with room count from `Config.Mansion`:
- connected
- at least 2 independent loops
- girth at least 4 rooms
- at least 2 chase loops of 4–8 rooms
- dead ends at most 2 deep
- hiding spots at least half the room count
- the exit not the start
- the Deliberation Table on a shortest start→exit path
- a Lantern room

New, for mansion layouts only:
- No overlaps on either floor, the porches included. Nothing south of the front line.
- Upper rooms stand on the ground footprint. Tall rooms never touch each other.
- Every seam's door spot is valid. Every shared wall with a valid spot has a seam. `maxSeams` and `sockets` are respected. Doors only join allowed zones.
- The exit is on the ground floor, at least `MinExitRooms` (4) doorways from the hall, with its door on an outer wall facing away from the front and a free porch.
- Each floor is connected on its own (counting tall rooms), and every stairwell opens on both floors, so a vertical loop exists.
- Chase loops are also measured in **studs**: door to door, plus `StairStuds` (30) for each change of floor.
  - A 4–8 room loop counts only if it is at least `MinLoopStuds` (100) long, and at least one loop must be `LongLoopStuds` (200) or more. In practice, the loop between the floors is 200–360 studs.
  - The old plan's 160 for every loop was dropped. Four 40-stud rooms made 160, but four mansion rooms round the hall's corner make 100–140, so nearly every compact loop was refused and houses came out tree-shaped.
  - **Retune after a playtest:** decide whether short loops make chases too easy or too hard.

### What the generator does (1,000 seeds, 2026-10-04)
- 70–75% of houses pass on the first attempt (1.4 on average), with no fallbacks. That takes about 40 ms per house in Lune, generation and validation included.
- Per house: 18–24 rooms, evenly spread; about 7.5 corridors and stairwells and 9.5 general rooms (about 4.3 of them upstairs). Half the houses have a second stairwell.
- `lune run tools/mansionstats [seeds]` prints these numbers. The authored fallback is seed 61, frozen with `lune run tools/plan 61 mansion freeze`.

## 5. Phases

| Phase | What | Where | Gate |
| --- | --- | --- | --- |
| M1 (**done** 2026-10-04) | `Logic/RoomRects`, `Logic/FloorPlan` (ASCII plans, fingerprints), `tools/plan`, the golden guard for the old generator (`tools/golden`, `Golden.spec`), mansion data, `Logic/MansionHouse` and `Logic/MansionGen`, validator rules, `Mansion.spec`, the authored fallback (`Data/MansionFallback`) | pure (Lune) | Example plans read like a house; tests green |
| M2 | Builder: two floors, rectangle rooms, per-segment walls and door gaps, the double-height hall with gallery and grand stair, stairwells (walkable ramps under step visuals), porches, windows on outer stretches; `RoomAt` by floor; `Config.Level.Mode` | Studio | Old mode identical (part dump hash); `plan` matches the house; seams line up (`execute_luau`); no console errors |
| M3 | Navigation and "bare rooms": `Navigator` routes along lanes and up stairs, `RandomPointIn`, peek spots and flank from seams, Companion on stairs, noise damped between floors, the Case File map per floor; F2 `plan`, `layout`, `navtest` | Studio | `navtest` 0 stuck on 3 seeds; hunts work on both floors; 3 clients |
| M4 | Furnishing: `Logic/RoomFurnish` (props anchored to walls, lanes and clear zone kept, essentials checked), every template moved over, mansion art (hall, gallery, stair, panelling, chandeliers, corridor closets), `docs/ART.md` updated | pure, then Studio | Screenshots per room; `clip`; hiding spots enterable |
| M5 | Retune lights, dust and stalker distances; docs; with the owner's approval `Mode = "Mansion"` | Studio | Full squad run; fps no worse; "did it ever feel like it cheated?" |

### M2 as built (2026-10-04)
- **Code:**
  - `World/MansionBuilder` builds rooms as rectangles over two floors, each wall broken per storey for its doorways.
  - The hall gets a gallery, railings, a carpeted central staircase and sconces; stairwells are dog-legs with a sconce on the half landing.
  - The front door is locked; the exit is built; corridors get a runner and more lights the longer they are.
  - Stairs are invisible wedge ramps under steps you can't collide with.
- **Furniture:** `Logic/RoomFit` fits each template's 40x40 furniture to its room and doorways (stopgap until M4). Chairs follow their table, and decor keeps off furniture.
- **The rest of the game:**
  - `WorldService` does `RoomAt` per floor, doorway and approach points from seams, walkable points, and the per-floor snapshot.
  - The client finds rooms by rectangle and floor, and the Case File map draws both floors.
  - The Guest ducks at seam panels.
  - `AnomalyService` reads `seamList`, and peek spots come from the seams.
- **Checked in Studio (one client):**
  - Seeds 61, 1800820264 and 7 build in 0.07-0.12 s with clean consoles, and their layout hashes match Lune.
  - Top-down views of seed 61 match the printed plan on both floors.
  - Every seam's two wall layers agree to 0.000 studs on all three seeds.
  - `clip` shows no overlaps on 1800820264 (seed 61's three, from the first fit, were fixed in RoomFit).
  - A character walked from the spawn up the grand stair, round to a stairwell, down both flights, across the house and up the back stairs to the bridge. Studio's pathfinding finds routes between rooms but not through closed doors; I opened one locally.
  - The Guest arrived and caught me on the ground floor.
  - Gate A still passes: the old house is parts 2151, hash 1550694282.
- **Not checked yet:**
  - the Case File map (Tab can't be sent through Studio's input tool)
  - multiple clients
  - the Guest and the Companion crossing between floors: `Navigator` still walks straight lines between doorway points, with no stair waypoints (M3)
  - noise between floors
  - the frame rate on a real machine
- **Known look issues for M4/M5:**
  - Some rooms (the dining room) are dim.
  - Corridors are 20 wide with no closets yet.
  - Corridor hiding spots are counted by the validator but not built.
  - Furniture is the old 40x40 sets squeezed or stretched; the hall's own furniture is sparse.

### M2 Gate A baseline (taken 2026-10-04)
Build `2026-10-04.3`, old mode, F2 `seed 1800820264` then `start`: 15 rooms on the first attempt, matching `lune run tools/plan 1800820264`. Running `tools/studio/partdump.luau` through `execute_luau` (Server) gave **parts 2151, hash 1550694282** on two fresh runs. After the builder is rewritten for rectangles, the old mode must give the same two numbers. If it doesn't, change the script to return the differing lines.

## 6. Risks
- **Stairs are new for everything that moves.** The Guest and the Companion use `Humanoid` movement, so walkable ramps are the safe base. `Navigator` needs waypoints with height. Noise and sight across floors need rules.
- **Bigger house, same squad.** 18–24 rooms spread 2–4 players thinner. The stalker's distances and the Director need a review once it's playable.
- **The slice hasn't passed Gate 2** (fun with friends), and the owner is planning a gameplay rework. The generator is kept independent of the current anomaly and evidence systems so it survives that rework.
