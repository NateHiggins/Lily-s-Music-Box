"""Serial, reversible source controls. Invoke only while owning the Godot lane."""
from pathlib import Path
import hashlib
import json
import argparse
import subprocess
import sys

HERE = Path(__file__).resolve().parent
parser = argparse.ArgumentParser()
parser.add_argument('--batch', default='')
args = parser.parse_args()
if args.batch and not all(c.isalnum() or c in '_-' for c in args.batch):
    raise SystemExit('Use a plain fresh batch name.')
prefix = args.batch + '_' if args.batch else ''
REPO = HERE.parents[3]
live = REPO / 'game/scripts/game/reality_save_storage.gd'
candidate = (HERE / 'proposed/game/scripts/game/reality_save_storage.gd').read_bytes()
if live.read_bytes() != candidate:
    raise SystemExit('Live storage differs from the packaged candidate; refusing controls.')
receipt_path = REPO / ('design/astra/evidence/save_recovery/' + prefix + 'controls_receipt.json')
if receipt_path.exists():
    raise SystemExit('Prior control receipt exists; choose a fresh controller receipt.')
records = []
try:
    for name, source in [('no_readback_red', 'storage_no_readback.gd'),
                         ('future_fallback_red', 'storage_future_fallback.gd')]:
        name = prefix + name
        control = (HERE / 'controls' / source).read_bytes()
        live.write_bytes(control)
        command = [sys.executable, str(HERE / 'run_storage_case.py'), name, 'recovery', '--expected-exit', '1']
        result = subprocess.run(command, cwd=REPO)
        records.append({'name': name, 'actual_exit': result.returncode,
                        'control_sha256': hashlib.sha256(control).hexdigest()})
        if result.returncode != 1:
            break
finally:
    live.write_bytes(candidate)
    receipt_path.write_text(json.dumps({'runs': records, 'restored_candidate_sha256': hashlib.sha256(candidate).hexdigest(),
        'restoration_matches': live.read_bytes() == candidate}, indent=2) + '\n')
raise SystemExit(0 if len(records) == 2 and all(record['actual_exit'] == 1 for record in records) else 1)
