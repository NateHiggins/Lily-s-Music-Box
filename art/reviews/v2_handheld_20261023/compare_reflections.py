import json
from pathlib import Path
root=Path(__file__).parent
names=['profile_ui_v2','reflection_off_control','reflection_early_v1','reflection_early_v2','reflection_final_v1']
def quant(a,p):
 a=sorted(a);x=(len(a)-1)*p;i=int(x);return a[i]+(a[min(i+1,len(a)-1)]-a[i])*(x-i)
out={'evidence_class':'INERT','notes':['First partial frame excluded per phase. Same 300 physics tick movement/turn route, 1280x720, uncapped, VSync off. Initialized world, not cold driver.','Reflection-off is causal diagnostic only; hidden-node declaration and extra-viewport treatment were rejected. Timings overlap; no independent asset/streaming qualification.'],'runs':{}}
for n in names:
 p=root/n/'profile.json'
 if not p.exists():continue
 d=json.loads(p.read_text());r={'settings':d['settings'],'phases':{}}
 for phase in ['first_print','steady_print','held_idle','lowered']:
  a=[x for x in d['samples'] if x['phase']==phase][1:];v=[x['wall_ms'] for x in a]
  r['phases'][phase]={'frames':len(a),'wall_ms':{'p50':quant(v,.5),'p95':quant(v,.95),'p99':quant(v,.99),'max':max(v)},'over_50ms':sum(x>50 for x in v),'over_100ms':sum(x>100 for x in v),'surface_pipeline_delta':max(x['pipeline_surface'] for x in a)-min(x['pipeline_surface'] for x in a),'reflection_probes_max':max(x.get('reflection_probes',-1) for x in a),'loading_warm_ms':a[0].get('reflection_warm_ms',None)}
 out['runs'][n]=r
(root/'reflection_comparison.json').write_text(json.dumps(out,indent=2)+'\n')
for n,r in out['runs'].items():print(n,r['phases']['first_print'])
