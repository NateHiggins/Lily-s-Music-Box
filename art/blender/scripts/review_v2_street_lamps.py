"""Blender review of the V2 street lamp stock before any Godot capture.

    blender -b -P art/blender/scripts/review_v2_street_lamps.py -- <out_dir>
"""
from pathlib import Path
import sys, math
import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[3]
OUT = Path(sys.argv[sys.argv.index("--") + 1]) if "--" in sys.argv else ROOT / "art/reviews/v2_street_lamps_20261024"
OUT.mkdir(parents=True, exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=str(ROOT / "art/blender/v2_street_lamps.blend"))
scene = bpy.context.scene
for obj in bpy.data.collections["StreetLampExport"].objects:
    if obj.name.startswith("signal_box_crook"):
        obj.location.x = 1.6
world = scene.world or bpy.data.worlds.new("review")
scene.world = world
world.use_nodes = True
world.node_tree.nodes["Background"].inputs[0].default_value = (0.03, 0.035, 0.05, 1)
for name, energy, rot in (("key", 2.0, (50, 0, -35)), ("rim", 0.6, (65, 0, 150))):
    sun = bpy.data.objects.new(name, bpy.data.lights.new(name, "SUN"))
    sun.data.energy = energy
    sun.rotation_euler = [math.radians(a) for a in rot]
    scene.collection.objects.link(sun)
for x in (0.0, 1.6):
    bulb = bpy.data.objects.new("bulb", bpy.data.lights.new("bulb", "POINT"))
    bulb.data.energy = 120
    bulb.data.color = (1.0, 0.72, 0.42)
    bulb.location = (x, -0.84, 3.86)
    scene.collection.objects.link(bulb)
bpy.ops.mesh.primitive_plane_add(size=40, location=(0, 0, 0))
ground = bpy.context.object
gm = bpy.data.materials.new("ground")
gm.diffuse_color = (0.12, 0.12, 0.12, 1)
ground.data.materials.append(gm)
cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
scene.collection.objects.link(cam)
scene.camera = cam
scene.render.engine = "BLENDER_EEVEE"
scene.render.resolution_x, scene.render.resolution_y = 1400, 1400
scene.view_settings.view_transform = "AgX"


def shoot(name, loc, target, lens):
    cam.location = loc
    cam.rotation_euler = (Vector(target) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
    cam.data.lens = lens
    scene.render.filepath = str(OUT / name)
    bpy.ops.render.render(write_still=True)


shoot("lamps_pair.png", (7.5, -5.5, 2.2), (0.8, -0.3, 2.3), 35)
shoot("lamps_crook_detail.png", (2.4, -2.6, 4.2), (0.4, -0.5, 4.1), 50)
shoot("signal_box_detail.png", (2.6, 1.9, 1.7), (1.6, 0.2, 1.65), 50)
