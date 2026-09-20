"""Read raw pilot GLBs independently of Blender export log success."""
import collections
import json
import math
from pathlib import Path
import struct
import sys

# Pinned Blender exporter rounds normals/tangents to four decimal places
# (io_scene_gltf2.io.com.constants.ROUNDING_DIGIT). The squared unit-length
# error bound is sqrt(3)*1e-4 + 3*(5e-5)^2. Zero vectors remain failures.
UNIT_SQUARED_TOLERANCE = .000174


def inspect(path):
    blob=path.read_bytes()
    length,kind=struct.unpack_from('<II',blob,12)
    gltf=json.loads(blob[20:20+length])
    offset=20+length
    length,kind=struct.unpack_from('<II',blob,offset)
    binary=blob[offset+8:offset+8+length]
    def read(index):
        accessor=gltf['accessors'][index]
        view=gltf['bufferViews'][accessor['bufferView']]
        count={'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4,'MAT4':16}[accessor['type']]
        code,size={5121:('B',1),5123:('H',2),5125:('I',4),5126:('f',4)}[accessor['componentType']]
        stride=view.get('byteStride',count*size)
        begin=view.get('byteOffset',0)+accessor.get('byteOffset',0)
        result=[struct.unpack_from('<'+code*count,binary,begin+i*stride) for i in range(accessor['count'])]
        if accessor.get('normalized') and code!='f':
            result=[tuple(x/(2**(size*8)-1) for x in row) for row in result]
        return result
    counts=collections.Counter(); regions=collections.Counter(); legs=collections.Counter(); ends=collections.Counter(); failures=[]
    for mesh in gltf['meshes']:
        for primitive in mesh['primitives']:
            attributes=primitive['attributes']
            counts['triangles']+=len(read(primitive['indices']))//3
            counts['vertices']+=len(read(attributes['POSITION']))
            for required in ['POSITION','NORMAL','TANGENT','TEXCOORD_0','TEXCOORD_1','COLOR_0','JOINTS_0','WEIGHTS_0']:
                if required not in attributes: failures.append([mesh['name'],'missing',required])
            for value in read(attributes['WEIGHTS_0']):
                if abs(sum(value)-1)>1e-5 or min(value)<0: failures.append([mesh['name'],'weights',value])
            for value in read(attributes['TANGENT']):
                if not all(map(math.isfinite,value)) or abs(abs(value[3])-1)>1e-6 or abs(sum(x*x for x in value[:3])-1)>UNIT_SQUARED_TOLERANCE:
                    failures.append([mesh['name'],'tangent',value])
            for value in read(attributes['NORMAL']):
                if not all(map(math.isfinite,value)) or abs(sum(x*x for x in value)-1)>UNIT_SQUARED_TOLERANCE: failures.append([mesh['name'],'normal',value])
            for value in read(attributes['COLOR_0']): regions[round(value[2]*255)]+=1
            allowed={'tardigrade':range(-1,8),'stentor':range(-13,0),'lacrymaria':range(-3,0),'vorticella':range(-13,0),'volvox':range(-13,0),'spirostomum':range(-37,0),'mesodinium':range(-13,0),'bacillaria':range(-1,0),'heliozoan':range(-13,0),'noctiluca':range(-3,0),'salpingoeca':range(-1,0),'euplotes':range(-7,0),'euglena':range(-2,0)}[path.parent.name]
            for leg,weight in read(attributes['TEXCOORD_1']):
                legs[round(leg)]+=1
                if leg!=round(leg) or leg not in allowed or not 0<=weight<=1 or (leg==-1 and weight!=0): failures.append([mesh['name'],'UV1',leg,weight])
                if weight==0: ends['root0']+=1
                if weight==1: ends['tip1']+=1
            if len(primitive.get('targets',[]))!=18 or any('NORMAL' not in t for t in primitive['targets']): failures.append([mesh['name'],'morph'])
    return {'file':str(path),'counts':dict(counts),'regions':dict(regions),'leg_ids':dict(legs),'endpoints':dict(ends),'violations':failures[:20],'violation_count':len(failures)}


if __name__=='__main__':
    root=Path(sys.argv[1]); out=Path(sys.argv[2])
    rows=[inspect(path) for path in sorted(root.glob('*/*.glb'))]
    out.write_text(json.dumps(rows,indent=2)+'\n')
    print(json.dumps([{k:r[k] for k in ('file','counts','violation_count','violations')} for r in rows],indent=2))
    raise SystemExit(any(r['violation_count'] for r in rows))
