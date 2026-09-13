"""Source roster, preservation, syntax and related category checks only."""
from pathlib import Path
import hashlib
import json
import subprocess
import sys

ROOT=Path(__file__).resolve().parents[4]
OUT=Path(__file__).resolve().parent
BASE='312c001'


def load(path):return json.loads((ROOT/path).read_text(encoding='utf-8'))


def main():
    anchors={r['id'] for r in load('game/data/orison_v2_blockout.json')['anchors']}
    furniture={r['id'] for r in load('game/data/orison_v2/domestic_furniture.json')['furniture']}
    accessories={r['id'] for r in load('game/data/orison_v2/household_accessories.json')['accessories']}
    heating={r['id'] for r in load('game/data/orison_v2/heating.json')['installed']}
    lights=load('game/data/orison_v2/room_lighting.json')
    roster=[]
    for r in lights['fixtures']:
        if r['kind']=='lamp':continue
        assert r['id'] in anchors
        assert len([s for s in lights['switches'] if s['room']==r['room']])==1
        roster.append(dict(id=r['id'],kind='light',room=r['room']))
    for unit in ['2A','2B','3A','3B','4A','4B']:
        prep=unit+'_prep_cabinet';mirror='F0'+unit[0]+'_'+unit+'_MIRROR_01'
        assert prep in furniture and prep in anchors and mirror in accessories
        roster += [dict(id=prep,kind='prep',unit=unit),dict(id=mirror,kind='mirror',unit=unit)]
        if unit!='2B':
            radiator='F0'+unit[0]+'_'+unit[1]+'_RADIATOR_01'
            assert radiator in heating and radiator in anchors
            roster.append(dict(id=radiator,kind='radiator',unit=unit))
    assert len(roster)==len({r['id'] for r in roster})==56
    assert sum(r['kind']=='light' for r in roster)==39
    assert not any(r['id']=='F02_B_RADIATOR_01' for r in roster)
    protected=['game/scripts/game/reality_game_state.gd','game/scripts/game/reality_save_storage.gd',
               'game/scripts/game/open_shift_radiator_ecosystem.gd','game/scripts/props/radiator_prop.gd',
               'game/scripts/building/switch_system.gd','game/data/building_layout.json','game/data/orison_v2_blockout.json',
               'game/scripts/building/building_root_selector.gd']
    protected += [p.relative_to(ROOT).as_posix() for p in (ROOT/'game/data/orison_v2').rglob('*.json')]
    for path in protected:
        old=subprocess.check_output(['git','show',BASE+':'+path],cwd=ROOT)
        assert (ROOT/path).read_bytes().replace(b'\r\n',b'\n')==old.replace(b'\r\n',b'\n'),('protected file changed',path)
    scripts=['game/scripts/building/orison_v2_household_state.gd',
             'game/scripts/building/orison_v2_medicine_cabinet.gd',
             'game/scripts/building/orison_v2_prep_cabinet.gd',
             'game/scripts/building/orison_v2_runtime_root.gd',
             'game/tests/orison_v2_household_state_test.gd',
             'game/tests/orison_v2_apartment_batch_test.gd']
    sys.path.insert(0,'C:/Users/nate_/AppData/Local/Temp/astra-gdscript-parser')
    from gdtoolkit.parser import parser
    for path in scripts:parser.parse((ROOT/path).read_text(encoding='utf-8'))
    results=[]
    for packet in ['v2_heating_batch_01','v2_household_accessories_01','v2_prep_cabinets_batch_01']:
        path='design/astra/work/'+packet+'/build.py'
        r=subprocess.run([sys.executable,path],cwd=ROOT,capture_output=True,text=True,encoding='utf-8')
        results.append(dict(path=path,exit=r.returncode,stdout=r.stdout,stderr=r.stderr))
        print(packet,r.returncode,flush=True)
    (OUT/'category_checks.json').write_text(json.dumps(results,indent=2)+'\n',encoding='utf-8')
    assert all(r['exit']==0 for r in results)
    result=dict(status='SOURCE_PASS_ENGINE_TESTS_PENDING',godot='NOT_RUN',base=BASE,
                roster=roster,protected_files=len(protected),syntax_parses=6,category_replays=3,
                source_hashes={p:hashlib.sha256((ROOT/p).read_bytes()).hexdigest() for p in scripts},
                limits='No engine execution or save/load behavior proved. Real disk round-trip, two world lifetimes, mid-session load/reset, malformed/unknown data, protected-save guard, quiet restore and disconnect checks are prepared in OrisonV2HouseholdStateTest.tscn.')
    (OUT/'source_checks.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8')
    print('56 source identities resolve; six syntax parses; three category replays pass')


if __name__=='__main__':main()
