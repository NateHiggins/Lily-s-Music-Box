"""Reproduce minimal curtain intake from exact native and original finish inputs."""
from pathlib import Path
import argparse,hashlib,json,math
from prepare_arcade_native_projection import NativeGLB
from prepare_arcade_door_intake import _verify_sources

ROOT=Path(__file__).resolve().parents[1]
PROOF=Path('game/tests/fixtures/arcade_darkroom_curtain_native.json')
OUTPUT=Path('game/data/orison_v2/arcade_darkroom_curtain.json')
ASSET='res://assets/props/arcade_darkroom_curtain.glb'
SOURCE='res://data/orison_v2/photo_radio_fittings.json'

def need(ok,message):
    if not ok:raise ValueError(message)

def build(root=ROOT,proof=None):
    root=Path(root)
    if proof is None:proof=json.loads((root/PROOF).read_text(encoding='utf-8'))
    need(proof.get('schema')=='orison.v2.arcade-darkroom-curtain.v1','native curtain schema')
    _verify_sources(root,proof)
    path=root/'game'/ASSET[6:]
    need(proof.get('asset')==ASSET and hashlib.sha256(path.read_bytes()).hexdigest()==proof.get('asset_sha256'),'native curtain payload changed')
    native=root/'art/blender/arcade_darkroom_curtain.blend'
    need(native.is_file() and hashlib.sha256(native.read_bytes()).hexdigest()==proof.get('native_sha256'),'editable curtain native source changed')
    glb=NativeGLB(path);parts=proof.get('parts')
    need(isinstance(parts,list) and len(parts)==1 and parts[0]==dict(name='LeftDarkroomCurtain',triangles=1288,material_key='fabric_warm'),'one registered curtain draw required')
    need(set(glb.names)=={'LeftDarkroomCurtain'} and glb.triangles('LeftDarkroomCurtain')==1288,'actual curtain triangle inventory changed')
    need(glb.transform(glb.names['LeftDarkroomCurtain'])==[[1,0,0,0],[0,1,0,0],[0,0,1,0],[0,0,0,1]],'curtain local hinge frame changed')
    source=root/'game'/SOURCE[6:];data=json.loads(source.read_text(encoding='utf-8'))
    original=[r for c in data['cells'] if c['id']=='shop_photo_supplies' for r in c['parts'] if r['name'].startswith('storm_shop_photo_supplies_dr_door__')]
    need(proof.get('original_parts')==original and len(original)==3,'original curtain material lineage changed')
    stocks=proof.get('stocks',[]);need(len(stocks)==2 and {s.get('name') for s in stocks}=={'PhotoDarkroomCurtain0','PhotoDarkroomCurtain1'} and all(s.get('triangles')==644 for s in stocks),'two closed cloth stocks required')
    for s in stocks:
        need(all(isinstance(s.get(k),list) and len(s[k])==3 and all(type(v) in (int,float) and math.isfinite(v) for v in s[k]) for k in ['low','high']) and type(s.get('closed_volume_m3')) in (int,float) and math.isfinite(s['closed_volume_m3']),'finite curtain stock witness required')
        need(all(lo<=a<=b<=hi for a,b,lo,hi in zip(s['low'],s['high'],[.13,.85,-.022],[.87,2.18,.022])) and s['closed_volume_m3']>0,'curtain outside existing leaf envelope')
    imported=(root/'game'/ASSET[6:]).with_suffix('.glb.import').read_bytes().replace(b'\r\n',b'\n')
    need(b'\nmeshes/force_disable_compression=true\n' in imported,'authored curtain import precision required')
    return dict(schema=proof['schema'],asset=ASSET,asset_sha256=proof['asset_sha256'],import_sha256_lf=hashlib.sha256(imported).hexdigest(),
                source_sha256_lf=hashlib.sha256(source.read_bytes().replace(b'\r\n',b'\n')).hexdigest())

def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--check',action='store_true');args=p.parse_args()
    text=json.dumps(build(),indent=2)+'\n'
    if args.check:need((ROOT/OUTPUT).read_text(encoding='utf-8')==text,'curtain intake stale')
    else:(ROOT/OUTPUT).write_text(text,encoding='utf-8',newline='\n')
    print('ARCADE_DARKROOM_CURTAIN_INTAKE_PASS original material lineage/2stocks/1draw')

if __name__=='__main__':main()
