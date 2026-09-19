"""Inventory reviewed source bindings; never classify them as runtime proof."""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[4]
report = json.loads((Path(__file__).parent/'spatial_before_review.json').read_text())
path = ROOT/'tools/orison_spatial_dependency_manifest.json'
manifest = json.loads(path.read_text())
reviewed = {
    'e4df3123e2131a21': 'V2 connection resolves the preserved F01 front door uniquely from blockout doors.',
    '081f54852e081df0': 'V2 connection keeps this open-shell semantic space while the exterior owns its geometry.',
    '37a6d01e4a9686da': 'V2 connection derives outward orientation from the named vestibule and its connected door.',
    '278e31b0de3e0971': 'Runtime creates this preserved DeskZone identity from the terminal-use footprint and operator stance.',
    '1eef430d5e31abf3': 'Runtime adapter resolves the named operator stance; global position controls terminal orientation.',
    '09631e744e448653': 'Runtime adapter resolves the named use envelope; global AABB controls interaction footprint.',
    'b8009f733680f4dd': 'V2 atmosphere reuses the existing production night panorama; asset path must survive migration.',
}
existing = {record['key'] for record in manifest['records']}
new = {record['key']: record for record in report['drift']['new_failing']}
assert not (existing & reviewed.keys())
assert reviewed.keys() <= new.keys()
for key, reason in reviewed.items():
    record = new[key].copy()
    assert record['target_exists'] is not False
    if record['kind'] == 'asset_path':
        assert (ROOT/'game'/record['token'].removeprefix('res://')).is_file()
    record['rationale'] = reason + ' Source inventory only; this does not confer runtime or cutover acceptance.'
    manifest['records'].append(record)
path.write_text(json.dumps(manifest, indent=1)+'\n', encoding='utf-8', newline='\n')
(Path(__file__).parent/'spatial_review.json').write_text(json.dumps({
    'reviewed_bindings': reviewed,
    'unreviewed_optional_provider_keys': sorted(new.keys() - reviewed.keys()),
    'existing_records_changed': 0,
    'classification_changes_accepted': 0,
    'runtime_acceptance': False,
}, indent=2)+'\n', encoding='utf-8', newline='\n')
