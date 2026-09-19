"""Author all occupied upper-room circuits; preserve the preceding source."""
import argparse
import importlib.util
import json
import math
from pathlib import Path
import subprocess
import sys
from collections import deque

ROOT=Path(__file__).resolve().parents[4]
OUT=Path(__file__).resolve().parent
BASE='e4a0964'
LAYOUT='game/data/orison_v2_blockout.json'
LIGHTING='game/data/orison_v2/room_lighting.json'
PROGRAM='game/data/orison_v2/upper_floor_programs.json'
PROBES='game/tests/data/v2_upper_lighting_probes.json'

def module(path,name):
    spec=importlib.util.spec_from_file_location(name,ROOT/path)
    value=importlib.util.module_from_spec(spec);spec.loader.exec_module(value);return value
def load(path):return json.loads((ROOT/path).read_text(encoding='utf-8'))
def base(path):return json.loads(subprocess.check_output(['git','show',BASE+':'+path],cwd=ROOT).decode())
def write(path,value,compact=False):
    path.write_bytes((json.dumps(value,**({'separators':(',',':')} if compact else {'indent':2}))+'\n').encode())

def geometry(layout):
    walls=module('design/astra/work/v2_apartment_walls_batch_01/build.py','light_walls')
    light=module('design/astra/work/v2_apartment_lighting_batch_01/build.py','light_geometry')
    fixtures=module('design/astra/work/v2_upper_fixtures_01/build.py','light_fixtures')
    geo=module('design/astra/work/v2_apartment_doors_batch_01/check.py','light_doors')
    anchors={a['id']:a for a in layout['anchors']};solids=[];sweeps=[]
    for wall in walls.owned(layout):
        holes=[(h['start'],h['end']) for h in walls.apertures(layout,wall) if h['sill']==0 and h['height']>=1.6]
        for lo,hi in walls.subtract(wall['start'],wall['end'],holes):
            r=[lo,wall['fixed']-.07,hi,wall['fixed']+.07] if wall['axis']=='x' else [wall['fixed']-.07,lo,wall['fixed']+.07,hi]
            solids.append((wall['level'],r))
    for level in ['F05','F06']:
        solids.extend((level,r['rect']) for r in layout['risers'] if r.get('solid',True))
    for record in load('game/data/orison_v2/domestic_furniture.json')['furniture']+load('game/data/orison_v2/domestic_fittings.json')['fittings']:
        a=anchors[record['id']]
        if a['level'] not in ['F05','F06']:continue
        for bounds in record.get('collision_boxes',[fixtures.bounds(record)]):
            solids.append((a['level'],light.footprint(bounds,a)))
        if record['kind']=='wardrobe':
            for side in [-1,1]:
                points=[geo.rotate(p,math.radians(92*-side)) for p in geo.rect_polygon([0 if side<0 else -.603,-.07,.603 if side<0 else 0,.015])]
                points=[[p[0]+side*.615,p[1]-.305] for p in points]
                points=[[a['position'][0]+p[0],a['position'][2]+p[1]] for p in [geo.rotate(p,a['yaw']) for p in points]]
                solids.append((a['level'],[min(p[0] for p in points),min(p[1] for p in points),max(p[0] for p in points),max(p[1] for p in points)]))
    programs=base(PROGRAM)
    for door in layout['doors']:
        if door['id'] not in programs['doors']:continue
        spec=programs['doors'][door['id']]
        offset=geo.rotate([0,spec['mount_offset']],door['yaw'])
        poses=[]
        for angle in range(0,101,2):
            poses.append([[p[i]+offset[i] for i in [0,1]] for p in geo.leaf_polygon(door,spec['swing_out'],angle)])
        sweeps.append((door['level'],poses))
        poly=poses[0] if spec['leaf_state']=='locked' else poses[-1]
        solids.append((door['level'],[min(p[0] for p in poly),min(p[1] for p in poly),max(p[0] for p in poly),max(p[1] for p in poly)]))
    return walls,light,geo,solids,sweeps

def build(apply=False):
    layout=base(LAYOUT);lighting=base(LIGHTING);program=base(PROGRAM)
    walls,light,geo,solids,sweeps=geometry(layout)
    spaces={s['id']:s for s in layout['spaces']}
    markers={m['id']:m for f in load('game/data/building_layout.json')['floors'] for m in f['markers'] if 'id' in m}
    new=[];targets=[];proof=[];routes={}
    for level in ['F05','F06']:
        obstacles=[r for lev,r in solids if lev==level]
        floors=[s['rect'] for s in layout['spaces'] if s['level']==level]
        def clear(x,z):
            if not all(any(r[0]<=x+dx<=r[2] and r[1]<=z+dz<=r[3] for r in floors) for dx,dz in [(0,0),(.38,0),(-.38,0),(0,.38),(0,-.38)]):return False
            return all(light.distance([x,z],r)>=.38 for r in obstacles)
        reached={(0,0)};queue=deque(reached);blocked=set();previous={}
        while queue:
            a=queue.popleft()
            for dx,dz in [(1,0),(-1,0),(0,1),(0,-1)]:
                b=(a[0]+dx,a[1]+dz)
                if b in reached or b in blocked:continue
                if clear(b[0]/10,b[1]/10):reached.add(b);previous[b]=a;queue.append(b)
                else:blocked.add(b)
        routes[level]=dict(reached=reached,previous=previous)
        for p in program['programs']:
            if not p['unit'].startswith(level[-1]) or p['disposition']!='occupied':continue
            for room_id in p['rooms']:
                room=spaces[room_id];r=room['rect'];c=[(r[0]+r[2])/2,(r[1]+r[3])/2]
                portals=[d['center'] for d in layout['doors']+layout['openings'] if room_id in d['connects']]
                candidates=[]
                for side in ['west','east','south','north']:
                    axis=0 if side in ['west','east'] else 1;along=1-axis
                    inward=[0,0];inward[axis]=1 if side in ['west','south'] else -1
                    fixed=r[axis] if inward[axis]>0 else r[axis+2]
                    yaw=math.atan2(-inward[0],-inward[1])
                    for n in range(math.ceil((r[along]+.5)*10),math.floor((r[along+2]-.5)*10)+1):
                        plate=[0,0];plate[axis]=fixed+.09*inward[axis];plate[along]=n/10
                        stance=[plate[i]+.96*inward[i] for i in [0,1]]
                        goal=tuple(round(v*10) for v in stance)
                        if goal not in reached or not clear(*stance):continue
                        if not all(r[i]+.45<=stance[i]<=r[i+2]-.45 for i in [0,1]):continue
                        try:owners=light.supporting_wall(layout,room,plate,yaw)
                        except AssertionError:continue
                        # Approach after opening the door; the fixed plate must
                        # remain outside the whole swing, the player may move.
                        if any(geo.distance(stance,poses[-1])<.38 or any(geo.distance(plate,poly)<.12 for poly in poses) for lev,poses in sweeps if lev==level):continue
                        # Reject a fixture or wall between the hand and plate.
                        if any(light.distance([stance[i]+(plate[i]-stance[i])*t for i in [0,1]],box)<.02 for box in obstacles for t in [.2,.4,.6,.8]):continue
                        score=min((math.dist(plate,d) for d in portals),default=math.dist(plate,c))
                        candidates.append((score,side,plate,yaw,stance,owners,goal))
                assert candidates,('no clear reachable switch',room_id)
                _,side,plate,yaw,stance,owners,goal=min(candidates)
                kind='pendant_shade' if room_id.endswith('_MAIN') else 'kitchen_linear' if room_id.endswith('_KITCHEN') else 'flush_dome'
                identity=room_id+'_LT_'+kind.upper();switch=room_id+'_SWITCH'
                original=markers.get(identity)
                bedroom={'A':'BED','B':'ALCOVE','C':'BED1'}[p['unit'][1]]
                fallback=markers[level+'_'+p['unit'][1]+'_'+bedroom+'_LT_FLUSH_DOME']
                gain=original['energy'] if original else fallback['energy']
                reach=round(min(7,math.hypot(r[2]-r[0],r[3]-r[1])*.5+.8),2)
                lighting['fixtures'].append(dict(id=identity,room=room_id,kind=kind,properties=dict(range_clamp=reach,energy_scale=gain)))
                lighting['switches'].append(dict(id=switch,room=room_id))
                for identity2,pos,rotation,role in [(identity,[c[0],3.0,c[1]],0,'fixture'),(switch,[plate[0],1.12,plate[1]],yaw,'interaction'),(switch+'_STANCE',[stance[0],0,stance[1]],yaw+math.pi,'clearance')]:
                    row=dict(id=identity2,level=level,space=room_id,position=pos,yaw=rotation,kind=role)
                    layout['anchors'].append(row);new.append(row)
                path=[goal]
                while path[-1]!=(0,0):path.append(previous[path[-1]])
                path.reverse();points=[[x/10,z/10] for x,z in path]+[stance]
                for a,b in zip(points,points[1:]):
                    for t in [.25,.5,.75]:assert clear(*[a[i]+(b[i]-a[i])*t for i in [0,1]]),(room_id,'route edge')
                targets.append(dict(room=room_id,fixture=identity,switch=switch,level=level,stance=stance,plate=plate,yaw=yaw,kind=kind,properties=lighting['fixtures'][-1]['properties']))
                proof.append(dict(room=room_id,wall_owners=owners,route=points,gain_source=original['id'] if original else fallback['id']))
    assert len(targets)==42
    for key in ['fixtures','switches']:assert len(lighting[key])==len({a['id'] for a in lighting[key]})
    assert len(layout['anchors'])==len({a['id'] for a in layout['anchors']})
    outputs={LAYOUT:layout,LIGHTING:lighting}
    for path,key in [(LAYOUT,'anchors'),(LIGHTING,None)]:
        current=load(path);original=base(path);candidate=outputs[path]
        if apply:
            if key: current[key]=[a for a in current[key] if a['id'] not in {v['id'] for v in new}]
            else:
                for table in ['fixtures','switches']:current[table]=[a for a in current[table] if a['room'] not in {t['room'] for t in targets}]
            assert current==original,('unexpected source changes',path)
        else:assert current==candidate,('regeneration mismatch',path)
    if apply:
        write(ROOT/LIGHTING,lighting)
        text=subprocess.check_output(['git','show',BASE+':'+LAYOUT],cwd=ROOT).decode()
        start=text.index('[',text.index('"anchors"'));_,size=json.JSONDecoder().raw_decode(text[start:]);end=start+size-1
        (ROOT/LAYOUT).write_bytes((text[:end].rstrip()+',\n'+',\n'.join('    '+json.dumps(r,separators=(',',':')) for r in new)+'\n  '+text[end:]).encode())
        write(ROOT/PROBES,dict(rooms=targets))
    else:assert load(PROBES)==dict(rooms=targets)
    write(OUT/'routes.json',dict(rooms=[dict(room=r['room'],points=r['route']) for r in proof]),True)
    summaries=[dict(room=r['room'],wall_owners=r['wall_owners'],route_points=len(r['route']),gain_source=r['gain_source']) for r in proof]
    write(OUT/'source_checks.json',dict(status='SOURCE_PASS',base=BASE,fixtures_added=42,switches_added=42,anchors_added=len(new),
          total_circuits=len(lighting['switches']),rooms=summaries,routes='routes.json',limits='Source capsule routes with ordinary doors and wardrobes open; physical targeting and light appearance need Godot. No player traversal claim.'))
    print('PASS: 42 upper room circuits, 126 anchors, reproducible wall/clearance routes')

if __name__=='__main__':
    sys.modules['build']=sys.modules[__name__]
    p=argparse.ArgumentParser();p.add_argument('--apply',action='store_true');build(p.parse_args().apply)
