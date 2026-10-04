"""Periodic straight-grain tank timber, calibrated in metres and millimetres.

No baked lighting, photographs, lettering or bitmap board joints. Closed
construction owns the stave joints; U follows the longitudinal wood fibres.
"""
from pathlib import Path
import hashlib,json,shutil
import numpy as np
from PIL import Image

ROOT=Path(__file__).resolve().parents[2]
TARGET=ROOT/'art/textures/procedural/tank_staves';TARGET.mkdir(parents=True,exist_ok=True)
SIZE=1024;SEED=19281112;rng=np.random.default_rng(SEED);frequency=np.fft.fftfreq(SIZE)
def field(longitudinal,transverse):
    noise=rng.normal(size=(SIZE,SIZE))
    filtered=np.fft.ifft2(np.fft.fft2(noise)*np.exp(-((frequency[None,:]/longitudinal)**2+(frequency[:,None]/transverse)**2))).real
    return filtered/filtered.std()
grain=field(.003,.10)*.75+field(.009,.025)*.25
macro=field(.005,.008);micro=field(.18,.22)
variation=grain*3.4+macro*2.+micro*.6
albedo=np.stack([147+variation,124+variation*.85,94+variation*.65],axis=-1)
roughness=np.clip(.67+grain*.025+micro*.008,.54,.80)
height=np.clip(.5+grain*.15+micro*.025,0,1)
relief_m=.0001;tile_m=1.
dx=(np.roll(height,-1,1)-np.roll(height,1,1))*relief_m*SIZE*.5/tile_m
dy=(np.roll(height,-1,0)-np.roll(height,1,0))*relief_m*SIZE*.5/tile_m
normal=np.stack((-dx,dy,np.ones_like(dx)),axis=-1);normal/=np.linalg.norm(normal,axis=-1)[...,None]
maps={'albedo':albedo,'roughness':roughness*255,'height':height*255,'normal':(normal*.5+.5)*255}
for key,values in maps.items():Image.fromarray(np.rint(np.clip(values,0,255)).astype(np.uint8)).save(TARGET/(key+'.png'),optimize=True)
metadata={'material':'tank_staves','generator':'art/tools/build_tank_staves.py','source':'Deterministic periodic straight fibre; no photographs, AI plate, lettering or baked illumination.','seed':SEED,'meters_per_tile':tile_m,'relief_mm':relief_m*1000,'long_grain_axis':'U','maps':{key:key+'.png' for key in maps},'map_sha256':{key:hashlib.sha256((TARGET/(key+'.png')).read_bytes()).hexdigest() for key in maps}}
(TARGET/'material.json').write_text(json.dumps(metadata,indent=2)+'\n',newline='\n')
for source,suffix in [('albedo','albedo'),('roughness','rough'),('normal','normal')]:shutil.copyfile(TARGET/(source+'.png'),ROOT/'game/assets/building/textures'/('T_ai_materials_tank_staves_'+suffix+'.png'))
print('Tank staves: periodic 1024 px / 1 m straight fibre, 0.1 mm relief; four source and three runtime maps.')
