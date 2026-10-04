"""Rebind unaffected native reports after an append-only catalogue addition.

Refuses any change to an old material specification, generated table line,
bound native/export, fixture or report outside the two catalogue input hashes.
No asset is regenerated and no pre-existing stale binding is made current.
"""
from pathlib import Path
import argparse,copy,hashlib,json,subprocess

def digest(data):return hashlib.sha256(data.replace(b'\r\n',b'\n')).hexdigest()

def main():
 parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--base',required=True);parser.add_argument('--write',action='store_true');parser.add_argument('--out',required=True);args=parser.parse_args()
 root=Path(__file__).resolve().parents[2]
 def blob(path):return subprocess.check_output(['git','show',args.base+':'+path],cwd=root)
 table='game/data/runtime_material_sets.json';gd='game/scripts/generated/material_sets.gd'
 before=json.loads(blob(table));after=json.loads((root/table).read_bytes());added=set(after['materials'])-set(before['materials'])
 assert added=={'iron_blackened'} and after['visual_locks']==before['visual_locks']
 assert all(after['materials'][k]==v for k,v in before['materials'].items())
 assert set(before)==set(after) and {k:v for k,v in before.items() if k!='materials'}=={k:v for k,v in after.items() if k!='materials'}
 old_lines=blob(gd).decode().splitlines();new_lines=(root/gd).read_text().splitlines()
 assert [line for line in new_lines if not line.lstrip().startswith("'iron_blackened':")]==old_lines
 result=[];pending={};locations={}
 for path in sorted((root/'art/blender').glob('*_construction.json')):
  relative=path.relative_to(root).as_posix();document=json.loads(path.read_text());bindings=document.get('source_bindings',{})
  affected=[key for key in [table,gd] if key in bindings]
  if not affected:continue
  old_doc=json.loads(blob(relative));assert document==old_doc,relative
  for key in affected:assert bindings[key]==digest(blob(key)),(relative,key,'previously stale')
  # Every native and shipping asset in this family's own binding remains exact.
  assets=[key for key in bindings if Path(key).suffix in ['.blend','.glb']]
  own_native=root/'art/blender'/(path.stem.removesuffix('_construction')+'.blend')
  assets.append(own_native.relative_to(root).as_posix())
  for key in assets:assert (root/key).read_bytes()==blob(key),key
  if 'asset_sha256' in document:
   stem=path.stem.removesuffix('_construction');stem='city_shells' if stem=='city_closure' else stem
   asset=document['runtime']['asset'].replace('res://','game/') if 'runtime' in document else 'game/assets/props/'+stem+'.glb'
   assert hashlib.sha256((root/asset).read_bytes()).hexdigest()==document['asset_sha256'],asset
  fixture=root/'game/tests/fixtures'/('orison_'+path.stem.removesuffix('_construction')+'.json')
  assert json.loads(fixture.read_text())==document,fixture
  changed=copy.deepcopy(document)
  for key in affected:changed['source_bindings'][key]=digest((root/key).read_bytes())
  expected=copy.deepcopy(changed);expected['source_bindings']=document['source_bindings'];assert expected==document
  result.append({'report':relative,'fixture':fixture.relative_to(root).as_posix(),'changed_bindings':affected,'geometry_data_unchanged':True,'native_and_export_unchanged':True})
  pending[fixture.relative_to(root).as_posix()]=changed;locations[fixture.relative_to(root).as_posix()]=path
 assert len(result)==7
 encoded={};visiting=set()
 def render(key):
  if key in encoded:return encoded[key]
  assert key not in visiting,'Cyclic report dependency';visiting.add(key);document=pending[key]
  for binding in document['source_bindings']:
   if binding in pending:
    assert document['source_bindings'][binding]==digest(blob(binding)),'Previously stale dependent fixture'
    document['source_bindings'][binding]=digest(render(binding))
  encoded[key]=(json.dumps(document,indent=2)+'\n').encode('utf-8');visiting.remove(key);return encoded[key]
 for key in pending:render(key)
 # Finish all validation and dependency hashing before the first write.
 if args.write:
  for key,data in encoded.items():(root/key).write_bytes(data);locations[key].write_bytes(data)
 out=root/args.out;out.parent.mkdir(parents=True,exist_ok=True)
 out.write_text(json.dumps({'evidence_class':'INERT','base':args.base,'retained_materials':len(before['materials']),'added':sorted(added),'old_visual_locks_unchanged':True,'reports':result},indent=2)+'\n',encoding='utf-8',newline='\n')
 print('Catalogue append-only proof:',len(before['materials']),'retained materials;',len(result),'unmodified native families; refreshed input bindings' if args.write else 'dry run')

if __name__=='__main__':main()
