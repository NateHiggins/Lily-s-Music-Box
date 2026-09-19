"""Copy exactly ten clean C1 sources, then run their existing Python contracts."""
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
import hashlib
import json
import os
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[4]
REPLAY = ROOT / 'design/astra/work/f01_reconstruction_review/source_replay_01'
OUT = ROOT / 'design/astra/evidence/f01_source_replay/installed_01'
HEAD = '77dc5f75cd7cb68be6d1f3d0be4f57ff1b06c3d4'
REF = 'c34ad283df148496fbd98e68638470835c930c5c'
PWSH = r'C:\Users\nate_\.cache\codex-runtimes\codex-primary-runtime\dependencies\native\powershell\pwsh.exe'
ALLOWED = [
    'art/data/m11c1/floor01_source_ownership.json',
    'tools/m11c1_floor01_owner_first/__init__.py',
    'tools/m11c1_floor01_owner_first/author_source_ownership.py',
    'tools/m11c1_floor01_owner_first/generate_owner_first_candidate.py',
    'tools/m11c1_floor01_owner_first/owner_first_export.py',
    'tools/m11c1_floor01_owner_first/run_disposable_export.py',
    'tools/m11c1_floor01_owner_first/source_ownership.py',
    'tools/rehearse_orison_floor01_partition.py',
    'tools/tests/test_m11c1_floor01_source_ownership.py',
    'tools/tests/test_m11c1_owner_first_export.py',
]


def git(*args):
    return subprocess.check_output(['git', *args], cwd=ROOT, stderr=subprocess.DEVNULL)


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def write(path, data):
    path.write_text(json.dumps(data, indent=2) + '\n', encoding='utf-8', newline='\n')


def protected_snapshot(records):
    return {row['path']: {'raw_sha256': sha(ROOT / row['path']),
        'working_clean_blob': git('hash-object', '--path=' + row['path'], row['path']).decode().strip()}
        for row in records}


assert git('rev-parse', 'HEAD').decode().strip() == HEAD
assert not git('diff', '--cached', '--name-only')
assert not git('diff', 'HEAD', '--name-only', '--', 'game', 'tools', 'art')
assert not git('ls-files', '--others', '--exclude-standard', '--', 'game', 'tools', 'art')
lane = subprocess.run([PWSH, '-NoProfile', '-Command',
    'Get-Process -Name "Godot*" -ErrorAction SilentlyContinue | Select-Object Id,ProcessName | ConvertTo-Json'], capture_output=True)
assert not lane.stdout.strip() and not lane.stderr.strip(), 'Godot lane must be empty before source installation.'
manifest_path = REPLAY / 'source_manifest.json'
manifest = json.loads(manifest_path.read_text(encoding='utf-8'))
assert manifest['source_reference'] == REF and {row['path'] for row in manifest['files']} == set(ALLOWED)
assert len(manifest['files']) == 10
for row in manifest['files']:
    target, source = ROOT / row['path'], REPLAY / row['replay_path']
    assert target.resolve().is_relative_to(ROOT) and source.resolve().is_relative_to(REPLAY / 'tree')
    assert not target.exists(), str(target)
    raw = source.read_bytes()
    assert len(raw) == row['bytes'] and hashlib.sha256(raw).hexdigest() == row['sha256']
    assert raw == git('show', REF + ':' + row['path'])
    assert git('rev-parse', REF + ':' + row['path']).decode().strip() == row['git_blob']
selection = json.loads((ROOT / 'design/astra/work/renderer_material_checkpoint/landing_01/selection.json').read_text())
protected = protected_snapshot(selection['protected'])
assert all(protected[row['path']] == {'raw_sha256': row['raw_sha256'], 'working_clean_blob': row['head_blob']} for row in selection['protected'])
OUT.mkdir(parents=True, exist_ok=False)
(OUT / 'installer.py.source').write_bytes(Path(__file__).read_bytes())
(OUT / 'source_manifest.json.source').write_bytes(manifest_path.read_bytes())
(OUT / 'empty_lane.stdout.log').write_bytes(lane.stdout)
(OUT / 'empty_lane.stderr.log').write_bytes(lane.stderr)
write(OUT / 'protected.before.json', protected)
(OUT / 'before.source.diff').write_bytes(git('diff', 'HEAD', '--binary', '--', 'game', 'tools', 'art'))
record = {'status': 'INSTALLING', 'head': HEAD, 'reference': REF, 'allowed_paths': ALLOWED,
    'source_manifest_sha256': sha(manifest_path), 'installed': [],
    'scope': 'Attributable source/tool reconstruction only; no Blender/Godot/exported geometry/provider/default or acceptance adoption.'}
write(OUT / 'receipt.json', record)
for row in manifest['files']:
    target = ROOT / row['path']
    target.parent.mkdir(parents=True, exist_ok=True)
    with target.open('xb') as handle:
        handle.write((REPLAY / row['replay_path']).read_bytes())
    assert sha(target) == row['sha256']
    record['installed'].append({'path': row['path'], 'sha256': sha(target), 'source_blob': row['git_blob']})
record['status'] = 'INSTALLED_EXISTING_CONTRACTS_RUNNING'
write(OUT / 'receipt.json', record)
commands = [
    ('ownership_catalog', [sys.executable, '-B', 'tools/m11c1_floor01_owner_first/source_ownership.py', '--json']),
    ('authorship_check', [sys.executable, '-B', 'tools/m11c1_floor01_owner_first/author_source_ownership.py', '--check']),
    ('ownership_selftest', [sys.executable, '-B', 'tools/tests/test_m11c1_floor01_source_ownership.py', '-v']),
    ('exporter_selftest', [sys.executable, '-B', 'tools/tests/test_m11c1_owner_first_export.py', '-v']),
]


def run(item):
    name, command = item
    started = time.perf_counter()
    process = subprocess.run(command, cwd=ROOT, capture_output=True, env={**os.environ, 'PYTHONIOENCODING': 'utf-8'})
    (OUT / (name + '.stdout.log')).write_bytes(process.stdout)
    (OUT / (name + '.stderr.log')).write_bytes(process.stderr)
    return {'name': name, 'command': command, 'actual_exit': process.returncode,
        'elapsed_seconds': time.perf_counter() - started,
        'stdout_sha256': hashlib.sha256(process.stdout).hexdigest(),
        'stderr_sha256': hashlib.sha256(process.stderr).hexdigest()}


with ThreadPoolExecutor(max_workers=4) as pool:
    results = list(pool.map(run, commands))
after = protected_snapshot(selection['protected'])
write(OUT / 'protected.after.json', after)
assert protected == after
assert all(sha(ROOT / row['path']) == row['sha256'] for row in manifest['files'])
assert not git('diff', 'HEAD', '--name-only', '--', 'game', 'tools', 'art')
assert set(git('ls-files', '--others', '--exclude-standard', '--', 'game', 'tools', 'art').decode().splitlines()) == set(ALLOWED)
record.update(status='SOURCE_REPLAY_VALIDATED' if all(row['actual_exit'] == 0 for row in results) else 'SOURCE_REPLAY_CONTRACT_FAILURE',
    runs=results, protected_unchanged=True, only_named_ten_sources_added=True, installed_source_bytes_unchanged=True,
    human_or_production_geometry_acceptance=False, evidence_files={p.name: sha(p) for p in OUT.iterdir() if p.is_file() and p.name != 'receipt.json'})
write(OUT / 'receipt.json', record)
print(json.dumps({'status': record['status'], 'installed_paths': len(record['installed']),
    'protected_unchanged': True, 'runs': [{'name': row['name'], 'actual_exit': row['actual_exit']} for row in results],
    'receipt_sha256': sha(OUT / 'receipt.json')}, indent=2))
raise SystemExit(int(any(row['actual_exit'] != 0 for row in results)))
