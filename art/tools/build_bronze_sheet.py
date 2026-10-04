"""Periodic formed bronze sheet with restrained local oxide; no large crust, lettering, photographs or baked light."""
from pathlib import Path
import hashlib,json,shutil
import numpy as np
from PIL import Image
r=Path(__file__).resolve().parents[2];out=r/'art/textures/procedural/bronze_sheet';out.mkdir(parents=True,exist_ok=True)
N=1024;rng=np.random.default_rng(19281114);f=np.fft.fftfreq(N);rad=np.hypot(f[:,None],f[None,:])
def field(cutoff):
    a=np.fft.ifft2(np.fft.fft2(rng.normal(size=(N,N)))*np.exp(-(rad/cutoff)**2)).real
    return a/a.std()
micro=field(.13);macro=field(.014);fine=field(.05)
patina=np.clip((macro-1.0)*.26,0,.65)*np.clip(.65+fine*.15,.25,1)
base=np.array([112.,91.,57.]);oxide=np.array([64.,83.,68.])
albedo=base[None,None,:]*(1-patina[...,None])+oxide[None,None,:]*patina[...,None]+micro[...,None]*.6
rough=np.clip(.56+patina*.15+micro*.008,.49,.69)
height=np.clip(.5+micro*.1+patina*.10,0,1)
dx=(np.roll(height,-1,1)-np.roll(height,1,1))*.00006*N*.5/.6
dy=(np.roll(height,-1,0)-np.roll(height,1,0))*.00006*N*.5/.6
normal=np.stack((-dx,dy,np.ones_like(dx)),axis=-1);normal/=np.linalg.norm(normal,axis=-1)[...,None]
for key,values in [('albedo',albedo),('roughness',rough*255),('height',height*255),('normal',(normal*.5+.5)*255)]:Image.fromarray(np.rint(np.clip(values,0,255)).astype(np.uint8)).save(out/(key+'.png'))
metadata={'material': 'bronze_sheet', 'generator': 'art/tools/build_bronze_sheet.py', 'source': 'Periodic formed bronze sheet with restrained local oxide; no large crust, lettering, photographs or baked light.', 'seed': 19281114, 'meters_per_tile': 0.6, 'relief_mm': 0.06, 'maps': {'albedo': 'albedo.png', 'roughness': 'roughness.png', 'height': 'height.png', 'normal': 'normal.png'}}
metadata['map_sha256']={k:hashlib.sha256((out/(k+'.png')).read_bytes()).hexdigest() for k in metadata['maps']}
(out/'material.json').write_text(json.dumps(metadata,indent=2)+'\n',newline='\n')
for source,suffix in [('albedo','albedo'),('roughness','rough'),('normal','normal')]:shutil.copyfile(out/(source+'.png'),r/'game/assets/building/textures'/('T_ai_materials_bronze_sheet_'+suffix+'.png'))
print('bronze_sheet: deterministic calibrated source and runtime PBR maps')
