"""Draw our own 1988 posters for the lobby mall's ad frames (LB6, immersive ads).

Each ad frame in the mall (Data/Mall `Ads`) shows one of these to a player
who can't be shown ads, and its AdGui shows it while no ad runs (its
FallbackImage), so the mall looks the same to everyone. The mall's own ads
from the year it died, faded by years in their lightboxes; the video store's
last COMING SOON; a TV off the air. None names a map or a real brand.

Drawn from code, seeded, so running this again gives the same images. Run
from the repository root with Python 3 and numpy + Pillow:

    python tools/posters.py [sheet.jpg]

Writes assets/posters/<name>.jpg (1024 x 576, 16:9, as Roblox's ads are),
and with an argument a contact sheet of all of them. The titles use the
Google fonts Roblox ships (OFL), found in the Roblox install, else Windows'.
Uploaded ids go in src/shared/Data/Posters.luau (the owner's account: ask
first).
"""

import glob
import math
import os
import sys

import numpy as np
from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageFont

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "posters")
W, H = 1024, 576


# Fonts ----------------------------------------------------------------------

FONT_DIRS = sorted(
    glob.glob(os.path.join(os.environ.get("LOCALAPPDATA", ""), "Roblox", "Versions", "*", "content", "fonts"))
) + ["C:/Windows/Fonts"]
FALLBACK = {"serif": "georgia.ttf", "serifb": "georgiab.ttf", "serifi": "georgiai.ttf", "sans": "arialbd.ttf"}


def font(name, size, kind="sans"):
    for d in FONT_DIRS:
        path = os.path.join(d, name)
        if os.path.exists(path):
            return ImageFont.truetype(path, size)
    return ImageFont.truetype(os.path.join("C:/Windows/Fonts", FALLBACK[kind]), size)


def fit(name, text, width, size, kind="sans"):
    """The font at the largest size up to `size` that sets `text` in `width`."""
    while size > 8:
        f = font(name, size, kind)
        if f.getlength(text) <= width:
            return f
        size -= 2
    return font(name, size, kind)


# Drawing helpers --------------------------------------------------------------


def rng_for(name):
    h = 5381
    for ch in name:
        h = (h * 33 + ord(ch)) % (2**32)
    return np.random.default_rng(h)


def vgrad(size, top, bottom, power=1.0):
    w, h = size
    t = (np.linspace(0, 1, h) ** power)[:, None, None]
    a = np.array(top, float)[None, None, :]
    b = np.array(bottom, float)[None, None, :]
    rows = a + (b - a) * t
    return Image.fromarray(np.repeat(rows, w, axis=1).clip(0, 255).astype(np.uint8))


def radial(size, centre, radius, inner, outer):
    w, h = size
    y, x = np.mgrid[0:h, 0:w]
    d = np.sqrt((x - centre[0]) ** 2 + (y - centre[1]) ** 2) / radius
    t = np.clip(d, 0, 1)[:, :, None]
    a = np.array(inner, float)[None, None, :]
    b = np.array(outer, float)[None, None, :]
    return Image.fromarray((a + (b - a) * t).clip(0, 255).astype(np.uint8))


def centred(draw, text, cx, y, f, fill, spacing=0):
    if spacing:
        widths = [f.getlength(c) for c in text]
        total = sum(widths) + spacing * (len(text) - 1)
        x = cx - total / 2
        for c, w in zip(text, widths):
            draw.text((x, y), c, font=f, fill=fill)
            x += w + spacing
        return
    w = f.getlength(text)
    draw.text((cx - w / 2, y), text, font=f, fill=fill)


def glow_text(img, text, cx, y, f, fill, glow, radius=10, strength=2):
    """Text with a soft light round it (a lit title)."""
    layer = Image.new("L", img.size, 0)
    d = ImageDraw.Draw(layer)
    centred(d, text, cx, y, f, 255)
    halo = layer.filter(ImageFilter.GaussianBlur(radius))
    halo = halo.point(lambda v: min(255, v * strength))
    img.paste(Image.new("RGB", img.size, glow), (0, 0), halo)
    ImageDraw.Draw(img).text((cx - f.getlength(text) / 2, y), text, font=f, fill=fill)


def shadow_text(img, text, cx, y, f, fill, shade=(0, 0, 0), off=(4, 4), blur=3):
    layer = Image.new("L", img.size, 0)
    centred(ImageDraw.Draw(layer), text, cx + off[0], y + off[1], f, 200)
    img.paste(Image.new("RGB", img.size, shade), (0, 0), layer.filter(ImageFilter.GaussianBlur(blur)))
    centred(ImageDraw.Draw(img), text, cx, y, f, fill)


def slanted(img, text, cx, y, f, fill, shear=0.22, outline=None, stroke=0):
    """Italic by shearing: a logo set leaning forward."""
    w = int(f.getlength(text) + 80)
    h = int(f.size * 1.6)
    layer = Image.new("L", (w, h), 0)
    d = ImageDraw.Draw(layer)
    d.text((40, 0), text, font=f, fill=255, stroke_width=stroke, stroke_fill=255)
    layer = layer.transform((w, h), Image.AFFINE, (1, shear, -shear * h * 0.6, 0, 1, 0), resample=Image.BICUBIC)
    x, top = int(cx - w / 2), int(y)
    if outline:
        thick = layer.filter(ImageFilter.MaxFilter(9))
        img.paste(Image.new("RGB", (w, h), outline), (x, top), thick)
    img.paste(Image.new("RGB", (w, h), fill), (x, top), layer)


def starburst(draw, cx, cy, r0, r1, points, fill, turn=0.0):
    pts = []
    for i in range(points * 2):
        a = turn + math.pi * i / points
        r = r1 if i % 2 == 0 else r0
        pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    draw.polygon(pts, fill=fill)


def age(img, r, fade=0.16, cast=(236, 226, 200), grain=7.0, specks=60, vignette=0.22):
    """Years in a lightbox: the inks faded toward the diffuser's cream (reds
    first), grain, a few specks of dust, the corners darker than the tubes."""
    a = np.asarray(img, float)
    # Reds and magentas fade first in the sun: pull red down a touch.
    a[:, :, 0] = a[:, :, 0] * (1 - fade * 0.35) + 0
    a = a * (1 - fade) + np.array(cast, float)[None, None, :] * fade
    a += r.normal(0, grain, a.shape[:2])[:, :, None]
    h, w = a.shape[:2]
    y, x = np.mgrid[0:h, 0:w]
    v = ((x - w / 2) / (w / 2)) ** 2 + ((y - h / 2) / (h / 2)) ** 2
    a *= (1 - vignette * np.clip(v / 2, 0, 1))[:, :, None]
    out = Image.fromarray(a.clip(0, 255).astype(np.uint8))
    d = ImageDraw.Draw(out)
    for _ in range(specks):
        sx, sy = r.uniform(0, w), r.uniform(0, h)
        s = r.uniform(0.6, 2.2)
        tone = int(r.uniform(30, 90))
        d.ellipse((sx - s, sy - s, sx + s, sy + s), fill=(tone, tone - 6, tone - 12))
    return out


def silhouette_house(draw, x, base, scale, fill, lit, figure=None):
    """A two-storey suburban house, gabled, its windows lit."""
    s = scale
    body = (x - 120 * s, base - 150 * s, x + 120 * s, base)
    draw.rectangle(body, fill=fill)
    draw.polygon([(x - 140 * s, base - 150 * s), (x, base - 250 * s), (x + 140 * s, base - 150 * s)], fill=fill)
    draw.rectangle((x + 60 * s, base - 260 * s, x + 84 * s, base - 190 * s), fill=fill)  # chimney
    # a porch roof
    draw.polygon(
        [(x - 150 * s, base - 62 * s), (x - 20 * s, base - 62 * s), (x - 30 * s, base - 78 * s), (x - 140 * s, base - 78 * s)],
        fill=fill,
    )
    windows = [
        (x - 90 * s, base - 130 * s),
        (x + 40 * s, base - 130 * s),
        (x - 22 * s, base - 215 * s),
        (x + 40 * s, base - 50 * s),
    ]
    for i, (wx, wy) in enumerate(windows):
        draw.rectangle((wx, wy, wx + 44 * s, wy + 50 * s), fill=lit)
        draw.line((wx + 22 * s, wy, wx + 22 * s, wy + 50 * s), fill=fill, width=max(1, int(3 * s)))
        draw.line((wx, wy + 25 * s, wx + 44 * s, wy + 25 * s), fill=fill, width=max(1, int(3 * s)))
        if figure is not None and i == figure:
            # someone standing at it, looking out
            cx = wx + 30 * s
            draw.ellipse((cx - 6 * s, wy + 8 * s, cx + 6 * s, wy + 21 * s), fill=fill)
            draw.rectangle((cx - 8 * s, wy + 20 * s, cx + 8 * s, wy + 50 * s), fill=fill)
    draw.rectangle((x - 70 * s, base - 50 * s, x - 46 * s, base), fill=lit)  # the door, lit


def pine(draw, x, base, h, fill):
    tiers = 5
    for i in range(tiers):
        top = base - h + i * h / (tiers + 1)
        half = h * (0.12 + 0.07 * i)
        draw.polygon([(x, top), (x - half, top + h / 3.2), (x + half, top + h / 3.2)], fill=fill)
    draw.rectangle((x - h * 0.03, base - h * 0.12, x + h * 0.03, base), fill=fill)


def billing(draw, cx, y, lines, f, fill):
    for i, line in enumerate(lines):
        centred(draw, line, cx, y + i * (f.size + 3), f, fill)


# The posters ------------------------------------------------------------------


def mayfields(r):
    """The department store's closing sale: the dead mall's last ad."""
    img = vgrad((W, H), (150, 26, 34), (98, 14, 22))
    d = ImageDraw.Draw(img)
    # pinstripes, a store's awning
    for x in range(0, W, 48):
        d.rectangle((x, 0, x + 18, 52), fill=(214, 196, 168))
    d.rectangle((0, 52, W, 60), fill=(60, 8, 14))
    shadow_text(img, "Mayfield's", 360, 82, font("AccanthisADFStd-Regular.otf", 112, "serifi"), (246, 236, 214))
    d = ImageDraw.Draw(img)
    centred(d, "DEPARTMENT STORE  ·  SINCE 1951", 360, 212, font("Montserrat-Bold.ttf", 22), (232, 210, 180), 2)
    big = fit("Oswald-Bold.ttf", "EVERYTHING MUST GO", 560, 120)
    shadow_text(img, "EVERYTHING MUST GO", 360, 270, big, (250, 240, 220), off=(5, 5))
    d = ImageDraw.Draw(img)
    centred(d, "STORE CLOSING  ·  ALL SALES FINAL", 360, 420, font("Oswald-Regular.ttf", 40), (240, 214, 160), 3)
    d.line((120, 482, 600, 482), fill=(232, 200, 150), width=2)
    centred(d, "Lower Level, by the Fountain", 360, 494, font("AccanthisADFStd-Regular.otf", 30, "serifi"), (226, 206, 178))
    # the starburst
    starburst(d, 860, 330, 136, 170, 18, (250, 214, 60), turn=0.1)
    starburst(d, 860, 330, 124, 152, 18, (236, 176, 30), turn=0.27)
    centred(d, "40%", 860, 232, font("Oswald-Bold.ttf", 100), (130, 16, 24))
    centred(d, "TO 70% OFF", 860, 360, font("Oswald-Bold.ttf", 40), (130, 16, 24))
    centred(d, "EVERYTHING", 860, 406, font("Montserrat-Black.ttf", 20), (120, 30, 20), 2)
    return age(img, r, fade=0.2)


def pine_hollow(r):
    """The development out past the mall: a home that grows with your family."""
    img = vgrad((W, H), (34, 40, 86), (236, 140, 72), power=1.4)
    d = ImageDraw.Draw(img)
    # the sun just down, a glow on the horizon
    glow = radial((W, H), (700, 470), 420, (255, 200, 120), (0, 0, 0))
    img = ImageChops.add(img, ImageChops.multiply(glow, Image.new("RGB", (W, H), (150, 110, 70))))
    d = ImageDraw.Draw(img)
    hill = [(0, 470)]
    for x in range(0, W + 1, 16):
        hill.append((x, 470 - 22 * math.sin(x / 170.0) - 10 * math.sin(x / 61.0)))
    hill += [(W, H), (0, H)]
    dark = (22, 20, 30)
    d.polygon(hill, fill=dark)
    for x, h in ((520, 200), (560, 150), (900, 230), (950, 170), (990, 210), (470, 130)):
        pine(d, x, 476, h, dark)
    silhouette_house(d, 730, 478, 0.92, dark, (255, 214, 120), figure=2)
    # the road up to it
    d.polygon([(560, H), (700, 480), (716, 480), (690, H)], fill=(40, 36, 44))
    # the words, on the left, in the dusk
    centred(d, "Now Building", 250, 70, font("AccanthisADFStd-Regular.otf", 34, "serifi"), (246, 226, 200))
    shadow_text(img, "PINE HOLLOW", 250, 108, font("Merriweather-Regular.ttf", 64, "serifb"), (252, 244, 226))
    d = ImageDraw.Draw(img)
    centred(d, "E S T A T E S", 250, 192, font("Montserrat-Bold.ttf", 28), (244, 214, 160))
    d.line((110, 240, 390, 240), fill=(244, 214, 160), width=2)
    centred(d, "A home that grows", 250, 258, font("AccanthisADFStd-Regular.otf", 38, "serifi"), (252, 240, 220))
    centred(d, "with your family.", 250, 302, font("AccanthisADFStd-Regular.otf", 38, "serifi"), (252, 240, 220))
    centred(d, "MODEL HOMES OPEN DAILY", 250, 370, font("Montserrat-Bold.ttf", 22), (250, 232, 200), 1)
    centred(d, "3 & 4 bedrooms from $89,900", 250, 402, font("Merriweather-Regular.ttf", 22, "serif"), (240, 220, 190))
    centred(d, "Route 9, past the old mill", 250, 520, font("Merriweather-Italic.ttf", 20, "serifi"), (200, 190, 200))
    return age(img, r, fade=0.14, cast=(230, 214, 190))


def portraits(r):
    """The portrait studio on the dead second floor."""
    img = Image.new("RGB", (W, H), (236, 228, 210))
    # the studio's mottled blue backdrop, in an oval
    n = r.normal(0, 1, (H // 8, W // 8))
    n = np.asarray(Image.fromarray(((n - n.min()) / (n.max() - n.min()) * 255).astype(np.uint8)).resize((W, H), Image.BICUBIC).filter(ImageFilter.GaussianBlur(18)), float) / 255
    back = radial((W, H), (300, 250), 420, (150, 176, 206), (40, 58, 96))
    b = np.asarray(back, float) * (0.75 + 0.5 * n[:, :, None])
    backdrop = Image.fromarray(b.clip(0, 255).astype(np.uint8))
    mask = Image.new("L", (W, H), 0)
    ImageDraw.Draw(mask).ellipse((48, 40, 552, 536), fill=255)
    img.paste(backdrop, (0, 0), mask.filter(ImageFilter.GaussianBlur(14)))
    d = ImageDraw.Draw(img)
    # the family, posed as studios posed them: the father standing behind,
    # the mother seated, two children in front; each against the backdrop's
    # light, a rim of it round their heads and shoulders
    people = (
        (250, 150, 40, 92, (44, 50, 70)),  # father, behind
        (372, 214, 36, 86, (52, 58, 80)),  # mother
        (182, 300, 30, 66, (60, 66, 90)),  # the older child
        (312, 352, 26, 58, (66, 72, 96)),  # the little one
    )
    rim = Image.new("L", (W, H), 0)
    rd = ImageDraw.Draw(rim)
    shapes = []
    for cx, cy, hr, sw, tone in people:
        head = (cx - hr, cy - hr * 1.25, cx + hr, cy + hr * 1.15)
        body = (cx - sw, cy + hr * 1.0, cx + sw, cy + hr * 1.0 + sw * 4)
        shapes.append((head, body, tone, sw))
    for head, body, tone, sw in shapes:
        rd.ellipse(head, outline=255, width=6)
        rd.rounded_rectangle(body, radius=int(sw * 0.8), outline=255, width=6)
    img.paste(Image.new("RGB", (W, H), (200, 216, 236)), (0, 0), rim.filter(ImageFilter.GaussianBlur(5)))
    d = ImageDraw.Draw(img)
    for head, body, tone, sw in shapes:
        d.rounded_rectangle(body, radius=int(sw * 0.8), fill=tone)
        d.ellipse(head, fill=tone)
        # a collar's pale V, so each reads as dressed for it
        cx = (head[0] + head[2]) / 2
        d.polygon(
            [(cx - sw * 0.28, body[1] + 4), (cx, body[1] + sw * 0.5), (cx + sw * 0.28, body[1] + 4)],
            fill=(200, 196, 190),
        )
    # the oval's edge again over anyone who reached past it
    outside = Image.eval(mask, lambda v: 255 - v).filter(ImageFilter.GaussianBlur(14))
    img.paste(Image.new("RGB", (W, H), (236, 228, 210)), (0, 0), outside)
    img = img.filter(ImageFilter.GaussianBlur(1.0))
    d = ImageDraw.Draw(img)
    # the right panel's words
    x = 790
    centred(d, "Portraits", x, 54, font("AccanthisADFStd-Regular.otf", 82, "serifi"), (60, 46, 40))
    centred(d, "by Lorraine", x, 140, font("AccanthisADFStd-Regular.otf", 46, "serifi"), (110, 70, 60))
    d.line((640, 214, 940, 214), fill=(150, 120, 100), width=2)
    centred(d, "Every family deserves", x, 232, font("Merriweather-Italic.ttf", 28, "serifi"), (70, 60, 56))
    centred(d, "to be remembered.", x, 270, font("Merriweather-Italic.ttf", 28, "serifi"), (70, 60, 56))
    centred(d, "FAMILY SITTING", x, 340, font("Oswald-Bold.ttf", 34), (60, 46, 40), 3)
    centred(d, "$19.88", x, 380, font("Oswald-Bold.ttf", 72), (150, 40, 46))
    centred(d, "8 wallets · two 5x7 · one 8x10", x, 470, font("Merriweather-Regular.ttf", 20, "serif"), (80, 70, 64))
    centred(d, "SECOND FLOOR · ABOVE THE FOUNTAIN", x, 512, font("Montserrat-Bold.ttf", 17), (90, 80, 72), 1)
    return age(img, r, fade=0.12)


def sparkle_cola(r):
    """A soft drink: home in time for dinner."""
    img = vgrad((W, H), (214, 40, 36), (150, 18, 30))
    d = ImageDraw.Draw(img)
    # 80s speed stripes across
    for i, c in enumerate(((250, 196, 40), (250, 120, 40), (250, 240, 220))):
        y0 = 452 + i * 30
        d.polygon([(0, y0 + 30), (W, y0 - 90), (W, y0 - 68), (0, y0 + 52)], fill=c)
    # the can, tilted a little
    can = Image.new("RGBA", (220, 380), (0, 0, 0, 0))
    cd = ImageDraw.Draw(can)
    body = vgrad((200, 330), (236, 236, 240), (150, 150, 160))
    shade = np.asarray(body, float)
    xs = np.linspace(-1, 1, 200)[None, :, None]
    shade = shade * (0.65 + 0.45 * (1 - xs**2)) + 40 * np.exp(-((xs + 0.45) ** 2) / 0.01)
    can.paste(Image.fromarray(shade.clip(0, 255).astype(np.uint8)), (10, 30))
    cd.rectangle((10, 120, 210, 250), fill=(200, 26, 34))
    cd.rectangle((10, 112, 210, 120), fill=(250, 196, 40))
    cd.rectangle((10, 250, 210, 258), fill=(250, 196, 40))
    small = fit("Montserrat-Black.ttf", "SPARKLE", 170, 34)
    cd.text((110 - small.getlength("SPARKLE") / 2, 146), "SPARKLE", font=small, fill=(250, 240, 220))
    cola = font("Oswald-Bold.ttf", 44)
    cd.text((110 - cola.getlength("COLA") / 2, 182), "COLA", font=cola, fill=(250, 240, 220))
    cd.ellipse((10, 14, 210, 46), fill=(196, 196, 204))
    cd.ellipse((10, 344, 210, 376), fill=(130, 130, 140))
    can = can.rotate(-12, resample=Image.BICUBIC, expand=True)
    img.paste(can, (700, 80), can)
    # condensation on it: a few bright beads
    d = ImageDraw.Draw(img)
    for _ in range(40):
        bx, by = r.uniform(740, 900), r.uniform(130, 420)
        s = r.uniform(1.5, 3.5)
        d.ellipse((bx - s, by - s, bx + s, by + s), fill=(255, 250, 250))
    slanted(img, "SPARKLE", 330, 60, font("Montserrat-Black.ttf", 118), (250, 244, 230), outline=(110, 10, 20))
    slanted(img, "COLA", 330, 196, font("Montserrat-Black.ttf", 100), (250, 200, 50), outline=(110, 10, 20))
    d = ImageDraw.Draw(img)
    centred(d, "Home in time for dinner.", 330, 336, font("Merriweather-Italic.ttf", 40, "serifi"), (252, 240, 220))
    centred(d, "ICE COLD AT THE FOOD COURT", 330, 394, font("Montserrat-Bold.ttf", 20), (250, 214, 160), 2)
    return age(img, r, fade=0.18)


def mask_face(size, r, crack=True):
    """A pale porcelain mask in the dark: a still face with nothing behind its eyes."""
    w, h = size
    img = Image.new("RGB", (w, h), (0, 0, 0))
    y, x = np.mgrid[0:h, 0:w]
    cx, cy = w / 2, h / 2
    rx, ry = w * 0.36, h * 0.46
    e = ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2
    inside = e < 1
    # lit from above and the left
    light = np.clip(1.15 - 0.55 * ((x - cx * 0.8) / rx) ** 2 - 0.5 * ((y - cy * 0.7) / ry) ** 2, 0.15, 1)
    shade = (np.array([236, 228, 214])[None, None, :] * light[:, :, None]) * inside[:, :, None]
    img = Image.fromarray(shade.clip(0, 255).astype(np.uint8))
    d = ImageDraw.Draw(img)
    for ex in (cx - rx * 0.42, cx + rx * 0.42):
        d.ellipse((ex - rx * 0.2, cy - ry * 0.2, ex + rx * 0.2, cy + ry * 0.02), fill=(4, 4, 6))
    # brows, a painted line each, and the small closed mouth
    d.arc((cx - rx * 0.66, cy - ry * 0.42, cx - rx * 0.18, cy - ry * 0.1), 200, 330, fill=(90, 80, 74), width=3)
    d.arc((cx + rx * 0.18, cy - ry * 0.42, cx + rx * 0.66, cy - ry * 0.1), 210, 340, fill=(90, 80, 74), width=3)
    d.line((cx - rx * 0.18, cy + ry * 0.45, cx + rx * 0.18, cy + ry * 0.45), fill=(120, 60, 60), width=4)
    if crack:
        px, py = cx + rx * 0.3, cy - ry * 0.95
        for _ in range(9):
            nx, ny = px + r.uniform(-14, 10), py + r.uniform(14, 28)
            d.line((px, py, nx, ny), fill=(40, 34, 32), width=2)
            px, py = nx, ny
    return img.filter(ImageFilter.GaussianBlur(0.8))


def dont_look_away(r):
    """COMING SOON on videocassette: a horror picture."""
    img = Image.new("RGB", (W, H), (6, 6, 8))
    face = mask_face((300, 400), r)
    halo = radial((W, H), (300, 290), 300, (60, 54, 70), (0, 0, 0))
    img = ImageChops.add(img, halo)
    img.paste(face, (150, 90), Image.fromarray((np.asarray(face).max(axis=2) > 6).astype(np.uint8) * 255))
    d = ImageDraw.Draw(img)
    # a hall behind him going into the dark
    for i in range(8):
        a = 40 + i * 6
        d.line((600, 120 + i * 50, 1000, 40 + i * 70), fill=(a // 3, a // 3, a // 2), width=1)
    title = fit("Oswald-Bold.ttf", "DON'T LOOK AWAY", 520, 120)
    glow_text(img, "DON'T", 740, 70, font("Oswald-Bold.ttf", 120), (232, 30, 30), (120, 0, 0), radius=12)
    glow_text(img, "LOOK AWAY", 740, 200, title, (232, 30, 30), (120, 0, 0), radius=12)
    d = ImageDraw.Draw(img)
    centred(d, "As long as you watch him,", 740, 352, font("Merriweather-Italic.ttf", 28, "serifi"), (210, 206, 200))
    centred(d, "he can't move.", 740, 390, font("Merriweather-Italic.ttf", 28, "serifi"), (210, 206, 200))
    billing(
        d,
        740,
        452,
        [
            "NIGHTFALL PICTURES PRESENTS A HOLLOWAY FILM",
            "MUSIC BY DALE ORMSBY  ·  WRITTEN AND DIRECTED BY JUNE HOLLOWAY",
        ],
        font("Oswald-Regular.ttf", 15),
        (150, 146, 140),
    )
    banner = font("Oswald-Bold.ttf", 24)
    half = (banner.getlength("COMING SOON ON VIDEOCASSETTE") + 27) / 2 + 22
    d.rectangle((740 - half, 510, 740 + half, 550), fill=(232, 30, 30))
    centred(d, "COMING SOON ON VIDEOCASSETTE", 740, 515, banner, (250, 240, 230), 1)
    return age(img, r, fade=0.08, cast=(210, 200, 190), grain=8, specks=90, vignette=0.3)


def suppertime(r):
    """COMING SOON on videocassette: the family dinner, and the one at its head."""
    img = Image.new("RGB", (W, H), (10, 6, 4))
    candle = radial((W, H), (512, 360), 460, (150, 80, 30), (0, 0, 0))
    img = ImageChops.add(img, candle)
    d = ImageDraw.Draw(img)
    # the table in perspective, its cloth catching the light
    d.polygon([(250, 560), (774, 560), (604, 390), (420, 390)], fill=(214, 196, 168))
    d.polygon([(250, 560), (774, 560), (774, 576), (250, 576)], fill=(120, 100, 80))
    # chairs down both sides, empty
    for i in range(3):
        t = i / 3.0
        y = 530 - t * 130
        s = 1 - t * 0.5
        for side in (-1, 1):
            x = 512 + side * (270 - t * 150)
            d.rectangle((x - 18 * s, y - 110 * s, x + 18 * s, y), fill=(40, 22, 14))
    # the one at the head of the table, in a high-backed chair
    d.rectangle((474, 262, 550, 396), fill=(30, 16, 10))
    d.ellipse((494, 290, 530, 330), fill=(236, 226, 210))  # the pale face
    d.ellipse((502, 304, 510, 312), fill=(0, 0, 0))
    d.ellipse((514, 304, 522, 312), fill=(0, 0, 0))
    d.rectangle((486, 330, 538, 396), fill=(14, 8, 6))
    # candles and their flames
    for cx in (436, 588):
        d.rectangle((cx - 5, 392, cx + 5, 436), fill=(240, 230, 210))
        d.ellipse((cx - 6, 372, cx + 6, 394), fill=(255, 220, 120))
    flames = Image.new("L", (W, H), 0)
    fd = ImageDraw.Draw(flames)
    for cx in (436, 588):
        fd.ellipse((cx - 30, 352, cx + 30, 412), fill=200)
    img.paste(Image.new("RGB", (W, H), (255, 190, 90)), (0, 0), flames.filter(ImageFilter.GaussianBlur(22)))
    d = ImageDraw.Draw(img)
    glow_text(img, "SUPPERTIME", 512, 36, fit("Merriweather-Regular.ttf", "SUPPERTIME", 760, 120, "serifb"), (246, 236, 214), (140, 60, 10), radius=14)
    d = ImageDraw.Draw(img)
    centred(d, "Everyone's home for dinner.", 512, 170, font("Merriweather-Italic.ttf", 28, "serifi"), (230, 200, 160))
    centred(d, "Even him.", 512, 206, font("Merriweather-Italic.ttf", 28, "serifi"), (230, 120, 90))
    billing(d, 110, 506, ["A BLACKWOOD FEATURE", "IN COLOR"], font("Oswald-Regular.ttf", 17), (170, 150, 120))
    d.rectangle((830, 512, 1008, 560), fill=(200, 140, 40))
    centred(d, "COMING SOON", 919, 512, font("Oswald-Bold.ttf", 22), (30, 16, 8), 1)
    centred(d, "ON VIDEOCASSETTE", 919, 536, font("Oswald-Bold.ttf", 16), (30, 16, 8), 1)
    return age(img, r, fade=0.08, cast=(220, 200, 170), grain=8, specks=90, vignette=0.28)


def stand_by(r):
    """A TV off the air: colour bars and the card over them."""
    img = Image.new("RGB", (W, H), (16, 16, 16))
    d = ImageDraw.Draw(img)
    bars = [(192, 192, 192), (192, 192, 0), (0, 192, 192), (0, 192, 0), (192, 0, 192), (192, 0, 0), (0, 0, 192)]
    strip = [(0, 0, 192), (16, 16, 16), (192, 0, 192), (16, 16, 16), (0, 192, 192), (16, 16, 16), (192, 192, 192)]
    foot = [(0, 33, 76), (235, 235, 235), (50, 0, 106), (16, 16, 16), (16, 16, 16)]
    bw = W / 7
    for i, c in enumerate(bars):
        d.rectangle((i * bw, 0, (i + 1) * bw, H * 0.67), fill=c)
    for i, c in enumerate(strip):
        d.rectangle((i * bw, H * 0.67, (i + 1) * bw, H * 0.75), fill=c)
    fw = W / 5
    for i, c in enumerate(foot):
        d.rectangle((i * fw, H * 0.75, (i + 1) * fw, H), fill=c)
    d.rectangle((W * 0.19, H * 0.24, W * 0.81, H * 0.44), fill=(12, 12, 14))
    centred(d, "PLEASE STAND BY", W / 2, H * 0.265, fit("Oswald-Bold.ttf", "PLEASE STAND BY", W * 0.56, 84), (236, 236, 236), 4)
    # a CRT's scan lines and its glass, a little bowed and dim at the edges
    a = np.asarray(img, float)
    a[::3, :, :] *= 0.82
    a += r.normal(0, 5, a.shape[:2])[:, :, None]
    h, w = a.shape[:2]
    y, x = np.mgrid[0:h, 0:w]
    v = ((x - w / 2) / (w / 2)) ** 4 + ((y - h / 2) / (h / 2)) ** 4
    a *= (1 - 0.35 * np.clip(v, 0, 1))[:, :, None]
    return Image.fromarray(a.clip(0, 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(0.6))


POSTERS = {
    "mayfields": mayfields,
    "pine_hollow": pine_hollow,
    "portraits": portraits,
    "sparkle_cola": sparkle_cola,
    "dont_look_away": dont_look_away,
    "suppertime": suppertime,
    "stand_by": stand_by,
}


def main():
    os.makedirs(OUT, exist_ok=True)
    made = []
    for name, draw in POSTERS.items():
        img = draw(rng_for(name))
        assert img.size == (W, H), name
        path = os.path.join(OUT, name + ".jpg")
        img.save(path, quality=90)
        made.append((name, img))
        print("wrote", path)
    if len(sys.argv) > 1:
        # A contact sheet, two across, for the report.
        tw, th, pad = 480, 270, 24
        rows = math.ceil(len(made) / 2)
        sheet = Image.new("RGB", (pad + 2 * (tw + pad), pad + rows * (th + pad + 28)), (24, 22, 20))
        sd = ImageDraw.Draw(sheet)
        label = font("Montserrat-Bold.ttf", 16)
        for i, (name, img) in enumerate(made):
            x = pad + (i % 2) * (tw + pad)
            y = pad + (i // 2) * (th + pad + 28)
            sheet.paste(img.resize((tw, th), Image.LANCZOS), (x, y))
            sd.text((x, y + th + 4), name + ".jpg", font=label, fill=(220, 210, 190))
        os.makedirs(os.path.dirname(os.path.abspath(sys.argv[1])), exist_ok=True)
        sheet.save(sys.argv[1], quality=88)
        print("wrote", sys.argv[1])


if __name__ == "__main__":
    main()
