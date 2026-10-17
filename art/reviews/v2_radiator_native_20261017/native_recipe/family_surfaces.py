"""UNINSTALLED continuous metric charts and catalogue finish preview."""
from recipe_paths import repository_root, output_directory, primitive_source
from pathlib import Path
import bpy, bmesh, json, math, hashlib, sys, struct
from mathutils import Vector
R = repository_root()
P = output_directory()
sys.path.insert(0, str(R / 'art/blender/scripts'))
from fabrication_native_batch import material
from fabrication_normals import stock_corner_normals
source = P / 'union_family_stock_candidate.blend'
bpy.ops.wm.open_mainfile(filepath=str(source))
objects = sorted([o for o in bpy.context.scene.objects if o.type == 'MESH'], key=lambda o: o.name)

def geometry_digest():
    digest = hashlib.sha256()
    for obj in objects:
        digest.update(obj.name.encode() + b'\x00')
        for row in obj.matrix_world:
            for value in row:
                digest.update(struct.pack('<d', value))
        for v in obj.data.vertices:
            for value in v.co:
                digest.update(struct.pack('<d', value))
        for face in obj.data.polygons:
            digest.update(struct.pack('<I', len(face.vertices)))
            for index in face.vertices:
                digest.update(struct.pack('<I', index))
    return digest.hexdigest()
before = geometry_digest()
catalog = json.loads((R / 'game/data/runtime_material_sets.json').read_text())['materials']
finishes = {key: material(R, key, dict(catalog_key=key, normal=0.35, roughness=catalog[key].get('roughness_multiplier', 1), tint=[1, 1, 1], pigment=1), catalog) for key in ['iron_neutral', 'brass_dull', 'iron_blackened']}
checks = []
charts = []

def check(label, passed, **detail):
    checks.append(dict(label=label, passed=bool(passed), **detail))
for obj in objects:
    mesh = obj.data
    bpy.ops.object.select_all(action='DESELECT')
    obj.hide_set(False)
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    for layer in list(mesh.uv_layers):
        mesh.uv_layers.remove(layer)
    mesh.uv_layers.new(name='Metres')
    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.uv.smart_project(angle_limit=math.radians(58), island_margin=0.01, area_weight=0)
    bpy.ops.uv.seams_from_islands(mark_seams=True, mark_sharp=False)
    bpy.ops.uv.unwrap(method='ANGLE_BASED', margin=0.005)
    bpy.ops.uv.average_islands_scale()
    bpy.ops.object.mode_set(mode='OBJECT')
    mesh.calc_loop_triangles()
    uv = mesh.uv_layers.active.data
    area3 = sum((t.area for t in mesh.loop_triangles))
    area2 = 0
    for tri in mesh.loop_triangles:
        a, b, c = [uv[i].uv for i in tri.loops]
        area2 += abs((b - a).cross(c - a)) * 0.5
    assert area2 > 0
    scale = math.sqrt(area3 / area2)
    for loop in uv:
        loop.uv *= scale
    minimum = float('inf')
    total = 0
    for tri in mesh.loop_triangles:
        a, b, c = [uv[i].uv for i in tri.loops]
        area = abs((b - a).cross(c - a)) * 0.5
        minimum = min(minimum, area)
        total += area
    check('every nondegenerate triangle retains finite chart area', minimum > 1e-14 and all((math.isfinite(v) for loop in uv for v in loop.uv)), id=obj.name, minimum_uv_area_m2=minimum)
    check('charts encode metres once rather than predividing material tile', abs(total - area3) < max(1e-10, area3 * 1e-05), id=obj.name, surface_area_m2=area3, chart_area_m2=total)
    mesh.normals_split_custom_set(stock_corner_normals(mesh))
    if obj.name in ['CastSectionThreeColumnCandidate', 'CastShoeFoot']:
        key = 'iron_neutral'
    elif obj.name == 'SixSpokeHandwheel' or 'Packing' in obj.name or 'BlindHeader' in obj.name:
        key = 'iron_blackened'
    elif obj.name in ['ThreadedMovingValveCore', 'BackoffUnionNut', 'VentHeaderReducer']:
        key = 'brass_dull'
    else:
        key = 'iron_neutral'
    mesh.materials.clear()
    mesh.materials.append(finishes[key])
    mesh.materials.append(finishes['brass_dull'])
    for face in mesh.polygons:
        face.use_smooth = True
        face.material_index = 1 if obj.name == 'SocketedThreadedValveHousing' and face.center.z > 0.264 else 0
    obj['proposed_material_key'] = key
    if 'Packing' in obj.name:
        obj['finish_pending'] = 'Graphited fibre packing needs its own registered custom recipe; current dark-metal preview is not acceptable as production packing.'
    charts.append(dict(id=obj.name, vertices=len(mesh.vertices), triangles=len(mesh.loop_triangles), surface_area_m2=area3, chart_area_m2=total, preview_key=key))
after = geometry_digest()
check('UV and finish review preserves exact mechanical geometry', before == after, before=before, after=after)
native = P / 'family_uv_candidate.blend'
bpy.ops.wm.save_as_mainfile(filepath=str(native))
report = dict(evidence_class='INERT', scope='UNINSTALLED continuous metric chart and catalogue preview. Exact mechanical fields unchanged from source candidate; prior geometry diagnostic remains its own original report. No final-buffer tangent, loaded-mipmap, finished packing palette, production runtime or human acceptance.', source_sha256=hashlib.sha256(source.read_bytes()).hexdigest(), native_sha256=hashlib.sha256(native.read_bytes()).hexdigest(), geometry_sha256_before=before, geometry_sha256_after=after, charts=charts, checks=checks, failures=[c for c in checks if not c['passed']])
(P / 'family_uv_review.json').write_text(json.dumps(report, indent=2) + '\n')
print('FAMILY UV', len(checks), 'checks', len(report['failures']), 'failures', flush=True)
if report['failures']:
    raise RuntimeError(report['failures'])
