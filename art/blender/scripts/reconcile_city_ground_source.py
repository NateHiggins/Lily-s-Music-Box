"""Reconcile the classified ground authoring map after the northwest registration.

Run after build_city_shells.py, before build_city_foundations.py and
build_orison_ground.py. Only this reviewed migration is allowed; unrelated
retained owners must still match their original bindings.
"""
from pathlib import Path
import hashlib
import json

ROOT = Path(__file__).resolve().parents[3]
PLAN = ROOT / 'art/data/orison_ground/retained_grade_source.json'
CITY = 'art/blender/city_shells.blend'
PREVIOUS_CITY = '52e06418d2a82dda0d5bacf754e45f37b51c2f7afcc5a35f97cd4a06cefb6ffd'

def source_hash(path):
    raw = path.read_bytes() if path.suffix in ['.blend', '.glb'] else path.read_text(encoding='utf-8').replace('\r\n', '\n').encode()
    return hashlib.sha256(raw).hexdigest()

plan = json.loads(PLAN.read_text(encoding='utf-8'))
registration = json.loads((ROOT / 'art/blender/city_shells_registration.json').read_text(encoding='utf-8'))
for relative, expected in plan['bindings'].items():
    if relative != CITY:
        assert source_hash(ROOT / relative) == expected, relative
for relative, expected in registration['bindings'].items():
    assert source_hash(ROOT / relative) == expected, relative
current = source_hash(ROOT / CITY)
assert registration['source_native_sha256'] == current
assert registration['source_solids'] == 335 and registration['runtime_batches'] == 84
assert abs(registration['offsets']['site_nbr_w'] + 3.2) < 1e-7
assert all(registration['offsets']['site_nw'+str(i)] == registration['offsets']['site_nbr_w'] for i in range(1, 5))
expected_retained = 900 if 'light_court_reconciliation' in plan else 899
assert len(plan['retained_solids']) == expected_retained
if expected_retained == 900:
    assert sum(r['owner'] == 'OrisonV2Blockout/F01_LIGHT_COURT_BASE/Collision' for r in plan['retained_solids']) == 1
assert not any('city' in r['owner'].lower() or r['owner'].startswith('site_') for r in plan['retained_solids'])
previous = plan['bindings'][CITY]
if 'city_registration_reconciliation' not in plan:
    assert previous == PREVIOUS_CITY
    for key in ['occupation_reservations', 'surface_exclusions']:
        assert sum(r['owner'] == 'OutsidePublicRegion/east_neighbor' for r in plan[key]) == 1
        plan[key] = [r for r in plan[key] if r['owner'] != 'OutsidePublicRegion/east_neighbor']
    plan['city_registration_reconciliation'] = {
        'evidence_class': 'INERT', 'previous_native_sha256': PREVIOUS_CITY,
        'method': 'All 899 retained geometric masks are unchanged and contain no city mass. The northwest row now shares the accepted near-neighbor registration. Remove only the prior bounded-batch neighbor exclusion; fresh exact native city undersides and fitted foundations are supplied separately by their builder.'}
else:
    assert plan['city_registration_reconciliation']['previous_native_sha256'] == PREVIOUS_CITY
    assert not any(r['owner'] == 'OutsidePublicRegion/east_neighbor' for r in plan['occupation_reservations'])
plan['bindings'][CITY] = current
plan['region'] = [-44, -16.605, 39.5, 24]
plan['method'] = 'Classified retained Orison geometry and occupied rooms, expanded to seven registered neighboring masses. Fresh native city foundation components and underside projections are added by build_orison_ground.py. Residual court drainage, farther city/street subgrade and weather closure remain open.'
PLAN.write_text(json.dumps(plan, indent=2)+'\n', encoding='utf-8', newline='\n')
print(f'Reconciled only city registration and the finite terrain envelope; {expected_retained} retained masks preserved.')
