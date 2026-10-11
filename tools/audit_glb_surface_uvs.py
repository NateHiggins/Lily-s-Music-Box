"""Check exported GLB UV triangle area; optionally compare retained geometry.

Read-only. A geometric triangle below float32 precision is counted separately,
never used to manufacture UV acceptance. --base compares node transforms and
triangle positions against a Git revision; no generated glTF is edited.
"""
from pathlib import Path
import argparse, collections, json, struct, subprocess
import numpy as np

DTYPES = {5120:'i1',5121:'u1',5122:'<i2',5123:'<u2',5125:'<u4',5126:'<f4'}
WIDTHS = {'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4,'MAT4':16}

def inspect(raw):
    assert raw[:4] == b'glTF'
    offset=12; document=None; binary=None
    while offset<len(raw):
        size,kind=struct.unpack_from('<II',raw,offset);offset+=8
        block=raw[offset:offset+size];offset+=size
        if kind==0x4e4f534a: document=json.loads(block)
        elif kind==0x004e4942: binary=block
    def accessor(index):
        spec=document['accessors'][index]; view=document['bufferViews'][spec['bufferView']]
        dtype=np.dtype(DTYPES[spec['componentType']]);width=WIDTHS[spec['type']]
        start=view.get('byteOffset',0)+spec.get('byteOffset',0)
        stride=view.get('byteStride',width*dtype.itemsize)
        return np.ndarray((spec['count'],width),dtype=dtype,buffer=binary,offset=start,strides=(stride,dtype.itemsize)).copy()
    rows=[];mesh_geometry=[]
    for mesh in document.get('meshes',[]):
        triangles=[]
        for number,primitive in enumerate(mesh['primitives']):
            if primitive.get('mode',4)!=4: continue
            attributes=primitive['attributes'];vertices=accessor(attributes['POSITION']).astype(float)
            indices=accessor(primitive['indices']).ravel() if 'indices' in primitive else np.arange(len(vertices))
            indices=indices.reshape((-1,3));points=vertices[indices]
            area=np.linalg.norm(np.cross(points[:,1]-points[:,0],points[:,2]-points[:,0]),axis=1)
            real=area>1e-9
            uv=accessor(attributes['TEXCOORD_0']) if 'TEXCOORD_0' in attributes else None
            collapsed=0
            if uv is not None:
                chart=uv[indices].astype(float);a=chart[:,1]-chart[:,0];b=chart[:,2]-chart[:,0]
                collapsed=int(np.sum((np.abs(a[:,0]*b[:,1]-a[:,1]*b[:,0])<=1e-12)&real))
            rows.append({'mesh':mesh.get('name',''),'surface':number,'missing_uv':uv is None,'nonfinite_uv':int(np.sum(~np.isfinite(uv))) if uv is not None else 0,'collapsed_uv_triangles':collapsed,'triangles':int(real.sum()),'degenerate_geometry_triangles':int((~real).sum())})
            for tri in points:
                triangles.append(tuple(sorted(tuple(v) for v in np.round(tri,5))))
        mesh_geometry.append(collections.Counter(triangles))
    # Blender's orphan mesh numbering depends on earlier batch stages.
    # Bind geometry to semantic nodes, not incidental datablock names.
    geometry={str(i)+':'+node.get('name',''):mesh_geometry[node['mesh']]
              for i,node in enumerate(document.get('nodes',[])) if 'mesh' in node}
    nodes=[{k:v for k,v in node.items() if k not in ['mesh','extras']} for node in document.get('nodes',[])]
    return rows,geometry,nodes

def audit(path,base=None):
    rows,geometry,nodes=inspect(path.read_bytes())
    result={'path':path.as_posix(),'surfaces':rows,'failures':sum(r['missing_uv'] or r['nonfinite_uv'] or r['collapsed_uv_triangles']>0 for r in rows)}
    if base:
        old=subprocess.check_output(['git','show',base+':'+path.as_posix()])
        _,old_geometry,old_nodes=inspect(old)
        result['geometry_retained']=geometry==old_geometry
        result['node_transforms_retained']=nodes==old_nodes
    return result

def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('paths',nargs='+');parser.add_argument('--base');parser.add_argument('--out')
    args=parser.parse_args();rows=[audit(Path(p),args.base) for p in args.paths]
    report={'evidence_class':'INERT','assets':rows,'failures':sum(r['failures'] for r in rows)}
    text=json.dumps(report,indent=2)+'\n'
    if args.out:Path(args.out).write_text(text,newline='\n')
    print('GLB UV audit:',len(rows),'assets;',report['failures'],'failing surfaces')
    for r in rows:
        print(r['path'],r['failures'],'UV failures; retained geometry:',r.get('geometry_retained'),'nodes:',r.get('node_transforms_retained'))
    return 1 if report['failures'] or any(r.get('geometry_retained') is False or r.get('node_transforms_retained') is False for r in rows) else 0

if __name__=='__main__':raise SystemExit(main())
