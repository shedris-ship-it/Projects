"""Swatches: flat squares carrying a tiling surface's maps (tools/textures.py)
through Studio's 3D importer, which uploads them with the batch's meshes on
the owner's account. Their image ids then go into the MaterialVariants
(src/shared/Data/Materials.luau, assets/materials/); the swatches themselves
are never used in the game. kit.py exports them as they are: no unwrap, no
bake.
"""

import os

import bpy

from . import shapes

TEXTURES = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", "..", "assets", "textures"))


def _image(path, colour_space):
    img = bpy.data.images.load(path)
    img.colorspace_settings.name = colour_space
    img.pack()
    return img


def swatch(name, stem, colour_only=False):
    """A 2 x 2 stud square (Blender X by Y, facing up) wearing
    assets/textures/<stem>.jpg, <stem>_normal.png and <stem>_rough.jpg (or
    only the colour: an image the game uses on its own, a Beam's)."""

    def build():
        bpy.ops.mesh.primitive_plane_add(size=2.0)
        obj = bpy.context.active_object
        obj.name = name
        obj.data.name = name
        mat = bpy.data.materials.new(name)
        mat.use_nodes = True
        nodes, links = mat.node_tree.nodes, mat.node_tree.links
        bsdf = [n for n in nodes if n.type == "BSDF_PRINCIPLED"][0]
        colour = nodes.new("ShaderNodeTexImage")
        colour.image = _image(os.path.join(TEXTURES, stem + ".jpg"), "sRGB")
        links.new(colour.outputs["Color"], bsdf.inputs["Base Color"])
        if colour_only:
            bsdf.inputs["Metallic"].default_value = 0.0
            obj.data.materials.append(mat)
            obj["swatch"] = True
            return shapes.apply_transform(obj)
        rough = nodes.new("ShaderNodeTexImage")
        rough.image = _image(os.path.join(TEXTURES, stem + "_rough.jpg"), "Non-Color")
        links.new(rough.outputs["Color"], bsdf.inputs["Roughness"])
        normal = nodes.new("ShaderNodeTexImage")
        normal.image = _image(os.path.join(TEXTURES, stem + "_normal.png"), "Non-Color")
        nmap = nodes.new("ShaderNodeNormalMap")
        links.new(normal.outputs["Color"], nmap.inputs["Color"])
        links.new(nmap.outputs["Normal"], bsdf.inputs["Normal"])
        bsdf.inputs["Metallic"].default_value = 0.0
        obj.data.materials.append(mat)
        obj["swatch"] = True
        return shapes.apply_transform(obj)

    build.__name__ = name
    return build


GOLDEN = [
    swatch("SwatchDamask", "damask"),
    swatch("SwatchFloral", "floral_stripe"),
    swatch("SwatchParquet", "parquet_chevron"),
]

# The house's surfaces rebuilt for PBR, and the new ones (the visual rework
# V4a, tools/surfaces.py), and the light shaft's image (Beams).
SURFACES = [
    swatch("SwatchWallpaperSprig", "wallpaper_sprig"),
    swatch("SwatchWallpaperStripe", "wallpaper_stripe"),
    swatch("SwatchPlaster", "plaster"),
    swatch("SwatchPopcorn", "popcorn"),
    swatch("SwatchOakFloor", "wood_floor"),
    swatch("SwatchPanelling", "wood_panel"),
    swatch("SwatchCarpet", "carpet"),
    swatch("SwatchLinoleum", "linoleum"),
    swatch("SwatchHexTile", "hex_tile"),
    swatch("SwatchConcrete", "concrete"),
    swatch("SwatchBrick", "brick"),
    swatch("SwatchRoughBoards", "rough_boards"),
    swatch("SwatchBathTile", "bath_tile"),
    swatch("SwatchFlagstone", "flagstone"),
    swatch("SwatchQuarryTile", "quarry_tile"),
    swatch("SwatchClapboard", "clapboard"),
    swatch("SwatchGravel", "gravel"),
    swatch("SwatchLightShaft", "light_shaft", colour_only=True),
]

# Redrawn after the first import (2026-10-15): the clapboard's peeling paint
# scattered evenly, and the light shaft soft across its width (Roblox lays a
# Beam's image height along the beam).
SURFACES2 = [
    swatch("SwatchClapboard2", "clapboard"),
    swatch("SwatchLightShaft2", "light_shaft", colour_only=True),
]
