"""Scratch periodic smoke film over fine plaster; no photographic or baked light data."""
from pathlib import Path
import hashlib,json,os,shutil
import numpy as np
from PIL import Image
ROOT=next(p for p in Path(__file__).resolve().parents if (p/'game/project.godot').is_file());out_root=Path(os.environ.get('SMOKED_PLASTER_OUTPUT',str(ROOT)));out=out_root/'art/textures/procedural/smoked_plaster';out.mkdir(parents=True,exist_ok=True)
size=2048;rng=np.random.default_rng(19281119);freq=np.fft.fftfreq(size);rad=np.hypot(freq[:,None],freq[None,:])
def field(cutoff):
 a=np.fft.ifft2(np.fft.fft2(rng.normal(size=(size,size)))*np.exp(-(rad/cutoff)**2)).real
 return (a-a.mean())/a.std()
smoke=field(.0014);stain=field(.004);fine=field(.12);micro=field(.28);trowel=field(.008)
# Optical deposit varies broadly; substrate relief is independent of pigment.
shade=np.clip(smoke*2.4+stain*.8+fine*.45,-7,7)
albedo=np.stack([28.2+shade,27.9+shade,28.1+shade],axis=-1)
roughness=np.clip(.935+fine*.005+stain*.006,.90,.96)
height=np.clip(.5+trowel*.08+fine*.055+micro*.024,.1,.9)
tile=1.8;relief=.00022
dx=(np.roll(height,-1,1)-np.roll(height,1,1))*relief*size*.5/tile
dy=(np.roll(height,-1,0)-np.roll(height,1,0))*relief*size*.5/tile
normal=np.stack([-dx,dy,np.ones_like(dx)],axis=-1);normal/=np.linalg.norm(normal,axis=-1)[...,None]
for name,a in [('albedo',albedo),('roughness',roughness*255),('height',height*255),('normal',(normal*.5+.5)*255)]:Image.fromarray(np.rint(np.clip(a,0,255)).astype(np.uint8)).save(out/(name+'.png'))
meta={'material':'smoked_plaster','generator':'art/tools/build_smoked_plaster.py','source':'Code-authored fine plaster relief under a heavy optical smoke film. No photographic pixels, baked illumination, lettering or invented paint chips.','seed':19281119,'meters_per_tile':tile,'relief_mm':relief*1000,'maps':{k:k+'.png' for k in ['albedo','roughness','height','normal']}}
meta['map_sha256']={k:hashlib.sha256((out/v).read_bytes()).hexdigest() for k,v in meta['maps'].items()};(out/'material.json').write_text(json.dumps(meta,indent=2)+'\n')
shipping=out_root/'game/assets/building/textures';shipping.mkdir(parents=True,exist_ok=True)
for source,suffix in [('albedo','albedo'),('roughness','rough'),('normal','normal')]:shutil.copyfile(out/(source+'.png'),shipping/('T_ai_materials_smoked_plaster_'+suffix+'.png'))
print('smoked_plaster study:',tile,'m; nominal relief',relief*1000,'mm; mean RGB',albedo.mean((0,1)).tolist())
