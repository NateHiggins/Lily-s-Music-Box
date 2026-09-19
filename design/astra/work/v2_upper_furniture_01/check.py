"""Geometry, original-record preservation, material and source integration gates."""
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
    outputs,new,targets=build.make()
    materials=build.load('game/data/runtime_material_sets.json')['materials']
    aliases={'floor_oak':'oak_quartered','fabric_cool':'linen','fabric_green':'linen'}
    for path,key in [(build.LAYOUT,'anchors'),(build.FURNITURE,'furniture')]:
        assert build.load(path)==outputs[path],path
        old=build.baseline(path);current=copy.deepcopy(outputs[path])
        assert current[key][:len(old[key])]==old[key],('old record changed',path)
        assert len(current[key])==len({r['id'] for r in current[key]}),path
        current[key]=old[key];assert current==old,('non-category property changed',path)
    for record in new:
        for surface in record['surfaces']:
            assert surface['material']=='glassish' or aliases.get(surface['material'],surface['material']) in materials
            assert len(surface['vertices'])==len(surface['normals']) and len(surface['vertices'])%9==0
            assert all(math.isfinite(v) for v in surface['vertices']+surface['normals'])
        for box in record.get('collision_boxes',[]):
            assert all(record['bounds'][0][i]<=box[0][i]<box[1][i]<=record['bounds'][1][i] for i in range(3))
    rejected=[]
    for mutation in ['outside_room','bed_collision','unreachable_stance','wardrobe_swing']:
        bad=copy.deepcopy(outputs);poses=copy.deepcopy(targets)
        anchors={a['id']:a for a in bad[build.LAYOUT]['anchors']}
        if mutation=='outside_room':anchors['5A_bed0']['position'][0]=-16
        elif mutation=='bed_collision':anchors['5A_bed0_ns']['position']=anchors['5A_bed0']['position'][:]
        elif mutation=='unreachable_stance':next(t for t in poses if t['id']=='5A_bed0')['point']=[-14.3,-10.8]
        else:next(t for t in poses if t['id']=='5A_w0_wardrobe')['point']=[-12.5,-8.6]
        try:build.validate(bad,new,poses)
        except AssertionError as e:rejected.append(dict(mutation=mutation,rejection=str(e)))
        else:raise AssertionError('negative control accepted: '+mutation)
    assert 'wardrobe motion hits stance' in rejected[-1]['rejection'],rejected[-1]
    protected=['game/data/building_layout.json','game/data/runtime_material_sets.json',
               'game/data/orison_v2/domestic_fittings.json','game/data/orison_v2/upper_floor_programs.json',
               'game/scripts/building/orison_v2_runtime_root.gd','game/scripts/building/orison_v2_domestic_furniture.gd',
               'game/scripts/building/orison_v2_household_state.gd','game/scripts/building/building_root_selector.gd',
               'game/scripts/props/baked_furniture_interaction.gd']
    for path in protected:
        old=subprocess.check_output(['git','show',build.BASE+':'+path],cwd=ROOT)
        assert (ROOT/path).read_bytes().replace(b'\r\n',b'\n')==old.replace(b'\r\n',b'\n'),path
    sys.path.insert(0,'C:/Users/nate_/AppData/Local/Temp/astra-gdscript-parser')
    from gdtoolkit.parser import parser
    scripts=['game/tests/orison_v2_upper_furniture_test.gd','game/tests/orison_v2_upper_floors_test.gd',
             'game/tests/orison_v2_upper_fixtures_test.gd','game/scripts/building/orison_v2_domestic_furniture.gd']
    for path in scripts:parser.parse((ROOT/path).read_text(encoding='utf-8'))
    persistence=build.module('design/astra/work/v2_household_persistence_01/check.py','upper_furniture_persistence')
    persistence.OUT=OUT/'persistence_regression';persistence.OUT.mkdir(exist_ok=True);persistence.main()
    bath=build.module('design/astra/work/v2_bath_details_01/build.py','upper_furniture_bath');bath.build()
    audit=subprocess.run([sys.executable,'tools/audit_orison_v2_completeness.py','--floor','F05','--floor','F06','--json'],cwd=ROOT,capture_output=True,text=True,encoding='utf-8')
    assert audit.returncode in [0,1,2] and 'summary' in json.loads(audit.stdout)
    (OUT/'completeness.json').write_bytes(audit.stdout.encode('utf-8'))
    (OUT/'completeness.stderr.txt').write_bytes(audit.stderr.encode('utf-8'))
    build.write(OUT/'source_checks.json',dict(status='SOURCE_PASS_RUNTIME_PENDING',godot='NOT_RUN',negative_controls=rejected,
                syntax_parses=len(scripts),protected_files=len(protected),completeness_exit=audit.returncode,
                source_hashes={p:hashlib.sha256((ROOT/p).read_bytes()).hexdigest() for p in scripts+protected}))
    print('Furniture source checks, four rejecting controls and related category regressions passed; completeness exit:',audit.returncode)

if __name__=='__main__':main()
