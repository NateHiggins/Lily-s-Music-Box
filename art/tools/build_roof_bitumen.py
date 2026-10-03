"""Deterministic, unlit periodic PBR bitumen grain; no photographs or lettering.

The material's relief is authored independently from its albedo. Existing
catalogue and runtime generators remain the shipping authorities.
"""
from pathlib import Path
import hashlib, json, shutil
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
TARGET = ROOT/'art/textures/procedural/roof_bitumen'
TARGET.mkdir(parents=True, exist_ok=True)
SIZE = 1024
SEED = 19281110
rng = np.random.default_rng(SEED)
freq = np.fft.fftfreq(SIZE)
radius = np.hypot(freq[:,None], freq[None,:])
def field(cutoff):
    f = rng.normal(size=(SIZE,SIZE))
    result = np.fft.ifft2(np.fft.fft2(f)*np.exp(-(radius/cutoff)**2)).real
    return result / result.std()
micro = field(.22)
grain = field(.075)
macro = field(.006)
# Quiet oxidised binder with fine mineral granules. No fake directional light,
# road-sized cracks, painted marks or repeating fixture-sized landmarks.
colour = np.clip(47 + macro*1.4 + grain*2.2 + micro*1.4, 30, 68)
albedo = np.stack((colour*1.025,colour,colour*.965),axis=-1)
rough = np.clip(.86 + grain*.025 + micro*.014, .75, .96)
height = np.clip(.5 + grain*.085 + micro*.045, 0, 1)
# OpenGL tangent normal from the authored 0.6 mm relief and 1 m tile.
dx = (np.roll(height,-1,1)-np.roll(height,1,1))*.0006*SIZE*.5
dy = (np.roll(height,-1,0)-np.roll(height,1,0))*.0006*SIZE*.5
normal = np.stack((-dx,dy,np.ones_like(dx)),axis=-1)
normal /= np.linalg.norm(normal,axis=-1)[...,None]
maps = {'albedo':albedo, 'roughness':rough*255, 'height':height*255,
        'normal':(normal*.5+.5)*255}
for key, values in maps.items():
    Image.fromarray(np.rint(np.clip(values,0,255)).astype(np.uint8)).save(TARGET/(key+'.png'),optimize=True)
metadata = {'material':'roof_bitumen','generator':'art/tools/build_roof_bitumen.py',
    'source':'Deterministic periodic procedural grain; no photographs, AI plate or lettering.',
    'seed':SEED,'meters_per_tile':1.0,'relief_mm':.6,
    'maps':{key:key+'.png' for key in maps},
    'map_sha256':{key:hashlib.sha256((TARGET/(key+'.png')).read_bytes()).hexdigest() for key in maps}}
(TARGET/'material.json').write_text(json.dumps(metadata,indent=2)+'\n',newline='\n')
shipping = ROOT/'game/assets/building/textures'
for source, suffix in [('albedo','albedo'),('roughness','rough'),('normal','normal')]:
    shutil.copyfile(TARGET/(source+'.png'),shipping/('T_ai_materials_roof_bitumen_'+suffix+'.png'))
print('Bitumen: deterministic 1024 px / 1 m periodic albedo, roughness, height and tangent-normal maps.')
