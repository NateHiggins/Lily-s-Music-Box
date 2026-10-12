"""Periodic oil-painted timber finish; brush ridges have 0.05-mm relief."""
from pathlib import Path
import hashlib,json,shutil
import numpy as np
from PIL import Image
ROOT=Path(__file__).resolve().parents[2]
out=ROOT/'art/textures/procedural/door_paint';out.mkdir(parents=True,exist_ok=True)
n=512;tile=.30;rng=np.random.default_rng(19281013);f=np.fft.fftfreq(n)
def field(x,y):
    a=np.fft.ifft2(np.fft.fft2(rng.normal(size=(n,n)))*np.exp(-((f[None,:]/x)**2+(f[:,None]/y)**2))).real
    return a/a.std()
brush=field(.24,.009);micro=field(.30,.30)
albedo=np.array([236.,235.,231.])+np.clip(brush*.45+micro*.25,-2,2)[...,None]
rough=np.clip(.44+brush*.015+micro*.004,.37,.51)
height=np.clip(.5+brush*.13+micro*.025,0,1);relief=.00005
dx=(np.roll(height,-1,1)-np.roll(height,1,1))*relief*n*.5/tile
dy=(np.roll(height,-1,0)-np.roll(height,1,0))*relief*n*.5/tile
normal=np.stack((-dx,dy,np.ones_like(dx)),axis=-1);normal/=np.linalg.norm(normal,axis=-1)[...,None]
for key,value in [('albedo',albedo),('roughness',rough*255),('height',height*255),('normal',(normal*.5+.5)*255)]:
    Image.fromarray(np.rint(np.clip(value,0,255)).astype(np.uint8)).save(out/(key+'.png'))
metadata={'material':'door_paint','generator':'art/tools/build_door_paint.py','source':__doc__,
 'seed':19281013,'meters_per_tile':tile,'relief_mm':relief*1000,'maps':{k:k+'.png' for k in ['albedo','roughness','height','normal']}}
metadata['map_sha256']={k:hashlib.sha256((out/v).read_bytes()).hexdigest() for k,v in metadata['maps'].items()}
(out/'material.json').write_text(json.dumps(metadata,indent=2)+'\n',encoding='utf-8',newline='\n')
for source,suffix in [('albedo','albedo'),('roughness','rough'),('normal','normal')]:
    shutil.copyfile(out/(source+'.png'),ROOT/'game/assets/building/textures'/('T_ai_materials_door_paint_'+suffix+'.png'))
print('door_paint: 512px, 0.30m tile, 0.05mm brush relief; original resident tints retained')
