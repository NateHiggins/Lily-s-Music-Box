"""Reproduce frame distributions from original plain or archived diagnostics."""
from pathlib import Path
import gzip,json,collections,math
ROOT=Path(__file__).resolve().parents[3];OUT=Path(__file__).resolve().parent

def load(packet,run,name):
    base=ROOT/'art/reviews'/packet
    path=base/run/name
    if path.exists():return json.loads(path.read_text(encoding='utf-8'))
    return json.loads(gzip.decompress((base/'archive/diagnostics'/run/(name+'.gz')).read_bytes()))

def quantile(values,fraction):
    values=sorted(values);at=(len(values)-1)*fraction;low=math.floor(at);high=math.ceil(at)
    return round(values[low]+(values[high]-values[low])*(at-low),3)

def distribution(values):
    return dict(n=len(values),p50=quantile(values,.5),p95=quantile(values,.95),p99=quantile(values,.99),maximum=round(max(values),3),above_33_333=sum(x>1000/30 for x in values),above_50=sum(x>50 for x in values),above_100=sum(x>100 for x in values))

def summarize(packet,run):
    source=load(packet,run,'frames.json');groups=collections.defaultdict(list)
    for previous,row in zip(source['samples'],source['samples'][1:]):
        if previous[0]==row[0] and row[0].startswith('nook_') and 'excluded' not in row[0]:groups[row[0]].append(row)
    phases={}
    for phase,rows in groups.items():
        phases[phase]={source['columns'][column]:distribution([r[column] for r in rows]) for column in range(1,6)}
        phases[phase]['pipeline_compilation_delta']={key:rows[-1][7][key]-rows[0][7][key] for key in rows[0][7]}
        phases[phase]['residency_states']=dict(collections.Counter(r[6] for r in rows))
    return dict(packet=packet,run=run,resolution=source['resolution'],vsync=source['vsync'],failures=source['failures'],phases=phases)

result=dict(evidence_class='INERT',method='Linear quantiles; discard boundary-straddling frames. Counters are observed, not additive CPU/GPU attribution.',
    matched_book_pair=[summarize('v2_nook_bindings_20261022',run) for run in ['world_before_v3','world_after_v1']],
    revamp_route=summarize('v2_nook_revamp_20261022','access_after_v1'),
    corrected_tint_route=summarize('v2_nook_revamp_20261022','access_final_v1'),
    limitations=['Only the book pair has the same local start/route. The final revamp includes entry and loaded-map diagnostics before book phases; do not compare it as isolated optimization.', 'Cold startup, loading, streaming and first-use cover rendering are not fully isolated by these local phases.','No runtime_contract or human acceptance.'])
(OUT/'measurements.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8',newline='\n')
for item in result['matched_book_pair']+[result['revamp_route']]:
    print(item['run'],{name:phase['wall_ms'] for name,phase in item['phases'].items()})
