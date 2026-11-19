"""Build the hoop and one-metre grip-to-guide stick in their runtime frames."""
import json
from math import cos, pi, sin, tau
from pathlib import Path
import sys

import bmesh
import bpy
from mathutils import Matrix

sys.path.insert(0, str(Path(__file__).resolve().parent))
from fabrication_native_batch import export, material, partition


ROOT = Path(__file__).resolve().parents[3]
RADIUS = .37
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.context.preferences.filepaths.save_version = 0
catalogue = json.loads((ROOT / "game/data/runtime_material_sets.json").read_bytes())["materials"]
construction = bpy.data.collections.new("Editable hoop and stick")
exports = bpy.data.collections.new("RollingHoop")
bpy.context.scene.collection.children.link(construction)
bpy.context.scene.collection.children.link(exports)


def solid(name, vertices, faces):
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(vertices, [], faces)
    obj = bpy.data.objects.new(name, mesh)
    construction.objects.link(obj)
    bm = bmesh.new()
    bm.from_mesh(mesh)
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    assert all(edge.is_manifold for edge in bm.edges) and bm.calc_volume(signed=True) > 0, name
    bm.to_mesh(mesh)
    bm.free()
    return obj


def band(name, profile):
    segments = 72
    count = len(profile)
    vertices = [(across, radius * cos(i*tau/segments), radius * sin(i*tau/segments))
                for i in range(segments) for across, radius in profile]
    faces = []
    for i in range(segments):
        a, b = i * count, ((i+1) % segments) * count
        for k in range(count):
            j = (k+1) % count
            faces.append((a+k, b+k, b+j, a+j))
    return solid(name, vertices, faces)


def rod(name, rings):
    sides = 16
    vertices = [(x + r*cos(i*tau/sides), r*sin(i*tau/sides), z)
                for x, z, r in rings for i in range(sides)]
    faces = [tuple(reversed(range(sides)))]
    for ring in range(len(rings)-1):
        a, b = ring*sides, (ring+1)*sides
        for i in range(sides):
            j = (i+1) % sides
            faces.append((a+i, a+j, b+j, b+i))
    faces.append(tuple(range(len(vertices)-sides,len(vertices))))
    return solid(name, vertices, faces)


def draw(label, key, tint, objects):
    finish = dict(catalog_key=key, tint=[*tint, 1.], pigment=1., normal=.32, roughness=1.)
    mat = material(ROOT, key, finish, catalogue)
    return partition(exports, label + "__" + key, objects, finish, mat, Matrix.Identity(4), catalogue)


rim = band("Rolled steel tread", [(-.010, .356),(.010, .356),(.010, RADIUS-.002),
                               (.008, RADIUS),(-.008, RADIUS),(-.010, RADIUS-.002)])
body = band("Swept oak ring", [(-.008,.332),(.008,.332),(.012,.336),(.012,.356),(-.012,.356),(-.012,.336)])
shaft = rod("Turned handle and ash shaft", [(0,.107,.017),(0,.098,.021),(0,-.07,.020),
                                            (0,-.14,.013),(0,-.75,.010),(0,-.885,.009)])
ferrule = rod("Guide ferrule", [(0,-.802,.014),(0,-.814,.016),(0,-.905,.012),(0,-.925,.009)])
tines = [rod("Guide tine", [(0,-.875,.007),(side*.019,-.941,.007),(side*.026,-.991,.006),
                             (side*.024,-1.035,.004)]) for side in (-1,1)]
draw("Hoop", "metal", (.49,.46,.41), [rim])
draw("Hoop", "timber", (.72,.49,.33), [body])
draw("Stick", "timber", (.78,.56,.36), [shaft])
draw("Stick", "metal", (.52,.50,.44), [ferrule,*tines])
construction.hide_render = True
construction.hide_viewport = True
proof = export(ROOT, "rolling_hoop", exports)
assert proof["status"] == "PASS", proof
print("ROLLING HOOP:", proof, flush=True)
