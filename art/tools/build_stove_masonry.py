"""Periodic hand-pressed fired clay and exposed lime; independent metric relief.

No mortar lines or lighting are baked into the clay. Native stocks own joints,
arris wear and exposure tint; independent channels own pits and pressed grain.
"""
from pathlib import Path
import hashlib,json
import numpy as np
from PIL import Image

ROOT=Path(__file__).resolve().parents[2]
SIZE=1024
TILE=.25

def field(rng,u,v,low,high,count):
    # A handful of plane waves reads as directional wood grain. Populate an
    # isotropic periodic frequency band with independent mineral variation.
    frequency=np.fft.fftfreq(SIZE)*SIZE
    radius=np.sqrt(frequency[:,None]**2+frequency[None,:]**2)
    envelope=np.exp(-.5*(radius/high)**4)*(1.-np.exp(-.5*(radius/low)**4))
    result=np.fft.ifft2(np.fft.fft2(rng.normal(size=u.shape))*envelope).real
    return result/result.std()

def build():
    y,x=np.mgrid[:SIZE,:SIZE];u=x/SIZE;v=y/SIZE
    reports=[]
    for number,key in enumerate(['stove_clinker','stove_lime']):
        rng=np.random.default_rng(19281021+number)
        pressed=field(rng,u,v,2,11,12)
        grain=field(rng,u,v,18,85,20)
        fines=field(rng,u,v,100,350,18)
        # All depressions are independently modeled in metres, rather than
        # inferred from pigment brightness. Wrap sampling is periodic.
        pits=np.clip(-grain-1.25,0,2.5)/2.5
        clay=key=='stove_clinker'
        height=(pressed*.00011+grain*.000025+fines*.000009-pits*.00028) if clay else (pressed*.000045+grain*.000055+fines*.000015-pits*.00014)
        pigment=field(rng,u,v,1,9,12)
        if clay:
            albedo=np.array([.48,.295,.205])+pigment[...,None]*np.array([.032,.021,.016])+grain[...,None]*.006
            rough=.84+pressed*.015+pits*.07+fines*.008
        else:
            albedo=np.array([.43,.409,.355])+pigment[...,None]*.016+grain[...,None]*.008
            rough=.91+grain*.012+pits*.025
        dx=(np.roll(height,-1,1)-np.roll(height,1,1))*SIZE/(2*TILE)
        dy=(np.roll(height,-1,0)-np.roll(height,1,0))*SIZE/(2*TILE)
        normal=np.stack([-dx,dy,np.ones_like(dx)],axis=-1);normal/=np.linalg.norm(normal,axis=-1)[...,None]
        rough=np.clip(rough,.72,.98)
        dest=ROOT/'art/textures/procedural'/key;dest.mkdir(parents=True,exist_ok=True)
        for name,value in [('albedo',albedo),('roughness',rough),('normal',normal*.5+.5)]:
            Image.fromarray(np.rint(np.clip(value,0,1)*255).astype(np.uint8)).save(dest/(name+'.png'))
        span=float(np.ptp(height));Image.fromarray(np.rint((height-height.min())/span*65535).astype(np.uint16)).save(dest/'height.png')
        maps={name:name+'.png' for name in ['albedo','roughness','normal','height']}
        report={'material':key,'status':'QUALIFICATION_PENDING','meters_per_tile':TILE,'generator':Path(__file__).relative_to(ROOT).as_posix(),
            'generator_sha256_lf':hashlib.sha256(Path(__file__).read_bytes().replace(b'\r\n',b'\n')).hexdigest(),
            'height_model':'periodic_independent_pressed_clay_v1' if clay else 'periodic_independent_lime_aggregate_v1',
            'height_storage_bits':16,'normal_strength':1.,'relief_mm':span*1000,'maps':maps,
            'map_sha256':{k:hashlib.sha256((dest/v).read_bytes()).hexdigest() for k,v in maps.items()},
            'measurements':{'normal_slope_rms':float(np.sqrt(np.mean(dx*dx+dy*dy))),'roughness_min':float(rough.min()),'roughness_max':float(rough.max())}}
        report['normal_authoring']={'construction':'hand-pressed fired clay with mineral pits' if clay else 'troweled lime with exposed aggregate',
            'height_units':'metres','normal_convention':'OpenGL','normal_strength':1.,
            'physical_tile_m':TILE,'height_min_m':float(height.min()),'height_max_m':float(height.max()),
            'nominal_feature_bands_m':{'pressed':[TILE/11,TILE/2],'grain':[TILE/85,TILE/18],'fines':[TILE/350,TILE/100]},
            'pigment_is_not_height':True,'unresolved_detail':'Features below the sampled bands remain in roughness, not aliased normal relief.'}
        (dest/'material.json').write_text(json.dumps(report,indent=2)+'\n',newline='\n');reports.append(report)
    return reports

if __name__=='__main__':
    for report in build():print(report['material'],report['relief_mm'],'mm relief',report['measurements'])
