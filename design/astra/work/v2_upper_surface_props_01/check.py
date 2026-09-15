import json,re,hashlib,subprocess
import build
ROOT,OUT=build.ROOT,build.OUT;E=ROOT/'design/astra/evidence/v2_upper_surface_props_01'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def main():
    build.run()
    protected=['game/data/building_layout.json','game/data/runtime_material_sets.json','game/data/orison_v2_blockout.json','game/data/orison_v2/domestic_furniture.json','game/data/orison_v2/domestic_fittings.json','game/data/orison_v2/heating.json','game/data/orison_v2/household_accessories.json','game/data/orison_v2/bath_details.json','game/scripts/building/orison_v2_runtime_root.gd','game/scripts/building/building_root_selector.gd']
    for path in protected:
        old=subprocess.check_output(['git','show',build.BASE+':'+path],cwd=ROOT)
        assert (ROOT/path).read_bytes().replace(b'\r\n',b'\n')==old.replace(b'\r\n',b'\n'),path
    p=OUT/'apartment_batch_final.log';e=OUT/'apartment_batch_final.log.stderr';text=p.read_text(encoding='utf-8')
    assert re.findall(r'(\d+) checks, (\d+) failures',text)==[('18332','0')]
    assert e.read_bytes()==b'' and not re.search(r'SCRIPT ERROR|ERROR:|leaked at exit',text)
    folder=E/'surfaces_01';receipt=json.loads((folder/'capture_receipt.json').read_text(encoding='utf-8-sig'))
    assert receipt['status']=='PASS' and receipt['engine_exit']==0 and receipt['actual_frames']==14
    assert (folder/'engine.log.stderr').read_bytes()==b''
    for row in receipt['files']:assert sha(folder/row['name'])==row['sha256']
    paths=[build.TARGET,build.PROBES,'game/scripts/building/orison_v2_surface_props.gd','game/tests/orison_v2_apartment_batch_test.gd','game/tests/orison_v2_upper_surface_shot.gd','game/tests/OrisonV2UpperSurfaceShot.tscn']+['design/astra/work/v2_upper_surface_props_01/'+n for n in ['build.py','check.py','inspect.py','source_checks.json']]
    report=dict(status='SCOPED_RUNTIME_PASS',base=build.BASE,added_props=29,total_surface_props=55,checks=18332,captures=14,source_sha256={p:sha(ROOT/p) for p in paths},stdout_sha256=sha(p),stderr_sha256=sha(e),protected_files=protected,limits='Fixed dressing only; no new mechanical or saved behavior. Broader room programs, media/equipment, played routes, full performance and human acceptance remain pending. V1 default; V2 incomplete; S2J open.')
    (E/'receipt.json').write_bytes((json.dumps(report,indent=2)+'\n').encode());print('PASS: 18332 checks; 14 captures; source preservation verified.')
if __name__=='__main__':main()
