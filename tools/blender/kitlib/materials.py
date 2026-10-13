"""Procedural materials for the kit, baked to PBR maps by kitlib.bake.

Each is a Principled BSDF fed by noise and waves in object space, so a
piece's grain, wear and weave come from its shape, not a tiling photo. They
follow docs/ART.md's palette: dark walnut, off-white paint, linen, brass.
Colours are given as 0-255 RGB.
"""

import bpy


def _srgb(c):
    """0-255 sRGB to Blender's linear 0-1."""

    def one(v):
        v = v / 255.0
        return v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4

    return (one(c[0]), one(c[1]), one(c[2]), 1.0)


class Nodes:
    """A small helper for building node trees in a line."""

    def __init__(self, material):
        material.use_nodes = True
        self.tree = material.node_tree
        self.nodes = self.tree.nodes
        self.links = self.tree.links
        self.nodes.clear()
        self.out = self.add("ShaderNodeOutputMaterial")
        self.bsdf = self.add("ShaderNodeBsdfPrincipled")
        self.link(self.bsdf.outputs["BSDF"], self.out.inputs["Surface"])
        self.coord = self.add("ShaderNodeTexCoord")

    def add(self, kind, **props):
        node = self.nodes.new(kind)
        for key, value in props.items():
            setattr(node, key, value)
        return node

    def link(self, a, b):
        self.links.new(a, b)

    def mapping(self, scale=(1, 1, 1), rotation=(0, 0, 0)):
        m = self.add("ShaderNodeMapping")
        m.inputs["Scale"].default_value = scale
        m.inputs["Rotation"].default_value = rotation
        self.link(self.coord.outputs["Object"], m.inputs["Vector"])
        return m

    def noise(self, vector, scale, detail=6.0, roughness=0.55):
        n = self.add("ShaderNodeTexNoise")
        n.inputs["Scale"].default_value = scale
        n.inputs["Detail"].default_value = detail
        n.inputs["Roughness"].default_value = roughness
        self.link(vector, n.inputs["Vector"])
        return n

    def ramp(self, factor, stops):
        """stops: [(position, (r, g, b, a) linear)]"""
        r = self.add("ShaderNodeValToRGB")
        elements = r.color_ramp.elements
        elements[0].position, elements[0].color = stops[0]
        elements[1].position, elements[1].color = stops[-1]
        for position, color in stops[1:-1]:
            e = elements.new(position)
            e.color = color
        self.link(factor, r.inputs["Fac"])
        return r

    def math(self, op, a, b=None, value=None):
        m = self.add("ShaderNodeMath", operation=op)
        if isinstance(a, (int, float)):
            m.inputs[0].default_value = a
        else:
            self.link(a, m.inputs[0])
        if b is not None:
            if isinstance(b, (int, float)):
                m.inputs[1].default_value = b
            else:
                self.link(b, m.inputs[1])
        # The third input (MULTIPLY_ADD's addend). It was ignored until
        # 2026-10-12, so every wood's `roughness` had no effect: the addend
        # stayed Blender's default 0.5.
        if value is not None:
            if isinstance(value, (int, float)):
                m.inputs[2].default_value = value
            else:
                self.link(value, m.inputs[2])
        return m

    def mix_colour(self, a, b, factor, blend="MIX"):
        """A colour Mix node by its sockets' stable identifiers (their
        positions move between Blender versions). Returns its colour output."""
        node = self.add("ShaderNodeMix", data_type="RGBA", blend_type=blend)

        def socket(sockets, ident):
            for s in sockets:
                if s.identifier == ident:
                    return s
            raise KeyError(ident)

        socket(node.inputs, "Factor_Float").default_value = factor
        self.link(a, socket(node.inputs, "A_Color"))
        self.link(b, socket(node.inputs, "B_Color"))
        return socket(node.outputs, "Result_Color")

    def bump(self, height, strength, distance=0.02):
        b = self.add("ShaderNodeBump")
        b.inputs["Strength"].default_value = strength
        b.inputs["Distance"].default_value = distance
        self.link(height, b.inputs["Height"])
        self.link(b.outputs["Normal"], self.bsdf.inputs["Normal"])
        return b


def wood(name, dark=(52, 34, 22), light=(98, 66, 42), grain_axis="Z", scale=1.0, roughness=0.5):
    """Walnut or oak: long rings stretched along grain_axis, broken up by
    noise, with fine pores. The rings run the length of a leg or a rail."""
    mat = bpy.data.materials.new(name)
    n = Nodes(mat)
    stretch = {"X": (0.25, 3.0, 3.0), "Y": (3.0, 0.25, 3.0), "Z": (3.0, 3.0, 0.25)}[grain_axis]
    m = n.mapping(scale=tuple(s * scale for s in stretch))
    warp = n.noise(m.outputs["Vector"], 2.0, 4.0, 0.5)
    rings = n.add("ShaderNodeTexWave", wave_type="RINGS")
    rings.inputs["Scale"].default_value = 1.6
    rings.inputs["Distortion"].default_value = 6.0
    rings.inputs["Detail"].default_value = 3.0
    mix = n.add("ShaderNodeVectorMath", operation="ADD")
    n.link(m.outputs["Vector"], mix.inputs[0])
    n.link(warp.outputs["Color"], mix.inputs[1])
    n.link(mix.outputs["Vector"], rings.inputs["Vector"])
    pores = n.noise(m.outputs["Vector"], 90.0, 2.0, 0.6)
    grain = n.math("MULTIPLY", rings.outputs["Fac"], pores.outputs["Fac"])
    color = n.ramp(
        grain.outputs["Value"],
        [(0.0, _srgb(dark)), (0.35, _srgb(dark)), (0.7, _srgb(light)), (1.0, _srgb(light))],
    )
    n.link(color.outputs["Color"], n.bsdf.inputs["Base Color"])
    # Worn and waxed: rougher in the open grain, glossier where hands go.
    rough = n.math("MULTIPLY_ADD", grain.outputs["Value"], 0.25, roughness - 0.1)
    n.link(rough.outputs["Value"], n.bsdf.inputs["Roughness"])
    n.bump(pores.outputs["Fac"], 0.12)
    n.bsdf.inputs["Metallic"].default_value = 0.0
    return mat


def paint(name, color=(196, 188, 168), roughness=0.55, grime=0.25):
    """Old gloss paint over wood: a faint brush texture and grime settled
    low and in the corners (the noise), never clean white."""
    mat = bpy.data.materials.new(name)
    n = Nodes(mat)
    m = n.mapping(scale=(1.0, 1.0, 1.0))
    blotch = n.noise(m.outputs["Vector"], 3.0, 6.0, 0.6)
    brush = n.noise(m.outputs["Vector"], 40.0, 2.0, 0.5)
    base = _srgb(color)
    dirty = tuple(c * 0.72 for c in base[:3]) + (1.0,)
    ramp = n.ramp(blotch.outputs["Fac"], [(0.0, base), (0.55, base), (1.0, dirty)])
    n.link(ramp.outputs["Color"], n.bsdf.inputs["Base Color"])
    rough = n.math("MULTIPLY_ADD", blotch.outputs["Fac"], grime, roughness - grime / 2)
    n.link(rough.outputs["Value"], n.bsdf.inputs["Roughness"])
    n.bump(brush.outputs["Fac"], 0.05)
    return mat


def fabric(name, color=(214, 200, 168), roughness=0.92):
    """Linen: a fine cross weave and a soft mottle."""
    mat = bpy.data.materials.new(name)
    n = Nodes(mat)
    m = n.mapping(scale=(1.0, 1.0, 1.0))
    weave_a = n.add("ShaderNodeTexWave", wave_type="BANDS", bands_direction="X")
    weave_a.inputs["Scale"].default_value = 60.0
    weave_b = n.add("ShaderNodeTexWave", wave_type="BANDS", bands_direction="Z")
    weave_b.inputs["Scale"].default_value = 60.0
    n.link(m.outputs["Vector"], weave_a.inputs["Vector"])
    n.link(m.outputs["Vector"], weave_b.inputs["Vector"])
    weave = n.math("MULTIPLY", weave_a.outputs["Fac"], weave_b.outputs["Fac"])
    mottle = n.noise(m.outputs["Vector"], 4.0, 4.0, 0.5)
    base = _srgb(color)
    shade = tuple(c * 0.82 for c in base[:3]) + (1.0,)
    ramp = n.ramp(mottle.outputs["Fac"], [(0.0, shade), (1.0, base)])
    n.link(ramp.outputs["Color"], n.bsdf.inputs["Base Color"])
    n.bsdf.inputs["Roughness"].default_value = roughness
    n.bump(weave.outputs["Value"], 0.15)
    return mat


def brass(name, color=(150, 118, 70), roughness=0.38):
    """Tarnished brass (kept off the reserved #C4965C): darker in the
    recesses, brighter where hands polish it."""
    mat = bpy.data.materials.new(name)
    n = Nodes(mat)
    m = n.mapping(scale=(1.0, 1.0, 1.0))
    tarnish = n.noise(m.outputs["Vector"], 6.0, 6.0, 0.6)
    base = _srgb(color)
    dark = tuple(c * 0.55 for c in base[:3]) + (1.0,)
    ramp = n.ramp(tarnish.outputs["Fac"], [(0.0, base), (0.6, base), (1.0, dark)])
    n.link(ramp.outputs["Color"], n.bsdf.inputs["Base Color"])
    rough = n.math("MULTIPLY_ADD", tarnish.outputs["Fac"], 0.3, roughness - 0.1)
    n.link(rough.outputs["Value"], n.bsdf.inputs["Roughness"])
    n.bsdf.inputs["Metallic"].default_value = 1.0
    return mat


def upholstery(name, base=(118, 74, 52), figure=(150, 108, 70), roughness=0.85):
    """1980s upholstery: a woven ground with a faded damask-like figure (a
    stretched voronoi and waves), worn paler where people sat."""
    mat = bpy.data.materials.new(name)
    n = Nodes(mat)
    m = n.mapping(scale=(1.0, 1.0, 1.0))
    cells = n.add("ShaderNodeTexVoronoi")
    cells.inputs["Scale"].default_value = 1.6
    n.link(m.outputs["Vector"], cells.inputs["Vector"])
    wave = n.add("ShaderNodeTexWave", wave_type="BANDS")
    wave.inputs["Scale"].default_value = 1.2
    wave.inputs["Distortion"].default_value = 4.0
    n.link(m.outputs["Vector"], wave.inputs["Vector"])
    figure_mask = n.math("MULTIPLY", cells.outputs["Distance"], wave.outputs["Fac"])
    shape = n.ramp(
        figure_mask.outputs["Value"],
        [(0.0, _srgb(base)), (0.12, _srgb(base)), (0.2, _srgb(figure)), (0.32, _srgb(base)), (1.0, _srgb(base))],
    )
    weave_a = n.add("ShaderNodeTexWave", wave_type="BANDS", bands_direction="X")
    weave_a.inputs["Scale"].default_value = 80.0
    n.link(m.outputs["Vector"], weave_a.inputs["Vector"])
    weave_b = n.add("ShaderNodeTexWave", wave_type="BANDS", bands_direction="Z")
    weave_b.inputs["Scale"].default_value = 80.0
    n.link(m.outputs["Vector"], weave_b.inputs["Vector"])
    weave = n.math("MULTIPLY", weave_a.outputs["Fac"], weave_b.outputs["Fac"])
    wear = n.noise(m.outputs["Vector"], 2.0, 3.0, 0.5)
    worn = n.mix_colour(shape.outputs["Color"], wear.outputs["Color"], 0.05, "SCREEN")
    n.link(worn, n.bsdf.inputs["Base Color"])
    n.bsdf.inputs["Roughness"].default_value = roughness
    n.bump(weave.outputs["Value"], 0.18)
    return mat


def velvet(name, color=(84, 34, 38), roughness=0.95):
    """Crushed velvet: a soft mottle and a sheen from the fibres."""
    mat = bpy.data.materials.new(name)
    n = Nodes(mat)
    m = n.mapping(scale=(1.0, 1.0, 1.0))
    crush = n.noise(m.outputs["Vector"], 6.0, 5.0, 0.6)
    base = _srgb(color)
    light = tuple(min(1.0, c * 1.5) for c in base[:3]) + (1.0,)
    ramp = n.ramp(crush.outputs["Fac"], [(0.0, base), (0.55, base), (1.0, light)])
    n.link(ramp.outputs["Color"], n.bsdf.inputs["Base Color"])
    n.bsdf.inputs["Roughness"].default_value = roughness
    try:
        n.bsdf.inputs["Sheen Weight"].default_value = 0.6
    except KeyError:
        pass
    n.bump(crush.outputs["Fac"], 0.08)
    return mat


def by_colour(name, roughness=0.6, grain=0.25):
    """One material for many pieces each coloured by its "Col" attribute
    (shapes.colour): a row of books, each its own cloth binding."""
    mat = bpy.data.materials.new(name)
    n = Nodes(mat)
    attr = n.add("ShaderNodeAttribute", attribute_name="Col")
    m = n.mapping(scale=(1.0, 1.0, 1.0))
    cloth = n.noise(m.outputs["Vector"], 40.0, 3.0, 0.5)
    shaded = n.mix_colour(attr.outputs["Color"], cloth.outputs["Color"], grain, "MULTIPLY")
    n.link(shaded, n.bsdf.inputs["Base Color"])
    n.bsdf.inputs["Roughness"].default_value = roughness
    return mat


def image(name, pixels, roughness=0.9, bump=0.1):
    """A material from a drawn picture (numpy, h x w x 3, 0-1 sRGB): the rug's
    pattern, mapped by the piece's UVs."""
    import numpy as np

    h, w = pixels.shape[:2]
    img = bpy.data.images.new(name + "_src", w, h, alpha=False)
    # (The colour space first: changing it afterwards regenerates the image
    # and loses the pixels.)
    img.colorspace_settings.name = "sRGB"
    rgba = np.concatenate([pixels[::-1], np.ones((h, w, 1))], axis=-1).astype(np.float32)
    img.pixels.foreach_set(rgba.ravel())
    img.update()
    img.pack()
    mat = bpy.data.materials.new(name)
    n = Nodes(mat)
    uv = n.add("ShaderNodeUVMap", uv_map="Pattern")  # the piece's own flat layout (furniture.rug)
    tex = n.add("ShaderNodeTexImage")
    tex.image = img
    n.link(uv.outputs["UV"], tex.inputs["Vector"])
    n.link(tex.outputs["Color"], n.bsdf.inputs["Base Color"])
    n.bsdf.inputs["Roughness"].default_value = roughness
    m = n.mapping(scale=(1.0, 1.0, 1.0))
    pile = n.noise(m.outputs["Vector"], 120.0, 2.0, 0.5)
    n.bump(pile.outputs["Fac"], bump)
    mat["uv_image"] = True  # (kit.py lays the piece's own UVs out before baking)
    return mat


def brick(name, color=(122, 58, 42), dark=(84, 38, 30), mortar=(150, 140, 124), scale=2.2, soot=0.0):
    """A 1970s-80s fireplace brick: running bond, each brick a little
    different, sandy mortar sunk between them; `soot` (0-1) darkens it, for a
    firebox's inside."""
    mat = bpy.data.materials.new(name)
    n = Nodes(mat)
    m = n.mapping(scale=(1.0, 1.0, 1.0))
    # The brick texture reads only a vector's x and y, so each face is given
    # its own pair (a box projection): across and up on the faces that look
    # along Y, deep and up on the sides. (One pair striped the sides, and the
    # front as well when it was the wrong one, seen 2026-10-12.)
    xyz = n.add("ShaderNodeSeparateXYZ")
    n.link(m.outputs["Vector"], xyz.inputs["Vector"])

    def course(u):
        vec = n.add("ShaderNodeCombineXYZ")
        n.link(xyz.outputs[u], vec.inputs["X"])
        n.link(xyz.outputs["Z"], vec.inputs["Y"])
        b = n.add("ShaderNodeTexBrick")
        b.inputs["Scale"].default_value = scale
        b.inputs["Mortar Size"].default_value = 0.025
        b.inputs["Bias"].default_value = 0.0
        b.inputs["Brick Width"].default_value = 0.5
        b.inputs["Row Height"].default_value = 0.18
        b.inputs["Color1"].default_value = _srgb(color)
        b.inputs["Color2"].default_value = _srgb(dark)
        b.inputs["Mortar"].default_value = _srgb(mortar)
        n.link(vec.outputs["Vector"], b.inputs["Vector"])
        return b

    front, side = course("X"), course("Y")
    geometry = n.add("ShaderNodeNewGeometry")
    normal = n.add("ShaderNodeSeparateXYZ")
    n.link(geometry.outputs["Normal"], normal.inputs["Vector"])
    facing = n.math("GREATER_THAN", n.math("ABSOLUTE", normal.outputs["X"]).outputs["Value"], 0.5)
    grit = n.noise(m.outputs["Vector"], 30.0, 4.0, 0.6)
    c = n.mix_colour(front.outputs["Color"], side.outputs["Color"], 0.0)
    n.link(facing.outputs["Value"], c.node.inputs[0])
    fac = n.add("ShaderNodeMix", data_type="FLOAT")
    sockets = {s.identifier: s for s in fac.inputs}
    n.link(facing.outputs["Value"], sockets["Factor_Float"])
    n.link(front.outputs["Fac"], sockets["A_Float"])
    n.link(side.outputs["Fac"], sockets["B_Float"])
    mortar_mask = [s for s in fac.outputs if s.identifier == "Result_Float"][0]
    if soot > 0:
        black = n.add("ShaderNodeRGB")
        black.outputs[0].default_value = (0.02, 0.018, 0.016, 1.0)
        c = n.mix_colour(c, black.outputs[0], soot)
    n.link(c, n.bsdf.inputs["Base Color"])
    rough = n.math("MULTIPLY_ADD", grit.outputs["Fac"], 0.15, 0.82)
    n.link(rough.outputs["Value"], n.bsdf.inputs["Roughness"])
    # The mortar sunk: the brick texture's own factor is 1 in the mortar.
    height = n.math("SUBTRACT", 1.0, mortar_mask)
    n.bump(height.outputs["Value"], 0.5, 0.03)
    return mat


def assign(obj, material):
    obj.data.materials.clear()
    obj.data.materials.append(material)
    return obj
