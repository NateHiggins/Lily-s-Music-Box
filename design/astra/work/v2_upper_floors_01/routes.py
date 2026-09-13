"""Capsule plan clearance against derived walls, chases and physical leaves."""
from collections import deque
import math
import build


def check(layout,program):
    walls=build.module('design/astra/work/v2_apartment_walls_batch_01/build.py','upper_route_walls')
    geo=build.module('design/astra/work/v2_apartment_doors_batch_01/check.py','upper_route_doors')
    edges=[w for w in walls.owned(layout) if w['level'] in ['F05','F06']]
    solids=[]
    for w in edges:
        holes=[(r['start'],r['end']) for r in walls.apertures(layout,w) if r['sill']==0 and r['height']>=1.574]
        for start,end in walls.subtract(w['start'],w['end'],holes):
            rect=[start,w['fixed']-.07,end,w['fixed']+.07] if w['axis']=='x' else [w['fixed']-.07,start,w['fixed']+.07,end]
            solids.append((w['owner'],w['level'],rect))
    for level in ['F05','F06']:
        for r in layout['risers']:
            if r.get('solid',True):solids.append((r['id'],level,r['rect']))
    doors={d['id']:d for d in layout['doors'] if d['id'] in program['doors']}
    def leaf(identity,d,degrees):
        offset=geo.rotate([0,program['doors'][identity]['mount_offset']],d['yaw'])
        return [[p[i]+offset[i] for i in [0,1]] for p in geo.leaf_polygon(d,program['doors'][identity]['swing_out'],degrees)]
    poses=0
    for identity,door in doors.items():
        for n in range(201):
            polygon=leaf(identity,door,n*.5)
            bounds=[min(p[0] for p in polygon),min(p[1] for p in polygon),max(p[0] for p in polygon),max(p[1] for p in polygon)]
            for owner,level,r in solids:
                if level!=door['level'] or min(bounds[2],r[2])<=max(bounds[0],r[0]) or min(bounds[3],r[3])<=max(bounds[1],r[1]):continue
                assert not geo.overlaps(polygon,geo.rect_polygon(r)),('leaf hits wall/chase',identity,owner,n*.5)
            poses+=1
    results=[]
    for level in ['F05','F06']:
        floor_rects=[r['rect'] for r in layout['spaces'] if r['level']==level and not r.get('no_floor')]
        floor_rects += [r['rect'] for r in layout['platforms'] if r['level']==level]
        rects=[r for _,floor,r in solids if floor==level]
        leaves=[leaf(identity,d,0 if program['doors'][identity]['leaf_state']=='locked' else 100)
                for identity,d in doors.items() if d['level']==level]
        def floor_at(x,z):return any(r[0]<=x<=r[2] and r[1]<=z<=r[3] for r in floor_rects)
        def clear(ix,iz):
            x,z=ix/10,iz/10
            for dx,dz in [(0,0),(.38,0),(-.38,0),(0,.38),(0,-.38),(.269,.269),(-.269,.269),(.269,-.269),(-.269,-.269)]:
                if not floor_at(x+dx,z+dz):return False
            for r in rects:
                if math.hypot(max(r[0]-x,0,x-r[2]),max(r[1]-z,0,z-r[3]))<.38:return False
            for polygon in leaves:
                if min(p[0] for p in polygon)-.38<x<max(p[0] for p in polygon)+.38 and min(p[1] for p in polygon)-.38<z<max(p[1] for p in polygon)+.38:
                    if geo.distance([x,z],polygon)<.38:return False
            return True
        start=(0,0);assert clear(*start)
        todo=deque([start]);reached={start};blocked=set();previous={}
        while todo:
            at=todo.popleft()
            for dx,dz in [(1,0),(-1,0),(0,1),(0,-1)]:
                step=(at[0]+dx,at[1]+dz)
                if step in reached or step in blocked:continue
                if clear(*step):
                    previous[step]=at;reached.add(step);todo.append(step)
                else:blocked.add(step)
        paths=[]
        for p in program['programs']:
            if not p['unit'].startswith(level[-1]):continue
            for identity in p['rooms']:
                room=next(s for s in layout['spaces'] if s['id']==identity);r=room['rect']
                candidates=[n for n in reached if r[0]+.38<n[0]/10<r[2]-.38 and r[1]+.38<n[1]/10<r[3]-.38]
                if p['disposition']!='occupied':
                    assert not candidates,('restricted room is bypassable',identity)
                    continue
                assert candidates,('capsule cannot reach room',identity)
                goal=min(candidates,key=lambda n: math.dist([n[0]/10,n[1]/10],[(r[0]+r[2])/2,(r[1]+r[3])/2]))
                points=[goal]
                while points[-1]!=start:points.append(previous[points[-1]])
                points.reverse()
                # Every 100mm grid edge is resampled at 25mm, so a narrow
                # diagonal wall end cannot slip between accepted grid nodes.
                for a,b in zip(points,points[1:]):
                    for t in [.25,.5,.75]:assert clear(a[0]+(b[0]-a[0])*t,a[1]+(b[1]-a[1])*t)
                paths.append(dict(room=identity,points=[[x/10,z/10] for x,z in points]))
        # Reach both established stair arrival lanes without crossing a void.
        for label,point in [('primary stair',[3.8,-2.6]),('service stair',[12.5,4.3])]:
            key=tuple(round(v*10) for v in point)
            assert key in reached,('upper stair landing disconnected',level,label)
        results.append(dict(level=level,reachable_grid_points=len(reached),room_routes=paths))
    return dict(radius=.38,grid_step=.1,edge_sample_step=.025,leaf_sweep_poses=poses,floors=results,
                limits='Plan clearance only, doors pre-opened except restricted entries. Does not prove operating stance, hardware rays, controller movement, stair climbing or engine physics.')
