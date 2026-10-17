"""Continuous metre charts and catalogue brass for the two native prototypes.

Writes separate candidates; keeps original mechanical checks and inputs intact.
"""
from recipe_paths import repository_root, output_directory, primitive_source
from pathlib import Path
import hashlib, json, math, struct, sys
import bpy
ROOT = repository_root()
P = output_directory()
sys.path.insert(0, str(ROOT / 'art/blender/scripts'))
from fabrication_native_batch import material
from fabrication_normals import stock_corner_normals

def geometry_digest(objects):
    h = hashlib.sha256()
    for obj in sorted(objects, key=lambda o: o.name):
        h.update(obj.name.encode() + b'\x00')
        for row in obj.matrix_world:
            for x in row:
                h.update(struct.pack('<d', x))
        for vertex in obj.data.vertices:
            for x in vertex.co:
                h.update(struct.pack('<d', x))
        for face in obj.data.polygons:
            h.update(struct.pack('<I', len(face.vertices)))
            for index in face.vertices:
                h.update(struct.pack('<I', index))
    return h.hexdigest()
catalog = json.loads((ROOT / 'game/data/runtime_material_sets.json').read_text())['materials']
for family in ['automatic_vent', 'articulated_union']:
    source = P / (family + '_candidate.blend')
    bpy.ops.wm.open_mainfile(filepath=str(source))
    objects = sorted([o for o in bpy.context.scene.objects if o.type == 'MESH'], key=lambda o: o.name)
    before = geometry_digest(objects)
    finishes = {key: material(ROOT, key, dict(catalog_key=key, normal=0.35, roughness=catalog[key]['roughness_multiplier'], tint=[1, 1, 1], pigment=1), catalog) for key in ['door_brass', 'iron_neutral', 'iron_blackened']}
    checks = []

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

        def chart_area(tri):
            a, b, c = [uv[i].uv for i in tri.loops]
            return abs((b - a).cross(c - a)) * 0.5
        area2 = sum((chart_area(t) for t in mesh.loop_triangles))
        assert area2 > 0, obj.name
        scale = math.sqrt(area3 / area2)
        for loop in uv:
            loop.uv *= scale
        areas = [chart_area(t) for t in mesh.loop_triangles]
        check('all native triangles have finite noncollapsed charts', all((a > 1e-18 for a in areas)) and all((math.isfinite(x) for loop in uv for x in loop.uv)), id=obj.name, minimum_uv_area=min(areas))
        check('UVs encode metres without a second material tile scale', abs(sum(areas) - area3) < max(1e-10, area3 * 1e-05), id=obj.name, chart_m2=sum(areas), surface_m2=area3)
        edge_faces = {}
        for face in mesh.polygons:
            loops = list(face.loop_indices)
            for a, b in zip(loops, loops[1:] + loops[:1]):
                edge = mesh.loops[a].edge_index
                edge_faces.setdefault(edge, []).append({mesh.loops[a].vertex_index: uv[a].uv.copy(), mesh.loops[b].vertex_index: uv[b].uv.copy()})
        tears = []
        continuous = 0
        for edge in mesh.edges:
            sides = edge_faces.get(edge.index, [])
            if edge.use_seam or len(sides) != 2:
                continue
            error = max(((sides[0][v] - sides[1][v]).length for v in edge.vertices))
            if error > 1e-07:
                tears.append(dict(edge=edge.index, error_m=error))
            continuous += 1
        check('unseamed shared edges have continuous UV coordinates', not tears, id=obj.name, checked_edges=continuous, tears=tears[:10])
        mesh.normals_split_custom_set(stock_corner_normals(mesh))
        if family == 'automatic_vent' or obj.name in ['ThreadedMovingValveCore', 'VentHeaderReducer', 'ValveSphericalRetainer', 'HeaderSphericalRetainer', 'FloatingMetalBearingRing', 'BackoffUnionNut']:
            key = 'door_brass'
        elif obj.name == 'SixSpokeHandwheel' or 'Packing' in obj.name or 'BlindHeader' in obj.name:
            key = 'iron_blackened'
        else:
            key = 'iron_neutral'
        mesh.materials.clear()
        mesh.materials.append(finishes[key])
        mesh.materials.append(finishes['door_brass'])
        for face in mesh.polygons:
            face.use_smooth = True
            face.material_index = int(obj.name == 'ArticulatedValveHousing' and face.center.z > 0.264)
        obj['proposed_material_key'] = key
    after = geometry_digest(objects)
    check('finish pass preserves exact mechanical geometry', before == after, before=before, after=after)
    output = P / (family + '_finished_candidate.blend')
    bpy.ops.wm.save_as_mainfile(filepath=str(output))
    report = dict(evidence_class='INERT', scope='Uninstalled continuous metre UV and catalogue finish. Original mechanics preserved exactly; no export, loaded mipmaps, production runtime or human acceptance.', source_sha256=hashlib.sha256(source.read_bytes()).hexdigest(), native_sha256=hashlib.sha256(output.read_bytes()).hexdigest(), checks=checks, failures=[c for c in checks if not c['passed']])
    (P / (family + '_surface_review.json')).write_text(json.dumps(report, indent=2) + '\n')
    print('MECHANISM SURFACE', family, len(checks), 'checks', len(report['failures']), 'failures', flush=True)
    if report['failures']:
        raise RuntimeError(report['failures'])
