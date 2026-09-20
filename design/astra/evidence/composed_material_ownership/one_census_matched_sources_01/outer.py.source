"""Hold inactive equivalence copies at baseline bytes for a one-owner comparison."""
from pathlib import Path
import hashlib
import json
import os
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[4]
BASE = ROOT / 'design/astra/evidence/vulkan_composed/runs/material_floor_admission_v1_full_01'
OUT = ROOT / 'design/astra/evidence/composed_material_ownership/one_census_matched_sources_01'
PACKAGE = ROOT / 'design/astra/work/encroachment_sweep/equivalence_revisions/runtime_plan_2a440_01/package.json'
INVOKE = Path(__file__).with_name('run_one_census_composed_01.py')
PWSH = Path(r'C:\Users\nate_\.cache\codex-runtimes\codex-primary-runtime\dependencies\native\powershell\pwsh.exe')
OWNER = 'game/scripts/reality/apartment_encroachment.gd'
FIXTURE = 'game/tests/vulkan_composed_root_test.gd'
NEW_OWNER = '1a1b067ff5b95c03fea739747c97deaaf9621e03a635b318b3379cef07bd3776'


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def empty_lane():
    p = subprocess.run([str(PWSH), '-NoProfile', '-Command',
        'Get-Process -Name "Godot*" -ErrorAction SilentlyContinue | Select-Object Id,ProcessName | ConvertTo-Json'], capture_output=True)
    if p.stdout.strip() or p.stderr.strip():
        raise RuntimeError('Godot lane not verified empty; no source swap permitted.')


def replace_bytes(path, raw, expected):
    if sha(path) != expected:
        raise RuntimeError('Source changed before exact swap: ' + str(path))
    temp = path.with_name(path.name + '.astra_matched_source.tmp')
    with temp.open('xb') as handle:
        handle.write(raw)
    os.replace(temp, path)
    if path.read_bytes() != raw:
        raise RuntimeError('Source byte verification failed: ' + str(path))


empty_lane()
assert sha(BASE / 'result.json') == 'a989c22dcab75312591058f50ba7d18ce2e9a073e254b0f929572f2a58ca452e'
assert sha(PACKAGE) == '581d257769535d35a27891722ea74fa75487ab567bae639c131f978b48c0f607'
assert sha(INVOKE) == '43bcf603d66a29c8384e4cd26c49174c3665b12dc90f1fb1809bf5586e25b428'
baseline = json.loads((BASE / 'result.json').read_text())
new_tests = json.loads(PACKAGE.read_text())['install']
changed = {path: digest for path, digest in new_tests.items() if baseline['before']['files'][path] != digest}
assert set(changed) == {'game/tests/fixtures/encroachment_sweep/' + name + '.gd'
                        for name in ['baseline', 'candidate', 'drop_late', 'priority']}
expected_current = dict(baseline['before']['files'])
expected_current.update(changed)
expected_current[OWNER] = NEW_OWNER
expected_current[FIXTURE] = '5ec63c36c6181b33c02bd2255039e9bf4e8db0c4465a45ac641d1481f422d6d3'
paths = subprocess.check_output(['git', 'ls-files', '--cached', '--others', '--exclude-standard', '-z', '--', 'game', 'tools'], cwd=ROOT).decode().split('\0')
actual = {path: sha(ROOT / path) for path in sorted(set(paths)) if path and (ROOT / path).is_file()}
assert actual == expected_current, 'Unexpected game/tool source difference outside the declared owner and four inactive test copies.'
OUT.mkdir(parents=True, exist_ok=False)
report = {'status': 'SOURCE_MATCH_PREFLIGHT', 'baseline_result_sha256': sha(BASE / 'result.json'),
    'owner_sha256': NEW_OWNER, 'temporary_test_copies': {}, 'restored_new_test_copies': False,
    'meaning': 'The four rebased equivalence copies are not loaded by the composed scene. Temporarily use captured baseline bytes so the two actual run source maps differ only at the production owner. Restore the new tested copies after completion.',
    'invocation_source_sha256': sha(INVOKE), 'outer_source_sha256': sha(Path(__file__))}
saved = {}
for index, (path, digest) in enumerate(changed.items()):
    old = BASE / 'before_sources' / path
    key = 'before_sources/' + path
    assert sha(old) == baseline['artifacts'][key] == baseline['before']['files'][path]
    saved[path] = (ROOT / path).read_bytes()
    (OUT / f'{index}_new.raw').write_bytes(saved[path])
    (OUT / f'{index}_baseline.raw').write_bytes(old.read_bytes())
    report['temporary_test_copies'][path] = {'new_sha256': digest, 'baseline_sha256': sha(old),
                                            'saved_new': f'{index}_new.raw', 'saved_baseline': f'{index}_baseline.raw'}
shutil.copy2(Path(__file__), OUT / 'outer.py.source')
shutil.copy2(INVOKE, OUT / 'invocation.py.source')
code = 1
try:
    for path, row in report['temporary_test_copies'].items():
        replace_bytes(ROOT / path, (BASE / 'before_sources' / path).read_bytes(), row['new_sha256'])
    report['status'] = 'COMPOSED_RUN_RUNNING'
    (OUT / 'receipt.json').write_text(json.dumps(report, indent=2) + '\n')
    p = subprocess.run([sys.executable, '-B', str(INVOKE), '--execute'], cwd=ROOT, capture_output=True)
    (OUT / 'invocation.stdout.log').write_bytes(p.stdout)
    (OUT / 'invocation.stderr.log').write_bytes(p.stderr)
    code = p.returncode
    report.update(status='COMPOSED_RUN_RETURNED', invocation_exit=code)
finally:
    try:
        empty_lane()
        for path, row in report['temporary_test_copies'].items():
            current = sha(ROOT / path)
            if current == row['baseline_sha256']:
                replace_bytes(ROOT / path, saved[path], current)
            elif current != row['new_sha256']:
                raise RuntimeError('Unexpected test edit; do not overwrite: ' + path)
        report['restored_new_test_copies'] = all(sha(ROOT / path) == row['new_sha256'] for path, row in report['temporary_test_copies'].items())
    except Exception as error:
        report['cleanup_error'] = str(error)
    (OUT / 'receipt.json').write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps({key: report.get(key) for key in ['status', 'invocation_exit', 'restored_new_test_copies', 'cleanup_error']}, indent=2))
raise SystemExit(int(code != 0 or report['restored_new_test_copies'] is not True))
