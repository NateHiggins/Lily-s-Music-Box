"""Refresh explicit changed context provenance; all affected native QA is rerun."""
from pathlib import Path
import hashlib,json,subprocess
R=Path.cwd();BASE=subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip();cache={};original_cache={}
def digest(data,path):return hashlib.sha256(data if Path(path).suffix in ['.blend','.glb','.png','.bin'] else data.replace(b'\r\n',b'\n')).hexdigest()
def original(path):
 if path not in original_cache:original_cache[path]=subprocess.check_output(['git','show',BASE+':'+path])
 return original_cache[path]
def current_digest(path):
 p=R/path;stat=p.stat();key=(path,stat.st_mtime_ns,stat.st_size)
 if key not in cache:cache[key]=digest(p.read_bytes(),path)
 return cache[key]
allowed=set(json.loads((R/'tmp/v2-finish-review/context-repair-changed-scripts.json').read_text(encoding='utf-8')))
for family in ['laundry_fittings','news_fittings','hardware_stock']:
 allowed.update([f'art/blender/{family}.blend',f'game/assets/props/{family}.glb',f'game/data/orison_v2/{family}.json',f'game/tests/fixtures/orison_{family}.json'])
reports=list((R/'art/blender').glob('*.json'))+list((R/'game/tests/fixtures').glob('orison_*.json'))
updates=[];prior_path=R/'tmp/v2-finish-review/context-repair-rebinding.json'
if prior_path.exists():updates=json.loads(prior_path.read_text(encoding='utf-8'))['updates']
for iteration in range(15):
 changed=0
 for p in reports:
  s=p.read_text(encoding='utf-8');d=json.loads(s)
  if not isinstance(d,dict) or not d.get('source_bindings'):continue
  relative=p.relative_to(R).as_posix();local=[]
  for path,bound in d['source_bindings'].items():
   actual=current_digest(path)
   if actual==bound:continue
   if path not in allowed:
    assert digest(original(path),path)!=bound,('unexpected new drift',relative,path)
    continue
   needle=json.dumps(path)+': '+json.dumps(bound);assert s.count(needle)==1,(relative,path)
   s=s.replace(needle,json.dumps(path)+': '+json.dumps(actual));local.append({'path':path,'before':bound,'after':actual})
  if local:
   p.write_text(s,encoding='utf-8',newline='\n');allowed.add(relative);updates.append({'report':relative,'bindings':local});changed+=1
 if not changed:break
else:raise AssertionError('dependency bindings did not converge')
prior_path.write_text(json.dumps({'evidence_class':'INERT','baseline':BASE,'scope':'Changed native context or inspector provenance only. No reuse of context acceptance; affected inspectors are rerun.','updates':updates},indent=2)+'\n',encoding='utf-8',newline='\n')
print('Refreshed',len(updates),'report updates; explicit binding closure converged')
