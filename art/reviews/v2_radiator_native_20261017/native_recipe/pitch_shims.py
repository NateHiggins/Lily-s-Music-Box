"""UNINSTALLED fitted wood wedges under the raised native shoe."""
from recipe_paths import repository_root, output_directory, primitive_source
from pathlib import Path
import bpy, bmesh, json, math, hashlib, sys
from mathutils import Vector, Matrix
from mathutils.bvhtree import BVHTree
R = repository_root()
P = output_directory()
bpy.ops.wm.open_mainfile(filepath=str(P / 'family_uv_candidate.blend'))
sys.path.insert(0, str(R / 'art/blender/scripts'))
from fabrication_native_batch import material
from fabrication_normals import stock_corner_normals
catalog = json.loads((R / 'game/data/runtime_material_sets.json').read_text())['materials']
wood = material(R, 'PitchShimTimber', dict(catalog_key='timber', normal=0.35, roughness=1, tint=[0.62, 0.52, 0.4], pigment=1), catalog)
poses = json.loads((P / 'pitch_kinematics_review.json').read_text())
assert not poses['failures']
foot = bpy.data.objects['CastShoeFoot']
casting = bpy.data.objects['CastSectionThreeColumnCandidate']
checks = []
stocks = []
groups = {}

def check(label, passed, **detail):
    checks.append(dict(label=label, passed=bool(passed), **detail))
for row in poses['poses']:
    if not row['pitch']:
        continue
    count = row['sections']
    half = (count - 1) * 0.092 / 2
    shift = max(0, half - 0.322)
    body = Matrix(row['body_matrix'])
    for side, x in [('supply', -half), ('far', half)]:
        pose = body @ Matrix.Translation((x + shift, 0.03, 0))
        sole = [pose @ v.co for v in foot.data.vertices if abs(v.co.z) < 1e-07]
        if min((point.z for point in sole)) < 1e-07:
            continue
        low = [min((point[i] for point in sole)) - 0.005 for i in range(2)]
        high = [max((point[i] for point in sole)) + 0.005 for i in range(2)]
        normal = pose.to_3x3() @ Vector((0, 0, 1))
        origin = pose @ Vector((0, 0, 0))

        def height(x, y):
            return origin.z - (normal.x * (x - origin.x) + normal.y * (y - origin.y)) / normal.z
        points = [Vector((x, y, height(x, y))) for x, y in [(low[0], low[1]), (high[0], low[1]), (high[0], high[1]), (low[0], high[1])]]
        assert min((point.z for point in points)) > 0
        points += [Vector((p.x, p.y, 0)) for p in points]
        bm = bmesh.new()
        verts = [bm.verts.new(point) for point in points]
        bmesh.ops.convex_hull(bm, input=verts, use_existing_faces=False)
        bmesh.ops.triangulate(bm, faces=list(bm.faces))
        bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
        bm.normal_update()
        label = 'Shim_%d_%s_%s' % (count, str(row['pitch']).replace('-', 'minus'), side)
        check('fitted wedge is closed positive stock above the floor', all((e.is_manifold for e in bm.edges)) and bm.calc_volume(signed=True) > 0 and (min((v.co.z for v in bm.verts)) >= 0), id=label)
        bvh = BVHTree.FromBMesh(bm)
        for x, y in [(0, 0), (-0.02, 0), (0.02, 0), (0, -0.03), (0, 0.03)]:
            point = pose @ Vector((x, y, 0))
            at, n, face, distance = bvh.ray_cast(point + Vector((0, 0, 0.001)), Vector((0, 0, -1)), 0.01)
            check('actual wedge top supports the actual sole plane', at is not None and abs(distance - 0.001) < 1e-06 and (n.z > 0.99), id=label, x=x, y=y, ray_distance_m=distance)
        mesh = bpy.data.meshes.new(label)
        bm.to_mesh(mesh)
        bm.free()
        uv = mesh.uv_layers.new(name='Metres')
        for face in mesh.polygons:
            n = face.normal.normalized()
            u = Vector((1, 0, 0)) if abs(n.x) < 0.95 else Vector((0, 1, 0))
            u = (u - n * n.dot(u)).normalized()
            v = n.cross(u)
            for loop in face.loop_indices:
                point = mesh.vertices[mesh.loops[loop].vertex_index].co
                uv.data[loop].uv = (point.dot(u), point.dot(v))
        mesh.calc_loop_triangles()
        areas = []
        for tri in mesh.loop_triangles:
            a, b, c = [uv.data[loop].uv for loop in tri.loops]
            areas.append(abs((b - a).cross(c - a)) * 0.5)
        check('every wedge triangle has a noncollapsed metric chart', all((area > 1e-14 for area in areas)), id=label, minimum_uv_area_m2=min(areas))
        mesh.materials.append(wood)
        mesh.normals_split_custom_set(stock_corner_normals(mesh))
        obj = bpy.data.objects.new(label, mesh)
        bpy.context.collection.objects.link(obj)
        obj.hide_render = True
        stocks.append(dict(id=label, sections=count, pitch=row['pitch'], side=side, minimum_height_m=min((p.z for p in points[:4])), maximum_height_m=max((p.z for p in points[:4]))))
        groups[count, row['pitch']] = obj
native = P / 'pitch_shims_candidate.blend'
bpy.ops.wm.save_as_mainfile(filepath=str(native))
report = dict(evidence_class='INERT', scope='UNINSTALLED native wood wedge supporting the raised shoe at16non-neutral poses. Lower shoe bears on floor. Does not model spherical seats, service-union travel, final exported UV/tangents, actual room fit of articulated parts, production runtime or human acceptance.', native_sha256=hashlib.sha256(native.read_bytes()).hexdigest(), pose_source_sha256=hashlib.sha256((P / 'pitch_kinematics_review.json').read_bytes()).hexdigest(), stocks=stocks, checks=checks, failures=[c for c in checks if not c['passed']])
(P / 'pitch_shims_review.json').write_text(json.dumps(report, indent=2) + '\n')
print('PITCH SHIMS', len(stocks), 'stocks', len(checks), 'checks', len(report['failures']), 'failures', flush=True)
if report['failures']:
    raise RuntimeError(report['failures'])
