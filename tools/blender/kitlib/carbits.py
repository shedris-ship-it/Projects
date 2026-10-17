"""The party cars' bits (LB4, docs/plans/lobby-rework.md, "The garage": the
pegboard of car bits, bought for Marks): things bolted on the outside of the
garage's station wagon (house.car: 7 x 5 x 14, its front -Y, the wheels'
middles 4.5 either side of its middle, the hubs 1 up, the roof 4.5 to 4.66
up from 1.4 behind the windscreen's top to 6.3, a rail along each edge).
The windows are dark glass with nothing behind them, so nothing goes inside.

Sketched first; the owner kept Claude's proposal for now (2026-10-16), so
MALL4 is the batch: the car split in three (its paint, tinted in the game to
the driver's, World/CarDress; the woodgrain, now a bit; the rest) and the
bits, each built in the car's own frame so it sits where the car's mesh does.
The sticker stays the game's (a SurfaceGui, its words sharp at any distance).

(Seen from behind the car, its front -y, the driver's side is +x.)
"""

import math

import bpy

from . import house, materials, shapes

W, D = 7.0, 14.0
WHEELS = (-(D / 2 - 2.5), D / 2 - 2.5)  # the wheels' middles (y)
HUB = 1.0


def _chrome(name):
    return materials.brass(name, color=(196, 198, 200), roughness=0.16)


def whitewalls(name="Whitewalls"):
    """A white band round each tyre's outer wall, between the hubcap and the
    tread: the 1950s-to-80s family car's dress-up."""
    white = materials.paint("Whitewall", color=(242, 240, 234), roughness=0.6, grime=0.15)
    parts = []
    for wy in WHEELS:
        for sx in (-1, 1):
            # (Closed round its inner rim too: open, its inside showed through.
            # Black tyre left either side of it. 0.05 thick: at 0.012 Roblox's
            # importer welded its two faces together and it shaded black, both
            # imports, 2026-10-16.)
            ring = shapes.lathe("Whitewall", [(0.72, 0.0), (0.9, 0.0), (0.9, 0.05), (0.72, 0.05), (0.72, 0.0)], steps=32)
            shapes.turn(ring, (0, sx * 90, 0), (sx * (W / 2 - 0.045), wy, HUB))
            parts.append(materials.assign(ring, white))
    return shapes.join(parts, name)


def roof_rack(name="RoofRack"):
    """Three chrome crossbars over the roof rails, and the family's luggage
    strapped on: two hard suitcases and a duffel bag."""
    chrome = _chrome("RackChrome")
    tan = materials.paint("CaseTan", color=(150, 108, 64), roughness=0.55, grime=0.4)
    green = materials.paint("CaseGreen", color=(52, 76, 58), roughness=0.5, grime=0.4)
    duffel = materials.fabric("Duffel", color=(120, 34, 34))
    strap = materials.paint("Strap", color=(30, 28, 26), roughness=0.8, grime=0.1)
    parts = []
    for y in (0.2, 2.5, 4.8):
        parts.append(materials.assign(shapes.box("RackBar", (W - 1.0, 0.12, 0.1), (0, y, 4.84), 0.03, 2), chrome))
        for sx in (-1, 1):
            parts.append(materials.assign(shapes.box("RackFoot", (0.16, 0.16, 0.16), (sx * (W / 2 - 0.6), y, 4.76), 0.03, 2), chrome))
    # The cases lie on the bars, a little askew.
    cases = [((-1.0, 1.4, 5.17), (2.4, 1.6, 0.56), tan, 4), ((1.15, 3.4, 5.14), (2.0, 1.4, 0.5), green, -6)]
    for at, size, mat, turn in cases:
        case = materials.assign(shapes.box("Suitcase", size, (0, 0, 0), 0.06, 3), mat)
        shapes.turn(case, (0, 0, turn), at)
        parts.append(case)
        handle = materials.assign(shapes.box("CaseHandle", (0.5, 0.08, 0.1), (0, 0, 0), 0.03, 2), strap)
        shapes.turn(handle, (0, 0, turn), (at[0], at[1] - size[1] / 2 - 0.02, at[2] + 0.05))
        parts.append(handle)
    bag = materials.assign(shapes.lathe("Duffel", [(0.0, -0.9), (0.32, -0.88), (0.42, -0.6), (0.44, 0.0), (0.42, 0.6), (0.32, 0.88), (0.0, 0.9)], steps=20), duffel)
    shapes.turn(bag, (0, 90, 0), (0.3, 5.3, 5.3))
    parts.append(bag)
    # A strap round each case, over its top and down its sides to the bars.
    for at, size, mat, turn in cases:
        over = materials.assign(shapes.box("RackStrap", (size[0] + 0.04, 0.12, 0.02), (0, 0, size[2] / 2 + 0.01), 0.005, 1), strap)
        sides = [
            materials.assign(shapes.box("RackStrapSide", (0.02, 0.12, size[2] + 0.02), (sx * (size[0] / 2 + 0.01), 0, 0), 0.005, 1), strap)
            for sx in (-1, 1)
        ]
        band = shapes.join([over] + sides, "RackStrapBand")
        shapes.turn(band, (0, 0, turn), at)
        parts.append(band)
    return shapes.join(parts, name)


def spotlight(name="Spotlight"):
    """An investigator's spotlight on the driver's pillar, turned to sweep a
    yard, and a CB radio's whip aerial off the back bumper, sprung at its
    foot."""
    chrome = _chrome("SpotChrome")
    lens = materials.paint("SpotLens", color=(220, 218, 200), roughness=0.05, grime=0.05)
    black = materials.paint("SpotBlack", color=(20, 20, 22), roughness=0.6, grime=0.1)
    parts = []
    # On the driver's (+x) A-pillar: an arm from the pillar, the lamp's can
    # over the wing mirror, its lens.
    parts.append(materials.assign(shapes.box("SpotArm", (0.56, 0.1, 0.1), (W / 2 - 0.13, -2.05, 3.4), 0.03, 2), chrome))
    can = shapes.lathe("SpotCan", [(0.0, -0.32), (0.2, -0.32), (0.26, -0.18), (0.26, 0.16), (0.24, 0.2), (0.0, 0.2)], steps=24)
    shapes.turn(can, (90, 0, 0), (W / 2 + 0.36, -2.15, 3.45))
    parts.append(materials.assign(can, chrome))
    glass = shapes.lathe("SpotGlass", [(0.0, 0.0), (0.22, 0.0), (0.22, 0.02), (0.0, 0.02)], steps=24)
    shapes.turn(glass, (90, 0, 0), (W / 2 + 0.36, -2.36, 3.45))
    parts.append(materials.assign(glass, lens))
    # The whip: a spring at its foot on the back bumper's other (-x) corner.
    spring = shapes.lathe("WhipSpring", [(0.0, 0.0), (0.07, 0.0), (0.07, 0.35), (0.0, 0.35)], steps=12)
    shapes.turn(spring, (0, 0, 0), (-(W / 2 - 0.4), D / 2 + 0.05, 1.3))
    parts.append(materials.assign(spring, black))
    whip = shapes.lathe("Whip", [(0.0, 0.0), (0.025, 0.0), (0.012, 4.2), (0.0, 4.2)], steps=8)
    shapes.turn(whip, (-6, 0, 0), (-(W / 2 - 0.4), D / 2 + 0.05, 1.65))
    parts.append(materials.assign(whip, chrome))
    return shapes.join(parts, name)


def bumper_sticker(text="I BRAKE FOR GHOSTS"):
    """A sticker on the tailgate, left of the plate: red letters on white,
    peeling at a corner. (No brands, no band names.)"""
    paper = materials.paint("Sticker", color=(236, 232, 220), roughness=0.5, grime=0.3)
    ink = materials.paint("StickerInk", color=(170, 30, 30), roughness=0.5, grime=0.1)
    plate = materials.assign(shapes.box("Sticker", (1.7, 0.012, 0.36), (-1.55, D / 2 + 0.012, 2.0), 0.004, 1), paper)
    curve = bpy.data.curves.new("StickerText", "FONT")
    curve.body = text
    curve.size = 0.2
    curve.align_x = "CENTER"
    curve.align_y = "CENTER"
    curve.extrude = 0.004
    words = bpy.data.objects.new("StickerText", curve)
    bpy.context.scene.collection.objects.link(words)
    words.rotation_euler = (math.radians(90), 0, math.radians(180))
    words.location = (-1.55, D / 2 + 0.022, 2.0)
    bpy.context.view_layer.objects.active = words
    for o in bpy.context.selected_objects:
        o.select_set(False)
    words.select_set(True)
    bpy.ops.object.convert(target="MESH")
    materials.assign(words, ink)
    return shapes.join([plate, words], "BumperSticker")


BITS = {
    "Whitewalls": whitewalls,
    "RoofRack": roof_rack,
    "Spotlight": spotlight,
    "BumperSticker": bumper_sticker,
}


# The car's paint under the driver's: a pale neutral grey the game tints
# (World/CarDress's BASE: a SurfaceAppearance's Color multiplies its map).
BASE = (230, 230, 230)


def car_body():
    """The paint: the lower body, the roof and the pillars."""
    return house.car(paint_color=BASE, only="body", name="MallCarBody")


def car_trim():
    """Everything else on the car as it's always been: the glass, chrome,
    tyres, hubcaps, lamps, grille and plate."""
    return house.car(only="trim", name="MallCarTrim")


def car_wood():
    """The woodgrain sides in their chrome frames (a bit since LB4)."""
    return house.car(only="wood", name="MallCarWood")


def car_whitewalls():
    return whitewalls("CarWhitewalls")


def car_roof_rack():
    return roof_rack("CarRoofRack")


def car_spotlight():
    return spotlight("CarSpotlight")


MALL4 = [car_body, car_trim, car_wood, car_whitewalls, car_roof_rack, car_spotlight]
