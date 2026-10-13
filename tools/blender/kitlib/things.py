"""The escape's things (the visual rework V4d, the kit's fourth rollout
batch): what every run is played for and with. The key, the five heirlooms
and the four valuables your hands carry (World/Items); the leads that keep
them (World/LeadProps: the three keepsake boxes and their lids, the display
case and its glass cover's frame, the figurine, the key rack); the locks'
hardware on the doors and chests (Services/LockService: the keyhole plates,
the code padlock's hasp, the bolt, the power lock's box, a padlock, a plank
nailed across); and the dinner's places (Services/FinaleService: the plate,
the candle).

Each is built in the game's own frame, as its grey-box is (x across, y up,
z with its front +Z), through G() and S(), which give Blender's (its front
-Y). A thing that lies on a surface stands on y = 0 round its grey-box's
origin; a moving piece (a lid) is built round the middle of the part it
hangs on; a door's hardware round the middle of its plate.
"""

import math
import random

import bmesh
import bpy
from mathutils import Vector

from . import materials, shapes
from .house import _chrome, _porcelain, _steel


def G(x, y, z):
    """A point in the game's frame (x, y up, z toward the front) as Blender's."""
    return (x, -z, y)


def S(x, y, z):
    """A size in the game's frame as Blender's."""
    return (x, z, y)


def _box(name, size, at, bevel=0.01, segments=2):
    return shapes.box(name, S(*size), G(*at), bevel, segments)


def _lathe(name, profile, at=(0, 0, 0), steps=24):
    """Spun round the game's y (up), standing at `at`."""
    return shapes.lathe(name, profile, G(*at), steps=steps)


def _new(name, bm):
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    return obj


def _torus(name, major, minor, segments=16, sides=6):
    """A ring lying in the game's floor plane round the origin: a key's bow,
    a chain's link, a bezel."""
    bm = bmesh.new()
    rows = []
    for i in range(segments):
        a = math.tau * i / segments
        row = []
        for j in range(sides):
            b = math.tau * j / sides
            r = major + minor * math.cos(b)
            row.append(bm.verts.new((r * math.cos(a), r * math.sin(a), minor * math.sin(b))))
        rows.append(row)
    for i in range(segments):
        nxt = rows[(i + 1) % segments]
        for j in range(sides):
            k = (j + 1) % sides
            bm.faces.new((rows[i][j], rows[i][k], nxt[k], nxt[j]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return shapes.smooth(_new(name, bm), 60)


def _ring(name, major, minor, at, degrees=(0, 0, 0), segments=24, sides=6):
    """A torus turned (degrees, about Blender's axes) and put at the game's `at`."""
    ring = _torus(name, major, minor, segments, sides)
    return shapes.turn(ring, degrees, G(*at))


def _tube(name, points, radii, sides=10, caps=True):
    """A tube through `points` (the game's frame), `radii` at each (or one
    for all): a spout, a handle, a hook, a shackle, a drip of wax."""
    pts = [Vector(G(*p)) for p in points]
    if isinstance(radii, (int, float)):
        radii = [radii] * len(pts)
    bm = bmesh.new()
    rings = []
    normal = None
    for i, p in enumerate(pts):
        if i == 0:
            t = pts[1] - pts[0]
        elif i == len(pts) - 1:
            t = pts[-1] - pts[-2]
        else:
            t = pts[i + 1] - pts[i - 1]
        t.normalize()
        if normal is None:
            ref = Vector((0, 0, 1)) if abs(t.z) < 0.9 else Vector((1, 0, 0))
            normal = t.cross(ref).normalized()
        else:
            # Carried along the curve, so the tube doesn't twist.
            normal = (normal - t * normal.dot(t)).normalized()
        binormal = t.cross(normal)
        ring = []
        for j in range(sides):
            a = math.tau * j / sides
            ring.append(bm.verts.new(p + (normal * math.cos(a) + binormal * math.sin(a)) * radii[i]))
        rings.append(ring)
    for i in range(len(rings) - 1):
        for j in range(sides):
            k = (j + 1) % sides
            bm.faces.new((rings[i][j], rings[i][k], rings[i + 1][k], rings[i + 1][j]))
    if caps:
        bm.faces.new(list(reversed(rings[0])))
        bm.faces.new(rings[-1])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return shapes.smooth(_new(name, bm), 50)


def _sphere(name, radius, at, steps=20, rings=10):
    profile = [(radius * math.sin(math.pi * k / rings), -radius * math.cos(math.pi * k / rings)) for k in range(rings + 1)]
    return _lathe(name, profile, at, steps)


def _chain(name, points, major=0.028, minor=0.007):
    """A fine chain lying along `points` (the game's frame): oval links,
    each turned a quarter round the chain from the last."""
    pts = [Vector(G(*p)) for p in points]
    step = major * 1.6
    samples = []
    carry = 0.0
    for a, b in zip(pts, pts[1:]):
        seg = b - a
        length = seg.length
        d = carry
        while d < length:
            samples.append((a + seg * (d / length), seg.normalized()))
            d += step
        carry = d - length
    links = []
    for i, (p, t) in enumerate(samples):
        link = _torus(name, major, minor, 10, 5)
        link.scale = (1.5, 1.0, 1.0)
        heading = math.degrees(math.atan2(t.y, t.x))
        shapes.turn(link, (90 if i % 2 else 0, 0, heading), p)
        links.append(link)
    return shapes.join(links, name)


def _settle(obj):
    """Bakes an object's location into its mesh (a joined piece keeps its
    first part's origin)."""
    shapes.select_only(obj)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    return obj


def _silver(name, roughness=0.22):
    return materials.brass(name, color=(184, 186, 190), roughness=roughness)


def _gilt(name):
    return materials.brass(name, color=(176, 140, 72), roughness=0.3)


def _dark(name, color=(24, 20, 18), roughness=0.6):
    return materials.paint(name, color=color, roughness=roughness, grime=0.0)


# Dials ----------------------------------------------------------------------


def _dial_picture(n=256, hours=10.15, minutes=8.6, face=(234, 226, 202), ink=(32, 28, 24), seconds=True, seed=1):
    """A watch or clock face, drawn (numpy, 0-1 sRGB, row 0 at the top): a
    chapter ring, minute ticks, hour batons, spade hands, a little seconds
    dial over the 6; yellowed with age."""
    import numpy as np

    yy, xx = np.mgrid[0:n, 0:n]
    u = (xx + 0.5) / n * 2 - 1
    v = 1 - (yy + 0.5) / n * 2
    r = np.sqrt(u * u + v * v)
    a = np.arctan2(u, v)  # clockwise from the 12
    img = np.ones((n, n, 3)) * (np.array(face) / 255.0)
    inkc = np.array(ink) / 255.0

    def paint(mask):
        img[mask] = inkc

    paint(np.abs(r - 0.93) < 0.016)
    paint(np.abs(r - 0.79) < 0.007)
    for count, inner, width in ((60, 0.79, 0.008), (12, 0.6, 0.03)):
        step = math.tau / count
        off = np.abs(((a + step / 2) % step) - step / 2) * r
        paint((r > inner) & (r < 0.93) & (off < width))

    def hand(angle, length, width, cx=0.0, cy=0.0):
        hx, hy = math.sin(angle), math.cos(angle)
        du, dv = u - cx, v - cy
        t = np.clip(du * hx + dv * hy, -0.1 * length, length)
        px, py = du - t * hx, dv - t * hy
        taper = width * (1.2 - 0.9 * np.clip(t / length, 0, 1))
        paint(np.sqrt(px * px + py * py) < taper)

    hand(hours / 12 * math.tau, 0.46, 0.045)
    hand(minutes / 60 * math.tau, 0.72, 0.03)
    paint(r < 0.055)
    if seconds:
        su, sv = u, v + 0.42
        sr = np.sqrt(su * su + sv * sv)
        paint(np.abs(sr - 0.15) < 0.008)
        hand(2.2, 0.12, 0.012, 0.0, -0.42)
    rng = np.random.default_rng(seed)
    blot = rng.random((n // 32, n // 32))
    blot = np.kron(blot, np.ones((32, 32)))[:n, :n]
    img *= (0.94 + 0.06 * blot)[..., None]
    img[r > 0.97] *= 0.7
    return np.clip(img, 0.0, 1.0)


def _dial(name, radius, picture, share=0.3):
    """A flat dial in the game's floor plane facing up, the picture mapped
    straight on (decor's canvas: the "Pattern" layer), its 12 toward the
    game's -z. Turn it (90, 0, 0) to stand it facing the front."""
    bm = bmesh.new()
    bmesh.ops.create_circle(bm, cap_ends=True, cap_tris=False, segments=32, radius=radius)
    obj = _new(name, bm)
    uv = obj.data.uv_layers.new(name="Pattern")
    for loop in obj.data.loops:
        co = obj.data.vertices[loop.vertex_index].co
        uv.data[loop.index].uv = (co.x / (2 * radius) + 0.5, co.y / (2 * radius) + 0.5)
    mat = materials.image(name + "Face", picture, roughness=0.35, bump=0.0)
    mat["uv_share"] = share
    return materials.assign(obj, mat)


# The key ----------------------------------------------------------------------


def key():
    """A brass key lying flat, 0.8 x 0.05 x 0.3 (World/Items' Key: its bow at
    -x, the teeth of its bit toward +z): an oval bow, a collar and a bead, a
    round shank, a bit with its wards cut; and the string its paper tag
    hangs from (the tag is the game's, written on)."""
    brass = materials.brass("KeyBrass", color=(158, 124, 70), roughness=0.34)
    string = materials.fabric("TagString", color=(204, 194, 164))
    y = 0.025
    parts = []
    bow = _torus("Bow", 0.11, 0.028, 24, 8)
    bow.scale = (1.0, 0.92, 0.85)
    shapes.turn(bow, (0, 0, 0), G(-0.29, y, 0))
    parts.append(materials.assign(bow, brass))
    for name, length, radius, x in (("Collar", 0.05, 0.034, -0.155), ("Bead", 0.03, 0.03, -0.11), ("Shank", 0.42, 0.021, 0.07)):
        parts.append(materials.assign(shapes.roll(name, length, radius, G(x, y, 0), axis="X", steps=12), brass))
    # The bit: a spine and three wards of different depths, toward +z.
    parts.append(materials.assign(_box("Spine", (0.13, 0.04, 0.04), (0.235, y, 0.025), 0.006), brass))
    for x, depth in ((0.19, 0.14), (0.235, 0.09), (0.28, 0.12)):
        parts.append(materials.assign(_box("Ward", (0.032, 0.04, depth), (x, y, depth / 2), 0.006), brass))
    parts.append(materials.assign(_sphere("Tip", 0.022, (0.29, y, 0), 10, 6), brass))
    # The tag's string, looped through the bow.
    loop = _tube("String", [(-0.4, 0.04, 0.03), (-0.43, 0.03, 0.06), (-0.47, 0.012, 0.09), (-0.5, 0.008, 0.11)], 0.007, 6)
    parts.append(materials.assign(loop, string))
    piece = shapes.join(parts, "Key")
    piece["bake_size"] = 256
    return piece


# The heirlooms --------------------------------------------------------------------


def candlestick():
    """A silver candlestick, 0.6 x 1.8 (World/Items' heirloom): a stepped
    foot, a knopped stem, a drip pan, and a half-burned candle that has run."""
    silver = _silver("CandlestickSilver")
    wax = materials.paint("CandleWax", color=(234, 226, 206), roughness=0.45, grime=0.12)
    wick = _dark("Wick")
    parts = []
    profile = [
        (0.0, 0.0),
        (0.3, 0.0),
        (0.3, 0.03),
        (0.27, 0.06),
        (0.2, 0.09),
        (0.11, 0.13),
        (0.08, 0.17),
        (0.11, 0.2),
        (0.065, 0.25),
        (0.05, 0.5),
        (0.065, 0.62),
        (0.09, 0.66),
        (0.06, 0.71),
        (0.048, 0.95),
        (0.07, 1.05),
        (0.058, 1.12),
        (0.09, 1.17),
        (0.17, 1.2),
        (0.17, 1.23),
        (0.1, 1.25),
        (0.1, 1.34),
        (0.0, 1.34),
    ]
    parts.append(materials.assign(_lathe("Stick", profile, steps=28), silver))
    candle = _lathe("Candle", [(0.0, 1.3), (0.085, 1.3), (0.085, 1.72), (0.07, 1.765), (0.0, 1.75)], steps=20)
    parts.append(materials.assign(candle, wax))
    rng = random.Random(3)
    for k in range(5):
        ang = rng.uniform(0, math.tau)
        low = 1.7 - rng.uniform(0.08, 0.32)
        cx, cz = math.cos(ang) * 0.082, math.sin(ang) * 0.082
        drip = _tube("Drip", [(cx, 1.71, cz), (cx * 1.02, (1.71 + low) / 2, cz * 1.02), (cx, low, cz)], [0.008, 0.01, 0.006], 6)
        parts.append(materials.assign(drip, wax))
    parts.append(materials.assign(_tube("Wick", [(0, 1.74, 0), (0.008, 1.775, 0), (0.016, 1.795, 0)], 0.007, 6), wick))
    piece = shapes.join(parts, "Candlestick")
    piece["bake_size"] = 512
    return piece


def pocket_watch():
    """A gold pocket watch lying face up, 0.6 across (World/Items'
    heirloom): its case and bezel, the dial (a drawn face), the pendant,
    crown and bow toward -z, and its chain curling away with a T-bar."""
    gold = materials.brass("WatchGold", color=(178, 142, 74), roughness=0.28)
    parts = []
    case = _lathe("Case", [(0.0, 0.0), (0.26, 0.0), (0.3, 0.03), (0.3, 0.08), (0.28, 0.105), (0.0, 0.105)], steps=36)
    parts.append(materials.assign(case, gold))
    parts.append(materials.assign(_ring("Bezel", 0.262, 0.016, (0, 0.105, 0), segments=36), gold))
    dial = _dial("WatchDial", 0.248, _dial_picture(seed=2))
    shapes.turn(dial, (0, 0, 0), G(0, 0.108, 0))
    parts.append(dial)
    parts.append(materials.assign(shapes.roll("Pendant", 0.08, 0.034, G(0, 0.052, -0.33), axis="Y", steps=12), gold))
    crown = shapes.roll("Crown", 0.05, 0.05, G(0, 0.052, -0.385), axis="Y", steps=16)
    parts.append(materials.assign(crown, gold))
    parts.append(materials.assign(_ring("WatchBow", 0.06, 0.012, (0, 0.03, -0.46), segments=16), gold))
    chain = _chain("Chain", [(0, 0.008, -0.52), (0.08, 0.008, -0.6), (0.22, 0.008, -0.62), (0.36, 0.008, -0.56), (0.46, 0.008, -0.48)])
    parts.append(materials.assign(chain, gold))
    parts.append(materials.assign(shapes.roll("TBar", 0.16, 0.014, G(0.48, 0.014, -0.46), axis="X", steps=8), gold))
    piece = shapes.join(parts, "PocketWatch")
    piece["bake_size"] = 512
    return piece


def locket():
    """An oval gold locket lying flat, 0.36 x 0.44 (World/Items' heirloom):
    a domed, engraved case with a flower at its middle, its bail toward -z,
    and its fine chain lying in a loose loop."""
    gold = materials.brass("LocketGold", color=(182, 146, 78), roughness=0.3)
    parts = []
    body = _lathe("Locket", [(0.0, 0.0), (0.17, 0.0), (0.2, 0.02), (0.2, 0.05), (0.17, 0.08), (0.08, 0.095), (0.0, 0.1)], steps=32)
    body.scale = (0.88, 1.08, 1.0)
    shapes.apply_transform(body)
    parts.append(materials.assign(body, gold))
    rim = _torus("Engraving", 0.14, 0.007, 32, 5)
    rim.scale = (0.88, 1.08, 1.0)
    shapes.turn(rim, (0, 0, 0), G(0, 0.085, 0))
    parts.append(materials.assign(rim, gold))
    for k in range(6):
        ang = k * math.tau / 6
        petal = _sphere("Petal", 0.022, (math.cos(ang) * 0.035, 0.09, math.sin(ang) * 0.035), 8, 4)
        parts.append(materials.assign(petal, gold))
    parts.append(materials.assign(_ring("Bail", 0.034, 0.01, (0, 0.03, -0.25), segments=12), gold))
    chain = _chain(
        "LocketChain",
        [(0, 0.007, -0.28), (-0.22, 0.007, -0.34), (-0.4, 0.007, -0.46), (-0.3, 0.007, -0.58), (0.0, 0.007, -0.6), (0.3, 0.007, -0.56), (0.4, 0.007, -0.44), (0.22, 0.007, -0.33), (0.02, 0.007, -0.28)],
        0.022,
        0.006,
    )
    parts.append(materials.assign(chain, gold))
    piece = shapes.join(parts, "Locket")
    piece["bake_size"] = 512
    return piece


def doll():
    """A porcelain doll standing 1.02 tall (World/Items' heirloom): a wine
    velvet dress with a lace hem and collar, porcelain hands and head,
    painted blue eyes, rosy cheeks, dark ringlets; looking out of its
    front (+z)."""
    porcelain = _porcelain("DollPorcelain", (236, 226, 214))
    dress = materials.velvet("DollDress", color=(118, 52, 62))
    lace = materials.fabric("DollLace", color=(234, 226, 208))
    hair = materials.paint("DollHair", color=(74, 48, 30), roughness=0.7, grime=0.2)
    eye = materials.paint("DollEye", color=(40, 58, 86), roughness=0.08, grime=0.0)
    lip = materials.paint("DollLip", color=(150, 58, 60), roughness=0.3, grime=0.0)
    cheek = materials.paint("DollCheek", color=(224, 168, 160), roughness=0.3, grime=0.0)
    shoe = _dark("DollShoe", (30, 26, 24), 0.3)
    parts = []
    skirt = _lathe("Skirt", [(0.0, 0.03), (0.25, 0.03), (0.255, 0.06), (0.23, 0.2), (0.18, 0.38), (0.12, 0.5), (0.11, 0.52), (0.0, 0.52)], steps=32)
    for v in skirt.data.vertices:
        rad = math.hypot(v.co.x, v.co.y)
        if rad > 0.02:
            ang = math.atan2(v.co.y, v.co.x)
            k = 1 + 0.05 * math.sin(8 * ang) * max(0.0, 1 - v.co.z / 0.52)
            v.co.x *= k
            v.co.y *= k
    skirt.data.update()
    parts.append(materials.assign(skirt, dress))
    parts.append(materials.assign(_ring("Hem", 0.248, 0.02, (0, 0.05, 0), segments=32), lace))
    for sx in (-1, 1):
        parts.append(materials.assign(_box("Shoe", (0.07, 0.05, 0.11), (sx * 0.06, 0.025, 0.2), 0.02), shoe))
    bodice = _lathe("Bodice", [(0.0, 0.5), (0.11, 0.5), (0.1, 0.6), (0.09, 0.67), (0.06, 0.72), (0.0, 0.72)], steps=24)
    parts.append(materials.assign(bodice, dress))
    collar = _lathe("Collar", [(0.03, 0.725), (0.1, 0.685), (0.108, 0.692), (0.04, 0.735)], steps=24)
    parts.append(materials.assign(collar, lace))
    parts.append(materials.assign(_lathe("Neck", [(0.0, 0.7), (0.034, 0.7), (0.032, 0.745), (0.0, 0.745)], steps=12), porcelain))
    head_y = 0.84
    parts.append(materials.assign(_sphere("Head", 0.15, (0, head_y, 0), 24, 12), porcelain))
    cap = _sphere("Hair", 0.165, (0, head_y + 0.012, -0.014), 28, 14)
    bm = bmesh.new()
    bm.from_mesh(cap.data)
    doomed = []
    for f in bm.faces:
        c = f.calc_center_median()
        # Open over the face (Blender's -y is its front) below the fringe,
        # and under the chin; the back falls to the nape.
        if (c.y < -0.03 and c.z < head_y + 0.07) or c.z < head_y - 0.1:
            doomed.append(f)
    bmesh.ops.delete(bm, geom=doomed, context="FACES")
    bm.to_mesh(cap.data)
    bm.free()
    parts.append(materials.assign(cap, hair))
    for sx in (-1, 1):
        for k in range(3):
            curl = _tube(
                "Curl",
                [
                    (
                        sx * (0.135 - 0.02 * k + 0.012 * math.sin(t * 1.7)),
                        head_y - 0.02 - t * 0.032,
                        -0.03 - 0.045 * k + 0.012 * math.cos(t * 1.7),
                    )
                    for t in range(9)
                ],
                [0.022 - 0.0012 * t for t in range(9)],
                8,
            )
            parts.append(materials.assign(curl, hair))
        parts.append(materials.assign(_sphere("Eye", 0.021, (sx * 0.052, head_y + 0.015, 0.128), 10, 6), eye))
        brow = _tube("Brow", [(sx * 0.025, head_y + 0.055, 0.14), (sx * 0.052, head_y + 0.062, 0.138), (sx * 0.078, head_y + 0.052, 0.128)], 0.005, 5)
        parts.append(materials.assign(brow, hair))
        rosy = _sphere("Cheek", 0.03, (0, 0, 0), 10, 6)
        rosy.scale = (1.0, 0.4, 0.6)
        shapes.turn(rosy, (0, 0, 0), G(sx * 0.078, head_y - 0.03, 0.118))
        parts.append(materials.assign(rosy, cheek))
        parts.append(materials.assign(_sphere("Sleeve", 0.05, (sx * 0.108, 0.655, 0.0), 12, 8), dress))
        arm = _tube("Arm", [(sx * 0.115, 0.64, 0.01), (sx * 0.145, 0.57, 0.035), (sx * 0.158, 0.505, 0.058)], [0.034, 0.03, 0.027], 8)
        parts.append(materials.assign(arm, dress))
        parts.append(materials.assign(_ring("Cuff", 0.026, 0.008, (sx * 0.159, 0.5, 0.06), (0, 0, 0), 12), lace))
        parts.append(materials.assign(_sphere("Hand", 0.028, (sx * 0.16, 0.475, 0.065), 10, 6), porcelain))
    mouth = _sphere("Lips", 0.018, (0, 0, 0), 10, 6)
    mouth.scale = (1.5, 0.5, 0.6)
    shapes.turn(mouth, (0, 0, 0), G(0, head_y - 0.05, 0.138))
    parts.append(materials.assign(mouth, lip))
    piece = shapes.join(parts, "Doll")
    piece["bake_size"] = 512
    return piece


def christening_cup():
    """A silver christening cup, 0.6 x 0.58 (World/Items' heirloom): a
    flared foot, a waisted bowl with an engraved band, a scrolled handle."""
    silver = _silver("CupSilver")
    parts = []
    profile = [
        (0.0, 0.0),
        (0.18, 0.0),
        (0.18, 0.025),
        (0.14, 0.06),
        (0.12, 0.08),
        (0.16, 0.1),
        (0.2, 0.13),
        (0.215, 0.3),
        (0.225, 0.5),
        (0.235, 0.56),
        (0.23, 0.58),
        (0.21, 0.58),
        (0.2, 0.55),
        (0.19, 0.3),
        (0.18, 0.15),
        (0.0, 0.14),
    ]
    parts.append(materials.assign(_lathe("Cup", profile, steps=32), silver))
    for y in (0.33, 0.45):
        parts.append(materials.assign(_ring("Band", 0.222, 0.007, (0, y, 0), segments=32), silver))
    handle = _tube("Handle", [(0.215, 0.5, 0), (0.3, 0.53, 0), (0.36, 0.46, 0), (0.355, 0.33, 0), (0.3, 0.24, 0), (0.205, 0.21, 0)], [0.024, 0.022, 0.02, 0.02, 0.019, 0.022], 10)
    parts.append(materials.assign(handle, silver))
    parts.append(materials.assign(_ring("Scroll", 0.03, 0.01, (0.335, 0.545, 0), (90, 0, 0), 12), silver))
    piece = shapes.join(parts, "ChristeningCup")
    piece["bake_size"] = 256
    return piece


# The valuables ---------------------------------------------------------------------


def carriage_clock():
    """A gilt carriage clock, 0.66 x 0.88 x 0.46 (World/Items' valuable): a
    plinth, corner pillars, bevelled glass sides showing the dark movement, a
    dial on both faces (it reads as a clock whichever way it's set down), a
    stepped cornice and its folding handle."""
    gilt = _gilt("ClockGilt")
    brass = materials.brass("CarriageBrass", color=(160, 126, 70), roughness=0.3)
    glass = materials.paint("ClockGlass", color=(40, 44, 46), roughness=0.05, grime=0.1)
    parts = []
    parts.append(materials.assign(_box("Plinth", (0.66, 0.08, 0.46), (0, 0.04, 0), 0.015), gilt))
    parts.append(materials.assign(_box("Step", (0.6, 0.03, 0.4), (0, 0.095, 0), 0.01), gilt))
    for sx in (-1, 1):
        for sz in (-1, 1):
            parts.append(materials.assign(_box("Pillar", (0.055, 0.6, 0.055), (sx * 0.265, 0.41, sz * 0.175), 0.012), brass))
        parts.append(materials.assign(_box("SideGlass", (0.015, 0.56, 0.3), (sx * 0.26, 0.41, 0), 0.0), glass))
    parts.append(materials.assign(_box("TopGlass", (0.5, 0.015, 0.32), (0, 0.705, 0), 0.0), glass))
    for sz in (-1, 1):
        parts.append(materials.assign(_box("DialPlate", (0.48, 0.56, 0.02), (0, 0.41, sz * 0.175), 0.006), brass))
        parts.append(materials.assign(_ring("Bezel", 0.168, 0.011, (0, 0.43, sz * 0.186), (90, 0, 0), 32), gilt))
    front = _dial("ClockDial", 0.162, _dial_picture(seed=4, seconds=False), share=0.25)
    shapes.turn(front, (90, 0, 0), G(0, 0.43, 0.1865))
    back = _dial("ClockDialBack", 0.162, _dial_picture(seed=5, seconds=False, hours=2.4, minutes=21), share=0.2)
    shapes.turn(back, (90, 0, 180), G(0, 0.43, -0.1865))
    parts += [front, back]
    parts.append(materials.assign(_box("Cornice", (0.62, 0.05, 0.42), (0, 0.735, 0), 0.015), gilt))
    parts.append(materials.assign(_box("CorniceCap", (0.54, 0.03, 0.34), (0, 0.775, 0), 0.01), gilt))
    for sx in (-1, 1):
        parts.append(materials.assign(_sphere("Pivot", 0.022, (sx * 0.2, 0.79, 0), 10, 6), gilt))
    handle = _tube("Handle", [(-0.2, 0.79, 0), (-0.2, 0.83, 0), (-0.16, 0.865, 0), (0.16, 0.865, 0), (0.2, 0.83, 0), (0.2, 0.79, 0)], 0.016, 8)
    parts.append(materials.assign(handle, gilt))
    piece = shapes.join(parts, "CarriageClock")
    piece["bake_size"] = 512
    return piece


def jewellery_box():
    """A red lacquered jewellery box, 1 x 0.47 x 0.67 (World/Items'
    valuable): ball feet, gilt corner mounts and band, a lid with a gilt
    inlay, the clasp and keyhole on its front (the grey-box's -z)."""
    lacquer = materials.paint("Lacquer", color=(110, 30, 34), roughness=0.14, grime=0.3)
    gilt = _gilt("BoxGilt")
    dark = _dark("BoxKeyhole")
    parts = []
    parts.append(materials.assign(_box("Body", (0.94, 0.33, 0.6), (0, 0.195, 0), 0.02), lacquer))
    for sx in (-1, 1):
        for sz in (-1, 1):
            parts.append(materials.assign(_sphere("Foot", 0.032, (sx * 0.42, 0.032, sz * 0.26), 10, 6), gilt))
            parts.append(materials.assign(_box("Mount", (0.04, 0.3, 0.04), (sx * 0.468, 0.2, sz * 0.298), 0.01), gilt))
    parts.append(materials.assign(_box("Band", (0.98, 0.03, 0.645), (0, 0.355, 0), 0.008), gilt))
    parts.append(materials.assign(_box("Lid", (0.98, 0.07, 0.645), (0, 0.405, 0), 0.025), lacquer))
    parts.append(materials.assign(_box("Dome", (0.88, 0.03, 0.55), (0, 0.45, 0), 0.015), lacquer))
    for size, at in (
        ((0.78, 0.006, 0.014), (0, 0.467, 0.22)),
        ((0.78, 0.006, 0.014), (0, 0.467, -0.22)),
        ((0.014, 0.006, 0.45), (0.39, 0.467, 0)),
        ((0.014, 0.006, 0.45), (-0.39, 0.467, 0)),
    ):
        parts.append(materials.assign(_box("Inlay", size, at, 0.0), gilt))
    parts.append(materials.assign(_box("Clasp", (0.12, 0.12, 0.025), (0, 0.33, -0.312), 0.008), gilt))
    parts.append(materials.assign(_box("Keyhole", (0.025, 0.05, 0.01), (0, 0.32, -0.327), 0.0), dark))
    piece = shapes.join(parts, "JewelleryBox")
    piece["bake_size"] = 512
    return piece


def silver_teapot():
    """A Georgian silver teapot, 0.62 x 0.68 (World/Items' valuable): a
    swelling body on a foot, a domed lid with a finial, a curved spout to
    the front (the grey-box's -z), an ebonised handle behind."""
    silver = _silver("TeapotSilver", 0.2)
    ebony = _dark("TeapotEbony", (30, 22, 18), 0.4)
    parts = []
    body = [(0.0, 0.0), (0.18, 0.0), (0.19, 0.02), (0.16, 0.045), (0.2, 0.065), (0.28, 0.14), (0.31, 0.26), (0.3, 0.38), (0.26, 0.46), (0.2, 0.5), (0.21, 0.52), (0.0, 0.52)]
    parts.append(materials.assign(_lathe("Pot", body, steps=32), silver))
    lid = [(0.0, 0.51), (0.2, 0.51), (0.19, 0.53), (0.14, 0.57), (0.06, 0.6), (0.04, 0.62), (0.055, 0.64), (0.04, 0.67), (0.0, 0.68)]
    parts.append(materials.assign(_lathe("Lid", lid, steps=24), silver))
    spout = _tube("Spout", [(0, 0.15, -0.24), (0, 0.2, -0.33), (0, 0.3, -0.39), (0, 0.42, -0.44), (0, 0.5, -0.5), (0, 0.53, -0.55)], [0.05, 0.042, 0.035, 0.03, 0.025, 0.024], 12)
    parts.append(materials.assign(spout, silver))
    handle = _tube("Handle", [(0, 0.44, 0.24), (0, 0.47, 0.32), (0, 0.42, 0.41), (0, 0.3, 0.43), (0, 0.2, 0.39), (0, 0.15, 0.3)], 0.026, 10)
    parts.append(materials.assign(handle, ebony))
    for y, z in ((0.45, 0.25), (0.16, 0.29)):
        parts.append(materials.assign(_sphere("Socket", 0.034, (0, y, z), 10, 6), silver))
    piece = shapes.join(parts, "SilverTeapot")
    piece["bake_size"] = 512
    return piece


def cash_box():
    """A steel cash box, 0.97 x 0.49 x 0.65 (World/Items' valuable): green
    stove enamel worn at the edges, its lid's lip, a folding bail handle on
    top, a brass lock plate and keyhole on its front (the grey-box's -z)."""
    paint = materials.paint("CashBoxPaint", color=(66, 82, 70), roughness=0.4, grime=0.5)
    seam = _dark("CashBoxSeam", (30, 36, 32), 0.5)
    steel = _chrome("CashBoxSteel")
    brass = materials.brass("CashBoxBrass")
    dark = _dark("CashBoxKeyhole")
    parts = []
    parts.append(materials.assign(_box("Body", (0.95, 0.3, 0.62), (0, 0.15, 0), 0.02), paint))
    parts.append(materials.assign(_box("Seam", (0.955, 0.012, 0.625), (0, 0.3, 0), 0.0), seam))
    parts.append(materials.assign(_box("Lid", (0.97, 0.1, 0.645), (0, 0.355, 0), 0.03), paint))
    for sx in (-1, 1):
        parts.append(materials.assign(_box("Lug", (0.04, 0.05, 0.06), (sx * 0.2, 0.42, 0), 0.01), steel))
    bail = _tube("Bail", [(-0.2, 0.43, 0), (-0.19, 0.47, 0), (-0.15, 0.475, 0), (0.15, 0.475, 0), (0.19, 0.47, 0), (0.2, 0.43, 0)], 0.016, 8)
    parts.append(materials.assign(bail, steel))
    parts.append(materials.assign(_box("LockPlate", (0.16, 0.14, 0.02), (0, 0.27, -0.318), 0.006), brass))
    parts.append(materials.assign(_box("Keyhole", (0.026, 0.06, 0.01), (0, 0.262, -0.33), 0.0), dark))
    piece = shapes.join(parts, "CashBox")
    piece["bake_size"] = 512
    return piece


# The keepsake boxes (World/LeadProps) ------------------------------------------------

KW, KH, KD, KT = 1.15, 0.5, 0.8, 0.06  # the box (LeadProps.keepsake), its walls


def _keepsake_body(name, outer, lining, extra=()):
    """An open box, 1.15 x 0.5 x 0.8: its floor and walls, lined inside (what
    it keeps shows when the lid's up)."""
    parts = [materials.assign(_box("Floor", (KW, 0.06, KD), (0, 0.03, 0), 0.012), outer)]
    for sz in (-1, 1):
        parts.append(materials.assign(_box("Side", (KW, KH - 0.06, KT), (0, (KH + 0.06) / 2, sz * (KD / 2 - KT / 2)), 0.012), outer))
    for sx in (-1, 1):
        parts.append(materials.assign(_box("End", (KT, KH - 0.06, KD - 2 * KT), (sx * (KW / 2 - KT / 2), (KH + 0.06) / 2, 0), 0.012), outer))
    inner_w, inner_d = KW - 2 * KT, KD - 2 * KT
    parts.append(materials.assign(_box("Lining", (inner_w - 0.01, 0.015, inner_d - 0.01), (0, 0.068, 0), 0.0), lining))
    for sz in (-1, 1):
        parts.append(materials.assign(_box("Lining", (inner_w, KH - 0.1, 0.01), (0, 0.06 + (KH - 0.1) / 2, sz * (inner_d / 2 - 0.005)), 0.0), lining))
    for sx in (-1, 1):
        parts.append(materials.assign(_box("Lining", (0.01, KH - 0.1, inner_d), (sx * (inner_w / 2 - 0.005), 0.06 + (KH - 0.1) / 2, 0), 0.0), lining))
    parts += list(extra)
    piece = shapes.join(parts, name)
    piece["bake_size"] = 512
    return piece


# Round the middle of LeadProps' Lid board (1.19 x 0.1 x 0.84 at the box's top).
LW, LH, LD = KW + 0.04, 0.1, KD + 0.04


def keepsake_wood():
    """The walnut keepsake box (LeadProps.KeepsakeLooks "wood"), a brass
    escutcheon on its front, lined in faded ochre velvet. Its lid is
    KeepsakeWoodLid."""
    wood = materials.wood("KeepsakeWalnut", (60, 38, 24), (112, 74, 48), grain_axis="X", scale=1.4, roughness=0.35)
    lining = materials.velvet("KeepsakeOchre", color=(150, 116, 72))
    brass = materials.brass("KeepsakeBrass")
    plate = materials.assign(_box("Escutcheon", (0.08, 0.12, 0.012), (0, 0.32, KD / 2 + 0.004), 0.004), brass)
    return _keepsake_body("KeepsakeWood", wood, lining, [plate])


def keepsake_wood_lid():
    """The walnut box's lid: a moulded board, brass corners, a brass plaque."""
    wood = materials.wood("KeepsakeLidWalnut", (60, 38, 24), (112, 74, 48), grain_axis="X", scale=1.4, roughness=0.35)
    brass = materials.brass("KeepsakeLidBrass")
    parts = [materials.assign(_box("Board", (LW, LH * 0.6, LD), (0, -LH * 0.2, 0), 0.02), wood)]
    parts.append(materials.assign(_box("Field", (LW - 0.12, LH * 0.4, LD - 0.12), (0, LH * 0.3, 0), 0.03, 3), wood))
    for sx in (-1, 1):
        for sz in (-1, 1):
            parts.append(materials.assign(_box("Corner", (0.14, 0.12, 0.14), (sx * (KW / 2 - 0.05), 0, sz * (KD / 2 - 0.05)), 0.015), brass))
    parts.append(materials.assign(_box("Plaque", (0.3, 0.008, 0.14), (0, LH / 2 + 0.004, 0), 0.004), brass))
    piece = shapes.join(parts, "KeepsakeWoodLid")
    piece["bake_size"] = 256
    return piece


def keepsake_tin():
    """The biscuit tin (LeadProps' "tin"): blue enamel with a cream band
    round it, silver inside. Its lid is KeepsakeTinLid."""
    tin = materials.paint("TinBlue", color=(46, 70, 92), roughness=0.3, grime=0.35)
    inside = _silver("TinInside", 0.4)
    cream = materials.paint("TinCream", color=(214, 196, 140), roughness=0.3, grime=0.3)
    band = []
    for sz in (-1, 1):
        band.append(materials.assign(_box("Band", (KW + 0.008, 0.09, 0.006), (0, 0.27, sz * (KD / 2 + 0.002)), 0.0), cream))
    for sx in (-1, 1):
        band.append(materials.assign(_box("Band", (0.006, 0.09, KD + 0.008), (sx * (KW / 2 + 0.002), 0.27, 0), 0.0), cream))
    return _keepsake_body("KeepsakeTin", tin, inside, band)


def keepsake_tin_lid():
    """The tin's red lid, its rolled edge, a cream band and a gold oval."""
    red = materials.paint("TinRed", color=(150, 40, 44), roughness=0.3, grime=0.35)
    cream = materials.paint("TinLidCream", color=(214, 196, 140), roughness=0.3, grime=0.3)
    gold = materials.paint("TinGold", color=(190, 156, 80), roughness=0.3, grime=0.2)
    parts = [materials.assign(_box("Lid", (LW, LH, LD), (0, 0, 0), 0.035, 3), red)]
    parts.append(materials.assign(_box("Band", (LW + 0.01, 0.03, 0.18), (0, LH / 2 + 0.003, 0), 0.008), cream))
    oval = _lathe("Oval", [(0.0, 0.0), (0.16, 0.0), (0.15, 0.012), (0.0, 0.014)], (0, LH / 2 + 0.016, 0), steps=24)
    oval.scale = (1.4, 1.0, 1.0)
    shapes.apply_transform(oval)
    parts.append(materials.assign(oval, gold))
    piece = shapes.join(parts, "KeepsakeTinLid")
    piece["bake_size"] = 256
    return piece


def keepsake_velvet():
    """The velvet case (LeadProps' "velvet"): crushed claret velvet, cream
    satin inside, a gold braid round its top edge. Its lid is
    KeepsakeVelvetLid."""
    velvet = materials.velvet("CaseVelvet", color=(70, 22, 34))
    satin = materials.fabric("CaseSatin", color=(222, 204, 172), roughness=0.5)
    braid = materials.brass("CaseBraid", color=(170, 136, 70), roughness=0.5)
    trim = []
    for sz in (-1, 1):
        trim.append(materials.assign(_box("Braid", (KW + 0.012, 0.025, 0.012), (0, KH - 0.02, sz * (KD / 2 + 0.003)), 0.004), braid))
    for sx in (-1, 1):
        trim.append(materials.assign(_box("Braid", (0.012, 0.025, KD + 0.012), (sx * (KW / 2 + 0.003), KH - 0.02, 0), 0.004), braid))
    return _keepsake_body("KeepsakeVelvet", velvet, satin, trim)


def keepsake_velvet_lid():
    """The velvet case's domed lid and the brass clasp hanging over its
    front (LeadProps' Clasp)."""
    velvet = materials.velvet("CaseLidVelvet", color=(84, 28, 40))
    brass = materials.brass("CaseClasp")
    lid = shapes.cushion("Lid", S(LW, LH, LD), (0, 0, 0), puff=0.04, levels=2, roundness=0.4)
    parts = [materials.assign(lid, velvet)]
    parts.append(materials.assign(_box("Clasp", (0.16, 0.14, 0.04), (0, -0.07, KD / 2 + 0.03), 0.01), brass))
    piece = shapes.join(parts, "KeepsakeVelvetLid")
    piece["bake_size"] = 256
    return piece


# The display case -------------------------------------------------------------------


def display_case():
    """A display case's base, 1.3 x 0.24 x 1 (LeadProps.displayCase): a
    stepped mahogany plinth, green felt, the brass lock plate on its front
    (the game's Lock part, where its pick prompt hangs). Its glass cover's
    frame is DisplayCaseCover; the glass is the game's."""
    wood = materials.wood("CaseMahogany", (52, 26, 18), (104, 56, 36), grain_axis="X", scale=1.2, roughness=0.3)
    felt = materials.velvet("CaseFelt", color=(38, 66, 50))
    brass = materials.brass("CaseLock")
    dark = _dark("CaseKeyhole")
    parts = []
    parts.append(materials.assign(_box("Base", (1.3, 0.14, 1.0), (0, 0.07, 0), 0.02), wood))
    parts.append(materials.assign(_box("Step", (1.24, 0.08, 0.94), (0, 0.18, 0), 0.02), wood))
    parts.append(materials.assign(_box("Felt", (1.1, 0.02, 0.8), (0, 0.23, 0), 0.0), felt))
    parts.append(materials.assign(_box("Lock", (0.18, 0.16, 0.03), (0, 0.11, 0.515), 0.008), brass))
    parts.append(materials.assign(_box("Keyhole", (0.035, 0.07, 0.01), (0, 0.11, 0.532), 0.0), dark))
    piece = shapes.join(parts, "DisplayCase")
    piece["bake_size"] = 512
    return piece


def display_case_cover():
    """The display case's cover: its mahogany frame round the game's glass,
    brass ball finials at the top corners, a brass catch over the lock.
    Built round the middle of the top pane (LeadProps' cover's main part)."""
    wood = materials.wood("CoverMahogany", (52, 26, 18), (104, 56, 36), grain_axis="X", scale=1.2, roughness=0.3)
    brass = materials.brass("CoverBrass")
    w, d, glass_h = 1.2, 0.9, 0.75
    low = -glass_h + 0.02  # the bottom rail, on the base's top
    parts = []
    for y in (0.0, low):
        for sz in (-1, 1):
            parts.append(materials.assign(_box("Rail", (w + 0.06, 0.05, 0.05), (0, y, sz * d / 2), 0.012), wood))
        for sx in (-1, 1):
            parts.append(materials.assign(_box("Rail", (0.05, 0.05, d - 0.05), (sx * w / 2, y, 0), 0.012), wood))
    for sx in (-1, 1):
        for sz in (-1, 1):
            parts.append(materials.assign(_box("Post", (0.05, glass_h, 0.05), (sx * w / 2, -glass_h / 2, sz * d / 2), 0.012), wood))
            parts.append(materials.assign(_sphere("Finial", 0.03, (sx * w / 2, 0.055, sz * d / 2), 10, 6), brass))
    parts.append(materials.assign(_box("Catch", (0.1, 0.07, 0.015), (0, low - 0.02, d / 2 + 0.032), 0.004), brass))
    piece = shapes.join(parts, "DisplayCaseCover")
    piece["bake_size"] = 256
    return piece


def figurine():
    """A porcelain shepherdess, 0.3 x 0.64 (LeadProps.figurine: what a case
    with nothing of his in it shows): a gilt-edged plinth, a pale blue skirt
    with a white apron and a pink sash, a straw bonnet, a gilt crook."""
    white = _porcelain("FigurineWhite", (238, 234, 228))
    blue = materials.paint("FigurineBlue", color=(150, 180, 204), roughness=0.15, grime=0.1)
    pink = materials.paint("FigurinePink", color=(214, 150, 160), roughness=0.15, grime=0.1)
    straw = materials.paint("FigurineStraw", color=(222, 196, 130), roughness=0.2, grime=0.1)
    hair = materials.paint("FigurineHair", color=(150, 110, 60), roughness=0.2, grime=0.1)
    gilt = _gilt("FigurineGilt")
    eye = _dark("FigurineEye")
    parts = []
    parts.append(materials.assign(_lathe("Plinth", [(0.0, 0.0), (0.15, 0.0), (0.15, 0.04), (0.13, 0.06), (0.0, 0.06)], steps=24), white))
    parts.append(materials.assign(_ring("Edge", 0.148, 0.006, (0, 0.04, 0), segments=24), gilt))
    skirt = _lathe("Skirt", [(0.0, 0.06), (0.13, 0.06), (0.12, 0.1), (0.1, 0.2), (0.07, 0.3), (0.05, 0.34), (0.0, 0.34)], steps=24)
    for v in skirt.data.vertices:
        if math.hypot(v.co.x, v.co.y) > 0.01:
            ang = math.atan2(v.co.y, v.co.x)
            k = 1 + 0.06 * math.sin(7 * ang)
            v.co.x *= k
            v.co.y *= k
    skirt.data.update()
    parts.append(materials.assign(skirt, blue))
    apron = _lathe("Apron", [(0.0, 0.1), (0.125, 0.1), (0.105, 0.2), (0.075, 0.3), (0.055, 0.34), (0.0, 0.34)], steps=24)
    bm = bmesh.new()
    bm.from_mesh(apron.data)
    doomed = []
    for f in bm.faces:
        c = f.calc_center_median()
        # Only its front, a little proud of the skirt's folds.
        if c.y > -0.02 or abs(math.atan2(c.x, -c.y)) > 0.55 or c.z < 0.11 or c.z > 0.33:
            doomed.append(f)
    bmesh.ops.delete(bm, geom=doomed, context="FACES")
    bm.to_mesh(apron.data)
    bm.free()
    for v in apron.data.vertices:
        v.co.x *= 1.1
        v.co.y *= 1.1
    apron.data.update()
    parts.append(materials.assign(apron, white))
    parts.append(materials.assign(_lathe("Bodice", [(0.0, 0.33), (0.06, 0.33), (0.056, 0.4), (0.05, 0.45), (0.035, 0.49), (0.0, 0.5)], steps=16), white))
    parts.append(materials.assign(_lathe("Neck", [(0.0, 0.48), (0.018, 0.48), (0.016, 0.51), (0.0, 0.51)], steps=10), white))
    parts.append(materials.assign(_ring("Sash", 0.06, 0.012, (0, 0.345, 0), segments=16), pink))
    parts.append(materials.assign(_sphere("Head", 0.05, (0, 0.55, 0), 16, 8), white))
    parts.append(materials.assign(_sphere("Bun", 0.028, (0, 0.57, -0.04), 10, 6), hair))
    parts.append(materials.assign(_tube("ArmL", [(-0.055, 0.47, 0.0), (-0.075, 0.42, 0.02), (-0.08, 0.37, 0.04)], 0.014, 6), white))
    parts.append(materials.assign(_lathe("Bonnet", [(0.0, 0.6), (0.085, 0.598), (0.088, 0.606), (0.05, 0.615), (0.04, 0.635), (0.0, 0.64)], steps=20), straw))
    for sx in (-1, 1):
        parts.append(materials.assign(_sphere("Eye", 0.007, (sx * 0.018, 0.558, 0.046), 6, 4), eye))
    parts.append(materials.assign(_tube("ArmR", [(0.055, 0.47, 0.0), (0.08, 0.43, 0.03), (0.097, 0.41, 0.05)], 0.014, 6), white))
    parts.append(materials.assign(_tube("Crook", [(0.1, 0.07, 0.05), (0.1, 0.56, 0.05), (0.105, 0.6, 0.05), (0.125, 0.615, 0.05), (0.14, 0.6, 0.05), (0.135, 0.58, 0.05)], 0.008, 6), gilt))
    piece = shapes.join(parts, "Figurine")
    piece["bake_size"] = 256
    return piece


# The key rack ---------------------------------------------------------------------------


def key_rack():
    """A pine key rack, 1.9 x 0.8 x 0.31 (LeadProps.keyRack), built round the
    middle of its board, its back on the wall (z = 0): a board with a
    rounded crest and a brass plate, a little shelf on brackets, four brass
    cup hooks where the keys hang."""
    pine = materials.wood("RackPine", (120, 86, 56), (170, 130, 88), grain_axis="X", scale=1.5, roughness=0.6)
    brass = materials.brass("RackBrass")
    parts = []
    parts.append(materials.assign(_box("Board", (1.9, 0.62, 0.1), (0, -0.09, 0.05), 0.03, 3), pine))
    parts.append(materials.assign(_box("Crest", (1.4, 0.2, 0.1), (0, 0.3, 0.05), 0.06, 4), pine))
    parts.append(materials.assign(_box("Plate", (0.4, 0.09, 0.01), (0, 0.31, 0.105), 0.004), brass))
    parts.append(materials.assign(_box("Shelf", (1.8, 0.04, 0.16), (0, 0.24, 0.13), 0.012), pine))
    for sx in (-1, 1):
        parts.append(materials.assign(_box("Bracket", (0.03, 0.12, 0.1), (sx * 0.8, 0.17, 0.13), 0.01), pine))
    for i in range(4):
        x = -1.9 / 2 + 1.9 * (i + 0.5) / 4
        parts.append(materials.assign(_ring("Washer", 0.026, 0.008, (x, 0.02, 0.105), (90, 0, 0), 12), brass))
        hook = _tube("Hook", [(x, 0.02, 0.1), (x, 0.02, 0.2), (x, 0.005, 0.26), (x, 0.03, 0.305), (x, 0.07, 0.3), (x, 0.09, 0.28)], 0.014, 8)
        parts.append(materials.assign(hook, brass))
    piece = shapes.join(parts, "KeyRack")
    piece["bake_size"] = 512
    return piece


# The locks' hardware (Services/LockService) ------------------------------------------------
# Each round the middle of its plate, its front (+z) out of the door.


def _keyhole(parts, y, z, dark):
    parts.append(materials.assign(shapes.roll("Hole", 0.006, 0.026, G(0, y + 0.03, z), axis="Y", steps=12), dark))
    parts.append(materials.assign(_box("Slot", (0.024, 0.06, 0.006), (0, y - 0.005, z), 0.0), dark))


def _plate(name, height, holes):
    brass = materials.brass(name + "Brass", color=(164, 132, 76), roughness=0.32)
    dark = _dark(name + "Hole")
    parts = [materials.assign(_box("Plate", (0.3, height, 0.035), (0, 0, -0.0075), 0.012), brass)]
    parts.append(materials.assign(_box("Field", (0.24, height - 0.06, 0.012), (0, 0, 0.016), 0.005), brass))
    for y in holes:
        _keyhole(parts, y, 0.022, dark)
    for y in (height / 2 - 0.05, -height / 2 + 0.05):
        parts.append(materials.assign(_lathe("Screw", [(0.0, 0.0), (0.02, 0.0), (0.016, 0.008), (0.0, 0.01)], steps=10), brass))
        shapes.turn(parts[-1], (90, 0, 0), G(0, y, 0.022))
    piece = shapes.join(parts, name)
    piece["bake_size"] = 256
    return piece


def key_plate():
    """A brass escutcheon, 0.3 x 0.6 (a keyed lock's plate): a raised field,
    the keyhole, two screws."""
    return _plate("KeyPlate", 0.6, [0.03])


def key_plate_double():
    """The double lock's long plate, 0.3 x 1.3: two keyholes."""
    return _plate("KeyPlateDouble", 1.3, [0.33, -0.27])


def hasp():
    """A hasp and staple with a combination padlock hanging from it, 0.3 x
    0.6 x 0.2 (a code lock's plate): its four number wheels across the
    lock's front."""
    steel = _steel("HaspSteel", (92, 94, 98), 0.4, 0.35)
    brass = materials.brass("HaspLock", color=(156, 124, 70), roughness=0.3)
    chrome = _chrome("HaspShackle")
    wheel = _dark("HaspWheel", (44, 44, 46), 0.4)
    figure = materials.paint("HaspFigure", color=(220, 214, 196), roughness=0.4, grime=0.0)
    parts = []
    parts.append(materials.assign(_box("Back", (0.24, 0.56, 0.025), (0, 0.0, -0.08), 0.008), steel))
    parts.append(materials.assign(_box("Strap", (0.11, 0.34, 0.02), (0, 0.1, -0.058), 0.006), steel))
    staple = _tube("Staple", [(-0.045, -0.06, -0.07), (-0.045, -0.06, -0.025), (0.045, -0.06, -0.025), (0.045, -0.06, -0.07)], 0.013, 8)
    parts.append(materials.assign(staple, steel))
    parts.append(materials.assign(_box("Lock", (0.26, 0.24, 0.09), (0, -0.2, 0.015), 0.025), brass))
    shackle = _tube("Shackle", [(-0.06, -0.09, 0.015), (-0.06, -0.04, 0.0), (-0.035, -0.015, -0.03), (0.035, -0.015, -0.03), (0.06, -0.04, 0.0), (0.06, -0.09, 0.015)], 0.014, 8)
    parts.append(materials.assign(shackle, chrome))
    for x in (-0.09, -0.03, 0.03, 0.09):
        parts.append(materials.assign(shapes.roll("Wheel", 0.05, 0.04, G(x, -0.22, 0.06), axis="X", steps=12), wheel))
        parts.append(materials.assign(_box("Figure", (0.014, 0.024, 0.004), (x, -0.22, 0.101), 0.0), figure))
    piece = shapes.join(parts, "Hasp")
    piece["bake_size"] = 256
    return piece


def bolt():
    """A black iron barrel bolt, 1.4 x 0.18 x 0.12 (a bolted door's plate):
    its back plate and straps, the barrel, the worn bolt with its knob, the
    keeper it shoots into."""
    iron = materials.paint("BoltIron", color=(40, 40, 42), roughness=0.5, grime=0.3)
    worn = materials.brass("BoltWorn", color=(120, 118, 112), roughness=0.4)
    parts = []
    parts.append(materials.assign(_box("Back", (0.9, 0.16, 0.02), (-0.15, 0.0, -0.05), 0.006), iron))
    parts.append(materials.assign(shapes.roll("Barrel", 0.8, 0.045, G(-0.15, 0.0, -0.01), axis="X", steps=12), iron))
    for x in (-0.5, 0.2):
        parts.append(materials.assign(_box("Strap", (0.07, 0.15, 0.05), (x, 0.0, -0.02), 0.01), iron))
    parts.append(materials.assign(shapes.roll("Rod", 1.05, 0.028, G(0.02, 0.0, -0.01), axis="X", steps=10), worn))
    parts.append(materials.assign(shapes.roll("Stub", 0.1, 0.018, G(-0.1, 0.05, -0.01), axis="Z", steps=8), worn))
    parts.append(materials.assign(_sphere("Knob", 0.03, (-0.1, 0.11, -0.01), 10, 6), worn))
    parts.append(materials.assign(_box("Keeper", (0.16, 0.17, 0.08), (0.6, 0.0, -0.02), 0.015), iron))
    piece = shapes.join(parts, "Bolt")
    piece["bake_size"] = 256
    return piece


def power_box():
    """A grey steel junction box, 0.5 x 0.8 x 0.16 (an electric lock's
    plate): a screwed cover, a chrome bezel round the game's lamp, a yellow
    warning label, a cable gland on top."""
    grey = _steel("PowerGrey", (96, 100, 98), 0.45, 0.45)
    chrome = _chrome("PowerBezel")
    label = materials.paint("PowerLabel", color=(200, 170, 50), roughness=0.4, grime=0.3)
    ink = _dark("PowerInk")
    parts = []
    parts.append(materials.assign(_box("Body", (0.48, 0.78, 0.13), (0, 0.0, -0.015), 0.03), grey))
    parts.append(materials.assign(_box("Cover", (0.44, 0.74, 0.02), (0, 0.0, 0.06), 0.015), grey))
    for sx in (-1, 1):
        for sy in (-1, 1):
            parts.append(materials.assign(_sphere("Screw", 0.014, (sx * 0.18, sy * 0.33, 0.07), 8, 4), chrome))
    parts.append(materials.assign(_ring("Bezel", 0.086, 0.014, (0, 0.25, 0.072), (90, 0, 0), 20), chrome))
    parts.append(materials.assign(_box("Label", (0.3, 0.12, 0.004), (0, -0.15, 0.072), 0.0), label))
    for k in range(3):
        parts.append(materials.assign(_box("Line", (0.22 - 0.05 * k, 0.012, 0.002), (0, -0.12 - 0.025 * k, 0.075), 0.0), ink))
    parts.append(materials.assign(shapes.roll("Gland", 0.03, 0.028, G(0.13, 0.385, -0.02), axis="Z", steps=12), grey))
    piece = shapes.join(parts, "PowerBox")
    piece["bake_size"] = 256
    return piece


def padlock():
    """A laminated steel padlock, 0.36 x 0.66 x 0.16 (a chain's lock), built
    round the middle of its body (the game's Padlock part); its shackle
    above, its keyway under a brass cover on the front."""
    steel = _steel("PadlockSteel", (82, 84, 88), 0.35, 0.35)
    groove = _dark("PadlockGroove", (40, 40, 42), 0.5)
    chrome = _chrome("PadlockShackle")
    brass = materials.brass("PadlockBrass")
    dark = _dark("PadlockKeyway")
    parts = []
    parts.append(materials.assign(_box("Body", (0.36, 0.42, 0.16), (0, 0, 0), 0.03), steel))
    for k in range(6):
        parts.append(materials.assign(_box("Groove", (0.364, 0.008, 0.164), (0, -0.15 + k * 0.06, 0), 0.0), groove))
    parts.append(materials.assign(shapes.roll("Cover", 0.012, 0.05, G(0, -0.09, 0.083), axis="Y", steps=14), brass))
    parts.append(materials.assign(_box("Keyway", (0.012, 0.05, 0.006), (0, -0.09, 0.09), 0.0), dark))
    shackle = _tube("Shackle", [(-0.1, 0.2, 0), (-0.1, 0.33, 0), (-0.075, 0.395, 0), (0.0, 0.42, 0), (0.075, 0.395, 0), (0.1, 0.33, 0), (0.1, 0.2, 0)], 0.032, 10)
    parts.append(materials.assign(shackle, chrome))
    piece = shapes.join(parts, "Padlock")
    piece["bake_size"] = 256
    return piece


def plank():
    """A rough pine plank, 7 x 0.55 x 0.14 (the boards nailed across a door
    or a chest, fitted to each), two nails driven through each end on both
    faces."""
    pine = materials.wood("PlankPine", (110, 80, 52), (168, 128, 86), grain_axis="X", scale=0.9, roughness=0.8)
    iron = _dark("PlankNail", (52, 50, 48), 0.5)
    parts = [materials.assign(_box("Plank", (7.0, 0.55, 0.14), (0, 0, 0), 0.015), pine)]
    rng = random.Random(9)
    for v in parts[0].data.vertices:
        if abs(v.co.x) > 3.45:
            v.co.x += rng.uniform(-0.03, 0.03)
    parts[0].data.update()
    for x in (-3.2, 3.2):
        for y in (-0.14, 0.14):
            for sz in (-1, 1):
                nail = _lathe("Nail", [(0.0, 0.0), (0.035, 0.0), (0.03, 0.012), (0.0, 0.014)], steps=10)
                shapes.turn(nail, (90 if sz > 0 else -90, 0, 0), G(x + rng.uniform(-0.05, 0.05), y, sz * 0.07))
                parts.append(materials.assign(nail, iron))
    piece = shapes.join(parts, "Plank")
    piece["bake_size"] = 512
    return piece


# The dinner (Services/FinaleService) ----------------------------------------------------------


def dinner_plate():
    """A gold-rimmed china plate, 1.3 across (a place at the dinner, its
    card and candle the game's and the kit's), round its own middle."""
    china = _porcelain("PlateChina", (238, 234, 224))
    gold = materials.brass("PlateGold", color=(180, 146, 80), roughness=0.25)
    profile = [
        (0.0, 0.005),
        (0.38, 0.005),
        (0.4, 0.0),
        (0.44, 0.0),
        (0.46, 0.02),
        (0.5, 0.045),
        (0.63, 0.06),
        (0.65, 0.072),
        (0.645, 0.08),
        (0.62, 0.076),
        (0.5, 0.058),
        (0.45, 0.034),
        (0.42, 0.028),
        (0.0, 0.028),
    ]
    parts = [materials.assign(_lathe("Plate", profile, (0, -0.04, 0), steps=48), china)]
    parts.append(materials.assign(_ring("Rim", 0.63, 0.005, (0, 0.034, 0), segments=48, sides=4), gold))
    parts.append(materials.assign(_ring("Well", 0.47, 0.004, (0, -0.002, 0), segments=48, sides=4), gold))
    piece = shapes.join(parts, "DinnerPlate")
    piece["bake_size"] = 512
    return piece


def table_candle():
    """A dinner candle in a silver chamberstick, 0.28 x 0.62, round its own
    middle; its top where the game's flame burns."""
    silver = _silver("ChamberSilver")
    wax = materials.paint("DinnerWax", color=(238, 232, 214), roughness=0.45, grime=0.12)
    wick = _dark("DinnerWick")
    y0 = -0.31
    parts = []
    holder = [(0.0, 0.0), (0.14, 0.0), (0.14, 0.015), (0.11, 0.03), (0.05, 0.05), (0.045, 0.07), (0.062, 0.09), (0.062, 0.11), (0.0, 0.11)]
    parts.append(materials.assign(_lathe("Holder", holder, (0, y0, 0), steps=24), silver))
    candle = [(0.0, 0.1), (0.072, 0.1), (0.072, 0.58), (0.06, 0.6), (0.0, 0.595)]
    parts.append(materials.assign(_lathe("Candle", candle, (0, y0, 0), steps=18), wax))
    rng = random.Random(6)
    for k in range(3):
        ang = rng.uniform(0, math.tau)
        low = 0.56 - rng.uniform(0.06, 0.22)
        cx, cz = math.cos(ang) * 0.069, math.sin(ang) * 0.069
        drip = _tube("Drip", [(cx, y0 + 0.565, cz), (cx * 1.02, y0 + (0.565 + low) / 2, cz * 1.02), (cx, y0 + low, cz)], [0.007, 0.009, 0.005], 6)
        parts.append(materials.assign(drip, wax))
    parts.append(materials.assign(_tube("Wick", [(0, y0 + 0.59, 0), (0.004, y0 + 0.615, 0)], 0.006, 6), wick))
    piece = shapes.join(parts, "TableCandle")
    piece["bake_size"] = 256
    return piece


THINGS = [
    key,
    candlestick,
    pocket_watch,
    locket,
    doll,
    christening_cup,
    carriage_clock,
    jewellery_box,
    silver_teapot,
    cash_box,
    keepsake_wood,
    keepsake_wood_lid,
    keepsake_tin,
    keepsake_tin_lid,
    keepsake_velvet,
    keepsake_velvet_lid,
    display_case,
    display_case_cover,
    figurine,
    key_rack,
    key_plate,
    key_plate_double,
    hasp,
    bolt,
    power_box,
    padlock,
    plank,
    dinner_plate,
    table_candle,
]
