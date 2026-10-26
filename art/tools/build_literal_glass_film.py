"""Subtle residue albedo for the existing glassish literal-alpha recipe.

Keeps the authored pane tint/opacity and existing drawn-glass roughness/normal.
Original deterministic surface-film pattern, 1.6 m tile; no reference pixels.
"""
from pathlib import Path
import json
import numpy as np
from PIL import Image
ROOT=Path(__file__).resolve().parents[2]
y,x=np.mgrid[0:512,0:512]/512
streak=(.5+.5*np.sin(2*np.pi*(11*x+.2*np.sin(2*np.pi*y))))**6
patch=.5+.5*np.sin(2*np.pi*(2*x+y))*np.cos(2*np.pi*3*y)
film=1.0-.018*streak*patch
rgb=np.repeat(film[:,:,None],3,axis=2)
Image.fromarray(np.round(rgb*255).astype('uint8'),'RGB').save(ROOT/'game/assets/building/textures/T_glass_film_albedo.png')
recipe={'material_key':'glassish','scope':'literal-alpha retained panes only; clear dielectric shader unchanged',
 'tile_m':1.6,'albedo':'T_glass_film_albedo.png','roughness':'T_glass_rough.png','normal':'T_glass_normal.png',
 'normal_convention':'OpenGL','tint_and_alpha':'retained from native material','film_attenuation_max':.018,
 'source':'art/tools/build_literal_glass_film.py','reference_pixels':False}
(ROOT/'art/textures/generated/glass/film_recipe.json').write_text(json.dumps(recipe,indent=2)+'\n')
