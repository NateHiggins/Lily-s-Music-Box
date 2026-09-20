"""Small-file preparation checks only. Does not import/run Godot or hash the game tree."""
from pathlib import Path
import ast
import hashlib
import json
import re
import subprocess
import sys

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
RELATIVE = 'game/scripts/reality/apartment_encroachment.gd'
sha = lambda data: hashlib.sha256(data).hexdigest()
files = [p for p in HERE.rglob('*') if p.is_file() and '__pycache__' not in p.parts
         and p.name not in {'review_checks.json', 'gate.stdout.txt', 'gate.stderr.txt'}]
for p in HERE.glob('*.py'):
    ast.parse(p.read_text(encoding='utf-8'), filename=str(p))
gate = subprocess.run([sys.executable, '-m', 'unittest', 'discover', '-s', str(HERE), '-p', 'test_gate.py', '-v'],
                      capture_output=True, cwd=ROOT)
(HERE / 'gate.stdout.txt').write_bytes(gate.stdout)
(HERE / 'gate.stderr.txt').write_bytes(gate.stderr)
patch = subprocess.run(['git', 'apply', '--check', str(HERE / 'apartment_material_binding.patch')],
                       capture_output=True, cwd=ROOT)
fixture = (HERE / 'proposed/game/tests/apartment_material_binding_test.gd').read_text(encoding='utf-8')
record = {
    'schema': 'astra.apartment_material_binding.static_review.v1',
    'status': 'prepared_only_not_engine_validated',
    'engine_runs': 0, 'live_writes': 0,
    'python_ast': 'pass', 'gate_test_exit': gate.returncode,
    'gate_stdout_sha256': sha(gate.stdout), 'gate_stderr_sha256': sha(gate.stderr),
    'git_apply_check_exit': patch.returncode,
    'git_apply_check_stdout': patch.stdout.decode(errors='replace'),
    'git_apply_check_stderr': patch.stderr.decode(errors='replace'),
    'focused_check_calls': len(re.findall(r'^\s+_check\(', fixture, re.M)),
    'original_still_matches_live': (ROOT / RELATIVE).read_bytes() == (HERE / 'originals' / RELATIVE).read_bytes(),
    'live_source_sha256': sha((ROOT / RELATIVE).read_bytes()),
    'files': {p.relative_to(HERE).as_posix(): sha(p.read_bytes()) for p in sorted(files)},
    'independent_static_review': {
        'reviewer': '/root/branch_forensics',
        'finding': 'No definite API/type or semantic blocker found in focused fixture; real queued governor callbacks and installed row checks inspected.',
        'limit': 'Fixture hand-constructs finish marker/row; actual build path awaits real-root validation.',
    },
}
(HERE / 'review_checks.json').write_text(json.dumps(record, indent=2) + '\n', encoding='utf-8')
print(json.dumps({key: record[key] for key in ['python_ast', 'gate_test_exit', 'git_apply_check_exit',
    'focused_check_calls', 'original_still_matches_live', 'live_source_sha256']}, indent=2))
raise SystemExit(int(gate.returncode != 0 or patch.returncode != 0 or not record['original_still_matches_live']))
