"""Design a socketed lobby takeoff without duplicating the F01 H-A port.

Produces an INERT candidate only. The parent is split at a real fitting;
native bores, supports, room fit and runtime still require verification.
"""
import argparse
import hashlib
import json
import math
from pathlib import Path

from heating_pipe_fittings import fitted_stations
from check_v2_heating_envelopes import floor_domain, floor_clearance

ROOT = Path(__file__).resolve().parents[1]


def plan(layout, routes, join_x=-4.7):
    parent = next(b for b in routes['branches'] if b['id']=='F01_A_RADIATOR_01')
    points = parent['points_local_godot']
    if not math.isfinite(join_x) or any(len(p)!=3 or not all(math.isfinite(v) for v in p) for p in points):
        raise ValueError('Finite three-axis parent coordinates required')
    # The takeoff belongs in the retained lobby floor, away from the west
    # bearing wall and the apartment threshold. Pick its actual source run.
    segment = next((i for i,(a,b) in enumerate(zip(points,points[1:]))
                    if min(a[0],b[0]) < join_x < max(a[0],b[0])
                    and abs(a[0]-b[0])>1), None)
    if segment is None:
        raise ValueError('Takeoff is outside the parent straight')
    a,b = points[segment:segment+2]
    t = (join_x-a[0])/(b[0]-a[0])
    join = [x+t*(y-x) for x,y in zip(a,b)]
    direction = [(y-x)/math.dist(a,b) for x,y in zip(a,b)]
    floor = next(r['y'] for r in layout['levels'] if r['id']=='F01')
    if not math.isfinite(floor):raise ValueError('Finite floor elevation required')
    proposal = {'id':'F01_LOBBY_RADIATOR_01','level':'F01','space':'F01_LOBBY',
                'position':[-5.2,.75,-6.5],'yaw':-math.pi/2,'kind':'interaction'}
    anchor=next((dict(a) for a in layout['anchors'] if a['id']==proposal['id']),proposal)
    if (anchor['level']!='F01' or anchor['space']!='F01_LOBBY' or
            abs(anchor.get('yaw',0)+math.pi/2)>1e-8 or abs(anchor['position'][1]-.75)>1e-8):
        raise ValueError('Lobby anchor requires a fresh fitting design')
    if not all(math.isfinite(v) for v in anchor['position']):raise ValueError('Finite anchor coordinates required')
    end = [anchor['position'][0]-.67*math.cos(anchor['yaw']),floor-.07,
           anchor['position'][2]+.67*math.sin(anchor['yaw'])]
    delta = [y-x for x,y in zip(join,end)]
    along = sum(x*y for x,y in zip(delta,direction))
    normal = [x-along*y for x,y in zip(delta,direction)]
    length = math.sqrt(sum(x*x for x in normal))
    if length<.15 or along<.15:
        raise ValueError('Takeoff has insufficient straight for sockets and bend')
    outlet = [x/length for x in normal]
    if direction[1]<=0 or outlet[1]<=0:
        raise ValueError('Condensate must fall toward the original supply')
    elbow = [x+y for x,y in zip(join,normal)]
    cut_minus = [x-.045*y for x,y in zip(join,direction)]
    cut_plus = [x+.045*y for x,y in zip(join,direction)]
    child_start = [x+.06*y for x,y in zip(join,outlet)]
    child = {'id':anchor['id'],'riser':'H-A','level':'F01',
             'parent_branch':parent['id'],'status':'CANDIDATE',
             'points_local_godot':[child_start,elbow,end,[end[0],floor,end[2]]]}
    fitted_stations(child['points_local_godot'])
    rects,holes = floor_domain(layout,child)
    clearance = floor_clearance([p[::2] for p in child['points_local_godot']],rects,holes)
    if clearance<.035:
        raise ValueError('Takeoff leaves its floor envelope')
    for original,cut in [(a,cut_minus),(b,cut_plus)]:
        if math.dist(original,cut)<.12:
            raise ValueError('Takeoff socket reaches an existing bend')
    return {'evidence_class':'INERT','status':'NATIVE_REVIEW_PENDING',
            'scope':'Source-derived socket design only; not installed or accepted.',
            'anchor_candidate':anchor,'parent_branch':parent['id'],
            'parent_segment':segment,'join_local_godot':join,
            'main_axis_local_godot':direction,'outlet_axis_local_godot':outlet,
            'parent_before':points[:segment+1]+[cut_minus],
            'parent_after':[cut_plus]+points[segment+1:],
            'child':child,'floor_clearance_m':clearance,
            'socket':{'outer_radius_m':.035,'branch_outer_radius_m':.034,
                      'flow_radius_m':.024,'main_flow_relief_m':.0002,
                      'pipe_outer_radius_m':.029,'receiving_radius_m':.0291,
                      'main_half_length_m':.07,'parent_cut_offset_m':.045,
                      'branch_length_m':.09,'branch_insert_start_m':.06}}


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--out',type=Path,required=True)
    args=parser.parse_args()
    sources=[ROOT/'game/data/orison_v2_blockout.json',
             ROOT/'art/blender/heating_distribution/heating_routes_exact.json',Path(__file__),
             ROOT/'tools/heating_pipe_fittings.py',ROOT/'tools/check_v2_heating_envelopes.py',
             ROOT/'tools/plan_v2_heating_distribution.py']
    result=plan(*[json.loads(p.read_text()) for p in sources[:2]])
    baseline=ROOT/'art/blender/heating_distribution/base18.blend'
    result['baseline_native']=baseline.relative_to(ROOT).as_posix()
    result['baseline_native_sha256']=hashlib.sha256(baseline.read_bytes()).hexdigest()
    sources.append(ROOT/'art/blender/heating_distribution/base18_mesh_inspection.json')
    result['source_sha256_lf']={p.relative_to(ROOT).as_posix():hashlib.sha256(
        p.read_bytes().replace(b'\r\n',b'\n')).hexdigest() for p in sources}
    args.out.parent.mkdir(parents=True,exist_ok=True)
    args.out.write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps({'status':result['status'],'clearance_m':result['floor_clearance_m'],
                      'join':result['join_local_godot']}))
