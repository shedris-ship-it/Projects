"""The rest of the house's furniture (the visual rework V4c, the kit's third
rollout batch): the bedrooms (the bed, the walk-in closet and its mirrored
doors, the crib), the lockers and tall cupboards you step into, the bathroom
(the toilet, the vanity, the clawfoot bath and its shower curtain), the
kitchen (the run of cupboards and their doors, the fridge and its doors, the
range), the utility rooms (the washer, the water heater, the workbench, the
boiler, the wine rack, the cistern), the garage's car, the lantern shrine and
the front door.

Each piece stands on Z = 0, centred, its front toward -Y (Roblox's +Z, the
room). A moving piece is built round the middle of the grey-box part it
hangs on (World/PropFactory). The hiding places keep the game's gaps: the
bed's skirt to the hem, the bath's curtain parted, the louvres at the eye.

Sizes are Roblox's { x, y, z } = Blender's (x, z, y).
"""

import math
import random

import bpy

from . import materials, shapes
from .living import HEM, LOUVRE_TILT, STAND_EYE, _door, _sheet, _solid, _walnut

OAK_DARK, OAK_LIGHT = (70, 48, 30), (128, 92, 58)


def _porcelain(name, color=(222, 220, 212)):
    return materials.paint(name, color=color, roughness=0.18, grime=0.35)


def _chrome(name):
    return materials.brass(name, color=(196, 198, 200), roughness=0.16)


def _steel(name, color=(110, 122, 116), roughness=0.45, grime=0.4):
    return materials.paint(name, color=color, roughness=roughness, grime=grime)


def _drape(name, w, d, top, hem, out, sides, folds=5):
    """A cloth lying over a w x d top at height `top` and falling to `hem`
    on the `sides` it has ("front", "back", "left", "right"), bowing out by
    `out` and folding; a quarter cone at each corner where two falling sides
    meet. Solid, so it shows from inside. Returns the joined object."""
    drop = top - hem

    def side(length):
        def at(u, v):
            x = (u - 0.5) * length
            y = -out - 0.06 * v * (0.5 + 0.5 * math.sin(u * math.pi * folds * 2)) - 0.02 * math.sin(v * math.pi)
            return (x, y, top - v * drop)

        return at

    sheets = []
    place = {
        "front": (w, 0, (0, -d / 2, 0)),
        "back": (w, 180, (0, d / 2, 0)),
        "left": (d, -90, (-w / 2, 0, 0)),
        "right": (d, 90, (w / 2, 0, 0)),
    }
    for key in sides:
        length, turn, at = place[key]
        s = _sheet(name, side(length), 28, 6)
        shapes.turn(s, (0, 0, turn), at)
        sheets.append(s)
    corners = {("front", "right"): (1, -1), ("back", "right"): (1, 1), ("back", "left"): (-1, 1), ("front", "left"): (-1, -1)}
    angles = {(1, -1): (-math.pi / 2, 0.0), (1, 1): (0.0, math.pi / 2), (-1, 1): (math.pi / 2, math.pi), (-1, -1): (math.pi, 1.5 * math.pi)}
    for (a, b), (sx, sy) in corners.items():
        if a in sides and b in sides:

            def quarter(u, v, sx=sx, sy=sy):
                a0, a1 = angles[(sx, sy)]
                ang = a0 + (a1 - a0) * u
                r = out + 0.03 * v
                return (sx * w / 2 + r * math.cos(ang), sy * d / 2 + r * math.sin(ang), top - v * drop)

            sheets.append(_sheet(name + "Corner", quarter, 4, 6))
    sheets.append(shapes.box(name + "Top", (w + 2 * out, d + 2 * out, 0.01), (0, 0, top), 0.0))
    cloth = shapes.join(sheets, name)
    # (A joined object keeps its first part's origin, and shapes.turn sets
    # the location outright: put the origin back at the world's first.)
    _settle(cloth)
    _solid(cloth, 0.02)
    return shapes.smooth(cloth, 60)


def _settle(obj):
    """Bakes an object's location, rotation and scale into its mesh, so its
    origin is the world's (before moving it with shapes.turn)."""
    shapes.select_only(obj)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    return obj


# The bedroom ---------------------------------------------------------------


def bed():
    """A 1988 double bed, 7 x 5.2 x 10 (Data/Props' Bed: its headboard rises
    over its 3): a walnut headboard with turned posts and finials, a low
    footboard, pillows, and a dusty-rose candlewick bedspread falling to the
    hem down both sides and over the foot (World/PropFactory's skirt: you
    hide under the bed and look out under it)."""
    w, d = 7.0, 10.0
    wood = _walnut("BedWalnut", "Z")
    wood_x = _walnut("BedWalnutAcross", "X")
    spread = materials.upholstery("Bedspread", base=(150, 104, 104), figure=(170, 124, 120), roughness=0.92)
    linen = materials.fabric("Pillowcase", color=(222, 214, 196))
    dark = materials.paint("BedFrame", color=(34, 26, 20), roughness=0.9, grime=0.1)
    parts = []
    head, foot = 0.5, 0.4
    # The headboard: two posts and a panelled board between, a crest rail.
    for sx in (-1, 1):
        post = shapes.lathe("Post", [(0.0, 0.0), (0.22, 0.0), (0.2, 0.3), (0.18, 3.9), (0.24, 4.0), (0.2, 4.15), (0.12, 4.3), (0.2, 4.55), (0.22, 4.7), (0.14, 4.85), (0.06, 4.98), (0.0, 5.05)], (sx * (w / 2 - 0.25), d / 2 - 0.25, 0), steps=16)
        parts.append(materials.assign(post, wood))
    parts.append(materials.assign(shapes.box("Headboard", (w - 0.6, 0.16, 3.0), (0, d / 2 - 0.25, 1.4 + 1.5), 0.04, 2), wood))
    parts.append(materials.assign(shapes.box("Crest", (w - 0.5, 0.24, 0.3), (0, d / 2 - 0.25, 4.35), 0.08, 3), wood_x))
    for k in range(5):
        x = -2.4 + k * 1.2
        parts.append(materials.assign(shapes.box("Field", (0.9, 0.05, 1.9), (x, d / 2 - 0.35, 3.0), 0.04, 2), wood))
    # The low footboard (under the spread's fall) and the frame and slats.
    parts.append(materials.assign(shapes.box("Footboard", (w - 0.1, foot, 1.5), (0, -(d / 2 - 0.25 - foot / 2), 1.0 + 0.75 - 0.25), 0.04, 2), wood_x))
    parts.append(materials.assign(shapes.box("Rails", (w - 0.6, d - 1.3, 0.6), (0, 0.15, 1.3), 0.03, 2), dark))
    for sx in (-1, 1):
        for sy in (-1, 1):
            leg = shapes.box("Leg", (0.35, 0.35, 1.1), (sx * (w / 2 - 0.4), sy * (d / 2 - 0.6), 0.55), 0.04, 2)
            parts.append(materials.assign(leg, dark))
    # The spread: over the mattress top (2.9) from under the pillows to the
    # foot, down the sides and the foot to the hem.
    top = 2.92
    covered = d - head - 1.6  # from the pillows to the foot
    cy = -(d / 2) + covered / 2 + 0.05
    cloth = _drape("Spread", w - 0.4, covered, top, HEM, 0.13, ("front", "left", "right"), folds=7)
    shapes.turn(cloth, (0, 0, 0), (0, cy, 0))
    parts.append(materials.assign(cloth, spread))
    # The turned-down sheet's edge and the pillows at the head.
    parts.append(materials.assign(shapes.box("Turndown", (w - 0.3, 0.9, 0.12), (0, cy + covered / 2 - 0.3, top + 0.04), 0.05, 2), linen))
    for sx in (-1, 1):
        pillow = shapes.cushion("Pillow", (w * 0.4, 1.4, 0.55), (sx * w * 0.22, d / 2 - head - 0.85, top + 0.15), puff=0.12, roundness=0.7, levels=1)
        parts.append(materials.assign(pillow, linen))
    # The bare mattress under the pillows.
    parts.append(materials.assign(shapes.box("Mattress", (w - 0.4, 1.6, 0.9), (0, d / 2 - head - 0.8, top - 0.45), 0.12, 3), linen))
    return shapes.join(parts, "Bed")


def closet():
    """A walk-in closet, 6 x 9 x 4 (Data/Props' Closet): a painted case with
    a header over two bypass tracks, a shelf and a chrome rail inside, a few
    clothes pushed to the ends (the middle stays clear: you stand there).
    Its doors are ClosetDoor (mirrored)."""
    w, h, d = 6.0, 9.0, 4.0
    paint = materials.paint("ClosetPaint", color=(214, 208, 194), roughness=0.5, grime=0.2)
    inside = materials.paint("ClosetInside", color=(70, 64, 56), roughness=0.85, grime=0.2)
    chrome = _chrome("ClosetChrome")
    coats = [materials.upholstery("Coat%d" % k, base=c, figure=tuple(min(255, int(v * 1.1)) for v in c), roughness=0.95) for k, c in enumerate(((70, 52, 44), (52, 58, 70), (110, 90, 70), (88, 40, 44)))]
    parts = []
    parts.append(materials.assign(shapes.box("Back", (w, 0.2, h), (0, d / 2 - 0.1, h / 2), 0.0), inside))
    for sx in (-1, 1):
        parts.append(materials.assign(shapes.box("Side", (0.2, d, h), (sx * (w / 2 - 0.1), 0, h / 2), 0.03, 2), paint))
        parts.append(materials.assign(shapes.box("SideIn", (0.02, d - 0.6, h - 0.8), (sx * (w / 2 - 0.21), 0.2, h / 2), 0.0), inside))
    parts.append(materials.assign(shapes.box("Top", (w, d, 0.2), (0, 0, h - 0.1), 0.03, 2), paint))
    parts.append(materials.assign(shapes.box("Header", (w, 0.5, 0.6), (0, -(d / 2 - 0.25), h - 0.5), 0.03, 2), paint))
    parts.append(materials.assign(shapes.box("Track", (w - 0.4, 0.4, 0.06), (0, -(d / 2 - 0.25), 0.03), 0.01, 1), chrome))
    parts.append(materials.assign(shapes.box("Shelf", (w - 0.4, d - 1.2, 0.12), (0, 0.4, h - 1.3), 0.02, 2), paint))
    parts.append(materials.assign(shapes.roll("Rail", w - 0.6, 0.06, (0, 0.4, h - 1.8), axis="X", steps=10), chrome))
    rng = random.Random(9)
    for sx in (-1, 1):
        for k in range(3):
            x = sx * (w / 2 - 0.5 - k * 0.32)
            length = rng.uniform(2.8, 4.2)
            coat = shapes.lathe("Coat", [(0.0, 0.0), (0.42, 0.0), (0.46, 0.06), (0.42, length * 0.5), (0.34, length * 0.85), (0.12, length * 0.97), (0.0, length)], steps=14)
            for v in coat.data.vertices:
                v.co.x *= 0.22
            shapes.turn(coat, (0, 0, 0), (x, 0.4, h - 1.85 - length))
            parts.append(materials.assign(coat, coats[(k + (sx > 0) * 2) % len(coats)]))
            hanger = shapes.box("Hanger", (0.04, 0.8, 0.05), (x, 0.4, h - 1.92), 0.01, 1)
            parts.append(materials.assign(hanger, chrome))
    return shapes.join(parts, "Closet")


def closet_door():
    """One of the closet's bypass doors, 3.1 x 8.2 round World/PropFactory's
    Door: a painted frame round the mirror (the glass is the game's, a pane
    he can show in), its lip just over the glass's edge, a recessed pull."""
    w, h, t = 3.1, 8.2, 0.1
    paint = materials.paint("ClosetDoorPaint", color=(220, 214, 200), roughness=0.45, grime=0.2)
    chrome = _chrome("ClosetPull")
    parts = []
    gw, gh = w - 0.5, h - 0.6  # the game's glass
    lip = 0.05
    for sx in (-1, 1):
        stile = shapes.box("Stile", (0.25 + lip, 0.14, h), (sx * (w / 2 - (0.25 + lip) / 2), -0.02, 0), 0.03, 2)
        parts.append(materials.assign(stile, paint))
    for sz in (-1, 1):
        rail = shapes.box("Rail", (gw - 2 * lip + 0.02, 0.14, 0.3 + lip), (0, -0.02, sz * (h / 2 - (0.3 + lip) / 2)), 0.03, 2)
        parts.append(materials.assign(rail, paint))
    parts.append(materials.assign(shapes.box("Backing", (gw, 0.03, gh), (0, 0.035, 0), 0.0), paint))
    parts.append(materials.assign(shapes.box("Pull", (0.08, 0.06, 0.9), (w / 2 - 0.13, -0.1, 0), 0.02, 2), chrome))
    piece = shapes.join(parts, "ClosetDoor")
    piece["bake_size"] = 512
    return piece


def crib():
    """An old white crib, 5 x 4 x 3 (Data/Props' Crib): turned corner posts,
    spindle sides, a thin mattress and a worn blanket; the paint chipped."""
    w, h, d = 5.0, 4.0, 3.0
    paint = materials.paint("CribPaint", color=(206, 200, 186), roughness=0.5, grime=0.5)
    mattress = materials.fabric("CribMattress", color=(196, 200, 206))
    blanket = materials.upholstery("CribBlanket", base=(170, 186, 200), figure=(190, 200, 210), roughness=0.95)
    parts = []
    for sx in (-1, 1):
        for sy in (-1, 1):
            post = shapes.lathe("Post", [(0.0, 0.0), (0.12, 0.0), (0.1, 0.3), (0.09, h - 0.2), (0.12, h - 0.1), (0.07, h + 0.05), (0.0, h + 0.1)], (sx * (w / 2 - 0.12), sy * (d / 2 - 0.12), 0), steps=12)
            parts.append(materials.assign(post, paint))
    parts.append(materials.assign(shapes.box("Base", (w - 0.2, d - 0.2, 0.3), (0, 0, 1.2), 0.03, 2), paint))
    parts.append(materials.assign(shapes.cushion("Mattress", (w - 0.4, d - 0.4, 0.3), (0, 0, 1.5), puff=0.03), mattress))
    blanket_obj = shapes.cushion("Blanket", (w * 0.55, d - 0.5, 0.1), (0.6, 0.05, 1.68), puff=0.05, roundness=0.8)
    parts.append(materials.assign(blanket_obj, blanket))
    for sy in (-1, 1):
        y = sy * (d / 2 - 0.12)
        for i in range(-4, 5):
            parts.append(materials.assign(shapes.lathe("Spindle", [(0.0, 0.0), (0.045, 0.0), (0.05, 1.2), (0.04, h - 1.5), (0.0, h - 1.5)], (i * w / 9, y, 1.35), steps=8), paint))
        parts.append(materials.assign(shapes.box("Rail", (w - 0.24, 0.12, 0.16), (0, y, h - 0.08), 0.04, 2), paint))
        parts.append(materials.assign(shapes.box("RailLow", (w - 0.24, 0.12, 0.16), (0, y, 1.35), 0.04, 2), paint))
    for sx in (-1, 1):
        parts.append(materials.assign(shapes.box("End", (0.1, d - 0.24, h - 1.4), (sx * (w / 2 - 0.12), 0, 1.35 + (h - 1.4) / 2), 0.03, 2), paint))
    return shapes.join(parts, "Crib")


# What you step into: the locker and the tall cupboard -----------------------


def _step_in(name, w, h, d, carcass_mat, inside_mat, hook_mat):
    parts = []
    for sx in (-1, 1):
        parts.append(materials.assign(shapes.box("Side", (0.1, d, h), (sx * (w / 2 - 0.05), 0, h / 2), 0.02, 2), carcass_mat))
    parts.append(materials.assign(shapes.box("Top", (w, d, 0.2), (0, 0, h - 0.1), 0.03, 2), carcass_mat))
    parts.append(materials.assign(shapes.box("Plinth", (w - 0.2, d, 0.2), (0, 0, 0.1), 0.02, 2), carcass_mat))
    parts.append(materials.assign(shapes.box("Back", (w - 0.2, 0.1, h - 0.4), (0, d / 2 - 0.05, h / 2), 0.0), inside_mat))
    for sx in (-1, 1):
        parts.append(materials.assign(shapes.box("Lining", (0.02, d - 0.2, h - 0.4), (sx * (w / 2 - 0.11), 0.05, h / 2), 0.0), inside_mat))
    hook = shapes.box("Hook", (0.08, 0.5, 0.08), (0, d / 2 - 0.45, h - 1.2), 0.02, 1)
    parts.append(materials.assign(hook, hook_mat))
    return parts


def locker():
    """A school steel locker, 3 x 8 x 3 (Data/Props' Locker), green-grey and
    scuffed, a hook inside. Its door is LockerDoor."""
    steel = _steel("LockerSteel")
    inside = _steel("LockerInside", color=(40, 44, 46), roughness=0.6, grime=0.5)
    return shapes.join(_step_in("Locker", 3.0, 8.0, 3.0, steel, inside, _chrome("LockerHook")), "Locker")


def tall_cupboard():
    """A tall pine cupboard, 3 x 8 x 3 (Data/Props' TallCupboard), a hook
    inside. Its door is TallCupboardDoor."""
    pine = materials.wood("CupboardPine", OAK_DARK, OAK_LIGHT, grain_axis="Z", scale=1.0, roughness=0.55)
    inside = materials.paint("CupboardInside", color=(52, 40, 30), roughness=0.85, grime=0.3)
    return shapes.join(_step_in("TallCupboard", 3.0, 8.0, 3.0, pine, inside, materials.brass("CupboardHook")), "TallCupboard")


def _step_door(name, steel):
    """A step-in cupboard's door (World/PropFactory's stepIn): 2.94 x 7.7 x
    0.12, louvres in a band 1.4 high round the standing eye (0.2 + its
    STAND_EYE), six slats, the solid door 0.45 each side of them; its handle
    1.3 under the eye on the right (it hinges on the left). Built round the
    leaf below the louvres, the piece's main part."""
    w, h = 2.94, 7.7
    bottom_abs = 0.15
    eye = 0.2 + STAND_EYE - bottom_abs
    band = 1.4
    low, high = eye - band / 2, eye + band / 2
    if steel:
        handle_mat = _chrome(name + "Handle")
        face = _steel(name + "Steel", color=(118, 130, 124))
    else:
        handle_mat = materials.brass(name + "Handle")
        face = materials.wood(name + "Pine", OAK_DARK, OAK_LIGHT, grain_axis="Z", scale=1.0, roughness=0.5)
    parts = []
    b = -h / 2
    parts.append(materials.assign(shapes.box("Lower", (w, 0.12, low), (0, 0, b + low / 2), 0.02, 2), face))
    parts.append(materials.assign(shapes.box("Upper", (w, 0.12, h - high), (0, 0, b + high + (h - high) / 2), 0.02, 2), face))
    for sx in (-1, 1):
        parts.append(materials.assign(shapes.box("Stile", (0.45, 0.12, band + 0.02), (sx * (w / 2 - 0.225), 0, b + eye), 0.02, 2), face))
    pitch = band / 6
    for i in range(6):
        slat = shapes.box("Slat", (w - 0.88, 0.11, 0.045), (0, 0, 0), 0.01, 1)
        shapes.turn(slat, (-LOUVRE_TILT, 0, 0), (0, 0, b + low + pitch * (i + 0.5)))
        parts.append(materials.assign(slat, face))
    if steel:
        # Pressed vents low and high, and a number plate.
        for z in (b + 0.6, b + h - 0.6):
            for k in range(5):
                parts.append(materials.assign(shapes.box("Vent", (0.9, 0.03, 0.05), (0, -0.065, z + (k - 2) * 0.1), 0.01, 1), face))
        parts.append(materials.assign(shapes.box("Plate", (0.5, 0.02, 0.25), (0, -0.07, b + h - 1.2), 0.01, 1), handle_mat))
        handle = shapes.box("Handle", (0.12, 0.12, 0.8), (w / 2 - 0.5, -0.12, b + eye - 1.3), 0.03, 2)
    else:
        for z0, z1 in ((0.4, low - 0.4), (high + 0.4, h - 0.4)):
            parts.append(materials.assign(shapes.box("Field", (w - 0.9, 0.04, z1 - z0), (0, -0.075, b + (z0 + z1) / 2), 0.04, 2), face))
        handle = shapes.lathe("Handle", [(0.0, 0.0), (0.06, 0.0), (0.09, 0.08), (0.06, 0.12), (0.0, 0.13)], steps=12)
        shapes.turn(handle, (90, 0, 0), (w / 2 - 0.5, -0.06, b + eye - 1.3))
    parts.append(materials.assign(handle, handle_mat))
    door = shapes.join(parts, name)
    # Hang it on the leaf below the louvres (its middle `low / 2` up).
    for v in door.data.vertices:
        v.co.z -= (low / 2) - h / 2
    door.data.update()
    bpy.context.view_layer.update()
    door["bake_size"] = 512
    return door


def locker_door():
    return _step_door("LockerDoor", True)


def tall_cupboard_door():
    return _step_door("TallCupboardDoor", False)


# The bathroom ---------------------------------------------------------------


def toilet():
    """A close-coupled toilet in old white porcelain, 2.5 x 3 x 3.5 (Data/
    Props' Toilet): the bowl, a wooden seat and its lid up against the
    cistern, the cistern with a chrome lever."""
    w, h, d = 2.5, 3.0, 3.5
    china = _porcelain("ToiletChina")
    wood = materials.wood("ToiletSeat", (90, 62, 40), (140, 100, 66), grain_axis="Y", scale=1.5, roughness=0.3)
    chrome = _chrome("ToiletChrome")
    water = materials.paint("ToiletWater", color=(70, 86, 84), roughness=0.05, grime=0.0)
    parts = []
    bowl_y = -0.35
    bowl = shapes.lathe("Bowl", [(0.0, 0.0), (0.45, 0.0), (0.5, 0.2), (0.42, 0.6), (0.62, 1.2), (0.86, 1.6), (0.9, 1.72), (0.8, 1.75), (0.55, 1.3), (0.0, 1.1)], steps=28)
    for v in bowl.data.vertices:
        v.co.y *= 1.35
    shapes.turn(bowl, (0, 0, 0), (0, bowl_y, 0))
    parts.append(materials.assign(bowl, china))
    parts.append(materials.assign(shapes.cushion("Water", (1.0, 1.4, 0.04), (0, bowl_y, 1.35), puff=0.0, roundness=0.9), water))
    seat = shapes.lathe("Seat", [(0.62, 1.76), (0.92, 1.76), (0.95, 1.82), (0.9, 1.86), (0.62, 1.86)], steps=28)
    for v in seat.data.vertices:
        v.co.y *= 1.35
    shapes.turn(seat, (0, 0, 0), (0, bowl_y, 0))
    parts.append(materials.assign(seat, wood))
    lid = shapes.cushion("Lid", (1.7, 2.0, 0.08), (0, 0, 0), puff=0.0, roundness=0.95)
    shapes.turn(lid, (-80, 0, 0), (0, d / 2 - 1.05, 1.9 + 0.95))
    parts.append(materials.assign(lid, wood))
    tank = shapes.box("Cistern", (w - 0.2, 0.9, 1.5), (0, d / 2 - 0.5, 1.9 + 0.75), 0.12, 3)
    parts.append(materials.assign(tank, china))
    parts.append(materials.assign(shapes.box("TankLid", (w - 0.1, 1.0, 0.14), (0, d / 2 - 0.5, 1.9 + 1.5 + 0.07), 0.06, 3), china))
    parts.append(materials.assign(shapes.box("Lever", (0.4, 0.06, 0.06), (w / 2 - 0.45, d / 2 - 0.98, 1.9 + 1.3), 0.02, 1), chrome))
    parts.append(materials.assign(shapes.box("Pipe", (0.18, 0.18, 1.9), (0, d / 2 - 0.4, 0.95), 0.06, 2), china))
    piece = shapes.join(parts, "Toilet")
    # (Its cistern stands taller than the grey-box's: within its 3, it would
    # be a squat thing. Data/Kit `rises`.)
    return piece


def sink():
    """A bathroom vanity, 3 x 4.3 x 2.5 (Data/Props' Sink; its tap rises over
    the 3.5): a laminate cabinet with two doors, a cultured-marble top with an
    oval basin, chrome taps."""
    w, h, d = 3.0, 3.5, 2.5
    laminate = materials.wood("VanityOak", OAK_DARK, OAK_LIGHT, grain_axis="Z", scale=1.2, roughness=0.4)
    marble = materials.paint("CulturedMarble", color=(214, 206, 190), roughness=0.15, grime=0.3)
    chrome = _chrome("VanityChrome")
    dark = materials.paint("Drain", color=(30, 30, 30), roughness=0.4, grime=0.0)
    parts = []
    body = h - 0.6
    parts.append(materials.assign(shapes.box("Cabinet", (w - 0.1, d - 0.2, body - 0.2), (0, 0.1, 0.2 + (body - 0.2) / 2), 0.03, 2), laminate))
    parts.append(materials.assign(shapes.box("Kick", (w - 0.3, d - 0.4, 0.2), (0, 0.15, 0.1), 0.0), dark))
    for sx in (-1, 1):
        parts.append(materials.assign(shapes.box("Door", (w / 2 - 0.12, 0.06, body - 0.45), (sx * (w / 4 - 0.02), -(d / 2 - 0.12), 0.25 + (body - 0.45) / 2), 0.03, 2), laminate))
        parts.append(materials.assign(shapes.lathe("Knob", [(0.0, 0.0), (0.05, 0.0), (0.06, 0.06), (0.0, 0.09)], (sx * 0.2, -(d / 2 - 0.09), body - 0.45), steps=10), chrome))
    top = shapes.box("Top", (w, d, 0.6), (0, 0, body + 0.3), 0.08, 3)
    parts.append(materials.assign(top, marble))
    basin = shapes.lathe("Basin", [(0.0, 0.0), (0.7, 0.0), (0.72, 0.02), (0.0, 0.02)], steps=28)
    for v in basin.data.vertices:
        v.co.y *= 0.72
    shapes.turn(basin, (0, 0, 0), (0, -0.1, h - 0.02))
    parts.append(materials.assign(basin, materials.paint("BasinShade", color=(150, 144, 132), roughness=0.2, grime=0.3)))
    parts.append(materials.assign(shapes.lathe("Plug", [(0.0, 0.0), (0.08, 0.0), (0.08, 0.02), (0.0, 0.02)], (0, -0.1, h - 0.01), steps=10), dark))
    # Taps: a spout and two cross heads.
    parts.append(materials.assign(shapes.lathe("Riser", [(0.0, 0.0), (0.07, 0.0), (0.06, 0.55), (0.0, 0.56)], (0, d / 2 - 0.45, h), steps=12), chrome))
    spout = shapes.roll("Spout", 0.55, 0.05, (0, 0, 0), axis="Y", steps=10)
    shapes.turn(spout, (12, 0, 0), (0, d / 2 - 0.68, h + 0.5))
    parts.append(materials.assign(spout, chrome))
    for sx in (-1, 1):
        parts.append(materials.assign(shapes.lathe("Tap", [(0.0, 0.0), (0.06, 0.0), (0.06, 0.2), (0.14, 0.24), (0.14, 0.3), (0.0, 0.32)], (sx * 0.55, d / 2 - 0.45, h), steps=12), chrome))
    return shapes.join(parts, "Sink")


def bathtub():
    """A clawfoot bath, 8 x 8 x 4 (Data/Props' Bathtub, its curtain rail at 8
    over its 3): a roll-top tub on four brass claws, full of the game's
    still water; taps at one end; a rail along its front and a vinyl curtain
    drawn along it in two halves, parted in the middle (World/PropFactory's
    ShowerCurtainL and R: you stand in the bath behind it and look through
    the gap)."""
    w, h, d = 8.0, 3.0, 4.0
    enamel = _porcelain("TubEnamel", color=(226, 222, 210))
    outside = materials.paint("TubOutside", color=(150, 166, 156), roughness=0.4, grime=0.35)
    brass = materials.brass("ClawBrass")
    chrome = _chrome("TubChrome")
    vinyl = materials.fabric("ShowerVinyl", color=(200, 210, 200), roughness=0.4)
    parts = []
    # The tub: an outer shell, the bowl cut out of it.
    shell = shapes.box("Shell", (w - 0.1, d - 0.1, 2.4), (0, 0, 0.7 + 1.2), 0.55, 4)
    bowl = shapes.box("Bowl", (w - 0.8, d - 0.8, 2.6), (0, 0, 1.05 + 1.3), 0.45, 4)
    mod = shell.modifiers.new("Hollow", "BOOLEAN")
    mod.operation = "DIFFERENCE"
    mod.object = bowl
    mod.solver = "EXACT"
    shapes.select_only(shell)
    bpy.ops.object.modifier_apply(modifier=mod.name)
    bpy.data.objects.remove(bowl, do_unlink=True)
    shapes.smooth(shell, 40)
    # The inside enamel, the outside painted: by the faces' height and facing.
    # (The cut leaves the cutter's empty slot behind: cleared first.)
    shell.data.materials.clear()
    shell.data.materials.append(enamel)
    shell.data.materials.append(outside)
    for poly in shell.data.polygons:
        c = poly.center
        inner = abs(c.x) < (w - 0.8) / 2 + 0.02 and abs(c.y) < (d - 0.8) / 2 + 0.02 and c.z > 1.0
        poly.material_index = 0 if inner or c.z > h + 0.05 else 1
    parts.append(shell)
    # The roll top.
    for sy in (-1, 1):
        parts.append(materials.assign(shapes.roll("Roll", w - 0.5, 0.15, (0, sy * (d / 2 - 0.2), h + 0.02), axis="X", steps=12), enamel))
    for sx in (-1, 1):
        parts.append(materials.assign(shapes.roll("Roll", d - 0.5, 0.15, (sx * (w / 2 - 0.2), 0, h + 0.02), axis="Y", steps=12), enamel))
    for sx in (-1, 1):
        for sy in (-1, 1):
            claw = shapes.lathe("Claw", [(0.0, 0.0), (0.24, 0.0), (0.26, 0.08), (0.14, 0.3), (0.2, 0.55), (0.12, 0.75), (0.0, 0.78)], (sx * (w / 2 - 0.65), sy * (d / 2 - 0.55), 0), steps=12)
            parts.append(materials.assign(claw, brass))
    # Taps at the left end, against the wall.
    x = -w / 2 + 0.6
    parts.append(materials.assign(shapes.lathe("TapNeck", [(0.0, 0.0), (0.07, 0.0), (0.06, 0.8), (0.0, 0.82)], (x, d / 2 - 0.3, h), steps=12), chrome))
    spout = shapes.roll("Spout", 0.6, 0.06, (0, 0, 0), axis="Y", steps=10)
    shapes.turn(spout, (15, 0, 0), (x, d / 2 - 0.58, h + 0.8))
    parts.append(materials.assign(spout, chrome))
    for dx in (-0.5, 0.5):
        parts.append(materials.assign(shapes.lathe("Tap", [(0.0, 0.0), (0.06, 0.0), (0.06, 0.18), (0.15, 0.22), (0.15, 0.28), (0.0, 0.3)], (x + dx, d / 2 - 0.25, h), steps=12), chrome))
    # The rail and the curtain, at the front (World/PropFactory: z = d/2).
    rail_z = 8.0
    parts.append(materials.assign(shapes.roll("Rail", w, 0.06, (0, -(d / 2), rail_z), axis="X", steps=10), chrome))
    for sx in (-1, 1):
        x0, x1 = sx * 0.1, sx * (w / 2 - 0.05)

        def panel(u, v, x0=x0, x1=x1):
            xx = x0 + (x1 - x0) * u
            deep = 0.06 * (0.5 + 0.5 * math.sin(u * math.pi * 8))
            return (xx, -(d / 2) - deep + 0.03, rail_z - 0.1 - v * 5.0)

        sheet = _sheet("Curtain", panel, 44, 4)
        _solid(sheet, 0.025)
        parts.append(materials.assign(shapes.smooth(sheet, 70), vinyl))
        for k in range(8):
            ring = shapes.lathe("Ring", [(0.06, -0.015), (0.08, -0.015), (0.08, 0.015), (0.06, 0.015)], steps=10)
            shapes.turn(ring, (90, 0, 0), (x0 + (x1 - x0) * (k + 0.5) / 8, -(d / 2), rail_z - 0.05))
            parts.append(materials.assign(ring, chrome))
    # Stays from the rail's ends up to the ceiling.
    for sx in (-1, 1):
        parts.append(materials.assign(shapes.roll("Stay", 2.0, 0.03, (sx * (w / 2 - 0.05), -(d / 2), rail_z + 1.0), axis="Z", steps=8), chrome))
    return shapes.join(parts, "Bathtub")


# The kitchen -----------------------------------------------------------------


def counter():
    """A run of kitchen cupboards, 12 x 4.8 x 3 (Data/Props' Counter; its
    splashback rises over the 3.6): oak face frames over five bays (their
    doors are CounterDoor), a recessed kick, a speckled laminate top with a
    wood edge, a steel sink with a chrome tap a quarter in from the left
    (Data/Props' CounterSink), white tiles up the wall behind."""
    w, h, d = 12.0, 3.6, 3.0
    oak = materials.wood("CounterOak", OAK_DARK, OAK_LIGHT, grain_axis="Z", scale=1.2, roughness=0.45)
    oak_x = materials.wood("CounterOakAcross", OAK_DARK, OAK_LIGHT, grain_axis="X", scale=1.2, roughness=0.45)
    inside = materials.paint("CounterInside", color=(48, 38, 28), roughness=0.85, grime=0.3)
    laminate = materials.paint("Laminate", color=(196, 190, 172), roughness=0.3, grime=0.35)
    steel = materials.brass("SinkSteel", color=(176, 178, 176), roughness=0.3)
    chrome = _chrome("CounterTap")
    tiles = materials.brick("Splashback", color=(220, 216, 200), dark=(206, 202, 186), mortar=(150, 146, 136), scale=4.0, width=0.25, height=0.25, offset=0.0, joint=0.02)
    parts = []
    body = h - 0.3
    face = d / 2 - 0.2  # the cupboards' front, behind the doors (World/PropFactory)
    n = 5
    dw = w / n
    # Carcass: ends, the kick, a dark inside, the dividers as face-frame stiles.
    for sx in (-1, 1):
        parts.append(materials.assign(shapes.box("End", (0.15, d - 0.2, body), (sx * (w / 2 - 0.075), 0.1, body / 2), 0.02, 2), oak))
    parts.append(materials.assign(shapes.box("Kick", (w - 0.3, d - 0.6, 0.35), (0, 0.3, 0.175), 0.0), inside))
    # Hollow bays: a back, a floor on the kick, a divider between each two
    # (what's kept in one lies in its middle, World/PropFactory's spot).
    parts.append(materials.assign(shapes.box("Back", (w - 0.3, 0.1, body - 0.35), (0, d / 2 - 0.05, 0.35 + (body - 0.35) / 2), 0.0), inside))
    parts.append(materials.assign(shapes.box("Floor", (w - 0.3, d - 0.3, 0.04), (0, 0.15, 0.37), 0.0), inside))
    for i in range(1, n):
        parts.append(materials.assign(shapes.box("Divider", (0.08, d - 0.4, body - 0.4), (-w / 2 + dw * i, 0.1, 0.35 + (body - 0.35) / 2), 0.0), inside))
        parts.append(materials.assign(shapes.box("Stile", (0.14, 0.06, body - 0.35), (-w / 2 + dw * i, -(face - 0.03), 0.35 + (body - 0.35) / 2), 0.02, 2), oak))
    parts.append(materials.assign(shapes.box("RailTop", (w - 0.3, 0.06, 0.12), (0, -(face - 0.03), body - 0.06), 0.02, 2), oak_x))
    # The top, its wood edge, the sink set in it.
    sink_x, sink_w = -w / 4, min(2.6, w * 0.32)
    parts.append(materials.assign(shapes.box("Top", (w, d, 0.24), (0, 0, h - 0.12 - 0.06), 0.03, 2), laminate))
    parts.append(materials.assign(shapes.box("Edge", (w + 0.02, 0.08, 0.3), (0, -(d / 2 - 0.03), h - 0.15), 0.03, 2), oak_x))
    parts.append(materials.assign(shapes.box("SinkRim", (sink_w, d * 0.6, 0.06), (sink_x, -0.05, h - 0.02), 0.03, 2), steel))
    parts.append(materials.assign(shapes.box("SinkBowl", (sink_w - 0.4, d * 0.46, 0.02), (sink_x, -0.05, h + 0.012), 0.0), materials.paint("SinkWell", color=(96, 98, 100), roughness=0.3, grime=0.3)))
    parts.append(materials.assign(shapes.lathe("TapNeck", [(0.0, 0.0), (0.08, 0.0), (0.07, 0.9), (0.0, 0.92)], (sink_x, d / 2 - 0.55, h), steps=12), chrome))
    spout = shapes.roll("Spout", 0.75, 0.06, (0, 0, 0), axis="Y", steps=10)
    shapes.turn(spout, (8, 0, 0), (sink_x, d / 2 - 0.92, h + 0.88))
    parts.append(materials.assign(spout, chrome))
    # The splashback.
    parts.append(materials.assign(shapes.box("Splashback", (w, 0.15, 1.2), (0, d / 2 - 0.1, h + 0.6), 0.0), tiles))
    return shapes.join(parts, "Counter")


def counter_door():
    """One of the counter's cupboard doors, 2.26 x 2.89 x 0.1 round World/
    PropFactory's Door: a raised oak panel, its pull high on the right
    (they hinge on the left)."""
    w, h = 2.4 - 0.14, 3.3 - 0.41
    oak = materials.wood("CounterDoorOak", OAK_DARK, OAK_LIGHT, grain_axis="Z", scale=1.2, roughness=0.4)
    brass = materials.brass("CounterPull")
    parts = [materials.assign(shapes.box("Leaf", (w, 0.1, h), (0, 0, 0), 0.03, 2), oak)]
    parts.append(materials.assign(shapes.box("Field", (w - 0.5, 0.04, h - 0.5), (0, -0.06, 0), 0.05, 2), oak))
    # (World/PropFactory: the handle at x + dw*0.3, h - 1.1 up: from the door's middle.)
    pull = shapes.box("Pull", (0.1, 0.1, 0.45), (0.72, -0.1, (3.6 - 1.1) - (0.38 + (3.3 - 0.41) / 2)), 0.03, 2)
    parts.append(materials.assign(pull, brass))
    piece = shapes.join(parts, "CounterDoor")
    piece["bake_size"] = 512
    return piece


FRIDGE = {"w": 4.0, "h": 8.0, "d": 3.5, "split": 8.0 * 0.62}
ALMOND = (210, 198, 170)


def fridge():
    """A 1988 almond fridge-freezer, 4 x 8 x 3.5 (Data/Props' Fridge): the
    case, the white liner and glass shelves inside, the freezer's floor; its
    doors are FridgeDoorTop and FridgeDoorBottom."""
    w, h, d, split = FRIDGE["w"], FRIDGE["h"], FRIDGE["d"], FRIDGE["split"]
    case = materials.paint("FridgeEnamel", color=ALMOND, roughness=0.3, grime=0.3)
    liner = materials.paint("FridgeLiner", color=(226, 230, 228), roughness=0.35, grime=0.2)
    glass = materials.paint("FridgeGlass", color=(170, 190, 196), roughness=0.08, grime=0.1)
    parts = []
    for sx in (-1, 1):
        parts.append(materials.assign(shapes.box("Side", (0.2, d, h), (sx * (w / 2 - 0.1), 0, h / 2), 0.08, 3), case))
    parts.append(materials.assign(shapes.box("Top", (w, d, 0.25), (0, 0, h - 0.125), 0.08, 3), case))
    parts.append(materials.assign(shapes.box("Plinth", (w - 0.4, d, 0.35), (0, 0, 0.175), 0.03, 2), case))
    parts.append(materials.assign(shapes.box("Grille", (w - 0.6, 0.04, 0.25), (0, -(d / 2 + 0.01), 0.2), 0.01, 1), materials.paint("FridgeGrille", color=(40, 38, 34), roughness=0.5, grime=0.3)))
    parts.append(materials.assign(shapes.box("Back", (w - 0.4, 0.2, h - 0.6), (0, d / 2 - 0.1, h / 2), 0.0), liner))
    for sx in (-1, 1):
        parts.append(materials.assign(shapes.box("Liner", (0.02, d - 0.3, h - 0.6), (sx * (w / 2 - 0.21), 0.05, h / 2), 0.0), liner))
    parts.append(materials.assign(shapes.box("Split", (w - 0.4, d, 0.2), (0, 0, split), 0.03, 2), liner))
    for z in (0.35 + (split - 0.45) / 3, 0.35 + (split - 0.45) * 2 / 3, split + (h - 0.25 - split) / 2):
        parts.append(materials.assign(shapes.box("Shelf", (w - 0.45, d - 1.0, 0.05), (0, 0.3, z), 0.01, 1), glass))
    parts.append(materials.assign(shapes.box("Crisper", (w - 0.5, d - 1.0, 0.6), (0, 0.3, 0.68), 0.04, 2), glass))
    return shapes.join(parts, "Fridge")


def _fridge_door(name, height, handle_len, handle_z, badge):
    w = FRIDGE["w"] - 0.15
    case = materials.paint(name + "Enamel", color=ALMOND, roughness=0.3, grime=0.3)
    liner = materials.paint(name + "Liner", color=(226, 230, 228), roughness=0.35, grime=0.2)
    trim = materials.paint(name + "Trim", color=(120, 92, 60), roughness=0.4, grime=0.2)
    parts = [materials.assign(shapes.box("Door", (w, 0.12, height), (0, 0, 0), 0.08, 3), case)]
    # Its inside: the liner, a gasket, shelves for jars on the back of it.
    parts.append(materials.assign(shapes.box("Inner", (w - 0.4, 0.2, height - 0.4), (0, 0.15, 0), 0.06, 2), liner))
    for k in range(2 if height > 3.5 else 1):
        z = -height / 2 + 0.8 + k * 1.6
        parts.append(materials.assign(shapes.box("Bin", (w - 0.6, 0.35, 0.3), (0, 0.42, z), 0.03, 2), liner))
    # A woodgrain-trimmed handle down the right edge (it hinges on the left).
    parts.append(materials.assign(shapes.box("Handle", (0.18, 0.18, handle_len), (FRIDGE["w"] / 2 - 0.5, -0.15, handle_z), 0.05, 3), trim))
    if badge:
        parts.append(materials.assign(shapes.box("Badge", (0.9, 0.03, 0.22), (-0.2, -0.075, badge), 0.02, 1), _chrome(name + "Badge")))
    piece = shapes.join(parts, name)
    piece["bake_size"] = 512
    return piece


def fridge_door_top():
    """The freezer's door, 3.85 x 2.84 round World/PropFactory's DoorTop."""
    split, h = FRIDGE["split"], FRIDGE["h"]
    height = h - split - 0.2
    mid = split + (h - split) / 2 + 0.05
    return _fridge_door("FridgeDoorTop", height, 1.4, (split + 1.2) - mid, (split + 2.2) - mid)


def fridge_door_bottom():
    """The fridge's door, 3.85 x 4.61 round World/PropFactory's DoorBottom."""
    split = FRIDGE["split"]
    height = split - 0.35
    mid = (split - 0.2) / 2 + 0.2
    return _fridge_door("FridgeDoorBottom", height, 2.0, (split - 1.4) - mid, None)


def stove():
    """A 1988 almond electric range, 4 x 4.9 x 3.5 (Data/Props' Stove; its
    backguard rises over the 3.6): four coil rings on chrome drip pans, an
    oven door with a dark window and a chrome bar, a backguard with a clock
    and four knobs."""
    w, h, d = 4.0, 3.6, 3.5
    enamel = materials.paint("RangeEnamel", color=ALMOND, roughness=0.3, grime=0.35)
    dark = materials.paint("RangeDark", color=(26, 24, 22), roughness=0.4, grime=0.2)
    chrome = _chrome("RangeChrome")
    glass = materials.paint("OvenWindow", color=(24, 22, 20), roughness=0.06, grime=0.15)
    clock = materials.paint("RangeClock", color=(222, 214, 190), roughness=0.3, grime=0.1)
    parts = []
    parts.append(materials.assign(shapes.box("Body", (w, d - 0.2, h - 0.1), (0, 0.1, (h - 0.1) / 2), 0.06, 3), enamel))
    parts.append(materials.assign(shapes.box("Cooktop", (w, d, 0.1), (0, 0, h - 0.05), 0.04, 2), enamel))
    for sx in (-1, 1):
        for sy in (-1, 1):
            cx, cy = sx * w / 4, sy * d / 4
            pan = shapes.lathe("Pan", [(0.0, 0.0), (0.5, 0.0), (0.6, 0.06), (0.0, 0.03)], (cx, cy, h - 0.02), steps=20)
            parts.append(materials.assign(pan, chrome))
            for r in (0.16, 0.28, 0.4):
                ring = shapes.lathe("Coil", [(r - 0.035, 0.0), (r + 0.035, 0.0), (r + 0.035, 0.05), (r - 0.035, 0.05)], (cx, cy, h + 0.02), steps=24)
                parts.append(materials.assign(ring, dark))
    parts.append(materials.assign(shapes.box("OvenDoor", (w - 0.3, 0.12, h * 0.55), (0, -(d / 2), h * 0.4), 0.05, 3), enamel))
    parts.append(materials.assign(shapes.box("Window", (w * 0.62, 0.03, h * 0.3), (0, -(d / 2 + 0.06), h * 0.4), 0.02, 2), glass))
    parts.append(materials.assign(shapes.roll("Bar", w * 0.78, 0.05, (0, -(d / 2 + 0.2), h * 0.72), axis="X", steps=10), chrome))
    parts.append(materials.assign(shapes.box("Drawer", (w - 0.3, 0.08, 0.5), (0, -(d / 2 - 0.02), 0.35), 0.03, 2), enamel))
    parts.append(materials.assign(shapes.box("Backguard", (w, 0.4, 1.3), (0, d / 2 - 0.2, h + 0.65), 0.06, 3), enamel))
    parts.append(materials.assign(shapes.box("Panel", (w - 0.3, 0.02, 0.6), (0, d / 2 - 0.41, h + 0.7), 0.01, 1), dark))
    parts.append(materials.assign(shapes.box("Clock", (0.7, 0.03, 0.4), (0, d / 2 - 0.43, h + 0.7), 0.01, 1), clock))
    for i in (-1.5, -0.5, 0.5, 1.5):
        if abs(i) < 1:
            continue
        for k in (0, 1):
            x = i * w / 5 + (k - 0.5) * 0.35 * (1 if i > 0 else -1)
            knob = shapes.lathe("Knob", [(0.0, 0.0), (0.14, 0.0), (0.13, 0.12), (0.0, 0.14)], steps=14)
            shapes.turn(knob, (90, 0, 0), (x, d / 2 - 0.42, h + 0.65))
            parts.append(materials.assign(knob, chrome))
    return shapes.join(parts, "Stove")


# The utility rooms ------------------------------------------------------------


def washer():
    """A 1988 front-loading washer, 3.5 x 4 x 3.5 (Data/Props' Washer): white
    enamel, a chrome-ringed porthole of dark glass, a control panel with two
    dials and a row of buttons."""
    w, h, d = 3.5, 4.0, 3.5
    enamel = materials.paint("WasherEnamel", color=(222, 220, 212), roughness=0.3, grime=0.35)
    chrome = _chrome("WasherChrome")
    glass = materials.paint("WasherGlass", color=(40, 46, 48), roughness=0.05, grime=0.1)
    panel = materials.paint("WasherPanel", color=(170, 160, 140), roughness=0.35, grime=0.2)
    parts = []
    parts.append(materials.assign(shapes.box("Body", (w, d, h - 0.1), (0, 0, (h - 0.1) / 2), 0.08, 3), enamel))
    parts.append(materials.assign(shapes.box("Lid", (w, d, 0.12), (0, 0, h - 0.06), 0.05, 2), enamel))
    door_z = h * 0.45
    ring = shapes.lathe("Ring", [(0.95, 0.0), (1.25, 0.0), (1.25, 0.12), (1.15, 0.2), (0.95, 0.2)], steps=36)
    shapes.turn(ring, (90, 0, 0), (0, -(d / 2), door_z))
    parts.append(materials.assign(ring, chrome))
    porthole = shapes.lathe("Glass", [(0.0, 0.0), (1.0, 0.0), (0.9, 0.12), (0.0, 0.16)], steps=36)
    shapes.turn(porthole, (90, 0, 0), (0, -(d / 2) + 0.05, door_z))
    parts.append(materials.assign(porthole, glass))
    parts.append(materials.assign(shapes.box("Panel", (w - 0.3, 0.06, 0.7), (0, -(d / 2) - 0.01, h - 0.55), 0.03, 2), panel))
    for sx in (-1, 1):
        dial = shapes.lathe("Dial", [(0.0, 0.0), (0.2, 0.0), (0.2, 0.1), (0.15, 0.16), (0.0, 0.16)], steps=16)
        shapes.turn(dial, (90, 0, 0), (sx * 1.1, -(d / 2) - 0.04, h - 0.55))
        parts.append(materials.assign(dial, chrome))
    for k in range(4):
        parts.append(materials.assign(shapes.box("Button", (0.18, 0.06, 0.1), (-0.45 + k * 0.3, -(d / 2) - 0.05, h - 0.55), 0.02, 1), enamel))
    return shapes.join(parts, "Washer")


def water_heater():
    """A gas water heater, 3 x 7 x 3 (Data/Props' WaterHeater): a tall
    enamelled jacket streaked with rust, its gas control and the pilot's
    little window near the foot, a relief valve, pipes and the flue's hood
    at the top."""
    jacket = materials.paint("HeaterJacket", color=(180, 178, 168), roughness=0.4, grime=0.6)
    brass = materials.brass("HeaterBrass")
    copper = materials.brass("HeaterCopper", color=(150, 90, 60), roughness=0.4)
    dark = materials.paint("HeaterDark", color=(40, 38, 34), roughness=0.5, grime=0.3)
    flame = materials.paint("Pilot", color=(80, 120, 255), roughness=0.5, grime=0.0)
    flame["glow"] = 1.0
    parts = []
    parts.append(materials.assign(shapes.lathe("Jacket", [(0.0, 0.0), (1.38, 0.0), (1.42, 0.08), (1.42, 6.2), (1.36, 6.35), (0.5, 6.45), (0.0, 6.45)], steps=36), jacket))
    parts.append(materials.assign(shapes.lathe("Hood", [(0.0, 6.45), (0.35, 6.45), (0.3, 6.6), (0.6, 6.7), (0.55, 6.75), (0.25, 6.75), (0.25, 7.0), (0.0, 7.0)], steps=20), dark))
    for x in (-0.7, 0.7):
        parts.append(materials.assign(shapes.roll("Pipe", 0.55, 0.09, (x, 0.2, 6.65), axis="Z", steps=10), copper))
    parts.append(materials.assign(shapes.box("Control", (0.6, 0.4, 0.5), (0, -1.45, 1.4), 0.05, 2), dark))
    parts.append(materials.assign(shapes.lathe("Knob", [(0.0, 0.0), (0.12, 0.0), (0.12, 0.08), (0.0, 0.1)], (0, -1.5, 1.4), steps=12), brass))
    parts.append(materials.assign(shapes.box("Pilot", (0.18, 0.02, 0.12), (0, -1.43, 0.55), 0.01, 1), flame))
    parts.append(materials.assign(shapes.box("Cover", (0.8, 0.06, 0.6), (0, -1.4, 0.5), 0.02, 1), jacket))
    valve = shapes.roll("Valve", 0.5, 0.07, (0, 0, 0), axis="X", steps=10)
    shapes.turn(valve, (0, 0, 0), (1.55, 0.0, 5.6))
    parts.append(materials.assign(valve, brass))
    parts.append(materials.assign(shapes.roll("Drain", 0.3, 0.07, (0, -1.5, 0.35), axis="Y", steps=8), brass))
    return shapes.join(parts, "WaterHeater")


def workbench():
    """A workbench, 10 x 8.6 x 3.5 (Data/Props' Workbench; its pegboard rises
    over the 3.6): a thick scarred top, a shelf under it, an iron vice at the
    right end (Data/Props' keepout), a pegboard with a saw, a hammer,
    spanners, a coil of rope."""
    w, h, d = 10.0, 3.6, 3.5
    top = materials.wood("BenchTop", (90, 66, 44), (140, 104, 70), grain_axis="X", scale=0.8, roughness=0.7)
    legs = materials.wood("BenchLegs", (90, 66, 44), (140, 104, 70), grain_axis="Z", scale=1.0, roughness=0.7)
    peg = materials.paint("Pegboard", color=(160, 130, 90), roughness=0.85, grime=0.4)
    iron = materials.paint("ViceIron", color=(50, 70, 64), roughness=0.5, grime=0.5)
    steel = _chrome("ToolSteel")
    handle = materials.paint("ToolHandle", color=(150, 40, 30), roughness=0.5, grime=0.3)
    rope = materials.fabric("Rope", color=(170, 150, 110))
    parts = []
    parts.append(materials.assign(shapes.box("Top", (w, d, 0.3), (0, 0, h - 0.15), 0.05, 2), top))
    for sx in (-1, 1):
        for sy in (-1, 1):
            parts.append(materials.assign(shapes.box("Leg", (0.35, 0.35, h - 0.3), (sx * (w / 2 - 0.4), sy * (d / 2 - 0.4), (h - 0.3) / 2), 0.03, 2), legs))
    parts.append(materials.assign(shapes.box("Shelf", (w - 0.6, d - 0.6, 0.12), (0, 0, 0.7), 0.02, 2), top))
    # The vice at the right end.
    vx = w / 2 - 1
    parts.append(materials.assign(shapes.box("ViceBody", (0.8, 0.8, 0.6), (vx, -0.2, h + 0.3), 0.06, 2), iron))
    parts.append(materials.assign(shapes.box("Jaw", (0.8, 0.15, 0.4), (vx, -0.68, h + 0.4), 0.03, 2), iron))
    parts.append(materials.assign(shapes.roll("Screw", 0.9, 0.04, (vx, -0.95, h + 0.3), axis="Y", steps=8), steel))
    parts.append(materials.assign(shapes.roll("Tommy", 0.7, 0.03, (vx, -1.35, h + 0.3), axis="X", steps=8), steel))
    # The pegboard and the tools on it.
    pz = h + 3
    parts.append(materials.assign(shapes.box("Pegboard", (w, 0.12, 4.0), (0, d / 2 - 0.06, pz), 0.02, 1), peg))
    bz = d / 2 - 0.18
    parts.append(materials.assign(shapes.box("Saw", (2.2, 0.03, 0.55), (-3.0, bz, pz + 0.8), 0.01, 1), steel))
    parts.append(materials.assign(shapes.box("SawHandle", (0.5, 0.08, 0.6), (-4.2, bz, pz + 0.8), 0.04, 2), handle))
    parts.append(materials.assign(shapes.box("Hammer", (0.12, 0.1, 1.2), (-0.8, bz, pz + 0.2), 0.03, 1), handle))
    parts.append(materials.assign(shapes.box("HammerHead", (0.5, 0.14, 0.16), (-0.8, bz, pz + 0.85), 0.03, 1), steel))
    for k in range(5):
        parts.append(materials.assign(shapes.box("Spanner", (0.09, 0.04, 0.6 + k * 0.12), (0.6 + k * 0.3, bz, pz + 0.6), 0.02, 1), steel))
    coil = shapes.lathe("Rope", [(0.45, -0.08), (0.6, -0.08), (0.6, 0.08), (0.45, 0.08)], steps=24)
    shapes.turn(coil, (90, 0, 0), (3.2, bz - 0.05, pz + 0.3))
    parts.append(materials.assign(coil, rope))
    return shapes.join(parts, "Workbench")


def car(paint_color=None, woodgrain=True, name="Car", only=None):
    """The garage's car, 7 x 5 x 14 (Data/Props' Car): a 1980s station wagon
    gone dull under the dust. Its body is drawn from its side's profile and
    swept across it: a sloped hood, the wheels in their arches, a near
    upright tail. On it the glass of the long wagon cabin, its pillars and
    roof, woodgrain panels down the sides, chrome bumpers, square headlamps,
    hubcaps. Its front is -Y (the grey-box's +Z). (LB4's car-bit sketches:
    `paint_color` another paint, `woodgrain` False without the woodgrain sides;
    the defaults are the car as it's been imported. LB4's paintable car, the
    mall4 batch: `only` one of CAR_GROUPS' groups, "body", "wood" or "trim".)"""
    w, d = 7.0, 14.0
    if paint_color is None:
        paint = materials.paint("CarPaint", color=(96, 42, 36), roughness=0.3, grime=0.45)
    else:
        paint = materials.paint("CarPaint%d_%d_%d" % paint_color, color=paint_color, roughness=0.3, grime=0.45)
    wood = materials.wood("Woodgrain", (90, 60, 36), (140, 100, 64), grain_axis="Y", scale=0.7, roughness=0.3)
    chrome = _chrome("CarChrome")
    glass = materials.paint("CarGlass", color=(70, 84, 90), roughness=0.04, grime=0.3)
    rubber = materials.paint("Tyre", color=(22, 22, 22), roughness=0.9, grime=0.1)
    lamp = materials.paint("Headlamp", color=(206, 206, 192), roughness=0.08, grime=0.15)
    red = materials.paint("TailLamp", color=(130, 22, 18), roughness=0.2, grime=0.15)
    dark = materials.paint("CarDark", color=(18, 18, 18), roughness=0.8, grime=0.0)
    parts = []
    fy, ry = -(d / 2 - 2.5), d / 2 - 2.5  # the wheels' middles (World/PropFactory)
    r_arch, hub = 1.2, 1.0

    def arch(cy):
        # Over a wheel, from its back to its front (the profile runs that way).
        pts = [(cy + r_arch, 0.75)]
        for k in range(11):
            a = math.pi * k / 10
            pts.append((cy + r_arch * math.cos(a), hub + r_arch * math.sin(a)))
        pts.append((cy - r_arch, 0.75))
        return pts

    # The lower body's side (y from the front, -7, to the back; z up).
    body = [
        (-6.95, 0.75),
        (-7.0, 1.2),
        (-7.0, 2.15),
        (-6.85, 2.42),
        (-4.5, 2.62),
        (-2.6, 2.75),
        (6.5, 2.75),
        (6.92, 2.6),
        (7.0, 1.2),
        (6.95, 0.75),
    ]
    body += arch(ry) + arch(fy)
    lower = shapes.moulding("Body", body, w - 0.1)
    # (shapes.moulding sweeps a profile along X; a car's side is in Y and Z.)
    shapes.bevel(lower, 0.1, 2, angle=30)
    parts.append(materials.assign(lower, paint))
    # The cabin: glass, its windscreen raked, the tailgate near upright.
    cabin = [(-2.6, 2.75), (-1.3, 4.52), (6.2, 4.55), (6.55, 4.38), (6.6, 2.75)]
    house_obj = shapes.moulding("Cabin", cabin, w - 0.8)
    parts.append(materials.assign(house_obj, glass))
    # Its roof, the pillars between the windows, a rail along each edge.
    roof = shapes.moulding("Roof", [(-1.42, 4.48), (6.32, 4.5), (6.32, 4.66), (-1.3, 4.66)], w - 0.7)
    parts.append(materials.assign(roof, paint))
    for y, thick in ((0.5, 0.26), (3.4, 0.34)):
        parts.append(materials.assign(shapes.box("Pillar", (w - 0.74, thick, 1.8), (0, y, 3.65), 0.03, 2), paint))
    rake = math.degrees(math.atan2(1.3, 1.77))
    for sx in (-1, 1):
        a = shapes.box("APillar", (0.18, 0.18, 2.2), (0, 0, 0), 0.04, 2)
        shapes.turn(a, (-rake, 0, 0), (sx * (w / 2 - 0.45), -1.95, 3.64))
        parts.append(materials.assign(a, paint))
        parts.append(materials.assign(shapes.box("DPillar", (0.18, 0.5, 1.75), (sx * (w / 2 - 0.45), 6.32, 3.6), 0.04, 2), paint))
        parts.append(materials.assign(shapes.box("RoofRail", (0.08, 6.6, 0.08), (sx * (w / 2 - 0.6), 2.4, 4.72), 0.03, 1), chrome))
        # A wing mirror by the windscreen.
        parts.append(materials.assign(shapes.box("Mirror", (0.35, 0.12, 0.25), (sx * (w / 2 + 0.05), -2.3, 3.0), 0.04, 2), chrome))
        # Woodgrain down the side, framed in chrome, round the arches.
        for y0, y1 in ((fy + r_arch + 0.15, ry - r_arch - 0.15), (ry + r_arch + 0.15, 6.8)) if woodgrain else ():
            cy, ln = (y0 + y1) / 2, y1 - y0
            parts.append(materials.assign(shapes.box("Wood", (0.03, ln, 1.0), (sx * (w / 2 - 0.035), cy, 1.95), 0.0), wood))
            for z in (1.43, 2.47):
                parts.append(materials.assign(shapes.box("Trim", (0.04, ln, 0.06), (sx * (w / 2 - 0.03), cy, z), 0.01, 1), chrome))
    # The wheels.
    for wy in (fy, ry):
        for sx in (-1, 1):
            wheel = shapes.lathe("Tyre", [(0.0, -0.4), (0.62, -0.4), (0.95, -0.35), (1.0, -0.2), (1.0, 0.2), (0.95, 0.35), (0.62, 0.4), (0.0, 0.4)], steps=24)
            shapes.turn(wheel, (0, 90, 0), (sx * (w / 2 - 0.45), wy, hub))
            parts.append(materials.assign(wheel, rubber))
            cap = shapes.lathe("Hubcap", [(0.0, 0.0), (0.6, 0.0), (0.55, 0.05), (0.2, 0.09), (0.0, 0.1)], steps=20)
            shapes.turn(cap, (0, sx * 90, 0), (sx * (w / 2 - 0.06), wy, hub))
            parts.append(materials.assign(cap, chrome))
    # Bumpers, the grille and the lamps.
    for sy in (-1, 1):
        parts.append(materials.assign(shapes.box("Bumper", (w + 0.05, 0.3, 0.42), (0, sy * (d / 2 + 0.05), 1.1), 0.1, 3), chrome))
    parts.append(materials.assign(shapes.box("Grille", (2.6, 0.06, 0.55), (0, -(d / 2 + 0.01), 1.8), 0.02, 2), chrome))
    for k in range(6):
        parts.append(materials.assign(shapes.box("Slat", (2.4, 0.02, 0.03), (0, -(d / 2 + 0.05), 1.6 + k * 0.08), 0.0), dark))
    for sx in (-1, 1):
        for x in (1.75, 2.45):
            parts.append(materials.assign(shapes.box("Headlamp", (0.55, 0.06, 0.34), (sx * x, -(d / 2 + 0.01), 1.85), 0.03, 2), lamp))
        parts.append(materials.assign(shapes.box("TailLamp", (0.45, 0.06, 0.9), (sx * (w / 2 - 0.35), d / 2 + 0.01, 1.9), 0.03, 2), red))
    parts.append(materials.assign(shapes.box("Plate", (1.2, 0.03, 0.4), (0, d / 2 + 0.02, 1.55), 0.01, 1), lamp))
    if only:
        keep = []
        for part in parts:
            if CAR_GROUPS.get(part.name.split(".")[0], "trim") == only:
                keep.append(part)
            else:
                bpy.data.objects.remove(part, do_unlink=True)
        parts = keep
    return shapes.join(parts, name)


# The car's pieces by what they're for (LB4's mall4 batch: the paint tinted in
# the game, the woodgrain a bit you fit, the rest as it's always been).
CAR_GROUPS = {
    "Body": "body",
    "Roof": "body",
    "Pillar": "body",
    "APillar": "body",
    "DPillar": "body",
    "Wood": "wood",
    "Trim": "wood",
}


def boiler():
    """The cellar's boiler, 6 x 10.8 x 5 (Data/Props' Boiler; its flue rises
    through the ceiling): a riveted steel drum on a brick plinth, a cast-iron
    firebox door whose grille the game's glowing bars show through, a cap,
    the flue, a pressure gauge, a pipe along the wall behind."""
    w, h, d = 6.0, 8.0, 5.0
    plinth = 0.6
    drum = min(w, d) - 0.4
    body = h - plinth - 1.4
    steel = _steel("BoilerSteel", color=(80, 76, 70), roughness=0.5, grime=0.6)
    iron = materials.paint("BoilerIron", color=(30, 28, 26), roughness=0.55, grime=0.4)
    brick = materials.brick("BoilerBrick", scale=3.0)
    copper = materials.brass("BoilerCopper", color=(140, 90, 60), roughness=0.45)
    gauge = materials.paint("GaugeFace", color=(222, 214, 190), roughness=0.3, grime=0.2)
    parts = []
    parts.append(materials.assign(shapes.box("Plinth", (w, d, plinth), (0, 0, plinth / 2), 0.03, 2), brick))
    parts.append(materials.assign(shapes.lathe("Drum", [(0.0, plinth), (drum / 2, plinth), (drum / 2, plinth + body), (drum / 2 - 0.1, plinth + body + 0.05), (0.0, plinth + body + 0.05)], steps=40), steel))
    for z in (plinth + 0.3, plinth + body * 0.5, plinth + body - 0.3):
        parts.append(materials.assign(shapes.lathe("Band", [(drum / 2, z - 0.08), (drum / 2 + 0.05, z - 0.08), (drum / 2 + 0.05, z + 0.08), (drum / 2, z + 0.08)], steps=40), iron))
    parts.append(materials.assign(shapes.lathe("Cap", [(0.0, plinth + body), (drum * 0.4, plinth + body), (drum * 0.38, plinth + body + 0.5), (0.0, plinth + body + 0.5)], steps=32), iron))
    parts.append(materials.assign(shapes.lathe("Flue", [(0.0, plinth + body + 0.2), (0.5, plinth + body + 0.2), (0.5, plinth + body + 4.2), (0.0, plinth + body + 4.2)], (0, 0.4, 0), steps=20), iron))
    # The firebox door, its grille slots where the game's bars glow.
    front = drum / 2
    parts.append(materials.assign(shapes.box("Firebox", (2.4, 0.5, 2.0), (0, -(front - 0.05), plinth + 1.4), 0.04, 2), iron))
    for i in range(-2, 3):
        parts.append(materials.assign(shapes.box("Slot", (0.2, 0.02, 0.92), (i * 0.36, -(front + 0.2), plinth + 1.4), 0.0), materials.paint("Slot", color=(10, 8, 6), roughness=0.9, grime=0.0)))
    parts.append(materials.assign(shapes.box("Latch", (0.5, 0.1, 0.14), (0.9, -(front + 0.24), plinth + 1.9), 0.03, 1), iron))
    gauge_obj = shapes.lathe("Gauge", [(0.0, 0.0), (0.45, 0.0), (0.45, 0.12), (0.4, 0.16), (0.0, 0.16)], steps=24)
    shapes.turn(gauge_obj, (90, 0, 0), (-0.9, -(front + 0.0), plinth + body - 0.9))
    parts.append(materials.assign(gauge_obj, gauge))
    parts.append(materials.assign(shapes.roll("Pipe", w, 0.25, (0, d / 2 - 0.4, h - 0.6), axis="X", steps=12), copper))
    return shapes.join(parts, "Boiler")


def wine_rack():
    """A cellar's wine rack, 6 x 8 x 2 (Data/Props' WineRack): an old oak
    case divided into a grid of cubbies, eight across and ten up, a dusty
    bottle lying in most of them with its neck to the front."""
    w, h, d = 6.0, 8.0, 2.0
    side, top, base = 0.2, 0.2, 0.3
    cols, rows = 8, 10
    cw = (w - 2 * side) / cols
    ch = (h - top - base) / rows
    oak = materials.wood("RackOak", OAK_DARK, OAK_LIGHT, grain_axis="Z", scale=1.2, roughness=0.75)
    oak_x = materials.wood("RackOakAcross", OAK_DARK, OAK_LIGHT, grain_axis="X", scale=1.2, roughness=0.75)
    back = materials.paint("RackBack", color=(30, 22, 16), roughness=0.9, grime=0.3)
    bottle = materials.paint("Bottle", color=(28, 44, 30), roughness=0.15, grime=0.6)
    foil = materials.paint("Foil", color=(110, 24, 28), roughness=0.3, grime=0.3)
    parts = []
    for sx in (-1, 1):
        parts.append(materials.assign(shapes.box("Side", (side, d, h), (sx * (w / 2 - side / 2), 0, h / 2), 0.03, 2), oak))
    parts.append(materials.assign(shapes.box("Top", (w, d, top), (0, 0, h - top / 2), 0.03, 2), oak_x))
    parts.append(materials.assign(shapes.box("Base", (w, d, base), (0, 0, base / 2), 0.03, 2), oak_x))
    parts.append(materials.assign(shapes.box("Back", (w - 2 * side, 0.05, h - top - base), (0, d / 2 - 0.025, base + (h - top - base) / 2), 0.0), back))
    inner = h - top - base
    for i in range(1, cols):
        x = -w / 2 + side + i * cw
        parts.append(materials.assign(shapes.box("Divider", (0.05, d - 0.08, inner), (x, -0.01, base + inner / 2), 0.0), oak))
    for j in range(1, rows):
        z = base + j * ch
        parts.append(materials.assign(shapes.box("Shelf", (w - 2 * side, d - 0.08, 0.05), (0, -0.01, z), 0.0), oak_x))
    rng = random.Random(5)
    r = 0.16
    for j in range(rows):
        for i in range(cols):
            if rng.random() < 0.22:
                continue
            x = -w / 2 + side + (i + 0.5) * cw
            z = base + j * ch + 0.03 + r
            body = shapes.lathe("Bottle", [(0.0, 0.0), (r, 0.0), (r, 0.95), (0.07, 1.25), (0.06, 1.55), (0.0, 1.55)], steps=8)
            shapes.turn(body, (90, 0, 0), (x, 0.62, z))
            parts.append(materials.assign(body, bottle))
            cap = shapes.lathe("Foil", [(0.0, 0.0), (0.065, 0.0), (0.065, 0.22), (0.0, 0.23)], steps=8)
            shapes.turn(cap, (90, 0, 0), (x, 0.62 - 1.33, z))
            parts.append(materials.assign(cap, foil))
    return shapes.join(parts, "WineRack")


def water_tank():
    """The attic's cold-water cistern, 8 x 6 x 5 (Data/Props' WaterTank): a
    galvanised steel box with riveted seams and rust running down them, on
    brick piers, its lid, the feed pipe."""
    w, h, d = 8.0, 6.0, 5.0
    steel = _steel("TankSteel", color=(140, 144, 140), roughness=0.4, grime=0.7)
    rust = materials.paint("TankRust", color=(110, 70, 44), roughness=0.8, grime=0.4)
    brick = materials.brick("TankBrick", scale=3.0)
    copper = materials.brass("TankPipe", color=(140, 90, 60), roughness=0.45)
    parts = []
    for sx in (-1, 1):
        parts.append(materials.assign(shapes.box("Pier", (0.8, d - 0.4, 0.6), (sx * (w / 2 - 0.8), 0, 0.3), 0.02, 2), brick))
    parts.append(materials.assign(shapes.box("Tank", (w, d, h - 0.6 - 0.1), (0, 0, 0.6 + (h - 0.7) / 2), 0.04, 2), steel))
    for z in (1.2, 3.2, 5.0):
        for (sx, sy, ww, dd) in ((0, -1, w + 0.04, 0.06), (0, 1, w + 0.04, 0.06)):
            parts.append(materials.assign(shapes.box("Band", (ww, dd, 0.12), (0, sy * (d / 2 + 0.01), z), 0.01, 1), steel))
        for sx in (-1, 1):
            parts.append(materials.assign(shapes.box("Band", (0.06, d + 0.04, 0.12), (sx * (w / 2 + 0.01), 0, z), 0.01, 1), steel))
    for k in range(5):
        x = -w / 2 + 1 + k * 1.5
        parts.append(materials.assign(shapes.box("Streak", (0.25, 0.02, 1.4), (x, -(d / 2 + 0.02), 4.1), 0.0), rust))
    parts.append(materials.assign(shapes.box("Lid", (w + 0.1, d + 0.1, 0.12), (0, 0, h - 0.06), 0.03, 2), steel))
    parts.append(materials.assign(shapes.roll("Feed", 0.9, 0.12, (w / 2 - 1.0, 0.0, h - 0.1), axis="Z", steps=10), copper))
    return shapes.join(parts, "WaterTank")


def shrine():
    """The lantern's shrine, 3 x 4.6 x 3 (Data/Props' Shrine): a stone
    pedestal with a moulded top, a wrought-iron lantern on it, its glass the
    game's own (the lantern's light)."""
    stone = materials.paint("ShrineStone", color=(120, 116, 106), roughness=0.85, grime=0.6)
    iron = materials.paint("LanternIron", color=(30, 28, 26), roughness=0.5, grime=0.3)
    parts = []
    parts.append(materials.assign(shapes.box("Base", (3.0, 3.0, 0.4), (0, 0, 0.2), 0.06, 2), stone))
    parts.append(materials.assign(shapes.box("Column", (2.4, 2.4, 1.8), (0, 0, 0.4 + 0.9), 0.08, 3), stone))
    parts.append(materials.assign(shapes.box("Cap", (2.9, 2.9, 0.4), (0, 0, 2.4), 0.08, 3), stone))
    # The lantern: corner posts, a base and a roof, round the game's glass
    # (1.1 x 1.4 x 1.1 at 3.5).
    for sx in (-1, 1):
        for sy in (-1, 1):
            parts.append(materials.assign(shapes.box("Post", (0.1, 0.1, 1.8), (sx * 0.65, sy * 0.65, 3.5), 0.02, 1), iron))
    parts.append(materials.assign(shapes.box("LanternBase", (1.5, 1.5, 0.15), (0, 0, 2.68), 0.03, 2), iron))
    roof = shapes.lathe("Roof", [(0.0, 4.35), (1.05, 4.35), (1.05, 4.42), (0.2, 4.75), (0.0, 4.78)], steps=4)
    roof.rotation_euler = (0, 0, math.radians(45))
    shapes.apply_transform(roof)
    parts.append(materials.assign(roof, iron))
    parts.append(materials.assign(shapes.lathe("Ring", [(0.08, 4.75), (0.18, 4.8), (0.18, 4.95), (0.08, 5.0)], steps=12), iron))
    for z in (2.9, 4.1):
        for (sx, sy, ww, dd) in ((0, -1, 1.4, 0.08), (0, 1, 1.4, 0.08), (-1, 0, 0.08, 1.4), (1, 0, 0.08, 1.4)):
            parts.append(materials.assign(shapes.box("Bar", (ww, dd, 0.08), (sx * 0.65, sy * 0.65, z), 0.02, 1), iron))
    return shapes.join(parts, "Shrine")


# The front door ----------------------------------------------------------------


def front_door():
    """The house's front door, 6 x 8 x 0.6 (World/MansionBuilder's
    FrontDoor): heavy, in old bottle-green paint, six raised panels on the
    hall's side, a brass knob and the letter slot's flap; on the porch's side
    the knocker and a peephole. Its front (-Y) faces the hall."""
    w, h, t = 6.0, 8.0, 0.6
    paint = materials.paint("FrontDoorPaint", color=(36, 58, 44), roughness=0.45, grime=0.35)
    brass = materials.brass("FrontDoorBrass", color=(150, 118, 70))
    parts = [materials.assign(shapes.box("Slab", (w, t, h), (0, 0, 0), 0.04, 2), paint)]
    stile, mullion = 0.85, 0.45
    pw = (w - 2 * stile - mullion) / 2
    for side in (-1, 1):
        for z0, z1 in ((-3.25, -0.9), (-0.3, 2.45), (2.85, 3.55)):
            for sx in (-1, 1):
                x = sx * (mullion / 2 + pw / 2)
                cz, ph = (z0 + z1) / 2, z1 - z0
                field = shapes.box("Field", (pw - 0.3, 0.06, ph - 0.3), (x, side * (t / 2 + 0.03), cz), 0.05, 2)
                parts.append(materials.assign(field, paint))
    # The hall's side: the knob, its rose, and the letter slot's flap.
    parts.append(materials.assign(shapes.lathe("Rose", [(0.0, 0.0), (0.28, 0.0), (0.26, 0.04), (0.0, 0.05)], steps=20), brass))
    rose = parts[-1]
    shapes.turn(rose, (90, 0, 0), (-(w / 2 - 0.8), -(t / 2), -0.5))
    knob = shapes.lathe("Knob", [(0.0, 0.0), (0.07, 0.0), (0.07, 0.15), (0.2, 0.25), (0.22, 0.35), (0.15, 0.45), (0.0, 0.47)], steps=20)
    shapes.turn(knob, (90, 0, 0), (-(w / 2 - 0.8), -(t / 2 + 0.03), -0.5))
    parts.append(materials.assign(knob, brass))
    parts.append(materials.assign(shapes.box("Flap", (1.2, 0.05, 0.35), (0, -(t / 2 + 0.03), -0.6 + 0.0), 0.03, 2), brass))
    # The porch's side: a ring knocker and the peephole.
    parts.append(materials.assign(shapes.box("KnockerPlate", (0.4, 0.05, 0.6), (0, t / 2 + 0.03, 1.4), 0.03, 2), brass))
    ring = shapes.lathe("Knocker", [(0.24, -0.04), (0.3, -0.04), (0.3, 0.04), (0.24, 0.04)], steps=20)
    shapes.turn(ring, (90, 0, 0), (0, t / 2 + 0.08, 1.15))
    parts.append(materials.assign(ring, brass))
    parts.append(materials.assign(shapes.lathe("Peephole", [(0.0, 0.0), (0.07, 0.0), (0.06, 0.06), (0.0, 0.07)], (0, 0, 0), steps=12), brass))
    shapes.turn(parts[-1], (-90, 0, 0), (0, t / 2 + 0.03, 2.3))
    return shapes.join(parts, "FrontDoor")


HOUSE = [
    bed,
    closet,
    closet_door,
    crib,
    locker,
    locker_door,
    tall_cupboard,
    tall_cupboard_door,
    toilet,
    sink,
    bathtub,
    counter,
    counter_door,
    fridge,
    fridge_door_top,
    fridge_door_bottom,
    stove,
    washer,
    water_heater,
    workbench,
    car,
    boiler,
    wine_rack,
    water_tank,
    shrine,
    front_door,
]
