"""Bind retained engine output and captures; does not launch Godot."""
import hashlib
import json
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[4]
HERE = Path(__file__).resolve().parent
EVIDENCE = ROOT / 'design/astra/evidence/v2_engine_resume_01'

def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def main():
    results = []
    for stem, scene, count in [
        ('upper_floors_final', 'OrisonV2UpperFloorsTest', 666),
        ('upper_fixtures_final', 'OrisonV2UpperFixturesTest', 410),
        ('upper_furniture_final', 'OrisonV2UpperFurnitureTest', 967),
        ('household_state_final', 'OrisonV2HouseholdStateTest', 54),
        ('apartment_batch_final', 'OrisonV2ApartmentBatchTest', 10588),
    ]:
        log = HERE / (stem + '.log')
        err = HERE / (stem + '.log.stderr')
        output = log.read_text(encoding='utf-8')
        verdicts = re.findall(r'(\d+) checks, (\d+) failures', output)
        assert verdicts == [(str(count), '0')], (stem, verdicts)
        assert err.read_bytes() == b'', stem
        assert not re.search(r'SCRIPT ERROR|ERROR:|leaked at exit', output), stem
        results.append(dict(scene='res://tests/' + scene + '.tscn',
                            renderer='windowed Forward+', resolution='960x540',
                            checks=count, failures=0,
                            stdout=str(log.relative_to(ROOT)).replace('\\', '/'),
                            stdout_sha256=digest(log), stderr_sha256=digest(err)))
    capture = EVIDENCE / 'upper_apartments_01'
    captured = json.loads((capture / 'capture_receipt.json').read_text(encoding='utf-8-sig'))
    assert captured['status'] == 'PASS' and captured['engine_exit'] == 0
    assert captured['actual_frames'] == 5
    for image in captured['files']:
        assert digest(capture / image['name']) == image['sha256']
    paths = [
        'game/scripts/building/orison_v2_bath_details.gd',
        'game/scripts/building/orison_v2_domestic_doors.gd',
        'game/scripts/building/orison_v2_household_state.gd',
        'game/scripts/building/orison_v2_prep_cabinet.gd',
        'game/tests/orison_v2_apartment_batch_test.gd',
        'game/tests/orison_v2_household_state_test.gd',
        'game/tests/orison_v2_upper_apartment_shot.gd',
        'game/tests/orison_v2_upper_floors_test.gd',
        'game/tests/orison_v2_upper_fixtures_test.gd',
        'game/tests/orison_v2_upper_furniture_test.gd',
    ]
    report = dict(schema_version=1, status='SCOPED_ENGINE_CHECKS_PASS',
                  base_head='e36fbcb38cabf4df4879521099b0307f47ec24ff',
                  suites=results, checks=sum(r['checks'] for r in results),
                  capture_receipt='upper_apartments_01/capture_receipt.json',
                  final_source_sha256={p:digest(ROOT/p) for p in paths},
                  unrelated_tracked_overlay={'game/scripts/dream/dream_exposure_field.gd':
                      digest(ROOT/'game/scripts/dream/dream_exposure_field.gd')},
                  limits='Bounded composition, interaction, save and teardown checks; five fixed-viewpoint captures. No played traversal, performance, listening, human acceptance or V2 completion claim. V1 remains default; S2J open.')
    (EVIDENCE/'receipt.json').write_bytes((json.dumps(report,indent=2)+'\n').encode())
    print(f"PASS: {report['checks']} engine checks and five hashed captures")

if __name__ == '__main__':
    main()
