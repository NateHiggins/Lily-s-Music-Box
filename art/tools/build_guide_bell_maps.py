"""Deterministic custom cell membrane/tissue PBR recipes, no reference pixels."""
import json
from pathlib import Path
import numpy as np
from PIL import Image
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'game/assets/dream/guide_bell'
OUT.mkdir(parents=True,exist_ok=True)
n=256
y,x=np.mgrid[:n,:n]/n
for name,color,rough in [('membrane',(.65,.56,.62),.27),('tissue',(.48,.35,.43),.48)]:
    height=.5+.16*np.sin(x*np.pi*48+np.sin(y*np.pi*12))+.08*np.sin((x*29+y*17)*np.pi*2)
    grain=np.random.default_rng(61025).random((n,n))-.5
    albedo=np.clip(np.array(color)[None,None,:]*(.85+.18*height[...,None]+.08*grain[...,None]),0,1)
    roughness=np.clip(rough+.12*(height-.5)+.04*grain,0,1)
    if name=='membrane':
        # Periodic, soft cellular density islands at several scales; not speckle.
        warp=.38*np.sin(2*np.pi*(x+2*y))
        clouds=(np.sin(2*np.pi*(3*x+y)+warp)*np.cos(2*np.pi*(2*y-x))
                +.45*np.sin(2*np.pi*(7*x+4*y)+warp)
                +.2*np.cos(2*np.pi*(11*y-5*x)))/1.65
        albedo=np.clip(albedo*(1+.26*clouds[...,None])
                       +clouds[...,None]*np.array([.025,-.01,.035]),0,1)
        roughness=np.clip(.23+.085*clouds+.025*(height-.5),.12,.36)
    dx=(np.roll(height,-1,1)-np.roll(height,1,1))*.25
    dy=(np.roll(height,-1,0)-np.roll(height,1,0))*.25
    normal=np.stack((-dx,-dy,np.ones_like(dx)),axis=-1); normal/=np.linalg.norm(normal,axis=-1)[...,None]
    for channel,values in [('albedo',albedo),('roughness',roughness),('normal',normal*.5+.5)]:
        Image.fromarray((values*255).astype('uint8')).save(OUT/f'{name}_{channel}.png')
    (OUT/f'{name}_recipe.json').write_text(json.dumps({'material_key':'guide_bell_'+name,'source':'art/tools/build_guide_bell_maps.py','provenance':'analytic cortical fibrils and seeded cellular granules','tile_scale_m':.16,'normal_convention':'OpenGL','maps':{c:f'{name}_{c}.png' for c in ['albedo','normal','roughness']}},indent=2)+'\n')
catalog=ROOT/'art/data/material_catalog.json'
data=json.loads(catalog.read_text())
for name in ['membrane','tissue']: data['guide_bell_'+name]={'base_color':[1,1,1,1],'roughness':1.0,'metallic':0}
catalog.write_text(json.dumps(data,indent=1)+'\n',newline='\n')
