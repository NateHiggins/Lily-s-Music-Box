"""Read-only native GLB check: each seating morph moves only its own bank.

This is a source diagnostic, not imported/runtime qualification.
"""
from pathlib import Path
import json,struct
import numpy as np

def audit(path):
    raw=Path(path).read_bytes();offset=12;chunks={}
    while offset<len(raw):
        size,kind=struct.unpack_from('<II',raw,offset);offset+=8
        chunks[kind]=raw[offset:offset+size];offset+=size
    doc=json.loads(chunks[0x4e4f534a]);binary=chunks[0x004e4942]
    def array(i):
        a=doc['accessors'][i]
        assert a['componentType']==5126 and a['type']=='VEC3'
        values=np.zeros((a['count'],3))
        if 'bufferView' in a:
            view=doc['bufferViews'][a['bufferView']]
            values[:]=np.ndarray((a['count'],3),dtype='<f4',buffer=binary,
                offset=view.get('byteOffset',0)+a.get('byteOffset',0),strides=(view.get('byteStride',12),4))
        if 'sparse' in a:
            sparse=a['sparse'];indices=sparse['indices'];v=doc['bufferViews'][indices['bufferView']]
            ids=np.frombuffer(binary,dtype={5121:'u1',5123:'<u2',5125:'<u4'}[indices['componentType']],
                count=sparse['count'],offset=v.get('byteOffset',0)+indices.get('byteOffset',0))
            data=sparse['values'];v=doc['bufferViews'][data['bufferView']]
            values[ids]=np.frombuffer(binary,dtype='<f4',count=sparse['count']*3,
                offset=v.get('byteOffset',0)+data.get('byteOffset',0)).reshape((-1,3))
        return values
    rows=[]
    for mesh in doc['meshes']:
        names=mesh.get('extras',{}).get('targetNames',[])
        if 'LowerSeat' not in names:continue
        for part in mesh['primitives']:
            points=array(part['attributes']['POSITION'])
            for bank,name in [(-1,'LowerSeat'),(1,'UpperSeat')]:
                delta=array(part['targets'][names.index(name)]['POSITION'])
                changed=np.linalg.norm(delta,axis=1)>1e-7
                assert changed.any(),(mesh['name'],name,'no movement')
                assert np.all(points[changed,1]*bank>.002),(mesh['name'],name,'cross-bank movement',
                    sorted(set(np.round(points[changed,1],6))))
                maximum=float(np.linalg.norm(delta,axis=1).max())
                assert maximum<.0004,(mesh['name'],name,'unexpected travel')
                rows.append(dict(mesh=mesh['name'],morph=name,vertices=int(changed.sum()),maximum_delta_m=maximum))
    assert len(rows)==4,rows
    return dict(evidence_class='INERT',status='PASS',checks=rows)

if __name__=='__main__':
    import argparse
    p=argparse.ArgumentParser();p.add_argument('asset');p.add_argument('--out');args=p.parse_args()
    report=audit(args.asset);data=json.dumps(report,indent=2)+'\n'
    if args.out:Path(args.out).write_text(data,newline='\n')
    print(data)
