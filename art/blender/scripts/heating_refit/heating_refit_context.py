"""Portable inputs for the four-emitter native retrofit build."""
import argparse
import hashlib
import json
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[4]
parser = argparse.ArgumentParser()
parser.add_argument('--work-dir', type=Path, required=True)
parser.add_argument('--plan', type=Path, default=ROOT/'art/data/orison_v2/heating_refit_authoring.json')
args, _ = parser.parse_known_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
OUT = args.work_dir.resolve()
OUT.mkdir(parents=True, exist_ok=True)
PLAN_PATH = args.plan.resolve()
PLAN = json.loads(PLAN_PATH.read_text(encoding='utf-8'))
assert PLAN['schema_version'] == 1 and PLAN['evidence_class'] == 'INERT'
assert len(PLAN['routes']['branches']) == 4 and not PLAN['supports']['unserved']
assert all(row['retained_bearing'] for row in PLAN['projection']['bearing_checks'])

def sha(path, normalize=False):
    raw = path.read_bytes()
    return hashlib.sha256(raw.replace(b'\r\n', b'\n') if normalize else raw).hexdigest()

assert sha(ROOT/PLAN['base_native']['path']) == PLAN['base_native']['sha256'], 'Pinned nineteen-emitter source changed'
assert sha(ROOT/PLAN['source_layout']['path'], True) == PLAN['source_layout']['sha256_lf'], 'Pinned source layout changed'
for relative, expected in PLAN['authority_lf'].items():
    assert sha(ROOT/relative, True) == expected, 'Shared stock/material authority changed: '+relative

def bindings():
    paths = [Path(__file__).parent.parent/'build_heating_refit.py', PLAN_PATH,
             ROOT/PLAN['base_native']['path'], ROOT/PLAN['source_layout']['path'],
             ROOT/'tools/heating_pipe_fittings.py']
    paths += sorted(Path(__file__).parent.glob('*.py'))
    paths += [ROOT/relative for relative in PLAN['authority_lf']]
    return {path.relative_to(ROOT).as_posix(): sha(path, path.suffix != '.blend') for path in paths}
