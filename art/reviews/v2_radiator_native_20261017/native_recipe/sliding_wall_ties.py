"""Native slotted anti-tip brackets; radiator ties slide during pitch/service.

The building brackets stay fixed. A welded T-head behind each slot restrains
wall-normal movement while allowing the reviewed horizontal service travel.
"""
from recipe_paths import repository_root, output_directory, primitive_source
from pathlib import Path
import bpy, bmesh, json, math, hashlib, sys
from mathutils import Vector, Matrix
from mathutils.bvhtree import BVHTree
R = repository_root()
P = output_directory()
from primitives import tube, boolean
sys.path.insert(0, str(R / 'art/blender/scripts'))
from fabrication_native_batch import material
from fabrication_normals import stock_corner_normals
plan = json.loads((P / 'wall_tie_mount_plan.json').read_text())
assert len(plan['ties']) == 46 and (not plan['missing'])
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.context.preferences.filepaths.save_version = 0
catalog = json.loads((R / 'game/data/runtime_material_sets.json').read_text())['materials']
materials = {key: material(R, key, dict(catalog_key=key, normal=0.35, roughness=catalog[key]['roughness_multiplier'], pigment=1, tint=[1, 1, 1]), catalog) for key in ['iron_neutral', 'iron_blackened']}

def block(name, center, size):
    bpy.ops.mesh.primitive_cube_add(size=1, location=center)
    obj = bpy.context.object
    obj.name = name
    obj.scale = size
    bpy.ops.object.transform_apply(location=True, rotation=False, scale=True)
    return obj

def finish(obj, key, weld=True):
    bpy.ops.object.select_all(action='DESELECT')
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    if weld:
        bmesh.ops.remove_doubles(bm, verts=list(bm.verts), dist=1e-06)
    bmesh.ops.dissolve_degenerate(bm, edges=list(bm.edges), dist=1e-06)
    bmesh.ops.triangulate(bm, faces=list(bm.faces))
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    bm.to_mesh(obj.data)
    bm.free()
    mesh = obj.data
    for layer in list(mesh.uv_layers):
        mesh.uv_layers.remove(layer)
    mesh.uv_layers.new(name='Metres')
    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.uv.smart_project(angle_limit=math.radians(58), island_margin=0.01)
    bpy.ops.uv.seams_from_islands(mark_seams=True, mark_sharp=False)
    bpy.ops.uv.unwrap(method='ANGLE_BASED', margin=0.005)
    bpy.ops.uv.average_islands_scale()
    bpy.ops.object.mode_set(mode='OBJECT')
    mesh.calc_loop_triangles()
    uv = mesh.uv_layers.active.data

    def area(tri):
        a, b, c = [uv[i].uv for i in tri.loops]
        return abs((b - a).cross(c - a)) * 0.5
    scale = math.sqrt(sum((t.area for t in mesh.loop_triangles)) / sum((area(t) for t in mesh.loop_triangles)))
    for loop in uv:
        loop.uv *= scale
    mesh.normals_split_custom_set(stock_corner_normals(mesh))
    mesh.materials.clear()
    mesh.materials.append(materials[key])
    for face in mesh.polygons:
        face.material_index = 0
        face.use_smooth = True
    obj['proposed_material_key'] = key
    obj.hide_render = True
    return obj
outer = [(-0.035, -0.075), (0.075, -0.075), (0.075, 0.095), (-0.035, 0.095)]
inner = [(-0.02, -0.02), (0.06, -0.02), (0.06, 0.04), (-0.02, 0.04)]
vertices = [(x, y, z) for y in [-0.004, 0] for x, z in outer + inner]
faces = []
for i in range(4):
    j = (i + 1) % 4
    faces.extend([(i, j, j + 4, i + 4), (i + 8, i + 12, j + 12, j + 8), (i, i + 8, j + 8, j), (i + 4, j + 4, j + 12, i + 12)])
mesh = bpy.data.meshes.new('SlottedWallBracket')
mesh.from_pydata(vertices, [], faces)
mesh.update()
plate = bpy.data.objects.new('SlottedWallBracket', mesh)
bpy.context.collection.objects.link(plate)
bm = bmesh.new()
bm.from_mesh(mesh)
bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
bm.to_mesh(mesh)
bm.free()
for z in [0.08, -0.06]:
    boolean(plate, tube('WeldedStandOff', (0.02, -0.02, z), (0.02, -0.0035, z), 0.007, 32), 'UNION')
    boolean(plate, tube('ContinuousAnchorBore', (0.02, -0.025, z), (0.02, 0.005, z), 0.0032, 32), 'DIFFERENCE')
plate = finish(plate, 'iron_blackened')
hardware = {}
for rear in sorted({round(t['wall_point_actor_blender'][1] - 0.025 - t['bracket_front_y'], 5) for t in plan['ties']}):
    parts = []
    for z in [0.08, -0.06]:
        stud = tube('AnchorStud', (0.02, rear, z), (0.02, 0.008, z), 0.003, 24)
        parts.append(stud)
        washer = tube('AnchorWasher', (0.02, 0, z), (0.02, 0.0015, z), 0.01, 32)
        boolean(washer, tube('WasherBore', (0.02, -0.002, z), (0.02, 0.004, z), 0.0032, 32), 'DIFFERENCE')
        parts.append(washer)
        nut = tube('AnchorNut', (0.02, 0.0015, z), (0.02, 0.0065, z), 0.006, 6)
        boolean(nut, tube('NutBore', (0.02, 0, z), (0.02, 0.009, z), 0.0032, 32), 'DIFFERENCE')
        parts.append(nut)
    bpy.ops.object.select_all(action='DESELECT')
    for obj in parts:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = parts[0]
    bpy.ops.object.join()
    obj = bpy.context.object
    obj.name = 'WallAnchors_%dum' % round(-rear * 1000000.0)
    hardware[rear] = finish(obj, 'iron_neutral', weld=False)
rods = {}
for tail in sorted({round(t['tie_tail_y_from_column'], 5) for t in plan['ties']}):
    collar = tube('MovingTie_%dum' % round(-tail * 1000000.0), (0, 0, -0.011), (0, 0, 0.011), 0.0265, 64)
    boolean(collar, tube('ColumnClearance', (0, 0, -0.015), (0, 0, 0.015), 0.0221, 64), 'DIFFERENCE')
    boolean(collar, tube('WeldedTieRod', (0, -0.025, 0), (0, tail - 0.001, 0), 0.005, 32), 'UNION')
    boolean(collar, block('CaptiveTHead', (0, tail, 0), (0.025, 0.004, 0.09)), 'UNION')
    rods[tail] = finish(collar, 'iron_blackened')
checks = []

def check(label, passed, **detail):
    checks.append(dict(label=label, passed=bool(passed), **detail))
for obj in [plate] + list(hardware.values()) + list(rods.values()):
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    check('wall tie stocks have closed positive walls', all((e.is_manifold for e in bm.edges)) and bm.calc_volume(signed=True) > 0, id=obj.name, nonmanifold=sum((not e.is_manifold for e in bm.edges)), volume_m3=bm.calc_volume(signed=True))
    bm.free()

def tree(obj, xf=Matrix.Identity(4)):
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bm.transform(xf)
    bm.normal_update()
    result = BVHTree.FromBMesh(bm)
    bm.free()
    return result
poses = json.loads((P / 'pitch_kinematics_review.json').read_text())['poses']
mounts = []
for tie in plan['ties']:
    x, y, z = tie['column_local_blender']
    wall = Matrix.Translation((x, tie['bracket_front_y'], z))
    tail = round(tie['tie_tail_y_from_column'], 5)
    rear = round(tie['wall_point_actor_blender'][1] - 0.025 - tie['bracket_front_y'], 5)
    bracket = tree(plate, wall)
    anchors = tree(hardware[rear], wall)
    for row in [r for r in poses if r['sections'] == tie['sections']]:
        for opening in [0, 0.02, 0.04]:
            transform = Matrix.Translation((opening, 0, 0)) @ Matrix(row['body_matrix']) @ Matrix.Translation((x, y, z))
            moving = tree(rods[tail], transform)
            for label, other in [('bracket', bracket), ('anchors', anchors)]:
                hits = moving.overlap(other)
                check('captured tie clears fixed supports through pitch/service', not hits, actor=tie['actor'], side=tie['side'], pitch=row['pitch'], opening_m=opening, other=label, triangle_pairs=len(hits))
    mounts.append(dict(actor=tie['actor'], side=tie['side'], column_local_blender=[x, y, z], bracket_front_y=tie['bracket_front_y'], rod=rods[tail].name, hardware=hardware[rear].name, backing_source=tie['backing_source'], upper_bearing_source=tie['upper_bearing_source'], lower_bearing_source=tie['lower_bearing_source']))
native = P / 'sliding_wall_ties_candidate.blend'
bpy.ops.wm.save_as_mainfile(filepath=str(native))
report = dict(evidence_class='INERT', scope='Uninstalled native anti-tip bracket, anchored stand-offs and captive moving ties. Sampled internal pitch/service clearance; composed room contact, bolt embedment, casting fit, final float buffers, installation and human acceptance still pending.', native_sha256=hashlib.sha256(native.read_bytes()).hexdigest(), plan_sha256=hashlib.sha256((P / 'wall_tie_mount_plan.json').read_bytes()).hexdigest(), mounts=mounts, checks=checks, failures=[c for c in checks if not c['passed']])
(P / 'sliding_wall_ties_review.json').write_text(json.dumps(report, indent=2) + '\n')
print('SLIDING WALL TIES', len(rods), 'rod variants', len(hardware), 'anchor variants', len(checks), 'checks', len(report['failures']), 'failures', flush=True)
if report['failures']:
    raise RuntimeError('Refit anti-tip supports before integration')
