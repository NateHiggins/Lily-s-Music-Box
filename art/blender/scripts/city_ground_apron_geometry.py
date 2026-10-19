"""Read actual exported ground bounds and derive a disjoint outer apron."""
import json,struct
import numpy as np


def exported_bounds(raw):
    assert raw[:4]==b'glTF'
    chunks={};offset=12
    while offset<len(raw):
        size,kind=struct.unpack_from('<II',raw,offset)
        chunks[kind]=raw[offset+8:offset+8+size];offset+=8+size
    doc=json.loads(chunks[0x4e4f534a]);binary=chunks[0x004e4942]
    low=np.full(3,np.inf);high=-low;seen=set()
    def visit(index,parent):
        nonlocal low,high
        assert index not in seen,'Repeated/cyclic scene node'
        seen.add(index);node=doc['nodes'][index]
        if 'matrix' in node:
            local=np.array(node['matrix']).reshape((4,4),order='F')
        else:
            x,y,z,w=node.get('rotation',[0,0,0,1])
            local=np.eye(4)
            local[:3,:3]=np.array([[1-2*(y*y+z*z),2*(x*y-z*w),2*(x*z+y*w)],
                [2*(x*y+z*w),1-2*(x*x+z*z),2*(y*z-x*w)],
                [2*(x*z-y*w),2*(y*z+x*w),1-2*(x*x+y*y)]])@np.diag(node.get('scale',[1,1,1]))
            local[:3,3]=node.get('translation',[0,0,0])
        world=parent@local
        if 'mesh' in node:
            for primitive in doc['meshes'][node['mesh']]['primitives']:
                spec=doc['accessors'][primitive['attributes']['POSITION']]
                assert spec['componentType']==5126 and spec['type']=='VEC3' and 'sparse' not in spec
                view=doc['bufferViews'][spec['bufferView']]
                points=np.ndarray((spec['count'],3),dtype='<f4',buffer=binary,
                    offset=view.get('byteOffset',0)+spec.get('byteOffset',0),strides=(view.get('byteStride',12),4)).astype(float)
                points=points@world[:3,:3].T+world[:3,3]
                assert np.isfinite(points).all()
                low=np.minimum(low,points.min(axis=0));high=np.maximum(high,points.max(axis=0))
        for child in node.get('children',[]):visit(child,world)
    for index in doc['scenes'][doc.get('scene',0)]['nodes']:visit(index,np.eye(4))
    assert np.isfinite(low).all() and np.all(high>low)
    return list(low)+list(high)


def apron_boxes(bounds,outer,depth):
    x,y,z,X,Y,Z=map(float,bounds);a,b,c,d=map(float,outer)
    assert a<x<X<c and b<z<Z<d and 0<float(depth)<1
    return [dict(id=identity,bounds=[u,Y-depth,v,U,Y,V]) for identity,(u,v,U,V) in [
        ('west',(a,b,x,d)),('east',(X,b,c,d)),
        ('north',(x,b,X,z)),('south',(x,Z,X,d))]]
