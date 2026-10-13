"""Render each piece of a batch's exported .glb on its own, under one warm
lamp from the front-left and a faint cool fill, to judge the kit before it
goes to Studio (the visual rework).

    blender -b --factory-startup -P tools/blender/preview.py -- golden

Writes build/kit/<batch>/preview_<piece>.png, one per piece, framed to it.
`--only=Name,Name`: only those pieces. `--behind`: seen from the game's -z instead (the things on a top face the
room down -z: World/Dressing). `--backfaces`: a face seen from behind shows
red (Studio draws only a face's front: a red patch would be a hole).
(Tile them with any image tool; Claude uses Pillow in a scratch venv.)
"""

import math
import os
import sys

import bpy
from mathutils import Vector

ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
args = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else ["spike"]
behind = "--behind" in args
# `--only=Name,Name`: just those pieces.
only = set()
for a in args:
    if a.startswith("--only="):
        only = set(a[len("--only=") :].split(","))
backfaces = "--backfaces" in args
batch = [a for a in args if not a.startswith("--")][0]
folder = os.path.join(ROOT, "build", "kit", batch)

bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete()
bpy.ops.import_scene.gltf(filepath=os.path.join(folder, batch + ".glb"))
pieces = [o for o in bpy.context.scene.objects if o.type == "MESH" and (not only or o.name in only)]
if backfaces:
    for mat in bpy.data.materials:
        if not mat.use_nodes:
            continue
        tree = mat.node_tree
        out = [n for n in tree.nodes if n.type == "OUTPUT_MATERIAL"][0]
        surface = out.inputs["Surface"].links[0].from_socket
        geo = tree.nodes.new("ShaderNodeNewGeometry")
        red = tree.nodes.new("ShaderNodeEmission")
        red.inputs["Color"].default_value = (1.0, 0.0, 0.0, 1.0)
        mix = tree.nodes.new("ShaderNodeMixShader")
        tree.links.new(geo.outputs["Backfacing"], mix.inputs["Fac"])
        tree.links.new(surface, mix.inputs[1])
        tree.links.new(red.outputs["Emission"], mix.inputs[2])
        tree.links.new(mix.outputs["Shader"], out.inputs["Surface"])

scene = bpy.context.scene
scene.render.engine = "CYCLES"
scene.cycles.samples = 48
scene.cycles.device = "CPU"
scene.render.resolution_x = 640
scene.render.resolution_y = 640
scene.world.color = (0.004, 0.004, 0.005)
scene.view_settings.view_transform = "AgX"

floor_mat = bpy.data.materials.new("Floor")
floor_mat.use_nodes = True
floor_mat.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.04, 0.03, 0.022, 1)
floor_mat.node_tree.nodes["Principled BSDF"].inputs["Roughness"].default_value = 0.7

meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
for piece in pieces:
    for other in meshes:
        other.hide_render = other is not piece
    corners = [piece.matrix_world @ Vector(c) for c in piece.bound_box]
    lo = Vector((min(c.x for c in corners), min(c.y for c in corners), min(c.z for c in corners)))
    hi = Vector((max(c.x for c in corners), max(c.y for c in corners), max(c.z for c in corners)))
    centre = (lo + hi) / 2
    size = hi - lo
    reach = max(size.x, size.y, size.z)
    # A floor and a back wall for this piece, a lamp and a fill.
    scratch = []
    bpy.ops.mesh.primitive_plane_add(size=reach * 6, location=(centre.x, centre.y, lo.z))
    scratch.append(bpy.context.active_object)
    wall_y = lo.y - reach * 0.6 if behind else hi.y + reach * 0.6
    bpy.ops.mesh.primitive_plane_add(size=reach * 6, location=(centre.x, wall_y, centre.z), rotation=(math.radians(90), 0, 0))
    scratch.append(bpy.context.active_object)
    for s in scratch:
        s.data.materials.append(floor_mat)
    side = -1 if behind else 1
    bpy.ops.object.light_add(type="POINT", location=(centre.x - side * reach * 0.8, centre.y - side * reach * 1.6, hi.z + reach * 0.4))
    lamp = bpy.context.active_object
    lamp.data.energy = 220 * reach * reach
    lamp.data.color = (1.0, 0.76, 0.42)
    lamp.data.shadow_soft_size = reach * 0.06
    scratch.append(lamp)
    bpy.ops.object.light_add(type="AREA", location=(centre.x + side * reach * 1.2, centre.y - side * reach * 1.1, centre.z))
    fill = bpy.context.active_object
    fill.data.energy = 18 * reach * reach
    fill.data.color = (0.55, 0.65, 1.0)
    fill.data.size = reach
    scratch.append(fill)
    # Three-quarters from the front, a little above (or from behind).
    eye = centre + Vector((reach * 0.75, -reach * 1.55, reach * 0.35))
    if behind:
        eye = centre + Vector((-reach * 0.75, reach * 1.55, reach * 0.35))
    bpy.ops.object.camera_add(location=eye)
    cam = bpy.context.active_object
    cam.rotation_euler = (centre - eye).to_track_quat("-Z", "Y").to_euler()
    cam.data.lens = 50
    scene.camera = cam
    scratch.append(cam)
    scene.render.filepath = os.path.join(folder, "preview_%s%s.png" % (piece.name, "_behind" if behind else ""))
    bpy.ops.render.render(write_still=True)
    print("PREVIEW", scene.render.filepath)
    for s in scratch:
        bpy.data.objects.remove(s, do_unlink=True)
