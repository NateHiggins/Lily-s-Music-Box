"""Compare physical triangle/normal multisets independently of revised UV charts."""
import collections, hashlib, json, struct
from pathlib import Path

def physical(path):
    raw=Path(path).read_bytes();length,kind=struct.unpack_from('<II',raw,12)
    assert kind==0x4e4f534a
    data=json.loads(raw[20:20+length]);size,kind=struct.unpack_from('<II',raw,20+length)
    assert kind==0x004e4942
    binary=raw[28+length:28+length+size]
    def accessor(index):
        a=data['accessors'][index];view=data['bufferViews'][a['bufferView']]
        width={'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4}[a['type']]
        fmt='<'+{5121:'B',5123:'H',5125:'I',5126:'f'}[a['componentType']]*width
        start=view.get('byteOffset',0)+a.get('byteOffset',0);stride=view.get('byteStride',struct.calcsize(fmt))
        return [struct.unpack_from(fmt,binary,start+i*stride) for i in range(a['count'])]
    result={}
    for mesh in data['meshes']:
        triangles=[]
        for primitive in mesh['primitives']:
            assert primitive.get('mode',4)==4
            p=accessor(primitive['attributes']['POSITION']);n=accessor(primitive['attributes']['NORMAL'])
            ids=[v[0] for v in accessor(primitive['indices'])] if 'indices' in primitive else list(range(len(p)))
            for i in range(0,len(ids),3):
                triangles.append(b''.join(struct.pack('<6f',*(p[j]+n[j])) for j in ids[i:i+3]))
        result[mesh['name']]=collections.Counter(triangles)
    return result

if __name__=='__main__':
    root=Path(__file__).resolve().parents[3]
    before=physical(Path(__file__).parent/'verified_v2_native/passage_shop_leaves.glb')
    after=physical(root/'game/assets/props/passage_shop_leaves.glb')
    assert before==after,'physical native stock changed'
    print(json.dumps({'evidence_class':'INERT','result':'PASS','scope':'Exact float32 position/normal triangle multisets, ignoring UV phase and vertex enumeration. Not runtime or rendered acceptance.','parts':len(after),'triangles':sum(sum(v.values()) for v in after.values())},indent=2))
