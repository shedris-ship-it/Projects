"""The golden area's architecture and fixtures (the visual rework V3, the
owner's picks of 2026-10-12: a lit brick fireplace for the living room). Each
piece is built round the origin in Blender's frame: X across, Z up, its front
facing -Y (Roblox's +Z once exported). Sizes match what the game builds
(World/MansionBuilder's railings and staircase, World/LevelBuilder's ceiling
fixtures and sconces), so World/Kit can put them in place.

Sizes are Roblox's { x, y, z } = Blender's (x, z, y).
"""

from . import materials, shapes

WALNUT_DARK, WALNUT_LIGHT = (46, 30, 20), (92, 62, 40)
TRIM_PAINT = (196, 188, 168)  # Config.Trim.Paint


def baluster():
    """A turned baluster in old cream paint, 0.26 x 3.1 x 0.26: a square
    block at the foot and the head (where it meets the rails), a vase between
    (World/MansionBuilder's railing: 0.22 square, the rail's height less 0.1)."""
    paint = materials.paint("BalusterPaint", color=TRIM_PAINT, roughness=0.5, grime=0.3)
    h = 3.1
    foot = shapes.box("Foot", (0.24, 0.24, 0.42), (0, 0, 0.21), 0.02, 2)
    head = shapes.box("Head", (0.24, 0.24, 0.36), (0, 0, h - 0.18), 0.02, 2)
    vase = shapes.lathe(
        "Vase",
        [
            (0.0, 0.42),
            (0.11, 0.42),
            (0.12, 0.47),
            (0.07, 0.56),
            (0.08, 0.68),
            (0.125, 1.05),
            (0.12, 1.25),
            (0.085, 1.55),
            (0.06, 2.1),
            (0.065, 2.3),
            (0.1, 2.42),
            (0.07, 2.52),
            (0.1, 2.62),
            (0.11, h - 0.36),
            (0.0, h - 0.36),
        ],
        steps=14,
    )
    parts = [materials.assign(o, paint) for o in (foot, vase, head)]
    return shapes.join(parts, "Baluster")


def newel():
    """The staircase's newel post in walnut, 0.8 x 3.8 x 0.8: a moulded base,
    a panelled shaft, a cap and a turned ball finial (World/MansionBuilder's
    Newel: 0.8 square, the rail's height plus 0.6)."""
    wood = materials.wood("NewelWalnut", WALNUT_DARK, WALNUT_LIGHT, grain_axis="Z", scale=1.2, roughness=0.42)
    parts = []
    parts.append(shapes.box("Base", (0.8, 0.8, 0.32), (0, 0, 0.16), 0.04, 2))
    parts.append(shapes.box("BaseMould", (0.74, 0.74, 0.1), (0, 0, 0.37), 0.04, 2))
    parts.append(shapes.box("Shaft", (0.62, 0.62, 2.5), (0, 0, 0.42 + 1.25), 0.03, 2))
    # A raised field on each face of the shaft.
    for dx, dy, sx, sy in ((0, -0.31, 0.4, 0.05), (0, 0.31, 0.4, 0.05), (-0.31, 0, 0.05, 0.4), (0.31, 0, 0.05, 0.4)):
        parts.append(shapes.box("Field", (sx, sy, 1.9), (dx, dy, 0.42 + 1.25), 0.02, 2))
    parts.append(shapes.box("Collar", (0.74, 0.74, 0.14), (0, 0, 2.99), 0.04, 2))
    parts.append(shapes.box("Cap", (0.86, 0.86, 0.16), (0, 0, 3.14), 0.05, 3))
    parts.append(
        shapes.lathe(
            "Finial",
            [
                (0.0, 3.22),
                (0.22, 3.22),
                (0.16, 3.3),
                (0.11, 3.36),
                (0.2, 3.5),
                (0.21, 3.58),
                (0.16, 3.69),
                (0.07, 3.76),
                (0.0, 3.8),
            ],
            steps=20,
        )
    )
    return shapes.join([materials.assign(p, wood) for p in parts], "Newel")


def handrail():
    """A moulded walnut handrail, 0.45 x 0.3 in section and 4 studs long
    (World/Kit stretches it to each rail's length: the grain runs along it)."""
    wood = materials.wood("RailWalnut", WALNUT_DARK, WALNUT_LIGHT, grain_axis="Y", scale=1.2, roughness=0.38)
    profile = [
        (-0.12, -0.15),
        (0.12, -0.15),
        (0.14, -0.1),
        (0.2, -0.065),
        (0.225, 0.0),
        (0.212, 0.065),
        (0.165, 0.118),
        (0.085, 0.145),
        (0.0, 0.15),
        (-0.085, 0.145),
        (-0.165, 0.118),
        (-0.212, 0.065),
        (-0.225, 0.0),
        (-0.2, -0.065),
        (-0.14, -0.1),
    ]
    rail = shapes.extrude("Handrail", profile, 4.0)
    return materials.assign(rail, wood)


def fireplace():
    """A 1980s brick fireplace, 7 x 4.42 x 2.4: brick piers and a lintel round
    an opening 2.8 wide and 2.6 high, a sooty firebox, a slate hearth that
    runs out into the room, a walnut mantel shelf on corbels, an iron grate
    with logs whose embers glow (its glow mask: World/Kit, the game's fire
    drives it). Its back stands against the wall (+Y)."""
    brick = materials.brick("FireBrick", scale=2.4)
    sooty = materials.brick("FireboxBrick", scale=2.4, soot=0.82)
    slate = materials.paint("Slate", color=(58, 56, 54), roughness=0.62, grime=0.2)
    wood = materials.wood("MantelWalnut", WALNUT_DARK, WALNUT_LIGHT, grain_axis="X", scale=1.0, roughness=0.4)
    iron = materials.paint("Iron", color=(28, 27, 26), roughness=0.55, grime=0.15)
    bark = materials.wood("Log", (40, 30, 22), (70, 52, 36), grain_axis="X", scale=3.0, roughness=0.9)
    embers = materials.paint("Embers", color=(120, 36, 12), roughness=0.9, grime=0.4)
    embers["glow"] = 1.0
    W, H, D = 6.4, 4.2, 1.0  # the brick surround
    back = 1.2  # its back face, against the wall
    front = back - D
    open_w, open_h = 2.8, 2.6
    pier = (W - open_w) / 2
    hearth_top = 0.25
    parts = []
    for sx in (-1, 1):
        p = shapes.box("Pier", (pier, D, H), (sx * (open_w / 2 + pier / 2), back - D / 2, H / 2), 0.03, 2)
        parts.append(materials.assign(p, brick))
    lintel = shapes.box("Lintel", (open_w, D, H - open_h), (0, back - D / 2, open_h + (H - open_h) / 2), 0.03, 2)
    parts.append(materials.assign(lintel, brick))
    # The firebox: back, sides and roof of sooty brick.
    parts.append(materials.assign(shapes.box("FireBack", (open_w, 0.12, open_h), (0, back - 0.06, open_h / 2), 0.0), sooty))
    for sx in (-1, 1):
        side = shapes.box("FireSide", (0.12, D - 0.12, open_h), (sx * (open_w / 2 - 0.06), back - D / 2 - 0.06, open_h / 2), 0.0)
        parts.append(materials.assign(side, sooty))
    parts.append(materials.assign(shapes.box("FireRoof", (open_w, D, 0.12), (0, back - D / 2, open_h - 0.06), 0.0), sooty))
    # The hearth: one slate slab, out in front and under the firebox.
    depth = back + 1.2
    parts.append(materials.assign(shapes.box("Hearth", (7.0, depth, hearth_top), (0, back - depth / 2, hearth_top / 2), 0.04, 2), slate))
    # The mantel: a moulded shelf on two corbels, a frieze board under it.
    parts.append(materials.assign(shapes.box("Shelf", (7.0, 1.4, 0.22), (0, back - 0.7, H + 0.11), 0.06, 3), wood))
    parts.append(materials.assign(shapes.box("Frieze", (6.6, 0.12, 0.42), (0, front - 0.06, H - 0.21), 0.03, 2), wood))
    for sx in (-1, 1):
        corbel = shapes.box("Corbel", (0.3, 0.32, 0.55), (sx * 3.05, front - 0.16, H - 0.28), 0.04, 2)
        parts.append(materials.assign(corbel, wood))
    # The grate: two iron dogs and three bars, logs across them, embers under.
    gy = back - 0.55
    for sx in (-1, 1):
        dog = shapes.box("Firedog", (0.08, 0.7, 0.5), (sx * 0.85, gy, hearth_top + 0.25), 0.02, 1)
        parts.append(materials.assign(dog, iron))
    for k, dz in enumerate((0.25, 0.32, 0.4)):
        bar = shapes.box("GrateBar", (1.8, 0.05, 0.05), (0, gy - 0.25 + k * 0.25, hearth_top + dz), 0.01, 1)
        parts.append(materials.assign(bar, iron))
    for i, (x, y, z, r, turn) in enumerate(((0, gy - 0.12, 0.62, 0.17, 4), (-0.15, gy + 0.18, 0.6, 0.15, -8), (0.25, gy + 0.02, 0.88, 0.14, 14))):
        log = shapes.roll("Log", 1.9, r, (x, y, hearth_top + z), axis="X", steps=12)
        shapes.turn(log, (0, 0, turn), at=(x, y, hearth_top + z))
        parts.append(materials.assign(log, bark))
    for x, y, s in ((-0.4, gy - 0.05, 0.22), (0.1, gy + 0.08, 0.26), (0.5, gy - 0.1, 0.2), (-0.1, gy - 0.22, 0.18)):
        ember = shapes.box("Ember", (s, s * 0.9, 0.08), (x, y, hearth_top + 0.05), 0.03, 2)
        parts.append(materials.assign(ember, embers))
    return shapes.join(parts, "Fireplace")


def chandelier():
    """A brass chandelier for the grand hall, 3.4 x 3.2 x 3.4: a stem from a
    ceiling cup, a turned body, six curved arms each with a candle and a
    small linen shade (the shades glow: their mask)."""
    brass = materials.brass("ChandelierBrass")
    candle = materials.paint("Candle", color=(232, 224, 204), roughness=0.6, grime=0.1)
    linen = materials.fabric("ChandelierShade", color=(222, 200, 160))
    linen["glow"] = 1.0
    parts = []
    parts.append(shapes.lathe("Cup", [(0.0, 3.2), (0.32, 3.2), (0.3, 3.14), (0.12, 3.02), (0.0, 3.0)], steps=20))
    parts.append(shapes.lathe("Stem", [(0.0, 1.6), (0.05, 1.6), (0.05, 3.02), (0.0, 3.02)], steps=10))
    parts.append(
        shapes.lathe(
            "Body",
            [(0.0, 0.5), (0.1, 0.5), (0.18, 0.7), (0.32, 0.95), (0.3, 1.05), (0.14, 1.2), (0.12, 1.5), (0.18, 1.6), (0.0, 1.66)],
            steps=24,
        )
    )
    import math

    for k in range(6):
        a = k * math.tau / 6
        cx, cy = math.cos(a), math.sin(a)
        # An arm: out from the body and up to a candle cup.
        reach = 1.35
        arm = shapes.roll("Arm", reach, 0.035, (cx * (0.3 + reach / 2), cy * (0.3 + reach / 2), 0.95), axis="X", steps=8)
        shapes.turn(arm, (0, 0, math.degrees(a)), at=(cx * (0.3 + reach / 2), cy * (0.3 + reach / 2), 0.95))
        parts.append(arm)
        tip = (cx * (0.3 + reach), cy * (0.3 + reach))
        parts.append(shapes.roll("Riser", 0.35, 0.035, (tip[0], tip[1], 1.12), axis="Z", steps=8))
        parts.append(shapes.lathe("CandleCup", [(0.0, 1.28), (0.12, 1.28), (0.14, 1.36), (0.0, 1.36)], (tip[0], tip[1], 0), steps=12))
        stick = shapes.roll("Candle", 0.36, 0.045, (tip[0], tip[1], 1.54), axis="Z", steps=8)
        parts.append(materials.assign(stick, candle))
        shade = shapes.lathe(
            "Shade", [(0.0, 1.62), (0.22, 1.62), (0.13, 1.92), (0.0, 1.92)], (tip[0], tip[1], 0), steps=16
        )
        parts.append(materials.assign(shade, linen))
    for p in parts:
        if not p.data.materials:
            materials.assign(p, brass)
    return shapes.join(parts, "Chandelier")


def pendant():
    """The rooms' hanging light, 2.2 x 1.45 x 2.2 (World/LevelBuilder's drum
    pendant: a canopy at the ceiling, a cord, a pleated linen drum and a
    diffuser under it; both glow). Its top touches the ceiling."""
    brass = materials.brass("PendantBrass")
    cord = materials.paint("Cord", color=(30, 28, 26), roughness=0.8, grime=0.0)
    linen = materials.fabric("DrumShade", color=(206, 170, 112))
    linen["glow"] = 1.0
    glass = materials.paint("Diffuser", color=(240, 228, 200), roughness=0.3, grime=0.05)
    glass["glow"] = 1.0
    h = 1.45
    parts = []
    parts.append(materials.assign(shapes.lathe("Canopy", [(0.0, h), (0.3, h), (0.28, h - 0.08), (0.1, h - 0.14), (0.0, h - 0.14)], steps=20), brass))
    parts.append(materials.assign(shapes.roll("Cord", 0.62, 0.025, (0, 0, h - 0.45), axis="Z", steps=6), cord))
    parts.append(materials.assign(shapes.lathe("Fitter", [(0.0, 0.66), (0.14, 0.66), (0.12, 0.76), (0.0, 0.78)], steps=12), brass))
    # The drum: a thin wall, open top and bottom.
    drum_outer = shapes.lathe("Drum", [(1.07, 0.0), (1.1, 0.0), (1.1, 0.7), (1.07, 0.7), (1.07, 0.0)], steps=48)
    parts.append(materials.assign(drum_outer, linen))
    parts.append(materials.assign(shapes.lathe("Diffuser", [(0.0, 0.04), (1.02, 0.04), (1.02, 0.07), (0.0, 0.07)], steps=40), glass))
    for z in (0.0, 0.68):
        parts.append(materials.assign(shapes.lathe("Trim", [(1.07, z), (1.12, z), (1.12, z + 0.03), (1.07, z + 0.03)], steps=48), brass))
    return shapes.join(parts, "Pendant")


def sconce():
    """A brass wall sconce, 0.9 x 1.3 x 1.0: a backplate on the wall (+Y), a
    curved arm, a bulb cup and a small linen shade (it glows)."""
    brass = materials.brass("SconceBrass")
    linen = materials.fabric("SconceShade", color=(220, 190, 140))
    linen["glow"] = 1.0
    back = 0.5
    parts = []
    parts.append(materials.assign(shapes.box("Plate", (0.42, 0.06, 0.8), (0, back - 0.03, 0.55), 0.03, 3), brass))
    parts.append(materials.assign(shapes.roll("Boss", 0.12, 0.09, (0, back - 0.12, 0.45), axis="Y", steps=12), brass))
    arm = shapes.roll("Arm", 0.62, 0.035, (0, back - 0.37, 0.45), axis="Y", steps=8)
    parts.append(materials.assign(arm, brass))
    parts.append(materials.assign(shapes.roll("Riser", 0.25, 0.035, (0, -0.0, 0.57), axis="Z", steps=8), brass))
    parts.append(materials.assign(shapes.lathe("Cup", [(0.0, 0.68), (0.1, 0.68), (0.12, 0.78), (0.0, 0.78)], (0, 0, 0), steps=12), brass))
    shade = shapes.lathe("Shade", [(0.0, 0.62), (0.45, 0.62), (0.3, 1.3), (0.0, 1.3)], (0, 0, 0), steps=24)
    parts.append(materials.assign(shade, linen))
    return shapes.join(parts, "Sconce")


GOLDEN2 = [baluster, newel, handrail, fireplace, chandelier, pendant, sconce]
