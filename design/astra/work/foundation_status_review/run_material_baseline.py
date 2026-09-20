"""One exact fixture-only material baseline; restore the fixture in finally."""
from pathlib import Path
import hashlib
import json
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[4]
EXECUTION = ROOT / 'design/astra/work/composed_material_invariants/runtime_execution'
EVIDENCE = ROOT / 'design/astra/evidence/composed_material_ownership'
OUT = EVIDENCE / 'initial_green_outer_01'
PWSH = Path(r'C:\Users\nate_\.cache\codex-runtimes\codex-primary-runtime\dependencies\native\powershell\pwsh.exe')
OUT.mkdir(parents=True, exist_ok=False)


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


sources = [Path(__file__), *[EXECUTION / name for name in
    ['environment_contract.py', 'invoke_wrapper.py', 'source_operation.py']]]
source_hashes = {str(path.relative_to(ROOT)): sha(path) for path in sources}
for path in sources:
    shutil.copy2(path, OUT / (path.name + '.source'))
census_command = [str(PWSH), '-NoProfile', '-Command',
    'Get-Process -Name "Godot*" -ErrorAction SilentlyContinue | Select-Object Id,ProcessName | ConvertTo-Json']
census = subprocess.run(census_command, capture_output=True)
(OUT / 'prelaunch_processes.stdout').write_bytes(census.stdout)
(OUT / 'prelaunch_processes.stderr').write_bytes(census.stderr)
if census.stdout.strip() or census.stderr.strip():
    raise SystemExit('Godot lane not verified empty; fixture installation refused.')


def run(label, command):
    process = subprocess.run(command, cwd=ROOT, capture_output=True)
    (OUT / (label + '.stdout.log')).write_bytes(process.stdout)
    (OUT / (label + '.stderr.log')).write_bytes(process.stderr)
    return {'command': command, 'exit': process.returncode}


report = {'invocation_sources': source_hashes, 'operations': {}}
try:
    report['operations']['install'] = run('install', [sys.executable, '-B', str(EXECUTION / 'source_operation.py'),
        'install_fixture', '--execute', '--receipt-dir', str(EVIDENCE / 'initial_green_fixture_install_01')])
    if report['operations']['install']['exit'] != 0:
        raise RuntimeError('Exact fixture installation failed; no engine launched.')
    report['operations']['baseline'] = run('baseline', [sys.executable, '-B', str(EXECUTION / 'invoke_wrapper.py'),
        'baseline', '--execute', '--receipt-dir', str(EVIDENCE / 'initial_green_invocation_01')])
finally:
    report['operations']['restore'] = run('restore', [sys.executable, '-B', str(EXECUTION / 'source_operation.py'),
        'restore_fixture', '--execute', '--receipt-dir', str(EVIDENCE / 'initial_green_fixture_restore_01')])
    report['invocation_sources_unchanged'] = source_hashes == {str(path.relative_to(ROOT)): sha(path) for path in sources}
    (OUT / 'receipt.json').write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
    print(json.dumps(report, indent=2))
raise SystemExit(int(any(row['exit'] != 0 for row in report['operations'].values()) or not report['invocation_sources_unchanged']))
