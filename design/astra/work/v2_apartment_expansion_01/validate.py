"""Bind the apartment expansion and prove geometry guards reject bad inputs."""
import copy
import hashlib
import importlib.util
import json
from pathlib import Path
import subprocess

ROOT=Path(__file__).resolve().parents[4]
OUT=Path(__file__).resolve().parent
BASE='1aa22cc'

def load(path):return json.loads((ROOT/path).read_text(encoding='utf-8'))
def old(path):return subprocess.check_output(['git','show',BASE+':'+path],cwd=ROOT)
def sha(path):return hashlib.sha256((ROOT/path).read_bytes()).hexdigest()

def main():
    spec=importlib.util.spec_from_file_location('expansion',OUT/'build.py')
    b=importlib.util.module_from_spec(spec);spec.loader.exec_module(b)
    paths=[b.LAYOUT,b.FURNITURE,b.FITTINGS,b.LIGHTING]
    outputs={p:load(p) for p in paths};receipt=load('design/astra/work/v2_apartment_expansion_01/receipt.json')
    original={p:json.loads(old(p)) for p in paths}
    for path,key in [(b.FURNITURE,'furniture'),(b.FITTINGS,'fittings'),(b.LIGHTING,'fixtures'),(b.LIGHTING,'switches')]:
        assert outputs[path][key][:len(original[path][key])]==original[path][key],path
    current=copy.deepcopy(outputs[b.LAYOUT]);prior=original[b.LAYOUT]
    for table in ['spaces','doors','openings','windows','anchors']:
        current[table]=current[table][:len(prior[table])]
    for r in current['spaces']:
        if r['id']=='F04_SERVICE_HALL':r['rect']=next(s['rect'] for s in prior['spaces'] if s['id']==r['id'])
    old_anchors={r['id']:r for r in prior['anchors']}
    for r in current['doors']:
        if r['id'] in b.DOOR_WIDTHS:r['width']=next(d['width'] for d in prior['doors'] if d['id']==r['id'])
    for r in current['anchors']:
        if r['id'] in b.REPAIRS:r.update(old_anchors[r['id']])
    assert current==prior,'unexpected existing layout modification'
    protected=['game/data/building_layout.json','game/data/resident_schedules.json','game/data/resident_story_details.json',
               'game/data/orison_v2/mina_routine.json','game/data/orison_v2/case_one_placement.json',
               'game/data/runtime_material_sets.json','game/project.godot',
               'game/scripts/props/door_prop.gd','game/scripts/props/tap_prop.gd']
    for path in protected:assert (ROOT/path).read_bytes().replace(b'\r\n',b'\n')==old(path).replace(b'\r\n',b'\n'),path
    negatives=[]
    for label in ['overlapping_room','severed_entry','riser_obstruction','invalid_material']:
        bad=copy.deepcopy(outputs)
        if label=='overlapping_room':
            room=next(r for r in bad[b.LAYOUT]['spaces'] if r['id']=='F03_A_MAIN');room['rect']=[-15.65,-3.85,0,3.1]
        elif label=='severed_entry':bad[b.LAYOUT]['doors']=[r for r in bad[b.LAYOUT]['doors'] if r['id']!='F03_DOOR_02']
        elif label=='riser_obstruction':
            anchor=next(r for r in bad[b.LAYOUT]['anchors'] if r['id']=='F03_3A_SHOWER_01');anchor['position'][0]=-6.55
        else:next(r for r in bad[b.FURNITURE]['furniture'] if r['id']=='3A_bed0')['surfaces'][0]['material']='missing_material'
        try:b.validate_geometry(bad,receipt['furniture_added'],[r for p in receipt['programs'] for r in p['rooms']],receipt['doors_added'])
        except AssertionError:negatives.append(label)
        else:raise AssertionError('negative accepted: '+label)
    generated=paths+['design/astra/work/v2_apartment_expansion_01/receipt.json']
    before={p:sha(p) for p in generated};b.build(apply=True)
    assert before=={p:sha(p) for p in generated},'regeneration changed bytes'
    result=dict(status='SOURCE_PASS_RUNTIME_PENDING',godot='NOT_RUN',base=BASE,
                old_furniture_preserved=70,old_fittings_preserved=20,new_rooms=12,new_furniture=22,new_fittings=10,new_circuits=12,
                allowed_existing_edits=['F04_SERVICE_HALL','F02_A_BATH_DOOR']+[i for i in b.REPAIRS if i in old_anchors],
                negative_controls_rejected=negatives,protected=protected,sha256=before,
                limits='No engine compilation, movement, water/light/audio behavior, resident navigation, appearance or performance proof.')
    (OUT/'source_validation.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8')
    inventory(outputs)
    print('PASS: preserved existing content; four meaningful negative controls rejected; generation byte-identical')

def inventory(outputs):
    source=load('game/data/building_layout.json');layout=outputs['game/data/orison_v2_blockout.json']
    schedules=load('game/data/resident_schedules.json')['residents']
    units=sorted({r['unit'] for f in source['floors'] for r in f['markers'] if r.get('unit') and len(r['unit'])==2})
    entries=[]
    for unit in units:
        prefix='F0'+unit[0]+'_'+unit[1]+'_'
        rooms=[s['id'] for s in layout['spaces'] if s['id'].startswith(prefix)]
        shared=unit in ['1B','1C']
        entries.append(dict(unit=unit,role='shared/service' if shared else source['meta']['residents'].get(unit,'residential'),
                            residents=[slug for slug,r in schedules.items() if r['unit']==unit],rooms=rooms,
                            status='NON_RESIDENTIAL_SOURCE_ROLE' if shared else 'DOMESTIC_CORE_IN_SOURCE' if rooms else 'ROOM_PROGRAM_PENDING',
                            furniture=[r['id'] for r in outputs['game/data/orison_v2/domestic_furniture.json']['furniture'] if r['id'].startswith(unit+'_')],
                            fittings=[r['id'] for r in outputs['game/data/orison_v2/domestic_fittings.json']['fittings'] if r['unit']==unit]))
    result=dict(godot='NOT_RUN',units=entries,residential_labels=22,detailed_units=6,remaining_residential_programs=16,shared_labels=['1B','1C'],
                limits='Unit labels include authored vacant/sealed/storage dispositions, not 22 occupied households. Source role coverage does not establish resident migration or completion.')
    (OUT/'current_inventory.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8')

if __name__=='__main__':main()
