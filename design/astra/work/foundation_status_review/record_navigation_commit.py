"""Record the reviewed nav landing and its separately bound static audit."""
from pathlib import Path
import hashlib
import json
import subprocess

ROOT = Path(__file__).resolve().parents[4]
PACKET = ROOT / 'design/astra'
PARENT = '9c12f19cf468d81c76369aca8a4f545a2129240b'


def git(*args):
    return subprocess.check_output(['git', *args], cwd=ROOT).decode().strip()


def read(rel):
    return json.loads((PACKET / rel).read_text(encoding='utf-8'))


def write(rel, value):
    (PACKET / rel).write_text(json.dumps(value, indent=2) + '\n', encoding='utf-8', newline='\n')


def sha(rel):
    return hashlib.sha256((PACKET / rel).read_bytes()).hexdigest()


def replace_once(rel, old, new):
    path = PACKET / rel
    content = path.read_text(encoding='utf-8')
    assert content.count(old) == 1, (rel, old)
    path.write_text(content.replace(old, new), encoding='utf-8', newline='\n')


head = git('rev-parse', 'HEAD')
assert git('rev-parse', 'HEAD^') == PARENT
assert not git('diff', '--cached', '--name-only')
selection_rel = 'work/resident_navigation_checkpoint/reviewed_01/selection.json'
stage = read('work/resident_navigation_checkpoint/reviewed_01/staging_manifest.json')
assert stage['head'] == PARENT and stage['status'] == 'VERIFIED' and not stage['issues']
assert sorted(git('diff-tree', '--no-commit-id', '--name-only', '-r', 'HEAD').splitlines()) == stage['actual_staged_paths']
audit_rel = 'evidence/navigation_commit_audits_01/receipt.json'
audit = read(audit_rel)
binding = read('evidence/navigation_commit_audits_01_binding/receipt.json')
assert audit['repository_head'] == head and binding['head'] == head and binding['source_unchanged']
exits = {row['id']: row['exit_code'] for row in audit['runs']}
assert all(code == (2 if name == 'orison_v2_completeness' else 1 if name == 'data_consumption' else 0)
           for name, code in exits.items())
aggregate_rel = 'evidence/resident_f01_haunt/nav_validation/nav_direct_03/aggregate.json'
assert sha(aggregate_rel) == '5ead54ffedbf6f8dde19b633a7ebe1eab06b4fa2b38d2efff45ec9901f19282f'
decisions_path = PACKET / 'DECISION_LOG.md'
decisions = decisions_path.read_text(encoding='utf-8')
assert 'ASTRA-D030' not in decisions, 'One-time nav commit record'

live = read('LIVE_STATE.json')
live.update(latest_repair_commit=head, latest_navigation_commit=head, ledger_evidence_head=head)
live['completeness_source'] = {
    'audit_id': 'orison_v2_completeness',
    'path': 'evidence/navigation_commit_audits_01/orison_v2_completeness.stdout.txt',
    'receipt_path': audit_rel, 'receipt_sha256': sha(audit_rel), 'repository_head': head,
    'sha256': sha('evidence/navigation_commit_audits_01/orison_v2_completeness.stdout.txt'),
}
live['policy'] = (f'The selected audit binds HEAD {head} plus its captured uncommitted renderer/material '
    f'and fixture overlay. Its {binding["input_count"]:,} source inputs were stable for that run. Later changes '
    'are not silently included. The two navigation owners and six fixtures are committed with exact '
    'historical evidence. Renderer and material candidates remain separate. Historical runtime receipts '
    'keep their original HEAD and source overlays; static evidence grants no runtime, human or release acceptance.')
write('LIVE_STATE.json', live)
rows = read('reviews/production_obligations.json')
ambient = next(row for row in rows if row['id'] == 'ASTRA-AGENT-AMBIENT')
assert ambient['status'] == 'PROGRAMMED'
ambient['provenance']['navigation_commit'] = head
ambient['provenance']['sources'] = list(dict.fromkeys(ambient['provenance']['sources'] + [aggregate_rel]))
ambient['open_defects'] = [d for d in ambient['open_defects'] if d != 'Navigation repair awaits its named commit/evidence checkpoint at this update']
write('reviews/production_obligations.json', rows)
decisions_path.write_text(decisions + '\n- ASTRA-D030: commit `' + head + '` lands exactly two navigation owners, '
    'six fixtures and the named historical nav/wait evidence. The final direct guard is33/33; three actual '
    'V1 journeys are31/31 through normal dwell, return and root retirement. Both narrow omissions fail '
    'as intended and exact restorations pass. Existing waiting40/40 and Passage26/26 remain unchanged. '
    'All17 protected paths are unchanged. Body layer/mask0, hidden lift riders, sampled support, broader '
    'graph safety, ordinary-day agents, human travel and performance remain explicit limits; no tier is promoted.\n',
    encoding='utf-8', newline='\n')
replace_once('INTEGRATION_REGISTER.md', '| M11C1/M11C2 and dream/lamp |',
    '| Resident public landings and bounded F01 journey | `' + head + '` | ResidentNav and ResidentRoutines committed with six fixtures; other renderer/material candidates excluded | Direct33/33, actual journey31/31 three times, two narrow omission/restoration controls, waiting40/40 and Passage26/26. Exact named selection and17 protected blobs verified. Layer-zero scripted actors and hidden lift ride remain; no human/crowd/ordinary-day or performance claim. |\n| M11C1/M11C2 and dream/lamp |')
replace_once('RISK_REGISTER.md',
    '| Resident destination and body/lifecycle scope | RELEASE_CRITICAL | F04 portal/approach/public-wait controls pass40/40; new public F01 point has actual-Body clearance and support, but route still crosses landing panels; earlier waiting capsule was an audit shape | Prove safe route and complete actual arrival/dwell/return, then ordinary-day/interruption/venue behavior |',
    '| Resident body and ordinary-day scope | RELEASE_CRITICAL | Public F01 destination and guarded short route complete31/31 actual journeys three times; waiting40/40 and Passage26/26 pass. Body remains layer/mask0 and lift riders hidden; earlier waiting capsule is separately qualified | Actual collision-bearing controllers, general route/crowd safety, ordinary-day perception/venue/social behavior, interruption and persistence |')
replace_once('RELEASE_EVIDENCE_MATRIX.md',
    '| Collision-bearing traversal | resident_lift_waiting/validation.json and resident_f01_haunt retained runs | Waiting/portal controls 40/40 and PassageNav 26/26; actual F01 arrival reached, but current destination candidate still fails its landing-door route sweep | Complete safe F01 dwell/return, actual controller, composed full routes and sequence breaking |',
    '| Resident journey and collision-bearing traversal | resident_f01_haunt/nav_validation/nav_direct_03/aggregate.json and resident_lift_waiting/validation.json | Direct33/33 and three actual31/31 journeys through full dwell, return and root retirement; narrow omissions fail and restore. Waiting40/40 and Passage26/26. Actual Body inspected but production movement remains layer-zero scripted with hidden lift riders | Actual collision-bearing PlayerController routes, general graph/crowd safety, ordinary-day actors, sequence breaking and human review |')
matrix = PACKET / 'RELEASE_EVIDENCE_MATRIX.md'
content = matrix.read_text(encoding='utf-8')
content = content.replace('time_hearing_commit_audits_01/data_consumption.stdout.txt', 'navigation_commit_audits_01/data_consumption.stdout.txt')
content = content.replace('| Spatial/systemic/implementor instruments | time_hearing_commit_audits_01 and world_timestamps receipts |', '| Spatial/systemic/implementor instruments | navigation_commit_audits_01 and world_timestamps receipts |')
old_current = ('`9c12f19cf468d81c76369aca8a4f545a2129240b`; `LIVE_STATE.json` selects the\n'
    'time_hearing_commit_audits_01 receipt at that HEAD plus its explicitly bound\n'
    'uncommitted source overlay. Its 1,625 inputs were stable during the audit;\n'
    'later fixture and candidate changes are not included. Five safety instruments\n'
    'and all seven existing selftest suites pass;\n'
    'completeness exits 2 and data consumption exits 1. No baseline, release gate,\n'
    'human acceptance, default selector or quarantined branch status was relaxed.')
assert content.count(old_current) == 1
content = content.replace(old_current,
    '`9c12f19cf468d81c76369aca8a4f545a2129240b`. Its time_hearing_commit_audits_01\n'
    'receipt remains historical evidence at that HEAD and its then-current\n'
    'uncommitted overlay. The newer selected nav audit is described below. No\n'
    'baseline, release gate, human acceptance, default selector or quarantined\n'
    'branch status was relaxed.')
content += ('\nNavigation production is now committed at `' + head + '`. The currently selected static audit is '
    '`navigation_commit_audits_01`, with its exact post-commit renderer/material fixture overlay and '
    f'{binding["input_count"]:,} stable source inputs. Five safety audits and seven selftest suites exit0; '
    'completeness2 and data-consumption1 remain open. Earlier cited runtime and static receipts keep their '
    'historical source boundaries. The full-game and human evidence tiers remain unchanged.\n')
matrix.write_text(content, encoding='utf-8', newline='\n')
findings = PACKET / 'PLAYTEST_FINDINGS.md'
findings.write_text(findings.read_text(encoding='utf-8') + '\n- RESIDENT-F01-JOURNEY-FINAL: the public destination '
    'and guarded short route now complete33 focused checks and three31-check actual V1 journeys, including '
    'normal44.274-second dwell, real return-lift readiness, original4D home and root retirement. Nav-call '
    'omission20/21 and old-coordinate omission15/21 remain diagnostic red; exact restorations pass. Earlier '
    'fixture errors/timeouts and destination/route failures remain immutable historical findings. These '
    'runs hold other actor choices/player, freeze campaign time and call one production _step per physics '
    'frame; they do not prove collision-bearing movement, full ordinary-day behavior or performance. '
    'Known host-loader/RGB8/found-art diagnostics remain recorded. See the final aggregate.\n',
    encoding='utf-8', newline='\n')
write('evidence/navigation_commit_checkpoint.json', {
    'production_commit': head, 'parent': PARENT, 'selected_audit': live['completeness_source'],
    'audit_exits': exits, 'stable_audit_input_count': binding['input_count'],
    'selected_path_count': stage['selected_paths'], 'selection_sha256': sha(selection_rel),
    'final_nav_aggregate_sha256': sha(aggregate_rel), 'protected_paths_unchanged': 17,
    'historical_receipts_rewritten': False, 'full_game_complete': False,
    'human_or_release_acceptance': False, 'default_selector': 'v1',
})
print('Recorded navigation commit and post-commit audit; broad evidence tiers unchanged.')
