# The visual rework, V4 (part 7): the atmosphere, and the last of the props (build `2026-10-13.190`)

The owner: "Lets close off the props with kit9, afterwards, if you could give me some examples of the tonemapper I could give you a more confident answer, along with the plan outline and whats next".

`kit9` takes the last things in and round the house that were still built from blocks:
- the things on tops (`World/Dressing`): the hall's telephone, the family photos in their frames, and the everyday clutter (mugs, plates, books, vases, magazines);
- the finds in drawers (`World/Junk`): the cassette, the matches, the letters, the candle, the thread, the painkillers, the spare batteries;
- every room's light switch (`Services/InteractService`) and the safe room's carton of batteries (`Services/SafeRoomService`);
- the night outside (`World/Exterior`): the woods, the bushes and the garden's evergreens, the streetlamp.

What is still built in code after it: the Guest (V5), the tools and your arms (V6), the notes and printouts (paper the game writes on), the hub.

## The batch (`tools/blender/kit.py kit9`, `kitlib/atmosphere`, `kitlib/prints`)

32 pieces, each built in the game's own frame round the blocks it dresses.

| Piece | For | Triangles |
| --- | --- | --- |
| Telephone | a beige rotary desk telephone: the body sloping up to the cradle, the dial (its number card drawn, the finger stop past the 0), the handset across the cradle's horns, its coiled cord down the side | 3,746 |
| PhotoFrame | a dark walnut frame with a gilt slip round the game's photo (still the game's, aged by Drift), a kraft back, the strut on its brass hinge | 250 |
| Mug | a stoneware mug glazed near white, cold coffee in it and a ring where it stood; `World/Dressing` tints each its own colour | 1,704 |
| SidePlate, SidePlateCrust | a stoneware side plate with a brown band, crumbs and a table knife; one with a sandwich's crusts | 1,712, 2,056 |
| BooksA, BooksB | three clothbound books (red, green, blue), or a brown hardback and a thin mustard one; their spines to the front with gilt bands | 768, 512 |
| Vase, VaseStems | a celadon baluster vase (tinted per house), one with dried stems and seed heads | 1,040, 3,888 |
| MagazineA, MagazineB | a home magazine ("HEARTHSIDE", November 1988) and a television weekly ("TELE-VIEW"), their covers drawn | 134 each |
| Cassette | a C90 out of its case: the shell, a handwritten label, the reels through the window | 330 |
| Matchbox | its printed label and strikers, the tray pushed out over red-headed matches | 1,446 |
| Letters | three letters tied in twine with a bow, the top one addressed, stamped and franked, an airmail one under it | 578 |
| Candle | a candle stub run down its side in an enamel chamberstick, chipped, a finger ring | 1,674 |
| Spool | a wooden spool of red thread, a needle through it, the loose end trailing | 1,052 |
| PillBottle | an amber pharmacy bottle, its typed label ("ELM ST. PHARMACY", made out to the Pryors), a ridged white cap | 756 |
| SpareBatteries | two D-cells in a rubber band | 1,248 |
| SwitchPlate, SwitchToggle | an ivory bakelite switch plate with its two screws, and its toggle | 464, 216 |
| BatteryBox | the safe room's carton: kraft board printed on its long sides, its flaps taped; the game's label on top | 420 |
| TreeOakA, TreeOakB, TreeTurning | trees in leaf (the woods' "leafy" plants): a trunk forking into limbs, a crown of leaf masses run together and budded so its outline breaks up, boughs reaching out under it; a maple turning orange and rust | ~4,100 each |
| TreeBareA, TreeBareB | bare trees, branching four times down to twigs | 2,100, 3,120 |
| ConiferA, ConiferB | a spruce and a narrower fir: tiers of drooping boughs to a spire | ~2,000 each |
| BushA, BushB | a rounded bush and a low sprawling one (the undergrowth and the garden's shrubs) | 1,000 each |
| Arborvitae | a tall narrow evergreen, between the windows | 1,106 |
| Streetlamp | a tapered octagonal galvanised pole, a curved arm, a cobra-head with its sodium refractor glowing | 896 |

The printed and written things (the dial card, the covers, the labels, the envelope, the carton's print) are drawn in `kitlib/prints`, with a block alphabet of its own; no real brand.

Studio has no cut-out leaves (`Enum.AlphaMode` is Overlay, Transparency, TintMask or Opaque; checked 2026-10-13), so the leaves are solid: masses run together by a voxel remesh, budded with small masses so the outline breaks up, each leaf a cell of a voronoi in the texture. `SurfaceAppearance.Color` does exist and tints a colour map, so one pale-glazed mug or vase becomes many (`World/Kit.tint`).

**Redone before the import** (`0_kit9_blender_small.png`, `0_kit9_blender_plants.png`):
- The leafy trees were lollipops: the crown sat high on a bare trunk. It's now lower and deeper, with boughs reaching out under it, their leaves part of the crown.
- The bushes read as rocks patterned in camouflage. They now have smaller leaves in a narrower range of greens, more masses, and buds over them.
- The conifers' top tiers folded through themselves, so their faces turned inward (Studio draws only a face's front, so they'd show as holes). Each face is now turned the way it must go.
- A mug handle that showed its corners, crusts that read as sticks, a blurred label on the carton and on the pill bottle, and a magazine's pages flush with its cover (they'd flicker).
- `kitlib/shapes.bounds` now measures a piece by its vertices. Blender's cached box went stale after a cut, so the arborvitae reported its foot 0.33 too low.
- `tools/blender/preview.py` gained `--behind` (the things on a top face the room down -z), `--backfaces` (a face seen from behind shows red) and `--only=`.

## In the game

- **On tops** (`World/Dressing`): every thing is still built as blocks first, then dressed (`Kit.dressThing`). The blocks stay its body for the hands, which carry it with the mesh on. Which look a thing wears comes from the draws its blocks already made (three books or two, a crust or not, stems or not, the magazine's hue). The mug and the vase take their blocks' colour as a tint. So the seed puts everything where it always did. The photo is the game's (`keep`), so Drift still ages it.
- **In drawers** (`World/Junk`): each find is dressed where it lies; its prompt ("Take them", "Read them") is found as before, through the mesh.
- **The light switch** (`Services/InteractService`): the plate is dressed with `Kit.dressPrompted` (new). The grey-box plate never collides, so once hidden the hands' aim would look past it. Its mesh hangs under it and catches the ray, and the aim walks up to the prompt, as at the chute's hatch. The toggle's mesh flips with it (`Kit.repose` in `Flip`).
- **The safe room's carton** (`Services/SafeRoomService`): `Kit.dressPrompted` the same way; its "BATTERIES D-CELL" label is still the game's, printed on top.
- **Outside** (`World/Exterior`):
  - Each plant wears one of its kind's looks (`Data/Kit` `Outside`; `Kit.placeOutside`, new), picked from the exterior's own seed and scaled to the plant.
  - None stands nearer the house than the stand-ins did: its reach is capped by the plant's `clear`, and a shrub's top stays under the sills.
  - One in five leafy trees is the turning maple, as the stand-ins' palette had it.
  - Each is turned and leaned at random and tinted one of four shades (`Config.Exterior.KitTint`). Only four, so Roblox can still draw the copies together.
  - Near trees cast shadows; far ones, bushes and the arborvitae don't.
  - The streetlamp's mesh stands over its parts. The head part, hidden, keeps its sodium lights and the lens's glare.
  - The stand-ins stay for any look that isn't imported.

## Tonemapper examples, and the owner's pick

Four spots in the same house at the same moment, with only `Lens.Tonemapper` changed (`tonemapper_compare.png`; full size `t1` to `t4`): the grand hall under its sconces, the dining room under its pendant, a dark corridor by torchlight, the kitchen at night.
- **Default** keeps the shadows deeper and the lamps warmer.
- **Retro** lifts the shadows a little and runs flatter and warmer-yellow, and its highlights bloom a touch more.

**The owner chose Retro** ("it looks like it has slightly more bloom"): `Config.Lens.Tonemapper = "Retro"`.

## Seen in Studio (build .190)

The owner imported `kit9.glb` (32 meshes). 180 kit meshes loaded, and the console was clean. Seed 1800820264, the mansion, solo:
- **The kitchen counter:** the three clothbound books, spines out, and the vase with its dried stems, tinted teal (`1_kitchen_before`, `1_kitchen_after`).
- **The study:** the rotary telephone on the desk, its dial to the room (2).
- **The playroom:** the mug, tinted cream, and HEARTHSIDE on the table, its cover reading the right way from the room (3).
- **A light switch:**
  - the plate, its screws and the toggle up (4);
  - after F2 `switch`, the light goes off and the toggle drops (4b);
  - the hands' aim from in front of it hits `KitSwitchPlate` and finds "Light switch: Switch the light on".
- **The finds** (F2 `find` for each): the cassette, the letters, the spool, the D-cells, the matchbox, the candle and the pill bottle, all in their looks (7).
- **The safe room's carton:** its printed side, with the game's label on top (8).
- **Outside:**
  - 1,029 kit meshes for 1,028 plants and the lamp, where the stand-ins took about 5,000 parts. The house built in 0.20 s (0.48 s before).
  - From the drive: the oaks and a spruce in silhouette against the sky, the streetlamp's head glowing and its sodium pool on the gravel (5).
  - The garden along the front wall, lit from the camera to see it: the low shrubs under the sills and an arborvitae between the windows (6).
- **Frame rate:** 60 (Studio's cap) from the drive looking into the woods, across the woods, and in a room. F2 `perf`: server heartbeat 0.1 ms.

**Gate A** moved, as expected: parts **2451**, hash **2057680657** (before: 2441 and 1845087318). The old house has 10 things on its tops, each now wearing its mesh: exactly the 10 new parts. Nothing else moved, because the draws are the same.

**Not checked in Studio:**
- the plate, the photo frame and the other stack of books (this house had none on its tops); they use the same code as the rest;
- picking each thing up and throwing it (the hands carry the blocks with the mesh welded on, as with kit6's things);
- the outside through every window: from inside, the night through a window is still near-black, as it was before (the eye adapts to the room);
- the garden's low shrubs read more as lumpy cushions than shrubs once squashed under the sills. They're dark at night, but the owner may want them redone.

They're in TC-294.

## Checks

623 tests, compile, selene 0 errors and 0 warnings, `rojo build`. TC-294. Two tests are new in `Kit.spec`:
- the house's everyday things have their looks, at the game's sizes;
- every plant outside stands on its foot, and the lamp is the lamp's height.
