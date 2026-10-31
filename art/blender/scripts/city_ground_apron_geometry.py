"""Read actual exported ground bounds and derive a disjoint outer apron."""
import json,struct,math
from functools import lru_cache
import numpy as np


def rounded_convex_offset(polygon, radius, segments=64):
    """Bounded Euclidean clearance, not an acute-corner mitre extension.

    The circumscribed regular disk contains the requested clearance circle;
    its maximum excess is radius*(sec(pi/segments)-1). A convex hull computes
    the Minkowski sum. Union distributes over this operation, so callers may
    offset the actual convex near/lower stocks without offsetting their tiny
    triangulation ears by unbounded mitres.
    """
    assert radius > 0 and segments >= 16 and segments % 4 == 0
    assert len(polygon) >= 3
    cross = lambda a,b,c: (b[0]-a[0])*(c[1]-a[1])-(b[1]-a[1])*(c[0]-a[0])
    signed = sum(a[0]*b[1]-a[1]*b[0] for a,b in zip(polygon,polygon[1:]+polygon[:1]))
    assert signed > 0 and all(cross(polygon[i-1],polygon[i],polygon[(i+1)%len(polygon)]) >= -1e-9 for i in range(len(polygon))), 'Expected a counterclockwise convex stock'
    circumradius = radius/math.cos(math.pi/segments)
    disk = [(circumradius*math.cos(2*math.pi*i/segments),circumradius*math.sin(2*math.pi*i/segments)) for i in range(segments)]
    points = sorted(set((float(x+dx),float(y+dy)) for x,y in polygon for dx,dy in disk))
    def half(points):
        result=[]
        for p in points:
            while len(result)>=2 and cross(result[-2],result[-1],p)<=1e-12:result.pop()
            result.append(p)
        return result
    return half(points)[:-1]+half(list(reversed(points)))[:-1]


def street_cut_footprints(plan, frame, layout):
    """Derive both native LODs' padded cuts in the existing building frame.

    This is an authoring projection of the street owner, never a second grade
    or collision authority. Actual soil subtraction and support are separate.
    Open edges must be outer bounds: an internal clipping plane could cut off
    another arm of a concave district and is refused rather than guessed.
    """
    from city_street_geometry import district_topology, split, clean
    door=next(row for row in layout['doors'] if row['id']=='F01_DOOR_06')
    offset=float(door['center'][1])+float(frame['source_threshold_z'])
    padding=float(plan['lod_error_m'])+float(plan['joint_m'])
    assert padding>0
    result=[]
    for district in plan.get('districts',[]):
        outline=district['road_outline_m']
        topologies=[district_topology(district,n,plan['curb_width_m'],plan['curb_cap_overhang_m']) for n in (12,8)]
        source_stocks=[t['road']+t['curb_caps'] for t in topologies]
        edges=[]
        for edge in district['open_edges']:
            axis=int(edge['axis']);value=float(edge['value_m'])
            assert axis in (0,1)
            lo=min(p[axis] for p in outline);hi=max(p[axis] for p in outline)
            assert abs(value-lo)<1e-8 or abs(value-hi)<1e-8,'Open continuation must be an outer plane'
            keep_high=abs(value-lo)<1e-8
            # The real cap returns project beyond the nominal road end by
            # their stock width/overhang. Preserve that actual terminal plane,
            # rather than discarding authored cap vertices at the road datum.
            coordinates=[p[axis] for stocks in source_stocks for stock in stocks for p in stock]
            stock_end=min(coordinates) if keep_high else max(coordinates)
            edges.append((axis,stock_end,keep_high))
        polygons=[];seen=set();counts=[]
        for stocks in source_stocks:
            counts.append(len(stocks))
            for stock in stocks:
                p=rounded_convex_offset(stock,padding)
                for axis,value,keep_high in edges:
                    # split retains the left side of its directed line.
                    a,b=([(value,1.),(value,0.)] if keep_high else [(value,0.),(value,1.)]) if axis==0 else ([(0.,value),(1.,value)] if keep_high else [(1.,value),(0.,value)])
                    p,_=split(p,a,b)
                    if not p:break
                if not p:continue
                p=clean([(-x,y+offset) for x,y in p])
                first=min(range(len(p)),key=lambda i:p[i]);p=p[first:]+p[:first]
                key=tuple(p)
                if key in seen:continue
                seen.add(key);polygons.append(p)
        result.append({'id':district['id'],'polygons':polygons,'subgrade_profile_m':sorted([[-float(x),float(h)] for x,h in district['ground_cut_profile_m']]),
                       'padding_m':padding,'padding_max_excess_m':padding*(1/math.cos(math.pi/64)-1),
                       'source_lod_stock_counts':counts,'offset_z_m':offset,'open_edges':district['open_edges'],
                       'open_stock_planes':edges})
    return result


def disjoint_cut_regions(polygons):
    """Keep a union once for independent volume integration and cap creation."""
    return _disjoint_cut_regions(tuple(tuple(tuple(v) for v in p) for p in polygons))


@lru_cache(maxsize=4)
def _disjoint_cut_regions(polygons):
    from city_street_geometry import bounds, overlap, area, cut
    result=[];originals=[];boxes=[]
    for p in sorted(polygons,key=lambda p:-area(p)):
        box=bounds(p)
        # Subtract the original convex stocks, whose union is identical to
        # the accepted fragments. Reusing fragments as masks needlessly
        # multiplies clipping work and slivers along prior partition lines.
        masks=[q for b,q in zip(boxes,originals) if overlap(box,b)]
        pieces=cut(p,masks)
        result.extend(pieces);originals.append(p);boxes.append(box)
    return tuple(tuple(p) for p in result)


def convex_union_boundaries(polygons):
    """Visible directed edges of convex stocks; no interior arrangement mesh."""
    from city_street_geometry import bounds,area
    assert all(len(p)>=3 and area(p)>0 for p in polygons),'Expected counterclockwise stocks'
    boxes=[bounds(p) for p in polygons];segments=[]
    for i,p in enumerate(polygons):
        for a,b in zip(p,p[1:]+p[:1]):
            vx,vy=b[0]-a[0],b[1]-a[1]
            if math.hypot(vx,vy)<1e-9:continue
            box=[min(a[0],b[0]),min(a[1],b[1]),max(a[0],b[0]),max(a[1],b[1])]
            hidden=[]
            for j,q in enumerate(polygons):
                if i==j:continue
                B=boxes[j]
                if box[0]>B[2]+1e-8 or box[2]<B[0]-1e-8 or box[1]>B[3]+1e-8 or box[3]<B[1]-1e-8:continue
                lo,hi=0.,1.;same=False
                for u,v in zip(q,q[1:]+q[:1]):
                    dx,dy=v[0]-u[0],v[1]-u[1];length=math.hypot(dx,dy)
                    c=(dx*(a[1]-u[1])-dy*(a[0]-u[0]))/length
                    d=(dx*vy-dy*vx)/length
                    if abs(d)<1e-10:
                        if c < -1e-8:hi=-1.;break
                        if abs(c)<1e-8 and dx*vx+dy*vy>0:same=True
                    elif d>0:lo=max(lo,-c/d)
                    else:hi=min(hi,-c/d)
                    if hi<=lo:break
                if hi>lo+1e-12 and not (same and i<j):hidden.append((max(0.,lo),min(1.,hi)))
            start=0.
            for lo,hi in sorted(hidden):
                if hi<=start:continue
                if lo>start+1e-11:segments.append(((a[0]+start*vx,a[1]+start*vy),(a[0]+lo*vx,a[1]+lo*vy)))
                start=max(start,hi)
            if start<1.-1e-11:segments.append(((a[0]+start*vx,a[1]+start*vy),b))
    # Stitch independently evaluated edge intersections at 0.1 micrometre.
    # Actual closed-stock volume is still checked at the original 0.001 m3.
    def key(p):return tuple(round(v,7) for v in p)
    edges={};incoming={}
    for a,b in segments:
        a,b=key(a),key(b)
        if a==b:continue
        assert a not in edges,('branch',a,edges.get(a),b)
        edges[a]=b;incoming[b]=incoming.get(b,0)+1
    assert set(edges)==set(incoming) and all(n==1 for n in incoming.values()),('open',len(edges),len(incoming),list(set(edges)-set(incoming))[:5],list(set(incoming)-set(edges))[:5])
    loops=[]
    while edges:
        first=next(iter(edges));p=[];at=first
        while True:
            p.append(at);at=edges.pop(at)
            if at==first:break
        assert area(p)>0,('hole',area(p))
        loops.append(p)
    return loops


def soil_cut_prisms(specifications):
    """Convex vertical cutters, split at every real subgrade-profile break."""
    from city_street_geometry import split,bounds
    result=[]
    for row in specifications:
        profile=row['subgrade_profile_m']
        for polygon in row['polygons']:
            lo,_,hi,_=bounds(polygon)
            stations=sorted(set([lo,hi]+[x for x,h in profile if lo<x<hi]))
            for a,b in zip(stations,stations[1:]):
                p,_=split(polygon,(a,1.),(a,0.))
                if p:p,_=split(p,(b,0.),(b,1.))
                if not p:continue
                h,H=profile_height(a,profile),profile_height(b,profile)
                slope=(H-h)/(b-a);intercept=h-slope*a
                planes=[]
                for u,v in zip(p,p[1:]+p[:1]):
                    dx,dz=v[0]-u[0],v[1]-u[1]
                    planes.append((dz,0.,-dx,dx*u[1]-dz*u[0]))
                planes.append((slope,-1.,0.,intercept))
                result.append({'polygon':p,'bounds':bounds(p),'slope':slope,'intercept':intercept,
                               'minimum_y':min(h,H),'planes':planes})
    return result


def clip_soil_face(face,prisms):
    """Remove only cutter interiors from a render face, retaining its winding.

    Unlike a Boolean of an open draw mesh this cannot invent a solid side or
    a cap. New cavity faces come separately from the closed native soil union.
    Unaffected double-precision source faces remain untouched.
    """
    from city_street_geometry import overlap
    parts=[face]
    for prism in prisms:
        kept=[]
        for p in parts:
            box=[min(v[0] for v in p),min(v[2] for v in p),max(v[0] for v in p),max(v[2] for v in p)]
            if max(v[1] for v in p)<=prism['minimum_y'] or not overlap(box,prism['bounds']):
                kept.append(p);continue
            remaining=list(p)
            for nx,ny,nz,d in prism['planes']:
                distance=lambda v:nx*v[0]+ny*v[1]+nz*v[2]+d
                values=[distance(v) for v in remaining]
                if max(values)<=0.:continue
                if min(values)>=0.:
                    kept.append(remaining);remaining=[];break
                outside=_clip_plane(remaining,lambda v:-distance(v))
                if outside:kept.append(outside)
                remaining=_clip_plane(remaining,distance)
                if not remaining:break
        parts=kept
        if not parts:break
    return parts


def _area_xmoment(p):
    """Stable area and first X moment; avoid far-origin shoelace cancellation."""
    a=p[0];areas=[];moments=[]
    for b,c in zip(p[1:-1],p[2:]):
        area=((b[0]-a[0])*(c[1]-a[1])-(b[1]-a[1])*(c[0]-a[0]))*.5
        areas.append(area);moments.append(area*(a[0]+((b[0]-a[0])+(c[0]-a[0]))/3.))
    return math.fsum(areas),math.fsum(moments)


def removed_flat_soil_volume(specifications,region,top,reservations):
    """Independent exact polygon/profile integral, including original voids.

    Valid only where the original soil roof is flat. Callers verify that
    restriction against the actual grade before invoking the native Boolean.
    No mesh Boolean result or measured output volume enters this calculation.
    """
    from city_street_geometry import rectangle,intersection,bounds,overlap,cut,split
    assert len(specifications)<=1,'Combine district overlaps before independent soil-volume proof'
    total=[]
    for row in specifications:
        profile=row['subgrade_profile_m'];floor=min(h for x,h in profile)
        clipped=[p for polygon in row['polygons'] if (p:=intersection(polygon,rectangle(region)))]
        if not clipped:continue
        cut_boxes=[bounds(p) for p in clipped]
        union=disjoint_cut_regions(clipped)
        # Unrelated building cavities must not multiply height slices across
        # every fragment of this street. A conservative per-stock box test
        # rejects only reservations that cannot meet any clipped cutter;
        # exact polygon subtraction below still decides actual overlap.
        relevant=[r['bounds'] for r in reservations if r['bounds'][1]<top and r['bounds'][4]>floor and any(overlap([r['bounds'][0],r['bounds'][2],r['bounds'][3],r['bounds'][5]],box) for box in cut_boxes)]
        heights=sorted(set([floor,top]+[v for b in relevant for v in [b[1],b[4]] if floor<v<top]))
        for y,Y in zip(heights,heights[1:]):
            masks=[rectangle([b[0],b[2],b[3],b[5]]) for b in relevant if b[1]<(y+Y)*.5<b[4]]
            for p in union:
                box=bounds(p)
                local=[m for m in masks if overlap(box,bounds(m))]
                for q in cut(p,local):
                    lo,_,hi,_=bounds(q)
                    stations=[lo,hi]+[x for x,h in profile if lo<x<hi]
                    for (a,h),(b,H) in zip(profile,profile[1:]):
                        if abs(H-h)<1e-15:continue
                        for level in (y,Y):
                            x=a+(level-h)*(b-a)/(H-h)
                            if a<x<b and lo<x<hi:stations.append(x)
                    stations=sorted(set(stations))
                    for a,b in zip(stations,stations[1:]):
                        face,_=split(q,(a,1.),(a,0.))
                        if face:face,_=split(face,(b,0.),(b,1.))
                        if not face:continue
                        h,H=profile_height(a,profile),profile_height(b,profile)
                        middle=(h+H)*.5
                        if middle>=Y:continue
                        area,moment=_area_xmoment(face)
                        if middle<=y:total.append(area*(Y-y))
                        else:
                            slope=(H-h)/(b-a)
                            total.append(area*(Y-h+slope*a)-slope*moment)
    return math.fsum(total)


def chunk_soil_faces(faces,pitch=4.):
    """Split convex cavity faces on the existing ground draw-chunk planes."""
    result={}
    for face in faces:
        low=[min(p[a] for p in face) for a in (0,2)]
        high=[max(p[a] for p in face) for a in (0,2)]
        for ix in range(math.floor(low[0]/pitch),math.floor(high[0]/pitch)+1):
            for iz in range(math.floor(low[1]/pitch),math.floor(high[1]/pitch)+1):
                p=list(face)
                for distance in [lambda p:ix*pitch-p[0],lambda p:p[0]-(ix+1)*pitch,
                                 lambda p:iz*pitch-p[2],lambda p:p[2]-(iz+1)*pitch]:
                    p=_clip_plane(p,distance)
                    if not p:break
                if p:result.setdefault((ix,iz),[]).append(p)
    return result


def exposed_grid_faces(solid, retained):
    """Exact six-neighbour faces using one Y/Z plane of scratch space.

    Preserve the original cell indices and exact-neighbour burial flag. Scratch
    arrays never scale with the number of X planes in the construction grid.
    """
    assert solid.ndim == 3 and retained.shape == solid.shape
    for axis in range(3):
        for direction in (-1, 1):
            for ix in range(solid.shape[0]):
                plane = solid[ix]
                if axis == 0:
                    index = ix+direction
                    if 0 <= index < solid.shape[0]:
                        neighbor, native = solid[index], retained[index]
                    else:
                        neighbor = np.zeros_like(plane);native = neighbor
                else:
                    neighbor = np.zeros_like(plane);native = np.zeros_like(plane)
                    target = [slice(None),slice(None)];source = target.copy()
                    target[axis-1] = slice(1,None) if direction == -1 else slice(None,-1)
                    source[axis-1] = slice(None,-1) if direction == -1 else slice(1,None)
                    neighbor[tuple(target)] = plane[tuple(source)]
                    native[tuple(target)] = retained[ix][tuple(source)]
                for iy,iz in np.argwhere(plane & ~neighbor):
                    yield axis,direction,ix,int(iy),int(iz),bool(native[iy,iz])


def labeled_rectangles(labels):
    """Disjoint maximal row-run rectangles; zero is absent, other labels stay distinct."""
    active = {}
    for v in range(labels.shape[1]):
        row = labels[:,v];current = {}
        if np.any(row):
            cuts = [0]+(np.flatnonzero(row[1:] != row[:-1])+1).tolist()+[len(row)]
            for a,b in zip(cuts,cuts[1:]):
                label = int(row[a])
                if not label:continue
                key = (label,a,b)
                rectangle = active.pop(key,None)
                if rectangle is None:rectangle = [label,a,v,b,v+1]
                else:rectangle[4] = v+1
                current[key] = rectangle
        yield from active.values()
        active = current
    yield from active.values()


def coalesced_grid_planes(solid, retained, asphalt, coordinates, chunk_m=4., parcel_protection=None):
    """Exact boundary rectangles before Python face storage; one normal plane at a time."""
    assert solid.shape == retained.shape == asphalt.shape
    spans = {}
    for axis,values in enumerate(coordinates):
        if axis == 1:spans[axis] = [(0,len(values)-1,None)];continue
        entries=[];start=0;prior=None
        for index,(a,b) in enumerate(zip(values,values[1:])):
            key=int(np.floor((a+b)*.5/chunk_m))
            assert a>=key*chunk_m-1e-6 and b<=(key+1)*chunk_m+1e-6,'Grid must include render chunk planes'
            if prior is not None and key!=prior:entries.append((start,index,prior));start=index
            prior=key
        entries.append((start,len(values)-1,prior));spans[axis]=entries
    for axis in range(3):
        u,v = [i for i in range(3) if i!=axis]
        for direction in (-1,1):
            for index in range(solid.shape[axis]):
                selection=[slice(None)]*3;selection[axis]=index;selection=tuple(selection)
                plane=solid[selection];adjacent=index+direction
                if 0<=adjacent<solid.shape[axis]:
                    other=list(selection);other[axis]=adjacent
                    neighbor=solid[tuple(other)];native=retained[tuple(other)]
                else:neighbor=np.zeros_like(plane);native=neighbor
                exposed=plane & ~neighbor
                count=int(np.count_nonzero(exposed))
                if not count:continue
                if parcel_protection is None:reserved=np.zeros_like(plane)
                elif axis==0:reserved=np.broadcast_to(parcel_protection[index][None,:],plane.shape)
                elif axis==1:reserved=parcel_protection
                else:reserved=np.broadcast_to(parcel_protection[:,index,None],plane.shape)
                source_labels=exposed.astype(np.uint8);source_labels[exposed & reserved]=2
                source_rows=list(labeled_rectangles(source_labels))
                source=[tuple(r[1:]) for r in source_rows]
                visible=exposed & ~native
                buried=count-int(np.count_nonzero(visible))
                base=axis==1 and direction==-1 and index==0
                render=[]
                if not base:
                    labels=visible.astype(np.uint8)
                    labels[visible & asphalt[selection]]=2
                    labels[visible & reserved]+=2
                    for label,a,b,A,B in labeled_rectangles(labels):
                        for lo,hi,ku in spans[u]:
                            if hi<=a or lo>=A:continue
                            for low,high,kv in spans[v]:
                                if high<=b or low>=B:continue
                                chunks={u:ku,v:kv}
                                if axis in (0,2):chunks[axis]=int(np.floor((coordinates[axis][index]+coordinates[axis][index+1])*.5/chunk_m))
                                render.append((label,(max(a,lo),max(b,low),min(A,hi),min(B,high)),(chunks[0],chunks[2])))
                yield dict(axis=axis,direction=direction,plane=index+(direction>0),source=source,render=render,
                           source_unprotected=[tuple(r[1:]) for r in source_rows if r[0]==1],
                           source_protected=[tuple(r[1:]) for r in source_rows if r[0]==2],
                           boundary_cells=count,buried_cells=buried,base_cells=int(np.count_nonzero(visible)) if base else 0)


def profile_height(at, points):
    """Clamped authored height; callers retain the registered metre frame."""
    assert len(points) >= 2 and all(b[0] > a[0] for a, b in zip(points, points[1:]))
    if at <= points[0][0]: return float(points[0][1])
    for (a, h), (b, H) in zip(points, points[1:]):
        if at <= b: return float(h + (H-h)*(at-a)/(b-a))
    return float(points[-1][1])


def _clip_plane(points, distance):
    """Keep the nonpositive side of a plane, preserving polygon winding."""
    out = []
    for a, b in zip(points, points[1:]+points[:1]):
        da, db = distance(a), distance(b)
        if da <= 0.: out.append(tuple(a))
        if (da < 0. < db) or (db < 0. < da):
            t = da/(da-db)
            out.append(tuple(u+t*(v-u) for u, v in zip(a, b)))
    unique = []
    for p in out:
        if not unique or np.linalg.norm(np.subtract(p, unique[-1])) > 1e-10:
            unique.append(p)
    if len(unique) > 1 and np.linalg.norm(np.subtract(unique[0], unique[-1])) <= 1e-10:
        unique.pop()
    if len(unique) < 3: return []
    normal = sum((np.cross(np.subtract(b, unique[0]), np.subtract(c, unique[0]))
                  for b, c in zip(unique[1:-1], unique[2:])), np.zeros(3))
    return unique if np.linalg.norm(normal) > 1e-12 else []


def clip_profile_face(points, profile):
    """Clip one convex soil face below a piecewise linear roof, without moving it.

    Subdivision at profile breaks supports convex as well as concave profiles.
    This only removes existing soil; it never translates a reservation cavity.
    Coordinates use (building X, height, building Z). New cap faces are separate.
    """
    low = min(p[0] for p in points); high = max(p[0] for p in points)
    breaks = [low] + [x for x, _ in profile if low < x < high] + [high]
    if high-low <= 1e-12:
        cap = profile_height(low, profile)
        face = _clip_plane(list(points), lambda p: p[1]-cap)
        return [face] if face else []
    result = []
    for a, b in zip(breaks, breaks[1:]):
        face = _clip_plane(list(points), lambda p: a-p[0])
        if face: face = _clip_plane(face, lambda p: p[0]-b)
        h, H = profile_height(a, profile), profile_height(b, profile)
        if face: face = _clip_plane(face, lambda p: p[1]-h-(H-h)*(p[0]-a)/(b-a))
        if face: result.append(face)
    return result


def profile_cell_volume(x0, x1, y0, y1, z0, z1, profile):
    """Independent exact integral of an axis-aligned cell below a linear roof.

    Threshold crossings split the integral before trapezoids are accumulated;
    sampling a cell centre or just its end heights would overcount cut cells.
    """
    assert x1 > x0 and y1 > y0 and z1 > z0
    cuts = [x0] + [x for x, _ in profile if x0 < x < x1] + [x1]
    area = 0.
    for a, b in zip(cuts, cuts[1:]):
        h, H = profile_height(a, profile), profile_height(b, profile)
        stations = [a, b]
        if abs(H-h) > 1e-15:
            stations += [a+(y-h)*(b-a)/(H-h) for y in (y0, y1) if min(h, H) < y < max(h, H)]
        stations.sort()
        depth = lambda x: max(0., min(y1, profile_height(x, profile))-y0)
        area += sum((d-c)*(depth(c)+depth(d))*.5 for c, d in zip(stations, stations[1:]))
    return area*(z1-z0)


def profile_grid_volume(xs, ys, zs, solid, profile, parcel_protection=None):
    """Integrate the remaining original soil cells, without mesh-volume input."""
    dz = np.diff(zs); volume = 0.
    for i, (a, b) in enumerate(zip(xs, xs[1:])):
        breaks = [a] + [x for x, _ in profile if a < x < b] + [b]
        heights = [profile_height(x, profile) for x in breaks]
        weights = np.maximum(0., np.minimum(ys[1:], min(heights))-ys[:-1])*(b-a)
        crossing = np.flatnonzero((ys[:-1] < max(heights)) & (ys[1:] > min(heights)))
        for j in crossing:
            weights[j] = profile_cell_volume(a,b,ys[j],ys[j+1],0.,1.,profile)
        lengths = np.einsum('jk,k->j',solid[i],dz,dtype=np.float64)
        if parcel_protection is None:volume += float(weights @ lengths)
        else:
            protected=np.einsum('jk,k->j',solid[i],dz*parcel_protection[i],dtype=np.float64)
            volume += float(weights @ (lengths-protected)+(np.diff(ys)*(b-a)) @ protected)
    return volume


def profile_roof_caps(xs, ys, zs, solid, profile, chunk_m=8., parcel_protection=None):
    """New upward roof faces where the cut crosses occupied original cells.

    Split at every original height plane and chunk boundary. Cavity footprints
    come from the actual boolean grid; mask envelopes never become solid caps.
    Existing exposed horizontal faces are retained by face clipping, not doubled.
    """
    result = []
    for i, (a, b) in enumerate(zip(xs, xs[1:])):
        bands = [a] + [x for x, _ in profile if a < x < b] + [b]
        bands += [chunk_m*k for k in range(int(np.floor(a/chunk_m))+1,int(np.ceil(b/chunk_m))) if a < chunk_m*k < b]
        bands = sorted(set(bands))
        for c, d in zip(bands, bands[1:]):
            h, H = profile_height(c, profile), profile_height(d, profile)
            stations = [c, d]
            if abs(H-h) > 1e-15:
                stations += [c+(y-h)*(d-c)/(H-h) for y in ys if min(h,H) < y < max(h,H)]
            stations.sort()
            for u, v in zip(stations, stations[1:]):
                height = profile_height((u+v)*.5, profile)
                if not ys[0] < height < ys[-1]-1e-10: continue
                j = int(np.searchsorted(ys,height,side='left'))-1
                occupied = solid[i,j].copy()
                if parcel_protection is not None:occupied &= ~parcel_protection[i]
                if abs(H-h) <= 1e-15 and abs(height-ys[j+1]) <= 1e-10:
                    occupied &= solid[i,j+1]  # Existing exposed top is not a new cap.
                start = None; owner = None
                for k in range(len(zs)-1):
                    group = int(np.floor((zs[k]+zs[k+1])*.5/chunk_m))
                    if start is not None and (not occupied[k] or group != owner):
                        z0,z1 = zs[start],zs[k]
                        result.append([(u,profile_height(u,profile),z0),(u,profile_height(u,profile),z1),
                                       (v,profile_height(v,profile),z1),(v,profile_height(v,profile),z0)])
                        start = None
                    if occupied[k] and start is None: start=k;owner=group
                if start is not None:
                    z0,z1 = zs[start],zs[-1]
                    result.append([(u,profile_height(u,profile),z0),(u,profile_height(u,profile),z1),
                                   (v,profile_height(v,profile),z1),(v,profile_height(v,profile),z0)])
    return result


def parcel_transition_cells(xs,ys,solid,profile,protected):
    """Require the original foundation voids to retain every raised parcel.

    A connected soil cell across a height discontinuity would need a new wall
    face. Refuse that case instead of leaving an open mesh or an earth cliff.
    """
    count=0
    for i in range(1,protected.shape[0]):
        change=protected[i-1]^protected[i]
        if np.any(change):
            h=profile_height(xs[i],profile)
            count+=int(np.count_nonzero(solid[i-1]&solid[i]&(ys[1:,None]>h)&change[None,:]))
    lower=np.asarray([min(profile_height(a,profile),profile_height(b,profile)) for a,b in zip(xs,xs[1:])])
    for k in range(1,protected.shape[1]):
        change=protected[:,k-1]^protected[:,k]
        if np.any(change):count+=int(np.count_nonzero(solid[:,:,k-1]&solid[:,:,k]&(ys[None,1:]>lower[:,None])&change[:,None]))
    return count


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
    west = profile_height(x, relief['west_profile']) if x >= relief['west_profile'][0][0] else top
    east = profile_height(x, relief['east_profile']) if x <= relief['east_profile'][-1][0] else top
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
