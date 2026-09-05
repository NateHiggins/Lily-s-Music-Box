"""Real separate-process save interruption/readers; run only with the Godot lane."""
from pathlib import Path
import argparse
import ctypes
from ctypes import wintypes
import datetime
import hashlib
import json
import os
import re
import shutil
import subprocess
import time
import uuid

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[4]
RUNNER = ROOT / 'tools/run_godot_serial.ps1'
PWSH = Path(r'C:\Users\nate_\.cache\codex-runtimes\codex-primary-runtime\dependencies\native\powershell\pwsh.exe')
SCENE = 'res://tests/reality_save_restart_worker.tscn'
SAVE_NAME = 'reality_maintenance_save.json'
parser = argparse.ArgumentParser()
parser.add_argument('batch')
parser.add_argument('--case', action='append', choices=['before_promote', 'after_promote', 'deletion_gap', 'failed_first_new'])
args = parser.parse_args()
if not re.fullmatch(r'[A-Za-z0-9_-]+', args.batch):
    raise SystemExit('Use a plain fresh batch name.')
OUT = ROOT / 'design/astra/evidence/save_recovery' / args.batch
OUT.mkdir(parents=True, exist_ok=False)

def sha(bytes): return hashlib.sha256(bytes).hexdigest()
def q(value): return "'" + str(value).replace("'", "''") + "'"
def utc(): return datetime.datetime.now(datetime.timezone.utc).isoformat()
def write_json(path, data): path.write_text(json.dumps(data, indent=2) + '\n', encoding='utf-8')

def inputs(label):
    rows = {}
    for directory, patterns in [('game/scripts', ['*.gd']), ('game/tests', ['*.gd', '*.tscn']),
                               ('game/scenes', ['*.tscn', '*.tres']), ('game/data', ['*.json'])]:
        for pattern in patterns:
            for file in (ROOT / directory).rglob(pattern):
                rows[file.relative_to(ROOT).as_posix()] = sha(file.read_bytes())
    rows['game/project.godot'] = sha((ROOT / 'game/project.godot').read_bytes())
    encoded = json.dumps(sorted(rows.items()), separators=(',', ':')).encode()
    write_json(OUT / (label + '.inputs.json'), rows)
    for relative in ['game/scripts/game/reality_game_state.gd', 'game/scripts/game/reality_save_storage.gd',
                     'game/scripts/game/campaign_clock.gd', 'game/scripts/game_boot.gd',
                     'game/tests/reality_save_restart_worker.gd', 'tools/run_godot_serial.ps1']:
        destination = OUT / label / relative
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(ROOT / relative, destination)
    return {'head': subprocess.check_output(['git', '-C', str(ROOT), 'rev-parse', 'HEAD']).decode().strip(),
            'sha256': sha(encoded), 'file_count': len(rows)}

def facts(new=False):
    return {'version': 4, 'intro_complete': True, 'dream_seed': '1928000019280000',
        'maintenance_jobs': {'vantry_chirp_2a': {'stage': 'closed' if new else 'repaired', 'origin': 'reported',
            'evidence': ['carbon_capsule_failed'], 'repair_result': {'quality': 'good'},
            'issued_at_basis': 'fixture_basis_preserved'}},
        'maintenance_items': {'carbon_transmitter_capsule': {'shop_id': 'hardware', 'consumed': True}},
        'dream': {'phase': 'return_pending' if new else 'armed', 'active': False,
            'case_id': 'mina_caption_crisis', 'profile_id': 'mina_release_print', 'window': {},
            'seed_hex': '1928000019280000', 'night_index': 0},
        'campaign_clock': {'schema_version': 2, 'calendar_mode': 'gregorian', 'year': 1928, 'month': 11,
            'day_of_month': 10, 'timezone': 'America/New_York', 'utc_offset_minutes': -300,
            'epoch_date': '1928-11-10', 'start_weekday': 'sat', 'start_doy': 314,
            'start_minute_of_day': 807, 'elapsed_minutes': 3.25 if new else 0.0}}

def projection(value):
    return {'version': value.get('version'), 'job': value.get('maintenance_jobs', {}).get('vantry_chirp_2a', {}),
            'item': value.get('maintenance_items', {}).get('carbon_transmitter_capsule', {}),
            'dream': value.get('dream', {}), 'seed': value.get('dream_seed', ''), 'clock': value.get('campaign_clock', {})}

def save_artifacts(case, tag):
    result = {}
    directory = case / 'appdata/PleaseRemainOnTheLine'
    target = case / ('artifacts_' + tag)
    target.mkdir()
    for path in sorted(directory.glob(SAVE_NAME + '*')):
        if path.is_file():
            bytes = path.read_bytes()
            shutil.copyfile(path, target / path.name)
            result[path.name] = {'bytes': len(bytes), 'sha256': sha(bytes)}
    write_json(case / ('hashes_' + tag + '.json'), result)
    return result

def terminate_marked_fixture(marker, runner_process):
    pid = int(marker['pid'])
    # PID, parent, executable, scene command and nonce are all checked before
    # opening this one process for termination; never kill by an executable glob.
    def query(process_id):
        command = ('Get-CimInstance Win32_Process -Filter ' + q(f'ProcessId = {process_id}') +
                   ' | Select-Object ProcessId,ParentProcessId,ExecutablePath,CommandLine,CreationDate | ConvertTo-Json -Compress')
        return json.loads(subprocess.check_output([str(PWSH), '-NoProfile', '-Command', command]))
    observed = query(pid)
    console = Path(subprocess.check_output([str(PWSH), '-NoProfile', '-Command',
        '(Get-Command Godot_v4.7.1-stable_win64_console.exe -ErrorAction Stop).Source']).decode().strip())
    def normalized(path): return os.path.normcase(os.path.normpath(str(path)))
    permitted = {normalized(console), normalized(console.with_name('Godot_v4.7.1-stable_win64.exe'))}
    if int(observed['ProcessId']) != pid or normalized(observed['ExecutablePath']) not in permitted or SCENE not in observed['CommandLine']:
        raise RuntimeError('Marker PID is not the exact installed Godot fixture command: ' + json.dumps(observed))
    chain = [observed]
    # The installed console launcher may parent the actual engine executable.
    # Verify that one concrete intermediary; an arbitrary ancestor is insufficient.
    parent = int(observed['ParentProcessId'])
    if parent != runner_process.pid:
        launcher = query(parent)
        chain.append(launcher)
        if (normalized(launcher['ExecutablePath']) != normalized(console)
                or SCENE not in launcher['CommandLine'] or int(launcher['ParentProcessId']) != runner_process.pid):
            raise RuntimeError('Marker PID is not a verified child of this serial runner: ' + json.dumps(chain))
    kernel = ctypes.WinDLL('kernel32', use_last_error=True)
    kernel.OpenProcess.argtypes = [wintypes.DWORD, wintypes.BOOL, wintypes.DWORD]
    kernel.OpenProcess.restype = wintypes.HANDLE
    kernel.TerminateProcess.argtypes = [wintypes.HANDLE, wintypes.UINT]
    kernel.TerminateProcess.restype = wintypes.BOOL
    kernel.WaitForSingleObject.argtypes = [wintypes.HANDLE, wintypes.DWORD]
    kernel.WaitForSingleObject.restype = wintypes.DWORD
    kernel.GetExitCodeProcess.argtypes = [wintypes.HANDLE, ctypes.POINTER(wintypes.DWORD)]
    kernel.GetExitCodeProcess.restype = wintypes.BOOL
    kernel.CloseHandle.argtypes = [wintypes.HANDLE]
    handle = kernel.OpenProcess(0x0001 | 0x00100000 | 0x1000, False, pid)
    if not handle:
        raise ctypes.WinError(ctypes.get_last_error())
    try:
        exit_code = wintypes.DWORD()
        if not kernel.GetExitCodeProcess(handle, ctypes.byref(exit_code)) or exit_code.value != 259:
            raise RuntimeError('Marked fixture is no longer active.')
        if not kernel.TerminateProcess(handle, 81):
            raise ctypes.WinError(ctypes.get_last_error())
        wait_result = kernel.WaitForSingleObject(handle, 5000)
        if not kernel.GetExitCodeProcess(handle, ctypes.byref(exit_code)):
            raise ctypes.WinError(ctypes.get_last_error())
        return {'mechanism': 'Windows TerminateProcess on verified fixture handle', 'requested_exit': 81,
                'observed_native_exit': int(exit_code.value), 'wait_result': int(wait_result),
                'process_identity': observed, 'verified_ancestor_chain': chain, 'terminated_utc': utc()}
    finally:
        kernel.CloseHandle(handle)

def run_process(case, mode, boundary='', expected_file=None, kill=False):
    run = case / mode
    run.mkdir()
    env = os.environ.copy()
    env['APPDATA'] = str(case / 'appdata')
    for key in ['ORISON_BUILDING_ROOT', 'SHOT_DIR', 'REALITY_TIME', 'REALITY_TIME_OVERRIDE', 'DAYNIGHT',
                'DAYNIGHT_FORCE', 'SCHEDULE', 'SCHEDULE_MINUTE', 'SCHEDULE_DAY', 'SCHEDULE_DOY',
                'WORLD_TIME_LEGACY_CONTROL', 'WORLD_TIME_LEGACY_SOURCE_DIR']:
        env.pop(key, None)
    nonce = str(uuid.uuid4())
    marker_path = run / 'checkpoint.json'
    report_path = run / 'worker_report.json'
    env.update({'CAMPAIGN_TIME_FREEZE': '1', 'SAVE_RECOVERY_WORKER_MODE': mode,
        'SAVE_RECOVERY_BOUNDARY': boundary, 'SAVE_RECOVERY_NONCE': nonce,
        'SAVE_RECOVERY_MARKER': str(marker_path), 'SAVE_RECOVERY_REPORT': str(report_path),
        'SAVE_RECOVERY_NEXT': str(case / 'new.json'), 'SAVE_RECOVERY_EXPECTED': str(expected_file or '')})
    log = run / 'godot.stdout.log'
    wrapper = run / 'command.ps1'
    wrapper.write_text('& ' + q(RUNNER) + ' -ProjectPath ' + q(ROOT / 'game') + ' -Scene ' + q(SCENE) +
        ' -LogPath ' + q(log) + " -TimeoutSeconds 35 -ExtraArgs @('--verbose')\nexit $LASTEXITCODE\n")
    command = [str(PWSH), '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', str(wrapper)]
    process = subprocess.Popen(command, cwd=ROOT, env=env, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    receipt = {'mode': mode, 'boundary': boundary, 'command': command, 'runner_pid': process.pid,
               'started_utc': utc(), 'APPDATA': env['APPDATA'], 'nonce': nonce}
    if kill:
        deadline = time.monotonic() + 25
        marker = None
        while time.monotonic() < deadline and process.poll() is None:
            if marker_path.is_file():
                try:
                    marker = json.loads(marker_path.read_text())
                    break
                except json.JSONDecodeError:
                    pass
            time.sleep(0.05)
        if marker is not None:
            try:
                if marker['nonce'] != nonce or marker['boundary'] != boundary or marker['gap_delete_error'] != 0:
                    raise RuntimeError('Fixture marker does not match its requested boundary.')
                receipt['marker'] = marker
                receipt['termination'] = terminate_marked_fixture(marker, process)
            except Exception as exc:
                # A bad identity never authorizes a kill. Still wait for the
                # bounded fixture/serial runner so no live process is abandoned.
                receipt['controller_error'] = repr(exc)
        else:
            receipt['marker_missing'] = True
    stdout, stderr = process.communicate(timeout=45)
    (run / 'runner.stdout.log').write_bytes(stdout)
    (run / 'runner.stderr.log').write_bytes(stderr)
    receipt['runner_exit'] = process.returncode
    receipt['finished_utc'] = utc()
    raw = '\n'.join(path.read_text(encoding='utf-8-sig', errors='replace') for path in [log, Path(str(log) + '.stderr')] if path.is_file())
    receipt['diagnostic_headers'] = [line for line in raw.splitlines() if re.search(r'WARNING:|ERROR:|SCRIPT ERROR:|Parse Error|leaked|resources still in use', line, re.I)]
    receipt['summary_lines'] = [line for line in raw.splitlines() if '[SAVE RESTART]' in line]
    if report_path.exists():
        receipt['report'] = json.loads(report_path.read_text())
    receipt['passed'] = (process.returncode == 81 and receipt.get('termination', {}).get('observed_native_exit') == 81) if kill else (
        process.returncode == 0 and receipt.get('report', {}).get('failures') == 0)
    receipt['passed'] = receipt['passed'] and not receipt['diagnostic_headers']
    write_json(run / 'receipt.json', receipt)
    print(json.dumps({key: receipt[key] for key in ['mode', 'boundary', 'runner_exit', 'passed', 'summary_lines', 'diagnostic_headers']}), flush=True)
    return receipt

receipt = {'schema': 'astra.save_recovery.process_restart.v1', 'started_utc': utc(),
           'scope': 'real process termination/restart at marked storage boundaries; no power-loss atomicity claim',
           'sampling_evidence_limit': 'Scene-installed callback counts do not observe preceding RealityState autoload sampling. Exact full saved-clock equality is checked across processes; source/static authority validates the no-resampling path.',
           'source_before': inputs('source_before'), 'cases': []}
try:
    for name in args.case or ['before_promote', 'after_promote', 'deletion_gap', 'failed_first_new']:
        case = OUT / name
        (case / 'appdata/PleaseRemainOnTheLine').mkdir(parents=True)
        write_json(case / 'old.json', facts(False))
        write_json(case / 'new.json', facts(True))
        primary = case / 'appdata/PleaseRemainOnTheLine' / SAVE_NAME
        result = {'name': name, 'processes': []}
        receipt['cases'].append(result)
        if name != 'failed_first_new':
            shutil.copyfile(case / 'old.json', primary)
            result['before'] = save_artifacts(case, 'before')
            result['processes'].append(run_process(case, 'writer', name, kill=True))
            if not result['processes'][-1]['passed']:
                raise RuntimeError('Writer termination did not meet the required marked boundary.')
            result['after_writer'] = save_artifacts(case, 'after_writer')
            selected = case / ('new.json' if name == 'after_promote' else 'old.json')
            result['processes'].append(run_process(case, 'reader', expected_file=selected))
            result['after_reader'] = save_artifacts(case, 'after_reader')
            expected = json.loads(selected.read_text())
            result['complete_generation'] = projection(json.loads(primary.read_text())) == projection(expected)
            result['expected_load_status'] = 'recovered' if name == 'deletion_gap' else 'loaded'
            result['load_status_matches'] = result['processes'][-1].get('report', {}).get('load_status', {}).get('status') == result['expected_load_status']
        else:
            result['processes'].append(run_process(case, 'first_fail'))
            result['after_failed_new'] = save_artifacts(case, 'after_failed_new')
            result['processes'].append(run_process(case, 'first_protected'))
            result['after_protected_reader'] = save_artifacts(case, 'after_protected_reader')
            result['orphan_preserved'] = result['after_failed_new'] == result['after_protected_reader']
            result['processes'].append(run_process(case, 'first_retry'))
            result['after_retry'] = save_artifacts(case, 'after_retry')
            expected_retry = case / 'committed_retry.json'
            shutil.copyfile(primary, expected_retry)
            result['processes'].append(run_process(case, 'reader', expected_file=expected_retry))
            result['after_retry_reader'] = save_artifacts(case, 'after_retry_reader')
            result['committed_primary_preserved'] = result['after_retry'][SAVE_NAME] == result['after_retry_reader'][SAVE_NAME]
        result['passed'] = all(p['passed'] for p in result['processes']) and all(
            result.get(key, True) for key in ['complete_generation', 'load_status_matches', 'orphan_preserved', 'committed_primary_preserved'])
        if not result['passed']:
            raise RuntimeError('A process-restart case failed; retain evidence and diagnose before continuing.')
finally:
    receipt['source_after'] = inputs('source_after')
    receipt['source_unchanged'] = receipt['source_before'] == receipt['source_after']
    receipt['finished_utc'] = utc()
    receipt['passed'] = bool(receipt['cases']) and all(case.get('passed', False) for case in receipt['cases']) and receipt['source_unchanged']
    write_json(OUT / 'receipt.json', receipt)
print(json.dumps({'passed': receipt['passed'], 'source_unchanged': receipt['source_unchanged'], 'cases': [case['name'] for case in receipt['cases']]}, indent=2), flush=True)
raise SystemExit(0 if receipt['passed'] else 1)
