"""Derived distributions for the occupied curtain route; never runtime proof."""
from pathlib import Path
import argparse
import collections
import json
import math

def distribution(values):
    data=sorted(float(v) for v in values if math.isfinite(float(v)))
    if not data:return {'n':0}
    def percentile(q):
        index=(len(data)-1)*q;lo=int(index);hi=min(lo+1,len(data)-1)
        return data[lo]+(data[hi]-data[lo])*(index-lo)
    return {'n':len(data),'p50_ms':percentile(.5),'p95_ms':percentile(.95),
        'p99_ms':percentile(.99),'max_ms':max(data),
        'over33_ms':sum(v>1000/30 for v in data),'over50_ms':sum(v>50 for v in data),
        'over100_ms':sum(v>100 for v in data)}

def read_run(root):
    root=Path(root)
    paths={k:root/(k+'.json') for k in ['route','frames','curtain_input']}
    missing=[str(v) for v in paths.values() if not v.exists()]
    if missing:return {'valid':False,'missing':missing,'root':str(root)}
    rows={k:json.loads(v.read_text(encoding='utf8')) for k,v in paths.items()}
    failures={k:r.get('failures',[]) for k,r in rows.items() if r.get('failures')}
    inputs=rows['curtain_input'];frames=rows['frames']
    phases=inputs['phases'];expected=[f'curtain_{verb}_{i}' for i in [1,2,3] for verb in ['open','close']]
    bad_phases=[]
    for phase in phases:
        goal=1.78 if '_open_' in phase['phase'] else 0
        if not phase['ok'] or abs(phase['after'].get('curtain',-100)-goal)>1e-5:
            bad_phases.append(phase['phase'])
    valid=not failures and not bad_phases and [p['phase'] for p in phases]==expected
    by_phase=collections.defaultdict(list)
    for row in frames['samples']:by_phase[row[0]].append(row)
    columns=frames['columns'];metrics=[c for c in columns if c.endswith('_ms')]
    quality_errors=[]
    if [p['phase'] for p in phases]!=expected:
        quality_errors.append('Expected exactly three ordered opening/closing pairs')
    for phase in phases:
        name=phase['phase']
        if any(not isinstance(c.get('ms'),(int,float)) or not math.isfinite(c['ms']) or c['ms']<0
               for c in phase['callbacks']):
            quality_errors.append(name+': invalid callback timing')
        callbacks=collections.Counter(c['stage'] for c in phase['callbacks'])
        if callbacks['constrained_motion']!=24 or callbacks['begin']!=1 or callbacks['end']!=1:
            quality_errors.append(name+': incomplete actual-input callback trace')
        if len(by_phase.get(name,[]))<24:
            quality_errors.append(name+': fewer than 24 rendered gesture intervals')
        wanted_start=0.0 if '_open_' in name else 1.78
        if abs(float(phase['before'].get('curtain',-100))-wanted_start)>1e-5:
            quality_errors.append(name+': wrong initial stop')
    if not rows['route'].get('trace') or any(not row.get('ok',False) for row in rows['route']['trace']):
        quality_errors.append('Walking trace missing or contains a failed waypoint')
    for sample in frames['samples']:
        if any(not isinstance(sample[columns.index(metric)],(int,float)) or
               not math.isfinite(sample[columns.index(metric)]) or sample[columns.index(metric)]<0
               for metric in metrics):
            quality_errors.append('Nonfinite, nonnumeric or negative frame timing');break
    valid=valid and not quality_errors
    summary={}
    for phase,values in by_phase.items():
        summary[phase]={metric:distribution(row[columns.index(metric)] for row in values) for metric in metrics}
    callback_summary={}
    for phase in phases:
        groups=collections.defaultdict(list)
        for callback in phase['callbacks']:groups[callback['stage']].append(callback['ms'])
        callback_summary[phase['phase']]={stage:distribution(values) for stage,values in groups.items()}
    spikes=[]
    previous=None
    for row in frames['samples']:
        monitors=row[-1];deltas={}
        if previous is not None:
            deltas={k:monitors[k]-previous.get(k,monitors[k]) for k in monitors
                if k.startswith(('PIPELINE_','OBJECT_')) and isinstance(monitors[k],(int,float)) and monitors[k]!=previous.get(k,monitors[k])}
        if row[1]>50:
            spikes.append({'phase':row[0],'wall_ms':row[1],
                **{m:row[columns.index(m)] for m in metrics if m!='wall_ms'},
                'residency':row[-2],'coincident_counter_deltas':deltas})
        previous=monitors
    spikes.sort(key=lambda r:r['wall_ms'],reverse=True)
    return {'valid':valid,'root':str(root),'failures':failures,'bad_phases':bad_phases,'quality_errors':quality_errors,
        'settings':{'resolution':inputs['resolution'],'fov':inputs['fov'],**inputs['settings'],'clock':inputs['clock']},
        'source':{'asset':inputs['drawn_source_sha256'],'motion':inputs['motion_source_sha256']},
        'frames':summary,'callbacks':callback_summary,'largest_spikes':spikes[:15],
        'trace_targets':[r['target'] for r in rows['route'].get('trace',[])],
        'phase_order':[p['phase'] for p in phases]}

def main():
    p=argparse.ArgumentParser();p.add_argument('before');p.add_argument('--after');p.add_argument('--out',required=True)
    a=p.parse_args();before=read_run(a.before)
    result={'evidence_class':'INERT','before':before,'limitations':[
        'Frame wall time, aggregate process time, physics and viewport render timings overlap; do not add them or call process time exclusive scripts.',
        'Callback duration is controller/owner execution, not OS-to-photon input latency.',
        'Counter coincidences are not causal attribution. One pair with repeated gestures is not broad V2 or statistical qualification.',
        'Initial fixture placement, door/walking approach and capture readbacks have separate scopes. Compare gesture phases and idle controls separately.']}
    if a.after:
        after=read_run(a.after);result['after']=after
        result['comparable']=before['valid'] and after['valid'] and before['settings']==after['settings'] \
            and before['phase_order']==after['phase_order'] and before['trace_targets']==after['trace_targets'] \
            and before['settings'].get('input_cadence')=='one curtain motion per process frame'
    else:result['comparable']=False
    Path(a.out).write_text(json.dumps(result,indent=2)+'\n',encoding='utf8')
    print(json.dumps({'before_valid':before['valid'],'after_valid':result.get('after',{}).get('valid'),'comparable':result['comparable'],'out':a.out}))

    return 0 if before['valid'] and (not a.after or result['comparable']) else 1

if __name__=='__main__':raise SystemExit(main())
