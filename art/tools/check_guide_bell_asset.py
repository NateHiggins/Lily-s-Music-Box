"""Check the actual exported GLB, including UVs after anatomical mesh joins."""
import json
import struct
import hashlib
from pathlib import Path
import numpy as np
ROOT=Path(__file__).resolve().parents[2]
path=ROOT/'game/assets/dream/guide_bell/guide_bell.glb'
raw=path.read_bytes()
size=struct.unpack_from('<I',raw,12)[0]
doc=json.loads(raw[20:20+size])
offset=20+size
size=struct.unpack_from('<I',raw,offset)[0]
blob=raw[offset+8:offset+8+size]
def array(index):
    a=doc['accessors'][index]; view=doc['bufferViews'][a['bufferView']]
    width={'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4}[a['type']]
    dtype=np.dtype({5126:'<f4',5125:'<u4',5123:'<u2'}[a['componentType']])
    start=view.get('byteOffset',0)+a.get('byteOffset',0)
    return np.ndarray((a['count'],width),dtype=dtype,buffer=blob,offset=start,
                      strides=(view.get('byteStride',width*dtype.itemsize),dtype.itemsize))
triangles=0; bad=0
for mesh in doc['meshes']:
    for primitive in mesh['primitives']:
        uv=array(primitive['attributes']['TEXCOORD_0'])
        xyz=array(primitive['attributes']['POSITION'])
        indices=array(primitive['indices']).reshape(-1,3)
        a,b,c=[uv[indices[:,i]] for i in range(3)]
        area=np.abs((b[:,0]-a[:,0])*(c[:,1]-a[:,1])-(b[:,1]-a[:,1])*(c[:,0]-a[:,0]))
        geometric=np.linalg.norm(np.cross(xyz[indices[:,1]]-xyz[indices[:,0]],xyz[indices[:,2]]-xyz[indices[:,0]]),axis=1)
        assert np.isfinite(uv).all() and np.isfinite(xyz).all()
        bad+=int(np.count_nonzero((geometric>1e-10)&(area<1e-12)))
        triangles+=len(indices)
result={'meshes':len(doc['meshes']),'triangles':triangles,'degenerate_uv_triangles':bad,
        'source':'art/blender/scripts/build_guide_bell.py','asset_sha256':hashlib.sha256(raw).hexdigest(),
        'status':'PASS' if bad==0 else 'FAIL'}
print(json.dumps(result,indent=2))
destination=ROOT/'tmp/guide_bell/native.json'
destination.parent.mkdir(parents=True,exist_ok=True)
destination.write_text(json.dumps(result,indent=2)+'\n',newline='\n')
assert bad==0,result
