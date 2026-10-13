# The visual rework, V0 and V3 (part 1): the kit pipeline, the golden room's first batch, the import route (builds `2026-10-12.175`, `.179` to `.182`)

The models come from Blender, built by script (the owner's choice, 2026-10-12). Blender 5.2.2 runs headless from `A:\Tools\blender-5.2.2-windows-x64\blender-5.2.2-windows-x64\blender.exe`.

## The pipeline (`tools/blender/`)

- `kit.py <batch>`: builds a batch's pieces procedurally, each at its `Data/Props` size, standing on the floor with its front facing the room. Each piece is UV-unwrapped and baked to colour (ambient occlusion multiplied in), normal, roughness and metalness maps at 1024 px. Exports one `.glb` and one `.fbx` to `build/kit/<batch>/` (git-ignored: everything regenerates from the scripts) plus `report.txt` with sizes and triangles.
- `kitlib/`:
  - **shapes:** bevelled boxes, lathes (turned legs, finials, lamp bases), cushions that bulge, rolled arms, panelled door slabs, per-piece colours;
  - **materials:** procedural walnut and oak, old paint, linen, tarnished brass, damask upholstery, velvet, bindings coloured per book, a drawn picture;
  - **bake:** the maps, with a second UV layer when a piece reads an authored pattern;
  - **furniture:** the golden batch.
- `preview.py <batch>`: renders each piece under one warm lamp, to judge it before Studio.
- Batches: `spike` (a colonial chair, a floor lamp, a six-panel door) and `golden`:

| Piece | Size (studs) | Triangles |
| --- | --- | --- |
| Dining table | 6 × 3.4 × 12 | 3,764 |
| Sofa | 9 × 3.5 × 4 | 4,388 |
| Wing-back armchair | 4 × 4 × 4 | 3,524 |
| Bookcase with books | 8.2 × 9 × 2.1 | 7,924 |
| Grandfather clock case | 2.7 × 8.4 × 2.1 | 1,892 |
| Coat rack with coats | 1.3 × 7 × 1.3 | 1,688 |
| Hall bench | 8 × 2.6 × 2.3 | 4,136 |
| Persian rug | 10 × 0.06 × 14.8 | 1,194 |

Fixed on the way: pieces turned after being moved swung round the world's origin (a 15.8-stud clock); the rug's pattern image was lost by setting its colour space after its pixels; overhangs trimmed to their footprints; the sofa and armchair lightened from 12,600 and 9,200 triangles.

## In the game (`World/Kit`, `Data/Kit`, `Kit.spec`)

- The grey-box stays as the game's body: solid, queryable, named, jointed, lit, but hidden. The kit's mesh is what you see, at the size it was modelled at; it never collides and never catches a ray.
- It sits inside the prop's model, so pushing moves it. Picked up, it's welded in, weightless, and never the weld root.
- A plain door's slab and panels take the door mesh, which swings with the door.
- Kinds whose mesh isn't in the place stay as blocks.
- `Kit.spec`: every mesh within 8% of its prop's size and never smaller than half of it.
- Checked in Studio with a stand-in mesh: 9 chairs dressed, 6 grey-box parts hidden each, a grabbed chair carried its mesh welded and weightless. Gate A unchanged.

## The import route, settled (build `.179`)

The owner imported the spike (`spike.glb`) with Studio's 3D importer on 2026-10-12. The importer made a `Scene` model in Workspace: the chair, the door and the floor lamp, each a MeshPart with a SurfaceAppearance (colour, normal, roughness, metalness), uploaded to the owner's account. It was imported twice; both copies use the same uploads.

**What Roblox lets each side do** (tested in Studio):

| | Build a mesh from its id | Set a SurfaceAppearance's maps |
| --- | --- | --- |
| A game script (server) | yes: `AssetService:CreateMeshPartAsync` | no |
| A plugin (the Rojo plugin, MCP) and `rojo build` | no: `MeshId` is not writable | yes |

**So the kit is a hybrid**, all text in the repo, nothing hand-made in the place:
- `Data/Kit` gives each imported piece its mesh's asset `id`.
- `assets/kit/<name>.model.json` is its SurfaceAppearance (the four map ids), which Rojo maps to `ReplicatedStorage.Kit` (`default.project.json`). `rojo build` writes them into a fresh place.
- At server start, `Kit.preload` (from `WorldService:Start`, and waited on by `WorldService:Build`) builds every mesh from its id at the same time, puts on its SurfaceAppearance, and keeps them as templates. Console: `[Consensus] kit: 3 meshes loaded (Chair, Door, FloorLamp)`. F2 `kit` lists them.

**Fixed on the way:** the importer turns a model's front from glTF's +Z (where `kit.py` builds it) to Roblox's -Z, so the first dining chairs had their backs to the table (shot 3). `World/Kit` now turns every imported piece by half a turn (`IMPORT_TURN`).

**Seen in Studio** (seed 1800820264):
- 11 chairs and floor lamps and 13 doors dressed in the mansion, 21 meshes in the old house.
- Spindle-back chairs face the table and cast spindle shadows (shot 4).
- The six-panel door swings with the real door and keeps the game's brass knob (shot 5).
- The floor lamp's brass and linen read well, but its shade didn't glow (shot 6). The old block shade was Neon, dimmed by its light (`EffectsController`).

**The lamp's glow:**
- `kitlib/bake.py` now bakes an emissive mask for materials marked `glow` (the lamp's linen): `FloorLamp_emissive.png`, white only on the shade. It's written into the glb as the emissive texture.
- `EffectsController` drives a kit mesh's `EmissiveStrength` and `EmissiveTint` from its lamp's light (`Config.Kit.ShadeGlow`; dark when off, hunt red in a hunt).
- Tested with a stand-in mask (the lamp's colour map, set in Studio for one test and then removed): the shade glows warm (shot 7). The real mask isn't on the owner's account yet.

**Gate A re-baselined** (the plan's approval covers the visual steps): **parts 2290, hash 387097105**. That's the 21 kit meshes added to the old house; nothing else moved.

## The golden batch in the game (build `.180`)

The owner imported `golden.glb` and the rebuilt `spike.glb`:
- **Glow maps work.** The importer carried the lamp shade's emissive mask into the SurfaceAppearance, so glowing pieces need no separate upload. `assets/kit/FloorLamp.model.json` has `EmissiveMaskContent`, which `rojo build` writes.
- **The other pieces:** the chair and the lamp got new meshes (new ids); the door is unchanged (the importer matched its uploads).
- **The ids** come straight from Studio (`HttpService:JSONEncode` over the imported `Scene` models), and the eleven `assets/kit/*.model.json` files are written from them.
- **In the game:** all 11 meshes load (`[Consensus] kit: 11 meshes loaded`).
  - The dining table: turned legs and a dark top (shot 10).
  - The grand hall: the Persian rug, and the clock case keeping the game's face and hands (shot 11).
  - The sofa, in the old house's living room (shot 12).
  - The armchair, bench and coat racks.
  - The floor lamp's shade glowing through its real mask (shot 13). `Config.Kit.ShadeGlow` is 1.1: at 1.6 it blew out to white.
  - The owner: the shade should "add a soft light around it, so far it looks like light only passes through on the bottom". The modelled shade cast shadows, so it hid its own bulb (shot 14); the old block shade cast none. Kit entries can now say `shadow = false`, and the floor lamp does: its light reaches the walls and ceiling all round again (shot 15).

**One kind stands for several things.** `Shelf` is the living room's and the study's bookcases, but also the dining room's china cabinet and the shelving in the laundry, garage, pantry, sewing room, boiler room, storeroom, workshop and cold store. `Chair` is also the nursery's rocker and the music room's stool. A kit entry can now list the item names it dresses (`names`, Lua patterns on the `Data/Rooms` ids, `Kit.wears`):
- the bookcase dresses only `books*`;
- the spindle chair dresses only `chair*`;
- the rest stay grey-box until their own pieces (V4).

**The bookcase** (the owner: "from the importer it didn't look like it had a texture, the actual shelf part of it supposed to be made of wood"):
- **The cause:** each of its hundreds of books had six faces with their own patches of the one 1024 px texture, which left the wood a corner of it. The wood came out blurred and pale (shot 8; the old `Shelf_color.png` was nearly all books).
- **The fix in the pipeline, for every piece from now on:**
  - `shapes.cull` deletes faces nobody sees (each book's back against the case and its bottom on the shelf).
  - A material can claim a share of the texture: `mat["uv_share"]`, packed into its own band by `bake._pack_by_share` (Blender's `pack_islands` into the band). The books take 0.3 and the wood the rest.
  - `kit.py <batch> <Piece>` builds one piece on its own (`build/kit/golden_Shelf/`), so a fix needs only that piece imported.
- The rebuilt case (shot 9): grain on the frame and shelves, a dark back behind the books.

**Gate A re-baselined** (the old house now has the golden pieces too): **parts 2308, hash 897645278**.

## The bookcase, rebuilt (build `.181`)

- **Imported** (`golden_Shelf.glb`, mesh `78480435296134`) and in the game. Under a lamp to one side, the wood is sharp: the frame, the grained shelves, a dark back behind the books (shot 16).
- **Under the torch, the back flared pale between the books** (shot 17).
  - First guess: the varnish. At roughness 0.45 the case is glossy, and the torch shines from the eye.
  - So the case went to roughness 0.62, and the back became its own plain, darker, unfinished board at 0.85 (`kitlib/furniture.py` `CaseBack`). Imported again: mesh `76759148172076`.
  - It still flared (shot 18). Turning off eye adaptation (`LensBypass` "exposure") changed nothing.

## Pieces placed by their centre (build `.182`)

**The real cause of the flare:**
- Studio's importer centres a mesh on its box, and the game puts that centre at the grey-box's middle.
- The bookcase's cornice overhangs the front, so its box's middle is 0.06 studs in front of the case's middle. The whole mesh sat 0.06 too far back, and its thin back panel went into the wall.
- What showed between the books was the wall's plaster, in front of the panel.
- (The red-sheet test had put the sheet inside the wall too, so it proved nothing.)

**The fix:**
- `kit.py` reports each piece's `centre` (where its box's middle is in the prop's frame, `{ x, z }` with the front +Z). `kit.py <batch> --bounds` prints them without baking.
- `Data/Kit` gives the lopsided pieces their centre: the bookcase `{ 0, 0.06 }`, the chair `{ 0, -0.042 }`, the sofa and armchair `{ 0, -0.012 }`, the clock `{ 0, 0.01 }`.
- `World/Kit` places each mesh by it. `Kit.spec` keeps it a small nudge.

**Under the torch now:** dark grained wood between the books (shot 19). The matte varnish stays: it suits a torch-lit house anyway.

**Gate A re-baselined:** parts 2308, hash **919916609** (the nudged meshes).

## Waiting on the owner

- Nothing for the kit right now. The `Scene` models in Workspace (every import so far) can be deleted: the game builds the kit from ids.

## Shots

- `0_spike_blender.png`: the spike in Blender.
- `1_golden_batch_blender.png`: the golden batch, each piece under a warm lamp: armchair, bench, coat rack, dining table; clock case, rug, bookcase, sofa.
- `2_spike_imported.jpg`: the spike as imported (door, lamp, chair).
- `3_chair_backwards.jpg`: the first try, a dining chair (mesh) with its back to the table; the grey-box in blue faces it.
- `4_dining_chairs.jpg`: fixed, the dining room's chairs.
- `5_door.jpg`: a modelled door, ajar.
- `6_lamp_unlit_shade.jpg`: the lamp, its shade unlit.
- `7_lamp_glow_test.jpg`: the shade glowing through a stand-in mask.
- `8_bookcase_imported_blurred_wood.jpg`: the first import of the bookcase, its wood blurred and its back pale.
- `9_bookcase_rebaked_preview.png`: the rebuilt bookcase in Blender's preview.
- `10_dining_table.jpg`: the dining table and its chairs.
- `11_grand_hall_rug_clock.jpg`: the grand hall's rug and clock.
- `12_sofa.jpg`: the sofa.
- `13_lamp_shade_glowing.jpg`: the floor lamp with its real glow mask, at `Config.Kit.ShadeGlow` 1.1 (1.6 blew it out to white).
- `14_lamp_light_trapped.jpg`: the modelled shade shadowing its own bulb: light only above and below.
- `15_lamp_light_all_round.jpg`: the lamp casting no shadow of its own: the corner lit all round.
- `16_bookcase_sharp_wood.jpg`: the rebuilt bookcase in the old house, under a lamp to one side: sharp wood, a dark back.
- `17_bookcase_torch_flare.jpg`: the same under the torch: the glossy back flares pale between the books (fixed in the next build of the piece).
- `18_bookcase_back_in_the_wall.jpg`: the matte bookcase under the torch, still pale between the books: the wall's plaster in front of its back.
- `19_bookcase_centred.jpg`: placed by its centre: dark grained wood between the books under the torch.
