"""UNINSTALLED offset steam valve, with a real seat and moving poppet."""
from recipe_paths import repository_root, output_directory, primitive_source
from pathlib import Path
import ast, bpy, bmesh, json, math, hashlib, collections
from mathutils import Vector, Matrix
from mathutils.bvhtree import BVHTree
R = repository_root()
P = output_directory()
source = primitive_source()
parsed = ast.parse(source.read_text())
exec(compile(ast.Module(body=[n for n in parsed.body if isinstance(n, ast.FunctionDef) and n.name in ['tube', 'ellipsoid', 'boolean']], type_ignores=[]), str(source), 'exec'))
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.context.preferences.filepaths.save_version = 0

def cv(x, y, z):
    return (x, -z, y)
outside = [ellipsoid('GlobeCasting', cv(-0.53, 0.215, 0), (0.055, 0.058, 0.068)), tube('InletBoss', cv(-0.63, 0.19, 0), cv(-0.565, 0.19, 0), 0.033), tube('OffsetOutlet', cv(-0.505, 0.225, -0.03), cv(-0.475, 0.19, -0.055), 0.03), tube('UnionSpigot', cv(-0.49, 0.19, -0.055), cv(-0.445, 0.19, -0.055), 0.0265), tube('BonnetNeck', cv(-0.53, 0.255, 0), cv(-0.53, 0.304, 0), 0.028), tube('PackingWrenchFlats', cv(-0.53, 0.287, 0), cv(-0.53, 0.319, 0), 0.032, 6)]
bpy.ops.mesh.primitive_cone_add(vertices=32, radius1=0.041, radius2=0.033, depth=0.02, location=cv(-0.53, 0.275, 0))
outside.append(bpy.context.object)
housing = outside[0]
for obj in outside[1:]:
    boolean(housing, obj, 'UNION')
inside = [tube('InletSteam', cv(-0.64, 0.19, 0), cv(-0.565, 0.18, 0), 0.017), ellipsoid('LowerSteamChamber', cv(-0.55, 0.18, 0), (0.035, 0.027, 0.018)), tube('SeatAperture', cv(-0.53, 0.19, 0), cv(-0.53, 0.235, 0), 0.014), tube('PoppetWell', cv(-0.53, 0.2, 0), cv(-0.53, 0.242, 0), 0.022), ellipsoid('UpperSteamChamber', cv(-0.53, 0.24, -0.012), (0.035, 0.032, 0.027)), tube('OutletSteam', cv(-0.52, 0.242, -0.018), cv(-0.475, 0.19, -0.055), 0.018), tube('SpigotSteam', cv(-0.49, 0.19, -0.055), cv(-0.435, 0.19, -0.055), 0.018), tube('StemBore', cv(-0.53, 0.245, 0), cv(-0.53, 0.33, 0), 0.0103)]
void = inside[0]
for obj in inside[1:]:
    boolean(void, obj, 'UNION')
fluid = void.copy()
fluid.data = void.data.copy()
fluid.name = 'DIAGNOSTIC_FluidDomain'
fluid.hide_render = True
bpy.context.collection.objects.link(fluid)
boolean(housing, void, 'DIFFERENCE')
housing.name = 'OffsetSteamValveHousing'
core = tube('MovingValveCore', (0, 0, -0.178), (0, 0, -0.174), 0.0175)
stem = tube('ValveStem', (0, 0, -0.175), (0, 0, 0.012), 0.008)
boolean(core, stem, 'UNION')
core.name = 'MovingValveCore'
with bpy.data.libraries.load(str(R / 'art/blender/heating_distribution.blend'), link=False) as (available, loaded):
    loaded.materials = ['iron_neutral']
material = loaded.materials[0]
checks = []

def check(label, passed, **detail):
    checks.append(dict(label=label, passed=bool(passed), **detail))
for obj in [housing, core, fluid]:
    bpy.ops.object.select_all(action='DESELECT')
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    before_bad = sum((not e.is_manifold for e in bm.edges))
    bmesh.ops.remove_doubles(bm, verts=list(bm.verts), dist=1e-06)
    bmesh.ops.triangulate(bm, faces=list(bm.faces))
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    bm.to_mesh(obj.data)
    check('closed positive native valve component', all((e.is_manifold for e in bm.edges)) and bm.calc_volume(signed=True) > 0, id=obj.name, nonmanifold_before_weld=before_bad, nonmanifold_after_weld=sum((not e.is_manifold for e in bm.edges)), volume_m3=bm.calc_volume(signed=True))
    bm.free()
    obj.data.materials.clear()
    obj.data.materials.append(material)
    uv = obj.data.uv_layers.active or obj.data.uv_layers.new(name='Metres')
    for face in obj.data.polygons:
        face.material_index = 0
        face.use_smooth = obj != fluid
        normal = face.normal.normalized()
        seed = Vector((0, 0, 1))
        if abs(normal.dot(seed)) > 0.95:
            seed = Vector((1, 0, 0))
        u = seed.cross(normal).normalized()
        v = normal.cross(u).normalized()
        for loop in face.loop_indices:
            point = obj.data.vertices[obj.data.loops[loop].vertex_index].co
            uv.data[loop].uv = (point.dot(u) / 0.4, point.dot(v) / 0.4)

def tree(obj, pose=Matrix.Identity(4)):
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bm.transform(pose)
    bm.normal_update()
    result = BVHTree.FromBMesh(bm)
    bm.free()
    return result
fluid_tree = tree(fluid)

def within(bvh, point):
    votes = 0
    for direction in [Vector((1, 0.271, 0.137)).normalized(), Vector((0.193, 1, 0.317)).normalized(), Vector((0.239, 0.167, 1)).normalized()]:
        at = point.copy()
        hits = 0
        for _ in range(64):
            pos, normal, face, distance = bvh.ray_cast(at, direction, 1)
            if pos is None:
                break
            hits += 1
            at = pos + direction * 1e-06
        votes += hits % 2
    return votes >= 2
step = 0.003
low = Vector((-0.644, -0.052, 0.16))
shape = (72, 49, 57)
allowed = set()
for x in range(shape[0]):
    for y in range(shape[1]):
        for z in range(shape[2]):
            point = low + Vector((x * step, y * step, z * step))
            if within(fluid_tree, point):
                allowed.add((x, y, z))

def nearest(target):
    return min(allowed, key=lambda q: (low + Vector(q) * step - Vector(target)).length_squared)
inlet = nearest(cv(-0.62, 0.19, 0))
outlet = nearest(cv(-0.45, 0.19, -0.055))
check('voxel seeds remain inside actual native port datums', all(((low + Vector(q) * step - Vector(target)).length < 0.004 for q, target in [(inlet, cv(-0.62, 0.19, 0)), (outlet, cv(-0.45, 0.19, -0.055))])))
for label, lift, expected in [('unobstructed', None, True), ('closed', 0, False), ('open', 0.018, True)]:
    solid = tree(core, Matrix.Translation(cv(-0.53, 0.378 + lift, 0))) if lift is not None else None
    blocked = {q for q in allowed if within(solid, low + Vector(q) * step)} if solid is not None else set()
    queue = collections.deque([inlet])
    seen = {inlet}
    while queue:
        q = queue.popleft()
        for delta in [(1, 0, 0), (-1, 0, 0), (0, 1, 0), (0, -1, 0), (0, 0, 1), (0, 0, -1)]:
            peer = tuple((q[i] + delta[i] for i in range(3)))
            if peer in allowed and peer not in blocked and (peer not in seen):
                seen.add(peer)
                queue.append(peer)
    connected = outlet in seen
    check('actual native poppet controls sampled internal connectivity', connected == expected, state=label, lift_m=lift, connected=connected, grid_step_m=step, fluid_cells=len(allowed), reached_cells=len(seen))
    if solid is not None:
        at, normal, face, distance = solid.ray_cast(Vector(cv(-0.53, 0.197, 0)), Vector((0, 0, 1)), 0.04)
        check('poppet lower face follows retained 18mm lift', at is not None and abs(at.z - (0.2 + lift)) < 1e-06, state=label)
native = P / 'offset_valve_candidate.blend'
bpy.ops.wm.save_as_mainfile(filepath=str(native))
report = dict(evidence_class='INERT', scope='UNINSTALLED inferred valve core. Native 3mm cavity connectivity and real poppet lift only; no runtime/physical-fluid proof. Packing seal, handwheel/thread, riser elbow/union fit, strict export and source integration remain pending.', native_sha256=hashlib.sha256(native.read_bytes()).hexdigest(), checks=checks, failures=[c for c in checks if not c['passed']])
(P / 'offset_valve_review.json').write_text(json.dumps(report, indent=2) + '\n')
print('OFFSET VALVE', len(checks), 'checks', len(report['failures']), 'failures', flush=True)
if report['failures']:
    raise RuntimeError(report['failures'])
