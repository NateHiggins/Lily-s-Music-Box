"""Survey the installed ground the distant districts must meet. Run it when the apron or
the bridge sheet changes, then rebuild build_city_far_districts.py:

    blender -b --python-exit-code 1 -P art/blender/scripts/survey_city_far_ground.py

h_near.npy: orison_ground + city_ground_apron in the BLOCKOUT frame, 4 m grid over
+-520 m. h_far.npy: the Queensboro sheet (land, island, river) placed exactly as
orison_v2_city_bridge.gd places it, in the WORLD frame, 20 m grid over +-2600 m.
Rows are z and columns x (Godot axes); NaN where nothing was hit.
"""
import math

import bpy
import numpy as np
from mathutils import Matrix, Vector
from mathutils.bvhtree import BVHTree

ROOT = __file__.replace("\\", "/").split("/art/blender/")[0]
PROPS = ROOT + "/game/assets/props/"
OUTDIR = ROOT + "/art/blender/data/city_far_survey/"
CITY_SHELLS_Z = -9.795  # CityShells' source-threshold offset in the world


def load(name, matrix=None):
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=PROPS + name + ".glb")
    new = [o for o in bpy.data.objects if o not in before]
    if matrix is not None:
        for o in new:
            if o.parent is None:
                o.matrix_world = matrix @ o.matrix_world
    return new


def tree(objects):
    depsgraph = bpy.context.evaluated_depsgraph_get()
    verts, polys = [], []
    for o in objects:
        if o.type != "MESH":
            continue
        mesh = o.evaluated_get(depsgraph).to_mesh()
        base = len(verts)
        verts += [o.matrix_world @ v.co for v in mesh.vertices]
        polys += [[base + i for i in p.vertices] for p in mesh.polygons]
    return BVHTree.FromPolygons(verts, polys)


def grid(bvh, limit, step, out):
    n = int(2 * limit / step) + 1
    heights = np.full((n, n), np.nan, np.float32)
    for j in range(n):
        z = -limit + j * step
        for i in range(n):
            x = -limit + i * step
            hit = bvh.ray_cast(Vector((x, -z, 500)), Vector((0, 0, -1)), 2000)
            if hit[0] is not None:
                heights[j, i] = hit[0].z
    np.save(out, heights)
    print("SURVEY", out, float(np.nanmin(heights)), float(np.nanmax(heights)))


bpy.ops.wm.read_factory_settings(use_empty=True)
grid(tree(load("orison_ground") + load("city_ground_apron")), 520, 4, OUTDIR + "h_near.npy")

bpy.ops.wm.read_factory_settings(use_empty=True)
azimuth = math.radians(119.70833333333333)  # data/orison_v2/exterior/city_bridge.json
dx, dz = math.sin(azimuth), -math.cos(azimuth)
length = 1135.2276
ox, oz = -250.0 - dx * length, -520.0 - dz * length + CITY_SHELLS_Z
godot_to_blender = Matrix(((1, 0, 0, 0), (0, 0, -1, 0), (0, 1, 0, 0), (0, 0, 0, 1)))
placement = Matrix(((dx, 0, -dz, ox), (0, 1, 0, -6.0), (dz, 0, dx, oz), (0, 0, 0, 1)))
bridge = load("city_bridge", godot_to_blender @ placement @ godot_to_blender.inverted())
grid(tree(bridge), 2600, 20, OUTDIR + "h_far.npy")
