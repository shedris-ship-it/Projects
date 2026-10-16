# The lobby rework, LB1b: the mall's kit, its first batch (build `2026-10-15.206`)

The owner walked build .205 ("I walked it and the height works") and asked to start LB1b, the Blender batch for the mall. As with the house's kit (the visual rework's kit3 to kit10), it comes in batches, each imported once by the owner:

- **`mall1`, the court** (this pass): what every player sees close up each time they're in the hub.
- `mall2`, the shops: the diner, the video store, the arcade, the electronics store, the boutique.
- `mall3`, the garage and the dead mall: the investigators' corner, the payphone, the vault's frame, the escalators, the upper fronts, the neon letters.
- Then the lighting pass with everything in, and the 50-player measurement.

## The pieces (`tools/blender/kitlib/mall.py`, kit.py `mall1`)

A 1980s mall, closed. The materials:
- dark bronze anodised metal;
- oak;
- terrazzo with its chips, polished once and dull now;
- brown quarry tile;
- the fountain's aqua mosaic, gone dry.

Nothing glows: the mall's own lamps are dead, and only what the investigators hung on their generator is lit.

| Piece | Dresses | Triangles | What it is |
| --- | --- | --- | --- |
| MallBench | the `Bench` blocks | 1,100 | five oak slats bolted to two cast pedestals; one lies tipped over |
| MallPlanter | the four `Planter`s | 3,592 | quarry tile under a terrazzo cap with a rounded nose, dried soil, the last leaves |
| DeadFicus | the four `DeadPlant` sticks | 676 | a bare trunk forking into thin branches, a few brown leaves hanging on; stretched to each stick's height |
| FountainBasin | `FountainBasin` | 3,060 | drained: terrazzo outside, a polished rim, the mosaic sunk a stud inside with a dark tide line, stains and a bronze drain |
| FountainCentre | `FountainPillar` | 1,392 | a drum, a fluted shaft, the bowl it spilled over (stained under the lip), a finial and its nozzle |
| MallDirectory | `Directory` | 1,276 | a bronze case, the mall's map on both faces (numbered shops, the list, the closed hall hatched, a red YOU ARE HERE where it stands), INFORMATION over it |
| PhotoBooth | `PhotoBooth` | 1,220 | red and cream enamel, the sign box (PHOTOS, 4 POSES), sample strips, the coin plate and the print slot, a red curtain most of the way across the way in |
| ShoppingCart | the two `Cart`s | 1,572 | chromed wire tapering to its nose, the orange grip, the tray, four casters; its wheels reach the floor under the basket the block stood for |
| LightboxWide, LightboxSmall | each ad's `AdFrame` | 1,132 each | a bronze poster case, its bezel's inside edge exactly on the ad's face, so nothing covers the ad (`tests/specs/Kit`) |
| GrilleBox | every shopfront's grille box | 516 | a sheet-steel hood, end brackets, the grille's bottom bar with its lock and handles; stretched to each front |
| MallColumn | the gallery's columns | 1,152 | a bronze plinth, the plaster shaft with a bronze band at the knee, a flared collar under the slab |
| GalleryParapet | the gallery's parapet and handrail | 540 | the plaster parapet, a terrazzo cap, a bronze band and a bronze fascia over the slab's edge, the brass handrail on posts; laid in lengths of about 10 along each run |
| MallChandelier | the `ChandelierRing` and its globes | 5,364 | a brass ring on six spokes, six opal globes, an inner ring of six smaller ones lower down and a big one in the middle, every bulb out |

## How the game wears them

- **The grey box stands until the meshes are in.** `World/MallBuilder` queues a dressing job for every piece. After the build it waits for `Kit.preload` (the meshes load with the house's) and runs them, so a piece that isn't imported yet stays a block. In Studio before the import, 44 jobs ran with no errors and the grey box was unchanged.
- **Data/Mall:**
  - a block names its piece with `kit`;
  - a piece that stands for several blocks (the chandelier) is in `Mall.KitGroups`, with the blocks it hides;
  - the ads name their case.
- **The fountain becomes a basin you step into** (`hollow`):
  - The solid block stops colliding.
  - An unseen floor and a ring of 16 wall pieces take its place.
  - The coins and leaves lying on its old top settle onto the drained floor.
- **The gallery's edge** is laid in lengths of about 10 studs per run, each from the slab's underside to the rail's top, facing the void. The columns stand where they stood.
- **The photo booth turned to face the court** (`rot` 180). The grey box had no front.
- **Specs:** `tests/specs/Kit` checks that every piece the mall names is in the kit, and that each ad's case is its face plus the bezel all round.

## Checked

- Every piece built at the size its grey box expects (kit.py's report, in `Data/Kit`).
- The previews (`previews/sheet.jpg`, each piece under one warm lamp) and a render where any face seen from behind shows red, which would be a hole in Roblox (`previews/backfaces_after.jpg`: none left but the cart's open wire ends, a few hundredths of a stud across):
  - **The first bake had holes in one piece: the bench's pedestals** (`previews/backfaces_before.jpg`).
    - Blender's own triangulation folded over their waisted outline. The triangles covered 2.1 and 3.9 square studs where the outline is 1.6, so in places you saw through to the far end's back.
    - `_side_prism` now tessellates its ends with `mathutils.geometry.tessellate_polygon`, which keeps inside a concave outline (checked: both ends 1.5724, the outline's area).
    - It also turns the whole solid round if its first end faces in.
    - The house's `fittings._prism` triangulates the same way. The house's pieces passed their own hole tests, so none of theirs is concave enough to show it.
  - **The directory's header and the booth's sign came out as smeared stripes,** and the booth's sample strips hid behind their own frame.
    - Blender's island packer had squeezed each piece's second picture into a sliver of its texture.
    - Each piece now carries one picture, its pictures stacked in it (`_atlas`, each card mapped to its part). The directory's header reads INFORMATION; the booth's sign reads PHOTOS and 4 POSES.
    - The frame now stands behind the strips.
  - The first bake's planter read as a bathroom's pink tile; it's brown quarry tile with a thin dark grout now.
  - The first bake's leaves were flat little planks; they're leaf-shaped now.
- In Studio, before the import: the dressing pass runs (44 jobs, no errors), the grey box is unchanged, no console errors.

## For the owner

1. Import the batch: in Studio, **Home → Import 3D**, pick `A:\111- Projects\Github\Projects\build\kit\mall1\mall1.fbx`, and import it with the importer's defaults. It uploads 14 meshes and their maps to your account, as the house's batches did.
2. Tell Claude when it's in. Claude reads the new ids in Studio, files them (Data/Kit `id`, `assets/kit/<piece>.model.json`), and checks every piece in place (TC-310).
3. You can delete the imported `Scene` model from Workspace afterwards, since the game builds the pieces from their ids.
