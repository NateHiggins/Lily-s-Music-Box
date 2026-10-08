"""Stage untouched generated zinc pigment with independently authored coating data."""
from pathlib import Path
import hashlib, json, shutil
import numpy as np
from PIL import Image
import generate_runtime_materials

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'art/textures/ai_sources/zinc_quiet_20261008.png'
OUT = ROOT / 'art/textures/ai_materials/zinc_quiet'
OUT.mkdir(parents=True, exist_ok=True)
SIZE, TILE, RELIEF = 512, .60, .008
rng = np.random.default_rng(19281009)
field = rng.standard_normal((SIZE, SIZE))
freq = np.fft.fftfreq(SIZE)
x, y = np.meshgrid(freq, freq)
field = np.fft.ifft2(np.fft.fft2(field) * np.exp(-((x/.23)**2+(y/.23)**2))).real
field /= field.std()
height = np.clip(.5 + field*.06, .1, .9)
dx = (np.roll(height,-1,1)-np.roll(height,1,1))*RELIEF*.001*SIZE/(2*TILE)
dy = (np.roll(height,-1,0)-np.roll(height,1,0))*RELIEF*.001*SIZE/(2*TILE)
normal = np.stack((-dx,dy,np.ones_like(height)),axis=-1)
normal /= np.linalg.norm(normal,axis=-1)[...,None]
for name, value in [('height',height),('normal',normal*.5+.5),('roughness',np.clip(.58+field*.007,.54,.62))]:
    Image.fromarray(np.round(np.clip(value,0,1)*255).astype('uint8')).save(OUT/(name+'.png'), optimize=True)
shutil.copyfile(SOURCE, OUT/'albedo.png')
metadata = {'material':'zinc_quiet','source':SOURCE.relative_to(ROOT).as_posix(),
    'source_sha256':hashlib.sha256(SOURCE.read_bytes()).hexdigest(),
    'generator':'art/tools/build_quiet_zinc.py','meters_per_tile':TILE,
    'maps':{'albedo':'albedo.png','roughness':'roughness.png','height':'height.png','normal':'normal.png'},
    'relief_mm':RELIEF,'height_model':'independent_periodic_zinc_coating_v1',
    'base_color_policy':'Generated pixels copied byte-exact. Spangle is pigment, never raised aggregate.',
    'roughness_mean':.58}
(OUT/'material.json').write_text(json.dumps(metadata,indent=2)+'\n',newline='\n')
provenance={'evidence_class':'INERT','generation':'built-in image_gen','generated_utc_date':'2026-10-08',
    'prompt':'art/textures/ai_sources/zinc_quiet_20261008.prompt.txt','source':metadata['source'],
    'sha256':metadata['source_sha256'],'scope':'New quiet galvanized coating pigment; independent near-flat microrelief.'}
(SOURCE.with_suffix('.source.json')).write_text(json.dumps(provenance,indent=2)+'\n',newline='\n')
stage=ROOT/'game/assets/building/textures'
for a,b in [('albedo','albedo'),('roughness','rough'),('normal','normal')]:
    shutil.copyfile(OUT/(a+'.png'),stage/('T_ai_materials_zinc_quiet_'+b+'.png'))
generate_runtime_materials.generate()
print('Quiet zinc staged; source pixels unchanged; independent coating relief:',RELIEF,'mm')
