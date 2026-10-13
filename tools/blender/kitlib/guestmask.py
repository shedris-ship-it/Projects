"""The Guest's mask (V5, the Guest remodelled; docs/ART.md "The Guest").

A porcelain doll's face over the black: a high smooth brow, big round eye
holes with painted lashes and a fine line round them, thin high brows, a
small nose, rouge on full cheeks, and a little painted rosebud mouth. Across
it, cheek to cheek, a hairline the porcelain will tear along: the grin.

It's a face that moves, which porcelain must not:
  - the grin tears open past the painted mouth along the hairline, as wide
    as it's asked (Lib/GuestMask), on two rows of small uneven teeth,
    clenched; every column of the lips has a bone of its own (fU01..,
    fL01..);
  - everything under the hairline is a jaw, hinged like a ventriloquist's
    dummy's (fJaw), that drops;
  - the cheeks bunch (fCheek), the eye holes squeeze to crescents or droop
    (fEyeUp, fEyeLo), the brows climb (fBrow).
The face's poses are set here (POSES) and carried into the game
(Data/GuestRig), so what's seen in Blender is what the game blends.

Its forms (Logic/GuestPose: 0 Calm, 1 Fraying, 2 Breaking) blend in the
game: two shells over the glaze, worn and broken, fade in (crazing and
tear-tracks; fractures and stains), and at Breaking three pieces come away
(the shards) and fall.

Coordinates: mask-local studs in the game's axes, about the mask's centre,
which sits on the head as Lib/GuestFace set the old mask (low and forward);
the head is GuestPose.Rig's. Points on it are found by (theta, phi) on an
ellipsoid as GuestPose.surface finds them (theta + toward his left), then
moved along its normal by the features.
"""

import math

import bmesh
import bpy
import numpy as np
from mathutils import Vector

from . import materials
from .guestrig import G2B, RIG, smoothstep

TAU = math.pi * 2
D2R = math.pi / 180

HEAD = RIG["headSize"]
A = HEAD[0] / 2 * 0.94  # the mask's half-width
B = HEAD[1] / 2 * 0.82  # half-height
C = HEAD[2] / 2 * 0.7  # depth
# Its centre in the model (the head's, low and forward: Lib/GuestFace).
CENTRE = Vector((0.0, RIG["headY"] - HEAD[1] * 0.07, -HEAD[2] / 2 * 0.42))
HEAD_CENTRE = Vector((0.0, RIG["headY"], 0.0)) - CENTRE  # mask-local

THICK = 0.016  # the porcelain
EYE_R = 0.085
EYES = {"L": (0.4, 0.2), "R": (-0.4, 0.2)}  # (theta, phi): + theta is his left
COLUMNS = 15  # the lips' bones across the grin

# The outline: an oval in (theta, phi).
RIM_THETA = 78 * D2R
RIM_PHI0 = 4 * D2R
RIM_PHI = 74 * D2R


def phi_top(th):
    k = max(0.0, 1 - (th / RIM_THETA) ** 2)
    return RIM_PHI0 + RIM_PHI * math.sqrt(k)


def phi_bot(th):
    k = max(0.0, 1 - (th / RIM_THETA) ** 2)
    return RIM_PHI0 - RIM_PHI * math.sqrt(k)


def phi_s(th):
    """The hairline (the grin's path): GuestPose.mouth's crescent, low in
    the middle, the corners climbing the cheeks to the rim; one side
    higher."""
    k = th / (60 * D2R)
    return -30 * D2R + min(26 * D2R * k * k, 44 * D2R) + 4 * D2R * (th / (90 * D2R)) ** 3


def _exit(sign):
    lo, hi = 0.0, RIM_THETA
    for _ in range(60):
        mid = (lo + hi) / 2
        if phi_s(sign * mid) < phi_top(sign * mid):
            lo = mid
        else:
            hi = mid
    return sign * lo


THETA_L = _exit(1)  # where the grin meets the rim on his left
THETA_R = _exit(-1)


def base(th, ph):
    return Vector((-A * math.cos(ph) * math.sin(th), B * math.sin(ph), -C * math.cos(ph) * math.cos(th)))


def base_normal(th, ph):
    p = base(th, ph)
    n = Vector((p.x / (A * A), p.y / (B * B), p.z / (C * C)))
    return n.normalized()


def param_of(x, y):
    ph = math.asin(max(-0.9999, min(0.9999, y / B)))
    th = math.asin(max(-0.9999, min(0.9999, -x / (A * math.cos(ph)))))
    return th, ph


def eye_xy(side):
    th, ph = EYES[side]
    p = base(th, ph)
    return p.x, p.y


def _g(x, y, cx, cy, sx, sy):
    return math.exp(-(((x - cx) / sx) ** 2) - ((y - cy) / sy) ** 2)


def slit_xy(th):
    p = base(th, phi_s(th))
    return p.x, p.y


def relief(x, y):
    """The face's features, studs out along the surface's normal."""
    d = 0.0
    for side in ("L", "R"):
        ex, ey = eye_xy(side)
        r = math.hypot(x - ex, y - ey)
        d -= 0.034 * math.exp(-((r / 0.115) ** 2))  # the socket
        d += 0.02 * _g(x, y, ex * 1.05, ey + 0.112, 0.11, 0.028)  # brow ridge
        d += 0.02 * _g(x, y, ex * 1.24, -0.07, 0.08, 0.07)  # the apple of the cheek
        d += 0.014 * _g(x, y, ex * 1.75, ey - 0.075, 0.07, 0.03)  # the cheekbone
        d -= 0.012 * _g(x, y, ex * 1.85, -0.17, 0.06, 0.06)  # hollow under it
        d -= 0.012 * _g(abs(x), y, 0.29, 0.12, 0.05, 0.12)  # temple
        # The fold from the nose's wing down toward the grin.
        sx = 1 if ex > 0 else -1
        d -= 0.006 * _line_g(x, y, (sx * 0.04, -0.07), (sx * 0.12, -0.17), 0.012)
    # The nose: a narrow bridge rising to a small tip, nostril wings.
    ey = eye_xy("L")[1]
    tip = -0.07
    if y > tip:
        t = max(0.0, min(1.0, (ey + 0.02 - y) / (ey + 0.02 - tip)))
        h = 0.012 + 0.04 * t * t
        sx = 0.019 + 0.016 * t
        d += h * math.exp(-((x / sx) ** 2)) * smoothstep(ey + 0.09, ey - 0.01, y)
    else:
        d += 0.052 * math.exp(-((x / 0.034) ** 2)) * math.exp(-(((y - tip) / 0.02) ** 2))
    d += 0.012 * _g(abs(x), y, 0.03, -0.074, 0.018, 0.016)
    # The rosebud: a little upper and lower lip on the hairline, a groove
    # down from the nose.
    sx_, sy_ = slit_xy(0.0)
    d += 0.007 * _g(x, y, 0.0, sy_ + 0.014, 0.05, 0.014)
    d += 0.009 * _g(x, y, 0.0, sy_ - 0.018, 0.045, 0.016)
    d -= 0.004 * _g(x, y, 0.0, sy_ + 0.06, 0.008, 0.03)
    d += 0.022 * _g(x, y, 0.0, -0.34, 0.07, 0.05)  # the chin
    d -= 0.004 * _g(x, y, 0.0, -0.33, 0.012, 0.012)  # its dimple
    d += 0.008 * _g(x, y, 0.0, 0.28, 0.25, 0.12)  # the brow's dome
    return d


def _line_g(x, y, a, b, width):
    ax, ay = a
    bx, by = b
    dx, dy = bx - ax, by - ay
    t = max(0.0, min(1.0, ((x - ax) * dx + (y - ay) * dy) / (dx * dx + dy * dy)))
    d = math.hypot(x - ax - t * dx, y - ay - t * dy)
    return math.exp(-((d / width) ** 2)) * math.sin(math.pi * t)


def pos(th, ph):
    """A point on the mask (mask-local), and its base (x, y) for paint."""
    p = base(th, ph)
    n = base_normal(th, ph)
    q = p + n * relief(p.x, p.y)
    # A face, not an egg: wider at the cheekbones, the brow a little
    # narrower, a doll's narrow jaw and small chin; flatter across the front.
    q.x *= 1 + 0.05 * math.exp(-(((p.y + 0.02) / 0.12) ** 2))
    q.x *= 1 - 0.05 * smoothstep(0.15, 0.42, p.y)
    q.x *= 1 - 0.18 * smoothstep(-0.12, -0.43, p.y)
    q.z *= 1 - 0.08 * math.exp(-((p.x / 0.22) ** 2) - ((p.y / 0.3) ** 2))
    return q


# Building -------------------------------------------------------------------------

N_COLS = 84
N_UP = 46
N_LOW = 26


def _grid(region):
    """(theta, phi) rows for a region: 'upper' (the hairline to the brow) or
    'lower' (the chin to the hairline); columns shared so the hairline's
    points are the same on both."""
    ths = [THETA_R + (THETA_L - THETA_R) * j / N_COLS for j in range(N_COLS + 1)]
    rows = []
    n = N_UP if region == "upper" else N_LOW
    for i in range(n + 1):
        row = []
        for th in ths:
            s = phi_s(th)
            if region == "upper":
                ph = s + (phi_top(th) - s) * (i / n)
            else:
                ph = phi_bot(th) + (s - phi_bot(th)) * (i / n)
            row.append((th, ph))
        rows.append(row)
    return rows


SHARDS = {
    # Where pieces come away at Breaking (base x, y; jagged): his right
    # temple, his left jaw, the brow above his left eye.
    "A": [(0.205, 0.17), (0.25, 0.155), (0.3, 0.19), (0.322, 0.26), (0.3, 0.33), (0.255, 0.36), (0.228, 0.31), (0.19, 0.29), (0.212, 0.235)],
    "B": [(-0.17, -0.26), (-0.215, -0.24), (-0.26, -0.265), (-0.29, -0.31), (-0.27, -0.36), (-0.225, -0.375), (-0.19, -0.345), (-0.2, -0.3)],
    "C": [(-0.02, 0.31), (-0.06, 0.295), (-0.1, 0.32), (-0.125, 0.36), (-0.09, 0.4), (-0.045, 0.405), (-0.012, 0.38), (-0.03, 0.345)],
}
SHARD_BONE = {"A": "fMask", "B": "fJaw", "C": "fMask"}


def _inside(poly, x, y):
    inside = False
    n = len(poly)
    for i in range(n):
        x1, y1 = poly[i]
        x2, y2 = poly[(i + 1) % n]
        if (y1 > y) != (y2 > y):
            t = (y - y1) / (y2 - y1)
            if x < x1 + t * (x2 - x1):
                inside = not inside
    return inside


def _nearest_on(poly, x, y):
    best, bd = None, 1e9
    n = len(poly)
    for i in range(n):
        ax, ay = poly[i]
        bx, by = poly[(i + 1) % n]
        dx, dy = bx - ax, by - ay
        t = max(0.0, min(1.0, ((x - ax) * dx + (y - ay) * dy) / (dx * dx + dy * dy)))
        qx, qy = ax + t * dx, ay + t * dy
        d = math.hypot(x - qx, y - qy)
        if d < bd:
            best, bd = (qx, qy), d
    return best, bd


def shard_distance(x, y):
    return min(_nearest_on(poly, x, y)[1] for poly in SHARDS.values())


def _region(region):
    """The region's surface as a bmesh with (theta, phi) on each vertex,
    eye holes cut and the shards marked (face layer 'shard': 0 none)."""
    bm = bmesh.new()
    lth = bm.verts.layers.float.new("th")
    lph = bm.verts.layers.float.new("ph")
    lsh = bm.faces.layers.int.new("shard")
    rows = _grid(region)
    vs = []
    for row in rows:
        r = []
        for th, ph in row:
            v = bm.verts.new(base(th, ph))
            v[lth], v[lph] = th, ph
            r.append(v)
        vs.append(r)
    for i in range(len(rows) - 1):
        for j in range(len(rows[0]) - 1):
            quad = (vs[i][j], vs[i][j + 1], vs[i + 1][j + 1], vs[i + 1][j])
            bm.faces.new(quad)
    # The degenerate ends (where the hairline meets the rim) fold together.
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
    bm.verts.ensure_lookup_table()

    def centre_xy(f):
        c = f.calc_center_median()
        return c.x, c.y

    if region == "upper":
        # The eye holes: faces inside the circle go, and the hole's edge is
        # pulled onto it.
        for side in ("L", "R"):
            ex, ey = eye_xy(side)
            gone = [f for f in bm.faces if math.hypot(centre_xy(f)[0] - ex, centre_xy(f)[1] - ey) < EYE_R]
            bmesh.ops.delete(bm, geom=gone, context="FACES")
            for v in bm.verts:
                if v.is_boundary and math.hypot(v.co.x - ex, v.co.y - ey) < EYE_R + 0.02:
                    a = math.atan2(v.co.y - ey, v.co.x - ex)
                    x, y = ex + EYE_R * math.cos(a), ey + EYE_R * math.sin(a)
                    th, ph = param_of(x, y)
                    v[lth], v[lph] = th, ph
                    v.co = base(th, ph)
    # The shards: mark their faces, then pull the edges between onto the
    # break's line.
    for key, poly in SHARDS.items():
        index = ord(key) - ord("A") + 1
        for f in bm.faces:
            x, y = centre_xy(f)
            if _inside(poly, x, y):
                f[lsh] = index
        edge_verts = set()
        for f in bm.faces:
            if f[lsh] == index:
                for v in f.verts:
                    if any(g[lsh] != index for g in v.link_faces):
                        edge_verts.add(v)
        for v in edge_verts:
            (x, y), _ = _nearest_on(poly, v.co.x, v.co.y)
            th, ph = param_of(x, y)
            v[lth], v[lph] = th, ph
            v.co = base(th, ph)
    # Final places, and the paint's layout (the "Pattern" UV: base x, y).
    uv = bm.loops.layers.uv.new("Pattern")
    for v in bm.verts:
        v.co = pos(v[lth], v[lph])
    for f in bm.faces:
        for loop in f.loops:
            th, ph = loop.vert[lth], loop.vert[lph]
            p = base(th, ph)
            loop[uv].uv = face_uv(p.x, p.y)
    return bm


def face_uv(x, y):
    """The paint's layout: the mask seen from the front, (0, 0) at the
    bottom of his right side as you look at him... (u along +x, v up)."""
    return (0.5 + x / (2 * A * 1.02), 0.5 + y / (2 * B * 1.02))


def _object(name, bm):
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    return obj


def _to_model(obj):
    """Mask-local to the model (the armature's frame), into Blender's axes."""
    for v in obj.data.vertices:
        v.co = G2B(Vector(v.co) + CENTRE)
    obj.data.update()


def _attr(obj, name):
    return [d.value for d in obj.data.attributes[name].data]


def _separate_shards(obj):
    """Splits the marked shard faces off into objects of their own."""
    shards = {}
    for key in SHARDS:
        index = ord(key) - ord("A") + 1
        layer = obj.data.attributes.get("shard")
        if layer is None:
            break
        if not any(d.value == index for d in layer.data):
            continue
        bpy.ops.object.select_all(action="DESELECT")
        obj.select_set(True)
        bpy.context.view_layer.objects.active = obj
        bpy.ops.object.mode_set(mode="EDIT")
        bm = bmesh.from_edit_mesh(obj.data)
        bm.select_mode = {"FACE"}
        lsh = bm.faces.layers.int.get("shard")
        for v in bm.verts:
            v.select_set(False)
        for f in bm.faces:
            f.select_set(f[lsh] == index)
        bm.select_flush_mode()
        bmesh.update_edit_mesh(obj.data)
        bpy.ops.mesh.separate(type="SELECTED")
        bpy.ops.object.mode_set(mode="OBJECT")
        new = [o for o in bpy.context.selected_objects if o is not obj][0]
        new.name = "GuestShard" + key
        new.data.name = new.name
        shards[key] = new
    return shards


# Weights ---------------------------------------------------------------------------


def column_thetas():
    return [THETA_R + (THETA_L - THETA_R) * k / (COLUMNS - 1) for k in range(COLUMNS)]


def _column(th):
    cols = column_thetas()
    t = (th - cols[0]) / (cols[-1] - cols[0]) * (COLUMNS - 1)
    k = max(0, min(COLUMNS - 2, int(math.floor(t))))
    return k, max(0.0, min(1.0, t - k))


CHEEKS = {"L": (-0.165, -0.07), "R": (0.165, -0.07)}  # base x, y (his left is -x)


def bone_name(kind, k):
    return "%s%02d" % (kind, k + 1)


def face_weights(th, ph, region):
    p = base(th, ph)
    x, y = p.x, p.y
    upper = region == "upper"
    w = {}
    # The lips: the columns either side, falling off away from the hairline.
    dist = abs(ph - phi_s(th)) * B
    reach = 0.05 if upper else 0.06
    if dist < reach:
        f = (1 - dist / reach) ** 2
        k, t = _column(th)
        kind = "fU" if upper else "fL"
        w[bone_name(kind, k)] = w.get(bone_name(kind, k), 0) + f * (1 - t)
        w[bone_name(kind, k + 1)] = w.get(bone_name(kind, k + 1), 0) + f * t
    if upper:
        for side in ("L", "R"):
            cx, cy = CHEEKS[side]
            w["fCheek" + side] = 0.8 * math.exp(-((math.hypot(x - cx, y - cy) / 0.075) ** 2))
            ex, ey = eye_xy(side)
            r = math.hypot(x - ex, y - ey)
            if r < EYE_R + 0.07:
                f = (1 - max(0.0, r - EYE_R) / 0.07) ** 2
                up = smoothstep(-0.35, 0.35, (y - ey) / max(r, 1e-6))
                w["fEyeUp" + side] = f * up
                w["fEyeLo" + side] = f * (1 - up)
            bx, by = ex * 1.05, ey + 0.13
            w["fBrow" + side] = 0.9 * math.exp(-((math.hypot(x - bx, y - by) / 0.06) ** 2))
    guard = smoothstep(0.0, 0.04, shard_distance(x, y))
    for k in list(w):
        w[k] *= guard
    total = sum(w.values())
    if total > 0.95:
        for k in w:
            w[k] *= 0.95 / total
        total = 0.95
    w["fMask" if upper else "fJaw"] = 1 - total
    return w


def weigh_face(obj, region):
    ths, phs = _attr(obj, "th"), _attr(obj, "ph")
    obj.vertex_groups.clear()
    groups = {}
    for i in range(len(ths)):
        w = face_weights(ths[i], phs[i], region)
        top = sorted(((v, b) for b, v in w.items() if v > 1e-4), reverse=True)[:4]
        total = sum(v for v, _ in top) or 1.0
        for v, b in top:
            g = groups.get(b) or obj.vertex_groups.new(name=b)
            groups[b] = g
            g.add([i], v / total, "REPLACE")


def weigh_all(obj, bone):
    obj.vertex_groups.clear()
    g = obj.vertex_groups.new(name=bone)
    g.add(list(range(len(obj.data.vertices))), 1.0, "REPLACE")


# Bones -----------------------------------------------------------------------------


def _surface_at(x, y):
    th, ph = param_of(x, y)
    return pos(th, ph)


def face_bones():
    """[(bone, parent, head (mask-local))]"""
    ends = (pos(THETA_L, phi_s(THETA_L)), pos(THETA_R, phi_s(THETA_R)))
    hinge = (ends[0] + ends[1]) / 2 + Vector((0, 0, 0.02))
    out = [("fMask", None, Vector((0, 0, 0))), ("fJaw", "fMask", hinge)]
    for k, th in enumerate(column_thetas()):
        at = pos(th, phi_s(th))
        out.append((bone_name("fU", k), "fMask", at))
        out.append((bone_name("fL", k), "fJaw", at))
    for side in ("L", "R"):
        cx, cy = CHEEKS[side]
        out.append(("fCheek" + side, "fMask", _surface_at(cx, cy)))
        ex, ey = eye_xy(side)
        out.append(("fEyeUp" + side, "fMask", _surface_at(ex, ey + EYE_R)))
        out.append(("fEyeLo" + side, "fMask", _surface_at(ex, ey - EYE_R)))
        out.append(("fBrow" + side, "fMask", _surface_at(ex * 1.05, ey + 0.13)))
    return out


def columns():
    """Each lip column: theta, its rest point, the way up the face there
    (the lips part along it) and out (the surface's normal)."""
    out = []
    for th in column_thetas():
        ph = phi_s(th)
        at = pos(th, ph)
        up = (pos(th, ph + 0.01) - pos(th, ph - 0.01)).normalized()
        out_ = base_normal(th, ph)
        out.append({"theta": th, "at": at, "up": up, "out": out_})
    return out


def eye_pins():
    """Where each eye's pin of light sits at rest: deep in the hole."""
    out = {}
    for side in ("L", "R"):
        th, ph = EYES[side]
        out[side] = pos(th, ph) - base_normal(th, ph) * 0.035
    return out


# The face's poses (bone -> (move (x, y, z) studs, turn (x, y, z) degrees),
# mask axes: +y up the face, -z out of it, +x his right). The game blends
# them by weight (Lib/GuestMask); the grin's columns are worked out there
# from its width and opening (lip_pose, below, is the same sum).
POSES = {
    # The grin pushes the cheeks up and squeezes the eye holes into
    # crescents: smiling eyes, on a mask.
    "Smile": {
        "fCheekL": ((0, 0.016, -0.01), None),
        "fCheekR": ((0, 0.016, -0.01), None),
        "fEyeLoL": ((0, 0.034, -0.006), None),
        "fEyeLoR": ((0, 0.034, -0.006), None),
        "fEyeUpL": ((0, -0.006, 0), None),
        "fEyeUpR": ((0, -0.006, 0), None),
        "fBrowL": ((0, 0.006, 0), None),
        "fBrowR": ((0, 0.006, 0), None),
    },
    # Delighted (curious, playing host, held and loving it).
    "BrowUp": {
        "fBrowL": ((0, 0.03, -0.004), None),
        "fBrowR": ((0, 0.03, -0.004), None),
        "fEyeUpL": ((0, 0.014, 0), None),
        "fEyeUpR": ((0, 0.014, 0), None),
    },
    # Irritated: the brows press down and in, the holes narrow.
    "BrowDown": {
        "fBrowL": ((0.008, -0.022, 0.004), None),
        "fBrowR": ((-0.008, -0.022, 0.004), None),
        "fEyeUpL": ((0, -0.022, 0.002), None),
        "fEyeUpR": ((0, -0.022, 0.002), None),
    },
    # Staring: the holes open wide.
    "Wide": {
        "fEyeUpL": ((0, 0.02, 0), None),
        "fEyeUpR": ((0, 0.02, 0), None),
        "fEyeLoL": ((0, -0.022, 0), None),
        "fEyeLoR": ((0, -0.022, 0), None),
    },
    # Breaking: his left eye droops and runs, the other stares, the jaw
    # hangs crooked.
    "Droop": {
        "fEyeLoL": ((-0.01, -0.038, 0), None),
        "fEyeUpL": ((-0.006, -0.026, 0), None),
        "fBrowL": ((0, -0.02, 0), None),
        "fCheekL": ((0, -0.016, 0), None),
        "fEyeUpR": ((0, 0.014, 0), None),
        "fJaw": ((0.004, -0.008, 0), (-3, 0, 5)),
    },
    # The dummy's jaw dropping: down, and a little back.
    "JawOpen": {
        "fJaw": ((0, -0.075, -0.004), (-8, 0, 0)),
    },
}


def lip_pose(width, opening):
    """The grin's columns for a half-width (radians round the head, as
    GuestPose.smile gives it) and how open (0..1): each column parts along
    its up by the share of the grin it's in. The game does the same
    (Lib/GuestMask.lips)."""
    out = {}
    retract = 0.0025 + 0.03 * min(1.0, opening * 1.6)
    for k, col in enumerate(columns()):
        u = abs(col["theta"]) / max(width, 1e-3)
        share = 0.0 if u >= 1 else (1 - u * u) ** 0.6 * smoothstep(1.0, 0.85, u)
        g = retract * share
        up, out_ = col["up"], col["out"]
        out[bone_name("fU", k)] = (tuple(up * (g * 0.7) + out_ * (g * 0.08)), None)
        out[bone_name("fL", k)] = (tuple(up * (-g) + out_ * (g * 0.08)), None)
    return out


# Teeth, the dark behind, the strap ------------------------------------------------------


def teeth(rng):
    """Two rows of small uneven teeth along the hairline, just behind the
    porcelain (they show only where the grin opens): the top row with the
    mask, the bottom with the jaw. A few gone, a few chipped."""
    rows = {"upper": [], "lower": []}
    th = THETA_R + 0.04
    while th < THETA_L - 0.04:
        ph = phi_s(th)
        at = pos(th, ph)
        up = (pos(th, ph + 0.01) - pos(th, ph - 0.01)).normalized()
        along = (pos(th + 0.01, phi_s(th + 0.01)) - pos(th - 0.01, phi_s(th - 0.01))).normalized()
        n = base_normal(th, ph)
        width = rng.uniform(0.012, 0.019)
        for which in ("upper", "lower"):
            if rng.random() < 0.08:
                continue  # gone
            sign = 1 if which == "upper" else -1
            length = rng.uniform(0.022, 0.032) if which == "upper" else rng.uniform(0.018, 0.026)
            if rng.random() < 0.12:
                length *= 0.6  # chipped
            tilt = rng.uniform(-0.15, 0.15)
            rows[which].append((at, up * sign, along, n, width, length, tilt))
        th += (width + 0.003) / (A * max(0.35, math.cos(th)))
    objects = {}
    for which, items in rows.items():
        bm = bmesh.new()
        for at, up, along, n, width, length, tilt in items:
            side = (along * math.cos(tilt) + up * math.sin(tilt)).normalized()
            root = at + up * (0.006 + length) - n * 0.005
            tip = at + up * 0.006 - n * 0.006
            ring_ = []
            for end, half, depth in ((root, width / 2, 0.008), (tip, width / 2 * 0.72, 0.006)):
                pts = []
                for k in range(6):
                    a = TAU * k / 6
                    pts.append(bm.verts.new(end + side * (half * math.cos(a)) - n * (depth * (1 + math.sin(a)) / 2)))
                ring_.append(pts)
            for k in range(6):
                j = (k + 1) % 6
                bm.faces.new((ring_[0][k], ring_[0][j], ring_[1][j], ring_[1][k]))
            bm.faces.new(ring_[1][::-1])
            bm.faces.new(ring_[0])
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        objects[which] = _object("Teeth" + which.title(), bm)
    return objects


def cavity():
    """The black behind the grin: a band set back behind the teeth, low
    enough to fill the jaw's drop."""
    bm = bmesh.new()
    rows = []
    for i in range(9):
        t = i / 8
        row = []
        for j in range(41):
            th = THETA_R + 0.03 + (THETA_L - THETA_R - 0.06) * j / 40
            ph = phi_s(th) + (6 - 26 * t) * D2R
            p = pos(th, ph) - base_normal(th, ph) * (0.03 + 0.02 * t)
            row.append(bm.verts.new(p))
        rows.append(row)
    for i in range(8):
        for j in range(40):
            bm.faces.new((rows[i][j], rows[i][j + 1], rows[i + 1][j + 1], rows[i + 1][j]))
    for f in bm.faces:
        if f.normal.z > 0:
            f.normal_flip()
    return _object("Cavity", bm)


def cups():
    """A black cup behind each eye hole, so the holes are voids."""
    bm = bmesh.new()
    for side in ("L", "R"):
        th, ph = EYES[side]
        n = base_normal(th, ph)
        c = pos(th, ph) - n * 0.004
        ref = Vector((0, 1, 0))
        u = n.cross(ref).normalized()
        v = n.cross(u).normalized()
        rings = []
        for i in range(7):
            a = (math.pi / 2) * i / 6
            r = 0.1 * math.cos(a)
            depth = 0.07 * math.sin(a)
            rings.append([bm.verts.new(c + (u * math.cos(b) + v * math.sin(b)) * r - n * depth) for b in (TAU * k / 16 for k in range(16))])
        for i in range(6):
            for k in range(16):
                j = (k + 1) % 16
                bm.faces.new((rings[i][k], rings[i][j], rings[i + 1][j], rings[i + 1][k]))
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-6)
    for f in bm.faces:
        if f.normal.dot(Vector((0, 0, -1))) < 0:
            f.normal_flip()
    return _object("Cups", bm)


def strap():
    """An old leather strap from his temples round the back of his head,
    a brass buckle behind."""
    hx, hy, hz = HEAD[0] / 2, HEAD[1] / 2, HEAD[2] / 2
    bm = bmesh.new()
    rows = []
    steps = 40
    for i in range(steps + 1):
        psi = math.radians(-22 + (202 + 22) * i / steps)
        cy = 0.15 + 0.07 * math.sin(psi)
        p = Vector((hx * 1.07 * math.cos(psi), cy, hz * 1.07 * math.sin(psi))) + HEAD_CENTRE
        out = Vector((math.cos(psi) / hx, 0, math.sin(psi) / hz)).normalized()
        row = []
        for k, (dy, dz) in enumerate(((-0.028, 0), (0.028, 0), (0.028, 0.009), (-0.028, 0.009))):
            row.append(bm.verts.new(p + Vector((0, dy, 0)) + out * dz))
        rows.append(row)
    for i in range(steps):
        for k in range(4):
            j = (k + 1) % 4
            bm.faces.new((rows[i][k], rows[i][j], rows[i + 1][j], rows[i + 1][k]))
    bm.faces.new(rows[0])
    bm.faces.new(rows[-1][::-1])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    for f in bm.faces:
        f.material_index = 5
    # The buckle.
    psi = math.radians(112)
    p = Vector((hx * 1.07 * math.cos(psi), 0.15 + 0.07 * math.sin(psi), hz * 1.07 * math.sin(psi))) + HEAD_CENTRE
    out = Vector((math.cos(psi) / hx, 0, math.sin(psi) / hz)).normalized()
    along = Vector((-math.sin(psi) * hx, 0, math.cos(psi) * hz)).normalized()
    before = len(bm.faces)
    frame = bmesh.ops.create_cube(bm, size=1.0)
    verts = frame["verts"]
    for v in verts:
        co = Vector(v.co)
        v.co = p + out * (0.012 + co.z * 0.008) + along * (co.x * 0.045) + Vector((0, co.y * 0.07, 0))
    for f in list(bm.faces)[before:]:
        f.material_index = 6
    return _object("Strap", bm)


# Paint ------------------------------------------------------------------------------

PAINT_N = 2048


def _stud_grid(n):
    """Stud coordinates (x, y) of each pixel of the paint (row 0 at the top),
    by face_uv."""
    yy, xx = np.mgrid[0:n, 0:n].astype(np.float64) + 0.5
    u = xx / n
    v = 1 - yy / n
    x = (u - 0.5) * 2 * A * 1.02
    y = (v - 0.5) * 2 * B * 1.02
    return x, y


def _vnoise(x, y, cell, rng):
    """Smooth value noise over stud coordinates, -1..1."""
    gx = int((x.max() - x.min()) / cell) + 3
    gy = int((y.max() - y.min()) / cell) + 3
    g = rng.uniform(-1, 1, (gy, gx))
    fx = (x - x.min()) / cell
    fy = (y - y.min()) / cell
    x0, y0 = np.floor(fx).astype(int), np.floor(fy).astype(int)
    tx, ty = fx - x0, fy - y0
    tx, ty = tx * tx * (3 - 2 * tx), ty * ty * (3 - 2 * ty)
    a = g[y0, x0] * (1 - tx) + g[y0, x0 + 1] * tx
    b = g[y0 + 1, x0] * (1 - tx) + g[y0 + 1, x0 + 1] * tx
    return a * (1 - ty) + b * ty


def _put(img, mask, rgb, alpha=1.0):
    a = np.clip(mask, 0, 1)[..., None] * alpha
    img[..., :3] = img[..., :3] * (1 - a) + np.array(rgb, dtype=np.float64) / 255.0 * a
    if img.shape[-1] == 4:
        img[..., 3:] = np.maximum(img[..., 3:], a)


def _index(v, half, n, flip):
    """Pixel index of a stud coordinate across the paint (face_uv)."""
    t = v / (2 * half * 1.02) + 0.5
    if flip:
        t = 1 - t
    return t * n - 0.5


def _line_mask(x, y, pts, width, soft=0.0012):
    """Coverage of a polyline in studs (width tapering from width[0] to
    width[1] along it, if a pair), each segment worked only over its own
    box of pixels."""
    w0, w1 = (width, width) if not isinstance(width, tuple) else width
    n = x.shape[0]
    m = np.zeros_like(x)
    total = sum(math.dist(a, b) for a, b in zip(pts, pts[1:])) or 1.0
    run = 0.0
    for (ax, ay), (bx, by) in zip(pts, pts[1:]):
        seg = math.dist((ax, ay), (bx, by))
        wa = w0 + (w1 - w0) * run / total
        wb = w0 + (w1 - w0) * (run + seg) / total
        run += seg
        pad = max(wa, wb) + soft * 2
        c0 = int(max(0, math.floor(_index(min(ax, bx) - pad, A, n, False))))
        c1 = int(min(n, math.ceil(_index(max(ax, bx) + pad, A, n, False)) + 1))
        r0 = int(max(0, math.floor(_index(max(ay, by) + pad, B, n, True))))
        r1 = int(min(n, math.ceil(_index(min(ay, by) - pad, B, n, True)) + 1))
        if c1 <= c0 or r1 <= r0:
            continue
        xs, ys = x[r0:r1, c0:c1], y[r0:r1, c0:c1]
        dx, dy = bx - ax, by - ay
        t = np.clip(((xs - ax) * dx + (ys - ay) * dy) / max(dx * dx + dy * dy, 1e-12), 0, 1)
        d = np.hypot(xs - ax - t * dx, ys - ay - t * dy)
        half = (wa + (wb - wa) * t) / 2
        m[r0:r1, c0:c1] = np.maximum(m[r0:r1, c0:c1], np.clip((half - d) / soft + 0.5, 0, 1))
    return m


def _jagged(rng, start, angle, length, step=0.012, wander=0.6):
    pts = [start]
    x, y = start
    a = angle
    run = 0.0
    while run < length:
        a += rng.uniform(-wander, wander)
        x += step * math.cos(a)
        y += step * math.sin(a)
        pts.append((x, y))
        run += step
        a = angle + (a - angle) * 0.6
    return pts


def _crazing(x, y, rng, cell, thin):
    """A craze of fine lines in the glaze (where a ridged noise peaks)."""
    n = _vnoise(x, y, cell, rng) * 0.65 + _vnoise(x, y, cell * 0.45, rng) * 0.35
    return np.clip((thin - np.abs(n)) / thin, 0, 1) ** 2


def _gp_xy(pts):
    """GuestPose's (theta, phi) polylines in base x, y."""
    out = []
    for th, ph in pts:
        p = base(th, ph)
        out.append((p.x, p.y))
    return out


# GuestPose.Cracks / .Blood (the tear-tracks' paths) / .Shards, as the old
# face drew them.
GP_CRACKS = [
    [(-0.05, 1.25), (0.08, 0.95), (0.02, 0.7), (0.17, 0.45), (0.3, 0.32)],
    [(0.08, 0.95), (-0.12, 0.82), (-0.22, 0.62)],
    [(0.02, 0.7), (0.12, 0.62)],
    [(-0.62, 0.55), (-0.5, 0.35), (-0.42, 0.1), (-0.52, -0.1)],
    [(0.55, -0.15), (0.68, -0.32), (0.62, -0.55)],
]
GP_TRACKS = [
    [(0.4, 0.12), (0.41, -0.05), (0.38, -0.25), (0.4, -0.45), (0.37, -0.62)],
    [(-0.4, 0.12), (-0.42, -0.08), (-0.4, -0.3), (-0.43, -0.5)],
    [(0.33, 0.12), (0.31, -0.02), (0.32, -0.16)],
]


def paint(seed=5):
    """The glaze and its paint, (n x n x 3, 0-1 sRGB, row 0 at the top), and
    a height for its crazing (n x n)."""
    rng = np.random.default_rng(seed)
    n = PAINT_N
    x, y = _stud_grid(n)
    img = np.ones((n, n, 3)) * np.array((224, 216, 202)) / 255.0
    r = np.sqrt((x / A) ** 2 + (y / B) ** 2)
    # Old ivory, yellowing toward the rim, a soft mottle, grime at the edge.
    _put(img, smoothstep_np(0.5, 1.0, r), (208, 194, 166), 0.55)
    _put(img, np.clip(_vnoise(x, y, 0.08, rng) * 0.5 + 0.5, 0, 1), (204, 196, 182), 0.3)
    _put(img, smoothstep_np(0.82, 1.0, r), (150, 138, 118), 0.35)
    # Rouge on the cheeks.
    for side in ("L", "R"):
        cx, cy = CHEEKS[side]
        g = np.exp(-(((x - cx) / 0.06) ** 2) - ((y - cy) / 0.05) ** 2)
        _put(img, g * (0.8 + 0.2 * _vnoise(x, y, 0.02, rng)), (206, 126, 120), 0.34)
    for side in ("L", "R"):
        ex, ey = eye_xy(side)
        d = np.hypot(x - ex, y - ey)
        # A fine dark line round the hole.
        _put(img, np.clip((0.0035 - np.abs(d - EYE_R - 0.004)) / 0.0012 + 0.5, 0, 1), (34, 26, 24), 0.6)
        # Painted lashes, long above and sparse below: a doll's.
        outward = 1 if ex > 0 else -1
        for k in range(8):
            a = math.radians(32 + 116 * k / 7 + rng.uniform(-4, 4))
            a2 = a + outward * 0.2 * (1 if math.cos(a) * outward > 0 else 0.4)
            p0 = (ex + (EYE_R + 0.004) * math.cos(a), ey + (EYE_R + 0.004) * math.sin(a))
            length = (0.015 + 0.008 * math.sin(math.radians(32 + 116 * k / 7))) * rng.uniform(0.85, 1.15)
            p1 = (p0[0] + length * math.cos(a2) * 0.7, p0[1] + length * math.sin(a2))
            _put(img, _line_mask(x, y, [p0, p1], (0.0022, 0.0008)), (36, 28, 26), 0.75)
        for k in range(5):
            a = math.radians(-62 - 56 * k / 4 + rng.uniform(-5, 5))
            p0 = (ex + (EYE_R + 0.005) * math.cos(a), ey + (EYE_R + 0.005) * math.sin(a))
            length = rng.uniform(0.012, 0.019)
            p1 = (p0[0] + length * math.cos(a) * 0.7, p0[1] + length * math.sin(a))
            _put(img, _line_mask(x, y, [p0, p1], (0.0016, 0.0006)), (52, 40, 36), 0.6)
        # A thin brow, arched far too high, the outer end higher still (the
        # left a little higher than the right).
        lift = 0.012 if side == "L" else 0.0
        pts = []
        for k in range(17):
            t = k / 16
            bx = ex + outward * (-0.07 + 0.15 * t)
            by = ey + 0.12 + lift + 0.045 * math.sin(math.pi * t) + 0.012 * t
            pts.append((bx, by))
        for off in (-0.0018, 0.0, 0.0018):
            _put(img, _line_mask(x, y, [(px, py + off) for px, py in pts], (0.0018, 0.0036)), (62, 50, 44), 0.5)
    # The rosebud mouth on the hairline: a cupid's bow over, a full little
    # lower lip under.
    ths = np.linspace(-0.25, 0.25, 101)
    sx = []
    for th in ths:
        p = base(th, phi_s(th))
        sx.append((p.x, p.y))
    sx = np.array(sx)
    ys_at = np.interp(x, sx[::-1, 0] if sx[0, 0] > sx[-1, 0] else sx[:, 0], sx[::-1, 1] if sx[0, 0] > sx[-1, 0] else sx[:, 1])
    rel = y - ys_at
    half = 0.05
    across = np.clip(1 - (x / half) ** 2, 0, 1)
    bow = 0.02 - 0.009 * np.exp(-((x / 0.012) ** 2)) + 0.004 * np.exp(-(((np.abs(x) - 0.017) / 0.008) ** 2))
    upper = (rel > 0) & (rel < bow * np.sqrt(across))
    lower = (rel <= 0) & (rel > -0.024 * across ** 0.8)
    lips = (upper | lower).astype(np.float64)
    lips = np.clip(lips * (0.85 + 0.15 * _vnoise(x, y, 0.006, rng)), 0, 1)
    _put(img, lips, (150, 52, 52), 0.85)
    # The nostrils.
    for s in (-1, 1):
        g = np.exp(-(((x - s * 0.017) / 0.008) ** 2) - ((y + 0.083) / 0.005) ** 2)
        _put(img, g, (108, 84, 78), 0.55)
    # The hairline the grin will tear along.
    line = []
    for k in range(400):
        th = THETA_R + (THETA_L - THETA_R) * k / 399
        p = base(th, phi_s(th))
        line.append((p.x, p.y))
    _put(img, _line_mask(x, y, line, 0.0016), (110, 100, 92), 0.35)
    # A faint craze toward the rim (calm: old, not yet broken).
    craze = _crazing(x, y, rng, 0.05, 0.03) * smoothstep_np(0.6, 0.95, r)
    _put(img, craze, (150, 140, 128), 0.25)
    height = 1 - craze * 0.5
    return img, height


def smoothstep_np(e0, e1, v):
    t = np.clip((v - e0) / (e1 - e0), 0, 1)
    return t * t * (3 - 2 * t)


def overlay_worn(seed=9):
    """Fraying (RGBA, 0-1, row 0 at the top): crazing all over, a first
    fracture over the brow, tear-tracks of grime from the eyes, flakes
    where the glaze has gone, grime."""
    rng = np.random.default_rng(seed)
    n = PAINT_N
    x, y = _stud_grid(n)
    img = np.zeros((n, n, 4))
    r = np.sqrt((x / A) ** 2 + (y / B) ** 2)
    _put(img, _crazing(x, y, rng, 0.04, 0.035), (88, 78, 70), 0.55)
    _put(img, _crazing(x, y, rng, 0.11, 0.02), (70, 62, 56), 0.7)
    _put(img, np.clip(_vnoise(x, y, 0.05, rng) * 1.4 - 0.3, 0, 1) * smoothstep_np(0.55, 1.0, r), (96, 84, 70), 0.4)
    for path in GP_CRACKS[:3]:
        pts = _gp_xy(path)
        jag = []
        for a, b in zip(pts, pts[1:]):
            ang = math.atan2(b[1] - a[1], b[0] - a[0])
            jag += _jagged(rng, a, ang, math.dist(a, b), 0.008, 0.5)
        _put(img, _line_mask(x, y, jag, (0.004, 0.0015)), (40, 32, 30), 0.9)
    for path in GP_TRACKS:
        pts = _gp_xy(path)
        m = _line_mask(x, y, pts, (0.016, 0.004), 0.006)
        m *= 0.6 + 0.4 * np.clip(_vnoise(x, y, 0.01, rng) + 0.5, 0, 1)
        _put(img, m, (86, 72, 60), 0.5)
    for _ in range(26):
        cx, cy = rng.uniform(-A, A), rng.uniform(-B, B)
        if (cx / A) ** 2 + (cy / B) ** 2 > 0.95:
            continue
        rad = rng.uniform(0.004, 0.012)
        blob = np.clip((rad * (1 + 0.4 * _vnoise(x, y, 0.004, rng)) - np.hypot(x - cx, y - cy)) / 0.0015 + 0.5, 0, 1)
        _put(img, blob, (198, 186, 166), 0.85)  # a flake: the bisque under the glaze
    return img


def overlay_broken(seed=13):
    """Breaking (RGBA): thick fractures from two blows, at the brow and the
    jaw, chipped along their edges; stains; the lines round where pieces
    came away."""
    rng = np.random.default_rng(seed)
    n = PAINT_N
    x, y = _stud_grid(n)
    img = np.zeros((n, n, 4))
    _put(img, np.clip(_vnoise(x, y, 0.07, rng) * 1.6 - 0.2, 0, 1), (70, 58, 48), 0.45)
    blows = [((0.09, 0.27), 9), ((-0.16, -0.31), 7)]
    for (bx, by), count in blows:
        for k in range(count):
            ang = TAU * k / count + rng.uniform(-0.3, 0.3)
            pts = _jagged(rng, (bx, by), ang, rng.uniform(0.12, 0.4), 0.01, 0.55)
            _put(img, _line_mask(x, y, pts, (0.01, 0.002), 0.0015), (196, 184, 164), 0.7)
            _put(img, _line_mask(x, y, pts, (0.006, 0.0012)), (22, 18, 16), 0.95)
            if rng.random() < 0.6:
                mid = pts[len(pts) // 2]
                side = _jagged(rng, mid, ang + rng.choice([-1, 1]) * rng.uniform(0.6, 1.2), rng.uniform(0.05, 0.14), 0.008, 0.5)
                _put(img, _line_mask(x, y, side, (0.004, 0.001)), (28, 22, 20), 0.9)
        g = np.exp(-(((x - bx) / 0.03) ** 2) - ((y - by) / 0.03) ** 2)
        _put(img, g, (30, 24, 22), 0.6)
    for path in GP_CRACKS[3:]:
        pts = _gp_xy(path)
        _put(img, _line_mask(x, y, pts, (0.006, 0.002)), (26, 20, 18), 0.9)
    for poly in SHARDS.values():
        loop = poly + [poly[0]]
        _put(img, _line_mask(x, y, loop, 0.007, 0.002), (40, 32, 28), 0.7)
    return img


# Materials ------------------------------------------------------------------------------


def _image(name, rgb, alpha=None):
    h, w = rgb.shape[:2]
    img = bpy.data.images.new(name, w, h, alpha=alpha is not None)
    img.colorspace_settings.name = "sRGB"
    a = np.ones((h, w, 1)) if alpha is None else alpha[..., None]
    rgba = np.concatenate([rgb[::-1], a[::-1]], axis=-1).astype(np.float32)
    img.pixels.foreach_set(rgba.ravel())
    img.update()
    img.pack()
    return img


def porcelain(paint_rgb, height):
    """The glaze: the paint by the "Pattern" layout, a low gloss, its craze
    in the bump."""
    mat = bpy.data.materials.new("GuestPorcelain")
    n = materials.Nodes(mat)
    uv = n.add("ShaderNodeUVMap", uv_map="Pattern")
    tex = n.add("ShaderNodeTexImage")
    tex.image = _image("GuestMaskPaint", paint_rgb)
    n.link(uv.outputs["UV"], tex.inputs["Vector"])
    n.link(tex.outputs["Color"], n.bsdf.inputs["Base Color"])
    htex = n.add("ShaderNodeTexImage")
    himg = _image("GuestMaskHeight", np.repeat(height[..., None], 3, axis=-1))
    himg.colorspace_settings.name = "Non-Color"
    htex.image = himg
    n.link(uv.outputs["UV"], htex.inputs["Vector"])
    rough = n.math("MULTIPLY_ADD", htex.outputs["Color"], -0.25, 0.57)
    n.link(rough.outputs["Value"], n.bsdf.inputs["Roughness"])
    n.bump(htex.outputs["Color"], 0.25, 0.002)
    mat["uv_share"] = 0.0
    return mat


def _plain(name, rgb, rough, metal=0.0, noise_scale=40.0, dark=None):
    mat = bpy.data.materials.new(name)
    n = materials.Nodes(mat)
    m = n.mapping()
    mottle = n.noise(m.outputs["Vector"], noise_scale, 4.0, 0.5)
    ramp = n.ramp(mottle.outputs["Fac"], [(0.3, materials._srgb(dark or rgb)), (0.7, materials._srgb(rgb))])
    n.link(ramp.outputs["Color"], n.bsdf.inputs["Base Color"])
    n.bsdf.inputs["Roughness"].default_value = rough
    n.bsdf.inputs["Metallic"].default_value = metal
    return mat


def mask_materials(paint_rgb, height):
    return [
        porcelain(paint_rgb, height),  # 0 the glaze
        _plain("GuestBisqueInner", (196, 186, 170), 0.85, dark=(176, 166, 150)),  # 1 its back
        _plain("GuestBisqueEdge", (210, 200, 184), 0.7, dark=(190, 180, 164)),  # 2 its broken edges
        _plain("GuestTeeth", (172, 160, 126), 0.32, dark=(140, 124, 92), noise_scale=120.0),  # 3
        _plain("GuestVoid", (0, 0, 0), 1.0),  # 4 the dark behind
        _plain("GuestStrap", (46, 32, 24), 0.62, dark=(30, 22, 18), noise_scale=60.0),  # 5
        materials.brass("GuestBuckle"),  # 6
    ]


def _set(obj, mats, index=None):
    obj.data.materials.clear()
    for m in mats:
        obj.data.materials.append(m)
    if index is not None:
        for p in obj.data.polygons:
            p.material_index = index


def _solidify(obj):
    mod = obj.modifiers.new("Solidify", "SOLIDIFY")
    mod.thickness = THICK
    mod.offset = -1.0  # (the faces point out of the face: thicken behind them)
    mod.use_even_offset = True
    mod.use_rim = True
    mod.material_offset = 1
    mod.material_offset_rim = 2
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.modifier_apply(modifier=mod.name)
    # Its back is never seen up close: a fifth of the faces will do (its
    # edges, shared with the rims, stay).
    bpy.ops.object.mode_set(mode="EDIT")
    bm = bmesh.from_edit_mesh(obj.data)
    bm.select_mode = {"FACE"}
    for v in bm.verts:
        v.select_set(False)
    for f in bm.faces:
        f.select_set(f.material_index == 1)
    bm.select_flush_mode()
    bmesh.update_edit_mesh(obj.data)
    bpy.ops.mesh.decimate(ratio=0.2)
    bpy.ops.object.mode_set(mode="OBJECT")


def _face_out(obj):
    """Every face of the shell toward -z (out of the face), before it's made
    thick."""
    for p in obj.data.polygons:
        pass
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bm.normal_update()
    for f in bm.faces:
        c = f.calc_center_median()
        p = Vector(c)
        # Away from the head's middle.
        away = p - HEAD_CENTRE
        if f.normal.dot(away) < 0:
            f.normal_flip()
    bm.to_mesh(obj.data)
    bm.free()


def build(rng):
    """Returns {name: object} (model space, Blender axes, weighed): the mask
    (GuestMask), its shards (GuestShardA..C), the two shells (GuestMaskWorn,
    GuestMaskBroken, with their RGBA paint as obj["overlay"]), and the
    material list. Not yet baked."""
    paint_rgb, height = paint()
    mats = mask_materials(paint_rgb, height)
    out = {}
    pieces = []
    shards = {}
    fronts = []
    for region in ("upper", "lower"):
        obj = _object("Mask" + region.title(), _region(region))
        _face_out(obj)
        _set(obj, mats, 0)
        weigh_face(obj, region)
        found = _separate_shards(obj)
        for key, shard in found.items():
            _set(shard, mats)
            weigh_all(shard, SHARD_BONE[key])
            shards[key] = shard
        fronts.append(obj)
    # The shells: copies of the glaze lifted off it, without the shards.
    shells = {}
    for name, lift in (("GuestMaskWorn", 0.0016), ("GuestMaskBroken", 0.0032)):
        copies = []
        for obj in fronts:
            c = obj.copy()
            c.data = obj.data.copy()
            bpy.context.scene.collection.objects.link(c)
            for v in c.data.vertices:
                v.co = Vector(v.co) + Vector(v.normal) * lift
            copies.append(c)
        shell = _join(copies, name)
        shells[name] = shell
    for obj in fronts:
        _solidify(obj)
        pieces.append(obj)
    for key, shard in shards.items():
        _solidify(shard)
    t = teeth(rng)
    _set(t["upper"], mats, 3)
    weigh_all(t["upper"], "fMask")
    _set(t["lower"], mats, 3)
    weigh_all(t["lower"], "fJaw")
    cav = cavity()
    _set(cav, mats, 4)
    weigh_all(cav, "fMask")
    cup = cups()
    _set(cup, mats, 4)
    weigh_all(cup, "fMask")
    mask = _join(pieces + [t["upper"], t["lower"]], "GuestMask")
    out["GuestMask"] = mask
    void = _join([cav, cup], "GuestMaskVoid")
    out["GuestMaskVoid"] = void
    for key, shard in shards.items():
        out[shard.name] = shard
    out.update(shells)
    for obj in out.values():
        _to_model(obj)
        bpy.ops.object.select_all(action="DESELECT")
        obj.select_set(True)
        bpy.context.view_layer.objects.active = obj
        try:
            bpy.ops.object.shade_smooth_by_angle(angle=math.radians(40))
        except (AttributeError, RuntimeError):
            bpy.ops.object.shade_smooth()
    shells["GuestMaskWorn"]["overlay"] = "worn"
    shells["GuestMaskBroken"]["overlay"] = "broken"
    return out, mats


def _join(objects, name):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objects:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objects[0]
    bpy.ops.object.join()
    obj = bpy.context.view_layer.objects.active
    obj.name = name
    obj.data.name = name
    return obj


def all_bones():
    """The face's bones in the model (for kitlib/guestrig's armature):
    [(bone, parent, head (game frame, model space))]; the mask's root under
    the head's bone."""
    out = []
    for bone, parent, at in face_bones():
        out.append((bone, parent or "gHead", at + CENTRE, "Mask"))
    return out
