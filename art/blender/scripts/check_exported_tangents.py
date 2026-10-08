"""Check final GLB tangent derivatives before spending a Godot import/run.

Usage: python art/blender/scripts/check_exported_tangents.py path.glb [...]
Reads exported buffer values, including glTF's flipped UVs; requires NumPy.
"""
from pathlib import Path
import json,struct,sys
import numpy as np

def validate(path):
    raw=Path(path).read_bytes()
    magic,version,size=struct.unpack_from('<III',raw)
    assert (magic,version,size)==(0x46546C67,2,len(raw)),path
    chunks={};offset=12
    while offset<len(raw):
        length,kind=struct.unpack_from('<II',raw,offset)
        chunks[kind]=raw[offset+8:offset+8+length];offset+=8+length
    doc=json.loads(chunks[0x4E4F534A]);binary=chunks[0x004E4942]
    def array(index):
        a=doc['accessors'][index];v=doc['bufferViews'][a['bufferView']]
        dtype=np.dtype({5121:'u1',5123:'<u2',5125:'<u4',5126:'<f4'}[a['componentType']])
        width={'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4}[a['type']]
        start=v.get('byteOffset',0)+a.get('byteOffset',0)
        return np.ndarray((a['count'],width),dtype=dtype,buffer=binary,offset=start,strides=(v.get('byteStride',width*dtype.itemsize),dtype.itemsize)).astype(float)
    triangles=0;worst=1.;parts=0
    for mesh in doc['meshes']:
        for primitive in mesh['primitives']:
            attributes=primitive['attributes']
            p,n,uv,t=[array(attributes[k]) for k in ['POSITION','NORMAL','TEXCOORD_0','TANGENT']]
            indices=array(primitive['indices']).astype(int).reshape((-1,3))
            assert all(np.isfinite(a).all() for a in [p,n,uv,t]),mesh['name']
            assert np.max(abs(np.linalg.norm(n,axis=1)-1))<.001 and np.max(abs(np.linalg.norm(t[:,:3],axis=1)-1))<.001,mesh['name']
            points=p[indices];tex=uv[indices];a=tex[:,1]-tex[:,0];b=tex[:,2]-tex[:,0]
            det=a[:,0]*b[:,1]-a[:,1]*b[:,0]
            assert np.all(abs(det)>1e-12),(mesh['name'],'collapsed UV')
            du=((points[:,1]-points[:,0])*b[:,1,None]-(points[:,2]-points[:,0])*a[:,1,None])/det[:,None]
            dv=((points[:,2]-points[:,0])*a[:,0,None]-(points[:,1]-points[:,0])*b[:,0,None])/det[:,None]
            normals=n[indices];actual=t[indices,:3]
            expected=du[:,None,:]-normals*np.sum(du[:,None,:]*normals,axis=2)[:,:,None]
            expected/=np.linalg.norm(expected,axis=2)[:,:,None]
            agreement=np.sum(expected*actual,axis=2)
            handed=np.sum(np.cross(normals,actual)*dv[:,None,:],axis=2)*t[indices,3]
            assert np.min(agreement)>.999 and np.min(handed)>0,(mesh['name'],float(np.min(agreement)),int(np.sum(handed<=0)))
            triangles+=len(indices);parts+=1;worst=min(worst,float(np.min(agreement)))
    return {'asset':str(path),'primitives':parts,'triangles':triangles,'minimum_tangent_agreement':worst,'status':'PASS'}

if __name__=='__main__':
    for path in sys.argv[1:]:print(json.dumps(validate(path)))
