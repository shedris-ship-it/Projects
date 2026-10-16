"""The lobby's mall, its third batch (docs/plans/lobby-rework.md, LB1b, kit.py
mall3): the garage, the vault's frame, the escalators and the neon letters.

- The garage, laid out by hand as the shops were (Data/Mall has where each
  stands): the investigators' camp down the west wall (two cots, the camp
  table with its coffee, the whiteboard, the case board with its photos and
  the house's plan, the desk, its chair and the CB radio, the evidence
  boxes) and the workshop down the east (the generator and its diesel, the
  cable reel, the power box, the car bits pegboard, the payphone, the
  tyres). The cars and the workbench are the house's own. The strip lights
  and the work lamps; the roll-up shutter on the garage door, also every
  dead shop's.
- The vault: an arched lattice rib for each of its eight, a lunette with a
  fan light for each end.
- The dead mall's stopped escalators, the pair.
- The shops' neon: real tubes, bent from a stroke alphabet drawn here (no
  font files), each shop's in its own style, and the raceway behind them.
  The tubes are drawn Neon in the game (World/MallBuilder), so they aren't
  baked.

Each piece is built in the game's frame (things.G), its front +z, round the
middle of the block it dresses or on the floor point of the group it stands
for (Data/Mall `KitGroups`); kit.py's `at` is where its box sits from there.
"""

import math
import random

import bmesh
import bpy
import numpy as np
from mathutils import Vector, geometry

from . import materials, prints, shapes
from .atmosphere import _plastic, _surface
from .fittings import _iron, _oak
from .house import _chrome
from .mall import _atlas, _bronze, _card, _plaster, _side_prism
from .mall2 import _flat, _formica, _glass, _laminate, _named, _picture_mat, _place, _steel, _vinyl
from .things import G, S, _box, _lathe, _new, _sphere, _torus, _tube


# Materials -------------------------------------------------------------------


def _olive(name, color=(78, 84, 58)):
    """Army olive paint, chipped and oily: the generator, the cots' frames."""
    return materials.paint(name, color=color, roughness=0.6, grime=0.55)


def _canvas(name, color=(110, 104, 78)):
    return materials.fabric(name, color=color, roughness=0.95)


def _rubber(name):
    return materials.paint(name, color=(24, 23, 22), roughness=0.9, grime=0.15)


def _card_brown(name, color=(178, 150, 106)):
    return materials.paint(name, color=color, roughness=0.92, grime=0.3)


def _cork(name):
    """Cork board: a warm brown with fine dark crumbs."""
    mat = bpy.data.materials.new(name)
    n = materials.Nodes(mat)
    m = n.mapping(scale=(1.0, 1.0, 1.0))
    crumb = n.add("ShaderNodeTexVoronoi")
    crumb.inputs["Scale"].default_value = 70.0
    n.link(m.outputs["Vector"], crumb.inputs["Vector"])
    ramp = n.ramp(crumb.outputs["Distance"], [(0.0, materials._srgb((84, 54, 30))), (0.25, materials._srgb((150, 104, 62))), (1.0, materials._srgb((176, 128, 80)))])
    n.link(ramp.outputs["Color"], n.bsdf.inputs["Base Color"])
    n.bsdf.inputs["Roughness"].default_value = 0.95
    n.bump(crumb.outputs["Distance"], 0.3)
    return mat


def _rust_steel(name, color=(96, 98, 96)):
    """Galvanised sheet gone dull and streaked: the roll-up shutters."""
    return materials.paint(name, color=color, roughness=0.55, grime=0.6)


# Shapes ----------------------------------------------------------------------


def _cyl_x(name, radius, length, at, steps=16):
    """A cylinder lying along the game's x, its middle at `at`."""
    c = _lathe(name, [(0.0, -length / 2), (radius, -length / 2), (radius, length / 2), (0.0, length / 2)], (0, 0, 0), steps)
    return shapes.turn(c, (0, 90, 0), G(*at))


def _cyl_z(name, radius, length, at, steps=16):
    """A cylinder lying along the game's z (toward the front)."""
    c = _lathe(name, [(0.0, -length / 2), (radius, -length / 2), (radius, length / 2), (0.0, length / 2)], (0, 0, 0), steps)
    return shapes.turn(c, (90, 0, 0), G(*at))


def _rot_x(p, degrees, about=(0.0, 0.0, 0.0)):
    """A point in the game's frame turned about the game's x through `about`,
    as Roblox's CFrame.Angles(rx, 0, 0)."""
    a = math.radians(degrees)
    x, y, z = p[0] - about[0], p[1] - about[1], p[2] - about[2]
    return (x + about[0], y * math.cos(a) - z * math.sin(a) + about[1], y * math.sin(a) + z * math.cos(a) + about[2])


def _box_pts(name, size, at, turn=None):
    """A box from its eight corners in the game's frame, each turned by
    `turn` (a function of a point) if given: a lamp head tipped down."""
    sx, sy, sz = size[0] / 2, size[1] / 2, size[2] / 2
    corners = [(x, y, z) for x in (-sx, sx) for y in (-sy, sy) for z in (-sz, sz)]
    pts = []
    for c in corners:
        p = (c[0] + at[0], c[1] + at[1], c[2] + at[2])
        pts.append(turn(p) if turn else p)
    faces = [(0, 1, 3, 2), (4, 6, 7, 5), (0, 4, 5, 1), (2, 3, 7, 6), (0, 2, 6, 4), (1, 5, 7, 3)]
    bm = bmesh.new()
    vs = [bm.verts.new(G(*p)) for p in pts]
    for f in faces:
        bm.faces.new([vs[i] for i in f])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return _new(name, bm)


# Pictures ----------------------------------------------------------------------


def snapshot(kind, seed):
    """A faded 4 x 3 snapshot pinned to the case board: the house at dusk, or
    a figure at a window nobody should be at."""
    rng = np.random.default_rng(seed)
    img = prints.blank(150, 200, (244, 240, 230))
    pic = prints.blank(124, 176, (70, 72, 88))
    if kind == "house":
        prints.rect(pic, 0, 80, 176, 124, (40, 46, 36))
        prints.rect(pic, 40, 40, 136, 92, (30, 30, 34))
        prints.stroke(pic, [(30, 44), (88, 14), (146, 44)], 8, (30, 30, 34))
        prints.rect(pic, 60, 56, 74, 70, (230, 190, 100))
        prints.rect(pic, 104, 56, 118, 70, (20, 20, 24))
    else:
        prints.rect(pic, 20, 10, 156, 114, (36, 38, 46))
        prints.rect(pic, 30, 18, 146, 106, (90, 96, 110))
        prints.rect(pic, 86, 18, 90, 106, (36, 38, 46))
        prints.rect(pic, 30, 60, 146, 64, (36, 38, 46))
        prints.disc(pic, 116, 44, 9, (226, 222, 210))
        prints.rect(pic, 106, 54, 126, 100, (14, 14, 16))
    pic = prints.blur(pic, 1)
    img[13:137, 12:188] = pic
    prints.age(img, rng, 0.14)
    return img


def blueprint():
    """The house's plan, pinned up: a blueprint of rooms and a red ring."""
    img = prints.blank(180, 240, (40, 70, 140))
    ink = (210, 226, 246)
    rooms = [(20, 20, 120, 90), (120, 20, 220, 70), (120, 70, 220, 160), (20, 90, 120, 160)]
    for x0, y0, x1, y1 in rooms:
        for (a, b, c, d) in ((x0, y0, x1, y0 + 2), (x0, y1 - 2, x1, y1), (x0, y0, x0 + 2, y1), (x1 - 2, y0, x1, y1)):
            prints.rect(img, a, b, c, d, ink)
    for k in range(8):
        prints.rect(img, 30 + k * 10, 150 - k * 6, 40 + k * 10, 152 - k * 6, ink)
    prints.ring(img, 170, 115, 26, 4, (220, 40, 34))
    prints.text(img, "HALFWAY HOUSE", 24, 4, 10, ink)
    return prints.age(img, np.random.default_rng(3), 0.1, yellow=(0.98, 0.98, 1.0))


def whiteboard_face():
    """The whiteboard's face, wiped many times: grey ghosts of old writing
    (the game writes TONIGHT on it, Data/Mall's sign)."""
    rng = np.random.default_rng(12)
    img = prints.blank(256, 448, (236, 238, 236))
    for k in range(6):
        y = 40 + k * 34
        prints.scribble(img, 30, y, rng.uniform(220, 410), 18, rng, (196, 200, 206), 2.2, 0.6)
    prints.stroke(img, [(300, 200), (420, 160)], 3, (190, 196, 206), 0.6)
    return img


def power_label():
    img = prints.blank(160, 220, (240, 200, 40))
    prints.stroke(img, [(110, 20), (60, 90), (110, 90), (70, 150)], 10, (20, 20, 20))
    return img


def box_label(text):
    img = prints.blank(80, 200, (236, 230, 214))
    prints.text(img, text, 12, 24, 30, (40, 34, 30), bold=0.6)
    return prints.age(img, np.random.default_rng(len(text)), 0.08)


def phone_card():
    img = prints.blank(120, 160, (226, 222, 210))
    prints.text(img, "LOCAL", 16, 12, 16, (30, 30, 34))
    prints.text(img, "CALLS 25", 16, 40, 16, (30, 30, 34))
    prints.text(img, "DIAL 0", 16, 68, 16, (180, 30, 30))
    return img


def road_map():
    rng = np.random.default_rng(31)
    img = prints.blank(200, 280, (226, 222, 196))
    for _ in range(20):
        a = (rng.uniform(0, 280), rng.uniform(0, 200))
        b = (a[0] + rng.uniform(-120, 120), a[1] + rng.uniform(-80, 80))
        prints.stroke(img, [a, b], rng.choice([2, 3, 5]), [(200, 60, 40), (90, 90, 90), (230, 180, 40)][int(rng.integers(0, 3))])
    prints.ring(img, 150, 96, 14, 3, (200, 30, 30))
    return prints.age(img, rng, 0.12)


# The garage: the workshop ---------------------------------------------------------


def generator():
    """The investigators' generator (Data/Mall group, on the floor where the
    `Generator` block stands, 8 x 5 x 5): a diesel set on its skid in army
    olive, the radiator's grille at the east end, the control panel on the
    west face (dials, the start key, a breaker), a muffler on top where the
    exhaust goes up through the roof, the fuel line, oil on the skid."""
    olive = _olive("GenOlive")
    dark = _iron("GenDark", (34, 34, 32))
    steel = _steel("GenSteel", 0.5)
    black = _plastic("GenBlack", (20, 20, 22))
    dial = materials.paint("GenDial", color=(226, 222, 206), roughness=0.4, grime=0.1)
    red = _plastic("GenRed", (190, 30, 30))
    L, W = 8.0, 5.0
    parts = [
        materials.assign(_box("Skid", (L + 0.2, 0.5, W), (0, 0.25, 0), 0.03, 1), dark),
        materials.assign(_box("Tank", (L - 0.4, 0.8, W - 0.4), (0, 0.9, 0), 0.05, 2), olive),
        materials.assign(_box("Body", (L - 1.6, 3.4, W - 0.8), (0.3, 3.0, 0), 0.12, 3), olive),
        materials.assign(_box("Roof", (L - 1.4, 0.25, W - 0.6), (0.3, 4.82, 0), 0.06, 2), olive),
    ]
    # Louvres down both long sides.
    for sz in (-1, 1):
        for k in range(7):
            parts.append(materials.assign(_box("Louvre", (0.7, 0.08, 0.06), (-1.8 + k * 0.75, 3.4, sz * (W / 2 - 0.37)), 0.02, 1), dark))
            parts.append(materials.assign(_box("Louvre", (0.7, 0.08, 0.06), (-1.8 + k * 0.75, 2.6, sz * (W / 2 - 0.37)), 0.02, 1), dark))
    # The radiator's grille at the east end.
    parts.append(materials.assign(_box("Radiator", (0.3, 3.0, W - 1.0), (L / 2 - 0.45, 3.0, 0), 0.04, 2), dark))
    for k in range(9):
        parts.append(materials.assign(_box("Fin", (0.1, 2.8, 0.06), (L / 2 - 0.28, 3.0, -1.6 + k * 0.4), 0.0, 1), steel))
    # The control panel on the west face, where the old block's was.
    px = -L / 2 + 0.05
    parts.append(materials.assign(_box("Panel", (0.3, 2.0, 2.5), (px, 3.5, 0), 0.04, 2), olive))
    for k, z in enumerate((-0.7, 0.0, 0.7)):
        d = _lathe("Dial", [(0.0, 0.0), (0.24, 0.0), (0.26, 0.06), (0.0, 0.08)], (0, 0, 0), 16)
        parts.append(materials.assign(_place(d, (0, -90, 0), (px - 0.16, 4.0, z)), dial))
    parts.append(materials.assign(_box("Key", (0.06, 0.2, 0.08), (px - 0.18, 3.2, -0.6), 0.02, 1), steel))
    parts.append(materials.assign(_box("Breaker", (0.12, 0.45, 0.3), (px - 0.2, 3.1, 0.4), 0.03, 2), black))
    parts.append(materials.assign(_box("Stop", (0.1, 0.25, 0.25), (px - 0.2, 2.7, 0.8), 0.04, 2), red))
    # The muffler on top, its pipe up to where the exhaust stack begins.
    parts.append(materials.assign(_cyl_x("Muffler", 0.45, 2.4, (2.0, 5.2, -1.0)), dark))
    parts.append(materials.assign(_tube("Stack", [(2.0, 5.2, -1.0), (2.0, 5.0, -1.0)], 0.45, 12), dark))
    # The fuel line from the tank, and an oil stain on the skid.
    parts.append(materials.assign(_tube("FuelLine", [(-L / 2 + 0.6, 0.9, W / 2 - 0.2), (-L / 2 + 0.3, 0.6, W / 2 + 0.1), (-L / 2 - 0.1, 0.1, W / 2 + 0.1)], 0.06, 6), black))
    parts.append(materials.assign(_box("Oil", (2.0, 0.01, 1.6), (1.0, 0.505, 1.2), 0.0, 1), black))
    return shapes.join(parts, "Generator")


def jerry_can():
    """A jerry can (Data/Mall `FuelCan`, 1.2 x 1.6 x 0.8): pressed steel in red,
    the X stamped in its sides, three handles across the top, the spout cap."""
    red = materials.paint("CanRed", color=(160, 34, 30), roughness=0.5, grime=0.45)
    W, H, D = 1.2, 1.6, 0.8
    parts = [materials.assign(_box("Body", (W - 0.06, H - 0.2, D), (0, -0.1, 0), 0.06, 3), red)]
    for sz in (-1, 1):
        for sx in (-1, 1):
            parts.append(materials.assign(_place(shapes.box("X", S(0.08, 1.4, 0.04), (0, 0, 0), 0.02, 1), (0, sx * 36, 0), (0, -0.1, sz * (D / 2 + 0.005))), red))
    for k in (-0.35, 0.0, 0.35):
        parts.append(materials.assign(_tube("Handle", [(k - 0.08, H / 2 - 0.2, 0.0), (k - 0.08, H / 2, 0.0), (k + 0.08, H / 2, 0.0), (k + 0.08, H / 2 - 0.2, 0.0)], 0.04, 6), red))
    parts.append(materials.assign(_lathe("Spout", [(0.0, 0.0), (0.12, 0.0), (0.12, 0.16), (0.0, 0.18)], (W / 2 - 0.25, H / 2 - 0.2, 0.0), 12), red))
    return shapes.join(parts, "JerryCan")


def _drum(name, pump):
    """A 55-gallon drum of diesel (1.9 across, 2.9 tall: Data/Mall `OilDrum`):
    blue steel, two rolling hoops, the lid's bungs; `pump`, a hand pump in
    the big bung, its hose coiled over."""
    blue = materials.paint(name + "Blue", color=(40, 70, 120), roughness=0.5, grime=0.5)
    steel = _steel(name + "Steel", 0.5)
    black = _plastic(name + "Hose", (20, 20, 22))
    R, H = 0.95, 2.9
    b, t = -H / 2, H / 2
    parts = [
        materials.assign(_lathe("Drum", [(0.0, b), (R - 0.04, b), (R, b + 0.06), (R, t - 0.06), (R - 0.04, t), (0.0, t)], steps=32), blue),
        materials.assign(_lathe("Chime", [(R - 0.02, t - 0.02), (R + 0.02, t - 0.02), (R + 0.02, t + 0.06), (R - 0.06, t + 0.06), (R - 0.06, t - 0.02)], steps=32), blue),
    ]
    for y in (b + H / 3, b + 2 * H / 3):
        parts.append(materials.assign(_lathe("Hoop", [(R - 0.02, y - 0.06), (R + 0.05, y - 0.03), (R + 0.05, y + 0.03), (R - 0.02, y + 0.06)], steps=32), blue))
    for x, z, r in ((0.45, 0.2, 0.12), (-0.5, -0.3, 0.08)):
        parts.append(materials.assign(_lathe("Bung", [(0.0, t), (r, t), (r, t + 0.05), (0.0, t + 0.05)], (x, 0, z), 12), steel))
    if pump:
        px, pz = 0.45, 0.2
        parts.append(materials.assign(_tube("PumpTube", [(px, t, pz), (px, t + 0.9, pz)], 0.07, 8), steel))
        parts.append(materials.assign(_box("PumpBody", (0.35, 0.35, 0.35), (px, t + 1.0, pz), 0.05, 2), steel))
        parts.append(materials.assign(_tube("Lever", [(px, t + 1.1, pz), (px - 0.5, t + 1.25, pz)], 0.04, 6), steel))
        parts.append(materials.assign(_tube("Spout", [(px + 0.17, t + 1.0, pz), (px + 0.45, t + 0.95, pz), (px + 0.5, t + 0.75, pz)], 0.05, 6), steel))
        hose = [(px, t + 1.0, pz + 0.17)]
        for k in range(14):
            a = k * 0.7
            hose.append((px - 0.2 + 0.25 * math.cos(a), t + 0.15 + 0.03 * k, pz + 0.2 + 0.25 * math.sin(a)))
        parts.append(materials.assign(_tube("Hose", hose, 0.04, 6), black))
    return shapes.join(parts, name)


def oil_drum():
    return _drum("OilDrum", False)


def oil_drum_pump():
    return _drum("OilDrumPump", True)


def cable_reel():
    """A wooden cable drum (Data/Mall `CableReel`), modelled upright, 1.4 tall,
    3 across (the block's turn lays it on its rim): plywood flanges bolted
    through, the drum wound with the generator's orange cable, its tail."""
    ply = materials.wood("ReelPly", (120, 92, 58), (170, 136, 92), grain_axis="X", scale=2.0, roughness=0.8)
    orange = _plastic("ReelCable", (226, 110, 26))
    steel = _steel("ReelBolt", 0.5)
    R, H = 1.5, 1.4
    parts = []
    for sy in (-1, 1):
        parts.append(materials.assign(_lathe("Flange", [(0.0, sy * H / 2 - 0.08), (R, sy * H / 2 - 0.08), (R, sy * H / 2 + 0.08), (0.0, sy * H / 2 + 0.08)], steps=32), ply))
        for k in range(6):
            a = math.tau * k / 6
            parts.append(materials.assign(_sphere("Bolt", 0.05, (0.45 * math.cos(a), sy * (H / 2 + 0.08), 0.45 * math.sin(a)), 8, 4), steel))
    parts.append(materials.assign(_lathe("Wound", [(0.0, -H / 2 + 0.08), (1.05, -H / 2 + 0.08), (1.1, -H / 2 + 0.2), (1.1, H / 2 - 0.2), (1.05, H / 2 - 0.08), (0.0, H / 2 - 0.08)], steps=32), orange))
    for k in range(5):
        y = -H / 2 + 0.2 + k * 0.25
        parts.append(materials.assign(_lathe("Turn", [(1.08, y - 0.06), (1.13, y), (1.08, y + 0.06)], steps=32), orange))
    parts.append(materials.assign(_tube("Tail", [(1.1, 0.0, 0.0), (1.3, 0.2, 0.4), (1.45, 0.5, 0.9)], 0.07, 8), orange))
    return shapes.join(parts, "CableReel")


def mall_power_box():
    """The power box on the garage's north wall (Data/Mall `PowerBox`, 3 x 4 x
    1): a grey steel distribution board the investigators wired the mall's
    circuits back into, its big switch thrown, a lightning label, conduit
    up the wall, their orange cables out of the bottom. Its front is +z."""
    grey = materials.paint("PBGrey", color=(126, 130, 128), roughness=0.5, grime=0.5)
    dark = _iron("PBDark", (40, 40, 40))
    orange = _plastic("PBCable", (226, 110, 26))
    pixels, (label,) = _atlas([power_label()])
    picture = _picture_mat("PBLabel", pixels, 0.12, roughness=0.5)
    W, H, D = 3.0, 4.0, 1.0
    parts = [
        materials.assign(_box("Box", (W - 0.2, H - 0.4, D - 0.2), (0, 0, -0.1), 0.04, 2), grey),
        materials.assign(_box("Door", (W - 0.3, H - 0.5, 0.06), (0, 0, D / 2 - 0.17), 0.03, 2), grey),
        _card("Label", picture, 0.55, 0.4, (0.8, 1.2, D / 2 - 0.135), 1, label),
        materials.assign(_box("Handle", (0.12, 0.5, 0.12), (1.1, 0.0, D / 2 - 0.08), 0.04, 2), dark),
        materials.assign(_box("SwitchPlate", (0.6, 1.0, 0.1), (W / 2 + 0.0, 0.2, -0.1), 0.03, 2), dark),
        materials.assign(_tube("Lever", [(W / 2 + 0.05, 0.2, -0.1), (W / 2 + 0.25, 0.65, -0.1)], 0.05, 6), dark),
        materials.assign(_tube("Conduit", [(-0.8, H / 2 - 0.2, -0.3), (-0.8, H / 2, -0.3)], 0.12, 8), grey),
        materials.assign(_tube("Conduit", [(0.6, H / 2 - 0.2, -0.3), (0.6, H / 2, -0.3)], 0.12, 8), grey),
    ]
    for x in (-0.9, -0.3, 0.3):
        parts.append(materials.assign(_tube("Cable", [(x, -H / 2 + 0.2, 0.0), (x, -H / 2 + 0.0, 0.1), (x + 0.1, -H / 2 + 0.0, 0.4)], 0.07, 6), orange))
    return shapes.join(parts, "MallPowerBox")


def car_pegboard():
    """The car bits pegboard on the garage's east wall (14 x 6 x 0.4; LB4's
    customisation hangs here later): brown pegboard in a pine frame, hubcaps,
    a steering wheel, fuzzy dice, a fan belt, wrenches, an air freshener."""
    board = materials.paint("CPBoard", color=(140, 104, 70), roughness=0.85, grime=0.3)
    pine = _oak("CPPine", axis="X")
    chrome = _chrome("CPChrome")
    black = _rubber("CPRubber")
    dice = materials.fabric("CPDice", color=(220, 220, 214))
    green = _plastic("CPTree", (40, 140, 60))
    W, H = 14.0, 6.0
    parts = [materials.assign(_box("Board", (W - 0.3, H - 0.3, 0.12), (0, 0, -0.14), 0.0, 1), board)]
    for sy in (-1, 1):
        parts.append(materials.assign(_box("Frame", (W, 0.15, 0.3), (0, sy * (H / 2 - 0.075), -0.05), 0.03, 2), pine))
    for sx in (-1, 1):
        parts.append(materials.assign(_box("Frame", (0.15, H - 0.3, 0.3), (sx * (W / 2 - 0.075), 0, -0.05), 0.03, 2), pine))
    for k, x in enumerate((-5.0, -3.2)):
        cap = _lathe("Hubcap", [(0.0, 0.0), (0.75, 0.0), (0.72, 0.06), (0.4, 0.14), (0.15, 0.18), (0.0, 0.2)], (0, 0, 0), 24)
        parts.append(materials.assign(_place(cap, (90, 0, 0), (x, 1.3 - k * 0.1, -0.06)), chrome))
    wheel = _torus("Wheel", 0.75, 0.07, 32, 8)
    parts.append(materials.assign(_place(wheel, (90, 0, 0), (-0.8, 1.1, 0.0)), black))
    for a in (0, 120, 240):
        r = math.radians(a + 90)
        parts.append(materials.assign(_tube("Spoke", [(-0.8, 1.1, 0.0), (-0.8 + 0.72 * math.cos(r), 1.1 + 0.72 * math.sin(r), 0.0)], 0.05, 6), black))
    for dx in (-0.12, 0.18):
        parts.append(materials.assign(_box("Die", (0.3, 0.3, 0.3), (1.6 + dx, 0.8 - abs(dx), 0.08), 0.08, 3), dice))
    parts.append(materials.assign(_tube("String", [(1.65, 1.6, 0.05), (1.55, 0.95, 0.08)], 0.015, 4), black))
    belt = _torus("Belt", 0.55, 0.05, 24, 4)
    belt.scale = (1.0, 1.0, 0.5)
    parts.append(materials.assign(_place(belt, (90, 0, 0), (3.2, 1.3, 0.0)), black))
    for k in range(5):
        x = 4.6 + k * 0.38
        parts.append(materials.assign(_box("Wrench", (0.1, 0.9 + k * 0.1, 0.04), (x, -1.0, 0.0), 0.02, 1), chrome))
    tree = [(0.0, 0.5), (0.3, 0.1), (0.15, 0.1), (0.35, -0.25), (0.05, -0.25), (0.05, -0.45), (-0.05, -0.45), (-0.05, -0.25), (-0.35, -0.25), (-0.15, 0.1), (-0.3, 0.1)]
    parts.append(materials.assign(_place(_flat("Tree", tree, -0.02, 0.02), (0, 0, 0), (-3.0, -1.1, 0.05)), green))
    for k in range(18):
        parts.append(materials.assign(_tube("Hook", [(-6 + k * 0.7, -2.2, -0.08), (-6 + k * 0.7, -2.2, 0.15)], 0.02, 4, caps=False), chrome))
    return shapes.join(parts, "CarPegboard")


def payphone():
    """The payphone on the garage's east wall (2 x 3 x 1.2; Roblox's
    invite-a-friend, LB2): a steel phone in its steel hood, the handset on
    its armoured cord, the keypad, the coin slot and return, the rate card.
    Its front is +z."""
    steel = _steel("PPSteel", 0.4)
    black = _plastic("PPBlack", (22, 22, 24))
    chrome = _chrome("PPChrome")
    pixels, (card,) = _atlas([phone_card()])
    picture = _picture_mat("PPCard", pixels, 0.12, roughness=0.4)
    W, H, D = 2.0, 3.0, 1.2
    b = -H / 2
    parts = [
        # The hood: back, two sides, a top.
        materials.assign(_box("HoodBack", (W - 0.16, H - 0.08, 0.08), (0, -0.04, -D / 2 + 0.04), 0.02, 1), steel),
        materials.assign(_box("HoodTop", (W, 0.08, D), (0, H / 2 - 0.04, 0), 0.02, 1), steel),
        materials.assign(_box("Shelf", (W - 0.2, 0.08, 0.5), (0, b + 0.5, -D / 2 + 0.3), 0.02, 1), steel),
        materials.assign(_box("Phone", (0.8, 1.6, 0.4), (0, 0.15, -D / 2 + 0.28), 0.06, 2), steel),
        materials.assign(_box("Handset", (0.22, 0.9, 0.2), (-0.32, 0.3, -D / 2 + 0.58), 0.08, 2), black),
        materials.assign(_box("CoinSlot", (0.2, 0.06, 0.04), (0.25, 0.8, -D / 2 + 0.49), 0.0, 1), black),
        materials.assign(_box("Return", (0.3, 0.2, 0.1), (0.25, -0.5, -D / 2 + 0.5), 0.03, 1), chrome),
        _card("Card", picture, 0.5, 0.36, (0.05, -0.05, -D / 2 + 0.485), 1, card),
    ]
    for sx in (-1, 1):
        parts.append(materials.assign(_box("HoodSide", (0.08, H - 0.08, D), (sx * (W / 2 - 0.04), -0.04, 0), 0.02, 1), steel))
    for r in range(4):
        for c in range(3):
            parts.append(materials.assign(_box("Key", (0.1, 0.08, 0.04), (0.12 + c * 0.13, 0.45 - r * 0.12, -D / 2 + 0.49), 0.02, 1), chrome))
    cord = [(-0.32, -0.15, -D / 2 + 0.58)]
    for k in range(10):
        cord.append((-0.32 + 0.06 * math.cos(k * 1.4), -0.2 - k * 0.04, -D / 2 + 0.55 + 0.06 * math.sin(k * 1.4)))
    cord.append((-0.2, -0.45, -D / 2 + 0.48))
    parts.append(materials.assign(_tube("Cord", cord, 0.025, 6), chrome))
    return shapes.join(parts, "Payphone")


def tyre_stack():
    """Four worn tyres stacked against the garage's east wall (2.4 across, 3.2
    tall: Data/Mall `TyreStack`). Upright."""
    rubber = _rubber("TyreRubber")
    H = 3.2
    parts = []
    rng = random.Random(9)
    for k in range(4):
        y = -H / 2 + 0.4 + k * 0.8
        t = _torus("Tyre", 0.85, 0.33, 32, 10)
        t.scale = (1.0, 1.0, 1.15)
        t.location = G(rng.uniform(-0.04, 0.04), y, rng.uniform(-0.04, 0.04))
        parts.append(materials.assign(t, rubber))
    return shapes.join(parts, "TyreStack")


# The garage: the camp -------------------------------------------------------------


def _cot(name, bag):
    """An army cot on the floor (7 long, the canvas 1.6 up): olive canvas on
    a timber frame, folding X legs; `bag`, a rumpled sleeping bag and a
    pillow on it; otherwise a folded grey blanket and a pillow. Long along x,
    its floor at y = 0."""
    canvas = _canvas(name + "Canvas")
    wood = _oak(name + "Frame", axis="X", roughness=0.6)
    dark = _iron(name + "Leg", (50, 48, 44))
    L, D, top = 7.0, 2.8, 1.6
    parts = [
        materials.assign(shapes.cushion("Canvas", S(L - 0.4, 0.08, D - 0.3), G(0, top - 0.08, 0), puff=-0.06, levels=2, roundness=0.1), canvas),
    ]
    for sz in (-1, 1):
        parts.append(materials.assign(_cyl_x("Rail", 0.07, L, (0, top - 0.06, sz * (D / 2 - 0.1))), wood))
    for x in (-L / 2 + 0.5, 0.0, L / 2 - 0.5):
        for sz in (-1, 1):
            parts.append(materials.assign(_tube("Leg", [(x - 0.25, 0.05, sz * (D / 2 - 0.1)), (x + 0.25, top - 0.1, -sz * (D / 2 - 0.3))], 0.045, 6), dark))
    pillow = materials.fabric(name + "Pillow", color=(214, 208, 192))
    parts.append(materials.assign(shapes.cushion("Pillow", S(1.3, 0.35, 2.0), G(-L / 2 + 1.0, top + 0.12, 0), puff=0.12, levels=2, roundness=0.6), pillow))
    if bag:
        sb = materials.fabric(name + "Bag", color=(70, 82, 54))
        lining = materials.fabric(name + "Lining", color=(150, 40, 36))
        parts.append(materials.assign(shapes.cushion("Bag", S(5.4, 0.45, 2.2), G(0.5, top + 0.18, 0), puff=0.18, levels=2, roundness=0.5), sb))
        parts.append(materials.assign(shapes.cushion("Flap", S(1.6, 0.18, 2.1), G(-1.6, top + 0.42, 0.05), puff=0.08, levels=2, roundness=0.4), lining))
    else:
        blanket = materials.fabric(name + "Blanket", color=(110, 110, 108))
        parts.append(materials.assign(shapes.cushion("Blanket", S(2.0, 0.5, 1.8), G(2.2, top + 0.2, 0), puff=0.06, levels=2, roundness=0.3), blanket))
    return shapes.join(parts, name)


def cot_bag():
    return _cot("CotBag", True)


def cot_blanket():
    return _cot("CotBlanket", False)


def camp_table():
    """Their camp table (6 x 3, its top 3.1 up, on the floor): a folding table
    in brown laminate on steel legs; a camp stove with the percolator on it,
    two thermoses, three mugs, a road map with a ring on it. Long along x,
    its floor at y = 0."""
    top = _laminate("CTTop", (130, 96, 64))
    steel = _steel("CTSteel", 0.5)
    green = _plastic("CTStove", (40, 90, 50))
    perc = _chrome("CTPerc")
    red = _plastic("CTRedFlask", (170, 40, 36))
    blue = _plastic("CTBlueFlask", (40, 70, 140))
    mug = _plastic("CTMug", (226, 222, 210))
    pixels, (map_rect,) = _atlas([road_map()])
    picture = _picture_mat("CTMap", pixels, 0.2, roughness=0.8)
    L, D, h = 6.0, 3.0, 3.1
    parts = [materials.assign(_box("Top", (L, 0.12, D), (0, h - 0.06, 0), 0.03, 2), top)]
    for sx in (-1, 1):
        x = sx * (L / 2 - 0.5)
        parts.append(materials.assign(_tube("Leg", [(x - 0.4, 0.04, -D / 2 + 0.3), (x + 0.4, h - 0.12, D / 2 - 0.3)], 0.05, 6), steel))
        parts.append(materials.assign(_tube("Leg", [(x - 0.4, 0.04, D / 2 - 0.3), (x + 0.4, h - 0.12, -D / 2 + 0.3)], 0.05, 6), steel))
    s = h
    parts.append(materials.assign(_box("Stove", (1.2, 0.3, 0.8), (-1.0, s + 0.15, -0.2), 0.04, 2), green))
    parts.append(materials.assign(_lathe("Perc", [(0.0, s + 0.3), (0.28, s + 0.3), (0.3, s + 0.9), (0.22, s + 1.0), (0.12, s + 1.1), (0.0, s + 1.12)], (-1.0, 0, -0.2), 18), perc))
    parts.append(materials.assign(_tube("PercHandle", [(-0.72, s + 0.9, -0.2), (-0.55, s + 0.85, -0.2), (-0.55, s + 0.45, -0.2), (-0.72, s + 0.4, -0.2)], 0.04, 6), _plastic("CTHandle", (20, 20, 20))))
    for (x, z, mat) in ((1.0, -0.5, red), (1.6, 0.4, blue)):
        parts.append(materials.assign(_lathe("Flask", [(0.0, s), (0.22, s), (0.22, s + 1.1), (0.17, s + 1.2), (0.17, s + 1.32), (0.0, s + 1.32)], (x, 0, z), 16), mat))
    for (x, z) in ((0.2, 0.7), (-0.2, 0.9), (2.4, -0.6)):
        parts.append(materials.assign(_lathe("Mug", [(0.0, s), (0.16, s), (0.17, s + 0.32), (0.0, s + 0.32)], (x, 0, z), 12), mug))
    parts.append(_place(materials.assign(_surface("Map", [(-0.9, 0, 0.6), (0.9, 0, 0.6), (0.9, 0, -0.6), (-0.9, 0, -0.6)], [(0, 1, 2, 3)], [(map_rect[0], map_rect[1]), (map_rect[2], map_rect[1]), (map_rect[2], map_rect[3]), (map_rect[0], map_rect[3])], (0, 1, 0)), picture), (0, 0, 12), (1.4, s + 0.005, 0.6)))
    return shapes.join(parts, "CampTable")


def whiteboard():
    """The whiteboard on the garage's west wall (7 x 4 x 0.3): an aluminium
    frame round a wiped white face (the game writes TONIGHT on it), its tray
    of markers and an eraser. Its front is +z."""
    alu = materials.brass("WBAlu", color=(176, 176, 172), roughness=0.4)
    pixels, (face,) = _atlas([whiteboard_face()])
    picture = _picture_mat("WBFace", pixels, 0.5, roughness=0.15)
    W, H = 7.0, 4.0
    parts = [
        materials.assign(_box("Back", (W - 0.2, H - 0.2, 0.15), (0, 0, -0.07), 0.0, 1), _plastic("WBBack", (200, 200, 198))),
        _card("Face", picture, W - 0.24, H - 0.24, (0, 0, 0.03), 1, face),
    ]
    b = 0.12
    for sy in (-1, 1):
        parts.append(materials.assign(_box("Frame", (W, b, 0.3), (0, sy * (H / 2 - b / 2), 0.0), 0.03, 2), alu))
    for sx in (-1, 1):
        parts.append(materials.assign(_box("Frame", (b, H - 2 * b, 0.3), (sx * (W / 2 - b / 2), 0, 0.0), 0.03, 2), alu))
    parts.append(materials.assign(_box("Tray", (W * 0.6, 0.06, 0.25), (0, -H / 2 + 0.02, 0.2), 0.02, 1), alu))
    for k, colour in enumerate([(30, 30, 30), (30, 60, 160), (180, 30, 30)]):
        parts.append(materials.assign(_cyl_x("Marker", 0.045, 0.5, (-0.8 + k * 0.6, -H / 2 + 0.1, 0.22), 8), _plastic("WBMarker%d" % k, colour)))
    parts.append(materials.assign(_box("Eraser", (0.6, 0.2, 0.2), (1.2, -H / 2 + 0.15, 0.22), 0.04, 2), _plastic("WBEraser", (40, 40, 44))))
    return shapes.join(parts, "Whiteboard")


def case_board():
    """The case board on the garage's west wall (12 x 6 x 0.4): cork in a
    timber frame (the photos, the plan and the red string are pinned on it,
    Data/Mall's blocks). Its front is +z."""
    cork = _cork("CaseCork")
    pine = _oak("CasePine", axis="X")
    W, H = 12.0, 6.0
    parts = [materials.assign(_box("Cork", (W - 0.4, H - 0.4, 0.2), (0, 0, -0.08), 0.0, 1), cork)]
    for sy in (-1, 1):
        parts.append(materials.assign(_box("Frame", (W, 0.2, 0.4), (0, sy * (H / 2 - 0.1), 0.0), 0.04, 2), pine))
    for sx in (-1, 1):
        parts.append(materials.assign(_box("Frame", (0.2, H - 0.4, 0.4), (sx * (W / 2 - 0.1), 0, 0.0), 0.04, 2), pine))
    return shapes.join(parts, "CaseBoard")


def _pinned(name, pixels, w, h, pin_colour):
    """A print pinned flat to the case board (w x h, its back on the cork), a
    push pin through its top."""
    pix, (rect,) = _atlas([pixels])
    picture = _picture_mat(name + "Pic", pix, 0.6, roughness=0.6)
    paper = _plastic(name + "Back", (236, 232, 222))
    parts = [
        materials.assign(_box("Paper", (w, h, 0.02), (0, 0, -0.01), 0.0, 1), paper),
        _card("Print", picture, w - 0.01, h - 0.01, (0, 0, 0.002), 1, rect),
        materials.assign(_sphere("Pin", 0.07, (0, h / 2 - 0.12, 0.06), 10, 5), _plastic(name + "Pin", pin_colour)),
    ]
    return shapes.join(parts, name)


def photo_house():
    return _pinned("PhotoHouse", snapshot("house", 2), 1.3, 1.0, (200, 30, 30))


def photo_figure():
    return _pinned("PhotoFigure", snapshot("figure", 5), 1.3, 1.0, (30, 80, 200))


def blueprint_pinned():
    return _pinned("Blueprint", blueprint(), 2.4, 1.8, (220, 200, 40))


def investigator_desk():
    """Their desk under the case board (7 x 3.2 x 3): a grey steel tanker
    desk, a drawer pedestal each end, a green blotter, a lamp's worth of
    papers, a phone. Its front (where you sit) is +z."""
    steel = materials.paint("DeskSteel", color=(120, 124, 120), roughness=0.5, grime=0.4)
    top = _laminate("DeskTop", (96, 110, 92))
    black = _plastic("DeskBlack", (24, 24, 26))
    paper = _plastic("DeskPaper", (230, 226, 210))
    L, H, D = 7.0, 3.2, 3.0
    b, t = -H / 2, H / 2
    parts = [
        materials.assign(_box("Top", (L, 0.12, D), (0, t - 0.06, 0), 0.03, 2), top),
        materials.assign(_box("Modesty", (L - 0.4, H - 0.6, 0.08), (0, b + (H - 0.6) / 2 + 0.3, -D / 2 + 0.1), 0.0, 1), steel),
    ]
    for sx in (-1, 1):
        x = sx * (L / 2 - 0.8)
        parts.append(materials.assign(_box("Pedestal", (1.5, H - 0.12, D - 0.1), (x, b + (H - 0.12) / 2, 0), 0.04, 2), steel))
        for k in range(3):
            y = b + 0.5 + k * 0.9
            parts.append(materials.assign(_box("Drawer", (1.4, 0.8, 0.04), (x, y, D / 2 - 0.03), 0.02, 1), steel))
            parts.append(materials.assign(_box("Pull", (0.5, 0.06, 0.08), (x, y + 0.2, D / 2 + 0.02), 0.02, 1), black))
    parts.append(materials.assign(_box("Blotter", (2.6, 0.02, 1.6), (0.4, t + 0.01, 0.3), 0.0, 1), _plastic("DeskBlotter", (40, 80, 50))))
    for k in range(4):
        parts.append(materials.assign(_place(shapes.box("Sheet", S(0.85, 0.01, 1.1), (0, 0, 0), 0.0, 1), (0, 0, -8 + k * 7), (-2.0 + k * 0.08, t + 0.02 + k * 0.012, 0.2 - k * 0.05)), paper))
    parts.append(materials.assign(_box("Phone", (0.8, 0.35, 0.8), (2.6, t + 0.18, -0.6), 0.08, 2), black))
    return shapes.join(parts, "InvestigatorDesk")


def desk_chair():
    """A swivel chair at their desk (2 x 3.8 x 2): five feet on casters, a
    gas column, a brown vinyl seat and back. Its front is +z (it faces the
    desk)."""
    vinyl = _vinyl("ChairVinyl", (80, 52, 36))
    black = _plastic("ChairBlack", (22, 22, 24))
    chrome = _chrome("ChairChrome")
    H = 3.8
    b = -H / 2
    parts = []
    for k in range(5):
        a = math.tau * k / 5
        end = (0.85 * math.cos(a), b + 0.22, 0.85 * math.sin(a))
        parts.append(materials.assign(_tube("Foot", [(0, b + 0.35, 0), end], 0.06, 6), black))
        parts.append(materials.assign(_sphere("Caster", 0.1, (end[0], b + 0.1, end[2]), 8, 4), black))
    parts.append(materials.assign(_lathe("Column", [(0.0, b + 0.3), (0.09, b + 0.3), (0.09, b + 1.6), (0.0, b + 1.6)], (0, 0, 0), 12), chrome))
    parts.append(materials.assign(shapes.cushion("Seat", S(1.6, 0.35, 1.6), G(0, b + 1.75, 0.1), puff=0.08, levels=2, roundness=0.5), vinyl))
    parts.append(materials.assign(shapes.cushion("Back", S(1.5, 1.6, 0.3), G(0, b + 2.85, -0.75), puff=0.06, levels=2, roundness=0.5), vinyl))
    parts.append(materials.assign(_tube("Spine", [(0, b + 1.6, -0.3), (0, b + 1.65, -0.8), (0, b + 2.2, -0.82)], 0.06, 6), black))
    return shapes.join(parts, "DeskChair")


def cb_radio():
    """The CB base station on their desk (1.6 x 0.8 x 1.2): a silver-faced
    set in a wood-grain case, its signal meter and channel dial, the hand
    mic on its coiled cord. Its front is +z."""
    case = materials.wood("CBWood", (60, 40, 26), (100, 70, 44), grain_axis="X", scale=2.0, roughness=0.5)
    face = materials.brass("CBFace", color=(176, 176, 170), roughness=0.4)
    black = _plastic("CBBlack", (22, 22, 24))
    meter = materials.paint("CBMeter", color=(230, 200, 120), roughness=0.3, grime=0.05)
    W, H, D = 1.6, 0.8, 1.2
    parts = [
        materials.assign(_box("Case", (W, H - 0.1, D - 0.1), (0, -0.05, -0.05), 0.04, 2), case),
        materials.assign(_box("Face", (W - 0.1, H - 0.2, 0.04), (0, -0.05, D / 2 - 0.08), 0.02, 1), face),
        materials.assign(_box("Meter", (0.4, 0.25, 0.03), (-0.45, 0.02, D / 2 - 0.05), 0.02, 1), meter),
    ]
    for k, x in enumerate((0.05, 0.35, 0.6)):
        kn = _lathe("Knob", [(0.0, 0.0), (0.08, 0.0), (0.08, 0.07), (0.0, 0.08)], (0, 0, 0), 12)
        parts.append(materials.assign(_place(kn, (90, 0, 0), (x, -0.08, D / 2 - 0.06)), black))
    parts.append(materials.assign(_box("Mic", (0.3, 0.45, 0.14), (W / 2 - 0.15, H / 2 - 0.05, -0.2), 0.06, 2), black))
    cord = [(W / 2 - 0.15, H / 2 - 0.3, -0.2)]
    for k in range(10):
        cord.append((W / 2 - 0.1 + 0.05 * math.cos(k * 1.4), H / 2 - 0.35 - k * 0.03, -0.25 + 0.05 * math.sin(k * 1.4)))
    parts.append(materials.assign(_tube("Cord", cord, 0.02, 5), black))
    return shapes.join(parts, "CBRadio")


def bankers_box():
    """A banker's file box of evidence (2.4 x 2 x 2.4, stretched to each
    stack's): white card with a lid, hand holes, a label marked in pen."""
    card = _card_brown("BoxCard", (220, 214, 196))
    dark = _plastic("BoxHole", (30, 26, 22))
    pixels, (label,) = _atlas([box_label("CASE 88")])
    picture = _picture_mat("BoxLabel", pixels, 0.12, roughness=0.8)
    W, H, D = 2.4, 2.0, 2.4
    parts = [
        materials.assign(_box("Box", (W - 0.06, H - 0.3, D - 0.06), (0, -0.15, 0), 0.03, 2), card),
        materials.assign(_box("Lid", (W, 0.35, D), (0, H / 2 - 0.175, 0), 0.04, 2), card),
        _card("Label", picture, 1.0, 0.4, (0, -0.2, D / 2 - 0.025), 1, label),
    ]
    for sx in (-1, 1):
        parts.append(materials.assign(_box("Hole", (0.03, 0.18, 0.6), (sx * (W / 2 - 0.02), 0.25, 0), 0.0, 1), dark))
    return shapes.join(parts, "BankersBox")


# The garage: its lights and its door ------------------------------------------------


def strip_fixture():
    """A garage strip light (8 x 0.45 x 1, at its light's point): a steel
    channel with end caps, a wire guard, two tubes under it (grey; a lit
    one's tubes are the game's Neon part, World/MallBuilder)."""
    steel = materials.paint("StripSteel", color=(200, 200, 196), roughness=0.5, grime=0.4)
    guard = _steel("StripGuard", 0.5)
    tube = _plastic("StripTube", (190, 192, 186))
    L = 8.0
    parts = [
        materials.assign(_box("Channel", (L, 0.25, 0.9), (0, 0.1, 0), 0.03, 2), steel),
    ]
    for sx in (-1, 1):
        parts.append(materials.assign(_box("Cap", (0.15, 0.35, 0.8), (sx * (L / 2 - 0.3), -0.1, 0), 0.02, 1), steel))
    for z in (-0.2, 0.2):
        parts.append(materials.assign(_cyl_x("Tube", 0.08, L - 0.7, (0, -0.15, z), 10), tube))
    for sx in (-1, 1):
        parts.append(materials.assign(_tube("Rod", [(sx * 2.5, 0.22, 0.0), (sx * 2.5, 1.0, 0.0)], 0.04, 6), guard))
    for k in range(9):
        x = -L / 2 + 0.6 + k * 0.85
        parts.append(materials.assign(_tube("Guard", [(x, 0.0, -0.45), (x, -0.3, -0.3), (x, -0.33, 0.0), (x, -0.3, 0.3), (x, 0.0, 0.45)], 0.02, 4, caps=False), guard))
    return shapes.join(parts, "StripFixture")


WORK_HEAD_Y = 7.0  # Data/Mall's work lamps hang their light 7 up


def work_lamp():
    """A work lamp on its tripod (on the floor, its head 7 up, tipped down 20
    degrees, as World/MallBuilder's lit head is): yellow tripod legs, the
    pole, the yoke, a halogen housing round the game's Neon head with its
    wire guard, open at the front; the cord to the floor."""
    yellow = materials.paint("WLYellow", color=(220, 170, 30), roughness=0.5, grime=0.4)
    dark = _iron("WLDark", (36, 36, 36))
    orange = _plastic("WLCord", (226, 110, 26))
    y = WORK_HEAD_Y
    tilt = lambda p: _rot_x(p, -20, (0.0, y, 0.0))  # noqa: E731
    parts = []
    for k in range(3):
        a = math.tau * k / 3 + 0.5
        parts.append(materials.assign(_tube("Leg", [(0, 2.2, 0), (1.3 * math.cos(a), 0.05, 1.3 * math.sin(a))], 0.05, 6), yellow))
    parts.append(materials.assign(_tube("Pole", [(0, 1.8, 0), (0, y - 0.9, 0)], 0.07, 8), yellow))
    parts.append(materials.assign(_tube("Yoke", [(-0.85, y - 0.1, 0), (-0.85, y - 0.85, 0), (0.85, y - 0.85, 0), (0.85, y - 0.1, 0)], 0.05, 6), dark))
    # The housing: a box 1.5 x 1.2 x 1.3 round the head, open at its front
    # (-z), built from its four walls and back, tipped as the head is.
    walls = [
        ("Top", (1.34, 0.08, 1.3), (0, y + 0.56, 0.05)),
        ("Bottom", (1.34, 0.08, 1.3), (0, y - 0.56, 0.05)),
        ("Left", (0.08, 1.2, 1.3), (-0.71, y, 0.05)),
        ("Right", (0.08, 1.2, 1.3), (0.71, y, 0.05)),
        ("Back", (1.34, 1.04, 0.08), (0, y, 0.66)),
    ]
    for name, size, at in walls:
        parts.append(materials.assign(_box_pts(name, size, at, tilt), dark))
    for k in range(4):
        x = -0.45 + k * 0.3
        parts.append(materials.assign(_tube("Guard", [tilt((x, y + 0.55, -0.62)), tilt((x, y + 0.2, -0.7)), tilt((x, y - 0.2, -0.7)), tilt((x, y - 0.55, -0.62))], 0.02, 4, caps=False), dark))
    parts.append(materials.assign(_tube("Handle", [tilt((-0.4, y + 0.6, 0.2)), tilt((-0.3, y + 0.85, 0.2)), tilt((0.3, y + 0.85, 0.2)), tilt((0.4, y + 0.6, 0.2))], 0.04, 6), dark))
    parts.append(materials.assign(_tube("Cord", [tilt((0, y - 0.5, 0.66)), (0.1, y - 1.6, 0.25), (0.15, 2.0, 0.1), (0.4, 0.05, 0.6), (1.4, 0.04, 1.2)], 0.04, 6), orange))
    return shapes.join(parts, "WorkLamp")


def roll_up_shutter():
    """A roll-up shutter, down (modelled 20 x 12, stretched to each: the
    garage's door, the dead shops' fronts): galvanised slats, a bottom bar
    with its handles and lock, the guides either side. Its front is +z
    (toward whoever looks at it)."""
    galv = _rust_steel("ShutterGalv")
    dark = _iron("ShutterDark", (60, 60, 58))
    W, H = 20.0, 12.0
    b = -H / 2
    pitch = 0.5
    rows = int(H / pitch)
    outline = []
    for k in range(rows * 2 + 1):
        y = b + 0.5 + (H - 0.5) * k / (rows * 2)
        z = 0.06 if k % 2 else -0.04
        outline.append((z, y))
    outline += [(-0.12, H / 2), (-0.12, b + 0.5)]
    parts = [materials.assign(_side_prism("Slats", outline, -W / 2 + 0.3, W / 2 - 0.3), galv)]
    parts.append(materials.assign(_box("BottomBar", (W - 0.6, 0.5, 0.3), (0, b + 0.25, 0.0), 0.04, 2), dark))
    for x in (-W / 4, W / 4):
        parts.append(materials.assign(_tube("Handle", [(x - 0.4, b + 0.4, 0.15), (x - 0.4, b + 0.4, 0.32), (x + 0.4, b + 0.4, 0.32), (x + 0.4, b + 0.4, 0.15)], 0.04, 6), dark))
    parts.append(materials.assign(_box("Lock", (0.3, 0.3, 0.12), (0, b + 0.3, 0.2), 0.03, 2), _chrome("ShutterLock")))
    for sx in (-1, 1):
        parts.append(materials.assign(_box("Guide", (0.3, H, 0.45), (sx * (W / 2 - 0.15), 0, 0.0), 0.03, 2), dark))
    obj = shapes.join(parts, "RollUpShutter")
    obj["bake_size"] = 1024
    return obj


# The vault --------------------------------------------------------------------------


VAULT_SPAN, VAULT_RISE = 40.0, 11.0  # Data/Mall's vault: z0..z1 and its rise


def _ellipse(t, inset=0.0):
    """A point on the vault's half-ellipse (t 0..1, east to west across z),
    `inset` in from it, in the rib's plane (z, y)."""
    a = math.pi * t
    r, h = VAULT_SPAN / 2 - inset, VAULT_RISE - inset
    return (-r * math.cos(a), h * math.sin(a))


def vault_rib():
    """One of the vault's eight ribs (40 across, 11 up from its springing): a
    lattice arch in dark steel, an outer and an inner chord with a zig-zag
    web between, its feet on base plates. In the game's z-y plane, x its
    thickness, its springing line at y = 0."""
    steel = _iron("RibSteel", (54, 58, 62), roughness=0.45, grime=0.4)
    n = 24
    outer = [_ellipse(k / n) for k in range(n + 1)]
    inner = [_ellipse(k / n, 1.0) for k in range(n + 1)]
    parts = [
        materials.assign(_tube("Outer", [(0.0, y, z) for z, y in outer], 0.17, 6), steel),
        materials.assign(_tube("Inner", [(0.0, y, z) for z, y in inner], 0.14, 6), steel),
    ]
    for k in range(n):
        a = outer[k] if k % 2 == 0 else inner[k]
        b = inner[k + 1] if k % 2 == 0 else outer[k + 1]
        parts.append(materials.assign(_tube("Web", [(0.0, a[1], a[0]), (0.0, b[1], b[0])], 0.07, 5), steel))
    for z in (-VAULT_SPAN / 2 + 0.5, VAULT_SPAN / 2 - 0.5):
        parts.append(materials.assign(_box("Plate", (0.8, 0.12, 1.4), (0, -0.06, z), 0.02, 1), steel))
    return shapes.join(parts, "VaultRib")


def vault_gable():
    """An end of the vault (40 across, 11 up from its springing): a plaster
    lunette with a fan light let into it, its dark glass in steel bars that
    spread from a half-wheel at the bottom. In the game's x-y plane (it is
    turned onto each end), its front +z, its springing line at y = 0."""
    plaster = _plaster("GablePlaster", color=(188, 180, 164))
    steel = _iron("GableSteel", (46, 50, 54), roughness=0.45, grime=0.3)
    glass = _glass("GableGlass", (30, 36, 44))
    n = 32
    rim = [(_ellipse(k / n)[0], _ellipse(k / n)[1]) for k in range(n + 1)]
    window = [(_ellipse(k / n, 2.5)[0], _ellipse(k / n, 2.5)[1]) for k in range(n + 1)]
    # The plaster: the lunette less the window, as a ring of quads, both
    # faces (front and back) closed by its rims.
    bm = bmesh.new()
    t = 0.6
    front = [bm.verts.new(G(x, y, t / 2)) for x, y in rim]
    back = [bm.verts.new(G(x, y, -t / 2)) for x, y in rim]
    wf = [bm.verts.new(G(x, y + 0.0, t / 2)) for x, y in window]
    wb = [bm.verts.new(G(x, y + 0.0, -t / 2)) for x, y in window]
    for k in range(n):
        bm.faces.new((front[k], front[k + 1], wf[k + 1], wf[k]))
        bm.faces.new((back[k + 1], back[k], wb[k], wb[k + 1]))
        bm.faces.new((back[k], back[k + 1], front[k + 1], front[k]))
        bm.faces.new((wf[k], wf[k + 1], wb[k + 1], wb[k]))
    # Its bottom edge between the rim and the window, either side.
    for side in (0, n):
        bm.faces.new((front[side], wf[side], wb[side], back[side]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    parts = [materials.assign(shapes.smooth(_new("Lunette", bm), 30), plaster)]
    # The glass, set back a little, and the sill.
    parts.append(materials.assign(_flat("Glass", [(x, y) for x, y in window], -0.1, 0.0), glass))
    parts.append(materials.assign(_box("Sill", (2 * (VAULT_SPAN / 2 - 2.5) + 0.4, 0.3, 0.8), (0, 0.15, 0.1), 0.04, 2), plaster))
    # The fan's bars from the half-wheel.
    hub = 2.0
    parts.append(materials.assign(_tube("Hub", [(hub * math.cos(math.pi * k / 12), hub * math.sin(math.pi * k / 12) + 0.3, 0.05) for k in range(13)], 0.1, 6), steel))
    for k in range(1, 12):
        a = math.pi * k / 12
        tip = _ellipse(1 - k / 12, 2.5)
        parts.append(materials.assign(_tube("Bar", [(hub * math.cos(a), hub * math.sin(a) + 0.3, 0.05), (tip[0], tip[1], 0.05)], 0.08, 5), steel))
    for r in (0.45, 0.75):
        arc = []
        for k in range(17):
            p = _ellipse(k / 16, 2.5)
            arc.append((p[0] * r, p[1] * r + 0.3 * (1 - r), 0.05))
        parts.append(materials.assign(_tube("Ring", arc, 0.08, 5), steel))
    return shapes.join(parts, "VaultGable")


# The escalators ----------------------------------------------------------------------


ESC_RUN, ESC_RISE = 38.0, 22.0  # Data/Mall's escalators: from x 100, y 0 up to x 138, y 22


def escalator_pair():
    """The dead mall's stopped escalators, the pair side by side (on the
    floor at the middle of the incline, x across 96..141, up to 22, two
    lanes 3.4 wide at z -2 and +2): stainless steps from the floor's comb
    plate up to the landing's, a black rubber handrail on a cream panelled
    balustrade each side, the truss clad in steel underneath."""
    steel = _steel("EscSteel", 0.45)
    tread = _iron("EscTread", (70, 72, 74), roughness=0.5, grime=0.5)
    cream = materials.paint("EscPanel", color=(196, 188, 170), roughness=0.5, grime=0.5)
    rubber = _rubber("EscRail")
    x0 = -19.0  # the incline's foot from the middle (119 - 100)
    angle = math.atan2(ESC_RISE, ESC_RUN)

    def on_incline(u):
        """The point a fraction u up the incline (x, y)."""
        return (x0 + ESC_RUN * u, ESC_RISE * u)

    def nose(x):
        """The steps' line at x: flat, up the incline, flat."""
        return min(max((x - x0) / ESC_RUN, 0.0), 1.0) * ESC_RISE

    xs = [x0 - 3.0, x0, x0 + ESC_RUN, x0 + ESC_RUN + 3.0]
    parts = []
    for lane in (-2.0, 2.0):
        # The steps: risers and treads up the incline, flat at each end, down
        # to a soffit parallel to it.
        steps = 28
        rise = ESC_RISE / steps
        run = ESC_RUN / steps
        pts = [(x0 - 3.0, 0.0), (x0, 0.0)]
        for k in range(steps):
            x, y = x0 + k * run, k * rise
            pts += [(x, y + rise), (x + run, y + rise)]
        pts += [(x0 + ESC_RUN + 3.0, ESC_RISE), (x0 + ESC_RUN + 3.0, ESC_RISE - 1.6), (x0 + ESC_RUN, ESC_RISE - 1.6), (x0 + 2.8, -0.05), (x0 - 3.0, -0.05)]
        parts.append(materials.assign(_flat("Steps", pts, lane - 1.6, lane + 1.6), tread))
        parts.append(materials.assign(_box("Comb", (1.2, 0.06, 3.2), (x0 - 2.4, 0.03, lane), 0.0, 1), steel))
        parts.append(materials.assign(_box("Comb", (1.2, 0.06, 3.2), (x0 + ESC_RUN + 2.4, ESC_RISE + 0.03, lane), 0.0, 1), steel))
    for z in (-3.9, 0.0, 3.9):
        # A cream panelled balustrade up 2.6 from the steps' line, its steel
        # skirt below, the handrail on top curling under at each end.
        ends = [x0 - 2.5, x0, x0 + ESC_RUN, x0 + ESC_RUN + 2.5]
        panel = [(x, nose(x) + 0.2) for x in ends] + [(x, nose(x) + 2.8) for x in reversed(ends)]
        parts.append(materials.assign(_flat("Panel", panel, z - 0.15, z + 0.15), cream))
        skirt = [(x, nose(x) + 0.35) for x in reversed(xs)]
        skirt = [(x0 - 3.0, -0.05)] + list(reversed(skirt)) + [(x0 + ESC_RUN + 3.0, ESC_RISE - 1.6), (x0 + ESC_RUN, ESC_RISE - 1.6), (x0 + 2.8, -0.05)]
        parts.append(materials.assign(_flat("Skirt", skirt, z - 0.2, z + 0.2), steel))
        rail = [(x0 - 2.5, 2.0, z), (x0 - 2.9, 2.5, z), (x0 - 2.5, 3.0, z), (x0, 3.0, z), (x0 + ESC_RUN, ESC_RISE + 3.0, z), (x0 + ESC_RUN + 2.5, ESC_RISE + 3.0, z), (x0 + ESC_RUN + 2.9, ESC_RISE + 2.5, z), (x0 + ESC_RUN + 2.5, ESC_RISE + 2.0, z)]
        parts.append(materials.assign(_tube("Handrail", rail, 0.14, 8), rubber))
    obj = shapes.join(parts, "EscalatorPair")
    obj["bake_size"] = 1024
    return obj


# The neon -----------------------------------------------------------------------------


def _arc(cx, cy, rx, ry, a0, a1, n):
    return [(cx + rx * math.cos(math.radians(a0 + (a1 - a0) * k / n)), cy + ry * math.sin(math.radians(a0 + (a1 - a0) * k / n))) for k in range(n + 1)]


def glyphs(n):
    """The neon's stroke alphabet: each letter's tubes as lines of points in a
    box 1 high (its width second), arcs in `n` steps (fewer: blockier)."""
    return {
        "A": ([[(0, 0), (0.375, 1), (0.75, 0)], [(0.17, 0.42), (0.58, 0.42)]], 0.75),
        "B": ([[(0, 0), (0, 1), (0.4, 1)] + _arc(0.4, 0.76, 0.24, 0.24, 90, -90, n) + [(0, 0.52)], [(0.4, 0.52), (0.44, 0.52)] + _arc(0.44, 0.26, 0.26, 0.26, 90, -90, n) + [(0, 0)]], 0.7),
        "C": ([_arc(0.5, 0.5, 0.5, 0.5, 50, 310, n * 2)], 0.82),
        "D": ([[(0, 0), (0, 1), (0.28, 1)] + _arc(0.28, 0.5, 0.45, 0.5, 90, -90, n * 2) + [(0, 0)]], 0.73),
        "E": ([[(0.62, 1), (0, 1), (0, 0), (0.62, 0)], [(0, 0.52), (0.48, 0.52)]], 0.62),
        "I": ([[(0, 0), (0, 1)]], 0.0),
        "L": ([[(0, 1), (0, 0), (0.58, 0)]], 0.58),
        "N": ([[(0, 0), (0, 1), (0.72, 0), (0.72, 1)]], 0.72),
        "O": ([_arc(0.46, 0.5, 0.46, 0.5, 90, 450, n * 2)], 0.92),
        "Q": ([_arc(0.46, 0.5, 0.46, 0.5, 90, 450, n * 2), [(0.56, 0.24), (0.96, -0.1)]], 0.96),
        "R": ([[(0, 0), (0, 1), (0.4, 1)] + _arc(0.4, 0.74, 0.26, 0.26, 90, -90, n) + [(0, 0.48)], [(0.3, 0.48), (0.68, 0)]], 0.68),
        "S": ([_arc(0.36, 0.75, 0.34, 0.25, 15, 270, n) + _arc(0.36, 0.25, 0.34, 0.25, 90, -165, n)], 0.72),
        "T": ([[(0, 1), (0.7, 1)], [(0.35, 1), (0.35, 0)]], 0.7),
        "U": ([[(0, 1), (0, 0.36)] + _arc(0.35, 0.36, 0.35, 0.36, 180, 360, n) + [(0.7, 1)]], 0.7),
        "V": ([[(0, 1), (0.37, 0), (0.74, 1)]], 0.74),
    }


def _neon(name, text, cap, width, slant=0.0, n=6, radius=0.1, gap=0.3, underline=None, border=False):
    """A word in neon tubes: `cap` high at most, fitted within `width`, each
    letter's strokes bent as tubes `radius` thick and 0.2 out from the sign's
    plane; `slant` leans it; `underline`, a swoosh (curve) or a straight bar
    under it; `border`, a tube round it. Middle at the sign's point; the
    tubes are Neon in the game, so it carries no maps."""
    g = glyphs(n)
    units = sum(g[c][1] for c in text) + gap * (len(text) - 1)
    s = min(cap, width * 0.92 / max(units, 1e-6))
    left = -units * s / 2
    z = 0.45  # (in front of the raceway's glass holders)
    strokes = []
    x = left
    for c in text:
        lines, w = g[c]
        for line in lines:
            strokes.append([(x + (px + slant * (py - 0.5)) * s, (py - 0.5) * s) for px, py in line])
        x += (w + gap) * s
    if underline == "swoosh":
        strokes.append([(left + t * units * s, -0.5 * s - 0.28 * s + 0.12 * s * math.sin(math.pi * t)) for t in [k / 16 for k in range(17)]])
    elif underline == "bar":
        strokes.append([(left, -0.5 * s - 0.3 * s), (left + units * s, -0.5 * s - 0.3 * s)])
    if border:
        m = 0.35 * s
        x0, x1, y0, y1 = left - m, left + units * s + m, -0.5 * s - m, 0.5 * s + m
        strokes.append([(x0, y0), (x1, y0), (x1, y1), (x0, y1), (x0, y0)])
    mat = _plastic(name + "Glass", (255, 255, 255), 0.2)
    parts = []
    for line in strokes:
        # (Each straight run as it is, each bend through its points: glass
        # tubing is bent smooth, so no corner is left sharp.)
        pts = [(px, py, z) for px, py in line]
        if len(pts) >= 2:
            parts.append(materials.assign(_tube("Tube", pts, radius, 6), mat))
    obj = shapes.join(parts, name)
    obj["swatch"] = True  # (drawn Neon in the game: no maps to bake)
    return obj


def neon_boutique():
    return _neon("NeonBoutique", "BOUTIQUE", 2.4, 20, slant=0.18, n=8, radius=0.08, underline="swoosh")


def neon_video():
    return _neon("NeonVideo", "VIDEO", 2.6, 18, n=8, radius=0.13, border=True)


def neon_arcade():
    return _neon("NeonArcade", "ARCADE", 2.8, 20, n=3, radius=0.12, gap=0.38)


def neon_electronics():
    return _neon("NeonElectronics", "ELECTRONICS", 2.2, 22, n=4, radius=0.1, underline="bar")


def neon_diner():
    return _neon("NeonDiner", "DINER", 2.8, 18, slant=0.12, n=8, radius=0.12, underline="swoosh")


def sign_raceway():
    """The raceway behind a neon word (modelled 10 long, stretched to each):
    a black steel channel with the transformer's box in its middle and the
    glass holders standing out of it. Its back on the wall, its front +z."""
    black = materials.paint("RacewayBlack", color=(24, 24, 26), roughness=0.5, grime=0.3)
    glassh = _plastic("RacewayHolder", (200, 200, 196))
    L = 10.0
    parts = [
        materials.assign(_box("Channel", (L, 0.5, 0.3), (0, 0, 0.0), 0.03, 2), black),
        materials.assign(_box("Transformer", (1.2, 0.7, 0.35), (0, 0, 0.02), 0.03, 2), black),
    ]
    for k in range(8):
        x = -L / 2 + 0.6 + k * (L - 1.2) / 7
        parts.append(materials.assign(_lathe("Holder", [(0.0, 0.0), (0.06, 0.0), (0.05, 0.26), (0.0, 0.27)], (0, 0, 0), 8), glassh))
        parts[-1] = _place(parts[-1], (90, 0, 0), (x, 0.15, 0.15))
    return shapes.join(parts, "SignRaceway")


MALL3 = [
    generator,
    jerry_can,
    oil_drum,
    oil_drum_pump,
    cable_reel,
    mall_power_box,
    car_pegboard,
    payphone,
    tyre_stack,
    cot_bag,
    cot_blanket,
    camp_table,
    whiteboard,
    case_board,
    photo_house,
    photo_figure,
    blueprint_pinned,
    investigator_desk,
    desk_chair,
    cb_radio,
    bankers_box,
    strip_fixture,
    work_lamp,
    roll_up_shutter,
    vault_rib,
    vault_gable,
    escalator_pair,
    neon_boutique,
    neon_video,
    neon_arcade,
    neon_electronics,
    neon_diner,
    sign_raceway,
]
