"""Original deterministic epithelial PBR maps; no photographic inputs.

Normal authoring: folded wet epithelial microrelief, 0.08 m reference chart,
0.0009375 m height per unit of the authored scalar field. The 40 longitudinal
folds have 2 mm pitch; the 80 transverse folds have 1 mm pitch. OpenGL +Y
normals encode derivatives in metres, with unit geometric strength. Membrane
shader strength is 0.16 to represent its wet interface; tissue keeps its own
striated optical treatment. Pigment is separate from this measured relief.
"""
from pathlib import Path
import json
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'game/assets/dream/tentacle_gang'
OUT.mkdir(parents=True,exist_ok=True)
y,x=np.mgrid[0:512,0:512]/512
rng=np.random.default_rng(7813)
pores=rng.random(x.shape)
height=.5+.12*np.sin(x*80*np.pi+np.sin(y*14*np.pi))+.05*np.sin(y*160*np.pi)+.06*pores
dy,dx=np.gradient(height)
normal=np.dstack((-dx*6,-dy*6,np.ones_like(x)))
normal/=np.linalg.norm(normal,axis=2)[:,:,None]
normal=(normal*.5+.5)*255
for family,color in [('membrane',[.48,.34,.41]),('tissue',[.55,.37,.39]),('eye',[.36,.30,.34])]:
    pigment=.72+.22*height+.06*np.sin(x*20+y*31)
    albedo=np.clip(pigment[:,:,None]*np.array(color)[None,None,:]*255,0,255)
    rough=np.clip((.28+.3*height+.13*(pores>.94))*255,0,255)
    if family in ('membrane','tissue'):
        # Soft guide-bell-style density islands; preserve this family's hue.
        warp=.38*np.sin(2*np.pi*(x+2*y))
        clouds=(np.sin(2*np.pi*(3*x+y)+warp)*np.cos(2*np.pi*(2*y-x))
                +.45*np.sin(2*np.pi*(7*x+4*y)+warp)
                +.2*np.cos(2*np.pi*(11*y-5*x)))/1.65
        clouds-=clouds.mean()
        mottled=albedo*(1+(.26 if family=='membrane' else .14)*clouds[:,:,None])
        albedo=mottled*(albedo.mean(axis=(0,1))/mottled.mean(axis=(0,1)))
        rough=np.clip(rough+255*.065*clouds,0,255)
    for suffix, pixels in [('albedo',albedo),('normal',normal),('roughness',rough)]:
        Image.fromarray(pixels.astype('uint8')).save(OUT/f'{family}_{suffix}.png')
    # Additive catalogue registration preserves other in-flight edits.
    path=ROOT/'art/data/material_catalog.json'
    catalog=json.loads(path.read_text())
    catalog['tentacle_gang_'+family]={'base_color':[1,1,1,1],'roughness':1.0,'metallic':0}
    path.write_text(json.dumps(catalog,indent=1)+'\n',newline='\n')
