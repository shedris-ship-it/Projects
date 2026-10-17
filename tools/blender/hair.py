"""Build the hair (2026-10-17; kitlib/hair) and export it for Studio's 3D
importer.

Run from the repository root (Blender 5.2, headless):

    blender.exe -b --factory-startup -P tools/blender/hair.py -- [--nobake] [--nocheck]

Builds the eight styles and the two scrunchies, grey (the game tints the
hair: SurfaceAppearance.Color, Data/Wardrobe HairColours); checks each
against every top's collar and the bare torso on both bodies, the head at
its classic height (want 0); bakes their maps; writes build/kit/hair/
hair.glb, the maps and report.txt, and the game's side, src/shared/Data/
KitHair.luau (generated: each piece's size, where its middle sits from the
head's, the head size it was built round, and how light its colour map reads, which
a hair colour's tint is worked out from).
"""

import os
import sys

import bpy
import numpy as np
from mathutils import Vector
from mathutils.bvhtree import BVHTree

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

from kitlib import bake, hair, shapes, wardrobe  # noqa: E402

ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
OUT = os.path.join(ROOT, "build", "kit", "hair")
DATA = os.path.join(ROOT, "src", "shared", "Data", "KitHair.luau")
WHITE = (255, 255, 255)
# The heads the hair is worn on (Roblox's classic-shaped dynamic heads,
# measured in Studio): the size the game stretches a piece from.
BASE = (1.1606, 1.1815, 1.1606)


def clear():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete()
    for block in (bpy.data.meshes, bpy.data.materials, bpy.data.images):
        for item in list(block):
            block.remove(item)


def fit(obj):
    """Its box: size (x, up, depth) and the middle (x, up, z) in the game's
    frame, from its own vertices."""
    lo, hi = shapes.bounds(obj)
    size = (hi.x - lo.x, hi.z - lo.z, hi.y - lo.y)
    at = ((lo.x + hi.x) / 2, (lo.z + hi.z) / 2, -(lo.y + hi.y) / 2)
    return size, at


def lua_num(v):
    return ("%.4f" % v).rstrip("0").rstrip(".") if abs(v) > 1e-9 else "0"


def lua_vec(t):
    return "{ " + ", ".join(lua_num(v) for v in t) + " }"


def world_tree(objs):
    """One BVH over the objects in world space."""
    deps = bpy.context.evaluated_depsgraph_get()
    verts, polys = [], []
    for obj in objs:
        ev = obj.evaluated_get(deps)
        me = ev.to_mesh()
        mw = obj.matrix_world
        base = len(verts)
        verts += [mw @ v.co for v in me.vertices]
        polys += [[base + i for i in p.vertices] for p in me.polygons]
        ev.to_mesh_clear()
    return BVHTree.FromPolygons(verts, polys)


def check(styles):
    """How far any hair comes through a top (its collar) or the bare torso,
    on both bodies, the head where the classic head sits: for each hair
    vertex near a surface, whether it's on the inside. Returns report lines
    and the worst depth."""
    _, built, _ = wardrobe.wardrobe()
    for obj in built.values():
        obj.hide_render = True
    tops = sorted(n for n in built if n.endswith("Torso"))
    lines, worst = [], 0.0
    for body in wardrobe.BODY_NAMES:
        proxies = wardrobe._proxy(body)
        torso = [o for o in proxies if "UpperTorso" in o.name]
        head_at = wardrobe.BODIES[body]["Head"]["at"]
        targets = [("bare", torso)]
        placed = []
        for name in tops:
            obj = built[name]
            copy = obj.copy()
            copy.data = obj.data
            bpy.context.scene.collection.objects.link(copy)
            part = obj["part"]
            s = wardrobe.scale_of(body, part)
            at = wardrobe.place_of(body, part, "C")
            copy.scale = (s.x, s.z, s.y)
            copy.location = wardrobe.G(at.x, at.y, at.z)
            placed.append(copy)
            targets.append((name[: -len("Torso")], [copy]))
        bpy.context.view_layer.update()
        trees = [(label, world_tree(objs)) for label, objs in targets]
        for style, pieces in styles.items():
            for piece in pieces:
                mw = piece.matrix_world.copy()
                piece.location = wardrobe.G(head_at[0], head_at[1], head_at[2])
                bpy.context.view_layer.update()
                pts = [piece.matrix_world @ v.co for v in piece.data.vertices]
                head = Vector(wardrobe.G(head_at[0], head_at[1], head_at[2]))
                for label, tree in trees:
                    deep, where = 0.0, None
                    for p in pts:
                        loc, nrm, _, dist = tree.find_nearest(p, 0.08)
                        if loc is not None and (p - loc).dot(nrm) < 0 and dist > deep:
                            deep, where = dist, p - head
                    if deep > 0.002:
                        # (Where, in the head's frame: x, up, z.)
                        lines.append("  %s %s through %s: %.3f at (%.2f, %.2f, %.2f)" % (body, piece.name, label, deep, where.x, where.z, -where.y))
                        worst = max(worst, deep)
                piece.matrix_world = mw
        for obj in proxies + placed:
            bpy.data.objects.remove(obj, do_unlink=True)
    for obj in list(built.values()):
        bpy.data.objects.remove(obj, do_unlink=True)
    return lines, worst


def mean_of(path):
    """How light a colour map reads (sRGB, 0 to 1): the 90th percentile of
    its covered pixels, not their mean (the locks' buried roots and
    undersides bake dark and are never seen)."""
    img = bpy.data.images.load(path)
    a = np.array(img.pixels[:], dtype=np.float32).reshape(-1, 4)[:, :3]
    bpy.data.images.remove(img)
    lum = a.mean(axis=1)
    covered = lum[lum > 0.02]
    return float(np.percentile(covered, 90)) if len(covered) else 0.0


def main():
    args = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    nobake = "--nobake" in args
    os.makedirs(OUT, exist_ok=True)
    clear()
    styles = {name: hair.build(name, tint=WHITE) for name in hair.STYLES}
    pieces = [obj for objs in styles.values() for obj in objs]
    report = []
    for obj in pieces:
        size, _ = fit(obj)
        report.append("%-24s %6d tris  %.2f x %.2f x %.2f" % (obj.name, shapes.triangles(obj), size[0], size[1], size[2]))
    checks, worst = ([], 0.0) if "--nocheck" in args else check(styles)
    report += ["", "CHECK (hair through a top or the bare torso; want none)"] + (checks or ["  none"])
    means = {}
    for obj in pieces:
        if nobake:
            continue
        bake.unwrap(obj)
        size = 512 if "Scrunchie" in obj.name else 1024
        # (Half the usual occlusion: the locks overlap, and the map has to
        # stay light enough to tint blonde.)
        paths = bake.bake_piece(obj, OUT, size=size, solo=True, ao_strength=0.35)
        means[obj.name] = mean_of(paths["color"])
    report += ["", "COLOUR MAP MEANS (sRGB)"] + ["  %-24s %.3f" % (k, v) for k, v in means.items()]

    lines = []
    for obj in sorted(pieces, key=lambda o: o.name):
        size, at = fit(obj)
        tinted = "Scrunchie" not in obj.name
        extra = ', mean = %s' % lua_num(means.get(obj.name, hair.MAP_MEAN)) if tinted else ""
        lines.append('\t\t%s = { part = "Head", side = "C", size = %s, at = %s, base = %s%s },' % (obj.name, lua_vec(size), lua_vec(at), lua_vec(BASE), extra))
    with open(DATA, "w", newline="\n") as f:
        f.write(
            "-- Generated by tools/blender/hair.py: don't edit by hand. The hair's\n"
            "-- pieces (kitlib/hair), each worn on the Head as the wardrobe's are on\n"
            "-- their parts (World/Kit.wear): `size` its box, `at` where its middle sits\n"
            "-- from the head's, `base` the head it was built round. `mean`: how light\n"
            "-- its grey colour map reads (sRGB, 0 to 1); a hair colour's tint is the\n"
            "-- colour over it (Logic/Closet.hairTint). Their ids are in Data/Kit (Wear).\n\n"
            "return {\n\tWear = {\n" + "\n".join(lines) + "\n\t},\n}\n"
        )

    # Each mesh named as its piece, side by side for the importer.
    for obj in pieces:
        obj.data.name = obj.name
    x = 0.0
    for obj in pieces:
        lo, hi = shapes.bounds(obj)
        obj.location.x += x - lo.x
        x += (hi.x - lo.x) + 0.6
    bpy.ops.object.select_all(action="DESELECT")
    for obj in pieces:
        obj.select_set(True)
    glb = os.path.join(OUT, "hair.glb")
    bpy.ops.export_scene.gltf(filepath=glb, export_format="GLB", use_selection=True, export_yup=True)
    report += ["", "worst %.3f" % worst, "wrote " + os.path.relpath(glb, ROOT)]
    with open(os.path.join(OUT, "report.txt"), "w") as f:
        f.write("\n".join(report) + "\n")
    print("HAIR_REPORT")
    print("\n".join(report))


main()
