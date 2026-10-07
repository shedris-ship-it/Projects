"""Make the house's textures (docs/ART.md, step 4: materials and grime).

Every texture is drawn from code, seeded, so running this again gives the
same images. Surface textures are greyscale and seamless: the part's Color
tints them, so one wallpaper serves the sage, rose and blue rooms. Each comes
with a normal map (OpenGL convention, green up, as Roblox expects). Grime
decals are colour with alpha.

Run from the repository root with Python 3 and numpy + Pillow:

    python tools/textures.py

Images are written to assets/textures/. Uploaded asset ids are recorded in
src/shared/Assets.luau.
"""

import math
import os

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "textures")
SIZE = 1024


# Noise ----------------------------------------------------------------------


def rng_for(name):
    return np.random.default_rng(abs(hash_text(name)) % (2**32))


def hash_text(text):
    h = 5381
    for ch in text:
        h = (h * 33 + ord(ch)) % (2**32)
    return h


def fbm(rng, size, beta, stretch=(1.0, 1.0), low=0.0):
    """Seamless 1/f^beta noise via the FFT, zero mean, unit spread.

    stretch makes features that many times longer along x and y (16, 1 gives
    streaks running along x). low removes features larger than 1/low of the
    tile."""
    white = rng.standard_normal((size, size))
    fy = np.fft.fftfreq(size)[:, None] * stretch[1]
    fx = np.fft.fftfreq(size)[None, :] * stretch[0]
    f = np.sqrt(fx * fx + fy * fy)
    f[0, 0] = 1.0
    filt = 1.0 / f**beta
    filt[0, 0] = 0.0
    if low > 0:
        filt *= 1.0 - np.exp(-((f * size / low) ** 2))
    out = np.real(np.fft.ifft2(np.fft.fft2(white) * filt))
    out -= out.mean()
    return out / (out.std() + 1e-9)


def blur(a, radius):
    """Seamless gaussian blur (wraps at the edges)."""
    size = a.shape[0]
    fy = np.fft.fftfreq(size)[:, None]
    fx = np.fft.fftfreq(size)[None, :]
    g = np.exp(-2 * (math.pi * radius) ** 2 * (fx * fx + fy * fy))
    return np.real(np.fft.ifft2(np.fft.fft2(a) * g))


def normal_map(height, strength):
    """Tangent-space normal map from a height field, wrapping at the edges."""
    dx = (np.roll(height, -1, axis=1) - np.roll(height, 1, axis=1)) * 0.5
    drow = (np.roll(height, -1, axis=0) - np.roll(height, 1, axis=0)) * 0.5
    nx = -dx * strength
    ny = drow * strength  # rows run down the image; green points up
    nz = np.ones_like(height)
    length = np.sqrt(nx * nx + ny * ny + nz * nz)
    rgb = np.stack([nx / length, ny / length, nz / length], axis=-1) * 0.5 + 0.5
    return Image.fromarray((np.clip(rgb, 0, 1) * 255 + 0.5).astype(np.uint8), "RGB")


def grey(a):
    return Image.fromarray((np.clip(a, 0, 1) * 255 + 0.5).astype(np.uint8), "L").convert("RGB")


def save(img, name):
    """Colour maps as high-quality JPEG; normal maps at half size as PNG (they
    carry no fine colour, and halving keeps the repository small); decals with
    alpha as PNG."""
    os.makedirs(OUT, exist_ok=True)
    if name.endswith("_normal"):
        img = img.resize((img.width // 2, img.height // 2), Image.LANCZOS)
        path = os.path.join(OUT, name + ".png")
        img.save(path, optimize=True)
    elif img.mode == "RGBA":
        path = os.path.join(OUT, name + ".png")
        img.save(path, optimize=True)
    else:
        path = os.path.join(OUT, name + ".jpg")
        img.save(path, quality=92, subsampling=0)
    print("wrote", os.path.relpath(path))


# Drawing that wraps around the tile edges -------------------------------------


class Canvas:
    """A supersampled greyscale canvas where shapes wrap across the edges."""

    def __init__(self, size, value, scale=2):
        self.size = size
        self.scale = scale
        self.img = Image.new("L", (size * scale, size * scale), int(value * 255))
        self.draw = ImageDraw.Draw(self.img)

    def _offsets(self):
        s = self.size * self.scale
        return [(ox, oy) for ox in (-s, 0, s) for oy in (-s, 0, s)]

    def polygon(self, points, value):
        k = self.scale
        for ox, oy in self._offsets():
            self.draw.polygon([(x * k + ox, y * k + oy) for x, y in points], fill=int(value * 255))

    def line(self, points, value, width):
        k = self.scale
        for ox, oy in self._offsets():
            self.draw.line(
                [(x * k + ox, y * k + oy) for x, y in points], fill=int(value * 255), width=max(1, int(width * k))
            )

    def ellipse(self, cx, cy, rx, ry, angle, value, steps=24):
        pts = []
        ca, sa = math.cos(angle), math.sin(angle)
        for i in range(steps):
            t = 2 * math.pi * i / steps
            x, y = rx * math.cos(t), ry * math.sin(t)
            pts.append((cx + x * ca - y * sa, cy + x * sa + y * ca))
        self.polygon(pts, value)

    def array(self):
        small = self.img.resize((self.size, self.size), Image.LANCZOS)
        return np.asarray(small, dtype=np.float64) / 255.0


# Surfaces ---------------------------------------------------------------------


def paper(rng, size, base):
    """Printed paper: faint fibre and slightly uneven ink."""
    return base + 0.012 * fbm(rng, size, 0.4) + 0.018 * fbm(rng, size, 1.8)


def wallpaper_sprig():
    """1980s wallpaper: small flower sprigs in a half-drop between pinstripes."""
    rng = rng_for("wallpaper_sprig")
    c = Canvas(SIZE, 0.0)
    ink = Canvas(SIZE, 0.0)  # how much ink lies where: 0 none, 1 full
    unit = SIZE // 4
    k = 1.6  # motif size
    for col in range(4):
        x = col * unit
        # Twin pinstripes.
        ink.line([(x + 2, 0), (x + 2, SIZE)], 0.45, 2.5)
        ink.line([(x + 9, 0), (x + 9, SIZE)], 0.45, 2.5)
        for row in range(4):
            cx = x + unit / 2
            cy = row * unit + (unit / 2 if col % 2 == 0 else unit)
            flip = -1 if (row + col) % 2 else 1
            # Stem.
            stem = [(cx + flip * 6 * k * math.sin(t * 2.2), cy + (34 - t * 62) * k) for t in np.linspace(0, 1, 16)]
            ink.line(stem, 0.75, 3 * k)
            # Two leaves along the stem.
            ink.ellipse(cx - 12 * k * flip, cy + 16 * k, 13 * k, 5 * k, -0.6 * flip, 0.7)
            ink.ellipse(cx + 11 * k * flip, cy + 2 * k, 11 * k, 4.5 * k, 0.7 * flip, 0.7)
            # The flower: five petals around a centre.
            fx, fy = stem[-1]
            for p in range(5):
                a = p * 2 * math.pi / 5 + 0.3 * flip
                ink.ellipse(fx + 9 * k * math.cos(a), fy + 9 * k * math.sin(a), 8 * k, 5 * k, a, 0.85)
            ink.ellipse(fx, fy, 4 * k, 4 * k, 0, 1.0)
            # Small buds off to the sides.
            ink.ellipse(cx + 20 * k * flip, cy - 18 * k, 3.5 * k, 3.5 * k, 0, 0.8)
            ink.ellipse(cx - 18 * k * flip, cy - 8 * k, 2.8 * k, 2.8 * k, 0, 0.8)
    coverage = ink.array()
    rng2 = rng_for("wallpaper_sprig_ink")
    ink_density = 0.24 * (1 + 0.15 * fbm(rng2, SIZE, 1.2))  # uneven print
    base = paper(rng, SIZE, 0.93)
    colour = base - coverage * ink_density
    # A light emboss: ink sits a hair proud of the paper.
    height = blur(coverage, 1.0) * 0.6 + 0.05 * fbm(rng, SIZE, 0.6)
    save(grey(colour), "wallpaper_sprig")
    save(normal_map(height, 2.0), "wallpaper_sprig_normal")
    del c


def wallpaper_stripe():
    """Regency stripes: a broad band with fine dots, flanked by thin lines."""
    rng = rng_for("wallpaper_stripe")
    ink = Canvas(SIZE, 0.0)
    unit = SIZE // 4
    for col in range(4):
        x = col * unit
        ink.polygon([(x + 70, 0), (x + 186, 0), (x + 186, SIZE), (x + 70, SIZE)], 0.32)
        for lx in (x + 56, x + 62, x + 194, x + 200):
            ink.line([(lx, 0), (lx, SIZE)], 0.55, 2)
        # Fine dots inside the band, in a diamond grid.
        for row in range(32):
            for k in range(4):
                dx = x + 84 + k * 29 + (14 if row % 2 else 0)
                if dx < x + 180:
                    ink.ellipse(dx, row * 32 + 8, 2.4, 2.4, 0, 0.55, steps=10)
    coverage = ink.array()
    ink_density = 0.22 * (1 + 0.12 * fbm(rng, SIZE, 1.2))
    colour = paper(rng, SIZE, 0.93) - coverage * ink_density
    height = blur(coverage, 1.0) * 0.4 + 0.05 * fbm(rng, SIZE, 0.6)
    save(grey(colour), "wallpaper_stripe")
    save(normal_map(height, 2.0), "wallpaper_stripe_normal")


def plaster():
    """Old painted plaster: soft blotches and faint trowel swirls."""
    rng = rng_for("plaster")
    blotch = fbm(rng, SIZE, 1.9)
    mid = fbm(rng, SIZE, 1.2)
    fine = fbm(rng, SIZE, 0.5)
    colour = 0.9 + 0.03 * blotch + 0.015 * mid + 0.008 * fine
    height = 0.5 * mid + 0.25 * fine + 0.6 * fbm(rng, SIZE, 1.5, stretch=(3.0, 1.0))
    save(grey(colour), "plaster")
    save(normal_map(height, 0.9), "plaster_normal")


def popcorn():
    """A popcorn ceiling: clustered lumps."""
    rng = rng_for("popcorn")
    lumps = blur(np.maximum(fbm(rng, SIZE, 0.2), 0.6) - 0.6, 1.4)
    lumps /= lumps.max()
    colour = 0.88 + 0.06 * lumps + 0.02 * fbm(rng, SIZE, 1.6)
    height = lumps + 0.15 * fbm(rng, SIZE, 0.8)
    save(grey(colour), "popcorn")
    save(normal_map(height, 6.0), "popcorn_normal")


def wood_grain(rng, size, along_x):
    stretch = (16.0, 1.0) if along_x else (1.0, 16.0)
    grain = fbm(rng, size, 1.1, stretch=stretch)
    fine = fbm(rng, size, 0.5, stretch=stretch)
    return grain, fine


def planks(name, along_x, count, joints, depth_value, normal_strength, base):
    """Boards with grain, gaps between them and staggered end joints."""
    rng = rng_for(name)
    grain, fine = wood_grain(rng, SIZE, along_x)
    width = SIZE // count
    coord = np.arange(SIZE)
    across = coord[:, None] if along_x else coord[None, :]
    along = coord[None, :] if along_x else coord[:, None]
    board = (across // width) % count
    within = across % width
    tone = rng.uniform(-0.07, 0.07, count)[board]
    # Growth rings show as gentle bands across each board.
    rings = 0.025 * np.sin((within + 6 * grain) * (2 * math.pi / rng.uniform(18, 30)))
    colour = base + tone + 0.05 * grain + 0.02 * fine + rings
    gap = np.zeros((SIZE, SIZE))
    edge = np.minimum(within, width - 1 - within)
    gap += np.clip(1.6 - edge, 0, 1)
    if joints:
        for b in range(count):
            for j in range(joints):
                pos = int(rng.uniform(0, SIZE))
                d = np.abs(((along - pos + SIZE // 2) % SIZE) - SIZE // 2)
                mask = (board == b) & (d < 1.6)
                gap = np.maximum(gap, mask * np.clip(1.6 - d, 0, 1))
    colour = colour * (1 - gap * (1 - depth_value))
    # Worn paths: slightly lighter, smoother patches.
    colour += 0.03 * np.clip(fbm(rng, SIZE, 2.2), 0, None)
    height = 0.3 * grain + 0.15 * fine - 2.0 * blur(gap, 0.8)
    return colour, height


def wood_floor():
    colour, height = planks("wood_floor", True, 8, 1, 0.35, 2.5, 0.84)
    save(grey(colour), "wood_floor")
    save(normal_map(height, 2.5), "wood_floor_normal")


def wood_panel():
    colour, height = planks("wood_panel", False, 8, 0, 0.3, 3.0, 0.84)
    save(grey(colour), "wood_panel")
    save(normal_map(height, 3.0), "wood_panel_normal")


def carpet():
    """Low-pile carpet: fibre speckle, faint wear and a few old stains."""
    rng = rng_for("carpet")
    fibre = fbm(rng, SIZE, 0.05)
    tuft = fbm(rng, SIZE, 0.7)
    colour = 0.86 + 0.045 * fibre + 0.03 * tuft + 0.025 * fbm(rng, SIZE, 2.0)
    stains = np.zeros((SIZE, SIZE))
    yy, xx = np.mgrid[0:SIZE, 0:SIZE]
    for _ in range(5):
        cx, cy = rng.uniform(0, SIZE, 2)
        r = rng.uniform(25, 70)
        dx = (xx - cx + SIZE / 2) % SIZE - SIZE / 2
        dy = (yy - cy + SIZE / 2) % SIZE - SIZE / 2
        stains += np.exp(-(dx * dx + dy * dy) / (2 * r * r)) * rng.uniform(0.04, 0.08)
    colour -= stains * (1 + 0.5 * fbm(rng, SIZE, 1.0))
    height = 0.7 * fibre + 0.5 * tuft
    save(grey(colour), "carpet")
    save(normal_map(height, 2.2), "carpet_normal")


def linoleum():
    """Checkerboard linoleum, worn at the joints and scuffed."""
    rng = rng_for("linoleum")
    n = 8
    cell = SIZE // n
    yy, xx = np.mgrid[0:SIZE, 0:SIZE]
    checker = ((xx // cell + yy // cell) % 2).astype(np.float64)
    colour = np.where(checker > 0, 0.93, 0.34)
    colour += 0.015 * fbm(rng, SIZE, 0.6) + 0.02 * fbm(rng, SIZE, 1.8)
    ex = np.minimum(xx % cell, cell - 1 - xx % cell)
    ey = np.minimum(yy % cell, cell - 1 - yy % cell)
    seam = np.clip(1.5 - np.minimum(ex, ey), 0, 1)
    colour = colour * (1 - 0.25 * seam) + 0.1 * seam * (checker < 1)
    scuff = Canvas(SIZE, 0.0)
    for _ in range(40):
        x, y = rng.uniform(0, SIZE, 2)
        a = rng.uniform(-0.4, 0.4)
        length = rng.uniform(15, 60)
        scuff.line([(x, y), (x + length * math.cos(a), y + length * math.sin(a))], rng.uniform(0.3, 0.7), 2)
    colour -= blur(scuff.array(), 1.2) * 0.12 * (colour > 0.6)
    height = -blur(seam, 0.8) + 0.1 * fbm(rng, SIZE, 1.0)
    save(grey(colour), "linoleum")
    save(normal_map(height, 2.0), "linoleum_normal")


def hex_tile():
    """Small white hexagonal tiles with dirty grout."""
    rng = rng_for("hex_tile")
    cols, rows = 16, 18  # pitch 64 x 56.9 px, close to a true hexagon and seamless
    w, h = SIZE / cols, SIZE / rows
    centres = []
    for r in range(rows):
        for q in range(cols):
            centres.append((q * w + (w / 2 if r % 2 else 0), r * h))
    centres = np.array(centres)
    yy, xx = np.mgrid[0:SIZE, 0:SIZE].astype(np.float64)
    best = np.full((SIZE, SIZE), 1e9)
    second = np.full((SIZE, SIZE), 1e9)
    owner = np.zeros((SIZE, SIZE), dtype=np.int64)
    for i, (cx, cy) in enumerate(centres):
        dx = (xx - cx + SIZE / 2) % SIZE - SIZE / 2
        dy = (yy - cy + SIZE / 2) % SIZE - SIZE / 2
        d = np.sqrt(dx * dx + dy * dy)
        closer = d < best
        second = np.where(closer, best, np.minimum(second, d))
        owner = np.where(closer, i, owner)
        best = np.where(closer, d, best)
    edge = second - best  # zero on the boundary between two tiles
    grout = np.clip(1 - (edge - 2.5) / 2.0, 0, 1)
    tone = rng.uniform(-0.03, 0.03, len(centres))[owner]
    colour = 0.92 + tone + 0.01 * fbm(rng, SIZE, 0.8)
    grout_colour = 0.55 + 0.06 * fbm(rng, SIZE, 1.5)
    colour = colour * (1 - grout) + grout_colour * grout
    dome = np.clip(edge / 10.0, 0, 1)
    height = dome - grout * 0.6
    save(grey(colour), "hex_tile")
    save(normal_map(height, 3.5), "hex_tile_normal")


def concrete():
    """Stained concrete: aggregate speckle, pits, oil and water marks."""
    rng = rng_for("concrete")
    big = fbm(rng, SIZE, 2.0)
    mid = fbm(rng, SIZE, 1.1)
    speck = fbm(rng, SIZE, 0.0)
    colour = 0.84 + 0.04 * big + 0.025 * mid + 0.02 * speck
    pits = (fbm(rng, SIZE, 0.3) > 2.6).astype(np.float64)
    pits = blur(pits, 0.7)
    colour -= 0.25 * pits
    stains = np.clip(fbm(rng, SIZE, 2.4), 0.6, None) - 0.6
    colour -= 0.12 * stains
    height = 0.3 * mid + 0.2 * speck - 1.2 * pits
    save(grey(colour), "concrete")
    save(normal_map(height, 1.5), "concrete_normal")


def roughness():
    """Tiny uniform roughness maps: matte (paper, plaster, carpet) and satin."""
    for name, value in (("rough_matte", 0.95), ("rough_satin", 0.6)):
        os.makedirs(OUT, exist_ok=True)
        Image.new("RGB", (8, 8), (int(value * 255),) * 3).save(os.path.join(OUT, name + ".png"))
        print("wrote", name)


# Grime decals ----------------------------------------------------------------


def rgba(colour, alpha):
    a = np.clip(alpha, 0, 1)
    img = np.zeros((alpha.shape[0], alpha.shape[1], 4))
    img[..., 0] = colour[0] / 255
    img[..., 1] = colour[1] / 255
    img[..., 2] = colour[2] / 255
    img[..., 3] = a
    return Image.fromarray((img * 255 + 0.5).astype(np.uint8), "RGBA")


def grime_water_stain():
    """A ceiling or wall water stain: a pale centre and brown tide lines."""
    n = 512
    rng = rng_for("water_stain")
    yy, xx = np.mgrid[0:n, 0:n].astype(np.float64)
    dx, dy = (xx - n / 2) / (n / 2), (yy - n / 2) / (n / 2)
    r = np.sqrt(dx * dx + dy * dy)
    theta = np.arctan2(dy, dx)
    wobble = 0.1 * fbm(rng, n, 2.6)
    edge = 0.78 + 0.1 * np.sin(3 * theta + 1.3) + 0.06 * np.sin(5 * theta) + wobble
    inside = np.clip((edge - r) * 12, 0, 1)
    tide = np.exp(-(((r - edge) / 0.025) ** 2)) + 0.6 * np.exp(-(((r - edge * 0.72) / 0.02) ** 2))
    alpha = 0.16 * inside * (1 + 0.4 * fbm(rng, n, 1.0)) + 0.55 * tide * (r < edge + 0.05)
    alpha *= np.clip((1.0 - r) * 6, 0, 1)
    save(rgba((96, 72, 40), alpha), "grime_water_stain")


def grime_rust_streak():
    """Rust running down a wall from a point near the top."""
    n = 512
    rng = rng_for("rust_streak")
    yy, xx = np.mgrid[0:n, 0:n].astype(np.float64)
    streaks = np.clip(fbm(rng, n, 1.2, stretch=(1.0, 25.0)), 0, None)
    across = np.exp(-(((xx - n / 2) / (n * 0.16)) ** 2))
    down = np.clip(1 - yy / n, 0, 1) ** 1.3 * np.clip(yy / (n * 0.05), 0, 1)
    alpha = 0.55 * streaks * across * down
    save(rgba((110, 56, 28), alpha), "grime_rust_streak")


def grime_scuffs():
    """Dark scuffs low on a wall, from furniture and shoes."""
    n = 512
    rng = rng_for("scuffs")
    c = Canvas(n, 0.0)
    for _ in range(26):
        x = rng.uniform(40, n - 40)
        y = rng.uniform(n * 0.45, n * 0.9)
        length = rng.uniform(12, 70)
        a = rng.uniform(-0.25, 0.25)
        c.line([(x, y), (x + length * math.cos(a), y + length * math.sin(a))], rng.uniform(0.3, 0.9), rng.uniform(2, 6))
    alpha = blur(c.array(), 3.5) * 0.55
    yy = np.mgrid[0:n, 0:n][0]
    alpha *= np.clip(np.minimum(yy, n - yy) / 40.0, 0, 1)
    xx = np.mgrid[0:n, 0:n][1]
    alpha *= np.clip(np.minimum(xx, n - xx) / 40.0, 0, 1)
    save(rgba((38, 32, 26), alpha), "grime_scuffs")


def grime_picture_ghost():
    """Where a picture hung for years: a cleaner patch with a dusty outline."""
    n = 512
    rng = rng_for("picture_ghost")
    yy, xx = np.mgrid[0:n, 0:n].astype(np.float64)
    hx, hy = n * 0.36, n * 0.42
    dx = np.abs(xx - n / 2) - hx
    dy = np.abs(yy - n / 2) - hy
    outside = np.sqrt(np.maximum(dx, 0) ** 2 + np.maximum(dy, 0) ** 2)
    inside = np.minimum(np.maximum(dx, dy), 0)
    d = outside + inside  # signed distance to the rectangle
    clean = np.clip(-d / 12.0, 0, 1)
    line = np.exp(-((d / 5.0) ** 2))
    alpha_clean = 0.22 * clean * (1 + 0.2 * fbm(rng, n, 1.5))
    alpha_line = 0.2 * line
    # Light where it was covered, darker dust along the old frame's edge.
    light = rgba((222, 212, 190), alpha_clean)
    dark = rgba((60, 52, 42), alpha_line)
    out = Image.alpha_composite(light, dark)
    out.save(os.path.join(OUT, "grime_picture_ghost.png"), optimize=True)
    print("wrote grime_picture_ghost")


# Family photos (docs/ART.md, Hero props) -----------------------------------
# Faded 1980s snapshots of an ordinary family, painted as simple shapes (no
# real people). Each comes in three states the client swaps between as Drift
# rises: normal, blurred, and with the faces gone.

PHOTO_W, PHOTO_H = 400, 500
SKIN = (214, 176, 146)


def _figure(d, x, ground, height, shirt, hair, rng, child=False):
    """One standing figure; returns the face box for the later states."""
    head = height * (0.17 if child else 0.14)
    body_w = head * 1.9
    top = ground - height
    face = (x - head / 2, top, x + head / 2, top + head * 1.15)
    # Legs, body, arms, neck, head, hair.
    d.rectangle((x - body_w * 0.35, ground - height * 0.42, x + body_w * 0.35, ground), fill=(58, 54, 60))
    d.rounded_rectangle(
        (x - body_w / 2, top + head * 1.05, x + body_w / 2, ground - height * 0.38), radius=head * 0.35, fill=shirt
    )
    d.rectangle((x - head * 0.18, top + head * 0.95, x + head * 0.18, top + head * 1.15), fill=SKIN)
    d.ellipse(face, fill=SKIN)
    d.chord((face[0] - 2, face[1] - head * 0.12, face[2] + 2, face[1] + head * 0.7), 180, 360, fill=hair)
    return face


def _features(d, face):
    x0, y0, x1, y1 = face
    w, h = x1 - x0, y1 - y0
    for ex in (0.33, 0.67):
        d.ellipse((x0 + w * ex - w * 0.06, y0 + h * 0.45, x0 + w * ex + w * 0.06, y0 + h * 0.53), fill=(50, 36, 30))
    d.arc((x0 + w * 0.32, y0 + h * 0.55, x0 + w * 0.68, y0 + h * 0.8), 20, 160, fill=(120, 60, 50), width=2)


def _scene(kind, rng):
    img = Image.new("RGB", (PHOTO_W, PHOTO_H), (0, 0, 0))
    d = ImageDraw.Draw(img)
    faces = []
    if kind == 0:
        # The family on the front lawn, the house behind them.
        d.rectangle((0, 0, PHOTO_W, 220), fill=(150, 176, 196))
        d.rectangle((0, 220, PHOTO_W, PHOTO_H), fill=(92, 120, 70))
        d.rectangle((40, 90, 360, 300), fill=(196, 182, 150))
        d.polygon([(20, 100), (200, 30), (380, 100)], fill=(110, 70, 60))
        d.rectangle((170, 200, 230, 300), fill=(90, 60, 44))
        d.rectangle((0, 300, PHOTO_W, PHOTO_H), fill=(92, 120, 70))
        people = [(110, 300, (140, 60, 50), (60, 44, 30)), (190, 290, (60, 80, 120), (40, 30, 24))]
        kids = [(260, 170, (180, 150, 60), (90, 64, 40)), (320, 150, (200, 90, 90), (90, 64, 40))]
        for x, h, shirt, hair in people:
            faces.append(_figure(d, x, 440, h, shirt, hair, rng))
        for x, h, shirt, hair in kids:
            faces.append(_figure(d, x, 440, h, shirt, hair, rng, child=True))
    elif kind == 1:
        # A couple at the dining table, a birthday cake between them.
        d.rectangle((0, 0, PHOTO_W, PHOTO_H), fill=(140, 110, 100))
        d.rectangle((0, 0, PHOTO_W, 60), fill=(120, 92, 84))
        d.rectangle((260, 70, 360, 170), fill=(80, 70, 60))
        faces.append(_figure(d, 110, 470, 300, (120, 100, 70), (50, 36, 26), rng))
        faces.append(_figure(d, 290, 470, 290, (90, 110, 90), (110, 70, 40), rng))
        d.rectangle((0, 330, PHOTO_W, PHOTO_H), fill=(200, 196, 180))
        d.rectangle((150, 270, 250, 330), fill=(232, 220, 200))
        for cx in (170, 200, 230):
            d.rectangle((cx - 2, 245, cx + 2, 270), fill=(220, 200, 120))
            d.ellipse((cx - 4, 236, cx + 4, 248), fill=(255, 220, 140))
    else:
        # Grandmother on the sofa with a small child.
        d.rectangle((0, 0, PHOTO_W, PHOTO_H), fill=(110, 116, 98))
        d.rectangle((20, 250, 380, 420), fill=(120, 80, 60))
        d.rectangle((20, 220, 380, 280), fill=(104, 70, 52))
        faces.append(_figure(d, 160, 420, 260, (150, 140, 160), (210, 210, 205), rng))
        faces.append(_figure(d, 270, 420, 170, (200, 170, 80), (80, 60, 36), rng, child=True))
        d.rectangle((0, 420, PHOTO_W, PHOTO_H), fill=(90, 70, 56))
    return img, d, faces


def _finish(img, rng):
    """Faded colour, grain, a soft vignette and the white print border."""
    a = np.asarray(img, dtype=np.float64) / 255.0
    lum = a @ np.array([0.3, 0.59, 0.11])
    sepia = np.stack([lum * 1.07 + 0.06, lum * 0.95 + 0.04, lum * 0.78 + 0.02], axis=-1)
    a = a * 0.45 + sepia * 0.55
    a = a * 0.85 + 0.1  # lifted, faded blacks
    a += rng.normal(0, 0.025, a.shape[:2])[..., None]
    yy, xx = np.mgrid[0 : a.shape[0], 0 : a.shape[1]]
    r = np.sqrt(((xx / a.shape[1]) - 0.5) ** 2 + ((yy / a.shape[0]) - 0.5) ** 2)
    a *= (1 - 0.35 * np.clip(r - 0.3, 0, 1) * 2)[..., None]
    pic = Image.fromarray((np.clip(a, 0, 1) * 255).astype(np.uint8), "RGB")
    border = Image.new("RGB", (PHOTO_W + 40, PHOTO_H + 70), (226, 220, 204))
    border.paste(pic, (20, 20))
    return border


def photos():
    for kind in range(3):
        for state in ("normal", "blurred", "faceless"):
            rng = np.random.default_rng(1000 + kind)
            img, d, faces = _scene(kind, rng)
            if state != "faceless":
                for face in faces:
                    _features(d, face)
            if state == "blurred":
                # The faces smear first; the rest of the picture only softens.
                soft = img.filter(ImageFilter.GaussianBlur(3))
                smear = img.filter(ImageFilter.GaussianBlur(9))
                mask = Image.new("L", img.size, 0)
                md = ImageDraw.Draw(mask)
                for x0, y0, x1, y1 in faces:
                    md.ellipse((x0 - 10, y0 - 10, x1 + 10, y1 + 10), fill=255)
                img = Image.composite(smear, soft, mask.filter(ImageFilter.GaussianBlur(6)))
            elif state == "faceless":
                # Blank faces, as if rubbed out, with dark smudges over them.
                for x0, y0, x1, y1 in faces:
                    d.ellipse((x0, y0 + (y1 - y0) * 0.25, x1, y1), fill=(196, 168, 146))
                    d.ellipse((x0 + 2, y0 + (y1 - y0) * 0.35, x1 - 2, y1 - 4), fill=(150, 130, 116))
                img = img.filter(ImageFilter.GaussianBlur(1.2))
            out = _finish(img, np.random.default_rng(2000 + kind))
            path = os.path.join(OUT, "photo_%d_%s.jpg" % (kind + 1, state))
            out.save(path, quality=90)
            print("wrote", os.path.relpath(path))


def _craze(rng, n, cells, width):
    """A network of hairlines: the edges between the cells of a scatter of
    points, by true distance to the bisector between the nearest two (no
    smudges where cells meet), `width` pixels wide."""
    pts = rng.random((cells, 2)) * n
    yy, xx = np.mgrid[0:n, 0:n].astype(np.float64)
    d1 = np.full((n, n), 1e9)
    d2 = np.full((n, n), 1e9)
    i1 = np.zeros((n, n), dtype=np.int64)
    i2 = np.zeros((n, n), dtype=np.int64)
    for k, (px, py) in enumerate(pts):
        d = np.hypot(xx - px, yy - py)
        closer = d < d1
        second = (~closer) & (d < d2)
        d2 = np.where(closer, d1, np.where(second, d, d2))
        i2 = np.where(closer, i1, np.where(second, k, i2))
        d1 = np.where(closer, d, d1)
        i1 = np.where(closer, k, i1)
    sep = np.hypot(pts[i1, 0] - pts[i2, 0], pts[i1, 1] - pts[i2, 1]) + 1e-6
    edge = (d2 * d2 - d1 * d1) / (2 * sep)
    return np.exp(-((edge / width) ** 2))


def _fractures(rng, n, origin, count, reach, scale):
    """Fracture lines from an impact point: jagged runs outwards that fork,
    and broken rings round the point (a spider-web), drawn at twice the size
    and brought down so the lines stay crisp. Returns (lines, edges): the
    cracks' darkness, and a pale lip along one side of each (where the glaze
    edge catches the light)."""
    big = n * 2
    lines = Image.new("L", (big, big), 0)
    lips = Image.new("L", (big, big), 0)
    draw, lip = ImageDraw.Draw(lines), ImageDraw.Draw(lips)
    ox, oy = origin[0] * big, origin[1] * big

    def run(x, y, angle, length, width, depth):
        # Porcelain breaks in near-straight runs with sudden kinks, tapering.
        steps = int(length / (big * 0.016)) + 2
        for i in range(steps):
            if rng.random() < 0.18:
                angle += rng.choice([-1, 1]) * (0.25 + rng.random() * 0.45)
            else:
                angle += rng.normal(0, 0.05)
            step = big * 0.016 * (0.7 + rng.random() * 0.6)
            nx, ny = x + math.cos(angle) * step, y + math.sin(angle) * step
            w = max(1, int(width * scale * (1 - i / steps) ** 0.7 + 0.5))
            draw.line([(x, y), (nx, ny)], fill=255, width=w)
            lip.line([(x + 2, y + 2), (nx + 2, ny + 2)], fill=200, width=max(1, int(w * 0.6)))
            x, y = nx, ny
            if depth < 2 and rng.random() < 0.06:
                run(x, y, angle + rng.choice([-1, 1]) * (0.4 + rng.random() * 0.5), length * 0.4, width * 0.6, depth + 1)

    for i in range(count):
        a = i / count * 2 * math.pi + rng.normal(0, 0.25)
        run(ox, oy, a, big * reach * (0.6 + rng.random() * 0.6), 5 + rng.random() * 4, 0)
    # The web: broken rings round the impact.
    for ring in range(3):
        r = big * reach * (0.12 + ring * 0.11)
        a0 = rng.random() * 2 * math.pi
        segs = []
        for k in range(28):
            a = a0 + k / 28 * 2 * math.pi
            rr = r * (0.85 + rng.random() * 0.3)
            segs.append((ox + math.cos(a) * rr, oy + math.sin(a) * rr))
        for k in range(len(segs) - 1):
            if rng.random() < 0.65:
                draw.line([segs[k], segs[k + 1]], fill=230, width=int(max(1, 3 * scale)))
    lines = np.asarray(lines.resize((n, n), Image.LANCZOS), dtype=np.float64) / 255
    lips = np.asarray(lips.resize((n, n), Image.LANCZOS), dtype=np.float64) / 255
    return lines, lips


def _chips(rng, n, centres, size):
    """Where the glaze has flaked away: ragged patches (the bisque beneath),
    returned as a 0..1 mask, and their outlines."""
    big = n * 2
    patch = Image.new("L", (big, big), 0)
    draw = ImageDraw.Draw(patch)
    for cx, cy, s in centres:
        # Angular: a flake of glaze, or a piece knocked out, has straight edges.
        pts = []
        radius = big * size * s
        corners = int(6 + rng.random() * 4)
        a0 = rng.random() * 2 * math.pi
        for k in range(corners):
            a = a0 + (k + rng.random() * 0.6) / corners * 2 * math.pi
            rr = radius * (0.45 + rng.random() * 0.75)
            pts.append((cx * big + math.cos(a) * rr, cy * big + math.sin(a) * rr * 0.85))
        draw.polygon(pts, fill=255)
    m = np.asarray(patch.resize((n, n), Image.LANCZOS), dtype=np.float64) / 255
    edge = np.clip(m - blur(m, 1.5), 0, 1) * 4 + np.clip(blur(m, 2.0) - m, 0, 1) * 3
    return m, np.clip(edge, 0, 1)


def guest_masks():
    """The Guest's porcelain mask (docs/ART.md "The Guest", 2026-10-07): a
    decal on the mask's front (Lib/GuestFace), laid under the eyes, brows and
    mouth, which stay geometry. Three glazes:
      calm     ivory, faint mottling, fine crazing, grime towards the rim
      worn     (Fraying) crazing everywhere, a first fracture over the brow,
               chips, dirty tear-tracks
      broken   (Breaking; the owner: "even more cracked and fucked up") shot
               through with fractures from two blows (the brow, the jaw:
               where the mask's pieces are gone), the glaze flaked to the
               bisque, stained and filthy
    The eyes sit at x = 0.5 +- 0.19, y = 0.40 of the image."""
    n = 1024
    for level, name in ((0, "calm"), (1, "worn"), (2, "broken")):
        rng = rng_for("guest_mask_" + name)
        yy, xx = np.mgrid[0:n, 0:n].astype(np.float64)
        u, v = (xx - n / 2) / (n / 2), (yy - n / 2) / (n / 2)
        r = np.sqrt(u * u + v * v)
        # The glaze: ivory, warmer and cooler in soft patches; yellowing and
        # greying as it ages.
        mottle = blur(fbm(rng, n, 2.2), 6)
        age = (0, 8, 20)[level]
        base = np.stack(
            [224 - age * 0.6 + 6 * mottle, 216 - age * 0.9 + 5 * mottle, 200 - age * 1.4 + 2 * mottle],
            axis=-1,
        )
        # Grime towards the rim and in the eye hollows; stains when worn.
        rim = np.clip((r - 0.55) / 0.45, 0, 1) ** 1.6
        hollows = 0.0
        for ex in (-0.38, 0.38):
            hollows = hollows + np.exp(-(((u - ex) / 0.2) ** 2 + ((v + 0.2) / 0.13) ** 2))
        dirt = rim * (0.35, 0.55, 0.7)[level] + hollows * (0.18, 0.35, 0.55)[level]
        if level >= 1:
            stains = np.clip(blur(fbm(rng, n, 1.4), 12) * 0.9 - (0.35 if level == 1 else 0.05), 0, 1)
            dirt = dirt + stains * (0.25 if level == 1 else 0.45)
        dirt = np.clip(dirt * (0.8 + 0.4 * np.clip(fbm(rng, n, 1.6) * 0.5 + 0.5, 0, 1)), 0, 0.92)
        grime = np.array([86, 72, 58])
        rgb = base * (1 - dirt[..., None]) + grime * dirt[..., None]
        # Crazing: in patches at Calm, everywhere once worn, coarser when broken.
        craze = _craze(rng, n, (180, 420, 520)[level], (0.7, 0.9, 1.1)[level])
        patch = np.clip(blur(fbm(rng, n, 1.8), 18) * 0.7 + (0.05, 0.75, 1.0)[level], 0, 1)
        c = (craze * patch * (0.3, 0.6, 0.75)[level])[..., None]
        rgb = rgb * (1 - c) + np.array([66, 56, 48]) * c
        if level >= 1:
            # Flaked glaze: the grey bisque beneath, with a dark rim.
            centres = [(0.3, 0.2, 1.0), (0.18, 0.55, 0.6), (0.82, 0.3, 0.5)]
            if level == 2:
                centres += [(0.72, 0.78, 1.3), (0.5, 0.1, 0.8), (0.12, 0.33, 0.9), (0.88, 0.6, 0.7), (0.4, 0.88, 0.6)]
            chips, chipEdge = _chips(rng, n, centres, 0.035 if level == 1 else 0.055)
            bisque = np.stack([150 + 10 * mottle, 142 + 9 * mottle, 128 + 8 * mottle], axis=-1)
            grain = np.clip(fbm(rng, n, 0.6) * 0.5 + 0.5, 0, 1)[..., None]
            bisque = bisque * (0.82 + 0.18 * grain)
            rgb = rgb * (1 - chips[..., None]) + bisque * chips[..., None]
            rgb = rgb * (1 - chipEdge[..., None] * 0.8) + np.array([40, 32, 26]) * chipEdge[..., None] * 0.8
            # Fractures: from the brow (Fraying), then the jaw too (Breaking).
            blows = [((0.27, 0.23), 5 if level == 1 else 8, 0.3 if level == 1 else 0.55)]
            if level == 2:
                blows.append(((0.74, 0.76), 7, 0.45))
            for origin, count, reach in blows:
                lines, lips = _fractures(rng, n, origin, count, reach, 1.8 if level == 1 else 3.0)
                rgb = rgb * (1 - lips[..., None] * 0.35) + np.array([238, 230, 214]) * lips[..., None] * 0.35
                rgb = rgb * (1 - lines[..., None]) + np.array([24, 18, 14]) * lines[..., None]
            # Tear-tracks: dirty runs from each eye, heavier when broken.
            wander = blur(fbm(rng, n, 2.4), 14)
            fleck = np.clip(fbm(rng, n, 0.9) * 0.5 + 0.5, 0, 1)
            cols = np.arange(n)
            for ex in (-0.38, 0.38):
                top = n * 0.415
                for row in range(int(top), int(n * 0.93)):
                    t = (row - top) / (n * 0.93 - top)
                    cx = n / 2 + (ex + 0.035 * wander[row, int(n / 2 + ex * n / 2)]) * n / 2
                    width = n * ((0.007, 0.012)[level - 1] + 0.006 * (1 - t))
                    strength = min(1, (row - top) / (n * 0.03)) * (0.7, 0.9)[level - 1] * (1 - t) ** 1.1
                    a = np.exp(-(((cols - cx) / width) ** 2)) * strength * (0.6 + 0.4 * fleck[row])
                    rgb[row] = rgb[row] * (1 - a[:, None]) + np.array([52, 42, 34]) * a[:, None]
        if level == 2:
            # Where pieces are gone outright: the dark beneath, ragged.
            holes, holeEdge = _chips(
                rng, n, [(0.27, 0.22, 1.0), (0.74, 0.77, 0.9), (0.18, 0.34, 0.5), (0.36, 0.12, 0.4)], 0.07
            )
            rgb = rgb * (1 - holes[..., None]) + np.array([6, 5, 6]) * holes[..., None]
        # Opaque over the mask, fading out at the image's corners (beyond the
        # mask's own edge, where the projection stretches).
        alpha = np.clip((1.02 - r) / 0.08, 0, 1)
        img = np.concatenate([np.clip(rgb, 0, 255) / 255, alpha[..., None]], axis=-1)
        save(Image.fromarray((img * 255 + 0.5).astype(np.uint8), "RGBA"), "guest_mask_" + name)

if __name__ == "__main__":
    if os.environ.get("ONLY") == "guest":
        guest_masks()
        raise SystemExit
    wallpaper_sprig()
    wallpaper_stripe()
    plaster()
    popcorn()
    wood_floor()
    wood_panel()
    carpet()
    linoleum()
    hex_tile()
    concrete()
    roughness()
    grime_water_stain()
    grime_rust_streak()
    grime_scuffs()
    grime_picture_ghost()
    photos()
    guest_masks()
