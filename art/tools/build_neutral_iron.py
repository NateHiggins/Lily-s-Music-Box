"""Stage the untouched generated iron colour plate with conservative PBR data.

The colour pixels are copied exactly. Periodic physical microrelief and
roughness are authored data, independent of the picture's pigment marks.
"""
from pathlib import Path
import hashlib,json,shutil
import numpy as np
from PIL import Image
import generate_runtime_materials
ROOT=Path(__file__).resolve().parents[2]
SOURCE=ROOT/'art/textures/ai_sources/iron_neutral_20261008.png'
OUT=ROOT/'art/textures/ai_materials/iron_neutral'
OUT.mkdir(parents=True,exist_ok=True)
metres=.4;size=512;relief=.035
rng=np.random.default_rng(19281008)
f=np.fft.fftfreq(size);fx,fy=np.meshgrid(f,f)
def noise(cutoff):
    a=np.fft.ifft2(np.fft.fft2(rng.standard_normal((size,size)))*np.exp(-((fx/cutoff)**2+(fy/cutoff)**2))).real
    return (a-a.mean())/a.std()
grain=noise(.18);micro=noise(.38)
height=.5+grain*.07+micro*.035
height=np.clip(height,.1,.9)
dx=(np.roll(height,-1,1)-np.roll(height,1,1))*relief*.001*size/(2*metres)
dy=(np.roll(height,-1,0)-np.roll(height,1,0))*relief*.001*size/(2*metres)
normal=np.stack((-dx,dy,np.ones_like(height)),axis=-1);normal/=np.linalg.norm(normal,axis=-1)[...,None]
rough=np.clip(.68+grain*.009+micro*.006,.62,.74)
def save(value,name):Image.fromarray(np.round(np.clip(value,0,1)*255).astype('uint8')).save(OUT/name,optimize=True)
save(height,'height.png');save(normal*.5+.5,'normal.png');save(rough,'roughness.png')
shutil.copyfile(SOURCE,OUT/'albedo.png')
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
metadata={'material':'iron_neutral','source':SOURCE.relative_to(ROOT).as_posix(),'source_sha256':sha(SOURCE),
          'generator':'art/tools/build_neutral_iron.py','meters_per_tile':metres,
          'maps':{'albedo':'albedo.png','roughness':'roughness.png','height':'height.png','normal':'normal.png'},
          'relief_mm':relief,'height_model':'independent_periodic_worked_iron_microrelief_v1',
          'base_color_policy':'Generated pixels retained byte-exact; no relighting, painted hardware or pigment-to-height conversion.',
          'roughness_mean':float(rough.mean()),'maximum_normal_slope':float(np.sqrt(dx*dx+dy*dy).max())}
(OUT/'material.json').write_text(json.dumps(metadata,indent=2)+'\n',newline='\n')
stage=ROOT/'game/assets/building/textures'
for a,b in [('albedo','albedo'),('roughness','rough'),('normal','normal')]:shutil.copyfile(OUT/(a+'.png'),stage/('T_ai_materials_iron_neutral_'+b+'.png'))
changed=generate_runtime_materials.generate()
print('Neutral iron:',Image.open(SOURCE).size,'source unchanged;',relief,'mm relief range; staged 3 runtime maps;',len(changed),'contract files')
