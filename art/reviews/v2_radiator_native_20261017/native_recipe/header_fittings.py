"""UNINSTALLED end plugs/reducer for the inferred hollow three-column casting."""
from recipe_paths import repository_root, output_directory, primitive_source
from pathlib import Path
import ast, bpy, bmesh, json, math, hashlib
from mathutils import Vector, Matrix
from mathutils.bvhtree import BVHTree
R = repository_root()
P = output_directory()
source = primitive_source()
parsed = ast.parse(source.read_text())
nodes = [n for n in parsed.body if isinstance(n, ast.FunctionDef) and n.name in ['tube', 'boolean']]
exec(compile(ast.Module(body=nodes, type_ignores=[]), str(source), 'exec'))
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.context.preferences.filepaths.save_version = 0
plug = tube('BlindHeaderPlug', (-0.02, 0, 0), (0.003, 0, 0), 0.0265)
head = tube('PlugWrenchFlats', (0.001, 0, 0), (0.015, 0, 0), 0.033, 6)
boolean(plug, head, 'UNION')
reducer = tube('VentHeaderReducer', (-0.02, 0, 0), (0.003, 0, 0), 0.0265)
head = tube('ReducerWrenchFlats', (0.001, 0, 0), (0.015, 0, 0), 0.033, 6)
boolean(reducer, head, 'UNION')
cut = tube('ActualVentNeckBore', (-0.03, 0, 0), (0.03, 0, 0), 0.0105)
boolean(reducer, cut, 'DIFFERENCE')
washer = tube('HeaderSealWasher', (0, 0, 0), (0.001, 0, 0), 0.0345)
cut = tube('CompressedSealBore', (-0.005, 0, 0), (0.005, 0, 0), 0.0264)
boolean(washer, cut, 'DIFFERENCE')
checks = []

def check(label, passed, **detail):
    checks.append(dict(label=label, passed=bool(passed), **detail))
with bpy.data.libraries.load(str(R / 'art/blender/heating_distribution.blend'), link=False) as (available, loaded):
    loaded.materials = ['iron_neutral']
material = loaded.materials[0]
for obj in [plug, reducer, washer]:
    bpy.ops.object.select_all(action='DESELECT')
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    bevel = obj.modifiers.new('Filed wrench edges', 'BEVEL')
    bevel.width = 0.0001 if obj == washer else 0.0006
    bevel.segments = 2
    bpy.ops.object.modifier_apply(modifier=bevel.name)
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bmesh.ops.remove_doubles(bm, verts=list(bm.verts), dist=1e-06)
    bmesh.ops.triangulate(bm, faces=list(bm.faces))
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    bm.to_mesh(obj.data)
    check('closed positive end fitting', all((e.is_manifold for e in bm.edges)) and bm.calc_volume(signed=True) > 0, id=obj.name, nonmanifold_edges=sum((not e.is_manifold for e in bm.edges)), volume_m3=bm.calc_volume(signed=True))
    bm.free()
    obj.data.materials.clear()
    obj.data.materials.append(material)
    uv = obj.data.uv_layers.active or obj.data.uv_layers.new(name='Metres')
    for face in obj.data.polygons:
        face.material_index = 0
        normal = face.normal.normalized()
        seed = Vector((0, 0, 1))
        if abs(normal.dot(seed)) > 0.95:
            seed = Vector((1, 0, 0))
        u = seed.cross(normal).normalized()
        v = normal.cross(u).normalized()
        for loop in face.loop_indices:
            point = obj.data.vertices[obj.data.loops[loop].vertex_index].co
            uv.data[loop].uv = (point.dot(u) / 0.4, point.dot(v) / 0.4)
    obj.hide_render = True
native = P / 'header_fittings_candidate.blend'
bpy.ops.wm.save_as_mainfile(filepath=str(native))
with bpy.data.libraries.load(str(P / 'three_column_casting_candidate.blend'), link=False) as (available, loaded):
    loaded.objects = ['CastSectionThreeColumnCandidate']
casting = loaded.objects[0]
bpy.context.collection.objects.link(casting)
casting.hide_render = True
with bpy.data.libraries.load(str(P / 'cast_shoe_foot_candidate.blend'), link=False) as (available, loaded):
    loaded.objects = ['CastShoeFoot']
foot = loaded.objects[0]
bpy.context.collection.objects.link(foot)
foot.hide_render = True
parts = []
for index in range(8):
    obj = casting.copy()
    obj.data = casting.data
    obj.hide_render = False
    obj.location = Vector(((index - 3.5) * 0.092, 0, 0.105))
    bpy.context.collection.objects.link(obj)
    parts.append(obj)
half = 3.5 * 0.092
for x in [-half, half]:
    obj = foot.copy()
    obj.data = foot.data
    obj.hide_render = False
    obj.location.x = x
    bpy.context.collection.objects.link(obj)
    parts.append(obj)
for name, prototype, point, rotation in [('LeftUpperBlindPlug', plug, (-half - 0.046, 0.055, 0.72), math.pi), ('RightLowerBlindPlug', plug, (half + 0.046, 0.055, 0.19), 0), ('RightUpperVentReducer', reducer, (half + 0.046, 0.055, 0.72), 0)]:
    obj = prototype.copy()
    obj.data = prototype.data
    obj.name = name
    obj.hide_render = False
    obj.location = point
    obj.rotation_euler.z = rotation
    bpy.context.collection.objects.link(obj)
    parts.append(obj)
    seal = washer.copy()
    seal.data = washer.data
    seal.name = name + '_Seal'
    seal.hide_render = False
    seal.location = point
    seal.rotation_euler.z = rotation
    bpy.context.collection.objects.link(seal)
    parts.append(seal)
    bm = bmesh.new()
    bm.from_mesh(washer.data)
    bm.normal_update()
    seal_tree = BVHTree.FromBMesh(bm)
    bm.free()
    for index in range(8):
        angle = index * math.tau / 8
        sample = Vector((0.0005, 0.02675 * math.cos(angle), 0.02675 * math.sin(angle)))
        at, normal, face, distance = seal_tree.find_nearest(sample)
        check('compressed seal occupies would-be annular escape gap', at is not None and (sample - at).dot(normal) < -1e-05, owner=name, ray=index)
bpy.context.view_layer.update()
bm = bmesh.new()
for obj in parts:
    count = len(bm.verts)
    bm.from_mesh(obj.data)
    bm.verts.ensure_lookup_table()
    for v in list(bm.verts)[count:]:
        v.co = obj.matrix_world @ v.co
bm.normal_update()
tree = BVHTree.FromBMesh(bm)
bm.free()
for height, direction, blocked in [(0.19, 1, True), (0.19, -1, False), (0.72, -1, True), (0.72, 1, False)]:
    at, normal, face, distance = tree.ray_cast(Vector((0, 0.055, height)), Vector((direction, 0, 0)), 0.6)
    check('assembled header plugs and open supply/vent paths agree', (at is not None) == blocked, height=height, direction=direction, blocked=blocked)
report = dict(evidence_class='INERT', scope='UNINSTALLED end fittings. Real header closures and vent reducer for the hollow shared casting. Retained vent must move to the actual upper port at prop y0.72/z-0.055 on integration; source, valve/union, pitch/shim and strict export remain pending.', native_sha256=hashlib.sha256(native.read_bytes()).hexdigest(), checks=checks, failures=[c for c in checks if not c['passed']])
(P / 'header_fittings_review.json').write_text(json.dumps(report, indent=2) + '\n')
print('HEADER FITTINGS', len(checks), 'checks', len(report['failures']), 'failures', flush=True)
if report['failures']:
    raise RuntimeError(report['failures'])
