"""Synthetic anatomy motion-policy controls. No saved sources or production assets."""
import argparse,importlib.util,json,math,sys
from pathlib import Path
import bpy
from mathutils import Vector

def load(path,name):
    spec=importlib.util.spec_from_file_location(name,path);m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m);return m

def run(checker,fixtures,case):
    c,objects=fixtures.fixture('valid_attached')
    profile={'bac':'bacillaria_raphe_slide','mes':'mesodinium_archipelago','noct':'noctiluca_flash','eup':'euplotes_cirral_walk','eug':'euglena_metaboly','listener':'crystal_listener_spin'}[case.split('_')[0]]
    c['species_id']={'bacillaria_raphe_slide':13,'mesodinium_archipelago':15,'noctiluca_flash':12,'euplotes_cirral_walk':7,'euglena_metaboly':10,'crystal_listener_spin':1}[profile]
    c['species_name']=checker.NAMES[c['species_id']];c['provenance']={'motion_profile':profile}
    names=['law_half' if i==8 else 'law_full' if i==16 else 'law_%02d'%i for i in range(1,17)]+['gait_a','gait_b']
    for obj in objects.values():
        rest=[p.co.copy() for p in obj.data.shape_keys.key_blocks['Basis'].data]
        for i,name in enumerate(names):
            key=obj.data.shape_keys.key_blocks.get(name) or obj.shape_key_add(name=name)
            t=(i+1)/16 if i<16 else 0.
            delta=Vector((.05*math.sin(math.tau*t),.05*(1-math.cos(math.tau*t)),0)) if i<16 else Vector((0,0,-.03 if i==16 else .03))
            if i==15 or (profile in ('bacillaria_raphe_slide','euplotes_cirral_walk','euglena_metaboly') and i>=16) or (profile=='noctiluca_flash' and i<16): delta=Vector()
            if case.endswith('broken_endpoint') and i==15: delta=Vector((.01,0,0))
            if case.endswith('inert_interior') and i==7: delta=Vector()
            if case.endswith('active_unused_phase') and i==16: delta=Vector((0,0,.01))
            if case in ('mes_inert_phase','noct_inert_phase','listener_inert_phase') and i==16: delta=Vector()
            if case=='noct_moving_law' and i==4: delta=Vector((.01,0,0))
            for vertex,point in zip(key.data,rest): vertex.co=point+delta
    c['poses']=[{'name':'neutral','shape_keys':{},'bones':{}}]+[{'name':name,'shape_keys':{obj:{name:1} for obj in objects},'bones':{}} for name in names]
    if case.endswith('missing_full'): c['poses']=[p for p in c['poses'] if p['name']!='law_full']
    if case.endswith('wrong_species'): c['species_id']=0;c['species_name']='seam_grazer'
    try:
        bpy.context.scene['dream_critter_contract']=json.dumps(c)
        c=checker.read_contract(bpy.context.scene)
        result=checker.validate_loaded(c,objects,None)
        return {'accepted':result['failures']==0,'checks':len(result['checks']),'failures':[x['check'] for x in result['checks'] if not x['passed']]}
    except Exception as e: return {'accepted':False,'error':type(e).__name__+': '+str(e)}

def main():
    p=argparse.ArgumentParser(allow_abbrev=False);p.add_argument('--before',required=True,type=Path);p.add_argument('--after',required=True,type=Path);p.add_argument('--fixtures',required=True,type=Path);p.add_argument('--out',required=True,type=Path)
    a=p.parse_args(sys.argv[sys.argv.index('--')+1:]);old=load(a.before,'old');new=load(a.after,'new');f=load(a.fixtures,'fixtures')
    positive=['listener_valid','bac_valid','mes_valid','noct_valid','eup_valid','eug_valid']
    negative=['listener_broken_endpoint','listener_inert_interior','listener_inert_phase','listener_missing_full','listener_wrong_species','bac_broken_endpoint','bac_inert_interior','bac_active_unused_phase','bac_missing_full','bac_wrong_species','mes_broken_endpoint','mes_inert_phase','mes_missing_full','noct_moving_law','noct_inert_phase','noct_missing_full','noct_wrong_species','eup_broken_endpoint','eup_inert_interior','eup_active_unused_phase','eup_missing_full','eug_broken_endpoint','eug_inert_interior','eug_active_unused_phase','eug_wrong_species']
    rows=[]
    for case in positive+negative:
        row={'case':case,'expected_accept':case in positive,'before':run(old,f,case),'after':run(new,f,case)};row['matches_expectation']=row['after']['accepted']==row['expected_accept'];rows.append(row)
    result={'schema':'dream_motion_policy_controls.v1','evidence_class':'INERT','before_sha256':new.sha256(a.before),'after_sha256':new.sha256(a.after),'controls':rows,'all_expected':all(r['matches_expectation'] for r in rows)}
    new.write_report(a.out,result);print('[MOTION POLICY]',len(rows),'PASS' if result['all_expected'] else 'FAIL');return 0 if result['all_expected'] else 1

if __name__=='__main__':raise SystemExit(main())
