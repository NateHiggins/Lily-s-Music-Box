"""Find unintended native stock intersections before source installation."""
from pathlib import Path
import bpy,bmesh,json,hashlib,argparse,sys
from mathutils import Vector
from mathutils.bvhtree import BVHTree
ROOT=Path(__file__).resolve().parents[1]
parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('--build-dir',type=Path,required=True)
parser.add_argument('--out',type=Path,required=True)
args=parser.parse_args(sys.argv[sys.argv.index('--')+1:])
P=args.build_dir;r=json.loads((P/'native_review.json').read_text());s=json.loads((P/'refit_supported_native.json').read_text());p=json.loads((P/'refit_pipes_native.json').read_text());native=P/r['native_file']
assert not r['failures'] and hashlib.sha256(native.read_bytes()).hexdigest()==r['native_sha256']
bpy.ops.wm.open_mainfile(filepath=str(native));families={};new=set()
for row in r['passages']+r['main_supports']+s['parts']:
 for name in row['parts']:families[name]=row['id'];new.add(name)
for row in r['tailpieces']:families[row['id']]=row['id'];new.add(row['id'])
for name in p['new_stocks']:new.add(name)
trees={};rows=[]
for obj in bpy.context.scene.objects:
 if obj.type!='MESH':continue
 corners=[obj.matrix_world@Vector(v) for v in obj.bound_box];bounds=[min(v[i] for v in corners) for i in range(3)]+[max(v[i] for v in corners) for i in range(3)]
 rows.append(dict(name=obj.name,obj=obj,bounds=bounds))
def tree(row):
 if row['name'] not in trees:
  bm=bmesh.new();bm.from_mesh(row['obj'].data);bm.transform(row['obj'].matrix_world);bm.normal_update();trees[row['name']]=BVHTree.FromBMesh(bm);bm.free()
 return trees[row['name']]
contacts=[];tested=set()
for a in rows:
 if a['name'] not in new:continue
 for b in rows:
  key=tuple(sorted((a['name'],b['name'])))
  if a is b or key in tested or not all(a['bounds'][i]<=b['bounds'][i+3]+1e-7 and b['bounds'][i]<=a['bounds'][i+3]+1e-7 for i in range(3)):continue
  tested.add(key);hits=tree(a).overlap(tree(b))
  if not hits:continue
  expected=None
  if families.get(a['name']) is not None and families.get(a['name'])==families.get(b['name']):expected='Closed stocks intentionally welded/seated within one fitting'
  for first,second in [(a['name'],b['name']),(b['name'],a['name'])]:
   if '__Coupling_' in first and first.split('__Coupling_')[0]==second:expected='Specified annular stock coupling seated over its own continuous pipe'
   if any(first==row['id']+'__Band' and second==row['branch'] for row in s['parts']):expected='Specified clamp band seated on its own pipe'
   if any(first==row['id']+'__Band' and second=='Restricted_Main_H-D_Extension' for row in r['main_supports']):expected='Specified riser clamp seated on its own main'
   if any(first in [port['branch'],port['branch']+'__Coupling_00_a'] and second in [port['main']] for port in p['ports']):expected='Bored branch/main socket, separately air-probed in native generation'
   if first=='Restricted_Main_H-D_ExtensionUnion' and second in ['Main_H-D','Restricted_Main_H-D_Extension']:expected='Annular extension union seated over its two main ends'
   if first.startswith('Main_H-D__Cap') and second=='Restricted_Main_H-D_Extension':expected='Original blind cap relocated to the extended open main end'
  contacts.append(dict(a=a['name'],b=b['name'],triangle_pairs=len(hits),expected_joinery=expected))
unexpected=[row for row in contacts if row['expected_joinery'] is None]
args.out.parent.mkdir(parents=True,exist_ok=True)
args.out.write_text(json.dumps(dict(evidence_class='INERT',scope='Native triangle intersections among new stocks and retained native heating distribution. Expected mechanical seating listed explicitly. Does not prove containment, full composed architecture fit or runtime/human acceptance.',native_sha256=r['native_sha256'],reviewer_sha256_lf=hashlib.sha256(Path(__file__).read_bytes().replace(b'\r\n',b'\n')).hexdigest(),candidate_pairs=len(tested),contacts=contacts,unexpected=unexpected),indent=2)+'\n')
print('NATIVE ASSEMBLY CONTACTS',len(contacts),'unexpected',len(unexpected),flush=True)

if unexpected:raise RuntimeError("Unexplained native assembly intersections")
