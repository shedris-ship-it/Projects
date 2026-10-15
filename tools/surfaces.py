"""The house's surfaces, rebuilt for PBR (the visual rework V4a, 2026-10-15).

Every room surface the house tiles (Data/Materials): each drawn seamless
from code, seeded, with three maps: colour (greyscale where the part's
Color tints it, so one wallpaper serves the sage, rose and blue rooms; in
colour where a surface has more than one hue, the brick), a normal map
(OpenGL, green up) and a roughness map of its own. Before V4a the ten
first surfaces had one flat roughness each, so a waxed floor and a matt
ceiling caught a lamp the same way; now a floor's finish is worn where
people walk, a tile is glossy and its grout dull, a damp cellar wall shines
where it's wet.

Run from the repository root with the venv's Python (numpy + Pillow):

    build/scratch/venv/Scripts/python.exe tools/surfaces.py [name ...]

Images go to assets/textures/ (<name>.jpg, <name>_normal.png,
<name>_rough.jpg); kitlib/swatches carries them through Studio's 3D
importer, which uploads them; their ids go in Assets.Textures.
"""

import math
import os
import sys

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(__file__))
import textures  # noqa: E402
from textures import SIZE, Canvas, blur, fbm, grey, normal_map, rng_for, save  # noqa: E402

# (SURFACES_OUT: somewhere else to write them, to look before they replace the
# ones in assets/textures.)
if os.environ.get("SURFACES_OUT"):
    textures.OUT = os.environ["SURFACES_OUT"]

# Helpers ------------------------------------------------------------------------


def smooth(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0, 1)
    return t * t * (3 - 2 * t)


def sample(field, x, y):
    """Bilinear lookup of a seamless field at fractional pixel coordinates,
    wrapping at the edges (domain warping)."""
    n = field.shape[0]
    x0 = np.floor(x).astype(np.int64)
    y0 = np.floor(y).astype(np.int64)
    fx, fy = x - x0, y - y0
    x0 %= n
    y0 %= n
    x1, y1 = (x0 + 1) % n, (y0 + 1) % n
    return (
        field[y0, x0] * (1 - fx) * (1 - fy)
        + field[y0, x1] * fx * (1 - fy)
        + field[y1, x0] * (1 - fx) * fy
        + field[y1, x1] * fx * fy
    )


def wrap(d, size=SIZE):
    """A signed distance along a seamless axis."""
    return (d + size / 2) % size - size / 2


def grid():
    y, x = np.mgrid[0:SIZE, 0:SIZE].astype(np.float64)
    return x, y


def cells(rng, points, size=SIZE, chunk=24):
    """Seamless Voronoi over `points` (n x 2, pixel coordinates): nearest
    and second-nearest distances and the nearest point's index."""
    x, y = grid()
    best = np.full((size, size), 1e9)
    second = np.full((size, size), 1e9)
    owner = np.zeros((size, size), dtype=np.int64)
    for i, (px, py) in enumerate(points):
        d = np.hypot(wrap(x - px, size), wrap(y - py, size))
        closer = d < best
        second = np.where(closer, best, np.minimum(second, d))
        owner = np.where(closer, i, owner)
        best = np.where(closer, d, best)
    return best, second, owner


def save_set(name, colour, height, rough, strength):
    """The surface's three maps: colour (greyscale from a 2D array, colour
    from an n x n x 3 one), normal (from the height field) and roughness."""
    if colour.ndim == 2:
        save(grey(colour), name)
    else:
        save(Image.fromarray((np.clip(colour, 0, 1) * 255 + 0.5).astype(np.uint8), "RGB"), name)
    save(normal_map(height, strength), name + "_normal")
    save(grey(np.clip(rough, 0.02, 1)), name + "_rough")


def scratches(rng, count, length, along_x=True, spread=0.5, width=1.2):
    """Fine scratches, mostly along one way, as a coverage field."""
    c = Canvas(SIZE, 0.0)
    for _ in range(count):
        x, y = rng.uniform(0, SIZE, 2)
        a = rng.normal(0 if along_x else math.pi / 2, spread)
        n = rng.uniform(length * 0.3, length)
        bend = rng.normal(0, 0.15)
        pts = []
        for t in np.linspace(0, 1, 6):
            aa = a + bend * t
            pts.append((x + n * t * math.cos(aa), y + n * t * math.sin(aa)))
        c.line(pts, rng.uniform(0.3, 1.0), width)
    return c.array()


# Wood ------------------------------------------------------------------------------


def boards(rng, along_x, widths, joints, period=(10.0, 16.0), quarter=0.3, arch=(0.06, 0.2)):
    """Boards of figured wood. `widths` across the tile in pixels (they sum to
    SIZE); `joints` end joints per run of boards (0: boards the whole tile
    long). Returns a dict of fields: wood (0 light earlywood .. 1 dark
    latewood), pores, board tone, gap (joints), bevel, the board's id."""
    x, y = grid()
    if not along_x:
        x, y = y, x
    edges = np.concatenate([[0], np.cumsum(widths)])
    row = np.searchsorted(edges, y, side="right") - 1
    row = np.clip(row, 0, len(widths) - 1)
    within = y - edges[row]
    width = np.asarray(widths, dtype=np.float64)[row]
    # End joints along each run, staggered.
    seg = np.zeros_like(row)
    seg_mid = np.full_like(x, SIZE / 2)
    seg_len = np.full_like(x, float(SIZE))
    end_gap = np.zeros_like(x)
    if joints:
        for r in range(len(widths)):
            pos = np.sort(rng.uniform(0, SIZE, joints))
            mask = row == r
            xs = x[mask]
            k = np.searchsorted(pos, xs) % joints
            seg[mask] = k
            start = pos[(k - 1) % joints]
            end = pos[k]
            length = (end - start) % SIZE
            length = np.where(length == 0, SIZE, length)
            seg_len[mask] = length
            seg_mid[mask] = (start + length / 2) % SIZE
            d = np.min(np.abs(np.stack([wrap(xs - p) for p in pos])), axis=0)
            end_gap[mask] = np.clip(1.6 - d, 0, 1)
    board = row * 37 + seg
    nb = int(board.max()) + 1
    tone = rng.normal(0, 1, nb)[board]
    # The log's heart near the board's face: rings cut across it show as
    # nested cathedral arches along the board (flat-sawn).
    # (Kept off the board: a heart inside it drew closed ovals, plywood's look.)
    below = rng.uniform(0, 1, nb) < 0.5
    off = rng.uniform(0.12, 0.9, nb)
    py = np.where(below, -off, 1 + off)[board] * width
    tilt = rng.uniform(arch[0], arch[1], nb)[board]
    per = rng.uniform(period[0], period[1], nb)[board]
    quartered = (rng.uniform(0, 1, nb) < quarter)[board]
    phase = rng.uniform(0, 100, nb)[board]
    dx = wrap(x - seg_mid) * np.minimum(1.0, SIZE / np.maximum(seg_len, 1))
    st = (8.0, 1.0) if along_x else (1.0, 8.0)
    warp = 5.0 * fbm(rng, SIZE, 1.6, stretch=st) + 1.5 * fbm(rng, SIZE, 1.0, stretch=(st[0] / 2.5, st[1] / 2.5))
    r_flat = np.hypot(within - py, dx * tilt) + warp
    r_quart = within * 0.55 + 0.6 * warp
    r = np.where(quartered, r_quart, r_flat) + phase
    # Uneven growth: some years' rings wider than others.
    r = r + 0.35 * per * np.sin(r / (per * 2.7)) + 0.2 * per * np.sin(r / (per * 6.1) + phase)
    ring = (r / per) % 1.0
    late = smooth(0.52, 0.86, ring) * (1 - smooth(0.95, 1.0, ring))
    fine = fbm(rng, SIZE, 0.6, stretch=(30.0, 1.0) if along_x else (1.0, 30.0))
    pores = np.clip(fine - 1.3, 0, 1) * (1 - late)
    edge = np.minimum(within, width - 1 - within)
    gap = np.maximum(np.clip(1.6 - edge, 0, 1), end_gap)
    bevel = np.clip(1 - edge / 4.0, 0, 1) * (1 - gap)
    # (Every field is in the image's own axes: only the coordinates were
    # swapped for boards that run up the tile.)
    return dict(wood=late, pores=pores, tone=tone, gap=gap, bevel=bevel, board=board, ring=ring, fine=fine)


def wood_floor():
    """Strip oak, worn: boards along the room, each with its own figure
    (flat-sawn cathedral arches or quarter-sawn straight grain) and tone,
    open pores, staggered end joints with dirt in them. Polyurethane: a low
    roughness, dulled where people walk and scratched. Greyscale: the
    floor's colour tints it."""
    rng = rng_for("v4a_wood_floor")
    b = boards(rng, True, [SIZE // 8] * 8, joints=2, period=(9.0, 14.0), arch=(0.18, 0.45))
    colour = 0.80 + 0.045 * b["tone"] - 0.17 * b["wood"] - 0.10 * b["pores"] + 0.015 * b["fine"]
    colour = colour * (1 - 0.6 * b["gap"]) * (1 - 0.06 * b["bevel"])
    wear = np.clip(fbm(rng, SIZE, 2.5), 0, None)
    scr = scratches(rng, 260, 90, along_x=True, spread=0.35, width=1.0)
    colour += 0.03 * wear + 0.02 * blur(scr, 0.6)
    rough = 0.34 + 0.16 * np.clip(wear, 0, 1.5) + 0.25 * blur(scr, 0.8) + 0.5 * b["gap"] + 0.04 * b["pores"]
    height = 0.18 * b["wood"] - 0.25 * b["pores"] - 2.2 * blur(b["gap"], 0.8) - 0.5 * b["bevel"] - 0.15 * scr
    save_set("wood_floor", colour, height, rough, 2.2)


def wood_panel():
    """1970s walnut V-groove panelling: vertical boards of three widths, a
    V-groove between each, a darker figured walnut; satin lacquer, duller
    in the grooves. Greyscale: the wall's colour tints it."""
    rng = rng_for("v4a_wood_panel")
    widths = [96, 160, 128, 96, 128, 160, 128, 128]  # sums to the tile
    b = boards(rng, False, widths, joints=0, period=(9.0, 15.0), quarter=0.15)
    colour = 0.74 + 0.05 * b["tone"] - 0.22 * b["wood"] - 0.08 * b["pores"] + 0.02 * b["fine"]
    # The V-groove: wide and dark, its two faces catching the light.
    v = np.clip(b["bevel"] * 1.6, 0, 1)
    colour = colour * (1 - 0.55 * b["gap"]) * (1 - 0.25 * v)
    sheen = fbm(rng, SIZE, 2.2)
    rough = 0.46 + 0.05 * sheen + 0.35 * v + 0.4 * b["gap"]
    height = 0.12 * b["wood"] - 0.2 * b["pores"] - 2.6 * blur(np.maximum(b["gap"], v * 0.7), 1.0)
    save_set("wood_panel", colour, height, rough, 2.4)


# Walls and ceilings ---------------------------------------------------------------


def cracks(rng, count, steps=(20, 60), step=(4.0, 9.0), width=1.0):
    """Hairline cracks: wandering lines that now and then fork."""
    c = Canvas(SIZE, 0.0)
    for _ in range(count):
        x, y = rng.uniform(0, SIZE, 2)
        a = rng.uniform(0, 2 * math.pi)
        stack = [(x, y, a, int(rng.integers(*steps)))]
        while stack:
            x, y, a, n = stack.pop()
            pts = [(x, y)]
            for _ in range(n):
                a += rng.normal(0, 0.35)
                d = rng.uniform(*step)
                x, y = x + d * math.cos(a), y + d * math.sin(a)
                pts.append((x, y))
                if rng.uniform() < 0.04 and len(stack) < 6:
                    stack.append((x, y, a + rng.choice([-1, 1]) * rng.uniform(0.5, 1.1), int(n * 0.4)))
            c.line(pts, rng.uniform(0.6, 1.0), width)
    return c.array()


def plaster():
    """Old painted plaster: a roller's orange-peel stipple, trowel marks
    under the paint, filled and repainted patches, hairline cracks, faint
    stains. Eggshell paint: a little sheen, duller on the patches and in the
    cracks. Greyscale: the wall's colour tints it."""
    rng = rng_for("v4a_plaster")
    blotch = fbm(rng, SIZE, 2.0)
    mid = fbm(rng, SIZE, 1.2)
    stipple = blur(rng.standard_normal((SIZE, SIZE)), 1.1)
    stipple /= stipple.std()
    trowel = fbm(rng, SIZE, 1.6, stretch=(4.0, 1.0))
    crack = cracks(rng, 6)
    patch = smooth(1.1, 1.5, fbm(rng, SIZE, 2.2))
    stain = smooth(0.9, 2.2, fbm(rng, SIZE, 2.3))
    colour = (
        0.88 + 0.028 * blotch + 0.012 * mid + 0.006 * stipple - 0.05 * stain + 0.018 * patch - 0.14 * blur(crack, 0.5)
    )
    rough = 0.7 + 0.035 * blotch + 0.015 * stipple + 0.1 * patch - 0.04 * stain + 0.2 * crack
    height = 0.35 * stipple + 0.2 * trowel + 0.3 * mid - 1.4 * blur(crack, 0.6) + 0.25 * patch
    save_set("plaster", colour, height, rough, 1.0)


def popcorn():
    """A popcorn ceiling: dense clustered lumps, deep crevices between,
    yellowed in patches (decades of cigarettes). Matt all over."""
    rng = rng_for("v4a_popcorn")
    lumps = np.zeros((SIZE, SIZE))
    for radius, weight, keep in ((3.2, 1.0, 0.86), (1.8, 0.7, 0.8), (1.0, 0.35, 0.7)):
        seeds = (rng.uniform(0, 1, (SIZE, SIZE)) > keep).astype(np.float64)
        lumps += weight * blur(seeds, radius)
    lumps = lumps / lumps.max()
    height = np.power(lumps, 0.7)
    crevice = np.clip(blur(height, 3.0) - height, 0, None)
    crevice /= crevice.max() + 1e-9
    yellow = smooth(0.6, 2.0, fbm(rng, SIZE, 2.4))
    colour = 0.86 + 0.08 * (height - 0.5) - 0.12 * crevice - 0.05 * yellow
    rough = 0.95 - 0.03 * height + 0.02 * crevice
    save_set("popcorn", colour, height, rough, 5.0)


def wallpaper_sprig():
    """1980s calico wallpaper: rosebud sprigs (petals, a darker curl, a
    calyx, two veined leaves) in a half-drop, a scatter of tiny buds and
    dots between; hung in strips with a faint seam every quarter tile. The
    inks a touch satin on matt paper. Greyscale: the wall's colour tints it."""
    rng = rng_for("v4a_wallpaper_sprig")
    petal, shade, leaf, stem, dots = (Canvas(SIZE, 0.0) for _ in range(5))
    strip = SIZE // 4  # one roll's width (about 1.5 studs)
    k = 1.25

    def sprig(cx, cy, flip, small=False):
        kk = k * (0.6 if small else 1.0)
        st = [(cx + flip * 7 * kk * math.sin(t * 2.4), cy + (30 - t * 56) * kk) for t in np.linspace(0, 1, 14)]
        stem.line(st, 1.0, 2.2 * kk)
        for t, side, ang in ((0.35, -1, 0.7), (0.62, 1, -0.6)):
            lx, ly = st[int(t * 13)]
            a = ang * flip
            ex, ey = lx + side * flip * 11 * kk, ly + 2 * kk
            leaf.ellipse(ex, ey, 11 * kk, 4.6 * kk, a, 1.0)
            rib = [(ex - 9 * kk * math.cos(a), ey - 9 * kk * math.sin(a)), (ex + 9 * kk * math.cos(a), ey + 9 * kk * math.sin(a))]
            stem.line(rib, 0.7, 0.9)
        bx, by = st[-1]
        for p in range(5):
            a = -math.pi / 2 + (p - 2) * 0.55 + 0.2 * flip
            petal.ellipse(bx + 6 * kk * math.cos(a), by - 3 * kk + 6 * kk * math.sin(a), 7.5 * kk, 5.5 * kk, a, 1.0)
        shade.ellipse(bx, by - 2 * kk, 4.2 * kk, 5.5 * kk, 0.3 * flip, 1.0)
        shade.line([(bx - 4 * kk, by - 5 * kk), (bx + 1 * kk, by - 8 * kk), (bx + 4 * kk, by - 4 * kk)], 0.8, 1.4 * kk)
        leaf.ellipse(bx - 5 * kk * flip, by + 5 * kk, 4 * kk, 2 * kk, 0.9 * flip, 1.0)
        leaf.ellipse(bx + 5 * kk * flip, by + 5 * kk, 4 * kk, 2 * kk, -0.9 * flip, 1.0)

    for col in range(8):
        x = col * strip / 2 + strip / 4
        for row in range(5):
            y = row * SIZE / 5 + (SIZE / 10 if col % 2 else 0)
            flip = -1 if (row + col) % 2 else 1
            sprig(x, y + 10, flip)
            # Small buds and dots between the sprigs.
            sprig(x + strip / 4, y + SIZE / 10 + 6, -flip, small=True)
            for _ in range(3):
                dots.ellipse(x + rng.uniform(-50, 50), y + rng.uniform(-60, 60), 1.6, 1.6, 0, 1.0, steps=8)
    P, S, L, T, D = (c.array() for c in (petal, shade, leaf, stem, dots))
    ink = np.maximum.reduce([P * 0.2, S * 0.36, L * 0.3, T * 0.32, D * 0.2])
    density = 1 + 0.12 * fbm(rng, SIZE, 1.2)  # uneven print
    x, _ = grid()
    seam = np.clip(1.5 - np.abs(wrap(x % strip - 0.5, strip)), 0, 1)
    paper_ = 0.92 + 0.01 * fbm(rng, SIZE, 0.4) + 0.012 * fbm(rng, SIZE, 1.8) - 0.03 * smooth(0.8, 2.2, fbm(rng, SIZE, 2.4))
    colour = paper_ - ink * density - 0.03 * seam
    coverage = np.clip(np.maximum.reduce([P, S, L, T, D]), 0, 1)
    rough = 0.9 - 0.12 * coverage + 0.05 * seam
    height = 0.5 * blur(coverage, 0.8) + 0.05 * fbm(rng, SIZE, 0.6) + 0.8 * blur(seam, 1.0)
    save_set("wallpaper_sprig", colour, height, rough, 1.8)


def wallpaper_stripe():
    """Regency stripes: a broad satin band with a fine moire, between matt
    bands, edged with pinlines; hung in strips, a faint seam at each.
    Greyscale: the wall's colour tints it."""
    rng = rng_for("v4a_wallpaper_stripe")
    unit = SIZE // 4
    x, y = grid()
    u = x % unit
    band = smooth(68, 72, u) * (1 - smooth(184, 188, u))
    lines = np.zeros_like(x)
    for lx in (56, 62, 194, 200):
        lines = np.maximum(lines, np.clip(1.2 - np.abs(u - lx), 0, 1))
    moire = 0.5 + 0.5 * np.sin(y * 2 * math.pi / 3.0 + 3 * fbm(rng, SIZE, 1.6, stretch=(1.0, 4.0)))
    seam = np.clip(1.5 - np.abs(wrap(u - 0.5, unit)), 0, 1)
    paper_ = 0.92 + 0.01 * fbm(rng, SIZE, 0.4) + 0.012 * fbm(rng, SIZE, 1.8)
    colour = paper_ - 0.12 * band - 0.012 * band * moire - 0.28 * lines - 0.025 * seam
    rough = 0.88 - 0.36 * band + 0.05 * band * moire + 0.05 * seam
    height = 0.12 * band + 0.06 * band * moire + 0.2 * lines + 0.8 * blur(seam, 1.0) + 0.04 * fbm(rng, SIZE, 0.6)
    save_set("wallpaper_stripe", colour, height, rough, 1.6)


# Floors -------------------------------------------------------------------------------


def carpet():
    """Cut-pile carpet: tufts of yarn with a few darker flecks, the pile
    lying different ways in patches (shading), flattened and lighter where
    people walk, a few old stains. Very rough. Greyscale: tinted by the
    floor's colour."""
    rng = rng_for("v4a_carpet")
    tuft = blur(rng.standard_normal((SIZE, SIZE)), 1.6)
    tuft /= tuft.std()
    fibre = blur(rng.standard_normal((SIZE, SIZE)), 0.6)
    fibre /= fibre.std()
    f = blur(rng.standard_normal((SIZE, SIZE)), 0.9)
    fleck = smooth(1.9, 2.4, f / f.std())
    shading = fbm(rng, SIZE, 1.8, stretch=(2.0, 1.0))
    traffic = np.clip(fbm(rng, SIZE, 2.6), 0, None)
    stains = smooth(1.2, 2.2, fbm(rng, SIZE, 2.2)) * (1 + 0.4 * fbm(rng, SIZE, 1.0))
    flat = 1 - 0.45 * np.clip(traffic, 0, 1)
    colour = (
        0.84
        + flat * (0.03 * tuft + 0.014 * fibre)
        + 0.03 * shading
        - 0.05 * fleck
        + 0.03 * traffic
        - 0.06 * stains
    )
    rough = 0.97 - 0.07 * np.clip(traffic, 0, 1) - 0.01 * tuft
    height = flat * (0.8 * tuft + 0.35 * fibre)
    save_set("carpet", colour, height, rough, 2.4)


def linoleum():
    """Vinyl composition tile in a checkerboard: each tile mottled along its
    grain, laid quarter-turned, flecked with chips; tight joints with wax
    built up along them; black heel scuffs; waxed glossy, dulled where
    people walk. Greyscale: tinted by the floor's colour."""
    rng = rng_for("v4a_linoleum")
    n = 8
    cell = SIZE // n
    x, y = grid()
    cx, cy = (x // cell).astype(int), (y // cell).astype(int)
    checker = ((cx + cy) % 2).astype(np.float64)
    turned = ((cx * 3 + cy * 5) % 2).astype(bool)
    mot = np.where(turned, fbm(rng, SIZE, 1.3, stretch=(1.0, 7.0)), fbm(rng, SIZE, 1.3, stretch=(7.0, 1.0)))
    chips = blur(rng.standard_normal((SIZE, SIZE)), 0.7)
    chips = chips / chips.std()
    chips = smooth(2.0, 2.6, chips) - smooth(2.0, 2.6, -chips)
    tone = rng.uniform(-0.02, 0.02, (n, n))[cy % n, cx % n]
    colour = np.where(checker > 0, 0.9 + 0.03 * mot + 0.04 * chips, 0.3 + 0.025 * mot + 0.06 * chips) + tone
    ex = np.minimum(x % cell, cell - 1 - x % cell)
    ey = np.minimum(y % cell, cell - 1 - y % cell)
    edge = np.minimum(ex, ey)
    joint = np.clip(1.3 - edge, 0, 1)
    wax = np.clip(1 - edge / 6.0, 0, 1) * (1 - joint)
    scuff = Canvas(SIZE, 0.0)
    for _ in range(55):
        sx, sy = rng.uniform(0, SIZE, 2)
        a = rng.uniform(0, 2 * math.pi)
        length = rng.uniform(10, 45)
        bend = rng.normal(0, 0.5)
        pts = [
            (sx + length * t * math.cos(a + bend * t), sy + length * t * math.sin(a + bend * t))
            for t in np.linspace(0, 1, 6)
        ]
        scuff.line(pts, rng.uniform(0.4, 1.0), rng.uniform(1.5, 3.0))
    sc = blur(scuff.array(), 1.0)
    traffic = np.clip(fbm(rng, SIZE, 2.5), 0, None)
    colour = colour * (1 - 0.35 * joint) - 0.05 * wax - 0.25 * sc * (colour > 0.6) - 0.05 * sc + 0.02 * traffic
    rough = 0.26 + 0.14 * np.clip(traffic, 0, 1.5) + 0.35 * sc + 0.45 * joint + 0.05 * wax
    height = -1.2 * blur(joint, 0.7) + 0.08 * chips + 0.05 * fbm(rng, SIZE, 1.0)
    save_set("linoleum", colour, height, rough, 2.0)


def hex_tile():
    """Small white hexagonal mosaic: glossy glazed tiles, each a hair
    different in tone and tilt (so they catch the light one by one), dirty
    grout between them, dull."""
    rng = rng_for("v4a_hex_tile")
    cols, rows = 16, 18
    w, h = SIZE / cols, SIZE / rows
    pts = [(q * w + (w / 2 if r % 2 else 0), r * h) for r in range(rows) for q in range(cols)]
    best, second, owner = cells(rng, pts)
    edge = second - best
    grout = np.clip(1 - (edge - 2.5) / 2.0, 0, 1)
    n = len(pts)
    tone = rng.uniform(-0.03, 0.03, n)[owner]
    x, y = grid()
    px = np.array([p[0] for p in pts])[owner]
    py = np.array([p[1] for p in pts])[owner]
    tilt = rng.normal(0, 0.012, (n, 2))
    plane = tilt[owner, 0] * wrap(x - px) + tilt[owner, 1] * wrap(y - py)
    dome = np.clip(edge / 9.0, 0, 1)
    grime = 0.5 + 0.5 * fbm(rng, SIZE, 1.6)
    colour = (0.92 + tone + 0.008 * fbm(rng, SIZE, 0.8)) * (1 - grout) + (0.6 - 0.12 * grime) * grout
    rough = (0.12 + rng.uniform(0, 0.06, n)[owner]) * (1 - grout) + 0.9 * grout
    height = dome * 0.9 + plane * (1 - grout) - grout * 0.7
    save_set("hex_tile", colour, height, rough, 3.2)


def concrete():
    """Stained concrete: aggregate speckle, pits, hairline cracks, oil
    stains (dark and slick), water tide-marks, dust. Greyscale: tinted."""
    rng = rng_for("v4a_concrete")
    big = fbm(rng, SIZE, 2.0)
    mid = fbm(rng, SIZE, 1.1)
    speck = blur(rng.standard_normal((SIZE, SIZE)), 0.7)
    speck /= speck.std()
    pits = blur((fbm(rng, SIZE, 0.3) > 2.4).astype(np.float64), 0.7)
    oil = np.clip(smooth(1.5, 2.4, fbm(rng, SIZE, 1.7)) * (0.7 + 0.3 * fbm(rng, SIZE, 1.0)), 0, 1)
    tide = np.clip(1 - np.abs(fbm(rng, SIZE, 2.0) - 1.2) / 0.05, 0, 1) * 0.6
    crack = cracks(rng, 4, steps=(30, 80), step=(5.0, 10.0))
    dust = smooth(0.4, 1.8, fbm(rng, SIZE, 2.4))
    colour = (
        0.82
        + 0.035 * big
        + 0.02 * mid
        + 0.015 * speck
        - 0.25 * pits
        - 0.22 * oil
        - 0.05 * tide
        - 0.15 * blur(crack, 0.6)
        + 0.04 * dust
    )
    rough = 0.84 + 0.03 * mid - 0.48 * oil + 0.08 * dust + 0.1 * crack
    height = 0.3 * mid + 0.15 * speck - 1.2 * pits - 1.0 * blur(crack, 0.7)
    save_set("concrete", colour, height, rough, 1.5)


# New surfaces (V4a): what the house still drew in Roblox's own materials -----------


def brick():
    """Old soft red brick in running bond, for the cellar: every brick its
    own colour (reds, browns, a dark over-fired one now and then), pitted,
    chipped at the corners; lime mortar, recessed; an old whitewash
    flaking, salt bloom, damp patches dark and wet. In colour: the wall's
    colour should be near white."""
    rng = rng_for("v4a_brick")
    rows, per_row = 30, 10
    bh, bw = SIZE / rows, SIZE / per_row
    x, y = grid()
    row = np.floor(y / bh).astype(int)
    shift = np.where(row % 2 == 0, 0.0, bw / 2)
    xs = (x + shift) % SIZE
    col = np.floor(xs / bw).astype(int)
    lx, ly = xs - col * bw, y - row * bh
    jitter = 2.0 * fbm(rng, SIZE, 1.4)
    mortar_w = 2.6
    ex = np.minimum(lx, bw - lx) + jitter * 0.6
    ey = np.minimum(ly, bh - ly) + jitter * 0.4
    face = smooth(mortar_w - 0.6, mortar_w + 1.6, np.minimum(ex, ey))
    key = (row % rows) * per_row + col % per_row
    nb = rows * per_row
    palette = np.array(
        [[0.56, 0.31, 0.23], [0.5, 0.29, 0.22], [0.6, 0.36, 0.27], [0.46, 0.27, 0.21], [0.52, 0.34, 0.27], [0.33, 0.2, 0.18]]
    )
    pick = rng.choice(len(palette), nb, p=[0.24, 0.24, 0.18, 0.14, 0.14, 0.06])
    base = palette[pick][key] * rng.uniform(0.9, 1.1, nb)[key][..., None]
    grain = blur(rng.standard_normal((SIZE, SIZE)), 0.8)
    grain /= grain.std()
    pits = smooth(2.0, 2.6, grain) + 0.5 * smooth(1.2, 1.6, fbm(rng, SIZE, 0.6))
    brick_c = base * (1 + 0.06 * fbm(rng, SIZE, 1.2)[..., None] + 0.04 * grain[..., None]) * (1 - 0.25 * pits[..., None])
    mortar_c = np.array([0.66, 0.63, 0.57]) * (1 + 0.05 * fbm(rng, SIZE, 1.0))[..., None]
    colour = brick_c * face[..., None] + mortar_c * (1 - face[..., None])
    wash = smooth(1.0, 1.8, fbm(rng, SIZE, 2.2)) * smooth(-0.2, 0.6, fbm(rng, SIZE, 0.9))
    colour = colour * (1 - 0.55 * wash[..., None]) + np.array([0.8, 0.79, 0.74]) * 0.55 * wash[..., None]
    bloom = smooth(1.4, 2.2, fbm(rng, SIZE, 1.6)) * (0.5 + 0.5 * smooth(0, 1, fbm(rng, SIZE, 0.5)))
    colour = colour * (1 - 0.3 * bloom[..., None]) + 0.85 * 0.3 * bloom[..., None]
    damp = smooth(1.0, 2.0, fbm(rng, SIZE, 1.9))
    colour *= 1 - 0.14 * damp[..., None]
    rough = 0.82 * face + 0.95 * (1 - face) + 0.06 * pits + 0.08 * wash - 0.4 * damp
    height = face * (1.0 - 0.3 * pits + 0.1 * grain) + 0.15 * wash
    save_set("brick", colour, height, rough, 2.6)


def rough_boards():
    """Rough-sawn pine boards for the attic's floors and the cellar's and
    attic's ceilings: wide boards, soft grain, knots, the saw's arcs across
    them, nail holes over the joists, dark gaps. Raw wood: rough.
    Greyscale: tinted by the surface's colour."""
    rng = rng_for("v4a_rough_boards")
    widths = [104, 120, 112, 128, 104, 120, 112, 128, 96]
    b = boards(rng, True, widths, joints=1, period=(14.0, 24.0), quarter=0.2, arch=(0.1, 0.3))
    x, y = grid()
    saw = np.zeros_like(x)
    edges = np.concatenate([[0], np.cumsum(widths)])
    for i in range(len(widths)):
        cx = rng.uniform(0, SIZE)
        cy = edges[i] + rng.choice([-1, 1]) * rng.uniform(400, 700)
        d = np.hypot(wrap(x - cx), y - cy)
        band = (y >= edges[i]) & (y < edges[i + 1])
        wob = 1.5 * fbm(rng, SIZE, 1.2)
        saw = np.where(band, np.sin((d + wob) * 2 * math.pi / rng.uniform(6.0, 9.0)) * (0.5 + 0.5 * fbm(rng, SIZE, 1.8)), saw)
    knots = np.zeros_like(x)
    for _ in range(9):
        kx, ky = rng.uniform(0, SIZE, 2)
        rx, ry = rng.uniform(5, 11), rng.uniform(4, 8)
        d = np.hypot(wrap(x - kx) / rx, wrap(y - ky) / ry)
        knots = np.maximum(knots, smooth(1.3, 0.6, d))
    nails = np.zeros_like(x)
    for jx in np.arange(0, SIZE, SIZE / 4) + 40:
        for i in range(len(widths)):
            for off in (0.25, 0.75):
                ny = edges[i] + widths[i] * off
                d = np.hypot(wrap(x - jx), wrap(y - ny))
                nails = np.maximum(nails, smooth(2.2, 1.0, d))
    colour = 0.74 + 0.05 * b["tone"] - 0.1 * b["wood"] + 0.012 * saw + 0.015 * b["fine"] - 0.3 * knots - 0.4 * nails
    colour = colour * (1 - 0.75 * b["gap"])
    colour -= 0.05 * smooth(0.5, 2.0, fbm(rng, SIZE, 2.2))
    rough = 0.86 + 0.01 * saw - 0.08 * knots + 0.1 * b["gap"]
    height = 0.15 * b["wood"] + 0.07 * saw + 0.1 * knots - 2.4 * blur(b["gap"], 1.0) - 1.0 * nails
    save_set("rough_boards", colour, height, rough, 2.0)


def bath_tile():
    """Square glazed wall tiles, the bathroom's: four-and-a-quarter inch
    tiles with pillowed edges, each a hair different in tone and tilt, a few
    with crazed glaze; dirty grout. Glossy tiles, dull grout. Greyscale:
    tinted (the 1980s pastels)."""
    rng = rng_for("v4a_bath_tile")
    n = 10
    cell = SIZE / n
    x, y = grid()
    cx, cy = np.floor(x / cell).astype(int), np.floor(y / cell).astype(int)
    lx, ly = x - cx * cell, y - cy * cell
    edge = np.minimum(np.minimum(lx, cell - lx), np.minimum(ly, cell - ly))
    grout = np.clip(1 - (edge - 1.2) / 1.2, 0, 1)
    pillow = np.clip(edge / 7.0, 0, 1)
    tid = (cy % n) * n + cx % n
    tone = rng.uniform(-0.025, 0.025, n * n)[tid]
    tilt = rng.normal(0, 0.01, (n * n, 2))
    plane = tilt[tid, 0] * (lx - cell / 2) + tilt[tid, 1] * (ly - cell / 2)
    crazed = (rng.uniform(0, 1, n * n) < 0.12)[tid]
    craze = cracks(rng, 40, steps=(4, 12), step=(3.0, 6.0), width=0.8) * crazed
    grime = 0.5 + 0.5 * fbm(rng, SIZE, 1.6)
    colour = (0.9 + tone + 0.006 * fbm(rng, SIZE, 0.8) - 0.05 * craze) * (1 - grout) + (0.62 - 0.12 * grime) * grout
    rough = (0.1 + 0.25 * craze) * (1 - grout) + 0.9 * grout
    height = pillow * 1.0 + plane * (1 - grout) - 0.6 * grout
    save_set("bath_tile", colour, height, rough, 3.0)


def flagstone():
    """Flagstones for the cellars, the mudroom and the pantry: irregular
    stones in sandy mortar, each with its own tone and cleft grain, worn
    smooth in the middle. Greyscale: tinted (slate grey)."""
    rng = rng_for("v4a_flagstone")
    k = 6
    pts = []
    for i in range(k):
        for j in range(k):
            pts.append(((i + 0.5 + rng.uniform(-0.32, 0.32)) * SIZE / k, (j + 0.5 + rng.uniform(-0.32, 0.32)) * SIZE / k))
    x, y = grid()
    wx = x + 14 * fbm(rng, SIZE, 1.8)
    wy = y + 14 * fbm(rng, SIZE, 1.8)
    best = np.full((SIZE, SIZE), 1e9)
    second = np.full((SIZE, SIZE), 1e9)
    owner = np.zeros((SIZE, SIZE), dtype=np.int64)
    for i, (px, py) in enumerate(pts):
        d = np.hypot(wrap(wx - px), wrap(wy - py))
        closer = d < best
        second = np.where(closer, best, np.minimum(second, d))
        owner = np.where(closer, i, owner)
        best = np.where(closer, d, best)
    edge = second - best
    joint = 1 - smooth(4.0, 8.0, edge)
    n = len(pts)
    tone = rng.uniform(-0.08, 0.08, n)[owner]
    ang = rng.uniform(0, math.pi, n)[owner]
    cleft = np.cos(ang) ** 2 * fbm(rng, SIZE, 1.2, stretch=(6.0, 1.0)) + np.sin(ang) ** 2 * fbm(rng, SIZE, 1.2, stretch=(1.0, 6.0))
    worn = smooth(10, 60, edge)
    stone_c = 0.66 + tone + 0.05 * cleft + 0.02 * fbm(rng, SIZE, 0.6)
    colour = stone_c * (1 - joint) + (0.92 + 0.04 * fbm(rng, SIZE, 1.0)) * joint
    rough = (0.82 - 0.2 * worn + 0.04 * cleft) * (1 - joint) + 0.95 * joint
    height = (0.35 * cleft * (1 - 0.6 * worn) + 0.4 * smooth(0, 20, edge)) * (1 - joint) - 0.8 * joint
    save_set("flagstone", colour, height, rough, 2.4)


def quarry_tile():
    """Terracotta quarry tiles for the sunroom: six-inch squares, each fired
    a different shade, darker at the edges, pitted; sealed (a soft sheen,
    worn duller); wide grey grout. In colour: the floor's colour should be
    near white."""
    rng = rng_for("v4a_quarry_tile")
    n = 11
    cell = SIZE / n
    x, y = grid()
    cx, cy = np.floor(x / cell).astype(int), np.floor(y / cell).astype(int)
    lx, ly = x - cx * cell, y - cy * cell
    edge = np.minimum(np.minimum(lx, cell - lx), np.minimum(ly, cell - ly)) + 0.5 * fbm(rng, SIZE, 1.2)
    grout = 1 - smooth(2.6, 4.2, edge)
    tid = (cy % n) * n + cx % n
    shade = rng.uniform(0.82, 1.12, n * n)[tid]
    terracotta = np.array([0.66, 0.36, 0.25])
    rim = 1 - 0.12 * (1 - smooth(4, 16, edge))
    p = blur(rng.standard_normal((SIZE, SIZE)), 0.8)
    pits = smooth(2.1, 2.7, p / p.std())
    tile_c = terracotta * (shade * rim * (1 + 0.05 * fbm(rng, SIZE, 1.3)) - 0.15 * pits)[..., None]
    grout_c = np.array([0.52, 0.5, 0.46]) * (1 + 0.05 * fbm(rng, SIZE, 1.0))[..., None]
    colour = tile_c * (1 - grout[..., None]) + grout_c * grout[..., None]
    traffic = np.clip(fbm(rng, SIZE, 2.5), 0, None)
    rough = (0.5 + 0.15 * np.clip(traffic, 0, 1.5) + 0.2 * pits) * (1 - grout) + 0.92 * grout
    height = smooth(2.6, 9.0, edge) * (1 - 0.3 * pits) - 0.6 * grout
    save_set("quarry_tile", colour, height, rough, 2.6)


def clapboard():
    """The house's outside: painted clapboard, weathered. Lapped boards, each
    sloping out to a thick bottom edge with a shadow under it; the paint
    flaking to grey wood in patches, dirt run down from above, a butt joint
    now and then. Greyscale: tinted (grey-green)."""
    rng = rng_for("v4a_clapboard")
    n = 17
    bh = SIZE / n
    x, y = grid()
    row = np.floor(y / bh).astype(int)
    t = (y - row * bh) / bh  # 0 at the board's top (under the one above) .. 1 at its bottom edge
    shadow = 1 - smooth(0.0, 0.12, t)
    joints = np.zeros_like(x)
    for r in range(n):
        for _ in range(int(rng.integers(0, 2))):
            jx = rng.uniform(0, SIZE)
            joints = np.maximum(joints, (row == r) * np.clip(1.3 - np.abs(wrap(x - jx)), 0, 1))
    grain = fbm(rng, SIZE, 1.0, stretch=(20.0, 1.0))
    # Small flakes scattered evenly, more along the boards' lower edges where
    # the rain sits (one big patch, repeated tile by tile, read as a stain
    # stamped across the wall, 2026-10-15).
    flake = 0.7 * fbm(rng, SIZE, 1.0) + 0.5 * fbm(rng, SIZE, 0.5) + 0.6 * smooth(0.6, 1.0, t)
    peel = smooth(1.55, 1.75, flake)
    peel_edge = np.clip(1 - np.abs(flake - 1.5) / 0.05, 0, 1) * (1 - peel)
    runs = smooth(0.6, 2.0, fbm(rng, SIZE, 1.2, stretch=(1.0, 10.0)))
    paint = 0.82 + 0.02 * fbm(rng, SIZE, 1.2) - 0.06 * runs
    bare = 0.55 + 0.05 * grain + 0.03 * fbm(rng, SIZE, 0.7)
    colour = paint * (1 - peel) + bare * peel
    colour = colour * (1 - 0.45 * shadow) * (1 - 0.5 * joints) - 0.05 * peel_edge
    rough = 0.72 * (1 - peel) + 0.95 * peel + 0.04 * runs
    height = 1.2 * t + 0.12 * grain * peel - 0.15 * peel - 0.6 * joints + 0.1 * peel_edge
    save_set("clapboard", colour, height, rough, 2.2)


def gravel():
    """The drive's gravel: rounded pebbles of many sizes, shapes and shades,
    packed close, a dark line where two meet and a gap here and there.
    Greyscale: tinted."""
    rng = rng_for("v4a_gravel")
    half = SIZE // 2
    n = 1000
    pts = rng.uniform(0, half, (n, 2))
    radius = rng.uniform(10.0, 16.0, n)
    ang = rng.uniform(0, math.pi, n)
    aspect = rng.uniform(1.0, 1.6, n)
    y, x = np.mgrid[0:half, 0:half].astype(np.float64)
    best = np.full((half, half), 1e9)
    second = np.full((half, half), 1e9)
    owner = np.zeros((half, half), dtype=np.int64)
    for i, (px, py) in enumerate(pts):
        dx, dy = wrap(x - px, half), wrap(y - py, half)
        c, s_ = math.cos(ang[i]), math.sin(ang[i])
        d = np.hypot((dx * c + dy * s_) / aspect[i], -dx * s_ + dy * c) / radius[i]
        closer = d < best
        second = np.where(closer, best, np.minimum(second, d))
        owner = np.where(closer, i, owner)
        best = np.where(closer, d, best)
    meet = 1 - smooth(0.0, 0.12, second - best)
    stone = smooth(1.0, 0.85, best) * (1 - 0.85 * meet)
    dome = np.sqrt(np.clip(1 - best * best, 0, 1))
    shade = rng.uniform(0.55, 1.0, n)[owner]

    def up(a):
        return np.kron(a, np.ones((2, 2)))

    stone, shade, dome = up(stone), up(shade), up(dome)
    sp = blur(rng.standard_normal((SIZE, SIZE)), 0.7)
    colour = (shade * (0.7 + 0.3 * dome) + 0.03 * sp / sp.std()) * stone + 0.14 * (1 - stone)
    rough = (0.78 - 0.06 * dome) * stone + 0.96 * (1 - stone)
    height = dome * stone - 0.3 * (1 - stone)
    save_set("gravel", blur(colour, 0.5), blur(height, 0.7), rough, 3.2)


def light_shaft():
    """Light in the air, for Beams (moonlight through a window, another
    player's torch): drawn additively, black is no light. Roblox lays a
    Beam's image with its height along the beam and its width across it
    (found in Studio, 2026-10-15: an image soft across its height came out
    soft at the ends and hard down the sides). Across (the width): a soft
    core that scatters away to nothing at both sides, the window's bars as
    faint blurred shadows in the haze. Along (the height): long faint
    streaks and patches, as light through dusty air. The Beam's own
    transparency fades it along its length."""
    rng = rng_for("v4a_light_shaft_2")
    w, h = 256, 512
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float64)
    u = (xx + 0.5) / w * 2 - 1
    core = np.exp(-((u / 0.42) ** 2))
    halo = np.exp(-((u / 0.8) ** 2)) * (1 - smooth(0.75, 1.0, np.abs(u)))
    across = 0.65 * core + 0.45 * halo
    bars = np.zeros_like(u)
    for c in (-0.34, 0.34):
        bars += np.exp(-(((u - c) / 0.07) ** 2))
    across *= 1 - 0.16 * bars
    st = fbm(rng, 512, 1.2, stretch=(1.0, 14.0))[:h, :w]
    patches = fbm(rng, 512, 2.2)[:h, :w]
    light = across * (0.84 + 0.12 * st + 0.06 * patches)
    light = np.clip(light / light.max(), 0, 1)
    save(Image.fromarray((light * 255 + 0.5).astype(np.uint8), "L").convert("RGB"), "light_shaft")


SURFACES = {
    "wood_floor": wood_floor,
    "wood_panel": wood_panel,
    "plaster": plaster,
    "popcorn": popcorn,
    "wallpaper_sprig": wallpaper_sprig,
    "wallpaper_stripe": wallpaper_stripe,
    "carpet": carpet,
    "linoleum": linoleum,
    "hex_tile": hex_tile,
    "concrete": concrete,
    "brick": brick,
    "rough_boards": rough_boards,
    "bath_tile": bath_tile,
    "flagstone": flagstone,
    "quarry_tile": quarry_tile,
    "clapboard": clapboard,
    "gravel": gravel,
    "light_shaft": light_shaft,
}


if __name__ == "__main__":
    names = sys.argv[1:] or list(SURFACES)
    for n in names:
        SURFACES[n]()
