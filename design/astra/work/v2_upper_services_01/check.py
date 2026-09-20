import json,hashlib,re,subprocess
import build
ROOT,OUT=build.ROOT,build.OUT
E=ROOT/'design/astra/evidence/v2_upper_services_01'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def main():
    build.run()
    protected=['game/data/building_layout.json','game/data/runtime_material_sets.json','game/data/orison_v2/domestic_furniture.json','game/data/orison_v2/domestic_fittings.json','game/data/orison_v2/upper_floor_programs.json','game/data/orison_v2/room_lighting.json','game/scripts/building/orison_v2_runtime_root.gd','game/scripts/building/building_root_selector.gd','game/scripts/props/radiator_prop.gd','game/scripts/props/medicine_cabinet_prop.gd','game/scripts/props/toaster_prop.gd']
    for path in protected:
        old=subprocess.check_output(['git','show',build.BASE+':'+path],cwd=ROOT)
        assert (ROOT/path).read_bytes().replace(b'\r\n',b'\n')==old.replace(b'\r\n',b'\n'),path
    suites=[]
    for name,count in [('apartment_batch_final',17984),('household_state',94),('upper_kitchens',957),('upper_lighting',8249)]:
        p=OUT/(name+'.log');e=OUT/(name+'.log.stderr');text=p.read_text(encoding='utf-8')
        assert re.findall(r'(\d+) checks, (\d+) failures',text)==[(str(count),'0')],name
        assert e.read_bytes()==b'' and not re.search(r'SCRIPT ERROR|ERROR:|leaked at exit',text),name
        suites.append(dict(run=name,checks=count,stdout_sha256=sha(p),stderr_sha256=sha(e)))
    folder=E/'services_01';capture=json.loads((folder/'capture_receipt.json').read_text(encoding='utf-8-sig'))
    assert capture['status']=='PASS' and capture['engine_exit']==0 and capture['actual_frames']==34
    assert (folder/'engine.log.stderr').read_bytes()==b''
    for row in capture['files']:assert sha(folder/row['name'])==row['sha256']
    source=[build.LAYOUT,build.HEAT,build.ACCESS,build.BATH,build.PROBES]+['game/scripts/building/'+n+'.gd' for n in ['orison_v2_heating','orison_v2_household_accessories','orison_v2_household_state','orison_v2_bath_details']]+['game/tests/'+n+'.gd' for n in ['orison_v2_apartment_batch_test','orison_v2_household_state_test','orison_v2_upper_kitchen_test','orison_v2_upper_services_shot']]+['game/tests/OrisonV2UpperServicesShot.tscn']
    source+=['design/astra/work/v2_upper_services_01/'+n for n in ['build.py','check.py','inspect.py','source_checks.json','routes.json']]
    report=dict(status='SCOPED_RUNTIME_PASS',base=build.BASE,radiators_added=6,medicine_cabinets_added=6,toasters_added=4,bath_details_added=18,total_installed_radiators=12,total_heat_demands=23,total_accessories=22,total_bath_details=36,total_saved_controls=116,suites=suites,checks=sum(s['checks'] for s in suites),captures=34,source_sha256={p:sha(ROOT/p) for p in source},protected_files=protected,limits='Bounded source, physical controls, saved-state, material and fixed-view capture proof. Physical utility routing, played routes, listening, full performance and human acceptance remain open. V1 default; V2 incomplete; S2J open.')
    (E/'receipt.json').write_bytes((json.dumps(report,indent=2)+'\n').encode());print('PASS',report['checks'],'checks; 34 captures; preserved baseline source.')
if __name__=='__main__':main()
