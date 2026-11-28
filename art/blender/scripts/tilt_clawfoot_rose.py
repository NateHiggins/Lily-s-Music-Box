"""Tilt the 4B bath's rain rose on its captive swivel so the spray lands in the tub.

Run with Blender 5.2, then publish with export_clawfoot_bath.py:
    blender -b -t 2 --python-exit-code 1 -P tilt_clawfoot_rose.py [-- --check]

The rose shell, perforated rim and jet nozzles turn rigidly about the centre of
the swivel seat, toward the foot of the tub (+X). The editable stock, the merged
export mesh, its custom normals and the SprayOrigin datum all receive the same
rotation, so the datum's own axis is the direction the game sprays along. The
script is idempotent: it records the applied angle on the datum and turns only
by the difference. A rigid turn keeps every metric UV edge length.
"""
from pathlib import Path
import math
import sys

import bpy
from mathutils import Matrix, Vector

ROOT = Path(__file__).resolve().parents[3]
BLEND = ROOT / 'art/blender/clawfoot_bath.blend'
TILT_DEGREES = 14.0
ROSE_PREFIXES = ('Rain rose shell', 'Rain rose perforated rim', 'Rose jet nozzle')
SEAT = 'Refit2__rose captive swivel seat'
MERGED = 'TubMesh__TubFixed'
DATUM = 'SprayOrigin'
KEY = 'rose_tilt_degrees'

check_only = '--check' in sys.argv
bpy.ops.wm.open_mainfile(filepath=str(BLEND))
datum = bpy.data.objects[DATUM]
applied = float(datum.get(KEY, 0.0))
delta = TILT_DEGREES - applied
rose = [o for o in bpy.data.objects if o.type == 'MESH' and o.name.startswith(ROSE_PREFIXES)]
assert len(rose) == 26, [o.name for o in rose]


def world_points(objects):
    return [o.matrix_world @ v.co for o in objects for v in o.data.vertices]


seat = world_points([bpy.data.objects[SEAT]])
pivot = sum(seat, Vector()) / len(seat)
# Face normal (0, 0, -1) must lean toward +X: a negative turn about +Y.
turn = Matrix.Rotation(math.radians(-delta), 4, 'Y')
rigid = Matrix.Translation(pivot) @ turn @ Matrix.Translation(-pivot)

points = world_points(rose)
low = Vector((min(p.x for p in points), min(p.y for p in points), min(p.z for p in points))) - Vector((.0006,) * 3)
high = Vector((max(p.x for p in points), max(p.y for p in points), max(p.z for p in points))) + Vector((.0006,) * 3)
merged = bpy.data.objects[MERGED]
mesh = merged.data
to_world = merged.matrix_world
to_local = to_world.inverted()
# The merged export mesh was joined from this stock, so its rose vertices sit
# exactly on the stock's. Match by position rather than by a box: the shell's
# top ring shares a height band with the swivel seat, which must not turn.
from mathutils import kdtree
tree = kdtree.KDTree(len(points))
for index, point in enumerate(points):
    tree.insert(point, index)
tree.balance()
back = (Matrix.Translation(pivot) @ Matrix.Rotation(math.radians(applied), 4, 'Y') @ Matrix.Translation(-pivot))
chosen = set()
for vertex in mesh.vertices:
    at = to_world @ vertex.co
    if not (low.x <= at.x <= high.x and low.y <= at.y <= high.y and low.z <= at.z <= high.z):
        continue
    if tree.find(at)[2] < 2e-5:
        chosen.add(vertex.index)
nozzles = sorted((o for o in rose if o.name.startswith('Rose jet nozzle')), key=lambda o: o.name)
centres = [sum((o.matrix_world @ v.co for v in o.data.vertices), Vector()) / len(o.data.vertices) for o in nozzles]
print('ROSE_TILT', {'applied': applied, 'target': TILT_DEGREES, 'pivot': tuple(round(c, 4) for c in pivot),
                    'stock_bounds': [tuple(round(c, 4) for c in low), tuple(round(c, 4) for c in high)],
                    'merged_vertices': len(chosen)}, flush=True)
print('ROSE_NOZZLES', [(round((back @ c).x + .47, 4), round((back @ c).y, 4)) for c in centres], flush=True)
assert 3000 < len(chosen) < 7000, len(chosen)
if check_only or abs(delta) < 1e-6:
    sys.exit(0)

for obj in rose:
    obj.matrix_world = rigid @ obj.matrix_world
normals = [corner.vector.copy() for corner in mesh.corner_normals]
local_turn = (to_local @ rigid @ to_world)
normal_turn = local_turn.to_3x3()
for index in chosen:
    mesh.vertices[index].co = local_turn @ mesh.vertices[index].co
for loop in mesh.loops:
    if loop.vertex_index in chosen:
        normals[loop.index] = (normal_turn @ normals[loop.index]).normalized()
mesh.normals_split_custom_set(normals)
mesh.update()
datum.matrix_world = rigid @ datum.matrix_world
datum[KEY] = TILT_DEGREES
bpy.ops.wm.save_mainfile(filepath=str(BLEND))
print('ROSE_TILT_APPLIED', {'degrees': TILT_DEGREES, 'datum': tuple(round(c, 4) for c in datum.matrix_world.translation),
                            'axis': tuple(round(c, 4) for c in (datum.matrix_world.to_3x3() @ Vector((0, 0, -1))))}, flush=True)
