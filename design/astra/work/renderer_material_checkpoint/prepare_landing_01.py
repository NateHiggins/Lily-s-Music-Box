"""Freeze an explicit renderer/material landing, excluding new V2 inspection work."""
from pathlib import Path
import hashlib
import json
import subprocess

ROOT = Path(__file__).resolve().parents[4]
OUT = ROOT / 'design/astra/work/renderer_material_checkpoint/landing_01'
HEAD = 'da68962aaeaabf56851abb7190dda14d7ff5675f'


def git(*args):
    return subprocess.check_output(['git', *args], cwd=ROOT, stderr=subprocess.DEVNULL)


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def write(path, value):
    path.write_text(json.dumps(value, indent=2) + '\n', encoding='utf-8', newline='\n')


assert git('rev-parse', 'HEAD').decode().strip() == HEAD
assert not git('diff', '--cached', '--name-only')
inventory_path = ROOT / 'design/astra/work/renderer_material_checkpoint/reviewed_01/inventory.json'
inventory = json.loads(inventory_path.read_text())
assert sha(ROOT / inventory['protected_packet']) == inventory['protected_packet_expected_sha256_from_existing_nav_scope']
game = inventory['live_owner_paths'] + inventory['changed_visibility_fixtures'] + inventory['new_test_paths']
assert len(set(game)) == 16
result_path = ROOT / 'design/astra/evidence/vulkan_composed/runs/candidate_v1_material_final_01/result.json'
assert sha(result_path) == '94babcd295c78c1212b8eaddb5aef55aa4f7e54f86606ee5ebbc8a1e04b89f9d'
result = json.loads(result_path.read_text())
assert all(sha(ROOT / p) == result['after']['files'][p] for p in game)
pending = set(git('diff', 'HEAD', '--name-only').decode().splitlines())
pending.update(git('ls-files', '--others', '--exclude-standard').decode().splitlines())
assert {p for p in pending if p.startswith(('game/', 'tools/'))} == set(game)
roots = [row['root'] for row in inventory['named_family_roots']] + [
    'design/astra/work/foundation_status_review',
    'design/astra/work/renderer_material_checkpoint/reviewed_01',
    'design/astra/evidence/navigation_commit_audits_01',
    'design/astra/evidence/navigation_commit_audits_01_binding',
]
named = inventory['named_reviews'] + inventory['other_named_metadata'] + game + [
    'design/astra/reviews/one_census_matched_execution_review.md',
    'design/astra/reviews/final_v1_material_execution_review.md',
    'design/astra/reviews/final_v1_material_execution_review.json',
    'design/astra/evidence/navigation_commit_checkpoint.json',
    'design/astra/evidence/renderer_material_status_01.json',
    'design/astra/work/renderer_material_checkpoint/prepare_landing_01.py',
] + ['design/astra/' + p for p in [
    'DECISION_LOG.md', 'INTEGRATION_REGISTER.md', 'LIVE_STATE.json',
    'MASTER_COMPLETION_LEDGER.json', 'MASTER_COMPLETION_LEDGER.md',
    'PLAYTEST_FINDINGS.md', 'RELEASE_EVIDENCE_MATRIX.md', 'RISK_REGISTER.md',
    'reviews/production_obligations.json',
]]
excluded_prefixes = ['design/astra/work/vulkan_composed/revisions/terminal_operator_view_01/']
selected = {p for p in pending if any(p.startswith(r + '/') for r in roots)} | (set(named) & pending)
excluded = sorted(p for p in selected if any(part in {'APPDATA', '__pycache__', '.godot'} for part in Path(p).parts)
    or any(p.startswith(prefix) for prefix in excluded_prefixes))
selected.difference_update(excluded)
assert all((ROOT / p).is_file() for p in selected)
assert all((ROOT / p).is_file() for p in named)
protected = []
for record in inventory['protected_paths_from_trusted_packet']:
    path, expected = record['path'], record['current_blob']
    head = git('rev-parse', 'HEAD:' + path).decode().strip()
    index = git('ls-files', '--stage', '--', path).decode().split()[1]
    working = git('hash-object', '--path=' + path, path).decode().strip()
    assert head == index == working == expected, path
    protected.append({'path': path, 'head_blob': head, 'index_blob': index,
        'working_clean_blob': working, 'raw_sha256': sha(ROOT / path)})
OUT.mkdir(parents=True, exist_ok=False)
manifest = {'schema': 'astra.renderer-material.landing-selection.v1', 'head': HEAD,
    'status': 'PREPARED_NOT_STAGED', 'inventory_sha256': sha(inventory_path),
    'final_v1_result_sha256': sha(result_path), 'game_paths': sorted(game),
    'named_family_roots': roots, 'explicitly_named_paths': named,
    'selected_paths': sorted(selected), 'selected_count': len(selected),
    'selected_sha256': {p: sha(ROOT / p) for p in sorted(selected)},
    'protected': protected, 'excluded_paths': excluded,
    'scope': 'Two owners, fourteen fixture files, completed evidence and current status; no C1, RGB8 proposal, Harukiya proposal, new V2 operator fixture, default cutover or acceptance promotion.'}
write(OUT / 'selection.json', manifest)
paths = sorted(selected | {'design/astra/work/renderer_material_checkpoint/landing_01/selection.json',
    'design/astra/work/renderer_material_checkpoint/landing_01/paths.nul'})
(OUT / 'paths.nul').write_bytes(('\0'.join(paths) + '\0').encode())
print(json.dumps({'selected_count': len(selected), 'to_stage_count': len(paths), 'game_paths': sorted(game),
    'protected_count': len(protected), 'excluded_count': len(excluded),
    'selection_sha256': sha(OUT / 'selection.json')}, indent=2))
