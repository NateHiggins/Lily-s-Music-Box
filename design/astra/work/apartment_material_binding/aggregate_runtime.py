"""Aggregate only retained material evidence and two selected live source files; no engine/tree census."""
from pathlib import Path
import datetime
import hashlib
import json

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
BASE = ROOT / 'design/astra/evidence/apartment_material_binding'
NAMES = ['original_01', 'original_02', 'original_03', 'original_04', 'candidate_01', 'candidate_02',
         'duplicate_registration_01', 'case_owner_marker_01', 'private_world_guard_01',
         'root_row_registration_01', 'restored_01']
PRODUCTION = 'game/scripts/reality/apartment_encroachment.gd'
FIXTURE = 'game/tests/apartment_material_binding_test.gd'
sha = lambda data: hashlib.sha256(data).hexdigest()
rows = []
mismatches = []
checked = 0
for name in NAMES:
    folder = BASE / name
    receipt_path = folder / 'receipt.json'
    receipt = json.loads(receipt_path.read_text(encoding='utf-8'))
    for relative, expected in receipt['artifact_hashes'].items():
        path = folder / relative
        checked += 1
        if not path.is_file() or sha(path.read_bytes()) != expected:
            mismatches.append({'run': name, 'artifact': relative})
    source_bindings = {}
    for label in ['source_before', 'source_after']:
        source = receipt[label]
        for relative, expected in source['source_copies'].items():
            copy = folder / label / relative
            if not copy.is_file() or sha(copy.read_bytes()) != expected:
                mismatches.append({'run': name, 'source_copy': label + '/' + relative})
        manifest = json.loads((folder / (label + '.runtime_inputs.json')).read_text(encoding='utf-8'))
        encoded = json.dumps(sorted([item['path'], item['sha256']] for item in manifest), separators=(',', ':')).encode()
        if sha(encoded) != source['runtime_inputs_sha256'] or len(manifest) != source['runtime_input_count']:
            mismatches.append({'run': name, 'manifest': label})
        source_bindings[label] = {'production': source['source_copies'][PRODUCTION],
            'fixture': source['source_copies'][FIXTURE], 'runtime_inputs_sha256': source['runtime_inputs_sha256'],
            'runtime_input_count': source['runtime_input_count'],
            'wrapper': source['source_copies']['design/astra/work/apartment_material_binding/run_case.py'],
            'bridge': source['source_copies'].get('design/astra/work/apartment_material_binding/runner_bridge.ps1')}
    raw_paths = ['godot.stdout.log', 'godot.stdout.log.stderr', 'runner.stdout.log', 'runner.stderr.log']
    raw = {relative: (folder / relative).read_text(encoding='utf-8-sig', errors='replace')
           for relative in raw_paths if (folder / relative).is_file()}
    headers = [line for line in raw.get('godot.stdout.log', '').splitlines()
               if line.startswith('APARTMENT MATERIAL BINDING:')]
    engine_launched = 'Godot Engine v' in raw.get('godot.stdout.log', '')
    condition = receipt.get('runner_reported_condition')
    if condition is None and not receipt['assessment']['complete_footer']:
        stderr = raw.get('runner.stderr.log', '')
        condition = ('timeout_termination' if 'TIMEOUT:' in stderr else
                     'lane_refusal' if 'LANE BUSY:' in stderr else
                     'parameter_binding_refusal' if "Missing an argument for parameter 'ExtraArgs'" in stderr else None)
    rows.append({'name': name, 'receipt': receipt_path.relative_to(ROOT).as_posix(),
        'receipt_sha256': sha(receipt_path.read_bytes()), 'actual_serial_process_exit': receipt['actual_exit'],
        'completed_fixture_exit': receipt.get('completed_fixture_exit'), 'runner_condition': condition,
        'engine_launch_observed_in_raw_banner': engine_launched,
        'diagnostic_gate_exit': receipt['diagnostic_gate_exit'],
        'control_acceptance_exit': receipt['control_acceptance_exit'],
        'complete_footer': receipt['assessment']['complete_footer'], 'raw_footer': headers,
        'raw_pass_count': len(receipt['assessment']['pass_labels']),
        'raw_fail_count': len(receipt['assessment']['fail_labels']),
        'failed_labels': receipt['assessment']['fail_labels'],
        'diagnostic_count': len(receipt['assessment']['diagnostics']),
        'distinct_diagnostics': sorted(set(receipt['assessment']['diagnostics'])),
        'warning_lines': receipt['warning_lines'], 'source_unchanged': receipt['source_unchanged'],
        'engine_unchanged': receipt['engine_unchanged'], 'engine_binaries': receipt['engine_before'],
        'source_bindings': source_bindings,
        'raw_streams': {relative: {'sha256': sha((folder / relative).read_bytes()),
                                  'bytes': (folder / relative).stat().st_size} for relative in raw}})
controls_path = BASE / 'ownership_controls_01/controls.json'
controls = json.loads(controls_path.read_text(encoding='utf-8'))
for control in controls['controls']:
    path = BASE / 'ownership_controls_01' / (control['name'] + '.gd')
    if sha(path.read_bytes()) != control['control_sha256']:
        mismatches.append({'control_source': control['name']})
validation = {
    'schema': 'astra.apartment_material_binding.validation.v1',
    'reviewed_utc': datetime.datetime.now(datetime.timezone.utc).isoformat(),
    'scope': 'focused registration/ownership only; actual material/field/governor consumers, no build/ecology/world-frame or performance acceptance',
    'artifact_hashes_checked': checked, 'hash_mismatches': mismatches,
    'current_selected_sources': {path: sha((ROOT / path).read_bytes()) for path in [PRODUCTION, FIXTURE]},
    'current_selected_source_scope': 'only these two files checked after lane handoff; no current whole-tree assertion',
    'runs': rows, 'ownership_controls': controls,
    'ownership_controls_receipt_sha256': sha(controls_path.read_bytes()),
    'control_driver_current_sha256': sha((HERE / 'run_ownership_controls.py').read_bytes()),
    'control_driver_binding_limit': 'driver hash observed after execution; each executed changed production source is independently copied and bound in its runtime receipt',
    'final_result': 'original_04 has18 expected native assertion failures; candidate_02 and restored_01 pass36/36 with empty diagnostics; four omissions fail their named contracts and restore exact candidate bytes',
    'historical_failures': {
        'original_01': 'fixture nullable bool runtime error and runner timeout; actual process1, no completed game exit; not intended product red',
        'original_02': 'external project lane refusal; actual process1, no game launch',
        'original_03': 'advanced PowerShell ExtraArgs binding refusal; actual process1, no game launch',
        'candidate_01': '36/36 assertions and native0 but73 missing-meta engine errors; diagnostic1; not accepted green',
    },
    'remaining_boundaries': [
        'Focused finish row/marker is hand-created; actual build guard/marker requires real-root material invariants.',
        'No real-root ApartmentEncroachmentTest, DreamArchitectureLifecycleLiveTest or composed performance run performed in this lane.',
        'No one-census reach_props optimization applied; measured callback-cost improvement remains unproved.',
        'SurfacePass first-owner cached surface reference preserved; existing copies still lack a new live governor budget propagation mechanism.',
        'Tier OFF does not call on_props_applied; retirement is verified on the next actual callback or explicit sweep.',
        'Runtime input binding covers scripts/scenes/JSON/shaders/includes and installed engine binaries, not all binary art/import-cache bytes.',
    ],
}
(BASE / 'validation.json').write_text(json.dumps(validation, indent=2) + '\n', encoding='utf-8')
print(json.dumps({'runs': len(rows), 'artifact_hashes_checked': checked, 'mismatches': mismatches,
                  'selected_sources': validation['current_selected_sources']}, indent=2))
raise SystemExit(int(bool(mismatches)))
