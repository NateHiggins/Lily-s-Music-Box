"""Record the completed source replay without promoting geometry acceptance."""
from pathlib import Path
import hashlib
import json

ROOT = Path(__file__).resolve().parents[4]
PACKET = ROOT / 'design/astra'
EVIDENCE = PACKET / 'evidence/f01_source_replay/installed_01'


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def write(path, value):
    path.write_text(json.dumps(value, indent=2, ensure_ascii=False) + '\n', encoding='utf-8', newline='\n')


receipt = json.loads((EVIDENCE / 'receipt.json').read_text())
assert receipt['status'] == 'SOURCE_REPLAY_VALIDATED'
assert all(row['actual_exit'] == 0 for row in receipt['runs'])
assert receipt['protected_unchanged'] and receipt['only_named_ten_sources_added']
assert all(sha(EVIDENCE / path) == fingerprint for path, fingerprint in receipt['evidence_files'].items())
assert all(sha(ROOT / row['path']) == row['sha256'] for row in receipt['installed'])
catalog = json.loads((EVIDENCE / 'ownership_catalog.stdout.log').read_text())
assert catalog['record_count'] == 5286 and catalog['status'] == 'PASS'
for name, count in [('ownership_selftest', 25), ('exporter_selftest', 10)]:
    log = (EVIDENCE / (name + '.stderr.log')).read_text()
    assert f'Ran {count} tests in ' in log and log.rstrip().endswith('OK')
obligations_path = PACKET / 'reviews/production_obligations.json'
obligations = json.loads(obligations_path.read_text())
row = next(item for item in obligations if item['id'] == 'ASTRA-F01-CUT')
row['status'] = 'PROGRAMMED'
row['current_state'] = ('Installed exactly ten clean C1 ownership/export source and test files from '
    'c34ad283df148496fbd98e68638470835c930c5c over renderer/material HEAD '
    '77dc5f75cd7cb68be6d1f3d0be4f57ff1b06c3d4. The existing catalog and authorship checks '
    'pass for 5,286 records; all 35 existing tests pass. No Blender export, geometry provider '
    'or generated production asset is established by this source-only receipt.')
row['automated_proof'] = ('evidence/f01_source_replay/installed_01/receipt.json binds four actual '
    'zero-exit commands: catalog, authorship --check, 25 ownership tests and 10 exporter tests. '
    'All ten source bytes and all 17 protected paths remained unchanged after testing. '
    'Existing refusal and payload-corruption controls are included; no new failure baseline.')
row['open_defects'] = ['Current independent Blender export equivalence remains pending',
    'No production owner-cell provider, complete alias consumer or streaming lifecycle proof',
    'C1 human acceptance remains pending; dirty C2 consumers remain quarantined']
row['provenance']['sources'].append('evidence/f01_source_replay/installed_01/receipt.json')
assert len(row['provenance']['sources']) == len(set(row['provenance']['sources']))
write(obligations_path, obligations)
state_path = PACKET / 'LIVE_STATE.json'
state = json.loads(state_path.read_text())
state['current_f01_source_replay'] = {
    'path': 'evidence/f01_source_replay/installed_01/receipt.json',
    'sha256': sha(EVIDENCE / 'receipt.json'), 'base_head': receipt['head'],
    'source_reference': receipt['reference'], 'status': receipt['status'],
    'scope': 'Uncommitted named source additions; static audit at HEAD excludes them; no geometry adoption.'}
write(state_path, state)
log_path = PACKET / 'DECISION_LOG.md'
log = log_path.read_text(encoding='utf-8')
assert '### D035 ' not in log
log += ('\n### D035 — Reconstruct clean F01 sources in the canonical worktree\n\n'
    'The ten named ownership/export dependencies and tests were copied byte-for-byte from '
    '`c34ad283df148496fbd98e68638470835c930c5c` over renderer/material HEAD `77dc5f7`. '
    'The catalog and authorship checks pass for 5,286 records, and the 25 ownership plus '
    '10 exporter tests pass. The installation receipt verifies raw source provenance, '
    'the complete protected 17-path boundary and the absence of any other game/tools/art '
    'change during this source-only installation. This starts the attributable reconstruction; '
    'it does not adopt C1 geometry or dirty C2 work, select a provider, or confer human acceptance. '
    'Next: two fresh guarded Blender exports, followed by the reversible production consumer.\n')
log_path.write_text(log, encoding='utf-8', newline='\n')
print(json.dumps({'status': 'SOURCE_PROGRESS_RECORDED', 'receipt_sha256': sha(EVIDENCE / 'receipt.json'),
    'existing_tests': 35, 'existing_command_exits': [r['actual_exit'] for r in receipt['runs']]}))
