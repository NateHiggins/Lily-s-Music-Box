"""THE GREY TEST (design/DREAM_TENTACLE_BLENDER_BUILD.md, the last rule).

    "The finished Blender model should look impressive with flat grey
     materials... Shaders should reveal the anatomy. They should not be
     responsible for inventing it."

So this renders the model in flat grey clay from the angles that can prove
or disprove it, including the ruling's own explicit test: from 45 degrees
the complete sphere of the eye must not be reconstructible (§4).

    "/c/Program Files/Blender Foundation/Blender 5.2/blender" -b \
        art/blender/dream_tentacle.blend \
        -P art/blender/scripts/render_dream_tentacle_grey.py
"""

import bpy
import math
import os
from mathutils import Vector

REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
OUT = os.path.join(REPO, "art", "renders", "dream_tentacle", "blender_grey")
LENGTH = 1.60
RES = (1280, 1280)

# name, azimuth (deg around Y), elevation (deg), target v along the limb, distance
SHOTS = [
    ("01_profile_left", 90.0, 4.0, 0.5, 2.05),
    ("02_profile_right", -90.0, 4.0, 0.5, 2.05),
    ("03_dorsal", 0.0, 6.0, 0.5, 2.05),
    ("04_ventral", 180.0, -6.0, 0.5, 2.05),
    ("05_three_quarter", 42.0, 16.0, 0.5, 1.95),
    ("06_orbit_front", 0.0, 4.0, 0.42, 0.42),
    ("07_orbit_45", 45.0, 8.0, 0.42, 0.42),
    ("08_orbit_45_other", -45.0, -6.0, 0.42, 0.42),
    ("09_root", 60.0, 10.0, 0.07, 0.55),
    ("10_club", -60.0, -8.0, 0.94, 0.40),
]


def clay_material():
    mat = bpy.data.materials.new("GREY_CLAY")
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = (0.55, 0.55, 0.56, 1.0)
    bsdf.inputs["Roughness"].default_value = 0.62
    if "Metallic" in bsdf.inputs:
        bsdf.inputs["Metallic"].default_value = 0.0
    if "Specular IOR Level" in bsdf.inputs:
        bsdf.inputs["Specular IOR Level"].default_value = 0.4
    return mat


def light_rig():
    """A key that rakes across the form, a fill, and a rim — the lighting a
    sculptor uses to judge silhouette and mass, nothing flattering."""
    for name, loc, energy, size in (
            ("KEY", (2.4, 1.6, 2.0), 420.0, 1.6),
            ("FILL", (-2.6, 0.9, 1.4), 90.0, 2.4),
            ("RIM", (-1.2, 2.4, -2.6), 260.0, 1.2)):
        data = bpy.data.lights.new(name, "AREA")
        data.energy = energy
        data.size = size
        obj = bpy.data.objects.new(name, data)
        obj.location = loc
        obj.rotation_euler = _look_dir(Vector(loc), Vector((0.0, LENGTH * 0.5, 0.0)))
        bpy.context.scene.collection.objects.link(obj)


def _look_dir(eye, target):
    d = (target - eye).normalized()
    return d.to_track_quat("-Z", "Y").to_euler()


def main():
    scene = bpy.context.scene
    for engine in ("BLENDER_EEVEE_NEXT", "BLENDER_EEVEE", "CYCLES"):
        try:
            scene.render.engine = engine
            break
        except TypeError:
            continue
    try:
        scene.eevee.taa_render_samples = 64
    except AttributeError:
        pass
    scene.render.resolution_x, scene.render.resolution_y = RES
    scene.render.film_transparent = False
    scene.world = bpy.data.worlds.new("W")
    scene.world.use_nodes = True
    bg = scene.world.node_tree.nodes["Background"]
    bg.inputs["Color"].default_value = (0.045, 0.045, 0.05, 1.0)
    bg.inputs["Strength"].default_value = 1.0
    clay = clay_material()
    meshes = [o for o in bpy.data.objects if o.type == "MESH"]
    for obj in meshes:
        obj.data.materials.clear()
        obj.data.materials.append(clay)
    light_rig()
    cam_data = bpy.data.cameras.new("CAM")
    cam_data.lens = 58.0
    cam = bpy.data.objects.new("CAM", cam_data)
    scene.collection.objects.link(cam)
    scene.camera = cam
    os.makedirs(OUT, exist_ok=True)
    for name, az, el, v, dist in SHOTS:
        target = Vector((0.0, v * LENGTH, 0.0))
        a, e = math.radians(az), math.radians(el)
        eye = target + Vector((math.sin(a) * math.cos(e), math.sin(e),
                               math.cos(a) * math.cos(e))) * dist
        cam.location = eye
        cam.rotation_euler = _look_dir(eye, target)
        scene.render.filepath = os.path.join(OUT, name + ".png")
        bpy.ops.render.render(write_still=True)
        print("[grey] %s" % name)
    print("[grey] DONE -> %s" % OUT)


if __name__ == "__main__":
    main()
