import hashlib,json,sys,shutil
from pathlib import Path
sys.path.insert(0,str(Path.cwd()/'tools'))
from audit_orison_v2_completeness import runtime_inputs_sha256
root=Path.cwd(); work=root/'tmp/v2-front-trim-20261017/final-contracts'; packet=work/'save_checkpoint'
r=json.loads((packet/'runtime_contract.json').read_text()); w=json.loads((work/'save_checkpoint.log.receipt.json').read_text())
errors=[]
if w.get('log',{}).get('script_error_count') or w.get('log',{}).get('fail_count'):errors.append('wrapper recorded script errors/failures')
if r.get('schema_version')!=2 or r.get('evidence_kind')!='runtime_contract' or r.get('selector')!='v2' or r.get('production_runtime') is not True:errors.append('invalid contract identity')
for label,data in [('test',r),('wrapper',w)]:
 e=data.get('execution',{})
 if not e.get('completed') or e.get('exit_code')!=0 or e.get('timed_out') is not False:errors.append(label+' execution not passed')
for name in ('production_composition','direct_manipulation','save_reconstruction'):
 c=r.get('contracts',{}).get(name,{})
 if c.get('executed') is not True or c.get('status')!='PASS':errors.append(name+' not passed')
source=r.get('source',{})
if source.get('runtime_inputs_sha256')!=runtime_inputs_sha256(root):errors.append('runtime source stale')
for path,digest in source.get('test_sources',{}).items():
 actual=hashlib.sha256((root/path).read_bytes().replace(b'\r\n',b'\n')).hexdigest()
 if actual!=digest:errors.append('test source stale: '+path)
if len(source.get('test_sources',{}))!=3:errors.append('missing inherited test sources')
if r.get('failures') or not r.get('observations') or any(row.get('ok') is not True for row in r['observations']):errors.append('failed or missing observations')
for kind in ('stdout','stderr'):
 p=Path(w['log'][kind])
 if hashlib.sha256(p.read_bytes()).hexdigest()!=w['log'][kind+'_sha256']:errors.append('wrapper log changed: '+kind)
out=dict(result='FAIL' if errors else 'PASS',scope=r['scope'],checks=r['checks'],errors=errors)
(work/'save_qualification.json').write_text(json.dumps(out,indent=2)+'\n')
print(json.dumps(out))
if errors:sys.exit(1)
dst=root/'art/renders/orison_v2/front_trim_install_20261017/save';dst.mkdir(exist_ok=True)
for p in packet.iterdir():
 if p.is_file():shutil.copy2(p,dst/p.name)
for suffix in ('','.stderr','.receipt.json'):shutil.copy2(work/('save_checkpoint.log'+suffix),dst.parent/('save.log'+suffix))
shutil.copy2(work/'save_qualification.json',dst.parent/'save_qualification.json')
