"""Preservation, material, regeneration and rejection checks without Godot."""
import copy
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import build as batch

ROOT=batch.ROOT
OUT=batch.OUT
BASE=batch.BASE
DATA=['game/data/orison_v2/domestic_furniture.json','game/data/orison_v2/domestic_surface_props.json',
      'game/data/orison_v2/domestic_radios.json','game/data/orison_v2_blockout.json',
      'art/data/runtime_material_sets.json','game/data/runtime_material_sets.json','game/scripts/generated/material_sets.gd']

def old(path):return subprocess.check_output(['git','show',BASE+':'+path],cwd=ROOT)
def sha(path):return hashlib.sha256((ROOT/path).read_bytes()).hexdigest()
def rejects(label,call):
    try:call()
    except AssertionError:return label
    raise AssertionError('bad candidate accepted: '+label)

def main():
    for path,key in [(DATA[0],'furniture'),(DATA[1],'props'),(DATA[2],'receivers'),(DATA[3],'anchors')]:
        prior=json.loads(old(path));current=batch.load(path)
        assert current[key][:len(prior[key])]==prior[key],path
        if key=='anchors':
            current[key]=current[key][:len(prior[key])];assert current==prior,'unexpected layout edits'
    for path in DATA[4:6]:
        prior=json.loads(old(path));current=batch.load(path)
        assert set(current['materials'])-set(prior['materials'])=={'terracotta','soil'}
        for key,value in prior['materials'].items():assert current['materials'][key]==value,key
        assert current['visual_locks']==prior['visual_locks']
    protected=['game/data/building_layout.json','game/data/domestic_radios.json','game/data/resident_schedules.json',
               'game/data/orison_v2/domestic_fittings.json','game/data/orison_v2/room_lighting.json',
               'game/scripts/props/domestic_radio_prop.gd','game/scripts/material_library.gd','game/project.godot']
    for path in protected:assert (ROOT/path).read_bytes().replace(b'\r\n',b'\n')==old(path).replace(b'\r\n',b'\n'),path
    materials=batch.module('art/tools/generate_runtime_materials.py','household_materials')
    assert materials.validate(materials.build_contract())==[]
    layout=batch.load(DATA[3]);rows=batch.load(DATA[0])['furniture'];record=next(r for r in rows if r['kind']=='plant')
    bad=copy.deepcopy(layout)
    next(a for a in bad['anchors'] if a['id']==record['id'])['position']=[-6.2,0,4.5]
    negatives=[rejects('plant_in_service_riser',lambda:batch.check(bad,rows,record))]
    surface=batch.module('design/astra/work/v2_surface_props_batch_01/build.py','household_surface_negative')
    surface.PLACEMENTS=copy.deepcopy(surface.PLACEMENTS)
    next(r for r in surface.PLACEMENTS if r[0]=='3A_story_cuttings')[3][1]+=.1
    negatives.append(rejects('floating_propagation_bottles',lambda:surface.build()))
    radio=batch.module('design/astra/work/v2_household_radios_batch_01/build.py','household_radio_negative')
    real_load=radio.load
    profiles=batch.load('game/data/domestic_radios.json')
    next(p for p in profiles['profiles'] if p['unit']=='3A')['speaker']='cone'
    radio.load=lambda path:profiles if path=='game/data/domestic_radios.json' else real_load(path)
    negatives.append(rejects('crystal_speaker_substitution',lambda:radio.build()))
    # Also protect already authored operating stances from the new supports.
    geo=batch.module('design/astra/work/v2_storage_tables_boards_batch_01/build.py','household_stances')
    door=batch.module('design/astra/work/v2_apartment_doors_batch_01/check.py','household_stance_distance')
    anchors={a['id']:a for a in layout['anchors']};stance_checks=0
    for identity in ['3A_wireless_table','4A_wireless_table','3A_story_specimen']:
        r=next(r for r in rows if r['id']==identity);a=anchors[identity];b=geo.volume(r['bounds'],a)
        for stance in layout['anchors']:
            if stance['level']!=a['level'] or stance.get('kind')!='clearance':continue
            assert door.distance([stance['position'][0],stance['position'][2]],door.rect_polygon([b[0],b[2],b[3],b[5]]))>=.38,(identity,stance['id'])
            stance_checks+=1
    before={p:sha(p) for p in DATA}
    for name in ['v2_household_radios_batch_01','v2_surface_props_batch_01','v2_household_completion_01']:
        subprocess.run([sys.executable,str(ROOT/'design/astra/work'/name/'build.py'),'--apply'],cwd=ROOT,check=True,capture_output=True)
    assert before=={p:sha(p) for p in DATA},'regeneration changed production bytes'
    category_results=[]
    for name,script in [('apartment_batches','build'),('apartment_seating_batch','build'),('apartment_lighting_batch','build'),
                        ('apartment_doors_batch','check'),('apartment_walls_batch','build'),('surface_props_batch','build'),
                        ('storage_tables_boards_batch','build'),('household_radios_batch','build'),('prep_cabinets_batch','build'),
                        ('specialist_devices_batch','build'),('projectors_batch','build')]:
        path='design/astra/work/v2_'+name+'_01/'+script+'.py'
        run=subprocess.run([sys.executable,str(ROOT/path)],cwd=ROOT,text=True,capture_output=True)
        category_results.append(dict(script=path,exit_code=run.returncode,stdout=run.stdout,stderr=run.stderr))
    (OUT/'category_checks.json').write_text(json.dumps(category_results,indent=2)+'\n')
    assert all(r['exit_code']==0 for r in category_results),'category failure; see category_checks.json'
    result=dict(status='SOURCE_PASS_RUNTIME_PENDING',godot='NOT_RUN',base=BASE,sha256=before,protected=protected,
                old_furniture_preserved=92,old_surface_props_preserved=19,old_radios_preserved=4,
                negative_controls_rejected=negatives,old_and_new_stances_checked=stance_checks,
                categories_passed=len(category_results),regeneration='BYTE_IDENTICAL',materials='53 entries, 51 old entries and all visual locks preserved',
                limits='Static geometry and source contract checks only; no engine compilation, physical interaction, audio perception, performance or visual acceptance.')
    (OUT/'source_validation.json').write_text(json.dumps(result,indent=2)+'\n')
    inventory=batch.load('design/astra/work/v2_apartment_expansion_01/current_inventory.json')
    for entry in inventory['units']:
        unit=entry['unit']
        entry['furniture']=[r['id'] for r in rows if r['id'].startswith(unit+'_')]
        entry['surface_props']=[r['id'] for r in batch.load(DATA[1])['props'] if r['unit']==unit]
        entry['receivers']=[r['id'] for r in batch.load(DATA[2])['receivers'] if r['unit']==unit]
    inventory['batch']='v2_household_completion_01'
    inventory['totals']=dict(furniture=95,surface_props=26,household_receivers=6)
    (OUT/'current_inventory.json').write_text(json.dumps(inventory,indent=2)+'\n')
    print('PASS: preserved existing content, three negative controls rejected, byte-identical regeneration and eleven category checks')

if __name__=='__main__':main()
