"""Explain the retained red runtime using a collision-safe, read-only replay."""
import copy
import hashlib
import json
from pathlib import Path
import re

ROOT = Path(r'C:\PleaseRemainOnTheLine-astra')
BASE = ROOT / 'design/astra/evidence/v2_reservation_display_02'
RUN = BASE / 'runs/01_candidate'
sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
result = json.loads((RUN / 'result.json').read_text())
for relative, expected in result['artifacts'].items():
    assert sha(RUN / relative) == expected, relative
assert result['actual_runner_exit'] == 1
assert result['assessment']['passed'] == 25 and result['assessment']['total'] == 28
assert result['lane_contract']['lane_contract_exit'] == 0
assert not result['assessment']['unknown_diagnostics'] and not result['assessment']['retention']
restored = json.loads((BASE / '01_candidate.restoration.json').read_text())
assert restored['status'] == 'EXACT_OWNED_SOURCES_RESTORED'
assert restored['target_phase'] == 'preinstall'
assert all(sha(ROOT / path) == value for path, value in restored['hashes'].items())
probe = json.loads((RUN / 'shots/reservation_display.json').read_text())
witness = probe['witnesses']
pattern = re.compile(r'(^|/)@CollisionShape3D@[0-9]+$')

def normalize(rows):
    mapping = {key: pattern.sub(r'\1@CollisionShape3D', key) for key in rows}
    assert len(set(mapping.values())) == len(mapping), 'Ambiguous anonymous siblings'
    changed = [key for key in rows if mapping[key] != key]
    assert all(rows[key]['class'] == 'CollisionShape3D' for key in changed)
    result = {}
    for key, row in rows.items():
        row = copy.deepcopy(row)
        if 'collision_descendants' in row:
            row['collision_descendants'] = [mapping[path] for path in row['collision_descendants']]
        result[mapping[key]] = row
    return result, changed

def geometry(rows):
    rows = copy.deepcopy(rows)
    for row in rows.values():
        row.pop('visible', None)
        row.pop('visible_in_tree', None)
    return rows

a, renamed_a = normalize(witness['review'])
b, renamed_b = normalize(witness['hidden'])
collisions = lambda rows: {path: row for path, row in rows.items() if 'collision_layer' in row or 'shape_class' in row}
other = lambda rows: {path: [row.get('visible'), row.get('visible_in_tree')] for path, row in rows.items() if path not in witness['target_paths']}
assert geometry(a) == geometry(b)
assert collisions(a) == collisions(b)
assert other(a) == other(b)
assert len(a) == len(b) == 2237 and len(renamed_a) == len(renamed_b) == 527
review = {
    'status': 'READ_ONLY_REPLAY_EXPLAINS_AUTOMATIC_NAME_FAILURE',
    'runtime_result_remains_failed': True,
    'result_sha256': sha(RUN / 'result.json'),
    'raw_probe_sha256': sha(RUN / 'shots/reservation_display.json'),
    'restoration_sha256': sha(BASE / '01_candidate.restoration.json'),
    'verified_artifacts': len(result['artifacts']),
    'actual_native_exit': 1, 'actual_checks': '25/28',
    'actual_failed_labels': result['assessment']['failed_labels'],
    'nodes_per_bare_scene': 2237, 'anonymous_collision_shapes_per_scene': 527,
    'mapping_rule': 'Only trailing @CollisionShape3D@digits; actual CollisionShape3D class; one-to-one parent-relative mapping; every collision reference resolves.',
    'normalized_geometry_equal': True, 'normalized_collision_equal': True,
    'normalized_non_target_display_equal': True,
    'scope': 'Explains the three retained comparison failures. No new engine run or product acceptance; raw paths and failed receipt remain unchanged.',
}
output = ROOT / 'design/astra/reviews/v2_reservation_first_run_01.json'
assert not output.exists()
output.write_text(json.dumps(review, indent=2) + '\n', encoding='utf-8')
print(json.dumps(review, indent=2))
