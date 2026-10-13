# The visual rework, V4 (part 1): the kit's first rollout batch (build `2026-10-13.184`)

The owner approved the golden area's look on 2026-10-13 ("I approve the look for now, proceed"), which opens the rollout: the kit batch by batch to the whole house (the plan's V4). This first batch, `kit3`, takes what every room has (its trim, its doors and windows, its pictures) and the halls' and bedrooms' common furniture, and finishes the golden area's last items (the stairs' treads, the corridor).

## The batch (`tools/blender/kit.py kit3`)

New in `kitlib/`:
- **trim:**
  - mouldings for the trim, each a section swept along X;
  - the stair's step;
  - the doors and their knob;
  - the sash window.
- **decor:** the paintings in gilt frames, the mirror's frame, the snake plant.
- **paintings:** four pictures drawn in numpy, each built in four steps:
  1. **Composed** as flat masses.
  2. **Painted** over with strokes. Each stroke picks up the colour under it, a little off in value and warmth, and runs along the form: broad strokes over a softened copy, then fine ones along the edges.
  3. **Aged** under a yellowed varnish, darkened at the edges, with a canvas weave.
  4. **Cracked:** a fine craquelure in patches.
- **furniture:** the chest of drawers and its drawer, the blanket chest and its lid, the moving box.

New in `shapes`: `moulding` (a section swept along X), `frame` (a picture frame, mitred), `cut_below`. The driver also gained two things:
- A piece can ask for a smaller texture (`bake_size`: the knob at 256 px, a drawer's front at 512 px).
- The report prints each piece's box middle in all three axes (`at`).

| Piece | Size (studs) | Triangles | Stands for |
| --- | --- | --- | --- |
| Baseboard | 4 × 0.7 × 0.14 | 76 | every run of baseboard: a shoe, a flat board, a bead, an ogee cap |
| Crown | 4 × 0.45 × 0.3 | 88 | the crown: an ogee from ceiling to wall |
| Casing | 4 × 0.55 × 0.18 | 78 | a doorway's casing: a bead at the opening, a back band outside |
| Dado rail | 4 × 0.2 × 0.12 | 58 | the chair rail over formal rooms' panelling |
| Stair step | 6 × 0.54 × 1.12 | 56 | each step: a walnut tread with a rounded nose over a cream riser |
| Knob | 0.52 × 0.52 × 0.94 | 1,044 | every door's knob set, a rose on each face |
| Door | 5.8 × 7.8 × 0.48 | 3,420 | the six-panel door, rebuilt (below) |
| Glass door | 5.8 × 7.8 × 0.48 | 3,588 | a wing's gate: stained walnut, glazed above its sill |
| Window | 6.3 × 5 × 0.5 | 2,114 | a double-hung sash, six panes over six, on a stool and apron |
| Paintings 1 to 4 | 5 × 4 × 0.25 | 154 each | an evening farm, a storm with a lighthouse, a winter wood, a moonlit lake |
| Mirror | 3 × 5 × 0.3 | 122 | a gilt frame whose lip stands in front of the game's glass |
| Plant | 1.7 × 4.5 × 1.9 | 3,216 | a snake plant in a glazed pot, inside the plant's reach |
| Chest of drawers | 6 × 3.6 × 2.5 | 1,820 | its carcass, top, plinth and bracket feet |
| Drawer | 5.5 × 0.88 × 0.24 | 1,536 | each drawer's front, with two brass bail pulls |
| Blanket chest | 5.05 × 2.4 × 3 | 2,628 | an open oak box with iron straps and handles, lined inside |
| Chest lid | 5.1 × 0.95 × 3.09 | 532 | its lid, with the iron hasp |
| Box | 4 × 1.6 × 4 | 276 | a taped cardboard box, written on in marker |

**The door, rebuilt.** The spike's door had its panels where the knob is (the knob sat on a panel's edge). Now:
- stiles 0.85 wide;
- small panels at the top and tall ones in the middle;
- a lock rail at the knob's height.

It went from 7,500 triangles (in the first bake of this batch) to 3,420. The rails' and stiles' mouldings no longer share a plane where they overlap, so they can't flicker.

**Fixed before the import, from the previews** (shot 0):
- The chest of drawers had no back: an open drawer would have shown the wall.
- The door was too heavy.

## In the game (`World/Kit`, `Data/Kit`, `Kit.spec`)

`World/Kit` gained five ways to dress the house:

- **`Kit.swap(part, name, roll)`, for trim.** Trim is only seen: it never collides and never catches a ray. So the mesh takes the part's place outright: its name, attributes, tags and transparency (a seam's trim shown only while it's a wall), and the part goes. `World/Trim` swaps every baseboard, crown and dado rail (in `segment`) and every casing piece.
  - **Casing legs:** the mesh lies along X, so a casing's legs are turned upright (`roll` ±90), their back band away from the opening.
  - **Direction:** trim's front is its part's -Z, so these entries turn back the half turn every piece gets (`turn = 180`).
  - **Corners:** a moulding's section fills its whole box, so stretching it along a run never squashes it. Two runs crossing in a corner make the mitre by themselves.
- **`Kit.place(parent, name, cframe, size)`, a piece where no grey-box part stands.** `World/MansionBuilder`'s flight puts a tread and riser on every step:
  - the tread's top 0.04 over the step and its nose 0.12 out;
  - the riser 0.03 in front of the step's face;
  - so no two faces share a plane.
- **Moving pieces (`pieces`).** A prop's drawer fronts and lid each hang on their piece's main part, inside the piece's model, so they slide and swing with it. Both `FurnitureService` and `MotionController` move every part in the model.
  - The grey-box parts they stand for are hidden.
  - The dark slot behind an open drawer stays the game's.
  - **The chest of drawers' layout:** it now stands on a 0.45 plinth (its feet) under a 0.15 top, its three drawers between. This is `World/PropFactory`'s `DRESSER_PLINTH` and `DRESSER_TOP`, and the drawers sit a little higher than before.
- **One mesh per part (`each`).** Each box in a stack wears the box mesh at its own size.
- **Wall decor (`Kit.dressDecor`, a new `Decor` group).** `PropFactory.buildDecor` dresses:
  - the window: its frame, sill and muntins;
  - the painting: one of four, by the decor's own seed, so every client sees the same one;
  - the mirror's frame.

  The glass, the night outside, the moonlight and any curtain or blind stay the game's.
- **Doors.** A gate's glazed door wears the glass door over its slab, frame and panels, at the whole door's frame where it rests (ajar or not; `dressSlab`'s `whole`). Every door's knob wears the knob.

`Kit.spec` has three new tests (seven in all):
- moving pieces say where they hang and what they stand for, and fit their prop;
- the mouldings are modelled at `Config.Trim`'s sections, fit their runs and face the room;
- wall decor dresses real decor within 8% of its size.

## Seen in Studio (seed 3, build `.184`)

- **`[Consensus] kit: 37 meshes loaded`**, no failures. The house dressed:
  - trim: 148 baseboards, 64 crowns, 126 casing pieces, 45 dado rails;
  - doors: 13 doors and 13 knobs;
  - stairs: 44 stair steps;
  - walls: 20 windows, 5 paintings;
  - furniture: the plant, the chest of drawers and its three drawers, the blanket chest and its lid, the boxes.

  The console was clean apart from the usual DataStore warnings.
- **The staircase** (shot 3) reads as stairs: cream risers under walnut treads with a lit nose, the runner up the middle.
- **The sash window** (shot 4): six panes over six, the lock on the meeting rail, the sill and apron, the game's sheer curtain in front, the night through the glass.
- **The chest of drawers** (shots 5, 6): F2 `furniture open` slid its drawers out, each carrying its modelled front and pulls. On the server, each drawer's mesh kept its place on its front.
- **The wing gate** (shot 7): walnut, glazed, the lock's own plate and the brass knob, light under the door.
- **The blanket chest** (shot 8): opened, its lid up, the dark lining inside; the boxes stacked by it.
- **The main corridor** (shot 9): the drum pendant, the runner, the chair rail, doors either side.

**Fixed after the import: a painting in its own shadow** (shot 1). A sconce on the same wall shines along it, and the frame, standing 0.25 out, put the recessed picture and a long stretch of wall in the dark. Paintings and the mirror now cast no shadow (`Data/Kit`'s `shadow = false`). Under the torch the picture reads, the gilt catching the light (shot 2).

**Gate A re-baselined:** parts 2388, hash 1667624079 (2319 and 1010683597 before). The windows, paintings, knobs and boxes each gain their mesh. The trim's swaps are one for one.

**Checks:** 616 tests, `tests/compile`, selene 0/0, `rojo build`. Generation didn't change (the chest of drawers' drawers only moved up), so `tools/completable` wasn't rerun.

## Not done yet

- The rest of V4 by room family:
  - the living room's TV stand, coffee and side tables, cabinets, curtains and the piano;
  - the bedrooms' beds, closets, wardrobes and the crib;
  - the kitchen and utility rooms;
  - the cellar and the attic.
- The front door and the mansion's exit door are still grey-box. So are the wainscot's flat panelling (it keeps its material) and the doorway linings.
- The hidden door keeps its own build: it's disguised as wall on one side.
- The paintings are dark by design (old varnish). If they read too dark in a lit room, the varnish can be lightened in `kitlib/paintings._age`.

## Shots

- `0_kit3_blender.png`: the batch in Blender's preview (trim, stair step, knob, both doors, window, mirror, plant, box; the four paintings; the chest of drawers and drawer, the blanket chest and lid).
- `1_painting_in_its_own_shadow.jpg`: the grand hall's painting, its picture black in the frame's shadow.
- `2_painting_no_shadow_torch.jpg`: fixed, the moonlit lake under the torch.
- `3_staircase_treads.jpg`: the grand staircase's treads and risers.
- `4_sash_window.jpg`: the dining room's sash window under the torch.
- `5_chest_of_drawers.jpg`, `6_drawers_open.jpg`: the master bedroom's chest of drawers, shut and open.
- `7_wing_gate.jpg`: the upstairs gate into a wing.
- `8_blanket_chest_open_boxes.jpg`: the child's bedroom's blanket chest open, the boxes by it.
- `9_main_corridor.jpg`: the main corridor.
- `10_hall_door_and_trim.jpg`: the hall's new door ajar, the dado rail and baseboard along the wainscot.
