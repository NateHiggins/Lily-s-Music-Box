"""Verify exact source additions and final retained runtime/capture receipts."""
import hashlib
import json
import re
import subprocess
import build

ROOT,OUT=build.ROOT,build.OUT
EVIDENCE=ROOT/'design/astra/evidence/v2_upper_lighting_01'

def digest(p):return hashlib.sha256(p.read_bytes()).hexdigest()

def main():
    build.build()
    protected=['game/data/building_layout.json','game/data/runtime_material_sets.json',
        'game/data/orison_v2/domestic_furniture.json','game/data/orison_v2/domestic_fittings.json',
        'game/data/orison_v2/upper_floor_programs.json',
        'game/scripts/building/orison_v2_runtime_root.gd',
        'game/scripts/building/orison_v2_household_state.gd',
        'game/scripts/building/building_root_selector.gd','game/scripts/props/light_fixture_prop.gd']
    for path in protected:
        old=subprocess.check_output(['git','show',build.BASE+':'+path],cwd=ROOT)
        assert (ROOT/path).read_bytes().replace(b'\r\n',b'\n')==old.replace(b'\r\n',b'\n'),path
    results=[]
    for stem,expected in [('runtime_final',8249),('household_state_final',57),('apartment_batch',17140)]:
        log=OUT/(stem+'.log');stderr=OUT/(stem+'.log.stderr')
        text=log.read_text(encoding='utf-8')
        verdict=re.findall(r'(\d+) checks, (\d+) failures',text)
        assert verdict==[(str(expected),'0')],(stem,verdict)
        assert stderr.read_bytes()==b'' and not re.search(r'SCRIPT ERROR|ERROR:|leaked at exit',text),stem
        results.append(dict(run=stem,checks=expected,failures=0,stdout_sha256=digest(log),stderr_sha256=digest(stderr)))
    capture=EVIDENCE/'rooms_02'
    receipt=json.loads((capture/'capture_receipt.json').read_text(encoding='utf-8-sig'))
    assert receipt['engine_exit']==0 and receipt['status']=='PASS' and receipt['actual_frames']==15
    assert (capture/'engine.log.stderr').read_bytes()==b''
    for row in receipt['files']:assert digest(capture/row['name'])==row['sha256']
    sources=[build.LAYOUT,build.LIGHTING,build.PROBES,
        'game/scripts/building/orison_v2_room_lighting.gd',
        'game/tests/orison_v2_upper_lighting_test.gd','game/tests/orison_v2_upper_lighting_shot.gd',
        'game/tests/orison_v2_household_state_test.gd','game/tests/orison_v2_apartment_batch_test.gd',
        'design/astra/work/v2_upper_lighting_01/build.py','design/astra/work/v2_upper_lighting_01/check.py',
        'design/astra/work/v2_upper_lighting_01/inspect.py']
    report=dict(status='SCOPED_RUNTIME_PASS',base=build.BASE,fixtures_added=42,switches_added=42,
        anchors_added=126,total_circuits=81,total_saved_household_controls=98,
        suites=results,checks=sum(r['checks'] for r in results),captures=15,
        source_sha256={p:digest(ROOT/p) for p in sources},protected_files=protected,
        unrelated_tracked_overlay={'game/scripts/dream/dream_exposure_field.gd':digest(ROOT/'game/scripts/dream/dream_exposure_field.gd')},
        limits='Source routes, physical targeting, circuit behavior, storey gating, saved facts and teardown checked. Five rendered viewpoints. No complete-building, played-route, full-performance or human acceptance; V1 default and S2J open.')
    (EVIDENCE/'receipt.json').write_bytes((json.dumps(report,indent=2)+'\n').encode())
    print('PASS:',report['checks'],'runtime checks; 15 verified captures; preserved original source.')

if __name__=='__main__':main()
