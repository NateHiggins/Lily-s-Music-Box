"""Periodic galvanized roof hardware with fine zinc variation; no oversized weather crust, lettering, photographs or baked light."""
from pathlib import Path
import hashlib,json,shutil
import numpy as np
from PIL import Image
r=Path(__file__).resolve().parents[2];out=r/'art/textures/procedural/galvanized_roof';out.mkdir(parents=True,exist_ok=True)
N=1024;rng=np.random.default_rng(19281115);f=np.fft.fftfreq(N);rad=np.hypot(f[:,None],f[None,:])
def field(cutoff):
    a=np.fft.ifft2(np.fft.fft2(rng.normal(size=(N,N)))*np.exp(-(rad/cutoff)**2)).real
    return a/a.std()
fine=field(.08);macro=field(.004);micro=field(.19)
variation=fine*2.8+macro*1.7+micro*.35
albedo=np.stack([163+variation,167+variation,168+variation],axis=-1)
rough=np.clip(.58+fine*.012+micro*.005,.51,.66)
height=np.clip(.5+fine*.08+micro*.04,0,1)
dx=(np.roll(height,-1,1)-np.roll(height,1,1))*.00005*N*.5/.9
dy=(np.roll(height,-1,0)-np.roll(height,1,0))*.00005*N*.5/.9
normal=np.stack((-dx,dy,np.ones_like(dx)),axis=-1);normal/=np.linalg.norm(normal,axis=-1)[...,None]
for key,values in [('albedo',albedo),('roughness',rough*255),('height',height*255),('normal',(normal*.5+.5)*255)]:Image.fromarray(np.rint(np.clip(values,0,255)).astype(np.uint8)).save(out/(key+'.png'))
metadata={'material': 'galvanized_roof', 'generator': 'art/tools/build_galvanized_roof.py', 'source': 'Periodic galvanized roof hardware with fine zinc variation; no oversized weather crust, lettering, photographs or baked light.', 'seed': 19281115, 'meters_per_tile': 0.9, 'relief_mm': 0.05, 'maps': {'albedo': 'albedo.png', 'roughness': 'roughness.png', 'height': 'height.png', 'normal': 'normal.png'}}
metadata['map_sha256']={k:hashlib.sha256((out/(k+'.png')).read_bytes()).hexdigest() for k in metadata['maps']}
(out/'material.json').write_text(json.dumps(metadata,indent=2)+'\n',newline='\n')
for source,suffix in [('albedo','albedo'),('roughness','rough'),('normal','normal')]:shutil.copyfile(out/(source+'.png'),r/'game/assets/building/textures'/('T_ai_materials_galvanized_roof_'+suffix+'.png'))
print('galvanized_roof: deterministic calibrated source and runtime PBR maps')
