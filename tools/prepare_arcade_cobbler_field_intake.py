"""Compile the fitted supporting field after its native asset is deliberately admitted."""
from pathlib import Path
import argparse,hashlib,importlib.util,json
from prepare_arcade_native_projection import NativeGLB
from prepare_arcade_door_intake import _verify_sources

ROOT=Path(__file__).resolve().parents[1]
PROOF=Path('game/tests/fixtures/arcade_cobbler_field_native.json')
OUTPUT=Path('game/data/orison_v2/arcade_cobbler_field.json')
ASSET='res://assets/props/arcade_cobbler_field.glb'

def need(ok,message):
    if not ok:raise ValueError(message)

def build(root=ROOT,proof=None):
    root=Path(root)
    if proof is None:proof=json.loads((root/PROOF).read_text(encoding='utf-8'))
    need(proof.get('schema')=='orison.v2.arcade-cobbler-field.v1','native field schema')
    _verify_sources(root,proof)
    path=root/'game'/ASSET[6:]
    need(proof.get('asset')==ASSET and hashlib.sha256(path.read_bytes()).hexdigest()==proof.get('asset_sha256'),'native field payload changed')
    spec=importlib.util.spec_from_file_location('arcade_cobbler_field_geometry',root/'art/blender/scripts/arcade_cobbler_field_geometry.py')
    g=importlib.util.module_from_spec(spec);spec.loader.exec_module(g)
    inputs=['art/data/arcade_plaza/source_plan.json','game/data/building_layout.json',
            'art/data/arcade_plaza/retained_equipment_placements.json','game/tests/fixtures/orison_cobbler_fittings.json']
    result=g.build(*(json.loads((root/p).read_text(encoding='utf-8')) for p in inputs))
    need(proof.get('support')==result['proof'],'actual contact/support projection changed')
    stripped=[{k:v for k,v in row.items() if k not in ['actual_native_volume_m3','native_vertex_quantization_m']} for row in proof.get('stocks',[])]
    # JSON serializes tuple vertices/faces as lists.
    need(stripped==json.loads(json.dumps(result['stocks'])),'closed support stocks changed')
    native=NativeGLB(path);draw=proof.get('draw',{})
    need(set(native.names)=={'CobblerSupportingFelt'} and draw.get('name')=='CobblerSupportingFelt','one registered field draw required')
    need(native.triangles(draw['name'])==draw.get('triangles')==96,'actual field triangle inventory')
    need(native.transform(native.names[draw['name']])==[[1,0,0,0],[0,1,0,0],[0,0,1,0],[0,0,0,1]],'field source frame changed')
    donors=proof.get('source_material_parts',[])
    need({r['name'] for r in donors}=={g.FELT+'__soot__north',g.FELT+'__soot__south'} and len(donors)==2,'both original field witnesses required')
    sidecar=json.loads((root/'game/data/orison_v2/cobbler_fittings.json').read_text())
    original=[r for c in sidecar['cells'] if c['id']==g.CELL for r in c['parts'] if r['name'].startswith(g.FELT+'__')]
    need(donors==original,'original material witnesses changed')
    bindings={('res://'+p[5:]):v for p,v in proof['source_bindings'].items() if p in ['game/data/building_layout.json',
        'game/data/orison_v2/cobbler_fittings.json','game/data/orison_v2/owner_finish_profiles.json',
        'game/assets/props/cobbler_fittings.glb','game/data/runtime_material_sets.json'] or p.startswith('game/assets/building/textures/')}
    imported=(root/'game'/ASSET[6:]).with_suffix('.glb.import')
    raw=imported.read_bytes().replace(b'\r\n',b'\n')
    need(b'\nmeshes/force_disable_compression=true\n' in raw,'authored imported UV/position precision required')
    bindings[ASSET+'.import']=dict(kind='lf',sha256=hashlib.sha256(raw).hexdigest())
    return dict(schema=proof['schema'],asset=ASSET,asset_sha256=proof['asset_sha256'],
        cell=g.CELL,source_parts=[dict(name=r['name']) for r in donors],source_bindings=bindings,
        source_disposal_authorized=False)

def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--check',action='store_true');args=parser.parse_args()
    result=build();text=json.dumps(result,indent=2)+'\n'
    if args.check:need((ROOT/OUTPUT).read_text(encoding='utf-8')==text,'field intake stale')
    else:(ROOT/OUTPUT).write_text(text,encoding='utf-8',newline='\n')
    print('ARCADE_COBBLER_INTAKE_PASS 8stocks/25felt/12floor; no source disposal')

if __name__=='__main__':main()
