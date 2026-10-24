"""Retained frame samples; local route observations, no runtime qualification."""
from pathlib import Path
import collections,json,math
OUT=Path(__file__).resolve().parent

def distribution(values):
 values=sorted(values)
 def q(f):
  at=(len(values)-1)*f;lo=math.floor(at);hi=math.ceil(at)
  return round(values[lo]+(values[hi]-values[lo])*(at-lo),3)
 return dict(n=len(values),p50=q(.5),p95=q(.95),p99=q(.99),maximum=round(max(values),3),above_50=sum(v>50 for v in values),above_100=sum(v>100 for v in values))

def summarize(run):
 source=json.loads((OUT/run/'frames.json').read_text(encoding='utf-8'));groups=collections.defaultdict(list)
 for previous,row in zip(source['samples'],source['samples'][1:]):
  if previous[0]==row[0] and row[0].startswith('nook_') and 'excluded' not in row[0]:groups[row[0]].append(row)
 result={}
 for phase,rows in groups.items():
  result[phase]={source['columns'][i]:distribution([r[i] for r in rows]) for i in range(1,6)}
  result[phase]['compilation_counter_delta']={k:rows[-1][7][k]-rows[0][7][k] for k in rows[0][7]}
  result[phase]['residency_states']=dict(collections.Counter(r[6] for r in rows))
 return dict(run=run,resolution=source['resolution'],vsync=source['vsync'],failures=source['failures'],phases=result)

runs=[summarize(name) for name in ['before_v1','after_v1'] if (OUT/name/'frames.json').is_file()]
result=dict(evidence_class='INERT',method='Linear quantiles; boundary-straddling samples excluded. Same production local route and settings; counters observed, not additive script/physics/render attribution.',runs=runs,limitations=['No controlled cold compilation or streaming-cost comparison.','No human acceptance or runtime_contract.','Changed book placement changes occlusion; decoration and placement costs are not isolated.'])
(OUT/'analysis.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8',newline='\n')
for run in runs:print(run['run'],{p:d['wall_ms'] for p,d in run['phases'].items()})
