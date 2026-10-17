"""The lobby's story clutter (2026-10-16, the owner: "Lets do 1 and 2"): what
makes the investigators' camp look lived in and the dead mall look left
behind, sketched first for the owner to pick from (docs/plans/lobby-story.md,
docs/progress/2026-10-16-lobby-lb5/story/).

- The camp: a camp stove with its kettle on a crate of tins, the takeaway
  stack, a boombox and its tapes, the TV cart they watch the crews' tapes
  on, raincoats on a peg rail, the map of sightings and three newspaper
  clippings for the case board.
- The dead mall: a wet-floor sign and a mop bucket (by the drip), a stack
  of food-court chairs, a SALE banner fallen on the floor.

The clippings and the map are about The Halfway House: a new map brings its
own (docs/NEW-MAP.md). Their words are drafts until the story's settled.

Each piece is built in the game's frame (things.G), its front +z, standing
on y 0 or round its middle (pinned things), as the other mall batches are.
"""

import math
import random

import numpy as np

from . import materials, prints, shapes
from .atmosphere import _plastic, _surface
from .fittings import _oak
from .house import _chrome
from .mall import _atlas, _card
from .mall2 import _flat, _glass, _picture_mat, _place, _steel, _top_card
from .mall3 import _pinned
from .things import _box, _lathe, _sphere, _tube

PAPER = (232, 226, 206)
INK = (34, 30, 30)


# Pictures ------------------------------------------------------------------------


def clipping_art(headline, seed, photo=True):
    """A newspaper clipping: a headline in bold over columns of grey type,
    a photo's grey block, yellowed and torn at the edges."""
    h, w = 520, 400
    img = prints.blank(h, w, PAPER)
    rng = np.random.default_rng(seed)
    lines = headline.split("\n")
    # (As big as fits the column, under the pin at the top.)
    size = 34
    while size > 16 and max(prints.text_width(line, size) for line in lines) > w - 36:
        size -= 1
    y = 78  # (below the pin)
    for line in lines:
        prints.text(img, line, 18, y, size, INK, bold=1.1)
        y += size + 8
    y += 8
    if photo:
        prints.rect(img, 18, y, w - 18, y + 150, (120, 118, 112))
        prints.rect(img, 40, y + 60, 200, y + 150, (70, 68, 64))
        prints.rect(img, 230, y + 30, 330, y + 150, (90, 88, 84))
        y += 166
    for col in range(2):
        x0 = 18 + col * 190
        yy = y
        while yy < h - 20:
            length = rng.uniform(120, 170)
            prints.rect(img, x0, yy, x0 + length, yy + 5, (140, 136, 128))
            yy += 12
    return prints.age(img, rng, 0.12)


CLIPPINGS = [
    ("HOUSE 'NOT THERE'\nBY MORNING", 3, True),
    ("FAMILY MISSING;\nTABLE LEFT LAID", 5, True),
    ("TRUCKER: 'SOMEONE\nWAS COMING TO DINNER'", 8, False),
]


def sightings_art(seed=11):
    """A county road map: roads, a river, the quarry, the dead mall marked,
    red pins where the house was seen, a date in ballpoint by each."""
    h, w = 520, 720
    img = prints.blank(h, w, (226, 220, 196))
    rng = np.random.default_rng(seed)
    # A few fields' greens, the river, the highway across, the county roads.
    for _ in range(6):
        prints.disc(img, rng.uniform(0, w), rng.uniform(80, h), rng.uniform(40, 90), (196, 210, 170), 0.5)
    prints.stroke(img, [(0, 400), (160, 360), (300, 390), (470, 320), (600, 340), (720, 300)], 10, (120, 150, 200))
    prints.stroke(img, [(0, 250), (200, 230), (420, 245), (720, 210)], 9, (210, 120, 50))
    prints.stroke(img, [(0, 250), (200, 230), (420, 245), (720, 210)], 3, (240, 200, 120))
    roads = [
        [(120, 70), (150, 160), (140, 240), (180, 380), (170, 520)],
        [(330, 80), (350, 200), (330, 240)],
        [(420, 245), (480, 330), (560, 430), (600, 520)],
        [(600, 60), (580, 150), (620, 230), (700, 300)],
        [(200, 230), (260, 300), (250, 450)],
    ]
    for road in roads:
        prints.stroke(img, road, 4, (150, 120, 90))
    prints.rect(img, 300, 196, 360, 232, (150, 150, 150))
    prints.text(img, "MALL", 306, 202, 18, INK, bold=0.6)
    prints.text(img, "QUARRY", 560, 98, 18, INK, bold=0.6)
    prints.text(img, "RIVER", 60, 404, 16, (70, 100, 150))
    pen = (40, 56, 130)
    for k, (x, y) in enumerate([(120, 120), (470, 140), (600, 400), (210, 440), (420, 330), (650, 220)]):
        prints.disc(img, x, y, 9, (190, 30, 30))
        prints.text(img, "%d/%d" % (3 + k, 4 + (k * 7) % 25), x + 14, y - 8, 16, pen)
    prints.text(img, "SIGHTINGS 88-0412", 20, 40, 26, INK, bold=0.9)
    return prints.age(img, rng, 0.1)


def wet_floor_art():
    """CAUTION / WET FLOOR, the slipping figure, on yellow."""
    h, w = 520, 300
    img = prints.blank(h, w, (240, 196, 30))
    prints.text(img, "CAUTION", (w - prints.text_width("CAUTION", 44)) / 2, 30, 44, INK, bold=1.2)
    prints.rect(img, 30, 92, w - 30, 98, INK)
    # The figure slipping.
    prints.disc(img, 168, 160, 22, INK)
    prints.stroke(img, [(160, 184), (130, 270)], 16, INK)
    prints.stroke(img, [(150, 200), (90, 180)], 12, INK)
    prints.stroke(img, [(150, 205), (210, 230)], 12, INK)
    prints.stroke(img, [(130, 270), (190, 300)], 13, INK)
    prints.stroke(img, [(130, 270), (80, 320)], 13, INK)
    prints.stroke(img, [(40, 340), (260, 340)], 6, INK)
    prints.text(img, "WET", (w - prints.text_width("WET", 50)) / 2, 380, 50, INK, bold=1.2)
    prints.text(img, "FLOOR", (w - prints.text_width("FLOOR", 50)) / 2, 440, 50, INK, bold=1.2)
    return prints.age(img, np.random.default_rng(4), 0.06)


def banner_art():
    """The SALE banner: red letters on white vinyl, EVERYTHING MUST GO."""
    h, w = 300, 800
    img = prints.blank(h, w, (238, 236, 228))
    prints.text(img, "SALE", (w - prints.text_width("SALE", 170, 1.1)) / 2, 20, 170, (196, 30, 34), spacing=1.1, bold=2.0)
    prints.text(img, "EVERYTHING MUST GO", (w - prints.text_width("EVERYTHING MUST GO", 40)) / 2, 222, 40, (40, 40, 60), bold=0.9)
    return prints.age(img, np.random.default_rng(9), 0.12)


def tape_label(text, seed):
    img = prints.blank(60, 300, (236, 232, 220))
    prints.text(img, text, 10, 14, 30, (40, 56, 130))
    return prints.age(img, np.random.default_rng(seed), 0.08)


def pizza_lid():
    img = prints.blank(400, 400, (190, 150, 100))
    prints.disc(img, 200, 170, 110, (180, 40, 34))
    prints.disc(img, 200, 170, 92, (236, 220, 190))
    prints.text(img, "HOT", (400 - prints.text_width("HOT", 46)) / 2, 128, 46, (180, 40, 34), bold=1.2)
    prints.text(img, "PIZZA", (400 - prints.text_width("PIZZA", 46)) / 2, 176, 46, (180, 40, 34), bold=1.2)
    prints.text(img, "WE DELIVER LATE", (400 - prints.text_width("WE DELIVER LATE", 26)) / 2, 320, 26, (60, 40, 30), bold=0.6)
    prints.disc(img, 300, 300, 40, (150, 110, 60), 0.35)  # (a grease ring)
    return prints.age(img, np.random.default_rng(2), 0.1)


# The camp -------------------------------------------------------------------------------


def camp_stove():
    """A green two-burner camp stove (2 x 0.5 x 1.1), its lid up for a
    windscreen, a dented kettle on one ring and a pot on the other."""
    green = materials.paint("StoveGreen", color=(48, 84, 52), roughness=0.45, grime=0.4)
    black = _plastic("StoveBlack", (24, 24, 24), 0.6)
    tin = _steel("StoveTin", 0.4)
    W, D = 2.0, 1.1
    parts = [materials.assign(_box("Body", (W, 0.35, D), (0, 0.175, 0), 0.03, 2), green)]
    parts.append(materials.assign(_box("Lid", (W, D * 0.95, 0.04), (0, 0.35 + D * 0.95 / 2, -D / 2 + 0.02), 0.02, 1), green))
    for sx in (-1, 1):
        flap = materials.assign(_box("Flap", (0.04, 0.4, D * 0.8), (0, 0, 0), 0.01, 1), green)
        parts.append(_place(flap, (0, 0, 0), (sx * (W / 2 - 0.02), 0.55, -0.05)))
    for sx in (-1, 1):
        parts.append(materials.assign(_lathe("Ring", [(0.0, 0.35), (0.28, 0.35), (0.28, 0.38), (0.0, 0.38)], (sx * 0.5, 0, 0.1), 20), black))
    kettle = _lathe("Kettle", [(0.0, 0.38), (0.24, 0.38), (0.27, 0.5), (0.24, 0.66), (0.12, 0.74), (0.04, 0.76), (0.0, 0.77)], (-0.5, 0, 0.1), 22)
    parts.append(materials.assign(kettle, tin))
    parts.append(materials.assign(_tube("Spout", [(-0.3, 0.5, 0.1), (-0.15, 0.62, 0.1), (-0.08, 0.7, 0.1)], [0.04, 0.03, 0.025], 8), tin))
    parts.append(materials.assign(_tube("Handle", [(-0.68, 0.72, 0.1), (-0.5, 0.92, 0.1), (-0.32, 0.72, 0.1)], 0.02, 6), black))
    pot = _lathe("Pot", [(0.0, 0.38), (0.26, 0.38), (0.27, 0.62), (0.25, 0.62), (0.24, 0.42), (0.0, 0.42)], (0.5, 0, 0.1), 22)
    parts.append(materials.assign(pot, tin))
    obj = shapes.join(parts, "CampStove")
    obj["bake_size"] = 512
    return obj


def tin_crate():
    """A slatted produce crate (2 x 1.2 x 1.4) full of tins, their labels
    faded. (The camp stove stands on it in the garage, so nothing sits on
    its top.)"""
    crate = _oak("CrateWood", axis="X")
    rng = random.Random(4)
    labels = [_plastic("TinLabel%d" % i, c, 0.5) for i, c in enumerate([(170, 40, 34), (220, 190, 70), (60, 90, 140), (60, 110, 60)])]
    tin = _steel("TinMetal", 0.35)
    W, H, D = 2.0, 1.2, 1.4
    parts = []
    for y in (0.2, 0.6, 1.0):
        for sz in (-1, 1):
            parts.append(materials.assign(_box("Slat", (W, 0.25, 0.06), (0, y, sz * (D / 2 - 0.03)), 0.01, 1), crate))
        for sx in (-1, 1):
            # (Between the front and back slats: overlapping them at the
            # corners, faces fought and showed through.)
            parts.append(materials.assign(_box("Slat", (0.06, 0.25, D - 0.12), (sx * (W / 2 - 0.03), y, 0), 0.01, 1), crate))
    parts.append(materials.assign(_box("Bottom", (W, 0.06, D), (0, 0.03, 0), 0.0, 1), crate))
    for i in range(4):
        for j in range(3):
            x, z = -0.7 + i * 0.47, -0.45 + j * 0.45
            top = H - 0.14 + rng.uniform(-0.05, 0.0)
            parts.append(materials.assign(_lathe("Tin", [(0.0, top - 0.5), (0.19, top - 0.5), (0.19, top), (0.0, top)], (x, 0, z), 14), tin))
            parts.append(materials.assign(_lathe("Label", [(0.195, top - 0.44), (0.195, top - 0.08)], (x, 0, z), 14), rng.choice(labels)))
    return shapes.join(parts, "TinCrate")


def pizza_boxes():
    """Takeaway: four pizza boxes stacked askew (1.6 x 0.6 x 1.6), the top
    lid printed, two paper coffee cups on it."""
    card = materials.paint("PizzaCard", color=(190, 150, 100), roughness=0.9, grime=0.35)
    pixels, (lid,) = _atlas([pizza_lid()])
    picture = _picture_mat("PizzaLid", pixels, 0.4, roughness=0.85)
    cup = _plastic("CupWhite", (236, 232, 222), 0.6)
    band = _plastic("CupBand", (170, 40, 34), 0.5)
    parts = []
    for k in range(4):
        b = materials.assign(_box("Box", (1.6, 0.13, 1.6), (0, 0, 0), 0.01, 1), card)
        parts.append(_place(b, (0, 0, (k * 7) % 11 - 5), (0.03 * k, 0.065 + k * 0.135, -0.02 * k)))
    top = 4 * 0.135
    parts.append(_place(_top_card("Lid", picture, 1.56, 1.56, (0, 0, 0), lid), (0, 0, 10), (0.09, top + 0.002, -0.06)))
    for x, z in ((0.35, 0.3), (-0.25, 0.4)):
        parts.append(materials.assign(_lathe("Cup", [(0.0, top), (0.12, top), (0.16, top + 0.42), (0.0, top + 0.42)], (x, 0, z), 14), cup))
        parts.append(materials.assign(_lathe("Band", [(0.135, top + 0.15), (0.15, top + 0.28)], (x, 0, z), 14), band))
    obj = shapes.join(parts, "PizzaBoxes")
    obj["bake_size"] = 512
    return obj


def boombox():
    """A twin-deck boombox (2.2 x 1.2 x 0.6): silver, two speakers, the
    cassette decks between, a handle and an aerial; tapes beside it."""
    silver = _plastic("BoomSilver", (176, 178, 182), 0.35)
    black = _plastic("BoomBlack", (22, 22, 24), 0.5)
    chrome = _chrome("BoomChrome")
    W, H, D = 2.2, 1.0, 0.55
    y0 = H / 2
    parts = [materials.assign(_box("Body", (W, H, D), (0, y0, 0), 0.08, 3), silver)]
    for sx in (-1, 1):
        cone = _lathe("Speaker", [(0.0, 0.0), (0.36, 0.0), (0.36, 0.04), (0.06, 0.18), (0.0, 0.18)], (0, 0, 0), 24)
        parts.append(materials.assign(_place(cone, (90, 0, 0), (sx * 0.72, y0 - 0.05, D / 2 + 0.01)), black))
        ring = _lathe("Rim", [(0.36, 0.0), (0.4, 0.0), (0.4, 0.05), (0.36, 0.05)], (0, 0, 0), 24)
        parts.append(materials.assign(_place(ring, (90, 0, 0), (sx * 0.72, y0 - 0.05, D / 2)), chrome))
    for sx in (-1, 1):
        parts.append(materials.assign(_box("Deck", (0.34, 0.42, 0.04), (sx * 0.19, y0 - 0.1, D / 2 + 0.01), 0.01, 1), black))
    parts.append(materials.assign(_box("Dial", (0.7, 0.14, 0.04), (0, y0 + 0.3, D / 2 + 0.01), 0.01, 1), black))
    parts.append(materials.assign(_tube("Handle", [(-0.8, H, 0), (-0.75, H + 0.3, 0), (0.75, H + 0.3, 0), (0.8, H, 0)], 0.05, 8), chrome))
    parts.append(materials.assign(_tube("Aerial", [(0.95, H, -0.15), (1.2, H + 1.4, -0.3)], [0.025, 0.012], 6), chrome))
    rng = random.Random(6)
    for k in range(3):
        t = materials.assign(_box("Tape", (0.5, 0.08, 0.32), (0, 0, 0), 0.01, 1), _plastic("TapeShell%d" % k, (30, 30, 30)))
        parts.append(_place(t, (0, 0, rng.uniform(-30, 30)), (1.55 + rng.uniform(-0.1, 0.1), 0.04 + 0.08 * k, rng.uniform(-0.1, 0.1))))
    obj = shapes.join(parts, "Boombox")
    obj["bake_size"] = 512
    return obj


def tv_cart():
    """The AV cart they watch the crews' tapes on (2.6 x 4.4 x 1.8): a steel
    cart on casters, a woodgrain TV on top, the VCR and a stack of labelled
    tapes on the shelf below."""
    steel = _steel("CartSteel", 0.4)
    black = _plastic("CartBlack", (24, 24, 26), 0.5)
    wood = materials.wood("TvWood", (70, 46, 28), (120, 84, 52), grain_axis="X", scale=1.0, roughness=0.4)
    glass = _glass("TvGlass", (30, 36, 34))
    W, D = 2.6, 1.8
    parts = []
    for y in (0.5, 2.3):
        parts.append(materials.assign(_box("Shelf", (W, 0.08, D), (0, y, 0), 0.02, 1), steel))
    for sx in (-1, 1):
        for sz in (-1, 1):
            parts.append(materials.assign(_box("Post", (0.08, 2.0, 0.08), (sx * (W / 2 - 0.06), 1.35, sz * (D / 2 - 0.06)), 0.01, 1), steel))
            parts.append(materials.assign(_sphere("Caster", 0.14, (sx * (W / 2 - 0.1), 0.14, sz * (D / 2 - 0.1)), 10, 5), black))
    # The TV: woodgrain case, a dark convex screen, the knobs.
    parts.append(materials.assign(_box("TvCase", (2.4, 1.8, 1.6), (0, 2.34 + 0.9, 0), 0.06, 2), wood))
    parts.append(materials.assign(shapes.cushion("Screen", (1.7, 0.14, 1.3), (-0.25, -0.8, 2.34 + 0.95), puff=0.04, levels=2, roundness=0.55), glass))
    for k in range(2):
        parts.append(materials.assign(_lathe("Knob", [(0.0, 0.0), (0.08, 0.0), (0.08, 0.06), (0.0, 0.07)], (0, 0, 0), 12), black))
        parts[-1] = _place(parts[-1], (90, 0, 0), (0.95, 2.34 + 1.2 - k * 0.4, 0.81))
    # The VCR and the tapes.
    parts.append(materials.assign(_box("Vcr", (1.6, 0.3, 1.2), (-0.3, 0.69, 0), 0.02, 1), black))
    parts.append(materials.assign(_box("VcrSlot", (0.7, 0.05, 0.02), (-0.4, 0.74, 0.61), 0.0, 1), _plastic("VcrSlot", (8, 8, 8))))
    labels = [tape_label(t, i) for i, t in enumerate(["88-0412 CREW 3", "88-0412 CREW 5", "CH 19 NIGHTS", "88-0412 HALL"])]
    pixels, rects = _atlas(labels)
    picture = _picture_mat("CartLabels", pixels, 0.5)
    for k, rect in enumerate(rects):
        y = 0.54 + 0.12 + k * 0.24
        parts.append(materials.assign(_box("Vhs", (0.75, 0.22, 1.1), (0.75, y, 0), 0.01, 1), black))
        parts.append(_card("Label", picture, 0.6, 0.12, (0.75, y, 0.553), 1, rect))
    return shapes.join(parts, "TvCart")


def raincoats():
    """A peg rail on the wall (4 x 3.6 x 0.6) with three yellow raincoats
    and a torch on its lanyard. Its back is on the wall (z 0), front +z."""
    rail = _oak("PegRail", axis="X")
    coat = materials.paint("Raincoat", color=(226, 186, 36), roughness=0.35, grime=0.3)
    black = _plastic("PegTorch", (30, 30, 30), 0.5)
    parts = [materials.assign(_box("Rail", (4.0, 0.3, 0.12), (0, 3.4, 0.06), 0.02, 1), rail)]
    seam = materials.paint("RaincoatSeam", color=(170, 136, 26), roughness=0.4, grime=0.3)
    # (The boutique's jacket cut long: shoulders off the peg, the sleeves
    # hanging at the sides, clockwise as _flat wants it, never crossing.)
    outline = [(-0.2, 0.0), (0.2, 0.0), (0.66, -0.1), (0.8, -1.6), (0.6, -1.62), (0.64, -2.4), (-0.64, -2.4), (-0.6, -1.62), (-0.8, -1.6), (-0.66, -0.1)]
    for k, x in enumerate((-1.3, 0.0, 1.3)):
        parts.append(materials.assign(_tube("Peg", [(x, 3.4, 0.1), (x, 3.45, 0.32)], 0.04, 8), rail))
        c = materials.assign(_flat("Coat", outline, -0.07, 0.07), coat)
        parts.append(_place(c, (0, 0, (k - 1) * 4), (x, 3.3, 0.24)))
        hood = shapes.cushion("Hood", (0.6, 0.12, 0.55), (x, -0.13, 3.05), puff=0.05, levels=2, roundness=0.7)
        parts.append(materials.assign(hood, coat))
        parts.append(materials.assign(_box("Placket", (0.06, 2.3, 0.02), (x, 2.12, 0.32), 0.0, 1), seam))
    parts.append(materials.assign(_tube("Lanyard", [(1.8, 3.45, 0.32), (1.75, 2.9, 0.3)], 0.012, 5), black))
    parts.append(materials.assign(_lathe("Torch", [(0.0, -0.5), (0.1, -0.5), (0.13, -0.1), (0.1, 0.0), (0.0, 0.0)], (1.75, 2.9, 0.3), 12), black))
    return shapes.join(parts, "Raincoats")


def sightings_map():
    return _pinned("SightingsMap", sightings_art(), 3.6, 2.6, (200, 30, 30))


def _clipping(i):
    headline, seed, photo = CLIPPINGS[i]
    obj = _pinned("Clipping%s" % "ABC"[i], clipping_art(headline, seed, photo), 1.0, 1.3, (220, 200, 40))
    obj["bake_size"] = 512
    return obj


def clipping_a():
    return _clipping(0)


def clipping_b():
    return _clipping(1)


def clipping_c():
    return _clipping(2)


# The dead mall ----------------------------------------------------------------------------


def wet_floor_sign():
    """The yellow A-frame (1.1 x 2.2 x 0.9): CAUTION / WET FLOOR both sides."""
    yellow = _plastic("SignYellow", (240, 196, 30), 0.4)
    pixels, (face,) = _atlas([wet_floor_art()])
    picture = _picture_mat("WetFloor", pixels, 0.5, roughness=0.4)
    parts = []
    for side in (-1, 1):
        panel = shapes.join(
            [
                materials.assign(_box("Panel", (1.1, 2.1, 0.05), (0, 1.05, 0), 0.03, 2), yellow),
                _card("Face", picture, 0.96, 1.7, (0, 1.0, 0.03), 1, face),
            ],
            "Panel",
        )
        # (Each leans in at the top, toward the other.)
        parts.append(_place(panel, (-12, 0, 90 - 90 * side), (0, 0, side * 0.44)))
    parts.append(materials.assign(_tube("Handle", [(-0.3, 2.0, 0), (0, 2.14, 0), (0.3, 2.0, 0)], 0.04, 6), yellow))
    obj = shapes.join(parts, "WetFloorSign")
    obj["bake_size"] = 512
    return obj


def mop_bucket():
    """A yellow mop bucket on casters with its wringer (1.6 x 2.4 x 1.1), the
    mop left standing in it, the water gone grey."""
    yellow = _plastic("BucketYellow", (232, 190, 40), 0.45)
    grey = materials.paint("BucketWater", color=(70, 74, 70), roughness=0.08, grime=0.2)
    black = _plastic("BucketBlack", (24, 24, 24), 0.6)
    wood = _oak("MopHandle", axis="Z")
    strands = materials.fabric("MopStrands", color=(170, 160, 136))
    bucket = _lathe("Bucket", [(0.0, 0.15), (0.6, 0.15), (0.75, 0.9), (0.68, 0.9), (0.55, 0.22), (0.0, 0.22)], (0, 0, 0), 4)
    bucket = _place(bucket, (0, 0, 45), (0, 0, 0))
    parts = [materials.assign(bucket, yellow)]
    parts.append(materials.assign(_box("Water", (0.9, 0.02, 0.9), (0, 0.7, 0), 0.0, 1), grey))
    parts.append(materials.assign(_box("Wringer", (0.5, 0.5, 1.0), (0.45, 1.1, 0), 0.05, 2), yellow))
    parts.append(materials.assign(_tube("Lever", [(0.45, 1.3, 0.3), (0.5, 2.2, 0.35)], 0.04, 6), black))
    for sx in (-1, 1):
        for sz in (-1, 1):
            parts.append(materials.assign(_sphere("Caster", 0.08, (sx * 0.5, 0.08, sz * 0.5), 8, 4), black))
    parts.append(materials.assign(_tube("Mop", [(-0.25, 0.55, 0.0), (-0.45, 3.4, -0.15)], 0.045, 8), wood))
    parts.append(materials.assign(shapes.cushion("Head", (0.5, 0.5, 0.4), (-0.25, 0.0, 0.5), puff=0.2, levels=2, roundness=0.8), strands))
    obj = shapes.join(parts, "MopBucket")
    obj["bake_size"] = 512
    return obj


def stacked_chairs():
    """Five food-court chairs stacked (1.8 x 4.4 x 1.8): moulded orange
    seats on chrome legs, the stack leaning a little."""
    orange = _plastic("ChairOrange", (212, 110, 40), 0.35)
    chrome = _chrome("ChairChrome")
    parts = []
    for k in range(5):
        y = 1.5 + k * 0.42
        dx = k * 0.03
        parts.append(materials.assign(_box("Seat", (1.5, 0.08, 1.4), (dx, y, 0.05), 0.06, 3), orange))
        back = materials.assign(_box("Back", (1.5, 1.0, 0.08), (0, 0, 0), 0.06, 3), orange)
        parts.append(_place(back, (-8, 0, 0), (dx, y + 0.55, -0.68)))
        for sx in (-1, 1):
            # Square tube, a straight length each (a bent tube turned inside
            # out at its corners): two legs down and the runner along the floor.
            x = dx + sx * 0.72
            for z in (0.62, -0.56):
                parts.append(materials.assign(_box("Leg", (0.06, 1.48, 0.06), (x, y - 0.76, z), 0.01, 1), chrome))
            parts.append(materials.assign(_box("Runner", (0.06, 0.06, 1.24), (x, y - 1.5, 0.03), 0.01, 1), chrome))
    return shapes.join(parts, "StackedChairs")


def sale_banner():
    """A vinyl SALE banner fallen to the floor (7 x 0.5 x 2.6), crumpled,
    the letters half lost in its folds."""
    pixels, (rect,) = _atlas([banner_art()])
    picture = _picture_mat("SaleBanner", pixels, 0.5, roughness=0.6)
    nx, nz = 40, 16
    L, D = 7.0, 2.6
    rng = random.Random(12)
    phases = [rng.uniform(0, math.tau) for _ in range(4)]
    verts, uvs, faces = [], [], []
    u0, v0, u1, v1 = rect
    for j in range(nz + 1):
        for i in range(nx + 1):
            s, t = i / nx, j / nz
            x = (s - 0.5) * L
            z = (t - 0.5) * D
            y = 0.03 + 0.22 * (1 + math.sin(s * 9 + phases[0] + t * 2)) * (0.5 + 0.5 * math.sin(s * 3 + phases[1]))
            y += 0.35 * max(0.0, math.sin(s * 5 + phases[2])) * t
            y += 0.18 * max(0.0, math.sin(s * 17 + t * 5 + phases[3]))
            # (Its far corner lifted where it caught on something.)
            y += 0.9 * max(0.0, s - 0.85) * 6.6 * t
            verts.append((x, y, z))
            uvs.append((u0 + (u1 - u0) * s, v1 - (v1 - v0) * t))
    for j in range(nz):
        for i in range(nx):
            a = j * (nx + 1) + i
            faces.append((a, a + 1, a + nx + 2, a + nx + 1))
    cloth = _surface("Banner", verts, faces, uvs, (0, 1, 0))
    # Its back, a hair under it: the lifted corner shows it (one face alone
    # is a hole from below in the game).
    under = _surface("BannerBack", [(x, y - 0.006, z) for x, y, z in verts], faces, None, (0, -1, 0))
    back = materials.paint("BannerBack", color=(220, 218, 210), roughness=0.6, grime=0.2)
    return shapes.join([materials.assign(cloth, picture), materials.assign(under, back)], "SaleBanner")


CAMP = [camp_stove, tin_crate, pizza_boxes, boombox, tv_cart, raincoats, sightings_map, clipping_a, clipping_b, clipping_c]
DEAD = [wet_floor_sign, mop_bucket, stacked_chairs, sale_banner]
CLUTTER = CAMP + DEAD
