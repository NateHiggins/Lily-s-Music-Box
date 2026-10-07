"""Counterfactual regression: old four spacer points must fail on the fitted rack."""
from pathlib import Path
import hashlib,json,subprocess,sys
from unittest.mock import patch
R=Path.cwd();sys.path.insert(0,str(R/'art/blender/scripts'))
import audit_native_support_dependents as audit
base=subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip()
relative='game/tests/fixtures/orison_hardware_tools.json';target=(R/relative).resolve()
old=subprocess.check_output(['git','show',base+':'+relative]);read=Path.read_text;digest=audit.digest
def old_read(path,*args,**kwargs):return old.decode('utf-8') if path.resolve()==target else read(path,*args,**kwargs)
def old_digest(path):return hashlib.sha256(old.replace(b'\r\n',b'\n')).hexdigest() if path.resolve()==target else digest(path)
out=R/'tmp/v2-finish-review/context-repair-support-counterfactual.json'
sys.argv=['test','--','--changed-family','hardware_stock','--out',str(out)]
with patch.object(Path,'read_text',old_read),patch.object(audit,'digest',old_digest):
 try:audit.main()
 except AssertionError:pass
 else:raise AssertionError('old missing supports were not detected')
d=json.loads(out.read_text(encoding='utf-8'));assert len(d['failures'])==4 and all(r['consumer_family']=='hardware_tools' for r in d['failures']),d['failures']
d['counterfactual']={'baseline':base,'in_memory_fixture_override':relative,'fixture_sha256':hashlib.sha256(old.replace(b'\r\n',b'\n')).hexdigest(),'expected_failures':4,'source_files_modified':False}
out.write_text(json.dumps(d,indent=2)+'\n',encoding='utf-8',newline='\n')
print('SUPPORT AUDIT REGRESSION: detected exactly four missing old spacer bearings; no source mutation')
