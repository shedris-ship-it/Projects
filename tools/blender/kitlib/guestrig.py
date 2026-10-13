"""The Guest's rig for the Blender model (V5, the Guest remodelled).

Everything here is in the game's frame: studs, +Y up, -Z where he faces, +X
his right, standing on y = 0 at the origin, as Stalker/StalkerModel builds
him. Blender's frame is (x, -z, y) of it (G2B), so the glTF the importer
reads is the game's frame itself.

The proportions come from the game: Logic/GuestPose's Rig and
Config.Guest.CoatHem, read from the source so the model can't drift from
the joints that move it.

Bones (all in their rest pose with no turn, so a bone's frame is the
game's axes at its head):
  - one per joint part, named "g" + the part ("gLeftUpperArm"), its head at
    the part's joint (the one its Motor6D turns it about); the game makes a
    Bone of that name under the part (Stalker/StalkerModel);
  - three per finger ("gLIndex1" at the knuckle, 2 at the middle joint, 3 at
    the tip), as Lib/GuestFace laid out the old fingers;
  - the face's ("f..."), under the mask (kitlib/guestmask).
"""

import math
import os
import re

import bpy
from mathutils import Matrix, Vector

ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", ".."))


def _read(path):
    with open(os.path.join(ROOT, path), encoding="utf-8") as f:
        return f.read()


def read_rig():
    """GuestPose.Rig as a dict (numbers and lists of numbers), with headY,
    and Config.Guest's CoatHem and FingerScale."""
    source = _read("src/shared/Logic/GuestPose.luau")
    block = re.search(r"GuestPose\.Rig = \{(.*?)\n\}", source, re.S).group(1)
    rig = {}
    for key, value in re.findall(r"^\s*(\w+) = ([^,\n]+(?:,[^\n]*\})?),", block, re.M):
        value = value.strip()
        if value.startswith("{"):
            rig[key] = [float(v) for v in value.strip("{} ").split(",")]
        else:
            rig[key] = float(value)
    rig["headY"] = rig["neckY"] + rig["neckLength"] + rig["headSize"][1] / 2
    config = _read("src/shared/Config.luau")
    rig["coatHem"] = float(re.search(r"CoatHem = ([\d.]+)", config).group(1))
    scales = re.search(r"FingerScale = \{([^}]*)\}", config).group(1)
    rig["fingerScale"] = [float(v) for v in scales.split(",")]
    return rig


RIG = read_rig()


def G2B(p):
    """A point in the game's frame to Blender's."""
    return Vector((p[0], -p[2], p[1]))


def B2G(v):
    return (v[0], v[2], -v[1])


# The game's frame to Blender's as a matrix (for turning poses over).
GAME_TO_BLENDER = Matrix(((1, 0, 0), (0, 0, -1), (0, 1, 0)))


def euler_xyz(rx, ry, rz):
    """CFrame.Angles(rx, ry, rz) (Rx * Ry * Rz) as a 3x3, in the game's frame."""
    return Matrix.Rotation(rx, 3, "X") @ Matrix.Rotation(ry, 3, "Y") @ Matrix.Rotation(rz, 3, "Z")


# Parts and joints ------------------------------------------------------------


def parts():
    """Each joint part's rest centre and its joint (game frame), as
    Stalker/StalkerModel builds them: name -> (centre, joint, parent part)."""
    r = RIG
    out = {}
    out["LowerTorso"] = ((0, r["lowerTorsoY"], 0), (0, r["lowerTorsoY"], 0), None)
    upper_h = r["upperTorsoSize"][1]
    out["UpperTorso"] = ((0, r["waistY"] + upper_h / 2, 0), (0, r["waistY"], 0), "LowerTorso")
    out["Head"] = ((0, r["headY"], 0), (0, r["neckY"], 0), "UpperTorso")
    for side, sx in (("Left", -1), ("Right", 1)):
        shoulder = (sx * r["shoulderX"], r["shoulderY"], 0)
        elbow = (shoulder[0], shoulder[1] - r["upperArm"], 0)
        wrist = (elbow[0], elbow[1] - r["lowerArm"], 0)
        hip = (sx * r["hipX"], r["hipY"], 0)
        knee = (hip[0], hip[1] - r["upperLeg"], 0)
        ankle = (knee[0], knee[1] - r["lowerLeg"], 0)
        foot = r["footSize"]
        out[side + "UpperArm"] = ((shoulder[0], shoulder[1] - r["upperArm"] / 2, 0), shoulder, "UpperTorso")
        out[side + "LowerArm"] = ((elbow[0], elbow[1] - r["lowerArm"] / 2, 0), elbow, side + "UpperArm")
        out[side + "Hand"] = ((wrist[0], wrist[1] - r["hand"] / 2, 0), wrist, side + "LowerArm")
        out[side + "UpperLeg"] = ((hip[0], hip[1] - r["upperLeg"] / 2, 0), hip, "LowerTorso")
        out[side + "LowerLeg"] = ((knee[0], knee[1] - r["lowerLeg"] / 2, 0), knee, side + "UpperLeg")
        out[side + "Foot"] = ((ankle[0], foot[1] / 2, -0.3), ankle, side + "LowerLeg")
        out[side + "CoatTail"] = (hip, hip, "LowerTorso")
    return out


PARTS = parts()


def joint(name):
    return Vector(PARTS[name][1])


def centre(name):
    return Vector(PARTS[name][0])


# Fingers: Lib/GuestFace.hand's layout -----------------------------------------

FINGERS = ("Index", "Middle", "Ring", "Pinky", "Thumb")
THUMB_TILT = (math.radians(-25), 0.0, math.radians(25))  # times `inward` on z


def finger_layout(side):
    """Per finger: (name, knuckle, middle, tip, tilt) in the game's frame at
    rest (straight), and the tilt (a 3x3: the finger runs along tilt * -Y).
    As GuestFace.hand: the knuckles in a row across the hand (front to back
    as it hangs), the thumb at the front edge, turned in."""
    r = RIG
    hand_centre = centre(side + "Hand")
    inward = 1 if side == "Left" else -1
    base = -r["hand"] / 2 + 0.04
    l1, l2 = r["finger"]
    layout = [
        (0.0, base, -0.075, 0.96),
        (0.0, base, -0.025, 1.06),
        (0.0, base, 0.025, 1.0),
        (0.0, base, 0.072, 0.84),
        (inward * 0.04, base + 0.22, -0.1, 0.7),
    ]
    out = []
    for name, (x, y, z, scale) in zip(FINGERS, layout):
        tilt = Matrix.Identity(3)
        if name == "Thumb":
            tilt = euler_xyz(THUMB_TILT[0], THUMB_TILT[1], inward * THUMB_TILT[2])
        down = tilt @ Vector((0, -1, 0))
        knuckle = hand_centre + Vector((x, y, z))
        middle = knuckle + down * (l1 * scale - 0.04)
        tip = middle + down * (l2 * scale - 0.01)
        out.append((name, knuckle, middle, tip, tilt, scale))
    return out


# Bones ------------------------------------------------------------------------

BODY = [
    "LowerTorso",
    "UpperTorso",
    "Head",
    "LeftUpperArm",
    "LeftLowerArm",
    "LeftHand",
    "RightUpperArm",
    "RightLowerArm",
    "RightHand",
    "LeftUpperLeg",
    "LeftLowerLeg",
    "LeftFoot",
    "RightUpperLeg",
    "RightLowerLeg",
    "RightFoot",
    "LeftCoatTail",
    "RightCoatTail",
]


def body_bones():
    """[(bone, parent bone, head (game), part it rides on)]"""
    out = []
    for name in BODY:
        parent = PARTS[name][2]
        out.append(("g" + name, parent and "g" + parent, joint(name), name))
    for side in ("Left", "Right"):
        s = side[0]
        for name, knuckle, middle, tip, _, _ in finger_layout(side):
            # 1 bends at the knuckle; 1e, at the middle joint, is where the
            # first segment ends (it moves out as the finger grows, so the
            # segment stretches evenly); 2 bends at the middle joint; 3 is
            # the tip (it moves out as the finger grows).
            k = "g%s%s" % (s, name)
            out.append((k + "1", "g%sHand" % side, knuckle, side + "Hand"))
            out.append((k + "1e", k + "1", middle, side + "Hand"))
            out.append((k + "2", k + "1e", middle, side + "Hand"))
            out.append((k + "3", k + "2", tip, side + "Hand"))
    return out


def build_armature(bones, name="GuestRig"):
    """An armature with every bone at its head pointing up the game's +Y
    (Blender's +Z) with no roll: each bone's frame is the game's axes, so
    a pose in the game (CFrame.Angles about a joint) is the same rotation
    of the pose bone, and the glTF's joints carry no turn."""
    data = bpy.data.armatures.new(name)
    arm = bpy.data.objects.new(name, data)
    bpy.context.scene.collection.objects.link(arm)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.select_all(action="DESELECT")
    arm.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    made = {}
    for bone, parent, head, _ in bones:
        eb = data.edit_bones.new(bone)
        h = G2B(head)
        eb.head = h
        eb.tail = h + Vector((0, 0, 0.05))
        eb.roll = 0.0
        eb.use_deform = True
        if parent:
            eb.parent = made[parent]
            eb.use_connect = False
        made[bone] = eb
    bpy.ops.object.mode_set(mode="OBJECT")
    return arm


def weigh(obj, fn):
    """Skin weights for every vertex of obj from fn(game point) -> {bone:
    weight}, as vertex groups; each vertex keeps its four strongest (glTF's
    limit, and Roblox's), normalised. Done per piece before pieces are
    joined (joining keeps the groups), so a palm never takes a finger's."""
    obj.vertex_groups.clear()
    groups = {}
    for v in obj.data.vertices:
        g_point = Vector(B2G(obj.matrix_world @ v.co))
        w = fn(g_point)
        top = sorted(((x, b) for b, x in w.items() if x > 1e-4), reverse=True)[:4]
        total = sum(x for x, _ in top) or 1.0
        for x, b in top:
            g = groups.get(b)
            if g is None:
                g = groups[b] = obj.vertex_groups.new(name=b)
            g.add([v.index], x / total, "REPLACE")
    return obj


def attach(obj, arm):
    """Skins obj (weighed) to the armature."""
    mod = obj.modifiers.new("Armature", "ARMATURE")
    mod.object = arm
    obj.parent = arm
    return obj


def smoothstep(e0, e1, x):
    if e0 == e1:
        return 1.0 if x >= e1 else 0.0
    t = max(0.0, min(1.0, (x - e0) / (e1 - e0)))
    return t * t * (3 - 2 * t)


def chain(y, links):
    """Weights down a hanging chain by height: links = [(bone, y_from, y_to)]
    from the top; each joint blends over `blend` either side. Returns
    {bone: weight}."""
    out = {}
    for i, (bone, top, bottom, blend) in enumerate(links):
        w = 1.0
        if i > 0:
            w *= smoothstep(top + blend, top - blend, y)
        if i < len(links) - 1:
            w *= smoothstep(bottom - blend, bottom + blend, y)
        if w > 0:
            out[bone] = out.get(bone, 0) + w
    return out
