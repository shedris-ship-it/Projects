"""Build the wardrobe and the tools (V6) and export them for Studio's 3D importer.

Run from the repository root (Blender 5.2, headless):

    blender.exe -b --factory-startup -P tools/blender/wardrobe.py -- [--only=A,B] [--nobake]

Builds every garment (kitlib/wardrobe: layer over layer, checked for anything
coming through) and every tool (kitlib/toolkit); bakes their maps; writes
build/kit/wardrobe/wardrobe.glb, the maps, report.txt; and the game's side,
src/shared/Data/KitWear.luau (generated: each piece's size, where its middle
sits on its body part, the part's size it was built at).

The right side's sleeves, legs and shoes are the left's mirrored with the
same UVs, so they wear the left's maps (assets/kit: the same SurfaceAppearance)
and go to the importer without textures of their own.
"""

import os
import sys

import bpy

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

from kitlib import bake, shapes, toolkit, wardrobe  # noqa: E402

ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
OUT = os.path.join(ROOT, "build", "kit", "wardrobe")
DATA = os.path.join(ROOT, "src", "shared", "Data", "KitWear.luau")


def clear():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete()
    for block in (bpy.data.meshes, bpy.data.materials, bpy.data.images):
        for item in list(block):
            block.remove(item)


def is_right(name, part):
    return part in wardrobe.LIMBS and name.endswith("R")


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


def main():
    args = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    only = None
    for a in args:
        if a.startswith("--only="):
            only = set(a[len("--only=") :].split(","))
    nobake = "--nobake" in args
    # `--reuse=A,B`: these pieces wear the maps baked last time (the rest bake).
    reuse = set()
    for a in args:
        if a.startswith("--reuse="):
            reuse = set(a[len("--reuse=") :].split(","))
        if a == "--reuse-wear":
            reuse = {"*wear"}
        if a == "--reuse-all":
            reuse = {"*wear", "*tools"}
    # `--rights`: export only the right sides (mirrored from the left ones, which
    # are built and wired as usual), to wardrobe_rights.glb.
    rights_only = "--rights" in args
    os.makedirs(OUT, exist_ok=True)
    clear()
    garments, built, log = wardrobe.wardrobe()
    checks = wardrobe.check(garments, built)
    # Each piece's inside (Roblox draws a face from the front only).
    for obj in built.values():
        wardrobe.line(obj)
    tools = [make() for make in toolkit.TOOLS]

    # The right sides: dropped now, mirrored again from the baked left ones.
    rights = {name: obj["part"] for name, obj in built.items() if is_right(name, obj["part"])}
    for name in rights:
        bpy.data.objects.remove(built.pop(name), do_unlink=True)

    pieces = list(built.values()) + tools
    if only:
        pieces = [o for o in pieces if o.name in only or o.name[:-1] + "R" in only]
    report = []
    for obj in pieces:
        if not nobake:
            bake.unwrap(obj)
            wear = not obj.name.startswith("Tool")
            wanted = obj.name in reuse or (wear and "*wear" in reuse) or (not wear and "*tools" in reuse)
            if wanted and bake.reuse_piece(obj, OUT):
                continue
            size = int(obj.get("bake_size", 1024 if obj.get("part") in ("UpperTorso",) else 512))
            bake.bake_piece(obj, OUT, size=size, solo=True)
    # The right sides back, wearing the left's UVs; a plain material each so
    # the importer brings no textures for them.
    plain = bpy.data.materials.new("Mirrored")
    for name, part in rights.items():
        left = bpy.data.objects.get(name[:-1] + "L")
        if left is None or (only and left not in pieces):
            continue
        right = wardrobe.mirror(left, name)
        right["part"] = part
        right.data.materials.clear()
        right.data.materials.append(plain)
        pieces.append(right)

    # The game's side: sizes and middles (kept from before the layout below).
    wear_lines, tool_lines = [], []
    for obj in sorted(pieces, key=lambda o: o.name):
        size, at = fit(obj)
        if obj.name.startswith("Tool"):
            tool_lines.append("\t\t%s = { size = %s, at = %s }," % (obj.name, lua_vec(size), lua_vec(at)))
        else:
            part = obj["part"]
            base = wardrobe.NOMINAL[part]
            side = "R" if is_right(obj.name, part) else ("L" if part in wardrobe.LIMBS else "C")
            wear_lines.append(
                '\t\t%s = { part = "%s", side = "%s", size = %s, at = %s, base = %s },'
                % (obj.name, part, side, lua_vec(size), lua_vec(at), lua_vec(base))
            )
        report.append("%-26s %6d tris  %.2f x %.2f x %.2f" % (obj.name, shapes.triangles(obj), size[0], size[1], size[2]))
    if rights_only:
        keep = [o for o in pieces if o.name in rights]
        for obj in [o for o in pieces if o.name not in rights]:
            bpy.data.objects.remove(obj, do_unlink=True)
        pieces = keep
    if not only and not rights_only:
        with open(DATA, "w", newline="\n") as f:
            f.write(
                "-- Generated by tools/blender/wardrobe.py (V6): don't edit by hand. The\n"
                "-- wardrobe's pieces (Wear: each worn on a body part, built at that part's\n"
                "-- size `base` and stretched by the game to the part it's on; `size` its box,\n"
                "-- `at` where its middle sits from the part's, in the part's frame) and the\n"
                "-- tools' meshes (Tools: `at` from the tool model's pivot). Their ids are in\n"
                "-- Data/Kit (Wear, Tools).\n\n"
                "return {\n\tWear = {\n" + "\n".join(wear_lines) + "\n\t},\n\tTools = {\n" + "\n".join(tool_lines) + "\n\t},\n}\n"
            )

    # Each mesh named as its piece (the importer names a part by its mesh; a
    # right side's mesh came out "...R.001" next to its dropped first copy).
    for obj in pieces:
        if obj.data.name != obj.name:
            old = bpy.data.meshes.get(obj.name)
            if old is not None and old is not obj.data and old.users == 0:
                bpy.data.meshes.remove(old)
            obj.data.name = obj.name
    # Side by side for the importer's preview.
    x = 0.0
    for obj in pieces:
        lo, hi = shapes.bounds(obj)
        obj.location.x += x - lo.x
        x += (hi.x - lo.x) + 0.6
    bpy.ops.object.select_all(action="DESELECT")
    for obj in pieces:
        obj.select_set(True)
    name = "wardrobe" if not only else "wardrobe_" + "_".join(sorted(only))
    if rights_only:
        name = "wardrobe_rights"
    glb = os.path.join(OUT, name + ".glb")
    bpy.ops.export_scene.gltf(filepath=glb, export_format="GLB", use_selection=True, export_yup=True)
    report += ["", "SETTLED"] + log + ["", "CHECK"] + checks + ["", "wrote " + os.path.relpath(glb, ROOT)]
    with open(os.path.join(OUT, "report.txt"), "w") as f:
        f.write("\n".join(report) + "\n")
    print("WARDROBE_REPORT")
    print("\n".join(report))


main()
