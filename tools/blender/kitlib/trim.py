"""The house's architecture (the visual rework V4b): the trim every room has
(baseboard, crown, the door casing, the dado rail), the doors, their knob, the
stair's steps and the sash window. Each piece is built round the origin in
Blender's frame: X along it (or across), Z up, its front toward -Y.

Trim is a moulding's section swept along X for 4 studs: World/Kit stretches
it to each run's length, so its section fills its whole box (the game's
Config.Trim sizes) and its paint and grain change only across it. Two runs
meeting in a corner cross each other's section, which makes the mitre.

Sizes are Roblox's { x, y, z } = Blender's (x, z, y).
"""

import math

from . import materials, shapes

TRIM_WOOD = ((50, 34, 23), (92, 64, 44))  # Config.Trim.Wood, dark walnut
TRIM_PAINT = (196, 188, 168)  # Config.Trim.Paint
KNOB_BRASS = (150, 128, 84)  # Config.Trim.Knob, tarnished


def _trim_wood(name):
    return materials.wood(name, TRIM_WOOD[0], TRIM_WOOD[1], grain_axis="X", scale=1.0, roughness=0.45)


def _trim_paint(name):
    # Grime low (it runs the length of a long run once stretched).
    return materials.paint(name, color=TRIM_PAINT, roughness=0.5, grime=0.15)


def _curve(a, b, steps, bulge):
    """Points from a to b ((y, z) each), bowed `bulge` studs out from the
    straight line toward -y (positive) or +y."""
    out = []
    for i in range(1, steps):
        s = i / steps
        y = a[0] + (b[0] - a[0]) * s - bulge * math.sin(math.pi * s)
        z = a[1] + (b[1] - a[1]) * s
        out.append((y, z))
    return out


def baseboard():
    """The baseboard, 0.7 high and 0.14 deep (Config.Trim): a quarter-round
    shoe at the floor, a flat board, a bead and an ogee cap curving back to
    the wall."""
    t, h = 0.07, 0.35
    profile = [
        (t, -h),
        (-t, -h),
        (-0.068, -0.325),
        (-0.062, -0.305),
        (-0.055, -0.292),
        (-0.05, -0.285),
        (-0.05, 0.16),
        (-0.056, 0.17),
        (-0.06, 0.185),
        (-0.058, 0.2),
        (-0.05, 0.21),
        (-0.045, 0.215),
        (-0.045, 0.235),
        (-0.042, 0.26),
        (-0.032, 0.284),
        (-0.018, 0.3),
        (-0.01, 0.315),
        (-0.007, 0.33),
        (-0.002, 0.343),
        (0.01, h),
        (t, h),
    ]
    board = shapes.moulding("Baseboard", profile, 4.0)
    shapes.cull(board, [(0, 1, 0), (0, 0, -1)])  # its back on the wall, its foot on the floor
    return materials.assign(board, _trim_wood("BaseboardWalnut"))


def crown():
    """The crown moulding, 0.45 high and 0.3 deep (Config.Trim): a fillet on
    the ceiling, an ogee sweeping down and back to a fillet on the wall."""
    t, h = 0.15, 0.225
    top = (-0.138, 0.19)
    foot = (0.112, -0.2)
    # A cyma recta: hollow above, round below.
    curve = []
    steps = 16
    for i in range(steps + 1):
        s = i / steps
        y = top[0] + (foot[0] - top[0]) * (s - 0.11 * math.sin(2 * math.pi * s))
        z = top[1] + (foot[1] - top[1]) * s
        curve.append((y, z))
    profile = [(t, -h), (t, h), (-t, h), (-t, 0.205), (-0.145, 0.195)] + curve + [(0.122, -0.212), (0.122, -h)]
    piece = shapes.moulding("Crown", profile, 4.0)
    shapes.cull(piece, [(0, 1, 0), (0, 0, 1)])  # on the wall and the ceiling
    return materials.assign(piece, _trim_wood("CrownWalnut"))


def _casing_profile(w, t):
    """A colonial casing's section across its width w (z from the opening's
    edge, -w/2, to its outer edge, +w/2) and depth t: a bead at the opening,
    a field rising gently, a back band at the outer edge. It only rises
    outward, so two lengths crossing at a corner make a true mitre."""
    lo, hi = -w / 2, w / 2
    back = t / 2
    f = t / 0.18  # (drawn for the door's 0.18)
    g = w / 0.55

    def p(y, z):
        return (y * f, z * g)

    pts = [
        (back, lo),
        p(0.02, -0.275),
        p(0.012, -0.268),
        p(0.006, -0.255),
        p(0.008, -0.24),
        p(0.012, -0.232),
        p(0.004, -0.2),
        p(-0.006, -0.08),
        p(-0.016, 0.06),
        p(-0.02, 0.1),
        p(-0.03, 0.118),
        p(-0.046, 0.13),
        p(-0.062, 0.142),
        p(-0.076, 0.158),
        p(-0.086, 0.178),
        p(-t / 2 / f, 0.2),
        p(-t / 2 / f, 0.238),
        p(-0.086, 0.258),
        p(-0.072, 0.27),
        p(-0.054, 0.275),
        (back, hi),
    ]
    return pts


def casing():
    """A door's casing, 0.55 wide and 0.18 deep (Config.Trim), lying as the
    head does: its opening edge down, its back band up. World/Trim turns it
    upright for the jambs."""
    piece = shapes.moulding("Casing", _casing_profile(0.55, 0.18), 4.0)
    shapes.cull(piece, [(0, 1, 0)])
    return materials.assign(piece, _trim_paint("CasingPaint"))


def dado_rail():
    """The dado (chair) rail over a formal room's panelling, 0.2 high and
    0.12 deep: a cove under a bullnose, a bevel back to the wall on top."""
    profile = [
        (0.06, -0.1),
        (0.03, -0.1),
        (0.005, -0.096),
        (-0.016, -0.084),
        (-0.03, -0.066),
        (-0.04, -0.045),
        (-0.052, -0.026),
        (-0.06, -0.004),
        (-0.06, 0.02),
        (-0.055, 0.04),
        (-0.045, 0.056),
        (-0.03, 0.07),
        (-0.015, 0.084),
        (0.002, 0.095),
        (0.02, 0.1),
        (0.06, 0.1),
    ]
    rail = shapes.moulding("DadoRail", profile, 4.0)
    shapes.cull(rail, [(0, 1, 0)])
    return materials.assign(rail, _trim_wood("DadoWalnut"))


def stair_step():
    """One step's tread and riser for the staircase, 6 wide, 0.54 high, 1.12
    deep (World/Kit fits it to each step: its width, rise and tread): a
    walnut tread board with a bullnose standing 0.12 over the riser, and a
    riser board in old cream paint under it. Its top stands 0.04 over the
    game's step and its riser 0.03 in front of it, so no faces share a
    plane."""
    w, h, d = 6.0, 0.54, 1.12
    board = 0.12
    nose = board / 2
    y0, y1 = -d / 2, d / 2
    top = h / 2
    # The tread's section: flat on top, a half-round nose at the front.
    profile = [(y1, top - board), (y1, top), (y0 + nose, top)]
    for k in range(1, 8):
        a = math.pi / 2 + math.pi * k / 8
        profile.append((y0 + nose + nose * math.cos(a), top - nose + nose * math.sin(a)))
    profile += [(y0 + nose, top - board)]
    tread = shapes.moulding("Tread", profile, w)
    shapes.cull(tread, [(0, 1, 0)])
    wood = materials.wood("TreadWalnut", (46, 30, 20), (92, 62, 40), grain_axis="X", scale=1.0, roughness=0.4)
    materials.assign(tread, wood)
    face = y0 + 0.12  # the game's step's front
    riser = shapes.box("Riser", (w, 0.03, h - board), (0, face - 0.015, -board / 2), 0.0)
    shapes.cull(riser, [(0, 1, 0), (0, 0, -1), (0, 0, 1)])
    materials.assign(riser, _trim_paint("RiserPaint"))
    # A small cove under the nose, where the tread meets the riser.
    cove = shapes.moulding(
        "Cove",
        [(face - 0.03, top - board), (face - 0.03 - 0.05, top - board), (face - 0.03 - 0.02, top - board - 0.03), (face - 0.03, top - board - 0.05)],
        w,
    )
    materials.assign(cove, _trim_paint("CovePaint"))
    return shapes.join([tread, riser, cove], "StairStep")


def knob():
    """A door's knob set, through the door: a rose on each face (the slab's
    faces at +-0.175), a neck and a round knob; 0.52 across, 0.94 through.
    Tarnished brass (Config.Trim.Knob)."""
    half = [
        (0.04, 0.0),
        (0.04, 0.17),
        (0.25, 0.175),
        (0.26, 0.185),
        (0.255, 0.2),
        (0.2, 0.212),
        (0.08, 0.22),
        (0.06, 0.24),
        (0.058, 0.3),
        (0.09, 0.33),
        (0.145, 0.37),
        (0.168, 0.4),
        (0.165, 0.43),
        (0.13, 0.455),
        (0.07, 0.468),
        (0.0, 0.47),
    ]
    profile = [(r, -z) for r, z in reversed(half)] + [(r, z) for r, z in half[1:]]
    profile = [(0.0, -0.47)] + profile[1:-1] + [(0.0, 0.47)]
    piece = shapes.lathe("Knob", profile, steps=18)
    shapes.turn(piece, (90, 0, 0))  # through the door: along Y (Roblox's Z)
    piece["bake_size"] = 256
    return materials.assign(piece, materials.brass("KnobBrass", color=KNOB_BRASS, roughness=0.36))


def _panel(name, x, z, w, h, depth, side, bevel=0.07):
    """A raised panel's field on one face of a door (side -1: the front, -Y),
    and the moulding round it."""
    t = 0.35 / 2
    y = side * (t + depth / 2)
    field = shapes.box(name + "Field", (w - 0.3, depth, h - 0.3), (x, y, z), bevel_width=depth * 0.9, segments=2)
    parts = [field]
    # The moulding round it: the rails across a hair prouder than the stiles
    # up, so where they overlap at the corners no two faces share a plane.
    for mx, mz, mw, mh, k in (
        (x, z + h / 2 - 0.04, w, 0.08, 1.3),
        (x, z - h / 2 + 0.04, w, 0.08, 1.3),
        (x - w / 2 + 0.04, z, 0.08, h - 0.02, 1.2),
        (x + w / 2 - 0.04, z, 0.08, h - 0.02, 1.2),
    ):
        mould = shapes.box(name + "Mould", (mw, depth * k, mh), (mx, side * (t + depth * k / 2), mz), 0.025, 1)
        shapes.cull(mould, [(0, -side, 0)])  # its back, on the door
        parts.append(mould)
    _ = bevel
    return parts


def door():
    """A 1988 six-panel interior door slab, 5.8 x 7.8 x 0.35 plus its panels
    (World/LevelBuilder's slab), in old off-white paint: small panels at the
    top, tall ones in the middle, a lock rail at the knob's height (0.5 under
    the middle: World/LevelBuilder) and stiles wide enough for its rose."""
    paint = materials.paint("DoorPaint", color=TRIM_PAINT, roughness=0.5, grime=0.25)
    w, h, t = 5.8, 7.8, 0.35
    slab = shapes.box("Slab", (w, t, h), (0, 0, 0), 0.03, 2)
    stile, mullion = 0.85, 0.45
    pw = (w - 2 * stile - mullion) / 2
    rows = [(-3.15, -0.8), (-0.2, 2.45), (2.85, 3.5)]  # bottom, middle, top panels (z from, to)
    parts = [slab]
    for side in (-1, 1):
        for z0, z1 in rows:
            for sx in (-1, 1):
                x = sx * (mullion / 2 + pw / 2)
                parts += _panel("Panel", x, (z0 + z1) / 2, pw, z1 - z0, 0.05, side)
    door = shapes.join(parts, "Door")
    return materials.assign(door, paint)


def glass_door():
    """A gate into a wing (docs/plans/level-design.md 10.7): a stained walnut
    door, 5.8 x 7.8 x 0.35, glazed above its sill (Config.Trim.GlassDoor:
    4.4 up, 0.7 stiles, a 0.5 top rail, a muntin down the middle), two raised
    panels below on each face. The glass is the game's own."""
    wood = materials.wood("GateWalnut", (46, 30, 20), (92, 62, 40), grain_axis="Z", scale=1.0, roughness=0.42)
    wood_x = materials.wood("GateWalnutAcross", (46, 30, 20), (92, 62, 40), grain_axis="X", scale=1.0, roughness=0.42)
    w, h, t = 5.8, 7.8, 0.35
    bottom = -h / 2
    sill = bottom + 4.4
    rail = 0.5
    stile = 0.7
    parts = []
    # The solid lower part, the stiles, the top rail and the muntin.
    parts.append(materials.assign(shapes.box("Lower", (w, t, sill - bottom), (0, 0, (sill + bottom) / 2), 0.03, 2), wood_x))
    glass_h = h / 2 - rail - sill
    for sx in (-1, 1):
        parts.append(materials.assign(shapes.box("Stile", (stile, t, glass_h), (sx * (w / 2 - stile / 2), 0, sill + glass_h / 2), 0.03, 2), wood))
    parts.append(materials.assign(shapes.box("Rail", (w, t, rail), (0, 0, h / 2 - rail / 2), 0.03, 2), wood_x))
    parts.append(materials.assign(shapes.box("Muntin", (0.14, 0.2, glass_h), (0, 0, sill + glass_h / 2), 0.02, 2), wood))
    # Glazing beads round each pane, both faces.
    inner = w / 2 - stile
    for side in (-1, 1):
        y = side * 0.11
        for x0, x1 in ((-inner, -0.07), (0.07, inner)):
            cx, bw = (x0 + x1) / 2, x1 - x0
            for bz, bh, bx, bww in (
                (sill + 0.04, 0.08, cx, bw),
                (h / 2 - rail - 0.04, 0.08, cx, bw),
                (sill + glass_h / 2, glass_h, x0 + 0.04, 0.08),
                (sill + glass_h / 2, glass_h, x1 - 0.04, 0.08),
            ):
                bead = shapes.box("Bead", (bww, 0.07, bh), (bx, y, bz), 0.025, 2)
                parts.append(materials.assign(bead, wood))
        # Two raised panels below the glass on each face.
        for sx in (-1, 1):
            for p in _panel("Panel", sx * 1.25, -2.2, 2.0, 2.4, 0.05, side):
                parts.append(materials.assign(p, wood_x))
        # A moulded sill under the glass.
        parts.append(materials.assign(shapes.box("Sill", (w - 2 * stile + 0.2, 0.08, 0.12), (0, side * 0.2, sill + 0.02), 0.03, 2), wood_x))
    return shapes.join(parts, "GlassDoor")


def window():
    """A 1988 double-hung sash window, 6 x 5 (Data/Props' Window, World/
    PropFactory's casing, sill and muntins), built out from the wall (+Y on
    the wall, the room at -Y): a casing round it, a stool sill on an apron,
    and two six-pane sashes, the lower one in front. The glass, the night and
    any curtain are the game's own. Its box is the game's frame's: 6 x 5,
    the casing on three sides, standing on the stool at the opening's foot,
    an apron under it to the frame's bottom edge."""
    paint = _trim_paint("WindowPaint")
    sash_paint = materials.paint("SashPaint", color=(206, 200, 184), roughness=0.45, grime=0.3)
    w, h = 6.0, 5.0
    cw, cd = 0.45, 0.18
    iw, ih = w - 2 * cw, h - 2 * cw
    foot = -ih / 2  # the opening's foot: the stool's top
    parts = []
    # The casing: a moulded frame round the opening, mitred at the head, its
    # legs cut square on the stool.
    section = _casing_profile(cw, cd)
    # (_casing_profile gives (y, z) with z from the opening's edge (-cw/2) to
    # the outer edge; the frame wants (u in from the outer edge, d out).)
    profile = [(cw / 2 - z, cd / 2 - y) for y, z in section]
    casing = shapes.cut_below(shapes.frame("Casing", w, h, profile), foot)
    parts.append(materials.assign(casing, paint))
    # The stool: a board 6.3 wide, 0.16 thick, 0.5 out, its nose rounded.
    t, out = 0.16, 0.5
    r = t / 2
    stool_profile = [(0.0, foot - t), (0.0, foot)]
    for k in range(0, 7):
        a = math.pi / 2 - math.pi * k / 6
        stool_profile.append((-out + r - r * math.cos(a), foot - r + r * math.sin(a)))
    stool = shapes.moulding("Stool", stool_profile, w + 0.3)
    parts.append(materials.assign(stool, paint))
    # The apron under it, down to the frame's bottom edge.
    apron_h = (foot - t) - (-h / 2)
    apron = shapes.box("Apron", (w - 0.3, 0.1, apron_h), (0, -0.05, -h / 2 + apron_h / 2), 0.03, 2)
    parts.append(materials.assign(apron, paint))
    # The sashes, in the opening (5.1 x 4.1): the upper one behind, the lower
    # in front, meeting at the middle; each three panes across and two down.
    sash_h = ih / 2 + 0.04
    for k, (z_mid, y_out) in enumerate(((ih / 4 - 0.02, 0.065), (-ih / 4 + 0.02, 0.135))):
        rails = []
        sw = iw - 0.04
        rails.append(shapes.box("SashStile", (0.18, 0.07, sash_h), (-sw / 2 + 0.09, -y_out, z_mid), 0.02, 2))
        rails.append(shapes.box("SashStile", (0.18, 0.07, sash_h), (sw / 2 - 0.09, -y_out, z_mid), 0.02, 2))
        top_rail = 0.18 if k == 0 else 0.14  # (the lower sash's top is the meeting rail)
        bottom_rail = 0.14 if k == 0 else 0.26
        rails.append(shapes.box("SashRail", (sw, 0.07, top_rail), (0, -y_out, z_mid + sash_h / 2 - top_rail / 2), 0.02, 2))
        rails.append(shapes.box("SashRail", (sw, 0.07, bottom_rail), (0, -y_out, z_mid - sash_h / 2 + bottom_rail / 2), 0.02, 2))
        # Muntins: two up, one across.
        inner_w = sw - 0.36
        inner_bottom = z_mid - sash_h / 2 + bottom_rail
        inner_top = z_mid + sash_h / 2 - top_rail
        for i in (1, 2):
            x = -inner_w / 2 + inner_w * i / 3
            rails.append(shapes.box("Muntin", (0.07, 0.05, inner_top - inner_bottom), (x, -y_out, (inner_top + inner_bottom) / 2), 0.015, 2))
        rails.append(shapes.box("Muntin", (inner_w, 0.05, 0.07), (0, -y_out, (inner_top + inner_bottom) / 2), 0.015, 2))
        for r in rails:
            parts.append(materials.assign(r, sash_paint))
    # Two brass sash lifts on the lower sash's bottom rail and a lock on the
    # meeting rail.
    brass = materials.brass("SashBrass", color=KNOB_BRASS)
    for sx in (-1, 1):
        lift = shapes.box("Lift", (0.22, 0.06, 0.1), (sx * 1.4, -0.2, foot + 0.16), 0.025, 2)
        parts.append(materials.assign(lift, brass))
    lock = shapes.box("Lock", (0.32, 0.08, 0.06), (0, -0.2, 0.02 + 0.05), 0.025, 2)
    parts.append(materials.assign(lock, brass))
    piece = shapes.join(parts, "Window")
    piece["frame"] = "wall"
    return piece


ARCH = [baseboard, crown, casing, dado_rail, stair_step, knob, door, glass_door, window]
