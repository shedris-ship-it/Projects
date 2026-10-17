"""Hair (2026-10-17; docs/progress/2026-10-17-hair-faces/): eight 1980s
styles for the classic head, worn welded on the Head like the wardrobe's
pieces on their parts (layered clothing can't be scripted).

The Boy and the Girl share the head, and so do the six faces (Roblox's free
dynamic heads with the classic shape; Data/Wardrobe): a round cylinder 0.58
studs in radius and 0.592 from its middle to its top, its edges rounded at
0.3 (measured in Studio by casting rays at a precise copy of the mesh,
2026-10-17; the dynamic heads and the old classic head measure the same).

Every style is built the same way: a thin cap over the scalp (the roots;
its edge is the hairline, thinning to nothing there) and locks laid over it.
A lock is a tapered strand of hair with a rounded top and a flatter
underside, walked over the head from its root along the style's combing
(away from a parting, toward a ponytail, down), each step held at its
height over the scalp, so it lies on the head and never through it. Below
the head a lock hangs straight down, as hair does. The crew cut is the cap
alone; the perm a deep cap of curls.

Pieces are built in the Head's frame (x across, y up, z; the face is -z),
centred on the head's middle. Each lock carries two UV layers for the
material: "Flow" (studs across and along the lock: the strands run along
it) and "Lock" (how far along, 0 at the root; and the lock's own tone).
The scrunchies are pieces of their own (a SurfaceAppearance tints a whole
mesh, and the hair's colour is the player's choice).
"""

import math
import random

import bmesh
import bpy
from mathutils import Vector

from . import clothmats as cm
from . import materials, shapes

TAU = math.pi * 2
R = 0.58  # the head's radius
HT = 0.592  # its middle to its top (and bottom)
RHO = 0.30  # the rounding of its top and bottom edges
GAP = 0.010  # hair over the scalp, at least
EDGE = 0.007  # a cap's very edge comes this much closer (GAP - EDGE over the scalp)
BELOW = -(HT - RHO)  # under this the head rounds in; hair keeps falling straight


def G(p):
    """A point in the head's frame (x, y up, z; the face is -z) in Blender's
    (the kit's convention: the game's +z is Blender's -y)."""
    return Vector((p.x, -p.z, p.y))


def V(x, y, z):
    return Vector((x, y, z))


def smooth(t):
    t = max(0.0, min(1.0, t))
    return t * t * (3 - 2 * t)


# The head, and the surface hair lies on ----------------------------------------------


def head_sdf(p):
    """Distance from the head's surface (negative inside)."""
    r = math.hypot(p.x, p.z)
    qx = r - (R - RHO)
    qy = abs(p.y) - (HT - RHO)
    return min(max(qx, qy), 0.0) + math.hypot(max(qx, 0.0), max(qy, 0.0)) - RHO


def flare(y):
    """How far hair stands out past the head's side below its lower edge:
    it falls past the rounding and, lower, out over the collars."""
    return 0.11 * smooth((BELOW + 0.02 - y) / 0.5)


def guide_sdf(p):
    """The head, but below its lower edge's rounding a cylinder flaring out:
    hair falls past the rounding, it doesn't tuck under it."""
    if p.y < BELOW:
        return math.hypot(p.x, p.z) - (R + flare(p.y))
    return head_sdf(p)


def normal(p, f=guide_sdf):
    e = 1e-4
    n = V(
        f(p + V(e, 0, 0)) - f(p - V(e, 0, 0)),
        f(p + V(0, e, 0)) - f(p - V(0, e, 0)),
        f(p + V(0, 0, e)) - f(p - V(0, 0, e)),
    )
    if n.length < 1e-9:
        return V(0, 1, 0)
    return n.normalized()


def project(p, h, f=guide_sdf):
    """p moved onto the surface h studs over the guide."""
    q = p.copy()
    for _ in range(5):
        d = f(q) - h
        if abs(d) < 1e-6:
            break
        q = q - normal(q, f) * d
    return q


def profile(s):
    """The guide's outline in any upright plane through the head's axis, by
    length s from the crown: (r, y) and its outward normal (nr, ny). Over the
    flat top, round the edge, then straight down (and on past the head)."""
    a = R - RHO
    if s <= a:
        return s, HT, 0.0, 1.0
    s2 = s - a
    arc = RHO * math.pi / 2
    if s2 <= arc:
        ang = s2 / RHO
        nr, ny = math.sin(ang), math.cos(ang)
        return a + RHO * nr, (HT - RHO) + RHO * ny, nr, ny
    return R, (HT - RHO) - (s2 - arc), 1.0, 0.0


def s_at(y):
    """The length from the crown down the outline to height y."""
    a = R - RHO
    if y >= HT:
        return 0.0
    if y >= HT - RHO:
        ang = math.acos(max(-1.0, min(1.0, (y - (HT - RHO)) / RHO)))
        return a + RHO * ang
    return a + RHO * math.pi / 2 + (HT - RHO) - y


def around(theta, r, y):
    """A point at angle theta round the head (0 the face, +pi/2 the head's
    +x side), r out from its axis, at height y."""
    return V(r * math.sin(theta), y, -r * math.cos(theta))


def on_head(theta, s, h=0.0):
    """The point at (theta, s) on the outline, h over the guide (and the gap);
    below the head, out as far as the guide flares."""
    r, y, nr, ny = profile(s)
    d = GAP + h
    if y < BELOW:
        r += flare(y)
    return around(theta, r + nr * d, y + ny * d)


def nape(y):
    """0 above the collars' line, 1 below it: there a cap hugs the scalp,
    inside every collar's lip (kitlib/wardrobe neck_collar: the head plus
    half the layers' gap)."""
    return smooth((-0.29 - y) / 0.07)


def theta_of(p):
    return math.atan2(p.x, -p.z)


def periodic(points, theta):
    """A smooth closed curve through (angle from the face, value) points
    given for one side (0..pi), the other side its mirror."""
    a = abs(((theta + math.pi) % TAU) - math.pi)
    pts = sorted(points)
    for (a0, v0), (a1, v1) in zip(pts, pts[1:]):
        if a0 <= a <= a1:
            t = smooth((a - a0) / max(a1 - a0, 1e-6))
            return v0 + (v1 - v0) * t
    return pts[-1][1] if a > pts[-1][0] else pts[0][1]


# The hairline every style's cap ends at (angle from the face, height): up
# off the forehead, turning straight down at the temple (the classic head
# has no ears: the hair covers its sides), down to the nape, which stays
# above the tallest collars' tops (they hug the head under there).
HAIRLINE = [(0.0, 0.37), (0.62, 0.35), (0.86, 0.32), (0.98, 0.12), (1.10, -0.10), (1.60, -0.15), (2.20, -0.22), (2.70, -0.33), (math.pi, -0.38)]


def head_mesh(name, K=72, steps=14):
    """The classic head itself (for previews and checks; never exported):
    its outline turned round its axis, in Blender's frame, its middle at the
    origin."""
    outline = [(0.0, -HT)]
    a = R - RHO
    for i in range(steps + 1):
        ang = -math.pi / 2 + (math.pi / 2) * i / steps
        outline.append((a + RHO * math.cos(ang), -(HT - RHO) + RHO * math.sin(ang)))
    for i in range(steps + 1):
        ang = (math.pi / 2) * i / steps
        outline.append((a + RHO * math.cos(ang), (HT - RHO) + RHO * math.sin(ang)))
    outline.append((0.0, HT))
    bm = bmesh.new()
    rings = []
    for r, y in outline:
        if r < 1e-6:
            rings.append([bm.verts.new(G(V(0, y, 0)))])
            continue
        rings.append([bm.verts.new(G(around(TAU * k / K, r, y))) for k in range(K)])
    for i in range(len(rings) - 1):
        lo, hi = rings[i], rings[i + 1]
        for k in range(K):
            if len(lo) == 1:
                bm.faces.new((lo[0], hi[(k + 1) % K], hi[k]))
            elif len(hi) == 1:
                bm.faces.new((lo[k], lo[(k + 1) % K], hi[0]))
            else:
                bm.faces.new((lo[k], lo[(k + 1) % K], hi[(k + 1) % K], hi[k]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    obj = shapes._object(name, bm)
    for p in obj.data.polygons:
        p.use_smooth = True
    return obj


# Building meshes ------------------------------------------------------------------


class Mesh:
    """A bmesh with the hair's two UV layers, built into one object."""

    def __init__(self, name):
        self.name = name
        self.bm = bmesh.new()
        self.flow = self.bm.loops.layers.uv.new("Flow")
        self.lock = self.bm.loops.layers.uv.new("Lock")

    def face(self, verts, uvs):
        """uvs: per vertex ((u, v) flow, (t, tone) lock)."""
        try:
            f = self.bm.faces.new(verts)
        except ValueError:
            return None
        for loop, (fl, lk) in zip(f.loops, uvs):
            loop[self.flow].uv = fl
            loop[self.lock].uv = lk
        return f

    def build(self, smooth_angle=60):
        bmesh.ops.remove_doubles(self.bm, verts=self.bm.verts, dist=1e-6)
        bmesh.ops.recalc_face_normals(self.bm, faces=self.bm.faces)
        obj = shapes._object(self.name, self.bm)
        shapes.smooth(obj, smooth_angle)
        obj["part"] = "Head"
        return obj


def cap(m, hem, thick, K=72, I=20, tone=0.5, inner=False, bump=None, hem_lip=0.0):
    """The scalp's cover: from the crown down every angle to `hem(theta)`
    (a height), `thick(theta, t)` studs over the head (t: 0 crown, 1 hem);
    thinning to nothing at the hem unless `inner` (then it's closed by an
    inside surface on the scalp and a rounded lip: for hair that stands off
    the head, the perm). `bump(p)` adds studs outward (curls)."""
    bm = m.bm
    rows = []
    s_hems = []
    for k in range(K):
        th = TAU * k / K
        s_hems.append(s_at(hem(th)))
    crown = None
    for i in range(I + 1):
        t = i / I
        row = []
        for k in range(K):
            th = TAU * k / K
            s = s_hems[k] * t
            h = thick(th, t)
            sink = 0.0
            if not inner:
                h *= smooth((1.0 - t) / 0.12)
                # (The very edge down onto the scalp: no gap under it for a
                # glancing look to slip into.)
                sink = EDGE * (1.0 - smooth((1.0 - t) / 0.06))
            p = on_head(th, s, h - sink)
            if not inner and p.y < BELOW:
                k = nape(p.y)
                p = project(p, GAP + h * (1 - k) - max(0.006 * k, sink), head_sdf)
            if bump is not None:
                p = p + normal(p) * bump(p, th, t)
            if i == 0:
                if crown is None:
                    crown = bm.verts.new(G(p))
                row.append(crown)
            else:
                row.append(bm.verts.new(G(p)))
        rows.append(row)

    def uv(k, i):
        s = s_hems[k % K] * i / I
        return ((k / K) * TAU * 0.6, s), (i / I, tone)

    for i in range(I):
        for k in range(K):
            k1 = k + 1
            a, b = rows[i][k], rows[i][k1 % K]
            c, d = rows[i + 1][k1 % K], rows[i + 1][k]
            if i == 0:
                m.face([a, d, c], [uv(k, 0), uv(k, 1), uv(k1, 1)])
            else:
                m.face([a, d, c, b], [uv(k, i), uv(k, i + 1), uv(k1, i + 1), uv(k1, i)])
    if inner:
        # The inside: from the lip back up to the scalp at the hairline's
        # height, then over the scalp to the crown (seldom seen).
        lip = []
        last = rows[-1]
        for k in range(K):
            th = TAU * k / K
            s = s_hems[k]
            h = thick(th, 1.0)
            outer = on_head(th, s, h)
            if bump is not None:
                outer = outer + normal(outer) * bump(outer, th, 1.0)
            base = on_head(th, s, 0.0)
            # A rounded lip: past the middle of the edge the way the hair
            # falls there (down the outline: straight down only where the
            # hairline runs level; by the face it runs steeply).
            r0, y0, _, _ = profile(max(s - 0.05, 0.0))
            r1, y1, _, _ = profile(s)
            fall = around(th, r1, y1) - around(th, r0, y0)
            fall = fall.normalized() if fall.length > 1e-6 else V(0, -1, 0)
            mid = (outer + base) * 0.5 + fall * min(hem_lip, (outer - base).length * 0.35)
            lip.append((bm.verts.new(G(mid)), bm.verts.new(G(base))))
        inner_rows = [[v for _, v in lip]]
        steps = max(4, I // 3)
        for j in range(1, steps + 1):
            t = 1.0 - j / steps
            row = []
            for k in range(K):
                th = TAU * k / K
                row.append(bm.verts.new(G(on_head(th, s_hems[k] * t, 0.0))))
            inner_rows.append(row)
        for k in range(K):
            k1 = (k + 1) % K
            m.face([last[k], lip[k][0], lip[k1][0], last[k1]], [uv(k, I), uv(k, I), uv(k + 1, I), uv(k + 1, I)])
            m.face([lip[k][0], lip[k][1], lip[k1][1], lip[k1][0]], [uv(k, I), uv(k, I), uv(k + 1, I), uv(k + 1, I)])
        for j in range(steps):
            for k in range(K):
                k1 = (k + 1) % K
                m.face(
                    [inner_rows[j][k], inner_rows[j + 1][k], inner_rows[j + 1][k1], inner_rows[j][k1]],
                    [uv(k, I), uv(k, I), uv(k + 1, I), uv(k + 1, I)],
                )


def walk(root, d0, length, flow, lift=lambda t: 0.0, n=14, stiff=0.45, free=None):
    """A lock's middle line: from `root` (on the head), first toward d0,
    then turning toward `flow(p, t)` (stiffness: how much each step turns),
    held `lift(t)` over the scalp. Past `free` (a share of its length) it
    leaves the surface and falls as the flow says, kept off the head."""
    p = project(root, GAP + lift(0.0))
    d = d0.normalized()
    pts, ns = [p], [normal(p)]
    ds = length / n
    for i in range(1, n + 1):
        t = i / n
        target = flow(p, t)
        if target.length > 1e-9:
            d = (d * (1.0 - stiff) + target.normalized() * stiff).normalized()
        if free is None or t <= free:
            nrm = normal(p)
            d = d - nrm * d.dot(nrm)
            if d.length < 1e-6:
                d = V(0, -1, 0) - nrm * (-nrm.y)
            d = d.normalized()
            p = project(p + d * ds, GAP + lift(t))
        else:
            p = p + d * ds
            out = guide_sdf(p) - (GAP + lift(t))
            if out < 0:
                p = p - normal(p) * out
        pts.append(p)
        ns.append(normal(p))
    return pts, ns


def strand(m, pts, ns, width, thick, sides=6, tone=0.5, under=0.35):
    """A lock along pts: `width(t)` across, `thick(t)` deep (the rounded top
    away from the head, the underside flatter by `under`), its tip a point."""
    n = len(pts)
    rings = []
    length = 0.0
    alongs = [0.0]
    for i in range(1, n):
        length += (pts[i] - pts[i - 1]).length
        alongs.append(length)
    for i in range(n - 1):
        p = pts[i]
        a, b = pts[max(i - 1, 0)], pts[min(i + 1, n - 1)]
        T = (b - a).normalized()
        N = ns[i] - T * ns[i].dot(T)
        if N.length < 1e-6:
            N = V(0, 0, 1)
        N.normalize()
        B = T.cross(N).normalized()
        t = i / (n - 1)
        w, th = width(t), thick(t)
        ring = []
        for k in range(sides):
            ang = TAU * k / sides
            c, s = math.cos(ang), math.sin(ang)
            off = B * (c * w / 2) + N * (s * th / 2 * (1.0 if s > 0 else under) + th * 0.25)
            ring.append(m.bm.verts.new(G(p + off)))
        rings.append(ring)
    tip = m.bm.verts.new(G(pts[-1]))
    wmid = width(0.3)

    def uv(k, i):
        return ((k / sides) * wmid, alongs[i]), (i / (n - 1), tone)

    for i in range(n - 2):
        for k in range(sides):
            k1 = k + 1
            m.face(
                [rings[i][k], rings[i][k1 % sides], rings[i + 1][k1 % sides], rings[i + 1][k]],
                [uv(k, i), uv(k1, i), uv(k1, i + 1), uv(k, i + 1)],
            )
    last = rings[-1]
    for k in range(sides):
        k1 = k + 1
        m.face([last[k], last[k1 % sides], tip], [uv(k, n - 2), uv(k1, n - 2), uv(k + 0.5, n - 1)])
    # The root, closed (it's under the cap or in the scrunchie).
    m.face(list(reversed(rings[0])), [uv(sides - k, 0) for k in range(sides)])


def taper(w0, w1=None, tip=0.85, end=0.7):
    """A lock's width: w0 at the root, swelling to w1, narrowing from `tip`
    of the way along to its end (`end`: lower is blunter)."""
    w1 = w0 if w1 is None else w1

    def f(t):
        base = w0 + (w1 - w0) * smooth(t / 0.35)
        if t > tip:
            base *= max(0.0, 1.0 - (t - tip) / (1.0 - tip)) ** end
        return max(base, 0.002)

    return f


def lock(m, rng, root, d0, length, flow, w, th, lift=None, n=None, stiff=0.45, free=None, sides=6, tip=0.8):
    """One lock: walked, then built (tone: a little lighter or darker). Its
    root starts thin and sunk into the cap (no row of roots showing), its
    end blunt-ish; a step every 0.09 studs or so."""
    lift = lift or (lambda t: 0.0)
    sunk = lambda t: lift(t) - th * 0.55 * (1.0 - smooth(t / 0.18))
    if n is None:
        n = max(7, min(16, int(length / 0.09)))
    pts, ns = walk(root, d0, length, flow, sunk, n=n, stiff=stiff, free=free)
    strand(m, pts, ns, taper(w * 0.18, w, tip=tip, end=0.4), taper(th * 0.15, th, tip=tip + (1 - tip) * 0.4, end=0.5), sides=sides, tone=rng.uniform(0.2, 0.8))
    return pts


# Combing --------------------------------------------------------------------------

DOWN = V(0, -1, 0)


def away_from(a, b, down=0.4, fwd_guard=True):
    """Combed away from the parting a-b (a segment over the top), falling."""

    def f(p, t):
        ab = b - a
        u = max(0.0, min(1.0, (p - a).dot(ab) / max(ab.dot(ab), 1e-9)))
        c = a + ab * u
        d = p - c
        d.y = 0.0
        if d.length < 1e-6:
            return DOWN
        side = d.normalized()
        out = side + DOWN * (down + 1.6 * t)
        if fwd_guard:
            out = guard_face(p, out)
        return out

    return f


def guard_face(p, d):
    """Keeps hair off the face: over the forehead, it goes sideways rather
    than down; past the temples it may fall."""
    th = theta_of(p)
    if abs(th) < 0.85 and p.y < 0.44 and p.y > -0.2:
        side = V(math.copysign(1.0, p.x if abs(p.x) > 1e-4 else 1.0), 0, 0)
        k = smooth((0.85 - abs(th)) / 0.25)
        d = d * (1 - k) + (side + V(0, 0.15, 0)) * k
    return d


def toward(c, pull=1.0):
    def f(p, t):
        d = c - p
        return d.normalized() * pull if d.length > 1e-6 else DOWN

    return f


def falling(lean=V(0, 0, 0)):
    def f(p, t):
        return DOWN + lean

    return f


# Materials ------------------------------------------------------------------------

TINT_SKETCH = (96, 62, 38)  # a mid brown for builds that aren't told a colour


def hair_material(name, tint=(255, 255, 255), kind="straight"):
    """Strands along each lock (the "Flow" UV), darker at the roots and in
    the cap (the "Lock" UV), each lock its own tone. The colour is a light
    grey times `tint` (the game tints the grey map: SurfaceAppearance.Color).
    `kind`: "straight", "short" (a crew cut's bristles) or "curly" (a perm's
    curls, in the object's space)."""
    mat = bpy.data.materials.new(name)
    n = materials.Nodes(mat)
    flow = n.add("ShaderNodeUVMap")
    flow.uv_map = "Flow"
    lk = n.add("ShaderNodeUVMap")
    lk.uv_map = "Lock"
    if kind == "curly":
        # Curls: wave bands warped hard into squiggles, two scales over each
        # other, in the object's space (a perm has no single direction).
        m0 = n.add("ShaderNodeMapping")
        n.link(n.coord.outputs["Object"], m0.inputs["Vector"])
        waves = []
        for scale, distortion, kind_ in ((38.0, 16.0, "BANDS"), (22.0, 11.0, "RINGS")):
            w = n.add("ShaderNodeTexWave", wave_type=kind_)
            w.inputs["Scale"].default_value = scale
            w.inputs["Distortion"].default_value = distortion
            w.inputs["Detail"].default_value = 3.0
            w.inputs["Detail Scale"].default_value = 1.6
            n.link(m0.outputs["Vector"], w.inputs["Vector"])
            waves.append(w)
        strands = n.math("MULTIPLY_ADD", waves[0].outputs["Fac"], 0.55, n.math("MULTIPLY", waves[1].outputs["Fac"], 0.45).outputs["Value"])
        bump_strength, bump_dist = 0.6, 0.006
    else:
        sx, sy = (190.0, 7.0) if kind == "straight" else (420.0, 90.0)
        m1 = n.add("ShaderNodeMapping")
        m1.inputs["Scale"].default_value = (sx, sy, 1.0)
        n.link(flow.outputs["UV"], m1.inputs["Vector"])
        s1 = n.noise(m1.outputs["Vector"], 1.0, 3.0, 0.55)
        m2 = n.add("ShaderNodeMapping")
        m2.inputs["Scale"].default_value = (sx * 2.7, sy * 2.0, 1.0)
        n.link(flow.outputs["UV"], m2.inputs["Vector"])
        s2 = n.noise(m2.outputs["Vector"], 1.0, 2.0, 0.5)
        strands = n.math("MULTIPLY_ADD", s1.outputs["Fac"], 0.65, n.math("MULTIPLY", s2.outputs["Fac"], 0.35).outputs["Value"])
        bump_strength, bump_dist = (0.45, 0.004) if kind == "straight" else (0.6, 0.003)
    sep = n.add("ShaderNodeSeparateXYZ")
    n.link(lk.outputs["UV"], sep.inputs["Vector"])
    # Roots darker (the first fifth of a lock, the cap), tips a shade lighter.
    ramp_root = n.ramp(sep.outputs["X"], [(0.0, (0.62, 0.62, 0.62, 1)), (0.22, (0.92, 0.92, 0.92, 1)), (1.0, (1.0, 1.0, 1.0, 1))])
    tone = n.math("MULTIPLY_ADD", sep.outputs["Y"], 0.24, 0.88)
    grey = n.ramp(strands.outputs["Value"], [(0.25, (0.58, 0.58, 0.58, 1)), (0.75, (0.92, 0.92, 0.92, 1))])
    shade = n.mix_colour(grey.outputs["Color"], ramp_root.outputs["Color"], 1.0, blend="MULTIPLY")
    tone_rgb = n.add("ShaderNodeCombineXYZ")
    for ax in ("X", "Y", "Z"):
        n.link(tone.outputs["Value"], tone_rgb.inputs[ax])
    shade = n.mix_colour(shade, tone_rgb.outputs["Vector"], 1.0, blend="MULTIPLY")
    tint_node = n.add("ShaderNodeRGB")
    tint_node.outputs["Color"].default_value = materials._srgb(tint)
    coloured = n.mix_colour(shade, tint_node.outputs["Color"], 1.0, blend="MULTIPLY")
    n.link(coloured, n.bsdf.inputs["Base Color"])
    rough = n.math("MULTIPLY_ADD", strands.outputs["Value"], -0.25, 0.62)
    n.link(rough.outputs["Value"], n.bsdf.inputs["Roughness"])
    n.bump(strands.outputs["Value"], bump_strength, bump_dist)
    mat["tint"] = list(tint)
    return mat


def set_tint(mat, tint):
    for node in mat.node_tree.nodes:
        if node.type == "RGB":
            node.outputs["Color"].default_value = materials._srgb(tint)


def scrunchie_material(name, color):
    return cm.plain(name, color, 0.78, bump=0.1, scale=60.0, mottle=0.1, folds=0.6)


def scrunchie(name, centre, axis, major=0.11, minor=0.055, lobes=11, mat=None):
    """A gathered fabric ring round a ponytail's root: a torus whose tube
    swells and pinches round it (the elastic's gathers)."""
    bm = bmesh.new()
    axis = axis.normalized()
    ref = V(0, 1, 0) if abs(axis.y) < 0.9 else V(1, 0, 0)
    e1 = axis.cross(ref).normalized()
    e2 = axis.cross(e1).normalized()
    U, W = 48, 12
    rings = []
    for i in range(U):
        a = TAU * i / U
        gather = 1.0 + 0.28 * math.sin(a * lobes)
        c = centre + (e1 * math.cos(a) + e2 * math.sin(a)) * major
        out = (e1 * math.cos(a) + e2 * math.sin(a))
        ring = []
        for j in range(W):
            b = TAU * j / W
            r = minor * gather
            q = c + out * (math.cos(b) * r) + axis * (math.sin(b) * r * 0.9)
            ring.append(bm.verts.new(G(q)))
        rings.append(ring)
    for i in range(U):
        for j in range(W):
            bm.faces.new((rings[i][j], rings[(i + 1) % U][j], rings[(i + 1) % U][(j + 1) % W], rings[i][(j + 1) % W]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    obj = shapes._object(name, bm)
    shapes.smooth(obj, 70)
    if mat is not None:
        obj.data.materials.append(mat)
    obj["part"] = "Head"
    return obj


# The styles -----------------------------------------------------------------------


def s_of(p):
    """How far down the outline from the crown a point on the head is."""
    r = math.hypot(p.x, p.z)
    a = R - RHO
    if p.y >= HT - RHO and r <= a:
        return r
    if p.y >= BELOW:
        return a + RHO * math.atan2(r - a, p.y - (HT - RHO))
    return a + RHO * math.pi / 2 + (BELOW - p.y)


def reach(root, bottom, extra=0.0):
    """A lock's length from root to hang down to `bottom` (a height)."""
    return s_at(bottom) - s_of(root) + extra


def hairline(th):
    return periodic(HAIRLINE, th)


def crew_cut(rng):
    """Short back and sides, a little longer on top and brushed up at the
    front: the cap alone, its bristles in the material."""
    m = Mesh("HairCrew")

    def thick(th, t):
        a = abs(((th + math.pi) % TAU) - math.pi)
        top = 0.042 + 0.018 * smooth(1 - a / 0.8) * smooth((t - 0.45) / 0.35)
        side = 0.016
        k = smooth((t - 0.30) / 0.32)
        return top * (1 - k) + side * k

    cap(m, hairline, thick, K=96, I=26, bump=lambda p, th, t: 0.004 * math.sin(th * 23 + t * 9) * math.sin(th * 7 - t * 31))
    return [m.build(50)]


def side_part(rng):
    """Short, parted on the left and combed over to the right with some lift
    at the front (the 1980s side part), short at the sides and back."""
    m = Mesh("HairSidePart")
    cap(m, hairline, lambda th, t: 0.014 * (1 - smooth((t - 0.6) / 0.4)) + 0.006, K=64, I=16)
    px = -0.22
    a, b = V(px, HT, -0.32), V(px, HT, 0.18)
    flow = away_from(a, b, down=0.25)
    # The long side: from the parting over the top, down the right; the
    # front ones lifted and swept (the wave over the forehead).
    for i in range(10):
        z = -0.31 + i * 0.054
        root = V(px + 0.02, HT, z)
        front = i < 3
        d0 = V(1, 0.0, -0.3 if front else 0.12)
        length = 0.66 + rng.uniform(-0.06, 0.06) - (0.0 if front else 0.06 * i / 9)
        lift = (lambda t, k=(0.075 if front else 0.035): k * (1 - smooth(t / 0.95)) + 0.012)
        lock(m, rng, root, d0, length, flow, rng.uniform(0.15, 0.19), 0.05, lift=lift, stiff=0.25, tip=rng.uniform(0.7, 0.85))
    # The short side.
    for i in range(7):
        z = -0.28 + i * 0.075
        root = V(px - 0.02, HT, z)
        lock(m, rng, root, V(-1, 0, 0.1), 0.40 + rng.uniform(-0.05, 0.04), flow, 0.14, 0.035, lift=lambda t: 0.022 * (1 - t), stiff=0.35, tip=rng.uniform(0.7, 0.85))
    # The crown and back: down, short, into the cap.
    for i in range(11):
        th = math.pi + (i - 5) * 0.23
        root = on_head(th, 0.10 + rng.uniform(0, 0.10))
        lock(m, rng, root, V(math.sin(th), -0.5, -math.cos(th)), 0.6 + rng.uniform(-0.06, 0.06), falling(), 0.16, 0.035, lift=lambda t: 0.022 * (1 - t), stiff=0.3, tip=rng.uniform(0.65, 0.8))
    return [m.build()]


def shoulder(rng):
    """Shoulder length, parted in the middle: falling straight down both
    sides and the back, framing the face, the ends turned out a little."""
    m = Mesh("HairShoulder")
    cap(m, hairline, lambda th, t: 0.014, K=64, I=16)
    a, b = V(0, HT, -0.34), V(0, HT, 0.16)
    flow = away_from(a, b, down=0.35)
    ends = lambda t: 0.032 + 0.045 * smooth((t - 0.72) / 0.28)

    def bottom(th):
        # Down to the shoulders at the sides (the classic body's shoulders,
        # in a jacket, come up to about -0.5 beside the head), past them at
        # the back.
        a = abs(((th + math.pi) % TAU) - math.pi)
        return -0.44 - 0.32 * smooth((a - 2.2) / 0.55)

    for side in (-1, 1):
        for i in range(11):
            z = -0.34 + i * 0.05
            root = V(side * 0.015, HT, z)
            front = z < -0.15
            d0 = V(side, 0, -0.2 if front else 0.05)
            low = (-0.40 if i < 2 else -0.45) + rng.uniform(-0.03, 0.03)
            lock(m, rng, root, d0, reach(root, low, 0.12), flow, rng.uniform(0.17, 0.21), 0.06, lift=ends, stiff=0.3, tip=rng.uniform(0.78, 0.9))
        # A layer under, from lower on the side, to fill.
        for i in range(6):
            th = side * (0.95 + i * 0.3)
            root = on_head(th, 0.45)
            lock(m, rng, root, V(math.sin(th) * 0.3, -1, -math.cos(th) * 0.3), reach(root, bottom(th) + rng.uniform(-0.02, 0.03)), falling(), 0.2, 0.05, lift=lambda t: 0.014 + 0.03 * t, stiff=0.4, tip=rng.uniform(0.75, 0.88))
    # The back, from the crown, down past the collar.
    for i in range(13):
        th = math.pi + (i - 6) * 0.18
        root = on_head(th, 0.06 + 0.12 * rng.random())
        lock(m, rng, root, V(math.sin(th), -0.2, -math.cos(th)), reach(root, bottom(th) + rng.uniform(-0.04, 0.04)), falling(), 0.21, 0.06, lift=ends, stiff=0.35, tip=rng.uniform(0.78, 0.9))
    return [m.build()]


def cap_from(m, pole, hem, thick, K=64, I=18, tone=0.5, reach=None):
    """A cap whose strands run from the hairline to `pole` (a ponytail's
    tie) rather than down from the crown: walked out from the pole over the
    head in every direction until the hairline (`hem(theta)`, a height),
    `thick(phi, t)` over the scalp (t: 0 at the pole, 1 at the hairline),
    thinning to nothing at the hairline. `reach`: no strand longer (from a
    tie at the side, the far side's would meet and fold over each other);
    one stopped short dives under a plain cap laid beneath it."""
    bm = m.bm
    p0 = project(pole, GAP, head_sdf)
    n0 = normal(p0, head_sdf)
    e1 = n0.cross(V(0, 1, 0) if abs(n0.y) < 0.9 else V(1, 0, 0)).normalized()
    e2 = n0.cross(e1).normalized()
    paths = []
    for k in range(K):
        phi = TAU * k / K
        d = e1 * math.cos(phi) + e2 * math.sin(phi)
        p = p0.copy()
        pts = [p0.copy()]
        short = False
        walked = 0.0
        for _ in range(200):
            nrm = normal(p, head_sdf)
            d = (d - nrm * d.dot(nrm)).normalized()
            p = project(p + d * 0.015, GAP, head_sdf)
            pts.append(p)
            walked += 0.015
            if p.y < hem(theta_of(p)):
                break
            if reach and walked >= reach:
                short = True
                break
        lengths = [0.0]
        for q0, q1 in zip(pts, pts[1:]):
            lengths.append(lengths[-1] + (q1 - q0).length)
        paths.append((pts, lengths, short))

    def at(k, t):
        pts, lengths, _ = paths[k % K]
        target = lengths[-1] * t
        for j in range(1, len(pts)):
            if lengths[j] >= target:
                u = (target - lengths[j - 1]) / max(lengths[j] - lengths[j - 1], 1e-9)
                return pts[j - 1].lerp(pts[j], u), lengths[-1]
        return pts[-1], lengths[-1]

    pole_v = bm.verts.new(G(p0 + n0 * thick(0.0, 0.0)))
    rows = []
    for i in range(1, I + 1):
        t = i / I
        row = []
        for k in range(K):
            q, _ = at(k, t)
            h = thick(TAU * k / K, t) * smooth((1.0 - t) / 0.12)
            if paths[k][2]:
                # (Stopped short: down under the cap beneath, no edge to see.)
                h = thick(TAU * k / K, t) * smooth((1.0 - t) / 0.25) - 0.004 * smooth((t - 0.8) / 0.2)
            low = nape(q.y)
            sink = 0.0 if paths[k][2] else EDGE * (1.0 - smooth((1.0 - t) / 0.06))
            # (q is on the scalp the gap out; in the collars' zone, and at the
            # hairline's very edge, closer.)
            row.append(bm.verts.new(G(q + normal(q, head_sdf) * (h * (1 - low) - max(0.006 * low, sink)))))
        rows.append(row)

    def uv(k, i):
        _, total = at(k, 1.0)
        return ((k / K) * TAU * 0.25, total * i / I), (i / I, tone)

    for k in range(K):
        k1 = (k + 1) % K
        m.face([pole_v, rows[0][k], rows[0][k1]], [uv(k, 0), uv(k, 1), uv(k + 1, 1)])
    for i in range(I - 1):
        for k in range(K):
            k1 = (k + 1) % K
            m.face([rows[i][k], rows[i + 1][k], rows[i + 1][k1], rows[i][k1]], [uv(k, i + 1), uv(k, i + 2), uv(k + 1, i + 2), uv(k + 1, i + 1)])


def _ponytail(m, rng, c, axis, fall_len, spread, tail_locks=11, reach=None):
    """Hair pulled from the hairline to the tie at c (a cap whose strands
    run to it, a few locks over it), then the tail out of it: first along
    `axis`, then falling. (`reach`: cap_from's.)"""
    if reach:
        cap(m, hairline, lambda th, t: 0.0, K=48, I=12)
    cap_from(m, c, hairline, lambda phi, t: 0.028 * smooth(t / 0.25) + 0.008, reach=reach)
    pull = toward(c)
    for i in range(14):
        th = TAU * (i + 0.5) / 14
        root = on_head(th, s_at(hairline(th)) - 0.05)
        dist = (c - root).length
        lock(m, rng, root, (c - root), dist * 1.05, pull, 0.2, 0.026, lift=lambda t: 0.03 + 0.01 * math.sin(t * math.pi), stiff=0.55, tip=0.92)
    e1 = axis.cross(V(0, 1, 0) if abs(axis.y) < 0.9 else V(1, 0, 0)).normalized()
    e2 = axis.cross(e1).normalized()
    for i in range(tail_locks):
        a = TAU * i / tail_locks
        ring = e1 * math.cos(a) + e2 * math.sin(a)
        start = c + ring * 0.035
        length = fall_len + rng.uniform(-0.08, 0.06)
        lean = ring * spread
        pts, ns = walk(start, axis + ring * 0.14, length, lambda p, t, lean=lean: DOWN + lean * (1 - t), n=16, stiff=0.15, free=0.0)
        strand(m, pts, ns, taper(0.08, 0.13, tip=rng.uniform(0.68, 0.8)), taper(0.06, 0.085, tip=0.72), sides=7, tone=rng.uniform(0.2, 0.8), under=0.8)


def high_ponytail(rng, scrunchie_mat=None):
    """Pulled up to a high ponytail at the back, tied with a scrunchie."""
    m = Mesh("HairPonytail")
    c = V(0, 0.44, 0.60)
    axis = V(0, 0.55, 1).normalized()
    _ponytail(m, rng, c, axis, 1.2, 0.13)
    hair = m.build()
    tie = scrunchie("HairPonytailScrunchie", c + axis * 0.02, axis, mat=scrunchie_mat)
    return [hair, tie]


def side_ponytail(rng, scrunchie_mat=None):
    """Pulled over to one side, tied high with a scrunchie, the tail down
    beside the head; the fringe teased up off the forehead."""
    m = Mesh("HairSidePony")
    c = V(0.60, 0.30, 0.12)
    axis = V(1, 0.5, 0.25).normalized()
    _ponytail(m, rng, c, axis, 0.95, 0.10, tail_locks=10, reach=1.3)
    # The fringe: teased up from the hairline and rolled back.
    for i in range(7):
        th = (i - 3) * 0.17
        root = on_head(th, s_at(hairline(th)) - 0.01)
        flow = lambda p, t: V(0, 1, 0.25) if p.y < HT - 0.04 else V(0.25, -0.2, 1)
        lock(m, rng, root, V(0, 1, 0.1), 0.42 + rng.uniform(-0.04, 0.04), flow, 0.17, 0.06, lift=lambda t: 0.075 * math.sin(min(t / 0.75, 1.0) * math.pi) + 0.015, stiff=0.35, tip=0.75)
    hair = m.build()
    tie = scrunchie("HairSidePonyScrunchie", c + axis * 0.02, axis, mat=scrunchie_mat)
    return [hair, tie]


def feathered(rng):
    """The feathered flip: parted in the middle, the front and sides swept
    back off the face in layers ("wings"), the ends flipped out at the jaw."""
    m = Mesh("HairFeathered")
    cap(m, hairline, lambda th, t: 0.016, K=64, I=16)

    def wing(p, t):
        # Sideways off the parting, then back and down round the head.
        th = theta_of(p)
        side = math.copysign(1.0, p.x if abs(p.x) > 1e-4 else 1.0)
        back = V(math.sin(th + side * math.pi / 2), 0, -math.cos(th + side * math.pi / 2))
        if p.y > 0.42:
            return V(side, -0.3, 0.25)
        return back * 0.9 + DOWN * (0.9 + 0.8 * t)

    for side in (-1, 1):
        for layer, (count, s0, bottom, lift0) in enumerate(((8, 0.0, -0.40, 0.06), (6, 0.5, -0.36, 0.03))):
            for i in range(count):
                if layer == 0:
                    root = V(side * 0.015, HT, -0.34 + i * 0.065)
                    d0 = V(side, 0, -0.3 if i < 3 else 0.1)
                else:
                    th = side * (0.7 + i * 0.3)
                    root = on_head(th, s0)
                    d0 = V(math.sin(th + side * 1.2), -0.6, -math.cos(th + side * 1.2))
                lift = (lambda t, l0=lift0: l0 * (1 - smooth(t / 0.6)) + 0.015 + 0.08 * smooth((t - 0.72) / 0.28))
                lock(m, rng, root, d0, reach(root, bottom + rng.uniform(-0.05, 0.05), 0.2), wing, rng.uniform(0.17, 0.2), 0.055, lift=lift, stiff=0.3, tip=rng.uniform(0.75, 0.88))
    # The back: to the nape, flipped out.
    for i in range(11):
        th = math.pi + (i - 5) * 0.21
        root = on_head(th, 0.1 + 0.1 * rng.random())
        lock(m, rng, root, V(math.sin(th), -0.3, -math.cos(th)), reach(root, -0.58 + rng.uniform(-0.05, 0.04)), falling(), 0.2, 0.055, lift=lambda t: 0.03 + 0.09 * smooth((t - 0.7) / 0.3), stiff=0.35, tip=rng.uniform(0.75, 0.88))
    return [m.build()]


def mullet(rng):
    """Short and full on top, brushed up at the front, short at the sides,
    long at the back over the collar."""
    m = Mesh("HairMullet")

    def thick(th, t):
        a = abs(((th + math.pi) % TAU) - math.pi)
        top = 0.06 + 0.03 * smooth(1 - a / 0.7) * smooth((t - 0.35) / 0.4)
        side = 0.014 if a < 2.3 else 0.03
        return top * (1 - smooth((t - 0.38) / 0.3)) + side * smooth((t - 0.38) / 0.3)

    cap(m, hairline, thick, K=80, I=22)
    # The back: long, over the collar.
    for i in range(11):
        th = math.pi + (i - 5) * 0.14
        root = on_head(th, 0.05 + 0.12 * rng.random())
        lock(m, rng, root, V(math.sin(th), -0.2, -math.cos(th)), reach(root, -0.86 + rng.uniform(-0.06, 0.05)), falling(), 0.18, 0.06, lift=lambda t: 0.035 + 0.06 * smooth((t - 0.6) / 0.4), stiff=0.35, tip=rng.uniform(0.75, 0.88))
    # A few over the sides' tops, swept back.
    for side in (-1, 1):
        for i in range(4):
            th = side * (1.0 + i * 0.3)
            root = on_head(th, 0.30)
            back = V(math.sin(th + side * 1.3), -0.4, -math.cos(th + side * 1.3))
            lock(m, rng, root, back, 0.36, lambda p, t, b=back: b, 0.16, 0.035, lift=lambda t: 0.02, stiff=0.3)
    return [m.build()]


def perm(rng):
    """The big teased perm (the Aqua Net look): a cloud of tight curls,
    high over the head and out past the shoulders' line, open at the face,
    a teased fringe standing up off the forehead."""
    m = Mesh("HairPerm")

    def hem(th):
        return periodic([(0.0, 0.40), (0.55, 0.36), (0.80, 0.25), (1.05, -0.25), (1.40, -0.40), (math.pi, -0.50)], th)

    def thick(th, t):
        a = abs(((th + math.pi) % TAU) - math.pi)
        top = 0.20
        side = 0.26 + 0.06 * smooth((a - 1.2) / 1.0)
        v = top * (1 - smooth(t / 0.5)) + side * smooth(t / 0.5)
        # Thinner where it frames the face; teased up at the front.
        near_face = smooth(1 - a / 0.9)
        v = v * (1 - 0.55 * near_face * smooth((t - 0.55) / 0.4))
        v += 0.10 * near_face * smooth((t - 0.45) / 0.3) * smooth((0.95 - t) / 0.2)
        # Fuller toward the ends, as a perm sits.
        v += 0.06 * smooth((t - 0.6) / 0.4) * smooth((a - 0.8) / 0.5)
        return v

    pts = []
    for _ in range(230):
        th = rng.uniform(-math.pi, math.pi)
        t = rng.uniform(0, 1) ** 0.8
        s = s_at(hem(th)) * t
        pts.append((on_head(th, s, thick(th, t)), rng.uniform(0.11, 0.16), rng.uniform(0.7, 1.0)))

    def bump(p, th, t):
        # Clumps blended smoothly where they meet (the larger of two left a
        # crease that folded), no higher than one clump.
        total = 0.0
        for c, rc, hgt in pts:
            d = (p - c).length
            if d < rc:
                total += hgt * (1 - (d / rc) ** 2) ** 2
        return 0.065 * math.tanh(total) - 0.035

    cap(m, hem, thick, K=96, I=36, inner=True, bump=bump, hem_lip=0.04)
    return [m.build(80)]


STYLES = {
    "Crew": crew_cut,
    "SidePart": side_part,
    "Shoulder": shoulder,
    "Ponytail": high_ponytail,
    "Feathered": feathered,
    "SidePony": side_ponytail,
    "Mullet": mullet,
    "Perm": perm,
}
KINDS = {"Crew": "short", "Perm": "curly"}

# Hair colours to choose from (natural 1988 shades, sRGB): how the hair
# should look. The map is grey (its mean MAP_MEAN, linear) and the game
# tints it, so the tint is the colour over that mean (tint_for).
COLOURS = [
    ("Black", (30, 26, 24)),
    ("Dark brown", (62, 42, 30)),
    ("Chestnut", (104, 64, 40)),
    ("Auburn", (128, 54, 32)),
    ("Ginger", (176, 90, 44)),
    ("Dirty blonde", (156, 124, 80)),
    ("Golden blonde", (212, 170, 104)),
    ("Platinum", (232, 222, 196)),
    ("Grey", (156, 154, 150)),
]
MAP_MEAN = 0.70


def tint_for(colour):
    """The tint that makes the grey map look `colour` (sRGB 0-255)."""

    def lin(v):
        v = v / 255.0
        return v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4

    def srgb(v):
        v = max(0.0, min(1.0, v))
        return 12.92 * v if v <= 0.0031308 else 1.055 * v ** (1 / 2.4) - 0.055

    return tuple(int(round(srgb(lin(c) / MAP_MEAN) * 255)) for c in colour)


# Scrunchie colours: neon 1980s fabric.
SCRUNCHIES = {"Ponytail": (214, 52, 130), "SidePony": (40, 168, 176)}


def build(name, tint=TINT_SKETCH, seed=1988):
    """One style's pieces, the hair in `tint` (the sketches; the game's batch
    is grey and tinted in the game)."""
    rng = random.Random(seed * 7919 + sum(ord(c) for c in name))
    mat = hair_material("Hair" + name + "Mat", tint, kind=KINDS.get(name, "straight"))
    maker = STYLES[name]
    if name in SCRUNCHIES:
        pieces = maker(rng, scrunchie_mat=scrunchie_material("Scrunchie" + name, SCRUNCHIES[name]))
    else:
        pieces = maker(rng)
    for obj in pieces:
        if not obj.data.materials:
            obj.data.materials.append(mat)
    return pieces
