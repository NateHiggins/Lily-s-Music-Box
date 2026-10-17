"""UNINSTALLED matched helical stem/nut for the retained 3.5 turns / 18mm lift."""
from recipe_paths import repository_root, output_directory, primitive_source
from pathlib import Path
import ast, bpy, bmesh, json, math, hashlib
from mathutils import Vector, Matrix
from mathutils.bvhtree import BVHTree
P = output_directory()
R = repository_root()
source = primitive_source()
parsed = ast.parse(source.read_text())
exec(compile(ast.Module(body=[n for n in parsed.body if isinstance(n, ast.FunctionDef) and n.name in ['tube', 'boolean']], type_ignores=[]), str(source), 'exec'))
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.context.preferences.filepaths.save_version = 0
with bpy.data.libraries.load(str(P / 'stem_packing_candidate.blend'), link=False) as (available, loaded):
    loaded.objects = ['OffsetSteamValveHousing', 'MovingValveCore', 'SixSpokeHandwheel']
housing, core, wheel = loaded.objects
for obj in loaded.objects:
    bpy.context.collection.objects.link(obj)
    obj.hide_render = False
pitch = 0.018 / 3.5

def helix(name, clearance=0):
    turns = 0.085 / pitch
    steps = math.ceil(turns * 48)
    vertices = []
    faces = []
    profile = [(0.0079, -0.0017 - clearance), (0.0096 + clearance, -0.0007 - clearance), (0.0096 + clearance, 0.0007 + clearance), (0.0079, 0.0017 + clearance)]
    for step in range(steps + 1):
        angle = turns * math.tau * step / steps
        z = -0.09 + pitch * angle / math.tau
        for radius, dz in profile:
            vertices.append((radius * math.cos(angle), radius * math.sin(angle), z + dz))
    for step in range(steps):
        for side in range(4):
            peer = (side + 1) % 4
            a = 4 * step + side
            b = 4 * step + peer
            faces.append((a, b, b + 4, a + 4))
    faces.extend([(3, 2, 1, 0), tuple((4 * steps + i for i in range(4)))])
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    bm = bmesh.new()
    bm.from_mesh(mesh)
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    bm.to_mesh(mesh)
    bm.free()
    return obj
thread = helix('StemThread')
thread_copy = thread.copy()
thread_copy.data = thread.data.copy()
bpy.context.collection.objects.link(thread_copy)
boolean(core, thread_copy, 'UNION')
core.name = 'ThreadedMovingValveCore'
nut = tube('ThreadedStemInsert', (-0.53, 0, 0.307), (-0.53, 0, 0.319), 0.0104)
boolean(nut, tube('NutMinorBore', (-0.53, 0, 0.3), (-0.53, 0, 0.325), 0.0081), 'DIFFERENCE')
cutter = helix('ThreadClearanceCutter', 0.00012)
cutter.location = Vector((-0.53, 0, 0.378))
boolean(nut, cutter, 'DIFFERENCE')
bpy.context.view_layer.update()
bm = bmesh.new()
bm.from_mesh(nut.data)
bm.transform(nut.matrix_world)
bm.normal_update()
nut_tree = BVHTree.FromBMesh(bm)
bm.free()
checks = []

def check(label, passed, **detail):
    checks.append(dict(label=label, passed=bool(passed), **detail))
for value in [0, 0.125, 0.25, 0.5, 0.75, 0.875, 1]:
    angle = value * math.tau * 3.5
    lift = value * 0.018
    pose = Matrix.Translation((-0.53, 0, 0.378 + lift)) @ Matrix.Rotation(angle, 4, 'Z')
    bm = bmesh.new()
    bm.from_mesh(thread.data)
    bm.transform(pose)
    bm.normal_update()
    moving = BVHTree.FromBMesh(bm)
    bm.free()
    clashes = moving.overlap(nut_tree)
    check('actual thread faces clear matching fixed nut through retained screw motion', not clashes, position=value, triangle_pairs=len(clashes))
boolean(housing, nut, 'UNION')
housing.name = 'ThreadedValveHousing'
bpy.data.objects.remove(thread, do_unlink=True)
packing = tube('FixedStemPacking', (-0.53, 0, 0.264), (-0.53, 0, 0.28), 0.0102)
boolean(packing, tube('SealBore', (-0.53, 0, 0.26), (-0.53, 0, 0.285), 0.008), 'DIFFERENCE')
check('thread begins above stem packing throughout lift', 0.378 - 0.09 - 0.0017 > 0.28)
material = housing.data.materials[0]
for obj in [housing, core, wheel, packing]:
    bpy.ops.object.select_all(action='DESELECT')
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bmesh.ops.remove_doubles(bm, verts=list(bm.verts), dist=1e-06)
    bmesh.ops.triangulate(bm, faces=list(bm.faces))
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    check('closed positive native threaded component', all((e.is_manifold for e in bm.edges)) and bm.calc_volume(signed=True) > 0, id=obj.name, nonmanifold=sum((not e.is_manifold for e in bm.edges)))
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
native = P / 'stem_screw_candidate.blend'
bpy.ops.wm.save_as_mainfile(filepath=str(native))
report = dict(evidence_class='INERT', scope='UNINSTALLED inferred screw/bonnet fit. Seven actual triangle checks follow retained authority motion, not a historical, pressure or runtime claim. Supply/union, graphite/metal finishes, pitch/shim, strict export and production integration remain pending.', lead_m_per_turn=pitch, native_sha256=hashlib.sha256(native.read_bytes()).hexdigest(), source_sha256=hashlib.sha256((P / 'stem_packing_candidate.blend').read_bytes()).hexdigest(), checks=checks, failures=[c for c in checks if not c['passed']])
(P / 'stem_screw_review.json').write_text(json.dumps(report, indent=2) + '\n')
print('STEM SCREW', len(checks), 'checks', len(report['failures']), 'failures', flush=True)
if report['failures']:
    raise RuntimeError(report['failures'])
