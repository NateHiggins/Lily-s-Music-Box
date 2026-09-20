"""Run one reviewed negative source control and always restore exact bytes.

Requires explicit ownership of the sole Godot lane and live sources. Controller
success means an intended red was recorded and restored, not game acceptance.
"""
from pathlib import Path
import argparse
import hashlib
import json
import subprocess
import sys

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
parser = argparse.ArgumentParser()
parser.add_argument('control', choices=['wrapped_minute', 'mid_report_late_sample'])
parser.add_argument('name')
args = parser.parse_args()
if not args.name.replace('_', '').isalnum():
    raise SystemExit('Use a fresh plain run name.')
out = HERE / 'control_receipts' / args.name
out.mkdir(parents=True, exist_ok=False)


def sha(raw):
    return hashlib.sha256(raw).hexdigest()


controls = sorted((HERE / 'controls' / args.control).rglob('*.gd'))
expected_count = 4 if args.control == 'wrapped_minute' else 1
if len(controls) != expected_count:
    raise SystemExit('Unexpected control source inventory.')
saved = {}
rows = []
for control in controls:
    relative = control.relative_to(HERE / 'controls' / args.control)
    live = ROOT / relative
    candidate = HERE / 'proposed' / relative
    if not relative.as_posix().startswith('game/scripts/') or not candidate.is_file():
        raise SystemExit('Control escaped its reviewed production scope.')
    raw = live.read_bytes()
    if raw != candidate.read_bytes():
        raise SystemExit('Live source differs from reviewed candidate: ' + str(relative))
    saved[live] = raw
    rows.append({'path': relative.as_posix(), 'candidate_sha256': sha(raw),
                 'control_sha256': sha(control.read_bytes())})
receipt = {'scope': 'negative control; restoration success is not a green runtime gate',
           'control': args.control, 'sources': rows, 'restored_exactly': False}
try:
    for control in controls:
        relative = control.relative_to(HERE / 'controls' / args.control)
        (ROOT / relative).write_bytes(control.read_bytes())
    command = [sys.executable, str(HERE / 'run_case.py'), args.name, 'timestamps', '--expected-exit', '1', '--timeout', '120']
    process = subprocess.run(command, cwd=ROOT, capture_output=True)
    (out / 'stdout.txt').write_bytes(process.stdout)
    (out / 'stderr.txt').write_bytes(process.stderr)
    receipt.update(command=command, controller_child_exit=process.returncode)
    case_path = ROOT / 'design/astra/evidence/world_timestamps' / args.name / 'receipt.json'
    case = json.loads(case_path.read_text(encoding='utf-8'))
    failures = case.get('failed_assertions', [])
    exact_fields = ('acquired_at', 'consumed_at', 'issued_at', 'closed_at', 'reported_at', 'at', 'adopted_at')
    intended_labels = all(any(line == '[WORLD TIMESTAMP FAIL] ' + field + ' records exact campaign elapsed minutes with its own basis'
                              for field in exact_fields) for line in failures)
    if args.control == 'mid_report_late_sample':
        intended_labels = failures == ['[WORLD TIMESTAMP FAIL] reported_at records exact campaign elapsed minutes with its own basis']
    receipt['intended_red'] = (process.returncode == 1 and case.get('actual_exit') == 1
        and case.get('source_unchanged') is True and bool(failures) and intended_labels
        and not case.get('diagnostic_gate', {}).get('error_or_retention_lines')
        and any('WORLD TIMESTAMPS: FAIL' in line for line in case.get('summary_lines', [])))
    receipt['runtime_receipt'] = case_path.relative_to(ROOT).as_posix()
    receipt['runtime_receipt_sha256'] = sha(case_path.read_bytes())
finally:
    for path, raw in saved.items():
        path.write_bytes(raw)
    receipt['restored_exactly'] = all(path.read_bytes() == raw for path, raw in saved.items())
    (out / 'receipt.json').write_text(json.dumps(receipt, indent=2) + '\n', encoding='utf-8')
print(json.dumps(receipt, indent=2))
raise SystemExit(0 if receipt.get('intended_red') and receipt['restored_exactly'] else 1)
