"""Build The Guest in Blender and export him for Roblox Studio's 3D importer
(V5, the Guest remodelled; docs/ART.md "The Guest").

Run from the repository root (Blender 5.2, headless):

    blender.exe -b --factory-startup -P tools/blender/guest.py -- [--preview] [--nobake] [--only=A,B]

Writes build/kit/guest/: guest.glb (his skinned pieces and their rig, the
mask's two shells), the baked maps, report.txt; and the game's side of the
rig, src/shared/Data/GuestRig.luau (generated: his bones and where they
rest, which part each piece rides on, the face's lip columns and poses).
`--preview` also renders him (build/kit/guest/preview_*.png), posed as
Logic/GuestPose poses him (build/kit/guest/poses.json, from
`lune run tools/_guestposes`). `--nobake` skips the bake (a quick look).
`--only=GuestMask,GuestMaskWorn`: export just those pieces (with the whole
rig) to guest_<names>.glb, for the owner to import again without the rest;
only the atlases they wear are baked.

Every bone rests with the game's axes at its head (kitlib/guestrig), so the
game makes a Bone of the same name at the same place (Stalker/StalkerModel)
and the meshes bend with it.
"""

import json
import math
import os
import struct
import sys

import bmesh
import bpy
import numpy as np
from mathutils import Matrix, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

from kitlib import bake, guestbody, guestmask, guestrig  # noqa: E402

ROOT = guestrig.ROOT
OUT = os.path.join(ROOT, "build", "kit", "guest")
DATA = os.path.join(ROOT, "src", "shared", "Data", "GuestRig.luau")

# The front of the mask's atlas: its paint's layout ("Pattern") squeezed
# into this corner; the rest of the atlas holds its back, edges, teeth and
# strap.
FRONT = (0.78, 0.97)


def clear():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete()
    for block in (bpy.data.meshes, bpy.data.materials, bpy.data.images, bpy.data.armatures):
        for item in list(block):
            block.remove(item)


def _select(objects, active=None):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objects:
        o.select_set(True)
    bpy.context.view_layer.objects.active = active or objects[0]


def _tag(obj, index):
    attr = obj.data.attributes.get("piece") or obj.data.attributes.new("piece", "INT", "FACE")
    for d in attr.data:
        d.value = index


def _alone(obj):
    """Hides every other object from the bake (its occlusion would darken
    this one: the mask's shells sit just over its glaze). Returns them."""
    hidden = [o for o in bpy.context.scene.objects if o is not obj and o.type == "MESH" and not o.hide_render]
    for o in hidden:
        o.hide_render = True
    return hidden


def _unhide(hidden):
    for o in hidden:
        o.hide_render = False


def _names(objects):
    """Each mesh's data named as its object (the importer may name its parts
    by either): a split left the data with a .001."""
    for obj in objects:
        if obj.data.name != obj.name:
            taken = bpy.data.meshes.get(obj.name)
            if taken is not None and taken is not obj.data:
                taken.name = obj.name + "_old"
            obj.data.name = obj.name


def _join(objects, name):
    _select(objects)
    bpy.ops.object.join()
    obj = bpy.context.view_layer.objects.active
    obj.name = name
    obj.data.name = name
    return obj


def _split(obj, names):
    """Splits a joined, baked object back into its pieces by their tags."""
    out = {}
    for index, name in enumerate(names):
        if index == len(names) - 1:
            break
        _select([obj])
        bpy.ops.object.mode_set(mode="EDIT")
        bm = bmesh.from_edit_mesh(obj.data)
        bm.select_mode = {"FACE"}
        layer = bm.faces.layers.int.get("piece")
        for v in bm.verts:
            v.select_set(False)
        for f in bm.faces:
            f.select_set(f[layer] == index)
        bm.select_flush_mode()
        bmesh.update_edit_mesh(obj.data)
        bpy.ops.mesh.separate(type="SELECTED")
        bpy.ops.object.mode_set(mode="OBJECT")
        new = [o for o in bpy.context.selected_objects if o is not obj][0]
        new.name = name
        new.data.name = name
        out[name] = new
    obj.name = names[-1]
    obj.data.name = names[-1]
    out[names[-1]] = obj
    return out


def _mask_layout(obj):
    """The mask's bake layout: the glaze by its paint's layout in FRONT, the
    rest packed into the strip beside it."""
    layers = obj.data.uv_layers
    pattern = layers["Pattern"]
    bake_uv = layers.get("BakeUV") or layers.new(name="BakeUV")
    layers.active = bake_uv
    _select([obj])
    bpy.ops.object.mode_set(mode="EDIT")
    bm = bmesh.from_edit_mesh(obj.data)
    uv_bake = bm.loops.layers.uv["BakeUV"]
    uv_pat = bm.loops.layers.uv["Pattern"]
    bm.select_mode = {"FACE"}
    for v in bm.verts:
        v.select_set(False)
    for f in bm.faces:
        front = f.material_index == 0
        f.select_set(not front)
        if front:
            for loop in f.loops:
                u, v = loop[uv_pat].uv
                loop[uv_bake].uv = (u * FRONT[0], v * FRONT[1])
    bm.select_flush_mode()
    bmesh.update_edit_mesh(obj.data)
    bpy.ops.uv.smart_project(angle_limit=math.radians(60), island_margin=0.01, scale_to_bounds=False)
    bm = bmesh.from_edit_mesh(obj.data)
    uv_bake = bm.loops.layers.uv["BakeUV"]
    rest = [f for f in bm.faces if f.material_index != 0]
    us = [l[uv_bake].uv for f in rest for l in f.loops]
    lo_u, hi_u = min(p.x for p in us), max(p.x for p in us)
    lo_v, hi_v = min(p.y for p in us), max(p.y for p in us)
    for p in us:
        p.x = 0.8 + (p.x - lo_u) / max(hi_u - lo_u, 1e-6) * 0.2
        p.y = (p.y - lo_v) / max(hi_v - lo_v, 1e-6)
    bmesh.update_edit_mesh(obj.data)
    bpy.ops.uv.pack_islands(udim_source="ORIGINAL_AABB", rotate=True, scale=True, margin=0.01)
    bpy.ops.object.mode_set(mode="OBJECT")
    del pattern


def _overlay_material(name, rgba, size=1024):
    """A shell's look: its RGBA paint laid into FRONT of the atlas, the rest
    clear."""
    n = rgba.shape[0]
    # The paint (row 0 at the top) down to the atlas's front, row 0 at the
    # bottom as Blender keeps pixels.
    atlas = np.zeros((size, size, 4))
    fw, fh = int(size * FRONT[0]), int(size * FRONT[1])
    rows = (np.arange(fh) + 0.5) / fh  # v up the front
    cols = (np.arange(fw) + 0.5) / fw
    src_r = np.clip(((1 - rows) * n).astype(int), 0, n - 1)
    src_c = np.clip((cols * n).astype(int), 0, n - 1)
    atlas[:fh, :fw] = rgba[src_r][:, src_c]
    img = bpy.data.images.new(name + "_color", size, size, alpha=True)
    img.colorspace_settings.name = "sRGB"
    img.pixels.foreach_set(atlas.astype(np.float32).ravel())
    img.update()
    path = os.path.join(OUT, name + "_color.png")
    img.filepath_raw = path
    img.file_format = "PNG"
    img.save()
    mat = bpy.data.materials.new(name + "_baked")
    mat.use_nodes = True
    nodes, links = mat.node_tree.nodes, mat.node_tree.links
    bsdf = [nd for nd in nodes if nd.type == "BSDF_PRINCIPLED"][0]
    tex = nodes.new("ShaderNodeTexImage")
    tex.image = img
    links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    links.new(tex.outputs["Alpha"], bsdf.inputs["Alpha"])
    bsdf.inputs["Roughness"].default_value = 0.6
    try:
        mat.surface_render_method = "BLENDED"
    except (AttributeError, TypeError):
        mat.blend_method = "BLEND"
    return mat


def _shell_layout(obj, mat):
    layers = obj.data.uv_layers
    bake_uv = layers.get("BakeUV") or layers.new(name="BakeUV")
    pattern = layers["Pattern"]
    for loop in obj.data.loops:
        u, v = pattern.data[loop.index].uv
        bake_uv.data[loop.index].uv = (u * FRONT[0], v * FRONT[1])
    bake.keep_bake_uv(obj)
    obj.data.materials.clear()
    obj.data.materials.append(mat)


def _box(obj):
    lo, hi = None, None
    for v in obj.data.vertices:
        g = Vector(guestrig.B2G(obj.matrix_world @ v.co))
        lo = g.copy() if lo is None else Vector((min(lo.x, g.x), min(lo.y, g.y), min(lo.z, g.z)))
        hi = g.copy() if hi is None else Vector((max(hi.x, g.x), max(hi.y, g.y), max(hi.z, g.z)))
    return lo, hi


def _triangles(obj):
    return sum(len(p.vertices) - 2 for p in obj.data.polygons)


# The glb, read back ----------------------------------------------------------------


def read_glb(path):
    with open(path, "rb") as f:
        data = f.read()
    magic, version, length = struct.unpack_from("<III", data, 0)
    off = 12
    chunks = []
    while off < length:
        clen, ctype = struct.unpack_from("<II", data, off)
        chunks.append((ctype, data[off + 8 : off + 8 + clen]))
        off += 8 + clen
    doc = json.loads(chunks[0][1].decode("utf-8"))
    binary = chunks[1][1] if len(chunks) > 1 else b""
    return doc, binary


def joint_rest(doc, binary):
    """{joint name: its rest position} from the skins' inverse bind matrices
    (what the importer binds the meshes to), and the most any joint is
    turned at rest (degrees: it should be none)."""
    out = {}
    worst = 0.0
    for skin in doc.get("skins", []):
        acc = doc["accessors"][skin["inverseBindMatrices"]]
        view = doc["bufferViews"][acc["bufferView"]]
        start = view.get("byteOffset", 0) + acc.get("byteOffset", 0)
        mats = np.frombuffer(binary, dtype="<f4", count=16 * acc["count"], offset=start).reshape(-1, 4, 4)
        for joint, m in zip(skin["joints"], mats):
            inv = Matrix([list(m[:, i]) for i in range(4)])  # glTF is column-major
            world = inv.inverted()
            name = doc["nodes"][joint]["name"]
            out[name] = Vector(world.translation)
            rot = world.to_3x3()
            angle = math.degrees(rot.to_quaternion().angle)
            worst = max(worst, angle)
    return out, worst


# The game's data -----------------------------------------------------------------------


def _v(p, digits=4):
    return "{ %s }" % ", ".join(("%." + str(digits) + "f") % c for c in p)


def game_parent(bone, parent):
    """Where the game hangs a bone: a part (a Bone under it) or a bone."""
    if bone.startswith("g") and bone[1:] in guestrig.PARTS:
        return bone[1:], True
    if bone == "fMask":
        return "Mask", True
    if bone.startswith("g") and bone.endswith("1") and not bone.endswith("e"):
        side = "Left" if bone[1] == "L" else "Right"
        return side + "Hand", True
    return parent, False


def write_data(bones, pieces, report):
    lines = [
        "-- The Guest's rig (V5, the Guest remodelled), generated by tools/blender/guest.py",
        "-- from Logic/GuestPose's Rig: don't edit by hand, run it again.",
        "--",
        "-- Bones: every bone his meshes bend with, in the order to make them; each hangs",
        "-- under a part (`part`: a Bone under it) or another bone (`bone`), `at` its",
        "-- rest place in the model as Stalker/StalkerModel builds him (standing on y = 0",
        "-- at the origin, facing -Z), with no turn. Pieces: each mesh (Data/Kit's Guest",
        "-- group has its id), the part it's welded to, its box's middle at rest, and its",
        "-- look (a SurfaceAppearance in ReplicatedStorage.Kit). Face: the mask, in its own",
        "-- frame (mask-local, about its centre; `centre` is where that sits on the head):",
        "-- its eyes' pins, the grin's columns (Lib/GuestMask parts the lips along `up`),",
        "-- and the poses (bone -> move studs, turn degrees) it blends.",
        "",
        "return {",
        "\tBones = {",
    ]
    for bone, parent, at, _ in bones:
        where, is_part = game_parent(bone, parent)
        key = "part" if is_part else "bone"
        lines.append('\t\t{ name = "%s", %s = "%s", at = %s },' % (bone, key, where, _v(at)))
    lines.append("\t},")
    lines.append("\tPieces = {")
    for name in sorted(pieces):
        p = pieces[name]
        extra = ""
        if p.get("overlay"):
            extra = ', overlay = "%s"' % p["overlay"]
        if p.get("shard"):
            extra = ', shard = "%s"' % p["shard"]
        lines.append(
            '\t\t%s = { part = "%s", centre = %s, size = %s, look = "%s"%s },'
            % (name, p["part"], _v(p["centre"]), _v(p["size"]), p["look"], extra)
        )
    lines.append("\t},")
    centre = guestmask.CENTRE - Vector((0, guestrig.RIG["headY"], 0))
    lines.append("\tFace = {")
    lines.append("\t\tcentre = %s, -- the mask's centre from the head's" % _v(centre))
    pins = guestmask.eye_pins()
    lines.append("\t\teyes = { L = %s, R = %s }," % (_v(pins["L"]), _v(pins["R"])))
    lines.append("\t\teyeRadius = %.3f," % guestmask.EYE_R)
    lines.append("\t\tcolumns = {")
    for col in guestmask.columns():
        lines.append("\t\t\t{ theta = %.4f, up = %s, out = %s }," % (col["theta"], _v(col["up"]), _v(col["out"])))
    lines.append("\t\t},")
    lines.append("\t\tposes = {")
    for pose in sorted(guestmask.POSES):
        lines.append("\t\t\t%s = {" % pose)
        for bone in sorted(guestmask.POSES[pose]):
            move, turn = guestmask.POSES[pose][bone]
            t = ", turn = %s" % _v(turn, 1) if turn else ""
            lines.append("\t\t\t\t%s = { move = %s%s }," % (bone, _v(move), t))
        lines.append("\t\t\t},")
    lines.append("\t\t},")
    lines.append("\t},")
    lines.append("\tFingers = {")
    for side in ("Left", "Right"):
        for name, knuckle, middle, tip, tilt, scale in guestrig.finger_layout(side):
            e = tilt.to_euler("ZYX")  # (CFrame.Angles order)
            lines.append(
                '\t\t{ hand = "%s", finger = "%s", bones = "g%s%s", first = %.4f, second = %.4f, tilt = %s },'
                % (side, name, side[0], name, (middle - knuckle).length, (tip - middle).length, _v((e.x, e.y, e.z)))
            )
    lines.append("\t},")
    lines.append("}")
    with open(DATA, "w", newline="\n") as f:
        f.write("\n".join(lines) + "\n")
    report.append("wrote " + os.path.relpath(DATA, ROOT))


# Previews ------------------------------------------------------------------------------


JOINT_PART = {
    "Root": "LowerTorso",
    "Waist": "UpperTorso",
    "Neck": "Head",
}
for _s in ("Left", "Right"):
    JOINT_PART.update(
        {
            _s + "Shoulder": _s + "UpperArm",
            _s + "Elbow": _s + "LowerArm",
            _s + "Wrist": _s + "Hand",
            _s + "Hip": _s + "UpperLeg",
            _s + "Knee": _s + "LowerLeg",
            _s + "Ankle": _s + "Foot",
        }
    )


def pose_rig(arm, values=None, face=None):
    """Poses the rig: values = GuestPose joint values ({joint: {rx, ry, rz,
    px, py, pz}}); face = {bone: (move, turn degrees)}."""
    for pb in arm.pose.bones:
        pb.rotation_mode = "ZYX"
        pb.rotation_euler = (0, 0, 0)
        pb.location = (0, 0, 0)
    for joint, v in (values or {}).items():
        part = JOINT_PART.get(joint)
        if part and ("g" + part) in arm.pose.bones:
            pb = arm.pose.bones["g" + part]
            pb.rotation_euler = (v[0], v[1], v[2])
            pb.location = (v[3], v[4], v[5])
    for bone, (move, turn) in (face or {}).items():
        if bone in arm.pose.bones:
            pb = arm.pose.bones[bone]
            pb.location = Vector(pb.location) + Vector(move)
            if turn:
                pb.rotation_euler = tuple(math.radians(t) for t in turn)
    bpy.context.view_layer.update()


def face_state(form, width_deg, opening, smile=0.0, brow=0.0, wide=0.0, droop=0.0, jaw=0.0):
    """A face for the previews: the same sums the game makes."""
    out = {}

    def add(pose, k):
        if k <= 0:
            return
        for bone, (move, turn) in guestmask.POSES[pose].items():
            m0, t0 = out.get(bone, ((0, 0, 0), (0, 0, 0)))
            m = tuple(a + b * k for a, b in zip(m0, move))
            t = tuple(a + b * k for a, b in zip(t0, turn or (0, 0, 0)))
            out[bone] = (m, t)

    add("Smile", smile)
    add("BrowUp", brow)
    add("Wide", wide)
    add("Droop", droop)
    add("JawOpen", jaw)
    for bone, (move, _) in guestmask.lip_pose(math.radians(width_deg), opening).items():
        m0, t0 = out.get(bone, ((0, 0, 0), (0, 0, 0)))
        out[bone] = (tuple(a + b for a, b in zip(m0, move)), t0)
    return out


def _light(name, kind, location, energy, colour, size=1.0, target=None):
    data = bpy.data.lights.new(name, kind)
    data.energy = energy
    data.color = colour
    if kind == "AREA":
        data.size = size
    obj = bpy.data.objects.new(name, data)
    bpy.context.scene.collection.objects.link(obj)
    obj.location = location
    if target is not None:
        direction = Vector(target) - Vector(location)
        obj.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
    return obj


def _camera(location, target, lens=50):
    data = bpy.data.cameras.new("Cam")
    data.lens = lens
    cam = bpy.data.objects.new("Cam", data)
    bpy.context.scene.collection.objects.link(cam)
    cam.location = location
    cam.rotation_euler = (Vector(target) - Vector(location)).to_track_quat("-Z", "Y").to_euler()
    bpy.context.scene.camera = cam
    return cam


def previews(arm, objects, poses):
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = 40
    scene.cycles.use_denoising = True
    scene.view_settings.view_transform = "AgX"
    scene.world.color = (0.006, 0.006, 0.008)
    floor = bpy.data.meshes.new("Floor")
    bm = bmesh.new()
    bmesh.ops.create_grid(bm, x_segments=1, y_segments=1, size=12)
    bm.to_mesh(floor)
    bm.free()
    fl = bpy.data.objects.new("Floor", floor)
    scene.collection.objects.link(fl)
    fm = bpy.data.materials.new("FloorMat")
    fm.use_nodes = True
    fm.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.05, 0.035, 0.025, 1)
    fm.node_tree.nodes["Principled BSDF"].inputs["Roughness"].default_value = 0.6
    floor.materials.append(fm)
    # A warm lamp from the front-left, a cold fill, a rim behind.
    G = guestrig.G2B
    _light("Key", "AREA", G((-2.5, 7.5, -4.5)), 900, (1.0, 0.78, 0.55), 2.0, G((0, 5, 0)))
    _light("Fill", "AREA", G((3.5, 4.0, -3.0)), 150, (0.55, 0.65, 0.9), 3.0, G((0, 4, 0)))
    _light("Rim", "AREA", G((1.0, 8.0, 4.0)), 500, (0.8, 0.85, 1.0), 2.0, G((0, 6, 0)))
    shells = {o.name: o for o in objects if o.name in ("GuestMaskWorn", "GuestMaskBroken")}
    shards = [o for o in objects if o.name.startswith("GuestShard")]
    tatters = [o for o in objects if "Tatters" in o.name]

    def form(level):
        shells["GuestMaskWorn"].hide_render = level < 1
        shells["GuestMaskBroken"].hide_render = level < 2
        for s in shards:
            s.hide_render = level >= 2
        for t in tatters:
            t.hide_render = level < 2

    def shot(name, cam_at, target, res=(720, 960), lens=50):
        scene.render.resolution_x, scene.render.resolution_y = res
        _camera(cam_at, target, lens)
        scene.render.filepath = os.path.join(OUT, "preview_" + name + ".png")
        bpy.ops.render.render(write_still=True)

    face_at = guestmask.CENTRE + Vector((0, 0.02, 0))
    fb = guestrig.G2B(face_at)
    # The whole of him.
    form(0)
    pose_rig(arm, poses.get("Idle"), face_state(0, 62, 0.05))
    shot("body_front", guestrig.G2B((0.6, 5.0, -9.0)), guestrig.G2B((0, 4.4, 0)), lens=38)
    shot("body_threequarter", guestrig.G2B((-5.5, 5.4, -7.0)), guestrig.G2B((0, 4.4, 0)), lens=38)
    pose_rig(arm, poses.get("Reach"), face_state(1, 96, 0.55, smile=1.0, brow=0.4))
    form(1)
    shot("body_reach", guestrig.G2B((2.2, 6.0, -7.5)), guestrig.G2B((0, 5.0, 0)), lens=38)
    form(2)
    pose_rig(arm, poses.get("Crawl"), face_state(2, 104, 0.7, smile=0.7, droop=1.0))
    shot("body_crawl", guestrig.G2B((-5.0, 3.0, -6.0)), guestrig.G2B((0, 2.0, 0)), lens=38)
    # His face, by form, and the catch.
    pose_rig(arm, None, None)
    cam = guestrig.G2B(face_at + Vector((0.25, 0.08, -1.6)))
    for name, level, face in (
        ("face_calm", 0, face_state(0, 62, 0.05)),
        ("face_fraying", 1, face_state(1, 96, 0.55, smile=1.0, brow=0.5)),
        ("face_breaking", 2, face_state(2, 104, 0.7, smile=0.7, droop=1.0)),
        ("face_catch", 2, face_state(2, 110, 1.0, smile=1.0, wide=1.0, droop=0.6, jaw=1.0)),
    ):
        form(level)
        pose_rig(arm, None, face)
        shot(name, cam, fb, res=(720, 720), lens=60)
    form(1)
    pose_rig(arm, poses.get("Idle"), face_state(1, 96, 0.5, smile=0.8, brow=0.3))
    shot("face_below", guestrig.G2B((0.4, 5.0, -4.0)), guestrig.G2B((0, 7.3, 0)), res=(720, 960), lens=45)
    form(0)
    pose_rig(arm, None, face_state(0, 62, 0.05))
    shot("face_side", guestrig.G2B(face_at + Vector((-1.3, 0.1, -0.8))), fb, res=(720, 720), lens=60)
    # The hands, held up.
    pose_rig(arm, poses.get("Reach"), None)
    shot("hands", guestrig.G2B((1.2, 6.2, -4.2)), guestrig.G2B((0, 5.6, -1.8)), res=(960, 720), lens=40)


# Main -------------------------------------------------------------------------------------


def main():
    args = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    preview = "--preview" in args
    nobake = "--nobake" in args
    only = set()
    for a in args:
        if a.startswith("--only="):
            only = set(a[len("--only=") :].split(","))
    os.makedirs(OUT, exist_ok=True)
    clear()
    report = []
    rng = np.random.default_rng(7)

    bones = guestrig.body_bones() + guestmask.all_bones()
    arm = guestrig.build_armature(bones)

    body = guestbody.pieces()  # [(obj, part)]
    mask, _ = guestmask.build(rng)
    shells = {k: v for k, v in mask.items() if v.get("overlay")}
    mask_set = [mask["GuestMask"]] + [v for k, v in mask.items() if k.startswith("GuestShard")]

    pieces = {}
    for obj, part in body:
        pieces[obj.name] = {"obj": obj, "part": part, "look": "GuestBody"}
    for obj in mask_set:
        pieces[obj.name] = {"obj": obj, "part": "Mask", "look": "GuestMask"}
        if obj.name.startswith("GuestShard"):
            key = obj.name[-1]
            pieces[obj.name]["shard"] = guestmask.SHARD_BONE[key]
    for name, obj in shells.items():
        pieces[name] = {"obj": obj, "part": "Mask", "look": name, "overlay": obj["overlay"]}
    # The dark behind the eye holes and the grin: no look (the game draws it
    # black and unlit).
    void = mask["GuestMaskVoid"]
    black = bpy.data.materials.new("GuestVoid_flat")
    black.use_nodes = True
    bsdf = black.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = (0, 0, 0, 1)
    bsdf.inputs["Roughness"].default_value = 1.0
    bsdf.inputs["Specular IOR Level"].default_value = 0.0
    void.data.materials.clear()
    void.data.materials.append(black)
    for p in void.data.polygons:
        p.material_index = 0
    for layer in list(void.data.uv_layers):
        void.data.uv_layers.remove(layer)
    pieces["GuestMaskVoid"] = {"obj": void, "part": "Mask", "look": "Void"}

    # Bake: the body as one atlas, the mask as another; the shells carry
    # their paint as drawn.
    wanted = lambda name: not only or name in only  # noqa: E731
    if not nobake and any(wanted(obj.name) for obj, _ in body):
        names = [obj.name for obj, _ in body]
        for i, (obj, _) in enumerate(body):
            _tag(obj, i)
        joined = _join([obj for obj, _ in body], "GuestBody")
        bake.unwrap(joined)
        hidden = _alone(joined)
        bake.bake_piece(joined, OUT, size=1024)
        _unhide(hidden)
        split = _split(joined, names)
        for name, obj in split.items():
            pieces[name]["obj"] = obj
    if not nobake and any(wanted(obj.name) for obj in mask_set):
        names = [o.name for o in mask_set]
        for i, obj in enumerate(mask_set):
            _tag(obj, i)
        joined = _join(mask_set, "GuestMaskSet")
        _mask_layout(joined)
        hidden = _alone(joined)
        # (Little occlusion: at rest the teeth and the grin's edges are shut
        # inside the porcelain, and they show only when it opens.)
        bake.bake_piece(joined, OUT, size=1024, ao_strength=0.2)
        _unhide(hidden)
        split = _split(joined, names)
        for name, obj in split.items():
            pieces[name]["obj"] = obj
    for name, obj in shells.items():
        rgba = guestmask.overlay_worn() if obj["overlay"] == "worn" else guestmask.overlay_broken()
        _shell_layout(obj, _overlay_material(name, rgba))
    for name, p in pieces.items():
        guestrig.attach(p["obj"], arm)
        lo, hi = _box(p["obj"])
        p["centre"] = (lo + hi) / 2
        p["size"] = hi - lo
        report.append("%-22s on %-14s %6d triangles  box %.2f x %.2f x %.2f" % (name, p["part"], _triangles(p["obj"]), *p["size"]))

    # Export: the rig and every piece (or the ones asked for).
    objects = [p["obj"] for p in pieces.values()]
    _names(objects)
    chosen = [p["obj"] for name, p in pieces.items() if wanted(name)]
    _select([arm] + chosen, arm)
    glb = os.path.join(OUT, "guest.glb" if not only else "guest_" + "_".join(sorted(only)) + ".glb")
    bpy.ops.export_scene.gltf(
        filepath=glb,
        export_format="GLB",
        use_selection=True,
        export_yup=True,
        export_skins=True,
        export_animations=False,
        export_morph=False,
        export_attributes=False,
    )
    report.append("wrote " + os.path.relpath(glb, ROOT))
    doc, binary = read_glb(glb)
    rest, worst = joint_rest(doc, binary)
    off = 0.0
    for bone, _, at, _ in bones:
        if bone in rest:
            # (glTF's frame is the game's: export_yup turns Blender's back.)
            off = max(off, (rest[bone] - Vector(at)).length)
    report.append("joints in the glb: %d of %d; furthest from the rig %.5f studs; most turned at rest %.3f deg" % (len(rest), len(bones), off, worst))
    report.append("meshes: %d, skins: %d, materials: %d, images: %d" % (len(doc.get("meshes", [])), len(doc.get("skins", [])), len(doc.get("materials", [])), len(doc.get("images", []))))
    write_data(bones, {k: v for k, v in pieces.items()}, report)
    with open(os.path.join(OUT, "report.txt"), "w") as f:
        f.write("\n".join(report) + "\n")
    print("GUEST_REPORT")
    print("\n".join(report))
    if preview:
        poses = {}
        path = os.path.join(OUT, "poses.json")
        if os.path.exists(path):
            with open(path) as f:
                poses = json.load(f)
        previews(arm, objects, poses)
        print("previews written")


main()
