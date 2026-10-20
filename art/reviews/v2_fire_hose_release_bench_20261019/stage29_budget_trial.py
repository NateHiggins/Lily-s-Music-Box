from pathlib import Path
import json,numpy as np
p=Path('tmp/v2-fire-hand-20261019/stage29_continuation_trial.py');v={'__file__':str(p.resolve()),'__name__':'trial'}
exec(compile(p.read_text().split('out=[]')[0],str(p),'exec'),v)
x=v['initial'].copy();v['scope']['off']=v['final_offset'];trace=[]
for chunk in range(16):
 x,it=v['advance'](x,32);m=v['metrics'](x);print('iteration',(chunk+1)*32,'metrics',m,flush=True);trace.append(m)
 if m[0]<=2e-5 and m[1]<=2e-5 and m[2]<=1e-6:break
Path('tmp/v2-fire-hand-20261019/stage29_budget_trial.json').write_text(json.dumps({'evidence_class':'INERT','trace':trace},indent=2))
