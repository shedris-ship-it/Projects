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


def swatch(name, stem):
    """A 2 x 2 stud square (Blender X by Y, facing up) wearing
    assets/textures/<stem>.jpg, <stem>_normal.png and <stem>_rough.jpg."""

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
