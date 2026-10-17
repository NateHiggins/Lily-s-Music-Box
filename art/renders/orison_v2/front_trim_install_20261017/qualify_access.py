import json,sys,shutil,hashlib
from pathlib import Path
sys.path.insert(0,str(Path.cwd()/'tools'))
from spatial_access_evidence import validate
from audit_orison_v2_completeness import runtime_inputs_sha256
from v2_surface_evidence import inputs
root=Path.cwd(); work=root/'tmp/v2-front-trim-20261017/final-contracts'
cases={'apartments': 'apartment_access_20261012','remaining':'remaining_apartments_20261013'}
tag=sys.argv[1];packet=work/(tag+'_checkpoint')
r=json.loads((packet/'runtime_contract.json').read_text());w=json.loads((work/(tag+'_checkpoint.log.receipt.json')).read_text())
errors=validate(r,root,runtime_inputs_sha256(root),inputs(root)['sha256'])
if w.get('log',{}).get('script_error_count') or w.get('log',{}).get('fail_count'):errors.append('wrapper recorded script errors/failures')
e=w.get('execution',{})
if not e.get('completed') or e.get('exit_code')!=0 or e.get('timed_out') is not False:errors.append('wrapper did not pass')
for kind in ('stdout','stderr'):
 if hashlib.sha256(Path(w['log'][kind]).read_bytes()).hexdigest()!=w['log'][kind+'_sha256']:errors.append(kind+' changed')
out={'result':'FAIL' if errors else 'PASS','errors':errors,'rooms':len(r['contracts']['room_access']['rooms']),'checks':len(r['checks'])}
(work/(tag+'_qualification.json')).write_text(json.dumps(out,indent=2)+'\n');print(json.dumps(out))
if errors:sys.exit(1)
archive=root/'art/renders/orison_v2/front_trim_install_20261017'/tag;archive.mkdir(exist_ok=True)
for p in packet.iterdir():
 if p.is_file():shutil.copy2(p,archive/p.name)
shutil.copy2(packet/'runtime_contract.json',root/'art/renders/orison_v2'/cases[tag]/'runtime_contract.json')
for suffix in ('','.stderr','.receipt.json'):shutil.copy2(work/(tag+'_checkpoint.log'+suffix),archive.parent/(tag+'.log'+suffix))
shutil.copy2(work/(tag+'_qualification.json'),archive.parent/(tag+'_qualification.json'))
