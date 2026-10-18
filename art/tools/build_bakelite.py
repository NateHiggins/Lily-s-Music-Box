"""Periodic moulded brown phenolic resin, replacing the library's marbled plate.

Quiet filler/flow colour and submicron polishing relief have independent
fields. No cavities, highlights, dirt islands, lettering or photographs.
"""
from pathlib import Path
import hashlib,json,shutil
import numpy as np
from PIL import Image

ROOT=Path(__file__).resolve().parents[2]

def build():
    out=ROOT/'art/textures/procedural/bakelite';out.mkdir(parents=True,exist_ok=True)
    size,tile,seed=512,.04,1928101718
    rng=np.random.default_rng(seed)
    fx,fy=np.meshgrid(np.fft.fftfreq(size),np.fft.fftfreq(size))
    def field(x,y):
        result=np.fft.ifft2(np.fft.fft2(rng.standard_normal((size,size)))*np.exp(-(fx/x)**2-(fy/y)**2)).real
        return (result-result.mean())/result.std()
    filler,flow,polish=field(.18,.18),field(.012,.045),field(.24,.24)
    height_m=filler*.0000004+polish*.00000012
    dx=(np.roll(height_m,-1,1)-np.roll(height_m,1,1))*size/(2*tile)
    dy=(np.roll(height_m,-1,0)-np.roll(height_m,1,0))*size/(2*tile)
    normal=np.stack((-dx,dy,np.ones_like(dx)),axis=-1)
    normal/=np.linalg.norm(normal,axis=-1)[...,None]
    albedo=np.clip(np.array([51,35,26])[None,None,:]+flow[...,None]*np.array([.7,.45,.3])+filler[...,None]*.12,0,255)
    roughness=np.clip(.26+flow*.006+filler*.003+polish*.002,.22,.30)
    extent=float(np.abs(height_m).max())
    maps={'albedo':albedo,'roughness':roughness*255,'normal':(normal*.5+.5)*255,'height':(height_m/(2*extent)+.5)*255}
    for name,value in maps.items():Image.fromarray(np.rint(value).astype('uint8')).save(out/(name+'.png'))
    metadata=dict(material='bakelite',generator='art/tools/build_bakelite.py',source=__doc__,
        seed=seed,meters_per_tile=tile,normal_convention='OpenGL',normal_strength=1.,metallic=0.,
        roughness_range=[float(roughness.min()),float(roughness.max())],rms_relief_mm=float(height_m.std()*1000),
        height_encoding_range_mm=[-extent*1000,extent*1000],maximum_normal_slope=float(np.hypot(dx,dy).max()),
        maps={name:name+'.png' for name in maps},
        map_sha256={name:hashlib.sha256((out/(name+'.png')).read_bytes()).hexdigest() for name in maps})
    (out/'material.json').write_text(json.dumps(metadata,indent=2)+'\n',encoding='utf-8',newline='\n')
    for name,suffix in [('albedo','albedo'),('roughness','rough'),('normal','normal')]:
        shutil.copyfile(out/(name+'.png'),ROOT/'game/assets/building/textures'/('T_ai_materials_bakelite_'+suffix+'.png'))
    print('bakelite: 512 px / 40 mm, RMS relief %.6f mm'%metadata['rms_relief_mm'])

if __name__=='__main__':build()
