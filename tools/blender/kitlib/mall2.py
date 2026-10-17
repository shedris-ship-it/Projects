"""The lobby's mall, its second batch (docs/plans/lobby-rework.md, LB1b, kit.py
mall2): the shops, laid out by hand (the owner: "be very deliberate with
placement in the shops"; Data/Mall has where each stands).

- The diner: the back bar with its coffee and grill, the counter, the stools,
  the booths' seats and tables, the two record boards' frames, the jukebox,
  the black and white check floor.
- The video store: the wall shelves of tapes face out, the islands, the
  rental counter, its TV, the case's standee.
- The arcade: three cabinets (HOUSE CALL, NIGHT DRIVE, a dead one), the
  prize counter and its wall, shut, the change machine, the carpet.
- Electronics: the showroom TVs and their long stand, the wall shelves of
  boxed sets, the glass counter of torches.
- The boutique: the round rack of jackets, the rails of tops and bottoms, the
  shoe wall, the slatwall, the changing booth, the cash wrap.

The dress forms in the boutique's window and the diner's coat rack are the
house's own pieces (Data/Kit `MallDressForm`, `MallCoatRack`).

Each piece is built round the middle of the block it dresses, in the game's
frame (things.G), its front +z; kit.py's `at` is where its box sits from
that middle. Every made-up title, word and label here is invented: no real
film, game, brand or logo.
"""

import math
import random

import bmesh
import bpy
import numpy as np
from mathutils import Vector, geometry

from . import materials, prints, shapes
from .atmosphere import _plastic, _surface
from .fittings import _oak
from .house import _chrome
from .mall import _atlas, _card, _side_prism
from .materials import Nodes, _srgb
from .things import G, S, _box, _lathe, _new, _sphere, _torus, _tube

for _ch, _rows in {
    "Z": ["#####", "    #", "   # ", "  #  ", " #   ", "#    ", "#####"],
    "J": ["  ###", "   # ", "   # ", "   # ", "#  # ", "#  # ", " ##  "],
    "!": ["  #  ", "  #  ", "  #  ", "  #  ", "  #  ", "     ", "  #  "],
    "?": [" ### ", "#   #", "    #", "   # ", "  #  ", "     ", "  #  "],
}.items():
    prints.FONT.setdefault(_ch, _rows)


# Materials -------------------------------------------------------------------


def _steel(name, roughness=0.35):
    """Brushed stainless steel: the diner's counters, the change machine."""
    return materials.brass(name, color=(168, 170, 172), roughness=roughness)


def _vinyl(name, color=(166, 30, 34)):
    """Diner vinyl: glossy, creased."""
    return materials.paint(name, color=color, roughness=0.38, grime=0.25)


def _formica(name, color=(228, 224, 214)):
    return materials.paint(name, color=color, roughness=0.32, grime=0.18)


def _laminate(name, color):
    return materials.paint(name, color=color, roughness=0.45, grime=0.2)


def _glass(name, color=(34, 44, 48)):
    """Glass as Roblox will draw it, opaque: dark and glossy."""
    return materials.paint(name, color=color, roughness=0.06, grime=0.04)


def _checker(name, dark=(30, 30, 32), light=(226, 222, 210), size=1.0):
    """Black and white check, `size` studs a square, worn and grimy."""
    mat = bpy.data.materials.new(name)
    n = Nodes(mat)
    m = n.mapping(scale=(1.0, 1.0, 1.0))
    xyz = n.add("ShaderNodeSeparateXYZ")
    n.link(m.outputs["Vector"], xyz.inputs["Vector"])
    fx = n.math("FLOOR", n.math("DIVIDE", xyz.outputs["X"], size).outputs["Value"])
    fy = n.math("FLOOR", n.math("DIVIDE", xyz.outputs["Y"], size).outputs["Value"])
    parity = n.math("MODULO", n.math("ADD", fx.outputs["Value"], fy.outputs["Value"]).outputs["Value"], 2.0)
    absolute = n.math("ABSOLUTE", parity.outputs["Value"])
    tile = n.ramp(absolute.outputs["Value"], [(0.0, _srgb(dark)), (0.5, _srgb(dark)), (0.51, _srgb(light)), (1.0, _srgb(light))])
    blotch = n.noise(m.outputs["Vector"], 1.4, 5.0, 0.6)
    dirty = n.ramp(blotch.outputs["Fac"], [(0.0, (1, 1, 1, 1)), (0.55, (1, 1, 1, 1)), (1.0, (0.7, 0.67, 0.6, 1))])
    c = n.mix_colour(tile.outputs["Color"], dirty.outputs["Color"], 1.0, "MULTIPLY")
    n.link(c, n.bsdf.inputs["Base Color"])
    rough = n.math("MULTIPLY_ADD", blotch.outputs["Fac"], 0.3, 0.22)
    n.link(rough.outputs["Value"], n.bsdf.inputs["Roughness"])
    return mat


# Shapes ----------------------------------------------------------------------


def _flat(name, outline, z0, z1):
    """An outline in the game's x-y plane [(x, y), ...] extruded from z0 to z1,
    its ends tessellated so a concave one (a shirt, a pair of trousers) keeps
    inside its outline (mall._side_prism's lesson)."""
    bm = bmesh.new()
    a = [bm.verts.new(G(x, y, z0)) for x, y in outline]
    b = [bm.verts.new(G(x, y, z1)) for x, y in outline]
    k = len(outline)
    for i in range(k):
        j = (i + 1) % k
        bm.faces.new((a[i], a[j], b[j], b[i]))
    for t in geometry.tessellate_polygon([[Vector((x, y, 0.0)) for x, y in outline]]):
        bm.faces.new((a[t[2]], a[t[1]], a[t[0]]))
        bm.faces.new((b[t[0]], b[t[1]], b[t[2]]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    # (The z1 end faces toward +z in the game, Blender's -y; if not, the
    # whole solid came out inside out.)
    for f in bm.faces:
        ys = [v.co.y for v in f.verts]
        if max(ys) - min(ys) < 1e-6 and abs(ys[0] + z1) < 1e-6:
            f.normal_update()
            if f.normal.y * (1 if z1 > z0 else -1) > 0:
                bmesh.ops.reverse_faces(bm, faces=bm.faces)
            break
    return shapes.smooth(_new(name, bm), 30)


def _named(obj, name):
    obj.name = name
    obj.data.name = name
    return obj


def _place(obj, degrees, at):
    """A part built round the origin, turned (degrees about Blender's axes:
    (tilt about x, 0, turn about the game's y)) and put at the game's `at`."""
    return shapes.turn(obj, degrees, G(*at))


def _side_card(name, mat, d, h, at, facing_x, rect):
    """A flat picture standing in the z-y plane round `at`, facing +x or -x,
    showing `rect` of its material's picture (mall._atlas)."""
    x0, y0, z0 = at
    near, far = (z0 + d / 2, z0 - d / 2) if facing_x > 0 else (z0 - d / 2, z0 + d / 2)
    u0, v0, u1, v1 = rect
    verts = [(x0, y0 - h / 2, near), (x0, y0 - h / 2, far), (x0, y0 + h / 2, far), (x0, y0 + h / 2, near)]
    uvs = [(u0, v0), (u1, v0), (u1, v1), (u0, v1)]
    return materials.assign(_surface(name, verts, [(0, 1, 2, 3)], uvs, (facing_x, 0, 0)), mat)


def _top_card(name, mat, w, d, at, rect):
    """A flat picture lying face up round `at`, its top toward -z (away from
    whoever stands at the +z front)."""
    x0, y0, z0 = at
    u0, v0, u1, v1 = rect
    verts = [(x0 - w / 2, y0, z0 + d / 2), (x0 + w / 2, y0, z0 + d / 2), (x0 + w / 2, y0, z0 - d / 2), (x0 - w / 2, y0, z0 - d / 2)]
    uvs = [(u0, v0), (u1, v0), (u1, v1), (u0, v1)]
    return materials.assign(_surface(name, verts, [(0, 1, 2, 3)], uvs, (0, 1, 0)), mat)


def _grid(pictures, cols):
    """Pictures of one size in a grid (rows top to bottom), and each one's
    place in UVs, (u0, v0, u1, v1)."""
    h, w = pictures[0].shape[:2]
    rows = (len(pictures) + cols - 1) // cols
    out = np.zeros((rows * h, cols * w, 3))
    rects = []
    for i, p in enumerate(pictures):
        r, c = divmod(i, cols)
        out[r * h : (r + 1) * h, c * w : (c + 1) * w] = p
        rects.append((c / cols, 1 - (r + 1) / rows, (c + 1) / cols, 1 - r / rows))
    return out, rects


# Pictures ----------------------------------------------------------------------

TITLES = ["SHADOW", "PORCH LIGHT", "MOTEL 9", "CREEK RD", "NEON", "THE ATTIC", "LAST BUS", "STORM", "LASER COP", "FANG", "DUSK", "TAPE 4", "CHILL", "HAUNT", "BLAST", "THE MALL"]
COVER_COLOURS = [(150, 20, 24), (18, 18, 22), (24, 40, 92), (88, 30, 110), (220, 180, 40), (232, 228, 220), (30, 80, 60), (200, 90, 30)]


def vhs_covers(seed=41):
    """Sixteen made-up rental covers, 128 x 224 each: a colour, a picture of
    a moon, mountains, a house or stripes, the title in block letters, the
    rental sticker."""
    rng = np.random.default_rng(seed)
    covers = []
    for i, title in enumerate(TITLES):
        bg = COVER_COLOURS[i % len(COVER_COLOURS)]
        img = prints.blank(224, 128, bg)
        ink = (240, 232, 210) if sum(bg) < 400 else (20, 20, 24)
        accent = COVER_COLOURS[(i * 3 + 2) % len(COVER_COLOURS)]
        kind = i % 4
        if kind == 0:
            prints.disc(img, 64 + rng.uniform(-20, 20), 70, 26, (236, 228, 196))
        elif kind == 1:
            for k in range(3):
                x = 10 + k * 40
                prints.stroke(img, [(x, 150), (x + 26, 96 - k * 6), (x + 52, 150)], 5, accent)
        elif kind == 2:
            prints.rect(img, 34, 90, 94, 150, (16, 14, 14))
            prints.stroke(img, [(28, 92), (64, 56), (100, 92)], 6, (16, 14, 14))
            prints.rect(img, 58, 104, 70, 116, (240, 200, 90))
        else:
            for k in range(5):
                prints.rect(img, 0, 70 + k * 16, 128, 78 + k * 16, accent)
        words = title.split()
        y = 160 if len(words) == 1 else 152
        for word in words:
            size = min(22, 118 / max(1, len(word)) * 7 / 6)
            prints.text(img, word, (128 - prints.text_width(word, size)) / 2, y, size, ink, bold=0.4)
            y += size + 4
        prints.rect(img, 0, 0, 128, 18, (20, 20, 22))
        prints.text(img, "VHS", 8, 5, 9, (220, 220, 220))
        prints.disc(img, 112, 206, 9, (250, 210, 60))
        covers.append(prints.age(img, rng, 0.08))
    return covers


def product_labels(seed=43):
    """Eight made-up boxed sets' fronts, 160 x 128: a white box, a coloured
    band, what's inside in block letters and a line drawing of it."""
    rng = np.random.default_rng(seed)
    labels = []
    for i, (word, band) in enumerate(
        [("STEREO", (200, 40, 40)), ("VIDEO", (30, 60, 150)), ("RADIO", (40, 140, 90)), ("PHONE", (220, 160, 30)), ("TORCH", (230, 200, 40)), ("CASSETTE", (120, 40, 140)), ("CLOCK", (40, 40, 44)), ("TV 13", (200, 90, 30))]
    ):
        img = prints.blank(128, 160, (232, 230, 222))
        prints.rect(img, 0, 0, 160, 30, band)
        prints.text(img, word, 8, 8, 16, (250, 248, 240), bold=0.3)
        prints.rect(img, 30, 48, 130, 108, (60, 60, 64))
        prints.rect(img, 36, 54, 124, 102, (150, 156, 160))
        for k in range(i % 3 + 2):
            prints.disc(img, 50 + k * 22, 78, 7, (40, 40, 44))
        labels.append(prints.age(img, rng, 0.06))
    return labels


def marquee(title, fg, bg, seed):
    img = prints.blank(120, 600, bg)
    for k in range(6):
        prints.rect(img, 0, 6 + k * 18, 600, 10 + k * 18, tuple(min(255, c + 30) for c in bg), 0.5)
    prints.text(img, title, (600 - prints.text_width(title, 64, 1.2)) / 2, 28, 64, fg, spacing=1.2, bold=1.5)
    return prints.age(img, np.random.default_rng(seed), 0.06)


def screen_house_call():
    """HOUSE CALL's attract screen: a maze in blue lines, you (yellow), him
    (a white mask), INSERT COIN."""
    img = prints.blank(300, 400, (6, 6, 10))
    rng = np.random.default_rng(7)
    for k in range(9):
        y = 30 + k * 26
        x0 = rng.uniform(20, 120)
        prints.stroke(img, [(x0, y), (x0 + rng.uniform(80, 240), y)], 4, (40, 70, 230))
    for k in range(7):
        x = 40 + k * 50
        y0 = rng.uniform(20, 140)
        prints.stroke(img, [(x, y0), (x, y0 + rng.uniform(40, 120))], 4, (40, 70, 230))
    prints.disc(img, 120, 210, 9, (250, 220, 40))
    prints.disc(img, 290, 110, 11, (236, 232, 222))
    prints.disc(img, 286, 107, 2, (10, 10, 10))
    prints.disc(img, 294, 107, 2, (10, 10, 10))
    prints.text(img, "HOUSE CALL", 110, 250, 18, (250, 220, 40))
    prints.text(img, "INSERT COIN", 132, 276, 12, (220, 220, 230))
    return prints.blur(img, 1)


def screen_night_drive():
    """NIGHT DRIVE's: a road in perspective, rain, your car's tail lights."""
    img = prints.blank(300, 400, (8, 8, 24))
    for k in range(10):
        t = k / 10
        prints.stroke(img, [(200 - 10 - t * 150, 120 + t * 170), (200 - 10 - (t + 0.06) * 150, 120 + (t + 0.06) * 170)], 3, (220, 220, 230))
        prints.stroke(img, [(200 + 10 + t * 150, 120 + t * 170), (200 + 10 + (t + 0.06) * 150, 120 + (t + 0.06) * 170)], 3, (220, 220, 230))
    prints.rect(img, 170, 220, 230, 260, (30, 30, 40))
    prints.rect(img, 172, 246, 184, 254, (240, 30, 30))
    prints.rect(img, 216, 246, 228, 254, (240, 30, 30))
    rng = np.random.default_rng(9)
    for _ in range(60):
        x, y = rng.uniform(0, 400), rng.uniform(0, 300)
        prints.stroke(img, [(x, y), (x - 3, y + 10)], 1, (90, 110, 180), 0.6)
    prints.text(img, "NIGHT DRIVE", 120, 40, 18, (80, 220, 250))
    prints.text(img, "INSERT COIN", 132, 276, 12, (220, 220, 230))
    return prints.blur(img, 1)


def screen_dead():
    """A dead machine's screen, dark, an OUT OF ORDER sheet taped over it."""
    img = prints.blank(300, 400, (16, 18, 20))
    prints.rect(img, 110, 90, 290, 210, (232, 226, 206))
    for x0, y0 in ((100, 82), (270, 82), (100, 200), (270, 200)):
        prints.rect(img, x0, y0, x0 + 30, y0 + 16, (200, 190, 150), 0.8)
    prints.text(img, "OUT OF", 140, 118, 22, (40, 34, 30))
    prints.text(img, "ORDER", 146, 150, 22, (40, 34, 30))
    return img


def side_art(a, b, c):
    img = prints.blank(400, 200, a)
    for k in range(-4, 8):
        x = k * 50
        prints.stroke(img, [(x, 400), (x + 220, 0)], 16, b)
        prints.stroke(img, [(x + 18, 400), (x + 238, 0)], 6, c)
    return prints.age(img, np.random.default_rng(int(sum(a))), 0.06)


def standee_poster(seed=17):
    """The case's standee: THE HALFWAY HOUSE on video, a house at night with
    one window lit and a tall figure before it, pale-masked."""
    h, w = 720, 312
    img = prints.blank(h, w, (12, 14, 26))
    rng = np.random.default_rng(seed)
    for _ in range(80):
        prints.disc(img, rng.uniform(0, w), rng.uniform(0, 300), rng.uniform(0.6, 1.4), (200, 200, 220), 0.7)
    prints.disc(img, 240, 120, 30, (226, 222, 196))
    prints.rect(img, 40, 330, 272, 520, (8, 8, 10))
    prints.stroke(img, [(30, 336), (156, 250), (282, 336)], 12, (8, 8, 10))
    prints.rect(img, 70, 380, 100, 420, (240, 196, 90))
    prints.rect(img, 200, 380, 230, 420, (20, 20, 24))
    prints.rect(img, 140, 470, 172, 520, (20, 20, 24))
    # The figure, in front.
    prints.rect(img, 132, 430, 182, 640, (4, 4, 6))
    prints.disc(img, 157, 412, 22, (4, 4, 6))
    prints.disc(img, 157, 410, 15, (230, 226, 214))
    prints.disc(img, 151, 406, 2.5, (10, 10, 10))
    prints.disc(img, 163, 406, 2.5, (10, 10, 10))
    prints.rect(img, 0, 520, w, 640, (14, 12, 12))
    prints.text(img, "THE HALFWAY", (w - prints.text_width("THE HALFWAY", 34)) / 2, 30, 34, (236, 226, 196), bold=0.8)
    prints.text(img, "HOUSE", (w - prints.text_width("HOUSE", 52, 1.2)) / 2, 74, 52, (200, 40, 34), spacing=1.2, bold=1.2)
    prints.text(img, "NOW ON VIDEO", (w - prints.text_width("NOW ON VIDEO", 24)) / 2, 660, 24, (236, 226, 196))
    prints.text(img, "RENT IT TONIGHT", (w - prints.text_width("RENT IT TONIGHT", 14)) / 2, 694, 14, (180, 170, 150))
    return prints.age(img, rng, 0.07)


def prize_case(seed=23):
    """The prize counter's front glass: shelves of what was to be won."""
    img = prints.blank(240, 960, (40, 30, 36))
    rng = np.random.default_rng(seed)
    for row in range(2):
        y = 20 + row * 110
        prints.rect(img, 0, y + 92, 960, y + 100, (120, 110, 100))
        for k in range(18):
            x = 30 + k * 52 + rng.uniform(-6, 6)
            colour = [(230, 80, 140), (80, 200, 230), (250, 220, 60), (140, 230, 120), (240, 140, 50)][int(rng.integers(0, 5))]
            if rng.random() < 0.5:
                prints.disc(img, x, y + 70, 20, colour)
                prints.disc(img, x - 8, y + 48, 8, colour)
                prints.disc(img, x + 8, y + 48, 8, colour)
            else:
                prints.rect(img, x - 16, y + 40, x + 16, y + 92, colour)
    for k in range(6):
        prints.stroke(img, [(k * 180, 240), (k * 180 + 120, 0)], 18, (255, 255, 255), 0.08)
    return prints.age(img, rng, 0.06)


def torch_case(seed=29):
    """The electronics counter's glass top: the torches on navy felt, NEW."""
    img = prints.blank(300, 1000, (24, 30, 64))
    looks = [((230, 196, 40), (40, 40, 40)), ((176, 136, 72), (120, 92, 48)), ((200, 204, 210), (120, 124, 130))]
    for k, (body, head) in enumerate(looks):
        x = 160 + k * 300
        prints.rect(img, x, 130, x + 180, 170, body)
        prints.rect(img, x + 170, 115, x + 220, 185, head)
        prints.disc(img, x + 222, 150, 30, (240, 240, 220))
        prints.rect(img, x + 40, 200, x + 120, 240, (236, 230, 210))
        prints.text(img, "NEW", x + 58, 210, 20, (200, 40, 34))
    rng = np.random.default_rng(seed)
    return prints.age(img, rng, 0.05)


def batteries_shelf():
    img = prints.blank(200, 1000, (30, 32, 36))
    for k in range(20):
        x = 20 + k * 48
        colour = [(230, 120, 30), (40, 40, 44), (200, 40, 40), (60, 120, 200)][k % 4]
        prints.rect(img, x, 40, x + 36, 160, colour)
        prints.rect(img, x + 6, 60, x + 30, 100, (230, 226, 210))
    return img


def change_header():
    img = prints.blank(160, 440, (20, 22, 26))
    prints.text(img, "CHANGE", (440 - prints.text_width("CHANGE", 48, 1.2)) / 2, 20, 48, (250, 200, 40), spacing=1.2, bold=1.0)
    prints.text(img, "TOKENS  BILLS", (440 - prints.text_width("TOKENS  BILLS", 28)) / 2, 100, 28, (230, 230, 230))
    return img


def fitting_header():
    img = prints.blank(100, 520, (232, 196, 206))
    prints.text(img, "FITTING ROOM", (520 - prints.text_width("FITTING ROOM", 40, 1.2)) / 2, 30, 40, (120, 40, 70), spacing=1.2)
    return prints.age(img, np.random.default_rng(3), 0.05)


def jukebox_panel():
    img = prints.blank(240, 360, (236, 228, 200))
    for r in range(8):
        for c in range(2):
            x0, y0 = 20 + c * 170, 16 + r * 27
            prints.rect(img, x0, y0, x0 + 150, y0 + 22, (250, 246, 232))
            prints.rect(img, x0 + 8, y0 + 7, x0 + 110, y0 + 10, (60, 50, 50))
            prints.rect(img, x0 + 8, y0 + 14, x0 + 80, y0 + 16, (160, 40, 40))
    return prints.age(img, np.random.default_rng(5), 0.08)


def carpet(seed=31, n=1024):
    """The arcade's carpet: black, with neon squiggles, triangles and rings."""
    img = prints.blank(n, n, (14, 12, 22))
    rng = np.random.default_rng(seed)
    neon = [(250, 60, 170), (60, 220, 250), (250, 220, 60), (150, 90, 250)]
    for _ in range(140):
        colour = neon[int(rng.integers(0, 4))]
        x, y = rng.uniform(0, n), rng.uniform(0, n)
        kind = rng.integers(0, 3)
        if kind == 0:
            pts = [(x + k * 10, y + 10 * math.sin(k * 1.4)) for k in range(6)]
            prints.stroke(img, pts, 5, colour)
        elif kind == 1:
            a = rng.uniform(0, math.tau)
            pts = [(x + 22 * math.cos(a + k * math.tau / 3), y + 22 * math.sin(a + k * math.tau / 3)) for k in range(4)]
            prints.stroke(img, pts, 4, colour)
        else:
            prints.ring(img, x, y, 12, 4, colour)
    return img


def bag_print():
    img = prints.blank(160, 140, (236, 160, 190))
    prints.text(img, "THANK", 26, 50, 24, (250, 246, 240), bold=0.5)
    prints.text(img, "YOU", 46, 84, 24, (250, 246, 240), bold=0.5)
    return img


# Garments ----------------------------------------------------------------------

SHIRT = [(-0.18, 0.0), (0.18, 0.0), (0.68, -0.12), (0.86, -0.6), (0.56, -0.66), (0.54, -2.0), (-0.54, -2.0), (-0.56, -0.66), (-0.86, -0.6), (-0.68, -0.12)]
JACKET = [(-0.2, 0.0), (0.2, 0.0), (0.74, -0.1), (0.9, -1.7), (0.66, -1.72), (0.62, -2.3), (-0.62, -2.3), (-0.66, -1.72), (-0.9, -1.7), (-0.74, -0.1)]
TROUSERS = [(-0.46, 0.0), (0.46, 0.0), (0.52, -2.9), (0.1, -2.9), (0.0, -1.0), (-0.1, -2.9), (-0.52, -2.9)]
EIGHTIES = [(64, 196, 196), (236, 80, 150), (120, 70, 180), (250, 210, 60), (30, 30, 34), (240, 236, 226), (70, 110, 190), (230, 100, 50)]


def _palette(prefix, colours, kind=materials.fabric):
    return [kind("%s%d" % (prefix, i), color=c) for i, c in enumerate(colours)]


def _garment(name, outline, mat, at, turn=0.0, thick=0.08):
    """A garment hanging from its hanger at `at`, turned about the game's y."""
    obj = materials.assign(_flat(name, outline, -thick / 2, thick / 2), mat)
    return _place(obj, (0, 0, turn), at)


def _hanger(name, mat, at, turn=0.0):
    hook = _tube(name, [(0, 0.22, 0), (0, 0.32, 0), (0.08, 0.36, 0)], 0.018, 5, caps=False)
    bar = _tube(name, [(-0.6, -0.08, 0), (0, 0.18, 0), (0.6, -0.08, 0)], 0.025, 5)
    obj = shapes.join([materials.assign(hook, mat), materials.assign(bar, mat)], name)
    return _place(obj, (0, 0, turn), at)


# Diner -------------------------------------------------------------------------


def diner_backbar():
    """The back bar against the diner's wall (Data/Mall `Backbar`, 30 x 3.2 x
    2.2): steel doors below, a formica top, and on it the coffee station and
    its pots, the malt mixer, the pie case, the griddle; a steel backsplash
    up to the boards. Its front is +z (to the counter)."""
    steel = _steel("BackbarSteel")
    top = _formica("BackbarTop", (214, 210, 200))
    black = _plastic("BackbarBlack", (26, 24, 24))
    glass = _glass("BackbarGlass", (70, 60, 40))
    pie = materials.paint("BackbarPie", color=(196, 140, 70), roughness=0.7, grime=0.3)
    L, H, D = 30.0, 3.2, 2.2
    b, t = -H / 2, H / 2
    parts = [
        materials.assign(_box("Body", (L, H - 0.16, D - 0.1), (0, b + (H - 0.16) / 2, -0.05), 0.02, 1), steel),
        materials.assign(_box("Top", (L, 0.16, D), (0, t - 0.08, 0), 0.04, 2), top),
        materials.assign(_box("Splash", (L, 1.8, 0.08), (0, t + 0.9, -D / 2 + 0.04), 0.01, 1), steel),
    ]
    # The doors' seams and pulls.
    for k in range(11):
        x = -L / 2 + 1.36 + k * 2.73
        parts.append(materials.assign(_box("Seam", (0.03, H - 0.5, 0.02), (x, b + (H - 0.16) / 2, D / 2 - 0.04), 0.0, 1), black))
        parts.append(materials.assign(_box("Pull", (0.5, 0.06, 0.06), (x - 0.4, t - 0.55, D / 2 - 0.02), 0.02, 2), steel))
    # The coffee station: two burners, two pots.
    cx = -6.0
    parts.append(materials.assign(_box("Brewer", (2.2, 1.6, 1.4), (cx, t + 0.8, -0.3), 0.06, 2), steel))
    for dx in (-0.55, 0.55):
        parts.append(materials.assign(_lathe("Pot", [(0.0, t + 0.02), (0.32, t + 0.02), (0.38, t + 0.25), (0.3, t + 0.55), (0.16, t + 0.62), (0.16, t + 0.7), (0.0, t + 0.7)], (cx + dx, 0, 0.55), 16), glass))
        parts.append(materials.assign(_tube("Handle", [(cx + dx + 0.3, t + 0.5, 0.55), (cx + dx + 0.5, t + 0.45, 0.55), (cx + dx + 0.36, t + 0.2, 0.55)], 0.04, 5), black))
    # The malt mixer.
    mx = 1.5
    parts.append(materials.assign(_box("MixerBase", (0.7, 0.2, 0.6), (mx, t + 0.1, 0.1), 0.05, 2), steel))
    parts.append(materials.assign(_box("MixerArm", (0.3, 1.2, 0.3), (mx, t + 0.8, -0.1), 0.06, 2), _vinyl("MixerGreen", (110, 180, 150))))
    parts.append(materials.assign(_lathe("MixerCup", [(0.0, t + 0.2), (0.16, t + 0.2), (0.22, t + 0.75), (0.0, t + 0.75)], (mx, 0, 0.25), 14), steel))
    # The pie case: a domed glass cover over a stand.
    px = 7.0
    parts.append(materials.assign(_lathe("PieStand", [(0.0, t), (0.15, t), (0.12, t + 0.3), (0.7, t + 0.36), (0.7, t + 0.42), (0.0, t + 0.42)], (px, 0, 0.1), 24), steel))
    parts.append(materials.assign(_lathe("Pie", [(0.0, t + 0.42), (0.6, t + 0.42), (0.6, t + 0.6), (0.0, t + 0.62)], (px, 0, 0.1), 24), pie))
    parts.append(materials.assign(_lathe("PieDome", [(0.68, t + 0.42), (0.66, t + 0.8), (0.45, t + 1.12), (0.12, t + 1.22), (0.1, t + 1.3), (0.0, t + 1.32), (0.0, t + 1.2), (0.6, t + 0.78), (0.62, t + 0.42), (0.68, t + 0.42)], (px, 0, 0.1), 24), glass))
    # The griddle and its hood edge.
    gx = -11.5
    parts.append(materials.assign(_box("Griddle", (3.0, 0.12, 1.6), (gx, t + 0.06, 0.1), 0.02, 1), black))
    parts.append(materials.assign(_box("GriddleRail", (3.1, 0.3, 0.08), (gx, t + 0.18, -0.72), 0.02, 1), steel))
    for sx in (-1, 1):
        parts.append(materials.assign(_box("GriddleRail", (0.08, 0.3, 1.6), (gx + sx * 1.53, t + 0.18, 0.1), 0.02, 1), steel))
    # Cups stacked upside down, and a napkin stack.
    for k in range(4):
        parts.append(materials.assign(_lathe("Cup", [(0.0, t), (0.16, t), (0.2, t + 0.28), (0.0, t + 0.28)], (11.0 + (k % 2) * 0.45, 0, 0.3 - (k // 2) * 0.45), 12), _formica("CupWhite", (238, 236, 230))))
    return shapes.join(parts, "DinerBackbar")


def diner_counter():
    """The diner's counter (30 x 4 x 3): a steel front with a red band and a
    recessed kick, a formica top with a chrome edge overhanging the stools,
    a lift-up flap at its south end; napkins, sugar and ketchup along it, the
    register at its north end. Its front is +z (the stools' side)."""
    steel = _steel("CounterSteel")
    red = _vinyl("CounterRed", (170, 34, 38))
    top = _formica("CounterTop")
    chrome = _chrome("CounterChrome")
    black = _plastic("CounterBlack", (24, 24, 26))
    ketchup = _plastic("Ketchup", (190, 30, 30))
    mustard = _plastic("Mustard", (230, 190, 40))
    L, H, D = 30.0, 4.0, 3.0
    b, t = -H / 2, H / 2
    parts = [
        materials.assign(_box("Kick", (L, 0.5, D - 0.6), (0, b + 0.25, -0.3), 0.02, 1), black),
        materials.assign(_box("Front", (L, H - 0.7, D - 0.3), (0, b + 0.5 + (H - 0.7) / 2, -0.15), 0.03, 2), steel),
        materials.assign(_box("Band", (L + 0.02, 0.5, 0.06), (0, b + 2.2, D / 2 - 0.27), 0.02, 2), red),
        materials.assign(_box("Top", (L + 0.1, 0.18, D + 0.1), (0, t - 0.09, 0.05), 0.05, 3), top),
        materials.assign(_box("Edge", (L + 0.14, 0.12, 0.06), (0, t - 0.1, D / 2 + 0.11), 0.03, 2), chrome),
        materials.assign(_box("Footrail", (L - 1.0, 0.1, 0.1), (0, b + 0.7, D / 2 + 0.1), 0.04, 2), chrome),
    ]
    for x in range(-14, 15, 4):
        parts.append(materials.assign(_box("RailFoot", (0.08, 0.1, 0.24), (x, b + 0.7, D / 2 - 0.02), 0.02, 1), chrome))
    # The flap's seams at the south end.
    for x in (L / 2 - 2.6, L / 2 - 0.2):
        parts.append(materials.assign(_box("FlapSeam", (0.03, 0.2, D), (x, t - 0.09, 0.05), 0.0, 1), black))
    # Along the top: a set every 5, the register at the north end.
    for x in (-10.0, -5.0, 0.0, 5.0, 10.0):
        parts.append(materials.assign(_box("Napkins", (0.5, 0.45, 0.3), (x - 0.4, t + 0.225, 0.6), 0.03, 2), chrome))
        parts.append(materials.assign(_lathe("Sugar", [(0.0, t), (0.12, t), (0.14, t + 0.3), (0.06, t + 0.38), (0.0, t + 0.42)], (x + 0.2, 0, 0.6), 12), _glass("SugarGlass", (200, 200, 196))))
        for dx, mat in ((0.55, ketchup), (0.8, mustard)):
            parts.append(materials.assign(_lathe("Bottle", [(0.0, t), (0.1, t), (0.11, t + 0.38), (0.04, t + 0.5), (0.0, t + 0.52)], (x + dx, 0, 0.6), 10), mat))
    rx = -13.0
    parts.append(materials.assign(_box("Register", (1.4, 0.7, 1.0), (rx, t + 0.35, -0.3), 0.06, 2), _plastic("RegisterBeige", (198, 188, 166))))
    parts.append(materials.assign(_box("RegisterTop", (1.2, 0.4, 0.4), (rx, t + 0.9, -0.55), 0.05, 2), _plastic("RegisterBeige2", (190, 180, 160))))
    for k in range(12):
        parts.append(materials.assign(_box("Key", (0.12, 0.05, 0.12), (rx - 0.45 + (k % 4) * 0.3, t + 0.72, -0.1 + (k // 4) * 0.22), 0.02, 1), black))
    return shapes.join(parts, "DinerCounter")


def diner_stool():
    """A counter stool (Data/Mall `Stool`, 2.5 high, 1.6 across): a chrome
    dome foot and column, a red vinyl seat in a chrome ring. Round."""
    chrome = _chrome("StoolChrome")
    red = _vinyl("StoolRed")
    h = 2.5
    b, t = -h / 2, h / 2
    parts = [
        materials.assign(_lathe("Foot", [(0.0, b), (0.75, b), (0.75, b + 0.06), (0.5, b + 0.22), (0.14, b + 0.34), (0.0, b + 0.34)], steps=32), chrome),
        materials.assign(_lathe("Column", [(0.0, b + 0.3), (0.12, b + 0.3), (0.12, t - 0.5), (0.3, t - 0.42), (0.0, t - 0.4)], steps=20), chrome),
        materials.assign(_lathe("Ring", [(0.0, t - 0.42), (0.78, t - 0.42), (0.8, t - 0.3), (0.78, t - 0.22), (0.0, t - 0.22)], steps=36), chrome),
        materials.assign(_lathe("Seat", [(0.0, t - 0.24), (0.74, t - 0.24), (0.8, t - 0.14), (0.74, t - 0.02), (0.4, t), (0.0, t)], steps=36), red),
    ]
    return shapes.join(parts, "DinerStool")


def diner_booth_seat():
    """A booth's bench (5 x 4.2 x 1.7): red vinyl, a tufted seat and a high
    back with a chrome cap, its back's rear in vinyl too (the next booth sits
    against it). Its front is +z, where you sit facing."""
    red = _vinyl("BoothRed")
    dark = _vinyl("BoothDark", (110, 20, 24))
    chrome = _chrome("BoothChrome")
    black = _plastic("BoothBase", (24, 20, 20))
    W, H, D = 5.0, 4.2, 1.7
    b = -H / 2
    seat_y = b + 1.55
    parts = [
        materials.assign(_box("Base", (W, 1.25, D - 0.3), (0, b + 0.625, -0.1), 0.03, 1), black),
        materials.assign(shapes.cushion("Seat", S(W - 0.1, 0.42, D - 0.45), G(0, seat_y - 0.1, 0.2), puff=0.06, levels=2, roundness=0.4), red),
        materials.assign(_box("Back", (W, H - 1.2, 0.3), (0, b + 1.2 + (H - 1.2) / 2, -D / 2 + 0.15), 0.06, 2), dark),
        materials.assign(shapes.cushion("BackPad", S(W - 0.2, 2.4, 0.32), G(0, seat_y + 1.35, -D / 2 + 0.42), puff=0.05, levels=2, roundness=0.4), red),
        materials.assign(_box("Cap", (W + 0.04, 0.1, 0.36), (0, H / 2 - 0.05, -D / 2 + 0.15), 0.04, 2), chrome),
        materials.assign(_box("Piping", (W, 0.06, 0.06), (0, seat_y + 0.12, D / 2 - 0.05), 0.02, 2), chrome),
    ]
    # Tufting: buttons and channels down the back.
    for k in range(5):
        x = -2.0 + k
        parts.append(materials.assign(_box("Channel", (0.04, 2.2, 0.04), (x, seat_y + 1.35, -D / 2 + 0.6), 0.0, 1), dark))
    return shapes.join(parts, "DinerBoothSeat")


def diner_table():
    """A booth's table (4.4 x 2.6 x 2.9): a cracked-ice formica top in a
    chrome edge on one steel pedestal; a napkin box, salt and pepper,
    ketchup and a menu card on it. Its long side along x."""
    top = _formica("TableTop", (226, 222, 214))
    chrome = _chrome("TableChrome")
    menu = materials.paint("TableMenu", color=(150, 30, 34), roughness=0.5, grime=0.2)
    W, H, D = 4.4, 2.6, 2.9
    b, t = -H / 2, H / 2
    parts = [
        materials.assign(_lathe("Foot", [(0.0, b), (0.9, b), (0.9, b + 0.06), (0.2, b + 0.2), (0.0, b + 0.2)], steps=28), chrome),
        materials.assign(_lathe("Post", [(0.0, b + 0.2), (0.14, b + 0.2), (0.14, t - 0.2), (0.0, t - 0.2)], steps=16), chrome),
        materials.assign(_box("Top", (W, 0.12, D), (0, t - 0.06 - 0.06, 0), 0.04, 2), top),
        materials.assign(_box("Edge", (W + 0.06, 0.1, D + 0.06), (0, t - 0.12, 0), 0.04, 2), chrome),
        materials.assign(_box("Napkins", (0.45, 0.42, 0.28), (W / 2 - 0.4, t + 0.21, 0), 0.03, 2), chrome),
        materials.assign(_lathe("Salt", [(0.0, t), (0.08, t), (0.09, t + 0.26), (0.05, t + 0.3), (0.0, t + 0.31)], (W / 2 - 0.8, 0, -0.18), 10), _glass("SaltGlass", (220, 220, 214))),
        materials.assign(_lathe("Pepper", [(0.0, t), (0.08, t), (0.09, t + 0.26), (0.05, t + 0.3), (0.0, t + 0.31)], (W / 2 - 0.8, 0, 0.18), 10), _glass("PepperGlass", (90, 80, 70))),
        materials.assign(_lathe("Ketchup", [(0.0, t), (0.1, t), (0.11, t + 0.38), (0.04, t + 0.5), (0.0, t + 0.52)], (W / 2 - 1.15, 0, 0), 10), _plastic("TableKetchup", (190, 30, 30))),
        materials.assign(_place(shapes.box("Menu", S(0.04, 0.55, 0.4), (0, 0, 0), 0.01, 1), (0, 0, 0), (W / 2 - 0.4, t + 0.5, -0.4)), menu),
    ]
    return shapes.join(parts, "DinerTable")


def menu_board():
    """A record board's frame (Data/Mall `MenuBoard` and `SpecialsBoard`, 13 x
    4 x 0.4): a black felt letterboard just behind the block's face (the
    records go on its face, World/MallBuilder's block, later) in a brushed
    aluminium frame standing proud of it. Its front is +z."""
    felt = materials.fabric("BoardFelt", color=(22, 22, 24), roughness=0.95)
    alu = materials.brass("BoardAlu", color=(176, 176, 172), roughness=0.4)
    W, H = 13.0, 4.0
    parts = [materials.assign(_box("Felt", (W, H, 0.3), (0, 0, 0.0), 0.0, 1), felt)]
    # The letterboard's grooves.
    for k in range(1, 20):
        y = -H / 2 + k * H / 20
        parts.append(materials.assign(_box("Groove", (W - 0.1, 0.02, 0.02), (0, y, 0.16), 0.0, 1), _plastic("GrooveDark", (10, 10, 12))))
    b = 0.25
    for sy in (-1, 1):
        parts.append(materials.assign(_box("Frame", (W + 2 * b, b, 0.5), (0, sy * (H / 2 + b / 2), 0.05), 0.05, 2), alu))
    for sx in (-1, 1):
        parts.append(materials.assign(_box("Frame", (b, H + 2 * b, 0.5), (sx * (W / 2 + b / 2), 0, 0.05), 0.05, 2), alu))
    return shapes.join(parts, "MenuBoard")


def jukebox():
    """The jukebox in the diner's corner (2.6 x 4.6 x 1.8): a walnut cabinet
    arched at the top, three coloured tubes running up its sides and over
    the arch (dark: it isn't on the generator), the dark glass dome inside
    the arch, the selection strips, the chrome grille over the speaker. Its
    front is +z."""
    walnut = materials.wood("JukeWalnut", (60, 36, 22), (110, 70, 40), grain_axis="Z", scale=1.2, roughness=0.4)
    chrome = _chrome("JukeChrome")
    tubes = [_glass("JukeTube%d" % i, c) for i, c in enumerate([(210, 120, 30), (180, 40, 40), (50, 110, 170)])]
    dome = _glass("JukeDome", (30, 26, 24))
    grille = _plastic("JukeGrille", (40, 30, 26))
    pixels, (panel,) = _atlas([jukebox_panel()])
    picture = _picture_mat("JukePanel", pixels, 0.2)
    W, H, D = 2.6, 4.6, 1.8
    b = -H / 2
    R = W / 2
    spring = H / 2 - R
    outline = [(-W / 2, b), (W / 2, b), (W / 2, spring)]
    outline += [(R * math.cos(math.pi * k / 16), spring + R * math.sin(math.pi * k / 16)) for k in range(1, 16)]
    outline.append((-W / 2, spring))
    parts = [materials.assign(_flat("Cabinet", outline, -D / 2, D / 2 - 0.05), walnut)]
    front = D / 2 - 0.05
    for i, mat in enumerate(tubes):
        r = R - 0.12 - i * 0.17
        path = [(r, b + 1.5, front + 0.06), (r, spring, front + 0.06)]
        path += [(r * math.cos(math.pi * k / 12), spring + r * math.sin(math.pi * k / 12), front + 0.06) for k in range(1, 12)]
        path += [(-r, spring, front + 0.06), (-r, b + 1.5, front + 0.06)]
        parts.append(materials.assign(_tube("Tube", path, 0.07, 8), mat))
    inner = R - 0.62
    arc = [(inner * math.cos(math.pi * k / 12), spring + inner * math.sin(math.pi * k / 12)) for k in range(13)]
    parts.append(materials.assign(_flat("Dome", [(inner, spring - 0.9)] + arc + [(-inner, spring - 0.9)], front, front + 0.04), dome))
    parts.append(_card("Panel", picture, 1.3, 0.85, (0, b + 1.95, front + 0.02), 1, panel))
    parts.append(materials.assign(_box("Grille", (1.9, 1.1, 0.06), (0, b + 0.8, front + 0.01), 0.04, 2), grille))
    for k in range(7):
        parts.append(materials.assign(_box("GrilleBar", (0.06, 1.1, 0.06), (-0.84 + k * 0.28, b + 0.8, front + 0.05), 0.02, 1), chrome))
    for k in range(10):
        parts.append(materials.assign(_box("Button", (0.12, 0.1, 0.06), (-0.7 + (k % 5) * 0.35, b + 1.45 - (k // 5) * 0.14, front + 0.03), 0.02, 1), chrome))
    return shapes.join(parts, "Jukebox")


def diner_floor():
    """The diner's floor in a 10 x 10 panel (World/MallBuilder lays them over
    the room, stretched to fit): black and white check, a stud a square."""
    mat = _checker("DinerCheck")
    obj = _named(materials.assign(_box("Floor", (10.0, 0.05, 10.0), (0, 0, 0), 0.0, 1), mat), "DinerFloor")
    obj["bake_size"] = 1024
    return obj


def _picture_mat(name, pixels, share, roughness=0.5):
    """A picture for flat cards, laid out in its band by kitlib.bake's own
    shelving (`uv_direct`), never Blender's packer."""
    from .atmosphere import _picture

    mat = _picture(name, pixels, share, roughness=roughness)
    mat["uv_direct"] = True
    return mat


# Video store ---------------------------------------------------------------------


def _tapes(prefix, picture, rects, width, rows, at, rng, lean=-12.0, depth=0.12, face=1):
    """Rows of tapes standing face out across `width` from `at` (the left end
    of the bottom row's back), each a box and its cover, leaning back; `face`
    -1 for a row facing -z (an island's far side)."""
    parts = []
    spine = [_plastic("%sSpine%d" % (prefix, i), c) for i, c in enumerate([(20, 20, 22), (230, 226, 216), (40, 40, 60)])]
    x0, y0, z0 = at
    n = int(width // 0.5)
    for r, y in enumerate(rows):
        for k in range(n):
            if rng.random() < 0.08:
                continue  # (rented)
            x = x0 + 0.25 + k * (width / n)
            box = materials.assign(shapes.box("Tape", S(0.4, 0.72, depth), (0, 0, 0), 0.01, 1), spine[int(rng.integers(0, 3))])
            card = _card("Cover", picture, 0.38, 0.7, (0, 0, depth / 2 + 0.003), 1, rects[int(rng.integers(0, len(rects)))])
            tape = shapes.join([box, card], "Tape")
            parts.append(_place(tape, (lean, 0, 0 if face > 0 else 180), (x, y + 0.36, z0 + face * depth / 2)))
    return parts


def video_shelf():
    """A run of wall shelving in the video store (Data/Mall `Shelf`, 7 x 7 x
    3): a navy back with a red header band, six shelves of tapes standing
    face out, a kick plinth. Its front is +z (off the wall)."""
    navy = _laminate("VideoNavy", (34, 40, 74))
    red = _laminate("VideoRed", (176, 34, 36))
    shelf = _laminate("VideoShelfEdge", (220, 214, 200))
    covers, rects = _grid(vhs_covers(), 4)
    picture = _picture_mat("VideoCovers", covers, 0.55, roughness=0.35)
    W, H, D = 7.0, 7.0, 3.0
    b = -H / 2
    parts = [
        # (Between the sides: a face sharing a plane with a side's flickers.)
        materials.assign(_box("Back", (W - 0.24, H, 0.25), (0, 0, -D / 2 + 0.125), 0.0, 1), navy),
        materials.assign(_box("Header", (W - 0.24, 0.8, 0.3), (0, H / 2 - 0.4, -D / 2 + 0.4), 0.03, 2), red),
        materials.assign(_box("Plinth", (W - 0.24, 0.5, D - 0.4), (0, b + 0.25, -0.2), 0.02, 1), navy),
    ]
    for sx in (-1, 1):
        parts.append(materials.assign(_box("Side", (0.12, H, D - 0.3), (sx * (W / 2 - 0.06), 0, -0.15), 0.02, 1), navy))
    rows = [b + 0.5 + k * 1.0 for k in range(6)]
    for r, y in enumerate(rows):
        depth = 1.1 - r * 0.08
        parts.append(materials.assign(_box("Shelf", (W - 0.24, 0.08, depth), (0, y, -D / 2 + 0.25 + depth / 2), 0.02, 1), shelf))
        parts.append(materials.assign(_box("Lip", (W - 0.24, 0.12, 0.04), (0, y + 0.06, -D / 2 + 0.25 + depth), 0.01, 1), shelf))
    rng = np.random.default_rng(13)
    parts += _tapes("Shelf", picture, rects, W - 0.5, rows, (-W / 2 + 0.25, 0.04, -D / 2 + 0.6), rng)
    obj = shapes.join(parts, "VideoShelf")
    obj["bake_size"] = 2048
    return obj


def video_island():
    """An island in the video store (Data/Mall `NewReleases`, `Family`; 8 x
    5.2 x 2): a gondola with tapes face out on both sides, three rows a side,
    a blank header band each side for the section's sign (Data/Mall's
    Signs), end caps. Long along x."""
    navy = _laminate("IslandNavy", (34, 40, 74))
    edge = _laminate("IslandEdge", (220, 214, 200))
    covers, rects = _grid(vhs_covers(), 4)
    picture = _picture_mat("IslandCovers", covers, 0.55, roughness=0.35)
    W, H, D = 8.0, 5.2, 2.0
    b = -H / 2
    parts = [
        materials.assign(_box("Spine", (W - 0.28, H - 0.9, 0.2), (0, b + (H - 0.9) / 2, 0), 0.0, 1), navy),
        materials.assign(_box("Header", (W, 0.8, 0.24), (0, H / 2 - 0.4, 0), 0.03, 2), navy),
        materials.assign(_box("Plinth", (W - 0.28, 0.5, D - 0.2), (0, b + 0.25, 0), 0.02, 1), navy),
    ]
    for sx in (-1, 1):
        parts.append(materials.assign(_box("Cap", (0.14, H - 0.9, D), (sx * (W / 2 - 0.07), b + (H - 0.9) / 2, 0), 0.03, 2), edge))
    rng = np.random.default_rng(29)
    rows = [b + 0.6 + k * 1.15 for k in range(3)]
    for sz in (-1, 1):
        for y in rows:
            parts.append(materials.assign(_box("Shelf", (W - 0.3, 0.08, 0.8), (0, y, sz * 0.5), 0.02, 1), edge))
        parts += _tapes("Island", picture, rects, W - 0.6, rows, (-W / 2 + 0.3, 0.04, sz * 0.12), rng, face=sz)
    obj = shapes.join(parts, "VideoIsland")
    obj["bake_size"] = 2048
    return obj


def video_counter():
    """The rental counter (6 x 4 x 3): grey laminate with a red stripe, a
    lighter top; on it the register, the RETURNS slot box and a rack of
    candy. Its front is +z (the customers')."""
    grey = _laminate("VCounterGrey", (120, 124, 132))
    red = _laminate("VCounterRed", (176, 34, 36))
    top = _formica("VCounterTop", (210, 206, 196))
    beige = _plastic("VRegister", (198, 188, 166))
    black = _plastic("VBlack", (24, 24, 26))
    W, H, D = 6.0, 4.0, 3.0
    b, t = -H / 2, H / 2
    parts = [
        materials.assign(_box("Body", (W, H - 0.15, D - 0.2), (0, b + (H - 0.15) / 2, -0.1), 0.03, 2), grey),
        materials.assign(_box("Stripe", (W + 0.02, 0.35, 0.05), (0, b + 2.6, D / 2 - 0.18), 0.01, 1), red),
        materials.assign(_box("Top", (W + 0.1, 0.15, D), (0, t - 0.075, 0), 0.04, 2), top),
        materials.assign(_box("Register", (1.4, 0.7, 1.0), (-1.6, t + 0.35, -0.5), 0.06, 2), beige),
        materials.assign(_box("Display", (0.8, 0.35, 0.3), (-1.6, t + 0.85, -0.85), 0.04, 2), black),
        materials.assign(_box("Returns", (1.2, 1.0, 0.9), (1.9, t + 0.5, -0.6), 0.04, 2), red),
        materials.assign(_box("Slot", (0.8, 0.08, 0.04), (1.9, t + 0.7, -0.14), 0.0, 1), black),
        materials.assign(_box("CandyRack", (1.0, 1.2, 0.5), (0.2, t + 0.6, 0.9), 0.03, 2), _plastic("CandyRack", (200, 196, 190))),
    ]
    rng = random.Random(3)
    for k in range(9):
        colour = [(230, 60, 60), (250, 200, 40), (60, 120, 220)][k % 3]
        parts.append(materials.assign(_box("Candy", (0.26, 0.3, 0.1), (-0.15 + (k % 3) * 0.35, t + 0.25 + (k // 3) * 0.38, 1.17), 0.01, 1), _plastic("Candy%d" % (k % 3), colour)))
    return shapes.join(parts, "VideoCounter")


def counter_tv():
    """The rental counter's TV (2.2 x 1.6 x 1.6): a small grey CRT, its
    screen dark glass, two knobs, rabbit ears. Its front is +z."""
    case = _plastic("CRTGrey", (110, 112, 116))
    glass = _glass("CRTGlass", (20, 28, 30))
    black = _plastic("CRTBlack", (24, 24, 26))
    W, H, D = 2.2, 1.6, 1.6
    parts = [
        materials.assign(_box("Case", (W, H - 0.2, D), (0, -0.1, 0), 0.12, 3), case),
        materials.assign(shapes.cushion("Screen", S(1.5, 1.05, 0.2), G(-0.25, -0.05, D / 2 - 0.02), puff=0.04, levels=2, roundness=0.6), glass),
    ]
    for k in range(2):
        parts.append(materials.assign(_lathe("Knob", [(0.0, 0.0), (0.09, 0.0), (0.09, 0.08), (0.0, 0.1)], (0, 0, 0), 12), black))
        parts[-1] = _place(parts[-1], (90, 0, 0), (0.8, 0.2 - k * 0.4, D / 2 + 0.05))
    for sx in (-1, 1):
        parts.append(materials.assign(_tube("Ear", [(0, H / 2 - 0.2, -0.2), (sx * 0.45, H / 2 + 0.0, -0.3)], 0.025, 5), _chrome("EarChrome")))
    return shapes.join(parts, "CounterTV")


def standee():
    """The case's standee (2.6 x 6 x 0.6): THE HALFWAY HOUSE on video, the
    poster cut out round its roof line, on a cardboard easel. Its front is
    +z."""
    card = materials.paint("StandeeCard", color=(170, 136, 96), roughness=0.9, grime=0.3)
    pixels, (rect,) = _atlas([standee_poster()])
    picture = _picture_mat("StandeePoster", pixels, 0.6, roughness=0.55)
    W, H = 2.6, 6.0
    b = -H / 2
    parts = [
        materials.assign(_box("Board", (W, H - 0.3, 0.06), (0, 0.15, 0.0), 0.0, 1), card),
        _card("Poster", picture, W - 0.04, H - 0.34, (0, 0.15, 0.035), 1, rect),
        materials.assign(_box("Foot", (W, 0.3, 0.5), (0, b + 0.15, 0.0), 0.02, 1), card),
        # The easel's strut, from the board's back at 1.4 up to the floor 1.3
        # behind it (it was tilted the other way, through the poster: the
        # owner, 2026-10-17).
        materials.assign(_place(shapes.box("Strut", S(0.06, 4.58, 0.06), (0, 0, 0), 0.0, 1), (16, 0, 0), (0, -0.8, -0.67)), card),
    ]
    return shapes.join(parts, "Standee")


# Arcade ----------------------------------------------------------------------------


def _cabinet(name, title, colours, screen_pixels, dead=False):
    """An 80s upright cabinet (Data/Mall `Cabinet`, 3 x 6 x 3): side panels in
    their art, the marquee over the screen, the screen sunk at its angle in
    a black bezel, the control panel with its stick and buttons, the coin
    door. Its front is +z. Its screen is the mesh's: when a game runs on it
    (the arcade's phase), a screen part goes where `screen` is here."""
    a, b, c = colours
    side_mat = materials.paint(name + "Side", color=a, roughness=0.45, grime=0.3 if dead else 0.2)
    black = _plastic(name + "Black", (16, 16, 18))
    chrome = _chrome(name + "Chrome")
    W, H, D = 3.0, 6.0, 3.0
    bt = -H / 2
    pictures = [marquee(title, c, b, len(title)), screen_pixels, side_art(a, b, c)]
    pixels, (marq, screen, art) = _atlas(pictures)
    picture = _picture_mat(name + "Art", pixels, 0.6, roughness=0.3)
    outline = [(-D / 2, bt), (D / 2 - 0.2, bt), (D / 2 - 0.2, bt + 2.6), (D / 2, bt + 2.9), (D / 2 - 0.35, bt + 3.2), (D / 2 - 0.6, bt + 4.6), (D / 2 - 0.3, bt + 4.7), (D / 2 - 0.3, bt + 5.5), (D / 2 - 0.6, H / 2), (-D / 2, H / 2)]
    parts = []
    for sx in (-1, 1):
        parts.append(materials.assign(_side_prism("Side", outline, sx * W / 2 - 0.08, sx * W / 2 + 0.08), side_mat))
        parts.append(_side_card("Art", picture, D - 0.8, 3.4, (sx * (W / 2 + 0.085), bt + 3.0, -0.3), sx, art))
    inner = W - 0.16
    parts.append(materials.assign(_box("Body", (inner, H - 0.1, D - 0.6), (0, 0, -0.3), 0.0, 1), black))
    # The kick and the coin door.
    parts.append(materials.assign(_box("Kick", (inner, 2.6, 0.1), (0, bt + 1.3, D / 2 - 0.25), 0.02, 1), black))
    parts.append(materials.assign(_box("CoinDoor", (1.0, 1.1, 0.06), (0, bt + 1.5, D / 2 - 0.18), 0.03, 2), chrome))
    for dx in (-0.22, 0.22):
        parts.append(materials.assign(_box("CoinSlot", (0.18, 0.3, 0.04), (dx, bt + 1.65, D / 2 - 0.14), 0.01, 1), _plastic(name + "Coin", (200, 60, 30) if not dead else (60, 40, 30))))
    # The control panel, sloping, its stick and buttons.
    panel = shapes.box("Panel", S(inner, 0.12, 0.7), (0, 0, 0), 0.03, 2)
    parts.append(materials.assign(_place(panel, (-25, 0, 0), (0, bt + 3.05, D / 2 - 0.25)), side_mat))
    parts.append(materials.assign(_lathe("Stick", [(0.0, 0.0), (0.03, 0.0), (0.03, 0.32), (0.0, 0.32)], (0, 0, 0), 8), black))
    parts[-1] = _place(parts[-1], (-25, 0, 0), (-0.6, bt + 3.1, D / 2 - 0.22))
    parts.append(materials.assign(_sphere("Ball", 0.1, (-0.6, bt + 3.42, D / 2 - 0.36), 10, 5), _plastic(name + "BallRed", (200, 30, 30))))
    for k, colour in enumerate([(220, 40, 40), (240, 200, 40), (60, 130, 230)]):
        btn = _lathe("Button", [(0.0, 0.0), (0.09, 0.0), (0.09, 0.06), (0.0, 0.08)], (0, 0, 0), 12)
        parts.append(materials.assign(_place(btn, (-25, 0, 0), (0.1 + k * 0.32, bt + 3.12, D / 2 - 0.25 + (k % 2) * 0.06)), _plastic("%sBtn%d" % (name, k), colour)))
    # The screen, sunk in its bezel at the cabinet's angle.
    bezel = shapes.box("Bezel", S(inner, 1.45, 0.1), (0, 0, 0), 0.0, 1)
    parts.append(materials.assign(_place(bezel, (-12, 0, 0), (0, bt + 3.9, D / 2 - 0.5)), black))
    scr = _card("Screen", picture, 1.9, 1.3, (0, 0, 0.06), 1, screen)
    parts.append(_place(scr, (-12, 0, 0), (0, bt + 3.9, D / 2 - 0.5)))
    # The marquee, its plexi over the title.
    parts.append(materials.assign(_box("MarqueeBox", (inner, 0.8, 0.5), (0, bt + 5.1, D / 2 - 0.55), 0.02, 1), black))
    parts.append(_card("Marquee", picture, inner - 0.1, 0.7, (0, bt + 5.1, D / 2 - 0.29), 1, marq))
    obj = shapes.join(parts, name)
    obj["bake_size"] = 1024
    return obj


def cabinet_house_call():
    return _cabinet("CabinetHouseCall", "HOUSE CALL", ((150, 24, 30), (40, 10, 12), (250, 210, 40)), screen_house_call())


def cabinet_night_drive():
    return _cabinet("CabinetNightDrive", "NIGHT DRIVE", ((24, 30, 110), (10, 12, 40), (80, 220, 250)), screen_night_drive())


def cabinet_dead():
    return _cabinet("CabinetDead", "STAR PATROL", ((90, 84, 80), (40, 38, 36), (150, 140, 120)), screen_dead(), dead=True)


def prize_counter():
    """The prize counter (12 x 4 x 3), shut: a laminate frame round a glass
    front of the prizes (drawn: Roblox draws no see-through kit), a glass
    top under the dust sheet. Its front is +z."""
    frame = _laminate("PrizeFrame", (120, 40, 90))
    top = _glass("PrizeTop", (60, 70, 74))
    pixels, (front,) = _atlas([prize_case()])
    picture = _picture_mat("PrizeCase", pixels, 0.4, roughness=0.15)
    W, H, D = 12.0, 4.0, 3.0
    b, t = -H / 2, H / 2
    parts = [
        materials.assign(_box("Plinth", (W, 0.6, D - 0.2), (0, b + 0.3, -0.1), 0.02, 1), frame),
        materials.assign(_box("Back", (W, H - 0.6, 0.2), (0, b + 0.6 + (H - 0.6) / 2, -D / 2 + 0.1), 0.02, 1), frame),
        materials.assign(_box("Inside", (W - 0.3, H - 0.8, D - 0.4), (0, b + 0.6 + (H - 0.8) / 2, -0.1), 0.0, 1), _plastic("PrizeInside", (40, 30, 36))),
        _card("Front", picture, W - 0.3, H - 1.0, (0, b + 0.6 + (H - 0.8) / 2, D / 2 - 0.08), 1, front),
        materials.assign(_box("Top", (W, 0.12, D), (0, t - 0.06, 0), 0.02, 1), top),
    ]
    for sx in (-1, 0, 1):
        parts.append(materials.assign(_box("Post", (0.15, H - 0.6, 0.15), (sx * (W / 2 - 0.075), b + 0.6 + (H - 0.6) / 2, D / 2 - 0.075), 0.02, 1), frame))
    parts.append(materials.assign(_box("Rail", (W, 0.15, 0.15), (0, t - 0.2, D / 2 - 0.075), 0.02, 1), frame))
    return shapes.join(parts, "PrizeCounter")


def prize_wall():
    """The prize wall behind the counter (12 x 4 x 0.4): brown pegboard,
    mostly empty hooks, a few prizes left on them. Its front is +z."""
    board = materials.paint("Pegboard", color=(150, 112, 74), roughness=0.85, grime=0.3)
    holes = _plastic("PegHole", (40, 30, 22))
    hook = _chrome("PegHook")
    W, H = 12.0, 4.0
    parts = [materials.assign(_box("Board", (W, H, 0.2), (0, 0, -0.1), 0.0, 1), board)]
    for r in range(8):
        for c in range(24):
            parts.append(materials.assign(_box("Hole", (0.06, 0.06, 0.01), (-W / 2 + 0.25 + c * 0.5, -H / 2 + 0.25 + r * 0.5, 0.0), 0.0, 1), holes))
    rng = random.Random(8)
    for r in range(3):
        for c in range(9):
            x, y = -W / 2 + 0.9 + c * 1.3, H / 2 - 0.7 - r * 1.25
            parts.append(materials.assign(_tube("Hook", [(x, y, 0.0), (x, y, 0.35), (x, y + 0.08, 0.4)], 0.02, 5, caps=False), hook))
            if rng.random() < 0.3:
                colour = [(230, 80, 140), (80, 200, 230), (250, 220, 60)][rng.randrange(3)]
                parts.append(materials.assign(_sphere("Prize", 0.22, (x, y - 0.3, 0.25), 10, 5), materials.fabric("Plush%d" % rng.randrange(3), color=colour)))
    return shapes.join(parts, "PrizeWall")


def change_machine():
    """The change machine by the arcade's door (2.2 x 5 x 1.8): brushed
    steel, its lit header (dark), the bill slot, the coin cup. Its front is
    +z."""
    steel = _steel("ChangeSteel")
    black = _plastic("ChangeBlack", (20, 20, 22))
    pixels, (head,) = _atlas([change_header()])
    picture = _picture_mat("ChangeHeader", pixels, 0.3, roughness=0.2)
    W, H, D = 2.2, 5.0, 1.8
    b = -H / 2
    parts = [
        materials.assign(_box("Body", (W, H, D), (0, 0, 0), 0.05, 2), steel),
        _card("Header", picture, W - 0.2, 0.75, (0, H / 2 - 0.5, D / 2 + 0.005), 1, head),
        materials.assign(_box("BillPlate", (0.9, 0.6, 0.06), (0, b + 3.0, D / 2 + 0.02), 0.02, 2), black),
        materials.assign(_box("BillSlot", (0.6, 0.06, 0.04), (0, b + 3.05, D / 2 + 0.06), 0.0, 1), steel),
        materials.assign(_box("Cup", (0.8, 0.5, 0.4), (0, b + 1.4, D / 2 + 0.1), 0.04, 2), steel),
        materials.assign(_box("CupMouth", (0.6, 0.3, 0.06), (0, b + 1.45, D / 2 + 0.3), 0.0, 1), black),
    ]
    return shapes.join(parts, "ChangeMachine")


def arcade_carpet():
    """The arcade's floor in a 10 x 10 panel (laid over the room, stretched
    to fit): black carpet in neon squiggles."""
    pixels, (rect,) = _atlas([carpet()])
    picture = _picture_mat("ArcadeCarpetPic", pixels, 0.95, roughness=0.95)
    slab = materials.assign(_box("Slab", (10.0, 0.04, 10.0), (0, -0.005, 0), 0.0, 1), _plastic("CarpetEdge", (14, 12, 22)))
    top = _top_card("Top", picture, 10.0, 10.0, (0, 0.016, 0), rect)
    obj = shapes.join([slab, top], "ArcadeCarpet")
    obj["bake_size"] = 1024
    return obj


# Electronics ---------------------------------------------------------------------


def showroom_tv():
    """A showroom TV on the window's stand (4 x 3 x 1.2): a 26-inch tube in a
    walnut-grain case, its convex screen dark, the knobs and grille down the
    right. Its front is +z."""
    wood = materials.wood("TVWood", (70, 44, 26), (120, 80, 46), grain_axis="X", scale=1.5, roughness=0.45)
    silver = materials.brass("TVSilver", color=(170, 170, 168), roughness=0.4)
    glass = _glass("TVGlass", (18, 24, 26))
    black = _plastic("TVBlack", (20, 20, 22))
    W, H, D = 4.0, 3.0, 1.2
    parts = [
        materials.assign(_box("Case", (W, H, D), (0, 0, 0), 0.08, 3), wood),
        materials.assign(_box("Bezel", (2.9, 2.5, 0.08), (-0.45, 0, D / 2 + 0.02), 0.05, 2), silver),
        materials.assign(shapes.cushion("Screen", S(2.6, 2.1, 0.22), G(-0.45, 0.05, D / 2 + 0.02), puff=0.05, levels=2, roundness=0.55), glass),
        materials.assign(_box("Panel", (0.7, 2.5, 0.06), (1.5, 0, D / 2 + 0.01), 0.03, 2), black),
    ]
    for k in range(3):
        knob = _lathe("Knob", [(0.0, 0.0), (0.14, 0.0), (0.14, 0.1), (0.0, 0.12)], (0, 0, 0), 14)
        parts.append(materials.assign(_place(knob, (90, 0, 0), (1.5, 0.85 - k * 0.45, D / 2 + 0.04)), silver))
    for k in range(6):
        parts.append(materials.assign(_box("Grille", (0.5, 0.04, 0.02), (1.5, -0.4 - k * 0.12, D / 2 + 0.05), 0.0, 1), silver))
    return shapes.join(parts, "ShowroomTV")


def tv_stand_long():
    """The window's TV stand (14 x 2.6 x 2): black ash laminate, three open
    bays with a VCR, a stereo and a tape deck in them. Its front is +z."""
    ash = _laminate("StandAsh", (26, 26, 28))
    silver = materials.brass("StandSilver", color=(160, 160, 158), roughness=0.4)
    black = _plastic("StandBlack", (14, 14, 16))
    red = _plastic("StandLED", (230, 40, 30))
    W, H, D = 14.0, 2.6, 2.0
    b, t = -H / 2, H / 2
    parts = [
        materials.assign(_box("Top", (W, 0.2, D), (0, t - 0.1, 0), 0.04, 2), ash),
        materials.assign(_box("Bottom", (W, 0.3, D), (0, b + 0.15, 0), 0.02, 1), ash),
        materials.assign(_box("Back", (W, H, 0.1), (0, 0, -D / 2 + 0.05), 0.0, 1), ash),
    ]
    for k in range(4):
        parts.append(materials.assign(_box("Divider", (0.2, H - 0.3, D), (-W / 2 + 0.1 + k * (W - 0.2) / 3, 0, 0), 0.02, 1), ash))
    for k in range(3):
        cx = -W / 2 + 0.1 + (k + 0.5) * (W - 0.2) / 3
        parts.append(materials.assign(_box("Deck", (3.4, 0.55, 1.4), (cx, b + 0.6, 0.1), 0.04, 2), black))
        parts.append(materials.assign(_box("Face", (3.3, 0.45, 0.04), (cx, b + 0.6, 0.82), 0.02, 1), silver))
        parts.append(materials.assign(_box("Slot", (1.4, 0.08, 0.03), (cx - 0.6, b + 0.65, 0.85), 0.0, 1), black))
        parts.append(materials.assign(_box("Clock", (0.5, 0.14, 0.03), (cx + 1.0, b + 0.65, 0.85), 0.0, 1), red))
    return shapes.join(parts, "TVStandLong")


def electronics_shelf():
    """A run of steel wall shelving in electronics (Data/Mall `Shelf`, 7 x 6
    x 3): four shelves of boxed sets, a boom box on one. Its front is +z."""
    steel = materials.paint("ElecSteel", color=(170, 172, 176), roughness=0.5, grime=0.3)
    boxes = _plastic("ElecBox", (232, 230, 222))
    labels, rects = _grid(product_labels(), 4)
    picture = _picture_mat("ElecLabels", labels, 0.45, roughness=0.4)
    W, H, D = 7.0, 6.0, 3.0
    b = -H / 2
    parts = [
        materials.assign(_box("Back", (W - 0.24, H, 0.15), (0, 0, -D / 2 + 0.075), 0.0, 1), steel),
        materials.assign(_box("Plinth", (W - 0.24, 0.4, D - 0.6), (0, b + 0.2, -0.3), 0.02, 1), steel),
    ]
    for sx in (-1, 1):
        parts.append(materials.assign(_box("Upright", (0.12, H, D - 0.6), (sx * (W / 2 - 0.06), 0, -0.3), 0.02, 1), steel))
    rng = random.Random(5)
    for r in range(4):
        y = b + 0.4 + r * 1.35
        parts.append(materials.assign(_box("Shelf", (W - 0.24, 0.08, D - 0.6), (0, y, -0.3), 0.02, 1), steel))
        x = -W / 2 + 0.3
        while x < W / 2 - 1.3:
            w = rng.choice([0.9, 1.1, 1.3])
            h = rng.choice([0.7, 0.9, 1.0])
            box = materials.assign(_box("Box", (w, h, 1.2), (x + w / 2, y + 0.04 + h / 2, -0.5), 0.02, 1), boxes)
            label = _card("Label", picture, w - 0.06, h - 0.06, (x + w / 2, y + 0.04 + h / 2, 0.105), 1, rects[rng.randrange(len(rects))])
            parts += [box, label]
            x += w + 0.12
    # A boom box on the second shelf's end.
    bx, by = W / 2 - 0.8, b + 0.4 + 1.35 + 0.04
    parts.append(materials.assign(_box("BoomBox", (1.2, 0.6, 0.4), (bx, by + 0.3, -0.2), 0.06, 2), _plastic("BoomGrey", (60, 60, 64))))
    for dx in (-0.3, 0.3):
        parts.append(materials.assign(_lathe("Speaker", [(0.0, 0.0), (0.18, 0.0), (0.16, 0.04), (0.0, 0.03)], (0, 0, 0), 16), _plastic("SpeakerCone", (20, 20, 22))))
        parts[-1] = _place(parts[-1], (90, 0, 0), (bx + dx, by + 0.28, 0.01))
    parts.append(materials.assign(_tube("Handle", [(bx - 0.4, by + 0.6, -0.2), (bx - 0.35, by + 0.8, -0.2), (bx + 0.35, by + 0.8, -0.2), (bx + 0.4, by + 0.6, -0.2)], 0.04, 6), _chrome("BoomChrome")))
    obj = shapes.join(parts, "ElectronicsShelf")
    obj["bake_size"] = 1024
    return obj


def display_counter():
    """The glass counter at the back of electronics (10 x 4 x 3), where they
    charge their torches: a black frame, the top glass over the torches on
    navy felt (the three looks, NEW), the front glass over batteries. Its
    front is +z."""
    frame = _laminate("DCFrame", (24, 24, 28))
    alu = materials.brass("DCAlu", color=(170, 170, 166), roughness=0.4)
    pixels, (top_rect, front_rect) = _atlas([torch_case(), batteries_shelf()])
    picture = _picture_mat("DCGlass", pixels, 0.5, roughness=0.1)
    W, H, D = 10.0, 4.0, 3.0
    b, t = -H / 2, H / 2
    parts = [
        materials.assign(_box("Plinth", (W, 0.8, D - 0.2), (0, b + 0.4, -0.1), 0.02, 1), frame),
        materials.assign(_box("Inside", (W - 0.2, H - 1.0, D - 0.4), (0, b + 0.8 + (H - 1.0) / 2, -0.1), 0.0, 1), _plastic("DCInside", (24, 30, 64))),
        _top_card("TopGlass", picture, W - 0.3, D - 0.3, (0, t - 0.02, 0), top_rect),
        _card("FrontGlass", picture, W - 0.3, H - 1.2, (0, b + 0.8 + (H - 1.2) / 2 + 0.1, D / 2 - 0.08), 1, front_rect),
    ]
    for sx in (-1, 1):
        parts.append(materials.assign(_box("Post", (0.12, H - 0.8, 0.12), (sx * (W / 2 - 0.06), b + 0.8 + (H - 0.8) / 2, D / 2 - 0.06), 0.02, 1), alu))
        parts.append(materials.assign(_box("Post", (0.12, H - 0.8, 0.12), (sx * (W / 2 - 0.06), b + 0.8 + (H - 0.8) / 2, -D / 2 + 0.06), 0.02, 1), alu))
    for sz in (-1, 1):
        parts.append(materials.assign(_box("Rim", (W, 0.08, 0.15), (0, t - 0.04, sz * (D / 2 - 0.075)), 0.02, 1), alu))
    for sx in (-1, 1):
        parts.append(materials.assign(_box("Rim", (0.15, 0.08, D), (sx * (W / 2 - 0.075), t - 0.04, 0), 0.02, 1), alu))
    return shapes.join(parts, "DisplayCounter")


# Boutique --------------------------------------------------------------------------


def round_rack():
    """A round rack of jackets (4.6 x 5 x 4.6): a chrome ring on its post and
    foot, sixteen jackets hanging round it in the 80s' colours. Round."""
    chrome = _chrome("RoundChrome")
    cloth = _palette("Jacket", [(70, 110, 190), (24, 22, 24), (236, 80, 150), (64, 196, 196), (120, 70, 180), (180, 196, 214)])
    H = 5.0
    b = -H / 2
    R = 1.7
    ring_y = b + 4.4
    parts = [
        materials.assign(_lathe("Foot", [(0.0, b), (0.9, b), (0.9, b + 0.05), (0.2, b + 0.15), (0.0, b + 0.15)], steps=24), chrome),
        materials.assign(_lathe("Post", [(0.0, b + 0.1), (0.06, b + 0.1), (0.06, ring_y), (0.0, ring_y)], steps=10), chrome),
    ]
    ring = _torus("Ring", R, 0.045, 32, 6)
    ring.location = (0, 0, ring_y)
    parts.append(materials.assign(ring, chrome))
    for k in range(4):
        a = k * math.pi / 2
        parts.append(materials.assign(_tube("Arm", [(0, ring_y, 0), (R * math.cos(a), ring_y, -R * math.sin(a))], 0.035, 5), chrome))
    rng = random.Random(4)
    for k in range(16):
        a = math.tau * k / 16
        at = (R * math.cos(a), ring_y - 0.25, -R * math.sin(a))
        turn = math.degrees(a)
        parts.append(_hanger("Hanger", chrome, at, turn))
        parts.append(_garment("Jacket", JACKET, cloth[rng.randrange(len(cloth))], (at[0], at[1] - 0.12, at[2]), turn, 0.14))
    return shapes.join(parts, "RoundRack")


def _rail(name, outline, colours, count, thick):
    """A straight rail on two chrome uprights and feet (7 x 5 x 1.6), its
    garments hanging across it, side on, as on a shop's rail."""
    chrome = _chrome(name + "Chrome")
    cloth = _palette(name + "Cloth", colours)
    W, H, D = 7.0, 5.0, 1.6
    b = -H / 2
    bar_y = b + 4.5
    parts = [materials.assign(_tube("Bar", [(-W / 2 + 0.1, bar_y, 0), (W / 2 - 0.1, bar_y, 0)], 0.05, 8), chrome)]
    for sx in (-1, 1):
        x = sx * (W / 2 - 0.1)
        parts.append(materials.assign(_tube("Upright", [(x, b + 0.08, 0), (x, bar_y, 0)], 0.05, 8), chrome))
        parts.append(materials.assign(_tube("Foot", [(x, b + 0.05, -D / 2 + 0.05), (x, b + 0.05, D / 2 - 0.05)], 0.05, 8), chrome))
    rng = random.Random(len(name))
    for k in range(count):
        x = -W / 2 + 0.5 + k * (W - 1.0) / (count - 1)
        at = (x, bar_y - 0.2, 0)
        parts.append(_hanger("Hanger", chrome, at, 90))
        parts.append(_garment("Garment", outline, cloth[rng.randrange(len(cloth))], (x, bar_y - 0.32, 0), 90, thick))
    return shapes.join(parts, name)


def rack_tops():
    return _rail("RackTops", SHIRT, EIGHTIES, 13, 0.1)


def rack_bottoms():
    return _rail("RackBottoms", TROUSERS, [(60, 90, 150), (40, 60, 110), (120, 90, 60), (236, 80, 150), (30, 30, 34), (200, 196, 186)], 11, 0.12)


def shoe_wall():
    """The shoe wall (8 x 6 x 1.4): five sloping shelves on a pink slatwall,
    pairs of hi-tops and loafers along them. Its front is +z (off the wall)."""
    back = _laminate("ShoeBack", (230, 196, 206))
    shelf = _laminate("ShoeShelf", (240, 238, 232))
    whites = [_plastic("ShoeWhite", (240, 238, 232)), _plastic("ShoeRed", (200, 40, 40)), _plastic("ShoeBlack", (26, 26, 28)), _plastic("ShoeTeal", (64, 196, 196)), materials.paint("ShoeLeather", color=(90, 50, 30), roughness=0.5, grime=0.2)]
    sole = _plastic("ShoeSole", (220, 214, 200))
    W, H, D = 8.0, 6.0, 1.4
    b = -H / 2
    parts = [materials.assign(_box("Back", (W, H, 0.2), (0, 0, -D / 2 + 0.1), 0.0, 1), back)]
    for k in range(1, 12):
        parts.append(materials.assign(_box("Slat", (W, 0.03, 0.02), (0, b + k * 0.5, -D / 2 + 0.21), 0.0, 1), _plastic("ShoeSlatGroove", (200, 170, 180))))
    rng = random.Random(6)
    for r in range(5):
        y = b + 0.6 + r * 1.1
        s = _place(shapes.box("Shelf", S(W - 0.2, 0.06, 0.9), (0, 0, 0), 0.02, 1), (-10, 0, 0), (0, y, -0.1))
        parts.append(materials.assign(s, shelf))
        for k in range(6):
            x = -W / 2 + 0.75 + k * 1.3
            mat = whites[rng.randrange(len(whites))]
            for dx in (-0.2, 0.2):
                body = shapes.box("Shoe", S(0.3, 0.34, 0.72), (0, 0, 0), 0.1, 1)
                body = _place(body, (-10, 0, 0), (x + dx, y + 0.24, 0.0))
                parts.append(materials.assign(body, mat))
                so = _place(shapes.box("Sole", S(0.34, 0.08, 0.78), (0, 0, 0), 0.0, 1), (-10, 0, 0), (x + dx, y + 0.06, 0.0))
                parts.append(materials.assign(so, sole))
    obj = shapes.join(parts, "ShoeWall")
    obj["bake_size"] = 1024
    return obj


def slatwall():
    """The boutique's slatwall down the west wall (10 x 7 x 1): pale pink
    slatwall, a chrome bar along it with tops facing out, a shelf of folded
    sweaters over them. Its front is +z (off the wall)."""
    back = _laminate("SlatPink", (236, 214, 220))
    groove = _plastic("SlatGroove", (200, 176, 184))
    chrome = _chrome("SlatChrome")
    shelf = _laminate("SlatShelf", (240, 238, 232))
    cloth = _palette("SlatCloth", EIGHTIES)
    W, H, D = 10.0, 7.0, 1.0
    b = -H / 2
    parts = [materials.assign(_box("Back", (W, H, 0.2), (0, 0, -D / 2 + 0.1), 0.0, 1), back)]
    for k in range(1, 14):
        parts.append(materials.assign(_box("Groove", (W, 0.04, 0.02), (0, b + k * 0.5, -D / 2 + 0.21), 0.0, 1), groove))
    bar_y = b + 4.4
    parts.append(materials.assign(_tube("Bar", [(-W / 2 + 0.4, bar_y, -0.1), (W / 2 - 0.4, bar_y, -0.1)], 0.04, 8), chrome))
    rng = random.Random(7)
    for k in range(6):
        x = -W / 2 + 1.0 + k * 1.6
        parts.append(_hanger("Hanger", chrome, (x, bar_y - 0.18, 0.05), 0))
        parts.append(_garment("Top", SHIRT, cloth[rng.randrange(len(cloth))], (x, bar_y - 0.3, 0.06), 0, 0.06))
    sy = b + 5.6
    parts.append(materials.assign(_box("Shelf", (W - 0.6, 0.08, 0.8), (0, sy, -0.1), 0.02, 1), shelf))
    for k in range(7):
        x = -W / 2 + 0.9 + k * 1.35
        for j in range(3):
            parts.append(materials.assign(_box("Folded", (0.9, 0.16, 0.6), (x, sy + 0.12 + j * 0.17, -0.1), 0.05, 2), cloth[(k + j) % len(cloth)]))
    return shapes.join(parts, "Slatwall")


def changing_booth():
    """The changing booth in the boutique's back corner (6 x 8 x 6): pink
    laminate walls under a FITTING ROOM header, the curtain on its rail
    drawn most of the way across, the long mirror inside (LB3's: you see
    yourself in it), a stool and a hook. Its front is +z. Built hollow; the
    game's block stays solid until LB3 opens it."""
    pink = _laminate("BoothPink", (226, 188, 198))
    chrome = _chrome("FitChrome")
    mirror = materials.brass("FitMirror", color=(200, 206, 210), roughness=0.08)
    curtain = materials.velvet("FitCurtain", color=(120, 40, 70))
    pixels, (rect,) = _atlas([fitting_header()])
    picture = _picture_mat("FitHeader", pixels, 0.25, roughness=0.3)
    W, H, D = 6.0, 8.0, 6.0
    b = -H / 2
    th = 0.2
    wall_h = H - 0.9
    parts = [
        materials.assign(_box("Back", (W - 2 * th, wall_h, th), (0, b + wall_h / 2, -D / 2 + th / 2), 0.02, 1), pink),
        materials.assign(_box("Header", (W, 0.9, D), (0, H / 2 - 0.45, 0), 0.03, 2), pink),
        _card("HeaderText", picture, W - 0.4, 0.7, (0, H / 2 - 0.45, D / 2 + 0.005), 1, rect),
        materials.assign(_box("Mirror", (2.0, 5.5, 0.04), (0, b + 3.6, -D / 2 + th + 0.02), 0.0, 1), mirror),
        materials.assign(_box("MirrorFrame", (2.2, 5.7, 0.03), (0, b + 3.6, -D / 2 + th + 0.005), 0.02, 1), chrome),
        materials.assign(_lathe("Stool", [(0.0, b), (0.5, b), (0.5, b + 1.4), (0.0, b + 1.4)], (1.8, 0, -1.6), 18), pink),
        materials.assign(_tube("Rail", [(-W / 2 + 0.2, H / 2 - 1.0, D / 2 - 0.25), (W / 2 - 0.2, H / 2 - 1.0, D / 2 - 0.25)], 0.04, 8), chrome),
        materials.assign(_tube("Hook", [(-W / 2 + th, b + 5.5, -1.0), (-W / 2 + th + 0.3, b + 5.5, -1.0), (-W / 2 + th + 0.35, b + 5.65, -1.0)], 0.03, 6), chrome),
    ]
    for sx in (-1, 1):
        parts.append(materials.assign(_box("Side", (th, wall_h, D), (sx * (W / 2 - th / 2), b + wall_h / 2, 0), 0.02, 1), pink))
    # The curtain, pleated, from the left jamb most of the way across.
    folds = 12
    x0, x1 = -W / 2 + th, W / 2 - 1.6
    top_y, bottom_y = H / 2 - 1.05, b + 0.2
    # A pleated outline, given its thickness, stood up: a closed solid.
    zig = [(x0 + (x1 - x0) * i / (folds * 2), D / 2 - 0.3 + (0.08 if i % 2 else -0.04)) for i in range(folds * 2 + 1)]
    ring = zig + [(x, z - 0.04) for x, z in reversed(zig)]
    bm = bmesh.new()
    lo = [bm.verts.new(G(x, bottom_y, z)) for x, z in ring]
    hi = [bm.verts.new(G(x, top_y, z)) for x, z in ring]
    n = len(ring)
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new((lo[i], lo[j], hi[j], hi[i]))
    for t in geometry.tessellate_polygon([[Vector((x, z, 0.0)) for x, z in ring]]):
        bm.faces.new((lo[t[0]], lo[t[1]], lo[t[2]]))
        bm.faces.new((hi[t[2]], hi[t[1]], hi[t[0]]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    # (Concave, so it can come out inside out: its foot faces down.)
    for f in bm.faces:
        if all(v in lo for v in f.verts):
            f.normal_update()
            if f.normal.z > 0:
                bmesh.ops.reverse_faces(bm, faces=bm.faces)
            break
    parts.append(materials.assign(shapes.smooth(_new("Curtain", bm), 80), curtain))
    return shapes.join(parts, "ChangingBooth")


def cash_wrap():
    """The boutique's cash wrap (7 x 4 x 3): a pink laminate counter with a
    chrome band, a glass top case of jewellery, the till, a stack of THANK
    YOU bags. Its front is +z (the customers')."""
    pink = _laminate("WrapPink", (220, 160, 180))
    chrome = _chrome("WrapChrome")
    top = _formica("WrapTop", (240, 238, 232))
    beige = _plastic("WrapTill", (198, 188, 166))
    glass = _glass("WrapGlass", (60, 66, 70))
    pixels, (rect,) = _atlas([bag_print()])
    picture = _picture_mat("WrapBag", pixels, 0.2, roughness=0.6)
    W, H, D = 7.0, 4.0, 3.0
    b, t = -H / 2, H / 2
    parts = [
        materials.assign(_box("Body", (W, H - 0.15, D - 0.2), (0, b + (H - 0.15) / 2, -0.1), 0.06, 2), pink),
        materials.assign(_box("Band", (W + 0.02, 0.18, 0.04), (0, b + 2.8, D / 2 - 0.18), 0.02, 2), chrome),
        materials.assign(_box("Top", (W + 0.1, 0.15, D), (0, t - 0.075, 0), 0.04, 2), top),
        materials.assign(_box("Till", (1.4, 0.7, 1.0), (2.2, t + 0.35, -0.5), 0.06, 2), beige),
        materials.assign(_box("Case", (2.0, 0.5, 1.0), (-1.8, t + 0.25, 0.4), 0.03, 2), glass),
        materials.assign(_box("CaseFrame", (2.06, 0.06, 1.06), (-1.8, t + 0.5, 0.4), 0.02, 1), chrome),
    ]
    for k in range(4):
        bag = materials.assign(_box("Bag", (0.9, 1.1, 0.25), (0, 0, 0), 0.02, 1), pink)
        face = _card("BagPrint", picture, 0.85, 1.05, (0, 0, 0.13), 1, rect)
        joined = shapes.join([bag, face], "Bag")
        parts.append(_place(joined, (0, 0, -6 + k * 4), (0.2 + k * 0.05, t + 0.55, 0.6 - k * 0.27)))
    return shapes.join(parts, "CashWrap")


MALL2 = [
    diner_backbar,
    diner_counter,
    diner_stool,
    diner_booth_seat,
    diner_table,
    menu_board,
    jukebox,
    diner_floor,
    video_shelf,
    video_island,
    video_counter,
    counter_tv,
    standee,
    cabinet_house_call,
    cabinet_night_drive,
    cabinet_dead,
    prize_counter,
    prize_wall,
    change_machine,
    arcade_carpet,
    showroom_tv,
    tv_stand_long,
    electronics_shelf,
    display_counter,
    round_rack,
    rack_tops,
    rack_bottoms,
    shoe_wall,
    slatwall,
    changing_booth,
    cash_wrap,
]
