"""UNINSTALLED hollow air vent, float needle and five fixed orifice inserts."""
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
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.context.preferences.filepaths.save_version = 0
x = 0.043
seat = 0.0602
travel = 0.0055
body = ellipsoid('VentBody', (x, 0, 0.02), (0.024, 0.024, 0.044))
boolean(body, tube('TopNeck', (x, 0, 0.05), (x, 0, 0.066), 0.018, 64), 'UNION')
boolean(body, tube('ThreadedInlet', (-0.018, 0, 0), (x, 0, 0), 0.01, 64), 'UNION')
boolean(body, ellipsoid('AirChamber', (x, 0, 0.025), (0.019, 0.019, 0.035)), 'DIFFERENCE')
boolean(body, tube('CapSocket', (x, 0, 0.045), (x, 0, 0.07), 0.014, 64), 'DIFFERENCE')
boolean(body, tube('SteamAirInlet', (-0.024, 0, 0), (x, 0, 0), 0.0065, 64), 'DIFFERENCE')
cap = tube('VentCap', (x, 0, 0.054), (x, 0, 0.068), 0.0135, 64)
boolean(cap, tube('VentCapFlange', (x, 0, 0.066), (x, 0, 0.075), 0.019, 64), 'UNION')
boolean(cap, tube('ContinuousNeedleBore', (x, 0, 0.05), (x, 0, 0.08), 0.0012, 64), 'DIFFERENCE')
boolean(cap, tube('NeedleBellmouth', (x, 0, 0.05), (x, 0, seat), 0.004, 64), 'DIFFERENCE')
boolean(cap, tube('OrificeSocket', (x, 0, 0.061), (x, 0, 0.08), 0.0032, 64), 'DIFFERENCE')
float_bell = ellipsoid('FloatAndNeedle', (x, 0, 0.022), (0.008, 0.008, 0.017))
boolean(float_bell, tube('NeedleStem', (x, 0, 0.035), (x, 0, 0.054), 0.001, 64), 'UNION')
bpy.ops.mesh.primitive_cone_add(vertices=64, radius1=0.0015, radius2=0, depth=0.006, location=(x, 0, 0.0565))
boolean(float_bell, bpy.context.object, 'UNION')
boolean(float_bell, ellipsoid('SealedFloatCavity', (x, 0, 0.022), (0.0074, 0.0074, 0.0164)), 'DIFFERENCE')
weights = [0.3, 0.48, 0.72, 1.0, 1.32]
inserts = {}
for grade, weight in enumerate(weights):
    radius = 0.00085 * math.sqrt(weight / 0.72)
    obj = tube('VentOrificeInsert_%d' % grade, (x, 0, 0.067), (x, 0, 0.076), 0.003, 64)
    boolean(obj, tube('OrificeWrenchHead', (x, 0, 0.075), (x, 0, 0.079), 0.005, 6), 'UNION')
    boolean(obj, tube('InsertFeedBore', (x, 0, 0.064), (x, 0, 0.0775), radius * 1.2, 64), 'DIFFERENCE')
    boolean(obj, tube('RoomFacingOutlet', (x, -0.001, 0.077), (x, 0.006, 0.077), radius, 64), 'DIFFERENCE')
    inserts[grade] = obj
checks = []

def check(label, passed, **detail):
    checks.append(dict(label=label, passed=bool(passed), **detail))
with bpy.data.libraries.load(str(P / 'family_uv_candidate.blend'), link=False) as (available, loaded):
    loaded.materials = [n for n in available.materials if n.startswith('brass_dull')]
material = loaded.materials[-1]
for obj in [body, cap, float_bell] + list(inserts.values()):
    bpy.ops.object.select_all(action='DESELECT')
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bmesh.ops.remove_doubles(bm, verts=list(bm.verts), dist=1e-08)
    bmesh.ops.dissolve_degenerate(bm, edges=list(bm.edges), dist=1e-08)
    bmesh.ops.triangulate(bm, faces=list(bm.faces))
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    bm.normal_update()
    pending = set(bm.faces)
    boundaries = []
    while pending:
        boundary = {pending.pop()}
        queue = list(boundary)
        while queue:
            face = queue.pop()
            for edge in face.edges:
                for peer in edge.link_faces:
                    if peer in pending:
                        pending.remove(peer)
                        boundary.add(peer)
                        queue.append(peer)
        boundaries.append(boundary)
    expected = 2 if obj == float_bell else 1
    check('vent stock has its intended connected boundary count', len(boundaries) == expected, id=obj.name, boundaries=len(boundaries))
    if obj == float_bell:
        inner = [component for component in boundaries if all((((v.co.x - x) / 0.0074) ** 2 + (v.co.y / 0.0074) ** 2 + ((v.co.z - 0.022) / 0.0164) ** 2 <= 1.0001 for face in component for v in face.verts))]
        check('sealed float cavity remains nested inside its outer shell', len(inner) == 1)
        if len(inner) == 1:
            volume = sum((face.verts[0].co.dot(face.verts[1].co.cross(face.verts[2].co)) / 6 for face in inner[0]))
            if volume > 0:
                bmesh.ops.reverse_faces(bm, faces=list(inner[0]))
            volume = sum((face.verts[0].co.dot(face.verts[1].co.cross(face.verts[2].co)) / 6 for face in inner[0]))
            check('sealed cavity normals point into the void', volume < 0, void_signed_volume_m3=volume)
    check('vent stock has closed positive walls', all((edge.is_manifold for edge in bm.edges)) and bm.calc_volume(signed=True) > 0, id=obj.name, nonmanifold=sum((not e.is_manifold for e in bm.edges)))
    bm.to_mesh(obj.data)
    bm.free()
    obj.data.materials.clear()
    obj.data.materials.append(material)
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
body_tree = tree(body)
cap_tree = tree(cap)
for lift in [0, travel * 0.5, travel]:
    bell_tree = tree(float_bell, Matrix.Translation((0, 0, lift)))
    check('float and needle clear their chamber throughout travel', not bell_tree.overlap(body_tree), lift_m=lift)
    hits = bell_tree.overlap(cap_tree)
    bounded = True
    for first, second in hits:
        face = cap.data.polygons[second]
        points = [cap.data.vertices[index].co for index in face.vertices]
        lower_lip = all((abs(p.z - seat) < 1e-07 for p in points))
        bore_wall = all((seat - 1e-07 <= p.z <= 0.061 + 1e-07 and math.hypot(p.x - x, p.y) <= 0.001201 for p in points))
        bounded = bounded and (lower_lip or bore_wall)
    cone_radius_at_seat = max(0, (0.0595 + lift - seat) * 0.0015 / 0.006)
    check('needle closure contacts only the fixed seat without exceeding its bore', not hits or (lift == travel and bounded and (cone_radius_at_seat <= 0.0012 + 1e-07)), lift_m=lift, triangle_pairs=len(hits), cone_radius_m=cone_radius_at_seat)
for grade, obj in inserts.items():
    aperture = tree(obj)
    radius = 0.00085 * math.sqrt(weights[grade] / 0.72)
    for index in range(8):
        angle = index * math.tau / 8
        at, n, face, distance = aperture.ray_cast(Vector((x, 0.004, 0.077)), Vector((math.cos(angle), 0, math.sin(angle))), 0.005)
        check('fixed orifice has the authored grade radius', at is not None and abs(distance - radius) < 2e-06, grade=grade, ray=index, radius_m=radius, observed_m=distance)
    route = [Vector(p) for p in [(-0.023, 0, 0), (x + 0.011, 0, 0), (x + 0.011, 0, 0.0445), (x + 0.002, 0, 0.0515), (x + 0.002, 0, 0.0598), (x, 0, 0.0598), (x, 0, 0.077), (x, 0.006, 0.077)]]
    for state, lift in [('cold', 0), ('closed', travel)]:
        trees = [body_tree, cap_tree, aperture, tree(float_bell, Matrix.Translation((0, 0, lift)))]
        blocked = []
        for index, (a, b) in enumerate(zip(route, route[1:])):
            delta = b - a
            if any((t.ray_cast(a, delta.normalized(), delta.length)[0] is not None for t in trees)):
                blocked.append(index)
        check('actual routed air path opens cold and closes at the needle', bool(blocked) == (state == 'closed'), grade=grade, state=state, blocked_legs=blocked)
native = P / 'automatic_vent_candidate.blend'
bpy.ops.wm.save_as_mainfile(filepath=str(native))
report = dict(evidence_class='INERT', scope='UNINSTALLED hollow vent, sealed float/needle, fixed seat and5interchangeable fixed inserts. Native wall/bore/routed-air samples, not fluid/thermal/pressure simulation, production direct manipulation, final UV/export, room fit or human acceptance.', native_sha256=hashlib.sha256(native.read_bytes()).hexdigest(), orifice_weights=weights, needle_travel_m=travel, checks=checks, failures=[c for c in checks if not c['passed']])
(P / 'automatic_vent_review.json').write_text(json.dumps(report, indent=2) + '\n')
print('AUTOMATIC VENT', len(checks), 'checks', len(report['failures']), 'failures', flush=True)
if report['failures']:
    raise RuntimeError(report['failures'])
