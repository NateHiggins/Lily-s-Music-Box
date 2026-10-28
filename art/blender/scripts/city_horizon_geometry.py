"""Closed distant window reveals; source geometry, never runtime evidence."""

import math


def building_outline(row):
    """Clockwise Blender XY boundary; explicit study outlines use Godot X/Z."""
    a,b,c,d=row['rect']
    points=row.get('architecture',{}).get('outline_m',[[c,d],[a,d],[a,b],[c,b]])
    outline=[(float(x),-float(z)) for x,z in points]
    area=sum(x*Y-X*y for (x,y),(X,Y) in zip(outline,outline[1:]+outline[:1]))*.5
    assert len(outline)>=4 and area<0,'Outline must run clockwise in Blender XY'
    assert all(a-1e-7<=x<=c+1e-7 and b-1e-7<=-y<=d+1e-7 for x,y in outline)
    return outline


def extrusion(outline,bottom,top):
    """Closed, consistently oriented polygonal stock, including concave courts."""
    assert bottom<top
    n=len(outline)
    vertices=[(x,y,z) for z in [bottom,top] for x,y in outline]
    faces=[tuple(range(n)),tuple(range(2*n-1,n-1,-1))]
    faces += [(j,i,i+n,j+n) for i,j in zip(range(n),list(range(1,n))+[0])]
    return vertices,faces


def offset_outline(outline,distance):
    """Intersect neighboring offset lines: full-depth mitres around real bays."""
    result=[]
    for index,p in enumerate(outline):
        previous=outline[index-1]; following=outline[(index+1)%len(outline)]
        ax,ay=p[0]-previous[0],p[1]-previous[1];al=math.hypot(ax,ay);ax/=al;ay/=al
        bx,by=following[0]-p[0],following[1]-p[1];bl=math.hypot(bx,by);bx/=bl;by/=bl
        det=ay*bx-ax*by;assert abs(det)>1e-8,'Collinear outline corner'
        # Left normals point out of this clockwise boundary.
        dx=(-by+ay)*distance;dy=(bx-ax)*distance
        t=(-by*dx+bx*dy)/det
        result.append((p[0]-ay*distance+ax*t,p[1]+ax*distance+ay*t))
    return result


def cornice_ring(outline,width,bottom,top):
    """Closed annular course. Its inner edge seats on the masonry face."""
    outer=offset_outline(outline,width);n=len(outline)
    v=[(x,y,z) for z in [bottom,top] for ring in [outline,outer] for x,y in ring]
    f=[]
    for i in range(n):
        j=(i+1)%n
        f += [(i,j,j+n,i+n),(i+2*n,i+3*n,j+3*n,j+2*n),
              (i,i+2*n,j+2*n,j),(i+n,j+n,j+3*n,i+3*n)]
    return v,[tuple(reversed(face)) for face in f]


def floor_intervals(row):
    study=row.get('architecture',{})
    heights=study.get('floor_heights_m')
    if heights is None:
        count=max(1,round(row['height_m']/row['storey_m']))
        height=row['height_m']/count
        # Preserve the existing multiplication order for unedited buildings.
        return [(i*height,(i+1)*height) for i in range(count)]
    assert all(float(h)>.65 for h in heights) and abs(sum(heights)-row['height_m'])<1e-6
    bottom=0.; result=[]
    for height in heights:
        result.append((bottom,bottom+height));bottom+=height
    return result

def reveal_cell(left,bottom,right,top,wl,low,wr,high,depth):
    assert left<wl<wr<right and bottom<low<high<top and 0<depth<.5
    outer=[(left,bottom),(left,top),(right,top),(right,bottom)]
    inner=[(wl,low),(wl,high),(wr,high),(wr,low)]
    vertices=[(x,y,z) for ring,y in [(outer,0),(outer,-depth),(inner,0),(inner,-depth)] for x,z in ring]
    faces=[]
    for i in range(4):
        j=(i+1)%4
        faces.extend([(i,j,j+8,i+8),(i+4,i+12,j+12,j+4),
                      (i,i+4,j+4,j),(i+8,j+8,j+12,i+12)])
    return vertices,faces


def ray_hit(origin,direction,row,height):
    if float(row['height_m'])<height:return False
    a,b,c,d=row['rect'];entry=0.;leave=1000.
    for at,component,lo,hi in zip(origin,direction,[a,b],[c,d]):
        if abs(component)<1e-12:
            if not lo<=at<=hi:return False
        else:
            first,second=sorted(((lo-at)/component,(hi-at)/component))
            entry=max(entry,first);leave=min(leave,second)
    return leave>=entry


def party_wall_overlap(first,last,floor_bottom,neighbours):
    """Actual outward wall segment, in root X/Z, covered by another mass."""
    x,z=first;X,Z=last
    for row in neighbours:
        if floor_bottom>=float(row['height_m'])+.65:continue
        a,b,c,d=row['rect']
        if abs(x-X)<1e-8:
            if a<x<c and min(max(z,Z),d)>max(min(z,Z),b)+1e-8:return True
        elif abs(z-Z)<1e-8:
            if b<z<d and min(max(x,X),c)>max(min(x,X),a)+1e-8:return True
        else:raise AssertionError('Facade segment is not axis-aligned')
    return False


def validate_plan(plan,retained_bounds):
    assert plan['schema']=='orison.city-horizon.v1' and plan['frame']=='ORISON_V2_BUILDING_FRAME'
    seen=set()
    for index,row in enumerate(plan['buildings']):
        assert row['id'] not in seen;seen.add(row['id'])
        a,b,c,d=row['rect'];x,y,z,X,Y,Z=retained_bounds
        assert a<c and b<d and 6<=row['height_m']<=55
        assert c<=x-4 or a>=X+4 or d<=z-4 or b>=Z+4
        assert min(a,b)>=-400 and max(c,d)<=400
        for other in plan['buildings'][index+1:]:
            e,f,g,h=other['rect']
            assert min(c,g)<=max(a,e) or min(d,h)<=max(b,f),(row['id'],other['id'])
    return True
