"""Rebind unaffected native reports after an append-only catalogue addition.

Refuses any change to an old material specification, generated table line,
bound native/export, fixture or report outside the catalogue input hashes.
No asset is regenerated and no pre-existing stale binding is made current.
"""
from pathlib import Path
import argparse,ast,copy,hashlib,json,subprocess

def digest(data):return hashlib.sha256(data.replace(b'\r\n',b'\n')).hexdigest()

def main():
 parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--base',required=True);parser.add_argument('--added',default='iron_blackened');parser.add_argument('--write',action='store_true');parser.add_argument('--out',required=True);parser.add_argument('--preserve-stale',action='store_true',help='Leave existing stale pins exact and list them in the proof');args=parser.parse_args()
 root=Path(__file__).resolve().parents[2]
 cache={}
 def blob(path):
  if path in cache:return cache[path]
  data=subprocess.check_output(['git','show',args.base+':'+path],cwd=root)
  if len(data)<1000000:cache[path]=data
  return data
 table='game/data/runtime_material_sets.json';gd='game/scripts/generated/material_sets.gd'
 before=json.loads(blob(table));after=json.loads((root/table).read_bytes());added=set(after['materials'])-set(before['materials'])
 assert added=={args.added} and after['visual_locks']==before['visual_locks']
 assert all(after['materials'][k]==v for k,v in before['materials'].items())
 assert set(before)==set(after) and {k:v for k,v in before.items() if k!='materials'}=={k:v for k,v in after.items() if k!='materials'}
 old_lines=blob(gd).decode().splitlines();new_lines=(root/gd).read_text().splitlines()
 assert [line for line in new_lines if not line.lstrip().startswith("'"+args.added+"':")]==old_lines
 for path in ['art/data/material_catalog.json','art/textures/catalog_mapping.json']:
  previous=json.loads(blob(path));current=json.loads((root/path).read_bytes())
  assert set(current)-set(previous)=={args.added},path
  assert {key:value for key,value in current.items() if key!=args.added}==previous,path
 generator='art/tools/generate_runtime_materials.py'
 previous_ast=ast.parse(blob(generator));current_ast=ast.parse((root/generator).read_bytes())
 policy=next(node.value for node in current_ast.body if isinstance(node,ast.Assign) and any(isinstance(target,ast.Name) and target.id=='RUNTIME_POLICY' for target in node.targets))
 index=next(i for i,key in enumerate(policy.keys) if isinstance(key,ast.Constant) and key.value==args.added)
 assert isinstance(policy.values[index],ast.Dict) and not policy.values[index].keys
 del policy.keys[index];del policy.values[index]
 assert ast.dump(current_ast)==ast.dump(previous_ast),'Generator changed beyond the appended empty runtime policy'
 def bound(document):
  if 'source_bindings' in document:return document['source_bindings']
  if 'bindings' in document:return document['bindings']
  return document.get('source_plan',{}).get('bindings',{})
 base_reports=set(subprocess.check_output(['git','ls-tree','-r','--name-only',args.base,'art/blender'],cwd=root).decode().splitlines())
 result=[];pending={};locations={};stale=[]
 for path in sorted((root/'art/blender').glob('*_construction.json')):
  relative=path.relative_to(root).as_posix()
  if relative not in base_reports:continue
  document=json.loads(path.read_text());bindings=bound(document)
  affected=[key for key in [table,gd,'art/data/material_catalog.json','art/textures/catalog_mapping.json','art/tools/generate_runtime_materials.py'] if key in bindings]
  if not affected:continue
  old_doc=json.loads(blob(relative));assert document==old_doc,relative
  for key in affected[:]:
   if bindings[key]!=digest(blob(key)):
    assert args.preserve_stale,(relative,key,'previously stale')
    stale.append({'report':relative,'binding':key,'retained_sha256':bindings[key]});affected.remove(key)
  # Every native and shipping asset in this family's own binding remains exact.
  assets=[key for key in bindings if Path(key).suffix in ['.blend','.glb']]
  own_native=root/'art/blender'/(path.stem.removesuffix('_construction')+'.blend')
  assets.append(own_native.relative_to(root).as_posix())
  for key in assets:assert (root/key).read_bytes()==blob(key),key
  if 'asset_sha256' in document:
   stem=path.stem.removesuffix('_construction');stem='city_shells' if stem=='city_closure' else stem
   asset=document['runtime']['asset'].replace('res://','game/') if 'runtime' in document else 'game/assets/props/'+stem+'.glb'
   assert hashlib.sha256((root/asset).read_bytes()).hexdigest()==document['asset_sha256'],asset
  family=path.stem.removesuffix('_construction')
  fixture=root/'game/tests/fixtures'/('orison_'+family+('_construction' if family in ['city_foundations','orison_ground'] else '')+'.json')
  if family=='orison_ground':fixture=root/'game/tests/fixtures/orison_ground_construction.json'
  assert json.loads(fixture.read_text())==document,fixture
  changed=copy.deepcopy(document)
  for key in affected:bound(changed)[key]=digest((root/key).read_bytes())
  expected=copy.deepcopy(changed)
  for key in affected:bound(expected)[key]=bindings[key]
  assert expected==document
  result.append({'report':relative,'fixture':fixture.relative_to(root).as_posix(),'changed_bindings':affected,'geometry_data_unchanged':True,'native_and_export_unchanged':True})
  pending[fixture.relative_to(root).as_posix()]=changed;locations[fixture.relative_to(root).as_posix()]=path
 # Early families use an inventory report or a fixture-only contract.
 for family,report in [('bar_stage',None),('bar_gallery',None)]:
  fixture='game/tests/fixtures/orison_'+family+'.json';document=json.loads((root/fixture).read_bytes())
  assert document==json.loads(blob(fixture)),fixture
  if report:assert json.loads((root/report).read_bytes())==document,report
  for key in ['art/blender/'+family+'.blend','game/assets/props/'+family+'.glb']:assert (root/key).read_bytes()==blob(key),key
  changed=copy.deepcopy(document);affected=[]
  for key in [table,gd,'art/data/material_catalog.json','art/textures/catalog_mapping.json','art/tools/generate_runtime_materials.py']:
   if key not in bound(document):continue
   if bound(document)[key]!=digest(blob(key)):
    assert args.preserve_stale,(fixture,key,'previously stale')
    stale.append({'report':report or fixture,'binding':key,'retained_sha256':bound(document)[key]});continue
   bound(changed)[key]=digest((root/key).read_bytes());affected.append(key)
  pending[fixture]=changed;locations[fixture]=root/report if report else None
  result.append({'report':report,'fixture':fixture,'changed_bindings':affected,'geometry_data_unchanged':True,'native_and_export_unchanged':True})
 assert result,'No existing catalogue-bound families found'
 aliases={path.relative_to(root).as_posix():key for key,path in locations.items() if path is not None}
 encoded={};visiting=set()
 def render(key):
  if key in encoded:return encoded[key]
  assert key not in visiting,'Cyclic report dependency';visiting.add(key);document=pending[key]
  for binding in bound(document):
   target=aliases.get(binding,binding)
   if target in pending:
    if bound(document)[binding]!=digest(blob(binding)):
     assert args.preserve_stale,'Previously stale dependent fixture'
     stale.append({'report':locations[key].relative_to(root).as_posix() if locations[key] else key,'binding':binding,'retained_sha256':bound(document)[binding]})
    else:bound(document)[binding]=digest(render(target))
  encoded[key]=(json.dumps(document,indent=2)+'\n').encode('utf-8');visiting.remove(key);return encoded[key]
 for key in pending:render(key)
 # Finish all validation and dependency hashing before the first write.
 if args.write:
  for key,data in encoded.items():
   (root/key).write_bytes(data)
   if locations[key]:locations[key].write_bytes(data)
 out=root/args.out;out.parent.mkdir(parents=True,exist_ok=True)
 out.write_text(json.dumps({'evidence_class':'INERT','base':args.base,'retained_materials':len(before['materials']),'added':sorted(added),'old_visual_locks_unchanged':True,'reports':result,'preexisting_stale_bindings_preserved':stale},indent=2)+'\n',encoding='utf-8',newline='\n')
 print('Catalogue append-only proof:',len(before['materials']),'retained materials;',len(result),'unmodified native families; refreshed input bindings' if args.write else 'dry run')

if __name__=='__main__':main()
