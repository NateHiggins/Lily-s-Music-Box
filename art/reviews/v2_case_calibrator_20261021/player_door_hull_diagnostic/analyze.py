"""INERT same-run contact distributions; no runtime or acceptance grant."""
from pathlib import Path
import gzip
import json
import math

ROOT = Path(__file__).resolve().parent


def read(path):
    return json.loads(path.read_bytes() if path.exists() else gzip.decompress(path.with_name(path.name + '.gz').read_bytes()))


def distribution(values):
    ordered = sorted(values)
    if not ordered:
        return {'n': 0}
    return {'n': len(ordered), **{key: ordered[max(0, math.ceil(q * len(ordered)) - 1)]
            for key, q in [('p50_ms', .5), ('p95_ms', .95), ('p99_ms', .99), ('max_ms', 1)]},
            'over_100_ms': sum(v > 100 for v in values), 'over_250_ms': sum(v > 250 for v in values)}


def analyze(path, log):
    frames = read(path / 'frames.json')
    ticks = read(path / 'inspection_observations.json')
    route = read(path / 'route.json')
    receipt = read(log.with_name(log.name + '.receipt.json'))
    result = {'evidence_class': 'INERT', 'kind': 'same_run_performance_diagnostic',
              'scope': 'Original / player-only native constraint hulls / original. Lower-cap step enabled throughout. Diagnostic controls, not runtime qualification or hardware latency.',
              'resolution': frames['resolution'], 'vsync': frames['vsync'], 'capture_control': frames['capture_control'],
              'route_waypoints': len(route['trace']), 'failures': frames['failures'],
              'execution': receipt['execution'], 'script_errors': receipt['log']['script_error_count'], 'cycles': {}}
    for prefix in ['original_a_', 'player_hulls_b_', 'restored_a_']:
        movement = [row for row in frames['samples'] if row[0].startswith(prefix)
                    and ('walk_' in row[0] or row[0].endswith('upper_turn'))]
        inspection = [row for row in frames['samples'] if row[0].startswith(prefix + 'inspection_')
                      and 'walk_' not in row[0] and 'approach' not in row[0] and 'excluded' not in row[0]]
        physical = [row for row in ticks['physics_ticks'] if row['phase'].startswith(prefix) and 'excluded' not in row['phase']]
        result['cycles'][prefix] = {'movement': distribution([row[1] for row in movement]),
                                   'inspection': distribution([row[1] for row in inspection]),
                                   'step': distribution([row['step_ms'] for row in physical if 'step_ms' in row]),
                                   'slide': distribution([row['slide_ms'] for row in physical if 'slide_ms' in row])}
    (path / 'comparison.json').write_bytes((json.dumps(result, indent=2) + '\n').encode())
    return result


if __name__ == '__main__':
    import sys
    directory = ROOT / (sys.argv[1] if len(sys.argv) > 1 else 'world_v4')
    log = ROOT / (sys.argv[2] if len(sys.argv) > 2 else 'world_v4.log')
    print(json.dumps(analyze(directory, log), indent=2))
