"""Give the existing phone-scale arm a fixed floor and a front-opening pan.

Keeps all arm joints, contact markers, timing and metric charts. Run in Blender
with --python-exit-code 1. Review output is external; no reference is exported.
"""
import bpy, hashlib, json, math, runpy
from pathlib import Path
from mathutils import Matrix, Vector
from mathutils.bvhtree import BVHTree

ROOT = Path(__file__).resolve().parents[3]
OUT = Path('C:/ov/reports/prologue_20261028/arm_front')
OUT.mkdir(parents=True, exist_ok=True)
source_path = ROOT / 'art/blender/companion_typing_arm.blend'
bpy.ops.wm.open_mainfile(filepath=str(source_path))
scene = bpy.context.scene
scene.frame_set(1)
assembly = bpy.data.objects['TypingArmAssembly']
hatch = bpy.data.objects['Arm_Hatch']
stocks = bpy.data.collections['01_EDITABLE_ARM_STOCK']
exports = bpy.data.collections['02_ARM_ONLY_EXPORT']

def fingerprint(obj):
    payload = ([list(v.co) for v in obj.data.vertices],
               [list(p.vertices) for p in obj.data.polygons])
    return hashlib.sha256(json.dumps(payload).encode()).hexdigest()

unchanged = {o.name: fingerprint(o) for o in exports.objects if o.type == 'MESH'
             and o.parent not in (assembly, hatch)}
before = hashlib.sha256(source_path.read_bytes()).hexdigest()
if not assembly.get('front_cassette_revision'):
    pan = bpy.data.objects['Underside hatch pan']
    floor = pan.copy()
    floor.data = pan.data.copy()
    floor.name = 'Fixed cassette floor'
    stocks.objects.link(floor)
    floor.data.transform(hatch.matrix_world @ pan.matrix_basis)
    floor.parent = assembly
    floor.matrix_basis = Matrix.Identity(4)
    floor['construction_role'] = 'stationary closed cassette bottom'
    # Rotate the complete returned pan and its existing hardware into the
    # front plane. The captive X-axis hinge remains seated at the same datum.
    rotation = Matrix.Rotation(math.pi / 2, 4, 'X')
    for obj in stocks.objects:
        if obj.type == 'MESH' and obj.parent == hatch:
            obj.data.transform(rotation)
            obj.data.update()
    action = hatch.animation_data.action
    curves = []
    for layer in action.layers:
        for strip in layer.strips:
            for bag in strip.channelbags:
                curves.extend(bag.fcurves)
    curve = next(c for c in curves if c.data_path == 'rotation_euler' and c.array_index == 0)
    maximum = max(abs(k.co.y) for k in curve.keyframe_points)
    factor = -(math.pi / 2) / maximum
    for key in curve.keyframe_points:
        key.co.y *= factor
        key.handle_left.y *= factor
        key.handle_right.y *= factor
    curve.update()
    hatch['opening_role'] = 'front pan folds outward and down; floor stays fixed'
    assembly['front_cassette_revision'] = 1
    for parent in (assembly, hatch):
        previous = next(o for o in exports.objects if o.type == 'MESH' and o.parent == parent)
        name = previous.name
        bpy.data.objects.remove(previous, do_unlink=True)
        copies = []
        for obj in list(stocks.objects):
            if obj.type != 'MESH' or obj.parent != parent:
                continue
            copy = obj.copy()
            copy.data = obj.data.copy()
            copy.parent = None
            copy.matrix_world = Matrix.Identity(4)
            copy.hide_render = False
            copy.hide_viewport = False
            exports.objects.link(copy)
            copies.append(copy)
        bpy.ops.object.select_all(action='DESELECT')
        for copy in copies:
            copy.select_set(True)
        bpy.context.view_layer.objects.active = copies[0]
        bpy.ops.object.join()
        result = bpy.context.object
        result.name = name
        result.parent = parent
        result.matrix_basis = Matrix.Identity(4)

assert all(fingerprint(bpy.data.objects[name]) == value for name, value in unchanged.items())
floor = bpy.data.objects['Fixed cassette floor']
pan = bpy.data.objects['Underside hatch pan']

def bvh(obj):
    return BVHTree.FromPolygons([obj.matrix_world @ v.co for v in obj.data.vertices],
                               [list(p.vertices) for p in obj.data.polygons])

failures = []
samples = 0
moving = [o for o in exports.objects if o.type == 'MESH' and o.parent not in (assembly, hatch)]
for frame in range(1, 433, 3):
    scene.frame_set(frame)
    bpy.context.view_layer.update()
    for barrier in (floor, pan):
        barrier_bvh = bvh(barrier)
        for obj in moving:
            hits = barrier_bvh.overlap(bvh(obj))
            samples += 1
            if hits:
                failures.append({'frame': frame, 'part': obj.name, 'barrier': barrier.name, 'triangles': len(hits)})
report = {'evidence_class': 'INERT', 'before_blend_sha256': before,
          'unchanged_export_meshes': unchanged, 'sampled_intersection_checks': samples,
          'failures': failures, 'scope': 'native sampled pan/floor clearance only; not every possible runtime key transition'}
(OUT / 'construction.json').write_text(json.dumps(report, indent=2), encoding='utf-8')
assert not failures, failures[:12]
scene.frame_set(1)
stocks.hide_render = True
stocks.hide_viewport = True
bpy.context.preferences.filepaths.save_version = 0
bpy.ops.wm.save_as_mainfile(filepath=str(source_path))
runpy.run_path(str(Path(__file__).with_name('export_companion_typing_arm.py')), run_name='__main__')
print('FRONT_CASSETTE_NATIVE', samples, 'checks; other arm meshes unchanged', flush=True)
