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
        return m

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


def assign(obj, material):
    obj.data.materials.clear()
    obj.data.materials.append(material)
    return obj
