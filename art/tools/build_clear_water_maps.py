"""Authored periodic water microripple PBR maps, without baked reflections.

Uniform diffuse color is tinted by the existing water owner. The geometric
flow and fill state stay with TapProp; these maps supply only surface stock.
"""
from pathlib import Path
import hashlib,json,shutil
import numpy as np
from PIL import Image
import generate_runtime_materials
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'art/textures/ai_materials/water_clear'

def main():
    OUT.mkdir(parents=True,exist_ok=True)
    size=256;metres=.25
    y,x=np.mgrid[:size,:size]/size
    height=.5+.13*np.sin(2*np.pi*(3*x+2*y))+.07*np.sin(2*np.pi*(7*x-5*y))
    relief=.06 # mm; still water, not a sculpted ocean tile
    dx=(np.roll(height,-1,1)-np.roll(height,1,1))*relief*.001*size/(2*metres)
    dy=(np.roll(height,-1,0)-np.roll(height,1,0))*relief*.001*size/(2*metres)
    normal=np.stack((-dx,dy,np.ones_like(height)),axis=-1)
    normal/=np.linalg.norm(normal,axis=-1)[...,None]
    maps={'albedo':np.ones((size,size,3)), 'roughness':np.full((size,size),.08),
          'height':height,'normal':normal*.5+.5}
    for name,value in maps.items():
        Image.fromarray(np.round(np.clip(value,0,1)*255).astype('uint8')).save(OUT/(name+'.png'),optimize=True)
    source=Path(__file__)
    metadata={'material':'water_clear','source':source.relative_to(ROOT).as_posix(),
              'source_sha256':hashlib.sha256(source.read_text().replace('\r\n','\n').encode()).hexdigest(),
              'meters_per_tile':metres,'relief_mm':relief,'maps':{k:k+'.png' for k in maps},
              'model':'periodic_still_water_microrelief_v1','albedo_policy':'Uniform neutral diffuse tint; no baked reflections.'}
    (OUT/'material.json').write_text(json.dumps(metadata,indent=2)+'\n',newline='\n')
    mapping=ROOT/'art/textures/catalog_mapping.json';data=json.loads(mapping.read_text());data['water_clear']='ai_materials/water_clear';mapping.write_text(json.dumps(data,indent=1,sort_keys=True)+'\n',newline='\n')
    for name,suffix in [('albedo','albedo'),('roughness','rough'),('normal','normal')]:
        shutil.copyfile(OUT/(name+'.png'),ROOT/'game/assets/building/textures'/('T_ai_materials_water_clear_'+suffix+'.png'))
    generate_runtime_materials.generate()
    print('Water stock: custom periodic microripple; 256px; .25m per tile; 0.06mm relief')

if __name__=='__main__':main()
