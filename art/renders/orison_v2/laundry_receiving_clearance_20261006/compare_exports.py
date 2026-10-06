from pathlib import Path
import hashlib,json,struct
R=Path('C:/PleaseRemainOnTheLine');T=R/'tmp/v2-finish-review';B=T/'laundry-receiving-before'
def sha(data):return hashlib.sha256(data).hexdigest()
def partitions(path):
    data=path.read_bytes();magic,version,length=struct.unpack_from('<III',data);assert magic==0x46546c67 and version==2 and length==len(data)
    pos=12;chunks={}
    while pos<len(data):
        size,kind=struct.unpack_from('<II',data,pos);pos+=8;chunks[kind]=data[pos:pos+size];pos+=size
    j=json.loads(chunks[0x4e4f534a]);raw=chunks[0x004e4942]
    def accessor(index):
        a=j['accessors'][index];v=j['bufferViews'][a['bufferView']];assert v['buffer']==0 and 'sparse' not in a
        width={5120:1,5121:1,5122:2,5123:2,5125:4,5126:4}[a['componentType']]*{'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4,'MAT4':16}[a['type']]
        start=v.get('byteOffset',0)+a.get('byteOffset',0);stride=v.get('byteStride',width)
        value=b''.join(raw[start+i*stride:start+i*stride+width] for i in range(a['count']))
        assert len(value)==a['count']*width
        return {'type':a['type'],'componentType':a['componentType'],'count':a['count'],'normalized':a.get('normalized',False),'sha256':sha(value)}
    result={}
    for node in j['nodes']:
        if 'mesh' not in node:continue
        name=node['name'];assert '__' in name and name not in result
        payload={'transform':{k:node[k] for k in ['matrix','translation','rotation','scale'] if k in node},'primitives':[]}
        for p in j['meshes'][node['mesh']]['primitives']:
            payload['primitives'].append({'mode':p.get('mode',4),'attributes':{k:accessor(v) for k,v in sorted(p['attributes'].items())},'indices':accessor(p['indices'])})
        result[name]={'sha256':sha(json.dumps(payload,sort_keys=True,separators=(',',':')).encode()),'arrays':payload}
    return result
old_path=B/'game/assets/props/laundry_fittings.glb';new_path=R/'game/assets/props/laundry_fittings.glb'
old=partitions(old_path);new=partitions(new_path);assert old.keys()==new.keys() and len(old)==99
changed=[name for name in old if old[name]!=new[name]]
expected={'storm_shop_model_laundry_iron_table__timber','storm_shop_model_laundry_iron_pad__linen'}
assert set(changed)==expected,changed
report={'evidence_class':'INERT','base_commit':'fd273b5ba36672096ab3fd3f105a1d91d64f400b','before_sha256':sha(old_path.read_bytes()),'after_sha256':sha(new_path.read_bytes()),'partitions':99,'changed':changed,'unchanged':{name:row['sha256'] for name,row in old.items() if name not in expected},'scope':'Actual serialized glTF positions, normals, texture coordinates, tangents, indices and node transforms compare byte-for-byte by accessor values. Exactly two furniture partitions change; all 97 others retain their arrays and transforms. This is inert geometry evidence, not runtime or service authority.'}
(T/'laundry-receiving-export-comparison.json').write_text(json.dumps(report,indent=1)+'\n',encoding='utf-8',newline='\n')
print('Exactly two native ironing partitions changed; all 97 other partition arrays and transforms remain byte-identical.')
