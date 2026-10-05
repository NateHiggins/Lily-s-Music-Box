"""Freeze the original stage sources and measured signal clearance."""
from pathlib import Path
import argparse, hashlib, json

ROOT=next(p for p in Path(__file__).resolve().parents if (p/'game/project.godot').is_file())
def digest(path):
    raw=path.read_bytes()
    return hashlib.sha256(raw if path.suffix in ('.bin','.glb','.png','.blend') else raw.replace(b'\r\n',b'\n')).hexdigest()

def main():
    parser=argparse.ArgumentParser();parser.add_argument('--probe',type=Path,required=True)
    parser.add_argument('--out',type=Path,default=ROOT/'art/data/bar_stage/source_fit.json');args=parser.parse_args()
    probe=json.loads(args.probe.read_bytes());assert not probe['failures'] and len(probe['sign_bounds'])==2
    layout=json.loads((ROOT/'art/data/building_layout.json').read_bytes());floor=next(f for f in layout['floors'] if f['id']=='F01')
    rows={r['id']:r for r in floor['furniture']}
    sources=[rows[f'retail_bar_drape{i}'] for i in range(16)]+[rows['retail_bar_pelmet']]
    markers=[r for r in floor['markers'] if r['id'].startswith(('F01_BAR_STAGE','F01_KARAOKE'))]
    assert len(markers)==3 and {r['id'] for r in markers}=={r['id'] for r in probe['markers']}
    def same(a,b):
        if isinstance(a,dict):return a.keys()==b.keys() and all(same(a[k],b[k]) for k in a)
        if isinstance(a,list):return len(a)==len(b) and all(same(x,y) for x,y in zip(a,b))
        if isinstance(a,(int,float)) and isinstance(b,(int,float)):return abs(a-b)<1e-8
        return a==b
    assert all(same(r,next(p for p in probe['markers'] if p['id']==r['id'])) for r in markers)
    bounds=[[round(float(v),6) for v in row] for row in probe['sign_bounds']]
    wall=rows['retail_bar_wall_s'];floor_row=rows['retail_bar_floor'];wall_y=wall['rect'][3]
    front=bounds[0][1]-.018
    depth=min(max(r['rect'][3]-r['rect'][1] for r in sources[:16]),front-wall_y-.022)
    assert depth>.025 and front<min(r['rect'][1] for r in sources[:16])
    bindings=[ROOT/'art/data/building_layout.json',ROOT/'game/assets/building/floor_01_cells/shop_bar.gltf',ROOT/'game/assets/building/floor_01_cells/shop_bar.bin',ROOT/'game/scripts/props/neon_sign_prop.gd',ROOT/'game/tests/orison_v2_bar_stage_fit.gd',Path(__file__)]
    plan={'schema':'orison.bar-stage.source-fit.v1','classification':'ADAPTATION','source_floor':'F01','sources':sources,'wall':wall,'dado':rows['retail_bar_dado_s'],'floor':floor_row,'stage':rows['retail_bar_stage'],'markers':markers,'sign_bounds':bounds,
          'fit':{'front_y':front,'depth_m':depth,'cloth_thickness_m':.002,'floor_clearance_m':.01,'rail_radius_m':.008,'ring_radius_m':.012,'ring_stock_m':.002,'cloth_tint':[.60,.16,.20,1.]},
          'bindings':{p.relative_to(ROOT).as_posix():digest(p) for p in bindings}}
    args.out.parent.mkdir(parents=True,exist_ok=True);args.out.write_text(json.dumps(plan,indent=2)+'\n',encoding='utf-8',newline='\n')
    print('BAR STAGE SOURCE FIT:',len(sources),'original stocks; rearward fit',round(front-sources[0]['rect'][3],3),'m; fold depth',round(depth,4),'m')
if __name__=='__main__':main()
