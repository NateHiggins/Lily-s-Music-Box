"""Authorized pre-serialization admitted corner-tangent source guide. No emitted-file edits."""
import json,numpy as np
from pathlib import Path
from cast_export_derivatives import _read,_remap

def load_guide(path):
 g=json.loads(path.read_text());raw=[(path.parent/x['uri']).read_bytes()for x in g['buffers']]
 def a(i):
  q=g['accessors'][i];v=g['bufferViews'][q['bufferView']];dt=np.dtype({5126:'<f4',5125:'<u4',5123:'<u2',5121:'u1'}[q['componentType']]);w={'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4}[q['type']];return np.ndarray((q['count'],w),dt,raw[v.get('buffer',0)],v.get('byteOffset',0)+q.get('byteOffset',0),strides=(v.get('byteStride',dt.itemsize*w),dt.itemsize)).copy()
 p=g['meshes'][0]['primitives'][0];return {k:a(v)for k,v in p['attributes'].items()},a(p['indices']).reshape(-1,3)

def apply_guide(primitive,source,require_weights=False):
 original,oi=source;aa={k:_read(v)for k,v in primitive.attributes.items()};ii=_read(primitive.indices).reshape(-1,3);assert ii.shape==oi.shape and set(aa)==set(original);assert not primitive.targets
 guard=['POSITION','NORMAL','TEXCOORD_0']+(['JOINTS_0','WEIGHTS_0']if require_weights else[])
 for k in guard:assert np.array_equal(aa[k][ii],original[k][oi]),'GuideCornerCorrespondence:'+k
 # Triangle ordinal and oriented P/N/UV triple are retained EXACTLY; no nearest matching.
 # Require every emitted/source vertex is consumed. Canonical vertex slot mapping may only merge equal native attributes.
 assert np.array_equal(np.unique(ii),np.arange(len(aa['POSITION']))) and np.array_equal(np.unique(oi),np.arange(len(original['POSITION'])))
 flat=oi.ravel();native=ii.ravel();_,first=np.unique(flat,return_index=True);selected=native[first];result={}
 for k in aa:
  if k=='TANGENT':result[k]=original[k].copy();continue
  result[k]=aa[k][selected].copy();assert np.array_equal(result[k][oi],aa[k][ii]),'GuideWouldMergeDifferentNativeData:'+k
 for k,v in result.items():primitive.attributes[k]=_remap(primitive.attributes[k],v)
 primitive.indices=_remap(primitive.indices,oi.astype(_read(primitive.indices).dtype).reshape(-1,1),element=True)
 return dict(triangles=len(ii),source_vertices=len(original['POSITION']),emitted_vertices=len(aa['POSITION']),corner_geometry_and_weights_exact=require_weights,tangent_corner_guide_exact=True,source_and_native_vertex_coverage_complete=True)
