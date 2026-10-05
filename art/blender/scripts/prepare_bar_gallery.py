"""Freeze a successful WallArtLaw/physics fit without altering source layout."""
from pathlib import Path
import argparse, hashlib, json, re

ROOT=next(p for p in Path(__file__).resolve().parents if (p/'game/project.godot').is_file())
def digest(path):
    raw=path.read_bytes()
    return hashlib.sha256(raw if path.suffix in ('.bin','.glb','.png','.blend') else raw.replace(b'\r\n',b'\n')).hexdigest()

def main():
    parser=argparse.ArgumentParser();parser.add_argument('--probe',type=Path,required=True)
    parser.add_argument('--out',type=Path,default=ROOT/'art/data/bar_gallery/source_fit.json');args=parser.parse_args()
    probe=json.loads(args.probe.read_bytes());poses=probe['poses']
    assert not probe['failures'] and len(poses)==22 and all(p.get('ok') for p in poses)
    layout=json.loads((ROOT/'art/data/building_layout.json').read_bytes())
    floor=next(f for f in layout['floors'] if f['id']=='F01')
    source={r['id']:r for r in floor['furniture'] if r['id'].startswith('retail_bar_gal')}
    assert set(source)=={p['id'] for p in poses}
    def same(a,b):
        if isinstance(a,dict):return a.keys()==b.keys() and all(same(a[k],b[k]) for k in a)
        if isinstance(a,list):return len(a)==len(b) and all(same(x,y) for x,y in zip(a,b))
        if isinstance(a,(int,float)) and isinstance(b,(int,float)):return abs(a-b)<1e-8
        return a==b
    for pose in poses:
        assert same(pose['source'],source[pose['id']])
        pose['source']=source[pose['id']]
    hands=(ROOT/'game/scripts/building/harukiya_interactables.gd').read_text()
    block=hands.split('var pictures := [',1)[1].split('\n\tfor spec in pictures:',1)[0]
    anchors=re.findall(r'\[\s*(-?[\d.]+),\s*(-?[\d.]+),\s*"([^"]+)"',block)
    assert len(anchors)==3
    available=[r for r in source.values() if r['rect'][2]-r['rect'][0] > r['rect'][3]-r['rect'][1]]
    inspectors=[]
    for index,(x,z,title) in enumerate(anchors):
        chosen=min(available,key=lambda r:((r['rect'][0]+r['rect'][2])*.5-float(x))**2+(r['z0']+r['h']*.5-float(z))**2)
        available.remove(chosen);inspectors.append({'zone':f'BAR_PIC_{index}','picture':chosen['id'],'original_title':title})
    bindings=[ROOT/'art/data/building_layout.json',ROOT/'game/assets/building/floor_01_cells/shop_bar.gltf',ROOT/'game/assets/building/floor_01_cells/shop_bar.bin',ROOT/'game/scripts/building/wall_art_law.gd',ROOT/'game/scripts/building/orison_v2_bar_gallery.gd',ROOT/'game/scripts/building/harukiya_interactables.gd',ROOT/'game/tests/orison_v2_bar_gallery_fit.gd']
    result={'schema':'orison.bar-gallery.source-fit.v1','classification':'ADAPTATION','source_floor':'F01','poses':poses,'inspectors':inspectors,
        'manufacture':{'border_m':.014,'print_thickness_m':.0005,'packer_width_m':.028,'packer_height_m':.028,'pin_radius_m':.0017,'pin_embed_m':.016},
        'bindings':{p.relative_to(ROOT).as_posix():digest(p) for p in bindings}}
    args.out.parent.mkdir(parents=True,exist_ok=True);args.out.write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8',newline='\n')
    print('BAR GALLERY SOURCE FIT:',len(poses),'lawful pictures;',len(inspectors),'retained inspection associations')
if __name__=='__main__':main()
