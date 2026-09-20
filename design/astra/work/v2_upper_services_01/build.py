"""Install authored upper household heat and accessories against current geometry."""
import copy, json, math, subprocess, sys, importlib.util, argparse
from pathlib import Path
from collections import deque
ROOT=Path(__file__).resolve().parents[4];OUT=Path(__file__).resolve().parent
BASE='888e4c3';LAYOUT='game/data/orison_v2_blockout.json';HEAT='game/data/orison_v2/heating.json';ACCESS='game/data/orison_v2/household_accessories.json';PROBES='game/tests/data/v2_upper_services_probes.json'
BATH='game/data/orison_v2/bath_details.json'
UNITS=['5A','5B','5C','6A','6B','6C']
def module(path,name):
 s=importlib.util.spec_from_file_location(name,ROOT/path);m=importlib.util.module_from_spec(s);s.loader.exec_module(m);return m
def load(p):return json.loads((ROOT/p).read_text(encoding='utf-8'))
def base(p):return json.loads(subprocess.check_output(['git','show',BASE+':'+p],cwd=ROOT).decode())
def write(p,v):p.write_bytes((json.dumps(v,indent=2)+'\n').encode())
geo=module('design/astra/work/v2_storage_tables_boards_batch_01/build.py','service_volume')
acc=module('design/astra/work/v2_household_accessories_01/build.py','service_accessory')
fit=module('design/astra/work/v2_upper_fixtures_01/build.py','service_fixture')

def geometry(layout):
 lights=module('design/astra/work/v2_upper_lighting_01/build.py','service_routes')
 def nav_load(p):
  data=base(p)
  if p.endswith('domestic_furniture.json'):data['furniture']=[r for r in data['furniture'] if r['kind']!='cupboard']
  return data
 lights.load=nav_load
 walls,distance,doors,solids,sweeps=lights.geometry(layout)
 anchors={a['id']:a for a in layout['anchors']};volumes=[]
 for r in base('game/data/orison_v2/domestic_furniture.json')['furniture']+base('game/data/orison_v2/domestic_fittings.json')['fittings']:
  a=anchors[r['id']]
  if a['level'] in ['F05','F06']:volumes.append((r['id'],a['level'],geo.volume(fit.bounds(r),a)))
 return walls,distance,doors,solids,sweeps,volumes

def run(apply=False):
 layout=base(LAYOUT);heating=base(HEAT);access=base(ACCESS);anchors={a['id']:a for a in layout['anchors']};spaces={s['id']:s for s in layout['spaces']}
 walls,distance,doors,solids,sweeps,volumes=geometry(layout)
 added=[];probes=[];proof=[];new_access=[];bath=base(BATH);new_details=[]
 markers=[m for f in base('game/data/building_layout.json')['floors'] for m in f.get('markers',[])]
 for unit in UNITS:
  for kind in ['toaster','mirror']:
   source=next((m for m in markers if m.get('unit')==unit and m.get('kind')==kind),None)
   if source is None:continue
   row=copy.deepcopy(next(r for r in access['accessories'] if r['unit']=='2A' and r['kind']==kind))
   row.update(id=source['id'],unit=unit,support=unit+'_prep_cabinet' if kind=='toaster' else 'F0'+unit[0]+'_'+unit+'_SINK_01')
   support=anchors[row['support']];stance=anchors[row['support']+'_STANCE']['position'];relative=[stance[i]-support['position'][i] for i in range(3)]
   row['stance']=acc.transform(dict(position=[0,0,0],yaw=-support['yaw']),relative)
   if kind=='mirror':row['position']=[0,.04,{'A':.232,'B':.292,'C':.222}[unit[1]]];row['hinge_side']=source['hinge_side']
   new_access.append(row)
   pose=acc.world_pose(row,anchors);b=geo.volume(row['bounds'],pose)
   for identity,level,other in volumes:
    if level==pose['level']:assert not geo.overlap(b,other),('accessory overlaps fixture',row['id'],identity)
   volumes.append((row['id'],pose['level'],b))
   proof.append(dict(id=row['id'],volume=b,source_marker=source['id']))
   probes.append(dict(id=row['id'],kind=kind,unit=unit,level=pose['level'],stance=stance,position=pose['position']))
 # Complete identical support-mounted bath detail categories for the upper homes.
 for unit in UNITS:
  for template in [r for r in base(BATH)['props'] if r['unit']=='2A']:
   row=copy.deepcopy(template);row.update(id=unit+'_'+row['kind'],unit=unit,support=unit+'_wc' if row['kind']=='toilet_roll' else 'F0'+unit[0]+'_'+unit+'_SINK_01')
   a=anchors[row['support']];b=geo.volume(row['bounds'],a);room=spaces[a['space']]['rect']
   assert b[0]>=room[0]+.07 and b[2]>=room[1]+.07 and b[3]<=room[2]-.07 and b[5]<=room[3]-.07,('bath detail outside room',row['id'])
   for identity,level,other in volumes:
    if level==a['level'] and identity!=row['support']:assert not geo.overlap(b,other),('bath detail overlap',row['id'],identity)
   volumes.append((row['id'],a['level'],b));new_details.append(row)
   proof.append(dict(id=row['id'],volume=b,template=template['id']))
 bath['props']+=new_details
 # Each new radiator occupies a clear wall interval in its household main room.
 for record in heating['network']:
  if record['unit'] not in UNITS:continue
  unit=record['unit'];room='F0'+unit[0]+'_'+unit[1]+'_MAIN';level=room[:3];r=spaces[room]['rect'];candidates=[]
  # Conservative envelope includes supply pipe, handwheel and air vent.
  bounds=[[-.72,-.75,-.15],[.7,.2,.15]]
  for side in ['west','east','south','north']:
   axis=0 if side in ['west','east'] else 1;along=1-axis;inward=[0,0];inward[axis]=1 if side in ['west','south'] else -1
   fixed=r[axis] if inward[axis]>0 else r[axis+2];yaw=math.atan2(-inward[0],-inward[1])
   for n in range(math.ceil((r[along]+.85)*10),math.floor((r[along+2]-.85)*10)+1):
    p=[0,0];p[axis]=fixed+.22*inward[axis];p[along]=n/10
    a=dict(id=record['id'],level=level,space=room,position=[p[0],.75,p[1]],yaw=yaw,kind='interaction');b=geo.volume(bounds,a);rect=[b[0],b[2],b[3],b[5]]
    if any(lev==level and geo.overlap(b,other) for _,lev,other in volumes):continue
    if any(lev==level and any(doors.overlaps(doors.rect_polygon(rect),poly) for poly in poses) for lev,poses in sweeps):continue
    if any(x['level']==level and x['id'].endswith('_STANCE') and distance.distance([x['position'][0],x['position'][2]],rect)<.38 for x in anchors.values()):continue
    stance=[p[i]+.95*inward[i] for i in [0,1]]
    if any(lev==level and distance.distance(stance,box)<.38 for lev,box in solids):continue
    if not all(r[i]+.45<=stance[i]<=r[i+2]-.45 for i in [0,1]):continue
    # Back face against a real wall interval; cabinet-style .09m mount probe.
    mounting=[p[i]-.13*inward[i] for i in [0,1]]
    try:distance.supporting_wall(layout,spaces[room],mounting,yaw)
    except AssertionError:continue
    if any(w['level']==level and any(min(cut['end'],b[3 if w['axis']=='x' else 5])>max(cut['start'],b[0 if w['axis']=='x' else 2]) and cut['sill']<.95 for cut in walls.apertures(layout,w)) for w in walls.owned(layout) if abs(w['fixed']-fixed)<1e-6 and w['axis']==('z' if axis==0 else 'x')):continue
    # Prefer a clear exterior interval near the authored emitter, then distance.
    score=math.dist(p,[record['pos'][0],-record['pos'][1]])
    candidates.append((score,a,stance,b))
  assert candidates,('no clear radiator location',unit)
  _,a,stance,b=min(candidates,key=lambda v:v[0]);added.append(a)
  added.append(dict(id=a['id'].replace('_01','_STANCE'),level=level,space=room,position=[stance[0],0,stance[1]],yaw=a['yaw']+math.pi,kind='clearance'))
  heating['installed'].append({k:record[k] for k in ['id','unit','riser','sections']})
  volumes.append((a['id'],level,b));solids.append((level,[b[0],b[2],b[3],b[5]]))
  probes.append(dict(id=a['id'],kind='radiator',unit=unit,level=level,stance=[stance[0],0,stance[1]],position=a['position']))
  proof.append(dict(id=a['id'],volume=b,source_marker=record['id']))
 layout['anchors']+=added;access['accessories']+=new_access
 # Continuous solid backing and full mirror/tray motion, using actual supports.
 motion_count=0;wall_list=walls.owned(layout)
 for row in new_access:
  pose=acc.world_pose(row,anchors);b=geo.volume(row['bounds'],pose);motions=[]
  if row['kind']=='toaster':
   assert row['position']==[0,.9,0]
   motions=[geo.volume(row['motion_bounds'],pose)]
  else:
   for n in range(33):
    p=acc.transform(pose,[-.254+.508*n/32,1.505,.058]);matching=[]
    for w in wall_list:
     axis=0 if w['axis']=='x' else 2;fixed=2-axis
     if w['level']==pose['level'] and abs(abs(p[fixed]-w['fixed'])-.07)<1e-6 and w['start']<=p[axis]<=w['end']:
      if not any(c['start']<p[axis]<c['end'] and min(b[4],c['sill']+c['height'])>max(b[1],c['sill']) for c in walls.apertures(layout,w)):matching.append(w)
    assert matching,('mirror lacks backing',row['id'],p)
   side=1 if row['hinge_side']=='left' else -1
   for degrees in range(96):
    hinge=acc.transform(pose,[side*.23,1.505,-.060]);low,high=sorted([0,-side*.46])
    motions.append(geo.volume([[low-.012,-.305,-.041],[high+.012,.305,.028]],dict(position=hinge,yaw=pose['yaw']-side*math.radians(degrees))))
  for b in motions:
   for identity,level,other in volumes:
    if identity!=row['id'] and level==pose['level']:assert not geo.overlap(b,other),('accessory motion collision',row['id'],identity)
   for lev,poses in sweeps:
    if lev==pose['level']:assert not any(doors.overlaps(doors.rect_polygon([b[0],b[2],b[3],b[5]]),p) for p in poses),('accessory in door sweep',row['id'])
   motion_count+=1
 # Route every existing and newly installed control approach against radiators.
 targets=[dict(id=a['id'],level=a['level'],stance=a['position']) for a in layout['anchors'] if a['level'] in ['F05','F06'] and a['id'].endswith('_STANCE')]+probes
 routes=[]
 for level in ['F05','F06']:
  obstacles=[r for lev,r in solids if lev==level];floors=[s['rect'] for s in layout['spaces'] if s['level']==level]
  def clear(x,z):return all(any(r[0]<=x+dx<=r[2] and r[1]<=z+dz<=r[3] for r in floors) for dx,dz in [(0,0),(.38,0),(-.38,0),(0,.38),(0,-.38)]) and all(distance.distance([x,z],r)>=.38-1e-6 for r in obstacles)
  reached={(0,0)};queue=deque(reached);previous={};blocked=set()
  while queue:
   a=queue.popleft()
   for dx,dz in [(1,0),(-1,0),(0,1),(0,-1)]:
    b=(a[0]+dx,a[1]+dz)
    if b in reached or b in blocked:continue
    if clear(b[0]/10,b[1]/10):reached.add(b);previous[b]=a;queue.append(b)
    else:blocked.add(b)
  for t in targets:
   if t['level']!=level:continue
   p=[t['stance'][0],t['stance'][2]];goal=tuple(round(v*10) for v in p)
   assert goal in reached and clear(*p),('unreachable service',t)
   route=[goal]
   while route[-1]!=(0,0):route.append(previous[route[-1]])
   points=[[x/10,z/10] for x,z in reversed(route)]+[p]
   for a,b in zip(points,points[1:]):
    for t2 in [.25,.5,.75]:assert clear(*[a[i]+(b[i]-a[i])*t2 for i in [0,1]])
   routes.append(dict(id=t['id'],level=level,points=points))
 outputs={LAYOUT:layout,HEAT:heating,ACCESS:access,BATH:bath,PROBES:dict(services=probes)}
 for path in [LAYOUT,HEAT,ACCESS,BATH]:assert load(path) in [base(path),outputs[path]] if apply else load(path)==outputs[path],('unexpected source',path)
 if apply:
  text=subprocess.check_output(['git','show',BASE+':'+LAYOUT],cwd=ROOT).decode();start=text.index('[',text.index('"anchors"'));_,size=json.JSONDecoder().raw_decode(text[start:]);end=start+size-1
  (ROOT/LAYOUT).write_bytes((text[:end].rstrip()+',\n'+',\n'.join('    '+json.dumps(a,separators=(',',':')) for a in added)+'\n  '+text[end:]).encode())
  for path in [HEAT,ACCESS,PROBES]:write(ROOT/path,outputs[path])
  (ROOT/BATH).write_bytes((json.dumps(bath,separators=(',',':'))+'\n').encode())
 else:assert load(PROBES)==outputs[PROBES]
 write(OUT/'source_checks.json',dict(status='SOURCE_PASS',base=BASE,added_radiators=6,added_accessories=len(new_access),added_bath_details=len(new_details),new_anchors=len(added),motion_poses=motion_count,approaches=len(routes),route_points=sum(len(r['points']) for r in routes),placements=proof))
 (OUT/'routes.json').write_bytes((json.dumps(routes,separators=(',',':'))+'\n').encode())
 print('PASS',len(new_access),'accessories; six radiators;',len(routes),'approaches')
if __name__=='__main__':
 sys.modules['build']=sys.modules[__name__];p=argparse.ArgumentParser();p.add_argument('--apply',action='store_true');run(p.parse_args().apply)
