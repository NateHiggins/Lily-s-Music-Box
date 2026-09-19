"""One source-bound hearing proof through the unchanged serial runner; requires lane handoff."""
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
BASE = ROOT / 'design/astra/evidence/hearing_presence'
RUNNER = ROOT / 'tools/run_godot_serial.ps1'
PWSH = Path(r'C:\Users\nate_\.cache\codex-runtimes\codex-primary-runtime\dependencies\native\powershell\pwsh.exe')
SCENES = {
    'focused': 'res://tests/NpcHearingPresenceTest.tscn',
    'composed': 'res://tests/orison_v2_presence_ledger_test.tscn',
    'authority': 'res://tests/OpenShiftAuthorityTest.tscn',
    'matrix': 'res://tests/OpenShiftSaveMatrixTest.tscn',
}
MARKERS = {'focused': 'NPC HEARING PRESENCE:', 'composed': 'ORISON V2 PRESENCE LEDGER:',
    'authority': 'OPEN SHIFT AUTHORITY TEST:', 'matrix': 'OPEN SHIFT SAVE MATRIX:'}

parser = argparse.ArgumentParser()
parser.add_argument('name')
parser.add_argument('mode', choices=SCENES)
parser.add_argument('--expected-exit', type=int, default=0)
parser.add_argument('--timeout', type=int, default=45)
args = parser.parse_args()
if not re.fullmatch(r'[A-Za-z0-9_-]+', args.name):
    raise SystemExit('Use a fresh plain run name.')
out = BASE / args.name
out.mkdir(parents=True, exist_ok=False)
profile = out / 'appdata'
profile.mkdir()

def sha(bytes):
    return hashlib.sha256(bytes).hexdigest()

def git(*args):
    return subprocess.check_output(['git', '-C', str(ROOT), *args], stderr=subprocess.DEVNULL)

def snapshot(label):
    files = [ROOT / 'game/project.godot']
    for directory, patterns in [('game/scripts', ['*.gd']), ('game/scenes', ['*.tscn', '*.tres']),
                                 ('game/tests', ['*.gd', '*.tscn']), ('game/data', ['*.json'])]:
        for pattern in patterns:
            files.extend((ROOT / directory).rglob(pattern))
    rows = [{'path': p.relative_to(ROOT).as_posix(), 'sha256': sha(p.read_bytes())}
            for p in sorted(set(files)) if p.is_file()]
    encoded = json.dumps(sorted([r['path'], r['sha256']] for r in rows), separators=(',', ':')).encode()
    (out / (label + '.runtime_inputs.json')).write_text(json.dumps(rows, indent=2) + '\n')
    diff = git('diff', 'HEAD', '--binary', '--', 'game')
    (out / (label + '.game.diff')).write_bytes(diff)
    selected = ['game/scripts/reality/npc_observation_ledger.gd',
        'game/tests/npc_hearing_presence_test.gd', 'game/tests/orison_v2_presence_ledger_test.gd',
        'game/scripts/building/building_root.gd', 'game/scripts/building/orison_v2_runtime_root.gd',
        'game/scripts/game/campaign_clock.gd', 'game/scripts/game/reality_game_state.gd',
        'game/scripts/game/open_shift_radiator_ecosystem.gd', 'tools/run_godot_serial.ps1',
        'design/astra/work/hearing_presence/run_case.py',
        'game/tests/NpcHearingPresenceTest.tscn', 'game/tests/orison_v2_presence_ledger_test.tscn']
    copies = {}
    for relative in selected:
        source = ROOT / relative
        if source.is_file():
            destination = out / label / relative
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(source, destination)
            copies[relative] = sha(source.read_bytes())
    return {'head': git('rev-parse', 'HEAD').decode().strip(), 'runtime_input_count': len(rows),
            'runtime_inputs_sha256': sha(encoded), 'tracked_game_diff_sha256': sha(diff), 'source_copies': copies}

env = os.environ.copy()
env['APPDATA'] = str(profile)
for key in ['ORISON_BUILDING_ROOT', 'SHOT_DIR', 'REALITY_TIME', 'REALITY_TIME_OVERRIDE',
            'DAYNIGHT', 'DAYNIGHT_FORCE', 'SCHEDULE', 'SCHEDULE_MINUTE', 'SCHEDULE_DAY',
            'SCHEDULE_DOY', 'WORLD_TIME_LEGACY_CONTROL', 'WORLD_TIME_LEGACY_SOURCE_DIR']:
    env.pop(key, None)
env['CAMPAIGN_TIME_FREEZE'] = '1'
def q(value):
    return "'" + str(value).replace("'", "''") + "'"
log = out / 'godot.stdout.log'
wrapper = out / 'command.ps1'
wrapper.write_text('& ' + q(RUNNER) + ' -ProjectPath ' + q(ROOT / 'game') +
    ' -Scene ' + q(SCENES[args.mode]) + ' -LogPath ' + q(log) +
    ' -TimeoutSeconds ' + str(args.timeout) + " -ExtraArgs @('--verbose')\nexit $LASTEXITCODE\n", encoding='utf-8')
command = [str(PWSH), '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', str(wrapper)]
receipt = {'schema': 'astra.hearing_presence.runtime.v1', 'name': args.name, 'mode': args.mode,
           'scene': SCENES[args.mode], 'expected_exit': args.expected_exit, 'command': command,
           'fresh_appdata': str(profile), 'profile_existed_before_run': False,
           'started_utc': datetime.datetime.now(datetime.timezone.utc).isoformat(),
           'scope': 'real production file/API fixture; no physical human route or multi-process restart claim',
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
raw = '\n'.join(p.read_text(encoding='utf-8-sig', errors='replace') for p in [log, Path(str(log) + '.stderr')] if p.is_file())
receipt['summary_lines'] = [line for line in raw.splitlines() if re.search(r'\[HEARING\]|NPC HEARING PRESENCE|ORISON V2 PRESENCE LEDGER|OPEN SHIFT|RESULT:', line)]
receipt['diagnostic_headers'] = [line for line in raw.splitlines() if re.search(r'WARNING:|ERROR:|SCRIPT ERROR:|Parse Error|leaked|resources still in use', line, re.I)]
receipt['expected_exit_matches'] = process.returncode == args.expected_exit
receipt['diagnostic_gate_exit'] = int(process.returncode != 0 or not receipt['source_unchanged']
    or not any(MARKERS[args.mode] in line and re.search(r'\bPASS\b', line) for line in raw.splitlines())
    or any(re.search(r'ERROR:|SCRIPT ERROR:|Parse Error|leaked|resources still in use|RID allocations|Unreferenced static string', line, re.I)
        for line in raw.splitlines()))
receipt['finished_utc'] = datetime.datetime.now(datetime.timezone.utc).isoformat()
receipt['artifact_hashes'] = {p.relative_to(out).as_posix(): sha(p.read_bytes()) for p in sorted(out.rglob('*'))
    if p.is_file() and p != receipt_path and 'appdata' not in p.relative_to(out).parts}
receipt_path.write_text(json.dumps(receipt, indent=2) + '\n')
print(json.dumps({key: receipt[key] for key in ['name', 'actual_exit', 'expected_exit', 'source_unchanged', 'diagnostic_gate_exit', 'summary_lines', 'diagnostic_headers']}, indent=2), flush=True)
raise SystemExit(receipt['diagnostic_gate_exit'])
