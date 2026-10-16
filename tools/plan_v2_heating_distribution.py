"""Draft underfloor heating routes through authored floor coverage, never across voids.

Candidate routing only: joist conflicts, sleeves, joints and native fitting still
require fabrication review before these routes can drive installed geometry.
"""
import argparse
import heapq
import itertools
import json
import math
from functools import lru_cache
from pathlib import Path
from heating_pipe_fittings import fitted_stations, floor_boundary

ROOT = Path(__file__).resolve().parents[1]
STEP = .10


def segment_distance(a,b,c,d):
    sub=lambda x,y:tuple(i-j for i,j in zip(x,y))
    dot=lambda x,y:sum(i*j for i,j in zip(x,y))
    u,v,w=sub(b,a),sub(d,c),sub(a,c)
    aa,bb,cc=dot(u,u),dot(u,v),dot(v,v)
    dd,ee=dot(u,w),dot(v,w)
    def point_distance(p,x,y):
        delta=sub(y,x);den=dot(delta,delta)
        t=max(0,min(1,dot(sub(p,x),delta)/den)) if den else 0
        return math.dist(p,[q+t*r for q,r in zip(x,delta)])
    result=min(point_distance(a,c,d),point_distance(b,c,d),point_distance(c,a,b),point_distance(d,a,b))
    det=aa*cc-bb*bb
    if det>1e-15:
        s,t=(bb*ee-cc*dd)/det,(aa*ee-bb*dd)/det
        if 0<=s<=1 and 0<=t<=1:
            result=min(result,math.dist([x+s*y for x,y in zip(a,u)],[x+t*y for x,y in zip(c,v)]))
    return result


def segments_within(a,b,c,d,distance):
    # Cheap broad phase avoids exact distances for remote floor edges.
    if any(max(a[i],b[i])+distance<min(c[i],d[i]) or
           max(c[i],d[i])+distance<min(a[i],b[i]) for i in range(len(a))):
        return False
    return segment_distance(a,b,c,d)<distance


def branch_conflicts(branches, radius=.032, clearance=.008):
    conflicts=[]
    for i,left in enumerate(branches):
        for right in branches[i+1:]:
            if left['level']!=right['level']: continue
            lp,rp=left['points_local_godot'],right['points_local_godot']
            if not lp or not rp: continue
            distance=min(segment_distance(a,b,c,d) for a,b in zip(lp,lp[1:]) for c,d in zip(rp,rp[1:]))
            if distance < 2*radius+clearance:
                conflicts.append({'a':left['id'],'b':right['id'],'centerline_distance_m':distance,
                                  'required_m':2*radius+clearance})
    return conflicts


def route(start, end, rectangles, holes, radius=.032, pipes=(), smooth=True):
    _, boundary = floor_boundary(rectangles, list(holes))
    def contains(rect, x, z):
        return rect[0] <= x <= rect[2] and rect[1] <= z <= rect[3]
    @lru_cache(maxsize=None)
    def clear(x,z):
        for a,b in pipes:
            dx,dz=b[0]-a[0],b[1]-a[1];length=dx*dx+dz*dz
            t=max(0,min(1,((x-a[0])*dx+(z-a[1])*dz)/length)) if length else 0
            if math.hypot(x-a[0]-t*dx,z-a[1]-t*dz)<radius+.04: return False
        for dx,dz in [(0,0),(radius,0),(-radius,0),(0,radius),(0,-radius)]:
            if not any(contains(r,x+dx,z+dz) for r in rectangles): return False
            if any(contains(r,x+dx,z+dz) for r in holes): return False
        return True
    def segment(a,b):
        # Exact union boundaries catch narrow openings missed by sampling.
        if any(segments_within(a,b,c,d,radius-1e-10) for c,d in boundary):
            return False
        # Sampling alone misses near contacts between samples at pipe corners.
        if any(segments_within(a,b,c,d,radius+.04-1e-10) for c,d in pipes):
            return False
        n=max(1,math.ceil(math.dist(a,b)/(.5*STEP)))
        return all(clear(a[0]+(b[0]-a[0])*i/n,a[1]+(b[1]-a[1])*i/n) for i in range(n+1))
    key=lambda p:(round(p[0]/STEP),round(p[1]/STEP))
    point=lambda p:(p[0]*STEP,p[1]*STEP)
    first,last=key(start),key(end)
    if not segment(start,point(first)) or not segment(point(last),end): return []
    todo=[(0,0,first)]; costs={first:0}; parents={}
    while todo:
        _,cost,at=heapq.heappop(todo)
        if cost != costs[at]: continue
        if at==last:
            chain=[at]
            while at in parents: at=parents[at];chain.append(at)
            points=[start]+[point(p) for p in reversed(chain)]+[end]
            # Pull taut only across sampled, pipe-clear floor. This removes
            # tiny grid-entry reversals that cannot accommodate cast elbows.
            if not smooth:
                reduced=[points[0]]
                for i,p in enumerate(points[1:-1],1):
                    a=reduced[-1];b=points[i+1]
                    cross=(p[0]-a[0])*(b[1]-p[1])-(p[1]-a[1])*(b[0]-p[0])
                    dot=(p[0]-a[0])*(b[0]-p[0])+(p[1]-a[1])*(b[1]-p[1])
                    if abs(cross)>1e-8 or dot<0: reduced.append(p)
                reduced.append(end)
                return [list(p) for i,p in enumerate(reduced) if i==0 or math.dist(p,reduced[i-1])>1e-8]
            reduced=[points[0]];cursor=0
            while cursor<len(points)-1:
                nxt=len(points)-1
                while nxt>cursor+1 and not segment(points[cursor],points[nxt]): nxt-=1
                reduced.append(points[nxt]);cursor=nxt
            return [list(p) for i,p in enumerate(reduced) if i==0 or math.dist(p,reduced[i-1])>1e-8]
        for dx,dz in [(1,0),(-1,0),(0,1),(0,-1)]:
            nxt=(at[0]+dx,at[1]+dz)
            if cost+1>=costs.get(nxt,math.inf) or not segment(point(at),point(nxt)): continue
            parents[nxt]=at;costs[nxt]=cost+1
            heapq.heappush(todo,(cost+1+abs(nxt[0]-last[0])+abs(nxt[1]-last[1]),cost+1,nxt))
    return []


def _plan_ordered(layout, heating, smooth=True, reserved=()):
    anchors={a['id']:a for a in layout['anchors']}
    levels={r['id']:r['y'] for r in layout['levels']}
    shaft=next(r for r in layout['risers'] if r['id']=='HEAT_STACK')['rect']
    cx,cz=(shaft[0]+shaft[2])*.5,(shaft[1]+shaft[3])*.5
    offsets={'H-A':[-.065,-.065],'H-B':[.065,-.065],'H-C':[-.065,.065],'H-D':[.065,.065]}
    results=[]; occupied={}
    for installed in heating['installed']:
        anchor=anchors[installed['id']];level=anchor['level'];x,_,z=anchor['position'];yaw=anchor.get('yaw',0)
        # RadiatorProp.RISER_X is the fixed floor stub; installation_drop=.75
        # cancels the standard .75m semantic mounting height.
        end=[x-.67*math.cos(yaw),z+.67*math.sin(yaw)]
        offset=offsets[installed['riser']];start=[cx+offset[0],cz+offset[1]]
        spaces=[s for s in layout['spaces'] if s['level']==level and not s.get('no_floor',False) and not s.get('open_shell',False)]
        ids={s['id'] for s in spaces};rects=[s['rect'] for s in spaces]+[shaft]
        rects += [p['rect'] for p in layout.get('platforms',[]) if p['level']==level]
        own_bores={installed['id']+'_'+space+'_SUPPLY_BORE' for space in ids}
        holes=[h['rect'] for h in layout['slab_openings'] if h.get('space') in ids and h.get('surface')=='Floor' and h.get('id') not in own_bores]
        for other,delta in offsets.items():
            if other!=installed['riser']:
                ox,oz=cx+delta[0],cz+delta[1]
                holes.append([ox-.04,oz-.04,ox+.04,oz+.04])
        peers=[b for b in reserved if b['level']==level and b['id']!=installed['id']]
        pipes=occupied.get(level,[]) + [(a[::2],b[::2]) for peer in peers
            for a,b in zip(peer['points_local_godot'],peer['points_local_godot'][1:])
            if math.dist(a[::2],b[::2])>1e-8]
        path=route(start,end,rects,holes,pipes=pipes,smooth=smooth)
        length=sum(math.dist(a,b) for a,b in zip(path,path[1:]))
        distance=0.;points=[]
        for i,p in enumerate(path):
            if i: distance+=math.dist(path[i-1],p)
            points.append([p[0],levels[level]-.13+.06*distance/max(length,.001),p[1]])
        if points: points.append([end[0],levels[level],end[1]])
        for a,b in zip(path,path[1:]):
            occupied.setdefault(level,[]).append((a,b))
        results.append({'id':installed['id'],'riser':installed['riser'],'level':level,
            'status':'CANDIDATE' if points else 'NO_FLOOR_ROUTE','points_local_godot':points,'horizontal_length_m':length})
    return {'evidence_class':'INERT','status':'FABRICATION_DESIGN_PENDING',
        'scope':'Floor-envelope routing and pairwise 32mm-radius branch centerline clearance with 8mm separation. Does not prove self-clearance, fitting envelopes, joists, sleeves, steam performance, native construction or runtime acceptance.',
        'branches':results, 'branch_clearance_conflicts':branch_conflicts(results)}


def plan(layout, heating):
    # A greedy first branch can divide a narrow floor band. Try the small
    # per-floor roster in different orders instead of crossing an occupied pipe.
    anchors={a['id']:a for a in layout['anchors']}
    groups={}
    for row in heating['installed']:
        groups.setdefault(anchors[row['id']]['level'],[]).append(row)
    if not groups: raise ValueError('No installed heating emitters to route')
    branches=[];orders={}
    for level,rows in sorted(groups.items()):
        best=None;best_failures=math.inf
        for order in itertools.permutations(rows):
            candidate=_plan_ordered(layout,{'installed':order},smooth=False)
            failures=sum(b['status']!='CANDIDATE' for b in candidate['branches'])
            if failures<best_failures:
                best,best_failures=candidate,failures
                orders[level]=[r['id'] for r in order]
            if failures==0: break
        branches.extend(best['branches'])
    # Reserve the complete floor layout before pulling any one route taut.
    # This prevents an early diagonal from cutting off a later radiator.
    installed={row['id']:row for row in heating['installed']}
    for i,branch in enumerate(branches):
        if not branch['points_local_godot']: continue
        candidate=_plan_ordered(layout,{'installed':[installed[branch['id']]]},reserved=branches)
        replacement=candidate['branches'][0]
        if replacement['points_local_godot']:
            branches[i]=replacement
    fitting_errors=[]
    for branch in branches:
        try: fitted_stations(branch['points_local_godot'])
        except ValueError as error:
            fitting_errors.append({'id':branch['id'],'reason':str(error)})
    return dict(best,branches=branches,routing_order=orders,
                fitting_errors=fitting_errors,
                branch_clearance_conflicts=branch_conflicts(branches))


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--out',type=Path,required=True);args=parser.parse_args()
    read=lambda p:json.loads((ROOT/p).read_text())
    data=plan(read('game/data/orison_v2_blockout.json'),read('game/data/orison_v2/heating.json'))
    args.out.parent.mkdir(parents=True,exist_ok=True);args.out.write_text(json.dumps(data,indent=2)+'\n')
    print(json.dumps({'routed':sum(r['status']=='CANDIDATE' for r in data['branches']),
                      'unrouted':[r['id'] for r in data['branches'] if r['status']!='CANDIDATE'],
                      'branch_clearance_conflicts':len(data['branch_clearance_conflicts']),
                      'fitting_errors':data['fitting_errors']}))
