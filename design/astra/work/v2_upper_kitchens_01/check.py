"""Replay source checks and bind retained engine evidence; does not launch Godot."""
import hashlib
import json
import re
import subprocess
import build
ROOT,OUT=build.ROOT,build.OUT
EVIDENCE=ROOT/'design/astra/evidence/v2_upper_kitchens_01'
def digest(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def main():
    build.run()
    protected=['game/data/building_layout.json','game/data/runtime_material_sets.json',
        'game/data/orison_v2/domestic_fittings.json','game/data/orison_v2/upper_floor_programs.json',
        'game/data/orison_v2/room_lighting.json','game/scripts/building/orison_v2_runtime_root.gd',
        'game/scripts/building/orison_v2_prep_cabinet.gd','game/scripts/building/building_root_selector.gd',
        'game/scripts/building/orison_v2_room_lighting.gd']
    for path in protected:
        old=subprocess.check_output(['git','show',build.BASE+':'+path],cwd=ROOT)
        assert (ROOT/path).read_bytes().replace(b'\r\n',b'\n')==old.replace(b'\r\n',b'\n'),path
    suites=[]
    for stem,expected in [('runtime_final',829),('household_state',76),('upper_lighting',8249),('apartment_batch',17272)]:
        log=OUT/(stem+'.log');stderr=OUT/(stem+'.log.stderr');text=log.read_text(encoding='utf-8')
        verdict=re.findall(r'(\d+) checks, (\d+) failures',text)
        assert verdict==[(str(expected),'0')],(stem,verdict)
        assert stderr.read_bytes()==b'' and not re.search(r'SCRIPT ERROR|ERROR:|leaked at exit',text),stem
        suites.append(dict(run=stem,checks=expected,failures=0,stdout_sha256=digest(log),stderr_sha256=digest(stderr)))
    capture=EVIDENCE/'kitchens_01'
    receipt=json.loads((capture/'capture_receipt.json').read_text(encoding='utf-8-sig'))
    assert receipt['engine_exit']==0 and receipt['status']=='PASS' and receipt['actual_frames']==12
    assert (capture/'engine.log.stderr').read_bytes()==b''
    for row in receipt['files']:assert digest(capture/row['name'])==row['sha256']
    sources=[build.LAYOUT,build.FURNITURE,build.PROBES,build.LIGHT_PROBES,
        'game/scripts/building/orison_v2_domestic_furniture.gd','game/scripts/building/orison_v2_household_state.gd',
        'game/tests/orison_v2_household_state_test.gd','game/tests/orison_v2_apartment_batch_test.gd',
        'game/tests/orison_v2_upper_kitchen_test.gd','game/tests/orison_v2_upper_kitchen_shot.gd',
        'game/tests/OrisonV2UpperKitchenTest.tscn','game/tests/OrisonV2UpperKitchenShot.tscn']
    sources += ['design/astra/work/v2_upper_kitchens_01/'+name for name in ['build.py','check.py','inspect.py','routes.json','source_checks.json']]
    report=dict(status='SCOPED_RUNTIME_PASS',base=build.BASE,new_preparation_cabinets=6,new_wall_cupboards=6,
        new_anchors=18,relocated_anchors=6,total_furniture=169,total_saved_household_controls=104,
        source_triangles=864,native_panel_triangles=288,suites=suites,checks=sum(r['checks'] for r in suites),
        captures=12,source_sha256={p:digest(ROOT/p) for p in sources},protected_files=protected,
        unrelated_tracked_overlay={'game/scripts/dream/dream_exposure_field.gd':digest(ROOT/'game/scripts/dream/dream_exposure_field.gd')},
        limits='Source geometry and appliance sweeps, 134 standing approaches, cabinet and sink rays, 42 light controls, saved state and teardown verified. Twelve fixed viewpoints. No continuous played route, complete building, full performance or human acceptance; V1 default and S2J open.')
    (EVIDENCE/'receipt.json').write_bytes((json.dumps(report,indent=2)+'\n').encode())
    print('PASS:',report['checks'],'runtime checks; 12 captures; source preservation verified.')
if __name__=='__main__':main()
