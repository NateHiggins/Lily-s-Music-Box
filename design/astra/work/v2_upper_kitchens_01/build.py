"""Whole-category dry preparation/storage for all six upper kitchens."""
import argparse
import copy
from collections import deque
import importlib.util
import json
import math
from pathlib import Path
import subprocess
import sys

ROOT=Path(__file__).resolve().parents[4]
OUT=Path(__file__).resolve().parent
BASE='73b65e6'
LAYOUT='game/data/orison_v2_blockout.json'
FURNITURE='game/data/orison_v2/domestic_furniture.json'
PROBES='game/tests/data/v2_upper_kitchen_probes.json'
UNITS=['5A','5B','5C','6A','6B','6C']
RELOCATIONS={f'F0{f}_{f}C_KITCHEN_SINK_01_STANCE':[4.85,0,4.9] for f in [5,6]}
RELOCATIONS.update({f'F0{f}_C_KITCHEN_SWITCH_STANCE':[5.6,0,4.9] for f in [5,6]})
RELOCATIONS.update({f'F0{f}_C_KITCHEN_SWITCH':[5.6,1.12,3.94] for f in [5,6]})
LIGHT_PROBES='game/tests/data/v2_upper_lighting_probes.json'

def module(path,name):
    spec=importlib.util.spec_from_file_location(name,ROOT/path)
    result=importlib.util.module_from_spec(spec);spec.loader.exec_module(result);return result
def load(path):return json.loads((ROOT/path).read_text(encoding='utf-8'))
def base(path):return json.loads(subprocess.check_output(['git','show',BASE+':'+path],cwd=ROOT).decode())
def write(path,value,compact=False):path.write_bytes((json.dumps(value,**({'separators':(',',':')} if compact else {'indent':2}))+'\n').encode())

def make():
    layout=base(LAYOUT);furniture=base(FURNITURE);new=[];anchors=[];probes=[]
    templates={r['id']:r for r in furniture['furniture']}
    for unit in UNITS:
        room='F0'+unit[0]+'_'+unit[1]+'_KITCHEN'
        if unit[1]=='A':prep=[-9.95,0,-6.665];cup=[-9.95,1.65,-6.72];yaw=0;stance=[-9.8,-7.8]
        elif unit[1]=='B':prep=[-8.985,0,7.1];cup=[-8.93,1.65,7.1];yaw=-math.pi/2;stance=[-7.95,7.1]
        else:prep=[4.115,0,4.94];cup=[4.17,1.65,4.94];yaw=-math.pi/2;stance=[5.25,4.9]
        for suffix,template,at in [('prep_cabinet','2A_prep_cabinet',prep),('k_wall_cupboard','2A_k_wall_cupboard',cup)]:
            identity=unit+'_'+suffix;r=copy.deepcopy(templates[template]);r['id']=identity
            if r['kind']=='prep_cabinet':r['mechanism']['unit']=unit
            else:r['source_component']['new_unit_variant']=True
            new.append(r)
            anchors.append(dict(id=identity,level=room[:3],space=room,position=at,yaw=yaw,kind='furniture'))
        identity=unit+'_prep_cabinet'
        anchors.append(dict(id=identity+'_STANCE',level=room[:3],space=room,position=[stance[0],0,stance[1]],yaw=yaw+math.pi,kind='clearance'))
        probes.append(dict(unit=unit,room=room,prep=identity,cupboard=unit+'_k_wall_cupboard',stance=stance))
    for a in layout['anchors']:
        if a['id'] in RELOCATIONS:
            a['position']=RELOCATIONS[a['id']]
            if '_SWITCH' in a['id']:a['yaw']=math.pi if not a['id'].endswith('_STANCE') else 0.0
    layout['anchors']+=anchors;furniture['furniture']+=new
    return {LAYOUT:layout,FURNITURE:furniture},new,anchors,probes

def validate(outputs,new,probes):
    layout=outputs[LAYOUT];anchors={a['id']:a for a in layout['anchors']};spaces={s['id']:s for s in layout['spaces']}
    geo=module('design/astra/work/v2_storage_tables_boards_batch_01/build.py','upper_kitchen_volumes')
    lights=module('design/astra/work/v2_upper_lighting_01/build.py','upper_kitchen_routes')
    # The old navigation census is built from the preserved baseline; the new
    # floor cabinets are added below. High wall cupboards stay above the body.
    lights.load=lambda path:base(path)
    walls,distance,leaves,solids,sweeps=lights.geometry(base(LAYOUT))
    fittings=module('design/astra/work/v2_upper_fixtures_01/build.py','upper_kitchen_fittings')
    volumes=[]
    for record in outputs[FURNITURE]['furniture']+load('game/data/orison_v2/domestic_fittings.json')['fittings']:
        a=anchors[record['id']]
        if a['level'] not in ['F05','F06']:continue
        volumes.append((record['id'],a['level'],geo.volume(fittings.bounds(record),a)))
    source_proof=[]
    for record in new:
        a=anchors[record['id']];b=geo.volume(record['bounds'],a);r=spaces[a['space']]['rect']
        assert b[0]>=r[0]+.07-1e-6 and b[2]>=r[1]+.07-1e-6 and b[3]<=r[2]-.07+1e-6 and b[5]<=r[3]-.07+1e-6,('outside kitchen',record['id'])
        for identity,level,other in volumes:
            if identity!=record['id'] and level==a['level']:assert not geo.overlap(b,other),('cabinet overlap',record['id'],identity)
        poly=leaves.rect_polygon([b[0],b[2],b[3],b[5]])
        for door_index,(level,poses) in enumerate(sweeps):
            if level==a['level']:
                for p in poses:assert not leaves.overlaps(poly,p),('door sweep hits cabinet',record['id'],door_index)
        inward=[-math.sin(a['yaw']),-math.cos(a['yaw'])]
        back=[a['position'][0]-record['bounds'][1][2]*inward[0],a['position'][2]-record['bounds'][1][2]*inward[1]]
        mounting=[back[i]+.02*inward[i] for i in [0,1]]
        owners=distance.supporting_wall(layout,spaces[a['space']],mounting,a['yaw'])
        # Test the full cabinet width against actual apertures, including windows.
        wall_fixed=[back[i]-.07*inward[i] for i in [0,1]]
        axis='z' if abs(inward[0])>.5 else 'x';k=2 if axis=='z' else 0
        for w in walls.owned(layout):
            if w['level']!=a['level'] or w['axis']!=axis or abs(w['fixed']-wall_fixed[1 if axis=='x' else 0])>1e-6:continue
            for cut in walls.apertures(layout,w):
                assert not (min(cut['end'],b[k+3])>max(cut['start'],b[k]) and min(cut['sill']+cut['height'],b[4])>max(cut['sill'],b[1])),('cabinet covers aperture',record['id'],cut['id'])
        if record['kind']=='prep_cabinet':solids.append((a['level'],[b[0],b[2],b[3],b[5]]))
        else:assert b[1]>=1.65 and b[4]<2.4
        source_proof.append(dict(id=record['id'],volume=b,wall_owners=owners))
    motion_poses=0
    for record in load('game/data/orison_v2/domestic_fittings.json')['fittings']:
        a=anchors[record['id']]
        if a['level'] not in ['F05','F06'] or record['kind'] not in ['fridge','stove']:continue
        motions=[]
        if record['kind']=='fridge':
            electric=record['properties']['monitor_top'];width=.72 if electric else .70;front=-.32 if electric else -.29
            for n in range(211):
                points=[leaves.rotate(p,math.radians(n*.5)) for p in leaves.rect_polygon([0,-.12,width,.025])]
                motions.append([[p[0]-width/2,p[1]+front] for p in points])
            if not electric:motions.append(leaves.rect_polygon([-.31,-.63,.31,-.25]))
        else:motions.append(leaves.rect_polygon([-.26,-.76,.26,-.28]))
        for points in motions:
            polygon=[[a['position'][0]+p[0],a['position'][2]+p[1]] for p in [leaves.rotate(p,a['yaw']) for p in points]]
            for item in source_proof:
                b=item['volume']
                if anchors[item['id']]['level']!=a['level'] or b[1]>=fittings.bounds(record)[1][1]:continue
                assert not leaves.overlaps(polygon,leaves.rect_polygon([b[0],b[2],b[3],b[5]])),('appliance motion hits cabinet',record['id'],item['id'])
            motion_poses+=1
    for identity in RELOCATIONS:
        if not identity.endswith('_SWITCH'):continue
        a=anchors[identity];point=[a['position'][0],a['position'][2]]
        distance.supporting_wall(layout,spaces[a['space']],point,a['yaw'])
        assert not any(leaves.distance(point,p)<.12 for lev,poses in sweeps if lev==a['level'] for p in poses),('switch in door sweep',identity)
    targets=[dict(id=p['prep'],level=p['room'][:3],point=p['stance']) for p in probes]
    # Keep all existing upper light, appliance and furniture approaches usable.
    for a in layout['anchors']:
        if a['id'] in {p['prep']+'_STANCE' for p in probes}:continue
        if a['level'] in ['F05','F06'] and a['id'].endswith('_STANCE'):
            targets.append(dict(id=a['id'],level=a['level'],point=[a['position'][0],a['position'][2]]))
    paths=[]
    for level in ['F05','F06']:
        obstacles=[r for lev,r in solids if lev==level];floors=[s['rect'] for s in layout['spaces'] if s['level']==level]
        def clear(x,z):
            return all(any(r[0]<=x+dx<=r[2] and r[1]<=z+dz<=r[3] for r in floors) for dx,dz in [(0,0),(.38,0),(-.38,0),(0,.38),(0,-.38)]) and all(distance.distance([x,z],r)>=.38-1e-6 for r in obstacles)
        todo=deque([(0,0)]);reached={(0,0)};blocked=set();previous={}
        while todo:
            at=todo.popleft()
            for dx,dz in [(1,0),(-1,0),(0,1),(0,-1)]:
                p=(at[0]+dx,at[1]+dz)
                if p in reached or p in blocked:continue
                if clear(p[0]/10,p[1]/10):reached.add(p);previous[p]=at;todo.append(p)
                else:blocked.add(p)
        for target in targets:
            if target['level']!=level:continue
            p=target['point'];goal=tuple(round(x*10) for x in p)
            assert goal in reached and clear(*p),('approach blocked',target,[(r,distance.distance(p,r)) for r in obstacles if distance.distance(p,r)<.38])
            route=[goal]
            while route[-1]!=(0,0):route.append(previous[route[-1]])
            points=[[x/10,z/10] for x,z in reversed(route)]+[p]
            for a,b in zip(points,points[1:]):
                for t in [.25,.5,.75]:assert clear(*[a[i]+(b[i]-a[i])*t for i in [0,1]]),('route edge',target['id'])
            paths.append(dict(id=target['id'],level=level,points=points))
    return dict(volumes=source_proof,appliance_motion_poses=motion_poses,relocated_anchors=RELOCATIONS,approaches=len(paths),routes=paths)

def run(apply=False):
    outputs,new,anchors,probes=make();proof=validate(outputs,new,probes)
    for path,key,own in [(LAYOUT,'anchors',anchors),(FURNITURE,'furniture',new)]:
        current=load(path)
        if apply:
            ids={r['id'] for r in own};current[key]=[r for r in current[key] if r['id'] not in ids]
            if path==LAYOUT:
                originals={a['id']:a for a in base(LAYOUT)['anchors']}
                for a in current['anchors']:
                    if a['id'] in RELOCATIONS:
                        assert a['position'] in [originals[a['id']]['position'],RELOCATIONS[a['id']]]
                        expected_yaw=math.pi if a['id'].endswith('_SWITCH') else 0.0 if '_SWITCH' in a['id'] else originals[a['id']]['yaw']
                        assert a['yaw'] in [originals[a['id']]['yaw'],expected_yaw]
                        a['position']=originals[a['id']]['position'];a['yaw']=originals[a['id']]['yaw']
            assert current==base(path),('unexpected concurrent source',path)
        else:assert current==outputs[path],('regeneration differs',path)
    light_probes=base(LIGHT_PROBES)
    for p in light_probes['rooms']:
        if p['switch']+'_STANCE' in RELOCATIONS:
            p['stance']=[RELOCATIONS[p['switch']+'_STANCE'][i] for i in [0,2]]
            p['plate']=[RELOCATIONS[p['switch']][i] for i in [0,2]];p['yaw']=math.pi
    assert load(LIGHT_PROBES) in [base(LIGHT_PROBES),light_probes] if apply else load(LIGHT_PROBES)==light_probes
    if apply:
        write(ROOT/FURNITURE,outputs[FURNITURE],True)
        text=subprocess.check_output(['git','show',BASE+':'+LAYOUT],cwd=ROOT).decode()
        for a in base(LAYOUT)['anchors']:
            if a['id'] in RELOCATIONS:
                replacement=copy.deepcopy(a);replacement['position']=RELOCATIONS[a['id']]
                if '_SWITCH' in a['id']:replacement['yaw']=math.pi if not a['id'].endswith('_STANCE') else 0.0
                old=json.dumps(a,separators=(',',':'));assert old in text
                text=text.replace(old,json.dumps(replacement,separators=(',',':')))
        start=text.index('[',text.index('"anchors"'));_,size=json.JSONDecoder().raw_decode(text[start:]);end=start+size-1
        (ROOT/LAYOUT).write_bytes((text[:end].rstrip()+',\n'+',\n'.join('    '+json.dumps(a,separators=(',',':')) for a in anchors)+'\n  '+text[end:]).encode())
        write(ROOT/PROBES,dict(kitchens=probes))
        write(ROOT/LIGHT_PROBES,light_probes)
    else:assert load(PROBES)==dict(kitchens=probes)
    write(OUT/'routes.json',proof.pop('routes'),True)
    proof.update(status='SOURCE_PASS',base=BASE,new_furniture=len(new),new_anchors=len(anchors),total_furniture=len(outputs[FURNITURE]['furniture']),triangles=sum(len(s['vertices'])//9 for r in new for s in r['surfaces']))
    write(OUT/'source_checks.json',proof)
    print('PASS:',len(new),'kitchen cabinets;',proof['approaches'],'new/existing approaches;',proof['triangles'],'source triangles')

if __name__=='__main__':
    sys.modules['build']=sys.modules[__name__]
    p=argparse.ArgumentParser();p.add_argument('--apply',action='store_true');run(p.parse_args().apply)
