"""The atmosphere (the visual rework V4, the kit's last rollout batch, kit9):
the everyday things that make the house lived in, and the night outside.

- On tops (World/Dressing): the hall's rotary telephone, a family photo in
  its standing frame (the photo is the game's, aged by Drift), and the
  clutter: a mug, a side plate (with and without a crust), two stacks of
  books, a vase (with and without dried stems), two magazines;
- in drawers (World/Junk, Data/Finds): a cassette, a matchbox, a bundle of
  letters, a candle in its enamel stick, a spool of thread, a pill bottle,
  two D-cells in a rubber band;
- in every room, its light switch (Services/InteractService): the plate and
  the toggle that flips; in the safe room, the box of batteries;
- outside (World/Exterior): two oaks and a tree turning, two bare trees, two
  conifers, two bushes, an arborvitae for the garden, the streetlamp.

Each is built in the game's own frame (things.G, S: x across, y up, z +Z)
round the grey-box it dresses, and faces where that does: the things on a
top face the room down their spot's -z (World/Dressing), as the telephone
and the frame always have; a switch's front is -z, off the wall at +z.
The plants stand on y = 0, their roots a little under the lawn.

A plant's leaves are solid masses run together (Studio's meshes take no
cut-out leaves: AlphaMode has no cutout), lumpy enough to break their
outline; each wears a leaf texture, and World/Exterior tints each tree.
"""

import math
import random

import bmesh
import bpy
from mathutils import Vector, noise

from . import materials, prints, shapes
from .fittings import _galv, _loft, _rounded_rect
from .house import _chrome
from .materials import Nodes, _srgb
from .things import G, _box, _dark, _lathe, _new, _ring, _settle, _silver, _sphere, _torus, _tube


# Materials -----------------------------------------------------------------------


def _plastic(name, color, roughness=0.32):
    return materials.paint(name, color=color, roughness=roughness, grime=0.08)


def _glaze(name, color, roughness=0.16):
    """Glazed earthenware or china: smooth, a faint mottle."""
    return materials.paint(name, color=color, roughness=roughness, grime=0.05)


def _paper(name, color=(226, 216, 190)):
    return materials.paint(name, color=color, roughness=0.85, grime=0.15)


def _picture(name, pixels, share, roughness=0.6):
    mat = materials.image(name, pixels, roughness=roughness, bump=0.02)
    mat["uv_share"] = share
    return mat


def _enamel(name, color=(234, 232, 224), chip=(26, 26, 30)):
    """Enamelled steel: glossy white, chipped black in spots."""
    mat = bpy.data.materials.new(name)
    n = Nodes(mat)
    m = n.mapping(scale=(1.0, 1.0, 1.0))
    spots = n.noise(m.outputs["Vector"], 9.0, 4.0, 0.6)
    ramp = n.ramp(spots.outputs["Fac"], [(0.0, _srgb(color)), (0.7, _srgb(color)), (0.72, _srgb(chip)), (1.0, _srgb(chip))])
    n.link(ramp.outputs["Color"], n.bsdf.inputs["Base Color"])
    n.bsdf.inputs["Roughness"].default_value = 0.14
    return mat


def _foliage(name, colours, cell=0.32, roughness=0.7):
    """Leaves: one cell of a voronoi per leaf, each its own colour from
    `colours` (0-255, darkest first), domed so each catches light; and
    broad patches lighter and darker over a crown."""
    mat = bpy.data.materials.new(name)
    n = Nodes(mat)
    m = n.mapping(scale=(1.0, 1.0, 1.0))
    cells = n.add("ShaderNodeTexVoronoi")
    cells.inputs["Scale"].default_value = 1.0 / cell
    n.link(m.outputs["Vector"], cells.inputs["Vector"])
    stops = [(i / (len(colours) - 1), _srgb(c)) for i, c in enumerate(colours)]
    sep = n.add("ShaderNodeSeparateColor")
    n.link(cells.outputs["Color"], sep.inputs["Color"])
    ramp = n.ramp(sep.outputs[0], stops)
    patch = n.noise(m.outputs["Vector"], 0.35, 3.0, 0.5)
    shade = n.ramp(patch.outputs["Fac"], [(0.3, (0.62, 0.62, 0.62, 1.0)), (0.7, (1.0, 1.0, 1.0, 1.0))])
    mixed = n.mix_colour(ramp.outputs["Color"], shade.outputs["Color"], 1.0, "MULTIPLY")
    n.link(mixed, n.bsdf.inputs["Base Color"])
    n.bsdf.inputs["Roughness"].default_value = roughness
    dome = n.math("SUBTRACT", 1.0, cells.outputs["Distance"])
    n.bump(dome.outputs["Value"], 0.65, 0.08)
    return mat


def _bark(name, color=(58, 50, 42), dark=(28, 24, 20)):
    """Bark: furrows running up the trunk, broken by noise."""
    mat = bpy.data.materials.new(name)
    n = Nodes(mat)
    m = n.mapping(scale=(3.0, 3.0, 0.6))
    wave = n.add("ShaderNodeTexWave", wave_type="BANDS", bands_direction="X")
    wave.inputs["Scale"].default_value = 2.5
    wave.inputs["Distortion"].default_value = 9.0
    wave.inputs["Detail"].default_value = 4.0
    n.link(m.outputs["Vector"], wave.inputs["Vector"])
    lichen = n.noise(m.outputs["Vector"], 2.0, 4.0, 0.6)
    ramp = n.ramp(wave.outputs["Fac"], [(0.0, _srgb(dark)), (0.45, _srgb(color)), (1.0, _srgb(color))])
    grey = n.ramp(lichen.outputs["Fac"], [(0.55, (1.0, 1.0, 1.0, 1.0)), (0.75, (1.25, 1.3, 1.2, 1.0))])
    n.link(n.mix_colour(ramp.outputs["Color"], grey.outputs["Color"], 1.0, "MULTIPLY"), n.bsdf.inputs["Base Color"])
    n.bsdf.inputs["Roughness"].default_value = 0.9
    n.bump(wave.outputs["Fac"], 0.9, 0.1)
    return mat


# Geometry helpers ------------------------------------------------------------------


def _surface(name, verts, faces, uvs=None, facing=None):
    """A mesh from points in the game's frame and faces (lists of indices),
    its "Pattern" UVs (one per point) if given, every face turned toward
    `facing` (a direction in the game's frame) if given."""
    bm = bmesh.new()
    vs = [bm.verts.new(G(*p)) for p in verts]
    fs = [bm.faces.new([vs[i] for i in f]) for f in faces]
    if facing is not None:
        want = Vector(G(*facing))
        for f in fs:
            f.normal_update()
            if f.normal.dot(want) < 0:
                f.normal_flip()
    obj = _new(name, bm)
    if uvs:
        layer = obj.data.uv_layers.new(name="Pattern")
        for loop in obj.data.loops:
            layer.data[loop.index].uv = uvs[loop.vertex_index]
    return obj


def _card(name, picture_mat, w, d, y, at=(0.0, 0.0), facing=(0, 1, 0)):
    """A flat picture lying face up at height y, w across and d deep round
    `at` (x, z), the picture's top toward +z (away from whoever reads it
    from the front, -z, whose left is +x: the game's frame is right-handed)."""
    x0, z0 = at
    verts = [(x0 - w / 2, y, z0 - d / 2), (x0 + w / 2, y, z0 - d / 2), (x0 + w / 2, y, z0 + d / 2), (x0 - w / 2, y, z0 + d / 2)]
    uvs = [(1.0, 0.0), (0.0, 0.0), (0.0, 1.0), (1.0, 1.0)]
    return materials.assign(_surface(name, verts, [(0, 1, 2, 3)], uvs, facing), picture_mat)


def _upright_card(name, picture_mat, w, h, at, facing_z):
    """A flat picture standing in the x-y plane round `at`, facing +z or -z
    (facing_z = 1 or -1), its top up and read the right way from there."""
    x0, y0, z0 = at
    left, right = (x0 + w / 2, x0 - w / 2) if facing_z < 0 else (x0 - w / 2, x0 + w / 2)
    verts = [(left, y0 - h / 2, z0), (right, y0 - h / 2, z0), (right, y0 + h / 2, z0), (left, y0 + h / 2, z0)]
    uvs = [(0.0, 0.0), (1.0, 0.0), (1.0, 1.0), (0.0, 1.0)]
    return materials.assign(_surface(name, verts, [(0, 1, 2, 3)], uvs, (0, 0, facing_z)), picture_mat)


def _band(name, picture_mat, radius, y0, y1, a0=-math.pi, a1=math.pi, steps=32):
    """A label round an upright cylinder from angle a0 to a1 (0 at the front,
    -z; positive toward -x, the right of whoever looks from the front), y0 to
    y1; the picture's middle at the front."""
    verts, uvs = [], []
    for i in range(steps + 1):
        a = a0 + (a1 - a0) * i / steps
        for y, v in ((y0, 0.0), (y1, 1.0)):
            verts.append((-radius * math.sin(a), y, -radius * math.cos(a)))
            uvs.append((i / steps, v))
    faces = [(2 * i, 2 * i + 2, 2 * i + 3, 2 * i + 1) for i in range(steps)]
    obj = _surface(name, verts, faces, uvs)
    # (Outward: each face away from the axis.)
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    for f in bm.faces:
        f.normal_update()
        c = f.calc_center_median()
        if f.normal.dot(Vector((c.x, c.y, 0))) < 0:
            f.normal_flip()
    bm.to_mesh(obj.data)
    bm.free()
    return materials.assign(obj, picture_mat)


def _shell(name, rings):
    """A closed body through rings (bottom up, each the same count, the
    game's frame), capped top and bottom with fans."""
    bm = bmesh.new()
    verts = [[bm.verts.new(G(*p)) for p in ring] for ring in rings]
    n = len(rings[0])
    for a, b in zip(verts, verts[1:]):
        for i in range(n):
            j = (i + 1) % n
            bm.faces.new((a[i], a[j], b[j], b[i]))
    for ring, top in ((verts[0], False), (verts[-1], True)):
        c = sum((v.co for v in ring), Vector()) / n
        hub = bm.verts.new(c)
        for i in range(n):
            j = (i + 1) % n
            bm.faces.new((ring[i], ring[j], hub) if top else (ring[j], ring[i], hub))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return shapes.smooth(_new(name, bm), 50)


def _ring_at(w, d, r, y, cz=0.0, per_corner=4):
    return [(x, yy, z + cz) for x, yy, z in _rounded_rect(w, d, r, y, per_corner)]


def _column(name, outline, y0, y1):
    """An outline in the game's floor plane [(x, z), ...] stood up from y0 to
    y1 (a ridged cap, a fluted thing)."""
    bm = bmesh.new()
    low = [bm.verts.new(G(x, y0, z)) for x, z in outline]
    high = [bm.verts.new(G(x, y1, z)) for x, z in outline]
    n = len(outline)
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new((low[i], low[j], high[j], high[i]))
    caps = [bm.faces.new(list(reversed(low))), bm.faces.new(high)]
    bmesh.ops.triangulate(bm, faces=caps)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return shapes.smooth(_new(name, bm), 30)


def _loop_path(points, closed=True):
    return points + [points[0]] if closed else points


def _smooth_path(points, per=5):
    """A smooth curve through points (the game's frame), `per` steps between
    each pair (Catmull-Rom): a mug's handle without corners."""
    pts = [Vector(p) for p in points]
    out = []
    for i in range(len(pts) - 1):
        p0 = pts[max(i - 1, 0)]
        p1, p2 = pts[i], pts[i + 1]
        p3 = pts[min(i + 2, len(pts) - 1)]
        for k in range(per):
            t = k / per
            t2, t3 = t * t, t * t * t
            q = 0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2 + (-p0 + 3 * p1 - 3 * p2 + p3) * t3)
            out.append(tuple(q))
    out.append(tuple(pts[-1]))
    return out


def _place(obj, degrees, at):
    """Turns a piece built round the origin (Blender's axes, degrees) and
    puts it at the game's `at`."""
    return shapes.turn(obj, degrees, G(*at))


def _finish(parts, name, bake=512):
    piece = shapes.join(parts, name)
    piece["bake_size"] = bake
    return piece


# The telephone (World/Dressing) ---------------------------------------------------

DIAL_TILT = 33.0  # degrees the dial's face leans back from flat toward the front


def telephone():
    """A beige rotary desk telephone, about 1.1 x 0.6 x 0.8 (Dressing's
    Telephone: its front, the dial, toward -z): a moulded body sloping up to
    the cradle, the dial on the slope, the handset across the cradle's horns
    and its coiled cord down the side."""
    beige = _plastic("PhoneBeige", (198, 186, 160))
    dark = _plastic("PhoneDark", (40, 36, 32), 0.4)
    chrome = _chrome("PhoneChrome")
    parts = []
    rings = [
        _ring_at(0.9, 0.8, 0.12, 0.0),
        _ring_at(0.93, 0.83, 0.13, 0.025),
        _ring_at(0.91, 0.81, 0.13, 0.06),
        _ring_at(0.87, 0.76, 0.14, 0.2, 0.01),
        _ring_at(0.8, 0.62, 0.15, 0.3, 0.07),
        _ring_at(0.72, 0.48, 0.16, 0.37, 0.13),
        _ring_at(0.62, 0.38, 0.14, 0.4, 0.16),
    ]
    parts.append(materials.assign(_shell("Body", rings), beige))
    # The dial on the slope: its face drawn (the number card under the
    # finger wheel), turned so its top is toward the back.
    import numpy as np

    picture = np.ascontiguousarray(np.rot90(prints.dial_card(), 2))
    dial_mat = _picture("DialCard", picture, 0.34, 0.25)
    t = math.radians(DIAL_TILT)
    n = Vector((0.0, math.cos(t), -math.sin(t)))  # out of the face (game frame)
    up = Vector((0.0, math.sin(t), math.cos(t)))  # up the face, toward the back
    centre = Vector((0.0, 0.29, -0.235)) + n * 0.02
    radius = 0.175
    bm = bmesh.new()
    bmesh.ops.create_circle(bm, cap_ends=True, cap_tris=False, segments=40, radius=radius)
    face = _new("Dial", bm)
    layer = face.data.uv_layers.new(name="Pattern")
    for loop in face.data.loops:
        co = face.data.vertices[loop.vertex_index].co
        layer.data[loop.index].uv = (co.x / (2 * radius) + 0.5, co.y / (2 * radius) + 0.5)
    materials.assign(face, dial_mat)
    parts.append(_place(face, (-DIAL_TILT, 0, 0), tuple(centre)))
    bezel = _torus("Bezel", radius + 0.01, 0.014, 40, 6)
    parts.append(materials.assign(_place(bezel, (-DIAL_TILT, 0, 0), tuple(centre + n * 0.004)), beige))
    # The finger stop past the 0, at about four o'clock.
    a = math.radians(-50)
    foot = centre + Vector((math.cos(a) * 0.155, 0, 0)) + up * (math.sin(a) * 0.155)
    stop = _tube("FingerStop", [tuple(foot), tuple(foot + n * 0.03 + Vector((0.01, 0, 0))), tuple(foot + n * 0.05 + Vector((0.03, 0, 0)))], 0.009, 6)
    parts.append(materials.assign(stop, chrome))
    # The cradle's horns and the hook switch's plungers between them.
    for sx in (-1, 1):
        horn = shapes.cushion("Horn", (0.15, 0.2, 0.15), (0, 0, 0), puff=0.02, levels=1, roundness=0.6)
        parts.append(materials.assign(_place(horn, (0, 0, 0), (sx * 0.29, 0.44, 0.17)), beige))
        plunger = _lathe("Plunger", [(0.0, 0.0), (0.03, 0.0), (0.03, 0.05), (0.0, 0.055)], (sx * 0.11, 0.39, 0.17), 10)
        parts.append(materials.assign(plunger, _plastic("PhoneWhite", (232, 228, 214))))
    # The handset across the horns: a grip arched a little, the earpiece
    # (+x) and the mouthpiece (-x) cups facing down at its ends.
    grip = [(-0.36, -0.045, 0), (-0.18, -0.01, 0), (0.0, 0.0, 0), (0.18, -0.01, 0), (0.36, -0.045, 0)]
    handle = _tube("Grip", grip, [0.055, 0.05, 0.048, 0.05, 0.055], 12)
    handle.scale = (1.0, 1.25, 0.9)  # (Blender's: across, deep, tall)
    shapes.apply_transform(handle)
    parts.append(materials.assign(_place(handle, (0, 0, 0), (0, 0.575, 0.17)), beige))
    for sx in (-1, 1):
        cup = _lathe(
            "Cup",
            [(0.0, 0.0), (0.105, 0.0), (0.125, 0.015), (0.125, 0.05), (0.1, 0.09), (0.07, 0.12), (0.0, 0.13)],
            (0, 0, 0),
            24,
        )
        cup = _place(cup, (0, 0, 0), (sx * 0.43, 0.43, 0.17))
        parts.append(materials.assign(cup, beige))
        grille = _lathe("Grille", [(0.0, 0.0), (0.075, 0.0), (0.075, 0.004), (0.0, 0.004)], (sx * 0.43, 0.426, 0.17), 16)
        parts.append(materials.assign(grille, dark))
    # The coiled cord: out of the mouthpiece's end, down the side, along the
    # top it stands on and into the body.
    path = [(-0.48, 0.47, 0.2), (-0.56, 0.36, 0.26), (-0.57, 0.18, 0.26), (-0.55, 0.05, 0.18), (-0.5, 0.04, 0.05), (-0.45, 0.05, -0.04)]
    centre_line = []
    for k in range(len(path) - 1):
        a_, b_ = Vector(path[k]), Vector(path[k + 1])
        for s in range(8):
            centre_line.append(a_.lerp(b_, s / 8))
    centre_line.append(Vector(path[-1]))
    coil = []
    turns = 26
    count = turns * 6
    for i in range(count + 1):
        f = i / count * (len(centre_line) - 1)
        k = min(int(f), len(centre_line) - 2)
        p = centre_line[k].lerp(centre_line[k + 1], f - k)
        tangent = (centre_line[k + 1] - centre_line[k]).normalized()
        side = tangent.cross(Vector((0, 0, 1)))
        if side.length < 0.1:
            side = tangent.cross(Vector((1, 0, 0)))
        side.normalize()
        other = tangent.cross(side)
        ang = i / 6 * math.tau
        coil.append(tuple(p + (side * math.cos(ang) + other * math.sin(ang)) * 0.022))
    parts.append(materials.assign(_tube("Cord", coil, 0.008, 4, caps=False), beige))
    return _finish(parts, "Telephone", 512)


# The photo frame (World/Dressing) -----------------------------------------------------

PHOTO_LEAN = 12.0  # degrees back from upright (Dressing's photoFrame)
PHOTO_MID = 0.62  # the frame's middle above the top it stands on
PHOTO_PROFILE = [(0.0, 0.0), (0.0, 0.07), (0.015, 0.095), (0.035, 0.1), (0.06, 0.09), (0.075, 0.08), (0.085, 0.075), (0.085, 0.0)]


def photo_frame():
    """A standing photo frame, 0.95 x 1.2 (Dressing's PhotoFrame), leaning
    back on its strut: a dark walnut moulding with a gilt slip round the
    game's photo (which stays the game's, aged by Drift), a kraft back, the
    strut on its brass hinge. Its front faces -z."""
    walnut = materials.wood("FrameWalnut", (38, 24, 16), (78, 52, 34), grain_axis="X", scale=2.0, roughness=0.35)
    gilt = materials.brass("FrameGilt", color=(170, 134, 70), roughness=0.3)
    kraft = _paper("FrameBack", (150, 112, 74))
    brass = materials.brass("FrameHinge", color=(150, 118, 70), roughness=0.4)
    lean = []
    frame = shapes.frame("Frame", 0.95, 1.2, PHOTO_PROFILE)
    lean.append(materials.assign(_place(frame, (0, 0, 180), (0, 0, 0.03)), walnut))
    slip = shapes.frame("Slip", 0.79, 1.04, [(0.0, 0.0), (0.0, 0.012), (0.012, 0.012), (0.012, 0.0)])
    lean.append(materials.assign(_place(slip, (0, 0, 180), (0, 0, -0.03)), gilt))
    back = _box("Back", (0.9, 1.15, 0.012), (0, 0, 0.026), 0.003, 1)
    lean.append(materials.assign(back, kraft))
    hinge = _box("Hinge", (0.12, 0.08, 0.012), (0, 0.2, 0.035), 0.003, 1)
    lean.append(materials.assign(hinge, brass))
    leaning = _settle(shapes.join(lean, "Leaning"))
    _place(leaning, (PHOTO_LEAN, 0, 0), (0, PHOTO_MID, 0))
    # The strut: from its hinge on the back to the top it stands on.
    t = math.radians(PHOTO_LEAN)
    hinge_at = Vector((0.0, PHOTO_MID + 0.2 * math.cos(t) - 0.04 * math.sin(t), 0.2 * math.sin(t) + 0.04 * math.cos(t)))
    foot = Vector((0.0, 0.0, 0.36))
    run = hinge_at - foot
    length = run.length
    tilt = math.degrees(math.atan2(-run.z, run.y))  # leaning its top toward the frame
    strut = _loft(
        "Strut",
        [_ring_at(0.12, 0.022, 0.006, -length / 2, 0, 2), _ring_at(0.08, 0.022, 0.006, length / 2, 0, 2)],
        close_bottom=True,
    )
    mid = (hinge_at + foot) / 2
    parts = [leaning, materials.assign(_place(strut, (-tilt, 0, 0), tuple(mid)), kraft)]
    return _finish(parts, "PhotoFrame", 512)


# The clutter on tops (World/Dressing) --------------------------------------------------

MUG_PROFILE = [
    (0.0, 0.0),
    (0.16, 0.0),
    (0.178, 0.008),
    (0.185, 0.03),
    (0.19, 0.2),
    (0.19, 0.4),
    (0.185, 0.418),
    (0.172, 0.42),
    (0.166, 0.41),
    (0.166, 0.06),
    (0.15, 0.045),
    (0.0, 0.045),
]


def mug():
    """A stoneware mug, 0.38 across and 0.42 tall (Dressing's Mug), its
    handle to +x, cold coffee in the bottom and a ring where it stood. Glazed
    near white: World/Dressing tints each its own colour."""
    glaze = _glaze("MugGlaze", (238, 232, 218))
    coffee = materials.paint("Coffee", color=(44, 26, 14), roughness=0.06, grime=0.0)
    stain = materials.paint("CoffeeRing", color=(120, 84, 52), roughness=0.3, grime=0.1)
    parts = [materials.assign(_lathe("Cup", MUG_PROFILE, steps=36), glaze)]
    parts.append(materials.assign(_lathe("Coffee", [(0.0, 0.0), (0.165, 0.0), (0.165, 0.004), (0.0, 0.004)], (0, 0.12, 0), 28), coffee))
    parts.append(materials.assign(_ring("Ring", 0.163, 0.004, (0, 0.2, 0), segments=32, sides=4), stain))
    handle = _tube(
        "Handle",
        _smooth_path([(0.17, 0.34, 0), (0.25, 0.36, 0), (0.3, 0.31, 0), (0.31, 0.22, 0), (0.28, 0.14, 0), (0.21, 0.1, 0), (0.17, 0.11, 0)]),
        0.03,
        10,
    )
    handle.scale = (1.0, 0.75, 1.0)
    shapes.apply_transform(handle)
    parts.append(materials.assign(handle, glaze))
    return _finish(parts, "Mug", 256)


PLATE_PROFILE = [
    (0.0, 0.004),
    (0.28, 0.004),
    (0.3, 0.0),
    (0.33, 0.0),
    (0.35, 0.016),
    (0.38, 0.034),
    (0.46, 0.045),
    (0.475, 0.054),
    (0.47, 0.06),
    (0.455, 0.056),
    (0.38, 0.046),
    (0.34, 0.026),
    (0.32, 0.022),
    (0.0, 0.022),
]


def _side_plate(name, crust):
    china = _glaze(name + "China", (232, 226, 210), 0.2)
    band = _glaze(name + "Band", (112, 72, 46), 0.25)
    steel = _silver(name + "Steel", 0.3)
    bread = materials.paint(name + "Bread", color=(176, 124, 70), roughness=0.85, grime=0.3)
    crumb_mat = materials.paint(name + "Crumb", color=(196, 152, 96), roughness=0.9, grime=0.2)
    parts = [materials.assign(_lathe("Plate", PLATE_PROFILE, steps=44), china)]
    parts.append(materials.assign(_ring("Band", 0.44, 0.006, (0, 0.046, 0), segments=44, sides=4), band))
    # A table knife across it, resting on the rim.
    knife = []
    knife.append(materials.assign(_box("Blade", (0.5, 0.008, 0.06), (0.1, 0, 0), 0.003, 1), steel))
    knife.append(materials.assign(_tube("KnifeHandle", [(-0.16, 0, 0), (-0.3, 0, 0), (-0.42, 0, 0)], [0.024, 0.026, 0.024], 8), steel))
    knife = shapes.join(knife, "Knife")
    _place(knife, (0, 3, 28), (0.02, 0.042, 0.12))
    parts.append(knife)
    rng = random.Random(7 if crust else 9)
    for _ in range(9):
        a, r = rng.uniform(0, math.tau), rng.uniform(0.05, 0.3)
        crumb = _sphere("Crumb", rng.uniform(0.008, 0.016), (math.cos(a) * r, 0.026, math.sin(a) * r), 6, 3)
        parts.append(materials.assign(crumb, crumb_mat))
    if crust:
        # The crusts of a sandwich, curled where they were left.
        for pts in (
            [(-0.22, 0.0, -0.12), (-0.08, 0.0, -0.2), (0.08, 0.0, -0.19), (0.18, 0.0, -0.1)],
            [(-0.18, 0.0, 0.02), (-0.24, 0.0, 0.12), (-0.18, 0.0, 0.22)],
        ):
            c = _tube("Crust", _smooth_path(pts, 4), 0.042, 8)
            c.scale = (1.0, 1.0, 0.55)  # (Blender's z: the game's y, flattened)
            shapes.apply_transform(c)
            c.location = Vector(G(0, 0.022, 0))
            parts.append(materials.assign(_settle(c), bread))
    return _finish(parts, name, 256)


def side_plate():
    """A side plate, 0.95 across (Dressing's Plate): stoneware with a brown
    band, crumbs and a knife left on it."""
    return _side_plate("SidePlate", False)


def side_plate_crust():
    """The side plate with the crusts of a sandwich left on it."""
    return _side_plate("SidePlateCrust", True)


def _book(name, w, h, d, cloth, at, yaw, cloth_mat, pages, gilt):
    """A clothbound book lying flat: boards top and bottom, the page block,
    the spine toward -z with two gilt bands; `at` its foot's middle."""
    parts = []
    board = 0.018
    for y in (board / 2, h - board / 2):
        b = _box("Board", (w, board, d), (0, y, 0), 0.004, 1)
        parts.append(shapes.colour(materials.assign(b, cloth_mat), cloth))
    block = _box("Pages", (w - 0.03, h - 2 * board + 0.004, d - 0.03), (0, h / 2, 0.012), 0.002, 1)
    parts.append(materials.assign(block, pages))
    spine = _tube("Spine", [(-w / 2, 0, 0), (w / 2, 0, 0)], h / 2, 10)
    spine.scale = (1.0, 0.35, 1.0)  # (Blender's y: the game's z, its depth)
    shapes.apply_transform(spine)
    spine_z = -d / 2 + 0.012
    parts.append(shapes.colour(materials.assign(_place(spine, (0, 0, 0), (0, h / 2, spine_z)), cloth_mat), cloth))
    front = spine_z - 0.35 * h / 2
    for x in (-w * 0.3, w * 0.3):
        band = _box("Gilt", (0.03, h * 0.5, 0.006), (x, h / 2, front + 0.002), 0.002, 1)
        parts.append(materials.assign(band, gilt))
    piece = shapes.join(parts, name)
    return _place(piece, (0, 0, math.degrees(yaw)), at)


def _books(name, specs):
    cloth = materials.by_colour(name + "Cloth", roughness=0.75, grain=0.3)
    pages = _paper(name + "Pages", (224, 212, 184))
    gilt = materials.brass(name + "Gilt", color=(170, 134, 70), roughness=0.35)
    parts = []
    y = 0.0
    for w, h, d, rgb, yaw, dx in specs:
        col = tuple(_srgb(rgb)[:3])
        parts.append(_book("Book", w, h, d, col, (dx, y, 0), yaw, cloth, pages, gilt))
        y += h
    return _finish(parts, name, 512)


def books_a():
    """Three clothbound books in a stack (Dressing's Books), spines to the
    front: a red, a green, a blue."""
    return _books(
        "BooksA",
        [(1.05, 0.2, 0.78, (112, 30, 28), 0.0, 0.0), (0.92, 0.16, 0.7, (34, 66, 46), 0.12, 0.03), (0.86, 0.24, 0.66, (32, 40, 72), -0.08, -0.02)],
    )


def books_b():
    """Two books (Dressing's Books): a brown hardback and a thin one on it."""
    return _books("BooksB", [(1.0, 0.22, 0.74, (94, 62, 38), 0.05, 0.0), (0.8, 0.1, 0.58, (150, 116, 48), 0.3, 0.05)])


VASE_PROFILE = [
    (0.0, 0.0),
    (0.19, 0.0),
    (0.215, 0.03),
    (0.26, 0.2),
    (0.29, 0.42),
    (0.275, 0.62),
    (0.2, 0.8),
    (0.13, 0.92),
    (0.118, 1.0),
    (0.14, 1.08),
    (0.152, 1.12),
    (0.13, 1.125),
    (0.108, 1.07),
    (0.1, 0.96),
    (0.0, 0.96),
]


def _vase(name, stems):
    glaze = _glaze(name + "Glaze", (214, 218, 206), 0.14)
    parts = [materials.assign(_lathe("Body", VASE_PROFILE, steps=40), glaze)]
    if stems:
        straw = materials.paint(name + "Straw", color=(170, 146, 102), roughness=0.85, grime=0.2)
        heads = materials.paint(name + "Heads", color=(156, 120, 104), roughness=0.95, grime=0.2)
        rng = random.Random(4)
        for k in range(8):
            a = k / 8 * math.tau + rng.uniform(-0.3, 0.3)
            lean = rng.uniform(0.1, 0.35)
            top = rng.uniform(1.65, 1.95)
            pts = [(0.02 * math.cos(a), 0.98, 0.02 * math.sin(a))]
            for f in (0.35, 0.7, 1.0):
                r = lean * f * f * 1.2
                pts.append((r * math.cos(a), 0.98 + (top - 0.98) * f, r * math.sin(a)))
            parts.append(materials.assign(_tube("Stem", pts, [0.012, 0.011, 0.009, 0.008], 5), straw))
            # A dried flower head: a lumpy cluster of florets.
            hx, hy, hz = pts[-1]
            for j in range(5):
                o = Vector((rng.uniform(-1, 1), rng.uniform(-0.3, 1), rng.uniform(-1, 1))).normalized() * 0.05
                parts.append(materials.assign(_sphere("Floret", rng.uniform(0.03, 0.045), (hx + o.x, hy + o.y, hz + o.z), 8, 5), heads))
    return _finish(parts, name, 512)


def vase():
    """A celadon baluster vase, 1.12 tall (Dressing's Vase): glazed pale,
    World/Dressing tints each."""
    return _vase("Vase", False)


def vase_stems():
    """The vase with a handful of dried stems and their seed heads."""
    return _vase("VaseStems", True)


def _magazine(name, picture, back_colour):
    cover = _picture(name + "Cover", picture, 0.62, 0.35)
    pages = _paper(name + "Pages", (232, 226, 210))
    back = materials.paint(name + "Back", color=back_colour, roughness=0.4, grime=0.1)
    w, d, t = 0.85, 1.1, 0.04
    parts = [materials.assign(_box("Pages", (w - 0.01, t - 0.01, d - 0.01), (0, t / 2, 0), 0.002, 1), pages)]
    parts.append(materials.assign(_box("Back", (w, 0.004, d), (0, 0.002, 0), 0.001, 1), back))
    parts.append(materials.assign(_box("Front", (w, 0.004, d), (0, t - 0.002, 0), 0.001, 1), back))
    parts.append(_card("Cover", cover, w, d, t + 0.0005))
    return _finish(parts, name, 512)


def magazine_a():
    """A home magazine lying on a top, 0.85 x 1.1 (Dressing's Magazine)."""
    return _magazine("MagazineA", prints.magazine_hearth(), (170, 60, 50))


def magazine_b():
    """A television listings weekly lying on a top, 0.85 x 1.1."""
    return _magazine("MagazineB", prints.magazine_screen(), (60, 80, 120))


# The finds in drawers (World/Junk) --------------------------------------------------


def cassette():
    """A cassette tape lying out of its case, 0.7 x 0.44 (Junk's Cassette):
    a black shell, its label and window drawn on top, the openings for the
    heads along its back edge."""
    shell = _plastic("CassetteShell", (32, 30, 28), 0.35)
    top = _picture("CassetteTop", prints.cassette_top(), 0.55, 0.4)
    dark = _dark("CassetteDark")
    parts = [materials.assign(_box("Shell", (0.7, 0.075, 0.44), (0, 0.04, 0), 0.012, 2), shell)]
    parts.append(_card("Top", top, 0.69, 0.43, 0.0785))
    for x in (-0.2, -0.08, 0.0, 0.08, 0.2):
        parts.append(materials.assign(_box("Opening", (0.05, 0.04, 0.01), (x, 0.035, 0.218), 0.003, 1), dark))
    return _finish(parts, "Cassette", 256)


def matchbox():
    """A matchbox, 0.42 x 0.14 x 0.28 (Junk's Matchbox): its sleeve with a
    printed label and a striker each side, the tray pushed out a little
    over a row of red-headed matches."""
    board = _paper("MatchBoard", (210, 196, 166))
    label = _picture("MatchLabel", prints.matchbox_label(), 0.45, 0.6)
    striker = materials.paint("Striker", color=(74, 50, 38), roughness=0.98, grime=0.4)
    wood = materials.paint("MatchWood", color=(214, 190, 140), roughness=0.8, grime=0.1)
    head = materials.paint("MatchHead", color=(150, 30, 26), roughness=0.6, grime=0.1)
    parts = []
    w, h, d, wall = 0.42, 0.14, 0.28, 0.01
    for y in (wall / 2, h - wall / 2):
        parts.append(materials.assign(_box("Sleeve", (w, wall, d), (0, y, 0), 0.002, 1), board))
    for z in (-d / 2 + wall / 2, d / 2 - wall / 2):
        parts.append(materials.assign(_box("Sleeve", (w, h, wall), (0, h / 2, z), 0.002, 1), board))
        parts.append(materials.assign(_box("Striker", (w - 0.02, h - 0.04, 0.003), (0, h / 2, z + math.copysign(0.0065, z)), 0.001, 1), striker))
    parts.append(_card("Label", label, w - 0.01, d - 0.01, h + 0.0005))
    # The tray, out 0.07 to +x.
    out = 0.07
    tw, th, td = w - 0.01, h - 2 * wall - 0.004, d - 2 * wall - 0.004
    tray = [materials.assign(_box("Tray", (tw, 0.006, td), (out, wall + 0.005, 0), 0.001, 1), board)]
    for x in (out - tw / 2 + 0.003, out + tw / 2 - 0.003):
        tray.append(materials.assign(_box("TrayEnd", (0.006, th, td), (x, wall + th / 2 + 0.002, 0), 0.001, 1), board))
    for z in (-td / 2 + 0.003, td / 2 - 0.003):
        tray.append(materials.assign(_box("TraySide", (tw, th, 0.006), (out, wall + th / 2 + 0.002, z), 0.001, 1), board))
    parts += tray
    for k in range(12):
        z = -td / 2 + 0.02 + k * (td - 0.04) / 11
        y = wall + 0.018 + (k % 2) * 0.012
        parts.append(materials.assign(_box("Match", (0.34, 0.016, 0.016), (out - 0.01, y, z), 0.002, 1), wood))
        parts.append(materials.assign(_sphere("Head", 0.017, (out + 0.165, y, z), 6, 4), head))
    return _finish(parts, "Matchbox", 256)


def letters():
    """A bundle of three letters tied with twine, 0.8 x 0.46 (Junk's
    Letters): the top one addressed, stamped and franked, an airmail one
    under it, the twine tied in a bow on top."""
    top = _picture("LetterTop", prints.envelope(), 0.55, 0.85)
    paper = _paper("LetterPaper", (226, 214, 186))
    blue = _paper("LetterAirmail", (176, 196, 214))
    twine = materials.fabric("Twine", color=(160, 128, 84), roughness=0.95)
    parts = []
    t = 0.016
    for i, (mat, yaw) in enumerate(((paper, -6), (blue, 3), (paper, 0))):
        env = [materials.assign(_box("Envelope", (0.8, t, 0.46), (0, t / 2, 0), 0.003, 1), mat)]
        if i == 2:
            env.append(_card("Address", top, 0.79, 0.45, t + 0.0005))
        piece = shapes.join(env, "Envelope")
        parts.append(_place(piece, (0, 0, yaw), (0, i * t, 0)))
    stack = 3 * t + 0.004
    # Twine round the bundle both ways, crossing on top at x 0.12.
    for along_x in (False, True):
        pts = []
        half = 0.42 if along_x else 0.245
        for k in range(16):
            a = k / 16 * math.tau
            u = half * max(-1, min(1, 1.25 * math.cos(a)))
            v = stack / 2 + (stack / 2 + 0.006) * max(-1, min(1, 1.6 * math.sin(a)))
            pts.append((u, v, 0.03) if along_x else (0.12, v, u))
        parts.append(materials.assign(_tube("Twine", _loop_path(pts), 0.006, 5, caps=False), twine))
    for s in (-1, 1):
        loop = _tube("Bow", [(0.12, stack + 0.006, 0.03), (0.12 + s * 0.05, stack + 0.02, 0.0), (0.12 + s * 0.08, stack + 0.012, 0.04), (0.12, stack + 0.006, 0.03)], 0.006, 5)
        parts.append(materials.assign(loop, twine))
        tail = _tube("Tail", [(0.12, stack + 0.006, 0.03), (0.12 + s * 0.04, stack + 0.004, 0.09), (0.12 + s * 0.06, stack + 0.002, 0.14)], 0.005, 5)
        parts.append(materials.assign(tail, twine))
    return _finish(parts, "Letters", 512)


def candle():
    """A candle stub in an enamel chamberstick, 0.5 across (Junk's Candle):
    a white dish with a blue rim and chips, its socket and finger ring, the
    candle burned low and run down its side."""
    enamel = _enamel("CandleEnamel")
    rim = _enamel("CandleRim", (40, 62, 112))
    wax = materials.paint("StubWax", color=(234, 226, 204), roughness=0.45, grime=0.15)
    wick = _dark("StubWick")
    dish = [(0.0, 0.0), (0.2, 0.0), (0.22, 0.008), (0.245, 0.03), (0.25, 0.05), (0.24, 0.052), (0.215, 0.026), (0.07, 0.016), (0.0, 0.016)]
    parts = [materials.assign(_lathe("Dish", dish, steps=36), enamel)]
    parts.append(materials.assign(_ring("Rim", 0.247, 0.006, (0, 0.051, 0), segments=36, sides=4), rim))
    socket = [(0.0, 0.016), (0.075, 0.016), (0.07, 0.1), (0.08, 0.108), (0.075, 0.115), (0.06, 0.112), (0.06, 0.06), (0.0, 0.06)]
    parts.append(materials.assign(_lathe("Socket", socket, steps=24), enamel))
    ring = _torus("FingerRing", 0.06, 0.013, 20, 6)
    parts.append(materials.assign(_place(ring, (90, 0, 0), (0.29, 0.06, 0)), enamel))
    stub = [(0.0, 0.06), (0.058, 0.06), (0.058, 0.3), (0.054, 0.318), (0.045, 0.31), (0.03, 0.296), (0.0, 0.29)]
    parts.append(materials.assign(_lathe("Stub", stub, steps=20), wax))
    rng = random.Random(12)
    for _ in range(4):
        a = rng.uniform(0, math.tau)
        low = rng.uniform(0.12, 0.24)
        cx, cz = math.cos(a) * 0.057, math.sin(a) * 0.057
        drip = _tube("Drip", [(cx, 0.31, cz), (cx * 1.03, (0.31 + low) / 2, cz * 1.03), (cx, low, cz)], [0.008, 0.011, 0.007], 6)
        parts.append(materials.assign(drip, wax))
    parts.append(materials.assign(_tube("Wick", [(0, 0.29, 0), (0.005, 0.315, 0), (0.016, 0.33, 0)], 0.006, 5), wick))
    return _finish(parts, "Candle", 256)


def spool():
    """A wooden spool of red thread, 0.35 tall (Junk's Spool), a needle
    pushed through the thread and its loose end trailing."""
    wood = materials.wood("SpoolWood", (176, 146, 100), (214, 186, 140), grain_axis="Z", scale=4.0, roughness=0.6)
    thread = bpy.data.materials.new("SpoolThread")
    n = Nodes(thread)
    m = n.mapping(scale=(1.0, 1.0, 1.0))
    wind = n.add("ShaderNodeTexWave", wave_type="BANDS", bands_direction="Z")
    wind.inputs["Scale"].default_value = 90.0
    n.link(m.outputs["Vector"], wind.inputs["Vector"])
    ramp = n.ramp(wind.outputs["Fac"], [(0.0, _srgb((96, 18, 22))), (1.0, _srgb((168, 34, 38)))])
    n.link(ramp.outputs["Color"], n.bsdf.inputs["Base Color"])
    n.bsdf.inputs["Roughness"].default_value = 0.7
    n.bump(wind.outputs["Fac"], 0.35)
    steel = _silver("NeedleSteel", 0.2)
    ends = [(0.0, 0.0), (0.16, 0.0), (0.172, 0.012), (0.168, 0.035), (0.1, 0.045), (0.1, 0.305), (0.168, 0.315), (0.172, 0.338), (0.16, 0.35), (0.03, 0.35), (0.03, 0.33), (0.0, 0.33)]
    parts = [materials.assign(_lathe("Spool", ends, steps=32), wood)]
    parts.append(materials.assign(_lathe("Thread", [(0.0, 0.046), (0.136, 0.046), (0.14, 0.06), (0.14, 0.29), (0.136, 0.304), (0.0, 0.304)], steps=32), thread))
    parts.append(materials.assign(_tube("Loose", [(0.14, 0.2, 0.0), (0.2, 0.12, 0.05), (0.25, 0.01, 0.12), (0.36, 0.006, 0.16)], 0.004, 4), thread))
    parts.append(materials.assign(_tube("Needle", [(-0.2, 0.3, 0.06), (0.0, 0.18, 0.02), (0.06, 0.15, 0.0)], [0.006, 0.006, 0.002], 6), steel))
    eye = _torus("Eye", 0.012, 0.003, 12, 4)
    parts.append(materials.assign(_place(eye, (0, 60, 0), (-0.205, 0.304, 0.062)), steel))
    return _finish(parts, "Spool", 256)


def pill_bottle():
    """An amber pharmacy bottle, 0.44 tall (Junk's PillBottle): its typed
    label round the front, a white child-proof cap with a ridged rim."""
    amber = materials.paint("Amber", color=(118, 58, 16), roughness=0.1, grime=0.05)
    cap = _plastic("PillCap", (236, 236, 228), 0.4)
    label = _picture("PillLabel", prints.pill_label(), 0.62, 0.5)
    body = [(0.0, 0.0), (0.098, 0.0), (0.108, 0.012), (0.11, 0.03), (0.11, 0.33), (0.1, 0.345), (0.094, 0.35), (0.0, 0.35)]
    parts = [materials.assign(_lathe("Bottle", body, steps=32), amber)]
    parts.append(_band("Label", label, 0.1115, 0.05, 0.29, -2.4, 2.4, 28))
    ridges = []
    for k in range(48):
        a = k / 48 * math.tau
        r = 0.122 if k % 2 == 0 else 0.116
        ridges.append((r * math.cos(a), r * math.sin(a)))
    parts.append(materials.assign(_column("CapRim", ridges, 0.33, 0.42), cap))
    parts.append(materials.assign(_lathe("CapTop", [(0.0, 0.42), (0.118, 0.42), (0.11, 0.44), (0.0, 0.44)], steps=32), cap))
    return _finish(parts, "PillBottle", 512)


def spare_batteries():
    """Two D-cells lying side by side along z (Junk's SpareBatteries), held
    by a rubber band round their middles."""
    import numpy as np

    wrap = _picture("CellWrap", np.ascontiguousarray(np.transpose(prints.battery_wrap(), (1, 0, 2))), 0.6, 0.35)
    metal = _silver("CellMetal", 0.3)
    rubber = materials.paint("RubberBand", color=(196, 140, 52), roughness=0.6, grime=0.1)
    parts = []
    cell = [(0.0, 0.0), (0.1, 0.0), (0.118, 0.01), (0.12, 0.02), (0.12, 0.53), (0.116, 0.545), (0.1, 0.55), (0.04, 0.55), (0.036, 0.566), (0.0, 0.566)]
    for x in (-0.13, 0.13):
        body = [materials.assign(_lathe("Cell", cell, steps=28), metal)]
        body.append(_band("Wrap", wrap, 0.1215, 0.024, 0.528, -math.pi, math.pi, 28))
        one = shapes.join(body, "Cell")
        # Lying down along z: its + end toward +z, its middle at the centre.
        one.location = Vector(G(0, -0.283, 0))
        shapes.select_only(one)
        bpy.ops.object.transform_apply(location=True, rotation=False, scale=False)
        parts.append(_place(one, (90, 0, 0), (x, 0.12, 0)))
    band = []
    for k in range(24):
        a = k / 24 * math.tau
        cx = 0.13 if math.cos(a) >= 0 else -0.13
        band.append((cx + 0.128 * math.cos(a), 0.12 + 0.128 * math.sin(a), 0.0))
    parts.append(materials.assign(_tube("Band", _loop_path(band), 0.009, 5, caps=False), rubber))
    return _finish(parts, "SpareBatteries", 256)


# Fittings: the light switch (Services/InteractService), the safe room's batteries ---------


def switch_plate():
    """A light switch's plate, 0.38 x 0.6 (InteractService's Plate, built
    round its middle, the wall at +z): ivory bakelite gone yellow, pillowed
    edges, the slot for the toggle and two screws."""
    ivory = _plastic("SwitchIvory", (226, 216, 190), 0.3)
    dark = _dark("SwitchSlot")
    parts = [materials.assign(_box("Plate", (0.38, 0.6, 0.05), (0, 0, 0), 0.016, 3), ivory)]
    parts.append(materials.assign(_box("Slot", (0.05, 0.16, 0.006), (0, 0.04, -0.0235), 0.004, 1), dark))
    for y in (-0.22, 0.22):
        screw = _lathe("Screw", [(0.0, 0.0), (0.028, 0.0), (0.026, 0.006), (0.016, 0.01), (0.0, 0.011)], (0, 0, 0), 12)
        parts.append(materials.assign(_place(screw, (-90, 0, 0), (0, y, -0.024)), ivory))
        parts.append(materials.assign(_box("ScrewSlot", (0.045, 0.006, 0.004), (0, y, -0.0335), 0.001, 1), dark))
    return _finish(parts, "SwitchPlate", 256)


def switch_toggle():
    """The switch's toggle (InteractService's Toggle, round its middle, its
    length along y): a small tapered bat, rounded at its tip."""
    ivory = _plastic("ToggleIvory", (236, 228, 206), 0.25)
    rings = [_ring_at(0.07, 0.06, 0.02, -0.09, 0, 3), _ring_at(0.062, 0.052, 0.02, 0.0, 0, 3), _ring_at(0.054, 0.044, 0.018, 0.065, 0, 3)]
    bat = materials.assign(_shell("Bat", rings), ivory)
    tip = materials.assign(_sphere("Tip", 0.029, (0, 0, 0), 12, 6), ivory)
    tip.scale = (0.95, 0.78, 1.0)  # (Blender's: across, deep, tall)
    shapes.apply_transform(tip)
    return _finish([bat, _place(tip, (0, 0, 0), (0, 0.066, 0))], "SwitchToggle", 128)


def battery_box():
    """The safe room's carton of torch batteries, 0.9 x 0.45 x 0.6 (round
    its middle; SafeRoomService's Box): kraft board printed on its long
    sides, the top's flaps taped shut (the game's label is printed on it)."""
    kraft = materials.paint("Kraft", color=(170, 130, 86), roughness=0.9, grime=0.25)
    side = _picture("CartonSide", prints.carton_side(), 0.7, 0.85)
    tape = materials.paint("CartonTape", color=(186, 150, 96), roughness=0.3, grime=0.1)
    band = materials.paint("CartonBand", color=(226, 182, 44), roughness=0.85, grime=0.2)
    w, h, d = 0.9, 0.45, 0.6
    parts = [materials.assign(_box("Carton", (w, h - 0.02, d), (0, -0.01, 0), 0.012, 2), kraft)]
    for s in (-1, 1):
        flap = _box("Flap", (w - 0.004, 0.012, d / 2 - 0.004), (0, 0, 0), 0.004, 1)
        parts.append(materials.assign(_place(flap, (s * 1.2, 0, 0), (0, h / 2 - 0.012, s * d / 4)), kraft))
        parts.append(_upright_card("Print", side, w - 0.04, h - 0.06, (0, -0.015, s * (d / 2 + 0.0008)), s))
    for sx in (-1, 1):
        parts.append(materials.assign(_box("Band", (0.003, 0.11, d - 0.04), (sx * (w / 2 + 0.0015), -0.005, 0), 0.001, 1), band))
    parts.append(materials.assign(_box("Tape", (w + 0.006, 0.003, 0.1), (0, h / 2 - 0.003, 0), 0.001, 1), tape))
    for sx in (-1, 1):
        parts.append(materials.assign(_box("TapeEnd", (0.003, 0.14, 0.1), (sx * (w / 2 + 0.003), h / 2 - 0.07, 0), 0.001, 1), tape))
    return _finish(parts, "BatteryBox", 1024)


# Outside (World/Exterior) ---------------------------------------------------------------


def _fbm(p, seed, octaves=3):
    total, amp, freq = 0.0, 1.0, 1.0
    for i in range(octaves):
        total += amp * noise.noise(p * freq + Vector((seed * 7.31 + i * 13.7, seed * 3.17, seed * 5.53)))
        amp *= 0.5
        freq *= 2.1
    return total


def _bud(rng, clumps, count, sizes, rise=-0.35):
    """Adds `count` small masses (radius from `sizes`) on the surfaces of the
    big ones, mostly on their tops and sides (never far under: `rise`, the
    lowest a bud's direction points)."""
    big = list(clumps)
    weights = [r[0] * r[2] for _, r in big]
    for _ in range(count):
        (cx, cy, cz), (rx, ry, rz) = rng.choices(big, weights)[0]
        d = Vector((rng.uniform(-1, 1), rng.uniform(rise, 1), rng.uniform(-1, 1)))
        if d.length < 1e-3:
            continue
        d.normalize()
        s = rng.uniform(*sizes)
        at = (cx + d.x * rx * 0.92, cy + d.y * ry * 0.92, cz + d.z * rz * 0.92)
        clumps.append((at, (s, s * rng.uniform(0.75, 1.0), s)))
    return clumps


def _remesh(obj, voxel, tris, jag=0.0, seed=0):
    """Runs a crown's overlapping masses together (a voxel remesh drops the
    faces inside), brings it down to about `tris` triangles, and jags its
    surface by up to `jag` so the outline breaks up as leaves do."""
    shapes.select_only(obj)
    mod = obj.modifiers.new("Remesh", "REMESH")
    mod.mode = "VOXEL"
    mod.voxel_size = voxel
    mod.adaptivity = 0.0
    bpy.ops.object.modifier_apply(modifier=mod.name)
    have = shapes.triangles(obj) or 1
    if have > tris:
        mod = obj.modifiers.new("Decimate", "DECIMATE")
        mod.ratio = tris / have
        bpy.ops.object.modifier_apply(modifier=mod.name)
    if jag:
        mesh = obj.data
        mesh.update()
        for v in mesh.vertices:
            d = noise.noise(v.co * 1.7 + Vector((seed * 1.3, 0, 0)))
            v.co += v.normal * (jag * d)
        mesh.update()
    return shapes.smooth(obj, 80)


def _masses(name, clumps, seed, lump=0.22, ripple=0.1, subdivisions=2):
    """Masses of leaves: each (centre, (rx, ry, rz)) in the game's frame an
    ellipsoid made lumpy by noise, all in one mesh."""
    bm = bmesh.new()
    for k, (centre, radii) in enumerate(clumps):
        geom = bmesh.ops.create_icosphere(bm, subdivisions=subdivisions, radius=1.0)
        c = Vector(G(*centre))
        rx, ry, rz = radii
        for v in geom["verts"]:
            d = v.co.normalized()
            bump = 1 + lump * _fbm(d * 1.6, seed + k, 2) + ripple * noise.noise(d * 5.0 + Vector((k * 2.1, seed, 0)))
            # (The game's x, y up, z: Blender's x, z, -y.)
            v.co = c + Vector((d.x * rx, d.y * rz, d.z * ry)) * bump
    return _new(name, bm)


def _limb(rng, start, direction, length, radius, depth, out, spec):
    """A limb and what grows from it (recursive): a tapering tube bending a
    little as it goes, its children leaving from along its outer part."""
    segs = spec["segments"][min(depth, len(spec["segments"]) - 1)]
    sides = spec["sides"][min(depth, len(spec["sides"]) - 1)]
    pts, radii = [start], [radius]
    d = direction.normalized()
    p = start.copy()
    for i in range(segs):
        wobble = Vector((rng.uniform(-1, 1), rng.uniform(-1, 1), rng.uniform(-1, 1))) * spec["wobble"]
        d = (d + wobble + Vector((0, spec["rise"], 0))).normalized()
        p = p + d * (length / segs)
        pts.append(p.copy())
        radii.append(radius * (1 - spec["taper"] * (i + 1) / segs))
    out.append((pts, radii, sides, depth))
    if depth >= spec["depth"]:
        return
    children = rng.randint(*spec["children"])
    base_angle = rng.uniform(0, math.tau)
    for c in range(children):
        t = rng.uniform(spec["from"], 0.95) if c else 1.0
        f = t * segs
        k = min(int(f), segs - 1)
        at = Vector(pts[k]).lerp(Vector(pts[k + 1]), f - k)
        r_at = radii[k] + (radii[k + 1] - radii[k]) * (f - k)
        # Away from the parent's line by the spread, round it by turns.
        ref = Vector((0, 1, 0)) if abs(d.y) < 0.95 else Vector((1, 0, 0))
        side = d.cross(ref).normalized()
        other = d.cross(side).normalized()
        turn = base_angle + c * math.tau / children + rng.uniform(-0.5, 0.5)
        spread = math.radians(rng.uniform(*spec["spread"]))
        nd = d * math.cos(spread) + (side * math.cos(turn) + other * math.sin(turn)) * math.sin(spread)
        _limb(rng, at, nd, length * rng.uniform(*spec["shrink"]), r_at * spec["thin"], depth + 1, out, spec)


def _skeleton(name, seed, trunk_points, trunk_radii, limbs, spec, bark):
    """A tree's wood: the trunk through its points, limbs from its top
    (each (start index, direction, length)), growing per `spec`."""
    rng = random.Random(seed)
    parts = [materials.assign(_tube("Trunk", trunk_points, trunk_radii, spec["sides"][0]), bark)]
    out = []
    for start, direction, length in limbs:
        p = Vector(trunk_points[start])
        r = trunk_radii[start] * 0.72
        _limb(rng, p, Vector(direction), length, r, 1, out, spec)
    for pts, radii, sides, depth in out:
        game = [tuple(v) for v in pts]
        parts.append(materials.assign(_tube("Limb", game, [max(r, spec["min"]) for r in radii], sides), bark))
    return parts


LEAVES_GREEN = [(30, 42, 22), (38, 52, 26), (46, 62, 30), (54, 70, 32), (62, 76, 34), (80, 84, 38)]
LEAVES_TURNING = [(70, 36, 18), (110, 52, 20), (150, 76, 26), (176, 112, 34), (120, 96, 36), (70, 74, 30)]
NEEDLES = [(16, 28, 22), (22, 38, 28), (30, 48, 34), (38, 56, 38)]
ARBOR = [(26, 40, 22), (36, 54, 28), (48, 66, 32), (60, 76, 34)]

LEAFY_SPEC = {
    "segments": [6, 4, 3, 2],
    "sides": [12, 8, 6, 4],
    "wobble": 0.18,
    "rise": 0.12,
    "taper": 0.5,
    "depth": 3,
    "children": (2, 3),
    "from": 0.45,
    "spread": (25, 45),
    "shrink": (0.55, 0.75),
    "thin": 0.62,
    "min": 0.05,
}


def _crown_clumps(rng, centre, radii, count, sizes, lift=0.2):
    """Masses round a crown's heart: one large in the middle, the rest
    bulging out round its upper part (few hang under it)."""
    cx, cy, cz = centre
    rx, ry, rz = radii
    clumps = [((cx, cy, cz), (rx * 0.78, ry * 0.75, rz * 0.78))]
    for _ in range(count):
        a = rng.uniform(0, math.tau)
        up = rng.uniform(-0.55, 1.0) + lift
        up = max(-0.7, min(1.0, up))
        flat = math.sqrt(max(0.0, 1 - up * up))
        reach = rng.uniform(0.55, 0.78)
        at = (cx + math.cos(a) * flat * rx * reach, cy + up * ry * reach, cz + math.sin(a) * flat * rz * reach)
        s = rng.uniform(*sizes)
        clumps.append((at, (s, s * rng.uniform(0.75, 1.0), s * rng.uniform(0.85, 1.1))))
    return clumps


def _leafy(name, seed, height, crown_centre, crown_radii, clumps, colours, lean=(0.0, 0.0)):
    """A tree in leaf, `height` tall: a trunk forking into limbs that reach
    into a crown of lumpy masses run together."""
    rng = random.Random(seed)
    bark = _bark(name + "Bark")
    leaves = _foliage(name + "Leaves", colours, cell=0.38)
    lx, lz = lean
    fork = crown_centre[1] - crown_radii[1] * 0.55
    trunk = [(0.0, -0.5, 0.0), (0.0, 0.6, 0.0), (lx * 0.3, fork * 0.45, lz * 0.3), (lx * 0.7, fork * 0.8, lz * 0.7), (lx, fork, lz)]
    radii = [height * 0.05, height * 0.034, height * 0.029, height * 0.025, height * 0.022]
    limbs = []
    for k in range(3):
        a = seed + k * math.tau / 3
        limbs.append((4, (math.cos(a) * 0.7, 1.0, math.sin(a) * 0.7), crown_radii[1] * 0.9))
    parts = _skeleton(name + "Wood", seed, trunk, radii, limbs, LEAFY_SPEC, bark)
    crown = _crown_clumps(rng, crown_centre, crown_radii, clumps, (crown_radii[0] * 0.3, crown_radii[0] * 0.42))
    # Lower boughs reaching out under the crown, each with leaves at its end.
    for k in range(4):
        a = seed * 1.7 + k * math.tau / 4 + rng.uniform(-0.4, 0.4)
        out = crown_radii[0] * rng.uniform(0.55, 0.75)
        low = crown_centre[1] - crown_radii[1] * rng.uniform(0.45, 0.65)
        size = crown_radii[0] * rng.uniform(0.3, 0.4)
        crown.append(((crown_centre[0] + math.cos(a) * out, low, crown_centre[2] + math.sin(a) * out), (size, size * 0.7, size)))
        bough = [(lx * 0.8, fork * 0.82, lz * 0.8), (math.cos(a) * out * 0.5, low - 0.6, math.sin(a) * out * 0.5), (crown_centre[0] + math.cos(a) * out * 0.9, low, crown_centre[2] + math.sin(a) * out * 0.9)]
        parts.append(materials.assign(_tube("Bough", bough, [height * 0.012, height * 0.008, height * 0.004], 6), bark))
    _bud(rng, crown, 46, (crown_radii[0] * 0.11, crown_radii[0] * 0.17))
    masses = _masses(name + "Crown", crown, seed)
    _remesh(masses, height * 0.02, 3000, jag=height * 0.012, seed=seed)
    parts.append(materials.assign(masses, leaves))
    piece = shapes.join(parts, name)
    piece["bake_size"] = 1024
    return piece


def tree_oak_a():
    """An old oak still in leaf, 24 tall (World/Exterior's leafy trees,
    scaled to each): a broad crown on three limbs."""
    return _leafy("TreeOakA", 3, 24.0, (0.0, 15.6, 0.0), (6.8, 7.0, 6.4), 15, LEAVES_GREEN)


def tree_oak_b():
    """A second oak, its crown lopsided and lower, its trunk leaning."""
    return _leafy("TreeOakB", 8, 24.0, (1.0, 14.6, -0.5), (7.0, 6.6, 6.2), 16, LEAVES_GREEN, lean=(0.8, -0.4))


def tree_turning():
    """A maple turning (late October), 24 tall: an upright oval crown gone
    orange and rust with a little green left."""
    return _leafy("TreeTurning", 21, 24.0, (0.0, 15.0, 0.0), (5.4, 8.0, 5.4), 14, LEAVES_TURNING)


BARE_SPEC = {
    "segments": [6, 5, 4, 3, 2],
    "sides": [12, 8, 6, 5, 4],
    "wobble": 0.22,
    "rise": 0.1,
    "taper": 0.55,
    "depth": 4,
    "children": (2, 3),
    "from": 0.4,
    "spread": (22, 42),
    "shrink": (0.58, 0.74),
    "thin": 0.6,
    "min": 0.035,
}


def _bare(name, seed, height, fork, limbs, lean=(0.0, 0.0)):
    bark = _bark(name + "Bark", (64, 58, 52), (30, 28, 26))
    lx, lz = lean
    trunk = [(0.0, -0.5, 0.0), (0.0, 0.6, 0.0), (lx * 0.4, fork * 0.5, lz * 0.4), (lx, fork, lz)]
    radii = [height * 0.046, height * 0.032, height * 0.027, height * 0.022]
    out = []
    for k in range(limbs):
        a = seed * 0.7 + k * math.tau / limbs
        out.append((3, (math.cos(a) * 0.55, 1.0, math.sin(a) * 0.55), (height - fork) * 0.62))
    parts = _skeleton(name + "Wood", seed, trunk, radii, out, BARE_SPEC, bark)
    piece = shapes.join(parts, name)
    piece["bake_size"] = 1024
    return piece


def tree_bare_a():
    """A bare tree, 24 tall (World/Exterior's bare trees): forked low,
    its branches reaching up and out in a tangle of twigs."""
    return _bare("TreeBareA", 5, 24.0, 9.0, 3)


def tree_bare_b():
    """A second bare tree, taller in the trunk and leaning."""
    return _bare("TreeBareB", 14, 24.0, 12.0, 4, lean=(-0.7, 0.5))


def _conifer(name, seed, height, tiers, points, radius, top_from=0.16):
    """A dark spruce, `height` tall: a trunk and tiers of drooping boughs,
    each a skirt of points (tips out and down, notches between) with an
    underside, narrowing to a spire."""
    rng = random.Random(seed)
    bark = _bark(name + "Bark")
    needles = _foliage(name + "Needles", NEEDLES, cell=0.22, roughness=0.8)
    parts = [materials.assign(_tube("Trunk", [(0, -0.4, 0), (0, height * 0.3, 0), (0, height * 0.97, 0)], [height * 0.025, height * 0.016, 0.04], 10), bark)]
    bm = bmesh.new()
    y0, y1 = height * top_from, height * 0.93
    for t in range(tiers):
        f = t / (tiers - 1)
        y = y0 + (y1 - y0) * f
        r = radius * (1 - f) ** 0.85 + 0.5
        n = max(5, points - int(f * 4))
        twist = rng.uniform(0, math.tau)
        droop = 0.22 * r + 0.3
        thick = 0.25 + 0.12 * r
        rings = {"top": [], "mid": [], "edge": [], "under": [], "core": []}
        for i in range(2 * n):
            a = twist + i * math.pi / n
            tip = i % 2 == 0
            rr = r * (rng.uniform(0.9, 1.1) if tip else 0.6)
            ey = y - (droop if tip else droop * 0.45) + rng.uniform(-0.1, 0.1)
            c, s = math.cos(a), math.sin(a)
            core = min(0.3, rr * 0.25)
            rings["core"].append(G(c * core, y + 0.35, s * core))
            rings["mid"].append(G(c * rr * 0.5, y + 0.05 - droop * 0.2, s * rr * 0.5))
            rings["edge"].append(G(c * rr, ey, s * rr))
            rings["under"].append(G(c * rr * 0.45, y - droop * 0.35 - thick, s * rr * 0.45))
            rings["top"].append(G(c * core, y - thick * 1.4, s * core))
        verts = {k: [bm.verts.new(p) for p in v] for k, v in rings.items()}
        order = ["core", "mid", "edge", "under", "top", "core"]
        facing = [1, 1, -1, -1, 0]  # up, up, down, down, (inside the trunk)
        m = 2 * n
        for (a_, b_), want in zip(zip(order, order[1:]), facing):
            A, B = verts[a_], verts[b_]
            for i in range(m):
                j = (i + 1) % m
                f = bm.faces.new((A[i], A[j], B[j], B[i]))
                f.normal_update()
                if want and f.normal.z * want < 0:
                    f.normal_flip()
    # The spire.
    tip_ring = [bm.verts.new(G(math.cos(k / 6 * math.tau) * 0.35, y1, math.sin(k / 6 * math.tau) * 0.35)) for k in range(6)]
    point = bm.verts.new(G(0, height, 0))
    for k in range(6):
        f = bm.faces.new((tip_ring[k], tip_ring[(k + 1) % 6], point))
        f.normal_update()
        out = f.calc_center_median() - Vector((0, 0, f.calc_center_median().z))
        if f.normal.dot(out) < 0:
            f.normal_flip()
    cap = bm.faces.new(list(reversed(tip_ring)))
    cap.normal_update()
    if cap.normal.z > 0:
        cap.normal_flip()
    boughs = shapes.smooth(_new("Boughs", bm), 70)
    parts.append(materials.assign(boughs, needles))
    piece = shapes.join(parts, name)
    piece["bake_size"] = 1024
    return piece


def conifer_a():
    """A spruce, 24 tall (World/Exterior's conifers): eleven tiers of
    drooping boughs to a spire."""
    return _conifer("ConiferA", 6, 24.0, 11, 10, 4.2)


def conifer_b():
    """A fir, narrower and denser in its tiers."""
    return _conifer("ConiferB", 17, 24.0, 15, 8, 3.4, top_from=0.12)


def _bush(name, seed, width, height, count, colours, tris=1000):
    rng = random.Random(seed)
    clumps = []
    for k in range(count):
        a = rng.uniform(0, math.tau)
        r = 0 if k == 0 else rng.uniform(0.15, 0.3) * width
        s = 0.3 * width if k == 0 else rng.uniform(0.13, 0.2) * width
        up = height * (0.3 if k == 0 else rng.uniform(0.2, 0.6))
        clumps.append(((math.cos(a) * r, up, math.sin(a) * r * 0.85), (s, s * height / width * 1.4, s * 0.9)))
    _bud(rng, clumps, 34, (width * 0.06, width * 0.1), rise=-0.1)
    leaves = _foliage(name + "Leaves", colours, cell=0.13)
    masses = _masses(name, clumps, seed, lump=0.2, ripple=0.12)
    _remesh(masses, width * 0.03, tris, jag=width * 0.02, seed=seed)
    # (Sunk a little: its foot in the grass.)
    shapes.cut_below(masses, -0.5)
    piece = materials.assign(masses, leaves)
    piece["bake_size"] = 512
    return piece


def bush_a():
    """A rounded bush, 5 across and 3 tall (World/Exterior's bushes and the
    garden's shrubs, scaled to each)."""
    return _bush("BushA", 2, 5.0, 3.0, 11, LEAVES_GREEN)


def bush_b():
    """A low sprawling bush, darker, 5.5 across."""
    return _bush("BushB", 11, 5.5, 2.4, 13, LEAVES_GREEN[:4] + [(44, 52, 30)])


def arborvitae():
    """An arborvitae, 9 tall and 3 across (World/Exterior's garden
    columns): a dense flame of scale-leaves stacked up from the grass."""
    rng = random.Random(23)
    clumps = []
    for k in range(9):
        f = k / 8
        y = 0.6 + f * 7.6
        r = 1.15 * (1 - f) ** 0.6 + 0.35
        o = (rng.uniform(-0.2, 0.2), rng.uniform(-0.2, 0.2))
        clumps.append(((o[0], y, o[1]), (r, 1.3, r)))
    _bud(rng, clumps, 40, (0.22, 0.36), rise=-0.5)
    leaves = _foliage("ArborLeaves", ARBOR, cell=0.09, roughness=0.8)
    masses = _masses("Arborvitae", clumps, 23, lump=0.14, ripple=0.12)
    _remesh(masses, 0.14, 1100, jag=0.06, seed=23)
    shapes.cut_below(masses, -0.4)
    piece = materials.assign(masses, leaves)
    piece["bake_size"] = 512
    return piece


LAMP_HEIGHT = 14.0  # Config.Exterior.LampHeight
LAMP_REACH = 2.4  # the arm's reach (World/Exterior's streetlamp), toward -z


def streetlamp():
    """A 1988 streetlamp, 14 tall (World/Exterior's): a tapered octagonal
    galvanised pole on a cast foot, a curved davit arm reaching 2.4 toward
    -z (the side the lamp faces), a cobra-head luminaire with its sodium
    refractor glowing underneath (the light itself is the game's)."""
    galv = _galv("LampGalv", (118, 122, 120))
    alu = materials.brass("LampAlu", color=(150, 152, 150), roughness=0.45)
    glass = materials.paint("Refractor", color=(255, 214, 160), roughness=0.2, grime=0.0)
    glass["glow"] = 1.0
    parts = []
    pole = [(0.0, -0.4), (0.34, -0.4), (0.34, 0.12), (0.26, 0.22), (0.22, 0.45), (0.2, 0.6), (0.13, LAMP_HEIGHT + 0.1), (0.0, LAMP_HEIGHT + 0.15)]
    parts.append(materials.assign(_lathe("Pole", pole, steps=8), galv))
    for k in range(4):
        a = k * math.pi / 2 + math.pi / 4
        parts.append(materials.assign(_sphere("Bolt", 0.045, (math.cos(a) * 0.28, 0.13, math.sin(a) * 0.28), 6, 3), galv))
    door = _box("Door", (0.16, 0.5, 0.02), (0, 1.2, -0.205), 0.01, 1)
    parts.append(materials.assign(door, galv))
    arm = [(0.0, LAMP_HEIGHT - 1.0, -0.1), (0.0, LAMP_HEIGHT - 0.4, -0.45), (0.0, LAMP_HEIGHT - 0.06, -1.1), (0.0, LAMP_HEIGHT + 0.08, -1.7), (0.0, LAMP_HEIGHT + 0.1, -2.0)]
    parts.append(materials.assign(_tube("Arm", arm, [0.08, 0.075, 0.07, 0.065, 0.065], 8), galv))
    brace = [(0.0, LAMP_HEIGHT - 1.6, -0.12), (0.0, LAMP_HEIGHT - 1.0, -0.6), (0.0, LAMP_HEIGHT - 0.45, -1.1)]
    parts.append(materials.assign(_tube("Brace", brace, 0.035, 6), galv))
    # The cobra head: lofted along -z, its refractor bowl under it.
    hy = LAMP_HEIGHT + 0.06
    rings = []
    for z, w, h in ((-1.9, 0.22, 0.16), (-2.05, 0.5, 0.28), (-2.4, 0.66, 0.34), (-2.8, 0.66, 0.32), (-3.05, 0.5, 0.26), (-3.18, 0.28, 0.16)):
        ring = []
        for k in range(16):
            a = k / 16 * math.tau
            ring.append((w / 2 * math.cos(a), hy + h / 2 * math.sin(a) * (1.0 if math.sin(a) > 0 else 0.5), z))
        rings.append(ring)
    bm = bmesh.new()
    vs = [[bm.verts.new(G(*p)) for p in ring] for ring in rings]
    for a_, b_ in zip(vs, vs[1:]):
        for i in range(16):
            j = (i + 1) % 16
            bm.faces.new((a_[i], a_[j], b_[j], b_[i]))
    for ring, last in ((vs[0], False), (vs[-1], True)):
        c = sum((v.co for v in ring), Vector()) / 16
        hub = bm.verts.new(c)
        for i in range(16):
            j = (i + 1) % 16
            bm.faces.new((ring[i], ring[j], hub) if last else (ring[j], ring[i], hub))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    parts.append(materials.assign(shapes.smooth(_new("Head", bm), 50), alu))
    bowl = _sphere("Bowl", 0.3, (0, 0, 0), 20, 10)
    bowl.scale = (0.95, 2.0, 0.55)  # Blender's: across, along the arm (y), down
    shapes.apply_transform(bowl)
    parts.append(materials.assign(_place(bowl, (0, 0, 0), (0, hy - 0.06, -2.55)), glass))
    return _finish(parts, "Streetlamp", 512)


ATMOSPHERE = [
    telephone,
    photo_frame,
    mug,
    side_plate,
    side_plate_crust,
    books_a,
    books_b,
    vase,
    vase_stems,
    magazine_a,
    magazine_b,
    cassette,
    matchbox,
    letters,
    candle,
    spool,
    pill_bottle,
    spare_batteries,
    switch_plate,
    switch_toggle,
    battery_box,
    tree_oak_a,
    tree_oak_b,
    tree_turning,
    tree_bare_a,
    tree_bare_b,
    conifer_a,
    conifer_b,
    bush_a,
    bush_b,
    arborvitae,
    streetlamp,
]
