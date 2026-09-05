"""Source geometry and placement checks; no native engine invocation."""
import hashlib,json,math,subprocess,sys
from pathlib import Path
from extract import generate
ROOT=Path(__file__).resolve().parents[4]; OUT=Path(__file__).parent
BASE='3a4ffbd7907fa6e3320388eceaf776c650be639b'
def read(p): return json.loads((ROOT/p).read_text())
data=read('game/data/orison_v2/domestic_furniture.json')
assert data==generate(), 'Extracted geometry differs from production assembly source'
prior=json.loads(subprocess.check_output(['git','show',BASE+':game/data/orison_v2/domestic_furniture.json'],cwd=ROOT))
assert data['furniture'][:3]==prior['furniture']
material_text=(ROOT/'game/scripts/generated/material_sets.gd').read_text()
for record in data['furniture']:
 for surface in record['surfaces']:
  key={'floor_oak':'oak_quartered','fabric_cool':'linen','fabric_green':'linen'}.get(surface['material'],surface['material'])
  assert key=='glassish' or ("'"+key+"':") in material_text,key
layout=read('game/data/orison_v2_blockout.json')
anchors={r['id']:r for r in layout['anchors']}; spaces={r['id']:r for r in layout['spaces']}
boxes=[]
placements={r['id']:r for r in read('design/astra/work/v2_f03_storage_01/placements.json')}
for source_record in data['furniture']:
 r={**source_record,**placements[source_record['id']]}
 assert anchors[r['id']]['position']==r['position'] and anchors[r['id']]['yaw']==r['yaw']
 assert anchors[r['id']]['space']==r['space']
 assert anchors[r['id']+'_STANCE']['position']==r['stance']
 lo,hi=r['bounds']; c,s=math.cos(r['yaw']),math.sin(r['yaw'])
 corners=[(r['position'][0]+c*x+s*z,r['position'][2]-s*x+c*z) for x in (lo[0],hi[0]) for z in (lo[2],hi[2])]
 box=[min(v[0] for v in corners),min(v[1] for v in corners),max(v[0] for v in corners),max(v[1] for v in corners)]
 room=spaces[r['space']]['rect']
 assert room[0]+.07<=box[0]<box[2]<=room[2]-.07,(r['id'],box)
 assert room[1]+.07<=box[1]<box[3]<=room[3]-.07,(r['id'],box)
 boxes.append((r['id'],box))
 for surface in r['surfaces']:
  vs,ns=surface['vertices'],surface['normals']
  assert len(vs)==len(ns) and len(vs)%9==0 and all(math.isfinite(x) for x in vs+ns)
  for i in range(0,len(vs),9):
   a,b,c=[vs[j:j+3] for j in (i,i+3,i+6)]
   u=[b[j]-a[j] for j in range(3)]; v=[c[j]-a[j] for j in range(3)]
   cross=[u[1]*v[2]-u[2]*v[1],u[2]*v[0]-u[0]*v[2],u[0]*v[1]-u[1]*v[0]]
   n=ns[i:i+3]
   assert abs(sum(x*x for x in n)-1)<1e-6
   assert sum(cross[j]*n[j] for j in range(3)) < -1e-12, 'Clockwise front face versus outward normal'
# Existing fittings are source-estimated bounds; new furniture bounds derive from mesh plus hull.
for r in read('design/astra/work/v2_f03_fittings_01/placements.json'):
 boxes.append((r['id'],r['closed_footprint']))
for i,(ident,a) in enumerate(boxes):
 for other,b in boxes[i+1:]:
  assert min(a[2],b[2])<=max(a[0],b[0]) or min(a[3],b[3])<=max(a[1],b[1]),(ident,other)
for station in layout['capsule_stations']:
 if station['level']!='F03': continue
 x,_,z=station['position']
 for ident,b in boxes:
  dx=max(b[0]-x,0,x-b[2]); dz=max(b[1]-z,0,z-b[3])
  assert dx*dx+dz*dz>=.33**2,(station['id'],ident,dx,dz)
# Sample both full leaves through the production 92-degree swing, with
# a conservative 0.10 m thickness including raised panels and knobs.
wardrobe=placements['3B_aw_wardrobe']
for side in [-1,1]:
 hx=wardrobe['position'][0]+side*(1.3*.5-.035)
 hz=wardrobe['position'][2]-.305
 for degree in range(93):
  angle=math.radians(degree)*-side
  c,s=math.cos(angle),math.sin(angle)
  for station in layout['capsule_stations']:
   if station['level']!='F03': continue
   x,_,z=station['position']; dx,dz=x-hx,z-hz
   # inverse of Godot yaw
   lx,lz=c*dx-s*dz,s*dx+c*dz
   lo,hi=sorted([0,-side*(1.3*.5-.047)])
   ex=max(lo-lx,0,lx-hi); ez=max(-.075-lz,0,lz-.025)
   assert ex*ex+ez*ez>=.33**2,('wardrobe sweep',side,degree,station['id'])
old=json.loads(subprocess.check_output(['git','show',BASE+':game/data/orison_v2_blockout.json'],cwd=ROOT))
owned={'F03_CAPSULE_3B_ALCOVE'}
for table,records in old.items():
 if not isinstance(records,list): assert records==layout[table]; continue
 current={r['id']:r for r in layout[table]} if records and isinstance(records[0],dict) and 'id' in records[0] else None
 if current is None: assert records==layout[table]; continue
 for r in records:
  if r['id'] not in owned: assert current[r['id']]==r,(table,r['id'])
assert len(layout['anchors'])==len(old['anchors'])+8
assert len(layout['capsule_stations'])==len(old['capsule_stations'])+4
paths=['game/data/orison_v2/domestic_furniture.json','game/data/orison_v2_blockout.json',
 'game/scripts/building/orison_v2_domestic_furniture.gd','game/scripts/building/orison_v2_wardrobe.gd',
 'game/tests/orison_v2_connected_world_test.gd']
sys.path.insert(0,'C:/Users/nate_/.cache/orison-source-tools/gdtoolkit')
from gdtoolkit.parser import parser
for p in paths:
 if p.endswith('.gd'): parser.parse((ROOT/p).read_text())
protected=['game/scripts/building/building_root_selector.gd','game/scripts/building/building_root.gd',
 'game/data/building_layout.json','art/data/building_layout.json','art/blender/scripts/build_orison.py',
 'game/scripts/props/baked_furniture_interaction.gd']
protected += [f'game/assets/building/floor_{f}.{e}' for f in ['01','02','03','04','05','06','b1'] for e in ['gltf','bin']]
subprocess.run(['git','diff','--exit-code',BASE,'--',*protected],cwd=ROOT,check=True)
receipt=dict(status='SOURCE_CHECKS_PASS_NATIVE_UNRUN',base_head=BASE,native_godot_started=False,
 checks=['deterministic source extraction','finite geometry and unit normals','clockwise triangle winding',
 'mesh and hull bounds inside finished rooms','disjoint furniture and fittings','all F03 standing capsules clear of added furniture and fittings',
 'named anchor transforms','wardrobe 0..92 degree sampled leaf sweep versus standing capsules','all surface material keys explicitly supported','previous three meshes unchanged','older layout records preserved except wardrobe approach station','GDScript syntax','protected source unchanged'],
 limits='No native compile, actual collision query, flush audio or input proof, visual approval or persistence acceptance.',
 files={p:hashlib.sha256((ROOT/p).read_bytes()).hexdigest() for p in paths})
(OUT/'source_checks.json').write_text(json.dumps(receipt,indent=2)+'\n',newline='\n')
print(receipt['status'])
