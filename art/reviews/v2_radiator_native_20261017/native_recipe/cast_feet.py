"""UNINSTALLED rounded cast shoe, with retained floor and bearing datums."""
from recipe_paths import repository_root, output_directory, primitive_source
from pathlib import Path
import bpy, bmesh, math, json, hashlib
from mathutils import Vector, Matrix
from mathutils.bvhtree import BVHTree
R = repository_root()
P = output_directory()
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.context.preferences.filepaths.save_version = 0
profile = [(0, 0.048, 0.082), (0.006, 0.058, 0.095), (0.015, 0.052, 0.088), (0.027, 0.038, 0.047), (0.05, 0.032, 0.033), (0.085, 0.033, 0.034), (0.105, 0.035, 0.035)]
sides = 32
verts = []
faces = []
charts = []
tile = 0.4
arcs = []
meridians = [[0.0] * sides for _ in profile]
for row, (height, rx, rz) in enumerate(profile):
    points = [Vector((rx * math.cos(i * math.tau / sides), rz * math.sin(i * math.tau / sides), height)) for i in range(sides)]
    arc = [0.0]
    for i in range(sides):
        arc.append(arc[-1] + (points[(i + 1) % sides] - points[i]).length)
    arcs.append(arc)
    verts.extend(points)
    if row:
        for i in range(sides):
            meridians[row][i] = meridians[row - 1][i] + (verts[row * sides + i] - verts[(row - 1) * sides + i]).length
for row in range(len(profile) - 1):
    for i in range(sides):
        j = (i + 1) % sides
        faces.append((row * sides + i, row * sides + j, (row + 1) * sides + j, (row + 1) * sides + i))
        charts.append([(arcs[row][i], meridians[row][i]), (arcs[row][i + 1], meridians[row][j]), (arcs[row + 1][i + 1], meridians[row + 1][j]), (arcs[row + 1][i], meridians[row + 1][i])])
for indices in [tuple(reversed(range(sides))), tuple(((len(profile) - 1) * sides + i for i in range(sides)))]:
    faces.append(indices)
    charts.append([(verts[i].x, verts[i].y) for i in indices])
mesh = bpy.data.meshes.new('CastShoeFoot')
mesh.from_pydata(verts, [], faces)
mesh.update()
uv = mesh.uv_layers.new(name='Metres')
for polygon, chart in zip(mesh.polygons, charts):
    polygon.use_smooth = polygon.index < len(faces) - 2
    for loop, point in zip(polygon.loop_indices, chart):
        uv.data[loop].uv = (point[0] / tile, point[1] / tile)
foot = bpy.data.objects.new('CastShoeFoot', mesh)
bpy.context.collection.objects.link(foot)
with bpy.data.libraries.load(str(R / 'art/blender/heating_distribution.blend'), link=False) as (available, loaded):
    loaded.materials = ['iron_neutral']
material = loaded.materials[0]
mesh.materials.append(material)
checks = []

def check(label, passed, **detail):
    checks.append(dict(label=label, passed=bool(passed), **detail))
bm = bmesh.new()
bm.from_mesh(mesh)
check('closed positive one-piece cast shoe', all((e.is_manifold for e in bm.edges)) and bm.calc_volume(signed=True) > 0, volume_m3=bm.calc_volume(signed=True))
bm.free()
check('floor datum and existing 105mm end bearing retained', min((v.co.z for v in mesh.vertices)) == 0 and abs(max((v.co.z for v in mesh.vertices)) - 0.105) < 1e-06)
check('rounded shoe stays within retained foot envelope', max((abs(v.co.x) for v in mesh.vertices)) <= 0.065 and max((abs(v.co.y) for v in mesh.vertices)) <= 0.106)
mesh.calc_loop_triangles()
bad = 0
for tri in mesh.loop_triangles:
    a, b, c = [uv.data[i].uv for i in tri.loops]
    if abs((b.x - a.x) * (c.y - a.y) - (b.y - a.y) * (c.x - a.x)) < 1e-12:
        bad += 1
check('metric shoe UVs remain noncollapsed', bad == 0, bad=bad)
for node in material.node_tree.nodes:
    if node.type == 'TEX_IMAGE' and node.image:
        path = Path(bpy.path.abspath(node.image.filepath))
        check('existing custom PBR source resolves', path.is_file(), image=node.image.name)
native = P / 'cast_shoe_foot_candidate.blend'
bpy.ops.wm.save_as_mainfile(filepath=str(native))
with bpy.data.libraries.load(str(P / 'three_column_casting_candidate.blend'), link=False) as (available, loaded):
    loaded.objects = ['CastSectionThreeColumnCandidate']
casting = loaded.objects[0]
bpy.context.collection.objects.link(casting)
casting.hide_render = True
foot.hide_render = True
for i in range(8):
    obj = casting.copy()
    obj.data = casting.data
    obj.hide_render = False
    obj.location = Vector(((i - 3.5) * 0.092, 0, 0.105))
    bpy.context.collection.objects.link(obj)
for x in [-3.5 * 0.092, 3.5 * 0.092]:
    obj = foot.copy()
    obj.data = foot.data
    obj.hide_render = False
    obj.location.x = x
    bpy.context.collection.objects.link(obj)
    bm = bmesh.new()
    bm.from_mesh(casting.data)
    bm.transform(Matrix.Translation((x, 0, 0.105)))
    bm.normal_update()
    tree = BVHTree.FromBMesh(bm)
    bm.free()
    for index in range(8):
        angle = index * math.tau / 8
        origin = Vector((x + 0.02 * math.cos(angle), 0.02 * math.sin(angle), 0.1))
        at, normal, face, distance = tree.ray_cast(origin, Vector((0, 0, 1)), 0.01)
        check('new shoe bears on actual casting underside', at is not None and abs(at.z - 0.105) < 1e-06 and (normal.z < -0.99), foot_x=x, ray=index)
report = dict(evidence_class='INERT', scope='UNINSTALLED cast foot and section seating prototype. Original floor/bearing datums retained; valve, vent, end plugs, pitch/shim motion, strict export and runtime remain pending.', native_sha256=hashlib.sha256(native.read_bytes()).hexdigest(), checks=checks, failures=[c for c in checks if not c['passed']])
(P / 'cast_shoe_review.json').write_text(json.dumps(report, indent=2) + '\n')
print('CAST SHOE', len(checks), 'checks', len(report['failures']), 'failures', flush=True)
if report['failures']:
    raise RuntimeError(report['failures'])
