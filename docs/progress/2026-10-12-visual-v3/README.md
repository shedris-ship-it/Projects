# The visual rework, V0 and V3 (part 1): the kit pipeline, the golden room's first batch, the import route (builds `2026-10-12.175` and `.179`)

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

## Waiting on the owner

- **Import again:** `build\kit\spike\spike.glb` (rebuilt with the lamp's glow mask; it also shows whether the importer carries emissive maps) and `build\kit\golden\golden.glb` (the golden room's 8 pieces). Then the `Scene` models in Workspace can be deleted: the game builds the kit from ids.

## Shots

- `0_spike_blender.png`: the spike in Blender.
- `1_golden_batch_blender.png`: the golden batch, each piece under a warm lamp: armchair, bench, coat rack, dining table; clock case, rug, bookcase, sofa.
- `2_spike_imported.jpg`: the spike as imported (door, lamp, chair).
- `3_chair_backwards.jpg`: the first try, a dining chair (mesh) with its back to the table; the grey-box in blue faces it.
- `4_dining_chairs.jpg`: fixed, the dining room's chairs.
- `5_door.jpg`: a modelled door, ajar.
- `6_lamp_unlit_shade.jpg`: the lamp, its shade unlit.
- `7_lamp_glow_test.jpg`: the shade glowing through a stand-in mask.
