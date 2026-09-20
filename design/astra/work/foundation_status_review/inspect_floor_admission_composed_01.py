"""Read-only complete raw-artifact and material-observer inspection."""
from pathlib import Path
from collections import defaultdict
import hashlib
import json
import statistics

ROOT = Path(__file__).resolve().parents[4]
RUN = ROOT / 'design/astra/evidence/vulkan_composed/runs/material_floor_admission_v1_full_01'
OUT = ROOT / 'design/astra/evidence/composed_material_ownership/floor_admission_inspection_01.json'


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


assert not OUT.exists(), 'Preserve the first inspection.'
result = json.loads((RUN / 'result.json').read_text())
probe = json.loads((RUN / 'frames/probe.json').read_text())
artifacts = result['artifacts']
issues = []
for name, digest in artifacts.items():
    path = RUN / name
    if not path.is_file() or sha(path) != digest:
        issues.append('missing or changed artifact: ' + name)
expected = {
    'game/scripts/reality/apartment_encroachment.gd': '2a440504ab80404f4d9f4ab16138df7db9255801ca879ff91aabafe3c7f4d0ca',
    'game/tests/vulkan_composed_root_test.gd': 'd67ce1ac8b19d51f6d4ccc88bc3fe11599dd6068afaccea6abb1d9ec50712508',
}
for label in ['before', 'after']:
    if any(result[label]['files'].get(path) != digest for path, digest in expected.items()):
        issues.append('exact owner/observer binding differs: ' + label)
    if sha(RUN / (label + '.diff')) != result[label]['diff_sha256']:
        issues.append('source diff binding differs: ' + label)
if result['before']['files'] != result['after']['files'] or not result['source_unchanged']:
    issues.append('game/tool inputs changed during run')
observations = []
for observation in probe['material_observations']:
    refresh = observation.get('refresh', {})
    record = {'stage': observation['stage'], 'issues': observation['issues'],
        'surface_governor': observation['surface_governor'],
        'registries': {floor: {'slots': row['slots'], 'unique': row['unique'], 'invalid': row['invalid'],
            'installed_exact': set(row['material_ids']) == set(row['installed_ids'])}
            for floor, row in observation['registries'].items()}}
    if refresh:
        names = ['passed', 'mutated', 'comparison_contract', 'case_rows_planned', 'case_rows_evaluated',
            'case_comparisons_evaluated', 'case_materials_touched', 'case_lifecycle_materials_evaluated',
            'registry_live_slots', 'registry_unique_materials', 'registry_lifecycle_materials_evaluated',
            'registry_types_valid', 'registry_lifecycle_restored', 'lifecycle_restore_union_size',
            'registry_restore_failures', 'facts_unchanged', 'same_frame_restored', 'force_restored',
            'intensities_restored']
        record['refresh'] = {key: refresh.get(key) for key in names}
        record['refresh']['precondition_passed'] = refresh.get('precondition', {}).get('passed')
        for key in ['case_comparisons', 'case_lifecycle_comparisons', 'registry_lifecycle_comparisons']:
            rows = refresh.get(key, [])
            record['refresh'][key] = {'rows': len(rows),
                'evaluated': sum(row.get('evaluated') is True for row in rows),
                'passed': sum(row.get('passed') is True for row in rows),
                'failed_rows': [row for row in rows if row.get('passed') is not True]}
        record['refresh']['full_registry_snapshot_equal'] = (
            refresh.get('registry_lifecycle_before') == refresh.get('registry_lifecycle_after'))
    observations.append(record)
transitions = defaultdict(list)
last = None
for row in probe['transitions']:
    if not row['warmup']:
        transitions[str(last) + ' -> ' + row['station']].append(row['apply_usec'] / 1000.0)
    last = row['station']
timings = {route: {'n': len(values), 'median_apply_ms': statistics.median(values),
    'min_apply_ms': min(values), 'max_apply_ms': max(values)} for route, values in transitions.items()}
images = sorted((RUN / 'frames').glob('*.png'))
report = {'status': 'RAW_ARTIFACT_AND_OBSERVER_INSPECTION_VISUAL_REVIEW_SEPARATE',
    'result_sha256': sha(RUN / 'result.json'), 'probe_sha256': sha(RUN / 'frames/probe.json'),
    'source_bindings': expected, 'artifact_count': len(artifacts), 'binding_issues': issues,
    'native_exit': result['actual_engine_exit'], 'base_gate': result['gate'],
    'checks': len(probe['checks']), 'passed': sum(row['passed'] is True for row in probe['checks']),
    'failed_checks': [row['label'] for row in probe['checks'] if row['passed'] is not True],
    'material_observations': observations, 'material_retirement': probe['material_retirement'],
    'transition_samples': timings, 'images': {path.name: sha(path) for path in images},
    'scope': 'Actual V1 authored build and teleported rendered transitions; no traversal, art/human or release performance acceptance. Compare optimization only against identical owner/observer context.'}
OUT.write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8', newline='\n')
print(json.dumps({key: report[key] for key in ['artifact_count', 'binding_issues', 'native_exit',
    'checks', 'passed', 'failed_checks', 'material_observations', 'material_retirement', 'transition_samples']}, indent=2))
print('inspection_sha256=' + sha(OUT))
