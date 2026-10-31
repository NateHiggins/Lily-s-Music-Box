"""Metre-space polygon construction for native street and station paving.

No runtime state or Blender scene mutation. Polygons are counterclockwise;
convex subtraction returns disjoint convex pieces and preserves actual curves
as the explicitly authored polygonal approximation.
"""
import math
EPS=1e-9

def grade_at(x,profile):
    """Authored street reference height; linear pieces and end continuation.

    Stations are construction-space X, not historical survey chainage.
    Breaks must also split native prisms so every top face remains planar.
    """
    assert len(profile)>=2 and all(b[0]>a[0] for a,b in zip(profile,profile[1:]))
    segment=next(((a,b) for a,b in zip(profile,profile[1:]) if x<=b[0]),(profile[-2],profile[-1]))
    a,b=segment
    return a[1]+(b[1]-a[1])*(x-a[0])/(b[0]-a[0])

def area(p):
    return sum(a[0]*b[1]-b[0]*a[1] for a,b in zip(p,p[1:]+p[:1]))*.5

def clean(p):
    q=[]
    for a in p:
        if not q or math.dist(a,q[-1])>EPS:q.append(tuple(a))
    if len(q)>1 and math.dist(q[0],q[-1])<EPS:q.pop()
    if len(q)<3 or abs(area(q))<1e-10:return []
    return q if area(q)>0 else list(reversed(q))

def rectangle(r):
    a,b,c,d=r;assert c>a and d>b
    return [(a,b),(c,b),(c,d),(a,d)]

def bounds(p):return [min(x for x,y in p),min(y for x,y in p),max(x for x,y in p),max(y for x,y in p)]

def overlap(a,b):return a[0]<b[2]-EPS and a[2]>b[0]+EPS and a[1]<b[3]-EPS and a[3]>b[1]+EPS

def split(p,a,b):
    inside=[];outside=[]
    cross=lambda v:(b[0]-a[0])*(v[1]-a[1])-(b[1]-a[1])*(v[0]-a[0])
    for u,v in zip(p,p[1:]+p[:1]):
        du,dv=cross(u),cross(v)
        if du>=-EPS:inside.append(u)
        if du<=EPS:outside.append(u)
        if (du<-EPS and dv>EPS) or (dv<-EPS and du>EPS):
            t=du/(du-dv);w=(u[0]+t*(v[0]-u[0]),u[1]+t*(v[1]-u[1]))
            inside.append(w);outside.append(w)
    return clean(inside),clean(outside)

def subtract(p,clip):
    if not overlap(bounds(p),bounds(clip)):return [p]
    result=[];remaining=p
    for a,b in zip(clip,clip[1:]+clip[:1]):
        remaining,outside=split(remaining,a,b)
        if outside:result.append(outside)
        if not remaining:break
    return result

def intersection(p,clip):
    for a,b in zip(clip,clip[1:]+clip[:1]):
        p,_=split(p,a,b)
        if not p:break
    return p

def cut(p,masks):
    parts=[p]
    for mask in masks:
        parts=[q for part in parts for q in subtract(part,mask)]
        if not parts:break
    return parts

def triangles(p):
    # Ear clipping supports the concave road corner without Blender's API.
    p=clean(p);result=[]
    def cross(a,b,c):return (b[0]-a[0])*(c[1]-a[1])-(b[1]-a[1])*(c[0]-a[0])
    while len(p)>3:
        found=False
        for i,b in enumerate(p):
            a,c=p[i-1],p[(i+1)%len(p)]
            if cross(a,b,c)<=1e-10:continue
            tri=[a,b,c]
            if any(all(cross(u,v,q)>=-1e-10 for u,v in zip(tri,tri[1:]+tri[:1])) for j,q in enumerate(p) if j not in [i,(i-1)%len(p),(i+1)%len(p)]):continue
            result.append(tri);p=p[:i]+p[i+1:];found=True;break
        assert found,'Non-simple or collapsed street polygon'
    if p:result.append(p)
    return result

def topology(plan,traffic,frame,transport):
    north=-float(frame['source_threshold_z'])-float(traffic['site']['carriageway_z'][0])
    south=north-float(plan['carriageway_width_m'])
    road=[rectangle([plan['main_x_m'][0],south,plan['main_x_m'][1],north])]
    corners=[];curbs=[];caps=[];half=float(traffic['junctions']['cross_half_width']);r=float(plan['corner_radius_m']);w=float(plan['curb_width_m']);n=int(plan['corner_segments']);o=float(plan['curb_cap_overhang_m'])
    xs=[float(traffic['junctions'][side+'_x']) for side in ['west','east']]
    cross_bounds=[]
    for side,x in zip(['west','east'],xs):
        left=x-half+float(plan['cross_west_inset_m'][side]);right=x+half;cross_bounds.append([left,right])
        road.extend([rectangle([left,north,right,plan['cross_north_end_m']]),rectangle([left,plan['cross_south_end_m'],right,south])])
        for sx in [-1,1]:
            for sy,y in [(-1,south),(1,north)]:
                edge=left if sx<0 else right;cx=edge+sx*r;cy=y+sy*r
                # Local corner q=(0,0) is the intersection of straight edges.
                arc=[(cx-sx*r*math.sin(i*math.pi/(2*n)),cy-sy*r*math.cos(i*math.pi/(2*n))) for i in range(n+1)]
                patch=clean([(edge,y)]+arc)
                road.extend(triangles(patch));corners.append(dict(center=[cx,cy],sign=[sx,sy],radius=r,road_polygon=patch))
                inner=[(cx-sx*(r-w)*math.sin(i*math.pi/(2*n)),cy-sy*(r-w)*math.cos(i*math.pi/(2*n))) for i in range(n+1)]
                curbs.extend(clean([arc[i],arc[i+1],inner[i+1],inner[i]]) for i in range(n))
                outer_cap=[(cx-sx*(r+o)*math.sin(i*math.pi/(2*n)),cy-sy*(r+o)*math.cos(i*math.pi/(2*n))) for i in range(n+1)]
                inner_cap=[(cx-sx*(r-w-o)*math.sin(i*math.pi/(2*n)),cy-sy*(r-w-o)*math.cos(i*math.pi/(2*n))) for i in range(n+1)]
                caps.extend(clean([outer_cap[i],outer_cap[i+1],inner_cap[i+1],inner_cap[i]]) for i in range(n))
        for sx in [-1,1]:
            edge=left if sx<0 else right
            a,b=sorted([edge,edge+sx*w])
            curbs.extend([rectangle([a,north+r,b,plan['cross_north_end_m']]),rectangle([a,plan['cross_south_end_m'],b,south-r])])
            caps.extend([rectangle([a-o,north+r,b+o,plan['cross_north_end_m']]),rectangle([a-o,plan['cross_south_end_m'],b+o,south-r])])
    # Main curb courses stop at retained fixed curb stocks and curved returns.
    main_spans=[plan['main_x_m'][0],cross_bounds[0][0]-r,cross_bounds[0][1]+r,-20.3,20.8,cross_bounds[1][0]-r,cross_bounds[1][1]+r,plan['main_x_m'][1]]
    for a,b in zip(main_spans[::2],main_spans[1::2]):
        if b<=a:continue
        cuts=[a]+([a+2.] if abs(a-20.8)<EPS else [])+([b-2.] if abs(b+20.3)<EPS else [])+[b]
        width=lambda x:.34 if abs(x-20.8)<EPS or abs(x+20.3)<EPS else w
        for left,right in zip(cuts,cuts[1:]):
            for y,sign in [(north,1),(south,-1)]:
                curbs.append(clean([(left,y),(right,y),(right,y+sign*width(right)),(left,y+sign*width(left))]))
                caps.append(clean([(left,y-sign*o),(right,y-sign*o),(right,y+sign*(width(right)+o)),(left,y+sign*(width(left)+o))]))
    margin=plan['protected_pier_margin_m'];islands=[]
    for x in transport['station']['bent_x_m']:
        for y in transport['station']['column_y_m']:
            rect=[x-.65-margin,y-.65-margin,x+.65+margin,y+.65+margin]
            if any(overlap(bounds(p),rect) for p in road):islands.append(rect)
    road=[q for p in road for q in cut(p,[rectangle(r) for r in islands])]
    curbs=[q for p in curbs for q in cut(p,[rectangle(r) for r in islands])]
    caps=[q for p in caps for q in cut(p,[rectangle(r) for r in islands])]
    # Straight protected islands are seated on retained station paving.
    for a,b,c,d in islands:
        curbs.extend([rectangle([a,b,c,b+w]),rectangle([a,d-w,c,d]),rectangle([a,b+w,a+w,d-w]),rectangle([c-w,b+w,c,d-w])])
        caps.extend([rectangle([a,b,c,b+w]),rectangle([a,d-w,c,d]),rectangle([a,b+w,a+w,d-w]),rectangle([c-w,b+w,c,d-w])])
    return dict(road=road,curbs=curbs,curb_caps=caps,corners=corners,islands=islands,north=north,south=south,junction_x=xs,cross_x_bounds=cross_bounds)


def offset_polygon(polygon,distance):
    """Parallel boundary with real mitres; input/output counterclockwise."""
    p=clean(polygon);result=[]
    for i,at in enumerate(p):
        previous=p[i-1];following=p[(i+1)%len(p)]
        ax,ay=at[0]-previous[0],at[1]-previous[1];length=math.hypot(ax,ay);ax/=length;ay/=length
        bx,by=following[0]-at[0],following[1]-at[1];length=math.hypot(bx,by);bx/=length;by/=length
        det=ax*by-ay*bx
        if abs(det)<1e-10:
            assert ax*bx+ay*by>.999999,'Reversing boundary'
            result.append((at[0]+ay*distance,at[1]-ax*distance));continue
        dx=(by-ay)*distance;dy=(ax-bx)*distance
        along=(dx*by-dy*bx)/det
        result.append((at[0]+ay*distance+ax*along,at[1]-ax*distance+ay*along))
    assert area(result)>0
    return result


def district_topology(spec,segments,curb_width,cap_overhang):
    """Native added road/footway geometry, including open continuation ends.

    This consumes CITY_ELEVATIONS_SOURCE coordinates. It makes no ground cut
    or runtime access claim: the required subgrade is emitted by the builder.
    """
    polygon=clean(spec['road_outline_m']);radius=float(spec['corner_radius_m'])
    assert segments>=4 and radius>0 and curb_width>0
    def is_open(a,b):
        return any(abs(a[int(row['axis'])]-row['value_m'])<1e-7 and
                   abs(b[int(row['axis'])]-row['value_m'])<1e-7 for row in spec['open_edges'])
    rounded=[]
    for i,p in enumerate(polygon):
        a=polygon[i-1];b=polygon[(i+1)%len(polygon)]
        ux,uy=p[0]-a[0],p[1]-a[1];before=math.hypot(ux,uy);ux/=before;uy/=before
        vx,vy=b[0]-p[0],b[1]-p[1];after=math.hypot(vx,vy);vx/=after;vy/=after
        angle=math.atan2(ux*vy-uy*vx,ux*vx+uy*vy)
        if is_open(a,p) or is_open(p,b) or abs(angle)<1e-8:
            rounded.append(p);continue
        trim=radius*math.tan(abs(angle)*.5)
        assert trim<min(before,after)*.45,('Fillet exceeds adjacent street',p)
        start=(p[0]-ux*trim,p[1]-uy*trim);sign=1 if angle>0 else -1
        center=(start[0]-uy*radius*sign,start[1]+ux*radius*sign)
        phase=math.atan2(start[1]-center[1],start[0]-center[0])
        for step in range(segments+1):
            turn=phase+angle*step/segments
            rounded.append((center[0]+radius*math.cos(turn),center[1]+radius*math.sin(turn)))
    rounded=clean(rounded);outer=offset_polygon(rounded,curb_width)
    cap_inner=offset_polygon(rounded,-cap_overhang);cap_outer=offset_polygon(rounded,curb_width+cap_overhang)
    curbs=[];caps=[]
    for i,p in enumerate(rounded):
        j=(i+1)%len(rounded);q=rounded[j]
        if is_open(p,q):continue
        curb=clean([p,q,outer[j],outer[i]]);cap=clean([cap_inner[i],cap_inner[j],cap_outer[j],cap_outer[i]])
        assert curb and cap
        curbs.extend(triangles(curb));caps.extend(triangles(cap))
    road=triangles(rounded);walk=[];masks=[rectangle(r) for r in spec['reserved_rects_m']]
    # Disjoint subjects prevent stacked public floor providers at the three
    # junctions. Curbs and preserved stairs keep their physical ownership.
    occupied=road+caps+masks
    for rect in spec['walk_rects_m']:
        pieces=cut(rectangle(rect),occupied)
        walk.extend(pieces);occupied.append(rectangle(rect))
    return dict(road=road,curbs=curbs,curb_caps=caps,walk=walk,
                rounded_road_outline=rounded,reserved=masks,
                maximum_curve_sagitta_m=radius*(1-math.cos(math.pi/(4*segments))))
