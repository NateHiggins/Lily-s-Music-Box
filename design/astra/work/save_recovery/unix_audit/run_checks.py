"""Actual isolated Python tests, without changing live tools or any game source."""
from pathlib import Path
import argparse
import importlib.util
import json
import subprocess
import sys
import unittest

ROOT = Path(__file__).resolve().parent
parser = argparse.ArgumentParser()
parser.add_argument('--child', choices=['original', 'candidate'])
args = parser.parse_args()
if args.child:
    module_path = (ROOT / 'originals/audit_systemic_situation_authority.py' if args.child == 'original'
                   else ROOT / 'proposed/tools/audit_systemic_situation_authority.py')
    spec = importlib.util.spec_from_file_location('audit_systemic_situation_authority', module_path)
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    spec = importlib.util.spec_from_file_location('staged_tests', ROOT / 'proposed/tools/tests/test_systemic_situation_authority.py')
    tests = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(tests)
    classes = ['HostUnixTests'] if args.child == 'original' else [
        'DetectionTests', 'HostCalendarTests', 'HostUnixTests', 'BaselineTests', 'ModeTests']
    suite = unittest.TestSuite(unittest.defaultTestLoader.loadTestsFromTestCase(getattr(tests, name)) for name in classes)
    result = unittest.TextTestRunner(verbosity=2).run(suite)
    raise SystemExit(0 if result.wasSuccessful() else 1)

evidence = ROOT / 'evidence'
evidence.mkdir(exist_ok=False)
receipt = {'scope': 'isolated synthetic Python fixtures; no live scans or live edits', 'runs': []}
for candidate, expected in [('original', 1), ('candidate', 0)]:
    command = [sys.executable, str(Path(__file__).resolve()), '--child', candidate]
    result = subprocess.run(command, cwd=ROOT, capture_output=True)
    (evidence / (candidate + '.stdout.txt')).write_bytes(result.stdout)
    (evidence / (candidate + '.stderr.txt')).write_bytes(result.stderr)
    receipt['runs'].append({'candidate': candidate, 'command': command, 'exit': result.returncode,
                            'expected': expected, 'matches': result.returncode == expected})
(evidence / 'receipt.json').write_text(json.dumps(receipt, indent=2) + '\n', encoding='utf-8')
print(json.dumps(receipt, indent=2))
raise SystemExit(0 if all(run['matches'] for run in receipt['runs']) else 1)
