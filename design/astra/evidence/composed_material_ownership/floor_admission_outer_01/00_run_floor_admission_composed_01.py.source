"""One actual full-building run with the reviewed floor owner and complete observer."""
from pathlib import Path
import argparse
import datetime
import hashlib
import json
import os
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[4]
PACKAGE = ROOT / 'design/astra/work/composed_material_invariants'
sys.path.insert(0, str(PACKAGE / 'runtime_execution'))
from environment_contract import prepare_environment, actual_wrapper_environment, WRAPPER
from invoke_wrapper import PINNED

OWNER = 'game/scripts/reality/apartment_encroachment.gd'
OWNER_SHA = '2a440504ab80404f4d9f4ab16138df7db9255801ca879ff91aabafe3c7f4d0ca'
FIXTURE = 'game/tests/vulkan_composed_root_test.gd'
ORIGINAL_SHA = '5ec63c36c6181b33c02bd2255039e9bf4e8db0c4465a45ac641d1481f422d6d3'
OBSERVER_SHA = 'd67ce1ac8b19d51f6d4ccc88bc3fe11599dd6068afaccea6abb1d9ec50712508'
ORIGINAL = PACKAGE / 'originals' / FIXTURE
PROPOSED = PACKAGE / 'revisions/all_registry_lifecycle_01/proposed' / FIXTURE
HEAD = 'da68962aaeaabf56851abb7190dda14d7ff5675f'
NAME = 'material_floor_admission_v1_full_01'
RUN = ROOT / 'design/astra/evidence/vulkan_composed/runs' / NAME
OUT = ROOT / 'design/astra/evidence/composed_material_ownership/floor_admission_outer_01'
PWSH = Path(r'C:\Users\nate_\.cache\codex-runtimes\codex-primary-runtime\dependencies\native\powershell\pwsh.exe')


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def empty_lane():
    census = subprocess.run([str(PWSH), '-NoProfile', '-Command',
        'Get-Process -Name "Godot*" -ErrorAction SilentlyContinue | Select-Object Id,ProcessName | ConvertTo-Json'],
        capture_output=True)
    if census.stdout.strip() or census.stderr.strip():
        raise RuntimeError('Godot lane is not verified empty; source mutation refused.')


def swap(source, before, after):
    target = ROOT / FIXTURE
    if sha(target) != before or sha(source) != after:
        raise RuntimeError('Exact fixture swap precondition failed.')
    temporary = target.with_name(target.name + '.astra_material_swap.tmp')
    with temporary.open('xb') as handle:
        handle.write(source.read_bytes())
    if sha(temporary) != after:
        raise RuntimeError('Temporary fixture bytes differ; target preserved.')
    os.replace(temporary, target)
    if sha(target) != after:
        raise RuntimeError('Fixture installation did not preserve exact bytes.')


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--execute', action='store_true')
    args = parser.parse_args()
    command = [sys.executable, '-B', str(WRAPPER), 'v1', 'candidate', NAME, '--scope', 'full']
    env, environment_receipt = prepare_environment(os.environ)
    projected = actual_wrapper_environment(env, RUN / 'APPDATA', RUN / 'frames')
    expected = dict(PINNED, **{OWNER: OWNER_SHA, FIXTURE: ORIGINAL_SHA})
    report = {'status': 'PREPARED_NO_ENGINE_OR_GAME_MUTATION', 'expected_head': HEAD,
        'recorded_at_utc': datetime.datetime.now(datetime.timezone.utc).isoformat(),
        'command': command, 'run_directory': str(RUN), 'expected_preinstall_sources': expected,
        'installed_observer_sha256': OBSERVER_SHA, 'environment': environment_receipt,
        'projected_child_environment': {key: projected[key] for key in [
            *environment_receipt['explicit_wrapper_material_environment'], 'APPDATA', 'SHOT_DIR',
            'ORISON_BUILDING_ROOT', 'VULKAN_COMPOSED_VARIANT', 'VULKAN_COMPOSED_SCOPE',
            'CAMPAIGN_TIME_FREEZE', 'WEATHER_SEED', 'TITLE_SCREEN_SILENT']}}
    if not args.execute:
        print(json.dumps(report, indent=2))
        return 0
    empty_lane()
    actual_head = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT).decode().strip()
    observed = {path: sha(ROOT / path) for path in expected}
    if actual_head != HEAD or observed != expected:
        raise RuntimeError('Declared HEAD or source preflight differs; no fixture installed.')
    if sha(ORIGINAL) != ORIGINAL_SHA or sha(PROPOSED) != OBSERVER_SHA:
        raise RuntimeError('Reviewed fixture package differs; no fixture installed.')
    if RUN.exists() or OUT.exists():
        raise RuntimeError('One-time run or outer receipt already exists; preserve it.')
    OUT.mkdir(parents=True)
    bound = [Path(__file__), PACKAGE / 'runtime_execution/environment_contract.py',
             PACKAGE / 'runtime_execution/invoke_wrapper.py', ORIGINAL, PROPOSED]
    report['invocation_sources'] = {}
    for index, path in enumerate(bound):
        shutil.copyfile(path, OUT / f'{index:02d}_{path.name}.source')
        report['invocation_sources'][str(path)] = sha(path)
    report['source_preflight'] = observed
    report['fixture_restored'] = False
    code = 1
    try:
        swap(PROPOSED, ORIGINAL_SHA, OBSERVER_SHA)
        report['status'] = 'WRAPPER_RUNNING'
        (OUT / 'receipt.json').write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
        result = subprocess.run(command, cwd=ROOT, env=env, capture_output=True)
        (OUT / 'invocation.stdout.log').write_bytes(result.stdout)
        (OUT / 'invocation.stderr.log').write_bytes(result.stderr)
        report.update(status='WRAPPER_RETURNED', wrapper_exit=result.returncode)
        code = result.returncode
        if (RUN / 'result.json').is_file():
            report['runtime_result_sha256'] = sha(RUN / 'result.json')
    finally:
        try:
            empty_lane()
            if sha(ROOT / FIXTURE) == OBSERVER_SHA:
                swap(ORIGINAL, OBSERVER_SHA, ORIGINAL_SHA)
            report['fixture_restored'] = sha(ROOT / FIXTURE) == ORIGINAL_SHA
            report['final_fixture_sha256'] = sha(ROOT / FIXTURE)
            report['owner_unchanged'] = sha(ROOT / OWNER) == OWNER_SHA
            report['invocation_sources_unchanged'] = all(sha(Path(path)) == digest
                for path, digest in report['invocation_sources'].items())
        except Exception as error:
            report['cleanup_error'] = str(error)
        (OUT / 'receipt.json').write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
        print(json.dumps({key: report.get(key) for key in ['status', 'wrapper_exit',
            'runtime_result_sha256', 'fixture_restored', 'final_fixture_sha256',
            'owner_unchanged', 'invocation_sources_unchanged', 'cleanup_error']}, indent=2))
    return int(code != 0 or not all(report.get(key) is True for key in
        ['fixture_restored', 'owner_unchanged', 'invocation_sources_unchanged']))


if __name__ == '__main__':
    raise SystemExit(main())
