"""Periodic construction softwood PBR from growth, fibres and saw relief.

Both face and end-grain stock are authored from physical fields. No image,
lettering, nail marks, shadows or painted illumination enters these maps.
Height is expressed in metres before computing the tangent-space normal.
"""
from pathlib import Path
import argparse, hashlib, json
import numpy as np
from PIL import Image

ROOT=Path(__file__).resolve().parents[2]
TAU=2*np.pi

def build(output_root=ROOT,size=2048):
    tile=1.0;rng=np.random.default_rng(19281118);frequency=np.fft.fftfreq(size)
    fu=frequency[None,:];fv=frequency[:,None]
    u=np.arange(size)[None,:]/size;v=np.arange(size)[:,None]/size
    def noise(along,across):
        x=np.fft.ifft2(np.fft.fft2(rng.normal(size=(size,size)))*np.exp(-(fu/along)**2-(fv/across)**2)).real
        return x/x.std()
    fibres=noise(.004,.15);micro=noise(.25,.25);soft=noise(.007,.01)
    phase=TAU*(200*v+1.1*np.sin(TAU*u)+.42*np.sin(TAU*(2*u+v))+.17*np.sin(TAU*(3*u-2*v)))
    late=np.exp(-((np.sin(phase)+1)/.20)**2)
    saw=np.sin(TAU*(400*u+.24*np.sin(TAU*v)+.11*np.sin(TAU*u)))
    radius=np.sqrt(np.sin(np.pi*u)**2+np.sin(np.pi*v)**2)
    end_late=np.exp(-((np.sin(TAU*(85*radius+.08*soft))+1)/.22)**2)
    reports=[]
    for key,rings,end in [('site_softwood',late,False),('site_softwood_endgrain',end_late,True)]:
        relief=(rings-rings.mean())*.00010+fibres*.000014+micro*.000004
        if not end:relief+=saw*.000024
        grain=soft*.7+fibres*.65+micro*.25-rings*9
        base=np.array([182.,173.,150.] if not end else [177.,165.,139.])
        albedo=np.clip(base+grain[...,None]*np.array([1.,1.,.85]),0,255)
        rough=np.clip(.79+fibres*.012+micro*.008-rings*.035+(.015 if end else saw*.008),.66,.90)
        # Central differences wrap the actual periodic height field. The
        # minus/+ normal convention matches the existing shipped PBR recipes.
        dx=(np.roll(relief,-1,1)-np.roll(relief,1,1))*size*.5/tile
        dy=(np.roll(relief,-1,0)-np.roll(relief,1,0))*size*.5/tile
        normal=np.stack((-dx,dy,np.ones_like(dx)),axis=-1);normal/=np.linalg.norm(normal,axis=-1)[...,None]
        folder=output_root/'art/textures/procedural'/key;folder.mkdir(parents=True,exist_ok=True)
        for name,value in [('albedo',albedo),('roughness',rough*255),('normal',(normal*.5+.5)*255)]:
            Image.fromarray(np.rint(np.clip(value,0,255)).astype(np.uint8)).save(folder/(name+'.png'))
        span=float(np.ptp(relief));height=np.rint((relief-relief.min())/span*65535).astype(np.uint16)
        Image.fromarray(height).save(folder/'height.png')
        maps={name:name+'.png' for name in ['albedo','roughness','normal','height']}
        meta={'material':key,'generator':'art/tools/build_site_softwood.py',
            'source':'Code-authored periodic growth bands, fibres and physical saw relief; no photographic or baked-lighting pixels.',
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
