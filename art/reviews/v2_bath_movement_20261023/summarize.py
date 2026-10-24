"""Summarize raw diagnostic frames without promoting them to qualification."""
from pathlib import Path
import json

root=Path(__file__).parent
def distribution(values):
    values=sorted(values)
    def q(p):
        index=(len(values)-1)*p;low=int(index)
        return values[low]+(values[min(low+1,len(values)-1)]-values[low])*(index-low)
    return {**{name:q(p) for name,p in [('p50',.5),('p95',.95),('p99',.99)]},'max':max(values)} if values else {}

source=json.loads((root/'diagnostic_v1/profile.json').read_text())
contacts=json.loads((root/'diagnostic_v1/contact_profile.json').read_text())
output={'evidence_class':'INERT','settings':source['settings'],'limits':['First incomplete wall sample of every phase excluded.','Physics stage records contain only ticks above one millisecond; no unbiased physics percentiles implied.','Render and global process/physics counters overlap and lag. Diagnostic disables never qualify production.','Global exclusion bisection in collision_v3 is confounded: query cost collapses after yielding a frame, independently of chosen subset. Its named suspect is not established as causal.'],'phases':{}}
for record in contacts['records']:
    phase=record['phase']
    frames=[s for s in source['samples'] if s['phase']=='bath_'+phase][1:]
    wall=[s['wall_ms'] for s in frames]
    output['phases'][phase]={'render_frames':len(frames),'wall_ms':distribution(wall),'over_50ms':sum(v>50 for v in wall),'over_100ms':sum(v>100 for v in wall),'slow_physics_records':len(record['physics']),'slow_physics_stages_ms':{key:distribution([s[key] for s in record['physics']]) for key in ['native_sync_ms','step_ms','slide_ms','follow_and_contact_ms']}}
(root/'summary.json').write_text(json.dumps(output,indent=2)+'\n',encoding='utf-8',newline='\n')
for phase,result in output['phases'].items():print(phase,result['wall_ms'])
