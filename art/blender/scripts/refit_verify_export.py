from pathlib import Path
import json,struct,sys,collections,hashlib
import numpy as np
R=Path('C:/PleaseRemainOnTheLine');O=Path(__file__).resolve().parent
sys.path.insert(0,str(R/'art/blender/scripts'))
from check_exported_tangents import validate
def read(path):
 raw=path.read_bytes();at=12;chunks={}
 while at<len(raw):
  size,kind=struct.unpack_from('<II',raw,at);chunks[kind]=raw[at+8:at+8+size];at+=8+size
 d=json.loads(chunks[0x4e4f534a]);binary=chunks[0x004e4942]
 def arr(i):
  a=d['accessors'][i];v=d['bufferViews'][a['bufferView']];w={'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4}[a['type']];dt=np.dtype({5121:'u1',5123:'<u2',5125:'<u4',5126:'<f4'}[a['componentType']]);return np.ndarray((a['count'],w),dtype=dt,buffer=binary,offset=v.get('byteOffset',0)+a.get('byteOffset',0),strides=(v.get('byteStride',w*dt.itemsize),dt.itemsize)).astype(float)
 return d,arr
old,b=read(R/'game/assets/props/bath_lavatory.glb');new,a=read(O/'bath_lavatory_v2.glb')
def inventory(doc,arr):
 meshes={};ratios=[];zero=0;missing=[]
 for node in doc['nodes']:
  if 'mesh' not in node:continue
  rows=[]
  for p in doc['meshes'][node['mesh']]['primitives']:
   at=p['attributes'];pp=arr(at['POSITION']);nn=arr(at['NORMAL']);uv=arr(at['TEXCOORD_0']);ix=arr(p['indices']).astype(int).reshape((-1,3))
   if 'TANGENT' not in at:missing.append(node['name'])
   for tri in ix:
    pts=pp[tri];area=np.linalg.norm(np.cross(pts[1]-pts[0],pts[2]-pts[0]))
    if area<1e-14:zero+=1;continue
    corners=sorted([(tuple(pp[i]),tuple(nn[i])) for i in tri],key=lambda item:tuple(round(v,6) for v in item[0]));rows.append(corners)
   for i,j in [(0,1),(1,2),(2,0)]:
    lp=np.linalg.norm(pp[ix[:,i]]-pp[ix[:,j]],axis=1);lq=np.linalg.norm(uv[ix[:,i]]-uv[ix[:,j]],axis=1);mask=(lp>1e-8)&(lq>1e-8);ratios.extend((lp[mask]/lq[mask]).tolist())
  meshes[node['name']]=rows
 return meshes,ratios,zero,missing
before,rb,zb,mb=inventory(old,b);after,ra,za,ma=inventory(new,a)
assert before.keys()==after.keys(),(before.keys()-after.keys(),after.keys()-before.keys())
normal_error=0;position_error=0;matches=[]
for name in before:
 def key(row):return tuple(tuple(round(v,6) for v in p) for p,n in row)
 lhs=sorted(before[name],key=key);rhs=sorted(after[name],key=key);assert len(lhs)==len(rhs),(name,len(lhs),len(rhs))
 assert [key(r) for r in lhs]==[key(r) for r in rhs],(name,'position triangle identity differs')
 for ll,rr in zip(lhs,rhs):
  pl=np.array([p for p,n in ll]);pr=np.array([p for p,n in rr]);nl=np.array([n for p,n in ll]);nr=np.array([n for p,n in rr]);position_error=max(position_error,float(np.max(abs(pl-pr))));normal_error=max(normal_error,float(np.max(abs(nl-nr))))
 local_error=max(float(np.max(abs(np.array([n for p,n in ll])-np.array([n for p,n in rr])))) for ll,rr in zip(lhs,rhs))
 matches.append({'node':name,'nondegenerate_triangles':len(lhs),'normal_component_error':local_error})
 if local_error>.0001:print('NORMAL_DIAGNOSTIC',name,local_error)
assert position_error<1e-7 and normal_error<.0001,(position_error,normal_error)
assert max(abs(np.array(ra)-1))<.005,(min(ra),max(ra))
assert not ma and za==0
old_nodes={n['name']:n for n in old['nodes']};new_nodes={n['name']:n for n in new['nodes']}
assert old_nodes.keys()==new_nodes.keys()
for name in old_nodes:
 for key in ['translation','rotation','scale','matrix']:
  assert old_nodes[name].get(key)==new_nodes[name].get(key),(name,key)
assert {m['name'] for m in old['materials']}=={m['name'] for m in new['materials']}
assert not new.get('images') and not new.get('animations')
result={'evidence_class':'INERT','baseline_missing_tangent_meshes':mb,'baseline_zero_area_triangles':zb,'baseline_uv_metres_per_unit_range':[min(rb),max(rb)],'new_uv_metres_per_unit_range':[min(ra),max(ra)],'maximum_position_component_error_m':position_error,'maximum_normal_component_error':normal_error,'node_transforms_exact':True,'nondegenerate_triangle_matches':matches,'materials':[m['name'] for m in new['materials']],'tangent_check':validate(O/'bath_lavatory_v2.glb'),'mesh_nodes':len(after),'draw_partitions':sum(len(m['primitives']) for m in new['meshes']),'new_zero_area_triangles':za,'runtime':'NOT_EXECUTED'}
(O/'export_verification.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result,indent=2))
