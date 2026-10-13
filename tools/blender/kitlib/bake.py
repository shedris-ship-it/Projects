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
    """Lays out the piece's own UVs for baking ("BakeUV"), leaving any authored
    layer (a rug's "Pattern") for its materials to read while baking."""
    from .shapes import select_only

    layers = obj.data.uv_layers
    bake_uv = layers.get("BakeUV") or layers.new(name="BakeUV")
    layers.active = bake_uv
    select_only(obj)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=math.radians(60), island_margin=margin, scale_to_bounds=False)
    shares = {}
    for i, slot in enumerate(obj.material_slots):
        share = slot.material.get("uv_share") if slot.material else None
        if share:
            shares[i] = float(share)
    if shares:
        _pack_by_share(obj, "BakeUV", shares, margin)
    bpy.ops.object.mode_set(mode="OBJECT")


def _pack_by_share(obj, layer, shares, margin):
    """Packs a material's faces into its own band of the texture (bottom up,
    mat["uv_share"] of its height each) and everything else into the rest,
    so a crowd of small things (books) can't starve the piece's own
    surfaces of texels. Edit mode, every face selected on entry."""
    import bmesh

    bpy.context.scene.tool_settings.use_uv_select_sync = True
    bands = []
    y = 0.0
    for index, share in shares.items():
        bands.append(({index}, (y, y + share)))
        y += share
    rest = {i for i in range(len(obj.material_slots)) if i not in shares}
    bands.append((rest, (y, 1.0)))
    for indices, (y0, y1) in bands:
        bm = bmesh.from_edit_mesh(obj.data)
        uv = bm.loops.layers.uv[layer]
        faces = [f for f in bm.faces if f.material_index in indices]
        if not faces:
            continue
        # Stretch the group's islands over its band: the box the packer
        # then fills (udim_source ORIGINAL_AABB), keeping islands' shapes.
        us = [l[uv].uv for f in faces for l in f.loops]
        lo_u, hi_u = min(p.x for p in us), max(p.x for p in us)
        lo_v, hi_v = min(p.y for p in us), max(p.y for p in us)
        for p in us:
            p.x = (p.x - lo_u) / max(hi_u - lo_u, 1e-6)
            p.y = y0 + (p.y - lo_v) / max(hi_v - lo_v, 1e-6) * (y1 - y0)
        for f in bm.faces:
            f.select = f.material_index in indices
        bmesh.update_edit_mesh(obj.data)
        bpy.ops.uv.pack_islands(udim_source="ORIGINAL_AABB", rotate=True, scale=True, margin=margin)
    bpy.ops.mesh.select_all(action="SELECT")


def keep_bake_uv(obj):
    """After baking, the exported piece carries only its baked layout."""
    layers = obj.data.uv_layers
    for layer in list(layers):
        if layer.name != "BakeUV":
            layers.remove(layer)
    if layers.get("BakeUV"):
        layers.active = layers["BakeUV"]
        layers["BakeUV"].active_render = True


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
    # Glow: where a material is marked to glow (mat["glow"], a lamp's shade),
    # white; elsewhere black. Roblox lights a SurfaceAppearance only where
    # its emissive mask says (World/Kit, EffectsController drive how much).
    emissive = None
    if any(slot.material.get("glow", 0.0) > 0 for slot in obj.material_slots):
        emissive = _image(name + "_emissive", size, "data")
        for slot in obj.material_slots:
            tree = slot.material.node_tree
            emit = tree.nodes.new("ShaderNodeEmission")
            emit.name = "GlowEmit"
            g = float(slot.material.get("glow", 0.0))
            emit.inputs["Color"].default_value = (g, g, g, 1.0)
            out = [n for n in tree.nodes if n.type == "OUTPUT_MATERIAL"][0]
            tree.links.new(emit.outputs["Emission"], out.inputs["Surface"])
        _bake(obj, "EMIT", emissive)
        for slot in obj.material_slots:
            tree = slot.material.node_tree
            bsdf = _principled(slot.material)
            out = [n for n in tree.nodes if n.type == "OUTPUT_MATERIAL"][0]
            tree.links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])
            tree.nodes.remove(tree.nodes["GlowEmit"])
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
    maps = [("color", color), ("normal", normal), ("roughness", rough), ("metalness", metal)]
    if emissive is not None:
        maps.append(("emissive", emissive))
    for key, image in maps:
        path = os.path.join(out_dir, "%s_%s.png" % (name, key))
        _save(image, path)
        paths[key] = path
    _rewire(obj, color, normal, rough, metal, emissive)
    keep_bake_uv(obj)
    return paths


def _rewire(obj, color, normal, rough, metal, emissive=None):
    """One plain material per piece, wired to the baked maps (the emissive
    mask, if any, as the glTF's emissive texture)."""
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
    if emissive is not None:
        tex(emissive, bsdf.inputs["Emission Color"], True)
        bsdf.inputs["Emission Strength"].default_value = 1.0
    nmap = nodes.new("ShaderNodeNormalMap")
    n = tex(normal, None, True)
    links.new(n.outputs["Color"], nmap.inputs["Color"])
    links.new(nmap.outputs["Normal"], bsdf.inputs["Normal"])
    obj.data.materials.clear()
    obj.data.materials.append(mat)
