"""Exact typed-fixture baseline; preserves the prior failed run and cleanup target."""
from pathlib import Path
import hashlib
import json
import os
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[4]
PACKAGE = ROOT / 'design/astra/work/composed_material_invariants'
REVISION = PACKAGE / 'revisions/typed_booleans_01'
EVIDENCE = ROOT / 'design/astra/evidence/composed_material_ownership'
OUT = EVIDENCE / 'typed_baseline_outer_02'
TARGET = ROOT / 'game/tests/vulkan_composed_root_test.gd'
ORIGINAL = PACKAGE / 'originals/game/tests/vulkan_composed_root_test.gd'
PROPOSED = REVISION / 'proposed/game/tests/vulkan_composed_root_test.gd'
OLD_SHA = '5ec63c36c6181b33c02bd2255039e9bf4e8db0c4465a45ac641d1481f422d6d3'
NEW_SHA = 'c2642de6f0c099a18e8d7c0f740f94a84f0d5bc90cc255973dee5ab6ad2ee6b5'
PWSH = Path(r'C:\Users\nate_\.cache\codex-runtimes\codex-primary-runtime\dependencies\native\powershell\pwsh.exe')


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def empty_lane():
    command = [str(PWSH), '-NoProfile', '-Command',
        'Get-Process -Name "Godot*" -ErrorAction SilentlyContinue | Select-Object Id,ProcessName | ConvertTo-Json']
    census = subprocess.run(command, capture_output=True)
    if census.stdout.strip() or census.stderr.strip():
        raise RuntimeError('Godot lane is not verified empty; source mutation refused.')


def swap(source, expected_before, expected_after):
    assert sha(TARGET) == expected_before and sha(source) == expected_after
    temporary = TARGET.with_name(TARGET.name + '.astra_material_swap.tmp')
    with temporary.open('xb') as handle:
        handle.write(source.read_bytes())
    assert sha(temporary) == expected_after
    os.replace(temporary, TARGET)
    assert sha(TARGET) == expected_after


empty_lane()
assert sha(TARGET) == sha(ORIGINAL) == OLD_SHA and sha(PROPOSED) == NEW_SHA
OUT.mkdir(parents=True, exist_ok=False)
for label, path in [('original.raw', TARGET), ('proposed.raw', PROPOSED), ('outer.py.source', Path(__file__))]:
    shutil.copy2(path, OUT / label)
command = [sys.executable, '-B', str(REVISION / 'runtime_invocation.py'), '--execute',
    '--receipt-dir', str(EVIDENCE / 'typed_baseline_invocation_02')]
report = {'original_sha256': OLD_SHA, 'installed_sha256': NEW_SHA, 'command': command,
    'outer_source_sha256': sha(Path(__file__)), 'fixture_restored': False}
code = 1
try:
    swap(PROPOSED, OLD_SHA, NEW_SHA)
    report['fixture_installed'] = True
    process = subprocess.run(command, cwd=ROOT, capture_output=True)
    (OUT / 'invocation.stdout.log').write_bytes(process.stdout)
    (OUT / 'invocation.stderr.log').write_bytes(process.stderr)
    report['wrapper_exit'] = process.returncode
    code = process.returncode
finally:
    empty_lane()
    if sha(TARGET) == NEW_SHA:
        swap(ORIGINAL, NEW_SHA, OLD_SHA)
    report['actual_final_fixture_sha256'] = sha(TARGET)
    report['fixture_restored'] = sha(TARGET) == OLD_SHA
    (OUT / 'receipt.json').write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
    print(json.dumps(report, indent=2))
raise SystemExit(int(code != 0 or report['fixture_restored'] is not True))
