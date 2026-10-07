"""Check actual native bearings consumed from changed fabrication families.

Runs inside Blender, before import. INERT fit QA; no exports or runtime proof.
Only contacts whose owner has a changed native replacement are in scope.
"""
from pathlib import Path
import argparse,hashlib,json,sys
import bpy
from mathutils import Vector
from mathutils.bvhtree import BVHTree

ROOT=next(p for p in Path(__file__).resolve().parents if (p/'game/project.godot').is_file())
def digest(path):
 data=path.read_bytes();return hashlib.sha256(data if path.suffix in ['.blend','.glb'] else data.replace(b'\r\n',b'\n')).hexdigest()

def main():
 parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--changed-family',action='append',required=True);parser.add_argument('--out',type=Path,required=True)
 args=parser.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
 output=args.out.resolve();assert output.is_relative_to(ROOT/'tmp')
 output.parent.mkdir(parents=True,exist_ok=True)
 fixtures={p.stem.removeprefix('orison_'):(p,json.loads(p.read_text(encoding='utf-8'))) for p in (ROOT/'game/tests/fixtures').glob('orison_*.json')}
 owners={};bindings={};trees={};checks=[];failures=[]
 bpy.ops.wm.read_factory_settings(use_empty=True)
 for family in args.changed_family:
  path,f=fixtures[family];native=ROOT/f'art/blender/{family}.blend'
  for p in [path,native]:bindings[p.relative_to(ROOT).as_posix()]=digest(p)
  assemblies={part['assembly'] for part in f['parts']};aliases={identity:identity for identity in assemblies}
  plan_path=ROOT/f'art/data/{family}/source_plan.json'
  if plan_path.is_file():
   plan=json.loads(plan_path.read_text(encoding='utf-8'));bindings[plan_path.relative_to(ROOT).as_posix()]=digest(plan_path)
   for group in plan.get('groups',[]):
    sources=group.get('sources',[])
    if sources and sources[0] in assemblies:aliases.update({identity:sources[0] for identity in sources})
  wanted={part['name'] for part in f['parts']}
  with bpy.data.libraries.load(str(native),link=False) as (src,dst):dst.objects=[n for n in src.objects if n in wanted]
  assert len(dst.objects)==len(wanted),(family,'missing native parts')
  linked={}
  for obj in dst.objects:bpy.context.scene.collection.objects.link(obj);linked[obj.name]=obj
  bpy.context.view_layer.update()
  for identity in assemblies:
   parts=[linked[p['name']] for p in f['parts'] if p['assembly']==identity]
   trees[(family,identity)]=[BVHTree.FromPolygons([o.matrix_world@v.co for v in o.data.vertices],[list(p.vertices) for p in o.data.polygons],epsilon=0.) for o in parts]
  for alias,identity in aliases.items():
   assert alias not in owners,('ambiguous support owner',alias)
   owners[alias]=(family,identity)
 for family,(path,f) in fixtures.items():
  if not isinstance(f,dict):continue
  for contact in f.get('contacts',[]):
   if not isinstance(contact,dict) or contact.get('owner') not in owners:continue
   bindings[path.relative_to(ROOT).as_posix()]=digest(path)
   p=contact['point'];d=contact['direction'];at=Vector((p[0],-p[2],p[1]));direction=Vector((d[0],-d[2],d[1])).normalized();hits=[]
   owner=owners[contact['owner']]
   for tree in trees[owner]:
    hit,normal,_,_=tree.ray_cast(at+direction*.010,-direction,.020)
    if hit is not None and normal.dot(direction)>.9:hits.append((hit-at).length)
   distance=min(hits) if hits else None
   row={'consumer_family':family,'assembly':contact['assembly'],'owner':contact['owner'],'native_owner_family':owner[0],'label':contact['label'],'point':p,'distance_m':distance,'passed':distance is not None and distance<.00003}
   checks.append(row)
   if not row['passed']:failures.append(row)
 result={'evidence_class':'INERT','changed_families':args.changed_family,'bindings':bindings,'checks':checks,'failures':failures,'scope':'Actual owner-side native bearing only, 30 micrometre bound. No floor/source owners, reciprocal embedded fixings, gameplay or runtime acceptance.'}
 output.write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8',newline='\n')
 print('NATIVE SUPPORT DEPENDENTS:',len(checks),'checks;',len(failures),'failures',flush=True)
 assert not failures,failures

if __name__=='__main__':main()
