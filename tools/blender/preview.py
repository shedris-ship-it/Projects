"""Render a batch's exported .glb under one warm lamp, to judge the kit
before it goes to Studio (the visual rework).

    blender -b --factory-startup -P tools/blender/preview.py -- spike

Writes build/kit/<batch>/preview.png.
"""

import math
import os
import sys

import bpy
from mathutils import Vector

ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
batch = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else "spike"
folder = os.path.join(ROOT, "build", "kit", batch)

bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete()
bpy.ops.import_scene.gltf(filepath=os.path.join(folder, batch + ".glb"))
pieces = [o for o in bpy.context.scene.objects if o.type == "MESH"]
lo = Vector((min(min((o.matrix_world @ Vector(c)).x for c in o.bound_box) for o in pieces), 0, 0))
hi = Vector((max(max((o.matrix_world @ Vector(c)).x for c in o.bound_box) for o in pieces), 0, 0))
mid_x = (lo.x + hi.x) / 2

bpy.ops.mesh.primitive_plane_add(size=60, location=(mid_x, 0, 0))
floor = bpy.context.active_object
mat = bpy.data.materials.new("Floor")
mat.use_nodes = True
mat.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.05, 0.035, 0.025, 1)
mat.node_tree.nodes["Principled BSDF"].inputs["Roughness"].default_value = 0.6
floor.data.materials.append(mat)
bpy.ops.mesh.primitive_plane_add(size=60, location=(mid_x, 4, 15), rotation=(math.radians(90), 0, 0))
wall = bpy.context.active_object
wall.data.materials.append(mat)

# One warm practical, as the house's lamps (Config.Lighting.Lamp).
bpy.ops.object.light_add(type="POINT", location=(mid_x - 2, -5, 7))
lamp = bpy.context.active_object
lamp.data.energy = 900
lamp.data.color = (1.0, 0.76, 0.42)
lamp.data.shadow_soft_size = 0.4
bpy.ops.object.light_add(type="AREA", location=(mid_x + 6, -8, 4))
fill = bpy.context.active_object
fill.data.energy = 120
fill.data.color = (0.55, 0.65, 1.0)

bpy.ops.object.camera_add(location=(mid_x, -16, 5.5))
cam = bpy.context.active_object
direction = Vector((mid_x, 0, 3)) - cam.location
cam.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
cam.data.lens = 40
scene = bpy.context.scene
scene.camera = cam
scene.render.engine = "CYCLES"
scene.cycles.samples = 48
scene.cycles.device = "CPU"
scene.render.resolution_x = 1280
scene.render.resolution_y = 640
scene.world.color = (0.005, 0.005, 0.006)
scene.view_settings.view_transform = "AgX"
scene.render.filepath = os.path.join(folder, "preview.png")
bpy.ops.render.render(write_still=True)
print("PREVIEW", scene.render.filepath)
