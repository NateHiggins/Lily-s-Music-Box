"""Check candidate fitted pipe envelopes; not installation or runtime proof."""
import argparse
import hashlib
import json
import math
from pathlib import Path

from heating_pipe_fittings import fitted_stations, floor_boundary
from plan_v2_heating_distribution import segment_distance

ROOT = Path(__file__).resolve().parents[1]


def floor_clearance(points, rectangles, holes):
    inside, boundary = floor_boundary(rectangles, holes)
    if not points or not all(inside(*p) for p in points):
        return 0.
    return min(segment_distance(a,b,c,d) for a,b in zip(points,points[1:])
               for c,d in boundary)


def floor_domain(layout, branch):
    shaft = next(r['rect'] for r in layout['risers'] if r['id']=='HEAT_STACK')
    cx, cz = (shaft[0]+shaft[2])/2, (shaft[1]+shaft[3])/2
    offsets = {'H-A':(-.065,-.065),'H-B':(.065,-.065),
               'H-C':(-.065,.065),'H-D':(.065,.065)}
    spaces = [s for s in layout['spaces'] if s['level']==branch['level']
              and not s.get('no_floor') and not s.get('open_shell')]
    ids = {s['id'] for s in spaces}
    rects = [s['rect'] for s in spaces]+[shaft]
    rects += [p['rect'] for p in layout.get('platforms',[]) if p['level']==branch['level']]
    own_bores={branch['id']+'_'+space+'_SUPPLY_BORE' for space in ids}
    holes = [h['rect'] for h in layout['slab_openings']
             if h.get('space') in ids and h.get('surface')=='Floor' and h.get('id') not in own_bores]
    for name,(dx,dz) in offsets.items():
        if name != branch['riser']:
            holes.append([cx+dx-.04,cz+dz-.04,cx+dx+.04,cz+dz+.04])
    return rects,holes


def check(layout, routes):
    # Conservative deviation bound for any <180-degree elbow sampled 12 times.
    error = .04*(1-math.cos(math.pi/24))
    radius = .029 + error
    fitted = []
    failures = []
    floors = []
    for branch in routes['branches']:
        try:
            points = [p for p,_ in fitted_stations(branch['points_local_godot'])]
        except ValueError as exc:
            failures.append({'id':branch['id'],'kind':'fit','reason':str(exc)})
            continue
        fitted.append((branch,points))
        rects,holes = floor_domain(layout,branch)
        distance = floor_clearance([p[::2] for p in points],rects,holes)
        floors.append({'id':branch['id'],'clearance_m':distance})
        if distance < radius:
            failures.append({'id':branch['id'],'kind':'floor_envelope','clearance_m':distance})
    minimum = None
    for i,(left,lp) in enumerate(fitted):
        for right,rp in fitted[i+1:]:
            if left['level'] != right['level']:
                continue
            distance = min(segment_distance(a,b,c,d) for a,b in zip(lp,lp[1:])
                           for c,d in zip(rp,rp[1:]))
            minimum = distance if minimum is None else min(minimum,distance)
            if distance < 2*radius+.008:
                failures.append({'id':left['id'],'other':right['id'],
                                 'kind':'pipe_envelope','clearance_m':distance})
    return {'evidence_class':'INERT','scope':'Candidate curved branch floor and peer-pipe envelopes only. Excludes self-intersection, fittings, supports, joists, penetrations and runtime acceptance.',
            'branches_checked':len(fitted),'radius_with_curve_error_m':radius,
            'minimum_peer_centerline_m':minimum,'floor_clearances':floors,'failures':failures}


def check_couplings(layout, routes, native):
    branches = {b['id']:b for b in routes['branches']}
    curves = {key:[p for p,_ in fitted_stations(b['points_local_godot'])]
              for key,b in branches.items()}
    failures = []
    stocks = []
    for row in native['couplings']:
        owner = row['id'].split('__')[0]
        if owner not in branches:
            raise ValueError('Unknown coupling owner: '+owner)
        # Native Blender axes: x, -Godot z, Godot y.
        a,b = [[p[0],p[2],-p[1]] for p in (row['start_blender'],row['end_blender'])]
        radius = row['outer_radius_m']
        rects,holes = floor_domain(layout,branches[owner])
        distance = floor_clearance([a[::2],b[::2]],rects,holes)
        if distance < radius:
            failures.append({'id':row['id'],'kind':'coupling_floor','clearance_m':distance})
        for peer,points in curves.items():
            if peer==owner or branches[peer]['level']!=branches[owner]['level']:
                continue
            distance = min(segment_distance(a,b,c,d) for c,d in zip(points,points[1:]))
            if distance < radius+.029342206+.008:
                failures.append({'id':row['id'],'other':peer,'kind':'coupling_pipe','clearance_m':distance})
        stocks.append((row,owner,a,b,radius))
    for i,(left,owner,a,b,radius) in enumerate(stocks):
        for right,peer,c,d,other_radius in stocks[i+1:]:
            if branches[owner]['level']!=branches[peer]['level']:
                continue
            distance = cylinder_separation(a,b,radius,c,d,other_radius)
            if distance < .008-1e-8:
                failures.append({'id':left['id'],'other':right['id'],'kind':'coupling_pair','clearance_m':distance})
    return {'checked':len(stocks),'failures':failures,
            'scope':'Capsules against floors and pipes; certified separating planes between finite coupling cylinders. Excludes intentional coupling contact with its own pipe.'}


def cylinder_separation(a,b,r,c,d,s):
    """Lower bound on finite-cylinder separation from exact support planes.

    A positive result certifies a gap. A negative result is inconclusive,
    not proof of intersection; the caller must retain it for further review.
    """
    dot=lambda u,v:sum(x*y for x,y in zip(u,v))
    sub=lambda u,v:[x-y for x,y in zip(u,v)]
    cross=lambda u,v:[u[1]*v[2]-u[2]*v[1],u[2]*v[0]-u[0]*v[2],u[0]*v[1]-u[1]*v[0]]
    u,v=sub(b,a),sub(d,c)
    lu,lv=math.sqrt(dot(u,u)),math.sqrt(dot(v,v))
    if min(lu,lv)<=0:raise ValueError('Zero-length coupling')
    u,v=[x/lu for x in u],[x/lv for x in v]
    delta=[(x+y-z-w)/2 for x,y,z,w in zip(c,d,a,b)]
    axes=[delta,u,v,cross(u,v)]
    axes += [[x-dot(delta,n)*y for x,y in zip(delta,n)] for n in (u,v)]
    result=-math.inf
    for n in axes:
        length=math.sqrt(dot(n,n))
        if length<1e-10:continue
        n=[x/length for x in n]
        du,dv=min(1,abs(dot(n,u))),min(1,abs(dot(n,v)))
        support=lu*.5*du+r*math.sqrt(max(0,1-du*du))+lv*.5*dv+s*math.sqrt(max(0,1-dv*dv))
        result=max(result,abs(dot(delta,n))-support)
    return result


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--routes',type=Path,required=True)
    parser.add_argument('--out',type=Path,required=True)
    parser.add_argument('--native-review',type=Path)
    args = parser.parse_args()
    result = check(json.loads((ROOT/'game/data/orison_v2_blockout.json').read_text()),
                   json.loads(args.routes.read_text()))
    if args.native_review:
        native=json.loads(args.native_review.read_text())
        route_hash=hashlib.sha256(args.routes.read_bytes().replace(b'\r\n',b'\n')).hexdigest()
        if native['routes_sha256'] != route_hash:
            raise ValueError('Native coupling review uses different routes')
        result['couplings']=check_couplings(
            json.loads((ROOT/'game/data/orison_v2_blockout.json').read_text()),
            json.loads(args.routes.read_text()),native)
        result['failures'].extend(result['couplings']['failures'])
    result['source_sha256'] = {
        str(path.resolve()):hashlib.sha256(path.read_bytes().replace(b'\r\n',b'\n')).hexdigest()
        for path in [args.routes,ROOT/'game/data/orison_v2_blockout.json',
                     Path(__file__),ROOT/'tools/heating_pipe_fittings.py',
                     ROOT/'tools/plan_v2_heating_distribution.py']}
    if args.native_review:
        result['source_sha256'][str(args.native_review.resolve())]=hashlib.sha256(
            args.native_review.read_bytes().replace(b'\r\n',b'\n')).hexdigest()
    args.out.parent.mkdir(parents=True,exist_ok=True)
    args.out.write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps(result))
    raise SystemExit(bool(result['failures']))
