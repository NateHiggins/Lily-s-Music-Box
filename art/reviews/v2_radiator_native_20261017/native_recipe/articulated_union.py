"""UNINSTALLED spherical feed joints; actual native fit across solved pitches."""
from recipe_paths import repository_root, output_directory, primitive_source
from pathlib import Path
import ast, bpy, bmesh, json, math, hashlib
from mathutils import Vector, Matrix
from mathutils.bvhtree import BVHTree
R = repository_root()
P = output_directory()
source = primitive_source()
parsed = ast.parse(source.read_text())
exec(compile(ast.Module(body=[n for n in parsed.body if isinstance(n, ast.FunctionDef) and n.name in ['tube', 'ellipsoid', 'boolean']], type_ignores=[]), str(source), 'exec'))
bpy.ops.wm.open_mainfile(filepath=str(P / 'family_uv_candidate.blend'))
source_objects = {o.name: o for o in bpy.data.objects if o.type == 'MESH'}
housing = source_objects['SocketedThreadedValveHousing']
a = Vector((-0.455, 0.085, 0.19))
metal = housing.data.materials[0]
poses = json.loads((P / 'pitch_kinematics_review.json').read_text())
assert not poses['failures']

def lathe(name, profile, sides=64):
    vertices = []
    faces = []
    for x, radius in profile:
        for index in range(sides):
            angle = index * math.tau / sides
            vertices.append((x, radius * math.cos(angle), radius * math.sin(angle)))
    for row in range(len(profile)):
        other = (row + 1) % len(profile)
        for index in range(sides):
            peer = (index + 1) % sides
            faces.append((row * sides + index, row * sides + peer, other * sides + peer, other * sides + index))
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    return obj

def sphere_profile(radius, start, end, steps):
    return [(start + (end - start) * i / steps, math.sqrt(radius * radius - (start + (end - start) * i / steps) ** 2)) for i in range(steps + 1)]

def retainer(name, right):
    obj = tube(name, (-0.012, 0, 0), (right, 0, 0), 0.052, 6)
    bpy.ops.mesh.primitive_uv_sphere_add(segments=128, ring_count=64, radius=0.0424)
    boolean(obj, bpy.context.object, 'DIFFERENCE')
    boolean(obj, tube('StemAngularClearance', (-0.02, 0, 0), (0.003, 0, 0), 0.038, 64), 'DIFFERENCE')
    boolean(obj, tube('NeckClearance', (0.026, 0, 0), (0.04, 0, 0), 0.0271, 64), 'DIFFERENCE')
    return obj
bpy.ops.mesh.primitive_cube_add(size=1, location=(a.x - 0.03 + 0.5, 0, 0))
clip = bpy.context.object
clip.scale = (1, 3, 3)
boolean(housing, clip, 'DIFFERENCE')
ball = lathe('FixedValveBall', [(-0.036, 0.0265)] + sphere_profile(0.032, -0.025, 0.025, 40) + [(0.025, 0.018), (-0.036, 0.018)])
ball.location = a
boolean(housing, ball, 'UNION')
housing.name = 'ArticulatedValveHousing'
boolean(housing, tube('ContinuousBallBore', (a.x - 0.05, a.y, a.z), (a.x + 0.03, a.y, a.z), 0.018, 64), 'DIFFERENCE')
neck_parts = {}
for count in [7, 8, 9, 10]:
    sample = next((row for row in poses['poses'] if row['sections'] == count))
    length = sample['feed_length_m']
    outer = sphere_profile(0.042, 0, 0.027, 18) + [(0.033, 0.0265), (length - 0.018, 0.0265)] + [(length + x, r) for x, r in sphere_profile(0.032, -0.016, 0.025, 30)]
    inner = [(length + 0.025, 0.018), (0.033, 0.018), (0.027, 0.018)] + list(reversed(sphere_profile(0.0322, 0, 0.025, 18)))
    neck_parts[count] = lathe('SphericalNeck_%d' % count, outer + inner)
socket = lathe('HeaderSphericalSocket', sphere_profile(0.042, 0, 0.023, 18) + [(0.025, 0.0265), (0.045, 0.0265), (0.045, 0.019), (0.027, 0.019)] + list(reversed(sphere_profile(0.0322, 0, 0.025, 18))))
ring_x = [-0.025 + 0.008 * i / 16 for i in range(17)]
ring = lathe('FloatingMetalBearingRing', [(x, math.sqrt(0.042 ** 2 - x * x)) for x in ring_x] + [(x, max(0.027, math.sqrt(0.03215 ** 2 - x * x))) for x in reversed(ring_x)])
valve_nut = retainer('ValveSphericalRetainer', 0.03)
header_nut = retainer('HeaderSphericalRetainer', 0.022)
parts = [housing, socket, ring, valve_nut, header_nut] + list(neck_parts.values())
checks = []

def check(label, passed, **detail):
    checks.append(dict(label=label, passed=bool(passed), **detail))
for obj in parts:
    bpy.ops.object.select_all(action='DESELECT')
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    tolerance = 1e-06 if obj == housing else 1e-07
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bmesh.ops.remove_doubles(bm, verts=list(bm.verts), dist=tolerance)
    bmesh.ops.dissolve_degenerate(bm, edges=list(bm.edges), dist=tolerance)
    bmesh.ops.triangulate(bm, faces=list(bm.faces))
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    bm.normal_update()
    check('closed positive spherical fitting stock', all((e.is_manifold for e in bm.edges)) and bm.calc_volume(signed=True) > 0, id=obj.name, nonmanifold=sum((not e.is_manifold for e in bm.edges)))
    pending = set(bm.verts)
    components = 0
    while pending:
        components += 1
        queue = [pending.pop()]
        while queue:
            vertex = queue.pop()
            for edge in vertex.link_edges:
                peer = edge.other_vert(vertex)
                if peer in pending:
                    pending.remove(peer)
                    queue.append(peer)
    check('each fitting is one connected native stock', components == 1, id=obj.name, components=components)
    bm.to_mesh(obj.data)
    bm.free()
    obj.data.materials.clear()
    obj.data.materials.append(metal)
    obj.hide_render = True
    uv = obj.data.uv_layers.active or obj.data.uv_layers.new(name='Metres')
    for face in obj.data.polygons:
        face.material_index = 0
        face.use_smooth = True
        n = face.normal.normalized()
        seed = Vector((0, 0, 1)) if abs(n.z) < 0.95 else Vector((1, 0, 0))
        u = seed.cross(n).normalized()
        v = n.cross(u)
        for loop in face.loop_indices:
            p = obj.data.vertices[obj.data.loops[loop].vertex_index].co
            uv.data[loop].uv = (p.dot(u), p.dot(v))

def tree(obj, pose=Matrix.Identity(4)):
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bm.transform(pose)
    bm.normal_update()
    result = BVHTree.FromBMesh(bm)
    bm.free()
    return result
fixed_tree = tree(housing)
at, normal, face, distance = fixed_tree.ray_cast(Vector((a.x - 0.033, a.y, a.z)), Vector((1, 0, 0)), 0.065)
check('fixed replacement ball retains an open axial outlet', at is None, hit_distance_m=distance)
for obj, start, length in [(socket, -0.001, 0.049)] + [(neck_parts[count], -0.001, next((r for r in poses['poses'] if r['sections'] == count))['feed_length_m'] + 0.028) for count in [7, 8, 9, 10]]:
    at, normal, face, distance = tree(obj).ray_cast(Vector((start, 0, 0)), Vector((1, 0, 0)), length)
    check('new socket and rigid neck retain open axial bores', at is None, id=obj.name, hit_distance_m=distance)
for row in poses['poses']:
    count = row['sections']
    body = Matrix(row['body_matrix'])
    beta = row['feed_angle_radians']
    theta = row['body_angle_radians']
    b = Vector(row['header_joint'])
    up = Matrix.Translation(a) @ Matrix.Rotation(-beta, 4, 'Y')
    down = Matrix.Translation(b) @ Matrix.Rotation(-theta, 4, 'Y')
    bearing = Matrix.Translation(b) @ Matrix.Rotation(-beta, 4, 'Y')
    targets = {'neck': tree(neck_parts[count], up), 'valve_ring': tree(ring, Matrix.Translation(a)), 'valve_nut': tree(valve_nut, up), 'header_socket': tree(socket, down), 'header_ring': tree(ring, bearing), 'header_nut': tree(header_nut, down), 'housing': fixed_tree}
    pairs = [('housing', 'neck'), ('housing', 'valve_ring'), ('housing', 'valve_nut'), ('neck', 'valve_ring'), ('neck', 'valve_nut'), ('neck', 'header_socket'), ('neck', 'header_ring'), ('neck', 'header_nut'), ('valve_ring', 'valve_nut'), ('header_ring', 'header_nut'), ('header_socket', 'header_ring'), ('header_socket', 'header_nut')]
    for first, second in pairs:
        hits = targets[first].overlap(targets[second])
        check('native articulated components clear one another', not hits, sections=count, pitch=row['pitch'], a=first, b=second, triangle_pairs=len(hits))
    half = (count - 1) * 0.092 / 2
    shift = max(0, half - 0.322)
    for index in range(count):
        cast_tree = tree(source_objects['CastSectionThreeColumnCandidate'], body @ Matrix.Translation(((index - (count - 1) / 2) * 0.092 + shift, 0.03, 0.105)))
        for key in ['header_socket', 'header_nut', 'header_ring', 'neck']:
            hits = cast_tree.overlap(targets[key])
            check('articulated fittings clear every casting', not hits, sections=count, pitch=row['pitch'], index=index, part=key, triangle_pairs=len(hits))
native = P / 'articulated_union_candidate.blend'
bpy.ops.wm.save_as_mainfile(filepath=str(native))
report = dict(evidence_class='INERT', scope='UNINSTALLED actual native spherical fittings and casting clearance across20solvedpitchposes. No pressure/flow, service opening, removable packing, final UV/export, room-fit, runtime or human acceptance.', reference='https://patents.google.com/patent/US1076921A/en', native_sha256=hashlib.sha256(native.read_bytes()).hexdigest(), kinematics_sha256=hashlib.sha256((P / 'pitch_kinematics_review.json').read_bytes()).hexdigest(), checks=checks, failures=[c for c in checks if not c['passed']])
(P / 'articulated_union_review.json').write_text(json.dumps(report, indent=2) + '\n')
print('ARTICULATED UNION', len(checks), 'checks', len(report['failures']), 'failures', flush=True)
if report['failures']:
    raise RuntimeError(report['failures'])
