"""Prove the five swept leads use metres in their continuous rest chart.

This authoring witness is INERT. Its position/UV digest lets the import bench
check that the renderer receives the same independently checked coordinates.
"""
from pathlib import Path
import hashlib,json,math,struct
import bpy,numpy as np
from mathutils import Matrix,Vector
R=Path(__file__).resolve().parents[3]
bpy.ops.wm.open_mainfile(filepath=str(R/'art/blender/task_lamp_supply.blend'))
data=json.loads((R/'art/blender/task_lamp_supply_construction.json').read_text(encoding='utf-8'))
C=Matrix(((1,0,0),(0,0,-1),(0,1,0)));records={}
for route in data['routes']:
    name=route['id']+'_ClothFlex';mesh=bpy.data.objects[name].data;n=16;radius=float(route['radius'])
    points=[Vector(p) for p in route['centerline']];lengths=[0.]
    for a,b in zip(points,points[1:]):lengths.append(lengths[-1]+(b-a).length)
    assert len(mesh.vertices)==len(points)*n,name
    radial=max(abs((C.inverted()@v.co-points[i//n]).length-radius) for i,v in enumerate(mesh.vertices))
    assert radial<.000005,(name,'radius mismatch',radial)
    def error_for_radius(r):
        maximum=0.;uv=mesh.uv_layers.active.data
        for face in mesh.polygons:
            js=[i%n for i in face.vertices];cap=len({i//n for i in face.vertices})==1;seam=0 in js and n-1 in js
            for loop in face.loop_indices:
                index=mesh.loops[loop].vertex_index;j=index%n;i=index//n
                if cap:u,v=r*math.cos(j*math.tau/n),r*math.sin(j*math.tau/n)
                else:u,v=(n if seam and j==0 else j)*math.tau*r/n,lengths[i]
                expected=Vector(((u+v)/math.sqrt(2),(v-u)/math.sqrt(2)))
                maximum=max(maximum,(uv[loop].uv-expected).length)
        return maximum
    correct=error_for_radius(radius);wrong=error_for_radius(radius*2)
    assert correct<.000002 and wrong>.001,(name,correct,wrong)
    records[name]={'radius_m':radius,'reference_length_m':lengths[-1],'maximum_radius_error_m':radial,
        'maximum_native_uv_error_m':correct,'double_radius_negative_error_m':wrong}
asset=R/'game/assets/props/task_lamp_supply.glb';raw=asset.read_bytes();chunks={};offset=12
while offset<len(raw):
    size,kind=struct.unpack_from('<II',raw,offset);chunks[kind]=raw[offset+8:offset+8+size];offset+=size+8
doc=json.loads(chunks[0x4e4f534a]);binary=chunks[0x004e4942]
def values(index):
    a=doc['accessors'][index];v=doc['bufferViews'][a['bufferView']];width={'VEC2':2,'VEC3':3}[a['type']]
    assert a['componentType']==5126
    return np.ndarray((a['count'],width),dtype='<f4',buffer=binary,offset=v.get('byteOffset',0)+a.get('byteOffset',0),strides=(v.get('byteStride',width*4),4))
for node in doc['nodes']:
    if node.get('name') not in records or 'mesh' not in node:continue
    unique=set()
    for primitive in doc['meshes'][node['mesh']]['primitives']:
        p=values(primitive['attributes']['POSITION']);uv=values(primitive['attributes']['TEXCOORD_0'])
        for row in np.concatenate((p,uv),axis=1):
            unique.add(struct.pack('<5f',*[0. if x==0 else float(x) for x in row]).hex())
    record=records[node['name']];record['unique_position_uv_pairs']=len(unique)
    record['position_uv_sha256']=hashlib.sha256(''.join(row+'\n' for row in sorted(unique)).encode('ascii')).hexdigest()
assert len(records)==5 and all('position_uv_sha256' in row for row in records.values())
out={'evidence_class':'INERT','asset':'res://assets/props/task_lamp_supply.glb','asset_sha256':hashlib.sha256(raw).hexdigest(),
    'source_sha256':{str(p.relative_to(R)).replace(chr(92),'/'):hashlib.sha256(p.read_bytes()).hexdigest() for p in [Path(__file__).resolve(),R/'art/blender/task_lamp_supply.blend',R/'art/blender/task_lamp_supply_construction.json']},
    'scope':'Native rest-length/radius chart, negative controls and exported position/UV identity; no runtime, routing or appearance acceptance.','meshes':records}
(R/'game/tests/fixtures/task_lamp_flex_uv.json').write_text(json.dumps(out,indent=2)+'\n',encoding='utf-8',newline='\n')
print('FLEX REST UV:',len(records),'physical charts and double-radius negative controls',flush=True)
