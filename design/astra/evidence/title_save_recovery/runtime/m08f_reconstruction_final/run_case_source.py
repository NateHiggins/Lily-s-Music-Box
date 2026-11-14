import argparse
import datetime
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import time

ROOT = Path(r'C:\PleaseRemainOnTheLine-astra')
BASE = Path(__file__).resolve().parent
PWSH = r'C:\Users\nate_\.cache\codex-runtimes\codex-primary-runtime\dependencies\native\powershell\pwsh.exe'
parser = argparse.ArgumentParser()
parser.add_argument('case')
parser.add_argument('scene')
parser.add_argument('--timeout', type=int, default=60)
parser.add_argument('--expected-exit', type=int, default=0)
parser.add_argument('--legacy', default='')
parser.add_argument('--root', choices=['v1', 'v2'])
parser.add_argument('--windowed', action='store_true')
cfg = parser.parse_args()
out = BASE / 'runtime' / cfg.case
out.mkdir(parents=True, exist_ok=False)

def sha(data):
    return hashlib.sha256(data).hexdigest()

def git(*args):
    return subprocess.check_output(['git', '-C', str(ROOT), *args], stderr=subprocess.DEVNULL)

def snapshot(tag):
    diff = git('diff', 'HEAD', '--binary', '--', 'game', 'tools')
    (out / (tag + '.diff')).write_bytes(diff)
    game_diff = git('diff', 'HEAD', '--binary', '--', 'game')
    (out / (tag + '.game.diff')).write_bytes(game_diff)
    paths = set(git('diff', 'HEAD', '--name-only', '--', 'game', 'tools').decode().splitlines()
                + git('ls-files', '--others', '--exclude-standard', 'game', 'tools').decode().splitlines())
    hashes = {}
    for path in sorted(paths):
        source = ROOT / path
        if not source.is_file():
            continue
        raw = source.read_bytes()
        hashes[path] = sha(raw)
        dest = out / (tag + '_sources') / path
        dest.parent.mkdir(parents=True, exist_ok=True)
        dest.write_bytes(raw)
    return {'head': git('rev-parse', 'HEAD').decode().strip(), 'diff_sha256': sha(diff),
            'game_diff_sha256': sha(game_diff), 'files': hashes}

def quote(value):
    return "'" + str(value).replace("'", "''") + "'"

env = os.environ.copy()
profile = out / 'userdata'
profile.mkdir()
frames = out / 'frames'
env['APPDATA'] = str(profile)
for key in ['ORISON_BUILDING_ROOT', 'DAYNIGHT', 'DAYNIGHT_FORCE', 'SCHEDULE', 'SCHEDULE_MINUTE',
            'SCHEDULE_DAY', 'SCHEDULE_DOY', 'CAMPAIGN_TIME_FREEZE', 'SHOT_DIR',
            'WORLD_TIME_LEGACY_CONTROL', 'TITLE_SCREEN_SILENT', 'ORISON_TITLE_DEBUG']:
    env.pop(key, None)
if cfg.root:
    env['ORISON_BUILDING_ROOT'] = cfg.root
env['TITLE_LEGACY_CONTROL'] = cfg.legacy
env['TITLE_LEGACY_SOURCE_DIR'] = str(ROOT / 'design/astra/evidence/title_save_recovery/legacy_sources')
env['TITLE_ACTUAL_RECEIPT'] = str(out / 'actual_launch.json')
env['SHOT_DIR'] = str(frames)
log = out / 'stdout.log'
command = '& ' + quote(ROOT / 'tools/run_godot_serial.ps1') + ' -Scene ' + quote(cfg.scene)
command += ' -ProjectPath ' + quote(ROOT / 'game') + ' -LogPath ' + quote(log)
command += ' -TimeoutSeconds ' + str(cfg.timeout) + " -ExtraArgs @('--verbose')"
if cfg.windowed:
    command += ' -Windowed'
command += '\nexit $LASTEXITCODE'
argv = [PWSH, '-NoProfile', '-ExecutionPolicy', 'Bypass', '-Command', command]
(out / 'run_case_source.py').write_bytes(Path(__file__).read_bytes())
receipt = {'schema': 'astra.title_save_recovery.case.v1', 'case': cfg.case, 'scene': cfg.scene,
           'command': argv, 'APPDATA': str(profile), 'fresh_profile_before_autoload': True,
           'test_directory_precreated': False, 'expected_exit': cfg.expected_exit,
           'legacy_control': cfg.legacy, 'selected_root_override': cfg.root,
           'windowed': cfg.windowed,
           'runner_sha256': sha(Path(__file__).read_bytes()),
           'serial_runner_sha256': sha((ROOT / 'tools/run_godot_serial.ps1').read_bytes()),
           'case_environment': {k: env.get(k, '') for k in ['APPDATA', 'ORISON_BUILDING_ROOT', 'TITLE_LEGACY_CONTROL',
               'TITLE_LEGACY_SOURCE_DIR', 'TITLE_ACTUAL_RECEIPT', 'SHOT_DIR', 'ORISON_TITLE_DEBUG']},
           'hardware_context': 'Godot4.7.1 RTX4080/i7-13700KF; process wall time, not performance proof',
           'started_at_utc': datetime.datetime.now(datetime.timezone.utc).isoformat(), 'before': snapshot('source_before')}
started = time.perf_counter()
proc = subprocess.run(argv, cwd=ROOT, env=env, capture_output=True)
receipt['elapsed_seconds'] = round(time.perf_counter() - started, 3)
receipt['actual_exit'] = proc.returncode
receipt['matches_expected_exit'] = proc.returncode == cfg.expected_exit
(out / 'runner.stdout.log').write_bytes(proc.stdout)
(out / 'runner.stderr.log').write_bytes(proc.stderr)
receipt['after'] = snapshot('source_after')
receipt['broad_source_unchanged'] = receipt['before'] == receipt['after']
before_game = {p: h for p, h in receipt['before']['files'].items() if p.startswith('game/')}
after_game = {p: h for p, h in receipt['after']['files'].items() if p.startswith('game/')}
receipt['runtime_source_unchanged'] = (before_game == after_game
    and receipt['before']['head'] == receipt['after']['head']
    and receipt['before']['game_diff_sha256'] == receipt['after']['game_diff_sha256'])
raw = '\n'.join(p.read_text(encoding='utf-8-sig', errors='replace') for p in [log, Path(str(log) + '.stderr')] if p.exists())
receipt['diagnostic_headers'] = [s for s in raw.splitlines() if re.search(r'WARNING:|ERROR:|SCRIPT ERROR:|Parse Error|leaked|resources still in use', s, re.I)]
receipt['summary_lines'] = [s for s in raw.splitlines() if re.search(r'\[TITLE|RESULT:|MATRIX:|checks=', s)]
receipt['artifacts'] = {p.relative_to(out).as_posix(): sha(p.read_bytes()) for p in out.rglob('*')
                        if p.is_file() and 'userdata' not in p.relative_to(out).parts}
(out / 'receipt.json').write_text(json.dumps(receipt, indent=2) + '\n', encoding='utf-8')
print(json.dumps({k: receipt[k] for k in ['case', 'actual_exit', 'expected_exit', 'elapsed_seconds',
      'runtime_source_unchanged', 'broad_source_unchanged', 'diagnostic_headers', 'summary_lines']}, indent=2), flush=True)
