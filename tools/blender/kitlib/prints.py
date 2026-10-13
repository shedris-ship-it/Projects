"""The printed and written surfaces of kit9 (the visual rework V4, the
atmosphere batch): a telephone's dial card, two magazine covers, a cassette's
label, a matchbox's, the letters' envelope, a pharmacy label, a D-cell's
wrapper and a battery carton's side. Each function returns an h x w x 3
picture (0-1 sRGB, row 0 at the top), mapped straight onto a face of its
piece (decor's canvas: the "Pattern" layer).

Nothing here copies a real brand: the names are made up and the type is a
small block alphabet drawn here (FONT), which is what a 1988 label printed
in a hurry looks like at arm's length.
"""

import math

import numpy as np

# A 5 x 7 block alphabet: each glyph is seven rows of five, '#' inked.
FONT = {
    "A": [" ### ", "#   #", "#   #", "#####", "#   #", "#   #", "#   #"],
    "B": ["#### ", "#   #", "#   #", "#### ", "#   #", "#   #", "#### "],
    "C": [" ### ", "#   #", "#    ", "#    ", "#    ", "#   #", " ### "],
    "D": ["#### ", "#   #", "#   #", "#   #", "#   #", "#   #", "#### "],
    "E": ["#####", "#    ", "#    ", "#### ", "#    ", "#    ", "#####"],
    "F": ["#####", "#    ", "#    ", "#### ", "#    ", "#    ", "#    "],
    "G": [" ### ", "#   #", "#    ", "# ###", "#   #", "#   #", " ####"],
    "H": ["#   #", "#   #", "#   #", "#####", "#   #", "#   #", "#   #"],
    "I": [" ### ", "  #  ", "  #  ", "  #  ", "  #  ", "  #  ", " ### "],
    "K": ["#   #", "#  # ", "# #  ", "##   ", "# #  ", "#  # ", "#   #"],
    "L": ["#    ", "#    ", "#    ", "#    ", "#    ", "#    ", "#####"],
    "M": ["#   #", "## ##", "# # #", "# # #", "#   #", "#   #", "#   #"],
    "N": ["#   #", "##  #", "# # #", "#  ##", "#   #", "#   #", "#   #"],
    "O": [" ### ", "#   #", "#   #", "#   #", "#   #", "#   #", " ### "],
    "P": ["#### ", "#   #", "#   #", "#### ", "#    ", "#    ", "#    "],
    "R": ["#### ", "#   #", "#   #", "#### ", "# #  ", "#  # ", "#   #"],
    "S": [" ####", "#    ", "#    ", " ### ", "    #", "    #", "#### "],
    "T": ["#####", "  #  ", "  #  ", "  #  ", "  #  ", "  #  ", "  #  "],
    "U": ["#   #", "#   #", "#   #", "#   #", "#   #", "#   #", " ### "],
    "V": ["#   #", "#   #", "#   #", "#   #", "#   #", " # # ", "  #  "],
    "W": ["#   #", "#   #", "#   #", "# # #", "# # #", "## ##", "#   #"],
    "X": ["#   #", "#   #", " # # ", "  #  ", " # # ", "#   #", "#   #"],
    "Y": ["#   #", "#   #", " # # ", "  #  ", "  #  ", "  #  ", "  #  "],
    "0": [" ### ", "#   #", "#  ##", "# # #", "##  #", "#   #", " ### "],
    "1": ["  #  ", " ##  ", "  #  ", "  #  ", "  #  ", "  #  ", " ### "],
    "2": [" ### ", "#   #", "    #", "   # ", "  #  ", " #   ", "#####"],
    "3": ["#####", "   # ", "  #  ", "   # ", "    #", "#   #", " ### "],
    "4": ["   # ", "  ## ", " # # ", "#  # ", "#####", "   # ", "   # "],
    "5": ["#####", "#    ", "#### ", "    #", "    #", "#   #", " ### "],
    "6": ["  ## ", " #   ", "#    ", "#### ", "#   #", "#   #", " ### "],
    "7": ["#####", "    #", "   # ", "  #  ", " #   ", " #   ", " #   "],
    "8": [" ### ", "#   #", "#   #", " ### ", "#   #", "#   #", " ### "],
    "9": [" ### ", "#   #", "#   #", " ####", "    #", "   # ", " ##  "],
    ".": ["     ", "     ", "     ", "     ", "     ", " ##  ", " ##  "],
    ",": ["     ", "     ", "     ", "     ", " ##  ", "  #  ", " #   "],
    "-": ["     ", "     ", "     ", "#####", "     ", "     ", "     "],
    "&": [" ##  ", "#  # ", "#  # ", " ##  ", "# # #", "#  # ", " ## #"],
    "'": ["  #  ", "  #  ", " #   ", "     ", "     ", "     ", "     "],
    " ": ["     "] * 7,
}


def _rgb(c):
    return np.array(c, dtype=np.float64) / 255.0


def blank(h, w, colour):
    img = np.ones((h, w, 3)) * _rgb(colour)
    return img


def grid(h, w):
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float64)
    return xx, yy


def put(img, mask, colour, alpha=1.0):
    """Ink `colour` where mask (0-1, the picture's size) says, `alpha` of it."""
    a = np.clip(mask, 0.0, 1.0)[..., None] * alpha
    img[:] = img * (1 - a) + _rgb(colour) * a


def rect(img, x0, y0, x1, y1, colour, alpha=1.0, soft=0.8):
    h, w = img.shape[:2]
    xx, yy = grid(h, w)
    m = np.clip(np.minimum.reduce([xx - x0, x1 - xx, yy - y0, y1 - yy]) / soft + 0.5, 0, 1)
    put(img, m, colour, alpha)


def disc(img, cx, cy, r, colour, alpha=1.0, soft=0.8):
    h, w = img.shape[:2]
    xx, yy = grid(h, w)
    d = np.sqrt((xx - cx) ** 2 + (yy - cy) ** 2)
    put(img, np.clip((r - d) / soft + 0.5, 0, 1), colour, alpha)


def ring(img, cx, cy, r, width, colour, alpha=1.0, soft=0.8):
    h, w = img.shape[:2]
    xx, yy = grid(h, w)
    d = np.abs(np.sqrt((xx - cx) ** 2 + (yy - cy) ** 2) - r)
    put(img, np.clip((width / 2 - d) / soft + 0.5, 0, 1), colour, alpha)


def text(img, s, x, y, height, colour, alpha=1.0, spacing=1.0, width_scale=1.0, bold=0.0):
    """Block letters, their top-left at (x, y) pixels, `height` pixels tall.
    Returns the x after the last letter."""
    px = height / 7.0
    pw = px * width_scale
    h, w = img.shape[:2]
    mask = np.zeros((h, w))
    cx = x
    for ch in s.upper():
        glyph = FONT.get(ch, FONT[" "])
        for row, line in enumerate(glyph):
            for col, c in enumerate(line):
                if c == "#":
                    x0 = cx + col * pw - bold
                    y0 = y + row * px - bold
                    x1, y1 = x0 + pw + 2 * bold, y0 + px + 2 * bold
                    ix0, iy0 = max(int(math.floor(x0)), 0), max(int(math.floor(y0)), 0)
                    ix1, iy1 = min(int(math.ceil(x1)), w), min(int(math.ceil(y1)), h)
                    if ix1 <= ix0 or iy1 <= iy0:
                        continue
                    xs = np.arange(ix0, ix1) + 0.5
                    ys = np.arange(iy0, iy1) + 0.5
                    cov_x = np.clip(np.minimum(xs - x0, x1 - xs) + 0.5, 0, 1)
                    cov_y = np.clip(np.minimum(ys - y0, y1 - ys) + 0.5, 0, 1)
                    mask[iy0:iy1, ix0:ix1] = np.maximum(mask[iy0:iy1, ix0:ix1], cov_y[:, None] * cov_x[None, :])
        cx += (5 + spacing) * pw
    put(img, mask, colour, alpha)
    return cx


def text_width(s, height, spacing=1.0, width_scale=1.0):
    return len(s) * (5 + spacing) * height / 7.0 * width_scale - spacing * height / 7.0 * width_scale


def stroke(img, points, width, colour, alpha=1.0):
    """A pen line through `points` [(x, y), ...] pixels, `width` across."""
    h, w = img.shape[:2]
    mask = np.zeros((h, w))
    r = width / 2.0
    for (ax, ay), (bx, by) in zip(points, points[1:]):
        x0, x1 = int(max(min(ax, bx) - r - 1, 0)), int(min(max(ax, bx) + r + 2, w))
        y0, y1 = int(max(min(ay, by) - r - 1, 0)), int(min(max(ay, by) + r + 2, h))
        if x1 <= x0 or y1 <= y0:
            continue
        yy, xx = np.mgrid[y0:y1, x0:x1].astype(np.float64) + 0.5
        dx, dy = bx - ax, by - ay
        length2 = dx * dx + dy * dy
        t = np.clip(((xx - ax) * dx + (yy - ay) * dy) / max(length2, 1e-9), 0, 1)
        d = np.sqrt((xx - ax - t * dx) ** 2 + (yy - ay - t * dy) ** 2)
        mask[y0:y1, x0:x1] = np.maximum(mask[y0:y1, x0:x1], np.clip(r - d + 0.5, 0, 1))
    put(img, mask, colour, alpha)


def scribble(img, x0, y0, x1, height, rng, colour, width=1.6, alpha=0.9):
    """A line of joined-up handwriting from (x0, y0 baseline) to x1: loops
    of no words (a prolate cycloid, each loop a letter, some tall), which is
    how writing reads from a step away."""
    x = x0
    slant = 0.25
    while x < x1 - height:
        letters = int(rng.integers(3, 8))
        pts = []
        for _ in range(letters):
            tall = rng.random() < 0.2
            amp = height * (1.0 if tall else rng.uniform(0.42, 0.55))
            wide = height * rng.uniform(0.28, 0.38)
            loop = wide * rng.uniform(0.5, 0.9)
            for k in range(13):
                t = math.tau * k / 12
                y = y0 - amp * (1 - math.cos(t)) / 2
                pts.append((x + wide * t / math.tau - loop * math.sin(t) / math.tau * 2 + (y0 - y) * slant, y))
            x += wide
            if x > x1:
                break
        stroke(img, pts, width, colour, alpha)
        x += height * rng.uniform(0.5, 0.9)


def blur(img, r):
    """A box blur `r` pixels each way, twice (soft, as a printed photo)."""
    out = img.copy()
    for _ in range(2):
        for axis in (0, 1):
            acc = np.zeros_like(out)
            for d in range(-r, r + 1):
                acc += np.roll(out, d, axis=axis)
            out = acc / (2 * r + 1)
    return out


def age(img, rng, amount=0.08, yellow=(0.97, 0.94, 0.86)):
    """Handled and yellowed: a soft mottle, the edges a little darker."""
    h, w = img.shape[:2]
    cells = max(h, w) // 24 + 2
    g = rng.uniform(-1, 1, (cells, cells))
    yy = np.linspace(0, cells - 1.001, h)
    xx = np.linspace(0, cells - 1.001, w)
    y0, x0 = yy.astype(int), xx.astype(int)
    fy, fx = (yy - y0)[:, None], (xx - x0)[None, :]
    a = g[y0][:, x0] * (1 - fx) + g[y0][:, x0 + 1] * fx
    b = g[y0 + 1][:, x0] * (1 - fx) + g[y0 + 1][:, x0 + 1] * fx
    n = a * (1 - fy) + b * fy
    img *= (1 + amount * n)[..., None]
    img *= np.array(yellow)
    u = np.linspace(-1, 1, w)[None, :]
    v = np.linspace(-1, 1, h)[:, None]
    edge = np.clip(np.maximum(np.abs(u), np.abs(v)) - 0.85, 0, 1) / 0.15
    img *= (1 - 0.12 * edge)[..., None]
    np.clip(img, 0, 1, out=img)
    return img


# The pictures ------------------------------------------------------------------


def dial_card(n=512, seed=2):
    """A rotary telephone's dial, seen face on (its top toward row 0): the
    white number card under a clear finger wheel, ten holes round it with a
    digit under each, the number card in the middle, and the wheel's rim."""
    rng = np.random.default_rng(seed)
    img = blank(n, n, (236, 232, 222))
    c = n / 2
    ink = (24, 22, 20)
    # The finger wheel's rim and the shadow of its holes over the card.
    ring(img, c, c, n * 0.47, n * 0.035, (196, 192, 184))
    ring(img, c, c, n * 0.485, n * 0.01, (150, 146, 138))
    # Holes from 1 (upper right) round anticlockwise to 0 (bottom), as a
    # Western dial runs; the finger stop sits past the 0.
    for k, digit in enumerate("1234567890"):
        a = math.radians(60 + k * 30)  # from the right, anticlockwise
        hx, hy = c + math.cos(a) * n * 0.34, c - math.sin(a) * n * 0.34
        disc(img, hx + 3, hy + 4, n * 0.072, (170, 166, 158))  # its shadow
        disc(img, hx, hy, n * 0.068, (246, 244, 238))
        ring(img, hx, hy, n * 0.068, n * 0.012, (120, 116, 110))
        th = n * 0.05
        text(img, digit, hx - text_width(digit, th) / 2, hy - th / 2, th, ink, bold=0.3)
    # The number card in the middle: a ring and the house's number, typed.
    disc(img, c, c, n * 0.17, (226, 220, 204))
    ring(img, c, c, n * 0.17, n * 0.01, (110, 104, 96))
    rect(img, c - n * 0.11, c - n * 0.006, c + n * 0.11, c + n * 0.006, (150, 60, 50))
    text(img, "555-0143", c - text_width("555-0143", n * 0.035) / 2, c - n * 0.07, n * 0.035, ink)
    scribble(img, c - n * 0.09, c + n * 0.07, c + n * 0.09, n * 0.03, rng, (40, 50, 110), 1.3)
    return age(img, rng, 0.05, (0.98, 0.96, 0.9))


def magazine_hearth(h=660, w=512, seed=8):
    """A home magazine, autumn 1988: a pale masthead, a lit house at dusk in
    the cover photo, cover lines down the side, the price and the date."""
    rng = np.random.default_rng(seed)
    img = blank(h, w, (232, 226, 210))
    # The photograph: a warm-windowed house under a blue dusk, a lawn.
    xx, yy = grid(h, w)
    sky = np.clip((yy - 120) / 380, 0, 1)
    photo = np.stack([0.24 + 0.3 * sky, 0.3 + 0.24 * sky, 0.52 + 0.06 * sky], -1)
    mask = (yy > 118) & (yy < h - 24) & (xx > 18) & (xx < w - 18)
    img[mask] = photo[mask]
    rect(img, 18, 470, w - 18, h - 24, (58, 74, 44))  # the lawn
    rect(img, 120, 300, 400, 470, (196, 184, 160))  # the house's front
    rect(img, 110, 290, 410, 302, (90, 70, 56))
    for x0, x1, y0, y1 in ((150, 210, 330, 390), (310, 370, 330, 390), (235, 285, 380, 470)):
        rect(img, x0, y0, x1, y1, (238, 196, 110) if y1 < 400 else (110, 72, 50))
    # The roof as a triangle.
    roof = (yy > 200 + np.abs(xx - 260) * 0.62) & (yy < 296) & (xx > 96) & (xx < 424)
    img[roof] = _rgb((84, 60, 52))
    inside = (yy > 118) & (yy < h - 24) & (xx > 18) & (xx < w - 18)
    img[inside] = blur(img, 2)[inside]
    # The masthead and the lines.
    rect(img, 18, 18, w - 18, 110, (164, 52, 40))
    text(img, "HEARTHSIDE", 34, 34, 64, (248, 240, 226), spacing=0.8, width_scale=0.82)
    text(img, "NOVEMBER 1988", 34, 100, 9, (248, 240, 226))
    text(img, "$2.25", w - 92, 100, 9, (248, 240, 226))
    for k, line in enumerate(("WARM ROOMS", "FOR WINTER", "", "OUR READERS'", "OLD HOUSES")):
        if line:
            text(img, line, 30, 140 + k * 26, 18, (250, 246, 236), bold=0.4)
    rect(img, 300, 510, w - 30, h - 40, (238, 220, 120))
    text(img, "40 PIES", 318, 528, 22, (120, 40, 30), bold=0.4)
    text(img, "& TARTS", 318, 560, 22, (120, 40, 30), bold=0.4)
    return age(img, rng, 0.07)


def magazine_screen(h=660, w=512, seed=13):
    """A television listings weekly: a red band masthead, a face in a
    studio-lit portrait, the week's dates, a strip of small pictures."""
    rng = np.random.default_rng(seed)
    img = blank(h, w, (240, 236, 228))
    xx, yy = grid(h, w)
    # The portrait: a warm face under studio light on a teal ground.
    rect(img, 0, 96, w, h - 90, (40, 98, 110))
    face = ((xx - 256) / 92) ** 2 + ((yy - 300) / 120) ** 2 < 1
    hair = ((xx - 256) / 120) ** 2 + ((yy - 250) / 120) ** 2 < 1
    img[hair & (yy < 330)] = _rgb((58, 36, 26))
    img[face] = _rgb((214, 164, 130))
    shoulders = ((xx - 256) / 220) ** 2 + ((yy - 560) / 150) ** 2 < 1
    img[shoulders & (yy < h - 90)] = _rgb((150, 40, 48))
    # Studio light from the left: the face and shoulders fall off to the right.
    light = np.clip(1.15 - (xx - 150) / 360, 0.55, 1.15)[..., None]
    region = (yy > 96) & (yy < h - 90)
    img[region] = (img * light)[region]
    for ex in (226, 286):
        disc(img, ex, 292, 9, (238, 226, 214))
        disc(img, ex + 1, 293, 5, (54, 36, 28))
    stroke(img, [(214, 276), (240, 272)], 4, (70, 44, 32))
    stroke(img, [(272, 272), (298, 276)], 4, (70, 44, 32))
    stroke(img, [(240, 360), (256, 364), (272, 360)], 6, (170, 84, 84))
    img[region] = blur(img, 3)[region]
    # The masthead.
    rect(img, 0, 0, w, 96, (200, 36, 34))
    text(img, "TELE-VIEW", 24, 14, 62, (255, 250, 240), spacing=0.6, width_scale=0.9, bold=0.6)
    text(img, "OCT 29 - NOV 4", 24, 80, 10, (255, 236, 200))
    text(img, "75C", w - 64, 80, 10, (255, 236, 200))
    # The strip of small pictures along the foot.
    rect(img, 0, h - 90, w, h, (24, 24, 28))
    for k in range(4):
        x0 = 14 + k * 124
        rect(img, x0, h - 80, x0 + 110, h - 12, tuple(int(v) for v in rng.integers(60, 200, 3)))
    text(img, "THE NEW SEASON", 24, 112, 20, (255, 236, 120), bold=0.5)
    return age(img, rng, 0.06)


def cassette_top(h=256, w=400, seed=21):
    """A cassette's top face: black shell, a cream label with a red band and
    a handwritten title, the window over the two reels, five screws."""
    rng = np.random.default_rng(seed)
    img = blank(h, w, (30, 29, 28))
    rect(img, 22, 16, w - 22, h - 58, (226, 216, 190), soft=1.2)
    rect(img, 22, 16, w - 22, 42, (178, 44, 38))
    text(img, "A", 32, 22, 16, (250, 240, 220), bold=0.4)
    text(img, "C90", w - 72, 22, 16, (250, 240, 220), bold=0.4)
    for k in range(3):
        stroke(img, [(40, 62 + k * 20), (w - 40, 62 + k * 20)], 1, (190, 170, 150))
    scribble(img, 46, 70, 260, 18, rng, (30, 40, 110), 2.4)
    # The window and the reels of tape through it.
    rect(img, 120, 96, w - 120, 150, (54, 46, 40))
    for cx in (156, w - 156):
        disc(img, cx, 123, 34, (78, 52, 36))
        disc(img, cx, 123, 14, (236, 232, 222))
        for k in range(6):
            a = k * math.tau / 6
            stroke(img, [(cx, 123), (cx + math.cos(a) * 11, 123 + math.sin(a) * 11)], 2.2, (60, 56, 52))
    # The screws.
    for sx, sy in ((14, 12), (w - 14, 12), (14, h - 12), (w - 14, h - 12), (w / 2, h - 30)):
        disc(img, sx, sy, 6, (120, 118, 114))
        stroke(img, [(sx - 4, sy), (sx + 4, sy)], 1.5, (40, 40, 40))
    return age(img, rng, 0.04, (1.0, 0.99, 0.96))


def matchbox_label(h=256, w=384, seed=3):
    """A matchbox's label: a red ground, a white star in a ring, a
    border of lines, block letters."""
    rng = np.random.default_rng(seed)
    img = blank(h, w, (178, 40, 32))
    rect(img, 10, 10, w - 10, h - 10, (236, 222, 190), soft=1)
    rect(img, 18, 18, w - 18, h - 18, (178, 40, 32), soft=1)
    disc(img, w / 2, h / 2 - 12, 62, (236, 222, 190))
    disc(img, w / 2, h / 2 - 12, 54, (24, 30, 60))
    xx, yy = grid(h, w)
    a = np.arctan2(yy - (h / 2 - 12), xx - w / 2)
    d = np.sqrt((xx - w / 2) ** 2 + (yy - (h / 2 - 12)) ** 2)
    star = d < 46 * (0.55 + 0.45 * np.cos(5 * (a + math.pi / 2)) ** 8)
    img[star] = _rgb((240, 230, 200))
    word = "SAFETY MATCHES"
    text(img, word, w / 2 - text_width(word, 18) / 2, h - 52, 18, (240, 228, 196), bold=0.3)
    return age(img, rng, 0.08)


def envelope(h=300, w=512, seed=17):
    """The top letter of a bundle: cream laid paper, an address in ink,
    a stamp and its postmark, the sender's name on the corner."""
    rng = np.random.default_rng(seed)
    img = blank(h, w, (232, 222, 196))
    # Laid lines in the paper.
    for y in range(0, h, 6):
        stroke(img, [(0, y), (w, y)], 1, (220, 210, 184), 0.5)
    ink = (36, 40, 86)
    for k, (x0, x1) in enumerate(((180, 400), (180, 430), (180, 360))):
        scribble(img, x0, 170 + k * 34, x1, 20, rng, ink, 2.2)
    scribble(img, 30, 46, 140, 10, rng, ink, 1.4)
    scribble(img, 30, 64, 120, 10, rng, ink, 1.4)
    # The stamp: a portrait in a perforated frame.
    rect(img, w - 108, 18, w - 26, 112, (246, 240, 226), soft=1.5)
    rect(img, w - 100, 26, w - 34, 104, (66, 92, 140))
    disc(img, w - 67, 62, 18, (222, 214, 196))
    text(img, "25", w - 96, 88, 10, (246, 240, 226))
    for k in range(4):
        x = w - 170 + k * 10
        stroke(img, [(x + math.sin(t / 6.0) * 2, 30 + t) for t in range(0, 70, 4)], 2, (40, 40, 44), 0.6)
    ring(img, w - 150, 60, 30, 3, (40, 40, 44), 0.6)
    text(img, "OCT 12", w - 172, 54, 9, (40, 40, 44), 0.6)
    return age(img, rng, 0.1, (0.97, 0.93, 0.84))


def pill_label(h=256, w=640, seed=29):
    """A pharmacy's typed label for round the bottle (its width the bottle's
    girth, its middle to the front): the shop's name, Rx and a number, the
    patient, the dose, the doctor."""
    rng = np.random.default_rng(seed)
    img = blank(h, w, (240, 238, 230))
    ink = (30, 30, 34)
    x0 = w * 0.18
    rect(img, x0, 16, w * 0.82, 50, (40, 70, 140))
    text(img, "ELM ST. PHARMACY", x0 + 10, 24, 18, (250, 250, 250), bold=0.3)
    text(img, "RX 104223", x0 + 6, 66, 16, ink)
    text(img, "10-02-88", w * 0.82 - text_width("10-02-88", 16) - 6, 66, 16, ink)
    text(img, "PRYOR, M.", x0 + 6, 98, 20, ink, bold=0.3)
    text(img, "TAKE 1 TABLET", x0 + 6, 132, 16, ink)
    text(img, "EVERY 6 HOURS", x0 + 6, 156, 16, ink)
    text(img, "FOR PAIN", x0 + 6, 180, 16, ink)
    rect(img, x0, 214, w * 0.82, 238, (232, 190, 60))
    text(img, "MAY CAUSE DROWSINESS", x0 + 8, 219, 14, ink)
    return age(img, rng, 0.06)


def battery_wrap(h=256, w=512, seed=31):
    """A D-cell's printed wrapper: x along the cell (its ends gold), y round
    its girth, the big D and the volts printed twice round it. (The piece
    turns it so the type runs along the cell, as it does on one.)"""
    rng = np.random.default_rng(seed)
    img = blank(h, w, (26, 26, 28))
    rect(img, 0, 0, 56, h, (190, 150, 60))
    rect(img, w - 56, 0, w, h, (190, 150, 60))
    for y0 in (0, h // 2):
        text(img, "D", 92, y0 + 22, 84, (232, 228, 214), bold=1.0)
        text(img, "HEAVY DUTY", 180, y0 + 30, 22, (232, 200, 90), bold=0.4)
        text(img, "1.5 VOLTS", 180, y0 + 72, 26, (232, 228, 214), bold=0.4)
    return age(img, rng, 0.04, (1.0, 0.98, 0.94))


def carton_side(h=320, w=640, seed=37):
    """A battery carton's long side: kraft board, a black and yellow band,
    a drawn D-cell, block letters."""
    rng = np.random.default_rng(seed)
    img = blank(h, w, (172, 132, 88))
    xx, yy = grid(h, w)
    # Corrugated board shows through the print as faint stripes.
    img *= (1 + 0.025 * np.sin(xx / 3.0))[..., None]
    rect(img, 0, 96, w, 230, (232, 186, 40))
    rect(img, 0, 96, w, 108, (24, 24, 24))
    rect(img, 0, 218, w, 230, (24, 24, 24))
    # A D-cell lying across the band.
    rect(img, 60, 128, 220, 200, (26, 26, 28), soft=2)
    rect(img, 60, 128, 220, 140, (190, 150, 60))
    rect(img, 60, 188, 220, 200, (190, 150, 60))
    rect(img, 220, 150, 236, 178, (170, 170, 172), soft=2)
    text(img, "D", 120, 146, 40, (232, 228, 214), bold=0.6)
    text(img, "BATTERIES", 270, 124, 40, (24, 24, 24), spacing=0.8, bold=0.8)
    text(img, "24 CELLS  1.5V", 272, 180, 22, (24, 24, 24), bold=0.4)
    text(img, "THIS SIDE UP", 40, 40, 20, (60, 44, 30), 0.8)
    # A shipping stamp gone faint.
    ring(img, w - 90, 52, 34, 4, (120, 40, 40), 0.5)
    text(img, "LOT 8", w - 116, 46, 12, (120, 40, 40), 0.5)
    return age(img, rng, 0.08, (0.98, 0.95, 0.9))
