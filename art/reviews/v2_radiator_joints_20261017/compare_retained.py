from pathlib import Path
import json,struct,hashlib
import numpy as np
R=Path('C:/PleaseRemainOnTheLine');T=R/'tmp/v2-control-finish-20261017'
def read(path):
    raw=path.read_bytes();chunks={};offset=12
    while offset<len(raw):
        size,kind=struct.unpack_from('<II',raw,offset);chunks[kind]=raw[offset+8:offset+8+size];offset+=size+8
    doc=json.loads(chunks[0x4e4f534a]);binary=chunks[0x004e4942]
    def values(index):
        a=doc['accessors'][index];v=doc['bufferViews'][a['bufferView']]
        dtype=np.dtype({5121:'u1',5123:'<u2',5125:'<u4',5126:'<f4'}[a['componentType']]);width={'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4}[a['type']]
        return np.ndarray((a['count'],width),dtype=dtype,buffer=binary,offset=v.get('byteOffset',0)+a.get('byteOffset',0),strides=(v.get('byteStride',width*dtype.itemsize),dtype.itemsize)).copy()
    return doc,values

T=R/'tmp/v2-radiator-joints-20261017'
old,oa=read(T/'before/game/assets/props/radiator_mechanisms.glb');new,na=read(T/'prepared_final/radiator_mechanisms.glb')
assert old['nodes']==new['nodes'],'node transforms or identities changed'
assert [m['name'] for m in old['materials']]==[m['name'] for m in new['materials']]
assert [m['name'] for m in old['meshes']]==[m['name'] for m in new['meshes']]
rows=[]
for om,nm in zip(old['meshes'],new['meshes']):
 if om['name']=='CastSectionThreeColumnCandidate':continue
 assert len(om['primitives'])==len(nm['primitives'])
 for op,np_ in zip(om['primitives'],nm['primitives']):
  assert np.array_equal(oa(op['indices']),na(np_['indices'])),(om['name'],'indices')
  assert op['attributes'].keys()==np_['attributes'].keys()
  for key in op['attributes']:assert np.array_equal(oa(op['attributes'][key]),na(np_['attributes'][key])),(om['name'],key)
  assert len(op.get('targets',[]))==len(np_.get('targets',[]))
  for ot,nt in zip(op.get('targets',[]),np_.get('targets',[])):
   for key in ot:assert np.array_equal(oa(ot[key]),na(nt[key])),(om['name'],'morph',key)
  rows.append(dict(stock=om['name'],all_attributes_indices_and_morphs_identical=True))
(T/'retained_stocks.json').write_text(json.dumps(dict(evidence_class='INERT',node_frames_identical=True,material_names_identical=True,retained=rows,scope='Exact exported noncasting buffers; no runtime behavior or appearance acceptance.'),indent=2)+'\n',newline='\n')
print('RETAINED STOCKS',len(rows),'exact; all node frames and material identities unchanged')
