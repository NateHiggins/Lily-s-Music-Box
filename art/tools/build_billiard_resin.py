"""Periodic neutral polished billiard finish, tinted per existing ball.

Code-authored albedo, roughness and microrelief; no photographic pixels,
lettering, numerals, baked highlights or global material replacement.
"""
from pathlib import Path
import hashlib,json,os,shutil
import numpy as np
from PIL import Image
ROOT=next(p for p in Path(__file__).resolve().parents if (p/'game/project.godot').is_file())
out_root=Path(os.environ.get('BILLIARD_FINISH_OUTPUT',str(ROOT)))
out=out_root/'art/textures/procedural/billiard_resin';out.mkdir(parents=True,exist_ok=True)
size=1024;rng=np.random.default_rng(19281117);freq=np.fft.fftfreq(size);radius=np.hypot(freq[:,None],freq[None,:])
def field(cutoff):
 values=np.fft.ifft2(np.fft.fft2(rng.normal(size=(size,size)))*np.exp(-(radius/cutoff)**2)).real
 return values/values.std()
fine=field(.12);micro=field(.27);broad=field(.015)
grain=fine*.22+micro*.16+broad*.35
albedo=np.stack([240+grain,240+grain,240+grain],axis=-1)
roughness=np.clip(.23+fine*.008+micro*.004+broad*.006,.19,.27)
height=np.clip(.50+fine*.05+micro*.016,0,1)
tile=.18;relief=.000008
dx=(np.roll(height,-1,1)-np.roll(height,1,1))*relief*size*.5/tile
dy=(np.roll(height,-1,0)-np.roll(height,1,0))*relief*size*.5/tile
normal=np.stack((-dx,dy,np.ones_like(dx)),axis=-1);normal/=np.linalg.norm(normal,axis=-1)[...,None]
for name,values in [('albedo',albedo),('roughness',roughness*255),('height',height*255),('normal',(normal*.5+.5)*255)]:
 Image.fromarray(np.rint(np.clip(values,0,255)).astype(np.uint8)).save(out/(name+'.png'))
metadata={'material':'billiard_resin','generator':'art/tools/build_billiard_resin.py','source':'Code-authored neutral polished finish; individual source balls retain their distinct colour through instance tint.','seed':19281117,'meters_per_tile':tile,'relief_mm':relief*1000,'maps':{k:k+'.png' for k in ['albedo','roughness','height','normal']}}
metadata['map_sha256']={k:hashlib.sha256((out/v).read_bytes()).hexdigest() for k,v in metadata['maps'].items()}
(out/'material.json').write_text(json.dumps(metadata,indent=2)+'\n',newline='\n')
shipping=out_root/'game/assets/building/textures';shipping.mkdir(parents=True,exist_ok=True)
for source,suffix in [('albedo','albedo'),('roughness','rough'),('normal','normal')]:shutil.copyfile(out/(source+'.png'),shipping/('T_ai_materials_billiard_resin_'+suffix+'.png'))
print('billiard_resin: nonmetallic polished periodic finish; 0.18 m tile; 0.008 mm relief')
