"""Replay retained diagnostic timings and the unchanged mechanism failures."""
from pathlib import Path
import collections,gzip,json,math,re
OUT=Path(__file__).resolve().parent
def raw(name):
 p=OUT/name
 return p.read_bytes() if p.exists() else gzip.decompress((OUT/'archive/diagnostics'/(name+'.gz')).read_bytes())
def stats(values):
 values=sorted(values)
 def q(f):
  at=(len(values)-1)*f;lo=math.floor(at);hi=math.ceil(at)
  return round(values[lo]+(values[hi]-values[lo])*(at-lo),3)
 return dict(n=len(values),p50=q(.5),p95=q(.95),p99=q(.99),maximum=round(max(values),3),above_33_333=sum(v>1000/30 for v in values),above_50=sum(v>50 for v in values))
def summarize(run):
 d=json.loads(raw(run+'/frames.json'));groups=collections.defaultdict(list)
 for row in d['samples']:
  if 'excluded' not in row[0]:groups[row[0]].append(row)
 phases={phase:{d['columns'][column]:stats([r[column] for r in rows]) for column in range(1,6)} for phase,rows in groups.items()}
 return dict(run=run,phases=phases,world_return=json.loads(raw(run+'/return.json')))
failures={name:re.findall(r'INSPECT CHECK: (.+) = false',raw(name+'.log').decode('utf-8')) for name in ['mechanism_before_v1','mechanism_v1']}
assert failures['mechanism_before_v1']==failures['mechanism_v1'] and len(failures['mechanism_v1'])==5
report=dict(evidence_class='INERT',method='Inclusive phase frames; linear quantiles; process/physics/render observations overlap and lag. V1 is capture-boundary contaminated. V2 drains diagnostic captures before measured input. One corrected post-fix route, no before/after performance claim.',runs=[summarize(run) for run in ['world_final_v1','world_final_v2']],mechanism_failures=failures)
(OUT/'measurements.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8',newline='\n')
print('Identical mechanism failures:',len(failures['mechanism_v1']))
for run in report['runs']:
 for phase in ['nook_return_hand','nook_return_release']:print(run['run'],phase,run['phases'][phase]['wall_ms'])
