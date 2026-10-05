# The house as a designed level

Status (2026-10-05): **L0 and L1 done** (builds `2026-10-05.25` to `.30`; section 9, "L1 as built"). The adventure now decides where the doors, wings and shortcuts go; the house follows the squad's size; every room's reason is counted and filled; and each run is the best of 12 candidate houses. **L2 under way** (section 10): the owner chose to go on to L2 before the squad playtest ("continue with L2", 2026-10-05). The playtest follows L2, then L3–L4. This builds on [`mansion-generation.md`](mansion-generation.md) (the house grammar, M1–M3) and [`gameplay-rework.md`](gameplay-rework.md) (the escape: locks, keys, puzzles, the dinner). Where they disagree about level design, this document wins.

## 1. Why

The owner asked on 2026-10-05: "I want to improve the level design and gameplay loop more and have a super sophisticated procedural level design." Measured over 100 mansions from the generator as it stood (`Logic/MansionGen`, `Logic/LockPlanner`, build `2026-10-05.24`):

| Problem | What was measured |
| --- | --- |
| The same skeleton every run | The hall at the front and the dining room beside it in 100 of 100 houses, then the kitchen, the service passage, the back stairs and the garage. Only the side of the service wing changes (49 / 51). |
| Locks laid on after the house, so they fall unevenly | Region 0 (open from the start) is a median 57% of the house (target 25–38%, the range 28–79%). 25 of 249 later regions are one room. 41 of 245 heirlooms lie in a hallway. A backtrack 0.18 times a run. The planner needs 8 attempts a house, mostly rejected for dead ends. |
| Rooms are boxes | Squares of 20, 30 or 40 studs with the old 40×40 furniture sets stretched (`Logic/RoomFit`); corridors 20 wide. |
| Nothing in the layout serves the horror or the talking | No landmarks to call out, no designed sightlines, no foreshadowing. |
| No story in the space | The notes are "Mom" and "Dad" templates; no room belongs to anyone. |

## 2. The owner's decisions (2026-10-05)

| Topic | Decision |
| --- | --- |
| What to build | All six parts (section 3). |
| New spaces | All four: a **cellar**, an **attic**, **servants' passages** with hidden doors, a **laundry chute**. |
| House size | **Follows the squad**: smaller for 1–2 players, bigger for 4, so each player covers about the same ground. |
| Playtest | **After parts 1 and 5** (phase L1), before the builder work. |
| Rooms | "Make sure each room has a purpose ideally, a reason for going there or being there, even if that reason is as simple as a landmark, but it has to be in such a way that the gameplay forms together cohesively, maybe different rooms could give you different gameplay options too, potentially, whatever you recommend." Section 4. |

## 3. The six parts

1. **Plan the adventure first, then build the house around it.** The approach of *Unexplored*'s cyclic generation, fitted to a house: the plan picks the run's beats (a loop to run in every wing, the long way in and a bolted shortcut home, a key on the far side of a loop from its door, a gate you must go back through an old wing to reach, two wings open at once so a squad splits up) and the house's doors, wings and items are laid to make each one happen.
2. **Real house plans and new kinds of space.** House types from real mansions (centre hall, L, U round a courtyard, H with two wings, a tower stair); wings with a character (the family's, the servants', the guests', the public rooms); a cellar, an attic, servants' passages and hidden doors, a laundry chute; rooms beyond squares (L-shapes by wide archways, alcoves, bay windows); narrow corridors lined with closets.
3. **A family who lived here.** Each run makes the family: names, who was who, whose rooms and whose heirlooms. Every note is written by one person in their own voice and only hints; photos on the walls; a child's drawings that point at hiding places. Finding things becomes detective work.
4. **Furniture laid out for play** (the mansion plan's M4). Furniture in natural groups; cover to break his line of sight; hiding spots spread so no room is a trap; long sightlines for dread; landmarks at junctions, so a squad can say "meet at the clock".
5. **Pick the best house, not the first that works.** Many candidate houses a run, each walked through by a simulated squad and measured (the walk to the front door, the backtracking and what shortcuts save, a loop at every stage, how far hiding spots are), and the one nearest the targets is played.
6. **The house fights back** (the rework's R3). Doors become walls where nobody sees, chosen by part 5's simulator so the house keeps its loops; he uses the servants' passages (you hear him in the walls); he has a room of his own; once a run, a corridor that loops.

## 4. Every room has a reason

The owner's rule: every room is worth going into, or being in, and the reasons work together. A room's reasons come in three tiers (`Logic/RoomPurpose`):

- **Strong:** something the run needs is there (a key, a note, a lead, a puzzle station, an heirloom), a Lantern shrine, a landmark, a tool.
- **Survival:** a hiding spot, a lure to send him the wrong way, heavy furniture to barricade a doorway with.
- **Route:** a corridor or a stair, or a room on a loop you can run round.

Every room that isn't a corridor or a stair has a strong or a survival reason, and every wing has a hiding spot, a lure and a landmark or a Lantern. Where a room has no strong reason of its own, the planner keeps a key, a lead or an heirloom there first.

L1 counts only what the house has today. L3 gives rooms their own options, each through a system that already exists (lures, noise, the map, hiding, throwing), so they fit together rather than piling up:

| Room | Its reason, or the option it gives (L3 unless it exists) |
| --- | --- |
| Grand hall | The start and the front door; the gallery to look down from; landmark: the grandfather clock (exists) |
| Dining room | The table: its place cards show what's still missing (exists) |
| Kitchen | Pots and plates to throw (loud); the **kettle**, a lure that whistles 20 s after you set it; the dumbwaiter (exists) |
| Pantry | A tight hiding spot; jars to throw |
| Laundry | The **washing machine**: a long rumbling lure that also hides your footsteps nearby; the chute's bottom |
| Service passage | The **servants' bell board**: a bell drops when something moves through a room with a bell pull. It tells you where he is, if someone's there to read it and call it out |
| Garage, mudroom | The **car horn**: one huge lure a run; the crowbar (board gates) |
| Living room, den | TV static (exists); the **record player**, a lure that plays a side for 40 s; heavy sofas to barricade with (exists) |
| Study | The **house plans**: this floor appears on the map; the computer (exists); the safe (exists) |
| Library (new) | A **bookcase door** into the servants' passages; notes |
| Music room | The piano (exists: a lure and the music box's tune) |
| Sunroom | Moonlit glass: he's seen coming, and so are you |
| Bathroom | The mirror (see behind you, exists); the flush (exists); a door that **locks from inside** and holds him a few seconds, once a hunt |
| Master bedroom | The walk-in closet (exists); the family's diary (the story) |
| Nursery | The **baby monitor**: leave the transmitter in a room, hear that room on the receiver |
| Kids' bedroom, playroom | Crayon drawings that point at hiding places (leads); **wind-up toys**, a lure that walks |
| Sewing room | The dress form, which he stops to look at |
| Guest room | His own room (L4): optional, risky, and what's in it helps at the dinner |
| Cellar | The boiler room's roar hides you; the breaker panel; the wine cellar's bottles to throw |
| Attic | The family's old things (heirlooms, the story); creaking boards (louder footsteps) |
| Corridors | Closets to hide in; landmarks (a clock, a suit of armour, portraits); long sightlines |
| Servants' passages | Narrow shortcuts behind the walls; he uses them too |

## 5. L1: the adventure, the squad, the search (before the playtest)

L1 changes how the house is put together and judged, using only rooms and systems that exist. The builder (`World/MansionBuilder`), the art and the Guest's walking are untouched, and so is the old house (`Logic/LevelGraph`, the golden houses, Gate A).

### 5.1 Measure first (`Logic/HouseMetrics`, `tools/housestats`)
A house and its plan are walked by a simulated efficient squad over `Logic/NavGraph` (real walking distances: stairs, the gallery, doors), with each stage's locks shut: start → each thing the plan needs, in the solver's order → its lock → the heirlooms → the table → the front door. Measured:

- the walk in studs, the share of it re-walked through rooms already visited (backtracking), and the returns to region 0;
- region sizes, region 0's share, one-room regions;
- what each bolt saves on the way back to the table once it's open;
- at every stage: the longest loop, the farthest an open room is from a hiding spot, the deepest dead end;
- items in corridors, the heirlooms' floors, the carry from each heirloom to the table, each key's walk to its door;
- gate kinds in a row and puzzles used;
- rooms with no reason (section 4).

`HouseMetrics.score` adds up how far each falls outside its band (`Config.LevelDesign.Targets`, by squad size). `lune run tools/housestats [count] [squad]` prints the spread of every number; `tools/plan` prints a house's scorecard.

### 5.2 The house follows the squad (`Config.Mansion.BySquad`, `Logic/HouseSize`)

| Squad | Rooms | Regions after the first | Heirlooms |
| --- | --- | --- | --- |
| 1 | 15–18 | 2 | 2 |
| 2 | 17–20 | 2 | 2–3 |
| 3 | 19–22 | 3 | 3 |
| 4 | 21–24 | 3 | 3 |

Hard adds a region, as before. A seed no longer names one house on its own: the seed and the squad size do. F2 `squad <1-4|auto>` sets the next run's size, so a solo test can build a four-player house, and the tools take the squad size.

### 5.3 Wings and beats (`Logic/Wings`)
Rooms are packed as before, but which shared walls become doors, and so the loops, wings and shortcuts, comes from the plan:

1. The generator keeps the tree that joined every room, and the doors the house can't do without (both floors joined, the stairs).
2. **Wings.** Region 0 is the hall, the dining room and the way between, grown to about a third of the house. The other regions are branches of the tree cut into wings of 3–7 rooms, preferably where a wing naturally starts: a corridor's mouth, a stairwell, the kitchen door, a change of floor.
3. **Beats**, per wing:
   - **a loop inside it** (4+ rooms), so a chase in the wing has somewhere to go;
   - **the shortcut**: a bolt from the wing's far end to an earlier region, where it saves the most walking back to the table (at least 60 studs, or none);
   - **the backtrack** (sometimes): the way in is from an older wing, and the obvious door is bolted from the other side;
   - **the long way round**: the wing's key is kept in an earlier room a good walk from its door, never in a corridor;
   - **parallel wings** for 3–4 players: two wings open at once, so splitting up pays;
   - **the double lock** for 3–4 players: one door, two keys from two far-apart rooms.
4. The planner (`LockPlanner`) takes the regions, order and gates from the wings and chooses only what each lock is and what keeps each heirloom. Houses without wings (the old house) are planned as before.

### 5.4 The programme (`Logic/Programme`)
Before any room is placed, the run draws its **adventure deck** (which kinds of lock and keeper it wants: the computer, the breaker, the safe, the music box, the crank, ...) and the **room list**: first the rooms the deck needs (a desk room for the computer, the music room for the music box, a homely room for the safe, a service room for the breaker), then rooms by theme and purpose. A room that fits nowhere drops out and its beat falls back to a plain key.

### 5.5 The search (`Logic/HouseSearch`)
About 12 candidate houses a run, each from its own forks of the seed, each planned and measured; the best score is played. The server yields between candidates, so it never stalls. F2 `house` prints the chosen house's scorecard and every room's reasons.

## 6. Phases

| Phase | What | Gate |
| --- | --- | --- |
| L0 | This document; banners; the `CLAUDE.md` roadmap | Owner approved the plan (2026-10-05) |
| L1 | Section 5: metrics and targets, squad sizes, room reasons, wings and beats, the programme, the search | Tests; `tools/housestats` meets its bands; Studio: `navtest fast` on 3 seeds at squads 1 and 4, full runs, Gate A unchanged |
| — | **The squad playtest** (`TESTING.md` TC-68 on, plus the level-design TCs) | "Did it ever feel like it cheated?" "Was it fun?" "Did you get lost?" "Did the shortcuts and going back feel good?" "Was every room worth going into?" |
| L2 | House plans and new spaces: a grammar of house types with wings as built units; floors from the cellar to the attic (−1 to 2); servants' passages and hidden doors; the laundry chute; narrow corridors with closets; L-shaped rooms by archways; glass-panelled gate doors and courtyard windows to see what's ahead | `navtest` on every new piece; fallback re-frozen; screenshots |
| L3 | The family (`Logic/Family`) and its notes, photos and drawings; furniture laid out for play (`Logic/RoomFurnish`, the old M4); landmarks; the room options of section 4 | Screenshots per room; `clip`; a playtest |
| L4 | The house fights back (the old R3): flips chosen by the simulator, his passages, his room, the looping corridor, house events by act | Playtest |

## 7. Additions to the fairness contract
- Every stage has somewhere to run round once its bolts are open, and no dead end deeper than 3 rooms (`LockPlanner.checkShape`, run on every partition before it's kept); region 0 is built round a loop of at least 100 studs. Every room but a stair has somewhere to hide. A lure in every wing is preferred by the search, not guaranteed (`kitGaps`); L3's room options close that gap.
- A shortcut only ever opens from the far side (it's a bolt).
- A backtrack gate is always reachable with what the squad has (the solver proves every plan).
- A double lock's two keys are always where the squad can get them before the door.
- The house follows the squad's size: a solo player never gets a 24-room house.

## 8. Risks
- **Wings that don't fit a house:** that candidate scores badly and the search skips it; the old region growth stays as a last resort.
- **More doors from the beats lower the validator's pass rate:** more attempts, absorbed by the search; watched with `tools/mansionstats`.
- **Generation time on the server:** measured in Studio; the number of candidates is in `Config.LevelDesign`, and the search yields between them.
- **The playtest may move the targets** (loop lengths, how big a house two players can manage): that's what the bands in `Config.LevelDesign.Targets` are for.

## 9. L1 as built (2026-10-05, builds `2026-10-05.25` to `.30`)

**The pipeline, per run** (`RunOrchestrator` → `Logic/HouseSearch`, 12 candidates, the server yielding between them):
1. `Logic/HouseSize`: the squad's room band, regions and heirlooms (`Config.Mansion.BySquad`; small houses also get fewer extra corridors and one stairwell). F2 `squad <1-4|auto>` stands in for a bigger squad.
2. `Logic/Programme`: the adventure deck (2 kinds for 1–2 players, 3 for 3–4) and the room list, needed rooms first (the study for the computer, the music room for the music box), then rooms with a landmark or a lure ahead of plain ones.
3. `Logic/MansionGen`: the spine and rooms as before, packed in the programme's order; then the doors: the required ones, then `Logic/Wings` (region 0 round a loop through the hall or the dining room; wings of 3–7 rooms cut from the tree of doors; a loop inside each wing; shortcuts home; the backtrack; wings side by side for 3–4 players; per-stage dead ends patched), each tried partition checked by `LockPlanner.checkShape`; then extra loops, preferring doors inside a wing.
4. `Logic/LockPlanner`: takes the wings' regions, order, gates and key regions, and draws the locks' kinds (favouring the deck) and keepers; keys go the long way round (40–300 walking studs from their door, `MansionHouse.walker`); keys and heirlooms go to rooms with no reason of their own first, never an heirloom in a corridor; the double lock for 3–4 players. Houses without wings (the old house, the authored fallback) are planned as before; the old house's plans are byte-identical.
5. `Logic/Leads` (notes go to rooms with no reason first), `Logic/RoomPurpose` (every room's reasons), `Logic/HouseMetrics` (a simulated squad walks it over `Logic/NavGraph`) and the score; the lowest is kept. F2 `house` prints the scores, the scorecard, the wings and every room's reasons; Telemetry `HouseChosen`.

**Measured** (`lune run tools/housestats 30 <squad>`; "before" is the generator as it stood, build `.24`, one house a seed):

| Squad 4 | Before | After |
| --- | --- | --- |
| Region 0's share of the house (band 0.25–0.4) | median 0.58, all 60 houses outside | median 0.43, range 0.29–0.50 |
| Regions after the first (wanted 3) | median 2 | 3 in 29 of 30 houses |
| The smallest region | 1–2 rooms in 38 of 60 | 3 or more in every house |
| Heirlooms in a corridor | in 28 of 60 houses | none |
| Trips back to an older region | none in 21 of 60 | median 1 (none in 2 of 30) |
| Puzzles a run | median 1 | median 2 |
| Rooms with no reason to go in | (not measured) | median 1 |
| Score on today's targets (lower is better) | one house with L1's generator: median 20.8 | best of 12: median 12.6 |

Squad 1: 15–18 rooms, 2 regions in 26 of 30 houses, region 0 a median 0.47, score 8.7. Generation: about 1.4 s a run in Lune, 0.8–1.5 s in Studio.

**Checked in Studio (one client):** squad sizes (seed 61 solo: 16 rooms, 2 regions, as in Lune); a double lock (shut with no key and with one, open on the second); `navtest fast` with every lock open and the shutters latched on the searched houses of seed 61 (squads 1 and 4: 18 and 23 legs) and seed 7 (17 and 26), and seed 6's single house (24): 0 failed, 0 stuck, 0 phases; a full run on seed 3 for four (the dinner, out of the front door, won); Gate A unchanged (parts 2134, hash 1322547804); clean consoles; `perf` 0.2 ms heartbeat.

**Found and fixed on the way:** the run tick ended a run as abandoned while the search yielded (the squad joins only once the house is built); candidate seeds from `Fork("house " .. i)` overlapped between next seeds (the salts hash one apart); F2 `unlock all` left crank shutters down, so `navtest` timed out on the long way round (it now latches them, and a leg's time follows his route).

**Not done, or open:**
- A region-0 share under 0.4 isn't always reachable: the hall, the dining room and their loop are a big share of a small house, and a public wing too big to be one wing stays in region 0. L2's house plans (wings built as units) are the real fix.
- Solo runs rarely go back to an older region (12 of 30): a solo house's second wing often opens from its first. Tune after the playtest.
- Shortcuts: half the wings of four rooms or more have one that saves 60+ studs; the zone rules (which rooms may share a door) leave few doorways to add.
- A lure in every wing isn't guaranteed (`kitGaps` median 2); L3's room options add lures.
- The authored fallback mansion (`Data/MansionFallback`) wasn't re-frozen: it has no wings and is planned the old way; the search keeps it only when every candidate falls back.
- Not checked: two clients (TC-90 to TC-94), the feel of it.

**Fixed after L1** (build `2026-10-05.31`): the dumbwaiter's hatch could find its wall taken by furniture, and its heirloom was then left upstairs (seed 3 for four: the garage under the nursery). The planner now offers only spots whose casing, and the crank downstairs, clear the furniture both rooms will have (`Logic/Dumbwaiter`: `furniture` and `footprint`, from `RoomFit.inMansion`, the fit `World/MansionBuilder` builds), so it's an ordinary deck pick again (weight 1.5, was 0.5). The build still checks the spot for anything else solid. Over the first houses of seeds 1 to 80 for four, 39 dumbwaiters were planned and none would hit fitted furniture (before: 28, one blocked).


## 10. L2: house plans and new spaces (plan, 2026-10-05)

The owner asked to go on to L2 before the playtest ("continue with L2"). L2 is the builder phase: new kinds of space, then new kinds of plan. Each step below is its own commit, checked by the specs, `tools/housestats` and Studio (`navtest` over every new piece, screenshots), and leaves the old house alone (Gate A).

### 10.0 The owner's notes on the cellar and the attic (2026-10-05, during L2.2)
- "Put the cellar and the attic in separate wings and not the starting wing, so they can be more important for progression."
- "Don't mean replacing existing wings with the attic and cellar, they should be additions to the existing wings, obviously the cellar entrance would be a first floor thing that goes down and the attic would be on second floor and go up, they should also tie into the gameplay loop somehow that makes the game better instead of annoying."

How the house keeps to them:
- **A wing each, on top.** The cellar and the attic are each a locked wing of their own (`Logic/Wings`: the tree enters each as one branch, and every partition must cut it; it can be any size). They come on top of the squad's wings: four players get 3 wings plus the cellar plus the attic, one player gets 2 plus one of them. Never open from the start. `HouseMetrics.storeyWings` counts any that isn't (weight 20 in the search).
- **Ground floor down, upper floor up.** The cellar stair comes up into the kitchen side of the ground floor, the attic stair into the upper floor; the back stairs (the servants' stair) reach both.
- **Part of the loop, not a detour.** Each holds something the run needs: the lock planner leans keys (×3, `Storeys.Keep`) and heirlooms (×4, `Storeys.Heirloom`: the family's old things) towards them, and puts the fuse box in the cellar when it can (go down to bring the power back); `HouseMetrics.storeyIdle` counts one holding nothing (weight 6).
- **Not annoying.** Small (2–3 rooms), lit by bare bulbs, one storey deep; two ways in where they fit, so they're a loop to run round, and the other way in is a bolt you open from inside (a shortcut home); a key for one is kept a short walk away like any other.
- **The main floors keep their rooms.** The squad's room band counts the main floors; the cellar's and the attic's rooms come on top (a solo house with a cellar is 18–22 rooms in all).

### 10.1 Storeys from the cellar to the attic (L2.1)
The code learns floors −1 (cellar) to 2 (attic). Nothing about the houses changes in this step: 240 mansions (four squad sizes) and 20 old houses keep their fingerprints, plans and walking graphs exactly.
- A room's `floor` is its lowest storey. A double-height room (`tall`) spans `floor` to `top` (one storey up unless it says otherwise), with a zone per storey.
- Which storey a height is on: storey *k* starts half a stud below its floor (`Storeys.of`, used everywhere that asked "upstairs or down?").
- A room above the ground stands on the storey below it; a cellar room lies under the ground floor; nothing stands over the void.
- The builder, the walkers' graph, `WorldService`, the map and the tools take any storeys the house has. The map shows the storeys the house has (Cellar, Ground floor, Upper floor, Attic).

### 10.2 The cellar (L2.2)
- **Reached** by the cellar stair (a straight flight down from a door off the kitchen side: the kitchen, pantry, service passage or laundry) and, where it fits, by the back stairs carried down. Two ways down make the cellar a loop of its own: kitchen, cellar stair, cellar, back stairs, service passage, kitchen.
- **Rooms** (2–4): the boiler room (the boiler: a landmark and the breaker panel's home), the wine cellar (racks to hide behind), the storeroom (shelves and crates), the workshop (a bench and tools), the cold store. Stone and whitewash, bare bulbs on pull-chains, joists overhead, no windows.
- **Zone** `cellar`: doorways only between cellar rooms and the bottoms of the stairs, so the dining room stays the only way into the service wing on the ground floor (the table stays on the path).
- **For the adventure:** the cellar is a natural wing ("the cellar door is locked"), and `Logic/Wings` already favours a cut at a change of floor.

### 10.3 The attic (L2.3)
- **Reached** by a steep attic stair from the upper hall and, where it fits, by the back stairs carried up (the servants' stair ran from the cellar to the attic). Two ways up make a loop.
- **Rooms** (2–3): the box room (trunks: a home for heirlooms), the servants' bedroom, the water-tank room, a stretch of attic passage. Rafters under a pitched roof, bare boards, a round gable window.
- **Zone** `attic`. Its boards creak: footsteps carry further up there (`Logic/VoiceNoise`'s footstep noise, by room).

**Who gets which** (`Config.Mansion.BySquad`): one or two players get one of them by chance (2–3 rooms); three or four get both (2–3 rooms each). Each is a wing of its own on top of the squad's (section 10.0), and its rooms come on top of the room band.

### 10.4 Servants' passages and hidden doors (L2.4)
- **Passages:** narrow ways (a 10-stud strip, about 6 to walk) behind the walls of a wing, opening into its rooms by hidden doors: a bookcase in the library or study, a panel in the dining room, a jib door in a bedroom.
- **Finding a hidden door:** it looks like the wall. Its tells: a draught (dust drifting towards it, a faint whistle), scuffs on the floor in the arc it swings, a book out of line. The prompt shows only at arm's length while facing it. From inside the passage it's a plain latched door.
- **Fairness:** the house is whole and fair without its passages (the validator, the walker graph and the planner treat an unfound hidden door as wall); nothing the run needs lies only behind one; The Guest treats an unfound hidden door as wall (he uses the passages in L4, as a rule players are told). Once someone opens it, it's a door for everyone.
- **Purpose:** a shortcut across a wing, somewhere to hide, sometimes a keepsake.

### 10.5 The laundry chute (L2.5)
- A hatch in an upstairs room standing over the laundry (a bathroom, the upper hall, a bedroom). Climb in to slide down (one way, about a second), or drop what you carry into it (it lands in the laundry basket).
- It opens only while the laundry can be walked to from the hall with the doors as they are, so nobody drops into a locked wing.
- Players only: The Guest doesn't fit.
- **Purpose:** an escape from upstairs, and a shortcut for heirlooms down to the dining room's side of the house.

### 10.6 House types (L2.6)
A grammar of plans, each a set of wing blocks the packer fills, with wings built as units with a character (the public rooms, the family's, the servants', the guests'): the centre hall (today's), the L, the U round a courtyard (windows across the courtyard show what's ahead), the H, and a tower stair. The search keeps runs from repeating a type.

### 10.7 Corridors, archways and glass (L2.7)
Narrow corridors (10–14 to walk) lined with closets to hide in; L-shaped rooms, two rectangles joined by a wide archway; glass-panelled gate doors, so a locked wing can be seen before it can be entered.

### 10.8 Fairness additions
- The cellar and the attic each have two ways in where they fit; where only one fits, the validator's dead-end rule still holds (no room more than 2 doorways from a loop).
- Hidden doors and the chute are extras: every fairness rule holds without them.
- The chute never drops anyone into a part of the house that's still locked.

### 10.9 Order and gates

| Step | What | Checked by |
| --- | --- | --- |
| L2.1 | Storeys −1 to 2 in the code | 240 + 20 house fingerprints unchanged; Studio: a run on two seeds, Gate A |
| L2.2 | The cellar | Specs; `housestats`; Studio `navtest` with a cellar on squads 1 and 4; screenshots |
| L2.3 | The attic | As L2.2 |
| L2.4 | Passages and hidden doors | Specs; Studio: finding, opening and walking a passage; `navtest` |
| L2.5 | The laundry chute | Specs; Studio: a drop, an item, the locked case |
| L2.6 | House types | `housestats` per type; screenshots from above |
| L2.7 | Corridors, archways, glass | Screenshots; `clip`; `navtest` |
| — | The fallback re-frozen; the squad playtest | |

### 10.10 L2.2 as built (build `2026-10-05.33`)
- **Storeys:** `Config.Mansion.Storeys` (which a house has, rooms each, the planner's leanings; L2.3 sets the split between the cellar and the attic by squad: until then every house has a cellar).
- **Generation** (`Logic/MansionGen`): the back stairs carried down (a stairwell spans any storeys: stacked dog-legs, `Logic/TallRooms`, the builder's upper flights hang as sloped slabs with 10 studs of headroom); the cellar's rooms packed from their foot under the service wing (`Placement.Under`); then the cellar stair from a cellar room up into a kitchen-side room right above it, as far from the back stairs as it fits. A few packings are tried (`Storeys.Tries`), the first with both stairs kept; the last try keeps the cellar to two rooms, so it's never a deep dead end.
- **Rooms** (`Data/Rooms` `CellarRooms`, checked by the same template rules as the old rooms): the boiler room (the boiler, a landmark), the wine cellar (racks), the storeroom, the workshop (a tool's bench), the cold store; the cellar stair. New props: `Boiler` (fixed, a glowing firebox), `WineRack` (pushed). Bare bulbs (`fixture = "bulb"`), joists (`joists`, `Config.Mansion.Joists`), boarded ceilings, no windows.
- **Measured:** the generator passes first time as often as without a cellar (solo 52% vs 50%, four 72% vs 70%, single attempts); about three cellars in four have both stairs. Over 30 searched houses each: the cellar is a wing of its own in every house (`storeyWings` 0) and holds something the run needs in every house (`storeyIdle` 0); region 0's share fell (four: median 0.38, was 0.43; solo 0.40, was 0.47); four players get 4 wings.
- **Studio** (one client): seed 7 for four (25 rooms, 4 wings, the cellar behind the back stairs with a bolted shortcut up the cellar stair): built in 0.11 s, the search 1.5 s, clean console; `navtest fast` 29 legs, 0 failed, 0 stuck, 0 phases (every storey of the three-storey back stairs, the cellar stair, every cellar room); the stairs' ramps and landings meet exactly; Gate A unchanged (2134 / 1322547804). The cellar's bulbs were raised after the first look (it was too dark to read the room).
- **Not checked:** the cellar by eye beyond two screenshots (the boiler room wasn't in that house), two clients, how it plays.

### 10.11 L2.3 as built (build `2026-10-05.34`)
- **Who gets which** (`Config.Mansion.BySquad[n].storeys`, put over `Config.Mansion.Storeys` by `Logic/HouseSize`): one or two players get exactly one of the cellar and the attic (even odds); three or four get both. The main floors' band for three and four came down by two rooms (17–20 and 19–22), so with both the house is 24–30 rooms in all (four: median 27; one: 18–22).
- **Generation:** once the upper hall is laid out, and before the bedrooms fill the space, the attic's loop is built (`MansionGen:_atticLoop`): the attic stair off the hall the back stairs open into upstairs (`Storeys.Attic.Beside`), about 40 studs from them, and one or two attic rooms over that hall reaching both stairs. The rest of the attic grows over the bedrooms later. When that can't be done, the attic grows from the back stairs alone (two rooms at most) and the old way is tried (rooms, then the stair beside them). Joining the cellar or the attic into one piece only has to keep the table on the way out (their loops climb two flights). The attic stair comes down into the upper hall or a bedroom, never a bathroom.
- **Rooms** (`Data/Rooms` `AtticRooms`, the template rules apply): the box room (trunks, a crib, a dress form), the servants' room (a bed), the water tank room (`WaterTank`, fixed), the lumber room; the attic stair. A sloped roof on rafters (`rafters`, `Config.Mansion.Rafters`: from 7 studs on the long walls to the ridge; nothing collides), bare boards, bulbs (which now light all round, so the rafters and the cellar's joists show), no furniture taller than the roof's low side.
- **Creaking boards** (`creaks` on the attic's templates, `WorldService:CreaksAt`, `Config.Player.CreakChance`): footsteps carry half as far again up there, and a noisy step sets a board creaking now and then (everyone hears it); creeping is silent.
- **The search:** `mainWings` (the squad's own wings, the cellar's and the attic's not counted: three for three or four players) and `storeyOneWay` (a cellar or attic with one way in) join `storeyWings` and `storeyIdle`; `minRegion` and `maxRegion` count the squad's own wings.
- **Studio** (one client): seed 7 for four (26 rooms, 5 wings: the attic opens first and holds an heirloom and one of a double lock's two keys, the cellar the other key and an heirloom): built in 0.13 s, the search 1.2–1.5 s, clean console; `navtest fast` 33 legs, 0 failed, 0 stuck, 0 phases (the back stairs on all four storeys, the attic stair, every attic and cellar room); screenshots of the lumber room (the roof, rafters and ridge) and the boiler room (brick, joists, the boiler's firebox); Gate A unchanged (2134 / 1322547804). The breaker's starting circuits can leave the cellar dark until the fuse box is worked (as for any wing); F2 `lights on` doesn't override that.
- **Not checked:** the creaking boards by ear, two clients, how it plays.
- **Measured** (30 searched houses each): four players: cellar and attic in every house, each a wing of its own holding something the run needs (30 of 30), two ways into each in 29 of 30, all three main wings plus both in 24 of 30 (median 5 wings), region 0 a median 0.37 of the house. One player: one of them in every house, its own wing in all 30, two ways in and something needed in 29 of 30. Single attempts pass first time as often as before the attic (one 57%, four 74%); in valid houses, attics have both stairs about 60% (one) to 80% (four) of the time, cellars about 85%.
