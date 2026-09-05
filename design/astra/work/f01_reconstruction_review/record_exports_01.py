"""Record the two executed exports and their independent comparison."""
from pathlib import Path
import hashlib
import json

ROOT = Path(__file__).resolve().parents[4]
PACKET = ROOT / 'design/astra'
RUN = PACKET / 'evidence/f01_source_export/export_01'


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def write(path, data):
    path.write_text(json.dumps(data, indent=2, ensure_ascii=False) + '\n', encoding='utf-8', newline='\n')


comparison = json.loads((RUN / 'comparison.json').read_text())
assert comparison['status'] == 'TWO_EXPORT_BYTE_OWNERSHIP_ALIAS_CHECKS_PASS_HUMAN_PENDING'
runs = []
for mode in ['a', 'b']:
    result = json.loads((RUN / mode / 'outer_result.json').read_text())
    assert result['outer_contract_exit'] == result['actual_bridge_exit'] == result['actual_blender_exit'] == result['actual_controller_exit'] == 0
    assert result['inputs_unchanged'] and result['empty_process_census_after']
    for name in ['blender.stderr.raw', 'controller.stderr.raw']:
        assert (RUN / mode / name).stat().st_size == 0
    assert all(sha(RUN / mode / p) == h for p, h in result['artifacts'].items())
    runs.append({'mode': mode, 'outer_result_sha256': sha(RUN / mode / 'outer_result.json'),
        'output': result['output'], 'elapsed_seconds': result['elapsed_seconds'], 'all_process_exits': 0})
assert comparison['runs'][0]['deterministic_36'] == comparison['runs'][1]['deterministic_36']
summary = {'status': comparison['status'], 'base_head': '77dc5f75cd7cb68be6d1f3d0be4f57ff1b06c3d4',
    'comparison_path': 'evidence/f01_source_export/export_01/comparison.json',
    'comparison_sha256': sha(RUN / 'comparison.json'), 'binding_sha256': sha(RUN / 'binding.json'),
    'counts': comparison['runs'][0]['recomputed_counts'], 'runs': runs,
    'input_boundary': '2,071 path existence/content records, including 17 protected paths; unchanged across both exports.',
    'independent_scope': '36 geometry file hashes, catalog ownership, actual cell addressing, alias completeness and counts.',
    'existing_core_scope': 'Nine canonical equivalence checks for vertex, triangle, world-triangle, attribute, material, collision, bounds, alias union and transform payloads passed in each fresh run.',
    'diagnostics': 'Both actual Blender and controller stderr streams are empty; root read both raw Blender stdout streams, containing version/catalog/library information and one generation marker each.',
    'limits': 'External deterministic reconstruction only. No generated production asset, provider, streaming, traversal, human acceptance or release proof.'}
assert not (RUN / 'summary.json').exists()
write(RUN / 'summary.json', summary)
path = PACKET / 'reviews/production_obligations.json'
obligations = json.loads(path.read_text())
row = next(item for item in obligations if item['id'] == 'ASTRA-F01-CUT')
row['current_state'] = ('Clean C1 sources are installed and tested. Two fresh Blender/controller exports '
    'and the independent comparison pass with 17 cells, 5,286 source records, 609 primitives, '
    '531 aliases and 189 semantic owners. All 36 geometry files are byte-identical between runs. '
    'Protected inputs are unchanged. The production provider is still absent; C1 human acceptance '
    'remains pending and dirty C2 work remains quarantined.')
row['automated_proof'] += (' Fresh export A and B each have Blender/controller/outer exit 0; independent '
    'comparison exit 0. All 2,071 input path states are unchanged. Existing canonical payload checks '
    'pass in both runs; the independent checker confirms bytes, ownership and aliases. '
    'The instrument also passed ten offline process/refusal controls. See export_01/summary.json.')
row['next_decisive_action'] = ('Build an explicit optional F01 provider against the current root, retaining '
    'a selectable legacy control, imported glTF ownership, complete aliases and current consumer classes. '
    'Prove actual-root composition and teardown before adding dynamic residency. Preserve v1 default '
    'and human-pending C1 scope.')
row['open_defects'] = ['No production owner-cell provider or complete alias consumer',
    'Streaming, actual routes, persistence and root lifecycle remain unproven for this geometry cut',
    'C1 human acceptance remains pending; dirty C2 consumers remain quarantined']
row['provenance']['sources'].append('evidence/f01_source_export/export_01/summary.json')
write(path, obligations)
path = PACKET / 'LIVE_STATE.json'
state = json.loads(path.read_text())
state['current_f01_export'] = {'path': 'evidence/f01_source_export/export_01/summary.json',
    'sha256': sha(RUN / 'summary.json'), 'base_head': summary['base_head'], 'status': summary['status'],
    'scope': summary['limits']}
write(path, state)
path = PACKET / 'DECISION_LOG.md'
log = path.read_text(encoding='utf-8')
assert '### D036 ' not in log
log += ('\n### D036 — Two independent clean F01 regenerations pass\n\n'
    'Both Blender 5.2.0 LTS exports and their existing canonical equivalence controllers exited 0. '
    'The independent comparison exited 0: candidate plus 17 cell glTF/BIN pairs are byte-identical '
    'across fresh external outputs, with 5,286 sources, 609 primitives, 183,726 triangles, '
    '345,536 vertices, 531 aliases (47 one-to-many) and 189 semantic owners. All 2,071 bound '
    'input path states, including the protected 17 paths, remain unchanged. Raw Blender and '
    'controller stderr are empty. The 95.203 s and 86.532 s outer transaction durations are '
    'generation records, not game-performance acceptance. The next construction step is an optional '
    'production provider with explicit legacy alias consumers; no generated production asset, '
    'streaming, selector or human-acceptance change is inferred. See '
    '`evidence/f01_source_export/export_01/summary.json`.\n')
path.write_text(log, encoding='utf-8', newline='\n')
print(json.dumps({'status': summary['status'], 'summary_sha256': sha(RUN / 'summary.json')}))
