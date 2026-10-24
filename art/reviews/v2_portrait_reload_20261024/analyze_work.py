"""INERT callback-wall attribution. Nested spans are unioned, never summed."""
import bisect
import hashlib
import json
import math
import sys
from collections import defaultdict
from pathlib import Path

run = Path(sys.argv[1])
source = run / 'work_trace.json'
data = json.loads(source.read_text(encoding='utf-8'))


def distribution(values):
    values = sorted(values)
    def percentile(p):
        if not values:
            return None
        f = (len(values) - 1) * p
        lo, hi = math.floor(f), math.ceil(f)
        return values[lo] + (values[hi] - values[lo]) * (f - lo)
    return dict(n=len(values), p50=percentile(.5), p95=percentile(.95),
                p99=percentile(.99), maximum=max(values, default=None),
                over_100=sum(v > 100 for v in values))


def covered(spans, start, end):
    clipped = sorted((max(a, start), min(b, end)) for a, b in spans if a < end and b > start)
    total, previous = 0, start
    for a, b in clipped:
        total += max(0, b - max(a, previous))
        previous = max(previous, b)
    return total / 1000


spans = defaultdict(list)
pending = {}
ends = {'process_end': ('process_begin', 'process_callbacks'),
        'physics_end': ('physics_begin', 'physics_callbacks'),
        'render_post': ('render_pre', 'render_submission')}
for usec, process, physics, render, event, phase in data['timeline']:
    if event in ends:
        begin, label = ends[event]
        if begin in pending:
            spans[label].append((pending.pop(begin), usec))
    else:
        pending[event] = usec
groups = defaultdict(list)
for row in data['household']:
    groups[row['stage']].append((row['end_usec'] - row['start_usec']) / 1000)
    spans['household'].append((row['start_usec'], row['end_usec']))

frames = data['frames']
rows = []
excluded = []
all_spans = [span for group in spans.values() for span in group]
for index in range(1, len(frames)):
    first, last = frames[index - 1], frames[index]
    if first['phase'].startswith('capture_excluded_') or last['phase'].startswith('capture_excluded_'):
        excluded.append(index)
        continue
    start, end = first['usec'], last['usec']
    row = dict(index=index, process_frame=last['process_frame'], phase=last['phase'],
               wall_ms=(end - start) / 1000, refresh_delta=last['room_refreshes'] - first['room_refreshes'],
               residency=last['residency'])
    for label, intervals in spans.items():
        row[label + '_ms'] = covered(intervals, start, end)
    row['outside_observed_spans_ms'] = row['wall_ms'] - covered(all_spans, start, end)
    row['compilation_delta'] = {k: last['counters'][k] - first['counters'][k]
                                for k in last['counters'] if k.startswith('PIPELINE_COMPILATIONS_')}
    rows.append(row)
result = dict(evidence_class='INERT',
              scope='Instrumented post-render signal intervals, not display latency. Callback windows include nested work. Render interval is CPU submission/wait, not GPU completion. Outside spans is unclassified engine/input/queued work/wait. Monitor deltas can lag work.',
              trace_sha256=hashlib.sha256(source.read_bytes()).hexdigest(),
              household_ms={k: distribution(v) for k, v in groups.items()},
              callback_ms={k: distribution([(b - a) / 1000 for a, b in v]) for k, v in spans.items() if k != 'household'},
              wall_ms=distribution([row['wall_ms'] for row in rows]),
              probe_post_sample_usec=distribution(data['probe_post_sample_usec']),
              excluded_capture_indices=excluded,
              largest_intervals=sorted(rows, key=lambda row: row['wall_ms'], reverse=True)[:20],
              book_count=len(data['book_states']),
              book_pages_ready=sum(row['pages_ready'] for row in data['book_states']),
              book_print_ready=sum(row['print_ready'] for row in data['book_states']),
              residency_states=sorted({row['residency'] for row in rows}),
              raw_interval_attribution=rows)
(run / 'work_analysis.json').write_text(json.dumps(result, indent=2) + '\n', encoding='utf-8')
print('wall_ms', result['wall_ms'])
print('household_ms', result['household_ms'])
print('callback_ms', result['callback_ms'])
print('largest', result['largest_intervals'][:5])
