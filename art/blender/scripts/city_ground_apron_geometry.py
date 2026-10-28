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


def relief_height(x, z, top, relief):
    """Authored metre elevations, not an independent runtime terrain authority."""
    def profile(at, points):
        if at <= points[0][0]: return points[0][1]
        for (a, h), (b, H) in zip(points, points[1:]):
            if at <= b: return h + (H-h)*(at-a)/(b-a)
        return points[-1][1]
    west = profile(x, relief['west_profile']) if x >= relief['west_profile'][0][0] else top
    east = profile(x, relief['east_profile']) if x <= relief['east_profile'][-1][0] else top
    c = relief['canal']
    canal = top
    if x > c['x_start'] and c['south_bank_z'] < z < c['north_bank_z']:
        end = min(1., (x-c['x_start'])/(c['bank_end_x']-c['x_start']))
        cross = min(1., (z-c['south_bank_z'])/(c['south_water_z']-c['south_bank_z']),
                    (c['north_bank_z']-z)/(c['north_bank_z']-c['north_water_z']))
        canal = top + (c['bed_y']-top)*end*cross
    return min(top, west, east, canal)


def relief_stock(bounds, relief):
    """One closed source stock, with shared top vertices and categorical finishes.

    Godot-frame vertices; the builder performs the axis conversion exactly once.
    Grid lines include all breakpoints, the retained seam and every water edge.
    """
    x, _, z, X, top, Z = bounds
    bottom = relief['solid_bottom_scene_y_m']
    assert bottom < min(relief['water_scene_y_m'], -8.) and 0 < relief['grid_pitch_m'] <= 100
    c = relief['canal']
    def lines(a, b, special):
        n = max(1, int(np.ceil((b-a)/relief['grid_pitch_m'])))
        return sorted(set([a, b] + [a+(b-a)*i/n for i in range(1,n)] + [v for v in special if a < v < b]))
    xs = lines(x, X, [p[0] for p in relief['west_profile']+relief['east_profile']] + [c['x_start'], c['bank_end_x']])
    zs = lines(z, Z, [c[k] for k in ['south_bank_z','south_water_z','north_water_z','north_bank_z']])
    v = [(a, relief_height(a,b,top,relief), b) for b in zs for a in xs]
    count = len(v)
    v += [(a,bottom,b) for b in zs for a in xs]
    f = []; keys = []
    def face(indices, key): f.append(tuple(indices)); keys.append(key)
    w = len(xs)
    for j in range(len(zs)-1):
        for i in range(w-1):
            a = j*w+i; b = a+1; d = a+w; e = d+1
            heights = [v[k][1] for k in [a,b,d,e]]
            key = 'asphalt' if min(heights) >= top-1e-7 else 'soil'
            # Concrete-faced rail/canal cuts, earth on the riverward fall.
            if max(heights)-min(heights) > 1 and (xs[i+1] <= -290 or zs[j+1] <= c['north_bank_z']): key = 'concrete'
            face((a,d,e),key); face((a,e,b),key)
            face((a+count,b+count,e+count,d+count),'soil')
    perimeter = list(range(w)) + [j*w+w-1 for j in range(1,len(zs))] + list(range(count-2,count-w-1,-1)) + [j*w for j in range(len(zs)-2,0,-1)]
    for a,b in zip(perimeter,perimeter[1:]+perimeter[:1]): face((a,b,b+count,a+count),'soil')
    return v, f, keys


def water_stock(vertices, faces, height):
    """Clip to the actual terrain triangles; no rectangular water over dry banks."""
    points=[]; triangles=[]; lookup={}
    def index(p):
        q=(round(float(p[0]),9),float(height),round(float(p[2]),9))
        if q not in lookup: lookup[q]=len(points); points.append(q)
        return lookup[q]
    for face in faces:
        if len(face)!=3: continue
        poly=[np.array(vertices[i],dtype=float) for i in face]
        if np.cross(poly[1]-poly[0],poly[2]-poly[0])[1]<=0: continue
        clipped=[]
        for a,b in zip(poly,poly[1:]+poly[:1]):
            inside=a[1]<=height; next_inside=b[1]<=height
            if inside: clipped.append(a)
            if inside!=next_inside: clipped.append(a+(b-a)*((height-a[1])/(b[1]-a[1])))
        ids=list(dict.fromkeys(index(p) for p in clipped))
        for i in range(1,len(ids)-1):
            tri=(ids[0],ids[i],ids[i+1])
            if np.linalg.norm(np.cross(np.subtract(points[tri[1]],points[tri[0]]),np.subtract(points[tri[2]],points[tri[0]])))>1e-8: triangles.append(tri)
    if not triangles: return [],[]
    from collections import Counter
    edges=Counter(tuple(sorted((a,b))) for f in triangles for a,b in zip(f,f[1:]+f[:1]))
    assert max(edges.values())<=2
    count=len(points); points += [(x,y-.05,z) for x,y,z in points[:]]
    result=triangles+[tuple(i+count for i in reversed(f)) for f in triangles]
    for f in triangles:
        for a,b in zip(f,f[1:]+f[:1]):
            if edges[tuple(sorted((a,b)))]==1: result.append((b,a,a+count,b+count))
    return points,result
