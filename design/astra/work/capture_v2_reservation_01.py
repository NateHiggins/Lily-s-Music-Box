"""Matched operator/phone capture with a temporary fixture and sampled lane proof."""
from pathlib import Path
import datetime
import hashlib
import json
import os
import re
import subprocess
import sys
import tempfile
import time

ROOT = Path(r'C:\PleaseRemainOnTheLine-astra')
BASE = ROOT / 'design/astra/work/v2_reservation_runtime_03'
PROOF = ROOT / 'design/astra/evidence/v2_reservation_display_03/runs/04_terminal_regression/result.json'
OUT = ROOT / 'design/astra/evidence/vulkan_composed/invocations/reservation_operator_view_v2_01'
PWSH = Path(r'C:\Users\nate_\.cache\codex-runtimes\codex-primary-runtime\dependencies\native\powershell\pwsh.exe')
DOCKER = r'C:\Program Files\Docker\Docker\resources\bin\docker.exe'
sha = lambda path: hashlib.sha256(path.read_bytes()).hexdigest()

def census():
    code = "ConvertTo-Json -Compress -InputObject @(Get-CimInstance Win32_Process | Where-Object Name -Match 'Godot|Blender|^python|^pwsh|^powershell' | Select-Object ProcessId,ParentProcessId,Name,CommandLine)"
    return json.loads(subprocess.check_output([str(PWSH), '-NoProfile', '-Command', code], text=True, timeout=15))

def engines(rows):
    return [row for row in rows if re.search('Godot|Blender', row['Name'], re.I)]

def container_admission():
    code = "ConvertTo-Json -Compress -InputObject @(Get-CimInstance Win32_Process | Where-Object Name -Match 'docker|dockerd|containerd' | Select-Object ProcessId,Name,CommandLine)"
    backends = json.loads(subprocess.check_output([str(PWSH), '-NoProfile', '-Command', code], text=True, timeout=15))
    running = subprocess.check_output(['wsl', '--list', '--running', '--quiet'], timeout=15).decode('utf-16-le').strip('\x00\r\n ')
    if not backends and not running:
        return {'status':'DOCKER_AND_WSL_STOPPED', 'backend_processes':backends, 'running_wsl_distributions':running}
    containers = subprocess.check_output([DOCKER, 'ps', '--quiet', '--filter', 'label=org.orison.godot-lane'], text=True, timeout=15).strip()
    assert not containers, 'Container Godot lane occupied'
    return {'status':'NO_LABELLED_GODOT_CONTAINERS', 'backend_processes':backends, 'running_wsl_distributions':running, 'labelled_container_ids':containers}

def atomic_write(path, data):
    temporary = None
    try:
        with tempfile.NamedTemporaryFile(dir=path.parent, prefix=path.name+'.astra-', suffix='.tmp', delete=False) as output:
            temporary = Path(output.name)
            output.write(data)
        assert sha(temporary) == hashlib.sha256(data).hexdigest()
        os.replace(temporary, path)
    finally:
        if temporary is not None and temporary.exists():
            temporary.unlink()

def main():
    binding = json.loads((BASE / 'capture_binding.json').read_text())
    proof = json.loads(PROOF.read_text())
    assert proof['actual_runner_exit'] == proof['assessment']['diagnostic_gate_exit'] == 0
    assert proof['assessment']['passed'] == proof['assessment']['total'] == 39
    assert proof['lane_contract']['lane_contract_exit'] == 0
    for rel, expected in proof['artifacts'].items():
        assert sha(PROOF.parent / rel) == expected, rel
    restored = json.loads((PROOF.parents[2] / '04_terminal_regression.restoration.json').read_text())
    assert restored['status'] == 'EXACT_OWNED_SOURCES_RESTORED'
    before = dict(proof['after']['copied_sources'])
    before[binding['fixture_install_target']] = binding['required_preinstall_fixture_sha256']
    assert all(sha(ROOT / rel) == expected for rel, expected in before.items())
    assert subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip() == binding['required_execution_head'] == '02fcb18a209624c9b609b65fb44b05b45c65de09'
    assert sha(ROOT / 'design/astra/work/vulkan_composed/run_case.py') == binding['wrapper_sha256']
    assert sha(ROOT / 'design/astra/work/vulkan_composed/gate.py') == binding['gate_sha256']
    container_state = container_admission()
    assert engines(census()) == [], 'Native lane occupied before capture'
    run = ROOT / binding['result']
    assert not OUT.exists() and not run.parent.exists(), 'Fresh capture namespace required'
    fixture = ROOT / binding['fixture_install_target']
    original, candidate = fixture.read_bytes(), (ROOT / binding['fixture_source']).read_bytes()
    assert hashlib.sha256(original).hexdigest() == binding['required_preinstall_fixture_sha256']
    assert hashlib.sha256(candidate).hexdigest() == binding['fixture_candidate_sha256']
    OUT.mkdir(parents=True)
    (OUT / 'fixture_original.gd').write_bytes(original)
    (OUT / 'fixture_candidate.gd').write_bytes(candidate)
    command = [sys.executable, '-B', *binding['wrapper_argv'][1:]]
    receipt = {'status': 'PREPARED', 'command': command, 'input_proof_sha256': sha(PROOF), 'container_admission':container_state,
               'binding_sha256': sha(BASE / 'capture_binding.json'), 'orchestrator_sha256': sha(Path(__file__)),
               'source_before': before, 'samples': [], 'exclusive_performance_claim': False,
               'started_at_utc': datetime.datetime.now(datetime.timezone.utc).isoformat()}
    def save():
        (OUT / 'invocation.json').write_text(json.dumps(receipt, indent=2)+'\n', encoding='utf-8')
    save()
    try:
        atomic_write(fixture, candidate)
        assert {rel: sha(ROOT/rel) for rel in binding['expected_sources_sha256']} == binding['expected_sources_sha256']
        receipt['status'] = 'RUNNING'
        save()
        with (OUT/'external.stdout.log').open('wb') as out, (OUT/'external.stderr.log').open('wb') as err:
            process = subprocess.Popen(command, cwd=ROOT, stdout=out, stderr=err)
            receipt['external_wrapper_pid'] = process.pid
            started = time.monotonic()
            while process.poll() is None:
                rows = census()
                if not receipt['samples'] or rows != receipt['samples'][-1]['processes']:
                    receipt['samples'].append({'elapsed_seconds': time.monotonic()-started, 'processes': rows})
                time.sleep(.05)
        receipt['actual_command_exit'] = process.returncode
        rows = {row['ProcessId']: row for sample in receipt['samples'] for row in sample['processes']}
        def owned(pid):
            seen = set()
            while pid in rows and pid not in seen:
                seen.add(pid)
                pid = rows[pid]['ParentProcessId']
                if pid == process.pid: return True
            return False
        conflicts = [row for sample in receipt['samples'] for row in sample['processes']
                     if row['ProcessId'] in rows and (row['ParentProcessId'],row['Name'],row['CommandLine']) !=
                     (rows[row['ProcessId']]['ParentProcessId'],rows[row['ProcessId']]['Name'],rows[row['ProcessId']]['CommandLine'])]
        observed_engines = engines(list(rows.values()))
        foreign = [row for row in observed_engines if not owned(row['ProcessId'])]
        actual = [row for row in observed_engines if row['Name'].lower() == 'godot_v4.7.1-stable_win64.exe' and owned(row['ProcessId'])]
        receipt['lane_contract'] = {'foreign_processes': foreign, 'conflicting_pid_observations': conflicts,
            'actual_owned_engines': actual, 'lane_contract_exit': int(bool(foreign or conflicts or len(actual) != 1)),
            'scope': 'Sampled native ancestry only; no absolute exclusivity or performance claim.'}
        if run.exists(): receipt['result_sha256'] = sha(run)
    except BaseException as error:
        receipt['execution_failure'] = {'type': type(error).__name__, 'message': str(error)}
        raise
    finally:
        try:
            receipt['processes_before_restore'] = engines(census())
            current = sha(fixture)
            if receipt['processes_before_restore'] == [] and current in (binding['fixture_candidate_sha256'], binding['required_preinstall_fixture_sha256']):
                atomic_write(fixture, original)
                receipt['source_after'] = {rel: sha(ROOT/rel) for rel in before}
                receipt['status'] = 'EXACT_FIXTURE_RESTORED' if receipt['source_after'] == before else 'SOURCE_DRIFT'
            else:
                receipt['status'] = 'RESTORATION_REFUSED_UNEXPECTED_SOURCE_OR_PROCESS'
        except BaseException as error:
            receipt['status'] = 'RESTORATION_FAILED_OR_CENSUS_UNAVAILABLE'
            receipt['restoration_failure'] = {'type': type(error).__name__, 'message': str(error)}
            raise
        finally:
            receipt['ended_at_utc'] = datetime.datetime.now(datetime.timezone.utc).isoformat()
            save()
    okay = receipt['status'] == 'EXACT_FIXTURE_RESTORED' and receipt.get('actual_command_exit') == 0 and receipt.get('lane_contract', {}).get('lane_contract_exit') == 0
    print(json.dumps({'status': receipt['status'], 'actual_command_exit': receipt.get('actual_command_exit'), 'lane_contract': receipt.get('lane_contract'), 'receipt': str(OUT/'invocation.json')}))
    return 0 if okay else 1

if __name__ == '__main__':
    raise SystemExit(main())
