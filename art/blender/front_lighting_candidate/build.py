"""Build the entire restored-front candidate natively; no shipping files are edited.

The candidate deliberately remains outside game/ pending composed qualification.
Existing native lamp stock is duplicated; entry drilling is performed in Blender.
"""
from pathlib import Path
import ast
import hashlib
import json
import math
import sys
import numpy as np

import bpy
import bmesh
from mathutils import Vector, Matrix

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / 'art/blender/scripts'))
sys.path.insert(0, str(Path(__file__).parent))
from fabrication_native_batch import material
from fabrication_chart_batch import triangle_charts
from stock import hanger

OUT = ROOT / 'tmp/v2-front-lighting-20261016'
OUT.mkdir(parents=True, exist_ok=True)
plan_path = ROOT / 'art/data/front_lighting_plan.json'
plan = json.loads(plan_path.read_text(encoding='utf-8'))
for path, expected in plan['source_bindings_lf'].items():
    assert hashlib.sha256((ROOT / path).read_bytes().replace(b'\r\n', b'\n')).hexdigest() == expected, path
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.context.preferences.filepaths.save_version = 0
catalog = json.loads((ROOT / 'game/data/runtime_material_sets.json').read_text(encoding='utf-8'))['materials']
materials = {}
for key in ['iron_neutral', 'galvanized_roof', 'brass_dull']:
    materials[key] = material(ROOT, key, dict(catalog_key=key, tint=[.65, .67, .68, 1],
                              pigment=1., normal=.12, roughness=.7), catalog)
# Reuse the proven stock primitives; no module execution or shipping export.
source_path = ROOT / 'art/blender/scripts/build_electrical_service.py'
tree = ast.parse(source_path.read_text(encoding='utf-8'))
exec(compile(ast.Module(body=[n for n in tree.body if isinstance(n, ast.FunctionDef)
    and n.name in {'point', 'cube', 'cylinder', 'cut', 'ring', 'finish', 'screw'}], type_ignores=[]), str(source_path), 'exec'))

native = bpy.data.collections.new('FrontLightingCandidate')
bpy.context.scene.collection.children.link(native)
checks = []


def record(obj, level, role, rechart=True):
    for collection in list(obj.users_collection):
        collection.objects.unlink(obj)
    native.objects.link(obj)
    obj['level'] = level
    obj['role'] = role
    if not rechart:
        return obj
    # Use the established physical-scale precision-safe charts. Dominant-axis
    # charts across smooth curved faces caused incompatible tangent seams.
    uv = obj.data.uv_layers.active
    points=np.asarray([[obj.data.vertices[i].co[:] for i in face.vertices] for face in obj.data.polygons],dtype=np.float64)
    lengths=np.linalg.norm(np.cross(points[:,1]-points[:,0],points[:,2]-points[:,0]),axis=1)
    ids=np.flatnonzero(lengths>1e-20)
    _,_,values,_=triangle_charts(points[ids],np.zeros(3),1.0)
    for i,chart in zip(ids,values):
        for loop,p in zip(obj.data.polygons[int(i)].loop_indices,chart):uv.data[loop].uv=p
    return obj


def oriented_ring(name, center, direction, length, outside=.0125, inside=.0105, level=''):
    obj = ring(outside, inside, length, center)
    d = Vector(point(direction)).normalized()
    obj.rotation_euler = d.to_track_quat('Z', 'Y').to_euler()
    return record(finish(name, [obj], 'galvanized_roof', .00012), level, 'open_conduit')


def gv(p):
    return Vector(p)


def repair_collapsed_charts(obj):
    # Exact Boolean cuts can leave sub-nanometre duplicate edges along the
    # bore. Remove only those edge endpoints, preserving unrelated bearings.
    bm=bmesh.new();bm.from_mesh(obj.data)
    tiny={v for edge in bm.edges if edge.calc_length()<1e-8 for v in edge.verts}
    if tiny:
        bmesh.ops.remove_doubles(bm,verts=list(tiny),dist=1e-8)
        bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
        bm.to_mesh(obj.data)
    bm.free()
    bpy.context.view_layer.objects.active = obj
    mod = obj.modifiers.new('Explicit final triangles', 'TRIANGULATE')
    bpy.ops.object.modifier_apply(modifier=mod.name)
    uv = obj.data.uv_layers.active
    for face in obj.data.polygons:
        values = [Vector(uv.data[i].uv) for i in face.loop_indices]
        if abs((values[1]-values[0]).cross(values[2]-values[0])) > 1e-10:
            continue
        pts = [obj.data.vertices[i].co for i in face.vertices]
        normal = (pts[1]-pts[0]).cross(pts[2]-pts[0])
        axis = max(range(3), key=lambda i: abs(normal[i]))
        a, b = [(1,2),(0,2),(0,1)][axis]
        # A local chart origin preserves float precision on the bore bevels.
        origin = pts[0].copy()
        for loop in face.loop_indices:
            co = obj.data.vertices[obj.data.loops[loop].vertex_index].co - origin
            uv.data[loop].uv = (co[a], co[b])


level_y = {r['id']: r['y'] for r in json.loads((ROOT / 'game/data/orison_v2_blockout.json').read_text())['levels']}
terminals = {tuple(j['position']) for j in plan['junctions'] if j['kind'] == 'terminal'}
junctions = {tuple(j['position']): j for j in plan['junctions']}
fixture_boxes = {(round(f['position'][0],6), round(level_y[f['level']]+2.95,6), round(f['position'][2],6)): f
                 for f in plan['fixtures']}
for i, segment in enumerate(plan['segments']):
    a, b = gv(segment['a']), gv(segment['b'])
    direction = (b-a).normalized()
    # Pipes enter an open box/coupling by 5mm, never stop at its outside face.
    def insertion(p):
        j = junctions[tuple(p)]
        return 0 if j['kind'] == 'terminal' else .010 if j['kind'] == 'coupling' else .025
    start, end = a + direction*insertion(segment['a']), b - direction*insertion(segment['b'])
    assert (end-start).dot(direction) > .001, ('short stock', i)
    oriented_ring('Conduit_%03d' % i, (start+end)/2, direction, (end-start).length, level=segment['level'])

for i, junction in enumerate(plan['junctions']):
    if junction['kind'] == 'terminal':
        continue
    p = gv(junction['position'])
    level = min((l for l in level_y if l.startswith('F')), key=lambda l: abs(level_y[l]+2.9-p.y))
    if junction['kind'] == 'coupling':
        oriented_ring('Coupling_%03d' % i, p, junction['directions'][0], .03, .0165, .0127, level)
        continue
    shell = cube((.07, .06, .07), p)
    # Open lower cover face so the fixed enclosure has a genuine cavity.
    cut(shell, cube((.058, .070, .058), p + Vector((0, -.012, 0))))
    for direction in junction['directions']:
        cutter = cylinder(.0127, .07, p + Vector(direction)*.03)
        cutter.rotation_euler = Vector(point(direction)).to_track_quat('Z', 'Y').to_euler()
        cut(shell, cutter)
    fixture = fixture_boxes.get(tuple(round(v,6) for v in junction['position']))
    if fixture:
        # The round adapter is welded into the open box base. Its underside
        # bears on the complete existing canopy rim; no screw heads intersect
        # the seated native cap and no conduit crosses the glass globe.
        plate=ring(.125 if fixture['kind']=='flush_dome' else .08,.0127,.004,p+Vector((0,-.028,0)))
        bpy.context.view_layer.objects.active=shell
        mod=shell.modifiers.new('Welded canopy adapter','BOOLEAN');mod.operation='UNION';mod.solver='EXACT';mod.object=plate
        bpy.ops.object.modifier_apply(modifier=mod.name);bpy.data.objects.remove(plate,do_unlink=True)
    record(finish('Junction_%03d' % i, [shell], 'iron_neutral', .00025), level, 'bored_junction')
    if fixture:
        width=.09 if fixture['kind']=='flush_dome' else .05
        for k, x in enumerate([-width,width]):
            stem=cylinder(.004,.072,(p.x+x,p.y+.010,p.z))
            washer=ring(.012,.004,.004,(p.x+x,p.y+.048,p.z))
            record(finish('CanopyBearing_%03d_%d'%(i,k),[stem,washer],'iron_neutral',.0001),level,'canopy_ceiling_bearing')
        continue
    cover = cube((.068, .004, .068), p + Vector((0, -.030, 0)))
    # Downward branches have the same open bore through the separate cover.
    if any(d[1] < -.5 for d in junction['directions']):
        cut(cover, cylinder(.0127, .02, p + Vector((0, -.030, 0))))
    record(finish('JunctionCover_%03d' % i, [cover], 'iron_neutral', .0002), level, 'fixed_cover')
    for k, offset in enumerate([(-.023, -.023), (.023, .023)]):
        cap = cylinder(.003, .003, p + Vector((offset[0], -.033, offset[1])))
        # A real slotted screw head, facing the accessible lower cover.
        cut(cap, cube((.0045, .003, .0008), p + Vector((offset[0], -.034, offset[1]))))
        record(finish('JunctionScrew_%03d_%d' % (i, k), [cap], 'brass_dull', .0001), level, 'screw')
    # Ceiling-mounted distribution boxes carry the fixture load through two
    # threaded stays; the conduit is not asked to suspend a heavy opal globe.
    if abs(p.y-(level_y[level]+2.95)) < .00001:
        for k, offset in enumerate([(-.023, .023), (.023, -.023)]):
            rod=cylinder(.003, .02, (p.x+offset[0], p.y+.04, p.z+offset[1]))
            record(finish('BoxBearing_%03d_%d'%(i,k),[rod],'iron_neutral',.0001), level, 'box_ceiling_bearing')

support_stock = {}
for i, support in enumerate(plan['supports']):
    p, seat = gv(support['position']), gv(support['seat'])
    segment = plan['segments'][support['segment']]
    direction = (gv(segment['b']) - gv(segment['a'])).normalized()
    key = (tuple(round(abs(v), 5) for v in direction), round(seat.y-p.y, 5))
    if key in support_stock:
        original, at = support_stock[key]
        obj = original.copy()
        native.objects.link(obj)
        obj.name = 'CeilingStay_%03d' % i
        obj.location = original.location + Vector(point(p-at))
        obj['level'] = segment['level']
        continue
    stock_obj=hanger('CeilingStay_%03d'%i,direction,seat.y-p.y,materials['iron_neutral'])
    stock_obj.location=Vector(point(p))
    record(stock_obj,segment['level'],'ceiling_hanger',False)
    support_stock[key] = (stock_obj, p.copy())

# Recreate the bored replacement covers at their exact original station pose.
for station in plan['source_junctions']:
    p = gv(station['cover_face']) + Vector((.002, 0, 0))
    cover = cube((.004, .236, .156), p)
    cutter = cylinder(.0127, .02, p)
    cutter.rotation_euler.y = math.pi/2
    cut(cover, cutter)
    record(finish(station['id']+'_BoredCover', [cover], 'iron_neutral', .0003), station['level'], 'source_bored_cover')

# Load the existing authored fixtures, preserving their UVs and materials.
names = {part['name'] for row in json.loads((ROOT / 'game/data/orison_v2/fixed_lighting.json').read_text())['assemblies']
         if row['id'] in ('flush_dome', 'cage_bulb_rise300') for part in row['parts']}
with bpy.data.libraries.load(str(ROOT / 'art/blender/fixed_lighting.blend'), link=False) as (available, loaded):
    loaded.objects = [n for n in available.objects if n in names]
stock = {o.name: o for o in loaded.objects}
for fixture in plan['fixtures']:
    anchor = gv(fixture['position']) + Vector((0, level_y[fixture['level']], 0))
    for name, original in stock.items():
        if not name.startswith(fixture['variant']+'__'):
            continue
        obj = original.copy()
        obj.data = original.data.copy()
        obj.name = fixture['id'] + '__' + name.split('__')[1]
        native.objects.link(obj)
        obj.location += Vector(point(anchor))
        obj['level'], obj['role'] = fixture['level'], 'native_fixture'
        # Deliberate native entry bore: never modify exported glTF stock.
        if ('flush_dome__Body' in name) or ('__Mount_' in name):
            p = gv(fixture['canopy_seat']) + Vector((0, -.025, 0))
            before = len(obj.data.polygons)
            if fixture['kind']=='cage_bulb':
                seat=gv(fixture['canopy_seat'])
                # The rigid suspension has a 20mm OD. A full 25mm entry bore
                # would erase it: use the rosette as a stepped reducer instead.
                # Source stock is a joined group of individually closed,
                # intersecting pieces. Drill each solid separately: Boolean
                # difference of that overlapping group can invert the cutter.
                saved_name=obj.name
                bpy.ops.object.select_all(action='DESELECT');obj.select_set(True)
                bpy.context.view_layer.objects.active=obj
                bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT')
                bpy.ops.mesh.separate(type='LOOSE');bpy.ops.object.mode_set(mode='OBJECT')
                stocks=list(bpy.context.selected_objects)
                for stock_obj in stocks:
                    cut(stock_obj,cylinder(.006,.36,seat+Vector((0,-.155,0))))
                    cut(stock_obj,cylinder(.0127,.020,seat+Vector((0,.001,0))))
                bpy.ops.object.select_all(action='DESELECT')
                for stock_obj in stocks:stock_obj.select_set(True)
                bpy.context.view_layer.objects.active=obj;bpy.ops.object.join()
                obj=bpy.context.object;obj.name=saved_name
            else:
                cut(obj, cylinder(.0127, .105, p))
            bpy.context.view_layer.objects.active = obj
            tri = obj.modifiers.new('Chart drilled triangles', 'TRIANGULATE')
            bpy.ops.object.modifier_apply(modifier=tri.name)
            repaired = 0
            uv = obj.data.uv_layers.active
            for face in obj.data.polygons:
                values = [Vector(uv.data[i].uv) for i in face.loop_indices]
                if abs((values[1]-values[0]).cross(values[2]-values[0])) >= 1e-13:
                    continue
                pts = [obj.data.vertices[i].co for i in face.vertices]
                normal = (pts[1]-pts[0]).cross(pts[2]-pts[0])
                axis = max(range(3), key=lambda i: abs(normal[i]))
                a, b = [(1,2), (0,2), (0,1)][axis]
                for loop in face.loop_indices:
                    co = obj.data.vertices[obj.data.loops[loop].vertex_index].co
                    uv.data[loop].uv = (co[a], co[b])
                repaired += 1
            checks.append(dict(check='authored canopy bore', fixture=fixture['id'], before=before,
                               after=len(obj.data.polygons), changed=before != len(obj.data.polygons),
                               repaired_bore_charts=repaired))
            repair_collapsed_charts(obj)

for obj in stock.values():
    bpy.data.objects.remove(obj, do_unlink=True)

# Surface backboxes, real top entries, wall saddles and retained switch stock.
with bpy.data.libraries.load(str(ROOT / 'art/blender/light_switch.blend'), link=False) as (available, loaded):
    loaded.objects = list(available.objects)
switch_stock = [o for o in loaded.objects if o]
temporary = bpy.data.collections.new('TemporarySwitchStock')
bpy.context.scene.collection.children.link(temporary)
for obj in switch_stock:
    temporary.objects.link(obj)
bpy.context.view_layer.update()
switch_materials = {key: material(ROOT, 'FrontSwitch_'+key,
    dict(catalog_key=key, tint=[1,1,1,1], pigment=1., normal=.10, roughness=.8), catalog)
    for key in ['bakelite', 'nickel_plated', 'porcelain', 'rubber_aged']}
for switch in plan['switches']:
    level, yaw = switch['level'], switch['yaw']
    anchor = gv(switch['position']) + Vector((0, level_y[level], 0))
    rotation = Matrix.Rotation(yaw, 4, 'Z')
    pose = Matrix.Translation(Vector(point(anchor))) @ rotation
    inward = Vector((math.sin(yaw), 0, math.cos(yaw)))
    center = anchor + inward*.012
    shell = cube(switch['backbox_size'])
    cavity = cube((.098, .162, .05), (0, 0, -.009))
    cut(shell, cavity)
    cutter = cylinder(.0127, .05, (0, .081, 0))
    cut(shell, cutter)
    shell.matrix_world = Matrix.Translation(Vector(point(center))) @ rotation
    record(finish(switch['id']+'_Backbox', [shell], 'iron_neutral', .00025), level, 'switch_backbox')
    # Vertical stems have actual wall bearings at <=650mm pitch.
    pipe = anchor + inward*.012
    for n, y in enumerate([1.50, 2.10, 2.70]):
        p = Vector((pipe.x, level_y[level]+y, pipe.z))
        band = ring(.0165, .0127, .018, p)
        # Wall face is 20mm behind the conduit centre; a short web joins it.
        seat = cube((.04, .025, .004))
        seat.matrix_world = Matrix.Translation(Vector(point(p+inward*.018))) @ rotation
        web = cube((.012, .015, .008))
        web.matrix_world = Matrix.Translation(Vector(point(p+inward*.012))) @ rotation
        record(finish(switch['id']+'_Saddle_'+str(n), [band, seat, web], 'iron_neutral', .0001), level, 'wall_saddle')
    for original in switch_stock:
        if original.type != 'MESH':
            continue
        obj = original.copy(); obj.data = original.data.copy()
        transform = original.matrix_world.copy()
        obj.parent = None
        obj.matrix_world = pose @ transform
        obj.name = switch['id']+'__'+original.name
        native.objects.link(obj)
        obj['level'], obj['role'] = level, 'native_switch'
        for i, finish_mat in enumerate(obj.data.materials):
            obj.data.materials[i] = switch_materials[finish_mat.name.split('.')[0]]
        repair_collapsed_charts(obj)
for obj in switch_stock:
    bpy.data.objects.remove(obj, do_unlink=True)
bpy.data.collections.remove(temporary)

# Unused spine tips close with real caps; source/canopy/switch tips stay open
# inside their respective fitted enclosure instead of receiving false plugs.
functional_tips = {tuple(r['points'][-1]) for r in plan['routes'] if r['kind'] in ('canopy', 'switch')}
functional_tips |= {tuple(r['points'][0]) for r in plan['routes'] if r['kind'] == 'source'}
for i, junction in enumerate(plan['junctions']):
    p = junction['position']
    if junction['kind'] != 'terminal' or tuple(p) in functional_tips:
        continue
    direction = gv(junction['directions'][0])
    cap = cylinder(.0145, .003, gv(p)-direction*.0015)
    cap.rotation_euler = Vector(point(direction)).to_track_quat('Z', 'Y').to_euler()
    level = min((l for l in level_y if l.startswith('F')), key=lambda l: abs(level_y[l]+2.9-p[1]))
    record(finish('SpineTipCap_%03d' % i, [cap], 'iron_neutral', .0001), level, 'spine_cap')

for obj in native.objects:
    mesh = obj.data
    mesh.calc_loop_triangles()
    bm = bmesh.new(); bm.from_mesh(mesh)
    closed = all(e.is_manifold for e in bm.edges)
    volume = bm.calc_volume(signed=True); bm.free()
    uv = mesh.uv_layers.active
    bad = 0
    for tri in mesh.loop_triangles:
        p = [Vector(uv.data[i].uv) for i in tri.loops]
        if tri.area > 1e-12 and abs((p[1]-p[0]).cross(p[2]-p[0])) < 1e-13:
            bad += 1
    checks.append(dict(check='mesh', name=obj.name, triangles=len(mesh.loop_triangles), closed=closed,
                       volume=volume, collapsed_uv=bad, role=obj['role']))

destination = ROOT / 'art/blender/front_lighting_candidate.blend'
for image in bpy.data.images:
    if image.source == 'FILE':
        image.filepath = bpy.path.relpath(bpy.path.abspath(image.filepath), start=str(destination.parent))
bpy.ops.wm.save_as_mainfile(filepath=str(destination))
failures = [c for c in checks if (c['check'] == 'authored canopy bore' and not c['changed']) or
            (c['check'] == 'mesh' and (not c['closed'] or c['volume'] <= 0 or c['collapsed_uv']))]
report = dict(evidence_class='INERT', status='NATIVE_CANDIDATE_NOT_INSTALLED',
              blend_sha256=hashlib.sha256(destination.read_bytes()).hexdigest(), checks=checks,
              failures=failures, plan_sha256=hashlib.sha256(plan_path.read_bytes()).hexdigest(),
              scope='Native mesh census and entry drilling only; fit, rendered review and runtime acceptance remain required.')
report['source_bindings_lf'] = {str(p.relative_to(ROOT)): hashlib.sha256(p.read_bytes().replace(b'\r\n', b'\n')).hexdigest()
    for p in [Path(__file__), ROOT/'tools/plan_v2_front_lighting.py', source_path,
              ROOT/'game/data/runtime_material_sets.json', ROOT/'game/data/orison_v2/fixed_lighting.json',
              ROOT/'art/blender/scripts/fabrication_native_batch.py',
              Path(__file__).with_name('stock.py'),ROOT/'art/blender/scripts/fabrication_chart_batch.py',
              ROOT/'art/blender/scripts/fabrication_uvs.py']}
report['binary_source_bindings'] = {str(p.relative_to(ROOT)): hashlib.sha256(p.read_bytes()).hexdigest()
    for p in [ROOT/'art/blender/fixed_lighting.blend', ROOT/'art/blender/light_switch.blend']}
(OUT / 'native_inspection.json').write_text(json.dumps(report, indent=2)+'\n', encoding='utf-8', newline='\n')
print('FRONT LIGHTING:', len(native.objects), 'parts;', len(checks), 'checks;', len(failures), 'failures')
if failures:
    print('FIRST FAILURES', failures[:8])
    raise RuntimeError('Candidate needs native repair; no runtime installation performed')
