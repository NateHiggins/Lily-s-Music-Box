"""Explicit-lane-only omission controls; edits only the owned material source and always restores it."""
from pathlib import Path
import hashlib
import json
import subprocess
import sys

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
LIVE = ROOT / 'game/scripts/reality/apartment_encroachment.gd'
EXPECTED = '7c54c18154ccf8de8c3bce13a356329344dec19411adb2f1237425ae99eb90db'
sha = lambda data: hashlib.sha256(data).hexdigest()


def once(source, old, new):
    if source.count(old) != 1:
        raise RuntimeError('Control source anchor is not unique: ' + old[:100])
    return source.replace(old, new)


def main():
    before = LIVE.read_bytes()
    if sha(before) != EXPECTED:
        raise SystemExit('Live ownership candidate is not the reviewed corrected source.')
    text = before.decode('utf-8')
    append = '\tif not (storey_materials[floor_id] as Array).has(m):\n\t\t(storey_materials[floor_id] as Array).append(m)'
    row_start = text.index('\tfor case_id in prop_rows:', text.index('func _bind_storey('))
    row_end = text.index('\tprint("[ENCROACH] living field on', row_start)
    controls = [
        ('duplicate_registration_01', once(text, append, append + '\n\t(storey_materials[floor_id] as Array).append(m)'),
         ['initial registration is nonempty and unique', 'same installed material on two draws registers once']),
        ('case_owner_marker_01', once(text, '\t\t\town.set_meta("living_storey", _floor_of(case_id))\n', ''),
         ['first reach retains exact installed floor prop row', 'first refresh immediately reaches installed floor prop']),
        ('private_world_guard_01', once(text, ' or cursor is SubViewport or cursor is CharacterBody3D',
            ' or cursor is CharacterBody3D'),
         ['storey scan excludes cabinet world', 'global reach still excludes private and dynamic draws']),
        ('root_row_registration_01', text[:row_start] + text[row_end:],
         ['root-level case draw remains in the floor registry', 'lifecycle immediately reaches both installed prop owners']),
    ]
    output = ROOT / 'design/astra/evidence/apartment_material_binding/ownership_controls_01'
    output.mkdir(parents=True, exist_ok=False)
    (output / 'candidate.gd').write_bytes(before)
    rows = []
    try:
        for name, changed, required in controls:
            if LIVE.read_bytes() != before:
                raise RuntimeError('Candidate was not restored before the next control.')
            control_bytes = changed.encode('utf-8')
            (output / (name + '.gd')).write_bytes(control_bytes)
            result = None
            try:
                LIVE.write_bytes(control_bytes)
                command = [sys.executable, str(HERE / 'run_case.py'), name, '--expect-red']
                result = subprocess.run(command, cwd=ROOT, capture_output=True)
            finally:
                LIVE.write_bytes(before)
            (output / (name + '.wrapper.stdout.txt')).write_bytes(result.stdout)
            (output / (name + '.wrapper.stderr.txt')).write_bytes(result.stderr)
            receipt_path = ROOT / 'design/astra/evidence/apartment_material_binding' / name / 'receipt.json'
            receipt = json.loads(receipt_path.read_text(encoding='utf-8'))
            restored = LIVE.read_bytes() == before
            required_failed = all(label in receipt['assessment']['fail_labels'] for label in required)
            accepted = result.returncode == 0 and receipt['assessment']['intended_red'] \
                and receipt['diagnostic_gate_exit'] == 1 and receipt['control_acceptance_exit'] == 0 \
                and required_failed and restored
            row = {'name': name, 'control_sha256': sha(control_bytes), 'required_fail_labels': required,
                   'required_labels_failed': required_failed, 'wrapper_exit': result.returncode,
                   'actual_serial_exit': receipt['actual_exit'], 'completed_fixture_exit': receipt['completed_fixture_exit'],
                   'diagnostic_gate_exit': receipt['diagnostic_gate_exit'], 'control_acceptance_exit': receipt['control_acceptance_exit'],
                   'receipt': receipt_path.relative_to(ROOT).as_posix(), 'receipt_sha256': sha(receipt_path.read_bytes()),
                   'restored_exact': restored, 'accepted_control': accepted}
            rows.append(row)
            (output / 'controls.json').write_text(json.dumps({'candidate_sha256': EXPECTED, 'controls': rows}, indent=2) + '\n')
            print(json.dumps(row), flush=True)
            if not accepted:
                return 1
    finally:
        LIVE.write_bytes(before)
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
