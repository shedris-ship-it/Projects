"""Shapes for the kit, built with bmesh so they're exact and repeatable.

Every function returns a new mesh object linked to the scene. Sizes are in
studs. Objects are made around their own origin; place them with location.
"""

import math

import bmesh
import bpy
from mathutils import Matrix, Vector


def _object(name, bm):
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    return obj


def select_only(obj):
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj


def bevel(obj, width, segments=3, angle=40):
    """Rounds every edge sharper than angle (degrees): the single biggest
    difference between a box and a piece of furniture."""
    mod = obj.modifiers.new("Bevel", "BEVEL")
    mod.width = width
    mod.segments = segments
    mod.limit_method = "ANGLE"
    mod.angle_limit = math.radians(angle)
    mod.harden_normals = True
    select_only(obj)
    bpy.ops.object.modifier_apply(modifier=mod.name)
    return obj


def smooth(obj, angle=35):
    """Smooth shading, keeping edges sharper than angle crisp."""
    select_only(obj)
    try:
        bpy.ops.object.shade_smooth_by_angle(angle=math.radians(angle))
    except AttributeError:
        bpy.ops.object.shade_smooth()
    return obj


def box(name, size, location=(0, 0, 0), bevel_width=0.04, segments=3):
    """A box size = (x, y, z) studs, centred on location, its edges rounded."""
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.scale(bm, vec=Vector(size), verts=bm.verts)
    bmesh.ops.translate(bm, vec=Vector(location), verts=bm.verts)
    obj = _object(name, bm)
    if bevel_width > 0:
        bevel(obj, bevel_width, segments)
    return smooth(obj)


def lathe(name, profile, location=(0, 0, 0), steps=32):
    """Turned wood or spun metal: profile is [(radius, z), ...] from the
    bottom up, spun round the Z axis. A radius of 0 closes that end."""
    bm = bmesh.new()
    verts = [bm.verts.new((max(r, 0.0), 0.0, z)) for r, z in profile]
    edges = [bm.edges.new((verts[i], verts[i + 1])) for i in range(len(verts) - 1)]
    bmesh.ops.spin(
        bm,
        geom=verts + edges,
        cent=(0, 0, 0),
        axis=(0, 0, 1),
        angle=math.tau,
        steps=steps,
        use_merge=True,
    )
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bmesh.ops.translate(bm, vec=Vector(location), verts=bm.verts)
    return smooth(_object(name, bm), 50)


def turned_leg(name, height, radius, location=(0, 0, 0)):
    """A 1980s colonial chair or table leg: a square-ish top, a vase, rings,
    a taper to a small foot. Built as a lathe."""
    r = radius
    h = height
    profile = [
        (0.0, 0.0),
        (r * 0.62, 0.0),
        (r * 0.7, h * 0.03),
        (r * 0.55, h * 0.12),
        (r * 0.62, h * 0.35),
        (r * 0.9, h * 0.52),
        (r * 0.7, h * 0.6),
        (r * 1.0, h * 0.64),
        (r * 1.0, h * 0.67),
        (r * 0.75, h * 0.7),
        (r * 1.05, h * 0.74),
        (r * 1.05, h * 1.0),
        (0.0, h * 1.0),
    ]
    return lathe(name, profile, location, steps=24)


def panel_slab(name, width, height, thickness, panels, frame=0.28, raise_depth=0.05, location=(0, 0, 0)):
    """A door slab with raised panels on both faces. panels is a list of
    (x, z, w, h) rectangles in slab coordinates (centre origin, X across,
    Z up). Each panel is inset with a bevelled field, like a moulded door."""
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.scale(bm, vec=Vector((width, thickness, height)), verts=bm.verts)
    obj = _object(name, bm)
    bevel(obj, 0.03, 2)
    parts = [obj]
    for side in (-1, 1):
        for px, pz, pw, ph in panels:
            # The raised field: a thin bevelled slab standing proud of the face.
            field = box(
                name + "_field",
                (pw - frame * 0.5, raise_depth * 2, ph - frame * 0.5),
                (px, side * (thickness / 2), pz),
                bevel_width=raise_depth * 0.9,
                segments=3,
            )
            # The moulding round it: four strips with a rounded profile.
            for (mx, mz, mw, mh) in (
                (px, pz + ph / 2, pw, frame * 0.35),
                (px, pz - ph / 2, pw, frame * 0.35),
                (px - pw / 2, pz, frame * 0.35, ph),
                (px + pw / 2, pz, frame * 0.35, ph),
            ):
                strip = box(name + "_mould", (mw, raise_depth * 1.4, mh), (mx, side * (thickness / 2), mz), 0.03, 2)
                parts.append(strip)
            parts.append(field)
    joined = join(parts, name)
    joined.location = Vector(location)
    return joined


def subdivide(obj, levels=2):
    """Smooths a cage into soft curves (cushions, rolled arms)."""
    mod = obj.modifiers.new("Subsurf", "SUBSURF")
    mod.levels = levels
    mod.render_levels = levels
    select_only(obj)
    bpy.ops.object.modifier_apply(modifier=mod.name)
    return obj


def cushion(name, size, location=(0, 0, 0), puff=0.12, levels=2, roundness=0.35):
    """An upholstered cushion: a rounded box that bulges in the middle of its
    top and front, as a stuffed one does. size = (x, y, z) studs."""
    sx, sy, sz = size
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.scale(bm, vec=Vector(size), verts=bm.verts)
    obj = _object(name, bm)
    bevel(obj, min(sx, sy, sz) * roundness * 0.5, 2, angle=30)
    subdivide(obj, levels)
    # Bulge: the top rises in the middle; the faces bow outwards a little.
    for v in obj.data.vertices:
        x, y, z = v.co
        u = max(0.0, 1 - (2 * x / sx) ** 2)
        w = max(0.0, 1 - (2 * y / sy) ** 2)
        h = max(0.0, 1 - (2 * z / sz) ** 2)
        if z > 0:
            v.co.z += puff * u * w * (z / (sz / 2))
        v.co.x *= 1 + 0.04 * w * h
        v.co.y *= 1 + 0.04 * u * h
    obj.location = Vector(location)
    return smooth(obj, 60)


def roll(name, length, radius, location=(0, 0, 0), axis="Y", steps=20):
    """A rolled sofa arm or bolster: a cylinder with rounded ends."""
    bm = bmesh.new()
    bmesh.ops.create_cone(
        bm, cap_ends=True, cap_tris=False, segments=steps, radius1=radius, radius2=radius, depth=length
    )
    obj = _object(name, bm)
    bevel(obj, radius * 0.35, 3, angle=30)
    if axis == "Y":
        obj.rotation_euler = (math.radians(90), 0, 0)
    elif axis == "X":
        obj.rotation_euler = (0, math.radians(90), 0)
    apply_transform(obj)
    obj.location = Vector(location)
    return smooth(obj, 60)


def turn(obj, degrees=(0, 0, 0), at=(0, 0, 0)):
    """Turns a piece built round the origin (make it at (0, 0, 0) first),
    then puts it at `at`. Turning a piece already moved would swing it round
    the world's origin instead of its own middle."""
    obj.rotation_euler = tuple(math.radians(d) for d in degrees)
    apply_transform(obj)
    obj.location = Vector(at)
    return obj


def cull(obj, directions, threshold=0.9):
    """Deletes the faces turned toward any of directions (unit (x, y, z)):
    the sides of a piece nobody can see, so they take no triangles and no
    room on its texture (a book's back against the case, its bottom on the
    shelf)."""
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    dirs = [Vector(d) for d in directions]
    doomed = [f for f in bm.faces if any(f.normal.dot(d) > threshold for d in dirs)]
    bmesh.ops.delete(bm, geom=doomed, context="FACES")
    bm.to_mesh(obj.data)
    bm.free()
    obj.data.update()
    return obj


def colour(obj, rgb):
    """Gives every vertex of obj a colour (0-1 linear) in the "Col" attribute,
    for materials that read it (one material for many coloured books)."""
    mesh = obj.data
    attr = mesh.color_attributes.get("Col") or mesh.color_attributes.new("Col", "FLOAT_COLOR", "POINT")
    for item in attr.data:
        item.color = (rgb[0], rgb[1], rgb[2], 1.0)
    return obj


def join(objects, name):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objects:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objects[0]
    bpy.ops.object.join()
    obj = bpy.context.view_layer.objects.active
    obj.name = name
    obj.data.name = name
    return obj


def apply_transform(obj):
    select_only(obj)
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    return obj


def triangles(obj):
    return sum(len(p.vertices) - 2 for p in obj.data.polygons)


def bounds(obj):
    """(min, max) of the object's mesh in world space."""
    corners = [obj.matrix_world @ Vector(c) for c in obj.bound_box]
    lo = Vector((min(c.x for c in corners), min(c.y for c in corners), min(c.z for c in corners)))
    hi = Vector((max(c.x for c in corners), max(c.y for c in corners), max(c.z for c in corners)))
    return lo, hi


def rotate(obj, degrees, axis="Z"):
    obj.rotation_euler.rotate_axis(axis, math.radians(degrees))
    return obj


__all__ = [
    "box",
    "lathe",
    "turned_leg",
    "panel_slab",
    "join",
    "bevel",
    "smooth",
    "select_only",
    "apply_transform",
    "triangles",
    "bounds",
    "rotate",
    "Matrix",
]
