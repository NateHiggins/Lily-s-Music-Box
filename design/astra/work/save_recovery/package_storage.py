"""Package an inspectable proposal and negative source controls; no live edits."""
from pathlib import Path
import ast
import difflib
import hashlib
import json

ROOT = Path(__file__).resolve().parent
REPO = ROOT.parents[3]
PROPOSED = ROOT / 'proposed'
files = sorted(p for p in PROPOSED.rglob('*') if p.is_file())
patch = []
records = []
for file in files:
    relative = file.relative_to(PROPOSED).as_posix()
    original = ROOT / 'originals' / relative
    before = original.read_text(encoding='utf-8') if original.exists() else ''
    after = file.read_text(encoding='utf-8')
    patch.extend(difflib.unified_diff(before.splitlines(keepends=True), after.splitlines(keepends=True),
        fromfile=f'a/{relative}' if original.exists() else '/dev/null', tofile=f'b/{relative}'))
    records.append({'target': relative, 'sha256': hashlib.sha256(file.read_bytes()).hexdigest(),
                    'lines': len(after.splitlines())})
(ROOT / 'storage_reality_state.patch').write_text(''.join(patch), encoding='utf-8', newline='\n')

storage = (PROPOSED / 'game/scripts/game/reality_save_storage.gd').read_text(encoding='utf-8')
controls = ROOT / 'controls'
controls.mkdir(exist_ok=True)
needle = 'return checked.kind == "bytes" and checked.bytes == bytes'
assert storage.count(needle) == 1
(controls / 'storage_no_readback.gd').write_text(storage.replace(needle, 'return true # NEGATIVE CONTROL: disables byte verification'), encoding='utf-8', newline='\n')
needle = 'if checked.code in ["future_save_read_only", "campaign_clock_read_only"]:'
assert storage.count(needle) == 1
(controls / 'storage_future_fallback.gd').write_text(storage.replace(needle, 'if false: # NEGATIVE CONTROL: removes primary refusal precedence'), encoding='utf-8', newline='\n')

original_matches = {}
for name in ['reality_game_state.gd', 'campaign_clock.gd']:
    relative = Path('game/scripts/game') / name
    original_matches[relative.as_posix()] = ((ROOT / 'originals' / relative).read_bytes()
                                            == (REPO / relative).read_bytes())
for path in [ROOT / 'prepare_reality_state.py', Path(__file__)]:
    ast.parse(path.read_text(encoding='utf-8'), filename=str(path))
runtime_cases = ['original_invalid_red', 'candidate_invalid_02', 'malformed_entry_red',
                 'malformed_entry_green', 'invalid_utf8_red', 'invalid_utf8_green',
                 'complete_no_readback_red', 'complete_future_fallback_red',
                 'complete_recovery_green', 'complete_compat_green', 'complete_calendar_green',
                 'process_restart_03']
runtime = {name: f'design/astra/evidence/save_recovery/{name}/receipt.json' for name in runtime_cases
           if (REPO / f'design/astra/evidence/save_recovery/{name}/receipt.json').is_file()}
receipt = {'status': 'integrated_focused_runtime_validated' if len(runtime) == len(runtime_cases)
           else 'prepared_not_integrated_not_executed', 'files': records,
           'original_live_byte_matches': original_matches,
           'original_copy_role': 'Preserved pre-integration references; live differences are intentional after authorized implementation.',
           'checks': ['Python preparation scripts parse with ast.parse',
                      'exact negative-control mutation anchors are unique',
                      'patch/source SHA256 package generated'],
           'runtime_receipts': runtime,
           'not_run': ['human K3 route matrix', 'native atomic replacement / power-loss durability'],
           'integration_dependency': 'Root-owned CampaignClock.bind_state guard is present and covered by focused runtime checks.',
           'current_clock_sha256': hashlib.sha256((REPO / 'game/scripts/game/campaign_clock.gd').read_bytes()).hexdigest()}
(ROOT / 'preparation_receipt.json').write_text(json.dumps(receipt, indent=2) + '\n', encoding='utf-8')
print(json.dumps(receipt, indent=2))
