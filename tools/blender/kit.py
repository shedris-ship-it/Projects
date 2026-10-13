"""Build a batch of the kit in Blender and export it for Roblox Studio's 3D
importer (the visual rework, docs/ART.md v2).

Run from the repository root (Blender 5.2, headless):

    A:\\Tools\\blender-5.2.2-windows-x64\\blender-5.2.2-windows-x64\\blender.exe -b --factory-startup -P tools/blender/kit.py -- spike

Writes build/kit/<batch>/: one .glb and one .fbx with every piece (meshes and
their baked maps), the maps as PNGs, and report.txt (sizes and triangles).
The build folder is git-ignored: everything regenerates from these scripts.
Units are studs. Each piece's size matches the game's own piece (Data/Props,
the door slab in World/LevelBuilder), so World/Kit can fit it.
"""

import os
import sys

import bpy

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

from kitlib import bake, furniture, materials, shapes  # noqa: E402

ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))


def clear():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete()
    for block in (bpy.data.meshes, bpy.data.materials, bpy.data.images):
        for item in list(block):
            block.remove(item)


# Pieces --------------------------------------------------------------------


def chair():
    """A 1980s colonial dining chair, 2.5 x 4 x 2.5 studs (Data/Props Chair):
    turned legs, a shaped seat, a back of spindles under a curved crest rail.
    The front faces -Y (Roblox's -Z once exported)."""
    wood = materials.wood("Walnut", grain_axis="Z", scale=1.4)
    wood_x = materials.wood("WalnutAcross", grain_axis="X", scale=1.4)
    parts = []
    w, d = 2.5, 2.5
    seat_z = 2.0
    for sx in (-1, 1):
        for sy in (-1, 1):
            leg = shapes.turned_leg("Leg", seat_z - 0.12, 0.13, (sx * (w / 2 - 0.22), sy * (d / 2 - 0.22), 0))
            parts.append(materials.assign(leg, wood))
    seat = shapes.box("Seat", (w, d - 0.1, 0.22), (0, 0.05, seat_z), bevel_width=0.07, segments=4)
    parts.append(materials.assign(seat, wood_x))
    # Stretchers between the legs.
    for sy in (-1, 1):
        rail = shapes.box("Stretcher", (w - 0.5, 0.1, 0.1), (0, sy * (d / 2 - 0.22), 0.55), 0.03, 2)
        parts.append(materials.assign(rail, wood_x))
    # The back: two posts, spindles, a crest rail.
    back_y = d / 2 - 0.2
    for sx in (-1, 1):
        post = shapes.box("Post", (0.16, 0.16, 2.0), (sx * (w / 2 - 0.22), back_y, seat_z + 1.0), 0.05, 3)
        parts.append(materials.assign(post, wood))
    for i in range(5):
        x = -0.72 + i * 0.36
        spindle = shapes.lathe(
            "Spindle",
            [(0.0, 0.0), (0.045, 0.0), (0.06, 0.5), (0.04, 1.0), (0.045, 1.45), (0.0, 1.45)],
            (x, back_y, seat_z + 0.1),
            steps=12,
        )
        parts.append(materials.assign(spindle, wood))
    crest = shapes.box("Crest", (w - 0.12, 0.14, 0.4), (0, back_y, seat_z + 1.82), 0.08, 4)
    parts.append(materials.assign(crest, wood_x))
    return shapes.join(parts, "Chair")


def floor_lamp():
    """A floor lamp, 1.5 x 6 x 1.5 studs (Data/Props FloorLamp): a brass
    stem on a weighted base, a pleated-look linen drum shade."""
    metal = materials.brass("Brass")
    linen = materials.fabric("Linen", color=(214, 196, 160))
    linen["glow"] = 1.0  # the shade glows from the bulb (its emissive mask)
    base = shapes.lathe(
        "Base",
        [(0.0, 0.0), (0.68, 0.0), (0.7, 0.06), (0.6, 0.14), (0.3, 0.22), (0.12, 0.3), (0.0, 0.3)],
        steps=40,
    )
    stem = shapes.lathe(
        "Stem",
        [
            (0.0, 0.25),
            (0.06, 0.25),
            (0.06, 2.4),
            (0.1, 2.5),
            (0.06, 2.6),
            (0.06, 4.6),
            (0.09, 4.7),
            (0.0, 4.75),
        ],
        steps=20,
    )
    shade = shapes.lathe(
        "Shade",
        [(0.42, 4.55), (0.75, 4.55), (0.72, 4.6), (0.5, 5.95), (0.46, 5.95), (0.44, 5.9), (0.68, 4.6)],
        steps=48,
    )
    for o, m in ((base, metal), (stem, metal), (shade, linen)):
        materials.assign(o, m)
    return shapes.join([base, stem, shade], "FloorLamp")


def door():
    """A 1988 six-panel interior door slab, 5.8 x 7.8 x 0.35 studs (the slab
    in World/LevelBuilder), in old off-white paint."""
    paint = materials.paint("DoorPaint", color=(196, 188, 168))
    w, h, t = 5.8, 7.8, 0.35
    panels = []
    for px in (-1.3, 1.3):
        panels += [(px, 2.45, 2.2, 2.0), (px, -0.05, 2.2, 2.0), (px, -2.55, 2.2, 2.0)]
    slab = shapes.panel_slab("Door", w, h, t, panels, frame=0.26, raise_depth=0.04)
    materials.assign(slab, paint)
    return slab


BATCHES = {
    "spike": [chair, floor_lamp, door],
    # The golden room's furniture (the visual rework V3): the grand hall, the
    # dining room and the living room, taken all the way first.
    "golden": furniture.GOLDEN,
}


def export(objects, out_dir, batch):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objects:
        o.select_set(True)
    glb = os.path.join(out_dir, batch + ".glb")
    bpy.ops.export_scene.gltf(filepath=glb, export_format="GLB", use_selection=True, export_yup=True)
    fbx = os.path.join(out_dir, batch + ".fbx")
    bpy.ops.export_scene.fbx(
        filepath=fbx,
        use_selection=True,
        path_mode="COPY",
        embed_textures=True,
        axis_forward="-Z",
        axis_up="Y",
        apply_unit_scale=True,
    )
    return glb, fbx


def main():
    # `-- <batch> [Piece ...]`: the whole batch, or only the named pieces (to
    # fix one piece without the owner importing the rest again), written to
    # build/kit/<batch>_<Piece...>/.
    # `--bounds` anywhere: only print each piece's box (no bake, no export).
    args = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else ["spike"]
    bounds_only = "--bounds" in args
    args = [a for a in args if a != "--bounds"]
    batch, only = args[0], set(args[1:])
    name = batch if not only else batch + "_" + "_".join(sorted(only))
    out_dir = os.path.join(ROOT, "build", "kit", name)
    os.makedirs(out_dir, exist_ok=True)
    clear()
    report = []
    objects = []
    spacing = 0.0
    for build in BATCHES[batch]:
        obj = build()
        if only and obj.name not in only:
            bpy.data.objects.remove(obj, do_unlink=True)
            continue
        lo, hi = shapes.bounds(obj)
        size = hi - lo
        # Studio's importer centres a mesh on its box, but the game puts a
        # piece where its grey-box's middle is: a box made lopsided by an
        # overhang (a bookcase's cornice) sits off by the difference, and its
        # back went into the wall. Data/Kit's `centre` = where the box's
        # middle is in the game's frame (x; z with the front +Z; Blender's
        # front is -Y), so World/Kit puts it back.
        centre = (round((lo.x + hi.x) / 2, 3), round(-(lo.y + hi.y) / 2, 3))
        if bounds_only:
            report.append(
                "%-16s size %.2f x %.2f x %.2f  centre = { %g, %g }  floor %.3f"
                % (obj.name, size.x, size.z, size.y, centre[0], centre[1], lo.z)
            )
            bpy.data.objects.remove(obj, do_unlink=True)
            continue
        # Lay them out side by side for the importer's preview.
        obj.location.x += spacing - lo.x
        spacing += size.x + 2.0
        bake.unwrap(obj)
        bake.bake_piece(obj, out_dir, size=1024)
        objects.append(obj)
        report.append(
            "%-12s %6.2f x %6.2f x %6.2f studs  %6d triangles  centre = { %g, %g }"
            % (obj.name, size.x, size.z, size.y, shapes.triangles(obj), centre[0], centre[1])
        )
    if bounds_only:
        print("KIT_REPORT")
        print("\n".join(report))
        return
    glb, fbx = export(objects, out_dir, name)
    report.append("wrote " + os.path.relpath(glb, ROOT))
    report.append("wrote " + os.path.relpath(fbx, ROOT))
    with open(os.path.join(out_dir, "report.txt"), "w") as f:
        f.write("\n".join(report) + "\n")
    print("KIT_REPORT")
    print("\n".join(report))


main()
