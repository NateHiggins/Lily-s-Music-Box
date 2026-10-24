"""Rebuild INERT distributions from original data or exact-byte gzip archives."""
from pathlib import Path
import gzip
import json
import math

ROOT = Path(__file__).resolve().parents[3]
HERE = Path(__file__).resolve().parent

def read(path):
    raw = path.read_bytes() if path.exists() else gzip.decompress(Path(str(path) + '.gz').read_bytes())
    return json.loads(raw)

def percentile(values, fraction):
    values = sorted(values)
    index = (len(values) - 1) * fraction
    lo = math.floor(index)
    hi = math.ceil(index)
    return values[lo] + (values[hi] - values[lo]) * (index - lo)

def distribution(values):
    return {name: percentile(values, p) for name, p in [('p50', .5), ('p95', .95), ('p99', .99), ('max', 1)]}

def without_timing(value):
    if isinstance(value, dict):
        return {k: without_timing(v) for k, v in value.items() if k != 'profile_usec'}
    if isinstance(value, list):
        return [without_timing(v) for v in value]
    return value

def main():
    result = {'evidence_class': 'INERT', 'scope': 'Uninstalled input and solver diagnostics; no played-world frame-time or installed spray qualification.', 'payout': {}, 'release': {}, 'default_controls': {}}
    for index in range(1, 17):
        name = f'payout_v{index}'
        path = HERE / name / 'payout.json'
        if not path.exists() and not Path(str(path) + '.gz').exists():
            continue
        data = read(path)
        steps = data['steps']
        record = {'events': len(steps), 'failures': data['failures'], 'input_setup_ms': data.get('input_setup_ms')}
        for key in ['input_ms', 'pose_latency_ms', 'max_solver_chunk_ms', 'solve_ms']:
            values = [row[key] for row in steps if key in row]
            if values:
                record[key] = distribution(values)
        record['events_with_pending_work'] = sum(row.get('pending_frames', 0) > 0 for row in steps)
        result['payout'][name] = record
    for name in ['settling_v1', 'misdirected_settling_v2', 'settling_v3', 'settling_final']:
        data = read(HERE / name / 'settling.json')
        steps = data['steps']
        result['release'][name] = {'steps': len(steps), 'solver_ms': distribution([row['solver_ms'] for row in steps]), 'total_solver_ms': sum(row['solver_ms'] for row in steps), 'last_error': steps[-1]['error'], 'failures': data['failures']}
    for kind in ['sparse', 'dense']:
        original = read(ROOT / 'art/reviews/v2_hose_follower_20261021' / (kind + '_control_v2') / 'gravity_trace.json')
        current = read(HERE / (kind + '_control_final') / 'gravity_trace.json')
        result['default_controls'][kind] = {'all_non_timing_fields_identical': without_timing(original) == without_timing(current)}
    (HERE / 'diagnostic_summary.json').write_text(json.dumps(result, indent=2) + '\n', encoding='utf-8', newline='\n')

if __name__ == '__main__':
    main()
