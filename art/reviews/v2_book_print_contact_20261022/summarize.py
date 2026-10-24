"""Replay diagnostic frame distributions, retaining action-boundary samples."""
from pathlib import Path
import collections,gzip,json,math
ROOT=Path(__file__).resolve().parents[3];OUT=Path(__file__).resolve().parent
def read(run,name):
 p=OUT/run/name
 if p.exists():return json.loads(p.read_text(encoding='utf-8'))
 return json.loads(gzip.decompress((OUT/'archive/diagnostics'/run/(name+'.gz')).read_bytes()))
def stats(values):
 values=sorted(values)
 def q(f):
  at=(len(values)-1)*f;lo=math.floor(at);hi=math.ceil(at)
  return round(values[lo]+(values[hi]-values[lo])*(at-lo),3)
 return dict(n=len(values),p50=q(.5),p95=q(.95),p99=q(.99),maximum=round(max(values),3),above_33_333=sum(x>1000/30 for x in values),above_50=sum(x>50 for x in values),above_100=sum(x>100 for x in values))
def summarize(run):
 d=read(run,'frames.json');groups=collections.defaultdict(list);stable=collections.defaultdict(list);boundaries=collections.defaultdict(list)
 for index,row in enumerate(d['samples']):
  phase=row[0]
  if 'excluded' in phase or phase=='startup':continue
  groups[phase].append(row)
  (stable if index>0 and d['samples'][index-1][0]==phase else boundaries)[phase].append(row)
 phases={}
 for phase,rows in groups.items():
  phases[phase]={d['columns'][column]:stats([r[column] for r in rows]) for column in range(1,6)}
  phases[phase]['without_boundary_wall_ms']=stats([r[1] for r in stable[phase]]) if stable[phase] else None
  phases[phase]['boundary_wall_ms']=[r[1] for r in boundaries[phase]]
  phases[phase]['pipeline_delta']={key:rows[-1][7][key]-rows[0][7][key] for key in rows[0][7]}
  phases[phase]['residency_states']=dict(collections.Counter(r[6] for r in rows))
 return dict(run=run,resolution=d['resolution'],vsync=d['vsync'],failures=d['failures'],phases=phases,printed=read(run,'print.json'))
report=dict(evidence_class='INERT',method='Linear quantiles. Inclusive phase timings retain transition/action frames; stable samples and boundary frames are also reported separately. Counters are asynchronous observations, not additive attribution.',
 runs=[summarize(run) for run in ['world_before_v3','world_after_v1','world_after_v2']],
 limitations=['One baseline and two candidate runs; no A/B/A.','First candidate regressed and is retained. Final candidate prepares hidden print during inspection in field-sized slices, with a 2 ms between-field budget. Individual fields/final upload may exceed that budget.','Process, physics and render counters overlap/lag. No cross-cell streaming or cold asset-I/O isolation is claimed.','Captures excluded from measured phases. No runtime_contract or human acceptance.'])
(OUT/'measurements.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8',newline='\n')
for run in report['runs']:
 print(run['run'],{phase:run['phases'][phase]['wall_ms'] for phase in ['nook_enter_inspection','print_first_open','print_open_still']},run['printed'])
