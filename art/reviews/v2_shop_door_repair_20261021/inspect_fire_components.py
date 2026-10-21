"""Read-only native convex-component discovery. No asset edits or qualification."""
import json,struct
from pathlib import Path
import numpy as np
root=Path(__file__).resolve().parents[3]
data=json.loads((root/'game/data/orison_v2/fire_cabinet_skin.json').read_text())
raw=(root/'game'/data['asset'].removeprefix('res://')).read_bytes();count=struct.unpack_from('<I',raw,12)[0];doc=json.loads(raw[20:20+count]);offset=20+count;size=struct.unpack_from('<I',raw,offset)[0];blob=raw[offset+8:offset+8+size]
def accessor(index):
 a=doc['accessors'][index];v=doc['bufferViews'][a['bufferView']];dtype={5126:'<f4',5123:'<u2',5125:'<u4'}[a['componentType']];width={'VEC3':3,'SCALAR':1}[a['type']];at=v.get('byteOffset',0)+a.get('byteOffset',0);stride=v.get('byteStride',np.dtype(dtype).itemsize*width)
 return np.ndarray((a['count'],width),dtype=dtype,buffer=blob,offset=at,strides=(stride,np.dtype(dtype).itemsize)).copy()
rows=[]
for node in doc['nodes']:
 if node.get('name') not in [r['id'] for r in data['parts'] if r.get('parent')=='door']:continue
 m=doc['meshes'][node['mesh']]['primitives'][0];vertices=accessor(m['attributes']['POSITION']);faces=accessor(m['indices']).ravel().reshape(-1,3)
 unique,remap=np.unique(vertices,axis=0,return_inverse=True);faces=remap[faces]
 parents=list(range(len(faces)));edges={}
 def find(i):
  while parents[i]!=i:parents[i]=parents[parents[i]];i=parents[i]
  return i
 for i,face in enumerate(faces):
  for a,b in zip(face,np.roll(face,-1)):
   key=tuple(sorted((int(a),int(b))));edges.setdefault(key,[]).append(i)
 for neighbors in edges.values():
  for other in neighbors[1:]:parents[find(other)]=find(neighbors[0])
 components={}
 for i in range(len(faces)):components.setdefault(find(i),[]).append(i)
 parts=[]
 for component in components.values():
  selected=faces[component];points=unique[np.unique(selected)].astype(float);tri=unique[selected].astype(float);normals=np.cross(tri[:,1]-tri[:,0],tri[:,2]-tri[:,0]);length=np.linalg.norm(normals,axis=1);valid=length>1e-15
  volume=np.einsum('ij,ij->i',tri[:,0],normals).sum()/6;normals[valid]/=length[valid,None];normals*=1 if volume>0 else -1
  deviation=max(float(np.max((points-tri[i,0])@normals[i])) for i in range(len(tri)) if valid[i])
  closed=all(len(edges[tuple(sorted((int(a),int(b))))])==2 for face in selected for a,b in zip(face,np.roll(face,-1)))
  parts.append({'triangles':len(selected),'unique_vertices':len(points),'closed':closed,'volume':volume,'convex_deviation_m':deviation,'certified_convex':closed and deviation<=1e-7 and abs(volume)>1e-15})
 rows.append({'id':node['name'],'components':parts})
report={'evidence_class':'INERT','scope':'Read-only exported stock topology and exact half-space convexity discovery; runtime imported precision and input remain separate.','rows':rows}
Path(__file__).with_name('fire_components_discovery.json').write_text(json.dumps(report,indent=2,default=lambda value:value.item())+'\n')
for row in rows:print(row['id'],len(row['components']),sum(r['certified_convex'] for r in row['components']),[(r['triangles'],r['certified_convex']) for r in row['components']])
