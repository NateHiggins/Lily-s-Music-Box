"""Closed distant window reveals; source geometry, never runtime evidence."""

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
