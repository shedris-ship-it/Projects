"""The living rooms', study's and bedrooms' furniture (the visual rework V4c,
the kit's second rollout batch): the console TV on its stand, the table with
its cloth, the writing desk and its drawers, the cabinet and the wardrobe
with their doors, the curtains, the upright piano, the china cabinet, the
utility shelving, the dress form, the rocking chair and the piano stool.

Each piece stands on Z = 0, centred, its front toward -Y (Roblox's +Z, the
room). A moving piece (a door, a drawer's front) is built round the middle
of the grey-box part it hangs on (World/PropFactory), so World/Kit can hang
it there. The hiding pieces keep the game's gaps exactly: a tablecloth's and
a desk skirt's hem at PropFactory.ClothHem, a wardrobe's louvres at the eye,
the curtain's parting; and their cloth shows from inside (it's solid).

Sizes are Roblox's { x, y, z } = Blender's (x, z, y).
"""

import math
import random

import bmesh
import bpy

from . import materials, shapes

WALNUT_DARK, WALNUT_LIGHT = (46, 30, 20), (92, 62, 40)
OAK_DARK, OAK_LIGHT = (70, 48, 30), (128, 92, 58)
HEM = 0.45  # World/PropFactory's ClothHem: the gap under a cloth you look out of
LINEN = (184, 172, 146)
STAND_EYE = 4.55  # World/PropFactory's: a player's eye over what they stand on
LOUVRE_TILT = 35  # degrees, World/PropFactory's


def _walnut(name, axis="Z", roughness=0.38):
    return materials.wood(name, WALNUT_DARK, WALNUT_LIGHT, grain_axis=axis, scale=1.1, roughness=roughness)


def _solid(obj, thickness):
    """Gives a sheet (a cloth) a thin back, so it shows from both sides."""
    mod = obj.modifiers.new("Solid", "SOLIDIFY")
    mod.thickness = thickness
    mod.offset = 0.0
    shapes.select_only(obj)
    bpy.ops.object.modifier_apply(modifier=mod.name)
    return obj


def _sheet(name, points_fn, cols, rows):
    """A grid of quads from points_fn(u, v) -> (x, y, z), u and v 0..1."""
    bm = bmesh.new()
    grid = [[bm.verts.new(points_fn(i / cols, j / rows)) for i in range(cols + 1)] for j in range(rows + 1)]
    for j in range(rows):
        for i in range(cols):
            bm.faces.new((grid[j][i], grid[j][i + 1], grid[j + 1][i + 1], grid[j + 1][i]))
    return shapes._object(name, bm)


# The TV and its stand -------------------------------------------------------

TV = {
    "body": (5.2, 3.4, 1.1),  # x, height, depth: its front at z 0.6 (game), on the stand's top
    "screen": (3.6, 2.6),  # World/PropFactory's Screen part
    "screen_x": -0.6,
    "screen_y": 1.8,  # its middle above the stand's top
}


def tv_stand():
    """A 1988 console TV on a walnut stand, 6 x 3 x 2 (the stand; Data/Props'
    TVStand) and the set on it (5.2 x 3.4, rabbit ears): a walnut-veneer
    cabinet, the screen's dark bezel (the glowing screen is the game's own,
    World/PropFactory's Screen), a control panel with dials and a speaker
    grille; in the stand a VCR whose clock blinks 12:00 (it glows) and a row
    of tapes."""
    w, h, d = 6.0, 3.0, 2.0
    wood = _walnut("StandWalnut", "X")
    wood_up = _walnut("StandWalnutUp", "Z")
    veneer = materials.wood("TVVeneer", (58, 38, 24), (104, 72, 46), grain_axis="X", scale=0.8, roughness=0.3)
    plastic = materials.paint("TVPlastic", color=(22, 21, 20), roughness=0.4, grime=0.1)
    silver = materials.paint("TVSilver", color=(150, 148, 142), roughness=0.3, grime=0.15)
    grille = materials.fabric("SpeakerCloth", color=(48, 40, 34), roughness=0.95)
    vcr = materials.paint("VCR", color=(26, 26, 28), roughness=0.35, grime=0.05)
    digits = materials.paint("VCRClock", color=(90, 255, 140), roughness=0.4, grime=0.0)
    digits["glow"] = 1.0
    tapes = materials.by_colour("Tapes", roughness=0.5)
    parts = []
    # The stand: a top, sides, a back, a shelf; a plinth.
    parts.append(materials.assign(shapes.box("Top", (w, d, 0.16), (0, 0, h - 0.08), 0.05, 3), wood))
    for sx in (-1, 1):
        parts.append(materials.assign(shapes.box("Side", (0.16, d - 0.05, h - 0.4), (sx * (w / 2 - 0.08), 0.02, 0.24 + (h - 0.4) / 2), 0.03, 2), wood_up))
    parts.append(materials.assign(shapes.box("Back", (w - 0.3, 0.06, h - 0.4), (0, d / 2 - 0.03, 0.24 + (h - 0.4) / 2), 0.0), wood_up))
    parts.append(materials.assign(shapes.box("Shelf", (w - 0.3, d - 0.15, 0.1), (0, 0.06, 1.4), 0.02, 2), wood))
    parts.append(materials.assign(shapes.box("Bottom", (w - 0.3, d - 0.15, 0.1), (0, 0.06, 0.29), 0.02, 2), wood))
    parts.append(materials.assign(shapes.box("Plinth", (w - 0.1, d - 0.2, 0.24), (0, 0.06, 0.12), 0.03, 2), wood))
    # The VCR on the upper shelf, its clock glowing.
    parts.append(materials.assign(shapes.box("VCR", (3.4, 1.4, 0.45), (-0.6, 0.0, 1.45 + 0.225), 0.03, 2), vcr))
    parts.append(materials.assign(shapes.box("Slot", (1.6, 0.02, 0.1), (-1.0, -0.71, 1.75), 0.0), plastic))
    parts.append(materials.assign(shapes.box("Clock", (0.5, 0.02, 0.12), (0.5, -0.71, 1.75), 0.0), digits))
    for k in range(5):
        parts.append(materials.assign(shapes.box("Button", (0.14, 0.04, 0.07), (0.05 + k * 0.2, -0.71, 1.58), 0.01, 1), silver))
    # Tapes standing on the lower shelf, spines out.
    rng = random.Random(88)
    x = -2.7
    while x < 2.4:
        t = 0.32
        tape = shapes.box("Tape", (t, 1.0, 1.9 * 0.42 + 0.1), (x + t / 2, 0.1, 0.34 + 0.45), 0.01, 1)
        shapes.colour(tape, rng.choice([(0.02, 0.02, 0.02), (0.6, 0.55, 0.45), (0.05, 0.05, 0.08), (0.5, 0.08, 0.06)]))
        parts.append(materials.assign(tape, tapes))
        x += t + rng.uniform(0.0, 0.04)
    # The set: a veneer cabinet, the tube's housing tapering behind.
    bw, bh, bd = TV["body"]
    front = 0.6
    body = shapes.box("Cabinet", (bw, bd, bh), (0, -(front - bd / 2), h + bh / 2), 0.08, 3)
    parts.append(materials.assign(body, veneer))
    housing = shapes.box("Housing", (bw - 1.6, 0.5, bh - 0.8), (-0.3, -(front - bd - 0.25), h + bh / 2 - 0.1), 0.15, 3)
    parts.append(materials.assign(housing, plastic))
    # The bezel round the screen, standing just in front of it (the game's
    # screen's front face is at 0.67; the bezel overlaps its edge).
    sw, sh = TV["screen"]
    sx0, sy0 = TV["screen_x"], h + TV["screen_y"]
    bez = 0.18
    for (cx, cz, ww, hh) in (
        (sx0, sy0 + sh / 2 + bez / 2 - 0.06, sw + 2 * bez - 0.12, bez),
        (sx0, sy0 - sh / 2 - bez / 2 + 0.06, sw + 2 * bez - 0.12, bez),
        (sx0 - sw / 2 - bez / 2 + 0.06, sy0, bez, sh),
        (sx0 + sw / 2 + bez / 2 - 0.06, sy0, bez, sh),
    ):
        parts.append(materials.assign(shapes.box("Bezel", (ww, 0.14, hh), (cx, -(front + 0.06), cz), 0.03, 2), plastic))
    # The tube's dark face, behind the game's half-clear glowing screen (which
    # sits from 0.57 to 0.67 out), so the veneer never shows through it.
    tube = shapes.box("Tube", (sw, 0.01, sh), (sx0, -(front + 0.008), sy0), 0.0)
    parts.append(materials.assign(tube, materials.paint("TubeGlass", color=(20, 24, 22), roughness=0.2, grime=0.0)))
    # A silver strip round the bezel.
    parts.append(materials.assign(shapes.box("Trim", (sw + 0.5, 0.02, 0.04), (sx0, -(front + 0.005), sy0 + sh / 2 + bez + 0.02), 0.0), silver))
    parts.append(materials.assign(shapes.box("Trim", (sw + 0.5, 0.02, 0.04), (sx0, -(front + 0.005), sy0 - sh / 2 - bez - 0.02), 0.0), silver))
    # The control panel on the right: two dials, buttons, a speaker grille.
    px = sx0 + sw / 2 + bez + (bw / 2 - (sx0 + sw / 2 + bez)) / 2
    for k, dz in enumerate((2.75, 2.25)):
        dial = shapes.lathe("Dial", [(0.0, 0.0), (0.17, 0.0), (0.17, 0.08), (0.14, 0.12), (0.0, 0.12)], steps=16)
        shapes.turn(dial, (90, 0, 0), (px, -front, h + dz))
        parts.append(materials.assign(dial, silver if k == 0 else plastic))
    for k in range(3):
        parts.append(materials.assign(shapes.box("Channel", (0.12, 0.05, 0.08), (px - 0.2 + k * 0.2, -(front + 0.02), h + 1.85), 0.01, 1), silver))
    parts.append(materials.assign(shapes.box("Grille", (0.62, 0.03, 1.05), (px, -(front + 0.01), h + 1.0), 0.02, 2), grille))
    # Rabbit ears.
    for side in (-1, 1):
        ear = shapes.roll("Ear", 1.8, 0.02, (0, 0, 0), axis="Z", steps=6)
        shapes.turn(ear, (0, side * 28, 0), (side * 0.45 + 0.6, -0.2, h + bh + 0.85))
        parts.append(materials.assign(ear, silver))
    parts.append(materials.assign(shapes.lathe("EarBase", [(0.0, 0.0), (0.3, 0.0), (0.26, 0.12), (0.08, 0.2), (0.0, 0.22)], (0.6, -0.2, h + bh), steps=16), plastic))
    piece = shapes.join(parts, "TVStand")
    return piece


# The table and its cloth ----------------------------------------------------


def table():
    """A table under a long linen cloth, 8 x 3.4 x 5 (Data/Props' Table, a
    place to hide): the cloth lies over the top and falls in soft folds to
    the hem, 0.45 off the floor all round (World/PropFactory's ClothHem: you
    look out under it), its corners hanging in cones; underneath, the legs
    and apron you see from inside. The cloth is solid, so it shows from
    under the table too."""
    w, h, d = 8.0, 3.4, 5.0
    cloth = materials.fabric("TableLinen", color=(206, 196, 172), roughness=0.9)
    wood = _walnut("TableLegs", "Z")
    parts = []
    for sx in (-1, 1):
        for sy in (-1, 1):
            leg = shapes.turned_leg("Leg", h - 0.3, 0.18, (sx * (w / 2 - 0.45), sy * (d / 2 - 0.45), 0))
            parts.append(materials.assign(leg, wood))
    parts.append(materials.assign(shapes.box("Apron", (w - 0.8, d - 0.8, 0.4), (0, 0, h - 0.5), 0.03, 2), wood))
    parts.append(materials.assign(shapes.box("Top", (w - 0.04, d - 0.04, 0.2), (0, 0, h - 0.13), 0.04, 2), wood))
    # The cloth: the top, then each side falling from the edge to the hem,
    # bowing out a little and folding; a cone at each corner.
    top = h + 0.005
    out = 0.05  # how far it stands off the table's edge
    drop = top - HEM

    def side(length, folds):
        def at(u, v):
            # u along the side, v down it; folds deepen toward the hem.
            x = (u - 0.5) * length
            y = -out - 0.06 * v * (0.5 + 0.5 * math.sin(u * math.pi * folds * 2)) - 0.02 * math.sin(v * math.pi)
            z = top - v * drop
            return (x, y, z)

        return at

    sheets = []
    for name, length, folds, place in (
        ("ClothFront", w, 6, lambda o: shapes.turn(o, (0, 0, 0), (0, -d / 2, 0))),
        ("ClothBack", w, 6, lambda o: shapes.turn(o, (0, 0, 180), (0, d / 2, 0))),
        ("ClothLeft", d, 4, lambda o: shapes.turn(o, (0, 0, -90), (-w / 2, 0, 0))),
        ("ClothRight", d, 4, lambda o: shapes.turn(o, (0, 0, 90), (w / 2, 0, 0))),
    ):
        s = _sheet(name, side(length, folds), 28, 6)
        place(s)
        sheets.append(s)
    lay = shapes.box("ClothTop", (w + 2 * out, d + 2 * out, 0.01), (0, 0, top), 0.0)
    sheets.append(lay)
    # Corners: a quarter cone joining each pair of sides.
    for sx in (-1, 1):
        for sy in (-1, 1):

            # (A quarter turn round the corner, outside the table.)
            def quarter(u, v, sx=sx, sy=sy):
                angles = {(1, -1): (-math.pi / 2, 0.0), (1, 1): (0.0, math.pi / 2), (-1, 1): (math.pi / 2, math.pi), (-1, -1): (math.pi, 1.5 * math.pi)}[(sx, sy)]
                a = angles[0] + (angles[1] - angles[0]) * u
                r = out + 0.03 * v
                return (sx * w / 2 + r * math.cos(a), sy * d / 2 + r * math.sin(a), top - v * drop)

            sheets.append(_sheet("ClothCorner", quarter, 4, 6))
    cloth_obj = shapes.join(sheets, "Cloth")
    _solid(cloth_obj, 0.02)
    shapes.smooth(cloth_obj, 60)
    parts.append(materials.assign(cloth_obj, cloth))
    piece = shapes.join(parts, "Table")
    lo, _hi = shapes.bounds(piece)
    assert abs(lo.z) < 0.01
    return piece


# The writing desk -----------------------------------------------------------


def desk():
    """A walnut writing desk, 7 x 3.4 x 3.5 (Data/Props' Desk; World/
    PropFactory's): a top with a leather writing inset, a pedestal of two
    drawers on the right (their fronts are DeskDrawerDeep and
    DeskDrawerShallow), a panelled end on the left, a modesty panel at the
    back of the kneehole, and across its front a pleated cloth skirt hanging
    to the hem (you hide in the kneehole and look out under it)."""
    w, h, d = 7.0, 3.4, 3.5
    wood = _walnut("DeskWalnut", "Z")
    wood_x = _walnut("DeskWalnutAcross", "X")
    leather = materials.upholstery("DeskLeather", base=(40, 56, 40), figure=(44, 60, 44), roughness=0.6)
    skirt = materials.fabric("DeskSkirt", color=(122, 46, 44), roughness=0.92)
    brass = materials.brass("DeskBrass")
    parts = []
    parts.append(materials.assign(shapes.box("Top", (w, d, 0.3), (0, 0, h - 0.15), 0.06, 3), wood_x))
    parts.append(materials.assign(shapes.box("Inset", (w - 1.4, d - 1.2, 0.02), (0, 0, h + 0.005), 0.0), leather))
    face = (d - 0.2) / 2  # the drawers' faces (World/PropFactory)
    x = w / 2 - 1.2
    ped = shapes.box("Pedestal", (2.2, d - 0.2, h - 0.3), (x, 0, (h - 0.3) / 2), 0.03, 2)
    parts.append(materials.assign(ped, wood))
    # The pedestal's face frame round the drawers.
    parts.append(materials.assign(shapes.box("Rail", (2.2, 0.04, 0.1), (x, -(face + 0.02), 2.0), 0.01, 1), wood_x))
    end = shapes.box("End", (0.3, d - 0.2, h - 0.3), (-w / 2 + 0.2, 0, (h - 0.3) / 2), 0.03, 2)
    parts.append(materials.assign(end, wood))
    parts.append(materials.assign(shapes.box("EndPanel", (0.04, d - 0.8, h - 1.0), (-w / 2 + 0.04, 0, (h - 0.3) / 2), 0.02, 2), wood))
    knee_l, knee_r = -w / 2 + 0.35, x - 1.1
    knee = knee_r - knee_l
    knee_x = (knee_l + knee_r) / 2
    parts.append(materials.assign(shapes.box("Modesty", (knee, 0.1, h - 0.3), (knee_x, d / 2 - 0.15, (h - 0.3) / 2), 0.02, 2), wood))
    # The skirt: hung from a rod under the top, pleated, to the hem.
    sz = d / 2 - 0.13  # World/PropFactory's Skirt plane

    def pleats(u, v):
        xx = knee_l + u * knee
        y = -(sz + 0.04 * (0.5 + 0.5 * math.sin(u * math.pi * 14)))
        z = (h - 0.3) - v * (h - 0.3 - HEM)
        return (xx, y, z)

    cloth = _sheet("Skirt", pleats, 56, 4)
    _solid(cloth, 0.02)
    parts.append(materials.assign(shapes.smooth(cloth, 60), skirt))
    parts.append(materials.assign(shapes.roll("Rod", knee, 0.025, (knee_x, -(sz + 0.02), h - 0.34), axis="X", steps=6), brass))
    return shapes.join(parts, "Desk")


def _drawer_front(name, w, fh, pull_y):
    wood = _walnut(name + "Walnut", "X", 0.34)
    brass = materials.brass(name + "Brass")
    parts = [materials.assign(shapes.box("Front", (w, 0.1, fh), (0, 0, 0), 0.03, 3), wood)]
    parts.append(materials.assign(shapes.box("Field", (w - 0.3, 0.03, fh - 0.3), (0, -0.06, 0), 0.02, 2), wood))
    # A brass cup pull.
    pull = shapes.box("Pull", (0.6, 0.08, 0.12), (0, -0.11, pull_y), 0.03, 2)
    parts.append(materials.assign(pull, brass))
    piece = shapes.join(parts, name)
    piece["bake_size"] = 512
    return piece


def desk_drawer_deep():
    """The desk's deep bottom drawer's front, 2 x 1.8 x 0.1 round World/
    PropFactory's Front, its pull near the top."""
    return _drawer_front("DeskDrawerDeep", 2.0, 1.8, 0.9 - 0.25)


def desk_drawer_shallow():
    """The desk's shallow top drawer's front, 2 x 0.95."""
    return _drawer_front("DeskDrawerShallow", 2.0, 0.95, 0.475 - 0.25)


# The cabinet and the wardrobe -----------------------------------------------


def _armoire(name, w, h, d, interior):
    """The carcass both share: walnut sides and back, a plinth and a cornice
    standing out over the doors' plane (the doors are their own pieces), the
    inside dark; `interior` adds its shelves or rail."""
    wood = _walnut(name + "Walnut", "Z")
    wood_x = _walnut(name + "WalnutAcross", "X")
    dark = materials.paint(name + "Inside", color=(34, 26, 20), roughness=0.85, grime=0.1)
    parts = []
    front = d / 2 + 0.16  # in front of the doors' faces (d/2 + 0.155)
    for sx in (-1, 1):
        parts.append(materials.assign(shapes.box("Side", (0.2, d, h - 0.3), (sx * (w / 2 - 0.1), 0, (h - 0.3) / 2 + 0.0), 0.03, 2), wood))
    parts.append(materials.assign(shapes.box("Back", (w - 0.4, 0.1, h - 0.6), (0, d / 2 - 0.05, h / 2), 0.0), dark))
    parts.append(materials.assign(shapes.box("Floor", (w - 0.4, d - 0.1, 0.06), (0, 0, 0.33), 0.0), dark))
    parts.append(materials.assign(shapes.box("Ceiling", (w - 0.4, d - 0.1, 0.06), (0, 0, h - 0.33), 0.0), dark))
    for sx in (-1, 1):
        parts.append(materials.assign(shapes.box("Lining", (0.02, d - 0.1, h - 0.66), (sx * (w / 2 - 0.21), 0, h / 2), 0.0), dark))
    # Plinth and cornice, deeper than the carcass by the doors.
    depth = d / 2 + front
    mid = (front - d / 2) / 2
    parts.append(materials.assign(shapes.box("Plinth", (w, depth, 0.3), (0, -mid, 0.15), 0.04, 2), wood_x))
    for k, (grow, tall, z) in enumerate(((0.0, 0.14, h - 0.23), (0.02, 0.08, h - 0.12), (0.04, 0.06, h - 0.04))):
        parts.append(materials.assign(shapes.box("Cornice", (w + grow * 0.5, depth + grow, tall), (0, -mid - grow / 2, z), 0.03, 2), wood_x))
    parts += interior(dark, wood_x)
    return parts


def _door(name, w, h, thick, panels, handle, handle_x, louvre=None):
    """A cupboard door round the middle of World/PropFactory's door part:
    w x h x thick with raised panels [(z_from, z_to)] (from the door's
    bottom), a brass handle at (handle_x, handle) from the door's middle,
    and optionally louvres: (z_from, z_to, slats, inset) open between."""
    wood = _walnut(name + "Walnut", "Z", 0.36)
    wood_x = _walnut(name + "WalnutAcross", "X", 0.36)
    brass = materials.brass(name + "Brass")
    parts = []
    bottom = -h / 2
    if louvre is None:
        parts.append(materials.assign(shapes.box("Leaf", (w, thick, h), (0, 0, 0), 0.03, 2), wood))
    else:
        lo_z, hi_z, slats, inset = louvre
        parts.append(materials.assign(shapes.box("Lower", (w, thick, lo_z), (0, 0, bottom + lo_z / 2), 0.03, 2), wood))
        parts.append(materials.assign(shapes.box("Upper", (w, thick, h - hi_z), (0, 0, bottom + hi_z + (h - hi_z) / 2), 0.03, 2), wood))
        for sx in (-1, 1):
            parts.append(materials.assign(shapes.box("Stile", (inset, thick, hi_z - lo_z + 0.02), (sx * (w / 2 - inset / 2), 0, bottom + (lo_z + hi_z) / 2), 0.02, 2), wood))
        pitch = (hi_z - lo_z) / slats
        for i in range(slats):
            slat = shapes.box("Slat", (w - 2 * inset + 0.02, thick * 0.9, 0.045), (0, 0, 0), 0.01, 1)
            # Tilted down toward the room, as the game's (World/PropFactory).
            shapes.turn(slat, (-LOUVRE_TILT, 0, 0), (0, 0, bottom + lo_z + pitch * (i + 0.5)))
            parts.append(materials.assign(slat, wood_x))
    for z0, z1 in panels:
        cz, ph = bottom + (z0 + z1) / 2, z1 - z0
        parts.append(materials.assign(shapes.box("Field", (w - 0.6, 0.05, ph - 0.3), (0, -(thick / 2 + 0.02), cz), 0.04, 2), wood))
        for (mx, mz, mw, mh) in ((0, cz + ph / 2 - 0.04, w - 0.3, 0.07), (0, cz - ph / 2 + 0.04, w - 0.3, 0.07)):
            parts.append(materials.assign(shapes.box("Mould", (mw, 0.06, mh), (mx, -(thick / 2 + 0.025), mz), 0.02, 1), wood_x))
        for sx in (-1, 1):
            parts.append(materials.assign(shapes.box("Mould", (0.07, 0.055, ph - 0.02), (sx * (w / 2 - 0.19), -(thick / 2 + 0.022), cz), 0.02, 1), wood))
    # The handle: a brass bar on two posts.
    bar = shapes.roll("Handle", 0.8, 0.035, (0, 0, 0), axis="Z", steps=10)
    shapes.turn(bar, (0, 0, 0), (handle_x, -(thick / 2 + 0.13), handle))
    parts.append(materials.assign(bar, brass))
    for dz in (-0.3, 0.3):
        parts.append(materials.assign(shapes.box("Post", (0.05, 0.13, 0.05), (handle_x, -(thick / 2 + 0.065), handle + dz), 0.015, 1), brass))
    piece = shapes.join(parts, name)
    piece["bake_size"] = 512
    return piece


def cabinet():
    """A walnut linen press, 6 x 8 x 3 (Data/Props' Cabinet): a carcass
    with two shelves inside, a plinth and a stepped cornice. Its doors are
    CabinetDoorL and CabinetDoorR (World/PropFactory's cupboard)."""
    w, h, d = 6.0, 8.0, 3.0

    def shelves(dark, wood_x):
        out = []
        for k in (1 / 3, 2 / 3):
            out.append(materials.assign(shapes.box("Shelf", (w - 0.4, d - 0.3, 0.12), (0, -0.05, 0.4 + (h - 0.7) * k), 0.02, 2), wood_x))
        _ = dark
        return out

    return shapes.join(_armoire("Cabinet", w, h, d, shelves), "Cabinet")


def _cabinet_door(name, sx):
    # World/PropFactory: w/2 - 0.03 wide, h - 0.6 tall, 0.15 thick, its
    # handle 0.35 from the middle of the pair at the cabinet's middle height.
    w, h = 6.0, 8.0
    dw, dh = w / 2 - 0.03, h - 0.6
    centre_x = sx * (w / 4 + 0.015)
    return _door(name, dw, dh, 0.15, [(0.35, 3.2), (3.6, dh - 0.35)], 0.0, sx * 0.35 - centre_x)


def cabinet_door_l():
    return _cabinet_door("CabinetDoorL", -1)


def cabinet_door_r():
    return _cabinet_door("CabinetDoorR", 1)


def wardrobe():
    """A walnut wardrobe, 6 x 9 x 3 (Data/Props' Wardrobe), the cabinet's
    carcass with a hat shelf and a hanging rail inside, room to step in. Its
    doors are WardrobeDoorL and WardrobeDoorR, louvred at the eye."""
    w, h, d = 6.0, 9.0, 3.0

    def fit(dark, wood_x):
        brass = materials.brass("WardrobeRail")
        out = [materials.assign(shapes.box("HatShelf", (w - 0.4, d - 0.5, 0.12), (0, -0.05, h - 2), 0.02, 2), wood_x)]
        out.append(materials.assign(shapes.roll("Rail", w - 0.4, 0.06, (0, 0.1, h - 2.5), axis="X", steps=10), brass))
        _ = dark
        return out

    return shapes.join(_armoire("Wardrobe", w, h, d, fit), "Wardrobe")


def _wardrobe_door(name, sx):
    # World/PropFactory's ventedLeaf for the wardrobe: from 0.3 up, h - 0.6
    # tall, louvres in a band 2 high round the eye on the plinth (0.4 +
    # STAND_EYE), 9 slats, stiles 0.35; the hanging part's main part is the
    # leaf below the louvres, so the door is built round its middle.
    w, h = 6.0, 9.0
    dw, dh = w / 2 - 0.03, h - 0.6
    eye = 0.4 + STAND_EYE
    band = 2.0
    low, high = eye - band / 2 - 0.3, eye + band / 2 - 0.3  # from the door's bottom (0.3)
    door = _door(
        name,
        dw,
        dh,
        0.15,
        [(0.35, low - 0.3), (high + 0.3, dh - 0.35)],
        (0.4 + STAND_EYE - 1.6) - 0.3 - dh / 2,
        sx * 0.35 - sx * (w / 4 + 0.015),
        louvre=(low, high, 9, 0.35),
    )
    # Hang it on the lower leaf's middle: the leaf runs 0 to `low` up the door.
    for v in door.data.vertices:
        v.co.z -= (low / 2) - dh / 2
    # (Or its box, which kit.py reports, stays the old one.)
    door.data.update()
    bpy.context.view_layer.update()
    return door


def wardrobe_door_l():
    return _wardrobe_door("WardrobeDoorL", -1)


def wardrobe_door_r():
    return _wardrobe_door("WardrobeDoorR", 1)


# The curtains ----------------------------------------------------------------


def curtain():
    """Heavy velvet curtains on a brass rod, 6 x 10 x 1.5 (Data/Props'
    Curtain, a place to hide): two panels gathered in deep folds, parted a
    hand's width in the middle (the gap you look through: World/PropFactory's
    FoldGapL and FoldGapR), hanging from rings to just off the floor, a stud
    off the wall. Solid: they show from behind too."""
    w, h, d = 6.0, 10.0, 1.5
    velvet = materials.velvet("CurtainVelvet", color=(96, 30, 34))
    brass = materials.brass("CurtainBrass")
    parts = []
    front = d / 2  # the folds' front (the game's)
    gap = 0.1
    rod_z = h - 0.25
    for side in (-1, 1):
        x0, x1 = side * gap, side * (w / 2 - 0.05)

        def panel(u, v, x0=x0, x1=x1):
            x = x0 + (x1 - x0) * u
            deep = 0.17 * (0.5 + 0.5 * math.sin(u * math.pi * 9))
            # Gathered at the top, falling a little looser to the floor.
            y = -(front - 0.36 + deep * (0.8 + 0.4 * v)) + 0.02
            z = rod_z - 0.15 - v * (rod_z - 0.15 - 0.12)
            return (x, y, z)

        sheet = _sheet("Panel", panel, 54, 6)
        _solid(sheet, 0.035)
        parts.append(materials.assign(shapes.smooth(sheet, 70), velvet))
        for k in range(7):
            ring = shapes.lathe("Ring", [(0.07, -0.02), (0.09, -0.02), (0.09, 0.02), (0.07, 0.02)], steps=10)
            shapes.turn(ring, (90, 0, 0), (x0 + (x1 - x0) * (k + 0.5) / 7, -(front - 0.2), rod_z - 0.08))
            parts.append(materials.assign(ring, brass))
    parts.append(materials.assign(shapes.roll("Rod", w, 0.06, (0, -(front - 0.2), rod_z), axis="X", steps=12), brass))
    for sx in (-1, 1):
        fin = shapes.lathe("Finial", [(0.0, 0.0), (0.06, 0.0), (0.11, 0.06), (0.09, 0.14), (0.03, 0.19), (0.0, 0.2)], steps=14)
        shapes.turn(fin, (0, sx * 90, 0), (sx * w / 2, -(front - 0.2), rod_z))
        parts.append(materials.assign(fin, brass))
        # A bracket from the wall (the prop's back) out to the rod.
        reach = d / 2 + (front - 0.2)
        bracket = shapes.box("Bracket", (0.06, reach, 0.06), (sx * (w / 2 - 0.3), d / 2 - reach / 2, rod_z), 0.01, 1)
        parts.append(materials.assign(bracket, brass))
    return shapes.join(parts, "Curtain")


# The piano -------------------------------------------------------------------


def piano():
    """An upright piano in old black lacquer, 7 x 5 x 3 (Data/Props' Piano;
    its top runs back from the keyboard, topSpan): the case, the fallboard
    folded back over open keys (white and black), a music desk, the legs on
    toe blocks under the keybed, two brass candle sconces, the pedals."""
    w, h, d = 7.0, 5.0, 3.0
    lacquer = materials.paint("PianoLacquer", color=(16, 14, 14), roughness=0.18, grime=0.15)
    ivory = materials.paint("Ivory", color=(222, 214, 190), roughness=0.35, grime=0.25)
    ebony = materials.paint("Ebony", color=(14, 12, 12), roughness=0.3, grime=0.05)
    felt = materials.fabric("PianoFelt", color=(110, 26, 30), roughness=0.95)
    brass = materials.brass("PianoBrass")
    parts = []
    back = d / 2
    case_d = d - 1.0  # World/PropFactory: the body stops 1 short of the front
    case_c = back - case_d / 2
    parts.append(materials.assign(shapes.box("Case", (w - 0.4, case_d, h - 0.4), (0, case_c, (h - 0.4) / 2 + 0.2), 0.05, 3), lacquer))
    for sx in (-1, 1):
        parts.append(materials.assign(shapes.box("Cheek", (0.2, case_d + 0.1, h), (sx * (w / 2 - 0.1), case_c - 0.05, h / 2), 0.05, 3), lacquer))
    parts.append(materials.assign(shapes.box("Lid", (w, case_d + 0.15, 0.12), (0, case_c - 0.05, h - 0.06), 0.04, 3), lacquer))
    parts.append(materials.assign(shapes.box("Plinth", (w - 0.4, case_d + 0.05, 0.2), (0, case_c, 0.1), 0.03, 2), lacquer))
    # The keybed out to the front, its keys, the fallboard folded back.
    kb_front = -(d / 2)
    kb_y = -(d / 2 - 0.6)  # World/PropFactory's keybed: its middle 0.6 in from the front
    parts.append(materials.assign(shapes.box("Keybed", (w - 0.4, 1.2, 0.5), (0, kb_y + 0.0, 2.8), 0.04, 2), lacquer))
    parts.append(materials.assign(shapes.box("Felt", (w - 0.8, 0.05, 0.06), (0, kb_y - 0.45 + 0.9, 3.09), 0.0), felt))
    keys_w = w - 0.8
    n = 52
    kw = keys_w / n
    for i in range(n):
        x = -keys_w / 2 + kw * (i + 0.5)
        key = shapes.box("Key", (kw - 0.012, 0.85, 0.08), (x, kb_y - 0.12, 3.09), 0.01, 1)
        parts.append(materials.assign(key, ivory))
    for i in range(n - 1):
        if i % 7 in (2, 6):
            continue
        x = -keys_w / 2 + kw * (i + 1)
        parts.append(materials.assign(shapes.box("Sharp", (kw * 0.55, 0.5, 0.1), (x, kb_y + 0.05, 3.17), 0.01, 1), ebony))
    parts.append(materials.assign(shapes.box("Fallboard", (w - 0.8, 0.08, 0.5), (0, (back - case_d) - 0.04, 3.45), 0.02, 2), lacquer))
    parts.append(materials.assign(shapes.box("Desk", (w - 1.6, 0.06, 0.9), (0, (back - case_d) - 0.05, 4.1), 0.02, 2), lacquer))
    # Legs under the keybed's ends, on toe blocks.
    for sx in (-1, 1):
        leg = shapes.turned_leg("Leg", 2.55, 0.14, (sx * (w / 2 - 0.35), kb_front + 0.35, 0))
        parts.append(materials.assign(leg, lacquer))
        parts.append(materials.assign(shapes.box("Toe", (0.32, 1.0, 0.18), (sx * (w / 2 - 0.35), kb_front + 0.6, 0.09), 0.03, 2), lacquer))
        # A brass candle sconce on each cheek.
        arm = shapes.roll("Sconce", 0.4, 0.025, (sx * (w / 2 - 0.4), (back - case_d) - 0.2, 3.9), axis="Y", steps=8)
        parts.append(materials.assign(arm, brass))
        parts.append(materials.assign(shapes.lathe("Cup", [(0.0, 0.0), (0.08, 0.0), (0.1, 0.08), (0.0, 0.08)], (sx * (w / 2 - 0.4), (back - case_d) - 0.42, 3.9), steps=10), brass))
    for k in (-0.35, 0, 0.35):
        parts.append(materials.assign(shapes.box("Pedal", (0.14, 0.45, 0.05), (k, (back - case_d) - 0.3, 0.3), 0.015, 1), brass))
    return shapes.join(parts, "Piano")


# The china cabinet and the shelving ----------------------------------------


def china_cabinet():
    """A walnut china cabinet, 8 x 9 x 2 (a Shelf item named china*): a
    cupboard below, open glazing bars above with plates stood up on their
    edges and cups along the shelves, a cornice."""
    w, h, d = 8.0, 9.0, 2.0
    wood = _walnut("ChinaWalnut", "Z")
    wood_x = _walnut("ChinaWalnutAcross", "X")
    back = materials.paint("ChinaBack", color=(52, 62, 58), roughness=0.8, grime=0.2)
    porcelain = materials.paint("Porcelain", color=(226, 224, 216), roughness=0.2, grime=0.1)
    rim = materials.paint("Willow", color=(48, 66, 120), roughness=0.25, grime=0.05)
    parts = []
    for sx in (-1, 1):
        parts.append(materials.assign(shapes.box("Side", (0.2, d, h - 0.4), (sx * (w / 2 - 0.1), 0, (h - 0.4) / 2 + 0.2), 0.03, 2), wood))
    parts.append(materials.assign(shapes.box("Back", (w - 0.4, 0.06, h - 0.5), (0, d / 2 - 0.03, h / 2), 0.0), back))
    parts.append(materials.assign(shapes.box("Plinth", (w, d, 0.25), (0, 0, 0.125), 0.04, 2), wood_x))
    # The cupboard below: two panelled doors (shut), a top board.
    lower = 3.2
    for sx in (-1, 1):
        parts.append(materials.assign(shapes.box("LowerDoor", (w / 2 - 0.25, 0.1, lower - 0.4), (sx * (w / 4 - 0.025), -(d / 2 - 0.02), 0.25 + (lower - 0.4) / 2 + 0.05), 0.03, 2), wood))
        parts.append(materials.assign(shapes.box("Field", (w / 2 - 0.9, 0.04, lower - 1.1), (sx * (w / 4 - 0.025), -(d / 2 + 0.04), 0.25 + (lower - 0.4) / 2 + 0.05), 0.04, 2), wood))
        knob = shapes.lathe("Knob", [(0.0, 0.0), (0.06, 0.0), (0.08, 0.06), (0.0, 0.1)], steps=10)
        shapes.turn(knob, (90, 0, 0), (sx * 0.3, -(d / 2 + 0.03), 1.8))
        parts.append(materials.assign(knob, materials.brass("ChinaKnob")))
    parts.append(materials.assign(shapes.box("Counter", (w + 0.1, d + 0.1, 0.12), (0, -0.05, lower), 0.04, 2), wood_x))
    # The glazed upper part: shelves, the glazing bars, plates and cups.
    top = h - 0.5
    for z in (lower + 1.6, lower + 3.2, top):
        parts.append(materials.assign(shapes.box("Shelf", (w - 0.4, d - 0.4, 0.08), (0, 0.1, z), 0.02, 2), wood_x))
    for k in range(5):
        x = -w / 2 + 0.2 + k * (w - 0.4) / 4
        parts.append(materials.assign(shapes.box("Bar", (0.1, 0.08, top - lower), (x, -(d / 2 - 0.05), (lower + top) / 2), 0.02, 2), wood))
    for z in (lower + 1.6, lower + 3.2):
        parts.append(materials.assign(shapes.box("Bar", (w - 0.4, 0.08, 0.08), (0, -(d / 2 - 0.05), z + 0.05), 0.02, 2), wood_x))
    rng = random.Random(11)
    for z in (lower + 0.06, lower + 1.66, lower + 3.26):
        x = -w / 2 + 0.6
        while x < w / 2 - 0.6:
            if rng.random() < 0.6:
                r = rng.uniform(0.42, 0.62)
                plate = shapes.lathe("Plate", [(0.0, 0.0), (r * 0.6, 0.0), (r, 0.05), (r * 0.98, 0.07), (r * 0.6, 0.03), (0.0, 0.03)], steps=24)
                shapes.turn(plate, (80, 0, 0), (x + r, 0.45, z + r))
                parts.append(materials.assign(plate, porcelain))
                band = shapes.lathe("Rim", [(r * 0.86, 0.045), (r * 0.97, 0.06), (r * 0.97, 0.066), (r * 0.86, 0.05)], steps=24)
                shapes.turn(band, (80, 0, 0), (x + r, 0.45, z + r))
                parts.append(materials.assign(band, rim))
                x += 2 * r + 0.15
            else:
                for _ in range(2):
                    cup = shapes.lathe("Cup", [(0.0, 0.0), (0.1, 0.0), (0.15, 0.25), (0.13, 0.26), (0.0, 0.05)], (x + 0.15, -0.1, z), steps=12)
                    parts.append(materials.assign(cup, porcelain))
                    x += 0.4
    for k, (grow, tall) in enumerate(((0.0, 0.16), (0.06, 0.1), (0.12, 0.08))):
        parts.append(materials.assign(shapes.box("Cornice", (w + grow * 0.5, d + grow * 0.5, tall), (0, -grow * 0.25, h - 0.42 + k * 0.13 + tall / 2), 0.03, 2), wood_x))
    return shapes.join(parts, "ChinaCabinet")


def utility_shelf():
    """Grey steel shelving, 8 x 9 x 2 (a Shelf item named shelf*: the
    pantry, the laundry, the garage, the attic): angle uprights, five
    shelves on the game's own heights, and what a house keeps on them: paint
    tins, jars, cans, boxes, bottles, a coil of hose."""
    w, h, d = 8.0, 9.0, 2.0
    steel = materials.paint("ShelfSteel", color=(110, 112, 108), roughness=0.5, grime=0.5)
    card = materials.paint("ShelfCard", color=(150, 118, 80), roughness=0.85, grime=0.45)
    tins = materials.by_colour("Tins", roughness=0.4)
    glass = materials.paint("Jar", color=(160, 150, 110), roughness=0.15, grime=0.3)
    parts = []
    for sx in (-1, 1):
        for sy in (-1, 1):
            post = shapes.box("Upright", (0.12, 0.12, h), (sx * (w / 2 - 0.06), sy * (d / 2 - 0.06), h / 2), 0.0)
            parts.append(materials.assign(post, steel))
    rng = random.Random(4)
    palette = [(0.5, 0.1, 0.08), (0.12, 0.2, 0.4), (0.7, 0.6, 0.2), (0.25, 0.3, 0.2), (0.6, 0.6, 0.58), (0.4, 0.25, 0.12)]
    for i in range(5):
        z = 0.2 + i * (h - 0.4) / 4  # the game's boards
        parts.append(materials.assign(shapes.box("Shelf", (w - 0.04, d - 0.04, 0.06), (0, 0, z), 0.01, 1), steel))
        parts.append(materials.assign(shapes.box("Lip", (w - 0.04, 0.02, 0.18), (0, -(d / 2 - 0.02), z - 0.06), 0.0), steel))
        if i == 4:
            break
        x = -w / 2 + 0.3
        end = w / 2 - 0.25
        while x < end - 0.4:
            kind = rng.random()
            if kind < 0.3:
                r = min(rng.uniform(0.25, 0.4), (end - x) / 2)
                tin = shapes.lathe("Tin", [(0.0, 0.0), (r, 0.0), (r, r * 2.2), (r * 0.95, r * 2.3), (0.0, r * 2.3)], (x + r, rng.uniform(-0.3, 0.2), z + 0.03), steps=16)
                shapes.colour(tin, rng.choice(palette))
                parts.append(materials.assign(tin, tins))
                x += 2 * r + 0.08
            elif kind < 0.5:
                for _ in range(rng.randint(2, 4)):
                    if x + 0.36 > end:
                        break
                    jar = shapes.lathe("Jar", [(0.0, 0.0), (0.16, 0.0), (0.17, 0.4), (0.12, 0.48), (0.12, 0.55), (0.0, 0.55)], (x + 0.18, rng.uniform(-0.4, 0.3), z + 0.03), steps=12)
                    parts.append(materials.assign(jar, glass))
                    x += 0.38
            elif kind < 0.8:
                bw = min(rng.uniform(0.9, 1.6), end - x)
                bh = rng.uniform(0.6, min(1.5, (h - 0.4) / 4 - 0.3))
                box = shapes.box("Carton", (bw, d - rng.uniform(0.3, 0.7), bh), (x + bw / 2, 0.1, z + 0.03 + bh / 2), 0.03, 2)
                parts.append(materials.assign(box, card))
                x += bw + 0.1
            else:
                for _ in range(rng.randint(2, 3)):
                    if x + 0.3 > end:
                        break
                    bottle = shapes.lathe("Bottle", [(0.0, 0.0), (0.13, 0.0), (0.13, 0.65), (0.06, 0.8), (0.05, 0.95), (0.0, 0.95)], (x + 0.15, rng.uniform(-0.3, 0.3), z + 0.03), steps=10)
                    shapes.colour(bottle, rng.choice(palette))
                    parts.append(materials.assign(bottle, tins))
                    x += 0.32
            x += rng.uniform(0.0, 0.3)
    return shapes.join(parts, "UtilityShelf")


# The dress form and the chairs ---------------------------------------------


def dress_form():
    """A dressmaker's form, 2 x 6.5 x 2 (Data/Props' Mannequin): a tripod of
    turned walnut, a pole, a padded linen torso with a waist and a hip, and
    on a short neck an egg of a head with no face; a red lace collar pinned
    on its front (so you can tell which way it faces)."""
    wood = _walnut("FormWalnut", "Z", 0.4)
    canvas = materials.fabric("FormLinen", color=(200, 186, 160), roughness=0.9)
    head = materials.paint("FormHead", color=(212, 200, 182), roughness=0.4, grime=0.35)
    lace = materials.fabric("FormLace", color=(150, 30, 40), roughness=0.9)
    brass = materials.brass("FormBrass")
    parts = []
    for k in range(3):
        a = k * math.tau / 3 + math.pi / 2
        foot = shapes.box("Foot", (0.14, 0.95, 0.12), (0, 0, 0), 0.04, 2)
        shapes.turn(foot, (-10, 0, math.degrees(a) - 90), (math.cos(a) * 0.45, math.sin(a) * 0.45, 0.14))
        parts.append(materials.assign(foot, wood))
    parts.append(materials.assign(shapes.lathe("Hub", [(0.0, 0.1), (0.2, 0.1), (0.16, 0.4), (0.0, 0.4)], steps=14), wood))
    parts.append(materials.assign(shapes.lathe("Pole", [(0.0, 0.35), (0.07, 0.35), (0.06, 2.6), (0.1, 2.68), (0.0, 2.7)], steps=12), wood))
    parts.append(materials.assign(shapes.lathe("Collet", [(0.0, 1.5), (0.1, 1.5), (0.1, 1.62), (0.0, 1.62)], steps=12), brass))
    # The torso: hips, waist, bust and shoulders, flattened front to back.
    profile = [(0.0, 2.6), (0.62, 2.62), (0.7, 2.9), (0.56, 3.35), (0.5, 3.6), (0.66, 4.1), (0.7, 4.5), (0.6, 4.95), (0.34, 5.2), (0.16, 5.28), (0.0, 5.3)]
    torso = shapes.lathe("Torso", profile, steps=28)
    for v in torso.data.vertices:
        v.co.y *= 0.62
        v.co.x *= 1.15 if v.co.z > 4.8 else 1.0  # (the shoulders square)
    parts.append(materials.assign(shapes.smooth(torso, 60), canvas))
    parts.append(materials.assign(shapes.lathe("Neck", [(0.0, 5.25), (0.16, 5.25), (0.14, 5.6), (0.0, 5.6)], steps=14), canvas))
    egg = shapes.lathe("Head", [(0.0, 5.55), (0.24, 5.62), (0.36, 5.85), (0.38, 6.05), (0.33, 6.3), (0.2, 6.45), (0.0, 6.5)], steps=24)
    parts.append(materials.assign(shapes.smooth(egg, 60), head))
    collar = shapes.box("Collar", (0.9, 0.06, 0.35), (0, -0.4, 4.95), 0.03, 2)
    parts.append(materials.assign(collar, lace))
    return shapes.join(parts, "DressForm")


def rocker():
    """A nursery rocking chair, 2.5 x 4 x 2.5 (a Chair item named rocker*):
    a spindle back, a woven seat, arms, and curved runners within its
    footprint."""
    wood = materials.wood("RockerOak", OAK_DARK, OAK_LIGHT, grain_axis="Z", scale=1.3, roughness=0.42)
    wood_x = materials.wood("RockerOakAcross", OAK_DARK, OAK_LIGHT, grain_axis="X", scale=1.3, roughness=0.42)
    rush = materials.upholstery("RockerRush", base=(150, 120, 70), figure=(160, 130, 80), roughness=0.9)
    w, d = 2.4, 2.4
    seat_z = 1.75
    parts = []
    # Runners: arcs along Y on each side.
    for sx in (-1, 1):
        for k in range(10):
            t0, t1 = k / 10, (k + 1) / 10
            y0, y1 = -d / 2 + d * t0, -d / 2 + d * t1
            z0 = 0.08 + 0.32 * (2 * t0 - 1) ** 2
            z1 = 0.08 + 0.32 * (2 * t1 - 1) ** 2
            seg = shapes.box("Runner", (0.12, math.hypot(y1 - y0, z1 - z0) + 0.02, 0.12), (0, 0, 0), 0.03, 1)
            shapes.turn(seg, (math.degrees(math.atan2(z1 - z0, y1 - y0)), 0, 0), (sx * (w / 2 - 0.12), (y0 + y1) / 2, (z0 + z1) / 2))
            parts.append(materials.assign(seg, wood_x))
        for sy in (-1, 1):
            leg = shapes.turned_leg("Leg", seat_z - 0.1, 0.11, (sx * (w / 2 - 0.12), sy * (d / 2 - 0.45), 0.1))
            parts.append(materials.assign(leg, wood))
    parts.append(materials.assign(shapes.box("Seat", (w - 0.1, d - 0.7, 0.16), (0, 0.0, seat_z), 0.05, 3), rush))
    back_y = d / 2 - 0.4
    for sx in (-1, 1):
        parts.append(materials.assign(shapes.box("Post", (0.13, 0.13, 2.3), (sx * (w / 2 - 0.15), back_y, seat_z + 1.1), 0.04, 2), wood))
        parts.append(materials.assign(shapes.box("Arm", (0.14, 1.3, 0.1), (sx * (w / 2 - 0.12), back_y - 0.6, seat_z + 0.8), 0.04, 2), wood_x))
    for i in range(6):
        x = -0.8 + i * 0.32
        parts.append(materials.assign(shapes.lathe("Spindle", [(0.0, 0.0), (0.04, 0.0), (0.05, 0.9), (0.035, 1.6), (0.0, 1.6)], (x, back_y, seat_z + 0.1), steps=8), wood))
    parts.append(materials.assign(shapes.box("Crest", (w - 0.2, 0.12, 0.42), (0, back_y, seat_z + 2.0), 0.08, 3), wood_x))
    return shapes.join(parts, "Rocker")


def stool():
    """A piano stool, 2.5 x 2.2 x 2.5 (a Chair item named stool*): a round
    buttoned seat on a turned column and three splayed feet."""
    wood = _walnut("StoolWalnut", "Z")
    velvet = materials.velvet("StoolVelvet", color=(70, 26, 30))
    parts = []
    parts.append(materials.assign(shapes.cushion("Seat", (1.6, 1.6, 0.35), (0, 0, 2.0), puff=0.06, roundness=0.9), velvet))
    parts.append(materials.assign(shapes.lathe("Rim", [(0.0, 1.72), (0.8, 1.72), (0.82, 1.82), (0.0, 1.84)], steps=32), wood))
    parts.append(materials.assign(shapes.lathe("Column", [(0.0, 0.3), (0.2, 0.3), (0.12, 0.6), (0.16, 1.0), (0.1, 1.4), (0.18, 1.62), (0.0, 1.72)], steps=16), wood))
    for k in range(3):
        a = k * math.tau / 3
        foot = shapes.box("Foot", (0.14, 1.0, 0.12), (0, 0, 0), 0.04, 2)
        shapes.turn(foot, (-14, 0, math.degrees(a) - 90), (math.cos(a) * 0.5, math.sin(a) * 0.5, 0.2))
        parts.append(materials.assign(foot, wood))
    return shapes.join(parts, "Stool")


LIVING = [
    tv_stand,
    table,
    desk,
    desk_drawer_deep,
    desk_drawer_shallow,
    cabinet,
    cabinet_door_l,
    cabinet_door_r,
    wardrobe,
    wardrobe_door_l,
    wardrobe_door_r,
    curtain,
    piano,
    china_cabinet,
    utility_shelf,
    dress_form,
    rocker,
    stool,
]
