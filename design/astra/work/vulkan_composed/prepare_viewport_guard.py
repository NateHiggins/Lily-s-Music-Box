"""Apply only the explicitly authorized SubViewport ownership boundary."""
from pathlib import Path
import datetime
import difflib
import hashlib
import json

ROOT = Path(__file__).resolve().parents[4]
LIVE = ROOT / 'game/scripts/building/building_root.gd'
OUT = ROOT / 'design/astra/evidence/vulkan_composed/viewport_boundary_repair'


def main():
    before = LIVE.read_bytes()
    sha = lambda data: hashlib.sha256(data).hexdigest()
    assert sha(before) == 'cd174d254420dade5388fbe11745a38836d1bb3bfad44f85fdfc4e860aecb7a5'
    newline = b'\r\n' if b'\r\n' in before else b'\n'
    anchor = b'\twhile cursor != null and cursor != floor:' + newline
    assert before.count(anchor) == 1
    addition = (b'\t\t# A cabinet viewport owns its world; building zones must not index it.' + newline
                + b'\t\tif cursor is SubViewport:' + newline + b'\t\t\treturn true' + newline)
    after = before.replace(anchor, anchor + addition)
    OUT.mkdir(parents=True, exist_ok=False)
    (OUT / 'building_root.before.gd.txt').write_bytes(before)
    (OUT / 'building_root.after.gd.txt').write_bytes(after)
    (OUT / 'change.diff').write_text(''.join(difflib.unified_diff(before.decode().splitlines(True), after.decode().splitlines(True), fromfile='before/building_root.gd', tofile='after/building_root.gd')), encoding='utf-8')
    LIVE.write_bytes(after)
    receipt = {'utc': datetime.datetime.now(datetime.timezone.utc).isoformat(), 'before_sha256': sha(before),
               'after_sha256': sha(after), 'live_matches_after': LIVE.read_bytes() == after,
               'scope': 'Only _late_owner_is_dynamic stops at a SubViewport ancestor; no renderer helper, threshold, layout, selector or other owner changes.',
               'prior_completed_red': '../runs/candidate_v1_diag_01/result.json',
               'runtime_status': 'not yet run; full matrix waits for independent resident-route diagnosis'}
    (OUT / 'receipt.json').write_text(json.dumps(receipt, indent=2) + '\n', encoding='utf-8')
    print(json.dumps(receipt, indent=2))


if __name__ == '__main__': main()
