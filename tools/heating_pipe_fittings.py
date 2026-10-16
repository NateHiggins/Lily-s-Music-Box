"""Constant-radius pipe centerlines for Blender, including pitched/non-square bends."""
import math


def fitted_stations(points, radius=.04, minimum_straight=.008, steps=12):
    if radius<=0 or steps<2 or len(points)<2: raise ValueError('Invalid fitting parameters')
    add=lambda a,b:[x+y for x,y in zip(a,b)]
    sub=lambda a,b:[x-y for x,y in zip(a,b)]
    mul=lambda a,s:[x*s for x in a]
    dot=lambda a,b:sum(x*y for x,y in zip(a,b))
    vectors=[sub(b,a) for a,b in zip(points,points[1:])]
    lengths=[math.sqrt(dot(v,v)) for v in vectors]
    if min(lengths)<1e-7: raise ValueError('Zero-length pipe segment')
    directions=[mul(v,1/length) for v,length in zip(vectors,lengths)]
    trims=[0.]*len(points); bends={}
    for i in range(1,len(points)-1):
        u,v=directions[i-1],directions[i]
        cosine=max(-1,min(1,dot(u,v)))
        angle=math.acos(cosine)
        if angle<1e-6: continue
        if math.pi-angle<1e-5: raise ValueError('Pipe reverses into itself')
        trims[i]=radius*math.tan(angle*.5)
        normal=mul(sub(v,mul(u,cosine)),1/math.sin(angle))
        start=sub(points[i],mul(u,trims[i]))
        bends[i]=(angle,u,normal,add(start,mul(normal,radius)))
    for i,length in enumerate(lengths):
        required=trims[i]+trims[i+1]+minimum_straight
        if length<required:
            raise ValueError(f'Segment {i} needs {required:.6f}m for fittings; has {length:.6f}m')
    stations=[(list(points[0]),directions[0])]
    for i in range(1,len(points)-1):
        if i not in bends: continue
        angle,u,n,center=bends[i]
        for step in range(steps+1):
            t=angle*step/steps
            position=add(center,mul(sub(mul(u,math.sin(t)),mul(n,math.cos(t))),radius))
            tangent=add(mul(u,math.cos(t)),mul(n,math.sin(t)))
            stations.append((position,tangent))
    stations.append((list(points[-1]),directions[-1]))
    return stations


def floor_boundary(rectangles, holes):
    """Exact axis-aligned boundary of rectangle union minus opening union."""
    def inside(x, z):
        contains = lambda r: r[0] <= x <= r[2] and r[1] <= z <= r[3]
        return any(map(contains, rectangles)) and not any(map(contains, holes))

    all_rects = rectangles + holes
    xs = sorted({r[i] for r in all_rects for i in (0, 2)})
    zs = sorted({r[i] for r in all_rects for i in (1, 3)})
    cells = {(i, j) for i in range(len(xs)-1) for j in range(len(zs)-1)
             if inside((xs[i]+xs[i+1])/2, (zs[j]+zs[j+1])/2)}
    edges = []
    for i, j in cells:
        x, xx, z, zz = xs[i], xs[i+1], zs[j], zs[j+1]
        for neighbor, edge in [((i-1,j), ((x,z),(x,zz))),
                               ((i+1,j), ((xx,z),(xx,zz))),
                               ((i,j-1), ((x,z),(xx,z))),
                               ((i,j+1), ((x,zz),(xx,zz)))]:
            if neighbor not in cells:
                edges.append(edge)
    # Cell subdivision must not turn one straight wall into hundreds of
    # redundant distance checks. Joining touching collinear edges preserves
    # the exact boundary, including every opening and disconnected island.
    groups = {}
    for a,b in edges:
        axis = 0 if a[1] == b[1] else 1
        fixed = a[1-axis]
        groups.setdefault((axis,fixed),[]).append(sorted((a[axis],b[axis])))
    merged = []
    for (axis,fixed), intervals in groups.items():
        intervals.sort()
        runs = []
        for lo,hi in intervals:
            if runs and lo <= runs[-1][1]:
                runs[-1][1] = max(runs[-1][1],hi)
            else:
                runs.append([lo,hi])
        for lo,hi in runs:
            merged.append(((lo,fixed),(hi,fixed)) if axis==0 else
                          ((fixed,lo),(fixed,hi)))
    return inside, merged

