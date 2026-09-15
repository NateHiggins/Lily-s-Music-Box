"""Current batch source regressions and explicit negative controls; no Godot."""
import copy
import hashlib
import json
import math
import subprocess
import sys
import build

ROOT,OUT=build.ROOT,build.OUT

def main():
    build.run()
    outputs,records,targets=build.make()
    for path,expected in outputs.items():assert build.load(path)==expected,path
    for path,key in [(build.LAYOUT,'anchors'),(build.FURNITURE,'furniture'),(build.FITTINGS,'fittings')]:
        rows=outputs[path][key];assert len(rows)==len({r['id'] for r in rows}),path
    sets=build.load('game/data/runtime_material_sets.json')['materials']
    triangles=0
    for r in records:
        if 'surfaces' not in r:continue
        for s in r['surfaces']:
            assert s['material'] in sets
            assert len(s['vertices'])==len(s['normals']) and len(s['vertices'])%9==0
            assert all(math.isfinite(v) for v in s['vertices']+s['normals'])
            triangles+=len(s['vertices'])//9
    # Reject regressions in fit, approach and the new appliance motion gate.
    failures=[]
    for name in ['outside_room','overlap','blocked_stance','swept_stance']:
        bad=copy.deepcopy(outputs);bad_targets=copy.deepcopy(targets)
        anchors={r['id']:r for r in bad[build.LAYOUT]['anchors']}
        if name=='outside_room':anchors['5A_wc']['position'][0]=-5.3
        elif name=='overlap':anchors['5A_wc']['position']=anchors['F05_5A_SHOWER_01']['position'][:]
        elif name=='blocked_stance':next(t for t in bad_targets if t['id']=='5A_wc')['point']=[-6.18,-11.85]
        else:next(t for t in bad_targets if t['id']=='F05_5A_FRIDGE_01')['point']=[-9.7,-8.4]
        try:build.validate(bad,records,bad_targets)
        except AssertionError as e:failures.append(dict(mutation=name,rejection=str(e)))
        else:raise AssertionError('negative control accepted: '+name)
    assert 'appliance swing hits stance' in failures[-1]['rejection'],failures[-1]
    protected=['game/data/building_layout.json','game/data/runtime_material_sets.json',build.PROGRAM,
               'game/scripts/building/orison_v2_domestic_fittings.gd','game/scripts/building/orison_v2_domestic_furniture.gd',
               'game/scripts/building/orison_v2_runtime_root.gd','game/scripts/building/orison_v2_household_state.gd',
               'game/scripts/building/building_root_selector.gd','game/scripts/props/fridge_prop.gd',
               'game/scripts/props/stove_prop.gd','game/scripts/props/tap_prop.gd']
    for path in protected:
        old=subprocess.check_output(['git','show',build.BASE+':'+path],cwd=ROOT)
        assert (ROOT/path).read_bytes().replace(b'\r\n',b'\n')==old.replace(b'\r\n',b'\n'),path
    sys.path.insert(0,'C:/Users/nate_/AppData/Local/Temp/astra-gdscript-parser')
    from gdtoolkit.parser import parser
    scripts=['game/tests/orison_v2_upper_fixtures_test.gd','game/tests/orison_v2_upper_floors_test.gd',
             'game/scripts/building/orison_v2_domestic_fittings.gd','game/scripts/building/orison_v2_domestic_furniture.gd']
    for path in scripts:parser.parse((ROOT/path).read_text(encoding='utf-8'))
    previous=build.module('design/astra/work/v2_household_persistence_01/check.py','upper_fixture_persistence')
    previous.OUT=OUT/'persistence_regression';previous.OUT.mkdir(exist_ok=True);previous.main()
    bath=build.module('design/astra/work/v2_bath_details_01/build.py','upper_fixture_bath');bath.build()
    audit=subprocess.run([sys.executable,'tools/audit_orison_v2_completeness.py','--floor','F05','--floor','F06','--json'],cwd=ROOT,capture_output=True,text=True,encoding='utf-8')
    assert audit.returncode in [0,1,2] and 'summary' in json.loads(audit.stdout)
    (OUT/'completeness.json').write_bytes(audit.stdout.encode('utf-8'))
    (OUT/'completeness.stderr.txt').write_bytes(audit.stderr.encode('utf-8'))
    result=dict(status='SOURCE_PASS_RUNTIME_PENDING',godot='NOT_RUN',negative_controls=failures,
                new_furniture_triangles=triangles,syntax_parses=len(scripts),protected_files=len(protected),
                completeness_exit=audit.returncode,related_categories=['56-control persistence','heating','accessories','prep cabinets','bath details'],
                source_hashes={p:hashlib.sha256((ROOT/p).read_bytes()).hexdigest() for p in scripts+protected})
    build.write(OUT/'source_checks.json',result)
    print('Four negative controls, four syntax parses, category regressions passed; completeness exit:',audit.returncode)

if __name__=='__main__':main()
