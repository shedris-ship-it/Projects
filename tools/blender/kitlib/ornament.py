"""The house's architecture, last of it (the visual rework V4b, 2026-10-15):
plaster ceiling roses over the lights, a coffered ceiling's beams and their
bosses, cast-iron radiators under the windows, and the pocket doors in the
archways between the formal rooms.

Each piece is built round the origin in Blender's frame (X along or across,
Z up, its front toward -Y); sizes are Roblox's { x, y, z } = Blender's
(x, z, y). The ceiling pieces have their top at z = 0, so they hang under
the ceiling; the beams are a section swept along X for 4 studs (World/Kit
stretches them to each run, as trim).
"""

import math

import bmesh
from mathutils import Vector

from . import materials, shapes

PLASTER = (214, 206, 188)  # a ceiling rose's paint: off-white, aged
COFFER_PAINT = (206, 198, 178)
WALNUT = ((50, 34, 23), (92, 64, 44))  # as the trim (kitlib/trim)
IRON_PAINT = (184, 176, 156)  # a radiator's old cream enamel
BRASS = (150, 128, 84)


def _plaster(name):
    return materials.paint(name, color=PLASTER, roughness=0.78, grime=0.18)


def _leaf(name, length, width, depth, radius, angle, z, tilt=18):
    """An acanthus leaf lying on the ceiling pointing outward: a cushion
    tapered toward its tip, curled down at the end, turned to `angle`."""
    # (A bevelled block cut along its length so it can curl, not a smoothed
    # cushion: at a ceiling's distance it reads the same, at a fifth of the
    # triangles.)
    leaf = shapes.box(name, (length, width, depth), (0, 0, 0), min(width, depth) * 0.45, 1)
    bm = bmesh.new()
    bm.from_mesh(leaf.data)
    along = [e for e in bm.edges if abs((e.verts[0].co - e.verts[1].co).normalized().x) > 0.9]
    bmesh.ops.subdivide_edges(bm, edges=along, cuts=4, use_grid_fill=True)
    bm.to_mesh(leaf.data)
    bm.free()
    for v in leaf.data.vertices:
        x, y, zz = v.co
        t = min(max((x / length) + 0.5, 0.0), 1.0)  # 0 at the root, 1 at the tip
        v.co.y *= 1.0 - 0.75 * t ** 1.6
        v.co.z -= depth * 1.2 * t ** 2  # curls down toward the room
        v.co.y += 0.25 * width * math.sin(t * math.pi) * (1 if v.co.y > 0 else -1) * 0.2
    shapes.turn(leaf, (0, -tilt, math.degrees(angle)), at=(math.cos(angle) * radius, math.sin(angle) * radius, z))
    return leaf


def _rose(name, radius, rings, leaves, leaf_size, beads):
    """A plaster ceiling medallion: a stepped disc of mouldings (rings of
    (from radius, to radius, drop below the ceiling)), a wreath of acanthus
    leaves, a bead ring at the rim, a centre boss with the light's hole."""
    paint = _plaster(name + "Plaster")
    parts = []
    # The stepped disc: from the rim in, each ring dropping a little lower.
    profile = [(radius, 0.0), (radius - 0.01, -0.035), (radius - 0.04, -0.055), (radius - 0.075, -0.05), (radius - 0.09, -0.03)]
    for r0, r1, drop in rings:
        r0 = min(r0, radius - 0.1)  # (inside the beads)
        profile += [(r0, -drop * 0.4), (r0 - (r0 - r1) * 0.3, -drop), (r1 + (r0 - r1) * 0.2, -drop), (r1, -drop * 0.7)]
    profile += [(0.0, profile[-1][1])]
    # (Lathe wants it from the bottom up; ours runs from the rim inward.)
    disc = shapes.lathe(name + "Disc", list(reversed(profile)) + [(radius, 0.0)], steps=48)
    parts.append(disc)
    # The leaves, in a ring between the outer moulding and the boss.
    mid = (rings[0][1] + rings[-1][0]) / 2 if len(rings) > 1 else radius * 0.6
    for k in range(leaves):
        a = k * math.tau / leaves
        parts.append(_leaf(name + "Leaf", leaf_size[0], leaf_size[1], leaf_size[2], mid, a, -rings[0][2] - 0.02))
    # The boss: a turned button with the cord's hole.
    deepest = max(d for _, _, d in rings)
    boss = shapes.lathe(
        name + "Boss",
        [(0.05, -deepest - 0.14), (0.16, -deepest - 0.12), (0.2, -deepest - 0.04), (0.16, -deepest + 0.02), (0.0, -deepest + 0.02)],
        steps=32,
    )
    parts.append(boss)
    for p in parts:
        materials.assign(p, paint)
    rose = shapes.join(parts, name)
    shapes.cull(rose, [(0, 0, 1)])  # its back on the ceiling
    shapes.smooth(rose, 50)
    return rose


def ceiling_rose():
    """The plaster rose over a pendant, 2.6 across and 0.3 deep: a beaded
    rim, two stepped mouldings, a wreath of sixteen acanthus leaves, a boss
    the pendant's canopy covers."""
    return _rose(
        "CeilingRose",
        1.3,
        rings=[(1.3, 1.1, 0.08), (0.55, 0.38, 0.14), (0.38, 0.2, 0.18)],
        leaves=16,
        leaf_size=(0.42, 0.2, 0.07),
        beads=48,
    )


def ceiling_rose_large():
    """The grand hall's rose over the chandelier, 4.8 across: three
    mouldings, two wreaths of leaves, a beaded rim."""
    r = 2.4
    rose = _rose(
        "CeilingRoseLarge",
        r,
        rings=[(2.4, 2.15, 0.1), (1.35, 1.15, 0.16), (0.7, 0.45, 0.22), (0.45, 0.25, 0.26)],
        leaves=20,
        leaf_size=(0.62, 0.3, 0.09),
        beads=80,
    )
    # A second, inner wreath, smaller and turned half a leaf.
    paint = rose.data.materials[0]
    inner = []
    for k in range(12):
        a = (k + 0.5) * math.tau / 12
        inner.append(materials.assign(_leaf("Inner", 0.34, 0.17, 0.06, 0.95, a, -0.2), paint))
    return shapes.join([rose] + inner, "CeilingRoseLarge")


def _coffer_profile(w, d, cove):
    """A coffer beam's section (y across, z down from the ceiling at 0): a
    cove moulding sweeping out onto the ceiling either side, the beam's
    sides with a fillet, a soffit with a bead down its middle."""
    hw = w / 2
    pts = [(hw + cove, 0.0)]
    # The cove: a quarter hollow from the ceiling down to the beam's side.
    for i in range(1, 8):
        s = i / 8
        a = s * math.pi / 2
        pts.append((hw + cove * (1 - math.sin(a)), -cove * (1 - math.cos(a))))
    pts += [(hw, -cove - 0.02), (hw, -d + 0.06), (hw - 0.03, -d + 0.03), (hw - 0.05, -d)]
    # The soffit with a small bead.
    pts += [(0.06, -d), (0.04, -d - 0.015), (0.0, -d - 0.02), (-0.04, -d - 0.015), (-0.06, -d)]
    pts += [(-hw + 0.05, -d), (-hw + 0.03, -d + 0.03), (-hw, -d + 0.06), (-hw, -cove - 0.02)]
    for i in range(7, 0, -1):
        s = i / 8
        a = s * math.pi / 2
        pts.append((-hw - cove * (1 - math.sin(a)), -cove * (1 - math.cos(a))))
    pts.append((-hw - cove, 0.0))
    return pts


COFFER = {"width": 0.55, "depth": 0.62, "cove": 0.14}


def _coffer_beam(name, material):
    c = COFFER
    profile = [(y, z) for y, z in _coffer_profile(c["width"], c["depth"], c["cove"])]
    beam = shapes.moulding(name, profile, 4.0)
    shapes.cull(beam, [(0, 0, 1)])  # its top on the ceiling
    return materials.assign(beam, material)


def coffer_beam_wood():
    """A walnut coffer beam (the dining room's, the study's): 0.83 wide
    with its coves, 0.64 deep, stretched along each run."""
    return _coffer_beam(
        "CofferBeamWood", materials.wood("CofferWalnut", WALNUT[0], WALNUT[1], grain_axis="X", scale=1.0, roughness=0.45)
    )


def coffer_beam_paint():
    """A painted coffer beam (the living room's, the music room's)."""
    return _coffer_beam("CofferBeamPaint", materials.paint("CofferPaint", color=COFFER_PAINT, roughness=0.6, grime=0.15))


def _boss(name, material):
    """Where two beams cross: a square block a little deeper than them, a
    carved four-petal rosette on its face, hiding the joint."""
    c = COFFER
    s = c["width"] + 0.32
    d = c["depth"] + 0.08
    # (Light: a room has twenty of them.)
    parts = [shapes.box(name + "Block", (s, s, d), (0, 0, -d / 2), 0.04, 1)]
    # A raised square field and a four-petal rosette on the soffit.
    parts.append(shapes.box(name + "Field", (s - 0.16, s - 0.16, 0.04), (0, 0, -d - 0.02), 0.015, 1))
    for k in range(4):
        a = k * math.pi / 2 + math.pi / 4
        petal = shapes.box(name + "Petal", (0.22, 0.11, 0.05), (0, 0, 0), 0.04, 1)
        shapes.turn(petal, (0, 0, math.degrees(a)), at=(math.cos(a) * 0.11, math.sin(a) * 0.11, -d - 0.065))
        parts.append(petal)
    parts.append(shapes.lathe(name + "Knob", [(0.0, -d - 0.12), (0.06, -d - 0.11), (0.07, -d - 0.05), (0.0, -d - 0.04)], steps=10))
    for p in parts:
        materials.assign(p, material)
    boss = shapes.join(parts, name)
    shapes.cull(boss, [(0, 0, 1)])
    return boss


def coffer_boss_wood():
    return _boss("CofferBossWood", materials.wood("BossWalnut", WALNUT[0], WALNUT[1], grain_axis="X", scale=1.0, roughness=0.45))


def coffer_boss_paint():
    return _boss("CofferBossPaint", materials.paint("BossPaint", color=COFFER_PAINT, roughness=0.6, grime=0.15))


RADIATOR = {"width": 4.2, "height": 2.55, "depth": 0.62}


def radiator():
    """A cast-iron column radiator under a window, 4.2 wide, 2.55 high,
    0.62 deep, standing on its feet: sixteen sections of three tubes each,
    joined top and bottom, in old cream enamel; a valve with a wheel at one
    end, its pipe down into the floor. Its back toward +Y (the wall)."""
    R = RADIATOR
    paint = materials.paint("RadiatorEnamel", color=IRON_PAINT, roughness=0.55, grime=0.35)
    brass = materials.brass("ValveBrass", color=BRASS)
    pipe_paint = materials.paint("RadiatorPipe", color=(120, 112, 100), roughness=0.5, grime=0.3)
    parts = []
    w, h, d = R["width"] - 0.5, R["height"], R["depth"]
    n = 16
    pitch = w / n
    foot = 0.14
    def tube(name, length, radius, at, axis, steps):
        # An open tube, its ends hidden in what it joins.
        t = shapes.lathe(name, [(radius, -length / 2), (radius, length / 2)], steps=steps)
        if axis == "X":
            shapes.turn(t, (0, 90, 0))
        t.location = at
        return t

    for i in range(n):
        x = -w / 2 + pitch * (i + 0.5)
        # A section: three tubes between a loop at the top and one at the
        # bottom (cast as one piece), a little gap to the next.
        for y in (-d * 0.3, 0.0, d * 0.3):
            parts.append(tube("Tube", h - foot - 0.25, 0.08, (x, y, foot + (h - foot) / 2), "Z", 8))
        # The loops: a rounded bar front to back, so from the front each
        # section ends in a round top, scalloped along the radiator.
        for z in (foot + 0.13, h - pitch * 0.48):
            loop = shapes.lathe(
                "Loop",
                [(0.0, -d * 0.48), (pitch * 0.47, -d * 0.48), (pitch * 0.48, -d * 0.45), (pitch * 0.48, d * 0.45), (pitch * 0.47, d * 0.48), (0.0, d * 0.48)],
                steps=12,
            )
            shapes.turn(loop, (90, 0, 0))
            loop.location = (x, 0.0, z)
            parts.append(loop)
        # The nipples joining it to the next section, top and bottom.
        if i < n - 1:
            for z in (foot + 0.13, h - pitch * 0.48):
                parts.append(tube("Nipple", pitch * 0.4, 0.06, (x + pitch / 2, 0.0, z), "X", 6))
    # Feet at either end.
    for x in (-w / 2 + pitch * 0.5, w / 2 - pitch * 0.5):
        parts.append(shapes.box("Foot", (pitch * 0.8, d * 0.9, foot), (x, 0.0, foot / 2), 0.03, 1))
    for p in parts:
        materials.assign(p, paint)
    # The valve and its pipe at the right-hand end.
    vx = w / 2 + 0.16
    parts.append(materials.assign(shapes.roll("Nipple", 0.3, 0.06, (w / 2 + 0.05, 0.0, foot + 0.1), axis="X", steps=10), pipe_paint))
    parts.append(materials.assign(shapes.box("ValveBody", (0.2, 0.18, 0.22), (vx, 0.0, foot + 0.1), 0.04, 2), brass))
    parts.append(materials.assign(shapes.roll("Spindle", 0.22, 0.025, (vx, 0.0, foot + 0.3), axis="Z", steps=8), brass))
    wheel = shapes.lathe(
        "Wheel", [(0.05, 0.0), (0.13, 0.0), (0.15, 0.02), (0.13, 0.045), (0.05, 0.045), (0.05, 0.0)], steps=16
    )
    shapes.turn(wheel, (0, 0, 0), at=(vx, 0.0, foot + 0.41))
    parts.append(materials.assign(wheel, brass))
    parts.append(materials.assign(shapes.roll("Pipe", foot + 0.05, 0.05, (vx, 0.0, (foot + 0.05) / 2), axis="Z", steps=10), pipe_paint))
    rad = shapes.join(parts, "Radiator")
    shapes.cull(rad, [(0, 0, -1)])  # its feet on the floor
    return rad


POCKET = {"out": 0.3, "into": 0.12, "thick": 0.16, "height": 7.9}


def pocket_door():
    """A pocket door's leaf where it shows, slid into its wall: its edge,
    pulled `out` studs from the jamb's lining, a stile with a bead down each
    face, a brass edge pull, and the dark slot it slides into (flush with the
    lining, a little wider than the leaf). X runs from in the wall to the
    leaf's edge (+X, into the opening), Y through the wall, Z up from the
    floor's middle. World/Trim stands one in each jamb of an archway."""
    P = POCKET
    walnut = materials.wood("PocketWalnut", WALNUT[0], WALNUT[1], grain_axis="Z", scale=1.0, roughness=0.45)
    brass = materials.brass("PocketPull", color=BRASS)
    shadow = materials.paint("PocketSlot", color=(14, 12, 10), roughness=0.95, grime=0.0)
    out, into, t, h = P["out"], P["into"], P["thick"], P["height"]
    parts = []
    # The leaf: from inside the wall to its edge.
    leaf = shapes.box("Leaf", (out + into, t, h), ((out - into) / 2, 0.0, 0.0), 0.02, 2)
    parts.append(materials.assign(leaf, walnut))
    # A bead down each face, a little back from the edge (the stile's moulding).
    for side in (-1, 1):
        bead = shapes.roll("Bead", h - 0.6, 0.012, (out - 0.18, side * (t / 2), 0.0), axis="Z", steps=6)
        parts.append(materials.assign(bead, walnut))
    # The edge pull: a recessed brass plate with a finger slot.
    plate = shapes.box("Pull", (0.012, t * 0.62, 0.42), (out + 0.002, 0.0, -0.3), 0.004, 2)
    parts.append(materials.assign(plate, brass))
    slot = shapes.box("PullSlot", (0.008, t * 0.36, 0.22), (out + 0.009, 0.0, -0.3), 0.003, 1)
    parts.append(materials.assign(slot, shadow))
    # The slot in the lining, the leaf coming out of it.
    gap = shapes.box("Slot", (0.02, t + 0.1, h), (0.0, 0.0, 0.0), 0.0, 1)
    parts.append(materials.assign(gap, shadow))
    door = shapes.join(parts, "PocketDoor")
    return door


V4B = [ceiling_rose, ceiling_rose_large, coffer_beam_wood, coffer_beam_paint, coffer_boss_wood, coffer_boss_paint, radiator, pocket_door]
