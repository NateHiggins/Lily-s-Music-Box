"""INERT: summarize original route samples; never writes runtime receipts."""
from pathlib import Path
import collections,json,math
ROOT=Path(__file__).resolve().parent

def distribution(values):
    values=sorted(values);n=len(values)
    if not n:return {}
    return {**{f'p{q}_ms':values[min(n-1,math.floor(n*q/100))] for q in [50,90,95,99]},'max_ms':values[-1],'frames':n,**{f'over_{t}ms':sum(v>t for v in values) for t in [33,50,100,250,1000]}}

def summarize(directory):
    raw=json.loads((directory/'frames.json').read_text());rows=raw['samples'];columns=raw['columns'];groups=collections.defaultdict(list)
    for row in rows:groups[row[0]].append(row)
    numeric=[(i,c) for i,c in enumerate(columns) if c.endswith('_ms')]
    report={'evidence_class':'INERT','kind':'performance_diagnostic','source':str(directory/'frames.json'),'settings':{'resolution':raw.get('resolution'),'vsync':raw.get('vsync')},'percentile_method':'sorted[min(N-1,floor(N*p))]','whole_route':distribution([r[1] for r in rows]),'phases':{key:{c:distribution([r[i] for r in items]) for i,c in numeric} for key,items in groups.items()},'failures':raw.get('failures',[]),'events':raw.get('events',[]),'step_guard_rejections':raw.get('step_guard_rejections') if raw.get('player_physics') else None}
    if directory.name.startswith('golden'):report['physics_instrumentation_note']='Detailed physics-stage instrumentation is disabled in the full repair route; its empty stage records and raw zero rejection counter do not establish absence of guarded contacts. Use the paired stair diagnostics for attribution.'
    (directory/('summary_recomputed.json' if directory.name=='golden_profile_v2' else 'summary.json')).write_bytes((json.dumps(report,indent=2)+'\n').encode())
    return report

if __name__=='__main__':
    result={}
    for family in ['golden_profile_v2','golden_final','performance_final','inspection_quiet_v2']:
        p=ROOT/family
        if not (p/'frames.json').exists():continue
        report=summarize(p);result[family]=report['whole_route'];print(family,result[family])
    (ROOT/'final_route_comparison.json').write_bytes((json.dumps({'evidence_class':'INERT','settings':'1280x720 Forward+ RTX4080 VSync off uncapped. Quiet final measurements; no input-to-photon claim. Original golden route lacks Space camera entry; separate final camera diagnostic has no before-source timing sample.','distributions':result},indent=2)+'\n').encode())
