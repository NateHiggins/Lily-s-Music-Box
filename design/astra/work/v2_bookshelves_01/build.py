"""Place the entire authored bookshelf roster in developed V2 households."""
import json, math, subprocess, importlib.util, argparse, re
from pathlib import Path
ROOT=Path(__file__).resolve().parents[4]; OUT=Path(__file__).resolve().parent
BASE='1ddf9d7'; LAYOUT='game/data/orison_v2_blockout.json'; DATA='game/data/orison_v2/bookshelves.json'
def base(p):return json.loads(subprocess.check_output(['git','show',BASE+':'+p],cwd=ROOT).decode())
def mod(p,n):
 s=importlib.util.spec_from_file_location(n,ROOT/p);m=importlib.util.module_from_spec(s);s.loader.exec_module(m);return m
def write(p,v):p.write_bytes((json.dumps(v,indent=2)+'\n').encode())
g=mod('design/astra/work/v2_storage_tables_boards_batch_01/build.py','shelf_volumes');g.load=lambda p: {'shelves':[]} if p.endswith('/bookshelves.json') else base(p)
l=mod('design/astra/work/v2_apartment_lighting_batch_01/build.py','shelf_distance')
w=mod('design/astra/work/v2_apartment_walls_batch_01/build.py','shelf_walls')
d=mod('design/astra/work/v2_apartment_doors_batch_01/check.py','shelf_doors')
BOUNDS={'plain':[[-.38,0,-.146],[.38,1.30,.14]],'repaired':[[-.371,0,-.131],[.377,1.22,.146]],'sectional':[[-.43,0,-.17],[.43,1.54,.171]]}
def run(apply=False):
 layout=base(LAYOUT);spaces={s['id']:s for s in layout['spaces']};anchors={a['id']:a for a in layout['anchors']}
 markers=[m for f in base('game/data/building_layout.json')['floors'] for m in f['markers'] if m.get('kind')=='bookshelf']
 volumes=g.obstacles(layout,base('game/data/orison_v2/domestic_furniture.json')['furniture']);walls=w.owned(layout);sweeps=[]
 text=(ROOT/'game/scripts/building/orison_v2_domestic_doors.gd').read_text()
 specs={i:dict(swing_out=o=='true',mount_offset=0) for i,o in re.findall(r'"([A-Z0-9_]+)": \{"kind": "[a-z_]+", "swing_out": (true|false)',text)}
 specs.update(base('game/data/orison_v2/upper_floor_programs.json')['doors'])
 for door in layout['doors']:
  if door['id'] not in specs:continue
  spec=specs[door['id']];off=d.rotate([0,spec.get('mount_offset',0)],door['yaw'])
  sweeps.append((door['level'],[[[p[i]+off[i] for i in [0,1]] for p in d.leaf_polygon(door,spec['swing_out'],n)] for n in range(101)]))
 added=[];rows=[];proof=[]
 for m in markers:
  unit=m['unit'];room='F0'+unit[0]+'_'+unit[1]+'_MAIN';space=spaces[room];r=space['rect'];bounds=BOUNDS[m['variant']];candidates=[]
  for side in ['west','east','south','north']:
   axis=0 if side in ['west','east'] else 1;along=1-axis;inward=[0,0];inward[axis]=1 if side in ['west','south'] else -1
   fixed=r[axis] if inward[axis]>0 else r[axis+2];yaw=math.atan2(inward[0],inward[1]);depth=-bounds[0][2]
   for n in range(math.ceil((r[along]+.6)*10),math.floor((r[along+2]-.6)*10)+1):
    p=[0,0];p[axis]=fixed+(.085+depth)*inward[axis];p[along]=n/10
    a=dict(id=m['id'],level=space['level'],space=room,position=[p[0],0,p[1]],yaw=yaw,kind='interaction');b=g.volume(bounds,a);rect=[b[0],b[2],b[3],b[5]]
    if any(lev==a['level'] and g.overlap(b,v) for _,lev,v in volumes):continue
    if any(lev==a['level'] and any(d.overlaps(d.rect_polygon(rect),poly) for poly in poses) for lev,poses in sweeps):continue
    if any(x['level']==a['level'] and (x['kind']=='clearance' or x['id'].endswith('STANCE')) and l.distance([x['position'][0],x['position'][2]],rect)<.4 for x in anchors.values()):continue
    stance=[p[i]+1.0*inward[i] for i in [0,1]]
    if any(lev==a['level'] and v[1]<1.58 and v[4]>.02 and l.distance(stance,[v[0],v[2],v[3],v[5]])<.4 for _,lev,v in volumes):continue
    if not all(r[i]+.46<stance[i]<r[i+2]-.46 for i in [0,1]):continue
    # The whole back must land against solid wall, including above windowsills.
    matching=[]
    for wall in walls:
     ax=0 if wall['axis']=='x' else 2
     if wall['level']!=a['level'] or abs(wall['fixed']-fixed)>1e-6 or wall['axis']!=('z' if axis==0 else 'x'):continue
     if wall['start']>b[ax] or wall['end']<b[ax+3]:continue
     if any(min(c['end'],b[ax+3])>max(c['start'],b[ax]) and c['sill']<b[4] for c in w.apertures(layout,wall)):continue
     matching.append(wall['owner']+':'+wall['side'])
    if not matching:continue
    try:g.check_routes_and_doors(layout,[(a['id'],a['level'],b)])
    except AssertionError:continue
    candidates.append((math.dist(p,[m['pos'][0],-m['pos'][1]]),a,stance,b,matching))
  assert candidates,('no clear bookshelf wall',unit)
  _,a,stance,b,backing=min(candidates,key=lambda c:c[0]);added += [a,dict(a,id=a['id']+'_STANCE',position=[stance[0],0,stance[1]],yaw=a['yaw'],kind='clearance')]
  volumes.append((a['id'],a['level'],b));anchors[a['id']]=a
  rows.append(dict(id=m['id'],unit=unit,owner=m['owner'],style=m['variant'],canonical_book=m.get('canonical_book',''),bounds=bounds))
  proof.append(dict(id=a['id'],position=a['position'],yaw=a['yaw'],stance=stance,wall_supports=backing,volume=b))
 layout['anchors']+=added
 samples,doors=g.check_routes_and_doors(layout,[(p['id'],'F0'+r['unit'][0],p['volume']) for p,r in zip(proof,rows)])
 data=dict(schema_version=1,shelves=rows)
 if apply:
  current=json.loads((ROOT/LAYOUT).read_text());assert current in [base(LAYOUT),layout]
  text=subprocess.check_output(['git','show',BASE+':'+LAYOUT],cwd=ROOT).decode();start=text.index('[',text.index('"anchors"'));_,size=json.JSONDecoder().raw_decode(text[start:]);end=start+size-1
  (ROOT/LAYOUT).write_bytes((text[:end].rstrip()+',\n'+',\n'.join('    '+json.dumps(a,separators=(',',':')) for a in added)+'\n  '+text[end:]).encode());write(ROOT/DATA,data)
 else:
  assert json.loads((ROOT/LAYOUT).read_text())==layout
  assert json.loads((ROOT/DATA).read_text())==data
 write(OUT/'source_checks.json',dict(status='SOURCE_PASS',base=BASE,shelves=len(rows),added_anchors=len(added),existing_route_samples=samples,lower_door_sweeps=doors,all_door_sweeps=len(sweeps),placements=proof))
 print(json.dumps(dict(shelves=len(rows),placements=proof)))
if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('--apply',action='store_true');run(p.parse_args().apply)
