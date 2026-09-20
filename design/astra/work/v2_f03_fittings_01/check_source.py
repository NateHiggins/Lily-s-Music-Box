"""Source checks, not executed appliance behavior or moving-leaf clearance."""
import hashlib
import itertools
import json
from pathlib import Path
import subprocess
import sys

ROOT=Path(__file__).resolve().parents[4]
OUT=Path(__file__).parent
BASE='5ecd79c938fbbab8b8143e22204eb9a4527e923a'
def read(p): return json.loads((ROOT/p).read_text(encoding='utf-8'))
layout=read('game/data/orison_v2_blockout.json')
records=read('game/data/orison_v2/domestic_fittings.json')['fittings']
placements=read('design/astra/work/v2_f03_fittings_01/placements.json')
old=json.loads(subprocess.check_output(['git','show',BASE+':game/data/orison_v2_blockout.json'],cwd=ROOT))
assert len({r['id'] for r in records})==len(records)==5
legacy=read('game/data/building_layout.json')
markers={m['id']:m for f in legacy['floors'] for m in f['markers']}
field_map={'compact_kitchen':'compact','has_drainboard':'drainboard','monitor_top':'monitor'}
for record in records:
    marker=markers[record['id']]
    assert record['kind']==marker['kind'] and record['unit']==marker['unit']
    for key,value in record['properties'].items():
        assert value==marker[field_map.get(key,key)], (record['id'],key)
new_ids={r['id'] for r in records}
for table in old:
    if table in ['anchors','capsule_stations']:
        assert layout[table][:len(old[table])]==old[table]
    elif table=='envelopes':
        for prior,current in zip(old[table],layout[table]):
            if prior['id']=='F03_B_KITCHEN_WORK_AISLE':
                assert current['rect']==[9.8,-7.5,12.75,-6.35]
            else: assert prior==current
    else: assert old[table]==layout[table],table
assert len(layout['anchors'])-len(old['anchors'])==10
assert len(layout['capsule_stations'])-len(old['capsule_stations'])==5
anchors={r['id']:r for r in layout['anchors']}
stations={r['id']:r for r in layout['capsule_stations']}
spaces={r['id']:r for r in layout['spaces']}
assert {p['id'] for p in placements} == new_ids and len(placements)==5
for placement in placements:
    ident=placement['id']; assert ident in new_ids
    room=spaces[placement['space']]['rect']; box=placement['closed_footprint']
    assert room[0]+.07<=box[0]<box[2]<=room[2]-.07
    assert room[1]+.07<=box[1]<box[3]<=room[3]-.07
    assert anchors[ident]['space']==placement['space']
    assert anchors[ident]['position']==placement['position'] and anchors[ident]['yaw']==placement['yaw']
    assert anchors[ident]['level']=='F03'
    stance_anchor=anchors[ident+'_STANCE']
    assert stance_anchor['position']==placement['stance'] and stance_anchor['space']==placement['space']
    assert stance_anchor['yaw']==placement['yaw']+3.141592653589793
    x,_,z=placement['stance']
    assert stations[ident+'_CAPSULE']==dict(id=ident+'_CAPSULE',level='F03',position=[x,.85,z])
    assert room[0]+.40<=x<=room[2]-.40 and room[1]+.40<=z<=room[3]-.40
    for body in placements:
        r=body['closed_footprint']; dx=max(r[0]-x,0,x-r[2]); dz=max(r[1]-z,0,z-r[3])
        assert dx*dx+dz*dz>=.33**2,(ident,body['id'])
for a,b in itertools.combinations(placements,2):
    ar,br=a['closed_footprint'],b['closed_footprint']
    assert min(ar[2],br[2])<=max(ar[0],br[0]) or min(ar[3],br[3])<=max(ar[1],br[1]),(a['id'],b['id'])
# Preserve the graph's distinction: the four water/gas fittings have no node.
acoustics={n['id'] for n in read('game/data/acoustic_graph.json')['nodes']}
assert new_ids & acoustics == {'F03_3B_FRIDGE_01'}
paths=['game/data/orison_v2_blockout.json','game/data/orison_v2/domestic_fittings.json',
       'game/scripts/building/orison_v2_domestic_fittings.gd','game/scripts/building/orison_v2_runtime_root.gd',
       'game/tests/orison_v2_connected_world_test.gd']
sys.path.insert(0,'C:/Users/nate_/.cache/orison-source-tools/gdtoolkit')
from gdtoolkit.parser import parser
for path in paths:
    if path.endswith('.gd'): parser.parse((ROOT/path).read_text(encoding='utf-8'))
protected=['game/scripts/building/building_root_selector.gd','game/scripts/building/building_root.gd',
           'game/data/building_layout.json','art/data/building_layout.json','game/data/acoustic_graph.json']
protected += [f'game/assets/building/floor_{f}.{e}' for f in ['01','02','03','04','05','06','b1'] for e in ['gltf','bin']]
subprocess.run(['git','diff','--exit-code',BASE,'--',*protected],cwd=ROOT,check=True)
receipt={'status':'SOURCE_CHECKS_PASS_NATIVE_UNRUN','base_head':BASE,'native_godot_started':False,
 'appliances':len(records),'checks':['original marker identities and settings','named anchor containment','closed footprints separated',
 'standing capsules clear of closed footprints','finished wall clearance','existing acoustic identities','older layout records preserved except named aisle','GDScript syntax'],
 'limits':'Declared footprints are conservative source estimates. Native mesh bounds, moving mechanisms, ray targeting, save/reconstruction and visual acceptance remain untested.',
 'files':{p:hashlib.sha256((ROOT/p).read_bytes()).hexdigest() for p in paths}}
(OUT/'source_checks.json').write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf-8',newline='\n')
print(json.dumps(receipt,indent=2))
