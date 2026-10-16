"""The tools in your hand and on the tables (V6; World/ToolModel): the torch,
the lantern, the radio, the crowbar, the bolt cutters and the smelling salts,
each a 1980s thing.

Each is built in its tool model's own frame (World/ToolModel: it points down
-z, away from you, its middle at the pivot; x across, y up), round the parts
the game keeps: the torch's lens and switch (they glow when it's on), the
lantern's glass and its flame. Those are left open in the mesh, so the game's
parts show through.
"""

import math

import bmesh
import bpy
from mathutils import Vector

from . import clothmats as cm
from . import materials, shapes


INSIDE = 0.008  # an open shell's wall thickness


def G(x, y, z):
    return (x, -z, y)


def _object(name, bm):
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    return obj


def _spin_z(name, profile, steps=32, z0=0.0, y=0.0, x=0.0):
    """A turned shape along the tool's length (-z forward): profile is
    [(radius, z)], spun round the line through (x, y)."""
    bm = bmesh.new()
    rings = []
    for r, z in profile:
        ring = []
        for k in range(steps):
            a = math.tau * k / steps
            ring.append(bm.verts.new(G(x + max(r, 0.0) * math.cos(a), y + max(r, 0.0) * math.sin(a), z0 + z)))
        rings.append(ring)
    for i in range(len(rings) - 1):
        for k in range(steps):
            k1 = (k + 1) % steps
            bm.faces.new((rings[i][k], rings[i][k1], rings[i + 1][k1], rings[i + 1][k]))
    for end in (0, len(rings) - 1):
        if profile[end][0] <= 0:
            continue
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    obj = _object(name, bm)
    return shapes.smooth(obj, 40)


def _spin_y(name, profile, steps=32, x=0.0, z=0.0):
    """A turned shape standing up (y): profile [(radius, y)]."""
    bm = bmesh.new()
    rings = []
    for r, y in profile:
        ring = []
        for k in range(steps):
            a = math.tau * k / steps
            ring.append(bm.verts.new(G(x + max(r, 0.0) * math.cos(a), y, z + max(r, 0.0) * math.sin(a))))
        rings.append(ring)
    for i in range(len(rings) - 1):
        for k in range(steps):
            k1 = (k + 1) % steps
            bm.faces.new((rings[i][k], rings[i][k1], rings[i + 1][k1], rings[i + 1][k]))
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return shapes.smooth(_object(name, bm), 40)


def _tube(name, points, radius, sides=10):
    """A round rod through game-frame points (a wire, a handle, a bar)."""
    bm = bmesh.new()
    rings = []
    pts = [Vector(p) for p in points]
    # (Each ring's frame carried on from the last as the path turns: picking
    # it afresh at each point flipped it where the path turned near upright,
    # and the tube twisted inside out there, 2026-10-15.)
    u = None
    last = None
    for i, p in enumerate(pts):
        d = (pts[min(i + 1, len(pts) - 1)] - pts[max(i - 1, 0)]).normalized()
        if u is None:
            a = Vector((0, 1, 0)) if abs(d.y) < 0.9 else Vector((1, 0, 0))
            u = d.cross(a).normalized()
        else:
            u = last.rotation_difference(d) @ u
            u = (u - d * u.dot(d)).normalized()
        last = d
        v = d.cross(u).normalized()
        ring = []
        for k in range(sides):
            t = math.tau * k / sides
            q = p + (u * math.cos(t) + v * math.sin(t)) * radius
            ring.append(bm.verts.new(G(q.x, q.y, q.z)))
        rings.append(ring)
    for i in range(len(rings) - 1):
        for k in range(sides):
            k1 = (k + 1) % sides
            bm.faces.new((rings[i][k], rings[i][k1], rings[i + 1][k1], rings[i + 1][k]))
    for ring, flip in ((rings[0], True), (rings[-1], False)):
        f = bm.faces.new(ring)
        if flip:
            f.normal_flip()
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return shapes.smooth(_object(name, bm), 50)


def _box(name, size, at, bevel=0.01):
    """A rounded box: size and centre in the game frame."""
    return shapes.box(name, (size[0], size[2], size[1]), G(*at), bevel, 2)


def _paint(obj, index):
    """Marks every face of a piece for material `index` (applied by _join)."""
    attr = obj.data.attributes.get("tool_mat") or obj.data.attributes.new("tool_mat", "INT", "FACE")
    for d in attr.data:
        d.value = index
    return obj


def _paint_where(obj, index, test):
    """Marks the faces whose middle (game frame) passes test for `index`."""
    attr = obj.data.attributes.get("tool_mat") or obj.data.attributes.new("tool_mat", "INT", "FACE")
    for poly, d in zip(obj.data.polygons, attr.data):
        c = poly.center
        if test(Vector((c.x, c.z, -c.y))):
            d.value = index
    return obj


def _join(objs, name, mats_):
    for o in objs:
        o.data.materials.clear()
        for m in mats_:
            o.data.materials.append(m)
    obj = shapes.join(objs, name)
    attr = obj.data.attributes.get("tool_mat")
    if attr:
        for poly, d in zip(obj.data.polygons, attr.data):
            poly.material_index = d.value
        obj.data.attributes.remove(attr)
    # An inside for every open shell (the torch's head: its reflector), each
    # in its own material: Roblox draws a face from the front only, so the
    # head showed straight through from the front (2026-10-15).
    shapes.line_open(obj, INSIDE)
    shapes.smooth(obj, 40)
    return obj


def _knurl(name, color):
    """Knurled aluminium: fine diamond ridges, anodised."""
    if name in cm._cache:
        return cm._cache[name]
    mat = bpy.data.materials.new(name)
    n = materials.Nodes(mat)
    m, sep = cm._xyz(n)
    a = n.add("ShaderNodeTexWave", wave_type="BANDS", bands_direction="DIAGONAL")
    a.inputs["Scale"].default_value = 70.0
    n.link(m.outputs["Vector"], a.inputs["Vector"])
    mirror_ = n.add("ShaderNodeMapping")
    mirror_.inputs["Scale"].default_value = (-1, 1, 1)
    n.link(m.outputs["Vector"], mirror_.inputs["Vector"])
    b = n.add("ShaderNodeTexWave", wave_type="BANDS", bands_direction="DIAGONAL")
    b.inputs["Scale"].default_value = 70.0
    n.link(mirror_.outputs["Vector"], b.inputs["Vector"])
    diamond = n.math("MULTIPLY", a.outputs["Fac"], b.outputs["Fac"])
    base = cm._srgb(color)
    low = tuple(c * 0.6 for c in base[:3]) + (1.0,)
    ramp = n.ramp(diamond.outputs["Value"], [(0.0, low), (0.5, base)])
    n.link(ramp.outputs["Color"], n.bsdf.inputs["Base Color"])
    n.bsdf.inputs["Metallic"].default_value = 0.85
    n.bsdf.inputs["Roughness"].default_value = 0.42
    n.bump(diamond.outputs["Value"], 0.5, 0.004)
    cm._cache[name] = mat
    return mat


def torch():
    """A 1980s metal torch: a knurled dark body, a chrome head flaring to its
    bezel (open: the game's lens glows in it), a rubber switch boot round the
    game's switch, a tail cap with a lanyard ring. Length 1.37 studs."""
    body_m = _knurl("TorchBody", (52, 54, 58))
    chrome = cm.metal("TorchChrome", (200, 200, 204), 0.18)
    rubber = cm.plain("TorchRubber", (28, 28, 30), 0.85, bump=0.1, folds=0.0)
    ml = [body_m, chrome, rubber]
    body = _spin_z("TorchBodyTube", [(0.0, 0.6), (0.15, 0.6), (0.155, 0.56), (0.155, -0.44), (0.16, -0.46)])
    _paint(body, 0)
    head = _spin_z(
        "TorchHead",
        [(0.16, -0.44), (0.17, -0.47), (0.21, -0.56), (0.235, -0.66), (0.24, -0.72), (0.245, -0.74), (0.215, -0.755), (0.2, -0.745)],
        steps=40,
    )
    _paint(head, 1)
    tail = _spin_z("TorchTail", [(0.0, 0.62), (0.13, 0.62), (0.165, 0.6), (0.165, 0.52), (0.155, 0.5)])
    _paint(tail, 1)
    ring = _tube("TorchLanyard", [(0, 0.0, 0.63), (0, 0.08, 0.66), (0, 0.13, 0.62), (0, 0.08, 0.58), (0, 0.0, 0.63)], 0.012, 8)
    _paint(ring, 1)
    boot = _box("TorchBoot", (0.15, 0.04, 0.26), (0, 0.155, 0.05), 0.015)
    _paint(boot, 2)
    obj = _join([body, head, tail, ring, boot], "ToolTorch", ml)
    obj["bake_size"] = 512
    return obj



# The torch's looks (LB4, docs/plans/lobby-rework.md, "Electronics"): sold for
# Marks, looks only. Each keeps today's lens (its opening at z -0.75, 0.4
# across), the switch on top at z 0.05 and the body round the grip just
# behind it (Config.ViewModel's `grip`), so the beam, the switch's glow and
# the hand are exactly as they are; nothing on them glows. Named
# ToolTorch<Look> (Data/Kit Tools).


def _lanyard(name, z, y=0.0):
    """A loop of cord off the tail."""
    return _tube(name, [(0, y, z), (0, y + 0.08, z + 0.035), (0, y + 0.13, z - 0.01), (0, y + 0.08, z - 0.05), (0, y, z)], 0.012, 8)


def torch_rubber():
    """A yellow rubber work torch (1,000 Marks): chunky and practical,
    ribbed where the hand goes, a black rubber bumper round the head, a black
    tail cap and lanyard, a black boot round the switch."""
    yellow = cm.plain("RubberYellow", (248, 196, 26), 0.66, bump=0.15, scale=60.0, mottle=0.04, folds=0.0)
    black = cm.plain("RubberBlack", (28, 28, 30), 0.85, bump=0.12, folds=0.0)
    ml = [yellow, black]
    body = _paint(_spin_z("RubberBody", [(0.0, 0.6), (0.155, 0.6), (0.165, 0.56), (0.165, -0.42), (0.172, -0.45)]), 0)
    ribs = [
        _paint(_spin_z("RubberRib", [(0.164, z - 0.022), (0.179, z - 0.012), (0.179, z + 0.012), (0.164, z + 0.022)]), 0)
        for z in (0.2, 0.28, 0.36, 0.44)
    ]
    head = _paint(_spin_z("RubberHead", [(0.172, -0.44), (0.185, -0.48), (0.225, -0.56), (0.248, -0.64), (0.252, -0.68)], steps=40), 0)
    bumper = _paint(
        _spin_z("RubberBumper", [(0.25, -0.655), (0.276, -0.675), (0.282, -0.735), (0.258, -0.768), (0.208, -0.765), (0.2, -0.75)], steps=40),
        1,
    )
    tail = _paint(_spin_z("RubberTail", [(0.0, 0.64), (0.14, 0.64), (0.172, 0.61), (0.172, 0.53), (0.165, 0.51)]), 1)
    ring = _paint(_lanyard("RubberLanyard", 0.66), 1)
    boot = _paint(_box("RubberBoot", (0.16, 0.05, 0.28), (0, 0.162, 0.05), 0.02), 1)
    obj = _join([body, head, bumper, tail, ring, boot] + ribs, "ToolTorchRubber", ml)
    obj["bake_size"] = 512
    return obj


def torch_brass():
    """A brass torch from someone's grandfather's drawer (1,500 Marks): an
    aged brass tube with engraved bands at either end, a knurled band to hold
    it by, a domed head with a rolled lip, a brass slide round the switch, a
    domed end cap and its ring."""
    brass = cm.metal("TorchBrass", (196, 160, 84), 0.3)
    dark = cm.metal("TorchBrassDark", (126, 96, 50), 0.5)
    knurl = _knurl("TorchBrassKnurl", (178, 142, 72))
    ml = [brass, dark, knurl]
    body = _paint(_spin_z("BrassBody", [(0.0, 0.6), (0.14, 0.6), (0.148, 0.57), (0.148, -0.4), (0.152, -0.42)]), 0)
    bands = [
        _paint(_spin_z("BrassBand", [(0.147, z - 0.012), (0.153, z - 0.008), (0.153, z + 0.008), (0.147, z + 0.012)]), 1)
        for z in (-0.33, -0.29, 0.5, 0.54)
    ]
    grip = _paint(_spin_z("BrassKnurl", [(0.147, 0.13), (0.152, 0.14), (0.152, 0.42), (0.147, 0.43)]), 2)
    head = _paint(
        _spin_z(
            "BrassHead",
            [(0.152, -0.42), (0.172, -0.46), (0.212, -0.54), (0.234, -0.62), (0.238, -0.69), (0.236, -0.73), (0.222, -0.752), (0.206, -0.756), (0.2, -0.745)],
            steps=40,
        ),
        0,
    )
    lip = _paint(_spin_z("BrassLip", [(0.236, -0.682), (0.25, -0.69), (0.252, -0.716), (0.238, -0.728)], steps=40), 0)
    slide = _paint(_box("BrassSlide", (0.13, 0.03, 0.32), (0, 0.15, 0.05), 0.012), 1)
    cap = _paint(_spin_z("BrassCap", [(0.0, 0.69), (0.06, 0.685), (0.115, 0.66), (0.145, 0.62), (0.15, 0.59)]), 0)
    ring = _paint(_tube("BrassRing", [(0, 0.0, 0.69), (0, 0.06, 0.72), (0, 0.1, 0.69), (0, 0.06, 0.66), (0, 0.0, 0.69)], 0.01, 8), 0)
    obj = _join([body, grip, head, lip, slide, cap, ring] + bands, "ToolTorchBrass", ml)
    obj["bake_size"] = 512
    return obj


def torch_chrome():
    """A long chrome torch (2,000 Marks), the one you show off: a long
    polished barrel, knurled where it's held, a wide head behind a crisp ring,
    a black rubber tail. Longer than today's only toward you, so the hand,
    the switch and the lens stay where they are."""
    chrome = cm.metal("TorchChromeBright", (216, 216, 222), 0.1)
    knurl = _knurl("TorchChromeKnurl", (184, 186, 192))
    rubber = cm.plain("TorchChromeRubber", (26, 26, 28), 0.85, bump=0.1, folds=0.0)
    ml = [chrome, knurl, rubber]
    body = _paint(_spin_z("ChromeBody", [(0.0, 1.15), (0.14, 1.15), (0.15, 1.12), (0.15, -0.42), (0.156, -0.44)]), 0)
    grips = [
        _paint(_spin_z("ChromeKnurl", [(0.149, a), (0.153, a + 0.01), (0.153, b - 0.01), (0.149, b)]), 1)
        for a, b in ((0.13, 0.42), (0.62, 0.98))
    ]
    collar = _paint(_spin_z("ChromeCollar", [(0.155, -0.43), (0.168, -0.425), (0.168, -0.395), (0.155, -0.39)]), 0)
    head = _paint(
        _spin_z(
            "ChromeHead",
            [(0.156, -0.44), (0.168, -0.46), (0.222, -0.55), (0.252, -0.64), (0.258, -0.72), (0.262, -0.745), (0.224, -0.762), (0.2, -0.748)],
            steps=40,
        ),
        0,
    )
    tail = _paint(_spin_z("ChromeTail", [(0.0, 1.2), (0.12, 1.2), (0.148, 1.18), (0.148, 1.13), (0.142, 1.12)]), 2)
    boot = _paint(_box("ChromeBoot", (0.15, 0.04, 0.26), (0, 0.155, 0.05), 0.015), 2)
    obj = _join([body, collar, head, tail, boot] + grips, "ToolTorchChrome", ml)
    obj["bake_size"] = 512
    return obj


# The looks on sale (LB4): in TOOLS since the owner kept them for now
# (2026-10-16).
TORCH_LOOKS = [torch_rubber, torch_brass, torch_chrome]

def lantern():
    """A hurricane lantern: a tin fount for a base, a wire guard round the
    game's glass and flame (left open), a vented top, a bail handle."""
    tin = cm.metal("LanternTin", (64, 74, 60), 0.45)
    brass = cm.metal("LanternBrass", (170, 134, 70), 0.3)
    ml = [tin, brass]
    fount = _spin_y("LanternFount", [(0.0, -0.44), (0.3, -0.44), (0.32, -0.4), (0.3, -0.32), (0.24, -0.3), (0.22, -0.28), (0.0, -0.28)])
    _paint(fount, 0)
    top = _spin_y("LanternTop", [(0.0, 0.46), (0.06, 0.46), (0.1, 0.4), (0.24, 0.34), (0.27, 0.3), (0.24, 0.28), (0.0, 0.28)])
    _paint(top, 0)
    wires = []
    for i in range(4):
        a = math.tau * (i + 0.5) / 4
        x, z = math.cos(a), math.sin(a)
        wires.append(_tube("LanternWire", [(x * 0.26, -0.3, z * 0.26), (x * 0.31, 0.0, z * 0.31), (x * 0.26, 0.3, z * 0.26)], 0.012, 6))
    for y in (-0.1, 0.12):
        pts = [(math.cos(math.tau * k / 24) * 0.305, y, math.sin(math.tau * k / 24) * 0.305) for k in range(25)]
        wires.append(_tube("LanternHoop", pts, 0.01, 6))
    bail = _tube("LanternBail", [(-0.27, 0.32, 0), (-0.22, 0.6, 0), (0, 0.7, 0), (0.22, 0.6, 0), (0.27, 0.32, 0)], 0.014, 8)
    knob = _spin_z("LanternKnob", [(0.0, 0.0), (0.04, 0.0), (0.04, -0.04), (0.0, -0.04)], steps=12, z0=-0.31, y=-0.35)
    _paint(knob, 1)
    obj = _join([fount, top, bail, knob] + wires, "ToolLantern", ml)
    _paint_named = None
    del _paint_named
    obj["bake_size"] = 512
    return obj


def radio():
    """A 1980s transistor radio: a leather case, a chrome speaker grille, a
    lit tuning scale, a tuning knob, a carrying strap and a telescopic aerial."""
    leather = cm.leather("RadioLeather", (92, 54, 34), 0.5)
    chrome = cm.metal("RadioChrome", (196, 196, 200), 0.22)
    scale = cm.plain("RadioScale", (226, 214, 176), 0.5, bump=0.02, folds=0.0)
    knob_m = cm.plain("RadioKnob", (34, 32, 30), 0.4, bump=0.02, folds=0.0)
    ml = [leather, chrome, scale, knob_m]
    case = _paint(_box("RadioCase", (0.95, 0.58, 0.36), (0, 0, 0), 0.06), 0)
    grille = _paint(_box("RadioGrille", (0.5, 0.42, 0.02), (-0.17, 0, -0.18), 0.01), 1)
    dial = _paint(_box("RadioDial", (0.24, 0.22, 0.02), (0.3, 0.1, -0.18), 0.008), 2)
    bezel = _paint(_box("RadioBezel", (0.27, 0.25, 0.012), (0.3, 0.1, -0.175), 0.006), 1)
    knob = _paint(_spin_z("RadioKnobTurn", [(0.0, -0.26), (0.06, -0.26), (0.065, -0.2), (0.0, -0.2)], steps=16, y=-0.14, x=0.3), 3)
    strap = _paint(_tube("RadioStrap", [(-0.47, 0.18, 0), (-0.4, 0.42, 0), (0, 0.5, 0), (0.4, 0.42, 0), (0.47, 0.18, 0)], 0.025, 8), 0)
    aerial = _paint(_tube("RadioAerial", [(0.4, 0.3, 0.1), (0.52, 1.35, 0.1)], 0.014, 8), 1)
    tip = _paint(_spin_y("RadioAerialTip", [(0.0, 1.32), (0.025, 1.32), (0.025, 1.38), (0.0, 1.38)], steps=10, x=0.52, z=0.1), 1)
    obj = _join([case, grille, dial, bezel, knob, strap, aerial, tip], "ToolRadio", ml)
    obj["bake_size"] = 512
    return obj


def crowbar():
    """A crowbar: hexagonal red-painted steel, worn to bare metal at the ends,
    a hooked claw (split) at the front, a flat chisel at the back."""
    paint = cm.plain("CrowbarPaint", (150, 40, 32), 0.45, bump=0.08, folds=0.0)
    steel = cm.metal("CrowbarSteel", (130, 130, 134), 0.35)
    ml = [paint, steel]
    pts = [(0, -0.02, 0.92), (0, 0.0, 0.5), (0, 0.0, -0.6), (0, 0.04, -0.8), (0, 0.16, -0.96), (0, 0.32, -1.0), (0, 0.42, -0.94)]
    bar = _paint(_tube("CrowbarBar", pts, 0.06, 6), 0)
    _paint_where(bar, 1, lambda g: g.z > 0.78 or g.y > 0.34)
    chisel = _paint(_box("CrowbarChisel", (0.15, 0.04, 0.2), (0, -0.04, 0.98), 0.01), 1)
    claw = _paint(_box("CrowbarClaw", (0.15, 0.04, 0.14), (0, 0.46, -0.9), 0.01), 1)
    obj = _join([bar, chisel, claw], "ToolCrowbar", ml)
    obj["bake_size"] = 512
    return obj


def bolt_cutters():
    """Bolt cutters: long steel handles in orange rubber grips, short heavy
    jaws and their bolted pivot plates."""
    steel = cm.metal("CutterSteel", (120, 122, 126), 0.35)
    grip_m = cm.plain("CutterGrip", (200, 110, 30), 0.7, bump=0.15, folds=0.0)
    ml = [steel, grip_m]
    parts = []
    for side in (-1, 1):
        parts.append(_paint(_tube("CutterHandle", [(side * 0.03, 0, -0.2), (side * 0.08, 0, 0.3), (side * 0.12, 0, 0.92)], 0.035, 8), 0))
        parts.append(_paint(_tube("CutterGrip", [(side * 0.095, 0, 0.5), (side * 0.12, 0, 0.94)], 0.05, 10), 1))
        parts.append(_paint(_box("CutterJaw", (0.05, 0.12, 0.3), (side * 0.035, 0, -0.38), 0.012), 0))
    parts.append(_paint(_box("CutterPlate", (0.18, 0.15, 0.14), (0, 0, -0.2), 0.02), 0))
    obj = _join(parts, "ToolBoltCutters", ml)
    obj["bake_size"] = 512
    return obj


def salts():
    """Smelling salts: a small brown glass bottle, a paper label, a black
    screw cap."""
    glass = cm.plain("SaltsGlass", (96, 58, 26), 0.12, bump=0.0, folds=0.0)
    paper = cm.plain("SaltsLabel", (225, 210, 170), 0.8, bump=0.05, folds=0.0)
    cap = cm.plain("SaltsCap", (34, 32, 30), 0.4, bump=0.02, folds=0.0)
    ml = [glass, paper, cap]
    bottle = _paint(_spin_y("SaltsBottle", [(0.0, -0.27), (0.14, -0.27), (0.15, -0.24), (0.15, 0.14), (0.1, 0.24), (0.075, 0.28), (0.075, 0.36), (0.0, 0.36)], steps=24), 0)
    label = _paint(_spin_y("SaltsLabelBand", [(0.153, -0.17), (0.153, 0.06)], steps=24), 1)
    lid = _paint(_spin_y("SaltsCapTop", [(0.0, 0.34), (0.095, 0.34), (0.095, 0.47), (0.0, 0.47)], steps=20), 2)
    obj = _join([bottle, label, lid], "ToolSalts", ml)
    obj["bake_size"] = 256
    return obj


TOOLS = [torch, lantern, radio, crowbar, bolt_cutters, salts] + TORCH_LOOKS
