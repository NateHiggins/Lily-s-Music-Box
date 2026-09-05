"""Run one focused material proof after explicit source/lane handoff; no source edits."""
from pathlib import Path
import argparse
import datetime
import hashlib
import json
import os
import re
import shutil
import subprocess
import time

ROOT = Path(__file__).resolve().parents[4]
BASE = ROOT / 'design/astra/evidence/apartment_material_binding'
RUNNER = ROOT / 'tools/run_godot_serial.ps1'
PWSH = Path(r'C:\Users\nate_\.cache\codex-runtimes\codex-primary-runtime\dependencies\native\powershell\pwsh.exe')
SCENE = 'res://tests/ApartmentMaterialBindingTest.tscn'
SELECTED = [
    'game/project.godot', 'game/scripts/reality/apartment_encroachment.gd',
    'game/scripts/reality/living_field.gd', 'game/scripts/building/surface_pass.gd',
    'game/scripts/props/functional_prop.gd',
    'game/tests/apartment_material_binding_test.gd', 'game/tests/ApartmentMaterialBindingTest.tscn',
    'tools/run_godot_serial.ps1', 'design/astra/work/apartment_material_binding/run_case.py',
]


def digest(data):
    return hashlib.sha256(data).hexdigest()


def git(*args):
    return subprocess.check_output(['git', '-C', str(ROOT), *args], stderr=subprocess.DEVNULL)


def assess(raw, native_exit, stable, expected_checks, expect_red):
    footers = re.findall(r'^APARTMENT MATERIAL BINDING: (PASS|FAIL) \((\d+)/(\d+)\)\s*$', raw, re.M)
    passed = re.findall(r'^\[BIND PASS\] (.+)$', raw, re.M)
    failed = re.findall(r'^\[BIND FAIL\] (.+)$', raw, re.M)
    diagnostics = [line for line in raw.splitlines() if re.search(
        r'ERROR:|SCRIPT ERROR:|Parse Error|leaked|resources still in use|RID allocations|Unreferenced static string', line, re.I)]
    complete = len(footers) == 1 and int(footers[0][2]) == expected_checks \
        and int(footers[0][1]) == len(passed) and len(passed) + len(failed) == expected_checks
    # Native exit is independently captured from the serial runner. Only the
    # consistency gate compares it with the fixture's assertion count.
    green = complete and stable and not diagnostics and native_exit == 0 and not failed and footers[0][0] == 'PASS'
    intended_red = complete and stable and not diagnostics and 0 < native_exit < 73 \
        and native_exit == len(failed) and footers[0][0] == 'FAIL'
    return {'complete_footer': complete, 'pass_labels': passed, 'fail_labels': failed,
            'diagnostics': diagnostics, 'green': green, 'intended_red': intended_red,
            'gate_exit': int(not (intended_red if expect_red else green))}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('name')
    parser.add_argument('--expect-red', action='store_true')
    parser.add_argument('--timeout', type=int, default=45)
    args = parser.parse_args()
    if not re.fullmatch(r'[A-Za-z0-9_-]+', args.name):
        raise SystemExit('Use a fresh plain run name.')
    out = BASE / args.name
    out.mkdir(parents=True, exist_ok=False)
    profile = out / 'appdata'
    profile.mkdir(exist_ok=False)

    def snapshot(label):
        files = [ROOT / 'game/project.godot']
        for directory, patterns in [('game/scripts', ['*.gd']), ('game/scenes', ['*.tscn', '*.tres']),
                                    ('game/tests', ['*.gd', '*.tscn']), ('game/data', ['*.json'])]:
            for pattern in patterns:
                files.extend((ROOT / directory).rglob(pattern))
        rows = [{'path': p.relative_to(ROOT).as_posix(), 'sha256': digest(p.read_bytes())}
                for p in sorted(set(files)) if p.is_file()]
        encoded = json.dumps(sorted([r['path'], r['sha256']] for r in rows), separators=(',', ':')).encode()
        (out / (label + '.runtime_inputs.json')).write_text(json.dumps(rows, indent=2) + '\n')
        diff = git('diff', 'HEAD', '--binary', '--', 'game')
        (out / (label + '.game.diff')).write_bytes(diff)
        copies = {}
        for relative in SELECTED:
            source = ROOT / relative
            destination = out / label / relative
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(source, destination)
            copies[relative] = digest(source.read_bytes())
        return {'head': git('rev-parse', 'HEAD').decode().strip(), 'runtime_input_count': len(rows),
                'runtime_inputs_sha256': digest(encoded), 'tracked_game_diff_sha256': digest(diff), 'source_copies': copies}

    env = os.environ.copy()
    env['APPDATA'] = str(profile)
    for key in list(env):
        if key.startswith(('SURFACE_', 'ENCROACH_', 'REALITY_TIME', 'SCHEDULE_', 'DAYNIGHT_')) \
                or key in {'SURFACE', 'ENCROACH', 'LIVING', 'SCHEDULE', 'DAYNIGHT', 'ORISON_BUILDING_ROOT', 'SHOT_DIR'}:
            env.pop(key, None)
    env['CAMPAIGN_TIME_FREEZE'] = '1'
    q = lambda value: "'" + str(value).replace("'", "''") + "'"
    log = out / 'godot.stdout.log'
    wrapper = out / 'command.ps1'
    wrapper.write_text('& ' + q(RUNNER) + ' -ProjectPath ' + q(ROOT / 'game') +
        ' -Scene ' + q(SCENE) + ' -LogPath ' + q(log) + ' -TimeoutSeconds ' + str(args.timeout) +
        " -ExtraArgs @('--verbose')\nexit $LASTEXITCODE\n", encoding='utf-8')
    command = [str(PWSH), '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', str(wrapper)]
    test_source = (ROOT / 'game/tests/apartment_material_binding_test.gd').read_text(encoding='utf-8')
    checks = len(re.findall(r'^\s+_check\(', test_source, re.M))
    receipt = {'schema': 'astra.apartment_material_binding.runtime.v1', 'name': args.name,
               'scene': SCENE, 'command': command, 'expect_red': args.expect_red,
               'expected_checks_from_copied_fixture': checks,
               'fresh_appdata': str(profile), 'profile_existed_before_run': False,
               'started_utc': datetime.datetime.now(datetime.timezone.utc).isoformat(),
               'scope': 'focused actual material/field/governor methods; no building/performance/human proof',
               'source_before': snapshot('source_before')}
    receipt_path = out / 'receipt.json'
    receipt_path.write_text(json.dumps(receipt, indent=2) + '\n')
    start = time.perf_counter()
    process = subprocess.run(command, cwd=ROOT, env=env, capture_output=True)
    (out / 'runner.stdout.log').write_bytes(process.stdout)
    (out / 'runner.stderr.log').write_bytes(process.stderr)
    receipt['actual_exit'] = process.returncode
    receipt['elapsed_seconds'] = round(time.perf_counter() - start, 3)
    receipt['source_after'] = snapshot('source_after')
    receipt['source_unchanged'] = receipt['source_before'] == receipt['source_after']
    raw = '\n'.join(p.read_text(encoding='utf-8-sig', errors='replace') for p in [log, Path(str(log) + '.stderr')]
                    if p.is_file())
    receipt['assessment'] = assess(raw, process.returncode, receipt['source_unchanged'], checks, args.expect_red)
    receipt['warning_lines'] = [line for line in raw.splitlines() if 'WARNING:' in line]
    receipt['finished_utc'] = datetime.datetime.now(datetime.timezone.utc).isoformat()
    receipt['artifact_hashes'] = {p.relative_to(out).as_posix(): digest(p.read_bytes()) for p in sorted(out.rglob('*'))
                                if p.is_file() and p != receipt_path and 'appdata' not in p.relative_to(out).parts}
    receipt_path.write_text(json.dumps(receipt, indent=2) + '\n')
    print(json.dumps({k: receipt[k] for k in ['name', 'actual_exit', 'source_unchanged', 'assessment']}, indent=2), flush=True)
    return receipt['assessment']['gate_exit']


if __name__ == '__main__':
    raise SystemExit(main())
