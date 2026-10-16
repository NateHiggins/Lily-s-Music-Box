"""Draft explicit radiator floor sleeves and main-shaft bores from fitted routes.

Does not modify the production layout or claim underfloor channel acceptance.
"""
import argparse
import hashlib
import json
import math
from pathlib import Path
from heating_pipe_fittings import fitted_stations

ROOT=Path(__file__).resolve().parents[1]


def clip_segment(a,b,bounds):
    low,high=0.,1.
    for axis in range(3):
        delta=b[axis]-a[axis]
        if abs(delta)<1e-12:
            if not bounds[axis]<=a[axis]<=bounds[axis+3]:return None
            continue
        enter,leave=sorted(((bounds[axis]-a[axis])/delta,(bounds[axis+3]-a[axis])/delta))
        low,high=max(low,enter),min(high,leave)
        if low>high:return None
    return [[x+(y-x)*t for x,y in zip(a,b)] for t in (low,high)]


def subtract_box(box,cut):
    lo=[max(box[i],cut[i]) for i in range(3)]
    hi=[min(box[i+3],cut[i+3]) for i in range(3)]
    if any(lo[i]>=hi[i] for i in range(3)):return [box]
    core=list(box);pieces=[]
    for axis in range(3):
        if core[axis]<lo[axis]:
            piece=list(core);piece[axis+3]=lo[axis];pieces.append(piece);core[axis]=lo[axis]
        if core[axis+3]>hi[axis]:
            piece=list(core);piece[axis]=hi[axis];pieces.append(piece);core[axis+3]=hi[axis]
    return pieces


def branch_ports(layout,routes):
    shaft=next(r for r in layout['risers'] if r['id']=='HEAT_STACK')
    x,z,xx,zz=shaft['rect'];radius=.04
    expanded=[x-radius,shaft['from_y']-radius,z-radius,xx+radius,shaft['to_y']+radius,zz+radius]
    result=[]
    for branch in routes['branches']:
        points=[p for p,_ in fitted_stations(branch['points_local_godot'])]
        groups=[];current=[]
        for a,b in zip(points,points[1:]):
            clipped=clip_segment(a,b,expanded)
            if clipped:
                current.extend(clipped)
            elif current:
                groups.append(current);current=[]
        if current:groups.append(current)
        for index,group in enumerate(groups):
            bounds=[min(p[i] for p in group)-radius for i in range(3)]
            bounds += [max(p[i] for p in group)+radius for i in range(3)]
            owner=[x,shaft['from_y'],z,xx,shaft['to_y'],zz]
            bounds=[max(bounds[i],owner[i]) for i in range(3)]+[min(bounds[i+3],owner[i+3]) for i in range(3)]
            result.append({'id':branch['id']+'_SHAFT_EXIT_%02d'%index,
                           'riser':'HEAT_STACK','bounds':bounds})
    return result


def build(layout,routes):
    openings=[]
    sleeves=[]
    for branch in routes['branches']:
        if not branch['points_local_godot']:
            raise ValueError('Missing route: '+branch['id'])
        x,y,z=branch['points_local_godot'][-1]
        half=.034
        rect=[x-half,z-half,x+half,z+half]
        owners=[]
        for space in layout['spaces']:
            if space['level']!=branch['level'] or space.get('no_floor'):continue
            a,b,c,d=space['rect']
            if rect[2]>a and rect[0]<c and rect[3]>b and rect[1]<d:
                if not (a<=rect[0] and b<=rect[1] and c>=rect[2] and d>=rect[3]):
                    raise ValueError('Sleeve crosses a room edge: '+branch['id'])
                owners.append(space['id'])
        for platform in layout.get('platforms',[]):
            if platform['level']!=branch['level']:continue
            a,b,c,d=platform['rect']
            if rect[2]>a and rect[0]<c and rect[3]>b and rect[1]<d:
                raise ValueError('Platform penetration needs a supported platform cut: '+branch['id'])
        if not owners:raise ValueError('No floor owner: '+branch['id'])
        for owner in owners:
            openings.append({'id':branch['id']+'_'+owner+'_SUPPLY_BORE',
                             'space':owner,'surface':'Floor','rect':rect})
        sleeves.append({'id':branch['id']+'_FLOOR_SLEEVE','branch':branch['id'],
                        'level':branch['level'],'center':[x,y,z],
                        'plate_outer_radius_m':.052,'bore_radius_m':.031,
                        'plate_bottom_m':0.,'plate_top_m':.004,
                        'neck_outer_radius_m':.033,'neck_bottom_m':-.025,'neck_top_m':0.})
    mains=[]
    supports=[]
    for name in sorted({b['riser'] for b in routes['branches']}):
        rows=[b for b in routes['branches'] if b['riser']==name]
        x,_,z=rows[0]['points_local_godot'][0]
        if any(abs(b['points_local_godot'][0][0]-x)>1e-8 or abs(b['points_local_godot'][0][2]-z)>1e-8 for b in rows):
            raise ValueError('Nonvertical main: '+name)
        top=max(b['points_local_godot'][0][1] for b in rows)+.15
        mains.append({'id':'HEAT_'+name+'_MAIN_CLEAR','riser':'HEAT_STACK',
                      'bounds':[x-.04,-.45,z-.04,x+.04,top+.04,z+.04]})
        # Bands bear on the bore wall through two embedded steel lugs. Keep
        # them away from branch ports and the blind cap; never bridge a lumen.
        for index in range(math.ceil((top+.45)/1.5)):
            y=-.15+index*1.5
            if y>top-.10:continue
            if any(abs(y-b['points_local_godot'][0][1])<.12 for b in routes['branches']):y+=.25
            if y>top-.10:continue
            supports.append({'id':'HEAT_'+name+'_SUPPORT_%02d'%index,
                             'riser':name,'center':[x,y,z],
                             'outer_radius_m':.038,'inner_radius_m':.029,
                             'height_m':.024,'lug_reach_m':.065,
                             'lug_half_depth_m':.012,'lug_half_height_m':.008})
    cuts=mains+branch_ports(layout,routes)
    shaft=next(r for r in layout['risers'] if r['id']=='HEAT_STACK')
    x,z,xx,zz=shaft['rect']
    pieces=[[x,shaft['from_y'],z,xx,shaft['to_y'],zz]]
    for opening in list(layout.get('riser_openings',[]))+cuts:
        if opening['riser']=='HEAT_STACK':
            pieces=[part for box in pieces for part in subtract_box(box,opening['bounds'])]
    for support in supports:
        x,y,z=support['center'];reach=support['lug_reach_m']
        # Both lug tips must be anchored in retained shaft stock, rather than
        # in a branch opening or outside the shaft.
        for sign in [-1,1]:
            for dy in [-support['lug_half_height_m'],support['lug_half_height_m']]:
                for dz in [-support['lug_half_depth_m'],support['lug_half_depth_m']]:
                    point=[x+sign*reach,y+dy,z+dz]
                    if not any(all(box[i]<=point[i]<=box[i+3] for i in range(3)) for box in pieces):
                        raise ValueError('Main support has no retained shaft bearing: '+support['id'])
    return {'evidence_class':'INERT','status':'INTERFACE_CANDIDATE_NOT_INSTALLED',
            'scope':'Floor entry sleeves, vertical main bores and branch shaft openings. Underfloor channels, supports, ceiling ownership and runtime acceptance remain open.',
            'slab_openings':openings,'riser_openings':cuts,'floor_sleeves':sleeves,
            'main_supports':supports,
            'shaft_review_pieces':pieces}


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--routes',type=Path,required=True)
    parser.add_argument('--out',type=Path,required=True)
    args=parser.parse_args()
    source=ROOT/'game/data/orison_v2_blockout.json'
    result=build(json.loads(source.read_text()),json.loads(args.routes.read_text()))
    result['source_sha256']={str(p.resolve()):hashlib.sha256(p.read_bytes().replace(b'\r\n',b'\n')).hexdigest()
                             for p in (source,args.routes,Path(__file__))}
    args.out.parent.mkdir(parents=True,exist_ok=True)
    args.out.write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps({key:len(result[key]) for key in ('slab_openings','riser_openings','floor_sleeves')}))
