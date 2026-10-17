import hashlib,json,shutil,sys
from pathlib import Path
root=Path.cwd();sys.path.insert(0,str(root/'tools'))
from audit_orison_v2_completeness import runtime_receipt_errors
work=root/'tmp/v2-front-trim-20261017/final-contracts';packet=work/'firstslice_checkpoint'
r=json.loads((packet/'runtime_authority_receipt.json').read_bytes());w=json.loads((work/'firstslice_checkpoint.log.receipt.json').read_bytes())
errors=runtime_receipt_errors(r,root)
e=w.get('execution',{})
if e.get('completed') is not True or e.get('exit_code')!=0 or e.get('timed_out') is not False:errors.append('wrapper did not complete successfully')
if w.get('log',{}).get('script_error_count') or w.get('log',{}).get('fail_count'):errors.append('wrapper has script errors or failures')
for kind in ['stdout','stderr']:
 if hashlib.sha256(Path(w['log'][kind]).read_bytes()).hexdigest()!=w['log'][kind+'_sha256']:errors.append(kind+' hash changed')
report={'result':'FAIL' if errors else 'PASS','errors':errors,'checks':len(r.get('checks',[]))}
(work/'firstslice_qualification.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8',newline='\n');print(json.dumps(report))
if errors:raise SystemExit(1)
dest=root/'art/renders/orison_v2/front_trim_install_20261017/firstslice';dest.mkdir(exist_ok=True)
shutil.copy2(packet/'runtime_authority_receipt.json',dest/'runtime_authority_receipt.json')
shutil.copy2(packet/'runtime_authority_receipt.json',root/'art/renders/orison_v2/first_slice_contract_20261011/runtime_authority_receipt.json')
for suffix in ['','.stderr','.receipt.json']:shutil.copy2(work/('firstslice_checkpoint.log'+suffix),dest.parent/('firstslice.log'+suffix))
shutil.copy2(work/'firstslice_qualification.json',dest.parent/'firstslice_qualification.json')
