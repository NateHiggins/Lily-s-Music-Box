"""Six installed radiators backed by the full authored heating demand roster."""
import argparse
import copy
import importlib.util
import json
import math
from pathlib import Path

ROOT=Path(__file__).resolve().parents[4]
OUT=Path(__file__).resolve().parent
BASE='7c9a536'
LAYOUT='game/data/orison_v2_blockout.json'
TARGET='game/data/orison_v2/heating.json'
# Semantic source ID, room, position, yaw, operator stance and approach.
PLACEMENTS=[
 ('F02_A_RADIATOR_01','F02_A_MAIN',[-14.5,.75,2.8],0,[-14.5,0,1.85],[-13.5,1.85]),
 ('F03_A_RADIATOR_01','F03_A_MAIN',[-11,.75,-3.58],math.pi,[-11,0,-2.65],[-10.4,-2.65]),
 ('F04_A_RADIATOR_01','F04_A_MAIN',[15.4,.75,-3],math.pi/2,[14.5,0,-3],[13.5,-2.8]),
 ('F04_B_RADIATOR_01','F04_B_MAIN',[-11.6,.75,3.15],0,[-11.6,0,2.2],[-12.3,2.2])]

def load(path):return json.loads((ROOT/path).read_text(encoding='utf-8'))
def module(path,name):
 spec=importlib.util.spec_from_file_location(name,ROOT/path);m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m);return m

def geometry(layout):
 geo=module('design/astra/work/v2_storage_tables_boards_batch_01/build.py','heating_geometry')
 doors=module('design/astra/work/v2_apartment_doors_batch_01/check.py','heating_doors')
 anchors={a['id']:a for a in layout['anchors']};spaces={s['id']:s for s in layout['spaces']}
 obstacles=geo.obstacles(layout,load('game/data/orison_v2/domestic_furniture.json')['furniture'])
 volumes=[r for r in obstacles if r[0] in {p[0] for p in PLACEMENTS}]
 assert len(volumes)==4
 approach_samples=0;sight_samples=0;stance_checks=0
 for identity,level,b in volumes:
  a=anchors[identity];room=spaces[a['space']]['rect']
  assert b[0]>=room[0]+.07 and b[2]>=room[1]+.07 and b[3]<=room[2]-.07 and b[5]<=room[3]-.07,('radiator outside room',identity)
  for other,floor,c in obstacles:
   if floor==level and identity!=other:assert not geo.overlap(b,c),('radiator overlap',identity,other)
  for stance in layout['anchors']:
   if stance['level']==level and stance.get('kind')=='clearance':
    assert doors.distance([stance['position'][0],stance['position'][2]],doors.rect_polygon([b[0],b[2],b[3],b[5]]))>=.38,('radiator blocks stance',identity,stance['id'])
    stance_checks+=1
  entry=next(p for p in PLACEMENTS if p[0]==identity);target=[entry[4][0],entry[4][2]];start=entry[5]
  steps=max(1,math.ceil(math.dist(start,target)/.025))
  for n in range(steps+1):
   p=[start[i]+(target[i]-start[i])*n/steps for i in range(2)]
   for other,floor,c in obstacles:
    if floor==level and c[1]<1.574 and c[4]>.02:assert doors.distance(p,doors.rect_polygon([c[0],c[2],c[3],c[5]]))>=.38,('blocked radiator approach',identity,other)
   approach_samples+=1
  # Production turn-valve target, including the installed .75m drop.
  c,s=math.cos(a['yaw']),math.sin(a['yaw']);x,z=-.53,-.02
  valve=[a['position'][0]+c*x+s*z,.39,a['position'][2]-s*x+c*z]
  eye=[target[0],1.41,target[1]];assert math.dist(eye,valve)<2.1
  for n in range(101):
   p=[eye[i]+(valve[i]-eye[i])*n/100 for i in range(3)]
   for other,floor,c in obstacles:
    if floor==level and identity!=other:assert not all(c[i]<p[i]<c[i+3] for i in range(3)),('blocked valve sightline',identity,other)
   sight_samples+=1
 samples,sweeps=geo.check_routes_and_doors(layout,volumes)
 return dict(route_samples=samples,door_sweeps=sweeps,stance_checks=stance_checks,approach_samples=approach_samples,valve_sightline_samples=sight_samples)

def build(apply=False):
 merge=module('design/astra/work/v2_apartment_batches_01/build.py','heating_merge')
 layout=load(LAYOUT);old_count=len(layout['anchors']);added=[]
 for identity,room,position,yaw,stance,_ in PLACEMENTS:
  added.append(dict(id=identity,level=room[:3],space=room,position=position,yaw=yaw,kind='interaction'))
  added.append(dict(id=identity.replace('_01','_STANCE'),level=room[:3],space=room,position=stance,yaw=yaw+math.pi,kind='clearance'))
 owned={a['id'] for a in added}
 layout['anchors']=merge.merge_rows([a for a in layout['anchors'] if a['id'] not in owned],added)
 checks=geometry(layout)
 network=[copy.deepcopy(r) for f in load('game/data/building_layout.json')['floors'] for r in f.get('markers',[]) if r.get('kind')=='radiator']
 assert len(network)==23 and len({r['id'] for r in network})==23
 installed=[dict(id=r['id'],unit=r['unit'],riser=r['riser'],sections=10 if r['unit']=='2B' else r['sections']) for r in network if r.get('unit') in ['2A','2B','3A','3B','4A','4B']]
 data=dict(schema_version=1,network=network,installed=installed)
 if (ROOT/TARGET).exists():assert load(TARGET)==data,'changed heating manifest'
 if apply:
  (ROOT/TARGET).write_text(json.dumps(data,indent=2)+'\n',encoding='utf-8')
  p=ROOT/LAYOUT;text=p.read_text(encoding='utf-8')
  for anchor in added:
   anchor_start=text.index('[',text.index('"anchors"'))
   token='"'+anchor['id']+'"'
   if token in text[anchor_start:]:
    start=text.rfind('{',anchor_start,text.index(token,anchor_start));_,length=json.JSONDecoder().raw_decode(text[start:])
    text=text[:start]+json.dumps(anchor,separators=(',',':'))+text[start+length:]
   else:
    _,length=json.JSONDecoder().raw_decode(text[anchor_start:]);end=anchor_start+length-1
    text=text[:end].rstrip()+',\n    '+json.dumps(anchor,separators=(',',':'))+'\n  '+text[end:]
  p.write_text(text,encoding='utf-8')
 receipt=dict(status='SOURCE_PASS_RUNTIME_PENDING',godot='NOT_RUN',base=BASE,network_demands=23,installed=installed,new_emitters=4,checks=checks,
  limits='Full roster preserves logical demand for seventeen unbuilt emitters. Six installed controls; no complete building claim. 2B ten-section accepted apparatus retained despite legacy nine-section marker. Source estimates only; physics, balance execution, listening, visuals, save and lifetime pending.')
 OUT.mkdir(parents=True,exist_ok=True);(OUT/'receipt.json').write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf-8')
 print(json.dumps(receipt))

if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('--apply',action='store_true');build(p.parse_args().apply)
