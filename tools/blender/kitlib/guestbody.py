"""The Guest's body (V5, the Guest remodelled; docs/ART.md "The Guest").

A dinner guest who stayed far too long: a long black wool overcoat to below
the knee, its collar turned up round a black neck, a dead carnation in its
lapel, a grubby shirt and a dark tie in the V; sleeves a little short, so
thin bony wrists show; long, bone-pale hands with knuckled fingers and long
yellowed nails; thin black trousers and cracked old dress shoes; a black
head like a stocking pulled over a skull, under the porcelain mask
(kitlib/guestmask).

Every piece is lofted from rings in the game's frame (kitlib/guestrig) and
skinned to the joint bones by height down each limb, so it bends where the
game's Motor6Ds turn. A piece is cut where a part ends (the sleeve at the
elbow, the trousers at the knee) on a shared ring with the same weights,
so the cut never opens: Roblox culls a MeshPart by its own box, and each
piece rides on its own part (Stalker/StalkerModel).
"""

import math

import bmesh
import bpy
import mathutils
from mathutils import Vector

from . import materials
from .guestrig import G2B, RIG, centre, chain, finger_layout, joint, smoothstep, weigh

TAU = math.pi * 2


# Geometry helpers -------------------------------------------------------------


def _object(name, bm):
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    return obj


def noise(p, scale=1.0):
    return mathutils.noise.noise(Vector((p[0] * scale, p[1] * scale, p[2] * scale)))


def spow(v, e):
    return math.copysign(abs(v) ** e, v)


def curve(keys, t):
    """Smooth interpolation through [(t, value)] (sorted by t)."""
    if t <= keys[0][0]:
        return keys[0][1]
    if t >= keys[-1][0]:
        return keys[-1][1]
    for (t0, v0), (t1, v1) in zip(keys, keys[1:]):
        if t0 <= t <= t1:
            u = (t - t0) / (t1 - t0)
            u = u * u * (3 - 2 * u)
            return v0 + (v1 - v0) * u
    return keys[-1][1]


def ring(y, w, d, count, x0=0.0, z0=0.0, n=2.0, a0=0.0, a1=TAU, closed=True, push=None):
    """Points round a superellipse at height y (game frame): half-width w
    (x), half-depth d (z), centred on (x0, z0); angle 0 is +x, 90 degrees +z
    (his back). push(angle, point) -> studs outward."""
    pts = []
    steps = count if closed else count - 1
    for i in range(count):
        a = a0 + (a1 - a0) * i / steps
        c, s = math.cos(a), math.sin(a)
        x = w * spow(c, 2.0 / n)
        z = d * spow(s, 2.0 / n)
        p = Vector((x0 + x, y, z0 + z))
        if push:
            out = Vector((x / max(w, 1e-6), 0, z / max(d, 1e-6)))
            if out.length > 1e-6:
                out.normalize()
            p += out * push(a, p)
        pts.append(p)
    return pts


def loft(name, rings, closed=True, mat_of=None, axis=None):
    """A surface through rings of game-frame points (each the same count),
    faces turned away from axis(p) (the line it's lofted round), so they face
    out. mat_of(i, j) -> material index."""
    bm = bmesh.new()
    vs = [[bm.verts.new(G2B(p)) for p in r] for r in rings]
    n = len(rings[0])
    for i in range(len(rings) - 1):
        for j in range(n if closed else n - 1):
            k = (j + 1) % n
            face = bm.faces.new((vs[i][j], vs[i + 1][j], vs[i + 1][k], vs[i][k]))
            if mat_of:
                face.material_index = mat_of(i, j)
    _face_out(bm, axis)
    return _object(name, bm)


def _face_out(bm, axis):
    bm.normal_update()
    for f in bm.faces:
        c = f.calc_center_median()
        g = Vector((c.x, c.z, -c.y))  # back to the game's frame
        if axis is None:
            away = g - Vector((0, g.y, 0))
        else:
            away = g - axis(g)
        away_b = Vector((away.x, -away.z, away.y))
        if away_b.length > 1e-6 and f.normal.dot(away_b) < 0:
            f.normal_flip()
    bm.normal_update()


def solidify(obj, thickness, offset=-1.0):
    mod = obj.modifiers.new("Solidify", "SOLIDIFY")
    mod.thickness = thickness
    mod.offset = offset
    mod.use_even_offset = True
    mod.use_rim = True
    _apply(obj, mod)
    return obj


def _apply(obj, mod):
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.modifier_apply(modifier=mod.name)


def join(objects, name):
    objects = [o for o in objects if o is not None]
    bpy.ops.object.select_all(action="DESELECT")
    for o in objects:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objects[0]
    bpy.ops.object.join()
    obj = bpy.context.view_layer.objects.active
    obj.name = name
    obj.data.name = name
    return obj


def shade(obj, angle=50):
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    try:
        bpy.ops.object.shade_smooth_by_angle(angle=math.radians(angle))
    except (AttributeError, RuntimeError):
        bpy.ops.object.shade_smooth()
    return obj


def mats(obj, *materials_):
    obj.data.materials.clear()
    for m in materials_:
        obj.data.materials.append(m)
    return obj


def tube(name, path, radius, count=10, mat=0, cap_end=True):
    """A round tube along path (game-frame points) with radius(t, i) at each
    point (t 0..1 along it): fingers, stems."""
    bm = bmesh.new()
    rings = []
    for i, p in enumerate(path):
        a = path[min(i + 1, len(path) - 1)] - path[max(i - 1, 0)]
        a.normalize()
        ref = Vector((0, 0, 1)) if abs(a.z) < 0.9 else Vector((1, 0, 0))
        u = a.cross(ref).normalized()
        v = a.cross(u).normalized()
        t = i / (len(path) - 1)
        rr = []
        for k in range(count):
            ang = TAU * k / count
            r = radius(t, i, ang)
            q = p + (u * math.cos(ang) + v * math.sin(ang)) * r
            rr.append(bm.verts.new(G2B(q)))
        rings.append(rr)
    for i in range(len(rings) - 1):
        for k in range(count):
            j = (k + 1) % count
            f = bm.faces.new((rings[i][k], rings[i][j], rings[i + 1][j], rings[i + 1][k]))
            f.material_index = mat
    if cap_end:
        tip = bm.verts.new(G2B(path[-1] + (path[-1] - path[-2]).normalized() * radius(1.0, len(path) - 1, 0) * 0.7))
        for k in range(count):
            j = (k + 1) % count
            f = bm.faces.new((rings[-1][k], rings[-1][j], tip))
            f.material_index = mat
    bm.normal_update()
    # Outward: away from the path.
    for f in bm.faces:
        c = f.calc_center_median()
        g = Vector((c.x, c.z, -c.y))
        best = min(path, key=lambda q: (q - g).length)
        away = g - best
        away_b = Vector((away.x, -away.z, away.y))
        if away_b.length > 1e-6 and f.normal.dot(away_b) < 0:
            f.normal_flip()
    return _object(name, bm)


def ellipsoid(name, c, r, rings=8, segs=12, mat=0, warp=None):
    """A small ellipsoid at c (game frame) with radii r: buttons, knuckles."""
    bm = bmesh.new()
    verts = []
    for i in range(rings + 1):
        phi = -math.pi / 2 + math.pi * i / rings
        row = []
        for k in range(segs):
            th = TAU * k / segs
            p = Vector((math.cos(phi) * math.cos(th) * r[0], math.sin(phi) * r[1], math.cos(phi) * math.sin(th) * r[2]))
            if warp:
                p = warp(p)
            row.append(bm.verts.new(G2B(Vector(c) + p)))
        verts.append(row)
    for i in range(rings):
        for k in range(segs):
            j = (k + 1) % segs
            quad = [verts[i][k], verts[i][j], verts[i + 1][j], verts[i + 1][k]]
            uniq = []
            for v in quad:
                if all((v.co - u.co).length > 1e-7 for u in uniq):
                    uniq.append(v)
            if len(uniq) >= 3:
                try:
                    f = bm.faces.new(uniq)
                    f.material_index = mat
                except ValueError:
                    pass
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-6)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return _object(name, bm)


def plate(name, rows, mat=0, normal_hint=None):
    """A sheet through rows of points (a grid), faces toward normal_hint
    (game frame): lapels, the shirt, the tie, flaps."""
    bm = bmesh.new()
    vs = [[bm.verts.new(G2B(p)) for p in r] for r in rows]
    for i in range(len(rows) - 1):
        for j in range(len(rows[0]) - 1):
            f = bm.faces.new((vs[i][j], vs[i + 1][j], vs[i + 1][j + 1], vs[i][j + 1]))
            f.material_index = mat
    bm.normal_update()
    if normal_hint is not None:
        hint = G2B(normal_hint)
        for f in bm.faces:
            if f.normal.dot(hint) < 0:
                f.normal_flip()
    return _object(name, bm)


def game_points(obj):
    return [Vector((v.co.x, v.co.z, -v.co.y)) for v in obj.data.vertices]


# Materials -----------------------------------------------------------------------

_cache = {}


def _srgb(c):
    return materials._srgb(c)


def wool(name="GuestWool", color=(22, 21, 24), light=(34, 33, 37)):
    """Heavy black overcoat wool: a fine twill, lint specks, worn lighter
    on the edges. Matte: your torch must not shine on it."""
    if name in _cache:
        return _cache[name]
    mat = bpy.data.materials.new(name)
    n = materials.Nodes(mat)
    m = n.mapping(scale=(1, 1, 1))
    mottle = n.noise(m.outputs["Vector"], 14.0, 4.0, 0.6)
    ramp = n.ramp(mottle.outputs["Fac"], [(0.3, _srgb(color)), (0.7, _srgb(light))])
    lint = n.noise(m.outputs["Vector"], 260.0, 2.0, 0.5)
    specks = n.ramp(lint.outputs["Fac"], [(0.7, (0, 0, 0, 1)), (0.78, (1, 1, 1, 1))])
    geo = n.add("ShaderNodeNewGeometry")
    edge = n.ramp(geo.outputs["Pointiness"], [(0.52, (0, 0, 0, 1)), (0.6, (1, 1, 1, 1))])
    worn = n.mix_colour(ramp.outputs["Color"], _cast((52, 50, 52), n), 0.0)
    _link_factor(n, worn, edge.outputs["Color"], 0.5)
    speck = n.mix_colour(worn, _cast((74, 70, 66), n), 0.0)
    _link_factor(n, speck, specks.outputs["Color"], 0.35)
    n.link(speck, n.bsdf.inputs["Base Color"])
    n.bsdf.inputs["Roughness"].default_value = 0.94
    # Twill: fine diagonal ribs.
    wave = n.add("ShaderNodeTexWave")
    wave.wave_type = "BANDS"
    wave.bands_direction = "DIAGONAL"
    wave.inputs["Scale"].default_value = 90.0
    wave.inputs["Distortion"].default_value = 1.5
    n.link(m.outputs["Vector"], wave.inputs["Vector"])
    n.bump(wave.outputs["Fac"], 0.12, 0.004)
    _cache[name] = mat
    return mat


def _cast(rgb, n=None):
    """A colour as an RGB node output (for mix inputs)."""
    node = (n or _cast.n).add("ShaderNodeRGB")
    node.outputs["Color"].default_value = _srgb(rgb)
    return node.outputs["Color"]


def _link_factor(n, result_socket, factor_socket, scale=1.0):
    """Points a Mix node's factor (found from its result socket) at a
    factor, scaled."""
    node = result_socket.node
    fac = [s for s in node.inputs if s.identifier == "Factor_Float"][0]
    if scale != 1.0:
        m = n.math("MULTIPLY", factor_socket, scale)
        n.link(m.outputs["Value"], fac)
    else:
        n.link(factor_socket, fac)


def _simple(name, rgb, rough, dark=None, scale=30.0, bump=0.08, metal=0.0, stains=None):
    """A plain material: a colour mottled toward dark, a roughness, a bump;
    stains = (rgb, amount): blotches."""
    if name in _cache:
        return _cache[name]
    mat = bpy.data.materials.new(name)
    n = materials.Nodes(mat)
    _cast.n = n
    m = n.mapping()
    mottle = n.noise(m.outputs["Vector"], scale, 5.0, 0.55)
    ramp = n.ramp(mottle.outputs["Fac"], [(0.25, _srgb(dark or rgb)), (0.75, _srgb(rgb))])
    out = ramp.outputs["Color"]
    if stains:
        blot = n.noise(m.outputs["Vector"], 6.0, 3.0, 0.6)
        mask = n.ramp(blot.outputs["Fac"], [(0.58, (0, 0, 0, 1)), (0.68, (1, 1, 1, 1))])
        mixed = n.mix_colour(out, _cast(stains[0], n), 0.0)
        _link_factor(n, mixed, mask.outputs["Color"], stains[1])
        out = mixed
    n.link(out, n.bsdf.inputs["Base Color"])
    n.bsdf.inputs["Roughness"].default_value = rough
    n.bsdf.inputs["Metallic"].default_value = metal
    if bump:
        fine = n.noise(m.outputs["Vector"], scale * 6, 3.0, 0.5)
        n.bump(fine.outputs["Fac"], bump, 0.003)
    _cache[name] = mat
    return mat


def leather():
    """Old black dress-shoe leather: cracked across the creases, scuffed."""
    if "GuestLeather" in _cache:
        return _cache["GuestLeather"]
    mat = bpy.data.materials.new("GuestLeather")
    n = materials.Nodes(mat)
    m = n.mapping()
    vor = n.add("ShaderNodeTexVoronoi")
    vor.feature = "DISTANCE_TO_EDGE"
    vor.inputs["Scale"].default_value = 70.0
    n.link(m.outputs["Vector"], vor.inputs["Vector"])
    crack = n.ramp(vor.outputs["Distance"], [(0.0, (1, 1, 1, 1)), (0.06, (0, 0, 0, 1))])
    scuff = n.noise(m.outputs["Vector"], 9.0, 4.0, 0.6)
    scuffs = n.ramp(scuff.outputs["Fac"], [(0.62, (0, 0, 0, 1)), (0.72, (1, 1, 1, 1))])
    base = _cast((15, 14, 14), n)
    col = n.mix_colour(base, _cast((44, 41, 39), n), 0.0)
    _link_factor(n, col, scuffs.outputs["Color"], 0.8)
    col2 = n.mix_colour(col, _cast((6, 6, 6), n), 0.0)
    _link_factor(n, col2, crack.outputs["Color"], 0.8)
    n.link(col2, n.bsdf.inputs["Base Color"])
    rough = n.math("MULTIPLY_ADD", scuffs.outputs["Color"], 0.35, 0.42)
    n.link(rough.outputs["Value"], n.bsdf.inputs["Roughness"])
    n.bump(crack.outputs["Color"], -0.3, 0.004)
    _cache["GuestLeather"] = mat
    return mat


def skin():
    """His hands and wrists: bone-pale and waxy, mottled, greyer at the
    knuckles, faint veins."""
    if "GuestSkin" in _cache:
        return _cache["GuestSkin"]
    mat = bpy.data.materials.new("GuestSkin")
    mat["uv_share"] = 0.3  # (kitlib/bake: the hands are seen up close)
    n = materials.Nodes(mat)
    m = n.mapping()
    mottle = n.noise(m.outputs["Vector"], 40.0, 5.0, 0.55)
    ramp = n.ramp(mottle.outputs["Fac"], [(0.3, _srgb((158, 150, 140))), (0.7, _srgb((184, 178, 166)))])
    geo = n.add("ShaderNodeNewGeometry")
    knuckle = n.ramp(geo.outputs["Pointiness"], [(0.5, (0, 0, 0, 1)), (0.58, (1, 1, 1, 1))])
    col = n.mix_colour(ramp.outputs["Color"], _cast((132, 118, 112), n), 0.0)
    _link_factor(n, col, knuckle.outputs["Color"], 0.6)
    veins = n.add("ShaderNodeTexWave")
    veins.wave_type = "RINGS"
    veins.inputs["Scale"].default_value = 18.0
    veins.inputs["Distortion"].default_value = 14.0
    veins.inputs["Detail"].default_value = 3.0
    n.link(m.outputs["Vector"], veins.inputs["Vector"])
    vmask = n.ramp(veins.outputs["Fac"], [(0.0, (1, 1, 1, 1)), (0.08, (0, 0, 0, 1))])
    col2 = n.mix_colour(col, _cast((128, 134, 142), n), 0.0)
    _link_factor(n, col2, vmask.outputs["Color"], 0.35)
    n.link(col2, n.bsdf.inputs["Base Color"])
    n.bsdf.inputs["Roughness"].default_value = 0.52
    pores = n.noise(m.outputs["Vector"], 400.0, 2.0, 0.5)
    n.bump(pores.outputs["Fac"], 0.08, 0.002)
    _cache["GuestSkin"] = mat
    return mat


def hood():
    """The black over his skull and neck: a fine rib knit, like a stocking."""
    if "GuestHood" in _cache:
        return _cache["GuestHood"]
    mat = bpy.data.materials.new("GuestHood")
    n = materials.Nodes(mat)
    m = n.mapping()
    mottle = n.noise(m.outputs["Vector"], 20.0, 3.0, 0.5)
    ramp = n.ramp(mottle.outputs["Fac"], [(0.3, _srgb((7, 7, 8))), (0.7, _srgb((14, 13, 15)))])
    n.link(ramp.outputs["Color"], n.bsdf.inputs["Base Color"])
    n.bsdf.inputs["Roughness"].default_value = 0.9
    rib = n.add("ShaderNodeTexWave")
    rib.wave_type = "BANDS"
    rib.bands_direction = "X"
    rib.inputs["Scale"].default_value = 160.0
    n.link(m.outputs["Vector"], rib.inputs["Vector"])
    n.bump(rib.outputs["Fac"], 0.18, 0.003)
    _cache["GuestHood"] = mat
    return mat


def body_materials():
    """Material slots shared by every body piece, in this order."""
    return [
        wool(),  # 0
        _simple("GuestShirt", (150, 143, 130), 0.82, dark=(128, 120, 106), stains=((128, 112, 82), 0.45)),  # 1
        _simple("GuestTie", (52, 22, 27), 0.55, dark=(36, 15, 19), scale=60.0),  # 2
        _simple("GuestHorn", (62, 52, 40), 0.36, dark=(40, 33, 26), scale=50.0, bump=0.02),  # 3
        leather(),  # 4
        skin(),  # 5
        _simple("GuestNail", (174, 152, 104), 0.32, dark=(120, 98, 62), scale=80.0, bump=0.04),  # 6
        hood(),  # 7
        _simple("GuestFlower", (84, 58, 48), 0.9, dark=(52, 36, 30), scale=90.0, bump=0.2),  # 8
        wool("GuestTrouser", (18, 18, 20), (28, 27, 30)),  # 9
    ]


WOOL, SHIRT, TIE, HORN, LEATHER, SKIN, NAIL, HOOD, FLOWER, TROUSER = range(10)


def _all_mats(obj):
    obj.data.materials.clear()
    for m in body_materials():
        obj.data.materials.append(m)
    return obj


def _set_mat(obj, index):
    for p in obj.data.polygons:
        p.material_index = index
    return obj


# The coat ------------------------------------------------------------------------

Y_TOP = RIG["neckY"] + 0.03  # the coat's neck hole


def _torso_shape(y):
    # (Narrow sloping shoulders: from the shoulder's point down at 6.5 to
    # the neck, the coat falling away; the sleeves' heads round them off.)
    w = curve([(4.28, 0.565), (4.42, 0.575), (4.8, 0.56), (5.4, 0.6), (6.0, 0.66), (6.3, 0.7), (6.5, 0.68), (6.66, 0.6), (6.78, 0.48), (6.88, 0.34), (6.95, 0.25), (Y_TOP, 0.21)], y)
    d = curve([(4.28, 0.355), (4.42, 0.36), (4.8, 0.36), (5.4, 0.38), (6.0, 0.41), (6.4, 0.4), (6.6, 0.34), (6.8, 0.26), (Y_TOP, 0.19)], y)
    zc = curve([(4.28, 0.03), (6.0, 0.05), (6.4, 0.08), (6.8, 0.06), (Y_TOP, 0.02)], y)
    n = curve([(4.28, 2.6), (6.0, 2.3), (6.6, 2.1), (Y_TOP, 2.0)], y)
    return w, d, zc, n


def _v_half(y):
    """Half the width of the coat's V over the shirt, at height y."""
    return 0.025 + 0.2 * max(0.0, (y - 5.92) / (Y_TOP - 5.92))


def _torso_push(a, p):
    y = p.y
    s = math.sin(a)
    back = max(0.0, s)
    front = max(0.0, -s)
    hunch = 0.075 * math.exp(-(((y - 6.25) / 0.3) ** 2)) * back**1.5
    blades = 0.018 * math.exp(-(((y - 6.15) / 0.18) ** 2)) * back * (math.exp(-(((abs(p.x) - 0.3) / 0.12) ** 2)))
    chest = 0.026 * math.exp(-(((y - 6.0) / 0.3) ** 2)) * front**2
    # Drag folds under the arms and creases round the waist.
    sides = max(0.0, abs(math.cos(a)) - 0.6) / 0.4
    drag = 0.008 * math.sin(y * 13 + a * 3) * sides * smoothstep(6.4, 5.6, y)
    rumple = 0.006 * noise(p, 7.0)
    return hunch + blades + chest + drag + rumple


def coat_torso():
    """The coat from the waist to the neck, the V over the shirt cut out
    (the shirt, the tie and the lapels are laid in it)."""
    ys = []
    y = 4.28
    while y < Y_TOP:
        ys.append(y)
        y += 0.1 if y < 6.3 else 0.05
    ys.append(Y_TOP)
    ys = list(reversed(ys))
    rings = []
    for y in ys:
        w, d, zc, n = _torso_shape(y)
        rings.append(ring(y, w, d, 56, z0=zc, n=n, push=_torso_push))
    obj = loft("CoatTorso", rings)
    _all_mats(obj)
    _set_mat(obj, WOOL)
    # Cut the V.
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    gone = []
    for f in bm.faces:
        c = f.calc_center_median()
        g = Vector((c.x, c.z, -c.y))
        w, d, zc, n = _torso_shape(g.y)
        if g.z < zc - 0.15 and g.y > 5.92 and abs(g.x) < _v_half(g.y):
            gone.append(f)
    bmesh.ops.delete(bm, geom=gone, context="FACES")
    bm.to_mesh(obj.data)
    bm.free()
    return obj


def _front_z(x, y, inset=0.0):
    """The coat's front surface z at (x, y) (its loft's front), moved back
    by inset."""
    w, d, zc, n = _torso_shape(y)
    u = max(-0.999, min(0.999, x / w))
    # superellipse: |x/w|^n + |z/d|^n = 1
    z = d * (1 - abs(u) ** n) ** (1.0 / n)
    a = math.atan2(-z, x)
    p = Vector((x, y, zc - z))
    push = _torso_push(a, p)
    return zc - z - push + inset


def shirt_and_tie():
    rows = []
    ys = [5.86 + i * 0.05 for i in range(int((Y_TOP + 0.02 - 5.86) / 0.05) + 1)]
    for y in ys:
        half = _v_half(y) + 0.05
        rows.append([Vector((x, y, _front_z(x, y, 0.028))) for x in (-half, -half / 2, 0.0, half / 2, half)])
    shirt = plate("Shirt", rows, normal_hint=(0, 0, -1))
    # The tie: from the knot down into the coat.
    rows = []
    for i in range(14):
        y = 5.86 + i * (6.82 - 5.86) / 13
        half = 0.036 - 0.012 * (y - 5.86) / (6.82 - 5.86)
        rows.append([Vector((x, y, _front_z(x, y, 0.02) - 0.004 * (1 - (x / half) ** 2))) for x in (-half, -half / 2, 0.0, half / 2, half)])
    tie = plate("Tie", rows, normal_hint=(0, 0, -1))
    knot = ellipsoid("Knot", (0, 6.86, _front_z(0, 6.86, 0.018)), (0.034, 0.04, 0.02), 6, 10)
    # The shirt's collar points either side of the knot.
    points = []
    for sx in (-1, 1):
        rows = [
            [Vector((sx * 0.03, 6.94, _front_z(sx * 0.03, 6.94, 0.016))), Vector((sx * 0.1, 6.95, _front_z(sx * 0.1, 6.95, 0.016)))],
            [Vector((sx * 0.045, 6.84, _front_z(sx * 0.045, 6.84, 0.012))), Vector((sx * 0.085, 6.8, _front_z(sx * 0.085, 6.8, 0.012)))],
        ]
        points.append(plate("CollarPoint", rows, normal_hint=(0, 0, -1)))
    for o in [shirt] + points:
        _all_mats(o)
        _set_mat(o, SHIRT)
    for o in (tie, knot):
        _all_mats(o)
        _set_mat(o, TIE)
    return [shirt, tie, knot] + points


def lapels():
    out = []
    for sx in (-1, 1):
        rows = []
        for i in range(16):
            y = 5.9 + i * (6.94 - 5.9) / 15
            inner = _v_half(y) - 0.02
            width = curve([(5.9, 0.04), (6.2, 0.09), (6.7, 0.12), (6.76, 0.07), (6.8, 0.11), (6.94, 0.08)], y)
            xs = [inner + width * k / 3 for k in range(4)]
            rows.append([Vector((sx * x, y, _front_z(sx * x, y, -0.012 - 0.004 * math.sin(k / 3 * math.pi)))) for k, x in enumerate(xs)])
        lapel = plate("Lapel", rows, normal_hint=(0, 0, -1))
        solidify(lapel, 0.012)
        _all_mats(lapel)
        _set_mat(lapel, WOOL)
        out.append(lapel)
    return out


def collar():
    """The collar turned up round his neck, open at the front."""
    rings = []
    for i in range(7):
        y = 6.84 + i * 0.065
        flare = i / 6
        rings.append(
            ring(
                y,
                0.25 + 0.05 * flare,
                0.23 + 0.04 * flare,
                30,
                z0=0.02,
                a0=math.radians(-60),
                a1=math.radians(240),
                closed=False,
                push=lambda a, p: 0.004 * noise(p, 9.0),
            )
        )
    obj = loft("Collar", rings, closed=False)
    solidify(obj, 0.026)
    _all_mats(obj)
    _set_mat(obj, WOOL)
    return obj


def buttons():
    out = []
    for i in range(3):
        y = RIG["waistY"] + 1.15 - (i + 1) * 0.42
        z = _front_z(-0.05, y, 0.0) - 0.006
        b = ellipsoid("Button", (-0.05, y, z), (0.034, 0.034, 0.012), 4, 12)
        out.append(b)
    # The half-belt across the back, with a button at each end.
    rows = []
    for k in range(9):
        x = -0.34 + 0.68 * k / 8
        rows.append([Vector((x, 4.7, _back_z(x, 4.7) + 0.012)), Vector((x, 4.8, _back_z(x, 4.8) + 0.012))])
    rows = [list(r) for r in zip(*rows)]
    belt = plate("Belt", rows, normal_hint=(0, 0, 1))
    solidify(belt, 0.01)
    _all_mats(belt)
    _set_mat(belt, WOOL)
    for sx in (-1, 1):
        out.append(ellipsoid("BeltButton", (sx * 0.3, 4.75, _back_z(sx * 0.3, 4.75) + 0.022), (0.026, 0.026, 0.01), 4, 10))
    for b in out:
        _all_mats(b)
        _set_mat(b, HORN)
    return out + [belt]


def _back_z(x, y):
    w, d, zc, n = _torso_shape(y)
    u = max(-0.999, min(0.999, x / w))
    z = d * (1 - abs(u) ** n) ** (1.0 / n)
    a = math.atan2(z, x)
    return zc + z + _torso_push(a, Vector((x, y, zc + z)))


def carnation():
    """A dead carnation in his left lapel, gone brown."""
    at = Vector((-0.16, 6.5, _front_z(-0.16, 6.5, -0.03)))

    def crumple(p):
        return p * (1 + 0.35 * noise(p, 60.0))

    flower = ellipsoid("Carnation", at, (0.045, 0.04, 0.035), 8, 14, warp=crumple)
    stem = tube("Stem", [at + Vector((0, -0.02, 0.01)), at + Vector((0.004, -0.07, 0.02)), at + Vector((0.006, -0.1, 0.024))], lambda t, i, a: 0.006, 6)
    _all_mats(flower)
    _set_mat(flower, FLOWER)
    _all_mats(stem)
    _set_mat(stem, FLOWER)
    return [flower, stem]


def _skirt_shape(y):
    hem = RIG["coatHem"]
    t = (4.36 - y) / (4.36 - hem)
    w = 0.6 + 0.12 * t * t
    d = 0.38 + 0.13 * t * t
    return w, d


def skirt_point(y, a, out=0.0):
    """A point on the skirt's surface at height y, angle a, `out` studs
    proud of it."""
    w, d = _skirt_shape(y)
    c, s = math.cos(a), math.sin(a)
    x = w * spow(c, 2.0 / 2.3)
    z = d * spow(s, 2.0 / 2.3)
    away = Vector((x / w, 0, z / d)).normalized()
    return Vector((x, y, 0.03 + z)) + away * out, away


def skirt(side):
    """One half of the coat's skirt, from the waist to below the knee: it
    follows his thigh a little (the coat tail's joint), overlapping the other
    half at the front and the back so it parts as he walks."""
    sx = -1 if side == "Left" else 1
    hem = RIG["coatHem"]
    if side == "Right":
        a0, a1 = math.radians(-100), math.radians(98)
    else:
        a0, a1 = math.radians(82), math.radians(280)
    count = 30
    rings = []
    ys = [4.36 - i * (4.36 - hem) / 26 for i in range(27)]
    for y in ys:
        w, d = _skirt_shape(y)
        t = (4.36 - y) / (4.36 - hem)

        def push(a, p, t=t, y=y):
            deg = math.degrees(a) % 360
            over = 0.0
            if side == "Left" and 250 <= deg <= 285:
                over = 0.014  # the left half over the right at the front
            if side == "Right" and 80 <= deg <= 100:
                over = 0.014  # the right over the left at the vent
            folds = (0.55 * math.sin(7 * a + 0.5) + 0.3 * math.sin(13 * a + 1.7) + 0.15 * math.sin(23 * a + 0.3)) * 0.05 * smoothstep(0.0, 1.0, t)
            return over + folds + 0.005 * noise(p, 6.0)

        pts = ring(y, w, d, count, z0=0.03, n=2.3, a0=a0, a1=a1, closed=False, push=push)
        # A ragged-ish hem: a little up and down round it.
        if y == ys[-1]:
            pts = [p + Vector((0, 0.03 * noise(p, 5.0), 0)) for p in pts]
        rings.append(pts)
    obj = loft(side + "Skirt", rings, closed=False)
    solidify(obj, 0.022)
    _all_mats(obj)
    _set_mat(obj, WOOL)
    # A pocket flap at the hip.
    rows = []
    for k in range(5):
        a = math.radians(-50 if side == "Right" else 230) + (k - 2) * 0.09
        top, _ = skirt_point(4.12, a, 0.03)
        bottom, _ = skirt_point(4.0, a, 0.036)
        rows.append([top, bottom])
    rows = [list(r) for r in zip(*rows)]
    flap = plate("Pocket", rows, normal_hint=(sx * 0.6, 0, -0.8))
    solidify(flap, 0.01)
    _all_mats(flap)
    _set_mat(flap, WOOL)
    return join([obj, flap], side + "Skirt")


def tatters(side):
    """Rags hanging from the hem, shown from Breaking (GuestController)."""
    hem = RIG["coatHem"]
    sx = -1 if side == "Left" else 1
    pieces = []
    for i in range(8):
        a = math.radians((-80 + i * 22) if side == "Right" else (100 + i * 22))
        length = 0.45 + ((i * 37 + (11 if sx > 0 else 0)) % 9) / 9 * 0.8
        width = 0.08 + (i % 3) * 0.035
        base, out = skirt_point(hem + 0.06, a)
        across = Vector((-out.z, 0, out.x))
        rows = []
        steps = 8
        for k in range(steps + 1):
            t = k / steps
            twist = 0.25 * math.sin(i + t * 2.5)
            dir_ = (across * math.cos(twist) + out * math.sin(twist))
            centre_ = base + Vector((0, -length * t, 0)) + out * (0.02 + 0.05 * t * t)
            half = width / 2 * (1 - 0.6 * t) * (1 + 0.3 * noise(centre_, 20.0))
            rows.append([centre_ - dir_ * half, centre_ + dir_ * half])
        rag = plate("Tatter", rows, normal_hint=(out.x, 0, out.z))
        pieces.append(rag)
    obj = join(pieces, side + "Tatters")
    solidify(obj, 0.012)
    _all_mats(obj)
    _set_mat(obj, WOOL)
    return obj


# Arms -----------------------------------------------------------------------------


def _sleeve_radius(y):
    return curve([(6.52, 0.165), (6.2, 0.16), (5.5, 0.15), (4.9, 0.145), (4.66, 0.145), (4.2, 0.136), (3.6, 0.128), (3.3, 0.13), (3.28, 0.143), (3.15, 0.143)], y)


SLEEVE_END = 3.15
SLEEVE_HEAD = 6.52  # where the sleeve's rounded head starts


def sleeve(side, upper):
    """The sleeve, cut at the elbow: upper (its rounded head over the
    shoulder, down to the elbow) or lower (elbow to the cuff, which stops
    short of the wrist)."""
    sx = -1 if side == "Left" else 1
    x0 = sx * RIG["shoulderX"]
    elbow = RIG["shoulderY"] - RIG["upperArm"]
    ys = []
    y = SLEEVE_HEAD if upper else elbow
    stop = elbow if upper else SLEEVE_END
    while y > stop + 1e-6:
        ys.append(y)
        y -= 0.07
    ys.append(stop)

    def push(a, p):
        y = p.y
        front = max(0.0, -math.sin(a))
        crease = 0.012 * math.sin((y - elbow) * 40) * math.exp(-(((y - elbow) / 0.18) ** 2)) * front
        bunch = 0.009 * math.sin(y * 34) * smoothstep(3.9, 3.4, y) * smoothstep(3.25, 3.35, y)
        back = max(0.0, math.sin(a))
        point = 0.02 * math.exp(-(((y - elbow) / 0.12) ** 2)) * back**2  # the elbow, poking the cloth
        twist = 0.006 * math.sin(3 * a + y * 5.0) * smoothstep(6.4, 5.8, y)
        return crease + bunch + point + twist + 0.004 * noise(p, 8.0)

    def axis_x(y):
        return x0 - sx * 0.07 * smoothstep(elbow, SLEEVE_HEAD, y)

    rings = []
    if upper:
        # The head of the sleeve: a low dome over the top of the arm, the
        # coat's shoulder sloping down to it.
        r0 = _sleeve_radius(SLEEVE_HEAD)
        for k in range(6, 0, -1):
            a = math.pi / 2 * k / 6
            yy = SLEEVE_HEAD + 0.09 * math.sin(a)
            rr = max(r0 * math.cos(a), 1e-4)
            rings.append(ring(yy, rr, rr * 1.06, 22, x0=axis_x(SLEEVE_HEAD)))
    rings += [ring(y, _sleeve_radius(y), _sleeve_radius(y) * 1.06, 22, x0=axis_x(y), push=push) for y in ys]
    obj = loft(side + ("UpperSleeve" if upper else "LowerSleeve"), rings, axis=lambda g: Vector((axis_x(g.y), g.y, 0)))
    if upper:
        bm = bmesh.new()
        bm.from_mesh(obj.data)
        bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-4)
        bm.to_mesh(obj.data)
        bm.free()
    solidify(obj, 0.018)
    _all_mats(obj)
    _set_mat(obj, WOOL)
    return obj


def wrist(side):
    """The thin bony wrist between the short cuff and the hand, the knob of
    the bone on the little finger's side."""
    sx = -1 if side == "Left" else 1
    x0 = sx * RIG["shoulderX"]
    w = joint(side + "Hand").y
    ys = [3.32 - i * (3.32 - (w - 0.08)) / 12 for i in range(13)]

    def push(a, p):
        knob = 0.018 * math.exp(-(((p.y - (w + 0.06)) / 0.035) ** 2)) * max(0.0, math.sin(a)) ** 2
        tendon = 0.004 * max(0.0, -math.cos(a) * sx) * smoothstep(3.1, w, p.y)
        return knob + tendon

    rings = [ring(y, 0.072 - 0.008 * smoothstep(3.2, w, y), 0.068, 14, x0=x0, push=push) for y in ys]
    obj = loft(side + "Wrist", rings, axis=lambda g: Vector((x0, g.y, 0)))
    _all_mats(obj)
    _set_mat(obj, SKIN)
    return obj


def hand(side):
    """A long narrow bony hand: a flat palm turned to his side, four long
    fingers in a row and the thumb in front, knuckles and long yellowed
    nails (Lib/GuestFace laid out the old one)."""
    sx = -1 if side == "Left" else 1
    inward = 1 if side == "Left" else -1
    hc = centre(side + "Hand")
    wrist_y = joint(side + "Hand").y
    knuckle_y = hc.y - RIG["hand"] / 2 + 0.04
    pieces = []
    # The palm: thin across (x), wide front to back (z), the back of the hand
    # rounded outward with a ridge to each finger.
    rows = []
    ys = [wrist_y + 0.04 - i * (wrist_y + 0.04 - (knuckle_y - 0.01)) / 12 for i in range(13)]
    for y in ys:
        t = (wrist_y + 0.04 - y) / (wrist_y + 0.04 - knuckle_y)
        half_z = 0.08 + 0.032 * smoothstep(0.0, 0.7, t)
        half_x = 0.04 + 0.004 * smoothstep(0.2, 0.9, t)

        def push(a, p, t=t):
            out = -inward * math.cos(a)  # the back of the hand, away from his side
            ridges = 0.0
            if out > 0.3:
                for z in (-0.075, -0.025, 0.025, 0.072):
                    ridges += 0.006 * math.exp(-(((p.z - z) / 0.012) ** 2)) * smoothstep(0.3, 1.0, t)
            knuckles = 0.0
            for z in (-0.075, -0.025, 0.025, 0.072):
                knuckles += 0.014 * math.exp(-(((p.z - z) / 0.02) ** 2)) * math.exp(-(((t - 1.0) / 0.12) ** 2)) * max(0.0, out)
            return ridges + knuckles + 0.003 * noise(p, 30.0)

        rows.append(ring(y, half_x, half_z, 20, x0=hc.x + inward * 0.004, z0=0.0, n=2.4, push=push))
    palm = loft(side + "Palm", rows, axis=lambda g: Vector((hc.x, g.y, 0)))
    # Close the bottom between the knuckles.
    bm = bmesh.new()
    bm.from_mesh(palm.data)
    bm.verts.ensure_lookup_table()
    edges = [e for e in bm.edges if e.is_boundary and all(v.co.z < knuckle_y + 0.001 for v in e.verts)]
    if edges:
        bmesh.ops.holes_fill(bm, edges=edges, sides=0)
    bm.to_mesh(palm.data)
    bm.free()
    weigh(palm, palm_weights(side))
    pieces.append(palm)
    for name, knuckle, middle, tip, tilt, scale in finger_layout(side):
        down = (middle - knuckle).normalized()
        n1 = 6
        n2 = 7
        path = [knuckle - down * 0.03]
        for i in range(1, n1 + 1):
            path.append(knuckle + (middle - knuckle) * (i / n1))
        for i in range(1, n2 + 1):
            path.append(middle + (tip - middle) * (i / n2))
        l1 = (middle - knuckle).length
        total = l1 + (tip - middle).length

        def radius(t, i, a, l1=l1, total=total, thumb=(name == "Thumb")):
            s = t * (total + 0.03) - 0.03
            r = 0.033 - 0.01 * (s / total)
            if thumb:
                r += 0.004
            # Knuckle bulges at each joint and a slimmer distal joint.
            r += 0.016 * math.exp(-((s / 0.025) ** 2))
            r += 0.013 * math.exp(-(((s - l1) / 0.022) ** 2))
            r += 0.006 * math.exp(-(((s - (l1 + (total - l1) * 0.55)) / 0.02) ** 2))
            return r

        finger = tube(side + name, path, radius, 10)
        weigh(finger, finger_weights(side, name))
        pieces.append(finger)
        # The nail: on the back of the fingertip, long, curling a little
        # toward the palm, yellowed.
        back = Vector((-inward, 0, 0))
        if name == "Thumb":
            back = (tilt @ Vector((-inward, 0, 0))).normalized()
        side_v = down.cross(back).normalized()
        rows = []
        for k in range(5):
            t = k / 4
            along = tip - down * 0.05 + down * (0.05 + 0.045) * t
            curl = -back * 0.012 * t * t
            half = 0.017 * (1 - 0.65 * t * t)
            lift = back * (0.022 - 0.004 * t)
            rows.append([along + lift + curl - side_v * half, along + lift + curl + back * 0.002, along + lift + curl + side_v * half])
        nail = plate(side + name + "Nail", rows, normal_hint=back)
        solidify(nail, 0.005)
        _all_mats(nail)
        _set_mat(nail, NAIL)
        weigh(nail, finger_weights(side, name))
        pieces.append(nail)
    for o in pieces:
        if not o.name.endswith("Nail") and "Nail" not in o.name:
            _all_mats(o)
            _set_mat(o, SKIN)
    obj = join(pieces, side + "Hand")
    return obj


# Legs ------------------------------------------------------------------------------


def trousers(side, upper):
    sx = -1 if side == "Left" else 1
    x0 = sx * RIG["hipX"]
    knee = RIG["hipY"] - RIG["upperLeg"]
    ankle = knee - RIG["lowerLeg"]
    y = 4.32 if upper else knee
    stop = knee if upper else ankle + 0.06
    ys = []
    while y > stop + 1e-6:
        ys.append(y)
        y -= 0.1
    ys.append(stop)

    def r(y):
        return curve([(4.32, 0.22), (3.5, 0.2), (2.6, 0.182), (2.2, 0.18), (1.6, 0.162), (0.8, 0.15), (0.4, 0.152), (ankle + 0.06, 0.162)], y)

    def push(a, p):
        crease = 0.006 * math.exp(-(((math.degrees(a) % 360 - 270) / 8) ** 2))  # the pressed crease down the front
        kneebag = 0.012 * math.exp(-(((p.y - knee) / 0.2) ** 2)) * max(0.0, -math.sin(a))
        break_ = 0.01 * math.sin(p.y * 30) * smoothstep(0.75, 0.4, p.y)
        return crease + kneebag + break_ + 0.004 * noise(p, 7.0)

    rings = [ring(y, r(y), r(y) * 1.05, 16, x0=x0, push=push) for y in ys]
    obj = loft(side + ("Thigh" if upper else "Shin"), rings, axis=lambda g: Vector((x0, g.y, 0)))
    solidify(obj, 0.016)
    _all_mats(obj)
    _set_mat(obj, TROUSER)
    return obj


def shoe(side):
    """An old dress shoe: a long rounded toe, a squared heel, the leather
    creased and cracked across the vamp."""
    sx = -1 if side == "Left" else 1
    x0 = sx * RIG["hipX"]
    ankle_y = RIG["hipY"] - RIG["upperLeg"] - RIG["lowerLeg"]
    sections = [
        # z (from the ankle, - toward the toe), half width, top height, bottom
        (0.2, 0.12, 0.3, 0.0),
        (0.14, 0.145, 0.33, 0.0),
        (0.02, 0.155, 0.31, 0.0),
        (-0.12, 0.165, 0.26, 0.02),
        (-0.3, 0.172, 0.21, 0.02),
        (-0.46, 0.168, 0.17, 0.0),
        (-0.6, 0.14, 0.14, 0.0),
        (-0.7, 0.105, 0.12, 0.0),
        (-0.77, 0.06, 0.1, 0.0),
        (-0.8, 0.02, 0.085, 0.01),
    ]
    rings = []
    for z, half, top, bottom in sections:
        pts = []
        for k in range(18):
            a = TAU * k / 18
            c, s = math.cos(a), math.sin(a)
            x = half * spow(c, 2 / 2.6)
            yy = (top + bottom) / 2 + (top - bottom) / 2 * spow(s, 2 / 3.0)
            yy = max(yy, 0.0)
            crease = 0.006 * math.sin(z * 60) * max(0.0, s) * smoothstep(-0.05, -0.2, z) * smoothstep(-0.55, -0.4, z)
            pts.append(Vector((x0 + x, yy + crease, z)))
        rings.append(pts)
    obj = loft(side + "Shoe", rings, axis=lambda g: Vector((x0, 0.16, g.z)))
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    edges = [e for e in bm.edges if e.is_boundary]
    bmesh.ops.holes_fill(bm, edges=edges, sides=0)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(obj.data)
    bm.free()
    # The ankle sits in the shoe's throat: nothing to see, the trousers break
    # over it.
    _all_mats(obj)
    _set_mat(obj, LEATHER)
    del ankle_y
    return obj


# The head ---------------------------------------------------------------------------


def head():
    """The black head under the mask, like a stocking pulled over a skull,
    on a long thin neck that disappears into the collar."""
    hy = RIG["headY"]
    hx, hh, hz = RIG["headSize"][0] / 2, RIG["headSize"][1] / 2, RIG["headSize"][2] / 2
    bottom = hy - hh
    rings = []
    ys = [6.78 + i * 0.06 for i in range(int((bottom + 0.06 - 6.78) / 0.06))]
    for y in ys:
        rings.append(ring(y, 0.13, 0.135, 20, z0=0.0))
    n = 18
    for i in range(1, n):
        phi = -math.pi / 2 + math.pi * i / n
        y = hy + hh * math.sin(phi)
        w = hx * math.cos(phi)
        d = hz * math.cos(phi)

        def push(a, p, phi=phi):
            back = max(0.0, math.sin(a))
            occiput = 0.03 * back**2 * math.exp(-(((phi + 0.1) / 0.5) ** 2))
            jaw = -0.03 * max(0.0, -math.sin(phi)) * (1 - back)
            return occiput + jaw

        if y > ys[-1] + 0.03:
            rings.append(ring(y, max(w, 0.13), max(d, 0.135), 20, z0=0.0, push=push))
    rings.append([Vector((0, hy + hh, 0))] * 20)
    rings = list(reversed(rings))
    obj = loft("Head", rings)
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
    bm.to_mesh(obj.data)
    bm.free()
    _all_mats(obj)
    _set_mat(obj, HOOD)
    return obj


# Weights -------------------------------------------------------------------------------


def torso_weights(p):
    w = chain(p.y, [("gUpperTorso", 99, RIG["waistY"], 0.18), ("gLowerTorso", RIG["waistY"], -99, 0.18)])
    # The shoulders go some way with the arms.
    side = "Left" if p.x < 0 else "Right"
    share = smoothstep(0.5, 0.85, abs(p.x)) * smoothstep(6.1, 6.55, p.y) * 0.85
    if share > 0:
        for k in w:
            w[k] *= 1 - share
        w["g%sUpperArm" % side] = share
    return w


def skirt_weights(side):
    def f(p):
        share = smoothstep(4.3, 3.7, p.y)
        return {"gLowerTorso": 1 - share, "g%sCoatTail" % side: share}

    return f


def arm_weights(side):
    s = side
    elbow = RIG["shoulderY"] - RIG["upperArm"]
    wrist_y = elbow - RIG["lowerArm"]

    def f(p):
        w = chain(
            p.y,
            [
                ("gUpperTorso", 99, 6.72, 0.16),
                ("g%sUpperArm" % s, 6.72, elbow, 0.14),
                ("g%sLowerArm" % s, elbow, wrist_y, 0.05),
                ("g%sHand" % s, wrist_y, -99, 0.05),
            ],
        )
        return w

    return f


def leg_weights(side):
    s = side
    knee = RIG["hipY"] - RIG["upperLeg"]
    ankle = knee - RIG["lowerLeg"]

    def f(p):
        return chain(
            p.y,
            [
                ("gLowerTorso", 99, RIG["hipY"], 0.12),
                ("g%sUpperLeg" % s, RIG["hipY"], knee, 0.14),
                ("g%sLowerLeg" % s, knee, ankle + 0.02, 0.05),
                ("g%sFoot" % s, ankle + 0.02, -99, 0.05),
            ],
        )

    return f


def head_weights(p):
    k = max(0.0, min(1.0, (p.y - 6.92) / (7.42 - 6.92)))
    return {"gHead": k, "gUpperTorso": 1 - k}


def palm_weights(side):
    hand_bone = "g%sHand" % side
    lower = "g%sLowerArm" % side
    wrist_y = joint(side + "Hand").y

    def f(p):
        arm = smoothstep(wrist_y - 0.05, wrist_y + 0.05, p.y)
        return {hand_bone: 1 - arm, lower: arm}

    return f


def finger_weights(side, finger):
    """One finger's weights: the palm's bone where it leaves the hand, then
    down the knuckle bone and its stretch bone (the first segment stretches
    evenly when the fingers grow, GuestController), the middle joint, and
    the tip's stretch bone."""
    s = side[0]
    for name, knuckle, middle, tip, tilt, scale in finger_layout(side):
        if name == finger:
            break
    axis = (middle - knuckle).normalized()
    l1 = (middle - knuckle).length
    l2 = (tip - middle).length
    hand_bone = "g%sHand" % side
    k1, e1, m2, t3 = ("g%s%s%s" % (s, finger, x) for x in ("1", "1e", "2", "3"))

    def f(p):
        s_along = (p - knuckle).dot(axis)
        w = {}
        palm_share = smoothstep(0.015, -0.03, s_along)
        if palm_share > 0:
            w[hand_bone] = palm_share
        rest = 1 - palm_share
        if rest <= 0:
            return w
        joint_blend = smoothstep(l1 - 0.025, l1 + 0.025, s_along)
        if s_along <= l1:
            u = max(0.0, min(1.0, s_along / l1))
            w[k1] = rest * (1 - u) * (1 - joint_blend)
            w[e1] = rest * u * (1 - joint_blend)
            w[m2] = rest * joint_blend
        else:
            v = max(0.0, min(1.0, (s_along - l1) / l2))
            w[e1] = rest * (1 - joint_blend)
            w[m2] = rest * joint_blend * (1 - v)
            w[t3] = rest * joint_blend * v
        return w

    return f


# Building it all ------------------------------------------------------------------------


def pieces():
    """[(object, part it rides on)] for the body (not the mask), each
    weighed: each becomes one MeshPart (Data/Kit's Guest group)."""
    out = []

    def add(obj, fn, part):
        if fn:
            weigh(obj, fn)
        obj.name = "Guest" + obj.name if not obj.name.startswith("Guest") else obj.name
        obj.data.name = obj.name
        shade(obj, 60)
        out.append((obj, part))

    torso = join([coat_torso(), collar()] + shirt_and_tie() + lapels() + buttons() + carnation(), "GuestTorso")
    add(torso, torso_weights, "UpperTorso")
    for side in ("Left", "Right"):
        add(skirt(side), skirt_weights(side), side + "CoatTail")
        add(tatters(side), skirt_weights(side), side + "CoatTail")
        add(sleeve(side, True), arm_weights(side), side + "UpperArm")
        add(join([sleeve(side, False), wrist(side)], side + "LowerSleeve"), arm_weights(side), side + "LowerArm")
        add(hand(side), None, side + "Hand")  # (weighed finger by finger)
        add(trousers(side, True), leg_weights(side), side + "UpperLeg")
        add(join([trousers(side, False), shoe(side)], side + "Shin"), leg_weights(side), side + "LowerLeg")
    add(head(), head_weights, "Head")
    return out
