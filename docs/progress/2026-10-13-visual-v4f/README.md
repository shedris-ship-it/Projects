# The visual rework, V4 (part 6): the moving fittings and the corridor landmarks (build `2026-10-13.189`)

The owner restarted their PC (C: had filled again, its page file at 19 GB) and said: "we can proceed with Kit8, afterwards, let me know where we're at in the broader visual update".

`kit8` takes:
- the house's moving fittings that were still blocks: the dumbwaiter, the crank doors' shutters and cranks, the laundry chute;
- the corridors' five landmarks.

What's left of V4 is `kit9`, the atmosphere:
- the photo frames, telephone and clutter on tops (`World/Dressing`);
- the finds in drawers (`World/Junk`);
- the outside's trees and lamp.

## The batch (`tools/blender/kit.py kit8`, `kitlib/fittings`)

20 pieces, each built in the game's own frame round the grey-box part it dresses, so the game moves it as it moved the part.

| Piece | For | Triangles |
| --- | --- | --- |
| DumbwaiterCasing | `Puzzles/Dumbwaiter`, each floor: an oak cabinet floor to ceiling, raised panels on its front and sides, a baseboard and a cornice round it, an architrave and a sill round the hatch's opening. Inside, the shaft's dark lining and the car's runners. Its sides reach back to the wall (the game's casing stands 0.3 off it) | 5,800 |
| DumbwaiterHatch | the stuck hatch downstairs: a small oak door, a glazed light round the game's glass (kept), a raised panel, brass hinges and knob | 2,696 |
| DumbwaiterCar | the car: an oak box open at the front, board sides, a brass lip, an iron bail and the rope it hangs from | 1,272 |
| JamBox | an open iron cradle bolted to the casing, and a brake rod from it up to a shoe under the wheel's rim | 1,184 |
| HandWheel | both cranks' wheel (scaled to each: the crank door's 1.1, the dumbwaiter's 0.8): a cast-iron rim on five curved spokes, the hub and axle, a turned wooden grip | 2,232 |
| ShutterSlat | one slat of a crank door's roller shutter: dark stained oak, bowed out, a V-groove where it meets the next | 40 |
| ShutterBar, RollerBox | the shutter's steel bottom bar with lifting handles both sides; the riveted green-grey roller box over the doorway with its round end plates and bearings | 564, 3,872 |
| CrankPlate, ShutterLatch | the crank's iron wall plate with its gear housing, ratchet ring and pawl; the drop latch inside | 3,102, 912 |
| ChuteHatch | the chute's hatch upstairs: almond-enamelled steel, a pressed surround, hinged at its foot, a chrome pull bar | 1,988 |
| ChuteMouth, LaundryBasket | the galvanised mouth over the laundry, its flap swung a little open; a wicker hamper (upright stakes, an over-under weave) heaped with sheets, a towel over its front | 1,772, 10,012 |
| ChuteTrapdoor, ChuteDuct | where the rooms share no wall: an oak trapdoor bound in steel with a brass ring in a cup, and a square galvanised duct out of the ceiling | 2,156, 924 |
| StagHead | a stag's head on a walnut shield: a lofted skull, a pale throat, a wet nose, glass eyes, twelve points of antler darkening to the burr | 3,870 |
| FounderPortrait | a broad gilt frame round the founder in oils (`kitlib/paintings.founder`: an old man in a frock coat and wing collar, white whiskers, deep-set eyes, under a century of varnish). The brass plate with his name stays the game's | 154 |
| Tapestry | a woven hanging on a gilt rod with finials (`paintings.tapestry`): a madder-red millefleur field, a blue border with a gold vine, bands of lozenges, a fruiting tree in a medallion, an urn of flowers. Soft folds, a gold fringe | 8,082 |
| StoppedClock | a deep walnut case, a brass bezel, an ivory dial (`paintings.clock_face`) cracked across with a damp stain, iron spade hands at a quarter to three | 2,330 |
| ShipsWheel | a varnished oak rim bound in brass, eight turned spokes through it to their handles, a drum hub with a brass cap | 4,380 |

**Redone before the import:**
- **The basket's weave** read as plain stripes. It now has 44 upright stakes, spaced evenly by length round the rim, and an over-under checker in the cane.
- **The stag's head** was a soft tube and looked like a toy. It's now lofted through shaped sections (broad and flat over the brow, narrowing to the jaw), with a wet nose, a chin, larger eyes set in dark patches, and the throat patch tucked under the jaw.
- **The founder's portrait:** the first try had a small boxy head on a long neck. It's now painted at 1200 px, the head bigger, its whiskers following the jaw, the neck short and in the jaw's shadow.
- **The tapestry's medallion** looked like a candelabra; it's now a fruiting tree. Its fleur-de-lis read as a trident, so it became an urn of flowers.

## In the game

**The dumbwaiter** (`Puzzles/Dumbwaiter`):
- The kit's casing stands on each floor (`Kit.place`), and the grey-box sides, fronts and trim are hidden.
- The stuck hatch is dressed (`Kit.dressPart`), and the glass stays the game's.
- The car's model rides in the car (`PivotTo` moves it with the floor).
- The jam box is dressed.
- The kit's wheel **turns as the car rises**, four turns from the bottom to the top (`Kit.repose` in `Kind.step`). The block wheel never turned. The grey-box wheel keeps the prompt, unseen.

**The crank doors** (`Services/CrankService`):
- The shutter is now **a stack of slats** from the bar up, placed again each step. One whose foot is in the box is rolled up (hidden), so the shutter rolls into the box as it rises. The grey-box slab stays the shutter's body, unseen.
- The bar follows the shutter.
- The roller box, the crank's plate and the latch are dressed.
- The kit's wheel turns with the shutter, as the block wheel did.

**The laundry chute** (`Services/ChuteService`):
- The hatch upstairs (or the trapdoor) is dressed. The grey-box hatch never collides, so once hidden the hands' aim would look past it. Its kit mesh hangs under the hatch and catches the ray itself, and the aim finds the hatch's prompt by walking up to it (`ChuteService:_dressHatch`).
- The mouth (or the ceiling's duct) and the basket are dressed.

**The landmarks:** `World/LandmarkProps` dresses each with `Kit.dressLandmark` (a new `Data/Kit` group, `Landmarks`, by the `Data/Landmarks` id). The portrait keeps its name plate.

**Fixed after seeing it in Studio:** the tapestry's fringe rested on a corridor's dado rail. It now hangs 0.12 higher (`floor`; 9 before, 9b after).

## Seen in Studio (build .189)

The owner imported `kit8.glb` (20 meshes). 148 kit meshes loaded, and the console was clean through three runs. The shots were lit from the camera, as the torch would be, where a room's own light left a piece in shadow.

**Seed 3, a squad of four, a full night:**
- **The dumbwaiter:**
  - downstairs: the casing, the hatch with its glass, the wheel on the casing's side, and the jam box's rod up to the wheel (1);
  - upstairs: the open hatch and the empty dark shaft (2);
  - after F2 `solve dumbwaiter:1`, the car 11 studs up with its heirloom in the opening (3).
- **The chute:**
  - the hatch in the bathroom's tiled wall (4); the hands' aim from in front of it hits the hatch's model and finds "Laundry chute: Climb in / drop";
  - the hamper (5) and the mouth over it (6).
- **The landmarks:** the stag's head (7), the founder's portrait with "EZRA PRYOR, 1921" on its plate (8), the tapestry (9, then 9b), the stopped clock (10), the ship's wheel (11).

**Seed 1, a squad of four:**
- **The crank door:** 18 slats, the bar and the roller box, the crank's plate and wheel beside it (12).
- After F2 `crank up`, 17 slats hidden in the box, one showing above the bar, and the doorway clear (13).
- The latch inside (14).

**Gate A** is unchanged: parts 2441, hash 1845087318.

**Not checked in Studio:**
- the trapdoor and the ceiling's duct (no house of these seeds has a chute with no shared wall);
- the wheels turning while you hold E (both turn by the same `Kit.repose` as the dumbwaiter's, checked only at the ends);
- the shutter mid-roll;
- the jam box with something wedged in it.

They're in TC-293.

## Checks

621 tests (two new in `Kit.spec`: every landmark has its look, hung from the wall; the fittings are modelled at the game's sizes), compile, selene 0 errors and 0 warnings, `rojo build`. TC-293.
