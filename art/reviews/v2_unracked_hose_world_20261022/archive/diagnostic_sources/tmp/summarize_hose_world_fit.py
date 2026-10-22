from pathlib import Path
import json,math,os
root=Path(__file__).resolve().parents[1]
here=root/'art/reviews/v2_unracked_hose_20261022'
def dist(values):
    values=sorted(values)
    def quantile(p):
        at=(len(values)-1)*p;i=math.floor(at);j=math.ceil(at)
        return values[i]+(values[j]-values[i])*(at-i)
    return dict(samples=len(values),p50=quantile(.5),p95=quantile(.95),p99=quantile(.99),maximum=values[-1],over_16_667=sum(x>1000/60 for x in values),over_33_333=sum(x>1000/30 for x in values),over_100=sum(x>100 for x in values))
version=os.environ.get('HOSE_WORLD_SUMMARY','world_coil_v4')
survey=json.loads((here/version/'layout_survey.json').read_text())
row=next(x for x in survey['stations'] if x['id']=='F02_FIRE_LINE_STAIR')
frames=json.loads((here/version/'frames.json').read_text())
samples=[x for x in frames['samples'] if x[0]=='played_unrack_input']
result=dict(evidence_class='INERT',scope='Complete-world initial layout and actual removal diagnostic. No matched before/after optimization, released behavior, save, spray or runtime qualification.',clear_stations=[x['id'] for x in survey['stations'] if x['clear']],actual_removal=dict(picked=row['input']['picked'],deployed=row['input']['deployed'],released=row['input']['released'],cpu_input_ms=dist([x['cpu_input_ms'] for x in row['input']['events']])),frames={})
for i,name in enumerate(frames['columns']):
    if name.endswith('_ms') and samples:result['frames'][name]=dist([x[i] for x in samples])
if samples:
    first=samples[0][-1];last=samples[-1][-1]
    result['pipeline_compilation_changes']={k:last[k]-first[k] for k in first}
carry=row['input'].get('carry',[])
if carry:
    result['actual_carry']=dict(cpu_input_ms=dist([x['cpu_input_ms'] for x in carry]),stalled_events=sum(x['progress_m']<.0001 for x in carry),events=carry)
result['phases_boundary_excluded']={}
for phase in ['played_unrack_input','played_unracked_carry']:
    rows=[x for x in frames['samples'] if x[0]==phase]
    if len(rows)>1:result['phases_boundary_excluded'][phase]={name:dist([x[i] for x in rows[1:]]) for i,name in enumerate(frames['columns']) if name.endswith('_ms')}
result['boundary_method']='Exclude the first partial interval following the diagnostic timer reset. Retain three post-release presentation frames. No displayed-latency or matched before/after claim.'
result['native']=[dict(name=p.parent.name,geometry=json.loads(p.read_text())) for p in (root/'tmp/v2-unracked-hose-20261022').glob(version+'_native_*/deformed_geometry.json')]
(here/(version+'_summary.json')).write_text(json.dumps(result,indent=2)+'\n',newline='\n')
print(json.dumps({k:v for k,v in result.items() if k!='native'},indent=2))
