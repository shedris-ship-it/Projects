"""Preview the wardrobe on the measured bodies (V6), before any import.

Run from the repository root (Blender 5.2, headless):

    blender.exe -b --factory-startup -P tools/blender/wardrobe_preview.py -- [--bake] [--norender]

Builds every garment (kitlib/wardrobe: settled layer over layer), checks
every pair of layers for anything coming through (wardrobe.check), stands
the two classic bodies (the capsules measured in Studio) in a row, dresses
each in an outfit, stretched to its parts as the game will, and renders
build/kit/wardrobe_preview/preview_<view>.png; report.txt has the pieces'
sizes and triangles, the settling and the check.

As the game will show them (2026-10-15: the first previews hid three faults
Studio showed): the pieces exactly as exported (wardrobe.py's wardrobe.glb,
its meshes and baked maps, a right side wearing its left side's), and every
face drawn from the front only, as Roblox does (Blender draws both sides).
`--bake` builds, lines and bakes them here instead; `--procedural` shows
the lined pieces in their unbaked materials; `--magenta` lights faces seen
from behind instead of leaving them out; `--shots=a,b` renders only those.
"""

import os
import sys

import bmesh
import bpy
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

from kitlib import bake, shapes, wardrobe  # noqa: E402

ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
OUT = os.path.join(ROOT, "build", "kit", "wardrobe_preview")

# Outfits to stand up: (body, top, bottom, shoes).
OUTFITS = [
    ("Boy", "Flannel", "Jeans", "Sneaker"),
    ("Girl", "Varsity", "Jeans", "Sneaker"),
    ("Boy", "Windbreaker", "Cords", "Sneaker"),
    ("Girl", "Cardigan", "Cords", "Loafer"),
]
LIFT = 3.0  # the root's height above the floor in the previews


def clear():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete()
    for block in (bpy.data.meshes, bpy.data.materials, bpy.data.images):
        for item in list(block):
            block.remove(item)


def side_of(name, part):
    if part in wardrobe.LIMBS:
        return "R" if name.endswith("R") else "L"
    return "C"


def place(obj, name, body, x_offset):
    """Stands a piece on a body at its part, stretched to that body's part
    (as World/Kit.wear does in the game)."""
    part = obj["part"]
    side = side_of(name, part)
    s = wardrobe.scale_of(body, part)
    at = wardrobe.place_of(body, part, side)
    obj.scale = (s.x, s.z, s.y)
    obj.location = wardrobe.G(at.x + x_offset, at.y + LIFT, at.z)


def proxy(body, x_offset):
    for obj in wardrobe._proxy(body):
        obj.location = (x_offset, 0, LIFT)


def light(name, kind, at, energy, color, size, target):
    data = bpy.data.lights.new(name, kind)
    data.energy = energy
    data.color = color
    if kind == "AREA":
        data.size = size
    obj = bpy.data.objects.new(name, data)
    bpy.context.scene.collection.objects.link(obj)
    obj.location = at
    obj.rotation_euler = (Vector(target) - Vector(at)).to_track_quat("-Z", "Y").to_euler()


def camera(at, target, lens=40):
    data = bpy.data.cameras.new("Cam")
    data.lens = lens
    cam = bpy.data.objects.new("Cam", data)
    bpy.context.scene.collection.objects.link(cam)
    cam.location = at
    cam.rotation_euler = (Vector(target) - Vector(at)).to_track_quat("-Z", "Y").to_euler()
    bpy.context.scene.camera = cam


def one_sided(mat):
    """Leaves out a face seen from behind (Roblox draws the front only)."""
    tree = mat.node_tree
    outs = [n for n in tree.nodes if n.type == "OUTPUT_MATERIAL"]
    if not outs or not outs[0].inputs["Surface"].links:
        return
    out = outs[0]
    src = out.inputs["Surface"].links[0].from_socket
    geo = tree.nodes.new("ShaderNodeNewGeometry")
    if "--magenta" in sys.argv:
        # (Debugging: faces seen from behind lit magenta instead of left out.)
        clear = tree.nodes.new("ShaderNodeEmission")
        clear.inputs["Color"].default_value = (1, 0, 1, 1)
    else:
        clear = tree.nodes.new("ShaderNodeBsdfTransparent")
    mix = tree.nodes.new("ShaderNodeMixShader")
    tree.links.new(geo.outputs["Backfacing"], mix.inputs[0])
    tree.links.new(src, mix.inputs[1])
    tree.links.new(clear.outputs[0], mix.inputs[2])
    tree.links.new(mix.outputs[0], out.inputs["Surface"])


def exported(built):
    """The pieces as exported (build/kit/wardrobe/wardrobe.glb, what the
    owner imports), each told its body part; a right side wears its left
    side's maps, as in the game (assets/kit)."""
    parts = {name: obj["part"] for name, obj in built.items()}
    for obj in list(built.values()):
        bpy.data.objects.remove(obj, do_unlink=True)
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=os.path.join(ROOT, "build", "kit", "wardrobe", "wardrobe.glb"))
    out = {}
    for obj in set(bpy.data.objects) - before:
        if obj.type == "MESH" and obj.name in parts:
            obj.parent = None
            obj.location = (0, 0, 0)
            obj["part"] = parts[obj.name]
            out[obj.name] = obj
        else:
            bpy.data.objects.remove(obj, do_unlink=True)
    for name, obj in out.items():
        twin = out.get(name[:-1] + "L") if name.endswith("R") else None
        if twin is not None and obj["part"] in wardrobe.LIMBS:
            obj.data.materials.clear()
            obj.data.materials.append(twin.data.materials[0])
    return out


def main():
    args = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    os.makedirs(OUT, exist_ok=True)
    clear()
    garments, built, log = wardrobe.wardrobe()
    checks = wardrobe.check(garments, built)
    if "--procedural" in args or "--bake" in args:
        for obj in built.values():
            wardrobe.line(obj)
    if "--bake" in args:
        # Baked here: the left sides, the right sides mirrored from them.
        rights = {n: o["part"] for n, o in built.items() if o["part"] in wardrobe.LIMBS and n.endswith("R")}
        for name in rights:
            bpy.data.objects.remove(built.pop(name), do_unlink=True)
        for obj in list(built.values()):
            bake.unwrap(obj)
            bake.bake_piece(obj, OUT, size=512, solo=True)
        for name, part in rights.items():
            right = wardrobe.mirror(built[name[:-1] + "L"], name)
            right["part"] = part
            built[name] = right
    elif "--procedural" not in args:
        built = exported(built)
    report = ["PIECES"]
    for obj in built.values():
        lo, hi = shapes.bounds(obj)
        report.append("%-26s %6d tris  %.2f x %.2f x %.2f" % (obj.name, shapes.triangles(obj), hi.x - lo.x, hi.z - lo.z, hi.y - lo.y))
    report += ["", "SETTLED"] + log + ["", "CHECK"] + checks
    with open(os.path.join(OUT, "report.txt"), "w") as f:
        f.write("\n".join(report) + "\n")
    print("WARDROBE_REPORT")
    print("\n".join(report))
    if "--norender" in args:
        return
    spacing = 3.4
    for i, (body, top, bottom, shoes) in enumerate(OUTFITS):
        x_offset = (i - (len(OUTFITS) - 1) / 2) * spacing
        proxy(body, x_offset)
        for garment in (top, bottom, shoes):
            for name, obj in built.items():
                if not name.startswith(garment):
                    continue
                copy = obj.copy()
                copy.data = obj.data
                bpy.context.scene.collection.objects.link(copy)
                place(copy, name, body, x_offset)
    for obj in built.values():
        obj.hide_render = True
    # Faces from the front only, as Roblox draws them (not the stand-in body).
    for mat in bpy.data.materials:
        if mat.use_nodes and not mat.name.startswith("ProxySkin"):
            one_sided(mat)
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = 24
    scene.cycles.use_denoising = True
    scene.view_settings.view_transform = "AgX"
    if not scene.world:
        scene.world = bpy.data.worlds.new("World")
    scene.world.color = (0.02, 0.02, 0.025)
    bm = bmesh.new()
    bmesh.ops.create_grid(bm, x_segments=1, y_segments=1, size=20)
    floor = bpy.data.meshes.new("Floor")
    bm.to_mesh(floor)
    bm.free()
    fl = bpy.data.objects.new("Floor", floor)
    scene.collection.objects.link(fl)
    fm = bpy.data.materials.new("FloorMat")
    fm.use_nodes = True
    fm.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.08, 0.05, 0.035, 1)
    floor.materials.append(fm)
    G = wardrobe.G
    light("Key", "AREA", G(-4, 9, -8), 1600, (1.0, 0.86, 0.7), 4.0, G(0, 3, 0))
    light("Fill", "AREA", G(6, 5, -6), 500, (0.75, 0.82, 1.0), 4.0, G(0, 3, 0))
    light("Rim", "AREA", G(0, 8, 7), 700, (0.9, 0.9, 1.0), 4.0, G(0, 4, 0))
    xs = [(i - (len(OUTFITS) - 1) / 2) * spacing for i in range(len(OUTFITS))]
    shots = [
        ("front", G(0.0, 3.6, -15.0), G(0, 2.9, 0), (1600, 820), 40),
        ("back", G(0.0, 3.8, 15.0), G(0, 2.9, 0), (1600, 820), 40),
        ("close_flannel", G(xs[0] + 1.2, 4.3, -4.4), G(xs[0], 3.4, 0), (900, 900), 45),
        ("close_varsity", G(xs[1] + 1.0, 4.2, -4.6), G(xs[1], 3.4, 0), (900, 900), 45),
        ("close_windbreaker", G(xs[2] - 1.3, 4.2, -4.4), G(xs[2], 3.4, 0), (900, 900), 45),
        ("close_cardigan", G(xs[3] - 1.2, 4.3, -4.4), G(xs[3], 3.4, 0), (900, 900), 45),
        ("close_feet", G(xs[0] + 1.6, 1.4, -3.4), G(xs[0], 0.6, 0), (900, 700), 45),
        ("close_loafers", G(xs[3] - 1.6, 1.4, -3.4), G(xs[3], 0.6, 0), (900, 700), 45),
        ("close_side", G(xs[0] - 4.2, 3.4, -0.6), G(xs[0], 3.0, 0), (900, 900), 45),
        ("low", G(0.0, 0.8, -12.0), G(0, 3.0, 0), (1600, 820), 40),
    ]
    only = [a[len("--shots="):].split(",") for a in args if a.startswith("--shots=")]
    for name, at, target, res, lens in shots:
        if only and name not in only[0]:
            continue
        scene.render.resolution_x, scene.render.resolution_y = res
        camera(at, target, lens)
        scene.render.filepath = os.path.join(OUT, "preview_" + name + ".png")
        bpy.ops.render.render(write_still=True)


main()
