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
rows=[]
for family,filename in [('annunciator_dispatch','dispatch_before.glb'),('annunciator_controls','controls_before.glb')]:
    old,oa=read(T/filename);new,na=read(R/'game/assets/props'/(family+'.glb'))
    assert [m['name'] for m in old['meshes']]==[m['name'] for m in new['meshes']]
    for om,nm in zip(old['meshes'],new['meshes']):
        assert len(om['primitives'])==len(nm['primitives'])
        for op,np_ in zip(om['primitives'],nm['primitives']):
            oi=oa(op['indices']).reshape(-1).astype(int);ni=na(np_['indices']).reshape(-1).astype(int)
            expanded_old=oa(op['attributes']['POSITION'])[oi];expanded_new=na(np_['attributes']['POSITION'])[ni]
            assert np.array_equal(expanded_old,expanded_new),(family,om['name'],'physical geometry changed')
            ou=oa(op['attributes']['TEXCOORD_0'])[oi].reshape((-1,3,2));nu=na(np_['attributes']['TEXCOORD_0'])[ni].reshape((-1,3,2))
            uv_delta=float(np.max(np.abs((ou[:,1:]-ou[:,:1])-(nu[:,1:]-nu[:,:1]))))
            assert uv_delta<1e-7,(family,om['name'],'UV scale changed')
            assert len(op.get('targets',[]))==len(np_.get('targets',[]))
            for ot,nt in zip(op.get('targets',[]),np_.get('targets',[])):
                assert np.array_equal(oa(ot['POSITION'])[oi],na(nt['POSITION'])[ni]),'spring movement changed'
            changed=not np.array_equal(oa(op['attributes']['NORMAL'])[oi],na(np_['attributes']['NORMAL'])[ni])
            rows.append({'family':family,'part':om['name'],'triangles':len(oi)//3,'expanded_position_sha256':hashlib.sha256(expanded_new.tobytes()).hexdigest(),'geometry_unchanged':True,'morph_positions_unchanged':True,'uv_edge_maximum_delta_m':uv_delta,'normals_changed':changed})
(T/'geometry_comparison.json').write_text(json.dumps({'evidence_class':'INERT','scope':'Expanded exported triangles, UV derivatives and spring morph positions; not production physics or gameplay.','parts':rows},indent=2)+'\n',newline='\n')
print({'parts':len(rows),'normal_changes':sum(r['normals_changed'] for r in rows),'physical_geometry_changes':0,'maximum_uv_edge_delta_m':max(r['uv_edge_maximum_delta_m'] for r in rows)})
