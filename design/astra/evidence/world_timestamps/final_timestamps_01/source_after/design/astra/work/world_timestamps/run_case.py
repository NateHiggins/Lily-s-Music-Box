"""One isolated real-engine case; execute only after root grants source/runtime lane."""
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
from gate import diagnostic_gate

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
PWSH = Path(r'C:\Users\nate_\.cache\codex-runtimes\codex-primary-runtime\dependencies\native\powershell\pwsh.exe')
SCENES = {
    'timestamps': 'res://tests/WorldTimestampTest.tscn',
    'jobs': 'res://tests/MaintenanceJobTest.tscn',
    'errand': 'res://tests/MaintenanceErrandTest.tscn',
    'register': 'res://tests/NightRegisterTest.tscn',
    'incidents': 'res://tests/OrganismIncidentsTest.tscn',
    'calendar': 'res://tests/CampaignCalendarTest.tscn',
    'save_recovery': 'res://tests/reality_save_recovery_test.tscn',
    'save_compat': 'res://tests/RealitySaveCompatTest.tscn',
}
parser = argparse.ArgumentParser()
parser.add_argument('name')
parser.add_argument('mode', choices=SCENES)
parser.add_argument('--expected-exit', type=int, default=0)
parser.add_argument('--timeout', type=int, default=60)
args = parser.parse_args()
if not re.fullmatch(r'[A-Za-z0-9_-]+', args.name) or not 1 <= args.timeout <= 180:
    raise SystemExit('Use a fresh plain run name and timeout from 1 to 180 seconds.')
out = ROOT / 'design/astra/evidence/world_timestamps' / args.name
out.mkdir(parents=True, exist_ok=False)
profile = out / 'appdata'
profile.mkdir()
def sha(value): return hashlib.sha256(value).hexdigest()
def q(value): return "'" + str(value).replace("'", "''") + "'"
def utc(): return datetime.datetime.now(datetime.timezone.utc).isoformat()
def write_json(path, value): path.write_text(json.dumps(value, indent=2) + '\n', encoding='utf-8')
def snapshot(label):
    rows = {'game/project.godot': sha((ROOT / 'game/project.godot').read_bytes())}
    for directory, patterns in [('game/scripts', ['*.gd']), ('game/tests', ['*.gd', '*.tscn']),
                                ('game/scenes', ['*.tscn', '*.tres']), ('game/data', ['*.json'])]:
        for pattern in patterns:
            for path in (ROOT / directory).rglob(pattern):
                rows[path.relative_to(ROOT).as_posix()] = sha(path.read_bytes())
    write_json(out / (label + '.inputs.json'), rows)
    files = [path.relative_to(HERE / 'proposed').as_posix() for path in (HERE / 'proposed').rglob('*') if path.is_file()]
    files += ['game/scripts/game/campaign_clock.gd', 'game/scripts/game/reality_game_state.gd',
              'game/scripts/game/reality_save_storage.gd', 'tools/run_godot_serial.ps1']
    files += ['design/astra/work/world_timestamps/run_case.py', 'design/astra/work/world_timestamps/gate.py']
    scene_relative = 'game/' + SCENES[args.mode].removeprefix('res://')
    files.append(scene_relative)
    files += ['game/' + path for path in re.findall(r'path="res://([^"\n]+\.gd)"',
        (ROOT / scene_relative).read_text(encoding='utf-8'))]
    copies = {}
    for relative in sorted(set(files)):
        target = out / label / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(ROOT / relative, target)
        copies[relative] = sha((ROOT / relative).read_bytes())
    return {'head': subprocess.check_output(['git', '-C', str(ROOT), 'rev-parse', 'HEAD']).decode().strip(),
            'sha256': sha(json.dumps(sorted(rows.items()), separators=(',', ':')).encode()), 'files': len(rows),
            'source_copies': copies}

env = os.environ.copy()
env['APPDATA'] = str(profile)
for name in ['ORISON_BUILDING_ROOT', 'SHOT_DIR', 'REALITY_TIME', 'REALITY_TIME_OVERRIDE',
             'DAYNIGHT', 'DAYNIGHT_FORCE', 'SCHEDULE', 'SCHEDULE_MINUTE', 'SCHEDULE_DAY', 'SCHEDULE_DOY']:
    env.pop(name, None)
env['CAMPAIGN_TIME_FREEZE'] = '1'
log = out / 'godot.stdout.log'
wrapper = out / 'command.ps1'
wrapper.write_text('& ' + q(ROOT / 'tools/run_godot_serial.ps1') + ' -ProjectPath ' + q(ROOT / 'game')
    + ' -Scene ' + q(SCENES[args.mode]) + ' -LogPath ' + q(log) + ' -TimeoutSeconds ' + str(args.timeout)
    + " -ExtraArgs @('--verbose')\nexit $LASTEXITCODE\n", encoding='utf-8')
command = [str(PWSH), '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', str(wrapper)]
receipt = {'schema': 'astra.world_timestamps.runtime.v1', 'name': args.name, 'mode': args.mode,
    'expected_exit': args.expected_exit, 'command': command, 'fresh_appdata': str(profile),
    'started_utc': utc(), 'source_before': snapshot('source_before'),
    'scope': 'recorded scene only; focused owner callback fixture is not a physical route or restart claim'}
write_json(out / 'receipt.json', receipt)
start = time.perf_counter()
process = subprocess.run(command, cwd=ROOT, env=env, capture_output=True)
(out / 'runner.stdout.log').write_bytes(process.stdout)
(out / 'runner.stderr.log').write_bytes(process.stderr)
receipt.update(actual_exit=process.returncode, elapsed_seconds=round(time.perf_counter() - start, 3),
               finished_utc=utc(), source_after=snapshot('source_after'))
raw = '\n'.join(path.read_text(encoding='utf-8-sig', errors='replace') for path in [log, Path(str(log) + '.stderr')] if path.is_file())
receipt['source_unchanged'] = receipt['source_before'] == receipt['source_after']
receipt['expected_exit_matches'] = process.returncode == args.expected_exit
receipt['summary_lines'] = [line for line in raw.splitlines() if re.search(r'WORLD TIMESTAMPS:|TEST:|PASS \d+/\d+|CAMPAIGN CALENDAR:|RESULT:', line)]
receipt['failed_assertions'] = [line for line in raw.splitlines() if '[WORLD TIMESTAMP FAIL]' in line]
receipt['diagnostic_headers'] = [line for line in raw.splitlines() if re.search(r'WARNING:|ERROR:|SCRIPT ERROR:|Parse Error|leaked|resources still in use', line, re.I)]
receipt['diagnostic_gate'] = diagnostic_gate(args.mode, process.returncode, receipt['source_unchanged'], raw)
receipt['artifact_hashes'] = {path.relative_to(out).as_posix(): sha(path.read_bytes()) for path in sorted(out.rglob('*'))
    if path.is_file() and path.name != 'receipt.json' and 'appdata' not in path.relative_to(out).parts}
write_json(out / 'receipt.json', receipt)
print(json.dumps({key: receipt[key] for key in ['actual_exit', 'source_unchanged', 'diagnostic_gate', 'summary_lines', 'diagnostic_headers']}, indent=2))
raise SystemExit(receipt['diagnostic_gate']['exit'])
