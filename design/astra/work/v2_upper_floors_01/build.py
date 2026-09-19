"""Append F05/F06 room programs and circulation without an engine launch."""
import argparse
import copy
import importlib.util
import json
import math
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[4]
OUT = Path(__file__).resolve().parent
BASE = '27f407b'
LAYOUT = 'game/data/orison_v2_blockout.json'
PROGRAM = 'game/data/orison_v2/upper_floor_programs.json'
PROBES = 'game/tests/data/v2_upper_floor_probes.json'
PEOPLE = {'5A':('nadia_quell','Nadia Quell','architectural drawing and correspondence'),
          '5B':('cal_dwyer','Cal Dwyer','radio listening and collecting'),
          '5C':('iris_bell','Iris Bell','painting and drying work'),
          '6A':('sacha_reed','Sacha Reed','photographic documentation and equipment'),
          '6B':('jonah_price','Jonah Price','writing and annotated notebooks'),
          '6C':('mae_kessler','Mae Kessler','antique appraisal and records')}
ROOMS = {
 'A': [('MAIN',[-15.65,-6.35,-8.3,-.6],'living and meals'),
       ('VESTIBULE',[-8.3,-3.85,-5.6,-.6],'private arrival and coat storage'),
       ('PRIVATE_HALL',[-8.3,-8.85,-5.6,-3.85],'bed and sanitary distribution'),
       ('BATH',[-8.3,-12.35,-5.6,-8.85],'private sanitary room'),
       ('BED',[-15.65,-12.35,-11.2,-6.35],'sleep and clothing'),
       ('KITCHEN',[-11.2,-9.35,-8.3,-6.35],'cooking and washing'),
       ('STUDY',[-11.2,-12.35,-8.3,-9.35],'resident work')],
 'B': [('MAIN',[-15.65,.6,-9.3,6.35],'living, meals and resident work'),
       ('VESTIBULE',[-9.3,.6,-6.5,3.1],'private arrival and coat storage'),
       ('BATH',[-9.3,3.1,-6.5,6.35],'private sanitary room'),
       ('ALCOVE',[-15.65,6.35,-11.2,11.65],'sleep and clothing'),
       ('PRIVATE_HALL',[-11.2,6.35,-9.3,11.65],'sleep and kitchen distribution'),
       ('KITCHEN',[-9.3,6.35,-6.5,11.65],'cooking and washing')],
 'C': [('VESTIBULE',[-2.2,3.85,.5,6.35],'private arrival and distribution'),
       ('MAIN',[-5.6,6.35,.5,11.65],'living and meals'),
       ('STUDIO',[-5.6,3.85,-2.2,6.35],'resident work'),
       ('PRIVATE_HALL',[.5,6.35,7.1,7.85],'private bed and service distribution'),
       ('BATH',[.5,3.85,3.8,6.35],'private sanitary room'),
       ('KITCHEN',[3.8,3.85,7.1,6.35],'cooking and washing'),
       ('BED1',[.5,7.85,3.8,11.65],'principal sleep and clothing'),
       ('BED2',[3.8,7.85,7.1,11.65],'second room; no additional resident assigned')]}
# room pair, centre, axis, width; None width means a 1.2m open passage.
LINKS = {
 'A': [('VESTIBULE','MAIN',[-8.3,-2.2],'z',None),
       ('MAIN','PRIVATE_HALL',[-8.3,-5.0],'z',None),
       ('MAIN','BED',[-13.4,-6.35],'x',.91),
       ('PRIVATE_HALL','BATH',[-6.95,-8.85],'x',.91),
       ('PRIVATE_HALL','KITCHEN',[-8.3,-7.5],'z',.91),
       ('KITCHEN','STUDY',[-9.7,-9.35],'x',.91)],
 'B': [('VESTIBULE','MAIN',[-9.3,1.85],'z',None),
       ('VESTIBULE','BATH',[-7.9,3.1],'x',.91),
       ('MAIN','PRIVATE_HALL',[-10.25,6.35],'x',None),
       ('PRIVATE_HALL','ALCOVE',[-11.2,8.8],'z',.91),
       ('PRIVATE_HALL','KITCHEN',[-9.3,8.8],'z',.91)],
 'C': [('VESTIBULE','MAIN',[-.85,6.35],'x',None),
       ('MAIN','STUDIO',[-4.0,6.35],'x',None),
       ('MAIN','PRIVATE_HALL',[.5,7.1],'z',None),
       ('PRIVATE_HALL','BATH',[2.1,6.35],'x',.91),
       ('PRIVATE_HALL','KITCHEN',[5.4,6.35],'x',.91),
       ('PRIVATE_HALL','BED1',[2.1,7.85],'x',.91),
       ('PRIVATE_HALL','BED2',[5.4,7.85],'x',.91)]}
WINDOWS = {'A':[('MAIN',[-15.65,-3.8],'z'),('BED',[-15.65,-10.1],'z'),
                 ('BED',[-13.4,-12.35],'x'),('STUDY',[-9.7,-12.35],'x'),('BATH',[-6.95,-12.35],'x')],
           'B':[('MAIN',[-15.65,3.7],'z'),('ALCOVE',[-15.65,8.8],'z'),('ALCOVE',[-13.4,11.65],'x'),('KITCHEN',[-7.9,11.65],'x')],
           'C':[('MAIN',[-3.0,11.65],'x'),('BED1',[2.1,11.65],'x'),('BED2',[5.4,11.65],'x')]}


def module(path,name):
    spec=importlib.util.spec_from_file_location(name,ROOT/path)
    value=importlib.util.module_from_spec(spec);spec.loader.exec_module(value)
    return value


def base():
    return json.loads(subprocess.check_output(['git','show',BASE+':'+LAYOUT],cwd=ROOT))


def owned_edges(layout,new_spaces):
    """Assign every shared boundary interval exactly once, cores first."""
    geo=module('design/astra/work/v2_apartment_walls_batch_01/build.py','upper_wall_source')
    claimed=[]
    for space in sorted(new_spaces,key=lambda s:(s['class']!='core',s['id'])):
        space['wall_sides']=[];space.pop('wall_extensions',None)
        for side in geo.SIDES:
            edge=geo.edge(space,side)
            remaining=geo.subtract(edge['start'],edge['end'],[(e['start'],e['end']) for e in claimed if geo.aligned(edge,e)])
            for start,end in remaining:
                if abs(start-edge['start'])<1e-6 and abs(end-edge['end'])<1e-6:
                    space['wall_sides'].append(side)
                else:
                    space.setdefault('wall_extensions',[]).append(dict(side=side,start=start,end=end))
                claimed.append(dict(edge,start=start,end=end))
    return claimed


def candidate():
    original=base();layout=copy.deepcopy(original);programs=[];specs={}
    common=['PUBLIC_CORE','SERVICE_CORE','SERVICE_HALL','EAST_HALL','SERVICE_CROSSING','SERVICE_HALL_SOUTH']
    portals=['SERVICE_HALL_CORE_OPENING','CORE_EAST_HALL_OPENING','EAST_CROSSING_OPENING','SERVICE_CROSSING_NORTH','SERVICE_CROSSING_SOUTH']
    def append(table,record): layout[table].append(record);return record
    def portal(level,identity,a,b,at,axis,width,unit,locked=False):
        if width is None:
            return append('openings',dict(id=identity,level=level,center=at,axis=axis,width=1.2,height=2.4,connects=[a,b]))
        door=append('doors',dict(id=identity,level=level,center=at,width=width,height=2.13,
                               yaw=0 if axis=='x' else math.pi/2,hinge='left',swing='authored room',connects=[a,b]))
        specs[identity]=dict(kind='apartment_entry' if '_DOOR_0' in identity else 'apartment_interior',
                             swing_out=False,unit=unit,leaf_state='locked' if locked else 'closed')
        return door
    for floor in [5,6]:
        level='F0'+str(floor);append('levels',dict(id=level,y=(floor-1)*3.2))
        ren=lambda r: json.loads(json.dumps(r).replace('F04',level))
        for suffix in common:
            r=ren(next(s for s in original['spaces'] if s['id']=='F04_'+suffix))
            r['purpose']={'PUBLIC_CORE':'passenger lift landing and primary stair',
                          'SERVICE_CORE':'service lift landing and service stair',
                          'SERVICE_HALL':'maintenance and delivery continuity beside the service core',
                          'SERVICE_HALL_SOUTH':'south maintenance continuity',
                          'SERVICE_CROSSING':'controlled public threshold across the service spine',
                          'EAST_HALL':'public approach to the restricted unit threshold'}.get(suffix,'upper floor circulation')
            if floor==6 and suffix.endswith('CORE'):r['no_ceiling']=False
            append('spaces',r)
        append('spaces',dict(id=level+'_WEST_HALL',level=level,rect=[-8.3,-.6,-2.2,.6],**{'class':'public'},purpose='public approach to '+str(floor)+'A and '+str(floor)+'B'))
        for suffix in portals:
            append('openings',ren(next(r for r in original['openings'] if r['id']=='F04_'+suffix)))
        portal(level,level+'_CORE_WEST_OPENING',level+'_PUBLIC_CORE',level+'_WEST_HALL',[-2.2,0],'z',None,'')
        for table in ['platforms','lift_landings']:
            for r in original[table]:
                if r.get('level')=='F04':append(table,ren(r))
        for kind in ['PRIMARY','SERVICE']:
            template=next(r for r in original['stairs'] if r['id']==kind+'_F03_F04')
            r=copy.deepcopy(template);r.update(id=kind+'_F0'+str(floor-1)+'_'+level,**{'from':'F0'+str(floor-1),'to':level})
            append('stairs',r)
            append('route_edges',dict(id='ROUTE_'+r['id'],**{'from':r['from']+('_PUBLIC_CORE' if kind=='PRIMARY' else '_SERVICE_CORE'),
                                                          'to':level+('_PUBLIC_CORE' if kind=='PRIMARY' else '_SERVICE_CORE'),'via':r['id']}))
        for letter in ['A','B','C']:
            unit=str(floor)+letter;prefix=level+'_'+letter+'_';person,name,work=PEOPLE[unit]
            room_ids=[]
            for suffix,rect,purpose in ROOMS[letter]:
                if 'resident work' in purpose:purpose=purpose.replace('resident work',work)
                record=dict(id=prefix+suffix,level=level,rect=rect,unit=unit,**{'class':'wet' if suffix=='BATH' else 'private'},purpose=name+': '+purpose)
                append('spaces',record);room_ids.append(record['id'])
            entry_id=level+'_DOOR_'+{'A':'02','B':'03','C':'06'}[letter]
            hall=level+('_PUBLIC_CORE' if letter=='C' else '_WEST_HALL')
            at={'A':[-7.1,-.6],'B':[-7.1,.6],'C':[-.85,3.85]}[letter]
            portal(level,entry_id,hall,prefix+'VESTIBULE',at,'x',.91,unit)
            for a,b,at,axis,width in LINKS[letter]:
                portal(level,prefix+a+'_'+b+('_OPENING' if width is None else '_DOOR'),prefix+a,prefix+b,at,axis,width,unit)
            for index,(room,at,axis) in enumerate(WINDOWS[letter]):
                append('windows',dict(id=prefix+'WINDOW_'+str(index+1),level=level,space=prefix+room,center=at,axis=axis,
                                      width=1.0 if room=='BATH' else 1.5,height=1.0 if room=='BATH' else 1.7,sill=1.5 if room=='BATH' else .8))
            programs.append(dict(unit=unit,resident=person,disposition='occupied',entry=entry_id,rooms=room_ids,
                                 stage='ROOM_PROGRAM_SOURCE',pending=['furnishings','water and heat','room lighting','resident migration','runtime and visual proof']))
        unit=str(floor)+'D';identity=level+'_D_RESTRICTED';entry_id=level+'_DOOR_05'
        purpose='vacant after fire damage; sealed threshold' if floor==5 else 'landlord storage; restricted threshold'
        append('spaces',dict(id=identity,level=level,unit=unit,rect=[9.5,-12.35,15.65,.3],**{'class':'service'},purpose=purpose))
        portal(level,entry_id,level+'_SERVICE_CROSSING',identity,[9.5,-3.25],'z',.91,unit,True)
        programs.append(dict(unit=unit,resident='',disposition='fire_damaged' if floor==5 else 'landlord_storage',
                             entry=entry_id,rooms=[identity],stage='RESTRICTED_THRESHOLD_SOURCE',pending=['threshold visual review','runtime lock proof']))
    additions=[r for r in layout['spaces'] if r['level'] in ['F05','F06']]
    owned_edges(layout,additions)
    # Windows retain the exterior finish on the exact side they pierce.
    indexed={r['id']:r for r in additions}
    for w in layout['windows']:
        if w['level'] not in ['F05','F06']:continue
        s=indexed[w['space']];r=s['rect']
        side=('south' if w['center'][1]==r[1] else 'north') if w['axis']=='x' else ('west' if w['center'][0]==r[0] else 'east')
        if side not in s.setdefault('exterior_sides',[]):s['exterior_sides'].append(side)
    door_geo=module('design/astra/work/v2_apartment_doors_batch_01/check.py','upper_swing_source')
    for door in layout['doors']:
        if door['id'] not in specs:continue
        target=indexed[door['connects'][1]]['rect']
        for outward in [False,True]:
            polygon=door_geo.leaf_polygon(door,outward,90)
            mid=[sum(p[i] for p in polygon)/4 for i in [0,1]]
            if target[0]<mid[0]<target[2] and target[1]<mid[1]<target[3]:
                specs[door['id']]['swing_out']=outward
                # Put the hinge on the reveal face, outside a 140mm wall.
                # A centre-plane hinge clips its own jamb beyond 95 degrees.
                specs[door['id']]['mount_offset']=.08 if outward else -.08
                specs[door['id']]['jamb_depth']=.22
                break
        else:raise AssertionError(('no inward leaf swing',door['id']))
    return layout,dict(schema_version=1,programs=programs,doors=specs)


def write_layout(layout):
    # Preserve original records and their authored formatting; append rows.
    text=subprocess.check_output(['git','show',BASE+':'+LAYOUT],cwd=ROOT).decode('utf-8')
    original=base()
    for table,rows in layout.items():
        if not isinstance(rows,list):continue
        old_ids={r['id'] for r in original[table]}
        added=[r for r in rows if r['id'] not in old_ids]
        if not added:continue
        start=text.index('[',text.index('"'+table+'"'));_,length=json.JSONDecoder().raw_decode(text[start:]);end=start+length-1
        text=text[:end].rstrip()+',\n'+',\n'.join('    '+json.dumps(r,separators=(',',':')) for r in added)+'\n  '+text[end:]
    assert json.loads(text)==layout
    return text.encode('utf-8')


def validate(layout,program):
    walls=module('design/astra/work/v2_apartment_walls_batch_01/build.py','upper_walls')
    door_geo=module('design/astra/work/v2_apartment_doors_batch_01/check.py','upper_doors')
    original=base()
    for key,value in original.items():
        if isinstance(value,list):
            now={r['id']:r for r in layout[key]}
            assert all(now[r['id']]==r for r in value),('baseline record changed',key)
        else:assert layout[key]==value,('baseline property changed',key)
    ids=[r['id'] for rows in layout.values() if isinstance(rows,list) for r in rows]
    assert len(ids)==len(set(ids)), 'duplicate semantic ID'
    spaces={s['id']:s for s in layout['spaces']};new=[s for s in spaces.values() if s['level'] in ['F05','F06']]
    for a in new:
        r=a['rect'];assert -15.65<=r[0]<r[2]<=15.65 and -12.35<=r[1]<r[3]<=11.65
        for b in new:
            if a['id']>=b['id'] or a['level']!=b['level']:continue
            q=b['rect'];assert min(r[2],q[2])-max(r[0],q[0])<=1e-6 or min(r[3],q[3])-max(r[1],q[1])<=1e-6,('room overlap',a['id'],b['id'])
        # Existing service halls intentionally contain the named pipe chases;
        # their walking lane is checked separately from room envelopes.
        if a['class'] in ['core','service']:continue
        for riser in layout['risers']:
            if not riser.get('solid',True):continue
            q=riser['rect'];assert min(r[2],q[2])-max(r[0],q[0])<=1e-6 or min(r[3],q[3])-max(r[1],q[1])<=1e-6,('room crosses service chase',a['id'],riser['id'])
    walls.PREFIXES=('F05_','F06_')
    assert not walls.missing(layout),'missing upper floor boundary'
    edges=[w for w in walls.owned(layout) if w['level'] in ['F05','F06']]
    for i,a in enumerate(edges):
        for b in edges[i+1:]:
            assert not (walls.aligned(a,b) and min(a['end'],b['end'])>max(a['start'],b['start'])+1e-6),('duplicate wall ownership',a,b)
    graph={s:set() for s in spaces}
    for r in layout['doors']+layout['openings']:
        a,b=r['connects'];assert a in spaces and b in spaces
        graph[a].add(b);graph[b].add(a)
        if r['level'] not in ['F05','F06']:continue
        axis=r.get('axis','x' if abs(r['yaw'])<.1 else 'z') if 'yaw' in r else r['axis']
        at=r['center'];along,fixed=(at if axis=='x' else at[::-1])
        bounds=[]
        for s in [spaces[a],spaces[b]]:
            possible=[walls.edge(s,side) for side in walls.SIDES]
            bounds.append(next((w for w in possible if w['axis']==axis and abs(w['fixed']-fixed)<1e-6 and along-r['width']/2>=w['start']-1e-6 and along+r['width']/2<=w['end']+1e-6),None))
        assert all(bounds),('portal is not inside both boundary intervals',r['id'])
    for level in ['F05','F06']:
        reached={level+'_PUBLIC_CORE'};todo=list(reached)
        while todo:
            for other in graph[todo.pop()]-reached:reached.add(other);todo.append(other)
        assert all(s['id'] in reached for s in new if s['level']==level),'unreachable upper room'
    assert len(program['programs'])==8
    assert set(program['doors'])=={d['id'] for d in layout['doors'] if d['level'] in ['F05','F06']}
    assert {p['resident'] for p in program['programs'] if p['disposition']=='occupied'}=={p[0] for p in PEOPLE.values()}
    assert all(program['doors'][p['entry']]['leaf_state']=='locked' for p in program['programs'] if p['disposition']!='occupied')
    levels={r['id']:r['y'] for r in layout['levels']}
    new_stairs=[s for s in layout['stairs'] if s['to'] in ['F05','F06']]
    assert len(new_stairs)==4
    for stair in new_stairs:
        assert abs(levels[stair['to']]-levels[stair['from']]-2*stair['rise']*stair['risers_per_flight'])<1e-6,'stair rise mismatch'
        template=next(s for s in original['stairs'] if s['id']==stair['id'].split('_')[0]+'_F03_F04')
        assert all(stair[k]==v for k,v in template.items() if k not in ['id','from','to']),'stair template drift'
        core=spaces[stair['to']+('_PUBLIC_CORE' if stair['id'].startswith('PRIMARY') else '_SERVICE_CORE')]['rect']
        x,z=stair['origin'];end_x=x+2*stair['width']+stair['gap']
        end_z=z+stair['tread']*stair['risers_per_flight']+stair['landing_depth']+.7
        assert core[0]<x<end_x<core[2] and core[1]<z<end_z<core[3],('stair exceeds its core',stair['id'])
        assert spaces[stair['from']+('_PUBLIC_CORE' if stair['id'].startswith('PRIMARY') else '_SERVICE_CORE')].get('no_ceiling'), 'lower core ceiling cuts the new stair'
    for window in layout['windows']:
        if window['level'] not in ['F05','F06']:continue
        space=spaces[window['space']]
        assert space['level']==window['level']
        assert 0<window['sill']<window['sill']+window['height']<=layout['dimensions']['clear_height']
        matching=[w for w in edges if w['owner']==space['id'] and any(a['id']==window['id'] for a in walls.apertures(layout,w))]
        assert matching,('window misses owned wall',window['id'])
    return dict(new_levels=2,new_spaces=len(new),occupied_room_programs=6,restricted_thresholds=2,
                stairs_added=4,lift_landings_added=4,windows_added=24,live_doors=len(program['doors']),
                wall_intervals=len(edges),godot='NOT_RUN',status='SOURCE_INTEGRATED_RUNTIME_PENDING')


def build(apply=False):
    layout,program=candidate();result=validate(layout,program)
    import routes
    paths=routes.check(layout,program)
    result.update(leaf_sweep_poses=paths['leaf_sweep_poses'],capsule_radius=paths['radius'],occupied_room_routes=42)
    rejected=[]
    for mutation in ['missing_stair','displaced_entry','changed_existing_room','unlocked_restricted']:
        bad=copy.deepcopy(layout);bad_program=copy.deepcopy(program)
        if mutation=='missing_stair':bad['stairs'].pop()
        elif mutation=='displaced_entry':next(d for d in bad['doors'] if d['id']=='F05_DOOR_02')['center'][0]+=10
        elif mutation=='changed_existing_room':bad['spaces'][0]['rect'][0]-=1
        else:bad_program['doors']['F05_DOOR_05']['leaf_state']='closed'
        try:validate(bad,bad_program)
        except AssertionError:rejected.append(mutation)
        else:raise AssertionError(('negative control accepted',mutation))
    result['rejected_controls']=rejected
    encoded=write_layout(layout)
    data=(json.dumps(program,indent=2)+'\n').encode('utf-8')
    probes=dict(floors=[dict(level=f['level'],rooms=[dict(id=r['room'],point=r['points'][-1]) for r in f['room_routes']]) for f in paths['floors']])
    probe_bytes=(json.dumps(probes,indent=2)+'\n').encode('utf-8')
    if apply:
        current=json.loads((ROOT/LAYOUT).read_text(encoding='utf-8'))
        # Recognize the first generated revision's generic corridor wording.
        comparison=copy.deepcopy(current);authored={r['id']:r for r in layout['spaces']}
        for r in comparison['spaces']:
            if r['level'] in ['F05','F06'] and r['purpose']=='upper floor circulation':r['purpose']=authored[r['id']]['purpose']
        assert current==base() or comparison==layout,'unreviewed concurrent layout changes'
        (ROOT/LAYOUT).write_bytes(encoded);(ROOT/PROGRAM).write_bytes(data);(ROOT/PROBES).write_bytes(probe_bytes)
    else:
        assert (ROOT/LAYOUT).read_bytes().replace(b'\r\n',b'\n')==encoded
        assert (ROOT/PROGRAM).read_bytes().replace(b'\r\n',b'\n')==data
        assert (ROOT/PROBES).read_bytes().replace(b'\r\n',b'\n')==probe_bytes
    (OUT/'routes.json').write_bytes((json.dumps(paths,separators=(',',':'))+'\n').encode('utf-8'))
    inventory=json.loads((ROOT/'design/astra/work/v2_household_accessories_01/current_inventory.json').read_text(encoding='utf-8'))
    by_unit={p['unit']:p for p in program['programs']}
    for row in inventory['units']:
        if row['unit'] in by_unit:
            p=by_unit[row['unit']];row['rooms']=p['rooms'];row['status']=p['stage'];row['pending']=p['pending']
    inventory.update(batch='v2_upper_floors_01',new_occupied_room_programs=6,new_restricted_thresholds=2,
                     remaining_residential_programs=8,basement_housing_program='PENDING_SEPARATELY',
                     limits='22 numbered residential labels exclude 1B/1C shared uses; B1 housing is tracked separately. Six furnished source cores, six additional unfurnished occupied programs and two restricted thresholds. No runtime completion claim.')
    (OUT/'current_inventory.json').write_bytes((json.dumps(inventory,indent=2)+'\n').encode('utf-8'))
    (OUT/'checks.json').write_bytes((json.dumps(result,indent=2)+'\n').encode('utf-8'))
    print(json.dumps(result))


if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--apply',action='store_true');build(parser.parse_args().apply)
