"""Periodic hand-buffed nickel plating: micron relief, quiet colour, fine wiping marks.

No baked illumination, lettering, photographic source or large corrosion spots.
Patina belongs to separate recessed hardware, not random blotches on a knob.
"""
from pathlib import Path
import hashlib, json, shutil
import numpy as np
from PIL import Image
ROOT=Path(__file__).resolve().parents[2]
out=ROOT/'art/textures/procedural/faucet_nickel';out.mkdir(parents=True,exist_ok=True)
size=512;tile=.18;rng=np.random.default_rng(19281012)
f=np.fft.fftfreq(size)
def field(x,y):
    mask=np.exp(-((f[None,:]/x)**2+(f[:,None]/y)**2))
    a=np.fft.ifft2(np.fft.fft2(rng.normal(size=(size,size)))*mask).real
    return a/a.std()
micro=field(.30,.30);wipe=field(.30,.006)
albedo=np.array([211.,209.,202.])+np.clip(micro*.35+wipe*.65,-2,2)[...,None]
rough=np.clip(.24+wipe*.012+micro*.006,.19,.30)
height=np.clip(.5+wipe*.10+micro*.025,0,1)
relief=.000004
dx=(np.roll(height,-1,1)-np.roll(height,1,1))*relief*size*.5/tile
dy=(np.roll(height,-1,0)-np.roll(height,1,0))*relief*size*.5/tile
normal=np.stack((-dx,dy,np.ones_like(dx)),axis=-1)
normal/=np.linalg.norm(normal,axis=-1)[...,None]
for key,values in [('albedo',albedo),('roughness',rough*255),('height',height*255),('normal',(normal*.5+.5)*255)]:
    Image.fromarray(np.rint(np.clip(values,0,255)).astype(np.uint8)).save(out/(key+'.png'))
metadata={'material':'faucet_nickel','generator':'art/tools/build_faucet_nickel.py',
 'source':__doc__,'seed':19281012,'meters_per_tile':tile,'relief_mm':relief*1000,
 'maps':{k:k+'.png' for k in ['albedo','roughness','height','normal']}}
metadata['map_sha256']={k:hashlib.sha256((out/v).read_bytes()).hexdigest() for k,v in metadata['maps'].items()}
(out/'material.json').write_text(json.dumps(metadata,indent=2)+'\n',encoding='utf-8',newline='\n')
for source,suffix in [('albedo','albedo'),('roughness','rough'),('normal','normal')]:
    shutil.copyfile(out/(source+'.png'),ROOT/'game/assets/building/textures'/('T_ai_materials_faucet_nickel_'+suffix+'.png'))
print('faucet_nickel: 512px, 0.18m tile, 4-micron relief, three runtime maps')
