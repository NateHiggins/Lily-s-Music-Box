#!/usr/bin/env python3
"""Refresh catalogue provenance only after proving a strictly additive material change.

No asset, recipe, runtime policy for existing keys, or visual evidence is rebuilt.
This creates an INERT comparison receipt, not new acceptance evidence.
"""
import argparse,ast,hashlib,json,subprocess
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]

def digest(data):return hashlib.sha256(data.replace(b'\r\n',b'\n')).hexdigest()

def unchanged_stale_binding(prior, current, literal, expected):
 """A stale receipt stays stale only if its entire baseline payload survives."""
 return prior == current and prior.get('source_bindings', {}).get(literal) == expected
def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--base',required=True);p.add_argument('--key',required=True,action='append');p.add_argument('--out',type=Path,required=True);p.add_argument('--apply',action='store_true');p.add_argument('--preserve-baseline-drift',action='store_true',help='Leave already-stale baseline bindings stale and list them; never renew their evidence');a=p.parse_args();keys=set(a.key)
 base=subprocess.check_output(['git','rev-parse',a.base],cwd=ROOT,text=True).strip()
 paths=['art/data/material_catalog.json','art/textures/catalog_mapping.json','art/data/runtime_material_sets.json','game/data/runtime_material_sets.json','game/scripts/generated/material_sets.gd','art/tools/generate_runtime_materials.py']
 before={s:subprocess.check_output(['git','show',base+':'+s],cwd=ROOT).replace(b'\r\n',b'\n') for s in paths};after={s:(ROOT/s).read_bytes().replace(b'\r\n',b'\n') for s in paths}
 for s in paths[:4]:
  old=json.loads(before[s]);new=json.loads(after[s])
  if 'runtime_material_sets' in s:
   assert old['visual_locks']==new['visual_locks'] and old['schema']==new['schema'],s
   old=old['materials'];new=new['materials']
  assert set(new)-set(old)==keys and {k:v for k,v in new.items() if k not in keys}==old,('nonadditive catalogue edit',s)
 gd=paths[4];lines=after[gd].decode().splitlines(keepends=True);added=[s for s in lines if any(s.lstrip().startswith(repr(key)+':') for key in keys)]
 assert len(added)==len(keys) and ''.join(s for s in lines if s not in added).encode()==before[gd],'existing generated runtime code changed'
 generator=paths[5];old=ast.parse(before[generator]);new=ast.parse(after[generator]);found=False
 for node in ast.walk(new):
  if isinstance(node,ast.Assign) and any(isinstance(t,ast.Name) and t.id=='RUNTIME_POLICY' for t in node.targets):
   pairs=[(k,v) for k,v in zip(node.value.keys,node.value.values) if not (isinstance(k,ast.Constant) and k.value in keys)]
   assert len(pairs)==len(node.value.keys)-len(keys);node.value.keys=[x[0] for x in pairs];node.value.values=[x[1] for x in pairs];found=True
 assert found and ast.dump(old)==ast.dump(new),'existing generator behavior changed'
 # Existing shipped maps must still equal the base, including unbound families.
 old_runtime=json.loads(before['game/data/runtime_material_sets.json'])
 texture_paths=sorted({'game/assets/building/textures/'+f for m in old_runtime['materials'].values() for f in m['files']})
 for s in texture_paths:
  original=subprocess.check_output(['git','show',base+':'+s],cwd=ROOT)
  assert (ROOT/s).read_bytes()==original,('existing texture changed',s)
 hashes={s:(digest(before[s]),digest(after[s])) for s in paths};updates=[];pending=[];documents={};original_bytes={};base_documents={}
 for folder,pattern in [('game/tests/fixtures','orison_*.json'),('art/blender','*_construction.json')]:
  for file in sorted((ROOT/folder).glob(pattern)):
   data=json.loads(file.read_text(encoding='utf-8'))
   if not isinstance(data,dict) or not data.get('source_bindings'):continue
   s=file.relative_to(ROOT).as_posix();documents[s]=data;original_bytes[s]=file.read_bytes()
 def base_bytes(s):
  if s not in base_documents:base_documents[s]=subprocess.check_output(['git','show',base+':'+s],cwd=ROOT).replace(b'\r\n',b'\n')
  return base_documents[s]
 serialized={};active=set();preserved_drift=[]
 def resolve(s):
  if s in serialized:return serialized[s]
  assert s not in active,('cyclic fixture bindings',s)
  active.add(s);data=documents[s];bindings=data['source_bindings'];changed=[]
  for literal,expected in bindings.items():
   rel=literal.replace('\\','/');new_hash=None;allowed=set()
   if rel in hashes:
    old_hash,new_hash=hashes[rel];allowed.add(old_hash)
   elif rel in documents:
    new_bytes=resolve(rel);new_hash=digest(new_bytes)
    if expected!=new_hash:
     previous=base_bytes(rel);old=json.loads(previous);current=json.loads(new_bytes)
     assert {k:v for k,v in old.items() if k!='source_bindings'}=={k:v for k,v in current.items() if k!='source_bindings'},('dependency changed beyond provenance',s,rel)
     allowed.update([digest(previous),digest(original_bytes[rel])])
   if new_hash is None or expected==new_hash:continue
   if expected not in allowed and a.preserve_baseline_drift:
    prior=json.loads(base_bytes(s));unchanged=json.loads(original_bytes[s])
    assert unchanged_stale_binding(prior,unchanged,literal,expected),('drift is not an unchanged baseline fixture',s,literal)
    preserved_drift.append({'path':s,'binding':literal,'stale_sha256':expected,'base_source_sha256':hashes[rel][0] if rel in hashes else digest(base_bytes(rel)),'candidate_source_sha256':new_hash})
    continue
   assert expected in allowed,('older or unrelated drift; requires review',s,literal)
   bindings[literal]=new_hash;changed.append(literal)
  result=(json.dumps(data,indent=2)+'\n').encode() if changed else original_bytes[s]
  serialized[s]=result;active.remove(s)
  if changed:
   pending.append((ROOT/s,result));updates.append({'path':s,'before_sha256':digest(original_bytes[s]),'after_sha256':digest(result),'bindings_only':changed,'asset_sha256_unchanged':data.get('asset_sha256')})
  return result
 for s in documents:resolve(s)
 # All proofs complete before the first mutation. No source geometry is rewritten.
 if a.apply:
  for file,updated in pending:file.write_bytes(updated)
 report={'evidence_class':'INERT','base':base,'new_key':a.key,'applied':a.apply,'existing_runtime_texture_files_unchanged':len(texture_paths),'shared_sources':{s:{'before':x,'after':y} for s,(x,y) in hashes.items()},'updates':updates,'preserved_baseline_drift':preserved_drift,'scope':'Strictly additive material catalogue provenance. Existing geometry and evidence are unchanged; this does not grant fresh visual/runtime acceptance. Listed pre-existing stale bindings remain stale.'}
 a.out.parent.mkdir(parents=True,exist_ok=True);a.out.write_text(json.dumps(report,indent=2)+'\n',newline='\n')
 print(json.dumps({'updated':len(updates),'applied':a.apply,'unchanged_texture_files':len(texture_paths)}))
if __name__=='__main__':main()
