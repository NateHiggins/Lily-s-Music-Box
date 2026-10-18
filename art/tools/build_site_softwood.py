"""Construction softwood with generated colour and calibrated physical relief.

Long-grain colour retains the generated plate byte-exact. End-grain colour and
independent microrelief are code-authored; pigment never determines height.
Height is expressed in metres before computing the tangent-space normal.
"""
from pathlib import Path
import argparse, hashlib, json
import shutil
import numpy as np
from PIL import Image

ROOT=Path(__file__).resolve().parents[2]
TAU=2*np.pi

def build(output_root=ROOT,size=2048):
    source=ROOT/'art/textures/ai_sources/site_softwood_20261017.png'
    plate=np.asarray(Image.open(source).convert('RGB'));size=plate.shape[0]
    if plate.shape!=(size,size,3):raise ValueError('square generated stock required')
    tile=1.0;rng=np.random.default_rng(19281118)
    u=np.linspace(0,1,size)[None,:];v=np.linspace(0,1,size)[:,None]
    def noise(along,across):
        # Cosine modes give reflecting (zero-slope) edges. Mirrored UV
        # neighbours therefore retain continuous micro-normal lighting.
        k=np.rint(np.abs(rng.normal(size=96))*along*size)
        l=np.rint(np.abs(rng.normal(size=96))*across*size)
        x=(np.cos(np.pi*v*l[None,:])*rng.normal(size=96)[None,:])@np.cos(np.pi*k[:,None]*u)
        return x/x.std()
    fibres=noise(.004,.15);micro=noise(.25,.25);soft=noise(.007,.01)
    saw=noise(.18,.006)
    late=np.zeros((size,size))
    radius=np.sqrt(np.sin(np.pi*u)**2+np.sin(np.pi*v)**2)
    end_late=np.exp(-((np.sin(TAU*(85*radius+.08*soft))+1)/.22)**2)
    reports=[]
    for key,rings,end in [('site_softwood',late,False),('site_softwood_endgrain',end_late,True)]:
        relief=(rings-rings.mean())*.000020+fibres*.000012+micro*.000002
        if not end:relief+=saw*.000006
        grain=soft*.7+fibres*.65+micro*.25-rings*9
        base=plate.mean((0,1))-(np.array([4.,4.,6.]) if end else 0)
        albedo=np.clip(base+grain[...,None]*np.array([1.,1.,.85]),0,255)
        rough=np.clip(.79+fibres*.012+micro*.008-rings*.035+(.015 if end else saw*.008),.66,.90)
        # Central differences sample the reflecting height field. The
        # minus/+ normal convention matches the existing shipped PBR recipes.
        dy,dx=np.gradient(relief,tile/(size-1),edge_order=2)
        dx[:,[0,-1]]=0;dy[[0,-1],:]=0
        normal=np.stack((-dx,dy,np.ones_like(dx)),axis=-1);normal/=np.linalg.norm(normal,axis=-1)[...,None]
        folder=output_root/'art/textures/procedural'/key;folder.mkdir(parents=True,exist_ok=True)
        for name,value in [('albedo',albedo),('roughness',rough*255),('normal',(normal*.5+.5)*255)]:
            Image.fromarray(np.rint(np.clip(value,0,255)).astype(np.uint8)).save(folder/(name+'.png'))
        if not end:shutil.copyfile(source,folder/'albedo.png')
        span=float(np.ptp(relief));height=np.rint((relief-relief.min())/span*65535).astype(np.uint16)
        Image.fromarray(height).save(folder/'height.png')
        maps={name:name+'.png' for name in ['albedo','roughness','normal','height']}
        meta={'material':key,'generator':'art/tools/build_site_softwood.py',
            'source':'New generated albedo retained byte-exact for long-grain stock; end grain and independent reflecting microrelief are code-authored. No photographic pixels, hardware marks, lettering or pigment-to-height conversion.',
            'albedo_source':source.relative_to(ROOT).as_posix(),
            'albedo_source_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),
            'uv_contract':'Mirrored metre charts with clamped texture sampling; normal slopes vanish at reflected borders.',
            'seed':19281118,'meters_per_tile':tile,'relief_mm':span*1000,
            'normal_strength':1.0,'grain_axis':'u' if not end else 'radial',
            'maps':maps,'map_sha256':{name:hashlib.sha256((folder/file).read_bytes()).hexdigest() for name,file in maps.items()},
            'measurements':{'roughness_min':float(rough.min()),'roughness_max':float(rough.max()),
                'normal_slope_rms':float(np.sqrt(np.mean(dx*dx+dy*dy))),
                'height_storage_bits':16,'nonfinite_values':int(np.sum(~np.isfinite(normal)))}}
        (folder/'material.json').write_text(json.dumps(meta,indent=2)+'\n',encoding='utf8',newline='\n')
        shipping=output_root/'game/assets/building/textures';shipping.mkdir(parents=True,exist_ok=True)
        for name,suffix in [('albedo','albedo'),('roughness','rough'),('normal','normal')]:
            (shipping/f'T_ai_materials_{key}_{suffix}.png').write_bytes((folder/(name+'.png')).read_bytes())
        reports.append(meta)
    return reports

if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--out-root',type=Path,default=ROOT)
    args=parser.parse_args();report=build(args.out_root)
    for row in report:print(row['material'],f"{row['relief_mm']:.3f} mm measured relief;",row['measurements'])
