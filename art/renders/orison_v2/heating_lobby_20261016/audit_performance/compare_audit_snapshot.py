from pathlib import Path
import json,os,subprocess,sys,time
root=Path.cwd();work=root/'tmp/v2-heating-next-20261016'
work.mkdir(parents=True,exist_ok=True)
(work/'audit_before_snapshot.py').write_bytes(subprocess.check_output(['git','show','9e3d04f0:tools/audit_orison_v2_completeness.py']))
env=dict(os.environ,PYTHONPATH=str(root/'tools'),PYTHONHASHSEED='0')
results={}
for tag,script in [('before',work/'audit_before_snapshot.py'),('after',root/'tools/audit_orison_v2_completeness.py')]:
 start=time.monotonic()
 run=subprocess.run([sys.executable,str(script),'--root',str(root),'--json'],capture_output=True,env=env)
 (work/('audit_'+tag+'.json')).write_bytes(run.stdout)
 (work/('audit_'+tag+'.stderr')).write_bytes(run.stderr)
 results[tag]={'exit':run.returncode,'elapsed_s':round(time.monotonic()-start,3)}
 if run.returncode not in (0,2): raise SystemExit(str(results)+str(run.stderr[:1000]))
a=json.loads((work/'audit_before.json').read_bytes());b=json.loads((work/'audit_after.json').read_bytes())
results['identical_payload']=a==b
results['result']='PASS' if a==b and results['before']['exit']==results['after']['exit'] else 'FAIL'
(work/'audit_snapshot_comparison.json').write_text(json.dumps(results,indent=2)+'\n',encoding='utf-8',newline='\n')
print(json.dumps(results))
raise SystemExit(0 if results['result']=='PASS' else 1)
