# The visual rework, V4a and the end of V2: the house's surfaces, light in the air (build `2026-10-15.195`)

The owner: "Lets do V4a and finish up V2". Along the way: "could we make the light rays look more natural and scatter as real moonlight would?", then "I think the lightrays might look a little weirder on account that its essentially planks of light ... its too rectangular". Both acted on (below). Two imports from the owner (`kit.py surfaces`, 18 swatches; `kit.py surfaces2`, two redrawn).

## V4a: every surface rebuilt, seven new ones (`tools/surfaces.py`, `Data/Materials`)

Before, the ten first surfaces (`tools/textures.py`, 2026-10-02) were plain greyscale drawings, each with one flat roughness for its whole surface (two 8 px images, "matte" and "satin"), so a waxed floor, a glazed tile and a matt ceiling caught a lamp alike. Now every surface is drawn again by `tools/surfaces.py` (seeded numpy, seamless) with its own colour, normal and roughness maps (`0_surfaces_lookdev.jpg`: test corners under one lamp; `0b`, `0c`: the maps):

| Surface | What it is now |
| --- | --- |
| OakFloor | strip oak, each board its own figure (cathedral arches or straight grain) and tone, open pores, end joints with dirt in them; the finish duller where people walk, scratched |
| Panelling | 1970s walnut V-groove panelling, boards of three widths |
| Wallpaper | calico rosebud sprigs in a half-drop, hung in strips with faint seams; ink a hair satin on matt paper |
| WallpaperStripe | Regency stripes: satin bands with a fine moire between matt bands, pinlines |
| OldPlaster | roller stipple, trowel marks under the paint, patched spots, hairline cracks, stains |
| PopcornCeiling | dense lumps, deep crevices, yellowed in patches |
| PileCarpet | cut pile, flecks, shading where the pile lies another way, flattened along the walking paths, old stains |
| CheckerLino | vinyl tile, each mottled along its grain and laid quarter-turned, chips, wax along the joints, heel scuffs |
| HexTile | glossy hex mosaic, each tile a hair different in tone and tilt, dirty dull grout |
| StainedConcrete | aggregate, pits, cracks, oil stains that shine, tide marks, dust |

New, for what the house still drew in Roblox's own materials:

| Surface | Where |
| --- | --- |
| CellarBrick | the cellar's walls: old red brick in running bond (in colour), whitewash flaking, salt bloom, damp patches that shine |
| RoughBoards | the attic's floors, the cellar's and attic's ceilings: wide rough-sawn boards, knots, nail holes, saw marks |
| BathTile | the bathroom's walls: square glazed tiles with pillowed edges, a few crazed |
| Flagstone | the mudroom's, the pantry's and the wine cellar's floors |
| QuarryTile | the sunroom's floor: terracotta (in colour) |
| Clapboard | the house's outside (`Config.Exterior.Facade`): lapped boards, weathered, paint flaking |
| Gravel | the drive |

- **The plan's other ~15 materials** (velvet, leather, brass, marble...) aren't needed any more: since the plan was written, every piece of furniture and every prop became a Blender model with its own baked maps (V3 to V6). So the new materials went to the surfaces that were still Roblox's own.
- **Tuned by eye in Studio:** the plaster read as stucco in a lamp's raking light at 16 studs a tile, so it's 7 now; the carpet's tufts read as lumps at 8, so it's 3.
- **Redrawn once and uploaded again:** the clapboard's peeling paint was one big patch, repeated tile by tile like a stamp (`1h_brick_clapboard_panels.jpg`); its flakes are scattered evenly now (`1i_outside_clapboard_gravel.jpg`).
- The old drawing code for the ten surfaces is gone from `tools/textures.py` (it would have overwritten the new images), and so are the flat roughness maps (`Assets.Roughness`).
- In the game: `1_kitchen_lino`, `1b_bathroom_tiles`, `1c_study_stripe_panelling_oak`, `1d_kids_bedroom_sprig_carpet`, `1e_sunroom_quarry_plaster`, `1f_mudroom_flagstone`, `1g_attic_rough_boards`.

## V2's finish: light in the air

- **Moonlight through a window** (`World/PropFactory` marks where it runs; `Controllers/EffectsController` makes it; `Config.Window.MoonBeam.Shaft`). The first try was a soft card of light (`2b_shaft_first_card.jpg`); the owner: "more natural, and scatter as real moonlight would". Layered softer cards were better (`2c`, `2d`), and the owner then put a finger on it: they were still "planks of light". A Beam in Roblox is a flat ribbon turned to face you, so from most angles it reads as a plank. Now there is no card at all: a faint haze of big soft blobs and fine dust drifts in a box along the moonlight's way from the glass to the floor, lit by the moonlight itself, so only what the moonlight reaches glows. It takes the light's own shape from any angle, brightest by the glass, and the storm's lightning brightens it with the rest (`2e_moon_haze.jpg`, `2f_moon_haze_side.jpg`). Each client makes it, where its graphics preset has dust.
- **Another player's torch in the air** (`Controllers/TorchHazeController`, `Config.Torch.Haze`; the polish pass's open item): the same idea, a haze and dust ahead of their head lit by their own torch, so you see the true cone of their beam, out to the first wall, and it sweeps through the dust as they turn (`3_torch_haze.jpg`, shown on a stand-in figure: one client can't have a second player). Your own torch has none.
- **The light recipes for PBR:** with the new roughness the rooms took the lamps well; no family's lamps needed changing. `Lighting.EnvironmentSpecularScale` is raised from 0.4 to 0.8 (`default.project.json`), so glazed tile and waxed floors pick up a little more sheen (`4_specular_04.jpg` against `4b_specular_10.jpg`).
- Looks only: what counts as lit for the rules is still `WorldService`'s light rule.

## Found in Studio (Roblox Beams)

- A Beam's transparency is sampled only at its vertices: with one segment, a sequence fading in and out at both ends drew nothing. Give it segments.
- Its transparency isn't linear: 0.84 drew nothing at all, 0.45 a solid card.
- Roblox lays a Beam's image with its height along the beam (an image soft across its height came out soft at its ends and hard down its sides).
- Particles with `LightInfluence` 1 are lit by a light's whole cone but aren't shadowed by walls, so the box they're born in has to give the shape (the first try lit a fog cloud round the window).

The light-shaft image drawn for the Beams went unused in the end (it's in the second swatch batch); the haze uses Roblox's own soft blob.

## Checks

- stylua, selene (0/0), compile (267 files), **636 tests** (`Materials.spec`: every surface has its own colour, normal and roughness maps), `rojo build`.
- In Studio: the surfaces in eight rooms and outside, the moon haze from two sides, the torch haze on a stand-in, a clean console. **Gate A unchanged: parts 2451, hash 2057680657.**

## Not checked

- Another player's torch haze with two real clients (TC-298).
- The cellar's brick in a real cellar: the runs I played didn't build one (the cellar is a locked wing), so it was judged on a panel in the attic.
- The haze's cost on a phone (each moonlit window about 100 blobs and 140 motes; Performance has no dust, and so no haze).
