"""Resident display boards, floor equipment and specialist comparison sets."""
import ast,json,math,zlib,subprocess,importlib.util,argparse
from pathlib import Path
from collections import deque
ROOT=Path(__file__).resolve().parents[4];OUT=Path(__file__).resolve().parent;BASE='3d615be'
LAYOUT='game/data/orison_v2_blockout.json';FURN='game/data/orison_v2/domestic_furniture.json';PROBES='game/tests/data/v2_upper_equipment_probes.json'
IDS=['5A_pins1','5A_pins2','5A_floorstack','5B_k_hob_radio0','5B_k_hob_radio1','5B_story_radio','5C_story_colorboard','6A_tripod','6A_soft1','6A_soft2','6A_gearcrate','6A_coil1','6A_coil2','6C_story_old_radio']
def base(p):return json.loads(subprocess.check_output(['git','show',BASE+':'+p],cwd=ROOT).decode())
def module(p,n):
 s=importlib.util.spec_from_file_location(n,ROOT/p);m=importlib.util.module_from_spec(s);s.loader.exec_module(m);return m
def write(p,v,compact=False):p.write_bytes((json.dumps(v,**({'separators':(',',':')} if compact else {'indent':2}))+'\n').encode())
geo=module('design/astra/work/v2_storage_tables_boards_batch_01/build.py','equipment_volumes');geo.load=base
light=module('design/astra/work/v2_apartment_lighting_batch_01/build.py','equipment_points')
upper=module('design/astra/work/v2_upper_lighting_01/build.py','equipment_routes');upper.base=base
contact=module('design/astra/work/v2_surface_props_batch_01/build.py','equipment_contact')
def extract():
 previous=module('design/astra/work/v2_apartment_batches_01/build.py','equipment_assembly');nodes=[]
 records={r['id']:r for f in base('game/data/building_layout.json')['floors'] for r in f.get('furniture',[])}
 records['5B_comparison_table']=dict(id='5B_comparison_table',asm='table_rect',L=1.15,W=.46,mat='wood_dark')
 functions={'asm_'+records[i]['asm'] for i in IDS}|{'case_wood','hash_str','_jit','asm_table_rect'}
 for n in ast.parse((ROOT/previous.SOURCE).read_text(encoding='utf-8')).body:
  if isinstance(n,ast.ClassDef) and n.name=='MeshBuf':n.body=[f for f in n.body if isinstance(f,ast.FunctionDef) and f.name in previous.METHODS];nodes.append(n)
  elif isinstance(n,ast.ClassDef) and n.name=='Frame':nodes.append(n)
  elif isinstance(n,ast.FunctionDef) and n.name in functions:nodes.append(n)
 ns=dict(math=math,zlib=zlib);exec(compile(ast.Module(body=nodes,type_ignores=[]),previous.SOURCE,'exec'),ns)
 result=[previous.furniture_record(i,records,ns) for i in ['5B_comparison_table']+IDS]
 for row in result:
  if row['kind']=='radio':row['mechanism']=dict(id=row['id'],asm='radio');row['bounds']=[[-.24,-.03,-.19],[.24,.31,.15]]
  if row['kind']=='tripod':
   # The source camera's rear plate is rendered as ground glass, sharing the
   # existing projector lens family rather than adding an emissive display.
   for surface in row['surfaces']:
    if surface['material']=='screen':surface['material']='milk_glass'
  if row['kind'] in ['tripod','softbox']:
   # Stand feet have slanted ends a few millimetres below the authored zero.
   bottom=row['bounds'][0][1]
   for surface in row['surfaces']:
    for n in range(1,len(surface['vertices']),3):surface['vertices'][n]-=bottom
   row['bounds'][0][1]=0;row['bounds'][1][1]-=bottom
 return result
PLACEMENTS={
 '5B_comparison_table':('F05_B_KITCHEN',[-8.985,0,10.65],-math.pi/2,[-7.95,0,10.65]),
 '5A_pins1':('F05_A_MAIN',[-15.56,1.05,-5.45],-math.pi/2,[-14.2,0,-5.45]),
 '5A_pins2':('F05_A_STUDY',[-11.11,1.15,-11.55],-math.pi/2,[-9.8,0,-11.35]),
 '5A_floorstack':('F05_A_MAIN',[-14.9,0,-4.6],math.radians(5),[-14.2,0,-5.5]),
 '5C_story_colorboard':('F05_C_MAIN',[-5.51,1.16,7.5],-math.pi/2,[-4.3,0,7.5]),
 '6A_tripod':('F06_A_MAIN',[-14.2,0,-4.6],-math.pi/2,[-15.1,0,-4.6]),
 '6A_soft1':('F06_A_MAIN',[-14.3,0,-5.6],-math.pi/3,[-13.2,0,-5.4]),
 '6A_soft2':('F06_A_MAIN',[-14.3,0,-3.7],-2*math.pi/3,[-13.2,0,-3.8]),
 '6A_gearcrate':('F06_A_MAIN',[-15.1,0,-1.6],math.radians(5),[-14.35,0,-2.0]),
 '6A_coil1':('F06_A_MAIN',[-13.2,0,-4.5],math.radians(30),[-12.2,0,-4.6]),
 '6A_coil2':('F06_A_MAIN',[-14.2,0,-3.1],math.radians(240),[-13.6,0,-3.0]),
}
SUPPORTS={
 '5B_k_hob_radio0':('5B_comparison_table',[-.27,.745,0]),
 '5B_k_hob_radio1':('5B_comparison_table',[.27,.745,0]),
 '5B_story_radio':('5B_din_t',[0,.735,-.32]),
 '6C_story_old_radio':('6C_din_t',[-.20,.735,.15]),
}
def run(apply=False):
 layout=base(LAYOUT);furniture=base(FURN);additions=extract();anchors={a['id']:a for a in layout['anchors']};spaces={s['id']:s for s in layout['spaces']};rows={r['id']:r for r in furniture['furniture']+additions};added=[];probes=[]
 for row in additions:
  identity=row['id']
  if identity in SUPPORTS:
   support,local=SUPPORTS[identity];a=anchors[support];c,s=math.cos(a['yaw']),math.sin(a['yaw'])
   room=a['space'];pos=[a['position'][0]+c*local[0]+s*local[2],a['position'][1]+local[1],a['position'][2]-s*local[0]+c*local[2]];yaw=a['yaw'];stance=anchors[support+'_STANCE']['position']
   row['support_source']=dict(id=support,position=local)
   # The case base, rather than its projecting control envelope, bears weight.
   for x in [local[0]-.19,local[0]+.19]:
    for z in [local[2]-.11,local[2]+.11]:assert contact.on_surface(rows[support],[x,z],local[1]),('radio base unsupported',identity)
  else:room,pos,yaw,stance=PLACEMENTS[identity]
  a=dict(id=identity,space=room,level=room[:3],position=pos,yaw=yaw,kind='furniture');st=dict(a,id=identity+'_STANCE',position=stance,yaw=math.atan2(-(pos[0]-stance[0]),-(pos[2]-stance[2])),kind='clearance')
  added.extend([a,st]);anchors[identity]=a;anchors[st['id']]=st
  probes.append(dict(id=identity,kind=row['kind'],unit=identity[:2],room=room,bounds=row['bounds'],stance=st['id'],support=row.get('support_source',{})))
 layout['anchors']+=added;furniture['furniture']+=additions
 volumes=geo.obstacles(layout,furniture['furniture']);new_ids={r['id'] for r in additions};new=[v for v in volumes if v[0] in new_ids]
 def navload(p):
  v=furniture if p==FURN else base(p)
  if p==FURN:v=dict(v,furniture=[r for r in v['furniture'] if r['kind']!='cupboard'])
  return v
 upper.load=navload;walls,distance,doors,solids,sweeps=upper.geometry(layout);wall_list=walls.owned(layout)
 for identity,level,b in new:
  a=anchors[identity];r=spaces[a['space']]['rect'];row=rows[identity];support=row.get('support_source',{}).get('id')
  assert b[0]>=r[0]+.07-1e-6 and b[2]>=r[1]+.07-1e-6 and b[3]<=r[2]-.07+1e-6 and b[5]<=r[3]-.07+1e-6,('equipment outside room',identity)
  for other,lev,v in volumes:
   if lev==level and other not in [identity,support] and rows.get(other,{}).get('support_source',{}).get('id')!=identity:assert not geo.overlap(b,v),('equipment overlap',identity,other,b,v)
  for lev,poses in sweeps:
   if lev==level:assert not any(doors.overlaps(doors.rect_polygon([b[0],b[2],b[3],b[5]]),p) for p in poses),('equipment door sweep',identity)
  if row['kind']=='pinboard':
   backing=[]
   for w in wall_list:
    axis=0 if w['axis']=='x' else 2;fixed=2-axis
    if w['level']!=level or w['start']>b[axis] or w['end']<b[axis+3]:continue
    gap=min(abs(b[fixed]-w['fixed']),abs(b[fixed+3]-w['fixed']))
    if not .069<=gap<=.091:continue
    if any(min(c['end'],b[axis+3])>max(c['start'],b[axis]) and min(b[4],c['sill']+c['height'])>max(b[1],c['sill']) for c in walls.apertures(layout,w)):continue
    backing.append(w['owner']+':'+w['side'])
   assert backing,('display board lacks solid backing',identity)
  stance=anchors[identity+'_STANCE']['position'];target=[a['position'][0],a['position'][1]+(b[4]-b[1])*.5,a['position'][2]]
  eye=[stance[0],1.41,stance[2]];assert math.dist(eye,target)<2.1,('equipment outside viewing reach',identity)
  for n in range(101):
   p=[eye[i]+(target[i]-eye[i])*n/100 for i in range(3)]
   for other,lev,v in volumes:
    if lev==level and other!=identity:assert not all(v[i]+1e-5<p[i]<v[i+3]-1e-5 for i in range(3)),('equipment sightline blocked',identity,other)
 # Conservatively include every service/receiver/bookcase as navigation solids.
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
   p=[a['position'][0],a['position'][2]];goal=tuple(round(v*10) for v in p);assert goal in reached and clear(p),('unreachable equipment/old stance',a['id'],p)
   route=[goal]
   while route[-1]!=(0,0):route.append(previous[route[-1]])
   points=[[x/10,z/10] for x,z in reversed(route)]+[p]
   for a1,b1 in zip(points,points[1:]):
    for t in [.25,.5,.75]:assert clear([a1[i]+(b1[i]-a1[i])*t for i in [0,1]])
   routes.append(dict(id=a['id'],level=level,points=points))
 for p,v in [(LAYOUT,layout),(FURN,furniture)]:
  current=json.loads((ROOT/p).read_text());assert current in [base(p),v] if apply else current==v
 if apply:
  text=subprocess.check_output(['git','show',BASE+':'+LAYOUT],cwd=ROOT).decode();start=text.index('[',text.index('"anchors"'));_,size=json.JSONDecoder().raw_decode(text[start:]);end=start+size-1
  (ROOT/LAYOUT).write_bytes((text[:end].rstrip()+',\n'+',\n'.join('    '+json.dumps(a,separators=(',',':')) for a in added)+'\n  '+text[end:]).encode());write(ROOT/FURN,furniture,True);write(ROOT/PROBES,dict(equipment=probes))
 else:assert json.loads((ROOT/PROBES).read_text())==dict(equipment=probes)
 write(OUT/'source_checks.json',dict(status='SOURCE_PASS',base=BASE,equipment=14,supports=1,new_anchors=len(added),route_destinations=len(routes),route_points=sum(len(r['points']) for r in routes),probes=probes));write(OUT/'routes.json',routes,True)
 print('SOURCE_PASS',len(additions),'assemblies;',len(routes),'destinations')
if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('--apply',action='store_true');run(p.parse_args().apply)
