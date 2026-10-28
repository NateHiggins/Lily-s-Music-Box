"""Restore authored city masses around V2 without importing their old ground.

The immutable generated city plan supplies every solid and roof profile.
North neighbors and the northeast row register to V2's wider envelope,
accepted service alley and construction-shed route. Each building/material is a separate export for culling.
"""
from pathlib import Path
import json
import re
import hashlib
import bpy
from collections import Counter
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[3]
layout = json.loads((ROOT/'art/data/building_layout.json').read_text(encoding='utf-8'))
v2 = json.loads((ROOT/'game/data/orison_v2_blockout.json').read_text(encoding='utf-8'))
regions = json.loads((ROOT/'game/data/orison_v2/exterior/regions.json').read_text(encoding='utf-8'))
spaces = {r['id']: r for r in v2['spaces']}
floor = next(f for f in layout['floors'] if f['id']=='F01')
def is_city_shell(identity):
    return (identity.startswith(('site_nbr_', 'site_back_', 'site_far_'))
            or re.match(r'^site_(?:nw|ne|sw|se)\d+_', identity) is not None)

records = [r for r in floor['furniture'] if is_city_shell(r['id']) and 'rect' in r
           and not r['id'].endswith('_beacon')]
import sys
sys.path.insert(0,str(Path(__file__).resolve().parent))
from city_registration import derive_city_offsets
from city_closure_source import shell_projection, v2_layout
source_records = shell_projection(layout)
height_plan_path = ROOT/'art/data/city_elevations/source_plan.json'
layout = v2_layout(layout, json.loads(height_plan_path.read_text()))
floor = next(f for f in layout['floors'] if f['id']=='F01')
records = [r for r in floor['furniture'] if is_city_shell(r['id']) and 'rect' in r and not r['id'].endswith('_beacon')]
projection_records = shell_projection(layout)
assert {r["id"] for r in records} == {r["id"] for r in projection_records}
offsets=derive_city_offsets(layout,v2,regions)
runtime_keys = {'common_brick':'brick', 'brick_patched':'brick', 'face_brick':'brick',
                'limestone':'concrete', 'concrete':'concrete', 'bronze':'bronze',
                'soot':'soot', 'metal':'metal', 'brass_mesh':'brass_mesh', 'lacquer_red':'metal'}
assert all(r['mat'] in runtime_keys for r in records)
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
materials = {}
for key in sorted(set(runtime_keys.values())):
    mat = bpy.data.materials.new(key)
    mat.diffuse_color = (.42,.38,.31,1)
    materials[key] = mat
groups = {}
native_checks = []
for row in records:
    name = row['id']
    group = '_'.join(name.split('_')[:3]) if name.startswith(('site_nbr_', 'site_back_', 'site_far_')) else '_'.join(name.split('_')[:2])
    dx = offsets.get(group,0)
    x0,y0,x1,y1 = row['rect']
    z0 = float(row.get('z0',0))
    h = float(row['h'])
    bpy.ops.mesh.primitive_cube_add(size=1,location=((x0+x1)/2+dx,(y0+y1)/2,z0+h/2))
    obj = bpy.context.object
    obj.name = name
    obj.dimensions = (x1-x0,y1-y0,h)
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    key = runtime_keys[row['mat']]
    obj.data.materials.append(materials[key])
    # Small supported arrises catch light without changing the authored envelope.
    mod = obj.modifiers.new('Construction arris','BEVEL')
    mod.width = min(.008,h/8,(x1-x0)/8,(y1-y0)/8)
    mod.segments = 1
    bpy.ops.object.modifier_apply(modifier=mod.name)
    for layer in list(obj.data.uv_layers): obj.data.uv_layers.remove(layer)
    uv = obj.data.uv_layers.new(name='Metres')
    uv.active_render = True
    for face in obj.data.polygons:
        axis = max(range(3),key=lambda i:abs(face.normal[i]))
        axes = ((1,2),(0,2),(0,1))[axis]
        for loop in face.loop_indices:
            v = obj.matrix_world @ obj.data.vertices[obj.data.loops[loop].vertex_index].co
            uv.data[loop].uv = (v[axes[0]],v[axes[1]])
    # Measure the actual constructed solid before writing provenance. A new
    # registration must never inherit a projection for another native save.
    corners = [obj.matrix_world @ Vector(corner) for corner in obj.bound_box]
    low = [min(v[axis] for v in corners) for axis in range(3)]
    high = [max(v[axis] for v in corners) for axis in range(3)]
    expected_low = [min(x0,x1)+dx,min(y0,y1),z0]
    expected_high = [max(x0,x1)+dx,max(y0,y1),z0+h]
    error = max(abs(a-b) for a,b in zip(low+high,expected_low+expected_high))
    assert error <= .00002, (name,"native envelope changed",error)
    edge_uses = Counter()
    for face in obj.data.polygons:
        indices = list(face.vertices)
        for index in range(len(indices)):
            edge_uses[tuple(sorted((indices[index],indices[(index+1)%len(indices)])))] += 1
    assert edge_uses and all(count == 2 for count in edge_uses.values()), (name,"open native stock")
    obj.data.calc_loop_triangles()
    volume = sum(obj.data.vertices[t.vertices[0]].co.dot(
        obj.data.vertices[t.vertices[1]].co.cross(obj.data.vertices[t.vertices[2]].co))
        for t in obj.data.loop_triangles)/6.0
    assert volume > 0, (name,"nonpositive native stock",volume)
    native_checks.append({"id":name,"bounds_error_m":error,"volume_m3":volume})
    groups.setdefault((group,key),[]).append(obj)
bpy.context.preferences.filepaths.save_version = 0
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'art/blender/city_shells.blend'))
for (group,key),objects in groups.items():
    bpy.ops.object.select_all(action='DESELECT')
    for obj in objects: obj.select_set(True)
    bpy.context.view_layer.objects.active = objects[0]
    bpy.ops.object.join()
    bpy.context.object.name = group+'__'+key
    bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
bpy.ops.object.select_all(action='SELECT')
bpy.ops.export_scene.gltf(filepath=str(ROOT/'game/assets/props/city_shells.glb'),
    export_format='GLB',export_yup=True,export_apply=True,export_tangents=True)
print('CITY SHELLS',len(records),'authored solids;',len(groups),'building/material batches;',offsets)

def source_hash(path):
    raw=path.read_bytes() if path.suffix in ['.blend','.glb'] else path.read_text(encoding='utf-8').replace('\r\n','\n').encode()
    return hashlib.sha256(raw).hexdigest()
report={'evidence_class':'INERT','offsets':offsets,'source_solids':len(records),'runtime_batches':len(groups),
        'source_native_sha256':source_hash(ROOT/'art/blender/city_shells.blend'),
        'bindings':{str(p.relative_to(ROOT)).replace('\\','/'):source_hash(p) for p in [ROOT/'art/data/building_layout.json',ROOT/'game/data/orison_v2_blockout.json',ROOT/'game/data/orison_v2/exterior/regions.json',Path(__file__),Path(__file__).with_name('city_registration.py'),Path(__file__).with_name('city_closure_source.py'),height_plan_path]},
        'note':'Existing authored closed city masses; northwest row shares its near mass registration. No new occupied building or service authority.'}
(ROOT/'art/blender/city_shells_registration.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8',newline='\n')

projection = {
    "evidence_class":"INERT",
    "scope":"Fresh consumed physical fields measured against all335 independently closed native solids by their owning builder; not runtime qualification.",
    "producer":"art/blender/scripts/build_city_shells.py",
    "layout_sha256":report["bindings"]["art/data/building_layout.json"],
    "native_sha256":report["source_native_sha256"],
    "source_records":source_records,
    "records":projection_records,
    "native_checks":native_checks,
}
assert len(native_checks) == len(projection_records) == 335
(ROOT/"art/blender/city_shells_consumed_layout.json").write_text(
    json.dumps(projection,indent=2)+"\n",encoding="utf-8",newline="\n")
print("CITY SHELL PROJECTION",len(native_checks),"closed solids; max bounds error",
      max(row["bounds_error_m"] for row in native_checks))
