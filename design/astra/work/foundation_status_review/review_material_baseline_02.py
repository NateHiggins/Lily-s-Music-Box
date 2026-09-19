"""Source-bound observations from the completed red composed material baseline."""
from pathlib import Path
from collections import Counter, defaultdict
import hashlib
import json
import statistics

ROOT = Path(__file__).resolve().parents[4]
RUN = ROOT / 'design/astra/evidence/vulkan_composed/runs/material_ownership_7c54_v1_full_02'
OUT = ROOT / 'design/astra/evidence/composed_material_ownership/typed_baseline_review_02.json'
assert not OUT.exists()
result = json.loads((RUN / 'result.json').read_text())
probe = json.loads((RUN / 'frames/probe.json').read_text())


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


failures = [row['label'] for row in probe['checks'] if row['passed'] is not True]
assert len(probe['checks']) == 314 and len(failures) == 8
assert all(name.startswith('material ') for name in failures)
assert result['actual_engine_exit'] == 1 and result['source_unchanged']
assert probe['material_retirement']['released']
images = sorted((RUN / 'frames').glob('*.png'))
assert len(images) == 18
image_hashes = {path.name: sha(path) for path in images}
assert all(result['artifacts']['frames/' + name] == fingerprint for name, fingerprint in image_hashes.items())
transitions = defaultdict(list)
last = None
for row in probe['transitions']:
    station = row['station']
    if not row['warmup']:
        transitions[str(last) + ' -> ' + station].append(row['apply_usec'] / 1000.0)
    last = station
timings = {name: {'n': len(values), 'median_apply_ms': statistics.median(values),
    'min_apply_ms': min(values), 'max_apply_ms': max(values)} for name, values in transitions.items()}
first = probe['material_observations'][0]
report = {
    'status': 'COMPOSED_MATERIAL_RED_REVIEWED_NO_ACCEPTANCE',
    'result_sha256': sha(RUN / 'result.json'), 'probe_sha256': sha(RUN / 'frames/probe.json'),
    'owner_sha256': '7c54c18154ccf8de8c3bce13a356329344dec19411adb2f1237425ae99eb90db',
    'fixture_sha256': 'c2642de6f0c099a18e8d7c0f740f94a84f0d5bc90cc255973dee5ab6ad2ee6b5',
    'native_exit': 1, 'diagnostic_exit': 1, 'checks': 314, 'passed': 306,
    'failed_checks': failures, 'original_renderer_checks_passed': 305,
    'new_material_retirement_passed': True,
    'non_inherited_error_headers': result['gate']['non_inherited_error_headers'],
    'unpair_errors': result['gate']['unpair_errors'],
    'soft_shadow_underflows': result['gate']['soft_shadow_underflows'],
    'retention_diagnostics': result['gate']['retention'], 'known_warning_debt': result['gate']['warnings'],
    'source_unchanged': result['source_unchanged'],
    'observations': [{
        'stage': observation['stage'], 'issues': observation['issues'],
        'governor': observation['surface_governor'],
        'registries': {floor: {'slots': row['slots'], 'unique': row['unique'], 'invalid': row['invalid'],
            'extra_registered_ids': sorted(set(row['material_ids']) - set(row['installed_ids'])),
            'missing_registered_ids': sorted(set(row['installed_ids']) - set(row['material_ids']))}
            for floor, row in observation['registries'].items()},
        'refresh': {key: value for key, value in observation.get('refresh', {}).items()
                    if key in ['passed', 'mutated', 'facts_unchanged', 'same_frame_restored', 'force_restored', 'intensities_restored', 'precondition']},
    } for observation in probe['material_observations']],
    'perceptual_review': {
        'all_18_images_directly_viewed_by_root': True, 'image_sha256': image_hashes,
        'observations': [
            'Street, Passage, lobby and F04 preserve recognizable geometry in main and secondary cameras; phone views are brighter than the main view.',
            'The two Passage views retain shopfronts, floor pattern and cart placement before retirement.',
            'Harukiya initial/return retain bar, stools and tables, but most of the interior is too dark for a finished readability claim.',
            'The actual F04 mirror contains a reflection; its wall image remains visibly distorted, and the separate reflection view has pronounced striped/banded surface shading. This is appearance debt, not a renderer ownership pass.',
            'The actual Operations cabinet retains the same room and title/text before and after Passage. INSERT COIN brightness changes while scene contents remain.',
            'The separate-world red square is visible initially/restored and absent in the blocked view.',
            'The visible building remains a rough presentation: blocky hand apparatus, repetitive finishes, coarse surfaces and uneven darkness. These screenshots grant no art, human-input, motion or release acceptance.',
            'The wardrobe ownership defects were found by actual installed-material observations; these fixed camera views do not show or visually clear those specific panels.',
        ],
    },
    'transition_samples': timings,
    'timing_scope': 'Six repeated cycles from this failed instrumented full V1 run. Material observers and synchronous probes run outside apply timers but affect workload/context. No speedup attribution against older different-source runs; no release or clean-baseline performance acceptance.',
    'external_gate_defect': 'The initial additive material gate incorrectly rejects valid negative signed Godot RefCounted ObjectIDs. Preserve its red output and revise separately; this does not explain or clear the eight actual GDScript material failures.',
    'next_decisive_action': 'Repair independently verified cross-floor case/material ownership, retain this actual composed red, restore and rerun before applying the separately equivalent one-census optimization.',
}
OUT.write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8', newline='\n')
print(json.dumps({'checks': 314, 'passed': 306, 'failures': 8, 'images_reviewed': len(images),
    'transition_samples': timings, 'report_sha256': sha(OUT)}, indent=2))
