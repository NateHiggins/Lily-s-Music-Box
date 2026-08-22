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
    # 0.55 m at 58 mm filled the frame with featureless white; the root is
    # 0.27 m across now and needs standing back from.
    ("09_root", 60.0, 10.0, 0.10, 0.95),
    # The membrane read as a flat fan in every profile shot because every
    # profile shot sees it EDGE ON. This one looks at its face.
    ("11_membrane", 35.0, 26.0, 0.06, 0.82),
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


def bend_the_rig():
    """POSE IT BEFORE BELIEVING IT (TB-13).

    A model that only ever renders in rest pose cannot tell you whether it is
    a creature or a pile of parts sitting in the same place. Every DEF_ bone
    takes a small rotation, which accumulates down the chain into a strong
    S-curve; anything not truly bound to the rig stays behind in mid-air and
    is impossible to miss.

    This is the check that found the real bug: `skin()` was adding armature
    modifiers with no vertex groups, so all ninety-four hard riders -- eye,
    lids, gold, suckers, crystals -- were unbound.
    """
    arm = bpy.data.objects.get("TENTACLE_RIG")
    if arm is None:
        print("[grey] no rig to pose")
        return False
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode="POSE")
    n = 0
    for pb in arm.pose.bones:
        if not pb.name.startswith("DEF_"):
            continue
        pb.rotation_mode = "XYZ"
        # Alternating axes so the result is an S, not an arc: a single-plane
        # bend can hide a rider that is only wrong in the other axis.
        pb.rotation_euler = (math.radians(3.4), 0.0,
                             math.radians(2.6 if n % 8 < 4 else -3.1))
        n += 1
    bpy.ops.object.mode_set(mode="OBJECT")
    bpy.context.view_layer.update()
    print("[grey] posed %d deform bones" % n)
    return True


def deformed_aim(kind):
    """Where to point once the rig has moved the creature.

    The shot list's targets are rest-pose coordinates, so a posed render aims
    at empty space and the limb leaves frame. These come from the EVALUATED
    mesh -- where the thing actually is.
    """
    deps = bpy.context.evaluated_depsgraph_get()
    deps.update()
    if kind == "eye":
        eye = None
        for o in bpy.data.objects:
            if o.type == "MESH" and o.name.startswith("EYE"):
                eye = o
                break
        if eye is not None:
            ev = eye.evaluated_get(deps)
            mesh = ev.to_mesh()
            acc = Vector((0.0, 0.0, 0.0))
            for v in mesh.vertices:
                acc += v.co
            if len(mesh.vertices):
                acc /= len(mesh.vertices)
            out = ev.matrix_world @ acc
            ev.to_mesh_clear()
            return out
    cage = max((o for o in bpy.data.objects if o.type == "MESH"),
               key=lambda o: len(o.data.vertices))
    ev = cage.evaluated_get(deps)
    lo = Vector((1e9, 1e9, 1e9))
    hi = Vector((-1e9, -1e9, -1e9))
    mesh = ev.to_mesh()
    for v in mesh.vertices:
        w = ev.matrix_world @ v.co
        for i in range(3):
            lo[i] = min(lo[i], w[i])
            hi[i] = max(hi[i], w[i])
    ev.to_mesh_clear()
    return (lo + hi) * 0.5


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
    out_dir = OUT
    shots = SHOTS
    posed = False
    if os.environ.get("GREY_POSE") == "bend":
        if bend_the_rig():
            posed = True
            out_dir = OUT + "_posed"
            # The three that would expose a rider left behind.
            shots = [s for s in SHOTS if s[0] in
                     ("01_profile_left", "05_three_quarter", "07_orbit_45")]
    os.makedirs(out_dir, exist_ok=True)
    for name, az, el, v, dist in shots:
        target = Vector((0.0, v * LENGTH, 0.0))
        if posed:
            target = deformed_aim("eye" if "orbit" in name else "body")
            if "orbit" not in name:
                dist *= 1.35
        
        a, e = math.radians(az), math.radians(el)
        eye = target + Vector((math.sin(a) * math.cos(e), math.sin(e),
                               math.cos(a) * math.cos(e))) * dist
        cam.location = eye
        cam.rotation_euler = _look_dir(eye, target)
        scene.render.filepath = os.path.join(out_dir, name + ".png")
        bpy.ops.render.render(write_still=True)
        print("[grey] %s" % name)
    print("[grey] DONE -> %s" % out_dir)


if __name__ == "__main__":
    main()
