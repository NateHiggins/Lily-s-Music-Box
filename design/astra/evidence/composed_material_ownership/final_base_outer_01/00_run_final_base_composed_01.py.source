"""Final base-fixture V1 composition. Existing wrapper and environment only."""
from pathlib import Path
import argparse
import datetime
import hashlib
import json
import os
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[4]
PACKAGE = ROOT / 'design/astra/work/composed_material_invariants'
sys.path.insert(0, str(PACKAGE / 'runtime_execution'))
from environment_contract import prepare_environment, actual_wrapper_environment, WRAPPER
from invoke_wrapper import PINNED

HEAD = 'da68962aaeaabf56851abb7190dda14d7ff5675f'
OWNER = 'game/scripts/reality/apartment_encroachment.gd'
OWNER_SHA = '1a1b067ff5b95c03fea739747c97deaaf9621e03a635b318b3379cef07bd3776'
FIXTURE = 'game/tests/vulkan_composed_root_test.gd'
FIXTURE_SHA = '5ec63c36c6181b33c02bd2255039e9bf4e8db0c4465a45ac641d1481f422d6d3'
NAME = 'candidate_v1_material_final_01'
RUN = ROOT / 'design/astra/evidence/vulkan_composed/runs' / NAME
OUT = ROOT / 'design/astra/evidence/composed_material_ownership/final_base_outer_01'
PWSH = Path(r'C:\Users\nate_\.cache\codex-runtimes\codex-primary-runtime\dependencies\native\powershell\pwsh.exe')


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def empty_lane():
    result = subprocess.run([str(PWSH), '-NoProfile', '-Command',
        'Get-Process -Name "Godot*" -ErrorAction SilentlyContinue | Select-Object Id,ProcessName | ConvertTo-Json'], capture_output=True)
    if result.stdout.strip() or result.stderr.strip():
        raise RuntimeError('Godot lane is not verified empty.')


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--execute', action='store_true')
    args = parser.parse_args()
    env, contract = prepare_environment(os.environ)
    expected = dict(PINNED, **{OWNER: OWNER_SHA, FIXTURE: FIXTURE_SHA})
    command = [sys.executable, '-B', str(WRAPPER), 'v1', 'candidate', NAME, '--scope', 'full']
    projected = actual_wrapper_environment(env, RUN / 'APPDATA', RUN / 'frames')
    report = {'status': 'PREPARED_NO_ENGINE_OR_SOURCE_MUTATION', 'expected_head': HEAD,
        'recorded_at_utc': datetime.datetime.now(datetime.timezone.utc).isoformat(),
        'command': command, 'expected_sources': expected, 'environment': contract,
        'projected_child_environment': {key: projected[key] for key in [
            *contract['explicit_wrapper_material_environment'], 'APPDATA', 'SHOT_DIR',
            'ORISON_BUILDING_ROOT', 'VULKAN_COMPOSED_VARIANT', 'VULKAN_COMPOSED_SCOPE',
            'CAMPAIGN_TIME_FREEZE', 'WEATHER_SEED', 'TITLE_SCREEN_SILENT']}}
    if not args.execute:
        print(json.dumps(report, indent=2))
        return 0
    empty_lane()
    if subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT).decode().strip() != HEAD:
        raise RuntimeError('Declared HEAD changed.')
    if {path: sha(ROOT / path) for path in expected} != expected:
        raise RuntimeError('Declared source preflight changed.')
    if RUN.exists() or OUT.exists():
        raise RuntimeError('Fresh output names required.')
    OUT.mkdir(parents=True)
    report['invocation_sources'] = {}
    for index, path in enumerate([Path(__file__), PACKAGE / 'runtime_execution/environment_contract.py',
                                  PACKAGE / 'runtime_execution/invoke_wrapper.py']):
        (OUT / f'{index:02d}_{path.name}.source').write_bytes(path.read_bytes())
        report['invocation_sources'][str(path)] = sha(path)
    report['status'] = 'WRAPPER_RUNNING'
    receipt = OUT / 'receipt.json'
    receipt.write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
    result = subprocess.run(command, cwd=ROOT, env=env, capture_output=True)
    (OUT / 'invocation.stdout.log').write_bytes(result.stdout)
    (OUT / 'invocation.stderr.log').write_bytes(result.stderr)
    report.update(status='WRAPPER_RETURNED', wrapper_exit=result.returncode)
    if (RUN / 'result.json').is_file():
        report['runtime_result_sha256'] = sha(RUN / 'result.json')
    empty_lane()
    report['declared_sources_unchanged'] = {path: sha(ROOT / path) for path in expected} == expected
    report['invocation_sources_unchanged'] = all(sha(Path(path)) == digest
        for path, digest in report['invocation_sources'].items())
    receipt.write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
    print(json.dumps({key: report.get(key) for key in ['status', 'wrapper_exit',
        'runtime_result_sha256', 'declared_sources_unchanged', 'invocation_sources_unchanged']}, indent=2))
    return int(result.returncode != 0 or not report['declared_sources_unchanged']
        or not report['invocation_sources_unchanged'])


if __name__ == '__main__':
    raise SystemExit(main())
