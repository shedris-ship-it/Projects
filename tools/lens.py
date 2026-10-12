"""Draw the lens's images (docs/ART.md v2, the visual rework V1: P.T. on 35mm film).

Everything is drawn from code and seeded, so running this again gives the same
images:

- grain_1 .. grain_8: film grain, 512 px and seamless. One image holds both
  halves of the grain: where the noise is above zero a dark speck (black), below
  zero a light one (white, far weaker: light specks over black read as TV
  snow, and film shows its grain in the mid-tones, not the blacks); alpha is
  how strong. Shown at one texel per screen pixel and flipped at 24 frames a
  second (Controllers/LensController).
- vignette: an even, dithered fall-off to black at the edges, strongest in the
  corners. Stretched to the screen, so it is oval on a wide one.
- glare: the soft halo round a practical light, warm white at the core going to
  amber and a red rim (film halation).
- glare_streak: a faint horizontal streak through a bright light.
- lens_dirt: smudges and specks on the lens, shown only when a bright light
  sits near the middle of the view.

Run from the repository root with Python 3, numpy and Pillow:

    python tools/lens.py

Images go to assets/textures/; their uploaded ids go in src/shared/Assets.luau.
"""

import os
import sys

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(__file__))
import textures as T  # noqa: E402  (the shared noise helpers and save())


def rgba(rgb, alpha):
    """rgb: (h, w, 3) or (3,) in 0..1; alpha: (h, w) in 0..1."""
    h, w = alpha.shape
    rgb = np.broadcast_to(np.asarray(rgb, dtype=float), (h, w, 3))
    img = np.concatenate([np.clip(rgb, 0, 1), np.clip(alpha, 0, 1)[..., None]], axis=-1)
    return Image.fromarray((img * 255 + 0.5).astype(np.uint8), "RGBA")


def grain(count=8, n=512):
    for i in range(1, count + 1):
        rng = T.rng_for("grain%d" % i)
        # Film grain is mostly single fine specks with a little clumping.
        fine = T.blur(rng.standard_normal((n, n)), 0.45)
        clump = T.blur(rng.standard_normal((n, n)), 1.3)
        g = fine / fine.std() * 0.9 + clump / clump.std() * 0.3
        g /= g.std()
        dark = np.clip(g, 0, None)
        light = np.clip(-g, 0, None) * 0.3
        alpha = np.clip((dark + light) / 2.6, 0, 1)
        rgb = np.where(g > 0, 0.0, 1.0)[..., None].repeat(3, axis=-1)
        T.save(rgba(rgb, alpha), "grain_%d" % i)


def vignette(n=1024):
    rng = T.rng_for("vignette")
    y, x = np.mgrid[0:n, 0:n] / (n - 1) * 2 - 1
    r = np.sqrt(x * x + y * y)  # 1 at the middle of an edge, 1.41 in a corner
    alpha = np.clip((r - 0.4) / 1.0, 0, 1) ** 1.7
    # Dither half a step either way so a soft dark ramp never bands.
    alpha = alpha + (rng.random((n, n)) - 0.5) / 255 * 1.5
    T.save(rgba((0, 0, 0), alpha), "vignette")


def glare(n=256):
    y, x = np.mgrid[0:n, 0:n] / (n - 1) * 2 - 1
    r = np.sqrt(x * x + y * y)
    core = np.exp(-((r / 0.07) ** 2))
    halo = np.exp(-((r / 0.38) ** 2)) * 0.32
    outer = np.exp(-((r / 0.75) ** 2)) * 0.08
    fade = np.clip(1 - r, 0, 1) ** 1.5  # nothing at the square's edge
    alpha = np.clip(core + halo + outer, 0, 1) * fade
    # Warm white at the core, amber through the halo, a red rim (halation).
    warm = np.array([1.0, 0.93, 0.8])
    amber = np.array([1.0, 0.66, 0.36])
    red = np.array([0.82, 0.24, 0.12])
    t = np.clip(r / 0.6, 0, 1)[..., None]
    rgb = np.where(t < 0.5, warm + (amber - warm) * (t / 0.5), amber + (red - amber) * ((t - 0.5) / 0.5))
    T.save(rgba(rgb, alpha), "glare")


def glare_streak(w=512, h=64):
    y, x = np.mgrid[0:h, 0:w]
    u = (x / (w - 1)) * 2 - 1
    v = (y - (h - 1) / 2) / 3.0
    along = np.exp(-np.abs(u) / 0.22) * np.clip(1 - np.abs(u), 0, 1)
    alpha = np.exp(-(v**2)) * along
    rgb = np.array([1.0, 0.82, 0.62])
    T.save(rgba(rgb, alpha), "glare_streak")


def lens_dirt(w=1024, h=576):
    rng = T.rng_for("lens dirt")
    yy, xx = np.mgrid[0:h, 0:w].astype(float)
    alpha = np.zeros((h, w))
    # Soft round blotches of every size, mostly small and faint.
    for _ in range(70):
        cx, cy = rng.random() * w, rng.random() * h
        radius = 3 + rng.random() ** 2.5 * 70
        strength = (0.03 + rng.random() * 0.14) * (1.2 if radius < 10 else 0.6)
        d2 = ((xx - cx) ** 2 + (yy - cy) ** 2) / (radius * radius)
        ring = 1 + 0.6 * np.exp(-((np.sqrt(d2) - 0.85) ** 2) / 0.02)  # a dried edge
        alpha += np.exp(-d2 * 1.4) * strength * ring
    # Smears: long faint wipes from a cloth.
    n = 1024
    smear = T.fbm(rng, n, 1.6, stretch=(4.0, 1.5))[:h, :w]
    alpha += np.clip(smear - 0.8, 0, None) * 0.06
    # Kept off the very middle a little, where your eye rests.
    mid = np.exp(-(((xx - w / 2) / (w * 0.22)) ** 2 + ((yy - h / 2) / (h * 0.25)) ** 2))
    alpha *= 1 - 0.5 * mid
    T.save(rgba((1.0, 0.97, 0.92), np.clip(alpha, 0, 0.6)), "lens_dirt")


if __name__ == "__main__":
    grain()
    vignette()
    glare()
    glare_streak()
    lens_dirt()
