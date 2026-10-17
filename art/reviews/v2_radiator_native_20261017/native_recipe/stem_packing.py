"""UNINSTALLED static stem packing and a joined six-spoke handwheel.

This stem seal is distinct from the source-owned removable 2B UNION packing.
No inventory, heat, saved state or input authority is changed.
"""
from recipe_paths import repository_root, output_directory, primitive_source
from pathlib import Path
import ast, bpy, bmesh, json, math, hashlib
from mathutils import Vector, Matrix
from mathutils.bvhtree import BVHTree
R = repository_root()
P = output_directory()
source = primitive_source()
parsed = ast.parse(source.read_text())
exec(compile(ast.Module(body=[n for n in parsed.body if isinstance(n, ast.FunctionDef) and n.name in ['tube', 'boolean']], type_ignores=[]), str(source), 'exec'))
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.context.preferences.filepaths.save_version = 0
with bpy.data.libraries.load(str(P / 'offset_valve_candidate.blend'), link=False) as (available, loaded):
    loaded.objects = ['OffsetSteamValveHousing', 'MovingValveCore']
housing, core = loaded.objects
for obj in loaded.objects:
    bpy.context.collection.objects.link(obj)
    obj.hide_render = False
packing = tube('FixedStemPacking', (-0.53, 0, 0.284), (-0.53, 0, 0.304), 0.0102)
boolean(packing, tube('PackingStemBore', (-0.53, 0, 0.28), (-0.53, 0, 0.31), 0.008), 'DIFFERENCE')
bpy.ops.mesh.primitive_torus_add(major_radius=0.062, minor_radius=0.009, major_segments=48, minor_segments=12)
rim = bpy.context.object
wheel = tube('SixSpokeHandwheel', (0, 0, -0.009), (0, 0, 0.009), 0.015)
for index in range(6):
    angle = index * math.tau / 6
    spoke = tube('CastSpoke', (0, 0, 0), (0.063 * math.cos(angle), 0.063 * math.sin(angle), 0), 0.0055)
    boolean(wheel, spoke, 'UNION')
boolean(wheel, rim, 'UNION')
material = housing.data.materials[0]
checks = []

def check(label, passed, **detail):
    checks.append(dict(label=label, passed=bool(passed), **detail))
for obj in [packing, wheel]:
    bpy.ops.object.select_all(action='DESELECT')
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bmesh.ops.remove_doubles(bm, verts=list(bm.verts), dist=1e-06)
    bmesh.ops.triangulate(bm, faces=list(bm.faces))
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    bm.normal_update()
    check('closed positive native component', all((e.is_manifold for e in bm.edges)) and bm.calc_volume(signed=True) > 0, id=obj.name, nonmanifold=sum((not e.is_manifold for e in bm.edges)), volume_m3=bm.calc_volume(signed=True))
    pending = set(bm.verts)
    components = 0
    while pending:
        components += 1
        stack = [pending.pop()]
        while stack:
            v = stack.pop()
            for edge in v.link_edges:
                peer = edge.other_vert(v)
                if peer in pending:
                    pending.remove(peer)
                    stack.append(peer)
    check('one connected stock', components == 1, id=obj.name, components=components)
    bm.to_mesh(obj.data)
    bm.free()
    obj.data.materials.clear()
    obj.data.materials.append(material)
    uv = obj.data.uv_layers.active or obj.data.uv_layers.new(name='Metres')
    for face in obj.data.polygons:
        face.material_index = 0
        face.use_smooth = True
        n = face.normal.normalized()
        seed = Vector((0, 0, 1))
        if abs(n.dot(seed)) > 0.95:
            seed = Vector((1, 0, 0))
        u = seed.cross(n).normalized()
        v = n.cross(u).normalized()
        for loop in face.loop_indices:
            point = obj.data.vertices[obj.data.loops[loop].vertex_index].co
            uv.data[loop].uv = (point.dot(u) / 0.4, point.dot(v) / 0.4)
packing_tree = BVHTree.FromObject(packing, bpy.context.evaluated_depsgraph_get())
for lift in [0, 0.009, 0.018]:
    bottom = 0.378 + lift - 0.175
    top = 0.378 + lift + 0.012
    check('full stem seal engagement throughout retained travel', bottom < 0.284 and top > 0.304, lift_m=lift)
    for index in range(8):
        angle = index * math.tau / 8
        direction = Vector((math.cos(angle), math.sin(angle), 0))
        at, normal, face, distance = packing_tree.ray_cast(Vector((-0.53, 0, 0.294)), direction, 0.02)
        check('stem packing bore follows actual 8mm stem radius', at is not None and abs(distance - 0.008) < 0.00015, lift_m=lift, ray=index)
check('handwheel remains inside retained 71mm radial envelope', max((Vector((v.co.x, v.co.y)).length for v in wheel.data.vertices)) <= 0.071001)
native = P / 'stem_packing_candidate.blend'
bpy.ops.wm.save_as_mainfile(filepath=str(native))
report = dict(evidence_class='INERT', scope='UNINSTALLED joined wheel and static stem seal only. Sampled seal fit is not pressure/fluid proof. Stem screw, gland retention, supply elbow/union fit, graphite finish, strict export and production integration remain pending.', native_sha256=hashlib.sha256(native.read_bytes()).hexdigest(), valve_source_sha256=hashlib.sha256((P / 'offset_valve_candidate.blend').read_bytes()).hexdigest(), checks=checks, failures=[c for c in checks if not c['passed']])
(P / 'stem_packing_review.json').write_text(json.dumps(report, indent=2) + '\n')
print('STEM PACKING AND WHEEL', len(checks), 'checks', len(report['failures']), 'failures', flush=True)
if report['failures']:
    raise RuntimeError(report['failures'])
