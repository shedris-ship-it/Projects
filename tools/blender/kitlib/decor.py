"""Things on the walls and the corridor's plant (the visual rework V4c/d): the
paintings in their gilt frames (kitlib/paintings draws the pictures), the
mirror's frame, a potted snake plant.

A wall piece hangs from y = 0 (the wall) out toward -Y, X across and Z up,
centred (World/Kit's decor: the game's wall decor frame). The plant stands on
Z = 0 like the furniture.
"""

import math

import bmesh
import bpy
from mathutils import Vector

from . import materials, paintings, shapes

GILT = (168, 128, 62)


def _gilt(name):
    """Old gold leaf: tarnished in the hollows, bright where it's been
    dusted (kept off the reserved brass #C4965C)."""
    return materials.brass(name, color=GILT, roughness=0.42)


# The picture frame's moulding, 0.3 wide and 0.25 deep: a rounded outer
# edge, a high bead, a deep cove, a small bead and a lip at the picture.
FRAME_PROFILE = [
    (0.0, 0.0),
    (0.0, 0.13),
    (0.012, 0.17),
    (0.035, 0.2),
    (0.065, 0.225),
    (0.095, 0.25),
    (0.125, 0.24),
    (0.15, 0.21),
    (0.18, 0.165),
    (0.21, 0.135),
    (0.235, 0.13),
    (0.25, 0.145),
    (0.265, 0.13),
    (0.282, 0.1),
    (0.3, 0.075),
    (0.3, 0.0),
]


def _canvas(name, picture, w, h, out):
    """The picture on a flat canvas w x h, `out` from the wall, its pattern
    mapped straight on (the "Pattern" layer, as the rug's)."""
    canvas = shapes.box(name, (w, 0.02, h), (0, -out, 0), 0.0)
    shapes.cull(canvas, [(0, 1, 0)])
    mesh = canvas.data
    uv = mesh.uv_layers.new(name="Pattern")
    for loop in mesh.loops:
        co = mesh.vertices[loop.vertex_index].co
        uv.data[loop.index].uv = ((co.x / w) + 0.5, (co.z / h) + 0.5)
    mat = materials.image(name + "Oils", picture, roughness=0.55, bump=0.06)
    # The picture is what you look at: most of the piece's texture.
    mat["uv_share"] = 0.72
    return materials.assign(canvas, mat)


def _painting(index):
    """A painting, 5 x 4 x 0.25 (Data/Props' Painting, World/PropFactory's
    frame): the gilt frame, the picture behind its lip."""
    picture = paintings.PICTURES[index]

    def build():
        w, h = 5.0, 4.0
        frame = materials.assign(shapes.frame("Frame", w, h, FRAME_PROFILE), _gilt("Gilt%d" % (index + 1)))
        canvas = _canvas("Canvas", picture(), w - 0.6 + 0.08, h - 0.6 + 0.08, 0.06)
        piece = shapes.join([frame, canvas], "Painting%d" % (index + 1))
        piece["frame"] = "wall"
        return piece

    build.__name__ = "painting%d" % (index + 1)
    return build


def mirror():
    """The mirror's frame, 3 x 5 (Data/Props' Mirror): a gilt moulding 0.24
    wide whose lip stands in front of the game's glass (2.6 x 4.6, 0.2 to
    0.25 out from the wall), so the glass sits in it."""
    w, h = 3.0, 5.0
    profile = [
        (0.0, 0.0),
        (0.0, 0.16),
        (0.015, 0.22),
        (0.045, 0.27),
        (0.08, 0.3),
        (0.11, 0.29),
        (0.14, 0.26),
        (0.17, 0.27),
        (0.2, 0.285),
        (0.225, 0.275),
        (0.24, 0.26),
        (0.24, 0.0),
    ]
    frame = materials.assign(shapes.frame("Mirror", w, h, profile), _gilt("MirrorGilt"))
    # A dark backing behind the glass, so its edge never shows the wall.
    back = shapes.box("Backing", (w - 0.4, 0.02, h - 0.4), (0, -0.16, 0), 0.0)
    shapes.cull(back, [(0, 1, 0)])
    materials.assign(back, materials.paint("MirrorBacking", color=(30, 28, 26), roughness=0.8, grime=0.0))
    piece = shapes.join([frame, back], "Mirror")
    piece["frame"] = "wall"
    return piece


def _leaf(rng_value, base, azimuth, length, width, lean, twist):
    """A snake plant's leaf: a stiff sword, widest a third of the way up,
    thin (it's solid: both faces show), leaning out from the middle and
    twisting a little. Its edge is marked in the "Edge" colour layer (1 at
    the margin, 0 down the middle) for the yellow margin."""
    bm = bmesh.new()
    rows = 12
    out_dir = Vector((math.cos(azimuth), math.sin(azimuth), 0))
    side_dir = Vector((-math.sin(azimuth), math.cos(azimuth), 0))
    verts = []
    for i in range(rows + 1):
        s = i / rows
        # Up, curving out as it goes.
        up = s * length
        out = math.sin(lean) * length * (s ** 1.6)
        centre = Vector(base) + out_dir * out + Vector((0, 0, up * math.cos(lean * 0.5)))
        half = width / 2 * (math.sin(math.pi * min(1.0, s * 1.35 + 0.05)) if s < 0.74 else (1 - s) / 0.26 * 0.62)
        half = max(half, 0.004)
        t = twist * s
        side = side_dir * math.cos(t) + out_dir * math.sin(t)
        # Three across: edge, middle (a little proud: a shallow V), edge.
        row = [
            bm.verts.new(centre - side * half),
            bm.verts.new(centre + out_dir * 0.012),
            bm.verts.new(centre + side * half),
        ]
        verts.append(row)
    for i in range(rows):
        a, b = verts[i], verts[i + 1]
        bm.faces.new((a[0], a[1], b[1], b[0]))
        bm.faces.new((a[1], a[2], b[2], b[1]))
    obj = shapes._object("Leaf", bm)
    mesh = obj.data
    edge = mesh.color_attributes.new("Col", "FLOAT_COLOR", "POINT")
    for k, item in enumerate(edge.data):
        e = 0.0 if k % 3 == 1 else 1.0
        item.color = (e, e, e, 1.0)
    # Solid: a thin back face, so it shows from behind (Roblox draws one side).
    mod = obj.modifiers.new("Solid", "SOLIDIFY")
    mod.thickness = 0.03
    mod.offset = 0.0
    shapes.select_only(obj)
    bpy.ops.object.modifier_apply(modifier=mod.name)
    _ = rng_value
    return shapes.smooth(obj, 50)


def _leaf_material():
    """Sansevieria: dark green crossed by grey-green bands that wander, a
    yellow margin."""
    mat = bpy.data.materials.new("SnakeLeaf")
    n = materials.Nodes(mat)
    m = n.mapping(scale=(1.0, 1.0, 1.0))
    bands = n.add("ShaderNodeTexWave", wave_type="BANDS", bands_direction="Z")
    bands.inputs["Scale"].default_value = 9.0
    bands.inputs["Distortion"].default_value = 9.0
    bands.inputs["Detail"].default_value = 3.0
    n.link(m.outputs["Vector"], bands.inputs["Vector"])
    green = n.ramp(
        bands.outputs["Fac"],
        [(0.0, materials._srgb((26, 50, 28))), (0.45, materials._srgb((30, 56, 30))), (0.7, materials._srgb((84, 110, 72))), (1.0, materials._srgb((40, 64, 36)))],
    )
    attr = n.add("ShaderNodeAttribute", attribute_name="Col")
    margin = n.math("GREATER_THAN", attr.outputs["Fac"], 0.82)
    yellow = n.add("ShaderNodeRGB")
    yellow.outputs[0].default_value = materials._srgb((176, 158, 70))
    colour = n.mix_colour(green.outputs["Color"], yellow.outputs[0], 0.0)
    n.link(margin.outputs["Value"], colour.node.inputs[0])
    n.link(colour, n.bsdf.inputs["Base Color"])
    n.bsdf.inputs["Roughness"].default_value = 0.45
    return mat


def plant():
    """A snake plant in a glazed pot on a saucer, 2 x 4.9 x 2 (Data/Props'
    Plant, its leaves within reach 1 of the middle): fourteen stiff leaves,
    banded, with yellow margins."""
    import random

    rng = random.Random(1988)
    glaze = materials.paint("PotGlaze", color=(118, 74, 52), roughness=0.22, grime=0.25)
    clay = materials.paint("Saucer", color=(150, 86, 62), roughness=0.7, grime=0.3)
    soil = materials.paint("Soil", color=(40, 30, 22), roughness=0.95, grime=0.3)
    parts = []
    parts.append(materials.assign(shapes.lathe("Saucer", [(0.0, 0.0), (0.72, 0.0), (0.78, 0.1), (0.74, 0.12), (0.66, 0.05), (0.0, 0.05)], steps=40), clay))
    pot = shapes.lathe(
        "Pot",
        [(0.0, 0.05), (0.48, 0.05), (0.52, 0.12), (0.6, 0.7), (0.66, 1.18), (0.72, 1.24), (0.73, 1.34), (0.66, 1.36), (0.62, 1.3), (0.0, 1.3)],
        steps=40,
    )
    parts.append(materials.assign(pot, glaze))
    parts.append(materials.assign(shapes.lathe("Soil", [(0.0, 1.22), (0.62, 1.22), (0.62, 1.25), (0.0, 1.27)], steps=32), soil))
    leaf_mat = _leaf_material()
    for k in range(14):
        a = k * 2.4 + rng.uniform(-0.3, 0.3)
        r = rng.uniform(0.05, 0.38)
        base = (math.cos(a) * r, math.sin(a) * r, 1.2)
        length = rng.uniform(2.1, 3.55) * (1.0 if r < 0.25 else 0.85)
        lean = rng.uniform(0.04, 0.2) + r * 0.35
        leaf = _leaf(rng, base, a, length, rng.uniform(0.22, 0.34), lean, rng.uniform(-0.5, 0.5))
        parts.append(materials.assign(leaf, leaf_mat))
    piece = shapes.join(parts, "Plant")
    # Within the plant's reach (1 from the middle) and its 5 of height.
    lo, hi = shapes.bounds(piece)
    assert max(-lo.x, hi.x, -lo.y, hi.y) <= 1.0, "a leaf leaves the plant's reach"
    assert hi.z <= 5.0, "too tall"
    return piece


DECOR = [_painting(0), _painting(1), _painting(2), _painting(3), mirror, plant]
