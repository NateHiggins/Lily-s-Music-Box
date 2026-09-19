"""Batch source-authored upper kitchen and resident tabletop objects."""
import argparse,ast,copy,hashlib,importlib.util,json,math,subprocess,zlib,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[4];OUT=Path(__file__).resolve().parent
BASE='2953357';TARGET='game/data/orison_v2/domestic_surface_props.json';PROBES='game/tests/data/v2_upper_surface_probes.json';UNITS=['5A','5B','5C','6A','6B','6C']
def mod(p,n):
 s=importlib.util.spec_from_file_location(n,ROOT/p);m=importlib.util.module_from_spec(s);s.loader.exec_module(m);return m
def load(p):return json.loads((ROOT/p).read_text(encoding='utf-8'))
def base(p):return json.loads(subprocess.check_output(['git','show',BASE+':'+p],cwd=ROOT).decode())
def write(p,v):p.write_bytes((json.dumps(v,indent=2)+'\n').encode())
def placements(records):
 rows=[]
 for unit in UNITS:
  for suffix,pos in [('k_kmug',[.62,.9195,-.09]),('k_kdishrack',[.43,.9195,0])]:
   if unit+'_'+suffix in records:rows.append((unit+'_'+suffix,unit,'F0'+unit[0]+'_'+unit+'_KITCHEN_SINK_01',pos,0))
 extras=[
 ('5A_model','5A_modtable',[0,.745,0]),('5A_papers1','5A_plantable',[-.81,.8,-.2]),('5A_papers2','5A_plantable',[-.81,.8,.24]),('5A_mug1','5A_plantable',[-.83,.8,-.49]),('5A_mug2','5A_planshelf',[.5,1.412,0]),
 ('5B_story_headphones','5B_din_t',[-.22,.735,0]),('5B_story_lead','5B_din_t',[.12,.735,0]),
 ('5C_story_solvents','5C_din_t',[-.3,.745,-.02]),('5C_story_studies','5C_din_t',[.25,.745,0]),
 ('6A_phones','6A_deskwall',[0,.77,-.9]),('6A_cans','6A_deskwall',[0,.77,-.3]),('6A_detail_capture_papers','6A_deskwall',[0,.77,.3]),('6A_detail_capture_mug','6A_deskwall',[0,.77,.9]),
 ('6B_story_draft','6B_din_t',[-.3,.745,-.06]),('6B_story_references','6B_din_t',[.05,.745,.05]),('6B_story_cold_coffee','6B_din_t',[.37,.745,.13]),
 ('6C_story_oddments','6C_din_t',[0,.735,-.2]),('6C_story_catalogues','6C_din_t',[.16,.735,.2])]
 rows += [(identity,identity[:2],support,pos,0) for identity,support,pos in extras]
 return rows

def run(apply=False):
 original=base(TARGET);layout=base('game/data/orison_v2_blockout.json');anchors={a['id']:a for a in layout['anchors']};spaces={s['id']:s for s in layout['spaces']}
 records={r['id']:r for f in base('game/data/building_layout.json')['floors'] for r in f.get('furniture',[])}
 plans=placements(records);extract=mod('design/astra/work/v2_apartment_batches_01/build.py','surface_extract');geo=mod('design/astra/work/v2_storage_tables_boards_batch_01/build.py','surface_volume');contact=mod('design/astra/work/v2_surface_props_batch_01/build.py','surface_contact');acc=mod('design/astra/work/v2_household_accessories_01/build.py','surface_pose');doors=mod('design/astra/work/v2_apartment_doors_batch_01/check.py','surface_door')
 tree=ast.parse((ROOT/extract.SOURCE).read_text(encoding='utf-8'));kinds={records[p[0]]['asm'] for p in plans};nodes=[]
 for node in tree.body:
  if isinstance(node,ast.ClassDef) and node.name=='MeshBuf':node.body=[m for m in node.body if isinstance(m,ast.FunctionDef) and m.name in extract.METHODS];nodes.append(node)
  elif isinstance(node,ast.ClassDef) and node.name=='Frame':nodes.append(node)
  elif isinstance(node,ast.FunctionDef) and node.name in {'asm_'+k for k in kinds}|{'case_wood','hash_str','_jit'}:nodes.append(node)
 ns={'math':math,'zlib':zlib};exec(compile(ast.Module(body=nodes,type_ignores=[]),extract.SOURCE,'exec'),ns)
 furniture=base('game/data/orison_v2/domestic_furniture.json')['furniture'];by_id={r['id']:r for r in furniture};fittings={r['id']:r for r in base('game/data/orison_v2/domestic_fittings.json')['fittings']}
 geo.load=lambda p:base(p)
 program=base('game/data/orison_v2/upper_floor_programs.json')['doors']
 obstacles=geo.obstacles(layout,furniture);materials=base('game/data/runtime_material_sets.json')['materials'];props=[];proof=[];probes=[]
 for identity,unit,support,position,yaw in plans:
  r=extract.furniture_record(identity,records,ns);vertices=[s['vertices'][i:i+3] for s in r['surfaces'] for i in range(0,len(s['vertices']),3)];bottom=min(v[1] for v in vertices)
  for s in r['surfaces']:
   assert s['material']=='glassish' or s['material'] in materials,(identity,s['material'])
   for i in range(1,len(s['vertices']),3):s['vertices'][i]-=bottom
  vertices=[s['vertices'][i:i+3] for s in r['surfaces'] for i in range(0,len(s['vertices']),3)]
  r['bounds']=[[min(v[i] for v in vertices) for i in range(3)],[max(v[i] for v in vertices) for i in range(3)]]
  r.update(unit=unit,support=support,position=position,yaw=yaw)
  pose=acc.world_pose(r,anchors);b=geo.volume(r['bounds'],pose);room=spaces[anchors[support]['space']]['rect']
  assert b[0]>=room[0]+.07 and b[2]>=room[1]+.07 and b[3]<=room[2]-.07 and b[5]<=room[3]-.07,('outside room',identity)
  local=geo.volume(r['bounds'],dict(position=position,yaw=yaw));corners=[[x,z] for x in [local[0],local[3]] for z in [local[2],local[5]]]
  if support in fittings:
   p=fittings[support]['properties'];assert p['fixture']=='kitchen_sink' and p['has_drainboard'] and not p['compact_kitchen'] and p['drain_side']==1
   assert abs(position[1]-.9195)<1e-6 and all(.315<=x<=.715 and -.22<=z<=.22 for x,z in corners),('drainboard support',identity)
  else:
   assert all(contact.on_surface(by_id[support],p,position[1]) for p in corners),('no horizontal support',identity,corners)
   # The drafting table already carries baked plans; new items must not cut
   # through any of those triangles above the chosen support plane.
   for s in by_id[support]['surfaces']:
    v=s['vertices']
    for i in range(0,len(v),9):
     tri=[v[i+j:i+j+3] for j in [0,3,6]]
     if min(p[1] for p in tri)<=position[1]+1e-6:continue
     rect=[min(p[0] for p in tri),min(p[2] for p in tri),max(p[0] for p in tri),max(p[2] for p in tri)]
     assert min(rect[2],local[3])<=max(rect[0],local[0])+1e-6 or min(rect[3],local[5])<=max(rect[1],local[2])+1e-6,('embedded support detail overlap',identity)
  for other,level,c in obstacles:
   if level==pose['level'] and other!=support:assert not geo.overlap(b,c),('object overlap',identity,other)
  for door in layout['doors']:
   if door['level']!=pose['level'] or door['id'] not in program:continue
   spec=program[door['id']];offset=doors.rotate([0,spec['mount_offset']],door['yaw'])
   for angle in range(0,101,2):
    poly=[[p[i]+offset[i] for i in [0,1]] for p in doors.leaf_polygon(door,spec['swing_out'],angle)]
    assert not doors.overlaps(doors.rect_polygon([b[0],b[2],b[3],b[5]]),poly),('room door hits object',identity,door['id'])
  obstacles.append((identity,pose['level'],b));props.append(r);proof.append(dict(id=identity,support=support,volume=b,contact=position[1],source_kind=records[identity]['asm']))
  probes.append(dict(id=identity,unit=unit,kind=r['kind'],support=support,room=anchors[support]['space']))
 data=copy.deepcopy(original);data['props']+=props
 assert load(TARGET) in [original,data] if apply else load(TARGET)==data,'unexpected source'
 if apply:
  (ROOT/TARGET).write_bytes((json.dumps(data,separators=(',',':'))+'\n').encode());write(ROOT/PROBES,dict(props=probes))
 else:assert load(PROBES)==dict(props=probes)
 write(OUT/'source_checks.json',dict(status='SOURCE_PASS',base=BASE,added=len(props),total=len(data['props']),source_triangles=sum(len(s['vertices'])//9 for r in props for s in r['surfaces']),placements=proof))
 print('PASS',len(props),'source-authored objects;',len(data['props']),'total surface props')
if __name__=='__main__':
 sys.modules['build']=sys.modules[__name__];p=argparse.ArgumentParser();p.add_argument('--apply',action='store_true');run(p.parse_args().apply)
