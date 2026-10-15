"""What Roblox will show of each outfit (V6): Roblox draws a face from the
front only, so an inside face that can be seen is a hole. Blender's renders
draw both sides and hide it (2026-10-15: every right-side piece came through
inside out, and only Studio showed it).

Run from the repository root (Blender 5.2, headless):

    blender.exe -b --factory-startup -P tools/blender/wardrobe_visibility.py

Builds every garment (kitlib/wardrobe), dresses both measured bodies in every
outfit (as the game stretches them), and looks at each from all round, from
level to overhead and a little from below: parallel rays from many
directions; the first thing each ray meets is what you'd see. A garment's
face met from behind counts against its piece. Prints each piece's count
(want 0) and where the worst ones are (in the part's frame).
"""

import math
import os
import sys

import bpy
from mathutils import Vector
from mathutils.bvhtree import BVHTree

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

from kitlib import wardrobe  # noqa: E402

# Squad looks (Data/Wardrobe Outfits): (top, bottom, shoes).
OUTFITS = [
    ("Flannel", "Jeans", "Sneaker"),
    ("Varsity", "Jeans", "Sneaker"),
    ("Windbreaker", "Cords", "Sneaker"),
    ("Cardigan", "Cords", "Loafer"),
]
DIRECTIONS = 96
KINDS = {}  # piece -> the kind of face met from behind (outer, lining, rim) -> count
GRID = 70


def side_of(name, part):
    if part in wardrobe.LIMBS:
        return "R" if name.endswith("R") else "L"
    return "C"


def place(obj, name, body):
    part = obj["part"]
    s = wardrobe.scale_of(body, part)
    at = wardrobe.place_of(body, part, side_of(name, part))
    obj.scale = (s.x, s.z, s.y)
    obj.location = wardrobe.G(at.x, at.y, at.z)


def directions(n):
    """Spread over the sphere (golden spiral), down to 30 degrees below level."""
    out = []
    golden = math.pi * (3 - math.sqrt(5))
    for i in range(n * 2):
        z = 1 - (i + 0.5) / (n * 2) * 2
        if z < -0.5:
            continue
        r = math.sqrt(max(0.0, 1 - z * z))
        a = golden * i
        out.append(Vector((math.cos(a) * r, math.sin(a) * r, z)))
    return out


def tree_of(objs):
    """One BVH over the objects in world space; each face's owner and normal."""
    deps = bpy.context.evaluated_depsgraph_get()
    verts, polys, owner, normals, mats = [], [], [], [], []
    for obj in objs:
        ev = obj.evaluated_get(deps)
        me = ev.to_mesh()
        mw = obj.matrix_world
        nm = mw.to_3x3().inverted().transposed()
        base = len(verts)
        verts += [mw @ v.co for v in me.vertices]
        for p in me.polygons:
            polys.append([base + i for i in p.vertices])
            owner.append(obj)
            normals.append((nm @ p.normal).normalized())
            m = obj.material_slots[p.material_index].material if obj.material_slots else None
            mats.append("lining" if m and m.name.endswith("Lining") else ("rim" if not p.use_smooth else "outer"))
        ev.to_mesh_clear()
    return BVHTree.FromPolygons(verts, polys), owner, normals, mats


def look(objs, garment_objs):
    tree, owner, normals, mats = tree_of(objs)
    pts = [obj.matrix_world @ v.co for obj in objs for v in obj.data.vertices]
    mid = sum(pts, Vector()) / len(pts)
    radius = max((p - mid).length for p in pts) * 1.05
    bad = {o.name: [] for o in garment_objs}
    seen = {o.name: 0 for o in garment_objs}
    for d in directions(DIRECTIONS):
        d = -d  # rays travel toward the body
        up = Vector((0, 0, 1)) if abs(d.z) < 0.9 else Vector((1, 0, 0))
        u = d.cross(up).normalized()
        v = d.cross(u).normalized()
        for i in range(GRID):
            for j in range(GRID):
                a = (i + 0.5) / GRID * 2 - 1
                b = (j + 0.5) / GRID * 2 - 1
                origin = mid - d * radius * 2 + u * a * radius + v * b * radius
                hit, normal, index, dist = tree.ray_cast(origin, d, radius * 4)
                if hit is None:
                    continue
                obj = owner[index]
                if obj.name not in seen:
                    continue
                seen[obj.name] += 1
                if normals[index].dot(d) > 0:
                    bad[obj.name].append(obj.matrix_world.inverted() @ hit)
                    KINDS[obj.name[:-1]] = KINDS.get(obj.name[:-1], {})
                    KINDS[obj.name[:-1]][mats[index]] = KINDS[obj.name[:-1]].get(mats[index], 0) + 1
    return seen, bad


def main():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete()
    garments, built, log = wardrobe.wardrobe()
    for obj in built.values():
        obj.hide_render = True
        if "--bare" not in sys.argv:
            wardrobe.line(obj)
    lines = []
    totals = {}
    for body in wardrobe.BODY_NAMES:
        for top, bottom, shoes in OUTFITS:
            body_objs = wardrobe._proxy(body)
            dressed = []
            for garment in (top, bottom, shoes):
                for name, obj in built.items():
                    if name.startswith(garment):
                        copy = obj.copy()
                        copy.data = obj.data
                        copy.name = name + "@"
                        bpy.context.scene.collection.objects.link(copy)
                        place(copy, name, body)
                        dressed.append(copy)
            bpy.context.view_layer.update()
            seen, bad = look(body_objs + dressed, dressed)
            for obj in dressed:
                key = obj.name[:-1]
                n = len(bad[obj.name])
                t = totals.setdefault(key, [0, 0, []])
                t[0] += n
                t[1] += seen[obj.name]
                t[2] += bad[obj.name]
                if n:
                    lines.append("  %s %s/%s %s: %d of %d seen from behind" % (body, top, bottom, key, n, seen[obj.name]))
            for obj in body_objs + dressed:
                bpy.data.objects.remove(obj, do_unlink=True)
    print("VISIBILITY")
    for key in sorted(totals):
        n, s, pts = totals[key]
        where = ""
        if pts:
            c = sum(pts, Vector()) / len(pts)
            lo = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
            hi = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
            where = "  at (%.2f %.2f %.2f) box (%.2f..%.2f, %.2f..%.2f, %.2f..%.2f)" % (
                c.x, c.y, c.z, lo.x, hi.x, lo.y, hi.y, lo.z, hi.z)
        print("%-26s %5d of %6d from behind (%.2f%%)%s %s" % (key, n, s, 100.0 * n / max(s, 1), where, KINDS.get(key, "")))
    print("\n".join(lines))


main()
