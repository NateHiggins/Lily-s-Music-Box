from pathlib import Path
import json,struct,hashlib,numpy as np
class Asset:
 def __init__(self,path):
  self.raw=Path(path).read_bytes();n=struct.unpack_from('<I',self.raw,12)[0];self.doc=json.loads(self.raw[20:20+n]);self.binary=self.raw[28+n:]
 def arr(self,i):
  a=self.doc['accessors'][i];v=self.doc['bufferViews'][a['bufferView']];dtype=np.dtype({5121:'u1',5123:'<u2',5125:'<u4',5126:'<f4'}[a['componentType']]);w={'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4}[a['type']];return np.ndarray((a['count'],w),dtype=dtype,buffer=self.binary,offset=v.get('byteOffset',0)+a.get('byteOffset',0),strides=(v.get('byteStride',w*dtype.itemsize),dtype.itemsize))
 def prim(self,p):
  d={'indices':self.arr(p['indices']).copy(),'attributes':{k:self.arr(i).copy() for k,i in p['attributes'].items()},'targets':[{k:self.arr(i).copy() for k,i in x.items()} for x in p.get('targets',[])],'material':self.doc['materials'][p['material']]['name']};return d
old=Asset('tmp/v2-radiator-polish-20261017/cast_surface_prepared/radiator_mechanisms.glb');new=Asset('tmp/v2-radiator-polish-20261017/cast_detail_metric/radiator_mechanisms.glb')
a={x['name']:x for x in old.doc['meshes']};b={x['name']:x for x in new.doc['meshes']};assert a.keys()==b.keys();allowed={'CastSectionThreeColumnCandidate','CastShoeFoot'};retained=[]
for name in a:
 if name in allowed:continue
 left,right=a[name],b[name];assert left.get('extras')==right.get('extras') and len(left['primitives'])==len(right['primitives'])
 for p,q in zip(left['primitives'],right['primitives']):
  p,q=old.prim(p),new.prim(q);assert p['material']==q['material'] and np.array_equal(p['indices'],q['indices']),name
  assert p['attributes'].keys()==q['attributes'].keys()
  for key in p['attributes']:assert np.array_equal(p['attributes'][key],q['attributes'][key]),(name,key)
  assert len(p['targets'])==len(q['targets'])
  for x,y in zip(p['targets'],q['targets']):
   assert x.keys()==y.keys()
   for key in x:assert np.array_equal(x[key],y[key]),(name,'morph',key)
 retained.append(name)
def frames(asset):
 return {x['name']:{k:v for k,v in x.items() if k not in ['mesh','name']} for x in asset.doc['nodes']}
assert frames(old)==frames(new)
result={'evidence_class':'INERT','status':'PASS','scope':'Retained GLB stock buffers, indices, material identities, all morph attributes and node frames; not behavior or runtime proof.','retained_stocks':retained,'allowed_changed_stocks':sorted(allowed),'before_sha256':hashlib.sha256(old.raw).hexdigest(),'after_sha256':hashlib.sha256(new.raw).hexdigest()}
Path('tmp/v2-radiator-polish-20261017/cast_detail_retained_buffers.json').write_text(json.dumps(result,indent=2)+'\n',newline='\n');print('RETAINED STOCK BUFFERS PASS:',len(retained),'stocks incl all packing morph anchors; every node frame unchanged')
