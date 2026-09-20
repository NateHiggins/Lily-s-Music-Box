"""Dedicated receiver tables for all six upper households; native profiles."""
import ast,json,math,zlib,subprocess,importlib.util,argparse
from pathlib import Path
from collections import deque
ROOT=Path(__file__).resolve().parents[4];OUT=Path(__file__).resolve().parent;BASE='b3aae2a'
LAYOUT='game/data/orison_v2_blockout.json';FURN='game/data/orison_v2/domestic_furniture.json';RADIO='game/data/orison_v2/domestic_radios.json';PROBES='game/tests/data/v2_upper_radio_probes.json'
UNITS=['5A','5B','5C','6A','6B','6C']
BOUNDS={'5A':[[-.53,0,-.175],[.275,.35,.145]],'5B':[[-.53,0,-.175],[.53,.38,.145]],'5C':[[-.17,0,-.12],[.29,.25,.12]],'6A':[[-.195,0,-.14],[.195,.298,.09]],'6B':[[-.53,0,-.185],[.225,.35,.14]],'6C':[[-.225,0,-.185],[.53,.38,.14]]}
def base(p):return json.loads(subprocess.check_output(['git','show',BASE+':'+p],cwd=ROOT).decode())
def module(p,n):
 s=importlib.util.spec_from_file_location(n,ROOT/p);m=importlib.util.module_from_spec(s);s.loader.exec_module(m);return m
def write(p,v,compact=False):p.write_bytes((json.dumps(v,**({'separators':(',',':')} if compact else {'indent':2}))+'\n').encode())
geo=module('design/astra/work/v2_storage_tables_boards_batch_01/build.py','radio_volumes');geo.load=base
light=module('design/astra/work/v2_apartment_lighting_batch_01/build.py','radio_points')
upper=module('design/astra/work/v2_upper_lighting_01/build.py','radio_routes');upper.base=base
def navload(p):
 v=base(p)
 if p==FURN:v['furniture']=[r for r in v['furniture'] if r['kind']!='cupboard']
 return v
upper.load=navload
def extract():
 previous=module('design/astra/work/v2_apartment_batches_01/build.py','radio_assembly');nodes=[]
 for n in ast.parse((ROOT/previous.SOURCE).read_text()).body:
  if isinstance(n,ast.ClassDef) and n.name=='MeshBuf':n.body=[f for f in n.body if isinstance(f,ast.FunctionDef) and f.name in previous.METHODS];nodes.append(n)
  elif isinstance(n,ast.ClassDef) and n.name=='Frame':nodes.append(n)
  elif isinstance(n,ast.FunctionDef) and n.name in {'asm_table_rect','case_wood','hash_str','_jit'}:nodes.append(n)
 ns=dict(math=math,zlib=zlib);exec(compile(ast.Module(body=nodes,type_ignores=[]),previous.SOURCE,'exec'),ns)
 records={u+'_wireless_table':dict(id=u+'_wireless_table',asm='table_rect',L=1.2 if u=='5B' else 1.1,W=.46,mat='wood_dark') for u in UNITS}
 return [previous.furniture_record(i,records,ns) for i in records]
def run(apply=False):
 layout=base(LAYOUT);furniture=base(FURN);radios=base(RADIO);tables=extract();spaces={s['id']:s for s in layout['spaces']};anchors={a['id']:a for a in layout['anchors']}
 legacy=module('design/astra/work/v2_household_radios_batch_01/build.py','legacy_radio_bounds')
 for row in radios['receivers']:row['bounds']=legacy.BOUNDS[row['unit']]
 volumes=geo.obstacles(layout,furniture['furniture']);walls,distance,doors,solids,sweeps=upper.geometry(layout);added=[];proof=[]
 for table in tables:
  unit=table['id'][:2];room='F0'+unit[0]+'_'+unit[1]+'_MAIN';r=spaces[room]['rect'];candidates=[]
  local=[-.08 if unit=='6C' else 0 if unit in ['5B','6A'] else .08,.745,0]
  for side in ['west','east','south','north']:
   axis=0 if side in ['west','east'] else 1;along=1-axis;inside=[0,0];inside[axis]=1 if side in ['west','south'] else -1;fixed=r[axis] if inside[axis]>0 else r[axis+2];yaw=math.atan2(-inside[0],-inside[1])
   for n in range(math.ceil((r[along]+.8)*10),math.floor((r[along+2]-.8)*10)+1):
    p=[0,0];p[axis]=fixed+.34*inside[axis];p[along]=n/10
    a=dict(id=table['id'],level=room[:3],space=room,position=[p[0],0,p[1]],yaw=yaw,kind='furniture');b=geo.volume(table['bounds'],a)
    c,s=math.cos(yaw),math.sin(yaw);pose=dict(position=[p[0]+c*local[0],.745,p[1]-s*local[0]],yaw=yaw);rb=geo.volume(BOUNDS[unit],pose)
    combined=[min(b[i],rb[i]) for i in range(3)]+[max(b[i+3],rb[i+3]) for i in range(3)];rect=[combined[0],combined[2],combined[3],combined[5]]
    if any(lev==a['level'] and geo.overlap(combined,v) for _,lev,v in volumes):continue
    if any(lev==a['level'] and any(doors.overlaps(doors.rect_polygon(rect),poly) for poly in poses) for lev,poses in sweeps):continue
    if any(x['level']==a['level'] and (x['kind']=='clearance' or x['id'].endswith('STANCE')) and light.distance([x['position'][0],x['position'][2]],rect)<.4 for x in anchors.values()):continue
    stance=[p[i]+1.1*inside[i] for i in [0,1]]
    if any(lev==a['level'] and v[1]<1.58 and v[4]>.02 and light.distance(stance,[v[0],v[2],v[3],v[5]])<.4 for _,lev,v in volumes):continue
    if not all(r[i]+.46<stance[i]<r[i+2]-.46 for i in [0,1]):continue
    if any(lev==a['level'] and light.distance(stance,box)<.4 for lev,box in solids):continue
    # Whole set and table remain inside this main room; window recesses remain free.
    if not (combined[0]>=r[0]+.07 and combined[2]>=r[1]+.07 and combined[3]<=r[2]-.07 and combined[5]<=r[3]-.07):continue
    wallpos=[p[i]-.25*inside[i] for i in [0,1]]
    try:distance.supporting_wall(layout,spaces[room],wallpos,yaw)
    except AssertionError:continue
    score=math.dist(stance,[(r[0]+r[2])/2,(r[1]+r[3])/2]);candidates.append((score,a,stance,combined,pose,rb))
  assert candidates,('no clear wireless table',unit)
  _,a,stance,b,pose,rb=min(candidates,key=lambda v:v[0]);added.extend([a,dict(a,id='DomesticRadio_'+unit+'_STANCE',position=[stance[0],0,stance[1]],yaw=a['yaw']+math.pi,kind='clearance')])
  volumes.append((a['id'],a['level'],b));solids.append((a['level'],[b[0],b[2],b[3],b[5]]))
  contact=module('design/astra/work/v2_surface_props_batch_01/build.py','radio_contact')
  rect=light.footprint(BOUNDS[unit],dict(position=local,yaw=0))
  for x in [rect[0],rect[2]]:
   for z in [rect[1],rect[3]]:assert contact.on_surface(table,[x,z],.745),(unit,'unsupported receiver')
  radios['receivers'].append(dict(id='DomesticRadio_'+unit,unit=unit,support=table['id'],position=local,yaw=0,bounds=BOUNDS[unit]))
  proof.append(dict(unit=unit,position=a['position'],yaw=a['yaw'],stance=stance,world_bounds=rb,support=a['id'],bounds=BOUNDS[unit]))
 layout['anchors']+=added;furniture['furniture']+=tables
 # Existing upper geometry plus all low installed service volumes, including
 # radiators and bookcases, must admit every old and new standing destination.
 for _,lev,b in volumes:
  if lev in ['F05','F06'] and b[1]<1.58 and b[4]>.02:solids.append((lev,[b[0],b[2],b[3],b[5]]))
 routes=[]
 for level in ['F05','F06']:
  boxes=[r for lev,r in solids if lev==level];floors=[s['rect'] for s in layout['spaces'] if s['level']==level]
  def clear(p):return all(any(r[0]<=p[0]+dx<=r[2] and r[1]<=p[1]+dz<=r[3] for r in floors) for dx,dz in [(0,0),(.38,0),(-.38,0),(0,.38),(0,-.38)]) and all(light.distance(p,r)>=.38-1e-6 for r in boxes)
  reached={(0,0)};queue=deque(reached);previous={};blocked=set()
  while queue:
   a=queue.popleft()
   for dx,dz in [(1,0),(-1,0),(0,1),(0,-1)]:
    b=(a[0]+dx,a[1]+dz)
    if b in reached or b in blocked:continue
    if clear([b[0]/10,b[1]/10]):reached.add(b);previous[b]=a;queue.append(b)
    else:blocked.add(b)
  for a in layout['anchors']:
   if a['level']!=level or not a['id'].endswith('STANCE'):continue
   p=[a['position'][0],a['position'][2]];goal=tuple(round(v*10) for v in p);assert goal in reached and clear(p),('unreachable standing destination',a['id'],p)
   route=[goal]
   while route[-1]!=(0,0):route.append(previous[route[-1]])
   points=[[x/10,z/10] for x,z in reversed(route)]+[p]
   for a1,b1 in zip(points,points[1:]):
    for t in [.25,.5,.75]:assert clear([a1[i]+(b1[i]-a1[i])*t for i in [0,1]])
   routes.append(dict(id=a['id'],level=level,points=points))
 outputs={LAYOUT:layout,FURN:furniture,RADIO:radios}
 for p,v in outputs.items():
  current=json.loads((ROOT/p).read_text())
  if p==RADIO and apply:
   # This batch promotes already checked receiver envelopes to shared source
   # metadata. Preserve every pre-existing placement field exactly.
   def bare(data):return dict(data,receivers=[{k:x for k,x in r.items() if k!='bounds'} for r in data['receivers']])
   assert bare(current) in [bare(base(p)),bare(v)]
  else:assert current in [base(p),v] if apply else current==v
 if apply:
  text=subprocess.check_output(['git','show',BASE+':'+LAYOUT],cwd=ROOT).decode();start=text.index('[',text.index('"anchors"'));_,size=json.JSONDecoder().raw_decode(text[start:]);end=start+size-1
  (ROOT/LAYOUT).write_bytes((text[:end].rstrip()+',\n'+',\n'.join('    '+json.dumps(a,separators=(',',':')) for a in added)+'\n  '+text[end:]).encode())
  write(ROOT/FURN,furniture,True);write(ROOT/RADIO,radios);write(ROOT/PROBES,dict(receivers=proof))
 else:assert json.loads((ROOT/PROBES).read_text())==dict(receivers=proof)
 write(OUT/'source_checks.json',dict(status='SOURCE_PASS',base=BASE,tables=6,receivers=6,added_anchors=12,route_destinations=len(routes),route_points=sum(len(r['points']) for r in routes),placements=proof));write(OUT/'routes.json',routes,True)
 print(json.dumps(dict(receivers=6,destinations=len(routes),placements=proof)))
if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('--apply',action='store_true');run(p.parse_args().apply)
