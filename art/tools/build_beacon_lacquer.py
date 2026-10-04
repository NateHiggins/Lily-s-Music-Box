"""Periodic painted-metal beacon lacquer, with calibrated micro-relief."""
from pathlib import Path
import hashlib,json,shutil
import numpy as np
from PIL import Image
r=Path(__file__).resolve().parents[2];out=r/'art/textures/procedural/beacon_lacquer';out.mkdir(parents=True,exist_ok=True);N=1024;rng=np.random.default_rng(19281113);f=np.fft.fftfreq(N);rad=np.hypot(f[:,None],f[None,:])
def field(cutoff):
 a=rng.normal(size=(N,N));a=np.fft.ifft2(np.fft.fft2(a)*np.exp(-(rad/cutoff)**2)).real;return a/a.std()
micro=field(.16);macro=field(.006);variation=macro*.8+micro*.22
albedo=np.stack([133+variation,36+variation*.5,28+variation*.35],axis=-1);rough=np.clip(.34+micro*.006,.30,.38);height=np.clip(.5+micro*.12,0,1)
dx=(np.roll(height,-1,1)-np.roll(height,1,1))*.00003*N*.5/.5;dy=(np.roll(height,-1,0)-np.roll(height,1,0))*.00003*N*.5/.5;normal=np.stack((-dx,dy,np.ones_like(dx)),axis=-1);normal/=np.linalg.norm(normal,axis=-1)[...,None]
for key,values in [('albedo',albedo),('roughness',rough*255),('height',height*255),('normal',(normal*.5+.5)*255)]:Image.fromarray(np.rint(np.clip(values,0,255)).astype(np.uint8)).save(out/(key+'.png'))
metadata={'material':'beacon_lacquer','generator':'art/tools/build_beacon_lacquer.py','source':'Deterministic periodic metal-housing lacquer; original source red hue, no photographs, wood-exposing chips, lettering or baked illumination.','seed':19281113,'meters_per_tile':.5,'relief_mm':.03,'maps':{k:k+'.png' for k in ['albedo','roughness','height','normal']},'map_sha256':{k:hashlib.sha256((out/(k+'.png')).read_bytes()).hexdigest() for k in ['albedo','roughness','height','normal']}}
(out/'material.json').write_text(json.dumps(metadata,indent=2)+'\n',newline='\n')
for source,suffix in [('albedo','albedo'),('roughness','rough'),('normal','normal')]:shutil.copyfile(out/(source+'.png'),r/'game/assets/building/textures'/('T_ai_materials_beacon_lacquer_'+suffix+'.png'))
print('Beacon lacquer: periodic 1024 px / 0.5 m source red hue, 0.03 mm relief; four source and three runtime maps.')
