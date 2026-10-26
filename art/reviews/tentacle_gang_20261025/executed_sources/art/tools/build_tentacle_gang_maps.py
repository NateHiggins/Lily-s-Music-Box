"""Original deterministic epithelial PBR maps; no photographic inputs."""
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
    for suffix, pixels in [('albedo',albedo),('normal',normal),('roughness',rough)]:
        Image.fromarray(pixels.astype('uint8')).save(OUT/f'{family}_{suffix}.png')
    # Additive catalogue registration preserves other in-flight edits.
    path=ROOT/'art/data/material_catalog.json'
    catalog=json.loads(path.read_text())
    catalog['tentacle_gang_'+family]={'base_color':[1,1,1,1],'roughness':1.0,'metallic':0}
    path.write_text(json.dumps(catalog,indent=1)+'\n',newline='\n')
