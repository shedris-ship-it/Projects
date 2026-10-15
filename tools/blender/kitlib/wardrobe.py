"""The wardrobe (V6, bodies and 1980s clothes; docs/progress/2026-10-14-visual-v6/).

Clothes for the two classic bodies (Data/Wardrobe: ROBLOX Boy and Girl),
one fitted piece for each body part a garment covers: a top's torso and
four sleeve pieces (and its hem over the hips if it isn't tucked in);
trousers' waist and four leg pieces; a pair of shoes. A classic body part
is a rigid capsule the game turns at its joint, so each piece is a capsule
round it that turns with it exactly as the body does (and your
first-person arm, copied from your character, wears its own sleeves).

Every piece is lofted round its part's real shape (bodyshape.txt, measured
in Studio): at each height and angle, the larger of the two bodies' surfaces
(each as a share of its own part's size) plus the cloth's thickness, so it
encloses both once the game stretches it to the part it's worn on.

No clipping between layers (the owner, 2026-10-15: "high quality with no
clipping between layers"): a piece that lies over another is pushed out
wherever the one under it would come through, on both bodies, in the pose
they stand in (Piece.cover): a jacket's hem over the trousers and belt and
the bottom of its own body, the trousers' waist over the tops of the legs
and a tucked-in shirt's tail, the belt over both, a sleeve's elbow over the
forearm's, a high-top over the trouser leg, the collar round the head.
`check()` measures every pair afterwards and reports anything still through.

Pieces are built in the body part's own frame (x across, y up, z; the
body's front is -z), centred on the part's middle at the Boy's size.
"""

import math
import os

import bmesh
import bpy
from mathutils import Vector

from . import clothmats as cm
from . import shapes

HERE = os.path.dirname(os.path.abspath(__file__))
TAU = math.pi * 2
ANGLES = 18  # the measured samples round each ring
FRONT = math.pi * 1.5  # theta at the middle of the front (-z)
BACK = math.pi * 0.5
GAP = 0.016  # studs between one layer and the next, at least


def G(x, y, z):
    """A point in the part's frame (x, y up, z; the front is -z) as Blender's
    (the kit's convention: the game's +z is Blender's -y)."""
    return (x, -z, y)


def B2G(v):
    return Vector((v[0], v[2], -v[1]))


# The bodies' measured shapes ---------------------------------------------------


def _load():
    bodies = {}
    current = None
    with open(os.path.join(HERE, "bodyshape.txt")) as f:
        for raw in f:
            line = raw.strip()
            if not line or line.startswith("#"):
                continue
            if line[0].isalpha():
                bits = line.split()
                body, name = bits[0], bits[1].replace("Left", "")
                current = {
                    "size": tuple(float(v) for v in bits[3:6]),
                    "at": tuple(float(v) for v in bits[7:10]),
                    "rings": [],
                }
                bodies.setdefault(body, {})[name] = current
            else:
                y, radii = line.split(":")
                current["rings"].append((float(y), [int(v) / 100.0 for v in radii.split(",")]))
    return bodies


BODIES = _load()
BODY_NAMES = ("Boy", "Girl")
# The size every piece is built at (the Boy's parts); the game stretches it
# to the part it's worn on, axis by axis (World/Kit.wear).
NOMINAL = {name: part["size"] for name, part in BODIES["Boy"].items()}
LIMBS = ("UpperArm", "LowerArm", "Hand", "UpperLeg", "LowerLeg", "Foot")


def _polar(size, radii):
    """A measured ring as samples (angle, share of the part's half-size)
    round its middle, sorted by angle."""
    hx, hz = size[0] / 2, size[2] / 2
    out = []
    for j, r in enumerate(radii):
        if r <= 0:
            continue
        a = TAU * j / ANGLES
        x, z = r * math.cos(a) / hx, r * math.sin(a) / hz
        out.append((math.atan2(z, x) % TAU, math.hypot(x, z)))
    out.sort()
    return out


_polar_cache = {}


def _ring_polar(body, part, index):
    key = (body, part, index)
    if key not in _polar_cache:
        p = BODIES[body][part]
        _polar_cache[key] = _polar(p["size"], p["rings"][index][1])
    return _polar_cache[key]


def _at_angle(samples, theta):
    if not samples:
        return 0.0
    if len(samples) == 1:
        return samples[0][1]
    for (a0, r0), (a1, r1) in zip(samples, samples[1:] + [(samples[0][0] + TAU, samples[0][1])]):
        t = theta
        if t < a0:
            t += TAU
        if a0 <= t <= a1:
            u = (t - a0) / max(a1 - a0, 1e-6)
            return r0 + (r1 - r0) * u
    return samples[-1][1]


def envelope(part, u, theta):
    """The share of the part's half-size the bodies reach at height u (-1
    bottom to 1 top) and angle theta: the larger of the two bodies, and of
    the rings above and below (so the cloth never dips between them)."""
    best = 0.0
    for body in BODY_NAMES:
        p = BODIES[body][part]
        hy = p["size"][1] / 2
        heights = [y / hy for y, _ in p["rings"]]
        for i in range(len(heights) - 1):
            if heights[i] - 1e-6 <= u <= heights[i + 1] + 1e-6:
                for k in (i, i + 1):
                    best = max(best, _at_angle(_ring_polar(body, part, k), theta))
                break
    return best


def scale_of(body, part):
    s, n = BODIES[body][part]["size"], NOMINAL[part]
    return Vector((s[0] / n[0], s[1] / n[1], s[2] / n[2]))


def place_of(body, part, side):
    a = BODIES[body][part]["at"]
    return Vector((a[0] if side != "R" else -a[0], a[1], a[2]))


def to_root(p, body, part, side):
    """A point in a piece's frame (at the Boy's size) to the body's root
    frame, as the game stretches and places it."""
    s = scale_of(body, part)
    q = Vector((p.x * s.x, p.y * s.y, p.z * s.z))
    if side == "R":
        q.x = -q.x
    return q + place_of(body, part, side)


def from_root(r, body, part, side):
    q = r - place_of(body, part, side)
    if side == "R":
        q.x = -q.x
    s = scale_of(body, part)
    return Vector((q.x / s.x, q.y / s.y, q.z / s.z))


# A piece of cloth ------------------------------------------------------------------


class Piece:
    """A capsule (or a band) of cloth round a body part: rows of rings from
    height u0 to u1 (shares of the part's half-height), each at the bodies'
    envelope plus `extra` studs (the cloth's thickness, its fullness, and
    whatever the layers under it need: cover()). Built into a mesh last."""

    def __init__(self, name, part, margin, u0=-1.0, u1=1.0, rows=16, angles=36, caps=(True, True),
                 swell=None, us=None, roll=None, a0=0.0, a1=TAU, closed=True, side="L", reach=0.93):
        self.name, self.part, self.side = name, part, side
        self.size = NOMINAL[part]
        self.hx, self.hy, self.hz = self.size[0] / 2, self.size[1] / 2, self.size[2] / 2
        self.us = us or [u0 + (u1 - u0) * i / (rows - 1) for i in range(rows)]
        self.closed = closed
        self.a0, self.a1 = a0, a1
        self.count = angles if closed else angles + 1
        self.angles = angles
        self.thetas = [a0 + (a1 - a0) * k / angles for k in range(self.count)]
        self.caps = caps
        self.margin = margin
        share = []
        for u in self.us:
            uu = max(min(u, reach), -reach)
            share.append([envelope(part, uu, t % TAU) for t in self.thetas])
        self.share = _smooth_rows(share, closed)
        self.extra = []
        for i, u in enumerate(self.us):
            row = []
            for t in self.thetas:
                e = margin + (swell(u, t % TAU) if swell else 0.0) + (roll[i] if roll else 0.0)
                row.append(e)
            self.extra.append(row)
        self.cap_lift = (0.035, 0.05)

    # Where its surface is.

    def _cell(self, u, theta):
        """Row and angle indices and weights round (u, theta)."""
        us = self.us
        if u <= us[0]:
            i, fu = 0, 0.0
        elif u >= us[-1]:
            i, fu = len(us) - 2, 1.0
        else:
            i = max(j for j in range(len(us) - 1) if us[j] <= u)
            fu = (u - us[i]) / max(us[i + 1] - us[i], 1e-6)
        if self.closed:
            t = (theta - self.a0) % TAU
            pos = t / TAU * self.angles
            k = int(math.floor(pos)) % self.angles
            fk = pos - math.floor(pos)
            k1 = (k + 1) % self.angles
        else:
            t = (theta - self.a0) % TAU
            span = self.a1 - self.a0
            pos = min(max(t / span, 0.0), 1.0) * self.angles
            k = min(int(math.floor(pos)), self.angles - 1)
            fk = pos - k
            k1 = k + 1
        return i, fu, k, k1, fk

    def _lerp(self, grid, u, theta):
        i, fu, k, k1, fk = self._cell(u, theta)
        a = grid[i][k] * (1 - fk) + grid[i][k1] * fk
        b = grid[i + 1][k] * (1 - fk) + grid[i + 1][k1] * fk
        return a * (1 - fu) + b * fu

    def point(self, u, theta, add=0.0):
        share = max(self._lerp(self.share, u, theta), 0.3)
        extra = self._lerp(self.extra, u, theta) + add
        c, s = math.cos(theta), math.sin(theta)
        return Vector((share * c * self.hx + c * extra, u * self.hy, share * s * self.hz + s * extra))

    def surface(self, u, theta, add=0.0):
        """A point on its surface (+add studs out) and the way out."""
        return self.point(u, theta, add), Vector((math.cos(theta), 0, math.sin(theta)))

    def frame(self, u, theta):
        """Its surface's way up it, way round it and way out, at (u, theta)."""
        du, dt = 0.02, 0.02
        p = self.point(u, theta)
        pu = (self.point(u + du, theta) - self.point(u - du, theta)).normalized()
        pt = (self.point(u, theta + dt) - self.point(u, theta - dt)).normalized()
        n = pt.cross(pu).normalized()
        if n.dot(Vector((math.cos(theta), 0, math.sin(theta)))) < 0:
            n = -n
        return p, pu, pt, n

    def grid_point(self, i, k):
        share = max(self.share[i][k], 0.3)
        extra = self.extra[i][k]
        t = self.thetas[k]
        c, s = math.cos(t), math.sin(t)
        return Vector((share * c * self.hx + c * extra, self.us[i] * self.hy, share * s * self.hz + s * extra))

    def radius_at(self, q):
        """How far its surface is from the part's axis in the direction of
        the frame point q (q's height), and q's own distance: (surface, q).
        None outside its height."""
        u = q.y / self.hy
        theta = math.atan2(q.z / self.hz, q.x / self.hx) % TAU
        if not self.closed:
            t = (theta - self.a0) % TAU
            if t > self.a1 - self.a0:
                return None
        dist = math.hypot(q.x, q.z)
        for top, end in ((False, self.us[0]), (True, self.us[-1])):
            beyond = (q.y - end * self.hy) * (1 if top else -1)
            if beyond <= 1e-6:
                continue
            cap = self.caps[1 if top else 0]
            if not cap or not self.closed:
                return None
            # Over a cap: its ring shrinking to 66% at the first lift, to a
            # point at the second (Piece.build); a flat cap stops at once.
            p = self.point(end, theta)
            ring = math.hypot(p.x, p.z)
            l0, l1 = self.cap_lift
            if cap == "flat" or beyond >= l1:
                return None
            if beyond <= l0:
                r = ring * (1 - 0.34 * beyond / l0)
            else:
                r = ring * 0.66 * (1 - (beyond - l0) / (l1 - l0))
            return r, dist, end, theta
        p = self.point(u, theta)
        return math.hypot(p.x, p.z), dist, u, theta

    # Covering what's under it.

    def cover(self, points, gap=GAP, u_range=None):
        """Pushes this piece out wherever a point of what's under it (frame
        points, already in this piece's frame) would come through, by `gap`
        at least. u_range: only between those heights."""
        moved = 0
        for _ in range(6):
            # Each point raises the four corners round it by what it needs
            # (raising all four by the same raises the surface there by as
            # much); the largest need at each corner wins. A few passes, as
            # extra pushes along the angle, not quite straight out.
            want = [list(row) for row in self.extra]
            hits = 0
            for q in points:
                hit = self.radius_at(q)
                if hit is None:
                    continue
                surface, dist, u, theta = hit
                if u_range and not (u_range[0] <= u <= u_range[1]):
                    continue
                need = dist + gap - surface
                if need <= 1e-4:
                    continue
                hits += 1
                i, fu, k, k1, fk = self._cell(u, theta)
                for ii in (i, i + 1):
                    for kk in (k, k1):
                        want[ii][kk] = max(want[ii][kk], self.extra[ii][kk] + need * 1.1)
            if not hits:
                break
            moved = max(moved, hits)
            self.extra = _smooth_rows(want, self.closed, passes=1)
        return moved

    def points(self):
        """Its surface as frame points: every ring, and its caps."""
        out = [self.grid_point(i, k) for i in range(len(self.us)) for k in range(self.count)]
        for top, row in ((False, 0), (True, len(self.us) - 1)):
            if not self.caps[1 if top else 0]:
                continue
            ring = [self.grid_point(row, k) for k in range(self.count)]
            centre = Vector((0, ring[0].y, 0))
            lift = 1 if top else -1
            for p in ring:
                q = centre + (p - centre) * 0.66
                q.y += lift * self.cap_lift[0]
                out.append(q)
            out.append(Vector((0, ring[0].y + lift * self.cap_lift[1], 0)))
        return out

    def band(self, name, u0, u1, add, thickness=0.02, rows=4, a0=None, a1=None):
        """A band lying over this piece (a cuff, a waistband, a belt): its
        rings at this piece's surface plus `add`, rolled `thickness` out in
        its middle, square-cut at a0..a1 if it doesn't go all round."""
        us = [u0, u0 + (u1 - u0) * 0.08, u1 - (u1 - u0) * 0.08, u1]
        roll = [0.0, thickness * 0.85, thickness, 0.0]
        closed = a0 is None
        b = Piece(name, self.part, 0.0, us=us, caps=(False, False), a0=a0 or 0.0, a1=a1 or TAU,
                  closed=closed, side=self.side, angles=self.angles)
        for i, u in enumerate(us):
            for k, t in enumerate(b.thetas):
                b.share[i][k] = max(self._lerp(self.share, u, t % TAU), 0.3)
                b.extra[i][k] = self._lerp(self.extra, u, t % TAU) + add + roll[i]
        return b

    # Into a mesh.

    def build(self, subdivide=0, smooth=60):
        bm = bmesh.new()
        rows = []
        for i in range(len(self.us)):
            rows.append([bm.verts.new(G(*self.grid_point(i, k))) for k in range(self.count)])
        n = self.count
        for i in range(len(rows) - 1):
            for k in range(self.angles):
                k1 = (k + 1) % n
                bm.faces.new((rows[i][k], rows[i][k1], rows[i + 1][k1], rows[i + 1][k]))
        for top in (False, True):
            if not self.caps[1 if top else 0] or not self.closed:
                continue
            row = rows[-1] if top else rows[0]
            lift = 1 if top else -1
            flat = self.caps[1 if top else 0] == "flat"
            y = self.us[-1 if top else 0] * self.hy
            if flat:
                centre = bm.verts.new(G(0, y, 0))
                for k in range(n):
                    bm.faces.new((row[k], row[(k + 1) % n], centre))
                continue
            inner = []
            for v in row:
                p = B2G(v.co)
                q = Vector((p.x * 0.66, y + lift * self.cap_lift[0], p.z * 0.66))
                inner.append(bm.verts.new(G(*q)))
            for k in range(n):
                bm.faces.new((row[k], row[(k + 1) % n], inner[(k + 1) % n], inner[k]))
            tip = bm.verts.new(G(0, y + lift * self.cap_lift[1], 0))
            for k in range(n):
                bm.faces.new((inner[k], inner[(k + 1) % n], tip))
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        obj = _object(self.name, bm)
        if subdivide:
            _subsurf(obj, subdivide)
        shapes.smooth(obj, smooth)
        obj["part"] = self.part
        return obj


def tuck(inner, outer, gap=GAP):
    """Pulls an inner piece in wherever it would come through the piece over
    it, on either body, so that one keeps its own shape (a forearm's sleeve
    tucked inside the upper sleeve at the elbow, the shin inside the thigh's
    foot). What's pulled in is hidden inside the outer piece, standing. Returns
    how many of its points moved."""
    moved = 0
    for _ in range(4):
        hits = 0
        for i in range(len(inner.us)):
            for k in range(inner.count):
                p = inner.grid_point(i, k)
                # The body there (this point with no cloth on it).
                share = max(inner.share[i][k], 0.3)
                t = inner.thetas[k]
                bare = Vector((share * math.cos(t) * inner.hx, inner.us[i] * inner.hy, share * math.sin(t) * inner.hz))
                over = 0.0
                body_out = False
                for body in BODY_NAMES:
                    q = from_root(to_root(p, body, inner.part, inner.side), body, outer.part, outer.side)
                    hit = outer.radius_at(q)
                    if hit is None:
                        # (Outside the outer piece: nothing to tuck under.)
                        body_out = True
                        continue
                    surface, dist, u, theta = hit
                    over = max(over, dist - (surface - gap))
                    b = from_root(to_root(bare, body, inner.part, inner.side), body, outer.part, outer.side)
                    bh = outer.radius_at(b)
                    if bh is None or bh[1] > bh[0] - 2 * gap:
                        body_out = True
                if over <= 1e-4:
                    continue
                if body_out:
                    # The body would show: keep it covered (the outer piece
                    # covers this instead, in cover()).
                    floor = GAP
                    if inner.extra[i][k] - over * 1.1 < floor:
                        continue
                inner.extra[i][k] -= over * 1.1
                hits += 1
        if not hits:
            break
        moved = max(moved, hits)
    return moved


def _smooth_rows(rows, closed=True, passes=2):
    """Softens a grid round its angles without ever lowering it."""
    out = [list(r) for r in rows]
    for _ in range(passes):
        for row in out:
            n = len(row)
            if closed:
                row[:] = [max(row[k], (row[k - 1] + 2 * row[k] + row[(k + 1) % n]) / 4) for k in range(n)]
            else:
                row[:] = [row[0]] + [max(row[k], (row[k - 1] + 2 * row[k] + row[k + 1]) / 4) for k in range(1, n - 1)] + [row[-1]]
    return out


def points_in(piece_points, from_part, from_side, to_part, to_side, bodies=BODY_NAMES):
    """Frame points of one piece, carried into another piece's frame on each
    body (the two stretched and placed as the game does)."""
    out = []
    for body in bodies:
        for p in piece_points:
            out.append(from_root(to_root(p, body, from_part, from_side), body, to_part, to_side))
    return out


def under(piece, inner, sides=None):
    """`inner`'s points in `piece`'s frame, on both bodies; a limb's from
    both sides when `piece` is on the middle of the body."""
    pts = inner.points()
    if sides is None:
        sides = ("L", "R") if inner.part in LIMBS and piece.part not in LIMBS else (inner.side,)
    out = []
    for side in sides:
        out += points_in(pts, inner.part, side, piece.part, piece.side)
    return out


def body_points(part, side="L", to_part=None, to_side="L"):
    """A body part's measured surface (both bodies), in a piece's frame."""
    out = []
    for body in BODY_NAMES:
        p = BODIES[body][part]
        size = p["size"]
        n = NOMINAL[part]
        for y, radii in p["rings"]:
            for j, r in enumerate(radii):
                if r <= 0:
                    continue
                a = TAU * j / ANGLES
                local = Vector((r * math.cos(a), y, r * math.sin(a)))
                if side == "R":
                    local.x = -local.x
                root = local + place_of(body, part, side)
                # (Measured in studs on that body: straight into the piece's frame.)
                out.append(from_root(root, body, to_part or part, to_side))
        del size, n
    return out


# Geometry helpers -----------------------------------------------------------------


def _object(name, bm):
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    return obj


def _apply_all(obj):
    shapes.select_only(obj)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    return obj


def _subsurf(obj, levels):
    mod = obj.modifiers.new("Subsurf", "SUBSURF")
    mod.levels = levels
    mod.render_levels = levels
    shapes.select_only(obj)
    bpy.ops.object.modifier_apply(modifier=mod.name)


def patch(name, piece, u, theta, width, height, add=0.0, depth=0.018, tilt=0.0, bevel=0.006):
    """A flat piece laid on a piece of cloth (a pocket, a placket, a patch):
    a thin rounded box at height u and angle theta, its back on the cloth."""
    p, out = piece.surface(u, theta, add)
    obj = shapes.box(name, (width, depth, height), (0, 0, 0), bevel_width=bevel, segments=2)
    yaw = math.atan2(out.x, -out.z)
    obj.rotation_euler = (0, math.radians(tilt), -yaw)
    obj.location = Vector(G(p.x + out.x * (depth / 2 - 0.004), p.y, p.z + out.z * (depth / 2 - 0.004)))
    return _apply_all(obj)


def lay(name, piece, u, theta, width, height, add=0.0, depth=0.016, tilt=0.0, bevel=0.005):
    """A flat piece lying on the cloth's own slope at (u, theta): its width
    round the piece, its height up it (an instep's tongue, a strap over the
    foot)."""
    p, pu, pt, n = piece.frame(u, theta)
    p = p + n * add
    obj = shapes.box(name, (width, depth, height), (0, 0, 0), bevel_width=bevel, segments=2)
    # Box axes: x = round (pt), y = out (n), z = up (pu): in Blender's frame.
    from mathutils import Matrix

    def b(v):
        return Vector(G(v.x, v.y, v.z))

    ax, ay, az = b(pt), b(n), b(pu)
    m = Matrix((ax, ay, az)).transposed()
    if tilt:
        m = m @ Matrix.Rotation(math.radians(tilt), 3, "Y")
    obj.matrix_world = Matrix.Translation(Vector(G(*(p + n * (depth / 2 - 0.004))))) @ m.to_4x4()
    return _apply_all(obj)


def button(name, piece, u, theta, add=0.0, radius=0.035, height=0.016, steps=14):
    """A round button standing on a piece of cloth, facing out."""
    p, out = piece.surface(u, theta, add)
    obj = shapes.lathe(
        name,
        [(0.0, -0.004), (radius, -0.004), (radius, height * 0.6), (radius * 0.85, height), (0.0, height * 0.9)],
        steps=steps,
    )
    yaw = math.atan2(out.x, -out.z)
    obj.rotation_euler = (math.radians(-90), 0, -yaw)
    obj.location = Vector(G(p.x, p.y, p.z))
    return _apply_all(obj)


def letter_c(name, piece, u, theta, radius, width, add=0.0, depth=0.03):
    """A letter C (a varsity jacket's chenille patch) lying on the cloth, its
    gap to the wearer's right."""
    p, out = piece.surface(u, theta, add)
    bm = bmesh.new()
    steps, gap = 22, 0.9
    inner, outer = [], []
    for i in range(steps + 1):
        a = gap / 2 + (TAU - gap) * i / steps
        c, s = math.cos(a), math.sin(a)
        inner.append(bm.verts.new((c * (radius - width / 2), 0.0, s * (radius - width / 2))))
        outer.append(bm.verts.new((c * (radius + width / 2), 0.0, s * (radius + width / 2))))
    back_inner = [bm.verts.new((v.co.x, -depth, v.co.z)) for v in inner]
    back_outer = [bm.verts.new((v.co.x, -depth, v.co.z)) for v in outer]
    for i in range(steps):
        bm.faces.new((inner[i], outer[i], outer[i + 1], inner[i + 1]))
        bm.faces.new((back_inner[i + 1], back_outer[i + 1], back_outer[i], back_inner[i]))
        bm.faces.new((outer[i + 1], outer[i], back_outer[i], back_outer[i + 1]))
        bm.faces.new((inner[i], inner[i + 1], back_inner[i + 1], back_inner[i]))
    for i in (0, steps):
        bm.faces.new((inner[i], back_inner[i], back_outer[i], outer[i]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    obj = _object(name, bm)
    yaw = math.atan2(out.x, -out.z)
    obj.rotation_euler = (0, 0, math.pi - yaw)
    obj.location = Vector(G(p.x + out.x * (depth - 0.004), p.y, p.z + out.z * (depth - 0.004)))
    _apply_all(obj)
    shapes.smooth(obj, 40)
    return obj


def collar_radius(radius, flare, thickness, t):
    """A collar_ring's radius a share t of the way up it."""
    return radius + flare * t * t + thickness * math.sin(t * math.pi)


def head_radius(y):
    """How far the head reaches from the neck's line at a height y in the
    upper torso's frame (the larger of the two bodies): a collar stands just
    outside it."""
    best = 0.0
    for body in BODY_NAMES:
        head = BODIES[body]["Head"]
        torso = BODIES[body]["UpperTorso"]
        # The torso's frame is stretched to each body's torso: back to studs.
        sy = torso["size"][1] / NOMINAL["UpperTorso"][1]
        local = y * sy + torso["at"][1] - head["at"][1]
        rings = head["rings"]
        for (y0, r0), (y1, r1) in zip(rings, rings[1:]):
            if y0 <= local <= y1:
                t = (local - y0) / max(y1 - y0, 1e-6)
                a, b = max(r0), max(r1)
                best = max(best, a + (b - a) * t)
                break
    return best


def neck_collar(name, y0, height, thickness, open_front=0.0, flare=0.0, rows=6, angles=32):
    """A collar round the base of the head, fitted to it: each ring just
    outside the head at its height (on both bodies), leaning out by `flare`
    at the top, rolled `thickness`; open at the front by `open_front`."""
    bm = bmesh.new()
    a0, a1 = (FRONT + open_front, FRONT - open_front + TAU) if open_front > 0 else (0.0, TAU)
    closed = open_front <= 0
    count = angles if closed else angles + 1
    rings = []
    base = max(head_radius(y0), 0.3)
    for i in range(rows):
        t = i / (rows - 1)
        y = y0 + height * t
        r = max(head_radius(y) + GAP, base) + flare * t * t + thickness * math.sin(t * math.pi)
        row = []
        for k in range(count):
            a = a0 + (a1 - a0) * k / angles
            row.append(bm.verts.new(G(r * math.cos(a), y, r * math.sin(a))))
        rings.append(row)
    inside = []
    top_r = max(head_radius(y0 + height * 0.96) + GAP * 0.5, base)
    for k in range(count):
        a = a0 + (a1 - a0) * k / angles
        inside.append(bm.verts.new(G(top_r * math.cos(a), y0 + height * 0.96, top_r * math.sin(a))))
    for i in range(rows - 1):
        for k in range(angles):
            k1 = (k + 1) % count
            bm.faces.new((rings[i][k], rings[i][k1], rings[i + 1][k1], rings[i + 1][k]))
    for k in range(angles):
        k1 = (k + 1) % count
        bm.faces.new((rings[-1][k], rings[-1][k1], inside[k1], inside[k]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    obj = _object(name, bm)
    _subsurf(obj, 1)
    shapes.smooth(obj, 60)
    return obj


def collar_ring(name, y, radius, height, flare, thickness=0.03, open_front=0.0, rows=5, angles=32):
    """A collar standing round the base of the head (the top of the upper
    torso): a short ring rising from `y` with `radius` at its foot, leaning
    out by `flare` at its top, rolled; open at the front by `open_front`
    radians each side."""
    bm = bmesh.new()
    a0, a1 = (FRONT + open_front, FRONT - open_front + TAU) if open_front > 0 else (0.0, TAU)
    closed = open_front <= 0
    count = angles if closed else angles + 1
    rings = []
    for i in range(rows):
        t = i / (rows - 1)
        r = collar_radius(radius, flare, thickness, t)
        row = []
        for k in range(count):
            a = a0 + (a1 - a0) * k / angles
            # The head is round: the collar hugs it, a touch deeper at the front.
            front = max(0.0, -math.sin(a)) * 0.04
            row.append(bm.verts.new(G((r + front) * math.cos(a), y + height * t, (r + front) * math.sin(a))))
        rings.append(row)
    # The inside of the collar (it's seen from above and the front).
    inside = []
    for k in range(count):
        a = a0 + (a1 - a0) * k / angles
        inside.append(bm.verts.new(G((radius - 0.012) * math.cos(a), y + height * 0.96, (radius - 0.012) * math.sin(a))))
    for i in range(rows - 1):
        for k in range(angles):
            k1 = (k + 1) % count
            bm.faces.new((rings[i][k], rings[i][k1], rings[i + 1][k1], rings[i + 1][k]))
    for k in range(angles):
        k1 = (k + 1) % count
        bm.faces.new((rings[-1][k], rings[-1][k1], inside[k1], inside[k]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    obj = _object(name, bm)
    _subsurf(obj, 1)
    shapes.smooth(obj, 60)
    return obj


def join(objects, name):
    obj = shapes.join([o for o in objects if o is not None], name)
    shapes.smooth(obj, 50)
    return obj


def mats(obj, *materials_):
    obj.data.materials.clear()
    for m in materials_:
        obj.data.materials.append(m)
    return obj


def paint(obj, index):
    for poly in obj.data.polygons:
        poly.material_index = index
    return obj


LINING = GAP * 0.8  # the cloth's thickness: less than the gap to the layer under it
LINING_SHARE = 0.15  # of the texture, for the inside (seldom seen)


def line(obj, thickness=LINING):
    """Gives a piece its inside: a lining a cloth's thickness in, facing in,
    and a rim round every open edge (shapes.line_open). Roblox draws a face
    from the front only, so a shell with no inside showed straight through at
    its cuffs, hems and collar (2026-10-15). Every open surface (the shell,
    and the bands, cuffs, soles and stripes lying on it, whose edges stand a
    hair off it); not the closed solids (pockets, buttons, collars). The
    lining wears a copy of the piece's first material, packed into its own
    small share of the texture (bake.unwrap, uv_share); the rims wear the
    cloth they edge. Run after check(): the lining sits inside the gap to the
    layer under it."""
    me = obj.data
    lining = me.materials[0].copy()
    lining.name = obj.name + "Lining"
    lining["uv_share"] = LINING_SHARE
    me.materials.append(lining)
    return shapes.line_open(obj, thickness, len(me.materials) - 1)


def mirror(obj, name):
    """The other side's piece: mirrored across the part's middle (x)."""
    copy = obj.copy()
    copy.data = obj.data.copy()
    copy.name = name
    copy.data.name = name
    bpy.context.scene.collection.objects.link(copy)
    copy.location = (0, 0, 0)
    copy.scale = (-1, 1, 1)
    # (Applying a negative scale reverses the faces itself: reversing them
    # again turned every right-side piece inside out, 2026-10-15; Roblox
    # draws only the outside, so the near side vanished.)
    _apply_all(copy)
    for key in obj.keys():
        copy[key] = obj[key]
    return copy


# The body's landmarks (both bodies, in the parts' frames) ----------------------------


def _hand_top_u():
    """Where the hand's top meets the forearm, as the lower arm's height (u):
    the higher of the two bodies, so a sleeve ends at the wrist."""
    best = -1.0
    for body in BODY_NAMES:
        hand = BODIES[body]["Hand"]
        top = hand["at"][1] + hand["size"][1] / 2
        arm = BODIES[body]["LowerArm"]
        best = max(best, (top - arm["at"][1]) / (arm["size"][1] / 2))
    return best


def _foot_top_u():
    """The top of the foot, as the lower leg's height (u)."""
    best = -1.0
    for body in BODY_NAMES:
        foot = BODIES[body]["Foot"]
        top = foot["at"][1] + foot["size"][1] / 2
        leg = BODIES[body]["LowerLeg"]
        best = max(best, (top - leg["at"][1]) / (leg["size"][1] / 2))
    return best


def _torso_top():
    return NOMINAL["UpperTorso"][1] / 2


WRIST_U = _hand_top_u()
ANKLE_U = _foot_top_u()
HEM_U = ANKLE_U - 0.08  # the trousers' hem: a few hundredths of a stud over the shoe's top


# The garments --------------------------------------------------------------------
#
# Built layer by layer (wardrobe()): every garment's bare pieces (Piece);
# the body inside each; then from the inside out, each piece's mesh is built
# (with its collars, plackets, pockets, buttons and bands, on its settled
# surface) and the pieces over it pushed out over that finished mesh before
# they're built in turn.


class Garment:
    def __init__(self, name, slot):
        self.name, self.slot = name, slot
        self.pieces = {}
        self.objects = {}  # key -> built object (the left side's)
        self.tucked = False
        self.high = False

    def add(self, key, piece):
        self.pieces[key] = piece
        return piece


def _top(name, margin, sleeve_margin, tucked, swell=None, sleeve_swell=None, lower_sleeve_swell=None):
    g = Garment(name, "Top")
    g.tucked = tucked
    g.add("Torso", Piece(name + "Torso", "UpperTorso", margin, caps=(False, True), swell=swell, rows=20))
    # The forearm's sleeve ends at the wrist (the hand's top), open: the
    # forearm goes into the hand there. The upper sleeve covers its top (at
    # the elbow the upper arm is the wider, on the body too).
    g.add("LowerSleeve", Piece(name + "LowerSleeveL", "LowerArm", sleeve_margin, u0=WRIST_U - 0.06, caps=(False, True), swell=lower_sleeve_swell or sleeve_swell))
    g.add("UpperSleeve", Piece(name + "UpperSleeveL", "UpperArm", sleeve_margin, caps=(False, True), swell=sleeve_swell))
    if not tucked:
        # The hem over the hips: a short band of the garment from below the
        # torso's foot up past it (the torso's foot tucks inside it).
        g.add("Hem", Piece(name + "Hem", "LowerTorso", margin + 0.03, u0=-0.62, u1=0.05, rows=6, caps=(False, False)))
    return g


def _bottom(name, margin, swell=None):
    g = Garment(name, "Bottom")
    # The classic leg is mostly thigh: the thigh piece reaches down to the
    # shoe's top and its foot flares over the shin's top, open, so the
    # trouser leg reads as one down to the shoe (and the shin turns inside
    # it at the knee). The shin ends just over the shoe's top (HEM_U): it
    # used to reach well down inside, and the shoe flared round it like a
    # funnel (the owner, 2026-10-15).
    g.add("LowerLeg", Piece(name + "LowerLegL", "LowerLeg", margin, u0=HEM_U, caps=(False, True), swell=swell))
    g.add("UpperLeg", Piece(name + "UpperLegL", "UpperLeg", margin, caps=(False, True), swell=swell))
    g.add("Waist", Piece(name + "Waist", "LowerTorso", margin, u1=0.6, caps=(True, False)))
    return g


def _shoes(name, margin, high):
    g = Garment(name, "Shoes")
    g.high = high
    # A high-top rises over the ankle (shaft()); a low shoe stops at the
    # foot's top, the trousers' hem just over it. Open at the top either way.
    top = 1.48 if high else 0.98
    g.add("Shoe", Piece(name + "L", "Foot", margin, u1=top, rows=12, caps=("flat", False), reach=0.93))
    return g


SPECS = {
    "Flannel": lambda: _top("Flannel", 0.045, 0.04, tucked=True),
    "Cardigan": lambda: _top("Cardigan", 0.07, 0.065, tucked=False, swell=lambda u, t: 0.012 * (1 - abs(u))),
    "Varsity": lambda: _top("Varsity", 0.075, 0.07, tucked=False, swell=lambda u, t: 0.02, sleeve_swell=lambda u, t: 0.015),
    "Windbreaker": lambda: _top(
        "Windbreaker", 0.07, 0.07, tucked=False, swell=lambda u, t: 0.03 * (1 - abs(u)),
        sleeve_swell=lambda u, t: 0.025, lower_sleeve_swell=lambda u, t: 0.012 + 0.02 * (1 + u) / 2,
    ),
    "Jeans": lambda: _bottom("Jeans", 0.035),
    "Cords": lambda: _bottom("Cords", 0.035, swell=lambda u, t: 0.008),
    # (Low-tops: on the classic body the shin is as wide as the foot's top,
    # so a high-top's shaft came out a bucket, 2026-10-15.)
    "Sneaker": lambda: _shoes("Sneaker", 0.03, high=False),
    "Loafer": lambda: _shoes("Loafer", 0.025, high=False),
}

BELT = (-0.15, 0.3)  # the trousers' belt (and waistband), as the lower torso's height


def shaft(piece, from_u=0.35):
    """A boot's shaft: from the ankle up, never narrower than further up, so
    it rises straight instead of pinching in at the foot's top."""
    rows = [i for i, u in enumerate(piece.us) if u >= from_u]
    for k in range(piece.count):
        for i in reversed(rows[:-1]):
            above = piece.grid_point(i + 1, k)
            here = piece.grid_point(i, k)
            need = math.hypot(above.x, above.z) * 0.985 - math.hypot(here.x, here.z)
            if need > 0:
                piece.extra[i][k] += need


def mesh_points(obj, to_piece, sides=None, keep=None):
    """A built object's vertices in a piece's frame, on both bodies (a limb's
    from both sides when the piece is on the middle of the body). keep(point
    in the object's own frame) -> bool filters them."""
    part = obj["part"]
    verts = [B2G(v.co) for v in obj.data.vertices]
    if keep:
        verts = [v for v in verts if keep(v)]
    if sides is None:
        sides = ("L", "R") if part in LIMBS and to_piece.part not in LIMBS else ("L",)
    out = []
    for side in sides:
        out += points_in(verts, part, side, to_piece.part, to_piece.side)
    return out


def wardrobe(names=None):
    """Builds the garments (all, or `names`), layer over layer: returns
    (garments, objects by name, settle log)."""
    names = names or list(SPECS)
    garments = [SPECS[n]() for n in names]
    tops = [g for g in garments if g.slot == "Top"]
    bottoms = [g for g in garments if g.slot == "Bottom"]
    shoes = [g for g in garments if g.slot == "Shoes"]
    log = []

    def note(what, n):
        if n:
            log.append("%s: %d points pushed it out" % (what, n))

    def cover(piece, objs, what, keep=None, u_range=None):
        pts = []
        for obj in objs:
            pts += mesh_points(obj, piece, keep=keep)
        note("%s over %s" % (piece.name, what), piece.cover(pts, GAP, u_range))

    # The body inside every piece of its own part, and the hand's top inside
    # the sleeve's end where it reaches in.
    for g in garments:
        for piece in g.pieces.values():
            note("%s over its body" % piece.name, piece.cover(body_points(piece.part, "L", piece.part, "L"), GAP))
    for g in tops:
        lp = g.pieces["LowerSleeve"]
        note("%s over the hand" % lp.name, lp.cover(body_points("Hand", "L", "LowerArm", "L"), GAP))
    # Inner pieces tucked inside the pieces over them where they meet, so
    # those keep their own shape: the forearm's sleeve in the upper sleeve,
    # the shin in the thigh, the thighs' tops in the seat.
    for t in tops:
        note("%s tucked in" % t.pieces["LowerSleeve"].name, tuck(t.pieces["LowerSleeve"], t.pieces["UpperSleeve"]))
    for b in bottoms:
        note("%s tucked in" % b.pieces["LowerLeg"].name, tuck(b.pieces["LowerLeg"], b.pieces["UpperLeg"]))
        note("%s tucked in" % b.pieces["UpperLeg"].name, tuck(b.pieces["UpperLeg"], b.pieces["Waist"]))
    # The shoes round the feet; the trousers' shins just over their tops
    # (the hem, no more: a shoe swallowing the trouser leg flared like a
    # funnel, 2026-10-15); then the thighs over the shins and the shoes, and
    # the seat over the thighs.
    for s in shoes:
        # Its collar round the ankle (the body's shin, which on the classic
        # body is wider than the foot's top: hugging the foot, the shoe left
        # a sliver of ankle under the hem).
        shoe = s.pieces["Shoe"]
        note("%s round the ankle" % shoe.name, shoe.cover(body_points("LowerLeg", "L", "Foot", "L"), GAP))
        if s.high:
            shaft(shoe)
        s.objects["Shoe"] = DRESS[s.name]["shoe"](s)
    for b in bottoms:
        cover(b.pieces["LowerLeg"], [s.objects["Shoe"] for s in shoes], "the shoes' tops")
        b.objects["LowerLeg"] = DRESS[b.name]["lower"](b)
    for b in bottoms:
        cover(b.pieces["UpperLeg"], [b.objects["LowerLeg"]] + [s.objects["Shoe"] for s in shoes], b.name + "'s shin and the shoes")
        upper = DRESS[b.name]["upper"](b)
        cover(b.pieces["Waist"], [upper], b.name + "'s thighs")
        b.objects["UpperLeg"] = upper
    # Sleeves: the forearm's, then the upper sleeve over it.
    for t in tops:
        lower = DRESS[t.name]["lower"](t)
        cover(t.pieces["UpperSleeve"], [lower], t.name + "'s forearm")
        upper = DRESS[t.name]["upper"](t)
        t.objects.update(LowerSleeve=lower, UpperSleeve=upper)
    # A tucked-in shirt: the trousers' waist inside it above the belt's top,
    # its tail inside the trousers below.
    for t in [g for g in tops if g.tucked]:
        torso = t.pieces["Torso"]
        for b in bottoms:
            waist = b.pieces["Waist"]
            above = [p for p in waist.points() if p.y / waist.hy > BELT[1]]
            note("%s over %s's waist" % (torso.name, b.name), torso.cover(points_in(above, "LowerTorso", "L", "UpperTorso", "L"), GAP))
        t.objects["Torso"] = DRESS[t.name]["torso"](t)
        for b in bottoms:
            waist = b.pieces["Waist"]
            belt_top = BELT[1] * waist.hy
            cover(waist, [t.objects["Torso"]], t.name + "'s tail", keep=None, u_range=(-1.0, BELT[1]))
            del belt_top
    # The trousers' waist, then the belt (or waistband) over it and any tail.
    for b in bottoms:
        b.objects["Waist"] = DRESS[b.name]["waist"](b)
        waist = b.pieces["Waist"]
        belt = waist.band(b.name + "Belt", BELT[0], BELT[1], 0.012, thickness=0.018)
        b.pieces["Belt"] = belt
        cover(belt, [b.objects["Waist"]] + [t.objects["Torso"] for t in tops if t.tucked], "the waist and tails", u_range=BELT)
        b.objects["Belt"] = DRESS[b.name]["belt"](b)
    # The other tops' bodies, then their hems over their own foot and every
    # trouser's waist, belt and thighs.
    for t in [g for g in tops if not g.tucked]:
        # Its body over every trouser's waist and belt where they reach up
        # under it (the hem covers them lower down).
        cover(t.pieces["Torso"], [o for b in bottoms for o in (b.objects["Waist"], b.objects["Belt"])], "the waists and belts")
        t.objects["Torso"] = DRESS[t.name]["torso"](t)
        hem = t.pieces["Hem"]
        under_hem = [t.objects["Torso"]]
        for b in bottoms:
            under_hem += [b.objects["Waist"], b.objects["Belt"], b.objects["UpperLeg"]]
        cover(hem, under_hem, "its body, the waists, belts and thighs")
        t.objects["Hem"] = DRESS[t.name]["hem"](t)
    # Then the right sides (mirrored) and the finished pieces.
    built = {}
    for g in garments:
        for obj in DRESS[g.name]["finish"](g):
            built[obj.name] = obj
    return garments, built, log


def check(garments, built):
    """Every layer against the ones under it, from the built meshes: how far
    any vertex of the inner layer comes through the outer one (studs; 0 is
    clean), on both bodies. Returns report lines."""
    tops = [g for g in garments if g.slot == "Top"]
    bottoms = [g for g in garments if g.slot == "Bottom"]
    shoes = [g for g in garments if g.slot == "Shoes"]
    pairs = []
    for g in bottoms:
        pairs += [(g.pieces["UpperLeg"], g.objects["LowerLeg"]), (g.pieces["Waist"], g.objects["UpperLeg"])]
    for g in tops:
        pairs.append((g.pieces["UpperSleeve"], g.objects["LowerSleeve"]))
        if not g.tucked:
            pairs.append((g.pieces["Hem"], g.objects["Torso"]))
            for b in bottoms:
                for key in ("Waist", "UpperLeg"):
                    pairs.append((g.pieces["Hem"], b.objects[key]))
                pairs.append((g.pieces["Torso"], b.objects["Waist"]))
        else:
            for b in bottoms:
                pairs.append((b.pieces["Belt"], g.objects["Torso"]))
    for s in shoes:
        for b in bottoms:
            pairs += [(b.pieces["LowerLeg"], s.objects["Shoe"]), (b.pieces["UpperLeg"], s.objects["Shoe"])]
    lines = []
    worst = 0.0
    for outer, inner in pairs:
        deepest, count = 0.0, 0
        for q in mesh_points(inner, outer):
            hit = outer.radius_at(q)
            if hit is None:
                continue
            surface, dist, u, theta = hit
            # (A piece is built with one subdivision: its mesh sits a hair
            # inside its rings.)
            through = dist - (surface - 0.003)
            if through > 0:
                count += 1
                deepest = max(deepest, through)
        worst = max(worst, deepest)
        lines.append("%-24s over %-24s %s" % (outer.name, inner.name, "clean" if count == 0 else "%d through, deepest %.3f" % (count, deepest)))
    lines.append("worst %.3f" % worst)
    return lines


# Dressing each garment: its pieces' meshes, materials and details. Each
# garment's DRESS entry builds one piece at a time (wardrobe() calls them
# from the inside out); "finish" mirrors the limbs and names the pieces.


def _finish(obj, name, part):
    obj.name = name
    obj.data.name = name
    obj["part"] = part
    return obj


def _lower_sleeve(g, ml, cuff=None, more=()):
    lp = g.pieces["LowerSleeve"]
    lower = mats(lp.build(), *ml)
    extra = []
    if cuff:
        index, height, add = cuff
        extra.append(paint(mats(lp.band(g.name + "CuffL", lp.us[0], lp.us[0] + height, add, thickness=0.022).build(subdivide=0), *ml), index))
    for make, index in more:
        extra.append(paint(mats(make(), *ml), index))
    if extra:
        lower = join([lower] + extra, g.name + "LowerSleeveL")
    return _finish(lower, g.name + "LowerSleeveL", "LowerArm")


def _upper_sleeve(g, ml, more=()):
    up = g.pieces["UpperSleeve"]
    upper = mats(up.build(), *ml)
    extra = [paint(mats(make(), *ml), index) for make, index in more]
    if extra:
        upper = join([upper] + extra, g.name + "UpperSleeveL")
    return _finish(upper, g.name + "UpperSleeveL", "UpperArm")


def _finish_top(g):
    out = [g.objects["Torso"]]
    if "Hem" in g.objects:
        out.append(g.objects["Hem"])
    upper, lower = g.objects["UpperSleeve"], g.objects["LowerSleeve"]
    out += [upper, lower, mirror(upper, g.name + "UpperSleeveR"), mirror(lower, g.name + "LowerSleeveR")]
    return out


def _finish_bottom(g):
    waist = _finish(join([g.objects["Waist"], g.objects["Belt"]], g.name + "Waist"), g.name + "Waist", "LowerTorso")
    # (The waist and belt are one piece now: what the checks look at.)
    g.objects["Waist"] = waist
    g.objects.pop("Belt")
    upper, lower = g.objects["UpperLeg"], g.objects["LowerLeg"]
    return [waist, upper, lower, mirror(upper, g.name + "UpperLegR"), mirror(lower, g.name + "LowerLegR")]


def _finish_shoes(g):
    left = g.objects["Shoe"]
    return [left, mirror(left, g.name + "R")]


# The flannel shirt.

def _flannel_mats():
    return [
        cm.flannel("Flannel", (150, 34, 30), (40, 22, 22), (196, 160, 70)),
        cm.plain("ShirtButton", (232, 226, 210), 0.35, bump=0.02, folds=0.0),
    ]


def flannel_torso(g):
    """A plaid flannel shirt, tucked in: a point collar, a button placket,
    two flapped chest pockets; red and black with a thin gold line."""
    ml = _flannel_mats()
    t = g.pieces["Torso"]
    torso = mats(t.build(), *ml)
    top = _torso_top()
    parts = [torso, mats(neck_collar("FlannelCollar", top - 0.03, 0.14, 0.022, open_front=0.24, flare=0.05), *ml)]
    for side in (-1, 1):
        parts.append(mats(patch("FlannelCollarPoint", t, 0.86, FRONT + side * 0.3, 0.24, 0.2, 0.004, depth=0.014, tilt=side * 30), *ml))
    parts.append(mats(patch("FlannelPlacket", t, -0.05, FRONT, 0.11, 1.62, 0.0, depth=0.012), *ml))
    buttons = [button("FlannelButton", t, u, FRONT, 0.008, radius=0.028) for u in (0.62, 0.3, -0.02, -0.34, -0.66)]
    for side in (-1, 1):
        theta = FRONT + side * 0.55
        parts.append(mats(patch("FlannelPocket", t, 0.3, theta, 0.36, 0.38, 0.0, depth=0.012), *ml))
        parts.append(mats(patch("FlannelPocketFlap", t, 0.5, theta, 0.38, 0.12, 0.012, depth=0.012), *ml))
        buttons.append(button("FlannelPocketButton", t, 0.46, theta, 0.024, radius=0.022))
    for b in buttons:
        paint(mats(b, *ml), 1)
    return _finish(join(parts + buttons, "FlannelTorso"), "FlannelTorso", "UpperTorso")


def flannel_lower(g):
    lp = g.pieces["LowerSleeve"]
    btn = (lambda: button("FlannelCuffButton", lp, lp.us[0] + 0.12, math.pi, 0.03, radius=0.02), 1)
    return _lower_sleeve(g, _flannel_mats(), cuff=(0, 0.26, 0.004), more=[btn])


# The cardigan.

def _cardigan_mats():
    return [
        cm.knit("CardiganKnit", (196, 150, 58), (120, 86, 30)),
        cm.rib("CardiganRib", (182, 138, 52)),
        cm.leather("CardiganButton", (70, 42, 26), 0.55),
        cm.plain("CardiganSuede", (96, 66, 44), 0.97, bump=0.3, scale=60.0, folds=0.1),
    ]


def cardigan_torso(g):
    """A chunky mustard knit cardigan over the hips: a ribbed neck and button
    band, four leather-knot buttons, patch pockets."""
    ml = _cardigan_mats()
    t = g.pieces["Torso"]
    torso = mats(t.build(), *ml)
    top = _torso_top()
    parts = [torso, paint(mats(neck_collar("CardiganNeck", top - 0.03, 0.1, 0.03, open_front=0.34, flare=0.02), *ml), 1)]
    # The button band stops above the hem (the hem covers the rest).
    parts.append(paint(mats(patch("CardiganBand", t, -0.08, FRONT, 0.13, 1.3, 0.0, depth=0.016), *ml), 1))
    for side in (-1, 1):
        parts.append(paint(mats(patch("CardiganVee", t, 0.66, FRONT + side * 0.16, 0.11, 0.46, 0.0, depth=0.016, tilt=-side * 24), *ml), 1))
        parts.append(mats(patch("CardiganPocket", t, -0.56, FRONT + side * 0.6, 0.42, 0.34, 0.0, depth=0.01, bevel=0.004), *ml))
    buttons = [paint(mats(button("CardiganButton", t, u, FRONT, 0.014, radius=0.045, height=0.026), *ml), 2) for u in (0.36, 0.04, -0.28, -0.6)]
    return _finish(join(parts + buttons, "CardiganTorso"), "CardiganTorso", "UpperTorso")


def cardigan_hem(g):
    ml = _cardigan_mats()
    h = g.pieces["Hem"]
    hem = mats(h.build(), *ml)
    band = paint(mats(h.band("CardiganHemBand", h.us[0], h.us[0] + 0.5, 0.004, thickness=0.024).build(subdivide=0), *ml), 1)
    return _finish(join([hem, band], "CardiganHem"), "CardiganHem", "LowerTorso")


def cardigan_upper(g):
    up = g.pieces["UpperSleeve"]
    # Suede patches on the elbows (the back of the upper sleeve's foot).
    elbow = (lambda: patch("CardiganElbow", up, -0.62, BACK, 0.3, 0.34, 0.0, depth=0.012), 3)
    return _upper_sleeve(g, _cardigan_mats(), more=[elbow])


# The varsity jacket.

def _varsity_mats():
    return [
        cm.plain("VarsityWool", (28, 66, 44), 0.94, bump=0.08, scale=50.0, folds=0.3),
        cm.leather("VarsityLeather", (226, 214, 186), 0.42),
        cm.rib("VarsityRib", (28, 66, 44)),
        cm.rib("VarsityStripe", (232, 220, 190)),
        cm.metal("VarsitySnap", (176, 140, 70), 0.3),
        cm.plain("VarsityChenille", (232, 220, 190), 0.98, bump=0.6, scale=150.0, folds=0.0),
    ]


def varsity_torso(g):
    """A letterman's jacket: bottle-green melton wool, a ribbed collar
    striped in cream, brass snaps, a chenille C on the chest, welt pockets
    edged in leather."""
    ml = _varsity_mats()
    t = g.pieces["Torso"]
    torso = mats(t.build(), *ml)
    top = _torso_top()
    collar = paint(mats(neck_collar("VarsityCollar", top - 0.03, 0.16, 0.035, open_front=0.26, flare=0.03), *ml), 2)
    stripes = []
    for s in (0.5, 0.7):
        y = top - 0.03 + 0.16 * s
        r = max(head_radius(y) + GAP, max(head_radius(top - 0.03), 0.3)) + 0.03 * s * s + 0.035 * math.sin(s * math.pi) + 0.003
        stripes.append(paint(mats(collar_ring("VarsityCollarStripe", y, r, 0.018, 0.0, 0.002, open_front=0.26, rows=2), *ml), 3))
    snaps = [paint(mats(button("VarsitySnap", t, u, FRONT, 0.004, radius=0.03, height=0.018), *ml), 4) for u in (0.66, 0.34, 0.02, -0.3, -0.62)]
    letter = paint(mats(letter_c("VarsityLetter", t, 0.34, FRONT - 0.62, 0.17, 0.05, 0.02), *ml), 5)
    edge = paint(mats(letter_c("VarsityLetterEdge", t, 0.34, FRONT - 0.62, 0.17, 0.075, 0.004, depth=0.018), *ml), 2)
    welts = [paint(mats(patch("VarsityWelt", t, -0.58, FRONT + side * 0.62, 0.06, 0.34, 0.0, depth=0.014, tilt=side * 25), *ml), 1) for side in (-1, 1)]
    return _finish(join([torso, collar] + stripes + snaps + [letter, edge] + welts, "VarsityTorso"), "VarsityTorso", "UpperTorso")


def varsity_hem(g):
    ml = _varsity_mats()
    h = g.pieces["Hem"]
    hem = paint(mats(h.build(), *ml), 2)
    stripes = [paint(mats(h.band("VarsityBandStripe", u, u + 0.08, 0.002, thickness=0.004).build(subdivide=0), *ml), 3) for u in (-0.42, -0.26)]
    return _finish(join([hem] + stripes, "VarsityHem"), "VarsityHem", "LowerTorso")


def _leather(obj):
    for poly in obj.data.polygons:
        if poly.material_index == 0:
            poly.material_index = 1
    return obj


def varsity_lower(g):
    lp = g.pieces["LowerSleeve"]
    stripe = (lambda: lp.band("VarsityCuffStripeL", lp.us[0] + 0.14, lp.us[0] + 0.2, 0.03, thickness=0.004).build(subdivide=0), 3)
    return _leather(_lower_sleeve(g, _varsity_mats(), cuff=(2, 0.34, 0.006), more=[stripe]))


def varsity_upper(g):
    return _leather(_upper_sleeve(g, _varsity_mats()))


# The windbreaker.

def _wind_mats():
    teal_c, purple_c, white_c = (38, 128, 132), (104, 52, 118), (226, 224, 216)
    return [
        cm.blocks("WindChest", [teal_c, white_c, purple_c, teal_c], [0.02, 0.17, 0.4], chevron=0.28),
        cm.nylon("WindTeal", teal_c),
        cm.rib("WindElastic", (34, 40, 44)),
        cm.metal("WindZip", (150, 150, 156), 0.35),
        cm.blocks("WindSleeve", [teal_c, white_c, purple_c, teal_c], [-0.16, -0.02, 0.2]),
    ]


def windbreaker_torso(g):
    """A colour-block nylon windbreaker: teal with a white and purple chevron
    across the chest, a stand collar and a front zip."""
    ml = _wind_mats()
    t = g.pieces["Torso"]
    torso = mats(t.build(), *ml)
    top = _torso_top()
    collar = paint(mats(neck_collar("WindCollar", top - 0.03, 0.2, 0.04, open_front=0.05, flare=0.02), *ml), 1)
    # The zip stops at the hem (which carries on over it).
    zipper = paint(mats(patch("WindZipper", t, 0.08, FRONT, 0.035, 1.72, 0.0, depth=0.01), *ml), 3)
    pull = paint(mats(patch("WindPull", t, 0.88, FRONT, 0.045, 0.1, 0.012, depth=0.012), *ml), 3)
    return _finish(join([torso, collar, zipper, pull], "WindbreakerTorso"), "WindbreakerTorso", "UpperTorso")


def windbreaker_hem(g):
    h = g.pieces["Hem"]
    return _finish(paint(mats(h.build(), *_wind_mats()), 2), "WindbreakerHem", "LowerTorso")


def windbreaker_lower(g):
    obj = _lower_sleeve(g, _wind_mats(), cuff=(2, 0.3, 0.004))
    for poly in obj.data.polygons:
        if poly.material_index == 0:
            poly.material_index = 1
    return obj


def windbreaker_upper(g):
    obj = _upper_sleeve(g, _wind_mats())
    for poly in obj.data.polygons:
        if poly.material_index == 0:
            poly.material_index = 4
    return obj


# Trousers.

def _jeans_mats():
    return [
        cm.denim("Denim", (52, 74, 112), (150, 172, 200)),
        cm.leather("BeltLeather", (74, 44, 26), 0.45),
        cm.metal("BeltBrass", (180, 146, 80), 0.28),
    ]


def _cords_mats():
    return [cm.corduroy("Cord", (150, 112, 70)), cm.plain("CordBand", (132, 96, 58), 0.9, bump=0.1, folds=0.1)]


def _shin(g, ml, cuff=None):
    """The shin, and for jeans a rolled cuff at its hem, over the shoe's top (cuff
    = (material index, add))."""
    lp = g.pieces["LowerLeg"]
    shin = mats(lp.build(), *ml)
    if cuff:
        index, add = cuff
        c = lp.band(g.name + "CuffL", HEM_U, HEM_U + 0.2, add, thickness=0.02).build(subdivide=0)
        shin = join([shin, paint(mats(c, *ml), index)], g.name + "LowerLegL")
    return _finish(shin, g.name + "LowerLegL", "LowerLeg")


def _thigh(g, ml, cuff=None):
    """The thigh, and the trousers' foot: a rolled cuff for jeans (cuff =
    (material index, height in u, add))."""
    up = g.pieces["UpperLeg"]
    upper = mats(up.build(), *ml)
    if cuff:
        index, height, add = cuff
        c = up.band(g.name + "CuffL", up.us[0], up.us[0] + height, add, thickness=0.026).build(subdivide=0)
        upper = join([upper, paint(mats(c, *ml), index)], g.name + "UpperLegL")
    return _finish(upper, g.name + "UpperLegL", "UpperLeg")


def jeans_waist(g):
    """Stonewashed high-waisted jeans (their seat; the belt is jeans_belt)."""
    return _finish(mats(g.pieces["Waist"].build(), *_jeans_mats()), "JeansWaistBody", "LowerTorso")


def jeans_belt(g):
    """A brown leather belt and a brass buckle."""
    ml = _jeans_mats()
    belt = g.pieces["Belt"]
    strap = paint(mats(belt.build(subdivide=0), *ml), 1)
    buckle = paint(mats(patch("JeansBuckle", belt, (BELT[0] + BELT[1]) / 2, FRONT, 0.2, 0.15, 0.016, depth=0.022, bevel=0.012), *ml), 2)
    return _finish(join([strap, buckle], "JeansBelt"), "JeansBelt", "LowerTorso")


def cords_waist(g):
    """Tan corduroy trousers: their seat, slant pockets."""
    ml = _cords_mats()
    w = g.pieces["Waist"]
    seat = mats(w.build(), *ml)
    pockets = [paint(mats(patch("CordsPocket", w, -0.5, FRONT + side * 0.85, 0.05, 0.36, 0.004, depth=0.008, tilt=side * 30), *ml), 1) for side in (-1, 1)]
    return _finish(join([seat] + pockets, "CordsWaistBody"), "CordsWaistBody", "LowerTorso")


def cords_belt(g):
    """The corduroys' waistband."""
    return _finish(paint(mats(g.pieces["Belt"].build(subdivide=0), *_cords_mats()), 1), "CordsBand", "LowerTorso")


# Shoes.

def sneaker(g):
    """White leather low-tops: a gum-white rubber sole, laces up the
    instep, a red stripe down each side (the trousers' hem over its top)."""
    ml = [
        cm.leather("SneakerLeather", (232, 228, 218), 0.5),
        cm.plain("SneakerRubber", (216, 206, 182), 0.75, bump=0.05, folds=0.0),
        cm.plain("SneakerLace", (244, 242, 236), 0.85, bump=0.3, scale=120.0, folds=0.0),
        cm.leather("SneakerStripe", (170, 40, 36), 0.45),
    ]
    s = g.pieces["Shoe"]
    body = mats(s.build(), *ml)
    sole = paint(mats(s.band("SneakerSole", -1.0, -0.62, 0.012, thickness=0.03).build(subdivide=0), *ml), 1)
    stripes = [paint(mats(lay("SneakerStripe", s, -0.05, a, 0.5, 0.08, 0.0, depth=0.006, tilt=-20 * side), *ml), 3) for side, a in ((-1, math.pi), (1, 0.0))]
    # The tongue up the instep, and laces across it.
    tongue = mats(lay("SneakerTongue", s, 0.32, FRONT, 0.22, 0.42, 0.004, depth=0.016), *ml)
    laces = [paint(mats(lay("SneakerLace", s, u, FRONT, 0.26, 0.032, 0.018, depth=0.014, tilt=t), *ml), 2) for u, t in ((0.12, 8), (0.26, -8), (0.4, 8), (0.54, -8))]
    toe = paint(mats(s.band("SneakerToe", -0.62, -0.3, 0.004, thickness=0.012, a0=FRONT - 0.7, a1=FRONT + 0.7).build(subdivide=0), *ml), 1)
    return _finish(join([body, sole, tongue, toe] + stripes + laces, "SneakerL"), "SneakerL", "Foot")


def loafer(g):
    """Brown penny loafers: smooth leather, a stitched apron over the toe, a
    strap across the instep, a thin dark sole."""
    ml = [cm.leather("LoaferLeather", (96, 56, 32), 0.4), cm.plain("LoaferSole", (40, 28, 22), 0.6, bump=0.05, folds=0.0)]
    s = g.pieces["Shoe"]
    body = mats(s.build(), *ml)
    sole = paint(mats(s.band("LoaferSole", -1.0, -0.72, 0.01, thickness=0.02).build(subdivide=0), *ml), 1)
    strap = mats(lay("LoaferStrap", s, 0.55, FRONT, 0.42, 0.1, 0.0, depth=0.014), *ml)
    apron = mats(s.band("LoaferApron", 0.05, 0.13, 0.003, thickness=0.01, a0=FRONT - 0.9, a1=FRONT + 0.9).build(subdivide=0), *ml)
    return _finish(join([body, sole, strap, apron], "LoaferL"), "LoaferL", "Foot")


DRESS = {
    "Flannel": {
        "torso": flannel_torso,
        "lower": flannel_lower,
        "upper": lambda g: _upper_sleeve(g, _flannel_mats()),
        "finish": _finish_top,
    },
    "Cardigan": {
        "torso": cardigan_torso,
        "hem": cardigan_hem,
        "lower": lambda g: _lower_sleeve(g, _cardigan_mats(), cuff=(1, 0.3, 0.004)),
        "upper": cardigan_upper,
        "finish": _finish_top,
    },
    "Varsity": {"torso": varsity_torso, "hem": varsity_hem, "lower": varsity_lower, "upper": varsity_upper, "finish": _finish_top},
    "Windbreaker": {
        "torso": windbreaker_torso,
        "hem": windbreaker_hem,
        "lower": windbreaker_lower,
        "upper": windbreaker_upper,
        "finish": _finish_top,
    },
    "Jeans": {
        "lower": lambda g: _shin(g, _jeans_mats(), cuff=(0, 0.006)),
        "upper": lambda g: _thigh(g, _jeans_mats()),
        "waist": jeans_waist,
        "belt": jeans_belt,
        "finish": _finish_bottom,
    },
    "Cords": {
        "lower": lambda g: _shin(g, _cords_mats()),
        "upper": lambda g: _thigh(g, _cords_mats()),
        "waist": cords_waist,
        "belt": cords_belt,
        "finish": _finish_bottom,
    },
    "Sneaker": {"shoe": sneaker, "finish": _finish_shoes},
    "Loafer": {"shoe": loafer, "finish": _finish_shoes},
}


def _proxy(body):
    """The measured body as plain capsules, for the previews (never
    exported). The right side's limbs mirrored."""
    out = []
    skin = cm.plain("ProxySkin", (214, 170, 130), 0.6, bump=0.0, folds=0.0)
    for name, part in BODIES[body].items():
        size = part["size"]
        hx, hz = size[0] / 2, size[2] / 2
        for side in ("L", "R") if name in LIMBS else ("L",):
            bm = bmesh.new()
            rows = []
            for y, radii in part["rings"]:
                samples = _polar(size, radii)
                row = []
                for k in range(36):
                    theta = TAU * k / 36
                    r = _at_angle(samples, theta) if samples else 0.0
                    c, s = math.cos(theta), math.sin(theta)
                    x = r * c * hx
                    at = place_of(body, name, side)
                    row.append(bm.verts.new(G((-x if side == "R" else x) + at.x, y + at.y, r * s * hz + at.z)))
                rows.append(row)
            for i in range(len(rows) - 1):
                for k in range(36):
                    bm.faces.new((rows[i][k], rows[i][(k + 1) % 36], rows[i + 1][(k + 1) % 36], rows[i + 1][k]))
            bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
            obj = _object("Proxy" + body + name + side, bm)
            mats(obj, skin)
            out.append(obj)
    return out
