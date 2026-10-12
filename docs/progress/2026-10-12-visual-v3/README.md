# The visual rework, V0 and V3 (part 1): the kit pipeline and the golden room's first batch (build `2026-10-12.175`)

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

## Waiting on the owner

- **The import** (V0's open question): Studio's **Home → Import 3D**, then `build\kit\spike\spike.glb` (and after it `build\kit\golden\golden.glb`). That puts the meshes and their textures on the owner's account; then the kit goes into `ReplicatedStorage.Kit`, and the route that keeps it in the place across `rojo build` gets settled: a published package loaded at start, or `.rbxm` files in the repo. F2 `kit probe <mesh id>` checks whether game scripts can build a piece from ids alone.

## Shots

- `0_spike_blender.png`: the spike in Blender.
- `1_golden_batch_blender.png`: the golden batch, each piece under a warm lamp: armchair, bench, coat rack, dining table; clock case, rug, bookcase, sofa.
