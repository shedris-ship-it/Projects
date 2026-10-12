"""Bake a piece's procedural materials to the four maps Roblox's
SurfaceAppearance takes (colour, normal, roughness, metalness), with ambient
occlusion multiplied into the colour so creases read in any light.

One texture set per piece: the piece is unwrapped once and every material on
it bakes into the same images.
"""

import math
import os

import bpy
import numpy as np


def _setup_cycles(samples):
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = samples
    scene.cycles.use_denoising = False
    scene.render.bake.margin = 8
    scene.render.bake.use_clear = True


def unwrap(obj, margin=0.01):
    from .shapes import select_only

    select_only(obj)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=math.radians(60), island_margin=margin, scale_to_bounds=False)
    bpy.ops.object.mode_set(mode="OBJECT")


def _image(name, size, data):
    image = bpy.data.images.new(name, size, size, alpha=False, float_buffer=False)
    image.colorspace_settings.name = "sRGB" if data == "color" else "Non-Color"
    return image


def _target(obj, image):
    """Point every material on obj at image as the bake target."""
    for slot in obj.material_slots:
        tree = slot.material.node_tree
        node = tree.nodes.get("BakeTarget") or tree.nodes.new("ShaderNodeTexImage")
        node.name = "BakeTarget"
        node.image = image
        for other in tree.nodes:
            other.select = False
        node.select = True
        tree.nodes.active = node


def _principled(material):
    for node in material.node_tree.nodes:
        if node.type == "BSDF_PRINCIPLED":
            return node
    return None


def _bake(obj, kind, image, **kwargs):
    from .shapes import select_only

    _target(obj, image)
    select_only(obj)
    bpy.ops.object.bake(type=kind, **kwargs)


def _pixels(image):
    a = np.empty(image.size[0] * image.size[1] * 4, dtype=np.float32)
    image.pixels.foreach_get(a)
    return a.reshape(image.size[1], image.size[0], 4)


def _set_pixels(image, a):
    image.pixels.foreach_set(a.astype(np.float32).ravel())


def _save(image, path):
    image.filepath_raw = path
    image.file_format = "PNG"
    image.save()


def bake_piece(obj, out_dir, size=1024, ao_strength=0.7, samples=24):
    """Bakes obj's maps to out_dir/<name>_{color,normal,roughness,metalness}.png
    and swaps its materials for one plain material wired to them (what the
    exporter writes and Roblox's importer turns into a SurfaceAppearance).
    Returns the four paths."""
    _setup_cycles(samples)
    name = obj.name
    os.makedirs(out_dir, exist_ok=True)
    color = _image(name + "_color", size, "color")
    rough = _image(name + "_roughness", size, "data")
    normal = _image(name + "_normal", size, "data")
    metal = _image(name + "_metalness", size, "data")
    ao = _image(name + "_ao", size, "data")

    # Colour: bake with metals turned off for a moment, since a metal has no
    # diffuse colour to bake.
    held = []
    for slot in obj.material_slots:
        bsdf = _principled(slot.material)
        socket = bsdf.inputs["Metallic"]
        links = [l for l in socket.links]
        held.append((bsdf, socket.default_value, [(l.from_socket, l.to_socket) for l in links]))
        for l in links:
            slot.material.node_tree.links.remove(l)
        socket.default_value = 0.0
    _bake(obj, "DIFFUSE", color, pass_filter={"COLOR"})
    # Metalness: the metallic value sent through an emission and baked.
    for (bsdf, value, links), slot in zip(held, obj.material_slots):
        tree = slot.material.node_tree
        emit = tree.nodes.new("ShaderNodeEmission")
        emit.name = "MetalEmit"
        if links:
            tree.links.new(links[0][0], emit.inputs["Color"])
        else:
            emit.inputs["Color"].default_value = (value, value, value, 1.0)
        out = [n for n in tree.nodes if n.type == "OUTPUT_MATERIAL"][0]
        tree.links.new(emit.outputs["Emission"], out.inputs["Surface"])
    _bake(obj, "EMIT", metal)
    for (bsdf, value, links), slot in zip(held, obj.material_slots):
        tree = slot.material.node_tree
        out = [n for n in tree.nodes if n.type == "OUTPUT_MATERIAL"][0]
        tree.links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])
        tree.nodes.remove(tree.nodes["MetalEmit"])
        bsdf.inputs["Metallic"].default_value = value
        for from_socket, to_socket in links:
            tree.links.new(from_socket, to_socket)
    _bake(obj, "ROUGHNESS", rough)
    _bake(obj, "NORMAL", normal, normal_space="TANGENT")
    bpy.context.scene.cycles.samples = max(samples, 64)
    _bake(obj, "AO", ao)

    # Creases darker: the colour times a share of the occlusion.
    c = _pixels(color)
    o = _pixels(ao)[..., :1]
    c[..., :3] *= 1.0 - ao_strength * (1.0 - o)
    _set_pixels(color, c)

    paths = {}
    for key, image in (("color", color), ("normal", normal), ("roughness", rough), ("metalness", metal)):
        path = os.path.join(out_dir, "%s_%s.png" % (name, key))
        _save(image, path)
        paths[key] = path
    _rewire(obj, color, normal, rough, metal)
    return paths


def _rewire(obj, color, normal, rough, metal):
    """One plain material per piece, wired to the baked maps."""
    mat = bpy.data.materials.new(obj.name + "_baked")
    mat.use_nodes = True
    nodes, links = mat.node_tree.nodes, mat.node_tree.links
    bsdf = [n for n in nodes if n.type == "BSDF_PRINCIPLED"][0]

    def tex(image, socket, non_color):
        node = nodes.new("ShaderNodeTexImage")
        node.image = image
        if non_color:
            image.colorspace_settings.name = "Non-Color"
        if socket is not None:
            links.new(node.outputs["Color"], socket)
        return node

    tex(color, bsdf.inputs["Base Color"], False)
    tex(rough, bsdf.inputs["Roughness"], True)
    tex(metal, bsdf.inputs["Metallic"], True)
    nmap = nodes.new("ShaderNodeNormalMap")
    n = tex(normal, None, True)
    links.new(n.outputs["Color"], nmap.inputs["Color"])
    links.new(nmap.outputs["Normal"], bsdf.inputs["Normal"])
    obj.data.materials.clear()
    obj.data.materials.append(mat)
