"""CPU native derivative repair; never patches generated glTF.
Blender --background --python-exit-code 1 --python export_character_hair.py -- source.blend output_dir hair.glb [--objects CARDS CAP]
Static hair only: two objects/materials, no modifiers/weights/shapes.
Writes a separate repaired native .blend, .glb, native .npz and export .json.
Requires Blender with NumPy and its bundled glTF exporter; no rendering.
Preserves triangle geometry, corner normals, all UVs and material partitions.
Exporter corner guard prevents incompatible tangents being deduplicated.
"""
import bpy,sys,json,hashlib
import numpy as np
from pathlib import Path
import argparse
def prepare_static_hair_mesh(obj):
 """Split static hair corners in memory, preserving native normals and all UVs.

 Requires unweighted mesh with no modifiers/shapes and identity rotation/scale.
 Does not detach parenting, export, save, or rebuild a character skin. The caller
 owns any subsequent Head binding and must verify complete character export.
 """
 if obj.type != 'MESH' or obj.modifiers or obj.vertex_groups or obj.data.shape_keys:
  raise ValueError('Prepare only an unweighted static mesh without modifiers/shapes')
 if not np.allclose(np.array(obj.matrix_world)[:3,:3],np.eye(3),atol=1e-8):raise ValueError('Hair rotation/scale must be applied before preparation')
 native={}
 mesh=obj.data;mesh.calc_loop_triangles();normals=[n.vector.copy()for n in mesh.corner_normals];uvnames=[u.name for u in mesh.uv_layers];rows=[];positions=[];normalrows=[];tex={n:[]for n in uvnames};materials=[]
 assert not mesh.color_attributes,'This scoped adapter refuses to discard colour attributes'
 for tri in mesh.loop_triangles:
  row=[]
  for li in tri.loops:
   row.append(len(positions));positions.append(tuple(mesh.vertices[mesh.loops[li].vertex_index].co));normalrows.append(tuple(normals[li]))
   for u in mesh.uv_layers:tex[u.name].append(tuple(u.data[li].uv))
  rows.append(row);materials.append(tri.material_index)
 coords=np.array(positions,dtype=np.float64)+np.array(obj.matrix_world.translation)
 native['POSITION']=coords[:,[0,2,1]]*np.array([1,1,-1])
 native['NORMAL']=np.array(normalrows)[:,[0,2,1]]*np.array([1,1,-1])
 for ui,name in enumerate(uvnames):native['TEXCOORD_'+str(ui)]=np.array(tex[name])*np.array([1,-1])+np.array([0,1])
 new=bpy.data.meshes.new(mesh.name+'_DerivativeCorners');new.from_pydata(positions,[],rows);new.update()
 for mat in mesh.materials:new.materials.append(mat)
 for name in uvnames:
  uv=new.uv_layers.new(name=name)
  for i,value in enumerate(tex[name]):uv.data[i].uv=value
 new.uv_layers.active_index=0;new.uv_layers[0].active_render=True
 guard=new.attributes.new(name='_corner_guard',type='FLOAT_VECTOR',domain='CORNER')
 normal_guide=new.attributes.new(name='_normal_guide',type='FLOAT_VECTOR',domain='CORNER')
 for i,n in enumerate(normalrows):normal_guide.data[i].vector=(n[0],n[2],-n[1])
 for p,mi in zip(new.polygons,materials):
  p.material_index=mi;p.use_smooth=True
  for li in p.loop_indices:guard.data[li].vector=(float(p.index),0,0)
 new.normals_split_custom_set(normalrows);obj.data=new
 return {'mesh':obj.name,'triangles':len(rows),'uv_layers':uvnames},native

class HairDerivativeExportExtension:
 corrected=0
 def gather_mesh_hook(self,mesh,*unused):
  from io_scene_gltf2.io.exp.binary_data import BinaryData
  from io_scene_gltf2.io.com.constants import BufferViewTarget
  for p in mesh.primitives:
   guides=set(p.attributes).intersection({'_NORMAL_GUIDE','_CORNER_GUARD'})
   if not guides:continue
   if len(guides)!=2:raise ValueError('Hair export requires both normal and corner guides')
   def array(a):
    cols={'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4}[a.type];dtype={5121:'u1',5123:'<u2',5125:'<u4',5126:'<f4'}[a.component_type]
    return np.frombuffer(a.buffer_view.data,dtype=dtype).reshape((-1,cols)).astype(np.float64)
   pos=array(p.attributes['POSITION']);normal=array(p.attributes['_NORMAL_GUIDE']);normal/=np.linalg.norm(normal,axis=1)[:,None];p.attributes['NORMAL'].buffer_view=BinaryData(normal.astype(np.float32).tobytes(),BufferViewTarget.ARRAY_BUFFER);uv=array(p.attributes['TEXCOORD_0']);idx=array(p.indices).astype(int).reshape((-1,3));points=pos[idx];q=uv[idx];a=q[:,1]-q[:,0];b=q[:,2]-q[:,0];det=a[:,0]*b[:,1]-a[:,1]*b[:,0];
   if not np.all(abs(det)>1e-12):raise ValueError('Collapsed primary UV triangle in hair')
   du=((points[:,1]-points[:,0])*b[:,1,None]-(points[:,2]-points[:,0])*a[:,1,None])/det[:,None];dv=((points[:,2]-points[:,0])*a[:,0,None]-(points[:,1]-points[:,0])*b[:,0,None])/det[:,None]
   n=normal[idx];n/=np.linalg.norm(n,axis=2)[:,:,None];t=du[:,None,:]-n*np.sum(du[:,None,:]*n,axis=2)[:,:,None];t/=np.linalg.norm(t,axis=2)[:,:,None];w=np.where(np.sum(np.cross(n,t)*dv[:,None,:],axis=2)<0,-1,1)
   values=np.zeros((len(pos),4),dtype=np.float32);values[idx]=np.concatenate([t,w[:,:,None]],axis=2)
   assert np.isfinite(values).all()
   p.attributes['TANGENT'].buffer_view=BinaryData(values.tobytes(),BufferViewTarget.ARRAY_BUFFER)
   for key in list(p.attributes):
    if key.upper()in('_CORNER_GUARD','_NORMAL_GUIDE'):del p.attributes[key]
   type(self).corrected+=len(idx)

def main():
 parser=argparse.ArgumentParser(description=__doc__)
 parser.add_argument('source', type=Path)
 parser.add_argument('output_directory', type=Path)
 parser.add_argument('output_filename', nargs='?', default='hair.glb')
 parser.add_argument('--objects', nargs=2, metavar=('CARDS', 'CAP'))
 args=parser.parse_args(sys.argv[sys.argv.index('--')+1:])
 source=args.source.resolve();out=args.output_directory.resolve()
 if Path(args.output_filename).name != args.output_filename or not args.output_filename.endswith('.glb'):
  raise ValueError('output_filename must be a plain .glb filename')
 asset=out/args.output_filename
 if not source.is_file() or source.suffix.lower() != '.blend':raise ValueError('source must be an existing .blend')
 if source.parent==out:raise ValueError('Use a separate output directory; the source is immutable')
 if asset.exists():raise FileExistsError('Refusing to overwrite an existing export: '+str(asset))
 out.mkdir(parents=True,exist_ok=True)
 sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest();before=sha(source)
 bpy.ops.wm.open_mainfile(filepath=str(source))
 if args.objects:names=args.objects
 else:
  pairs=[pair for pair in [('HairCards','HairUnderCap'),('Hair','HairCap')] if all(n in bpy.data.objects for n in pair)]
  if len(pairs)!=1:raise ValueError('Select exactly two static hair objects with --objects CARDS CAP')
  names=pairs[0]
 if len(set(names))!=2 or any(n not in bpy.data.objects for n in names):raise ValueError('Two distinct existing hair objects required')
 objects=[bpy.data.objects[n]for n in names];expected=0;inventory=[];native={}
 for obj in objects:
  if obj.type != 'MESH':raise ValueError(obj.name+': selected hair must be a mesh')
  if obj.modifiers or obj.vertex_groups or obj.data.shape_keys:raise ValueError(obj.name+': static hair only; modifiers, skin weights and shape keys are unsupported')
  if len(obj.data.materials)!=1 or obj.data.materials[0] is None:raise ValueError(obj.name+': exactly one assigned material required')
  if len(obj.data.uv_layers)<(2 if obj==objects[0] else 1):raise ValueError(obj.name+': UV0 and UV1 along-strand controls required')
  if not np.allclose(np.array(obj.matrix_world)[:3,:3],np.eye(3),atol=1e-8):raise ValueError(obj.name+': apply rotation/scale in an independently reviewed source first')
 if objects[0].data.materials[0]==objects[1].data.materials[0]:raise ValueError('Cards and cap require distinct materials')
 for slot,obj in enumerate(objects):
  row,fields=prepare_static_hair_mesh(obj)
  inventory.append(row);expected+=row['triangles']
  native.update({str(slot)+'_'+k:v for k,v in fields.items()})
  world=obj.matrix_world.copy();obj.parent=None;obj.matrix_world=world
 for other in list(bpy.data.objects):
  if other not in objects:bpy.data.objects.remove(other,do_unlink=True)
 for o in objects:o.hide_render=False;o.hide_set(False);o.select_set(True)
 import io_scene_gltf2
 io_scene_gltf2.glTF2ExportUserExtension=HairDerivativeExportExtension
 np.savez_compressed(out/(asset.stem+'.native.npz'),**native)
 bpy.ops.wm.save_as_mainfile(filepath=str(out/(asset.stem+'.blend')))
 bpy.ops.export_scene.gltf(filepath=str(asset),export_format='GLB',use_selection=True,export_skins=False,export_animations=False,export_tangents=True,export_attributes=True)
 assert HairDerivativeExportExtension.corrected==expected,(HairDerivativeExportExtension.corrected,expected)
 assert sha(source)==before
 (out/(asset.stem+'.export.json')).write_text(json.dumps({'source_sha256':before,'source_unchanged':True,'export_sha256':sha(asset),'triangles':expected,'inventory':inventory,'source':str(source),'output':str(asset),'native_snapshot':asset.stem+'.native.npz','native_snapshot_sha256':sha(out/(asset.stem+'.native.npz')),'scope':'Native export correction; independent derivative/triangle-equivalence audit required'},indent=2));print('NATIVE_HAIR_DERIVATIVE_EXPORT',expected)

if __name__=='__main__':
 main()
