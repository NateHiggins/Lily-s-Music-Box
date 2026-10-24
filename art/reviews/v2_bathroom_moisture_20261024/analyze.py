"""INERT frame distributions from actual occupied-world routes."""
from pathlib import Path
import json,math,collections
OUT=Path(__file__).resolve().parent

def dist(v):
 v=sorted(v)
 def q(f):
  n=(len(v)-1)*f;a=math.floor(n);b=math.ceil(n)
  return round(v[a]+(v[b]-v[a])*(n-a),3)
 return dict(n=len(v),p50=q(.5),p95=q(.95),p99=q(.99),maximum=round(max(v),3),above_33=sum(x>1000/30 for x in v),above_50=sum(x>50 for x in v),above_100=sum(x>100 for x in v))

runs=[]
for run in ['before_v1','after_v1','after_v2','after_v3','paper_world_v3','paper_world_v4','paper_world_v6']:
 path=(OUT.parent/'v2_paper_holder_20261024'/run.removeprefix('paper_') if run.startswith('paper_') else OUT/run)/'frames.json'
 if not path.exists():continue
 data=json.loads(path.read_text());groups=collections.defaultdict(list)
 for previous,row in zip(data['samples'],data['samples'][1:]):
  if previous[0]==row[0] and 'excluded' not in row[0]:groups[row[0]].append(row)
 phases={}
 for phase,rows in groups.items():
  phases[phase]={data['columns'][i]:dist([r[i] for r in rows]) for i in range(1,8)}
  phases[phase]['residency_states']=dict(collections.Counter(r[8] for r in rows))
  phases[phase]['compilation_counter_delta']={k:rows[-1][9][k]-rows[0][9][k] for k in rows[0][9] if k.startswith('PIPELINE_')}
 runs.append(dict(run=run,resolution=data['resolution'],render_method=data['render_method'],vsync=data['vsync'],failures=data['failures'],flow_samples=data['flow_samples'],phases=phases,spikes=[dict(phase=r[0],wall_ms=r[1],render_cpu_ms=r[4],render_gpu_ms=r[5],mirror_cpu_ms=r[6],mirror_gpu_ms=r[7]) for r in data['samples'] if r[1]>50 and 'excluded' not in r[0]]))
result=dict(evidence_class='INERT',method='Linear quantiles; exclude boundary-straddling intervals and explicitly excluded checks/captures. Actual original route/settings; added effect assertions run between timed phases. No images during timed route.',limitations=['One source baseline; repeats are not a randomized causal experiment.','Process/physics/render counters can overlap or lag and are not additive.','No input-to-photon latency, human acceptance or runtime_contract.','Original failure verdicts remain distinct from timing observations.'],runs=runs)
(OUT/'analysis.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8',newline='\n')
for run in runs:print(run['run'],{p:r['wall_ms'] for p,r in run['phases'].items() if p in ['dry_shower','cold_shower','hot_developing','hot_mirror','off_mirror_decay']})
