"""The lobby's mall, its first batch (docs/plans/lobby-rework.md, LB1b, kit.py
mall1): the court, what every player sees close up each time they're in the
hub. The bench, the planter and its dead ficus, the fountain's basin and
centrepiece, the directory, the photo booth, a shopping cart, the ad
lightboxes' frames (two sizes), the shopfronts' rolled-grille box, and the
gallery's column, its parapet with the handrail, and the dead chandelier.

A 1980s mall, closed: dark bronze anodised metal, oak, terrazzo with its
chips, brown quarry tile, the fountain's aqua mosaic gone dull. Nothing
glows: the mall's own lamps are dead (the investigators' generator lights
only what they hung up themselves).

Each piece is built round the middle of the grey-box block or part it
dresses (Data/Mall's blocks, World/MallBuilder's parts), in the game's frame
(things.G: x, y up, z toward the front), so kit.py's `at` is where its box's
middle sits from that middle. Sizes are Roblox's { x, y, z }.
"""

import math
import random

import bmesh
import bpy
import numpy as np
from mathutils import Vector, geometry

from . import materials, prints, shapes
from .atmosphere import _picture, _surface
from .fittings import _loft, _oak, _prism
from .house import _chrome
from .materials import Nodes, _srgb
from .things import G, S, _box, _lathe, _new, _sphere, _torus, _tube

# The block alphabet has no Q (BOUTIQUE) and no Z.
prints.FONT.setdefault("Q", [" ### ", "#   #", "#   #", "#   #", "# # #", "#  # ", " ## #"])


# Materials -------------------------------------------------------------------


def _bronze(name, roughness=0.42):
    """Dark bronze anodised aluminium, the 1980s mall's metal: frames,
    pedestals, the directory's case."""
    return materials.brass(name, color=(74, 60, 46), roughness=roughness)


def _plaster(name, color=(204, 196, 180)):
    return materials.paint(name, color=color, roughness=0.82, grime=0.4)


def _stone(name, color=(178, 170, 156)):
    """Cast stone, water-stained."""
    return materials.paint(name, color=color, roughness=0.88, grime=0.55)


def _glass_dead(name):
    """Opal glass, dusty, its bulb long out."""
    return materials.paint(name, color=(176, 170, 156), roughness=0.3, grime=0.45)


def _mix_vector(n, a, b, factor):
    node = n.add("ShaderNodeMix", data_type="VECTOR")
    ins = {s.identifier: s for s in node.inputs}
    n.link(factor, ins["Factor_Float"])
    n.link(a, ins["A_Vector"])
    n.link(b, ins["B_Vector"])
    return [s for s in node.outputs if s.identifier == "Result_Vector"][0]


def _tiles(name, color, dark, grout, size, joint, roughness=0.5, grime=0.25):
    """Square tiles in a grid on every face, floors too (materials.brick reads
    only walls): each face takes the two axes it lies along. `size` and
    `joint` in studs."""
    mat = bpy.data.materials.new(name)
    n = Nodes(mat)
    m = n.mapping(scale=(1.0, 1.0, 1.0))
    xyz = n.add("ShaderNodeSeparateXYZ")
    n.link(m.outputs["Vector"], xyz.inputs["Vector"])

    def pair(a, b):
        v = n.add("ShaderNodeCombineXYZ")
        n.link(xyz.outputs[a], v.inputs["X"])
        n.link(xyz.outputs[b], v.inputs["Y"])
        return v.outputs["Vector"]

    geometry = n.add("ShaderNodeNewGeometry")
    normal = n.add("ShaderNodeSeparateXYZ")
    n.link(geometry.outputs["Normal"], normal.inputs["Vector"])
    fx = n.math("GREATER_THAN", n.math("ABSOLUTE", normal.outputs["X"]).outputs["Value"], 0.5)
    fz = n.math("GREATER_THAN", n.math("ABSOLUTE", normal.outputs["Z"]).outputs["Value"], 0.5)
    walls = _mix_vector(n, pair("X", "Z"), pair("Y", "Z"), fx.outputs["Value"])
    uv = _mix_vector(n, walls, pair("X", "Y"), fz.outputs["Value"])
    b = n.add("ShaderNodeTexBrick")
    b.offset = 0.0
    b.inputs["Scale"].default_value = 1.0
    b.inputs["Mortar Size"].default_value = joint
    b.inputs["Bias"].default_value = 0.0
    b.inputs["Brick Width"].default_value = size
    b.inputs["Row Height"].default_value = size
    b.inputs["Color1"].default_value = _srgb(color)
    b.inputs["Color2"].default_value = _srgb(dark)
    b.inputs["Mortar"].default_value = _srgb(grout)
    n.link(uv, b.inputs["Vector"])
    # Grime settled in blotches over it all.
    blotch = n.noise(m.outputs["Vector"], 1.5, 5.0, 0.6)
    dirty = n.ramp(blotch.outputs["Fac"], [(0.0, (1, 1, 1, 1)), (0.5, (1, 1, 1, 1)), (1.0, (0.62, 0.6, 0.56, 1))])
    c = n.mix_colour(b.outputs["Color"], dirty.outputs["Color"], 1.0, "MULTIPLY")
    n.link(c, n.bsdf.inputs["Base Color"])
    rough = n.math("MULTIPLY_ADD", blotch.outputs["Fac"], grime, roughness - grime / 2)
    n.link(rough.outputs["Value"], n.bsdf.inputs["Roughness"])
    height = n.math("SUBTRACT", 1.0, b.outputs["Fac"])
    n.bump(height.outputs["Value"], 0.45, 0.02)
    return mat


def _terrazzo(name, base=(198, 188, 172), roughness=0.3, chips=0.3):
    """Terrazzo: a warm cement ground set with chips of stone in three
    colours, polished once, dull now and grimy in blotches."""
    mat = bpy.data.materials.new(name)
    n = Nodes(mat)
    m = n.mapping(scale=(1.0, 1.0, 1.0))
    cells = n.add("ShaderNodeTexVoronoi")
    cells.inputs["Scale"].default_value = 22.0
    n.link(m.outputs["Vector"], cells.inputs["Vector"])
    which = n.add("ShaderNodeSeparateColor")
    n.link(cells.outputs["Color"], which.inputs["Color"])
    kind = n.ramp(
        which.outputs["Red"],
        [(0.0, _srgb((122, 104, 86))), (0.34, _srgb((86, 90, 98))), (0.67, _srgb((236, 230, 218))), (1.0, _srgb((236, 230, 218)))],
    )
    kind.color_ramp.interpolation = "CONSTANT"
    chip = n.math("LESS_THAN", cells.outputs["Distance"], chips)
    mottle = n.noise(m.outputs["Vector"], 3.0, 4.0, 0.5)
    b = _srgb(base)
    ground = n.ramp(mottle.outputs["Fac"], [(0.0, tuple(v * 0.9 for v in b[:3]) + (1,)), (1.0, b)])
    c = n.mix_colour(ground.outputs["Color"], kind.outputs["Color"], 0.0)
    n.link(chip.outputs["Value"], c.node.inputs[0])
    blotch = n.noise(m.outputs["Vector"], 1.2, 5.0, 0.6)
    dirty = n.ramp(blotch.outputs["Fac"], [(0.0, (1, 1, 1, 1)), (0.55, (1, 1, 1, 1)), (1.0, (0.66, 0.63, 0.58, 1))])
    c = n.mix_colour(c, dirty.outputs["Color"], 1.0, "MULTIPLY")
    n.link(c, n.bsdf.inputs["Base Color"])
    rough = n.math("MULTIPLY_ADD", blotch.outputs["Fac"], 0.35, roughness)
    n.link(rough.outputs["Value"], n.bsdf.inputs["Roughness"])
    n.bump(chip.outputs["Value"], 0.04, 0.01)
    return mat


def _quarry(name):
    """Brown quarry tile, half-stud squares: the planters' sides."""
    # (Brown, not salmon, and a thin dark grout: the first bake read as a
    # bathroom's pink tile.)
    return _tiles(name, (118, 64, 42), (98, 52, 34), (84, 76, 66), 0.5, 0.012, roughness=0.62)


def _mosaic(name):
    """The fountain's aqua mosaic, dull and dry."""
    return _tiles(name, (82, 132, 128), (64, 110, 110), (172, 168, 156), 0.15, 0.012, roughness=0.35, grime=0.45)


# Shapes ----------------------------------------------------------------------


def _side_prism(name, outline, x0, x1):
    """An outline in the game's z-y plane [(z, y), ...], extruded along x from
    x0 to x1: a pedestal or a hood seen from the side."""
    bm = bmesh.new()
    a = [bm.verts.new(G(x0, y, z)) for z, y in outline]
    b = [bm.verts.new(G(x1, y, z)) for z, y in outline]
    k = len(outline)
    for i in range(k):
        j = (i + 1) % k
        bm.faces.new((a[i], a[j], b[j], b[i]))
    # The ends in triangles that keep inside a concave outline (bmesh's own
    # triangulation folded over the bench's waisted pedestals, 2026-10-15:
    # holes, seen through to the far end's back, and overlaps).
    for t in geometry.tessellate_polygon([[Vector((z, y, 0.0)) for z, y in outline]]):
        bm.faces.new((a[t[2]], a[t[1]], a[t[0]]))
        bm.faces.new((b[t[0]], b[t[1]], b[t[2]]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    # (And if its x0 end then faces in, every face is turned round.)
    for f in bm.faces:
        xs = [v.co.x for v in f.verts]
        if max(xs) - min(xs) < 1e-6 and abs(xs[0] - x0) < 1e-6:
            f.normal_update()
            if f.normal.x > 0:
                bmesh.ops.reverse_faces(bm, faces=bm.faces)
            break
    return shapes.smooth(_new(name, bm), 30)


def _leaf(name, length, width, at, degrees):
    """A leaf: a flat pointed oval, a little thickness so both faces show,
    turned (degrees about Blender's axes) and put at the game's `at`."""
    outline = []
    for k in range(10):
        t = math.pi * k / 9
        outline.append((-length / 2 * math.cos(t), width / 2 * math.sin(t) ** 1.3))
    for k in range(1, 9):
        t = math.pi * k / 9
        outline.append((length / 2 * math.cos(t), -width / 2 * math.sin(t) ** 1.3))
    leaf = _prism(name, outline, -0.006, 0.006)
    return shapes.turn(leaf, degrees, G(*at))


def _atlas(pictures, gap=8):
    """Several pictures stacked into one (top to bottom), each piece's only
    picture material: Blender's packer squeezed a second picture's band to a
    sliver (the booth's sign and samples, 2026-10-15). Returns the pixels and
    each picture's place in its UVs, (u0, v0, u1, v1)."""
    w = max(p.shape[1] for p in pictures)
    h = sum(p.shape[0] for p in pictures) + gap * (len(pictures) - 1)
    out = np.zeros((h, w, 3))
    rects, y = [], 0
    for p in pictures:
        ph, pw = p.shape[:2]
        out[y : y + ph, :pw] = p
        out[y : y + ph, pw:] = p[:, -1:]  # (padded with its own edge)
        if y + ph < h:
            out[y + ph : y + ph + gap] = p[-1:, :1] if pw == w else p[-1, -1]
        rects.append((0.0, 1.0 - (y + ph) / h, pw / w, 1.0 - y / h))
        y += ph + gap
    return out, rects


def _card(name, mat, w, h, at, facing_z, rect):
    """A flat picture standing in the x-y plane round `at`, facing +z or -z
    (facing_z = 1 or -1), showing `rect` of its material's picture (_atlas)."""
    x0, y0, z0 = at
    left, right = (x0 + w / 2, x0 - w / 2) if facing_z < 0 else (x0 - w / 2, x0 + w / 2)
    u0, v0, u1, v1 = rect
    verts = [(left, y0 - h / 2, z0), (right, y0 - h / 2, z0), (right, y0 + h / 2, z0), (left, y0 + h / 2, z0)]
    uvs = [(u0, v0), (u1, v0), (u1, v1), (u0, v1)]
    return materials.assign(_surface(name, verts, [(0, 1, 2, 3)], uvs, (0, 0, facing_z)), mat)


def _materials_by(obj, mats, pick):
    """Gives each face of obj one of `mats` by `pick(x, y, z, up)`: its
    middle in the game's frame and how far its normal points up."""
    obj.data.materials.clear()
    for m in mats:
        obj.data.materials.append(m)
    mw = obj.matrix_world
    turn = mw.to_3x3()
    for poly in obj.data.polygons:
        c = mw @ poly.center
        up = (turn @ poly.normal).normalized().z
        poly.material_index = pick(c.x, c.z, -c.y, up)
    return obj


def _disc(name, radius, y, at=(0.0, 0.0), thick=0.01, steps=24):
    """A flat round thing lying at height y round (x, z): a stain, a coin."""
    x, z = at
    return _lathe(name, [(0.0, y), (radius, y), (radius, y + thick), (0.0, y + thick)], (x, 0.0, z), steps)


# Pieces ----------------------------------------------------------------------


def bench():
    """The court's bench, 8 x 1.8 x 2.4 studs (Data/Mall `Bench`): five oak
    slats bolted to two cast pedestals in dark bronze, the 1980s mall's
    standard, no back."""
    oak = _oak("BenchOak", axis="X", roughness=0.58)
    metal = _bronze("BenchBronze")
    bolt = _chrome("BenchBolt")
    w, h, d = 8.0, 1.8, 2.4
    top, bottom = h / 2, -h / 2
    slat_t, n, gap = 0.14, 5, 0.08
    slat_w = (d - gap * (n - 1)) / n
    parts = []
    for i in range(n):
        z = -d / 2 + slat_w / 2 + i * (slat_w + gap)
        parts.append(materials.assign(_box("Slat", (w, slat_t, slat_w), (0, top - slat_t / 2, z), 0.045, 2), oak))
    for x in (-2.7, 2.7):
        parts.append(materials.assign(_box("Bearer", (0.34, 0.14, d - 0.12), (x, top - slat_t - 0.07, 0), 0.03, 2), metal))
        outline = [
            (-1.0, bottom),
            (1.0, bottom),
            (1.0, bottom + 0.12),
            (0.38, bottom + 0.34),
            (0.28, -0.1),
            (0.42, 0.4),
            (1.1, 0.56),
            (1.1, top - slat_t - 0.14),
            (-1.1, top - slat_t - 0.14),
            (-1.1, 0.56),
            (-0.42, 0.4),
            (-0.28, -0.1),
            (-0.38, bottom + 0.34),
            (-1.0, bottom + 0.12),
        ]
        parts.append(materials.assign(_side_prism("Pedestal", outline, x - 0.13, x + 0.13), metal))
        for i in range(n):
            z = -d / 2 + slat_w / 2 + i * (slat_w + gap)
            parts.append(materials.assign(_sphere("Bolt", 0.045, (x, top, z), 6, 3), bolt))
    return shapes.join(parts, "MallBench")


def planter():
    """A square planter, 6 x 3 x 6 studs (Data/Mall `Planter`): brown quarry
    tile under a terrazzo cap with a rounded nose, the soil dried and
    sunk, the last leaves on it. (Its dead tree is DeadFicus.)"""
    tile = _quarry("PlanterTile")
    cap = _terrazzo("PlanterCap")
    soil = materials.paint("PlanterSoil", color=(62, 48, 36), roughness=0.95, grime=0.5)
    leaf = materials.paint("PlanterLeaf", color=(124, 92, 56), roughness=0.85, grime=0.3)
    W, H = 6.0, 3.0
    bottom = -H / 2
    cap_h, cap_w, wall = 0.34, 0.8, 0.5
    body = W - 0.16  # the cap overhangs the tiles
    wall_h = H - cap_h
    wy = bottom + wall_h / 2
    parts = []
    for sz in (-1, 1):
        parts.append(materials.assign(_box("Wall", (body, wall_h, wall), (0, wy, sz * (body / 2 - wall / 2)), 0.02), tile))
    for sx in (-1, 1):
        parts.append(materials.assign(_box("Wall", (wall, wall_h, body - 2 * wall), (sx * (body / 2 - wall / 2), wy, 0), 0.02), tile))
    cy = H / 2 - cap_h / 2
    for sz in (-1, 1):
        parts.append(materials.assign(_box("Cap", (W, cap_h, cap_w), (0, cy, sz * (W / 2 - cap_w / 2)), 0.1, 3), cap))
    for sx in (-1, 1):
        parts.append(materials.assign(_box("Cap", (cap_w, cap_h, W - 2 * cap_w + 0.02), (sx * (W / 2 - cap_w / 2), cy, 0), 0.1, 3), cap))
    inner = W - 2 * cap_w + 0.3
    earth = shapes.cushion("Soil", S(inner, 0.3, inner), G(0, H / 2 - 0.62, 0), puff=0.08, levels=2, roundness=0.2)
    parts.append(materials.assign(earth, soil))
    rng = random.Random(11)
    for _ in range(12):
        x, z = rng.uniform(-2.8, 2.8), rng.uniform(-2.8, 2.8)
        m = max(abs(x), abs(z))
        if m < inner / 2 - 0.25:
            y = H / 2 - 0.42  # on the soil
        elif W / 2 - cap_w + 0.1 < m < W / 2 - 0.15:
            y = H / 2 + 0.01  # on the cap
        else:
            continue
        parts.append(materials.assign(_leaf("Leaf", 0.36, 0.16, (x, y, z), (90 + rng.uniform(-10, 10), rng.uniform(-10, 10), rng.uniform(0, 180))), leaf))
    return shapes.join(parts, "MallPlanter")


def dead_ficus():
    """A planter's ficus, dead since the mall shut: a bare trunk 2.6 studs
    tall (Data/Mall `DeadPlant`, stretched to each one's height), thin
    branches forking up and out, a few brown leaves still hanging on. Built
    round the block's middle, the trunk up its y."""
    bark = materials.paint("FicusBark", color=(98, 82, 66), roughness=0.9, grime=0.45)
    leaf = materials.paint("FicusLeaf", color=(120, 88, 50), roughness=0.85, grime=0.35)
    rng = random.Random(4)
    h = 2.6
    y0 = -h / 2
    parts = [materials.assign(_tube("Trunk", [(0, y0, 0), (0.04, y0 + 0.8, 0.02), (-0.03, y0 + 1.5, 0.0), (0.02, y0 + 2.2, -0.02)], [0.11, 0.085, 0.065, 0.04], sides=8), bark)]
    for k in range(8):
        a = math.tau * k / 8 + rng.uniform(-0.3, 0.3)
        y = y0 + 1.15 + k * 0.13
        length = rng.uniform(0.45, 0.85)
        rise = rng.uniform(0.25, 0.45)
        tip_y = min(y + rise, h / 2 - 0.05)
        end = (math.cos(a) * length, tip_y, math.sin(a) * length)
        mid = (end[0] * 0.45, y + (tip_y - y) * 0.7, end[2] * 0.45)
        parts.append(materials.assign(_tube("Branch", [(0, y, 0), mid, end], [0.032, 0.022, 0.01], sides=5), bark))
        for _ in range(rng.randint(0, 2)):
            at = (end[0] + rng.uniform(-0.08, 0.08), end[1] - rng.uniform(0.04, 0.12), end[2] + rng.uniform(-0.08, 0.08))
            parts.append(materials.assign(_leaf("Leaf", 0.22, 0.1, at, (rng.uniform(-50, -20), 0, rng.uniform(0, 180))), leaf))
    return shapes.join(parts, "DeadFicus")


FOUNTAIN_R = 7.0  # Data/Mall `FountainBasin`: 14 across
FOUNTAIN_FLOOR = -0.3  # the drained floor, from the block's middle (World/MallBuilder's `hollow`)


def fountain_basin():
    """The fountain's basin, 14 studs across and 1.6 high (Data/Mall
    `FountainBasin`), drained: terrazzo outside, a polished terrazzo rim
    with a rounded nose, and sunk inside, the old aqua mosaic gone dull with
    a dark tide line round it, stains where the last water dried, a drain.
    Built round the block's middle (its floor at FOUNTAIN_FLOOR)."""
    side = _terrazzo("BasinSide", base=(176, 166, 150), roughness=0.45)
    rim = _terrazzo("BasinRim", base=(204, 196, 182), roughness=0.25)
    tile = _mosaic("BasinMosaic")
    tide = materials.paint("BasinTide", color=(52, 58, 48), roughness=0.7, grime=0.4)
    stain = materials.paint("BasinStain", color=(70, 84, 78), roughness=0.6, grime=0.3)
    metal = _bronze("BasinDrain", 0.5)
    r, top, bottom, inner = FOUNTAIN_R, 0.8, -0.8, FOUNTAIN_R - 0.95
    steps = 72
    F = FOUNTAIN_FLOOR
    # One closed solid (Roblox draws a face from its front only, so no open
    # strips), its faces then given their materials by where they are.
    body = _lathe(
        "Body",
        [
            (0.0, F),
            (inner - 0.05, F),
            (inner, F + 0.04),
            (inner, top - 0.06),
            (inner + 0.06, top),
            (r - 0.04, top),
            (r + 0.04, top - 0.01),
            (r + 0.08, top - 0.07),
            (r + 0.06, top - 0.15),
            (r, top - 0.2),
            (r, bottom + 0.06),
            (r - 0.04, bottom),
            (0.0, bottom),
        ],
        steps=steps,
    )

    def pick(x, y, z, up):
        out = math.hypot(x, z)
        if up > 0.9 and out < inner - 0.01:
            return 2  # the floor
        if out < inner + 0.01 and y < top - 0.07:
            return 2  # the inside wall
        if y > top - 0.22:
            return 1  # the rim
        return 0

    parts = [
        _materials_by(body, [side, rim, tile], pick),
        # Where the water stood all those years.
        materials.assign(
            _lathe("Tide", [(inner - 0.012, top - 0.42), (inner - 0.004, top - 0.42), (inner - 0.004, top - 0.34), (inner - 0.012, top - 0.34), (inner - 0.012, top - 0.42)], steps=steps),
            tide,
        ),
    ]
    rng = random.Random(7)
    for _ in range(7):
        a, d = rng.uniform(0, math.tau), rng.uniform(1.6, inner - 0.8)
        parts.append(materials.assign(_disc("Stain", rng.uniform(0.4, 1.1), FOUNTAIN_FLOOR + 0.002, (d * math.cos(a), d * math.sin(a)), 0.004), stain))
    # The drain: a bronze grate off the middle.
    gx, gz = 2.6, -2.2
    parts.append(materials.assign(_lathe("Drain", [(0.0, FOUNTAIN_FLOOR), (0.5, FOUNTAIN_FLOOR), (0.5, FOUNTAIN_FLOOR + 0.03), (0.44, FOUNTAIN_FLOOR + 0.04), (0.0, FOUNTAIN_FLOOR + 0.04)], (gx, 0, gz), 24), metal))
    for k in range(-3, 4):
        parts.append(materials.assign(_box("Slot", (0.06, 0.012, 0.7 - abs(k) * 0.07), (gx + k * 0.12, FOUNTAIN_FLOOR + 0.045, gz), 0.0, 1), tide))
    obj = shapes.join(parts, "FountainBasin")
    obj["bake_size"] = 2048
    return obj


def fountain_centre():
    """The fountain's centrepiece, standing in the basin (Data/Mall
    `FountainPillar`, 5 high and 2.4 across): a drum, a fluted shaft, a
    shallow bowl it spilled over and a finial with its nozzle, cast stone
    stained green-black under the lip. Built round the block's middle."""
    stone = _stone("CentreStone")
    stained = materials.paint("CentreStained", color=(112, 118, 100), roughness=0.8, grime=0.55)
    nozzle = _bronze("CentreNozzle", 0.5)
    base = -2.5 + 0.5  # the basin's floor (World/MallBuilder's `hollow`)
    parts = [
        materials.assign(_lathe("Drum", [(0.0, base - 0.5), (1.2, base - 0.5), (1.2, base + 0.6), (1.14, base + 0.68), (0.9, base + 0.74), (0.66, base + 0.8), (0.0, base + 0.8)]), stone),
    ]
    rings = []
    flutes = 16
    for y in (base + 0.8, base + 1.1, 1.0, 1.25):
        ring = []
        for k in range(flutes * 2):
            a = math.tau * k / (flutes * 2)
            rr = 0.56 if k % 2 == 0 else 0.5
            if y in (base + 0.8, 1.25):
                rr = 0.6
            ring.append((rr * math.cos(a), y, rr * math.sin(a)))
        rings.append(ring)
    parts.append(materials.assign(_loft("Shaft", rings), stone))
    bowl = _lathe(
        "Bowl",
        [(0.0, 1.2), (0.6, 1.2), (0.9, 1.32), (1.5, 1.52), (1.9, 1.72), (1.98, 1.84), (1.96, 1.92), (1.86, 1.94), (1.5, 1.82), (0.6, 1.72), (0.0, 1.7)],
        steps=40,
    )
    # Stained where the water ran over the lip and under it.
    parts.append(_materials_by(bowl, [stone, stained], lambda x, y, z, up: 1 if up < 0.0 else 0))
    parts.append(materials.assign(_lathe("Finial", [(0.0, 1.68), (0.3, 1.68), (0.28, 1.95), (0.18, 2.05), (0.24, 2.18), (0.2, 2.26), (0.0, 2.3)], steps=20), stone))
    parts.append(materials.assign(_lathe("Nozzle", [(0.0, 2.28), (0.05, 2.28), (0.05, 2.5), (0.0, 2.5)], steps=10), nozzle))
    return shapes.join(parts, "FountainCentre")


# The directory's map: Data/Mall's rooms ({x0, z0, x1, z1}, north up), the
# shops numbered as the list beside it reads.
MAP_ROOMS = [
    ("court", (-50, -30, 50, 30), (232, 224, 204), None),
    ("boutique", (-50, -62, -17, -30), (196, 120, 140), "1"),
    ("video", (-17, -62, 17, -30), (110, 140, 190), "2"),
    ("arcade", (17, -62, 50, -30), (150, 116, 180), "3"),
    ("electronics", (-50, 30, -17, 62), (96, 160, 150), "4"),
    ("deadshop", (17, 30, 50, 62), (170, 164, 150), None),
    ("diner", (-82, -26, -50, 26), (196, 96, 84), "5"),
    ("concourse", (50, -20, 118, 20), (170, 164, 150), None),
]


def directory_map(h=880, w=640, seed=19):
    """The mall directory's backlit map, yellowed: the plan, numbered, the
    list, and the red YOU ARE HERE."""
    img = prints.blank(h, w, (236, 228, 208))
    ink = (40, 34, 30)
    prints.rect(img, 0, 0, w, 76, (64, 52, 42))
    title = "DIRECTORY"
    prints.text(img, title, (w - prints.text_width(title, 44, 1.2)) / 2, 16, 44, (232, 222, 198), spacing=1.2)
    # The plan: x -86..122 and z -66..66 into the box below the title.
    x0, x1, z0, z1 = -86, 122, -66, 66
    left, top, right = 30, 104, w - 30
    k = (right - left) / (x1 - x0)
    bottom = top + (z1 - z0) * k

    def px(x, z):
        return left + (x - x0) * k, top + (z - z0) * k

    for name, (a, b, c, d), colour, label in MAP_ROOMS:
        (ax, ay), (cx, cy) = px(a, b), px(c, d)
        prints.rect(img, ax, ay, cx, cy, colour)
        prints.rect(img, ax, ay, cx, ay + 2, ink)
        prints.rect(img, ax, cy - 2, cx, cy, ink)
        prints.rect(img, ax, ay, ax + 2, cy, ink)
        prints.rect(img, cx - 2, ay, cx, cy, ink)
        if label:
            prints.disc(img, (ax + cx) / 2, (ay + cy) / 2, 15, (250, 246, 236))
            prints.text(img, label, (ax + cx) / 2 - 7, (ay + cy) / 2 - 10, 20, ink)
    # The hall beyond the shutter, hatched: closed.
    (ax, ay), (cx, cy) = px(50, -20), px(118, 20)
    for i in range(0, int(cx - ax) + int(cy - ay), 14):
        prints.stroke(img, [(ax + i, ay), (ax + i - (cy - ay), cy)], 2.0, (120, 114, 104), 0.7)
    prints.text(img, "CLOSED", (ax + cx) / 2 - prints.text_width("CLOSED", 18) / 2, (ay + cy) / 2 - 9, 18, ink)
    # The fountain.
    fx, fy = px(0, 0)
    prints.disc(img, fx, fy, 7 * k, (120, 170, 176))
    prints.ring(img, fx, fy, 7 * k, 2.5, ink)
    # You are here: the directory itself (Data/Mall `Directory`).
    hx, hy = px(6.5, 22)
    prints.disc(img, hx, hy, 12, (200, 40, 34))
    prints.ring(img, hx, hy, 19, 3, (200, 40, 34))
    prints.text(img, "YOU ARE HERE", hx + 26, hy - 9, 18, (170, 30, 26))
    # The list.
    y = bottom + 34
    for label, name in (("1", "BOUTIQUE"), ("2", "VIDEO RENTAL"), ("3", "ARCADE"), ("4", "ELECTRONICS"), ("5", "DINER")):
        prints.disc(img, left + 14, y + 12, 13, ink)
        prints.text(img, label, left + 8, y + 3, 18, (240, 234, 220))
        prints.text(img, name, left + 40, y + 1, 22, ink)
        y += 40
    prints.text(img, "SERVICE CORRIDOR - STAFF ONLY", left, y + 12, 16, (110, 100, 88))
    rng = np.random.default_rng(seed)
    return prints.age(img, rng, 0.1)


def header_plate(h=124, w=640):
    """The directory's header: INFORMATION in cream on bronze, a backlit
    plate gone dark."""
    img = prints.blank(h, w, (58, 48, 40))
    word = "INFORMATION"
    prints.text(img, word, (w - prints.text_width(word, 56, 1.4)) / 2, (h - 56) / 2, 56, (214, 200, 170), spacing=1.4)
    return prints.age(img, np.random.default_rng(29), 0.06)


def directory():
    """The mall directory, 4 x 7 x 0.8 studs (Data/Mall `Directory`; "you are
    here", the lobby's map): a dark bronze case on a plinth, its backlit
    map behind glass on both faces, long dark, under a header plate."""
    metal = _bronze("DirectoryBronze")
    pixels, (header, plan) = _atlas([header_plate(), directory_map()])
    picture = _picture("DirectoryMap", pixels, 0.66, roughness=0.25)
    W, H, D = 4.0, 7.0, 0.8
    bottom = -H / 2
    parts = [
        materials.assign(_box("Plinth", (W, 0.5, D), (0, bottom + 0.25, 0), 0.04, 2), metal),
        materials.assign(_box("Case", (W - 0.3, 6.2, D - 0.2), (0, bottom + 0.5 + 3.1, 0), 0.06, 2), metal),
        materials.assign(_box("Top", (W, 0.3, D), (0, H / 2 - 0.15, 0), 0.06, 3), metal),
    ]
    face = D / 2 - 0.1 + 0.005
    for sz in (-1, 1):
        parts.append(_card("Map", picture, 3.2, 4.4, (0, -0.1, sz * face), sz, plan))
        parts.append(_card("Header", picture, 3.2, 0.62, (0, 2.6, sz * face), sz, header))
        # The bezel round the map's glass.
        for dy in (-2.28, 2.08):
            parts.append(materials.assign(_box("Bezel", (3.4, 0.14, 0.06), (0, dy, sz * (face + 0.02)), 0.02, 2), metal))
        for dx in (-1.67, 1.67):
            parts.append(materials.assign(_box("Bezel", (0.14, 4.5, 0.06), (dx, -0.1, sz * (face + 0.02)), 0.02, 2), metal))
    obj = shapes.join(parts, "MallDirectory")
    obj["bake_size"] = 2048
    return obj


def photo_strip(h=600, w=520, seed=23):
    """The booth's samples behind glass: three strips of four, faded heads
    and shoulders (nobody you'd know), on its panel."""
    img = prints.blank(h, w, (232, 224, 206))
    rng = np.random.default_rng(seed)
    for s in range(3):
        x0 = 30 + s * 165
        prints.rect(img, x0, 30, x0 + 130, h - 60, (248, 246, 240))
        for f in range(4):
            y0 = 40 + f * ((h - 110) / 4)
            fh = (h - 110) / 4 - 10
            tone = (120 + 20 * s, 104 + 10 * f, 90)
            prints.rect(img, x0 + 10, y0, x0 + 120, y0 + fh, tone)
            cx = x0 + 65 + rng.uniform(-8, 8)
            prints.disc(img, cx, y0 + fh * 0.42, fh * 0.2, (70, 58, 50))
            prints.disc(img, cx, y0 + fh * 1.02, fh * 0.42, (60, 50, 44))
    prints.text(img, "4 POSES", 40, h - 44, 28, (60, 40, 34))
    img = prints.blur(img, 1)
    return prints.age(img, rng, 0.12)


def booth_sign(h=200, w=820):
    img = prints.blank(h, w, (238, 228, 200))
    prints.rect(img, 0, 0, w, 14, (150, 36, 34))
    prints.rect(img, 0, h - 14, w, h, (150, 36, 34))
    word = "PHOTOS"
    prints.text(img, word, (w - prints.text_width(word, 112, 1.3)) / 2, 30, 112, (150, 36, 34), spacing=1.3, bold=1.0)
    small = "4 POSES - 1.00"
    prints.text(img, small, (w - prints.text_width(small, 30)) / 2, 152, 30, (60, 40, 34))
    return prints.age(img, np.random.default_rng(5), 0.08)


def photo_booth():
    """The photo booth, 5 x 8 x 5 studs (Data/Mall `PhotoBooth`): a red and
    cream enamelled cabinet, its sign box on top, the sample strips and the
    coin plate on the front's left, and on its right the way in, a red
    curtain most of the way across it. Its front is +z."""
    red = materials.paint("BoothRed", color=(150, 38, 34), roughness=0.32, grime=0.3)
    cream = materials.paint("BoothCream", color=(226, 216, 192), roughness=0.36, grime=0.3)
    dark = materials.paint("BoothInside", color=(28, 24, 22), roughness=0.8, grime=0.1)
    chrome = _chrome("BoothChrome")
    curtain = materials.velvet("BoothCurtain", color=(96, 28, 30))
    pixels, (sign_rect, samples_rect) = _atlas([booth_sign(), photo_strip()])
    picture = _picture("BoothPictures", pixels, 0.36, roughness=0.25)
    W, H, D = 5.0, 8.0, 5.0
    bottom = -H / 2
    body_top = bottom + 6.6
    door_x0, door_x1, door_top, recess = 0.2, 2.25, bottom + 5.6, 1.0
    front = D / 2
    parts = [
        # The cabinet round the doorway: its left, the back, the lintel, the
        # right jamb.
        materials.assign(_box("Body", (W / 2 + door_x0, 6.6, D), (-W / 2 + (W / 2 + door_x0) / 2, bottom + 3.3, 0), 0.08, 2), red),
        materials.assign(_box("Body", (W / 2 - door_x0, 6.6, D - recess), (door_x0 + (W / 2 - door_x0) / 2, bottom + 3.3, -recess / 2), 0.08, 2), red),
        materials.assign(_box("Lintel", (door_x1 - door_x0 + 0.02, body_top - door_top, recess), ((door_x0 + door_x1) / 2, (door_top + body_top) / 2, front - recess / 2), 0.04, 2), red),
        materials.assign(_box("Jamb", (W / 2 - door_x1, 6.6, recess), ((door_x1 + W / 2) / 2, bottom + 3.3, front - recess / 2), 0.04, 2), red),
        materials.assign(_box("Inside", (door_x1 - door_x0, door_top - bottom, 0.02), ((door_x0 + door_x1) / 2, (bottom + door_top) / 2, front - recess + 0.012), 0.0, 1), dark),
        # The cream band round its waist and the kick plate.
        materials.assign(_box("Band", (W + 0.04, 0.5, D + 0.04), (0, bottom + 4.6, 0), 0.04, 2), cream),
        materials.assign(_box("Kick", (W + 0.03, 0.4, D + 0.03), (0, bottom + 0.2, 0), 0.03, 2), chrome),
        # The sign box, a little in from the body, its face on three sides.
        materials.assign(_box("SignBox", (W - 0.2, H / 2 - body_top + 0.0, D - 0.2), (0, (body_top + H / 2) / 2, 0), 0.06, 2), cream),
        _card("Sign", picture, W - 0.5, 1.12, (0, (body_top + H / 2) / 2, (D - 0.2) / 2 + 0.005), 1, sign_rect),
        # The samples, the coin plate, the slot the strip drops into.
        _card("Samples", picture, 1.9, 2.2, (-1.25, bottom + 3.0, front + 0.012), 1, samples_rect),
        # (Its frame behind the samples, standing out round them: it hid them
        # in the first bake.)
        materials.assign(_box("SampleFrame", (2.08, 2.38, 0.04), (-1.25, bottom + 3.0, front - 0.01), 0.015, 2), chrome),
        materials.assign(_box("CoinPlate", (0.7, 0.9, 0.06), (-1.25, bottom + 1.5, front + 0.02), 0.02, 2), chrome),
        materials.assign(_box("CoinSlot", (0.08, 0.32, 0.02), (-1.25, bottom + 1.62, front + 0.055), 0.0, 1), dark),
        materials.assign(_box("Hood", (1.1, 0.12, 0.34), (-1.25, bottom + 0.95, front + 0.16), 0.03, 2), chrome),
        materials.assign(_box("Delivery", (0.9, 0.36, 0.02), (-1.25, bottom + 0.75, front + 0.012), 0.0, 1), dark),
        # The rail and the curtain on it, drawn most of the way across.
        materials.assign(_tube("Rail", [(door_x0 - 0.02, door_top - 0.12, front - 0.12), (door_x1 + 0.02, door_top - 0.12, front - 0.12)], 0.035, 8), chrome),
    ]
    folds = 9
    x_from, x_to = door_x0 + 0.55, door_x1
    rows = []
    for y in (bottom + 0.3, door_top - 0.14):
        ring = []
        for i in range(folds * 2 + 1):
            t = i / (folds * 2)
            x = x_from + (x_to - x_from) * t
            z = front - 0.14 + (0.08 if i % 2 else -0.04)
            ring.append((x, y, z))
        rows.append(ring)
    # A pleated sheet, front faces only, and its back a little behind it.
    bm = bmesh.new()
    for off in (0.0, -0.025):
        verts = [[bm.verts.new(G(x, y, z + off)) for x, y, z in row] for row in rows]
        for i in range(len(rows[0]) - 1):
            face = (verts[0][i], verts[0][i + 1], verts[1][i + 1], verts[1][i])
            bm.faces.new(face if off == 0.0 else tuple(reversed(face)))
    for f in bm.faces:
        f.normal_update()
    curtain_obj = _new("Curtain", bm)
    parts.append(materials.assign(shapes.smooth(curtain_obj, 80), curtain))
    obj = shapes.join(parts, "PhotoBooth")
    obj["bake_size"] = 2048
    return obj


def shopping_cart():
    """A shopping cart, its basket 2.2 x 1.6 x 3.4 studs (Data/Mall `Cart`):
    chromed wire tapering to its nose, the handle's orange grip, the lower
    tray and four casters. Built round the basket's middle; the wheels
    reach the floor 2.1 below it."""
    wire = _chrome("CartWire")
    grip = materials.paint("CartGrip", color=(200, 92, 32), roughness=0.4, grime=0.3)
    rubber = materials.paint("CartRubber", color=(30, 28, 28), roughness=0.85, grime=0.1)
    w_top, w_bot, d_top, d_bot = 2.2, 1.8, 3.4, 2.9
    y_top, y_bot = 0.8, -0.8
    nose = -1.0  # the basket tapers toward -z
    r = 0.022
    parts = []

    def rim(w, d, y, zc):
        return [(-w / 2, y, zc - d / 2), (w / 2, y, zc - d / 2), (w / 2, y, zc + d / 2), (-w / 2, y, zc + d / 2), (-w / 2, y, zc - d / 2)]

    top_c, bot_c = 0.0, 0.25
    parts.append(materials.assign(_tube("Rim", rim(w_top, d_top, y_top, top_c), 0.045, 6), wire))
    parts.append(materials.assign(_tube("Rim", rim(w_bot, d_bot, y_bot, bot_c), 0.035, 6), wire))

    def lerp(a, b, t):
        return tuple(a[i] + (b[i] - a[i]) * t for i in range(3))

    # The sides' uprights and rails, between the top and bottom rims.
    for sx in (-1, 1):
        a0, a1 = (sx * w_top / 2, y_top, top_c - d_top / 2), (sx * w_top / 2, y_top, top_c + d_top / 2)
        b0, b1 = (sx * w_bot / 2, y_bot, bot_c - d_bot / 2), (sx * w_bot / 2, y_bot, bot_c + d_bot / 2)
        for i in range(1, 20):
            t = i / 20
            parts.append(materials.assign(_tube("Wire", [lerp(a0, a1, t), lerp(b0, b1, t)], r, 4, caps=False), wire))
        for j in range(1, 5):
            t = j / 5
            parts.append(materials.assign(_tube("Wire", [lerp(a0, b0, t), lerp(a1, b1, t)], r, 4, caps=False), wire))
    for sz, (zt, zb) in ((-1, (top_c - d_top / 2, bot_c - d_bot / 2)), (1, (top_c + d_top / 2, bot_c + d_bot / 2))):
        a0, a1 = (-w_top / 2, y_top, zt), (w_top / 2, y_top, zt)
        b0, b1 = (-w_bot / 2, y_bot, zb), (w_bot / 2, y_bot, zb)
        for i in range(1, 12):
            t = i / 12
            parts.append(materials.assign(_tube("Wire", [lerp(a0, a1, t), lerp(b0, b1, t)], r, 4, caps=False), wire))
        for j in range(1, 5):
            t = j / 5
            parts.append(materials.assign(_tube("Wire", [lerp(a0, b0, t), lerp(a1, b1, t)], r, 4, caps=False), wire))
    for i in range(1, 10):
        x = -w_bot / 2 + w_bot * i / 10
        parts.append(materials.assign(_tube("Wire", [(x, y_bot, bot_c - d_bot / 2), (x, y_bot, bot_c + d_bot / 2)], r, 4, caps=False), wire))
    # The handle, up and back from the basket's back.
    back = top_c + d_top / 2
    for sx in (-1, 1):
        parts.append(materials.assign(_tube("HandleArm", [(sx * w_top / 2, y_top - 0.1, back), (sx * w_top / 2, y_top + 0.35, back + 0.32)], 0.04, 6), wire))
    parts.append(materials.assign(_tube("Grip", [(-w_top / 2 - 0.02, y_top + 0.35, back + 0.32), (w_top / 2 + 0.02, y_top + 0.35, back + 0.32)], 0.07, 10), grip))
    # The frame down to the casters, and the tray on it.
    floor = -2.1
    base_y = floor + 0.42
    for sx in (-1, 1):
        parts.append(materials.assign(_tube("Leg", [(sx * w_bot / 2, y_bot, bot_c + d_bot / 2 - 0.1), (sx * 0.85, base_y, 1.5)], 0.05, 6), wire))
        parts.append(materials.assign(_tube("Leg", [(sx * w_bot / 2, y_bot, bot_c - d_bot / 2 + 0.1), (sx * 0.6, base_y, nose - 0.4)], 0.04, 6), wire))
        parts.append(materials.assign(_tube("Base", [(sx * 0.85, base_y, 1.5), (sx * 0.6, base_y, nose - 0.4)], 0.05, 6), wire))
    for i in range(7):
        t = i / 6
        z = 1.4 + (nose - 0.3 - 1.4) * t
        hw = 0.85 + (0.6 - 0.85) * t
        parts.append(materials.assign(_tube("Tray", [(-hw, base_y + 0.04, z), (hw, base_y + 0.04, z)], r, 4, caps=False), wire))
    for x, z in ((0.85, 1.5), (-0.85, 1.5), (0.6, nose - 0.4), (-0.6, nose - 0.4)):
        parts.append(materials.assign(_tube("Fork", [(x, base_y, z), (x, floor + 0.2, z)], 0.035, 6), wire))
        wheel = _lathe("Wheel", [(0.0, -0.06), (0.17, -0.06), (0.2, -0.02), (0.2, 0.02), (0.17, 0.06), (0.0, 0.06)], steps=14)
        parts.append(materials.assign(shapes.turn(wheel, (0, 90, 0), G(x, floor + 0.2, z)), rubber))
    return shapes.join(parts, "ShoppingCart")


def _lightbox(name, face_w, face_h):
    """A backlit poster case round an ad's face (World/MallBuilder's AdFrame
    and AdFace): a dark bronze box behind it, and a rounded bezel standing
    proud of the face, its inside edge on the face's (the face is the ad's,
    so nothing of it is covered). Its front is +z; the face's front sits 0.1
    behind the bezel's. Built round the box's middle: 0.8 deep."""
    metal = _bronze(name + "Bronze")
    screw = _chrome(name + "Screw")
    W, H = face_w + 0.6, face_h + 0.6
    parts = [materials.assign(_box("Back", (W - 0.06, H - 0.06, 0.6), (0, 0, -0.1), 0.08, 3), metal)]
    b = 0.3
    for sy in (-1, 1):
        parts.append(materials.assign(_box("Bezel", (W, b, 0.2), (0, sy * (H / 2 - b / 2), 0.3), 0.07, 3), metal))
    for sx in (-1, 1):
        parts.append(materials.assign(_box("Bezel", (b, H - 2 * b + 0.02, 0.2), (sx * (W / 2 - b / 2), 0, 0.3), 0.07, 3), metal))
    for sx in (-1, 1):
        for sy in (-1, 1):
            parts.append(materials.assign(_sphere("Screw", 0.05, (sx * (W / 2 - b / 2), sy * (H / 2 - b / 2), 0.4), 8, 4), screw))
    # A little cord into its back, the generator's (World/MallBuilder's cables
    # come up the wall to it).
    obj = shapes.join(parts, name)
    obj["bake_size"] = 512
    return obj


def lightbox_wide():
    """The west lightboxes' case: an 11 x 6.2 face (Data/Mall `Ads`)."""
    return _lightbox("LightboxWide", 11.0, 6.2)


def lightbox_small():
    """The east lightboxes' case: an 8.4 x 5 face."""
    return _lightbox("LightboxSmall", 8.4, 5.0)


def grille_box():
    """A shopfront's rolled-up grille in its box over the opening (World/
    MallBuilder's GrilleBox, a front's width + 1 by 1.4 by 1.4; stretched to
    each front): a sheet-steel hood rounded at its front, end brackets, and
    under it the grille's bottom bar with its lock and two pull handles. Its
    front is +z (toward the court)."""
    steel = materials.paint("GrilleSteel", color=(96, 92, 86), roughness=0.5, grime=0.45)
    bar = materials.paint("GrilleBar", color=(66, 64, 60), roughness=0.45, grime=0.4)
    chrome = _chrome("GrilleChrome")
    L = 29.0
    hood = [(-0.7, -0.7), (-0.42, -0.7), (-0.42, -0.5), (0.52, -0.5), (0.52, -0.7), (0.7, -0.7), (0.7, -0.1)]
    for k in range(1, 8):
        a = math.radians(90 * k / 8)
        hood.append((-0.1 + 0.8 * math.cos(a), -0.1 + 0.8 * math.sin(a)))
    hood.append((-0.7, 0.7))
    parts = [materials.assign(_side_prism("Hood", hood, -L / 2 + 0.12, L / 2 - 0.12), steel)]
    for sx in (-1, 1):
        parts.append(materials.assign(_box("Bracket", (0.12, 1.4, 1.4), (sx * (L / 2 - 0.06), 0, 0), 0.02, 2), steel))
    parts.append(materials.assign(_box("BottomBar", (L - 0.6, 0.16, 0.6), (0, -0.56, 0.05), 0.03, 2), bar))
    for x in (-L / 4, L / 4):
        parts.append(materials.assign(_tube("Handle", [(x - 0.35, -0.62, 0.36), (x - 0.35, -0.68, 0.5), (x + 0.35, -0.68, 0.5), (x + 0.35, -0.62, 0.36)], 0.035, 6), chrome))
    parts.append(materials.assign(_lathe("Lock", [(0.0, -0.66), (0.12, -0.66), (0.12, -0.48), (0.0, -0.48)], (0, 0, 0.38), 12), chrome))
    return shapes.join(parts, "GrilleBox")


def column():
    """A gallery's column (World/MallBuilder's Column: 20.8 high, 2 across,
    floor to the gallery's slab): a dark bronze plinth, the plaster shaft
    with a bronze band at the knee, a flared collar under the slab. Built
    round its middle."""
    plaster = _plaster("ColumnPlaster", color=(200, 192, 176))
    metal = _bronze("ColumnBronze")
    h = 20.8
    b, t = -h / 2, h / 2
    parts = [
        materials.assign(_lathe("Plinth", [(0.0, b), (1.32, b), (1.32, b + 0.9), (1.26, b + 0.98), (1.06, b + 1.04), (0.0, b + 1.04)], steps=36), metal),
        materials.assign(_lathe("Shaft", [(0.0, b + 1.0), (1.0, b + 1.0), (1.0, t - 1.0), (0.0, t - 1.0)], steps=36), plaster),
        materials.assign(_lathe("Band", [(0.98, b + 3.2), (1.04, b + 3.24), (1.04, b + 3.46), (0.98, b + 3.5), (0.98, b + 3.2)], steps=36), metal),
        materials.assign(_lathe("Collar", [(0.0, t - 1.02), (1.0, t - 1.02), (1.04, t - 0.9), (1.16, t - 0.55), (1.32, t - 0.24), (1.36, t - 0.2), (1.36, t), (0.0, t)], steps=36), plaster),
    ]
    obj = shapes.join(parts, "MallColumn")
    obj["bake_size"] = 1024
    return obj


PARAPET_LENGTH = 10.0  # World/MallBuilder lays a gallery's run in these, stretched to fit


def gallery_parapet():
    """A length of the gallery's edge over the void (World/MallBuilder: its
    Parapet and Handrail, with the slab's edge below): the plaster parapet
    3.6 high on the slab, a terrazzo cap with a rounded nose, a bronze band
    along the void side, a bronze fascia over the slab's edge, the brass
    handrail on posts. 10 long, 5.1 high (1.2 of slab, 3.6 of parapet, 0.3 of
    rail), its front +z over the void. Built round its box's middle."""
    plaster = _plaster("ParapetPlaster")
    cap = _terrazzo("ParapetCap", base=(196, 188, 174), roughness=0.3)
    metal = _bronze("ParapetBronze")
    brass = materials.brass("ParapetRail", color=(140, 112, 70), roughness=0.35)
    L = PARAPET_LENGTH
    b = -2.55  # the slab's underside
    slab_top = b + 1.2
    top = slab_top + 3.6
    parts = [
        materials.assign(_box("Fascia", (L, 1.2, 0.12), (0, b + 0.6, 0.3), 0.03, 2), metal),
        materials.assign(_box("Body", (L, 3.6 - 0.18, 0.6), (0, slab_top + (3.6 - 0.18) / 2, 0), 0.0, 1), plaster),
        materials.assign(_box("Band", (L, 0.5, 0.06), (0, slab_top + 2.2, 0.32), 0.02, 2), metal),
        materials.assign(_box("Cap", (L, 0.2, 0.74), (0, top - 0.1, 0.03), 0.08, 3), cap),
    ]
    rail_y = top + 0.3 - 0.11
    for x in (-3.75, -1.25, 1.25, 3.75):
        parts.append(materials.assign(_tube("Post", [(x, top, 0.0), (x, rail_y, 0.0)], 0.04, 6), brass))
    parts.append(materials.assign(_tube("Handrail", [(-L / 2, rail_y, 0.0), (L / 2, rail_y, 0.0)], 0.11, 12, caps=True), brass))
    return shapes.join(parts, "GalleryParapet")


def chandelier():
    """The court's chandelier, dead (Data/Mall `ChandelierRing` and its
    globes, the cord above): a brass ring 12 across on six spokes from the
    hub, six opal globes hanging from it, an inner ring of six smaller ones
    lower down and a big one in the middle, every bulb long out. Built round
    the ring's middle."""
    brass = materials.brass("ChandelierBrass", color=(132, 106, 66), roughness=0.4)
    glass = _glass_dead("ChandelierGlass")
    R, Ri = 6.0, 3.1
    parts = [materials.assign(_torus("Ring", R, 0.2, 48, 8), brass)]
    inner = _torus("InnerRing", Ri, 0.14, 32, 6)
    inner.location = (0, 0, -2.0)
    parts.append(materials.assign(inner, brass))
    parts.append(materials.assign(_lathe("Hub", [(0.0, -0.5), (0.55, -0.5), (0.6, -0.2), (0.45, 0.3), (0.18, 0.55), (0.18, 0.9), (0.0, 0.9)], steps=20), brass))
    for k in range(6):
        a = math.tau * k / 6
        ca, sa = math.cos(a), math.sin(a)
        parts.append(materials.assign(_tube("Spoke", [(0.5 * ca, 0.0, 0.5 * sa), (R * 0.5 * ca, 0.18, R * 0.5 * sa), (R * ca, 0.0, R * sa)], 0.08, 6), brass))
        # The outer globes hang where the ring's every other segment was.
        gx, gz = R * ca, R * sa
        parts.append(materials.assign(_tube("Stem", [(gx, 0.0, gz), (gx, -0.42, gz)], 0.05, 6), brass))
        parts.append(materials.assign(_lathe("Fitter", [(0.0, -0.4), (0.08, -0.4), (0.3, -0.46), (0.36, -0.62), (0.0, -0.62)], (gx, 0, gz), 14), brass))
        parts.append(materials.assign(_sphere("Globe", 0.9, (gx, -1.4, gz), 16, 8), glass))
        # The inner ring's rods and globes, half a turn round.
        b = a + math.tau / 12
        ix, iz = Ri * math.cos(b), Ri * math.sin(b)
        parts.append(materials.assign(_tube("Rod", [(R * math.cos(b), 0.0, R * math.sin(b)), (ix, -2.0, iz)], 0.04, 5), brass))
        parts.append(materials.assign(_sphere("Globe", 0.65, (ix, -2.8, iz), 14, 7), glass))
        parts.append(materials.assign(_lathe("Fitter", [(0.0, -2.1), (0.06, -2.1), (0.24, -2.16), (0.26, -2.3), (0.0, -2.3)], (ix, 0, iz), 12), brass))
    parts.append(materials.assign(_tube("Drop", [(0, -0.5, 0), (0, -1.5, 0)], 0.07, 8), brass))
    parts.append(materials.assign(_sphere("Globe", 1.05, (0, -2.5, 0), 18, 9), glass))
    return shapes.join(parts, "MallChandelier")


MALL1 = [
    bench,
    planter,
    dead_ficus,
    fountain_basin,
    fountain_centre,
    directory,
    photo_booth,
    shopping_cart,
    lightbox_wide,
    lightbox_small,
    grille_box,
    column,
    gallery_parapet,
    chandelier,
]
