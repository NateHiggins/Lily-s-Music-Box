"""Record the exact reviewed material/renderer commit and static source boundary."""
from pathlib import Path
import hashlib
import json
import subprocess

ROOT = Path(__file__).resolve().parents[4]
PACKET = ROOT / 'design/astra'
HEAD = '77dc5f75cd7cb68be6d1f3d0be4f57ff1b06c3d4'


def read(path):
    return json.loads((PACKET / path).read_text(encoding='utf-8'))


def sha(path):
    return hashlib.sha256((PACKET / path).read_bytes()).hexdigest()


def write(path, data):
    (PACKET / path).write_text(json.dumps(data, indent=2) + '\n', encoding='utf-8', newline='\n')


assert subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT).decode().strip() == HEAD
assert not subprocess.check_output(['git', 'diff', '--cached', '--name-only'], cwd=ROOT)
commit = read('work/renderer_material_checkpoint/staging_01/commit_verification.json')
assert commit['head'] == HEAD and commit['path_count'] == 3786 and commit['all_modes_blobs_verified']
audit_rel = 'evidence/renderer_material_commit_audits_01/receipt.json'
audit = read(audit_rel)
binding = read('evidence/renderer_material_commit_audits_01_binding/receipt.json')
assert audit['repository_head'] == binding['head'] == HEAD and binding['source_unchanged']
exits = {row['id']: row['exit_code'] for row in audit['runs']}
assert all(value == (2 if key == 'orison_v2_completeness' else 1 if key == 'data_consumption' else 0) for key, value in exits.items())
decisions = PACKET / 'DECISION_LOG.md'
assert 'ASTRA-D034' not in decisions.read_text(encoding='utf-8')
live = read('LIVE_STATE.json')
live.update(latest_repair_commit=HEAD, latest_renderer_material_commit=HEAD, ledger_evidence_head=HEAD)
live['completeness_source'] = {'audit_id': 'orison_v2_completeness',
    'path': 'evidence/renderer_material_commit_audits_01/orison_v2_completeness.stdout.txt',
    'receipt_path': audit_rel, 'receipt_sha256': sha(audit_rel), 'repository_head': HEAD,
    'sha256': sha('evidence/renderer_material_commit_audits_01/orison_v2_completeness.stdout.txt')}
live['policy'] = ('The selected static audit binds renderer/material commit ' + HEAD + ' and2328 stable explicit text/glTF inputs. '
    'Its broader text suffix coverage is declared in the binding receipt; native assets have separate protected/runtime manifests. '
    'The two owners and fourteen fixtures are committed with exact failed/control/final evidence. Later V2 fixture/C1 work is not included. '
    'Historical runtime receipts retain their original HEAD and captured overlays. Static or bounded runtime success grants no human, visual or release acceptance.')
write('LIVE_STATE.json', live)
rows = read('reviews/production_obligations.json')
perf = next(row for row in rows if row['id'] == 'ASTRA-PERF')
assert perf['status'] == 'PROGRAMMED'
perf['current_state'] = perf['current_state'].replace('The current production candidates await their named checkpoint.',
    'The two production owners and fourteen fixtures are committed at ' + HEAD + '; broader performance and V2 product work remain open.')
perf['next_decisive_action'] = perf['next_decisive_action'].replace('Land the reviewed foundation sources and evidence. ', '')
perf['open_defects'] = [item.replace('Current renderer/material source checkpoint is pending; no-op native-call count remains explicitly unproved.',
    'No-op native-call count remains explicitly unproved.') for item in perf['open_defects']]
perf['provenance']['renderer_material_commit'] = HEAD
perf['provenance']['sources'] = list(dict.fromkeys(perf['provenance']['sources'] + [
    'work/renderer_material_checkpoint/landing_01/selection.json',
    'work/renderer_material_checkpoint/staging_01/commit_verification.json', audit_rel]))
write('reviews/production_obligations.json', rows)
register = PACKET / 'INTEGRATION_REGISTER.md'
text = register.read_text(encoding='utf-8')
anchor = '| M11C1/M11C2 and dream/lamp |'
assert text.count(anchor) == 1
text = text.replace(anchor, '| Renderer world boundaries and apartment material ownership | `' + HEAD + '` | Two production owners and fourteen fixtures committed; default V1 retained | Operation/viewport/material selective reds retained; wardrobe63, equivalence171, actual material314 and final base305 pass. V2 structural14 passes but terminal camera is occluded. Final Street/Passage remains approximately1.19s; no art/human/release performance acceptance. |\n' + anchor)
register.write_text(text, encoding='utf-8', newline='\n')
decisions.write_text(decisions.read_text(encoding='utf-8') + '\n- ASTRA-D034: commit `' + HEAD + '` lands exactly3786 named paths: two production owners, fourteen fixtures, retained evidence and current status. Every committed mode/blob matches the reviewed stage. All17 protected HEAD/index/working blobs and raw hashes remain unchanged; independent review verifies3784 selected raw hashes and1850 artifact references across36 clear result schemas. The postcommit static audit binds2328 stable text/glTF inputs; five safety audits and seven selftests exit0, completeness2/data1 remain open. Later V2 inspection work and C1 replay are outside this landing. No default, baseline, human or release acceptance changed.\n', encoding='utf-8', newline='\n')
matrix = PACKET / 'RELEASE_EVIDENCE_MATRIX.md'
text = matrix.read_text(encoding='utf-8')
text = text.replace('| Data consumption | navigation_commit_audits_01/data_consumption.stdout.txt and bound receipt |',
    '| Data consumption | renderer_material_commit_audits_01/data_consumption.stdout.txt and bound receipt |')
text = text.replace('| Spatial/systemic/implementor instruments | navigation_commit_audits_01 and world_timestamps receipts |',
    '| Spatial/systemic/implementor instruments | renderer_material_commit_audits_01 and world_timestamps receipts |')
text = text.replace('The currently selected static audit is `navigation_commit_audits_01`,',
    'Its historical postcommit static audit is `navigation_commit_audits_01`,')
text += ('\nThe current selected static audit is `renderer_material_commit_audits_01` at `' + HEAD + '`, binding2328 unchanged text/glTF inputs with explicit broader suffix coverage. '
    'Five safety audits and seven selftests pass; completeness2 and data-consumption1 remain authoritative. The source landing contains exactly two owners and fourteen fixtures. '
    'Later V2 operator-view diagnostics/C1 source replay are outside this audit and retain their own source boundaries.\n')
matrix.write_text(text, encoding='utf-8', newline='\n')
write('evidence/renderer_material_commit_checkpoint.json', {'production_commit': HEAD, 'parent': commit['parent'],
    'selected_audit': live['completeness_source'], 'audit_exits': exits, 'stable_audit_input_count': binding['input_count'],
    'committed_paths': commit['path_count'], 'production_owners': 2, 'fixtures': 14, 'protected_paths_unchanged': 17,
    'all_committed_modes_blobs_verified': True, 'historical_receipts_rewritten': False, 'full_game_complete': False,
    'human_or_release_acceptance': False, 'default_selector': 'v1'})
print('Renderer/material commit and current static source boundary recorded.')
