"""Refresh only current passive-stock provenance after two roof wall ports."""
import argparse,copy,hashlib,json,subprocess
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
def main():
    p=argparse.ArgumentParser();p.add_argument('--base',required=True);p.add_argument('--apply',action='store_true');args=p.parse_args()
    name='game/data/orison_v2_blockout.json'
    before=subprocess.check_output(['git','show',args.base+':'+name],cwd=ROOT)
    after=(ROOT/name).read_bytes();old=json.loads(before);new=json.loads(after);expected=copy.deepcopy(old)
    ids={'ROOF_PUBLIC_CORE_LIGHT_SUPPLY_WALL_PORT','ROOF_SERVICE_CORE_LIGHT_SUPPLY_WALL_PORT'}
    added=[r for r in new['wall_service_openings'] if r['id'] in ids]
    assert len(added)==2
    expected['wall_service_openings']+=added
    assert new==expected,'Unrelated layout edit refused'
    asset='game/assets/props/domestic_objects.glb'
    assert subprocess.check_output(['git','show',args.base+':'+asset],cwd=ROOT)==(ROOT/asset).read_bytes()
    digest=lambda raw:hashlib.sha256(raw.replace(b'\r\n',b'\n')).hexdigest()
    for name in ['art/blender/domestic_objects_construction.json','game/tests/fixtures/orison_domestic_objects.json']:
        path=ROOT/name;data=json.loads(path.read_text(encoding='utf-8'))
        assert data['source_bindings']['game/data/orison_v2_blockout.json']==digest(before),'Preexisting provenance drift'
        data['source_bindings']['game/data/orison_v2_blockout.json']=digest(after)
        if args.apply:path.write_text(json.dumps(data,indent=2)+'\n',encoding='utf-8',newline='\n')
    print('Two wall ports only; unchanged native passive stock; two current provenance bindings')
if __name__=='__main__':main()
