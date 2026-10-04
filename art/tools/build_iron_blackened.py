"""Periodic bare blackened iron for laundry irons and mechanical hardware.

Extends the existing code-authored periodic PBR workflow. No reference image,
lettering, paint chips, baked highlights or shadow is included in these maps.
"""
from pathlib import Path
import hashlib,json,os,shutil
import numpy as np
from PIL import Image

ROOT=Path(__file__).resolve().parents[2]
out_root=Path(os.environ.get('IRON_FINISH_OUTPUT',str(ROOT)))
out=out_root/'art/textures/procedural/iron_blackened';out.mkdir(parents=True,exist_ok=True)
size=1024;rng=np.random.default_rng(19281116);freq=np.fft.fftfreq(size);radius=np.hypot(freq[:,None],freq[None,:])
def field(cutoff):
    values=np.fft.ifft2(np.fft.fft2(rng.normal(size=(size,size)))*np.exp(-(radius/cutoff)**2)).real
    return values/values.std()
fine=field(.10);micro=field(.24);broad=field(.009)
grain=fine*1.6+micro*.65+broad*1.1
albedo=np.stack([52+grain,53+grain,54+grain],axis=-1)
roughness=np.clip(.72+fine*.024+micro*.011,.61,.83)
height=np.clip(.50+fine*.10+micro*.035,0,1)
tile=.4;relief=.00008
dx=(np.roll(height,-1,1)-np.roll(height,1,1))*relief*size*.5/tile
dy=(np.roll(height,-1,0)-np.roll(height,1,0))*relief*size*.5/tile
normal=np.stack((-dx,dy,np.ones_like(dx)),axis=-1);normal/=np.linalg.norm(normal,axis=-1)[...,None]
for name,values in [('albedo',albedo),('roughness',roughness*255),('height',height*255),('normal',(normal*.5+.5)*255)]:
    Image.fromarray(np.rint(np.clip(values,0,255)).astype(np.uint8)).save(out/(name+'.png'))
metadata={'material':'iron_blackened','generator':'art/tools/build_iron_blackened.py','source':'Code-authored periodic casting grain and black oxide; no paint or photographic pixels.','seed':19281116,'meters_per_tile':tile,'relief_mm':relief*1000,'maps':{k:k+'.png' for k in ['albedo','roughness','height','normal']}}
metadata['map_sha256']={k:hashlib.sha256((out/v).read_bytes()).hexdigest() for k,v in metadata['maps'].items()}
(out/'material.json').write_text(json.dumps(metadata,indent=2)+'\n',encoding='utf-8',newline='\n')
shipping=out_root/'game/assets/building/textures';shipping.mkdir(parents=True,exist_ok=True)
for source,suffix in [('albedo','albedo'),('roughness','rough'),('normal','normal')]:
    shutil.copyfile(out/(source+'.png'),shipping/('T_ai_materials_iron_blackened_'+suffix+'.png'))
print('iron_blackened: periodic 0.4-m casting grain; 0.08-mm relief; three runtime maps')
