"""The house's moving fittings and the corridors' landmarks (the visual
rework V4, the kit's sixth rollout batch, kit8):

- the dumbwaiter (server/Puzzles/Dumbwaiter): its casing on each floor, the
  stuck hatch downstairs, the car, and the jam box under its crank;
- the crank doors (Services/CrankService): a slat of the roller shutter (the
  game stacks them as it rolls), its bottom bar, the roller box over the
  doorway, the crank's wall plate, the latch inside, and the hand wheel both
  cranks turn (the dumbwaiter's smaller);
- the laundry chute (Services/ChuteService): the hatch in an upstairs wall,
  its mouth over the laundry and the basket under it; where the rooms share
  no wall, the trapdoor in the floor and the duct out of the ceiling;
- the five corridor landmarks (World/LandmarkProps, Data/Landmarks): the
  stag's head, the founder's portrait, the tapestry, the stopped clock, the
  ship's wheel.

Each is built in the game's own frame (things.G, S): x across, y up, z
toward its front (+Z), round the grey-box part it dresses, so the game moves
it as it moved the part (the car, the wheel, a slat). The landmarks hang
from z = 0 (the wall) out, round the frame World/LandmarkProps builds them on.
"""

import math

import bmesh
import bpy

from . import materials, paintings, shapes
from .decor import FRAME_PROFILE, _canvas
from .decor import _gilt as _frame_gilt
from .living import _solid
from .things import G, _box, _dark, _dial, _gilt, _lathe, _new, _ring, _sphere, _tube

OAK_DARK, OAK_LIGHT = (72, 48, 30), (124, 86, 54)


def _oak(name, axis="Z", roughness=0.42):
    return materials.wood(name, OAK_DARK, OAK_LIGHT, grain_axis=axis, scale=1.2, roughness=roughness)


def _iron(name, color=(40, 38, 36), roughness=0.5, grime=0.35):
    """Cast iron, painted black long ago."""
    return materials.paint(name, color=color, roughness=roughness, grime=grime)


def _galv(name, color=(138, 144, 146)):
    """Galvanised sheet steel, gone dull."""
    return materials.brass(name, color=color, roughness=0.55)


def _prism(name, outline, z0, z1):
    """An outline in the game's x-y plane [(x, y), ...] (anticlockwise seen
    from the front), extruded from z0 to z1 toward the front."""
    bm = bmesh.new()
    back = [bm.verts.new(G(x, y, z0)) for x, y in outline]
    front = [bm.verts.new(G(x, y, z1)) for x, y in outline]
    n = len(outline)
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new((back[i], back[j], front[j], front[i]))
    caps = [bm.faces.new(list(reversed(back))), bm.faces.new(front)]
    bmesh.ops.triangulate(bm, faces=caps)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return shapes.smooth(_new(name, bm), 30)


def _loft(name, rings, close_bottom=False):
    """A surface through rings of points (the game's frame), each ring the
    same count, bottom up: a basket's wall, a duct."""
    bm = bmesh.new()
    verts = [[bm.verts.new(G(*p)) for p in ring] for ring in rings]
    n = len(rings[0])
    for a, b in zip(verts, verts[1:]):
        for i in range(n):
            j = (i + 1) % n
            bm.faces.new((a[i], a[j], b[j], b[i]))
    if close_bottom:
        bm.faces.new(list(reversed(verts[0])))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return shapes.smooth(_new(name, bm), 50)


def _rounded_rect(w, d, r, y, per_corner=4, bulge=0.0):
    """A ring round a w x d rectangle with corners rounded r, at height y
    (the game's x and z), anticlockwise from above; `bulge` bows its sides
    out at their middles."""
    pts = []
    for cx, cz, a0 in ((w / 2 - r, d / 2 - r, 0), (-w / 2 + r, d / 2 - r, 90), (-w / 2 + r, -d / 2 + r, 180), (w / 2 - r, -d / 2 + r, 270)):
        for k in range(per_corner + 1):
            a = math.radians(a0 + 90 * k / per_corner)
            pts.append((cx + r * math.cos(a), y, cz + r * math.sin(a)))
    if bulge:
        out = []
        for x, yy, z in pts:
            fx = 1 - (2 * x / w) ** 2
            fz = 1 - (2 * z / d) ** 2
            out.append((x * (1 + bulge * max(0.0, fz)), yy, z * (1 + bulge * max(0.0, fx))))
        pts = out
    return pts


def _studs(name, points, radius, mat, steps=6, rings=3):
    """Little domed heads (rivets, bolts) at points in the game's frame."""
    return [materials.assign(_sphere(name, radius, p, steps, rings), mat) for p in points]


def _raised(name, w, h, field, mould, depth=0.035):
    """A raised panel facing the game's +z round the origin: a bevelled
    field standing proud of z = 0 and a moulding round it."""
    parts = [materials.assign(_box(name + "Field", (w - 0.14, h - 0.14, depth), (0, 0, depth / 2), depth * 0.7, 2), field)]
    m = 0.05
    for size, at in (
        ((w, m, depth * 1.5), (0, h / 2 - m / 2, depth * 0.75)),
        ((w, m, depth * 1.5), (0, -h / 2 + m / 2, depth * 0.75)),
        ((m, h - 2 * m, depth * 1.5), (-w / 2 + m / 2, 0, depth * 0.75)),
        ((m, h - 2 * m, depth * 1.5), (w / 2 - m / 2, 0, depth * 0.75)),
    ):
        parts.append(materials.assign(_box(name + "Mould", size, at, 0.012, 2), mould))
    return shapes.join(parts, name)


# The dumbwaiter (server/Puzzles/Dumbwaiter) --------------------------------------

DW_W, DW_D = 1.9, 1.7  # Config.Dumbwaiter Width and Depth
HATCH_Y, OPEN_H = 2.6, 1.4  # the car's floor at each hatch; the opening's height
STOREY = 10.0  # Config.Level.WallHeight: the casing runs floor to ceiling
BEHIND = 0.32  # its back stands this far off the wall's face (Inset past the wall's line)

BASE_PROFILE = [(0.0, 0.0), (-0.07, 0.0), (-0.07, 0.42), (-0.05, 0.47), (-0.03, 0.49), (-0.03, 0.53), (0.0, 0.55)]
CORNICE_PROFILE = [(0.0, 0.0), (-0.03, 0.0), (-0.05, 0.08), (-0.1, 0.18), (-0.16, 0.3), (-0.16, 0.4), (0.0, 0.4)]


def _wrap(name, profile, w, d, y, mat):
    """A moulding round a box's front and both sides (w across, d deep from
    z = -BEHIND), its foot at height y: a baseboard, a cornice."""
    reach = max(-p[0] for p in profile)
    parts = [materials.assign(shapes.moulding(name, profile, w + 2 * reach, (0, -d + BEHIND, y)), mat)]
    for sx in (-1, 1):
        run = shapes.moulding(name, profile, d + reach, (0, 0, 0))
        shapes.turn(run, (0, 0, sx * 90), G(sx * w / 2, y, -BEHIND + (d + reach) / 2))
        parts.append(materials.assign(run, mat))
    return parts


def dumbwaiter_casing():
    """The dumbwaiter's casing on one floor, 1.9 x 10 x 1.7 (Puzzles/
    Dumbwaiter's sides, fronts and trim), round its back on the floor, its
    front +z: an oak cabinet floor to ceiling, panelled on its front and
    sides, a baseboard and a cornice round it, the hatch's opening (2.6 to
    4.0 up) framed by an architrave over a sill. Inside, the shaft's dark
    lining and the runners the car rides. Its sides reach back to the wall
    (the game's casing stands off it). The same on both floors: downstairs
    the stuck hatch closes the opening (DumbwaiterHatch)."""
    oak = _oak("CasingOak")
    oak_x = _oak("CasingOakAcross", "X")
    lining = _dark("ShaftLining", (30, 24, 20), 0.85)
    t, ft = 0.15, 0.12
    w, d = DW_W, DW_D
    top = HATCH_Y + OPEN_H
    deep = d - ft + BEHIND
    parts = []
    for sx in (-1, 1):
        parts.append(materials.assign(_box("Side", (t, STOREY, deep), (sx * (w / 2 - t / 2), STOREY / 2, -BEHIND + deep / 2), 0.01, 1), oak))
        # (Beside the opening, the front's stiles close the sides' ends.)
        parts.append(materials.assign(_box("Stile", (t, OPEN_H, ft), (sx * (w / 2 - t / 2), HATCH_Y + OPEN_H / 2, d - ft / 2), 0.01, 1), oak))
    parts.append(materials.assign(_box("FrontLow", (w, HATCH_Y, ft), (0, HATCH_Y / 2, d - ft / 2), 0.01, 1), oak))
    parts.append(materials.assign(_box("FrontHigh", (w, STOREY - top, ft), (0, top + (STOREY - top) / 2, d - ft / 2), 0.01, 1), oak))
    # Inside: the shaft's dark back and the runners either side.
    parts.append(materials.assign(_box("Lining", (w - 2 * t, STOREY, 0.04), (0, STOREY / 2, -BEHIND + 0.04), 0.0), lining))
    for sx in (-1, 1):
        parts.append(materials.assign(_box("Runner", (0.05, STOREY, 0.1), (sx * (w / 2 - t - 0.025), STOREY / 2, d / 2), 0.01, 1), lining))
    # Raised panels: the front under and over the hatch, both sides.
    for pw, ph, py in ((1.45, 1.55, 1.48), (1.45, 2.3, 5.45), (1.45, 2.3, 7.95)):
        parts.append(shapes.turn(_raised("Panel", pw, ph, oak, oak_x), (0, 0, 0), G(0, py, d)))
    for sx in (-1, 1):
        for ph, py in ((2.6, 2.05), (2.6, 4.95), (2.5, 7.85)):
            panel = _raised("Panel", deep - 0.4, ph, oak, oak_x)
            parts.append(shapes.turn(panel, (0, 0, sx * 90), G(sx * w / 2, py, -BEHIND + deep / 2)))
    # The opening's architrave, and a sill under it.
    arch = 0.11
    for sx in (-1, 1):
        post = _box("Architrave", (arch, OPEN_H + arch, 0.05), (sx * (0.8 + arch / 2), HATCH_Y + (OPEN_H + arch) / 2, d + 0.025), 0.015, 2)
        parts.append(materials.assign(post, oak))
    parts.append(materials.assign(_box("Lintel", (1.6 + 2 * arch, arch, 0.06), (0, top + arch / 2, d + 0.03), 0.015, 2), oak_x))
    parts.append(materials.assign(_box("Sill", (1.8, 0.06, 0.16), (0, HATCH_Y - 0.03, d + 0.04), 0.015, 2), oak_x))
    parts += _wrap("Baseboard", BASE_PROFILE, w, d + BEHIND, 0.0, oak_x)
    parts += _wrap("Cornice", CORNICE_PROFILE, w, d + BEHIND, STOREY - 0.4, oak_x)
    piece = shapes.join(parts, "DumbwaiterCasing")
    piece["bake_size"] = 1024
    return piece


def dumbwaiter_hatch():
    """The stuck hatch downstairs, 1.6 x 1.4 x 0.1 round its middle (Puzzles/
    Dumbwaiter's Hatch): a little oak door, a glazed light round the game's
    glass (kept) over a raised panel, brass hinges and a knob."""
    oak = _oak("HatchOak")
    oak_x = _oak("HatchOakAcross", "X")
    brass = materials.brass("HatchBrass", color=(170, 136, 78), roughness=0.35)
    w, t = 1.6, 0.1
    gy0, gy1 = -0.1, 0.4  # the glass (the game's Window: 0.7 x 0.5, 0.15 up)
    parts = [
        materials.assign(_box("TopRail", (w, 0.7 - gy1, t), (0, (gy1 + 0.7) / 2, 0), 0.012, 2), oak_x),
        materials.assign(_box("MidRail", (w, gy0 + 0.25, t), (0, (gy0 - 0.25) / 2, 0), 0.012, 2), oak_x),
        materials.assign(_box("Bottom", (w, 0.45, t), (0, -0.475, 0), 0.012, 2), oak),
    ]
    for sx in (-1, 1):
        parts.append(materials.assign(_box("Stile", (0.45, gy1 - gy0, t), (sx * 0.575, (gy0 + gy1) / 2, 0), 0.012, 2), oak))
        parts.append(materials.assign(_box("Bead", (0.035, gy1 - gy0 + 0.07, 0.03), (sx * 0.368, (gy0 + gy1) / 2, t / 2 + 0.012), 0.008), oak))
    for y in (gy0 - 0.018, gy1 + 0.018):
        parts.append(materials.assign(_box("Bead", (0.77, 0.035, 0.03), (0, y, t / 2 + 0.012), 0.008), oak_x))
    parts.append(shapes.turn(_raised("Panel", 1.3, 0.35, oak, oak_x, depth=0.025), (0, 0, 0), G(0, -0.475, t / 2)))
    for y in (0.48, -0.5):
        parts.append(materials.assign(_box("Hinge", (0.07, 0.22, 0.025), (-0.77, y, t / 2 + 0.008), 0.006), brass))
        parts.append(materials.assign(shapes.roll("Knuckle", 0.22, 0.022, G(-0.8, y, t / 2 + 0.01), axis="Z", steps=8), brass))
    parts.append(materials.assign(_lathe("Rose", [(0.0, 0.0), (0.06, 0.0), (0.06, 0.012), (0.0, 0.016)]), brass))
    parts[-1] = shapes.turn(parts[-1], (90, 0, 0), G(0.6, -0.02, t / 2))
    knob = _lathe("Knob", [(0.0, 0.0), (0.022, 0.0), (0.02, 0.05), (0.05, 0.08), (0.05, 0.11), (0.0, 0.13)], steps=14)
    parts.append(materials.assign(shapes.turn(knob, (90, 0, 0), G(0.6, -0.02, t / 2 + 0.01)), brass))
    piece = shapes.join(parts, "DumbwaiterHatch")
    piece["bake_size"] = 512
    return piece


def dumbwaiter_car():
    """The dumbwaiter's car, 1.25 x 1.36 x 1.25 round its floor's middle
    (Puzzles/Dumbwaiter's CarFloor), open at the front: an oak floor with a
    brass lip, board sides, a back and a top; an iron bail over it and the
    rope it hangs from, running up into the shaft."""
    oak = _oak("CarOak")
    oak_x = _oak("CarOakAcross", "X")
    oak_z = _oak("CarBoard", "Y")
    iron = _iron("CarIron")
    brass = materials.brass("CarBrass", color=(170, 136, 78), roughness=0.35)
    rope = materials.fabric("CarRope", color=(146, 124, 88), roughness=0.95)
    c = 1.25
    parts = [
        materials.assign(_box("Floor", (c, 0.1, c), (0, 0, 0), 0.015, 2), oak_x),
        materials.assign(_box("Back", (c, 1.26, 0.07), (0, 0.68, -c / 2 + 0.035), 0.01, 1), oak),
        materials.assign(_box("Top", (c, 0.08, c), (0, 1.31, 0), 0.015, 2), oak_x),
        materials.assign(_box("Lip", (c - 0.16, 0.04, 0.03), (0, 0.07, c / 2 - 0.02), 0.008), brass),
    ]
    for sx in (-1, 1):
        for y0, y1 in ((0.05, 0.63), (0.69, 1.27)):
            parts.append(materials.assign(_box("Board", (0.06, y1 - y0, c - 0.12), (sx * (c / 2 - 0.03), (y0 + y1) / 2, -0.02), 0.01, 1), oak_z))
        parts.append(materials.assign(_box("Post", (0.07, 1.26, 0.07), (sx * (c / 2 - 0.035), 0.68, c / 2 - 0.035), 0.012, 2), oak))
    bail = [(-0.36, 1.35, 0.0), (-0.3, 1.5, 0.0), (-0.16, 1.6, 0.0), (0.0, 1.63, 0.0), (0.16, 1.6, 0.0), (0.3, 1.5, 0.0), (0.36, 1.35, 0.0)]
    parts.append(materials.assign(_tube("Bail", bail, 0.026, 8), iron))
    for sx in (-1, 1):
        parts.append(materials.assign(_box("Strap", (0.1, 0.04, 0.3), (sx * 0.36, 1.37, 0), 0.01), iron))
    parts.append(materials.assign(_ring("Thimble", 0.05, 0.016, (0, 1.69, 0), (90, 0, 0), 12, 6), iron))
    parts.append(materials.assign(_tube("Rope", [(0, 1.72, 0), (0, 2.6, 0.0), (0, 3.6, 0.0)], 0.032, 8), rope))
    piece = shapes.join(parts, "DumbwaiterCar")
    piece["bake_size"] = 512
    return piece


def jam_box():
    """The jam box under the dumbwaiter's crank, 0.7 x 0.5 x 0.7 round its
    middle (Puzzles/Dumbwaiter's JamBox), the casing at its left: an open
    iron cradle bolted to the casing, and the brake rod from it up to the
    wheel's rim: something heavy wedged in the cradle holds the brake on."""
    iron = _iron("JamIron")
    worn = _iron("JamWorn", (74, 70, 64), 0.4, 0.2)
    parts = [materials.assign(_box("Bottom", (0.7, 0.06, 0.7), (0, -0.22, 0), 0.015), iron)]
    for sx in (-1, 1):
        parts.append(materials.assign(_box("Wall", (0.05, 0.46, 0.7), (sx * 0.325, 0.0, 0), 0.012), iron))
        parts.append(materials.assign(_box("Wall", (0.6, 0.46, 0.05), (0, 0.0, sx * 0.325), 0.012), iron))
        parts.append(materials.assign(_box("Bracket", (0.16, 0.08, 0.1), (-0.41, 0.12, sx * 0.2), 0.012), iron))
    parts.append(materials.assign(_box("Flange", (0.78, 0.04, 0.78), (0, 0.23, 0), 0.01), worn))
    parts.append(materials.assign(_box("Hole", (0.66, 0.05, 0.66), (0, 0.235, 0), 0.0), _dark("JamDark", (14, 12, 10))))
    # The brake: a rod from the cradle up to a shoe under the wheel's rim.
    parts.append(materials.assign(_tube("Rod", [(-0.3, 0.2, 0.0), (-0.33, 1.0, 0.0), (-0.35, 1.74, 0.0)], 0.024, 8), iron))
    parts.append(materials.assign(_box("Shoe", (0.07, 0.05, 0.26), (-0.35, 1.765, 0), 0.012), worn))
    parts.append(materials.assign(_box("Guide", (0.1, 0.06, 0.08), (-0.38, 1.0, 0), 0.012), iron))
    parts += _studs("Bolt", [(-0.49, 0.12, sx * 0.2) for sx in (-1, 1)], 0.03, worn)
    piece = shapes.join(parts, "JamBox")
    piece["bake_size"] = 256
    return piece


def hand_wheel():
    """A crank's hand wheel, 1.06 across round its middle (the crank doors'
    Wheel, Services/CrankService; the dumbwaiter's, smaller), its face
    toward +z: a cast-iron rim on five curved spokes, the hub, the axle
    back to the wall, a turned wooden grip on its pin. The game turns it
    about z as the shutter or the car rises."""
    iron = _iron("WheelIron")
    worn = _iron("WheelWorn", (78, 72, 64), 0.35, 0.2)
    grip = _oak("WheelGrip", "Y", roughness=0.3)
    radius = 0.48
    parts = [materials.assign(_ring("Rim", radius, 0.05, (0, 0, 0), (90, 0, 0), 40, 8), worn)]
    for k in range(5):
        a0 = math.tau * k / 5
        pts = []
        for i in range(7):
            r = 0.08 + (radius - 0.09) * i / 6
            a = a0 + 0.35 * math.sin(math.pi * i / 6)
            pts.append((r * math.sin(a), r * math.cos(a), 0.0))
        parts.append(materials.assign(_tube("Spoke", pts, [0.036, 0.032, 0.028, 0.026, 0.026, 0.028, 0.032], 8), iron))
    parts.append(materials.assign(shapes.roll("Hub", 0.16, 0.1, G(0, 0, 0.01), axis="Y", steps=16), iron))
    parts.append(materials.assign(shapes.roll("Axle", 0.17, 0.045, G(0, 0, -0.1), axis="Y", steps=12), worn))
    parts.append(materials.assign(shapes.roll("Nut", 0.04, 0.06, G(0, 0, 0.1), axis="Y", steps=6), worn))
    # The grip on its pin, on the rim.
    gx = 0.39
    parts.append(materials.assign(shapes.roll("Boss", 0.08, 0.055, G(gx, 0, 0.04), axis="Y", steps=12), iron))
    handle = _lathe("Grip", [(0.0, 0.0), (0.035, 0.0), (0.05, 0.05), (0.045, 0.16), (0.052, 0.27), (0.04, 0.31), (0.0, 0.32)], steps=14)
    parts.append(materials.assign(shapes.turn(handle, (90, 0, 0), G(gx, 0, 0.08)), grip))
    piece = shapes.join(parts, "HandWheel")
    piece["bake_size"] = 256
    return piece


# The crank door (Services/CrankService) ------------------------------------------

SLAT_W, SLAT_H = 6.6, 0.45  # the shutter's width (the doorway's and 0.6); a slat's pitch


def shutter_slat():
    """One slat of a crank door's roller shutter, 6.6 x 0.45 x 0.23 round its
    middle (the game stacks them from the bottom bar up, and those rolled
    into the box are hidden): dark stained oak, bowed out at the front, a
    V-groove where it meets the next."""
    wood = materials.wood("SlatOak", (40, 30, 22), (78, 60, 42), grain_axis="X", scale=1.2, roughness=0.5)
    # (The section in the game's (z out, y up), round the slat's middle.)
    section = [(-0.035, -0.225), (0.06, -0.205), (0.105, -0.14), (0.12, -0.05), (0.12, 0.05), (0.105, 0.14), (0.06, 0.205), (-0.035, 0.225), (-0.09, 0.205), (-0.1, 0.0), (-0.09, -0.205)]
    slat = shapes.moulding("Slat", [(-z, y) for z, y in section], SLAT_W)
    piece = shapes.join([materials.assign(slat, wood)], "ShutterSlat")
    piece["bake_size"] = 256
    return piece


def shutter_bar():
    """The shutter's bottom bar, 6.7 x 0.3 x 0.42 round its middle (the
    game's BottomBar): a steel angle shod with rubber, a lifting handle
    either side on both faces."""
    steel = _iron("BarSteel", (52, 52, 54), 0.45, 0.4)
    rubber = _dark("BarRubber", (18, 18, 18), 0.9)
    parts = [
        materials.assign(_box("Rail", (6.7, 0.22, 0.3), (0, 0.04, 0), 0.03, 2), steel),
        materials.assign(_box("Flange", (6.7, 0.05, 0.42), (0, -0.095, 0), 0.015), steel),
        materials.assign(_box("Seal", (6.6, 0.05, 0.12), (0, -0.135, 0), 0.02), rubber),
    ]
    for x in (-1.6, 1.6):
        for sz in (-1, 1):
            pts = [(x - 0.24, 0.02, sz * 0.15), (x - 0.22, 0.02, sz * 0.27), (x + 0.22, 0.02, sz * 0.27), (x + 0.24, 0.02, sz * 0.15)]
            parts.append(materials.assign(_tube("Handle", pts, 0.026, 8), steel))
    piece = shapes.join(parts, "ShutterBar")
    piece["bake_size"] = 512
    return piece


def roller_box():
    """The roller box over a crank door, 6.9 x 0.9 x 1.1 round its middle
    (the game's RollerBox): a rounded steel hood in old green-grey paint,
    riveted along both faces, a round end plate with the roller's bearing
    at each end, a maker's plate, the dark slot the shutter rolls into."""
    paint = materials.paint("RollerPaint", color=(58, 64, 58), roughness=0.5, grime=0.5)
    iron = _iron("RollerIron")
    brass = materials.brass("RollerPlate", color=(150, 124, 70), roughness=0.4)
    parts = [materials.assign(_box("Hood", (6.9, 0.9, 1.1), (0, 0, 0), 0.28, 5), paint)]
    for sx in (-1, 1):
        parts.append(materials.assign(shapes.roll("End", 0.06, 0.56, G(sx * 3.47, 0, 0), axis="X", steps=28), paint))
        parts.append(materials.assign(shapes.roll("Bearing", 0.1, 0.15, G(sx * 3.53, 0, 0), axis="X", steps=16), iron))
        for k in range(6):
            a = math.tau * k / 6
            parts += _studs("Bolt", [(sx * 3.505, 0.38 * math.sin(a), 0.38 * math.cos(a))], 0.03, iron)
    for sz in (-1, 1):
        for y in (0.3, -0.3):
            parts += _studs("Rivet", [(-3.1 + 0.4 * k, y, sz * 0.55) for k in range(16)], 0.026, paint)
        parts.append(materials.assign(_box("Plate", (0.9, 0.24, 0.015), (0, 0.04, sz * 0.555), 0.006), brass))
    parts.append(materials.assign(_box("Slot", (6.6, 0.01, 0.34), (0, -0.452, 0), 0.0), _dark("RollerSlot", (10, 10, 10), 0.9)))
    piece = shapes.join(parts, "RollerBox")
    piece["bake_size"] = 512
    return piece


def crank_plate():
    """The crank's wall plate, 1.3 x 1.3 round its middle (the game's Plate,
    its back on the wall, its front +z here): a cast-iron plate with a
    stepped edge, four bolts, the gear's round housing the wheel's axle
    runs into, the ratchet's toothed ring and its pawl on a spring."""
    iron = _iron("PlateIron")
    worn = _iron("PlateWorn", (78, 72, 64), 0.35, 0.2)
    parts = [
        materials.assign(_box("Plate", (1.3, 1.3, 0.06), (0, 0, -0.045), 0.02, 2), iron),
        materials.assign(_box("Step", (1.16, 1.16, 0.03), (0, 0, -0.005), 0.012, 2), iron),
        materials.assign(shapes.roll("Housing", 0.1, 0.34, G(0, 0, 0.06), axis="Y", steps=28), iron),
    ]
    for k in range(16):
        tooth = _box("Tooth", (0.07, 0.06, 0.04), (0, 0, 0), 0.006)
        a = 360 * k / 16
        r = 0.3
        shapes.turn(tooth, (0, a, 0), G(r * math.sin(math.radians(a)), r * math.cos(math.radians(a)), 0.13))
        parts.append(materials.assign(tooth, worn))
    pawl = _box("Pawl", (0.06, 0.34, 0.035), (0, 0, 0), 0.01)
    parts.append(materials.assign(shapes.turn(pawl, (0, -40, 0), G(0.38, 0.38, 0.12)), worn))
    parts.append(materials.assign(shapes.roll("Pivot", 0.06, 0.04, G(0.48, 0.5, 0.1), axis="Y", steps=8), worn))
    coil = [(0.5 + 0.03 * math.cos(t), 0.36 + t * 0.012, 0.1 + 0.03 * math.sin(t)) for t in [i * 0.6 for i in range(14)]]
    parts.append(materials.assign(_tube("Spring", coil, 0.008, 5, caps=False), iron))
    parts += _studs("Bolt", [(sx * 0.53, sy * 0.53, 0.01) for sx in (-1, 1) for sy in (-1, 1)], 0.045, worn)
    piece = shapes.join(parts, "CrankPlate")
    piece["bake_size"] = 256
    return piece


def shutter_latch():
    """The latch inside a crank door, 0.5 x 0.9 round its plate's middle (the
    game's Plate, its back on the wall, its front +z here): an iron plate,
    a keeper, and the drop latch's lever hanging from its pivot."""
    iron = _iron("LatchIron")
    worn = _iron("LatchWorn", (86, 78, 66), 0.35, 0.2)
    parts = [
        materials.assign(_box("Plate", (0.5, 0.9, 0.06), (0, 0, -0.03), 0.015, 2), iron),
        materials.assign(_box("Keeper", (0.3, 0.12, 0.08), (0, -0.3, 0.04), 0.012), iron),
        materials.assign(shapes.roll("Pivot", 0.1, 0.05, G(0, 0.3, 0.05), axis="Y", steps=10), worn),
        materials.assign(_tube("Lever", [(0, 0.3, 0.1), (0, 0.1, 0.13), (0, -0.12, 0.15)], 0.03, 8), worn),
        materials.assign(_sphere("Ball", 0.05, (0, -0.15, 0.15), 10, 5), worn),
    ]
    parts += _studs("Bolt", [(sx * 0.17, sy * 0.37, 0.0) for sx in (-1, 1) for sy in (-1, 1)], 0.03, worn)
    piece = shapes.join(parts, "ShutterLatch")
    piece["bake_size"] = 128
    return piece


# The laundry chute (Services/ChuteService) ---------------------------------------


def chute_hatch():
    """The laundry chute's hatch in an upstairs wall, 2.9 x 2.5 round its
    frame's middle (the game's Frame, its back on the wall, its front +z
    here): almond-enamelled steel, a pressed surround, the door with a
    raised field, hinged along its foot, a chrome pull bar and a catch."""
    enamel = materials.paint("ChuteEnamel", color=(222, 210, 186), roughness=0.35, grime=0.35)
    edge = materials.paint("ChuteEdge", color=(196, 184, 160), roughness=0.4, grime=0.4)
    chrome = materials.brass("ChuteChrome", color=(190, 192, 194), roughness=0.2)
    surround = shapes.frame("Surround", 2.9, 2.5, [(0.0, 0.0), (0.0, 0.05), (0.03, 0.1), (0.13, 0.1), (0.16, 0.07), (0.16, 0.0)])
    parts = [materials.assign(shapes.turn(surround, (0, 0, 0), G(0, 0, -0.06)), edge)]
    parts.append(materials.assign(_box("Door", (2.58, 2.18, 0.06), (0, 0, 0.0), 0.02, 2), enamel))
    parts.append(materials.assign(_box("Field", (2.1, 1.5, 0.025), (0, -0.05, 0.04), 0.018, 3), enamel))
    parts.append(materials.assign(shapes.roll("Hinge", 2.3, 0.028, G(0, -1.07, 0.04), axis="X", steps=10), chrome))
    pull = [(-0.4, 0.82, 0.03), (-0.4, 0.82, 0.14), (-0.36, 0.82, 0.18), (0.36, 0.82, 0.18), (0.4, 0.82, 0.14), (0.4, 0.82, 0.03)]
    parts.append(materials.assign(_tube("Pull", pull, 0.028, 8), chrome))
    for sx in (-1, 1):
        parts.append(materials.assign(shapes.roll("Foot", 0.03, 0.05, G(sx * 0.4, 0.82, 0.04), axis="Y", steps=10), chrome))
    parts.append(materials.assign(_box("Catch", (0.2, 0.08, 0.03), (0, 1.03, 0.04), 0.01), chrome))
    piece = shapes.join(parts, "ChuteHatch")
    piece["bake_size"] = 512
    return piece


def chute_mouth():
    """The chute's mouth over the laundry, 2.6 x 1.4 x 1.2 round its middle
    (the game's Mouth, its back on the wall, its front +z here): a
    galvanised hood out of the wall with riveted seams, its dark throat,
    and the flap hung from its top, swung a little open."""
    galv = _galv("MouthGalv")
    dark = _dark("MouthThroat", (16, 15, 14), 0.9)
    w, h, d = 2.6, 1.4, 1.2
    parts = [
        materials.assign(_box("Top", (w, 0.04, d), (0, h / 2 - 0.02, 0), 0.008), galv),
        materials.assign(_box("Floor", (w, 0.04, d), (0, -h / 2 + 0.02, 0), 0.008), galv),
        materials.assign(_box("Throat", (w - 0.1, h - 0.1, 0.02), (0, 0, -d / 2 + 0.03), 0.0), dark),
    ]
    for sx in (-1, 1):
        parts.append(materials.assign(_box("Cheek", (0.04, h, d), (sx * (w / 2 - 0.02), 0, 0), 0.008), galv))
    # A rolled lip round the mouth, and seams along its top.
    for size, at in (((w + 0.06, 0.06, 0.06), (0, h / 2, d / 2)), ((w + 0.06, 0.06, 0.06), (0, -h / 2, d / 2)), ((0.06, h, 0.06), (-w / 2, 0, d / 2)), ((0.06, h, 0.06), (w / 2, 0, d / 2))):
        parts.append(materials.assign(_box("Lip", size, at, 0.02, 2), galv))
    for x in (-0.65, 0.65):
        parts.append(materials.assign(_box("Seam", (0.03, 0.02, d), (x, h / 2 + 0.01, 0), 0.006), galv))
        parts += _studs("Rivet", [(x, h / 2 + 0.02, -0.45 + 0.3 * k) for k in range(4)], 0.018, galv)
    flap = _box("Flap", (w - 0.2, 1.1, 0.04), (0, -0.55, 0), 0.01)
    parts.append(materials.assign(shapes.turn(flap, (-12, 0, 0), G(0, 0.45, d / 2 + 0.04)), galv))
    parts.append(materials.assign(shapes.roll("Hinge", w - 0.2, 0.025, G(0, 0.45, d / 2 + 0.04), axis="X", steps=8), galv))
    piece = shapes.join(parts, "ChuteMouth")
    piece["bake_size"] = 512
    return piece


def _wicker(name, color=(168, 134, 88)):
    """Woven cane: weavers round the basket over upright stakes, its colour
    and bump from the weave."""
    mat = bpy.data.materials.new(name)
    n = materials.Nodes(mat)
    m = n.mapping(scale=(1.0, 1.0, 1.0))
    weft = n.add("ShaderNodeTexWave", wave_type="BANDS", bands_direction="Z")
    weft.inputs["Scale"].default_value = 4.5
    n.link(m.outputs["Vector"], weft.inputs["Vector"])
    stakes = []
    for axis in ("X", "Y"):
        s = n.add("ShaderNodeTexWave", wave_type="BANDS", bands_direction=axis)
        s.inputs["Scale"].default_value = 1.3
        n.link(m.outputs["Vector"], s.inputs["Vector"])
        stakes.append(s)
    both = n.math("ADD", stakes[0].outputs["Fac"], stakes[1].outputs["Fac"])
    # Over and under: each weaver shows between the stakes it passes over,
    # alternate rows offset (a checker a stake wide and a weaver tall).
    cells = n.add("ShaderNodeMapping")
    cells.inputs["Scale"].default_value = (6.25, 6.25, 14.3)
    n.link(n.coord.outputs["Object"], cells.inputs["Vector"])
    checker = n.add("ShaderNodeTexChecker")
    checker.inputs["Scale"].default_value = 1.0
    n.link(cells.outputs["Vector"], checker.inputs["Vector"])
    over = n.math("MULTIPLY_ADD", checker.outputs["Fac"], 0.65, 0.35)
    lift = n.math("MULTIPLY_ADD", both.outputs["Value"], 0.05, over.outputs["Value"])
    weave = n.math("MULTIPLY", weft.outputs["Fac"], lift.outputs["Value"])
    base = materials._srgb(color)
    dark = tuple(c * 0.45 for c in base[:3]) + (1.0,)
    ramp = n.ramp(weave.outputs["Value"], [(0.0, dark), (0.55, base), (1.0, tuple(min(1.0, c * 1.2) for c in base[:3]) + (1.0,))])
    n.link(ramp.outputs["Color"], n.bsdf.inputs["Base Color"])
    n.bsdf.inputs["Roughness"].default_value = 0.75
    n.bump(weave.outputs["Value"], 0.5)
    return mat


def laundry_basket():
    """The basket under the chute, 2.6 x 1.6 x 2 round its middle (the game's
    Basket; its Linen too), its front +z: a wicker hamper, wider at the rim,
    a rolled rim and a loop handle at each end, heaped with sheets and
    towels, one hanging over its front."""
    cane = _wicker("BasketCane")
    rim_cane = _wicker("BasketRim", (150, 118, 76))
    linen = materials.fabric("BasketSheet", color=(222, 216, 202))
    blue = materials.fabric("BasketTowel", color=(146, 166, 186))
    rose = materials.fabric("BasketPink", color=(198, 160, 150))
    w, h, d = 2.6, 1.6, 2.0
    rings = []
    for k in range(6):
        t = k / 5
        rw = (w - 0.24) + 0.24 * t
        rd = (d - 0.2) + 0.2 * t
        rings.append(_rounded_rect(rw, rd, 0.2, -h / 2 + 0.03 + (h - 0.1) * t, 4, bulge=0.025 * math.sin(math.pi * t)))
    wall = _loft("Wall", rings, close_bottom=True)
    _solid(wall, 0.05)
    parts = [materials.assign(wall, cane)]
    # Its stakes: canes standing up round the outside, the weave between them.
    foot = _rounded_rect(w - 0.24, d - 0.2, 0.2, -h / 2 + 0.03, 4)
    head = _rounded_rect(w, d, 0.2, h / 2 - 0.08, 4)
    # (Spaced evenly round the rim, by length, not by the ring's points.)
    ring_len = len(foot)
    edges = [math.dist(head[i], head[(i + 1) % ring_len]) for i in range(ring_len)]
    count = 44
    step = sum(edges) / count
    for k in range(count):
        i, along = 0, k * step
        while along > edges[i]:
            along -= edges[i]
            i += 1
        t = along / edges[i]
        a0, a1 = foot[i], foot[(i + 1) % ring_len]
        b0, b1 = head[i], head[(i + 1) % ring_len]
        lo = tuple(a0[j] + (a1[j] - a0[j]) * t for j in range(3))
        hi = tuple(b0[j] + (b1[j] - b0[j]) * t for j in range(3))
        # (Just outside the wall: pushed out from the middle.)
        def out(pt, by=1.025):
            return (pt[0] * by, pt[1], pt[2] * by)
        mid = tuple((lo[j] + hi[j]) / 2 for j in range(3))
        parts.append(materials.assign(_tube("Stake", [out(lo), out(mid, 1.04), out(hi)], 0.024, 6), rim_cane))
    rim = _rounded_rect(w, d, 0.2, h / 2 - 0.06, 4)
    parts.append(materials.assign(_tube("Rim", rim + rim[:1], 0.055, 8, caps=False), rim_cane))
    for sx in (-1, 1):
        loop = [(sx * w / 2, h / 2 - 0.06, -0.32), (sx * (w / 2 + 0.07), h / 2 + 0.08, -0.2), (sx * (w / 2 + 0.09), h / 2 + 0.14, 0.0), (sx * (w / 2 + 0.07), h / 2 + 0.08, 0.2), (sx * w / 2, h / 2 - 0.06, 0.32)]
        parts.append(materials.assign(_tube("Handle", loop, 0.04, 8), rim_cane))
    # The washing heaped in it.
    for size, at, mat in (
        ((1.3, 0.55, 1.1), (-0.5, 0.62, -0.3), linen),
        ((1.2, 0.5, 1.0), (0.55, 0.6, 0.2), rose),
        ((1.1, 0.6, 0.9), (0.1, 0.78, -0.25), linen),
        ((0.9, 0.42, 0.8), (-0.55, 0.66, 0.45), blue),
    ):
        lump = shapes.cushion("Washing", (size[0], size[2], size[1]), (0, 0, 0), puff=0.14, levels=2, roundness=0.6)
        parts.append(materials.assign(shapes.turn(lump, (0, 0, (at[0] * 37) % 30 - 15), G(*at)), mat))

    # A towel over the front, from inside, over the rim, down the outside.
    def towel(uu, vv):
        x = -0.15 + 0.85 * uu
        fold = 0.03 * math.sin(uu * math.pi * 5)
        if vv < 0.35:
            t = vv / 0.35
            return G(x, 0.6 + 0.22 * t, d / 2 - 0.3 + 0.32 * t + fold)
        if vv < 0.5:
            t = (vv - 0.35) / 0.15
            return G(x, 0.82 + 0.03 * math.sin(t * math.pi), d / 2 + 0.02 + 0.1 * t + fold)
        t = (vv - 0.5) / 0.5
        return G(x, 0.82 - 0.75 * t, d / 2 + 0.12 + 0.02 * t + fold * (1 + t))

    bm = bmesh.new()
    cols, rows = 16, 10
    grid = [[bm.verts.new(towel(i / cols, j / rows)) for i in range(cols + 1)] for j in range(rows + 1)]
    for j in range(rows):
        for i in range(cols):
            bm.faces.new((grid[j][i], grid[j][i + 1], grid[j + 1][i + 1], grid[j + 1][i]))
    cloth = _new("Towel", bm)
    _solid(cloth, 0.025)
    parts.append(materials.assign(shapes.smooth(cloth, 60), blue))
    piece = shapes.join(parts, "LaundryBasket")
    piece["bake_size"] = 1024
    return piece


def chute_trapdoor():
    """The chute's trapdoor in an upstairs floor, 2.9 x 2.9 round its frame's
    middle (the game's Frame, flush on the floor; its ring toward +z): a
    steel frame, a hatch of oak boards bound in steel, two strap hinges,
    a brass ring lying in its recessed cup."""
    oak = _oak("TrapOak", "Y", roughness=0.5)
    steel = _iron("TrapSteel", (60, 60, 58), 0.45, 0.4)
    brass = materials.brass("TrapBrass", color=(170, 136, 78), roughness=0.35)
    s = 2.6
    surround = shapes.frame("Surround", 2.9, 2.9, [(0.0, 0.0), (0.0, 0.04), (0.15, 0.04), (0.15, 0.0)])
    # (Laid flat, its face up.)
    parts = [materials.assign(shapes.turn(surround, (-90, 0, 0), G(0, -0.01, 0)), steel)]
    for k in range(5):
        x = -s / 2 + s / 5 * (k + 0.5)
        parts.append(materials.assign(_box("Board", (s / 5 - 0.03, 0.05, s - 0.1), (x, 0.03, 0), 0.01, 1), oak))
    for z in (-s / 2 + 0.06, s / 2 - 0.06):
        parts.append(materials.assign(_box("Band", (s, 0.055, 0.1), (0, 0.032, z), 0.01), steel))
    for x in (-0.75, 0.75):
        parts.append(materials.assign(_box("Strap", (0.16, 0.012, 1.2), (x, 0.062, -s / 2 + 0.6), 0.004), steel))
        parts += _studs("Nail", [(x, 0.068, -s / 2 + 0.25 + 0.3 * k) for k in range(4)], 0.022, steel)
        parts.append(materials.assign(shapes.roll("Knuckle", 0.2, 0.035, G(x, 0.04, -s / 2 - 0.02), axis="X", steps=8), steel))
    parts.append(materials.assign(_box("Cup", (0.5, 0.012, 0.42), (0, 0.06, 0.8), 0.006), _dark("TrapCup", (30, 26, 22))))
    parts.append(materials.assign(_ring("Ring", 0.17, 0.022, (0, 0.075, 0.8), segments=24), brass))
    parts.append(materials.assign(_box("Staple", (0.08, 0.03, 0.06), (0, 0.07, 0.62), 0.008), brass))
    piece = shapes.join(parts, "ChuteTrapdoor")
    piece["bake_size"] = 512
    return piece


def chute_duct():
    """The chute's duct out of the laundry's ceiling, 2.6 x 1.2 x 2.6 round
    its middle (the game's Mouth under a trapdoor): galvanised sheet with a
    collar at the ceiling, riveted corners, a rolled lip, the dark shaft
    up inside it."""
    galv = _galv("DuctGalv")
    dark = _dark("DuctThroat", (16, 15, 14), 0.9)
    s, h = 2.6, 1.2
    parts = [materials.assign(_box("Throat", (s - 0.1, 0.02, s - 0.1), (0, h / 2 - 0.05, 0), 0.0), dark)]
    for sx in (-1, 1):
        parts.append(materials.assign(_box("Wall", (0.04, h, s), (sx * (s / 2 - 0.02), 0, 0), 0.008), galv))
        parts.append(materials.assign(_box("Wall", (s, h, 0.04), (0, 0, sx * (s / 2 - 0.02)), 0.008), galv))
    collar = shapes.frame("Collar", s + 0.36, s + 0.36, [(0.0, 0.0), (0.0, 0.05), (0.18, 0.05), (0.2, 0.0)])
    # (Flat on the ceiling, its face down.)
    parts.append(materials.assign(shapes.turn(collar, (90, 0, 0), G(0, h / 2, 0)), galv))
    lip = shapes.frame("Lip", s + 0.08, s + 0.08, [(0.0, 0.0), (0.0, 0.06), (0.1, 0.06), (0.1, 0.0)])
    parts.append(materials.assign(shapes.turn(lip, (90, 0, 0), G(0, -h / 2, 0)), galv))
    for sx in (-1, 1):
        for sz in (-1, 1):
            parts += _studs("Rivet", [(sx * (s / 2 + 0.005), -0.4 + 0.27 * k, sz * (s / 2 - 0.12)) for k in range(4)], 0.018, galv)
    piece = shapes.join(parts, "ChuteDuct")
    piece["bake_size"] = 512
    return piece


# The corridors' landmarks (World/LandmarkProps) -----------------------------------


def _shield(w, top, bottom, n=12):
    """A shield's outline, anticlockwise from its point: sides falling in a
    curve to a point, a top rising to a peak in the middle and the corners."""
    pts = []
    for k in range(n + 1):
        y = bottom + (0.0 - bottom) * k / n
        pts.append((w / 2 * (1 - (y / bottom) ** 2) ** 0.6, y))
    pts.append((w / 2, top - 0.12))
    for k in range(2 * n + 1):
        x = w / 2 - w * k / (2 * n)
        pts.append((x, top - 0.06 + 0.06 * math.cos(4 * math.pi * x / w)))
    pts.append((-w / 2, top - 0.12))
    for k in range(n, 0, -1):
        y = bottom + (0.0 - bottom) * k / n
        pts.append((-w / 2 * (1 - (y / bottom) ** 2) ** 0.6, y))
    # (The point itself once: the first point.)
    return pts[:-1] if abs(pts[-1][0]) < 1e-6 else pts


def _antler(name):
    """Antler: dark and rough at the burr, paling to bone at the tines."""
    mat = bpy.data.materials.new(name)
    n = materials.Nodes(mat)
    sep = n.add("ShaderNodeSeparateXYZ")
    n.link(n.coord.outputs["Object"], sep.inputs["Vector"])
    t = n.math("MULTIPLY_ADD", sep.outputs["Z"], 0.75, -0.45)
    m = n.mapping(scale=(1.0, 1.0, 1.0))
    ridges = n.noise(m.outputs["Vector"], 30.0, 4.0, 0.6)
    ramp = n.ramp(t.outputs["Value"], [(0.0, materials._srgb((80, 62, 44))), (0.55, materials._srgb((156, 134, 102))), (1.0, materials._srgb((224, 212, 186)))])
    n.link(ramp.outputs["Color"], n.bsdf.inputs["Base Color"])
    n.bsdf.inputs["Roughness"].default_value = 0.6
    n.bump(ridges.outputs["Fac"], 0.35)
    return mat


def stag_head():
    """A stag's head on a shield (Data/Landmarks' stag), its back on the
    wall: a walnut shield, the neck and head in short brown hide with a
    pale throat, glass eyes, the dark muzzle, ears laid back, and twelve
    points of antler spread above."""
    walnut = materials.wood("PlaqueWalnut", (50, 30, 18), (100, 62, 38), grain_axis="Z", scale=1.4, roughness=0.3)
    hide = materials.velvet("StagHide", color=(112, 80, 54))
    muzzle = materials.velvet("StagMuzzle", color=(56, 40, 30))
    pale = materials.velvet("StagThroat", color=(196, 182, 156))
    eye = materials.paint("StagEye", color=(14, 10, 8), roughness=0.06, grime=0.0)
    antler = _antler("StagAntler")
    plaque = _prism("Plaque", _shield(1.4, 0.9, -0.9), 0.0, 0.12)
    shapes.bevel(plaque, 0.03, 2, angle=30)
    parts = [materials.assign(plaque, walnut)]
    inner = _prism("Inlay", _shield(1.16, 0.74, -0.74), 0.12, 0.15)
    shapes.bevel(inner, 0.012, 2, angle=30)
    parts.append(materials.assign(inner, walnut))
    neck = _tube("Neck", [(0, -0.22, 0.1), (0, -0.1, 0.42), (0, 0.1, 0.72), (0, 0.28, 0.92)], [0.42, 0.4, 0.33, 0.28], 18)
    neck.scale = (0.78, 1.0, 1.0)
    parts.append(materials.assign(shapes.apply_transform(neck), hide))
    # The head: lofted through sections from the back of the skull to the
    # muzzle, broad and flat over the brow, narrowing to the jaw.
    sections = [(0.44, 0.84, 0.2, 0.22), (0.46, 0.98, 0.25, 0.27), (0.43, 1.14, 0.25, 0.25), (0.35, 1.36, 0.19, 0.2), (0.27, 1.56, 0.14, 0.17), (0.21, 1.72, 0.12, 0.15), (0.17, 1.84, 0.1, 0.12)]
    rings = []
    for y, z, a, b in sections:
        ring = []
        for k in range(18):
            th = math.tau * k / 18
            ring.append((a * math.sin(th) * (0.85 + 0.15 * math.cos(th)), y + b * math.cos(th), z))
        rings.append(ring)
    skull = _loft("Head", rings, close_bottom=True)
    bm = bmesh.new()
    bm.from_mesh(skull.data)
    last = [v for v in bm.verts if abs(v.co.y + 1.84) < 1e-4]
    tip = bm.verts.new(G(0, 0.16, 1.9))
    last.sort(key=lambda v: math.atan2(v.co.x, v.co.z - 0.16))
    for i in range(len(last)):
        bm.faces.new((last[i], last[(i + 1) % len(last)], tip))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(skull.data)
    bm.free()
    parts.append(materials.assign(shapes.smooth(skull, 60), hide))
    # (Made round the origin, squashed, then put in place.)
    nose = _sphere("Nose", 0.09, (0, 0, 0), 14, 7)
    nose.scale = (1.1, 0.8, 0.85)
    wet = materials.paint("StagNose", color=(24, 18, 16), roughness=0.22, grime=0.0)
    parts.append(materials.assign(shapes.turn(shapes.apply_transform(nose), (0, 0, 0), G(0, 0.17, 1.88)), wet))
    chin = _sphere("Chin", 0.1, (0, 0, 0), 12, 6)
    chin.scale = (0.8, 1.2, 0.6)
    parts.append(materials.assign(shapes.turn(shapes.apply_transform(chin), (0, 0, 0), G(0, 0.06, 1.7)), muzzle))
    throat = _sphere("Throat", 0.13, (0, 0, 0), 14, 7)
    throat.scale = (0.75, 1.0, 0.5)
    parts.append(materials.assign(shapes.turn(shapes.apply_transform(throat), (0, 0, 0), G(0, 0.24, 1.0)), pale))
    for sx in (-1, 1):
        patch = _sphere("EyePatch", 0.085, (0, 0, 0), 12, 6)
        patch.scale = (0.6, 1.0, 0.8)
        parts.append(materials.assign(shapes.turn(shapes.apply_transform(patch), (0, 0, 0), G(sx * 0.205, 0.47, 1.16)), muzzle))
        parts.append(materials.assign(_sphere("Eye", 0.062, (sx * 0.225, 0.475, 1.17), 12, 6), eye))
        ear = _sphere("Ear", 0.16, (0, 0, 0), 12, 6)
        ear.scale = (0.42, 0.25, 1.0)
        shapes.apply_transform(ear)
        parts.append(materials.assign(shapes.turn(ear, (0, sx * 58, 0), G(sx * 0.32, 0.66, 0.93)), hide))
        # The antler: a beam sweeping up and out, its tines forward and up.
        beam = [(sx * 0.13, 0.62, 0.95), (sx * 0.3, 0.95, 0.9), (sx * 0.55, 1.3, 0.85), (sx * 0.75, 1.62, 0.9), (sx * 0.86, 1.92, 1.0)]
        parts.append(materials.assign(_tube("Beam", beam, [0.058, 0.05, 0.042, 0.032, 0.02], 10), antler))
        parts.append(materials.assign(_ring("Burr", 0.06, 0.022, (sx * 0.15, 0.66, 0.945), (35, sx * -20, 0), 14, 6), antler))
        for a, b, c in (
            ((sx * 0.24, 0.83, 0.92), (sx * 0.28, 0.9, 1.1), (sx * 0.3, 1.02, 1.26)),
            ((sx * 0.46, 1.17, 0.87), (sx * 0.5, 1.3, 1.02), (sx * 0.5, 1.46, 1.12)),
            ((sx * 0.66, 1.48, 0.88), (sx * 0.64, 1.66, 0.94), (sx * 0.6, 1.86, 0.98)),
            ((sx * 0.84, 1.88, 0.99), (sx * 0.94, 1.98, 0.98), (sx * 1.0, 2.06, 0.94)),
            ((sx * 0.82, 1.86, 1.0), (sx * 0.82, 1.98, 1.08), (sx * 0.78, 2.08, 1.14)),
        ):
            parts.append(materials.assign(_tube("Tine", [a, b, c], [0.03, 0.022, 0.01], 8), antler))
    piece = shapes.join(parts, "StagHead")
    piece["bake_size"] = 1024
    return piece


def founder_portrait():
    """The founder's portrait (Data/Landmarks' big portrait), 2.6 x 3.4 round
    the frame's middle 0.3 up, its back on the wall: a broad gilt frame
    round the old man in oils (kitlib/paintings.founder). The brass plate
    under it, with his name, is the game's."""
    w, h = 2.6, 3.4
    profile = [(u * 0.2 / 0.3, d * 0.22 / 0.25) for u, d in FRAME_PROFILE]
    frame = materials.assign(shapes.frame("Frame", w, h, profile), _frame_gilt("FounderGilt"))
    shapes.turn(frame, (0, 0, 0), G(0, 0.3, 0))
    canvas = _canvas("Canvas", paintings.founder(), w - 0.4 + 0.06, h - 0.4 + 0.06, 0.05)
    shapes.turn(canvas, (0, 0, 0), G(0, 0.3, 0))
    piece = shapes.join([frame, canvas], "FounderPortrait")
    piece["bake_size"] = 1024
    return piece


def tapestry():
    """The tapestry (Data/Landmarks), 2.8 x 3.6 of cloth hung by loops from a
    gilt rod with finials on two brackets, its back near the wall: the weave
    (kitlib/paintings.tapestry) in soft vertical folds, a gold fringe along
    its hem."""
    gilt = _gilt("TapestryGilt")
    loops = materials.fabric("TapestryLoop", color=(44, 52, 86))
    fringe = materials.fabric("TapestryFringe", color=(176, 142, 74))
    w, top, bottom = 2.8, 1.95, -1.65

    def at(uu, vv):
        x = (uu - 0.5) * w
        y = top - vv * (top - bottom)
        z = 0.12 + 0.035 * math.sin(uu * math.pi * 6) * (0.4 + 0.6 * vv) + 0.03 * vv * vv
        return G(x, y, z)

    bm = bmesh.new()
    cols, rows = 48, 24
    grid = [[bm.verts.new(at(i / cols, j / rows)) for i in range(cols + 1)] for j in range(rows + 1)]
    for j in range(rows):
        for i in range(cols):
            bm.faces.new((grid[j][i], grid[j][i + 1], grid[j + 1][i + 1], grid[j + 1][i]))
    uv = bm.loops.layers.uv.new("Pattern")
    for j in range(rows + 1):
        for i in range(cols + 1):
            for loop in grid[j][i].link_loops:
                loop[uv].uv = (i / cols, 1 - j / rows)
    cloth = _new("Cloth", bm)
    _solid(cloth, 0.03)
    weave = materials.image("TapestryWeave", paintings.tapestry(), roughness=0.95, bump=0.15)
    weave["uv_share"] = 0.7
    parts = [materials.assign(shapes.smooth(cloth, 60), weave)]
    parts.append(materials.assign(shapes.roll("Rod", 3.1, 0.045, G(0, 2.0, 0.16), axis="X", steps=12), gilt))
    for sx in (-1, 1):
        fin = _lathe("Finial", [(0.0, 0.0), (0.05, 0.0), (0.08, 0.05), (0.06, 0.12), (0.02, 0.16), (0.0, 0.17)], steps=14)
        parts.append(materials.assign(shapes.turn(fin, (0, sx * 90, 0), G(sx * 1.55, 2.0, 0.16)), gilt))
        parts.append(materials.assign(_box("Bracket", (0.05, 0.05, 0.16), (sx * 1.25, 2.0, 0.08), 0.01), gilt))
        parts.append(materials.assign(shapes.roll("Rose", 0.02, 0.07, G(sx * 1.25, 2.0, 0.01), axis="Y", steps=12), gilt))
    for k in range(8):
        x = -1.225 + 2.45 * k / 7
        parts.append(materials.assign(_ring("Loop", 0.075, 0.02, (x, 2.0, 0.16), (0, 90, 0), 12, 5), loops))
    for k in range(47):
        uu = (k + 0.5) / 47
        p = at(uu, 1.0)
        x, z = p[0], -p[1]
        parts.append(materials.assign(_tube("Tassel", [(x, bottom + 0.01, z), (x, bottom - 0.08, z + 0.005), (x, bottom - 0.15, z + 0.01)], [0.012, 0.016, 0.02], 5), fringe))
    piece = shapes.join(parts, "Tapestry")
    piece["bake_size"] = 1024
    return piece


def _hand(name, outline, degrees, z):
    """A clock hand: its outline pointing up from the pivot, turned
    `degrees` clockwise from the twelve, at depth z, 0.3 up."""
    hand = _prism(name, outline, -0.008, 0.008)
    return shapes.turn(hand, (0, degrees, 0), G(0, 0.3, z))


def stopped_clock():
    """The stopped clock (Data/Landmarks), 2.4 across round its middle 0.3 up,
    its back on the wall: a deep walnut case, a brass bezel, the ivory dial
    (kitlib/paintings.clock_face) cracked across, and iron spade hands
    stopped at a quarter to three."""
    walnut = materials.wood("ClockWalnut", (48, 30, 18), (96, 60, 36), grain_axis="X", scale=1.6, roughness=0.3)
    brass = materials.brass("ClockBezel", color=(176, 142, 80), roughness=0.3)
    iron = _iron("ClockHands", (20, 18, 18), 0.4, 0.1)
    case = _lathe("Case", [(0.0, 0.0), (1.2, 0.0), (1.2, 0.12), (1.17, 0.19), (1.12, 0.23), (1.07, 0.22), (1.05, 0.18), (1.05, 0.16), (0.0, 0.16)], steps=64)
    parts = [materials.assign(shapes.turn(case, (90, 0, 0), G(0, 0.3, 0)), walnut)]
    parts.append(materials.assign(_ring("Bezel", 1.06, 0.022, (0, 0.3, 0.215), (90, 0, 0), 64, 8), brass))
    face = _dial("Dial", 1.04, paintings.clock_face(), share=0.6)
    parts.append(shapes.turn(face, (90, 0, 0), G(0, 0.3, 0.165)))
    hour = [(-0.035, -0.12), (0.035, -0.12), (0.03, 0.36), (0.085, 0.44), (0.05, 0.53), (0.0, 0.62), (-0.05, 0.53), (-0.085, 0.44), (-0.03, 0.36)]
    minute = [(-0.025, -0.16), (0.025, -0.16), (0.02, 0.62), (0.06, 0.7), (0.035, 0.8), (0.0, 0.92), (-0.035, 0.8), (-0.06, 0.7), (-0.02, 0.62)]
    parts.append(materials.assign(_hand("Hour", hour, 82.5, 0.19), iron))
    parts.append(materials.assign(_hand("Minute", minute, 270.0, 0.21), iron))
    parts.append(materials.assign(shapes.roll("Boss", 0.06, 0.05, G(0, 0.3, 0.215), axis="Y", steps=12), brass))
    piece = shapes.join(parts, "StoppedClock")
    piece["bake_size"] = 1024
    return piece


def ships_wheel():
    """A ship's wheel (Data/Landmarks), 2.6 across round its hub 0.3 up and
    0.3 out from the wall: a varnished oak rim bound with a brass ring,
    eight turned spokes running through it to their handles, a drum hub
    with a brass cap, on an oak block on the wall."""
    oak = materials.wood("WheelOak", (96, 62, 34), (156, 108, 62), grain_axis="Z", scale=1.4, roughness=0.3)
    oak_x = materials.wood("WheelOakRim", (96, 62, 34), (156, 108, 62), grain_axis="X", scale=1.4, roughness=0.3)
    brass = materials.brass("WheelBrass", color=(176, 142, 80), roughness=0.3)
    cy, cz = 0.3, 0.3
    parts = [materials.assign(_ring("Rim", 0.95, 0.07, (0, cy, cz), (90, 0, 0), 56, 10), oak_x)]
    parts.append(materials.assign(_ring("Band", 0.95, 0.02, (0, cy, cz + 0.068), (90, 0, 0), 56, 6), brass))
    profile = [(0.0, 0.2), (0.05, 0.2), (0.058, 0.32), (0.046, 0.55), (0.056, 0.75), (0.05, 0.88), (0.05, 1.02), (0.04, 1.04), (0.052, 1.1), (0.066, 1.17), (0.05, 1.24), (0.058, 1.28), (0.0, 1.31)]
    for k in range(8):
        spoke = _lathe("Spoke", profile, steps=12)
        parts.append(materials.assign(shapes.turn(spoke, (0, 45 * k, 0), G(0, cy, cz)), oak))
    hub = _lathe("Hub", [(0.0, 0.0), (0.24, 0.0), (0.26, 0.04), (0.26, 0.3), (0.24, 0.34), (0.0, 0.34)], steps=28)
    parts.append(materials.assign(shapes.turn(hub, (90, 0, 0), G(0, cy, 0.12)), oak_x))
    cap = _lathe("Cap", [(0.0, 0.0), (0.16, 0.0), (0.15, 0.03), (0.1, 0.06), (0.0, 0.07)], steps=24)
    parts.append(materials.assign(shapes.turn(cap, (90, 0, 0), G(0, cy, 0.46)), brass))
    parts.append(materials.assign(_box("Block", (0.5, 0.5, 0.12), (0, cy, 0.06), 0.03, 2), oak))
    piece = shapes.join(parts, "ShipsWheel")
    piece["bake_size"] = 1024
    return piece


FITTINGS = [
    dumbwaiter_casing,
    dumbwaiter_hatch,
    dumbwaiter_car,
    jam_box,
    hand_wheel,
    shutter_slat,
    shutter_bar,
    roller_box,
    crank_plate,
    shutter_latch,
    chute_hatch,
    chute_mouth,
    laundry_basket,
    chute_trapdoor,
    chute_duct,
    stag_head,
    founder_portrait,
    tapestry,
    stopped_clock,
    ships_wheel,
]
