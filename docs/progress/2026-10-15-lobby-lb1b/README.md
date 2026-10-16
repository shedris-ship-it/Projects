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

## mall3: the garage, the vault's frame, the escalators, the neon (build `2026-10-16.210`)

The owner started `mall3`.

**The garage, laid out by hand as the shops were** (`mall3/plan_garage_before.jpg`, `plan_garage_after.jpg`). Its sense held: the way to the run stays clear down the middle, from the video store's back door to the roll-up door, with the investigators' camp down the west wall and the workshop down the east. Five things changed:
- **The desk** was 4 studs high and stood 2 studs off the wall. It's a desk's height now (3.2), against the wall under the case board, with a swivel chair at it and the CB radio on it.
- **The generator** had three cans to run on. Two 55-gallon drums of diesel stand beside it, a hand pump in one.
- **Two stacks of tyres** stand against the east wall by the last bay.
- **The cars** stand nose to the roll-up door, as cars leaving through it would (LB2's party cars come later).
- **The wall pieces** (whiteboard, case board, photos, plan, desk, pegboard, payphone, power box, workbench) are now turned blocks facing into the room, so each modelled front faces the right way.

`MallLayout.misplaced`'s spec now covers the garage too; it passes.

**The kit** (`tools/blender/kitlib/mall3.py`, kit.py `mall3`), 33 pieces:
- **The workshop:**
  - the generator, a diesel set on its skid in army olive: radiator grille, control panel (dials, key, breaker, stop), louvres, the muffler where the exhaust goes up through the roof, the fuel line, oil on the skid;
  - jerry cans, the two diesel drums, a wooden cable reel wound with the orange cable;
  - the power box (the investigators' wiring back into the mall: its switch thrown, conduit, their cables out of it);
  - the car bits pegboard (hubcaps, a steering wheel, fuzzy dice, a fan belt, wrenches, an air freshener);
  - the payphone in its hood, the tyre stacks.
  - The house's own workbench and car.
- **The camp:**
  - a cot with a sleeping bag, a cot with a folded blanket;
  - the camp table with a percolator on a camp stove, two thermoses, mugs, a road map ringed in red;
  - the whiteboard (wiped ghosts of old writing; the game's TONIGHT sign is written over it);
  - the cork case board, two snapshots (the house at dusk; a figure at a window), the house's blueprint, pinned;
  - the steel desk, the swivel chair, the CB set, banker's boxes of evidence.
- **The garage's lights:**
  - the strip light in its channel with a wire guard (a lit one's tubes are the game's Neon part, slimmed to fit under it);
  - the work lamp on its tripod, its housing round the game's lit head.
- **The roll-up shutter:** galvanised slats, the bottom bar, handles and lock, the guides. Stretched to every shutter: the garage's door, the dead mall's ten shopfronts, the upper floors' shuttered fronts.
- **The vault:**
  - a lattice rib for each of the eight: outer and inner chords with a zig-zag web, on base plates;
  - a plaster lunette at each end with a fan light of steel bars in dark glass.

  They're modelled for its span (40) and rise (11), which the Kit spec holds them to. The glass between the ribs stays the game's see-through glass, so the moonlight still comes through.
- **The escalators:** the stopped pair, steps from comb plate to comb plate, cream panelled balustrades and black handrails that follow the steps (flat, up, flat), the truss clad underneath.
- **The neon:**
  - each shop's word bent in real tubes from a stroke alphabet drawn in the script (no font files):
    - BOUTIQUE slanted, with a swoosh;
    - VIDEO bold, in a border;
    - ARCADE blocky;
    - ELECTRONICS wide, underlined;
    - DINER slanted, with a swoosh;
  - each on a black raceway with its glass holders and transformer.
  - The tubes carry no maps. The game draws them Neon in the sign's own colour, so they glow and brown out with the generator, and the old text is hidden once they're in.

**How the game wears them:**
- the blocks' `kit` and the groups as before;
- `Data/Mall` Signs `neon`, Vaults `kit`;
- `MallBuilder` dresses the strip lights, work lamps and shutters itself.

Everything stands as grey box until imported, and a piece not yet imported changes nothing.

**Checked before the import** (`mall3/sheet.jpg`, `mall3/backfaces.jpg`):
- Every piece builds at the size its block, group or opening expects, and every offset in `Data/Kit` matches kit.py's report. The neon, the shutters and the raceway face out of their frames, so their offsets are mirrored as the ad cases' are.
- The pieces are light: at most 7,160 triangles (the cot with its sleeping bag), most under 2,000.
- **The first bake's faults are fixed:**
  - Hairline seams where boxes met on one plane (the payphone's hood, the work lamp's housing, the whiteboard's, case board's and pegboard's frame corners; the whiteboard's face on its backing, which tinted it). Each now fits between its neighbours.
  - The evidence boxes' label was cut off at "CASE 88-"; it reads CASE 88.
- The escalators were rendered from above and below as well, since the preview shows them edge on: steps on both lanes, three balustrades, the handrails, the cladding.
- **In Studio before the import** (build .210): 189 dressing jobs ran with no warnings and no errors from the game. The house's car and workbench, already imported, went straight in (`mall3/house_car_workbench.jpg`): the cars nose to the door, the bench facing the room. Everything else stays grey box until imported.

**For the owner:** import `build/kit/mall3/mall3.fbx` (Home → Import 3D). It's 33 meshes, but only 28 come with maps: the five neon words have none, since the game draws them glowing in their own colour. Then Claude files the ids and checks TC-312.

### mall3 imported and seen in Studio (build `2026-10-16.211`)

**The import:**
- The owner imported `mall3.fbx` (Home → Import 3D): all 33 meshes, the five neon words without maps as intended.
- Claude filed the 33 ids in `Data/Kit` and the 28 sets of maps in `assets/kit`, and Rojo synced them (no duplicate looks).

**In play:**
- 299 kit meshes and the batch loaded.
- All 189 dressing jobs ran and 509 grey blocks were hidden. Every piece is in place:
  - the garage's 29 (with 4 strip lights and the 2 work lamps);
  - 21 roll-up shutters (the garage's door, the dead mall's ten fronts and the ten upper shutters);
  - 8 vault ribs and 2 lunettes, the escalator pair;
  - the five neon words with their raceways.
- The neon is drawn Neon in each sign's colour, no maps, and the old text is switched off.

**Two things fixed on seeing it:**
- **The raceway behind each neon word read as a line struck through it** (`mall3/ingame_0_neon_before_raceway.jpg`, `ingame_2_neon_west.jpg`). It now runs under the word, the letters standing up from it, and on the shops it tucks behind the grille box (`ingame_1_neon.jpg`).
- **The camp's work lamp faced the bays while its light fell on the camp.** The work lamps take an `aim` now (Data/Mall's lights): the camp's faces the case board and throws its tripod's shadow up the wall; the workshop's faces the generator (`ingame_4_camp.jpg`).

| Shot | What it shows |
| --- | --- |
| `mall3/ingame_1_neon.jpg` | BOUTIQUE, VIDEO and ARCADE in neon over their fronts |
| `mall3/ingame_2_neon_west.jpg` | ELECTRONICS and DINER (taken before the raceway moved) |
| `mall3/ingame_3_vault.jpg` | Looking up: the ribs over the dark glass, the east lunette over the two-storey grille |
| `mall3/ingame_4_camp.jpg` | The camp: cots, the camp table, TONIGHT on the whiteboard, the case board, the desk and chair, the boxes, the lamp aimed at the board |
| `mall3/ingame_5_workshop.jpg` | The generator, drums, cans and reel, the car bits pegboard, the payphone, a lamp, a strip light |
| `mall3/ingame_6_escalators.jpg` | Through the grille: the stopped escalators between the dead fronts' shutters |

For the owner:
- TC-312 by eye.
- You can delete `Workspace.Scene` (the imported copy).
- The night keeps the vault's lattice dark until lightning lights it. If you'd like it read more, a faint light on the ribs is a later tweak for the lighting pass.

## The lighting pass and the 50-player measurement (build `2026-10-16.212`)

The owner asked for LB1b's last two steps: the lighting pass, with every piece in, and the 50-player measurement.

### The lighting pass

Each area was walked at the game's own exposure (the hub's lens, no test light). The mall's mood stays as the owner set it: dark but for the shops, the ads and what the investigators hung on their generator. The changes are where that mood hid something a player needs:

- **The garage's way out was a black void** at the end of the walk from the video store's back door (`lighting/garage_way_before.jpg`). Two lights fix it (`garage_way_after.jpg`):
  - A strip light now hangs over the bays (one of the three there; the other two stay dead), so the cars and their lines read.
  - A caged lamp on a bracket over the roll-up door (`Config.Mall.Lights.dock`, a warm downward spot) lights the door and the CARS sign: the way out, seen from the far end.
- **Shadows follow the graphics preset.** The camp's work lamp is the mall's one shadow-caster. It casts its tripod's shadow up the case board on Cinematic and Balanced, and none on Performance, as the house's lights do (`MallShadow` tag, `MallController`).
- **The work lamps are aimed** at what they light (mall3's import pass): the case board, the generator.
- **Left as it is, on purpose:**
  - The vault's lattice is dark against the night until lightning lights it; the owner wanted the dark beyond the lit corner.
  - The dead concourse stays lit only by its battery emergency lamps and the EXIT sign.

**The light budget**, counted in play:
- 52 lights in the hub (2 spot, 50 point), at most one casting shadows;
- the five neon words are Neon parts, so they cost no light beyond their sign's own glow;
- 297 meshes in the mall, 332 in the kit.

### The 50-player measurement

**How:** F2 `crowd <n>` (Services/OutfitService `DebugCrowd`, Services/DebugService) stands n dressed stand-ins over the mall's open floor. Each is a real classic body in a real outfit (both bodies, every outfit in turn) with Roblox's idle playing.
- They are spread as a full lobby would stand: about half in the court, a quarter in the garage, the rest in the shops.
- Their floor comes from `MallLayout.openSpots` (spec'd: clear of every solid piece and column; 80+ spots, 40+ in the court).
- `crowd clear` takes them away.
- F2 `perf` now also counts the lights, the shadow-casters, the meshes and the players and stand-ins. The F2 overlay's new "render" line shows the frame's CPU and GPU time and the meshes' and textures' memory.

**The numbers** (Studio's play client on the owner's PC, the Cinematic preset, 8 seconds per view):

| | Frame rate | Render CPU | Render GPU | Mesh memory | Texture memory | Client instances |
| --- | --- | --- | --- | --- | --- | --- |
| The court, alone | 60 fps | 3.8 ms | 5.1 ms | 45 MB | 266 MB | 52,400 |
| The court, 49 stand-ins + you | 60 fps | 6.0 ms | 6.1 ms | 49 MB | 274 MB | 68,700 |
| The garage, with them | 60 fps | 4.3 ms | 5.4 ms | | | |

- A full lobby costs about 2 ms of CPU and 1 ms of GPU a frame and 12 MB of memory on this machine, well inside a 60 fps frame (16.7 ms).
- Dressing 49 took 2 seconds on the server, and its heartbeat stayed at 0.1 ms.
- The worst single frame was 19 to 24 ms, with or without them: Studio's own hitches, not the crowd.

**What this doesn't cover:**
- A phone. The owner's check: open the place on a phone (or Studio's device emulator) and run `crowd 49` and `perf` there.
- Real players' networking. Stand-ins are anchored, so their movement isn't replicated; a full server's 50 moving characters also cost bandwidth and the server's physics, which only a live test shows.
- The shop's future outfits (LB3) are the same kind of welded pieces, so a lobby of them should cost what this one does.

`crowd`, `perf` and the overlay's render line are kept for the next measurement (LB3's shop full of outfits, V9's performance pass).

| Shot | What it shows |
| --- | --- |
| `lighting/garage_way_before.jpg`, `garage_way_after.jpg` | The way out from the video store's back door, before and after |
| `lighting/crowd_court.jpg` | 49 stand-ins over the court and in the shops |
| `lighting/crowd_garage.jpg` | Those waiting in the garage, by the cars and the lit door |

**LB1b is done.** Next in the plan: LB2, parties and the video rental.
