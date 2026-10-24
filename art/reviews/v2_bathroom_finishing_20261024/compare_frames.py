"""INERT same-route distributions, excluding phase-transition samples."""
import json
import math
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
HERE = Path(__file__).resolve().parent
ROUTES = {
    'original_before': ROOT / 'art/reviews/v2_bathroom_moisture_20261024/before_v1/frames.json',
    'previous_checkpoint': ROOT / 'art/reviews/v2_paper_holder_20261024/world_v6/frames.json',
    'finishing_candidate': HERE / 'performance_v1/frames.json',
    'frame_clearance_final': HERE / 'frame_clearance_world_v1/frames.json',
}
PHASES = ['dry_shower', 'cold_shower', 'hot_developing', 'hot_mirror', 'off_mirror_decay']

def quantile(values, fraction):
    ordered = sorted(values)
    at = (len(ordered) - 1) * fraction
    low, high = math.floor(at), math.ceil(at)
    return ordered[low] + (ordered[high] - ordered[low]) * (at - low)

result = {'evidence_class': 'INERT', 'method': 'Linear quantiles. Drop only samples whose preceding phase differs. Wall and overlapping engine timing counters are not additive. No input-to-photon measurement.', 'routes': {}}
for name, path in ROUTES.items():
    data = json.loads(path.read_text(encoding='utf-8'))
    assert not data['failures'], (name, data['failures'])
    samples = data['samples']
    phases = {}
    for phase in PHASES:
        rows = [row for i, row in enumerate(samples) if i and row[0] == phase and samples[i-1][0] == phase]
        wall = [row[1] for row in rows]
        assert wall, (name, phase)
        phases[phase] = {'n': len(wall), **{'p' + str(int(q*100)): round(quantile(wall, q), 3) for q in [.5, .95, .99]},
                         'maximum_ms': max(wall), **{'above_' + str(t) + 'ms': sum(v > t for v in wall) for t in [33, 50, 100]},
                         'counter_medians_ms': {data['columns'][i]: round(quantile([row[i] for row in rows], .5), 3) for i in range(2,8)},
                         'residency_states': sorted(set(row[8] for row in rows))}
    result['routes'][name] = {'path': str(path.relative_to(ROOT)), 'settings': {key: data[key] for key in ['resolution','fov','render_method','vsync']}, 'phases': phases}
assert len({json.dumps(row['settings'], sort_keys=True) for row in result['routes'].values()}) == 1
(HERE / 'frame_distributions.json').write_text(json.dumps(result, indent=2) + '\n', encoding='utf-8', newline='\n')
for name, route in result['routes'].items():
    print(name)
    for phase, row in route['phases'].items():
        print(phase, row['n'], row['p50'], row['p95'], row['p99'], row['maximum_ms'], row['above_50ms'])
