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

## Imported and seen in Studio (build `2026-10-15.207`)

**The import:**
- The owner imported `mall1.fbx` (Home → Import 3D).
- Its 14 meshes and their maps came in under `Workspace.Scene`, each at its modelled size.
- Claude filed them: each mesh's id in `Data/Kit` and its four maps in `assets/kit/<piece>.model.json`.

**In play** (Rojo synced; the file lengths matched):
- The console printed 268 kit meshes loaded (the house's 254 and these 14), with no errors.
- Every dressing job ran (44) and 66 grey blocks were hidden. Each piece in place:
  - 2 benches;
  - 4 planters and 4 dead ficus;
  - the fountain's basin and centrepiece;
  - the directory and the photo booth;
  - 2 carts;
  - 4 lightbox cases;
  - 6 grille boxes;
  - 12 columns (the court's 4 and the dead mall's 8);
  - 58 lengths of parapet;
  - the chandelier.
- **The fountain is stepped into:**
  - On the court floor the character's root stood at 3.20; dropped into the basin, at 3.70. That is its drained floor, half a stud up, not the old solid top a stud and a half up.
  - It walked back out over the rim on its own.
  - The coins and leaves lie on the drained floor.

| Shot | What it shows |
| --- | --- |
| `ingame/1_spawn.jpg` | From the spawn: the directory, the fountain, a planter, the columns, the chandelier's globes (compare `../2026-10-15-lobby-lb1a/grandeur/1_spawn.jpg`) |
| `ingame/2_fountain.jpg` | The drained basin: terrazzo rim, mosaic, stains, coins and leaves on its floor, the centrepiece (the pole behind it is a gallery column) |
| `ingame/3_bench_planter.jpg` | A bench, a planter and its ficus, a column's bronze plinth, an east lightbox behind |
| `ingame/4_booth_directory.jpg` | The photo booth facing the court (PHOTOS, the samples), the directory's north face |
| `ingame/5_chandelier_gallery.jpg` | Looking up: the chandelier, the columns' collars, the parapet along the gallery |
| `ingame/6_parapet_corner.jpg` | The parapet's two runs meeting over the diner and the boutique, facing the void |
| `ingame/7_lightbox.jpg` | A west lightbox: the bronze case and its screws round "THIS SPACE AVAILABLE", nothing over the face |
| `ingame/8_cart.jpg` | A shopping cart on its wheels by the dead shop's grille |

Not judged here, for the owner (TC-310):
- the look by eye at the game's own exposure (the court is dark by design, so the pieces read mostly where the shops and bulbs light them);
- the dead mall's tipped-over cart, seen only through the grille.

**You can now delete `Workspace.Scene`** (the imported copy); the game builds every piece from its id.

## mall2: the shops, laid out by hand (build `2026-10-15.208`)

The owner started `mall2` and asked: "Be very deliberate with placement in the shops, since this hub isn't procedural like the main game, we can have extra attention to detail for the lobby".

**So the shops were laid out first, in the grey box, and only then modelled to that layout.** The grey box's shops were placeholder blocks. Each was redesigned as the room it is:
- each shop around its one job (the plan's table);
- the way in clear;
- aisles at least 4 studs wide for a busy lobby;
- every piece facing what it serves.

The layout was checked from above (`mall2/plan_*.jpg`) and at eye level before any modelling. Then each piece was built to its block's exact size.

**The rules, as a spec** (`MallLayout.misplaced`, `tests/specs/MallLayout`). In the five shops:
- no solid piece goes through a wall or the floor;
- no two stand in each other (a TV on its counter only touches it);
- nothing stands in the 3 studs inside a doorway, unless it's a window display put there on purpose (`window`: the boutique's dress forms, the electronics TV wall).

It caught the video counter's TV poking 0.15 studs into the way in.

**The shops:**

- **The diner** (the run records; booths to sit in with your squad):
  - The back bar along the wall holds the coffee station and its pots, the malt mixer, the pie case, the griddle and a steel backsplash.
  - The two record boards hang over it: the menu is Normal, the specials Hard. Their frames go round the boards' faces, where the records will be drawn.
  - In front: the counter, steel with a red band, a formica top, a foot rail, a lift-up flap, napkins, sugar and ketchup along it, the register at one end. Six chrome stools face it with knee room.
  - Booths in pairs down the court wall, either side of the way in, plus one out from each end wall: six booths, 24 seats. Every seat faces its table, back to back with the next booth.
  - The jukebox and an investigator's coat on the house's coat rack fill the two far corners.
  - The middle stays open, about 15 by 40 studs. The floor is black and white check (`floorKit`, panels).
- **The video store** (pick the case; the straight way to the garage):
  - The way through stays clear down the middle, 14 studs wide, from the door to the garage.
  - Tapes face out on shelving down both walls, HORROR on the left and ACTION · COMEDY on the right.
  - Two islands stand either side of the way: NEW RELEASES on the left (where the case tapes will go, LB2) and FAMILY on the right.
  - The rental counter is by the door, its TV turned to the way in.
  - A standee for THE HALFWAY HOUSE ("NOW ON VIDEO") stands by the window.
  - All 16 covers are invented.
- **The arcade** (its machines):
  - Cabinets face into the room down the back wall and the east wall. HOUSE CALL (the first game in the plan) takes the back wall, seen from the court. NIGHT DRIVE comes next, and two dead machines with OUT OF ORDER taped on their screens sit at the end.
  - The prize counter is shut under its dust sheet on the west wall, its pegboard prize wall behind with most hooks empty, and the CLOSED sign over it, as the owner wanted.
  - The change machine stands by the door. The floor is black carpet with neon squiggles.
- **Electronics** (the torch's looks):
  - The TV wall in the window: three wood-grain sets on a black stand of VCRs and decks, their screens to the court, a way in 6 studs wide either side.
  - Steel shelving of boxed sets down both walls.
  - At the back, the glass counter where they charge their torches. Under its glass, the three torch looks from the plan (yellow rubber, brass, chrome) lie on navy felt, marked NEW. The SERVICE · BATTERIES · REPAIRS sign hangs over it.
- **The boutique** (clothes, its racks by slot):
  - Two dress forms in the window either side of the way in (the house's dress form; they could wear the paid line at LB3).
  - A round rack of jackets, rails of tops and of bottoms, the shoe wall of sneakers and loafers, and a slatwall of tops and folded sweaters down the west wall.
  - The changing booth in the back corner: a curtain, a long mirror inside, FITTING ROOM over it. It's built hollow for LB3, but its block stays solid until then.
  - The cash wrap at the back, with its till, a jewellery case and THANK YOU bags.

**The kit** (`tools/blender/kitlib/mall2.py`, kit.py `mall2`): 31 new pieces. Two of the house's own pieces are reused, the dress form and the coat rack, and they were in place as soon as this synced, because they're already imported.

**Checked before the import** (`mall2/sheet.jpg`, `mall2/backfaces.jpg`). The first bake's faults are fixed:
- **The shoe wall was 32,764 triangles**, over Roblox's 20,000 per mesh: 60 shoes modelled as subdivided cushions. They're bevelled boxes now, 3,724 triangles for the whole wall.
- **Pictures on wide cards were lost:** the prize counter's prizes, the torches under the counter's glass, the change machine's CHANGE header, FITTING ROOM. Blender's island packer had squeezed each into a sliver at its texture's edge.
  - `kitlib/bake.py` now lays a picture material's cards out itself when the material asks (`uv_direct`, `_shelve`): row by row, every card at one scale, as big as fits, never wider than the texture.
  - mall2's pictures all ask. The house's batches don't, so nothing already imported changes.
- **The jukebox didn't read as one:** the coloured bands were sunk in a side-arched cabinet. It's rebuilt as the classic shape, arched at the front, with three tubes (amber, red, blue) up its sides and over the arch, a dark dome inside, the selection strips and the grille.
- **The changing booth had two hairline holes:** the curtain's open edges, and a wall face sharing a plane with another. The curtain is a closed pleated solid now, and the back wall stands between the sides.
- **The shelves' backs overlapped their sides** on the same plane (a red strip in the hole render, against the wall, where it would flicker in Roblox). The back, header and plinth of the video shelving, the islands and the electronics shelving now fit between the sides.
- Left as it is: a speck at one corner of the record boards' frames, where its lengths meet, against the wall.

### mall2 imported and seen in Studio (build `2026-10-16.209`)

**The import:**
- The owner imported `mall2.fbx` (Home → Import 3D): all 31 meshes and their maps, at their modelled sizes, uploaded to their account.
- Claude filed them: each mesh's id in `Data/Kit` and its four maps in `assets/kit/<piece>.model.json`.
- Rojo synced both (the file's exact length in Studio; 31 new looks in `ReplicatedStorage.Kit`, no duplicates).

**In play:**
- 299 kit meshes loaded and no errors from the game.
- All 114 dressing jobs ran and 134 grey blocks were hidden, every piece in place:
  - the diner: back bar, counter, 6 stools, 12 booth seats at 6 tables, 2 board frames, the jukebox, the coat rack, 15 floor panels;
  - the video store: 6 wall shelves, 2 islands, the counter and its TV, the standee;
  - the arcade: 6 cabinets, the prize counter and wall, the change machine, 9 carpet panels;
  - electronics: 3 TVs on their stand, 4 shelves, the glass counter;
  - the boutique: 2 dress forms, the round rack, 2 rails, the shoe wall, the slatwall, the changing booth, the cash wrap.

| Shot | What it shows |
| --- | --- |
| `mall2/ingame_1_diner.jpg` | The counter and its six stools under SPECIALS · HARD and MENU · NORMAL, the check floor (compare `before_diner.jpg`) |
| `mall2/ingame_2_diner_booths.jpg` | The booths in pairs and at the end wall, each seat facing its table, the jukebox in the corner |
| `mall2/ingame_3_video.jpg` | The clear way to STAFF ONLY · GARAGE, tapes face out under HORROR and ACTION · COMEDY, the islands, the counter |
| `mall2/ingame_4_arcade.jpg` | HOUSE CALL and NIGHT DRIVE on the back wall, NIGHT DRIVE and the two dead STAR PATROLs on the east, the neon carpet |
| `mall2/ingame_5_arcade_prizes.jpg` | PRIZES · CLOSED over the pegboard, the counter shut under its sheet, the change machine |
| `mall2/ingame_6_electronics.jpg` | The TV wall on its stand of decks facing the court, the shelves, the service counter |
| `mall2/ingame_7_boutique.jpg` | The dress forms facing the court, the slatwall, the round rack, the rails, FITTING ROOM, the shoe wall |

**Notes:**
- This was checked in a local copy of the place (`Consensus.rbxlx`, not the published place), so profiles didn't save. The footstep samples (`Assets.Footsteps`, other creators' audio) also failed to load there: "Asset type does not match", since Roblox grants that audio only to the published place.
- The pieces are Kit meshes like the house's, so they'll be in the published place too once its Rojo is connected.

For the owner: TC-311 by eye, and you can delete `Workspace.Scene` (the imported copy).
