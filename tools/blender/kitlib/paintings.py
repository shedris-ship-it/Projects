"""The house's paintings (the visual rework V4d): four old landscapes in oils,
drawn here stroke by stroke and aged under yellowed varnish and craquelure.
Hung in the halls of a 1988 house: reproductions of 19th-century pictures,
gone dark. Each function returns an h x w x 3 picture (0-1 sRGB).

A painting is composed first as flat masses (sky, hills, water, trees), then
painted over with strokes that each pick up the colour beneath, a little off
in value and warmth, and run along the form (across the sky and water, up a
tree, along a hill): broad ones over a softened picture, then small ones
where the edges are, then glazed, cracked and darkened at the edges as an old
picture is.
"""

import math

import numpy as np

H, W = 792, 1024  # the canvas's 4.4 x 3.4 studs


def _grid(h=H, w=W):
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float64)
    return xx / w, yy / h  # 0-1 across and down


def _noise(rng, cell, h=H, w=W, cell_y=None):
    """Smooth value noise, about one bump per `cell` pixels across (and
    `cell_y` down, if given), -1..1."""
    cy = cell_y or cell
    gh, gw = int(h // cy) + 2, int(w // cell) + 2
    g = rng.uniform(-1, 1, (gh, gw))
    y = np.arange(h) / cy
    x = np.arange(w) / cell
    y0, x0 = np.floor(y).astype(int), np.floor(x).astype(int)
    fy, fx = y - y0, x - x0
    fy = fy * fy * (3 - 2 * fy)
    fx = fx * fx * (3 - 2 * fx)
    a = g[y0][:, x0]
    b = g[y0][:, x0 + 1]
    c = g[y0 + 1][:, x0]
    d = g[y0 + 1][:, x0 + 1]
    top = a + (b - a) * fx[None, :]
    bot = c + (d - c) * fx[None, :]
    return top + (bot - top) * fy[:, None]


def _fbm(rng, cell, octaves=4, h=H, w=W, squash=1.0):
    """Layered noise; `squash` < 1 stretches it across (cloud banks, water)."""
    out = np.zeros((h, w))
    amp, total = 1.0, 0.0
    for _ in range(octaves):
        out += amp * _noise(rng, max(2, cell), h, w, max(2, cell * squash))
        total += amp
        amp *= 0.5
        cell /= 2
    return out / total


def _line(rng, base, amp, cell, w=W):
    """A wandering horizon (one height per column, 0-1 down the canvas)."""
    n = _noise(rng, cell, 1, w)[0]
    n2 = _noise(rng, max(2, cell // 4), 1, w)[0]
    return base + amp * n + amp * 0.25 * n2


def _rgb(c):
    return np.array(c, dtype=np.float64) / 255.0


def _mix(img, mask, colour):
    m = np.clip(mask, 0, 1)[..., None]
    return img * (1 - m) + np.asarray(colour) * m


def _gradient(v, stops):
    """A colour per pixel from v (0-1) through stops [(pos, rgb 0-255)]."""
    out = np.zeros(v.shape + (3,))
    pos = [p for p, _ in stops]
    cols = [_rgb(c) for _, c in stops]
    for ch in range(3):
        out[..., ch] = np.interp(v, pos, [c[ch] for c in cols])
    return out


def _blur(img, r):
    """A box blur r pixels each way (twice, so it's soft)."""
    out = img
    for _ in range(2):
        pad = np.pad(out, ((r + 1, r), (r + 1, r), (0, 0)), mode="edge")
        c = pad.cumsum(0)
        out = (c[2 * r + 1 :] - c[: -2 * r - 1]) / (2 * r + 1)
        c = out.cumsum(1)
        out = (c[:, 2 * r + 1 :] - c[:, : -2 * r - 1]) / (2 * r + 1)
    return out


def _window(h, w, cx, cy, r):
    y0, y1 = int(max(0, cy - r - 1)), int(min(h, cy + r + 2))
    x0, x1 = int(max(0, cx - r - 1)), int(min(w, cx + r + 2))
    return y0, y1, x0, x1


def _tree(img, angle, rng, x, base_y, height, width, colour, kind="round", light=None):
    """A tree on img (and its strokes' direction on angle: up the trunk and
    round the crown): a trunk and a crown of many leafy clumps, lit from one
    side (`light`, a colour), or bare forking branches."""
    h, w = img.shape[:2]
    px, py = x * w, base_y * h
    th = height * h
    trunk_w = max(2.0, width * w * 0.06)

    def dab(bx, by, r, a, col):
        r = max(0.8, r)
        y0, y1, x0, x1 = _window(h, w, bx, by, r)
        if y0 >= y1 or x0 >= x1:
            return
        sy, sx = np.mgrid[y0:y1, x0:x1]
        m = (np.abs(sx - bx) < r + 0.5) & (np.abs(sy - by) < r + 0.5)
        img[y0:y1, x0:x1][m] = col
        angle[y0:y1, x0:x1][m] = -a

    def branch(x0, y0, a, length, thick, depth, col):
        steps = max(6, int(length / max(1.0, thick)))
        for i in range(steps):
            t = i / steps
            dab(x0 + math.cos(a) * length * t, y0 - math.sin(a) * length * t, thick * (1 - 0.6 * t), a, col)
        if depth > 0:
            ex = x0 + math.cos(a) * length
            ey = y0 - math.sin(a) * length
            for da in (-0.5, 0.45):
                branch(ex, ey, a + da + rng.uniform(-0.15, 0.15), length * 0.62, thick * 0.6, depth - 1, col)

    if kind == "round":
        # The trunk and a few limbs into the crown.
        branch(px, py, math.pi / 2, th * 0.5, trunk_w, 0, colour * 0.6)
        for a0 in (math.pi / 2 - 0.6, math.pi / 2 + 0.5):
            branch(px, py - th * 0.38, a0, th * 0.25, trunk_w * 0.6, 1, colour * 0.6)
        # The crown: clumps scattered over an oval, darker below, lit on one side.
        cx0, cy0 = px, py - th * 0.7
        rx, ry = width * w * 0.5, th * 0.32
        for k in range(46):
            a = rng.uniform(0, math.tau)
            rad = math.sqrt(rng.uniform(0, 1))
            cx = cx0 + math.cos(a) * rad * rx
            cy = cy0 + math.sin(a) * rad * ry * (0.8 if math.sin(a) < 0 else 1.0)
            r = rx * rng.uniform(0.16, 0.3)
            y0, y1, x0, x1 = _window(h, w, cx, cy, r * 1.4)
            sy, sx = np.mgrid[y0:y1, x0:x1].astype(np.float64)
            d = np.hypot((sx - cx) / r, (sy - cy) / (r * 0.8)) + 0.3 * rng.uniform(-1, 1, sx.shape) * 0.3
            blob = d < 1.0
            lit = np.clip(((cx - cx0) / rx) * (1 if light is not None else 0) * 0.5 + 0.5 - (cy - cy0) / ry * 0.4, 0, 1)
            col = colour * (0.75 + 0.35 * lit)
            if light is not None:
                col = col * (1 - 0.25 * lit) + np.asarray(light) * 0.25 * lit
            img[y0:y1, x0:x1][blob] = col
            angle[y0:y1, x0:x1][blob] = np.arctan2(sy[blob] - cy, sx[blob] - cx) + math.pi / 2
    else:
        branch(px, py, math.pi / 2, th * 0.5, trunk_w, 0, colour)
        for a0 in (math.pi / 2 - 0.5, math.pi / 2, math.pi / 2 + 0.55):
            branch(px, py - th * 0.45, a0 + rng.uniform(-0.1, 0.1), th * 0.42, trunk_w * 0.8, 3, colour * 1.1)


def _stamps(sizes):
    """Brush stamps for each (length, width) in 16 directions: soft at the
    ends, streaked along by the bristles."""
    stamps = {}
    for si, (length, width) in enumerate(sizes):
        r = int(length / 2 + 2)
        yy, xx = np.mgrid[-r : r + 1, -r : r + 1].astype(np.float64)
        for ai in range(16):
            a = ai * math.pi / 16
            u = xx * math.cos(a) + yy * math.sin(a)
            v = -xx * math.sin(a) + yy * math.cos(a)
            d = (u / (length / 2)) ** 2 + (v / (width / 2)) ** 2
            alpha = np.clip((1 - d) * 3.0, 0, 1)
            alpha *= 0.55 + 0.45 * np.sin(v * 2.2 + si * 1.7) ** 2
            stamps[(si, ai)] = (r, alpha)
    return stamps


def _pass(out, base, angle, rng, count, sizes, jitter, where=None):
    h, w = base.shape[:2]
    stamps = _stamps(sizes)
    if where is None:
        ys = rng.integers(0, h, count)
        xs = rng.integers(0, w, count)
    else:
        # Strokes where `where` is high (the edges): sampled by its weight.
        p = where.ravel() / where.sum()
        idx = rng.choice(h * w, size=count, p=p)
        ys, xs = idx // w, idx % w
    size_of = rng.integers(0, len(sizes), count)
    value = rng.normal(1.0, jitter, count)
    warm = rng.normal(0.0, jitter * 0.35, count)
    for k in range(count):
        y, x = ys[k], xs[k]
        a = angle[y, x] % math.pi
        ai = int(round(a / (math.pi / 16))) % 16
        r, alpha = stamps[(size_of[k], ai)]
        y0, y1 = max(0, y - r), min(h, y + r + 1)
        x0, x1 = max(0, x - r), min(w, x + r + 1)
        al = alpha[y0 - (y - r) : y1 - (y - r), x0 - (x - r) : x1 - (x - r)][..., None] * 0.9
        colour = base[y, x] * value[k] + np.array((warm[k], warm[k] * 0.3, -warm[k]))
        out[y0:y1, x0:x1] = out[y0:y1, x0:x1] * (1 - al) + colour * al
    return out


def _paint(img, angle, rng, broad, fine, jitter=0.1):
    """Paints the picture: broad strokes over a softened copy (they blend its
    masses as a brush does), then fine ones along its edges, from the sharp
    one."""
    soft = _blur(img, 3)
    out = soft.copy()
    _pass(out, soft, angle, rng, broad, [(30, 8), (22, 7), (16, 5)], jitter)
    gy, gx = np.gradient(img.mean(axis=-1))
    edges = np.hypot(gx, gy)
    edges = _blur(edges[..., None], 2)[..., 0] + 0.002
    _pass(out, img, angle, rng, fine, [(11, 3), (7, 2.5)], jitter * 0.6, where=edges)
    return np.clip(out, 0, 1)


def _age(img, rng, varnish=(0.86, 0.74, 0.5), dark=0.82):
    """Old varnish (a yellow-brown glaze that dims the blues), edges darkened
    under the frame's shadow, a canvas weave, and fine craquelure in
    patches."""
    h, w = img.shape[:2]
    u, v = _grid(h, w)
    img = img * np.array(varnish) * dark
    blotch = _fbm(rng, 180, 3, h, w)
    img *= (0.92 + 0.08 * blotch)[..., None]
    edge = np.minimum(np.minimum(u, 1 - u) * (w / h), np.minimum(v, 1 - v))
    img *= (0.7 + 0.3 * np.clip(edge / 0.2, 0, 1) ** 0.7)[..., None]
    yy, xx = np.mgrid[0:h, 0:w]
    weave = 0.965 + 0.035 * (np.sin(xx * 1.9) * np.sin(yy * 1.9))
    img *= weave[..., None]
    # Craquelure: the edges of a jittered cell pattern, warped so it isn't a
    # net, thin, and only where the noise says.
    cell = 15
    wy = yy + _noise(rng, 40, h, w) * 6
    wx = xx + _noise(rng, 40, h, w) * 6
    gh, gw = h // cell + 3, w // cell + 3
    seeds = (np.mgrid[0:gh, 0:gw].transpose(1, 2, 0) - 1 + rng.uniform(0.0, 1.0, (gh, gw, 2))) * cell
    cy = np.clip((wy // cell).astype(int) + 1, 1, gh - 2)
    cx = np.clip((wx // cell).astype(int) + 1, 1, gw - 2)
    best = np.full((h, w), 1e9)
    second = np.full((h, w), 1e9)
    for dy in (-1, 0, 1):
        for dx in (-1, 0, 1):
            s = seeds[cy + dy, cx + dx]
            d = np.hypot(wy - s[..., 0], wx - s[..., 1])
            second = np.where(d < best, best, np.minimum(second, d))
            best = np.minimum(best, d)
    crack = np.clip(1 - (second - best) / 0.9, 0, 1)
    crack *= np.clip(_fbm(rng, 110, 3, h, w) * 2.2 - 0.1, 0, 1)
    img *= (1 - 0.22 * crack)[..., None]
    return np.clip(img, 0, 1)


def evening_hills(seed=11):
    """Evening over rolling hills: a warm sky low and a grey-blue one high,
    banks of cloud, three ranges of hills going blue with distance, a white
    farmhouse with a lit window, a lone oak on the near hill."""
    rng = np.random.default_rng(seed)
    u, v = _grid()
    sky = _gradient(v, [(0.0, (66, 80, 100)), (0.3, (126, 122, 116)), (0.48, (200, 152, 96)), (0.58, (222, 176, 112))])
    clouds = np.clip(_fbm(rng, 260, 5, squash=0.35) * 1.8 - 0.05, 0, 1) * np.clip((0.5 - v) * 6, 0, 1)
    cloud_col = _gradient(v, [(0.0, (92, 96, 104)), (0.45, (170, 130, 104))])
    img = sky * (1 - clouds[..., None] * 0.7) + cloud_col * clouds[..., None] * 0.7
    angle = np.zeros((H, W))
    ranges = [((96, 108, 118), 0.55, 0.025), ((84, 96, 76), 0.62, 0.035), ((66, 76, 46), 0.71, 0.05)]
    for c, base, amp in ranges:
        line = _line(rng, base, amp, 280)
        mask = v > line[None, :]
        depth = np.clip((v - line[None, :]) * 5, 0, 1)
        col = _rgb(c)[None, None, :] * (1 - 0.22 * depth[..., None])
        img = np.where(mask[..., None], col, img)
        slope = np.gradient(line) * H / W
        angle = np.where(mask, -np.arctan(slope)[None, :], angle)
    near = _line(rng, 0.8, 0.05, 320)
    mask = v > near[None, :]
    fore = _rgb((58, 62, 30)) * (1 - 0.45 * np.clip((v - 0.8) * 4, 0, 1))[..., None]
    fore *= (0.9 + 0.12 * _fbm(rng, 30, 3))[..., None]
    img = np.where(mask[..., None], fore, img)
    path_x = 0.42 + 0.07 * np.sin((1 - v) * 9)
    pm = (np.abs(u - path_x) < 0.006 + (v - 0.8) * 0.1) & mask
    img[pm] = _rgb((132, 116, 82)) * (0.85 + 0.2 * rng.random((pm.sum(), 1)))
    hx = 0.3
    hy = _line(np.random.default_rng(seed + 1), 0.63, 0.0, 280)[int(hx * W)] + 0.005
    house = (np.abs(u - hx) < 0.032) & (v < hy) & (v > hy - 0.038)
    img[house] = _rgb((206, 194, 168))
    img[house & (u > hx + 0.012)] = _rgb((150, 140, 124))  # its shaded end
    roof = (v < hy - 0.038) & (v > hy - 0.038 - (0.042 - np.abs(u - hx)) * 0.65) & (np.abs(u - hx) < 0.042)
    img[roof] = _rgb((104, 50, 36))
    win = (np.abs(u - hx + 0.012) < 0.005) & (np.abs(v - (hy - 0.02)) < 0.007)
    img[win] = _rgb((255, 214, 130))
    _tree(img, angle, rng, 0.74, near[int(0.74 * W)] + 0.04, 0.42, 0.2, _rgb((44, 50, 24)), light=_rgb((200, 150, 80)))
    out = _paint(img, angle, rng, 22000, 16000)
    return _age(out, rng)


def stormy_coast(seed=23):
    """A storm coming in off the sea: heavy dark clouds with a break of pale
    light, a grey-green sea with whitecaps, a grassy headland ending in a
    cliff, a lighthouse on it whose lamp is lit, black rocks in front."""
    rng = np.random.default_rng(seed)
    u, v = _grid()
    sky = _gradient(v, [(0.0, (44, 48, 54)), (0.35, (86, 88, 90)), (0.5, (150, 146, 128))])
    clouds = _fbm(rng, 220, 5, squash=0.45)
    img = _mix(sky, np.clip(clouds * 1.6 + 0.25, 0, 1) * (v < 0.52), _rgb((38, 40, 44)))
    gap = np.exp(-(((u - 0.64) / 0.14) ** 2 + ((v - 0.37) / 0.045) ** 2)) * (0.7 + 0.3 * _fbm(rng, 40, 3))
    img = _mix(img, gap, _rgb((216, 206, 172)))
    # Rain falling from the dark on the right.
    rain = np.clip((u - 0.75) * 4, 0, 1) * (v < 0.52) * (np.sin(u * 600 + v * 120) > 0.6) * 0.25
    img = _mix(img, rain, _rgb((70, 72, 76)))
    angle = np.full((H, W), 0.12)
    horizon = 0.52
    sea = v > horizon
    depth = np.clip((v - horizon) / (1 - horizon), 0, 1)
    sea_col = _gradient(depth, [(0.0, (100, 110, 100)), (0.4, (60, 76, 68)), (1.0, (38, 50, 44))])
    sea_col *= (0.9 + 0.15 * _fbm(rng, 90, 3, squash=0.2))[..., None]
    img = np.where(sea[..., None], sea_col, img)
    # The light from the break, on the water under it.
    shine = np.exp(-(((u - 0.64) / 0.1) ** 2)) * np.clip(1 - depth * 2, 0, 1) * sea
    img = _mix(img, shine * 0.5, _rgb((180, 176, 150)))
    angle = np.where(sea, 0.0, angle)
    crest = _fbm(rng, 70, 3, squash=0.08)
    caps = sea & (crest > 0.56 - depth * 0.12)
    img = _mix(img, caps * 0.5, _rgb((186, 190, 176)))
    # The headland: grass on top, a rock face down into the sea.
    top = _line(rng, 0.42, 0.015, 220)
    x = np.arange(W) / W
    top = top + np.clip((x - 0.26) * 1.6, 0, None) ** 1.4
    cliff_foot = horizon + 0.12
    hm = (v > top[None, :]) & (v < cliff_foot + 0.03 * _noise(rng, 20)) & (u < 0.5)
    rock = _rgb((58, 56, 50)) * (0.75 + 0.35 * _fbm(rng, 18, 3))[..., None]
    grass = _rgb((64, 70, 40)) * (0.85 + 0.2 * _fbm(rng, 14, 3))[..., None]
    turf = (v < top[None, :] + 0.035)
    img = np.where((hm & turf)[..., None], grass, np.where(hm[..., None], rock, img))
    angle[hm] = math.pi / 2
    angle[hm & turf] = 0.2
    tx = 0.15
    ty = top[int(tx * W)] + 0.005
    tower = (np.abs(u - tx) < 0.014 + (v - (ty - 0.17)) * 0.03) & (v < ty) & (v > ty - 0.16)
    img[tower] = _rgb((210, 204, 188))
    img[tower & (u > tx + 0.004)] = _rgb((160, 156, 146))
    band = tower & (np.abs(v - (ty - 0.085)) < 0.012)
    img[band] = _rgb((150, 50, 40))
    cap = (np.abs(u - tx) < 0.02) & (np.abs(v - (ty - 0.195)) < 0.012)
    img[cap] = _rgb((40, 34, 30))
    lamp = (np.abs(u - tx) < 0.011) & (np.abs(v - (ty - 0.172)) < 0.011)
    img[lamp] = _rgb((255, 232, 160))
    glow = np.exp(-(((u - tx) / 0.05) ** 2 + ((v - (ty - 0.172)) / 0.035) ** 2))
    img = _mix(img, glow * 0.45, _rgb((240, 214, 150)))
    beam = np.clip(1 - np.abs((v - (ty - 0.172)) - (u - tx) * 0.12) / (0.008 + (u - tx) * 0.06), 0, 1) * (u > tx) * np.clip(1 - (u - tx) * 1.6, 0, 1)
    img = _mix(img, beam * 0.3, _rgb((230, 214, 160)))
    rocks = v > _line(rng, 0.9, 0.04, 70)[None, :]
    img[rocks] = _rgb((28, 28, 26)) * (0.8 + 0.4 * rng.random((rocks.sum(), 1)))
    angle[rocks] = 0.8
    out = _paint(img, angle, rng, 24000, 16000, jitter=0.12)
    return _age(out, rng)


def winter_wood(seed=37):
    """A winter wood at dusk: a pale grey sky, snow, a frozen pond holding
    the sky, bare black trees, a broken fence, one far light."""
    rng = np.random.default_rng(seed)
    u, v = _grid()
    sky = _gradient(v, [(0.0, (112, 118, 128)), (0.4, (174, 170, 164)), (0.6, (200, 186, 166))])
    sky *= (0.95 + 0.06 * _fbm(rng, 200, 4, squash=0.4))[..., None]
    img = sky.copy()
    angle = np.zeros((H, W))
    ground = _line(rng, 0.6, 0.015, 300)
    gm = v > ground[None, :]
    snow = _gradient(np.clip((v - 0.6) / 0.4, 0, 1), [(0.0, (176, 178, 182)), (1.0, (214, 214, 208))])
    snow *= (0.92 + 0.08 * _fbm(rng, 70, 3, squash=0.4))[..., None]
    img = np.where(gm[..., None], snow, img)
    angle = np.where(gm, 0.05, angle)
    far = (v > ground[None, :] - 0.06 - 0.035 * _noise(rng, 10)) & ~gm
    img = _mix(img, far * 0.75, _rgb((104, 104, 110)))
    angle = np.where(far, math.pi / 2, angle)
    pond = (((u - 0.56) / 0.25) ** 2 + ((v - 0.77) / 0.065) ** 2) < 1
    mirror_y = np.clip((2 * ground[(u * W).astype(int).clip(0, W - 1)] - v) * H, 0, H - 1).astype(int)
    refl = sky[mirror_y, (u * W).astype(int).clip(0, W - 1)] * 0.8 + 0.04
    img = np.where(pond[..., None], refl, img)
    rim = pond & ~((((u - 0.56) / 0.235) ** 2 + ((v - 0.77) / 0.055) ** 2) < 1)
    img[rim] = _rgb((150, 150, 150))
    for x, h_, wd in ((0.12, 0.55, 0.12), (0.27, 0.42, 0.1), (0.83, 0.6, 0.12), (0.93, 0.38, 0.08), (0.7, 0.3, 0.07)):
        _tree(img, angle, rng, x, ground[int(x * W)] + 0.03, h_, wd, _rgb((32, 30, 28)), kind="bare")
    for k in range(7):
        fx = 0.05 + k * 0.05
        fy = 0.72 + k * 0.025
        post = (np.abs(u - fx) < 0.004) & (v < fy) & (v > fy - 0.06 + (k % 3) * 0.012)
        img[post] = _rgb((54, 46, 40))
    rail = (np.abs(v - (0.69 + (u - 0.05) * 0.5)) < 0.003) & (u > 0.05) & (u < 0.24)
    img[rail] = _rgb((60, 52, 44))
    lx = 0.4
    light = np.exp(-(((u - lx) / 0.006) ** 2 + ((v - (ground[int(lx * W)] - 0.02)) / 0.005) ** 2))
    img = _mix(img, light, _rgb((255, 200, 120)))
    out = _paint(img, angle, rng, 20000, 16000, jitter=0.08)
    return _age(out, rng, varnish=(0.88, 0.8, 0.62))


def moonlit_lake(seed=53):
    """A lake under the moon: a deep blue-green night, the moon low in a
    haze, its broken path across the water, black pines on the far shore, a
    rowboat pulled up in the reeds."""
    rng = np.random.default_rng(seed)
    u, v = _grid()
    sky = _gradient(v, [(0.0, (14, 22, 30)), (0.4, (34, 50, 58)), (0.55, (60, 78, 82))])
    img = sky.copy()
    mx, my = 0.64, 0.3
    dist = np.hypot((u - mx) * W / H, v - my)
    img = _mix(img, np.exp(-((dist / 0.13) ** 2)) * 0.6, _rgb((122, 142, 136)))
    clouds = np.clip(_fbm(rng, 220, 4, squash=0.3) * 1.5 - 0.15, 0, 1) * (v < 0.5)
    lit_clouds = _mix(np.zeros_like(img) + _rgb((36, 50, 56)), np.exp(-((dist / 0.25) ** 2)), _rgb((110, 118, 108)))
    img = img * (1 - clouds[..., None] * 0.55) + lit_clouds * clouds[..., None] * 0.55
    img[dist < 0.034] = _rgb((228, 226, 198))
    angle = np.zeros((H, W))
    shore = 0.56
    x = np.arange(W) / W
    tops = np.abs(np.sin(x * 150 + _noise(rng, 8, 1, W)[0] * 3)) ** 0.6
    pines = shore - tops * 0.055 * (0.55 + 0.45 * _noise(rng, 60, 1, W)[0])
    pm = (v > pines[None, :]) & (v < shore + 0.012)
    img[pm] = _rgb((10, 16, 16))
    angle[pm] = math.pi / 2
    water = v >= shore + 0.012
    refl = sky[np.clip((2 * shore - v) * H, 0, H - 1).astype(int), np.clip(u * W, 0, W - 1).astype(int)] * 0.65
    img = np.where(water[..., None], refl, img)
    ripples = _fbm(rng, 140, 4, squash=0.06)
    spread = 0.02 + (v - shore) * 0.16
    path = water * np.exp(-(((u - mx) / spread) ** 2)) * np.clip(ripples * 2.2 + 0.25, 0, 1)
    img = _mix(img, path * 0.8, _rgb((206, 208, 184)))
    angle = np.where(water, 0.0, angle)
    reeds_line = 0.86 - 0.06 * np.abs(np.sin(x * 320)) * (0.5 + 0.5 * _noise(rng, 30, 1, W)[0])
    reeds = (v > reeds_line[None, :]) & (u < 0.38)
    img[reeds] = _rgb((26, 30, 20))
    angle[reeds] = math.pi / 2
    boat = (((u - 0.25) / 0.085) ** 2 + ((v - 0.875) / 0.02) ** 2 < 1) & (v > 0.872)
    img[boat] = _rgb((72, 48, 32))
    gunwale = boat & (v < 0.879)
    img[gunwale] = _rgb((120, 96, 70))
    out = _paint(img, angle, rng, 20000, 14000, jitter=0.09)
    return _age(out, rng, varnish=(0.84, 0.78, 0.6), dark=0.92)


PICTURES = [evening_hills, stormy_coast, winter_wood, moonlit_lake]
