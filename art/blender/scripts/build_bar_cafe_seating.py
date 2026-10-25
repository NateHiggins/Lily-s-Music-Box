"""Correct eight tangent-facing chairs through exact source-bound Blender stock."""
from pathlib import Path
import os,sys,json,hashlib,math,numpy as np
import bpy,bmesh
from mathutils import Vector,Matrix
from mathutils.kdtree import KDTree
R=next(p for p in Path(__file__).resolve().parents if (p/'game/project.godot').is_file())
os.environ['ORISON_DEFINITIONS_ONLY']='1';sys.path.insert(0,str(R/'art/blender/scripts'));import build_orison as source
layout=json.loads((R/'game/data/building_layout.json').read_text(encoding='utf8'));f=next(f for f in layout['floors'] if f['id']=='F01')
chairs=[r for r in f['furniture'] if r['id'].startswith('retail_bar_ch') and r.get('asm')=='chair']
gltf=json.loads((R/'game/assets/building/floor_01_cells/shop_bar.gltf').read_text(encoding='utf8'));binary=(R/'game/assets/building/floor_01_cells/shop_bar.bin').read_bytes()
def values(i):
 a=gltf['accessors'][i];v=gltf['bufferViews'][a['bufferView']];dt=np.dtype({5123:'<u2',5125:'<u4',5126:'<f4'}[a['componentType']]);w={'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4}[a['type']]
 return np.ndarray((a['count'],w),dtype=dt,buffer=binary,offset=v.get('byteOffset',0)+a.get('byteOffset',0),strides=(v.get('byteStride',dt.itemsize*w),dt.itemsize)).copy()
retirement=[];members=[];native={};normals_by_key={};origins_by_key={}
for row in chairs:
 buffers={}
 def buf(key):
  if key not in buffers:buffers[key]=source.MeshBuf('Probe_'+key,key if key!='hull' else 'slab')
  return buffers[key]
 frame=source.Frame(buf,lambda:buf('hull'),row['at'][0],row['at'][1],float(f['z'])+row['z0'],row['yaw'],0.)
 source.asm_chair(frame,row)
 counts={}
 for key,buffer in buffers.items():
  kd=KDTree(len(buffer.verts))
  for i,(x,y,z) in enumerate(buffer.verts):kd.insert((x,z,-y),i)
  kd.balance()
  source_name='F01_OWN_SHOP_BAR_furnish_'+('hull-colonly' if key=='hull' else key)
  node=next(n for n in gltf['nodes'] if n.get('name')==source_name);mesh=gltf['meshes'][node['mesh']];assert len(mesh['primitives'])==1
  primitive=mesh['primitives'][0];positions=values(primitive['attributes']['POSITION']);indices=values(primitive['indices']).astype(int).reshape((-1,3))
  selected=np.array([kd.find(v)[2]<.00003 for v in positions]);hit=selected[indices].all(axis=1)
  triangles=positions[indices[hit]];counts[key]=len(triangles)
  assert len(triangles)>0,(row['id'],key)
  if key!='fx_shadow':
   pivot=Vector((row['at'][0],row['at'][1],float(f['z'])+row['z0']));rotation=Matrix.Rotation(-math.pi/2,3,'Z')
   points=[rotation@(Vector((v[0],-v[2],v[1]))-pivot)+pivot for tri in triangles for v in tri]
   native.setdefault(key,[]).extend(points)
   origins_by_key.setdefault(key,[]).extend([tuple(pivot)]*len(points))
   old_normals=values(primitive['attributes']['NORMAL'])[indices[hit]].reshape((-1,3))
   normals_by_key.setdefault(key,[]).extend(rotation@Vector((n[0],-n[2],n[1])) for n in old_normals)
   retirement.append({'resident_furniture':row['id'],'draw':source_name,'source_triangles':len(indices),'material':key,'triangles':triangles.tolist(),'count':int(hit.sum())})
 members.append({'id':row['id'],'source':row,'matches':counts})
assert all(r['matches']['hull']==12 and r['matches']['fx_shadow']==2 for r in members),members

# All selection above is against the untouched shipping source. Rebuild native
# render/collision geometry in Blender; never rewrite generated shipping glTF.
bpy.ops.wm.read_factory_settings(use_empty=True);bpy.context.preferences.filepaths.save_version=0
from fabrication_chart_batch import triangle_charts
from check_exported_tangents import validate as validate_export
catalog=json.loads((R/'game/data/runtime_material_sets.json').read_text(encoding='utf8'))['materials']
parts=[]
for key,points in native.items():
 name='BarCafeHull-colonly' if key=='hull' else 'BarCafeChairs__'+key
 mesh=bpy.data.meshes.new(name);mesh.from_pydata(points,[],[tuple(range(i,i+3)) for i in range(0,len(points),3)]);mesh.update()
 coords=np.array([v.co[:] for v in mesh.vertices]);idx=np.arange(len(points)).reshape((-1,3))
 local_triangles=coords[idx]-np.array(origins_by_key[key])[idx[:,0]][:,None,:]
 ns,us,charts,_=triangle_charts(local_triangles,np.zeros(3),1.,np.repeat(np.eye(3)[None,:,:],len(idx),axis=0),np.zeros(len(idx),dtype=bool))
 uv=mesh.uv_layers.new(name='Metres');uv.data.foreach_set('uv',charts.astype(np.float32).ravel())
 guide=mesh.attributes.new(name='_tangent_guide',type='FLOAT_VECTOR',domain='CORNER');g=np.repeat(us[:,[0,2,1]],3,axis=0);g[:,2]*=-1;guide.data.foreach_set('vector',g.astype(np.float32).ravel())
 mesh.normals_split_custom_set(normals_by_key[key]);obj=bpy.data.objects.new(name,mesh);bpy.context.scene.collection.objects.link(obj)
 material=bpy.data.materials.new('Collision only' if key=='hull' else key);mesh.materials.append(material)
 if key!='hull':parts.append({'name':name,'catalog_key':key,'tile':catalog[key]['meters_per_tile'],'triangles':len(mesh.polygons)})
class ExportUVHandedness:
 def gather_mesh_hook(self,mesh,blender_data,blender_object,vertex_groups,modifiers,materials,export_settings):
  from io_scene_gltf2.io.exp.binary_data import BinaryData
  from io_scene_gltf2.io.com.constants import BufferViewTarget
  for primitive in mesh.primitives:
   def values(key):return np.frombuffer(primitive.attributes[key].buffer_view.data,dtype='<f4').reshape((-1,3)).astype(float)
   n=values('NORMAL');n/=np.linalg.norm(n,axis=1)[:,None];g=values('_TANGENT_GUIDE');t=g-n*np.sum(g*n,axis=1)[:,None];t/=np.linalg.norm(t,axis=1)[:,None]
   primitive.attributes['TANGENT'].buffer_view=BinaryData(np.column_stack((t,-np.ones(len(t)))).astype('<f4').tobytes(),BufferViewTarget.ARRAY_BUFFER);del primitive.attributes['_TANGENT_GUIDE']
import io_scene_gltf2
io_scene_gltf2.glTF2ExportUserExtension=ExportUVHandedness
bpy.ops.wm.save_as_mainfile(filepath=str(R/'art/blender/bar_cafe_seating.blend'))
asset=R/'game/assets/props/bar_cafe_seating.glb'
bpy.ops.export_scene.gltf(filepath=str(asset),export_format='GLB',export_yup=True,export_tangents=True,export_attributes=True,export_materials='PLACEHOLDER')
exported=validate_export(asset)
data={'schema_version':1,'asset':'res://assets/props/bar_cafe_seating.glb','parts':parts,'chairs':members,'retirement':retirement,'correction_degrees':-90.}
(R/'game/data/orison_v2/bar_cafe_seating.json').write_bytes((json.dumps(data,indent=2)+'\n').encode('utf8'))
report={'evidence_class':'INERT','scope':'Source-bound native 90-degree placement repair. Original 16 floor-shadow triangles retained. No source-cell rewrite or runtime acceptance.','chairs':members,'retired_counts':{k:sum(r['count'] for r in retirement if r['material']==k) for k in native},'exported':exported,'asset_sha256':hashlib.sha256(asset.read_bytes()).hexdigest()}
dependencies=[Path(__file__),R/'art/blender/scripts/build_orison.py',R/'art/data/building_layout.json',R/'game/data/building_layout.json',R/'art/data/material_catalog.json',R/'art/textures/catalog_mapping.json',R/'game/assets/building/floor_01_cells/shop_bar.gltf',R/'game/assets/building/floor_01_cells/shop_bar.bin',R/'game/data/runtime_material_sets.json']
dependencies.extend(R/'art/blender/scripts'/name for name in ['fabrication_chart_batch.py','fabrication_uvs.py','check_exported_tangents.py'])
def source_digest(path):
 raw=path.read_bytes()
 return hashlib.sha256(raw.replace(b'\r\n',b'\n') if path.suffix in ['.py','.json','.gltf'] else raw).hexdigest()
report['source_bindings']={path.relative_to(R).as_posix():source_digest(path) for path in dependencies}
(R/'art/blender/bar_cafe_seating_construction.json').write_bytes((json.dumps(report,indent=2)+'\n').encode('utf8'))
print('BAR CAFE SEATING',report)
