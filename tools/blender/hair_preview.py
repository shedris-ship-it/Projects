"""Preview the hair (2026-10-17; kitlib/hair) on the classic head and the
measured bodies, before any import.

Run from the repository root (Blender 5.2, headless):

    blender.exe -b --factory-startup -P tools/blender/hair_preview.py -- [--styles=Crew,Perm]
        [--body=Boy] [--views=front,three,backthree] [--dressed[=procedural]] [--faces=DIR]
        [--colours=Black,Ginger,...] [--strip=Shoulder] [--samples=24] [--out=DIR]

Stands one body per style in a row (the head is the measured one: a round
cylinder, its edges rounded), its hair on, and renders
<out>/hair_<body>_<view>_<n>.png, four figures a shot (views: front,
three, back, backthree). `--dressed` puts the wardrobe on them as exported
(build/kit/wardrobe/wardrobe.glb and wardrobe_lb3.glb, baked maps), and
`--dressed=procedural` as built here (kitlib/wardrobe, every garment in its
own materials: the sketches' way); `--faces=DIR` lays a face's features over
each head's front (DIR/<face>.png, spanning the head's front box);
`--colours` gives each style its hair colour (kitlib/hair COLOURS).
`--strip=Style` stands that style once in every colour instead. Faces are
drawn from the front only, as Roblox does.
"""

import math
import os
import re
import sys

import bmesh
import bpy
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

from kitlib import clothmats as cm  # noqa: E402
from kitlib import hair, materials, wardrobe  # noqa: E402

ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
LIFT = 3.0
HEAD_AT = 1.586  # the head's middle over the root (bodyshape.txt)
SKIN = (214, 170, 130)

# What each figure wears (top, bottom, shoes) and which face, in turn.
OUTFITS = {
    "Boy": [
        ("Flannel", "Jeans", "Sneaker"), ("Varsity", "Jeans", "Sneaker"), ("Ringer", "Cords", "Loafer"),
        ("Windbreaker", "Parachute", "HighTop"), ("DenimJacket", "Jeans", "Sneaker"), ("Sweatshirt", "Cords", "Sneaker"),
        ("Biker", "Jeans", "HighTop"), ("Cardigan", "Cords", "Loafer"),
    ],
    "Girl": [
        ("Cardigan", "Cords", "Loafer"), ("Ringer", "Jeans", "HighTop"), ("Varsity", "Jeans", "Sneaker"),
        ("Sweatshirt", "Parachute", "HighTop"), ("Biker", "Jeans", "Sneaker"), ("DenimJacket", "Cords", "Loafer"),
        ("Flannel", "Jeans", "Sneaker"), ("Windbreaker", "Cords", "Sneaker"),
    ],
}
FACES = {
    "Boy": ["Dennis", "Kenneth", "ManFace", "Dennis", "Kenneth", "ManFace", "Dennis", "Kenneth"],
    "Girl": ["Lindsey", "Cindy", "WomanFace", "Lindsey", "Cindy", "WomanFace", "Lindsey", "Cindy"],
}


def clear():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete()
    for block in (bpy.data.meshes, bpy.data.materials, bpy.data.images):
        for item in list(block):
            block.remove(item)


def head_material(name, face_png):
    """Skin, with a face's features laid over the head's front (as a decal
    is: projected straight on, front faces only)."""
    mat = bpy.data.materials.new(name)
    n = materials.Nodes(mat)
    skin = materials._srgb(SKIN)
    n.bsdf.inputs["Roughness"].default_value = 0.55
    if not face_png or not os.path.exists(face_png):
        n.bsdf.inputs["Base Color"].default_value = skin
        return mat
    img = bpy.data.images.load(face_png)
    tex = n.add("ShaderNodeTexImage")
    tex.image = img
    tex.extension = "CLIP"
    # u from the viewer's left (Blender +x) to right; v up.
    m = n.add("ShaderNodeMapping")
    m.inputs["Scale"].default_value = (-1.0 / 1.159, 1.0, 1.0 / 1.182)
    m.inputs["Location"].default_value = (0.5, 0.0, 0.5)
    n.link(n.coord.outputs["Object"], m.inputs["Vector"])
    sep = n.add("ShaderNodeSeparateXYZ")
    n.link(m.outputs["Vector"], sep.inputs["Vector"])
    uv = n.add("ShaderNodeCombineXYZ")
    n.link(sep.outputs["X"], uv.inputs["X"])
    n.link(sep.outputs["Z"], uv.inputs["Y"])
    n.link(uv.outputs["Vector"], tex.inputs["Vector"])
    geo = n.add("ShaderNodeNewGeometry")
    nsep = n.add("ShaderNodeSeparateXYZ")
    n.link(geo.outputs["Normal"], nsep.inputs["Vector"])
    front = n.math("GREATER_THAN", nsep.outputs["Y"], 0.35)
    a = n.math("MULTIPLY", tex.outputs["Alpha"], front.outputs["Value"])
    base = n.add("ShaderNodeRGB")
    base.outputs["Color"].default_value = skin
    mix = n.mix_colour(base.outputs["Color"], tex.outputs["Color"], 0.0)
    fac = [s for s in mix.node.inputs if s.identifier == "Factor_Float"][0]
    n.link(a.outputs["Value"], fac)
    n.link(mix, n.bsdf.inputs["Base Color"])
    return mat


def head_mesh(name, mat):
    """The classic head: its outline turned round its axis (the face +y,
    Blender's, which is the game's -z)."""
    outline = [(0.0, -hair.HT)]
    steps = 14
    a = hair.R - hair.RHO
    for i in range(steps + 1):
        ang = -math.pi / 2 + (math.pi / 2) * i / steps
        outline.append((a + hair.RHO * math.cos(ang), -(hair.HT - hair.RHO) + hair.RHO * math.sin(ang)))
    for i in range(steps + 1):
        ang = (math.pi / 2) * i / steps
        outline.append((a + hair.RHO * math.cos(ang), (hair.HT - hair.RHO) + hair.RHO * math.sin(ang)))
    outline.append((0.0, hair.HT))
    bm = bmesh.new()
    K = 72
    rings = []
    for r, y in outline:
        if r < 1e-6:
            rings.append([bm.verts.new((0, 0, y))])
            continue
        rings.append([bm.verts.new((r * math.sin(math.tau * k / K), r * math.cos(math.tau * k / K), y)) for k in range(K)])
    for i in range(len(rings) - 1):
        lo, hi = rings[i], rings[i + 1]
        for k in range(K):
            if len(lo) == 1:
                bm.faces.new((lo[0], hi[(k + 1) % K], hi[k]))
            elif len(hi) == 1:
                bm.faces.new((lo[k], lo[(k + 1) % K], hi[0]))
            else:
                bm.faces.new((lo[k], lo[(k + 1) % K], hi[(k + 1) % K], hi[k]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    for p in mesh.polygons:
        p.use_smooth = True
    obj.data.materials.append(mat)
    return obj


def wear_parts():
    """Each exported piece's body part and side (Data/KitWear)."""
    text = open(os.path.join(ROOT, "src", "shared", "Data", "KitWear.luau"), encoding="utf-8").read()
    return {m.group(1): (m.group(2), m.group(3)) for m in re.finditer(r'(\w+) = \{\s*part = "(\w+)",\s*side = "(\w)"', text)}


def load_wardrobe(procedural=False):
    """The wardrobe's pieces, hidden, each told its part and side: as
    exported (baked; a right side wearing its left side's maps, as in the
    game), or `procedural`: built here in their own materials (the
    sketches' way, every garment)."""
    if procedural:
        _, built, _ = wardrobe.wardrobe()
        for name, obj in built.items():
            wardrobe.line(obj)
            part = obj["part"]
            obj["side"] = ("R" if name.endswith("R") else "L") if part in wardrobe.LIMBS else "C"
            obj.hide_render = True
        return dict(built)
    parts = wear_parts()
    out = {}
    for fn in ("wardrobe.glb", "wardrobe_lb3.glb"):
        path = os.path.join(ROOT, "build", "kit", "wardrobe", fn)
        if not os.path.exists(path):
            continue
        before = set(bpy.data.objects)
        bpy.ops.import_scene.gltf(filepath=path)
        for obj in set(bpy.data.objects) - before:
            if obj.type == "MESH" and obj.name in parts and obj.name not in out:
                obj.parent = None
                obj.location = (0, 0, 0)
                obj.rotation_euler = (0, 0, 0)
                obj["part"], obj["side"] = parts[obj.name]
                obj.hide_render = True
                out[obj.name] = obj
            else:
                bpy.data.objects.remove(obj, do_unlink=True)
    for name, obj in out.items():
        if obj["side"] == "R":
            twin = out.get(name[:-1] + "L")
            if twin is not None and twin.data.materials:
                obj.data.materials.clear()
                obj.data.materials.append(twin.data.materials[0])
    return out


def dress(pieces, kind, outfit, x):
    top, bottom, shoes = outfit
    made = []
    for garment in (top, bottom, shoes):
        for name, obj in pieces.items():
            rest = name[len(garment) :]
            if not name.startswith(garment) or not rest or not rest[0].isupper():
                continue
            # (High-tops: the game leaves the trousers' shins off.)
            if garment == bottom and shoes == "HighTop" and rest.startswith("LowerLeg"):
                continue
            copy = obj.copy()
            copy.data = obj.data
            copy.hide_render = False
            bpy.context.scene.collection.objects.link(copy)
            part, side = obj["part"], obj["side"]
            s = wardrobe.scale_of(kind, part)
            at = wardrobe.place_of(kind, part, side)
            copy.scale = (s.x, s.z, s.y)
            copy.location = wardrobe.G(at.x + x, at.y + LIFT, at.z)
            made.append(copy)
    return made


def figure(kind, x, skin, head_mat):
    for obj in wardrobe._proxy(kind):
        if "Head" in obj.name:
            bpy.data.objects.remove(obj, do_unlink=True)
            continue
        obj.location = (x, 0, LIFT)
        obj.data.materials.clear()
        obj.data.materials.append(skin)
    head = head_mesh("Head" + kind + str(x), head_mat)
    head.location = (x, 0, LIFT + HEAD_AT)
    return head


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


def camera(at, target, ortho):
    data = bpy.data.cameras.new("Cam")
    data.type = "ORTHO"
    data.ortho_scale = ortho
    cam = bpy.data.objects.new("Cam", data)
    bpy.context.scene.collection.objects.link(cam)
    cam.location = at
    cam.rotation_euler = (Vector(target) - Vector(at)).to_track_quat("-Z", "Y").to_euler()
    bpy.context.scene.camera = cam
    return cam


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
        clear_ = tree.nodes.new("ShaderNodeEmission")
        clear_.inputs["Color"].default_value = (1, 0, 1, 1)
    else:
        clear_ = tree.nodes.new("ShaderNodeBsdfTransparent")
    mix = tree.nodes.new("ShaderNodeMixShader")
    tree.links.new(geo.outputs["Backfacing"], mix.inputs[0])
    tree.links.new(src, mix.inputs[1])
    tree.links.new(clear_.outputs[0], mix.inputs[2])
    tree.links.new(mix.outputs[0], out.inputs["Surface"])


def arg(args, key, default):
    for a in args:
        if a.startswith("--" + key + "="):
            return a[len(key) + 3 :]
    return default


def turn_all(xs, degrees):
    """Turns every figure about its own upright axis (a three-quarter view
    of each in one orthographic shot)."""
    a = math.radians(degrees)
    for obj in bpy.context.scene.objects:
        if obj.type != "MESH" or obj.name.startswith("Floor") or obj.hide_render:
            continue
        cx = obj.get("fig_x", min(xs, key=lambda x: abs(x - obj.location.x)))
        dx, dy = obj.location.x - cx, obj.location.y
        obj.location.x = cx + dx * math.cos(a) - dy * math.sin(a)
        obj.location.y = dx * math.sin(a) + dy * math.cos(a)
        obj.rotation_euler.z += a


def main():
    args = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    strip = arg(args, "strip", None)
    kind = arg(args, "body", "Boy")
    views = arg(args, "views", "front,three").split(",")
    samples = int(arg(args, "samples", "24"))
    faces_dir = arg(args, "faces", None)
    faces_dir = faces_dir and os.path.abspath(faces_dir)
    out_dir = os.path.abspath(arg(args, "out", os.path.join(ROOT, "build", "scratch", "hair-faces", "preview")))
    os.makedirs(out_dir, exist_ok=True)
    palette = dict(hair.COLOURS)
    if strip:
        styles = [strip] * len(hair.COLOURS)
        colours = [name for name, _ in hair.COLOURS]
    else:
        styles = arg(args, "styles", ",".join(hair.STYLES)).split(",")
        colours = arg(args, "colours", "Chestnut").split(",")
    clear()
    skin = cm.plain("ProxySkin", SKIN, 0.6, bump=0.0, folds=0.0)
    pieces = load_wardrobe(procedural="--dressed=procedural" in args) if any(a.startswith("--dressed") for a in args) else {}
    spacing = 1.9 if strip else 2.6
    xs = []
    report = []
    for i, name in enumerate(styles):
        x = (i - (len(styles) - 1) / 2) * spacing
        xs.append(x)
        face = FACES[kind][i % len(FACES[kind])] if faces_dir else None
        head = figure(kind, x, skin, head_material("HeadSkin%d" % i, face and os.path.join(faces_dir, face + ".png")))
        if pieces:
            dress(pieces, kind, OUTFITS[kind][i % len(OUTFITS[kind])], x)
        colour = palette[colours[i % len(colours)]]
        made = hair.build(name, tint=hair.tint_for(colour))
        if strip:
            # One material a figure (each its own colour).
            for obj in made:
                for slot in obj.material_slots:
                    if slot.material and slot.material.name.startswith("Hair"):
                        slot.material = slot.material.copy()
                        hair.set_tint(slot.material, hair.tint_for(colour))
        for obj in bpy.context.scene.objects:
            if obj.type == "MESH" and "fig_x" not in obj and not obj.hide_render and not obj.name.startswith("Floor"):
                obj["fig_x"] = x
        tris = 0
        for obj in made:
            obj.location = head.location
            tris += sum(len(p.vertices) - 2 for p in obj.data.polygons)
        report.append("%-10s %-14s %6d tris" % (name, colours[i % len(colours)], tris))
    print("HAIR_REPORT")
    print("\n".join(report))
    for mat in bpy.data.materials:
        if mat.node_tree and not mat.name.startswith("ProxySkin") and not mat.name.startswith("HeadSkin"):
            one_sided(mat)
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = samples
    scene.cycles.use_denoising = True
    scene.view_settings.view_transform = "AgX"
    scene.world = bpy.data.worlds.new("World")
    scene.world.color = (0.03, 0.03, 0.035)
    bm = bmesh.new()
    bmesh.ops.create_grid(bm, x_segments=1, y_segments=1, size=40)
    floor = bpy.data.meshes.new("Floor")
    bm.to_mesh(floor)
    bm.free()
    fl = bpy.data.objects.new("Floor", floor)
    scene.collection.objects.link(fl)
    fm = bpy.data.materials.new("FloorMat")
    fm.use_nodes = True
    fm.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.08, 0.05, 0.035, 1)
    floor.materials.append(fm)
    hy = LIFT + HEAD_AT
    light("Key", "AREA", (-6, 10, hy + 6), 2600, (1.0, 0.88, 0.74), 6.0, (0, 0, hy))
    light("Fill", "AREA", (8, 7, hy + 1), 900, (0.75, 0.82, 1.0), 6.0, (0, 0, hy))
    light("Rim", "AREA", (0, -9, hy + 5), 1400, (0.9, 0.9, 1.0), 6.0, (0, 0, hy))
    group = len(xs) if strip else int(arg(args, "group", "4"))
    width = int(arg(args, "width", "2400"))
    tall = 2.3 if strip else 3.0
    turns = {"front": 0, "three": -40, "back": 180, "backthree": 140}
    for g0 in range(0, len(xs), group):
        gx = xs[g0 : g0 + group]
        cx = (gx[0] + gx[-1]) / 2
        gspan = gx[-1] - gx[0] + spacing
        height = int(width * tall / gspan)
        mid = hy - (0.35 if strip else 0.55)
        for view in views:
            scene.render.resolution_x, scene.render.resolution_y = width, height
            # The face looks along +y (the game's -z): the camera stands there.
            camera((cx, 30, mid), (cx, 0, mid), ortho=gspan)
            turn_all(xs, turns[view])
            scene.render.filepath = os.path.join(out_dir, "hair_%s_%s_%s.png" % ("strip_" + strip if strip else kind.lower(), view, g0 // group + 1))
            bpy.ops.render.render(write_still=True)
            turn_all(xs, -turns[view])


main()
