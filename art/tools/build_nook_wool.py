"""Period woven wool: independent pigment, yarn relief and roughness.

Periodic 240 mm diamond repeat, 1.875 mm yarns. No photographic source,
lettering or baked lighting. Geometry owns the rug's bound perimeter.
"""
from pathlib import Path
import hashlib,json,shutil
import numpy as np
from PIL import Image

ROOT=Path(__file__).resolve().parents[2]
SIZE=1024;TILE=.24

def build():
    y,x=np.mgrid[:SIZE,:SIZE];u=x/SIZE;v=y/SIZE
    rng=np.random.default_rng(19281022)
    # Crossing warp/weft vary in height with their actual over-under order.
    warp=np.cos(2*np.pi*128*u);weft=np.cos(2*np.pi*128*v)
    over=np.cos(2*np.pi*64*u)*np.cos(2*np.pi*64*v)
    height=.00009*(warp+weft)+.000045*over*(warp-weft)
    fibre=rng.normal(0,1,u.shape)
    diamond=np.abs((u*2)%1-.5)+np.abs((v*2)%1-.5)
    motif=(diamond<.17)|((diamond>.28)&(diamond<.32))
    pigment=np.where(motif[...,None],np.array([.43,.33,.20]),np.array([.31,.15,.105]))
    pigment=pigment+(warp+weft)[...,None]*.009+fibre[...,None]*.006
    rough=np.clip(.91+.025*over+.01*fibre,.83,.98)
    dx=(np.roll(height,-1,1)-np.roll(height,1,1))*SIZE/(2*TILE)
    dy=(np.roll(height,-1,0)-np.roll(height,1,0))*SIZE/(2*TILE)
    normal=np.stack([-dx,dy,np.ones_like(dx)],axis=-1);normal/=np.linalg.norm(normal,axis=-1)[...,None]
    key='nook_woven_wool';dest=ROOT/'art/textures/procedural'/key;dest.mkdir(parents=True,exist_ok=True)
    for name,value in [('albedo',pigment),('roughness',rough),('normal',normal*.5+.5)]:
        Image.fromarray(np.rint(np.clip(value,0,1)*255).astype(np.uint8)).save(dest/(name+'.png'))
    Image.fromarray(np.rint((height-height.min())/np.ptp(height)*65535).astype(np.uint16)).save(dest/'height.png')
    maps={k:k+'.png' for k in ['albedo','roughness','normal','height']}
    report=dict(material=key,status='QUALIFICATION_PENDING',meters_per_tile=TILE,
        generator=Path(__file__).relative_to(ROOT).as_posix(),generator_sha256_lf=hashlib.sha256(Path(__file__).read_bytes().replace(b'\r\n',b'\n')).hexdigest(),
        maps=maps,map_sha256={k:hashlib.sha256((dest/v).read_bytes()).hexdigest() for k,v in maps.items()},height_storage_bits=16,
        normal_strength=1.,normal_convention='OpenGL',normal_authoring=dict(construction='crossing wool warp/weft with alternating over-under relief',height_units='metres',normal_convention='OpenGL',normal_strength=1.,physical_tile_m=TILE,
            height_min_m=float(height.min()),height_max_m=float(height.max()),nominal_feature_bands_m={'yarn':[TILE/128,TILE/64]},pigment_is_not_height=True,unresolved_detail='Subpixel fibres remain in roughness.'),
        measurements=dict(normal_slope_rms=float(np.sqrt(np.mean(dx*dx+dy*dy))),roughness_min=float(rough.min()),roughness_max=float(rough.max())))
    (dest/'material.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8',newline='\n')
    for source,target in [('albedo','albedo'),('roughness','rough'),('normal','normal')]:shutil.copyfile(dest/(source+'.png'),ROOT/f'game/assets/building/textures/T_ai_materials_{key}_{target}.png')
    print(key,report['measurements'])

if __name__=='__main__':build()
