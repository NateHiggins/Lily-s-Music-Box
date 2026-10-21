"""Read-only exported-source checks; not Godot import or runtime acceptance."""
import hashlib,json,struct
from pathlib import Path
import numpy as np
ROOT=Path(__file__).resolve().parents[3]
path=ROOT/'art/blender/c_stove_stack/c_stove_stack.glb';raw=path.read_bytes();length=struct.unpack_from('<I',raw,12)[0];doc=json.loads(raw[20:20+length]);binary=raw[28+length:]
dtypes={5121:'u1',5123:'<u2',5125:'<u4',5126:'<f4'};widths={'VEC2':2,'VEC3':3,'VEC4':4,'SCALAR':1}
def data(index):
 a=doc['accessors'][index];v=doc['bufferViews'][a['bufferView']];d=np.dtype(dtypes[a['componentType']]);w=widths[a['type']]
 return np.ndarray((a['count'],w),d,buffer=binary,offset=v.get('byteOffset',0)+a.get('byteOffset',0),strides=(v.get('byteStride',w*d.itemsize),d.itemsize)).copy().astype(float)
rows=[];catalog=json.loads((ROOT/'game/data/runtime_material_sets.json').read_bytes())['materials']
for mesh_index,mesh in enumerate(doc['meshes']):
 for p in mesh['primitives']:
  a=p['attributes'];v=data(a['POSITION']);idx=data(p['indices']).astype(int).ravel().reshape(-1,3);points=v[idx];uv=data(a['TEXCOORD_0']);n=data(a['NORMAL']);t=data(a['TANGENT']);key=next(node['name'] for node in doc['nodes'] if node.get('mesh')==mesh_index);tile=catalog[key]['meters_per_tile']
  edges=points[:,[1,2,0]]-points;charts=uv[idx][:,[1,2,0]]-uv[idx];dist=np.linalg.norm(edges,axis=2);tex=np.linalg.norm(charts,axis=2)*tile;ratio=tex[dist>.00005]/dist[dist>.00005]
  zero=int((np.linalg.norm(np.cross(points[:,1]-points[:,0],points[:,2]-points[:,0]),axis=1)==0).sum());excess=float((tex-dist).max());widest=float(ratio.max())
  du=uv[idx[:,1]]-uv[idx[:,0]];dv=uv[idx[:,2]]-uv[idx[:,0]];det=du[:,0]*dv[:,1]-du[:,1]*dv[:,0];noncollapsed=bool((np.abs(det)>1e-12).all())
  expected=((points[:,1]-points[:,0])*dv[:,1,None]-(points[:,2]-points[:,0])*du[:,1,None])/det[:,None];bt=((points[:,2]-points[:,0])*du[:,0,None]-(points[:,1]-points[:,0])*dv[:,0,None])/det[:,None]
  ns=n[idx];ts=t[idx];proj=expected[:,None,:]-ns*(expected[:,None,:]*ns).sum(axis=2)[:,:,None];proj/=np.linalg.norm(proj,axis=2)[:,:,None]
  dot=(proj*ts[:,:,:3]).sum(axis=2);hand=(np.cross(ns,ts[:,:,:3])*bt[:,None,:]).sum(axis=2)*ts[:,:,3]
  row={'material_key':key,'triangles':len(idx),'exact_zero_triangles':zero,'uv_noncollapsed':noncollapsed,'metric_max_excess_m':excess,'metric_widest_ratio':widest,'minimum_tangent_dot':float(dot.min()),'positive_handedness':bool((hand>0).all())}
  row['pass']=zero==0 and noncollapsed and excess<=.00005 and abs(widest-1)<.005 and row['minimum_tangent_dot']>.999 and row['positive_handedness'];rows.append(row)
  if not row['pass']:
   bad=np.argwhere((dot<=.999)|(hand<=0))
   for triangle,corner in bad[:4]:print('SOURCE BASIS DIAGNOSTIC',key,'triangle',triangle,'corner',corner,'position',points[triangle].tolist(),'normal',ns[triangle,corner].tolist(),'tangent',ts[triangle,corner].tolist(),'uv',uv[idx[triangle]].tolist())
result={'evidence_class':'INERT','scope':'Exported source only. Not Godot imported precision, loaded mipmaps, installation or runtime acceptance.','asset_sha256':hashlib.sha256(raw).hexdigest(),'surfaces':rows,'failures':sum(not r['pass'] for r in rows)}
out=ROOT/'art/reviews/v2_c_stove_stack_20261020/source-metric-audit.json';out.write_text(json.dumps(result,indent=2)+'\n',newline='\n');print(json.dumps(result,indent=2));raise SystemExit(1 if result['failures'] else 0)
