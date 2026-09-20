"""Summarize paired smoke samples without inventing a release threshold."""
import argparse
from collections import defaultdict
import json
import math
from pathlib import Path
import statistics


def distribution(values):
    values = sorted(values)
    return {'n': len(values), 'median': statistics.median(values),
            'p95_nearest_rank': values[max(0, math.ceil(len(values) * .95) - 1)], 'max': max(values)} if values else {'n': 0}


def summarize(path):
    probe = json.loads(Path(path).read_text())
    rows = defaultdict(lambda: defaultdict(list))
    for transition in probe.get('transitions', []):
        # Cold warmup and the final blocked retirement stance are distinct.
        if not 0 <= transition['cycle'] < 6: continue
        dest = rows[transition['station']]
        dest['synchronous_apply_usec'].append(transition['apply_usec'])
        dest['unchanged_scan_usec_per_call'].append(transition['repeated_scan_usec'] / transition['repeated_scan_count'])
        for frame in transition['frames']:
            for key in ['wait_usec', 'viewport_gpu_ms', 'viewport_cpu_ms', 'objects', 'draw_calls', 'primitives']:
                dest[key].append(frame[key])
    return {'root': probe['root'], 'variant': probe['variant'], 'execution_scope': probe.get('execution_scope', 'legacy_full'),
            'measured_phase_signature': [(t['cycle'], t['station'], len(t['frames'])) for t in probe.get('transitions', []) if 0 <= t['cycle'] < 6],
            'stations': {station: {key: distribution(values) for key, values in measurements.items()}
                         for station, measurements in rows.items()},
            'limits': 'Only the identical 36 completed pre-control transitions can be matched across full/root_retirement scopes; phase signatures and final retirement gates must both pass. A crashed/missing final probe is not a completed comparator. Warmup, captures, separate-world control and teardown are excluded. Frame waits include scheduling/vsync and live composition; viewport render timings are separate. Native logging and adaptive material state confound comparisons. No release-performance threshold is invented.'}


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('probes', nargs='+')
    args = parser.parse_args()
    print(json.dumps({str(p): summarize(p) for p in args.probes}, indent=2))
