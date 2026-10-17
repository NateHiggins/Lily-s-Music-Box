"""UNINSTALLED swept supply and service union, reviewed at every authored count."""
from recipe_paths import repository_root, output_directory, primitive_source
from pathlib import Path
import ast, bpy, bmesh, json, math, hashlib, sys, os
from mathutils import Vector, Matrix
from mathutils.bvhtree import BVHTree
R = repository_root()
P = output_directory()
source = primitive_source()
parsed = ast.parse(source.read_text())
exec(compile(ast.Module(body=[n for n in parsed.body if isinstance(n, ast.FunctionDef) and n.name in ['tube', 'boolean']], type_ignores=[]), str(source), 'exec'))
sys.path.insert(0, str(R / 'tools'))
from heating_pipe_fittings import fitted_stations
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.context.preferences.filepaths.save_version = 0

def load(file, names):
    with bpy.data.libraries.load(str(P / file), link=False) as (available, loaded):
        loaded.objects = names
    for obj in loaded.objects:
        bpy.context.collection.objects.link(obj)
        obj.hide_render = True
    return loaded.objects
housing, core, wheel, packing = load('stem_screw_candidate.blend', ['ThreadedValveHousing', 'ThreadedMovingValveCore', 'SixSpokeHandwheel', 'FixedStemPacking'])
casting = load('three_column_casting_candidate.blend', ['CastSectionThreeColumnCandidate'])[0]
foot = load('cast_shoe_foot_candidate.blend', ['CastShoeFoot'])[0]
blind, reducer, washer = load('header_fittings_candidate.blend', ['BlindHeaderPlug', 'VentHeaderReducer', 'HeaderSealWasher'])
material = housing.data.materials[0]
stand_off = 0.03

def cv(x, y, z):
    return Vector((x, -z, y))
boolean(housing, tube('InletFemaleSocket', cv(-0.64, 0.19, 0), cv(-0.608, 0.19, 0), 0.0293), 'DIFFERENCE')
housing.name = 'SocketedThreadedValveHousing'
spigot = tube('ExtendedUnionSpigot', cv(-0.449, 0.19, -0.055), cv(-0.435, 0.19, -0.055), 0.0265)
boolean(spigot, tube('ExtendedSpigotBore', cv(-0.452, 0.19, -0.055), cv(-0.432, 0.19, -0.055), 0.018), 'DIFFERENCE')
boolean(housing, spigot, 'UNION')
stations = fitted_stations([cv(-0.67, 0, 0), cv(-0.67, 0.19, 0), cv(-0.61, 0.19, 0)], radius=0.04, steps=16)
lower = []
for index in range(17):
    u = index / 16
    lower.append(([-0.67, stand_off * u * u * (3 - 2 * u), 0.15 * u], Vector((0, stand_off * 6 * u * (1 - u) / 0.15, 1)).normalized()))
stations = lower + [(Vector(point) + Vector((0, stand_off, 0)), tangent) for point, tangent in stations[2:]]
vertices = []
faces = []
sides = 32
last_t = Vector(stations[0][1])
u = Vector((1, 0, 0))
for point, tangent in stations:
    point, tangent = (Vector(point), Vector(tangent))
    u = last_t.rotation_difference(tangent) @ u
    u.normalize()
    last_t = tangent
    v = tangent.cross(u).normalized()
    for radius in [0.029, 0.024]:
        for index in range(sides):
            angle = index * math.tau / sides
            vertices.append(point + radius * (u * math.cos(angle) + v * math.sin(angle)))
for row in range(len(stations) - 1):
    for layer in range(2):
        for index in range(sides):
            peer = (index + 1) % sides
            a = row * 2 * sides + layer * sides + index
            b = row * 2 * sides + layer * sides + peer
            faces.append((a, b, b + 2 * sides, a + 2 * sides))
for row in [0, len(stations) - 1]:
    for index in range(sides):
        peer = (index + 1) % sides
        a = row * 2 * sides + index
        b = row * 2 * sides + peer
        faces.append((a, a + sides, b + sides, b))
mesh = bpy.data.meshes.new('SweptSupplyElbow')
mesh.from_pydata(vertices, [], faces)
mesh.update()
supply = bpy.data.objects.new('SweptSupplyElbow', mesh)
bpy.context.collection.objects.link(supply)

def annulus(name, a, b, outer, inner, sides=32):
    obj = tube(name, cv(a, 0.19, -0.055), cv(b, 0.19, -0.055), outer, sides)
    boolean(obj, tube(name + 'Bore', cv(a - 0.002, 0.19, -0.055), cv(b + 0.002, 0.19, -0.055), inner), 'DIFFERENCE')
    return obj
upstream = tube('FixedUnionSocket', cv(-0.455, 0.19, -0.055), cv(-0.411, 0.19, -0.055), 0.033, 32)
flange = tube('UpstreamSeatFlange', cv(-0.418, 0.19, -0.055), cv(-0.411, 0.19, -0.055), 0.042, 32)
boolean(upstream, flange, 'UNION')
boolean(upstream, tube('UnionThroughBore', cv(-0.46, 0.19, -0.055), cv(-0.408, 0.19, -0.055), 0.019), 'DIFFERENCE')
boolean(upstream, tube('ValveSpigotCounterbore', cv(-0.46, 0.19, -0.055), cv(-0.432, 0.19, -0.055), 0.0268), 'DIFFERENCE')
nut = annulus('BackoffUnionNut', -0.444, -0.388, 0.052, 0.0423, 6)
shoulder = annulus('NutRetainingShoulder', -0.398, -0.388, 0.047, 0.0271)
boolean(nut, shoulder, 'UNION')
seal = annulus('RemovableUnionPacking', -0.411, -0.409, 0.036, 0.019)
checks = []

def check(label, passed, **detail):
    checks.append(dict(label=label, passed=bool(passed), **detail))

def finish(obj):
    bpy.ops.object.select_all(action='DESELECT')
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bmesh.ops.remove_doubles(bm, verts=list(bm.verts), dist=1e-06)
    bmesh.ops.dissolve_degenerate(bm, edges=list(bm.edges), dist=1e-06)
    bmesh.ops.triangulate(bm, faces=list(bm.faces))
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    check('closed positive mechanical stock', all((e.is_manifold for e in bm.edges)) and bm.calc_volume(signed=True) > 0, id=obj.name, nonmanifold=sum((not e.is_manifold for e in bm.edges)))
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
    obj.hide_render = True
parts = [housing, supply, upstream, nut, seal]
tails = {}
for count in [7, 8, 9, 10]:
    half = (count - 1) * 0.092 / 2
    shift = max(0, half - 0.322)
    port = -half + shift - 0.046
    tail = annulus('HeaderTail_%d' % count, -0.409, port + 0.02, 0.0265, 0.019)
    flange = annulus('DownstreamSeat_%d' % count, -0.409, -0.398, 0.04, 0.019)
    boolean(tail, flange, 'UNION')
    tails[count] = tail
    parts.append(tail)
for obj in parts:
    if obj != supply:
        obj.location.y += stand_off
    finish(obj)

def tree(obj, pose=Matrix.Identity(4)):
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bm.transform(pose @ obj.matrix_world)
    bm.normal_update()
    result = BVHTree.FromBMesh(bm)
    bm.free()
    return result
fixed = [housing, supply, upstream]
for a, b in [(housing, nut), (housing, upstream), (housing, supply)]:
    hits = tree(a).overlap(tree(b))
    check('socket stocks clear at fitted male and female radii', not hits, a=a.name, b=b.name, triangle_pairs=len(hits))
for index, (point, tangent) in enumerate(stations):
    if index in [0, len(stations) - 1]:
        continue
    at, normal, face, distance = tree(supply).find_nearest(Vector(point))
    check('swept pipe centerline stays in its open bore', at is not None and distance > 0.022, station=index, nearest_wall_m=distance)
for count, tail in tails.items():
    half = (count - 1) * 0.092 / 2
    shift = max(0, half - 0.322)
    for opening in [0, 0.5, 1]:
        drift = 0.028 * opening
        nut_shift = -0.016 * opening
        active_nut = tree(nut, Matrix.Translation((nut_shift, 0, 0)))
        for part in [housing, supply]:
            hits = active_nut.overlap(tree(part))
            check('nut backs away from valve and floor elbow without intersection', not hits, sections=count, opening=opening, other=part.name, triangle_pairs=len(hits))
        for index in range(count):
            pose = Matrix.Translation(((index - (count - 1) / 2) * 0.092 + shift + drift, stand_off, 0.105))
            cast_tree = tree(casting, pose)
            for part, part_tree in [('valve', tree(housing)), ('nut', active_nut)]:
                hits = cast_tree.overlap(part_tree)
                check('every casting clears fixed valve and backed-off nut', not hits, sections=count, opening=opening, index=index, other=part, triangle_pairs=len(hits))
        tail_tree = tree(tail, Matrix.Translation((drift, 0, 0)))
        at, normal, face, distance = tail_tree.ray_cast(cv(-0.408 + drift, 0.19, -0.055 - stand_off), Vector((1, 0, 0)), 0.2)
        check('downstream tail has a real open bore', at is None, sections=count, opening=opening)
    check('left header datum reserves closed nut clearance', -half + shift - 0.046 - -0.388 >= 0.0199, sections=count, body_shift_m=shift, left_header_x=-half + shift - 0.046)
native = P / 'union_family_stock_candidate.blend'
bpy.ops.wm.save_as_mainfile(filepath=str(native))
report = dict(evidence_class='INERT', scope='UNINSTALLED neutral-pitch family. Actual native wheel/nut/body travel clearance for all7/8/9/10counts, hollow supply and service union. Positive heat pitch, shim/foot contact, body room fit, all seal surfaces, final UV/PBR/export and production interaction integration remain pending. No runtime, full-containment, pressure or human acceptance.', native_sha256=hashlib.sha256(native.read_bytes()).hexdigest(), checks=checks, failures=[c for c in checks if not c['passed']])
(P / 'union_family_review.json').write_text(json.dumps(report, indent=2) + '\n')
print('UNION FAMILY', len(checks), 'checks', len(report['failures']), 'failures', flush=True)
if report['failures']:
    raise RuntimeError(report['failures'])
