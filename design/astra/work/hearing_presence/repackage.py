"""Refresh the reviewed proposal patch from preserved original inputs."""
from pathlib import Path
import difflib
import hashlib
import json

HERE = Path(__file__).resolve().parent
paths = ['game/scripts/reality/npc_observation_ledger.gd',
    'game/tests/orison_v2_presence_ledger_test.gd',
    'game/tests/npc_hearing_presence_test.gd', 'game/tests/NpcHearingPresenceTest.tscn']
patch = ''
rows = []
for relative in paths:
    original = HERE / 'originals' / relative
    proposed = HERE / 'proposed' / relative
    before = original.read_text(encoding='utf-8') if original.exists() else ''
    patch += ''.join(difflib.unified_diff(before.splitlines(True),
        proposed.read_text(encoding='utf-8').splitlines(True),
        fromfile='a/' + relative if original.exists() else '/dev/null',
        tofile='b/' + relative))
    rows.append({'path': relative, 'sha256': hashlib.sha256(proposed.read_bytes()).hexdigest()})
(HERE / 'hearing_presence.patch').write_text(patch, encoding='utf-8', newline='\n')
receipt = json.loads((HERE / 'preparation.json').read_text(encoding='utf-8'))
receipt['files'] = rows
(HERE / 'preparation.json').write_text(json.dumps(receipt, indent=2) + '\n', encoding='utf-8')
print('Reviewed proposal repackaged; no live edit or runtime proof')
