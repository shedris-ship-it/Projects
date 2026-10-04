# Variable room sizes: plan for a local Studio session

Status: **planned, not started** (2026-10-04). Written in a cloud session with no Studio; no game code for this project exists yet. The work is meant for a **local session with Studio and its MCP tools**, because most of the risk is in things only Studio shows: walls lining up, the Guest getting through doors, lights in small rooms.

File and line references are as of commit `f41127b` (branch `claude/ecstatic-noether-7skntv`) and may drift by about 20 lines.

## 1. Goal and the owner's decisions

The owner (2026-10-04): "some of the rooms feel far too large, like the bathroom... the corridor we have is great... could we have variable room sizes and still make it all come together in the procedural gen?"

Decisions made:
- **Finer grid with true sizes**, not insetting small rooms inside a 40-stud cell. (I recommended insetting, because it is much smaller; the owner chose the bigger option.)
- **Every room that needs it**, not just a pilot.
- I changed one detail: a **10-stud lattice**, not 20. With 20-stud steps the only sizes are 20 and 40. On a 10-stud lattice rooms can be 20, 30 or 40 on a side. If the owner prefers only 20 and 40, that is a data change (the template `size` fields), not a code change.
- Keep the old generator as the default until the new one is approved (`Config.Level.Mode`).

Why the rooms feel big (from `docs/ART.md`, "Scale"): 1 stud is about 0.32 m, so a 40-stud room is about 12.7 m square against a real 4 to 5 m. Roblox spaces are normally built about 1.5× real size; ours are 2.5 to 3×. The corridors the owner likes are 14 studs wide (the nearest wall is about 7 studs from you). `ART.md` records "the 40-stud grid itself stays"; this project reverses that decision, so update that line in P5.

## 2. Design

1. **Rooms are rectangles.** `{id, x, z, w, d}` in studs, with x, z, w, d multiples of 10 and w, d from 20 to 40. A pure `Logic/RoomRects` does overlap, shared-wall and "which room is at this point" maths.
2. **Seams.**
   - Two rooms are adjacent when they share at least 20 studs of wall. Shorter contacts are plain wall.
   - One seam per adjacent pair (door or no door), exactly as today, so divergence, phantom doors and Phantom Architecture keep working.
   - The door sits on a 10-stud lattice position along the shared wall, nearest the middle, at least 7 studs from either corner. A 40-wall's middle (20) is on the lattice, so the old 40×40 grid is just a special case.
   - A room side can have more than one seam now, so `sides[dir].seam` becomes a list.
3. **Lanes and the clear zone** (the fairness contract, generalised).
   - Each seam keeps an 8-wide lane clear (`Config.Level.LaneHalfWidth = 4`), straight in from the door.
   - The clear zone is the room inset by the band depth. It is never furnished.
   - Any two doors are joined by lane, then a straight line inside the zone, then lane. The zone is a rectangle, so that route is always walkable and no navmesh is needed. For a 40×40 room this is exactly today's rule.
4. **Furniture fits its room.**
   - Templates stop hard-coding absolute positions. Each prop says which wall it is on and roughly where, and is marked essential (hiding spots, shrine, Deliberation Table) or optional.
   - A pure `Logic/RoomFurnish` slides props along their wall to avoid lanes and neighbours, drops optional props that don't fit, and rejects a room whose essential props don't fit.
   - The existing authored coordinates are tried first, so hand-tuned layouts survive where they still fit.
   - New template fields: `size = {w, d}`, `minSize`, `maxSeams` (a bathroom takes at most 2), `sockets = "any" | "center"` (the corridor templates need `"center"` so their arms still line up), and per prop `wall`, `along`, `essential`.
5. **Generator** `Logic/LevelModules` (new; `Logic/LevelGraph` stays untouched for the old mode).
   - Pick the templates with the same role pools, mood pacing and `max` limits, then place rectangles one at a time, flush against what is already placed. Score candidates for compactness and for extra adjacencies, so loops form.
   - Reuse `Logic/Graph` (geometry-free) and the loop-adding and role-assignment logic.
   - Window orientation is per wall segment; a template may be rotated 0, 90, 180 or 270 degrees, and 90 and 270 swap w and d.
   - New randomness goes in its own `Rng` forks, so old seeds never change.
6. **Validator** `Logic/LayoutValidator`.
   - Keep every current rule (see section 5).
   - Loop length is also measured in **studs**, not just rooms. Small rooms make a four-room loop much shorter, so chases would be too easy to lose. Suggested floor: about 160 studs of path, which is what four 40-stud rooms give today.
   - New rules: no overlaps, every seam has a free lattice position on shared wall, the exit has a free porch (14×12) outside it, and every template's essential props fit its room.
7. **Navigation.**
   - The Guest's route per room becomes: approach point, lane end, lane end, approach point (straight between lane ends inside the clear zone). Today `Navigator` goes door to door in a diagonal, which only works because 40×40 rooms are open.
   - `RandomPointIn`, peek spots and the "flank" move use the clear zone and the seam records, not the room centre and the centre-to-centre midpoint.
8. **Lighting, dust and clearances** scale with room size (lamp, window and bounce ranges are tuned for 40-stud rooms; dust layers and grime clearances too).
9. **Old mode stays.** `Config.Level.Mode = "Cells"` (today) or `"Rects"`, and a debug `layout cells|rects|bare`. The builder is written for rectangles; the old mode is the special case with every room 40×40.

## 3. Target room sizes (starting point; one line each in `Data/Rooms.luau`)

Furniture is already about 1.5× real size, so shorten a few over-scale props where a room is tight (the 8-long tub, the 12-long counter).

| Template | Today | Target (w×d) | Constraint / note |
| --- | --- | --- | --- |
| hallway, hallway_runner, attic_landing | 40, plus-shaped, 14 wide | unchanged | `sockets = "center"`; the owner likes these |
| foyer (start) | 40×40 | 30×30 | Case Board is 9 wide and needs a wall of about 27; four spawns plus the Companion |
| living_room | 40×40 | 40×30 | sofa 9, TV, shelf 8 |
| dining_room (Deliberation) | 40×40 | 40×30 | table 6×12; the squad stands round it |
| kitchen | 40×40 | 30×20 | shorten the 12-long counter to about 8 |
| den, playroom | 40×40 | 30×20 | |
| master_bedroom | 40×40 | 30×30 | bed 7×10 |
| kids_bedroom | 40×40 | 30×30 | 2 hiding spots |
| guest_room | 40×40 | 20×30 | bed 7×10 |
| study, music_room, sewing_room | 40×40 | 30×20 | |
| sunroom | 40×40 | 30×30 | three windows |
| bathroom | 40×40 | 30×20 | `maxSeams = 2`; tub 8 long (or shorten to 6) |
| nursery | 40×40 | 20×20 | |
| pantry | 40×40 | 20×20 | shelves shortened from 8 to 6 |
| laundry | 40×40 | 20×30 | 2 hiding spots; shelf shortened |
| mudroom (exit role) | 40×40 | 20×30 | 2 hiding spots |
| garage (exit role) | 40×40 | 40×40, kept big | car is 7×14 and needs a 37-stud wall; squad gathers here |

Lower bounds that set these (from `docs/DesignDoc.md` and the code):
1. Doorway lanes (8 wide) and a clear zone. This is the real floor on room size. A wall of length L gives a prop only L/2 minus 4 along it when there is a door in the middle.
2. A wall at least about 19 long (peek hide points sit 8.2 either side of a door; a 6-wide window needs about 18.5).
3. At least 3 wall slots and 3 floor slots per room (`Rooms.spec` enforces it).
4. Narrow side at least about 16, so two players can hold a stare-down at 8 or more studs and still avoid the 5-stud close-contact lunge.
5. Total hiding spots at least `ceil(rooms/2)`. The templates have 25 across 22, about 2× slack.
6. The hard cases: garage wall about 37, dining wall about 33 as dressed.

## 4. Phases (Studio work comes before the template rewrite)

| Phase | What | Where | Studio gate |
| --- | --- | --- | --- |
| P0 | `Logic/RoomRects`; an ASCII floor-plan tool `lune run tools/plan <seed>`; a **golden test** that the old generator's output (rooms, templates, rotations, seams, doors) for 1,000 seeds never changes | pure | none |
| P1 | `Logic/LevelModules` and the new validator rules; property tests over thousands of seeds (no overlap, connected, loops met, exit and porch free); read ASCII plans of many seeds and tune placement scoring | pure | none |
| **P2** | **Rectangle builder and world, templates untouched.** `LevelBuilder`, `Trim`, `Grime` and `WorldService` take per-room rectangles and per-wall segments; seams as lists; exit and porch; windows only on free wall segments; `RoomAt` from the lattice; `Config.Level.Mode` | Studio | **Gate A** |
| **P3** | **Navigation, client and "bare rooms".** `Navigator` lane and zone routes, `RandomPointIn`, peek spots from seams, `Tactician`, arrival; client `RoomAt`, Case File map, the Guest's door stoop; lamp, window and dust scaling hooks. A **bare-room mode** builds `Rects` rooms with walls, floors, doors, windows and lights but no furniture, with generic tell slots (a small `Logic/GenericSlots`: floor slots in the zone, wall slots on free wall segments) and the hiding-spot rule off. New F2 commands: `plan`, `layout cells\|rects\|bare`, `navtest` | Studio | **Gate B** |
| P4 | `Logic/RoomFurnish` and every template moved to wall-anchored props with a minimum size, in batches (small rooms first); `Rooms.spec` becomes property tests (for each template at its size, with random seam sets: essentials placed, lanes and zone clear, nothing overlaps) | pure, then Studio | **Gate C**, one per batch |
| P5 | All templates at their sizes; lamp, window, dust and noise retune; stalker distances reviewed; docs updated (`ART.md`, `DesignDoc` §3, `ARCHITECTURE.md`, `TESTING.md`, `CLAUDE.md`); with the owner's approval `Mode = "Rects"` becomes the default | Studio | **Gate D** |

Why P2 and P3 come before P4: they prove the hard parts (walls lining up, the Guest getting through, lights and windows in small rooms) on real houses without first rewriting about 20 templates. The bare-room mode makes that possible.

**Gate A** (the old mode is unchanged):
- `layout cells`, `seed 1800820264`, `start`: same room count, templates and rotations as before.
- Screenshots from the `docs/baseline/2026-10-02` spots match (foyer, kitchen, living room, corridors).
- `clip` is no worse than before; the console is clean; the hub build id matches `src/shared/Build.luau`.

**Gate B** (a bare `rects` house works), for at least 5 seeds:
- No console errors; `plan` (ASCII map in the Output window) matches what you see in the house.
- Walk every doorway, real and phantom. Walls, trim and skins meet at every seam. Check with `execute_luau`: for each seam, the door-gap edges of the two rooms' walls agree to within 0.05 studs.
- Windows face outside only; the exit door and porch don't touch another room (`clip`).
- `navtest` reports **0 stuck** over every room pair, on 3 seeds.
- Hunts work in small rooms (he arrives, chases, loses you; no frozen Guest).
- Lamps and dust don't flood small rooms; 3 clients work.

**Gate C**, per batch of templates: screenshots of each room from its doorways; `clip` under about 0.3 studs; hiding spots enterable; tell slots reachable; `navtest` still 0 stuck; the property tests green.

**Gate D**: a full run (4 clients if possible); frame rate no worse than before (F2 overlay); the owner says the rooms feel right.

## 5. Map of what assumes "one room = one 40×40 cell"

### Generation and data (`src/shared`)
- `Logic/LevelGraph.luau`:
  - Room records are `{id, gx, gz}` (`:44`, `:72`); `cells["gx,gz"] = id` (`:73`); edges are id pairs.
  - Cell-bound: `growBlob` (`:43`, one 4-neighbour cell at a time), `adjacentPairs` (`:81`, E and S neighbours only), `isOuterSide`/`hasOuterSide` (`:182-196`), `worldSide` and rotation (`:201`, square footprint), `orientWindows` (`:223`, whole sides), `finish` (`:403`, one seam per adjacent pair at `:419`, `door = connected and rng:Chance(DoorChance 0.65)`), `fallback` (`:455`, a hard-coded 4×3 grid of 12 cells with 14 edges).
  - Reusable: role selection (`assignRoles` `:246`), template picking (`assignTemplates` `:310`, apart from its `hasOuterSide` call), `addLoops` logic (`:111`, apart from its candidate source), mood pacing.
  - Generation: up to 10 attempts, `Rng.new(seed + attempt*7919)` (`:499`).
- `Logic/Graph.luau`: entirely geometry-free (BFS, girth, `deadEndDepths`, `fundamentalCycles`, `weightedPath`). Reuse as is.
- `Logic/LayoutValidator.luau` rules: room count 10 to 16 (`:50-54`); all reachable (`:58`); at least 2 independent loops (`:63-67`); girth at least 4 (`:68-72`); at least 2 fundamental cycles of length 4 to 8 (`:73-84`); no room more than 2 from a loop (`:86-90`); hiding spots at least `ceil(rooms/2)` (`:93-97`); every room has a template (`:100-104`); exit exists, is not the start and has an outside wall (`:105-123`, the only cell-aware rule, with its own `cellKey` at `:9` and `:115` because `LevelGraph` requires the validator); deliberation exists and is on the start to exit path (`:124-133`); at least 1 lantern room (`:134-136`). Nothing validates geometry today.
- `Logic/Corridor.luau`: `armOf` (`:19`), `armOfWall` (`:31`), `filledArms` (`:40-75`, goes through `isOuterSide`). This is the existing precedent for a walkable shape smaller than the cell.
- `Data/Rooms.luau`: 22 templates, all authored in absolute coordinates in a local 40×40 frame (x east, z south, origin at the floor centre; furniture edges reach ±19.5 on at least two walls). Fields: `id, name, mood, family, weight, max (default 1; hallway 3, hallway_runner 2), roles, floor, wall, wainscot, reverb, light, props[{id,kind,x,z,ry,key,deliberation}], decor[{id,kind,y,key} + side/along or x/z/face], wallSlots, floorSlots, shrine (required on every template), spawns, caseBoard, corridor{halfWidth}`. General (role-free) templates total 21 max-copies for at most 13 general rooms, so the pool is barely larger than a house: do not split it by size class.
- `Config.Level` (`Config.luau:128-147`): `CellSize 40, WallHeight 10, WallThickness 0.5, DoorWidth 6, DoorHeight 8, Origin, LobbyOrigin {0,0,1400}, RoomCount {10,16}, ExtraEdges {2,3}, MaxExtraEdges 4, LoopLength {4,8}, MinLoops 2, MaxDeadEndChain 2, LanternRooms {1,2}, MaxAttempts 10, DoorChance 0.65, LaneHalfWidth 4, BandDepth 8`. `LaneHalfWidth` and `BandDepth` are read only by specs and a comment; at run time the same knowledge is duplicated as `Navigator.BAND = 10.5` and `WorldService.RandomPointIn`'s ±9.

### Specs that encode the geometry (`tests/specs`)
- `Rooms.spec.luau`: `half = CellSize/2 - WallThickness` (19.5), `lane`, `inner = half - BandDepth + 0.5` (`:6-8`); the eight band rectangles (`:11-20`) and corridor strips (`:24-35`); furniture inside the bands (`:94`), no overlaps (`:123`), shrine in the band (`:146`), wall slots and decor clear of doorways (`:159`), corridor checks (`:196`, `:263`), general-room supply of 13 (`:331-348`). Specs that read no geometry survive any size change.
- `LevelGraph.spec.luau`: determinism on gx, gz, template, rotation only; 1,000 seeds with at most 5 fallbacks; one seam per neighbouring pair; `worldSide` must match `CFrame.Angles` (`:107`); at least 75% of windows face outside, at most 20% of window-lit rooms lose theirs (`:123`).
- `Corridor.spec.luau`, `Stalk.spec.luau:191-213` (peek spots), `Guest.spec.luau:77-82` (`GuestPose.stoop(..., 40, 3)`).

### Builder and world (`src/server`)
- `World/LevelBuilder.luau`:
  - `:30-36` `CELL`, `HALF`, `INNER` (19.5), `HEIGHT`, `DOOR_W`, `DOOR_H`; `:46-59` `SIDE_LOCAL`; `:66-68` `cellCenter`; `:70-88` `wallCFrame`/`slotCFrame`.
  - `:104-131` `buildWall` (a wall is one cell long, the door gap at its middle, plus `Lintel` and `SeamPanel`).
  - `:344-345` `center`, `roomCF` (rotation 0..3 times 90 degrees); `:362-381` `Floor` and `Ceiling` are `CELL`×`CELL`; `:407-412` one `buildWall` per world side.
  - `:420-466` corridor closets; `:483-530` prefabs (`clone:PivotTo(roomCF)`); `:532-586` props; `:587-629` decor; `:633-675` key light (the ceiling fixture is at the cell centre) and bounce; `:679-698` wall and floor slots; `:702-707` spawns and Case Board; `:752-778` shrine.
  - Exit (about `:779-893`): `doorPos = center + dir*HALF`, `face = center + dir*INNER`, porch at `center + dir*(HALF+6)` sized 14×12, `ExitZone` 8×8×8.
  - Seams (about `:899-948`): direction from the centre delta; `midpoint = (A.center + B.center)/2`; faces `center ± dir*INNER`; door slab `DOOR_W-0.2` wide; the door model is parented to `roomA.model`.
  - Grime and Dressing run last (`:1009-1010`).
- `World/Trim.luau`: `:28-30` `HALF`/`INNER`; `:171-195` room faces (`reach = INNER`); `:222-239` corridor closets; `:349-359` seam skins span `-INNER..INNER`.
- `World/Grime.luau`: `:24-25` `INNER`; `:58-62` `onWall`; `:87` wall span; `:115-127` corridors get ceiling stains only; `Config.Grime.SeamClearance = 8`, `SlotClearance = 4`.
- `World/Dressing.luau`, `World/ToolPickups.luau`, `Shared/World/PropFactory.luau`: prop-relative, not affected. `World/ClipScan.luau:91` only treats `Part`s named `"Wall"` as walls, so name new wall pieces `Wall` or extend it.
- `Services/WorldService.luau`: `:17` `CELL`; `:100-123` `LayoutSnapshot` (rooms with gx, gz; doorways are left out on purpose); `:139-151` `RoomAt` (`floor((pos - origin)/CELL + 0.5)`; purely cell-based, so a void point counts as a room); `:172-177` `SeamBetween` (key `"seam:a-b"`); `:180-183` `DoorwayPoint` (centre midpoint); `:186-190` `ApproachPoint` (`center + dir*(CELL/2 - inset)`); `:192-215` `IsLit`/`SetRoomLight`; `:227-261` slot pops (geometry-free); `:277-294` `RandomPointIn` (±9, or the corridor branch).
- Seam consumers (all expect one seam per room pair and a seam on a walkable floor both sides): `WitnessService:56-62`, `DivergenceService:93-96`, `PerceptionPlanner:173-207`, `AnomalyService:163-185` (`room.sides[dir].seam`, single), `Rituals/PhantomArchitecture.prepare` (`:26-61`), client `PerceptionController` (`:73`, `:163-217`, by the `SeamId` attribute; size-agnostic). **A flippable seam over solid floor would send a player into a wall.**
- `Services/DoorService.luau:98-116`: the open slab swings 100 degrees about the jamb hinge (`LevelBuilder` about `:985`) and needs about 6 studs of depth and a half-width of at least 4 beside the doorway. Collision is off when open, so it is cosmetic.

### Stalker (`src/server/Stalker`, `Services/StalkerService.luau`)
- `Navigator.luau`: `:12-13` `ARRIVE = 2.2`, `BAND = 10.5`; `:42-46` `inBand`; `:112-128` the route per hop is `ApproachPoint(a,b,3.5)`, `DoorwayPoint`, `ApproachPoint(b,a,3.5)`, then straight to the next approach point (a diagonal across the room). No navmesh; stuck nudge at `:197-217`.
- `Stalk.luau`: `:268-306` `_peekSpots` (uses the centre-to-centre midpoint; spots are filtered by `Body:Fits`, so ones inside solid are dropped silently); `:393-407` `_farPoint` (wants at least 30); `:499-516` `DoorwayStand`; `:169-176` `_estimate`; `:672-691` `Search`.
- `PeekSpots.luau:18-50`: pure, doorway-relative, lateral 4.6, hide lateral 8.2 (`Config.luau:470-474`); a wall beside a doorway needs more than about 9.
- `Tactician.luau`: `roomCenter` at `:239, :249, :268, :281, :319`; approach insets 6, 5, 4, 4, 2.5; `FlankBlindSpot` (`:287-294`) only checks `RoomAt(behind) ~= nil`, so it must use `Fits`.
- `StalkerService.luau`: `:512-533` back-away goals; `:780-806` arrival (`exit.door.Position + inward*5`, `room.center`, `RandomPointIn`, with `Fits` and `_spotSeen`); `:828-841` `_forceArrive`.
- Fine as is: `Body.Fits` (box overlap, `:297-321`), `Sight`, `StalkRules`, `SightMath`, `BeliefMap`, `Perception`.
- `CompanionService.luau:222, :245`: straight `Humanoid:MoveTo` with no pathing; it may stick on a dog-leg and self-heals by teleporting past 40 studs.

### Client (`src/client`)
- `Controllers/StateController.luau:139-153` `RoomAt` (grid arithmetic from the snapshot's `cell` and `origin`); `UI/CaseFile.luau:219-250` (one square per gx, gz).
- `Controllers/EffectsController.luau:196-262` `addDust` reads the room's `Floor` part size (`:210`, `:226-233`): one floor part sized to the walkable room works, several would not.
- `Controllers/GuestController.luau:237-239`: `GuestPose.stoop(x, z, CellSize, DoorWidth/2)` ducks at every cell-boundary midpoint, wall or doorway, which keeps it free of tells; doorways are deliberately absent from the snapshot. Rects need an equivalent from shared-wall midpoints.
- `Controllers/AudioController.luau:177-191` (reverb by room name), `PerceptionController`, `FootstepController`, `GuestReflection`: fine.

### Numbers tuned for 40-stud rooms (retune in P5)
- Distances: `IsolationDistance 25`, `Tier1MinDistance 25`, `HuntStartMinDistance 25`, `TeammateRadius 10`, `DeliberationRange 14` (unused), `PeekMinDistance {25,12,8}`, `StareBackAwayRange 16`, `ContactRadius 5`, `LungeRadius 6`.
- Light and dust: lamp, window and screen ranges 44, 40, 40; bounce 34; ceiling light `min(template range × 1.5, 40)`; `DustLayers` half-widths 4, 8, 13, 19; `ShadowRadius` 62 on and 74 off.
- Movement: walk 8, sprint 19; stamina gives about 6.25 s of sprint, about 119 studs, which is about 3 cells at a 40-stud pitch. A loop of small rooms is runnable in one breath.

## 6. Invariants to preserve

1. A seam is one 6×8 opening at a known world position, with both rooms' wall layers, trim and skins aligned.
2. Every adjacent pair is a seam, flippable, with walkable floor both sides.
3. Door lanes and the clear zone are clear of furniture.
4. `RoomAt` is correct, and a void point never counts as a room.
5. Windows only on outer walls; wall slots and decor avoid doorways.
6. Hiding spots at least `ceil(rooms/2)`.
7. Rotation: the builder's `CFrame.Angles` and `LevelGraph.worldSide` agree.
8. **Determinism.** A new draw in an existing attempt stream reshuffles every seed (the debug seed `1800820264` and the baseline screenshots would change). Put new randomness in `rng:Fork(...)`; iterate sorted lists, never the string-keyed `cells` map; the golden test in P0 and the determinism spec should cover doors, seams and sizes.

## 7. Local-session playbook

**Setup**
1. `git fetch origin`, `git checkout claude/ecstatic-noether-7skntv`, `git pull`. Check `git log -1`.
2. `rokit install` (rojo, lune, selene, stylua). Run `stylua src tests`, `lune run tests/run`, `lune run tests/compile`, `selene src tests`, `rojo build default.project.json -o Consensus.rbxlx`; all must pass (185 tests at `f41127b`).
3. `bash tools/serve-mirror.sh` in the background; click **Connect** (or **Okay → Connect**) in Studio's Rojo panel and **accept every change**.
4. Confirm the hub panel's `build ...` matches `src/shared/Build.luau`, and that `list_roblox_studios` sees Studio.

**At each gate**
- `start_stop_play`, then `get_console_output` (fix every red error).
- F2: `seed 1800820264`, `layout cells|rects|bare` (once P3 exists), `start`, then `plan`, `navtest`, `clip`.
- A fixed set of `screen_capture` shots (wait about 6 s after moving the camera, or lighting comes out black), taken from the same spots each time.
- `execute_luau` to read numbers (seam wall edges, floor sizes, overlaps) rather than judging by eye.
- Multi-client checks need the owner (**Test → Clients and Servers**); the MCP drives one Studio session.

**Keeping usage down**
- Read section 5 before opening any file; do not re-explore.
- Build and test pure logic with Lune first (P0, P1, the first half of P4); that needs no Studio.
- One focused capture set per gate; use `execute_luau` for measurements.
- Commit and push at the end of each phase, and bump `Build.id` whenever the owner would see a difference.

## 8. Risks

- **The builder and the stalker are only tested in Studio.** Expect at least one fix-up round at each gate. `navtest`, `plan`, `clip` and the Gate A parity check exist to catch problems early.
- **A 20×20 room with four seams has little floor.** `maxSeams` per template and the generator rejecting bad placements handle it, at some cost to layout variety.
- **Loops are shorter in studs.** The studs-based loop rule keeps chases fair, but the stalker numbers may need tuning after a small-room house has been played.
- **It is the biggest change in the project.** The slice has not passed Gate 2 (fun with friends) and `CLAUDE.md` warns against building on an unproven core. Play a squad session on the current build between gates if possible.

## 9. Not in this project

Random size variation inside one template per seed, rooms larger than 40, relaxing the four-lane rule for tiny rooms, usable closets in leftover space, and any change to the corridors.
