"""Batch the inspected native heating assembly for a Godot import candidate.

No production paths are written. Existing boiler feed remains its own asset.
"""
import bpy
import hashlib
import json
import math
import struct
import argparse
import sys
from pathlib import Path

ROOT=Path(__file__).resolve().parents[3]
parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('--work-dir',type=Path,required=True)
args=parser.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
OUT=args.work_dir.resolve()/'native'
blend=OUT/'heating_distribution_candidate.blend'
inspection=OUT/'mesh_inspection.json'
report=json.loads(inspection.read_text())
if report['failures'] or report['blend_sha256']!=hashlib.sha256(blend.read_bytes()).hexdigest():
    raise RuntimeError('Candidate has no current successful native inspection')
bpy.ops.wm.open_mainfile(filepath=str(blend))
groups={}
for obj in list(bpy.context.scene.objects):
    if obj.type!='MESH' or obj.get('level')=='BOILER':
        bpy.data.objects.remove(obj,do_unlink=True)
        continue
    level=obj.get('level')
    if not level:raise RuntimeError('Missing assembly level: '+obj.name)
    active=obj.data.uv_layers.active
    if active is None:raise RuntimeError('Missing native UV chart: '+obj.name)
    active_name=active.name
    for layer in list(obj.data.uv_layers):
        if layer.name!=active_name:obj.data.uv_layers.remove(layer)
    obj.data.uv_layers.active.name='UVMap'
    groups.setdefault(level,[]).append(obj)
counts={}
for level,parts in sorted(groups.items()):
    bpy.ops.object.select_all(action='DESELECT')
    for part in parts:part.hide_set(False);part.select_set(True)
    bpy.context.view_layer.objects.active=parts[0]
    bpy.ops.object.join()
    obj=bpy.context.object;obj.name='Heating_'+level
    bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
    obj.data.calc_loop_triangles()
    counts[obj.name]={'source_parts':len(parts),'triangles':len(obj.data.loop_triangles)}
    counts[obj.name]['bounds_blender']=[min(v.co[i] for v in obj.data.vertices) for i in range(3)]+[max(v.co[i] for v in obj.data.vertices) for i in range(3)]
path=OUT/'heating_distribution.glb'
bpy.ops.export_scene.gltf(filepath=str(path),export_format='GLB',export_yup=True,
                         export_apply=True,export_materials='NONE',export_texcoords=True)
raw=path.read_bytes()
length,kind=struct.unpack_from('<II',raw,12)
if kind!=0x4e4f534a:raise RuntimeError('Missing GLB JSON chunk')
gltf=json.loads(raw[20:20+length])
if len(gltf['meshes'])!=len(groups):raise RuntimeError('Lost a level batch during export')
for mesh in gltf['meshes']:
    for primitive in mesh['primitives']:
        if not {'POSITION','NORMAL','TEXCOORD_0'}<=primitive['attributes'].keys():
            raise RuntimeError('Export dropped required surface attributes')
if gltf.get('images') or gltf.get('textures'):
    raise RuntimeError('Candidate unexpectedly duplicates catalog textures')
# Validate the actual export, including axis conversion and final UV arrays.
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(path))
roundtrip={}
uv_failures=[]
for obj in bpy.context.scene.objects:
    if obj.type!='MESH':continue
    if obj.name not in counts:raise RuntimeError('Unexpected exported batch: '+obj.name)
    mesh=obj.data;mesh.calc_loop_triangles()
    positions=[obj.matrix_world@v.co for v in mesh.vertices]
    bounds=[min(p[i] for p in positions) for i in range(3)]+[max(p[i] for p in positions) for i in range(3)]
    if any(abs(a-b)>1e-5 for a,b in zip(bounds,counts[obj.name]['bounds_blender'])):
        raise RuntimeError('Export moved batch geometry: '+obj.name)
    if len(mesh.loop_triangles)!=counts[obj.name]['triangles']:
        raise RuntimeError('Export changed triangle count: '+obj.name)
    if not mesh.uv_layers.active:raise RuntimeError('Export dropped UVs: '+obj.name)
    uv=mesh.uv_layers.active.data
    for tri in mesh.loop_triangles:
        a,b,c=[uv[i].uv for i in tri.loops]
        area=abs((b.x-a.x)*(c.y-a.y)-(b.y-a.y)*(c.x-a.x))*.5
        if not math.isfinite(area) or area<1e-12:
            uv_failures.append({'batch':obj.name,'triangle':tri.index,'area_uv':area,'uv':[list(a),list(b),list(c)],'area_geometry':tri.area})
    roundtrip[obj.name]={'triangles':len(mesh.loop_triangles),'bounds_match':True,'collapsed_uv_triangles':sum(r['batch']==obj.name for r in uv_failures)}
if set(roundtrip)!=set(counts):raise RuntimeError('Reimport lost a batch')
result={'evidence_class':'INERT','status':'EXPORT_UV_FAILED' if uv_failures else 'GODOT_IMPORT_CANDIDATE',
        'scope':'Inspected native assembly batched by level. Runtime material binding, imported UV precision, loaded mipmaps, collision and installation remain unverified.',
        'groups':counts,'roundtrip':roundtrip,'uv_failures':uv_failures,'bytes':len(raw),'glb_sha256':hashlib.sha256(raw).hexdigest(),
        'required_godot_import_settings':{'meshes/force_disable_compression':True},
        'blend_sha256':report['blend_sha256'],
        'inspection_sha256':hashlib.sha256(inspection.read_bytes()).hexdigest()}
(OUT/'export_candidate.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps({'groups':len(counts),'uv_failures':len(uv_failures),'examples':uv_failures[:5]}))
if uv_failures:raise RuntimeError('Export UV verification failed')
