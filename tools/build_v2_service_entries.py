"""Project the missing service-door approach, outside retained flight/shaft stock."""
import argparse
import copy
import json
import math
from pathlib import Path

from build_v2_roof import render, upsert_records

ROOT=Path(__file__).resolve().parents[1]
SOURCE=ROOT/'art/data/orison_v2/service_entry_source.json'
TARGET=ROOT/'game/data/orison_v2_blockout.json'


def project(layout,source,heating=None):
    if heating is None:heating=json.loads((ROOT/'art/data/orison_v2/heating_refit_authoring.json').read_text(encoding='utf-8'))
    if set(source)!={'schema_version','repairs','bypasses','ports'} or source['schema_version']!=1 or len(source['repairs'])!=1:
        raise ValueError('One explicit service-entry repair required')
    row=source['repairs'][0]
    if set(row)!={'id','level','door','stair','rect','reason'} or row['id']!='F01_SERVICE_ENTRY_PLATFORM' or row['level']!='F01' or not isinstance(row['reason'],str) or not row['reason'].strip():
        raise ValueError('Bounded ground service-entry repair required')
    if row['door']!='F01_SERVICE_CORE_DOOR' or row['stair']!='SERVICE_F01_F02':
        raise ValueError('Retained ground door and stair owners required')
    door=next(r for r in layout['doors'] if r['id']==row['door'])
    stair=next(r for r in layout['stairs'] if r['id']==row['stair'])
    landing=next(r for r in layout['platforms'] if r['id']=='F01_SERVICE_LANDING')
    if door['level']!='F01' or door['hinge']!='right' or abs(door['yaw']-math.pi/2)>1e-6 or stair['from']!='F01':
        raise ValueError('Repair requires the actual retained door handing and stair frame')
    # .33 m capsule + .10 m hand clearance beyond the closed latch endpoint;
    # another full capsule radius must remain supported behind that stance.
    north=math.ceil((door['center'][1]+door['width']/2+.33+.10+.33)/.05-1e-9)*.05
    expected=[landing['rect'][0],landing['rect'][3],stair['origin'][0],round(north,6)]
    rect=row['rect']
    if not isinstance(rect,list) or len(rect)!=4 or any(type(x) not in (int,float) or not math.isfinite(x) for x in rect) or any(abs(a-b)>1e-8 for a,b in zip(rect,expected)):
        raise ValueError('Repair must match the retained landing/flight edges and full latch-side capsule support')
    if stair['origin'][1]!=rect[1] or rect[2]-rect[0]<.66+.01:
        raise ValueError('Actual first-flight seam and standing capsule width required')
    for platform in layout['platforms']:
        if platform['level']!='F01' or platform['id']==row['id']:continue
        other=platform['rect']
        if min(rect[2],other[2])>max(rect[0],other[0]) and min(rect[3],other[3])>max(rect[1],other[1]):
            raise ValueError('Repair overlaps existing floor stock')
    for shaft in layout['risers']:
        if shaft.get('solid') is not False:continue
        other=shaft['rect']
        if min(rect[2],other[2])>max(rect[0],other[0]) and min(rect[3],other[3])>max(rect[1],other[1]):
            raise ValueError('Repair overlaps a shaft reservation')
    result=copy.deepcopy(layout)
    result['platforms']=upsert_records(result['platforms'],[{k:copy.deepcopy(row[k]) for k in ('id','level','rect')}|{'class':'core'}])
    bypass=source['bypasses']
    if set(bypass)!={'ground_room','ground_openings','upper_room','upper_openings'}:
        raise ValueError('Explicit ground transfer and upper hall bypass owners required')
    room=bypass['ground_room'];upper=bypass['upper_room']
    spaces={r['id']:r for r in layout['spaces']}
    reference=spaces['F03_SERVICE_HALL']['rect']
    if room.get('id')!='F01_SERVICE_RISER_BYPASS' or room.get('level')!='F01' or room.get('class')!='service' or room.get('rect')!=[reference[0],spaces['F01_CORE_TO_SERVICE']['rect'][3],spaces['F01_SERVICE_HALL']['rect'][0],2.0] or room.get('wall_sides')!=['west','north'] or not room.get('purpose','').strip():
        raise ValueError('Ground bypass must fit the existing transfer and hall behind the retained risers')
    r=room['rect']
    for other in layout['spaces']:
        if other['level']!='F01' or other['id']==room['id']:continue
        b=other['rect']
        if min(r[2],b[2])>max(r[0],b[0]) and min(r[3],b[3])>max(r[1],b[1]):
            raise ValueError('Ground bypass overlaps an existing room authority')
    if set(upper)!={'id','level','class','rect','purpose','wall_sides'} or upper['id']!='F02_SERVICE_RISER_BYPASS' or upper['level']!='F02' or upper['class']!='service' or upper['rect']!=[reference[0],-1.35,spaces['F02_SERVICE_HALL']['rect'][0],2.0] or upper['wall_sides']!=['west','south','north'] or not upper['purpose'].strip():
        raise ValueError('F02 bypass must fit behind the retained hall wall and risers')
    for other in layout['spaces']:
        if other['level']!='F02' or other['id']==upper['id']:continue
        b=other['rect'];r=upper['rect']
        if min(r[2],b[2])>max(r[0],b[0]) and min(r[3],b[3])>max(r[1],b[1]):
            raise ValueError('F02 bypass overlaps another room authority')
    result['spaces']=upsert_records(result['spaces'],[room,upper])
    openings=bypass['ground_openings']+bypass['upper_openings']
    if len(openings)!=4 or {o['id'] for o in openings}!={'F01_TRANSFER_BYPASS_OPENING','F01_BYPASS_HALL_OPENING','F02_BYPASS_HALL_SOUTH_OPENING','F02_BYPASS_HALL_NORTH_OPENING'}:
        raise ValueError('All four real bypass apertures required')
    from audit_orison_v2_completeness import V2Model
    model=V2Model(result)
    for opening in openings:
        owner=room if opening['id'].startswith('F01_') else upper
        if opening['level']!=owner['level'] or owner['id'] not in opening['connects'] or len(opening['connects'])!=2 or opening['height']!=2.4 or opening['width'] not in [1.0,1.05]:
            raise ValueError('Standing source apertures into the actual bypass required')
        other=next(i for i in opening['connects'] if i!=owner['id'])
        if other not in ['F01_CORE_TO_SERVICE','F01_SERVICE_HALL','F02_SERVICE_HALL'] or opening['shared_wall_owner']!=other:
            raise ValueError('Existing service wall must retain the new opening')
        boundary=model._shared_boundary(owner,model.spaces[other])
        if not boundary or opening['axis']!=boundary['axis']:
            raise ValueError('Opening must cross the actual shared source boundary')
        normal,along=(0,1) if boundary['axis']=='z' else (1,0)
        if opening['center'][normal]!=boundary['fixed'] or opening['center'][along]-opening['width']/2<boundary['start'] or opening['center'][along]+opening['width']/2>boundary['finish']:
            raise ValueError('Aperture must fit the shared boundary without corner overrun')
    result['openings']=upsert_records(result['openings'],openings)
    # The new outer north wall crosses an existing pitched branch. Derive
    # its inner and outer bores from that retained centreline, not a moved pipe.
    ports=source['ports']
    if len(ports)!=1 or ports[0]!={'id':'F02_SERVICE_BYPASS_HEAT','room':upper['id'],'side':'north','branch':'F03_C_RADIATOR_01','segment':1,'clearance_m':.041}:
        raise ValueError('Explicit retained heating branch and fitted wall port required')
    port=ports[0]
    route=next(r for r in heating['routes']['branches'] if r['id']==port['branch'])
    a,b=route['points_local_godot'][port['segment']:port['segment']+2]
    if abs(a[0]-b[0])>1e-8 or b[2]<=a[2] or abs(b[1]-a[1])/(b[2]-a[2])>.01:
        raise ValueError('Port requires the retained straight pitched pipe segment')
    half=layout['dimensions']['partition_wall']/2
    far=layout['dimensions']['outer_wall']-half
    z=upper['rect'][3]
    def bounds(lo,hi):
        if not a[2]<lo<hi<b[2]:raise ValueError('Pipe segment does not pass through the whole new wall')
        points=[[a[i]+(b[i]-a[i])*(v-a[2])/(b[2]-a[2]) for i in range(3)] for v in (lo,hi)]
        radius=port['clearance_m']
        return [min(p[0] for p in points)-radius,min(p[1] for p in points)-radius,lo,
                max(p[0] for p in points)+radius,max(p[1] for p in points)+radius,hi]
    inner={'id':port['id']+'_INNER_PORT','space':upper['id'],'side':'north','bounds':bounds(z-half,z+half)}
    outer={'id':port['id']+'_OUTER_PORT','owner':'ExteriorMasonry','bounds':bounds(z+half,z+far)}
    cut=inner['bounds'];floor=next(r['y'] for r in layout['levels'] if r['id']==upper['level'])
    if not (upper['rect'][0]<=cut[0]<cut[3]<=upper['rect'][2] and floor<=cut[1]<cut[4]<=floor+layout['dimensions']['clear_height']):
        raise ValueError('Retained pipe bore exceeds the new wall owner')
    result['wall_service_openings']=upsert_records(result['wall_service_openings'],[inner])
    result['masonry_service_openings']=upsert_records(result['masonry_service_openings'],[outer])
    return result


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check',action='store_true')
    args=parser.parse_args()
    text=TARGET.read_text(encoding='utf-8')
    before=json.loads(text)
    after=project(before,json.loads(SOURCE.read_text(encoding='utf-8')))
    if args.check:
        if before!=after:raise SystemExit('Service-entry projection is stale')
        print('Service-entry projection matches actual landing, flight and door owners')
    else:TARGET.write_bytes(render(text,after).replace('\n','\r\n').encode('utf-8'))


if __name__=='__main__':main()
