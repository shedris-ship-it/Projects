"""Draw the interface's paper (V7, the diegetic 1988 interface; docs/ART.md).

Everything in the interface is a thing from 1988: a torn slip for the
objective, sheets of typing paper for notes and settings, a manila case
folder for the lobby and the dossier, graph paper for the map, a lined
notebook for the journal, a strip of yellowed tape to hold a slip down, a
soft shadow to lift paper off the screen, and a CRT's scanlines. Each is
drawn here from code, seeded, so running it again gives the same images.

Run from the repository root with Python 3 and numpy + Pillow:

    python tools/paper.py

Writes assets/paper/<name>.png. Uploaded ids go in src/shared/Assets.luau
(Assets.Paper). The interface (Lib/Ui, Ui.paper) stretches each paper whole:
nine-sliced, Roblox drew the middle without the edges' yellowing and a seam
showed. Only the shadow is sliced (it's even in its middle).
"""

import math
import os

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "paper")


def rng(seed):
    return np.random.default_rng(seed)


def fbm(r, h, w, beta=1.8, low=0.0):
    """Smooth noise (1/f^beta via the FFT), zero mean, unit spread."""
    fy = np.fft.fftfreq(h)[:, None]
    fx = np.fft.fftfreq(w)[None, :]
    f = np.sqrt(fx * fx + fy * fy)
    f[0, 0] = 1.0
    amp = 1.0 / f ** (beta / 2.0)
    amp[0, 0] = 0.0
    if low > 0:
        amp *= f > low
    phase = r.uniform(0, 2 * math.pi, (h, w))
    spec = amp * np.exp(1j * phase)
    a = np.real(np.fft.ifft2(spec))
    a -= a.mean()
    return a / (a.std() + 1e-9)


def fibres(r, h, w, count, length, alpha):
    """Fine fibres laid in the paper: short faint strokes."""
    img = Image.new("L", (w, h), 0)
    d = ImageDraw.Draw(img)
    for _ in range(count):
        x, y = r.uniform(0, w), r.uniform(0, h)
        a = r.uniform(0, math.pi)
        n = r.uniform(0.4, 1.0) * length
        pts = []
        for k in range(6):
            t = k / 5
            pts.append((x + math.cos(a) * n * t + r.normal(0, 1.2), y + math.sin(a) * n * t + r.normal(0, 1.2)))
        d.line(pts, fill=int(255 * alpha * r.uniform(0.5, 1.0)), width=1)
    return np.asarray(img, dtype=np.float64) / 255.0


def base_paper(r, h, w, colour, mottle=0.035, fibre=0.25):
    """Aged paper's colour: a soft mottle, fibres, a few foxing spots."""
    c = np.ones((h, w, 3)) * np.array(colour) / 255.0
    m = fbm(r, h, w, 2.2)
    c *= 1 + m[..., None] * mottle
    fine = fbm(r, h, w, 0.6)
    c *= 1 + fine[..., None] * 0.012
    fib = fibres(r, h, w, int(h * w / 900), 18, fibre)
    c -= fib[..., None] * np.array([0.05, 0.05, 0.06])
    # Foxing: a few small rust spots.
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float64)
    for _ in range(int(r.integers(6, 14))):
        cx, cy, rad = r.uniform(0, w), r.uniform(0, h), r.uniform(2, 9)
        g = np.exp(-(((xx - cx) ** 2 + (yy - cy) ** 2) / (2 * rad * rad)))
        c -= g[..., None] * np.array([0.04, 0.08, 0.12]) * r.uniform(0.4, 1.0)
    return c


def edge_age(c, h, w, margin, strength, tint=(0.94, 0.86, 0.70)):
    """Yellowed, a little darker toward the edges."""
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float64)
    d = np.minimum.reduce([xx, w - 1 - xx, yy, h - 1 - yy])
    k = np.clip(1 - d / margin, 0, 1) ** 2
    c *= 1 - k[..., None] * strength * (1 - np.array(tint))
    return c


def torn_alpha(r, h, w, sides, depth):
    """Alpha with torn edges on the given sides ('l', 'r', 't', 'b')."""
    a = np.ones((h, w))
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float64)
    for side in sides:
        n = w if side in "tb" else h
        line = fbm(r, 1, n, 1.4)[0] * 0.35 + fbm(r, 1, n, 0.4)[0] * 0.15
        line = (line - line.min()) / (line.max() - line.min() + 1e-9) * depth + 2
        if side == "l":
            a *= np.clip(xx - line[:, None].T.T.reshape(h, 1), 0, 1)
        elif side == "r":
            a *= np.clip((w - 1 - xx) - line.reshape(h, 1), 0, 1)
        elif side == "t":
            a *= np.clip(yy - line.reshape(1, w), 0, 1)
        else:
            a *= np.clip((h - 1 - yy) - line.reshape(1, w), 0, 1)
    return a


def save(c, a, name):
    os.makedirs(OUT, exist_ok=True)
    rgb = np.clip(c, 0, 1)
    img = np.dstack([rgb, np.clip(a, 0, 1)]) if a is not None else rgb
    mode = "RGBA" if a is not None else "RGB"
    Image.fromarray((img * 255).round().astype(np.uint8), mode).save(os.path.join(OUT, name + ".png"))
    print("wrote", name, img.shape[1], "x", img.shape[0])


# The pieces --------------------------------------------------------------------


def sheet():
    """A sheet of old typing paper (notes, settings, the how-to), its edges
    yellowed and a little worn. Slice centre: 48 px in from each edge."""
    r = rng(11)
    h, w = 1024, 768
    c = base_paper(r, h, w, (234, 226, 206))
    c = edge_age(c, h, w, 90, 0.9)
    # A faint fold across the middle.
    yy = np.arange(h)[:, None].astype(np.float64)
    fold = np.exp(-(((yy - h * 0.48) / 3.0) ** 2)) * 0.05 - np.exp(-(((yy - h * 0.48 - 5) / 4.0) ** 2)) * 0.02
    c -= fold[..., None]
    a = torn_alpha(r, h, w, "lrtb", 3)
    save(c, a, "sheet")


def slip():
    """A slip torn off a notepad (the objective), torn along its bottom and
    right. Slice centre: 40 px in from each edge."""
    r = rng(23)
    h, w = 256, 768
    c = base_paper(r, h, w, (238, 230, 208), fibre=0.2)
    c = edge_age(c, h, w, 50, 0.7)
    # Faint blue rules, as on a notepad.
    for y in range(70, h - 30, 46):
        c[y : y + 2, :, :] *= np.array([0.9, 0.93, 0.98])
    a = torn_alpha(r, h, w, "rb", 10) * torn_alpha(r, h, w, "lt", 2)
    save(c, a, "slip")


def folder():
    """A manila case folder's front (the lobby, the dossier). Slice centre:
    64 px in from each edge."""
    r = rng(37)
    h, w = 768, 1024
    c = base_paper(r, h, w, (204, 176, 122), mottle=0.05, fibre=0.35)
    c = edge_age(c, h, w, 110, 1.0, tint=(0.80, 0.70, 0.55))
    # Worn creases and a coffee ring.
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float64)
    for _ in range(3):
        x0, y0, a0 = r.uniform(0, w), r.uniform(0, h), r.uniform(0, math.pi)
        d = np.abs((xx - x0) * math.sin(a0) - (yy - y0) * math.cos(a0))
        c -= (np.exp(-((d / 1.6) ** 2)) * 0.06)[..., None]
    cx, cy, rad = w * 0.78, h * 0.7, 70
    ringd = np.abs(np.sqrt((xx - cx) ** 2 + (yy - cy) ** 2) - rad)
    c -= (np.exp(-((ringd / 3.0) ** 2)) * 0.09 * (0.6 + 0.4 * np.sin(np.arctan2(yy - cy, xx - cx) * 3)))[..., None] * np.array([0.6, 0.9, 1.2])
    a = torn_alpha(r, h, w, "lrtb", 2)
    save(c, a, "folder")


def graph():
    """Graph paper (the map), tileable: a pale grid every 32 px, a darker
    line every 128 px. Tile it at 128 px to keep the squares even."""
    r = rng(41)
    h = w = 512
    c = base_paper(r, h, w, (236, 234, 222), mottle=0.02, fibre=0.15)
    ink = np.array([0.62, 0.78, 0.80])
    for k in range(0, w, 32):
        heavy = k % 128 == 0
        width = 2 if heavy else 1
        strength = 0.55 if heavy else 0.3
        c[:, k : k + width] = c[:, k : k + width] * (1 - strength) + ink * strength
        c[k : k + width, :] = c[k : k + width, :] * (1 - strength) + ink * strength
    save(c, None, "graph")


def notebook():
    """A lined notebook page (the journal): blue rules, a red margin.
    Slice centre: 48 px in from each edge."""
    r = rng(53)
    h, w = 1024, 768
    c = base_paper(r, h, w, (240, 236, 222), fibre=0.18)
    c = edge_age(c, h, w, 70, 0.6)
    blue = np.array([0.55, 0.68, 0.86])
    for y in range(150, h - 40, 40):
        c[y : y + 2, :] = c[y : y + 2, :] * 0.55 + blue * 0.45
    red = np.array([0.86, 0.45, 0.45])
    c[:, 110:113] = c[:, 110:113] * 0.4 + red * 0.6
    # Punched holes down the left.
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float64)
    a = torn_alpha(r, h, w, "lrtb", 2)
    for y in (180, h // 2, h - 180):
        a *= np.clip(np.sqrt((xx - 40) ** 2 + (yy - y) ** 2) - 13, 0, 1)
    save(c, a, "notebook")


def tape():
    """A strip of old yellowed cellophane tape, its ends torn."""
    r = rng(61)
    h, w = 96, 320
    c = np.ones((h, w, 3)) * np.array([226, 210, 160]) / 255.0
    c *= 1 + fbm(r, h, w, 1.6)[..., None] * 0.05
    a = np.ones((h, w)) * 0.55
    a *= 1 + fbm(r, h, w, 1.0) * 0.08
    a *= torn_alpha(r, h, w, "lr", 8)
    save(c, a, "tape")


def shadow():
    """A soft shadow under paper (black, blurred). Slice centre: 40 px in."""
    h = w = 160
    img = Image.new("L", (w, h), 0)
    ImageDraw.Draw(img).rectangle([40, 40, w - 40, h - 40], fill=255)
    img = img.filter(ImageFilter.GaussianBlur(14))
    a = np.asarray(img, dtype=np.float64) / 255.0
    save(np.zeros((h, w, 3)), a * 0.75, "shadow")


def scanlines():
    """A CRT's scanlines and its faint grain (tiled over the computer's
    screen): a dark line every other row of 4."""
    r = rng(71)
    h = w = 256
    a = np.zeros((h, w))
    for y in range(0, h, 4):
        a[y + 2 : y + 4, :] = 0.38
    a += fbm(r, h, w, 0.2) * 0.02
    save(np.zeros((h, w, 3)), np.clip(a, 0, 1), "scanlines")


if __name__ == "__main__":
    for make in (sheet, slip, folder, graph, notebook, tape, shadow, scanlines):
        make()
