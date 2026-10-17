import json,sys,hashlib,shutil
from pathlib import Path
sys.path.insert(0,str(Path.cwd()/'tools'))
from audit_orison_v2_completeness import runtime_receipt_errors
root=Path.cwd();work=root/'tmp/v2-front-trim-20261017/final-contracts';tag=sys.argv[1]
assert tag in ('dumbwaiter','roof')
packet=work/(tag+'_checkpoint');r=json.loads((packet/'runtime_contract.json').read_text());w=json.loads((work/(tag+'_checkpoint.log.receipt.json')).read_text())
errors=runtime_receipt_errors(r,root)
if r.get('failures')!=0 or not r.get('checks') or any(c.get('ok') is not True for c in r['checks']):errors.append('failed/missing checks')
c=r.get('contracts',{}).get('physical_interaction',{})
if c.get('executed') is not True or c.get('status')!='PASS':errors.append('physical interaction not passed')
deps=r.get('source',{}).get('test_dependencies',{})
if not deps:errors.append('missing parent-source binding')
for p,h in deps.items():
 if hashlib.sha256((root/p).read_bytes().replace(b'\r\n',b'\n')).hexdigest()!=h:errors.append('stale dependency '+p)
if w.get('log',{}).get('script_error_count') or w.get('log',{}).get('fail_count'):errors.append('wrapper recorded script errors/failures')
e=w.get('execution',{})
if not e.get('completed') or e.get('exit_code')!=0 or e.get('timed_out') is not False:errors.append('wrapper not completed successfully')
for kind in ('stdout','stderr'):
 if hashlib.sha256(Path(w['log'][kind]).read_bytes()).hexdigest()!=w['log'][kind+'_sha256']:errors.append(kind+' changed')
out=dict(result='FAIL' if errors else 'PASS',scope=r['scope'],checks=len(r['checks']),errors=errors)
(work/(tag+'_qualification.json')).write_text(json.dumps(out,indent=2)+'\n');print(json.dumps(out))
if errors:sys.exit(1)
dst=root/'art/renders/orison_v2/front_trim_install_20261017'/tag;dst.mkdir(exist_ok=True)
for p in packet.iterdir():
 if p.is_file():shutil.copy2(p,dst/p.name)
for suffix in ('','.stderr','.receipt.json'):shutil.copy2(work/(tag+'_checkpoint.log'+suffix),dst.parent/(tag+'.log'+suffix))
shutil.copy2(work/(tag+'_qualification.json'),dst.parent/(tag+'_qualification.json'))
