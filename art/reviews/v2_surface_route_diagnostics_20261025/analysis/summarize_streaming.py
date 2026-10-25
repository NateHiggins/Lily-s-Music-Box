"""INERT summaries; preserve failed routes and phase-boundary spikes."""
import collections
import hashlib
import json
import math
import sys
from pathlib import Path


def distribution(values):
    values = sorted(float(x) for x in values if math.isfinite(float(x)))
    if not values:
        return {"count": 0}
    def q(f):
        i = (len(values)-1)*f
        low = int(i)
        return values[low] + (values[min(low+1,len(values)-1)]-values[low])*(i-low)
    return {"count":len(values),"p50_ms":q(.5),"p95_ms":q(.95),
            "p99_ms":q(.99),"max_ms":values[-1],
            "over_50_ms":sum(x>50 for x in values),"over_100_ms":sum(x>100 for x in values)}


def summarize(directory):
    directory = Path(directory)
    raw = (directory/'frames.json').read_bytes()
    data = json.loads(raw.decode('utf-8-sig'))
    columns = data['columns']
    assert columns[:7] == ['phase','wall_ms','process_ms','physics_ms','render_cpu_ms','render_gpu_ms','residency']
    rows = data['samples']
    assert rows, 'no executed frame samples'
    groups = collections.defaultdict(list)
    spikes = []
    compilation_deltas = collections.Counter()
    previous_phase = None
    previous_monitors = {}
    for index, row in enumerate(rows):
        phase,wall,process,physics,cpu,gpu,state = row[:7]
        assert all(math.isfinite(float(x)) and x>=0 for x in [wall,process,physics,cpu,gpu])
        boundary = previous_phase is not None and phase != previous_phase
        excluded = phase.startswith('capture_excluded_') or str(previous_phase).startswith('capture_excluded_')
        startup = phase == 'startup'
        groups['all_raw'].append(row)
        if excluded:
            groups['capture_and_adjacent_intervals'].append(row)
        elif startup:
            groups['startup_labelled'].append(row)
        else:
            groups['playable_including_phase_boundaries'].append(row)
            groups['residency_'+state].append(row)
            groups['phase_'+phase].append(row)
        if boundary:
            groups['phase_boundaries'].append(row)
        deltas = {}
        monitors = row[7] if len(row)>7 else {}
        for key,value in monitors.items():
            if key in previous_monitors:
                delta = value-previous_monitors[key]
                if delta >= 0:
                    deltas[key] = delta
                    compilation_deltas[key] += delta
        if wall>50:
            spikes.append(dict(index=index,phase=phase,previous_phase=previous_phase,
                               boundary=boundary,capture_related=excluded,residency=state,
                               wall_ms=wall,process_ms=process,physics_ms=physics,
                               render_cpu_ms=cpu,render_gpu_ms=gpu,compilation_deltas=deltas))
        previous_phase,previous_monitors = phase,monitors
    result = {'evidence_class':'INERT','scope':'Observed CPU/GPU monitors and callback intervals, not display latency. CPU/physics/render timings overlap and must not be added. Failed or incomplete routes remain failures.',
              'frames_sha256':hashlib.sha256(raw).hexdigest(),'route_failures':data.get('failures',[]),
              'groups':{},'compilation_deltas':dict(compilation_deltas),
              'spikes_over_50_ms':sorted(spikes,key=lambda x:x['wall_ms'],reverse=True)}
    for name, selected in groups.items():
        result['groups'][name]={columns[i]:distribution(r[i] for r in selected) for i in range(1,6)}
    for name in ['settings','streaming']:
        path = directory/(name+'.json')
        if path.exists():
            value = json.loads(path.read_text(encoding='utf-8-sig'))
            if name == 'streaming':
                result[name]={'failures':value.get('failures',[]),'cycles':value.get('cycles',[]),
                             'final_residency':value.get('final_residency',{})}
            else:
                result[name] = value
    work = directory/'work_trace.json'
    if work.exists():
        value = json.loads(work.read_text(encoding='utf-8-sig'))
        result['work_trace_truncated'] = value['truncated']
        counters = collections.defaultdict(list)
        for frame in value['frames']:
            for key,number in frame['counters'].items():
                counters[key].append(number)
        result['observed_counter_ranges'] = {key:{'min':min(v),'max':max(v)} for key,v in counters.items()}
    return result


if __name__ == '__main__':
    result = summarize(sys.argv[1])
    destination = Path(sys.argv[2])
    destination.write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8',newline='\n')
    print(json.dumps({'failures':result['route_failures'],
                      'playable':result['groups'].get('playable_including_phase_boundaries'),
                      'compilation_deltas':result['compilation_deltas']},indent=2))
