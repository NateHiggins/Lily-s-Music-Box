"""Place underfloor pipe hangers against authored floor coverage, candidate only."""
import argparse
import json
import math
from pathlib import Path
from heating_pipe_fittings import fitted_stations, floor_boundary
from check_v2_heating_envelopes import floor_domain
from plan_v2_heating_distribution import segment_distance

ROOT=Path(__file__).resolve().parents[1]


def build(layout,routes):
    supports=[];unserved=[]
    curves={b['id']:fitted_stations(b['points_local_godot']) for b in routes['branches']}
    for branch in routes['branches']:
        floor_y=branch['points_local_godot'][-1][1]
        inside,boundary=floor_boundary(*floor_domain(layout,branch))
        count=0
        for index,((a,ta),(b,tb)) in enumerate(zip(curves[branch['id']],curves[branch['id']][1:])):
            length=math.dist(a,b)
            if length<.4 or sum(x*y for x,y in zip(ta,tb))<.999999 or abs(ta[1])>.1:continue
            placed=0
            for k in range(max(1,math.ceil(length/1.2))):
                t=(k+.5)/max(1,math.ceil(length/1.2))
                at=[x+(y-x)*t for x,y in zip(a,b)]
                end=[at[0],floor_y-.008,at[2]]
                if end[1]-at[1]<.04:continue
                p=[at[0],at[2]]
                if not inside(*p) or min(segment_distance(p,p,c,d) for c,d in boundary)<.036:continue
                blocked=False
                for peer in routes['branches']:
                    if peer['id']==branch['id'] or peer['level']!=branch['level']:continue
                    for (c,_),(d,_) in zip(curves[peer['id']],curves[peer['id']][1:]):
                        if segment_distance(at,end,c,d)<.065:blocked=True;break
                    if blocked:break
                if blocked:continue
                owners=[s['id'] for s in layout['spaces']+layout.get('platforms',[]) if s['level']==branch['level']
                        and not s.get('no_floor') and not s.get('open_shell')
                        and s['rect'][0]<=at[0]<=s['rect'][2] and s['rect'][1]<=at[2]<=s['rect'][3]]
                if not owners:continue
                supports.append({'id':branch['id']+'_HANGER_%03d'%count,'branch':branch['id'],
                                 'level':branch['level'],'floor_owners':owners,'center':at,
                                 'tangent':ta,'floor_y':floor_y,'outer_radius_m':.034,
                                 'inner_radius_m':.029,'band_length_m':.018,
                                 'stem_top_y':floor_y-.008,'stem_bottom_y':at[1]+.032})
                count+=1;placed+=1
            if not placed:unserved.append({'branch':branch['id'],'segment':index,'length_m':length})
    return {'evidence_class':'INERT','scope':'Candidate hangers within floor envelope; floor substrate and installed assembly still require visual review.',
            'supports':supports,'unserved_straights':unserved}


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--routes',type=Path,required=True)
    parser.add_argument('--out',type=Path,required=True)
    args=parser.parse_args()
    result=build(json.loads((ROOT/'game/data/orison_v2_blockout.json').read_text()),json.loads(args.routes.read_text()))
    args.out.parent.mkdir(parents=True,exist_ok=True)
    args.out.write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps({'supports':len(result['supports']),'unserved_straights':result['unserved_straights']}))
