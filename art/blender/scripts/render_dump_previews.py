"""Render a front-view preview of every extracted Meshy character master.

The dump's albedo atlases are too scrambled to identify anyone; a posed
render is the evidence the resident mapping gets made from. One frame per
character, textured, neutral grey world, head-to-foot framing.

    "/c/Program Files/Blender Foundation/Blender 5.2/blender" -b -P \
        art/blender/scripts/render_dump_previews.py -- <out_dir>
"""
import glob
import os
import sys

import bpy

ROOT = os.path.normpath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
MESHY = os.path.join(ROOT, "art", "blender", "meshy")
OUT = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else \
    os.path.join(MESHY, "_previews")


def render_one(char_dir: str) -> None:
    name = os.path.basename(char_dir)
    out_path = os.path.join(OUT, name + ".png")
    if os.path.exists(out_path):
        print("skip", name)
        return
    base = glob.glob(os.path.join(char_dir, "*_Character_output.fbx"))
    if not base:
        print("no base fbx:", name)
        return
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.fbx(filepath=base[0])
    # Frame the character: world bounds of all meshes.
    lo = [1e9] * 3
    hi = [-1e9] * 3
    for o in bpy.data.objects:
        if o.type != "MESH":
            continue
        for corner in o.bound_box:
            w = o.matrix_world @ type(o.location)(corner)
            for i in range(3):
                lo[i] = min(lo[i], w[i])
                hi[i] = max(hi[i], w[i])
    cx, cy = (lo[0] + hi[0]) / 2, (lo[1] + hi[1]) / 2
    cz = (lo[2] + hi[2]) / 2
    height = max(0.5, hi[2] - lo[2])
    cam_data = bpy.data.cameras.new("cam")
    cam = bpy.data.objects.new("cam", cam_data)
    bpy.context.scene.collection.objects.link(cam)
    cam.location = (cx, cy - height * 1.7, cz + height * 0.08)
    cam.rotation_euler = (1.5008, 0, 0)
    bpy.context.scene.camera = cam
    sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN"))
    sun.data.energy = 3.0
    sun.rotation_euler = (0.9, 0.2, 0.5)
    bpy.context.scene.collection.objects.link(sun)
    world = bpy.data.worlds.new("w")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = \
        (0.22, 0.22, 0.25, 1)
    bpy.context.scene.world = world
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x = 384
    scene.render.resolution_y = 512
    scene.render.filepath = out_path
    bpy.ops.render.render(write_still=True)
    print("rendered", name)


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    for char_dir in sorted(glob.glob(os.path.join(MESHY, "Meshy_AI_*"))):
        if os.path.isdir(char_dir):
            try:
                render_one(char_dir)
            except Exception as exc:  # keep the batch alive per character
                print("FAILED", os.path.basename(char_dir), exc)
