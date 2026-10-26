"""Viscous residue stock: 8 mm folds, 0.3 mm relief, +Y OpenGL normals.
Physical chart 0.08 m; rough char islands interrupt wet metallic fluid.
Original mathematical recipe, no photographic inputs or lettering.
"""
from pathlib import Path
import numpy as np
from PIL import Image
R=Path(__file__).resolve().parents[2];out=R/'game/assets/dream/tentacle_gang'
y,x=np.mgrid[0:512,0:512]/512
fold=np.sin(2*np.pi*(10*x+.7*np.sin(2*np.pi*3*y)))
eddies=np.sin(2*np.pi*3*x+2*np.sin(2*np.pi*2*y))*np.cos(2*np.pi*4*y)
char=np.clip((eddies-.35)*2,0,1)
h=.0003*fold+.00012*char
dy,dx=np.gradient(h,.08/512)
n=np.dstack((-dx,-dy,np.ones_like(x)));n/=np.linalg.norm(n,axis=2)[:,:,None]
a=np.repeat((.78+.06*fold)[:,:,None],3,axis=2)
for channel,data in [('albedo',a),('normal',n*.5+.5),('roughness',.18+.04*fold+.08*char)]:
 Image.fromarray(np.uint8(np.clip(data,0,1)*255)).save(out/('residue_'+channel+'.png'))
