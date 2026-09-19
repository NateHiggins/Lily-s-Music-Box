"""Snapshot queued fixture, preserve parser evidence; never edit game or run Godot."""
from pathlib import Path
import datetime
import difflib
import hashlib
import json
import shutil
import subprocess
import sys
import time

BASE = Path(__file__).resolve().parent
ROOT = BASE.parents[3]
OUT = ROOT / 'design/astra/evidence/vulkan_composed/queued_scope_controls'
sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()


def main():
    OUT.mkdir(parents=True, exist_ok=False)
    names = ['gate.py', 'test_gate.py', 'variant_case.py', 'test_variant_case.py', 'run_case.py',
             'summarize_cost.py', 'game/tests/vulkan_composed_root_test.gd', 'game/tests/VulkanComposedRootTest.tscn']
    before = {name: sha(BASE / name) for name in names}
    for name in names:
        target = OUT / 'sources' / name
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(BASE / name, target)
    live = ROOT / 'game/tests/vulkan_composed_root_test.gd'
    live_hash = sha(live)
    (OUT / 'pending_fixture.diff').write_text(''.join(difflib.unified_diff(live.read_text().splitlines(True),
        (BASE / 'game/tests/vulkan_composed_root_test.gd').read_text().splitlines(True),
        fromfile='currently-live/game/tests/vulkan_composed_root_test.gd', tofile='queued/game/tests/vulkan_composed_root_test.gd')), encoding='utf-8')
    started = time.perf_counter()
    result = subprocess.run([sys.executable, '-m', 'unittest', 'test_gate', 'test_variant_case', '-v'], cwd=BASE, capture_output=True)
    elapsed = time.perf_counter() - started
    (OUT / 'stdout.log').write_bytes(result.stdout)
    (OUT / 'stderr.log').write_bytes(result.stderr)
    receipt = {'utc': datetime.datetime.now(datetime.timezone.utc).isoformat(), 'actual_exit': result.returncode,
        'elapsed_seconds': elapsed, 'sources': before, 'sources_unchanged': before == {name: sha(BASE / name) for name in names},
        'live_fixture_sha256': live_hash, 'live_fixture_unchanged': sha(live) == live_hash,
        'scope': '31 synthetic parser and exact source-transform controls only; queued GDScript has not compiled or run.',
        'pending': ['Install queued fixture only on source/lane handoff', 'Full candidate18captures',
                    'Actual cabinet raw viewport before/after repeated Passage transitions', 'Effective SubViewport.find_world_3d comparison',
                    'Root-retirement omission15captures only if broader omission crashes; actual native signature and completed retirement still required'],
        'cost_limit': 'Only identical completed36transition/144frame phases before separate-world controls may be matched. No crash walltime or incomplete arrays are a completed comparator.',
        'access_violation_policy': 'Always failed/incomplete, never intended-only red, even with known native signature.',
        'underflow_policy': 'Independent soft-shadow underflow remains fatal and prevents intended-only unpair classification.'}
    (OUT / 'receipt.json').write_text(json.dumps(receipt, indent=2) + '\n', encoding='utf-8')
    print(json.dumps(receipt, indent=2))


if __name__ == '__main__': main()
