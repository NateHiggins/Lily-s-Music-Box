"""INERT: summarize retained diagnostics, never issue runtime qualification."""
import collections
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent


def distribution(values):
    values = sorted(values)
    def quantile(q):
        at = (len(values) - 1) * q
        low = int(at)
        return round(values[low] + (values[min(low + 1, len(values) - 1)] - values[low]) * (at - low), 3)
    return dict(n=len(values), p50=quantile(.5), p95=quantile(.95),
                p99=quantile(.99), maximum=round(values[-1], 3),
                over_33_333=sum(v > 1000 / 30 for v in values), over_50=sum(v > 50 for v in values))


def world(name):
    data = json.loads((ROOT / name / 'frames.json').read_text(encoding='utf-8'))
    groups = collections.defaultdict(list)
    for row in data['samples']:
        if row[0].startswith('library_') and not row[0].endswith('_excluded'):
            groups[row[0]].append(row)
    phases = {}
    for phase, rows in groups.items():
        rows = rows[1:]  # First interval straddles the phase boundary.
        if not rows:
            continue
        phases[phase] = {
            column: distribution([row[index] for row in rows])
            for index, column in [(1, 'wall_ms'), (4, 'render_cpu_ms'), (5, 'render_gpu_ms')]
        }
        phases[phase]['residency'] = dict(collections.Counter(row[6] for row in rows))
        phases[phase]['pipeline_counter_deltas'] = {
            key: rows[-1][7][key] - rows[0][7][key] for key in rows[0][7]
        }
    return dict(phases=phases, resolution=data['resolution'], vsync=data['vsync'],
                failures=data['failures'], own_book_contacts=sum(
                    any('/Book_' in contact for contact in frame['contacts'])
                    for frame in data['player_physics']))


def inputs(name):
    data = json.loads((ROOT / name / 'input_costs.json').read_text(encoding='utf-8'))
    groups = collections.defaultdict(list)
    for row in data['records']:
        groups[row['stage']].append(row['ms'])
    return {stage: distribution(values) for stage, values in groups.items()}


result = dict(evidence_class='INERT', unit='milliseconds',
              limitations=[
                  'World routes have identical input waypoints/settings; carrier contact changed the post-pickup view. No isolated geometry performance claim.',
                  'Render CPU/GPU timings are measured viewport counters; process/physics monitors are coarse and lagging, not a per-frame cost decomposition.',
                  'Residency and pipeline counters separate observed streaming/compilation activity but do not time loading or compilation costs.',
                  'World route does not open a book. Input handler timings come from a separate actual-input controlled scene.',
                  'No human acceptance or runtime_contract qualification.'
              ])
result['world'] = {name: world(name) for name in ['world_before_v4', 'world_after_v1', 'world_after_carrier_v1']}
result['input'] = {name: inputs(name) for name in ['cover_cost_before_v1', 'cover_cost_after_v1']}
(ROOT / 'measurements.json').write_text(json.dumps(result, indent=2) + '\n', encoding='utf-8')
for name, data in result['world'].items():
    print(name, 'own-book-contact samples', data['own_book_contacts'])
    for phase, row in data['phases'].items():
        print(' ', phase, row['wall_ms'])
for name, data in result['input'].items():
    print(name, data.get('constrained_motion'))
