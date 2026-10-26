"""Custom UV tissue stock: pores/folds in relief, mineral draw marks in gold.

No anatomy, lettering, lighting or reference imagery is baked into these maps.
Metre tile .04; membrane relief 0.25 mm; mineral relief 0.004 mm; OpenGL normals.
"""
from pathlib import Path
import json
import hashlib
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]

def main():
    size = 128
    y,x = np.mgrid[:size,:size]/size
    catalog_path = ROOT/'art/data/material_catalog.json'
    catalog = json.loads(catalog_path.read_text())
    mapping_path = ROOT/'art/textures/catalog_mapping.json'
    mapping = json.loads(mapping_path.read_text())
    for substance, color, rough, relief in [('membrane',(.78,.76,.66),.28,.00025),('organ',(.55,.43,.32),.64,.00012),('mineral',(.83,.54,.18),.22,.000004)]:
        key = 'tardigrade_'+substance
        output = ROOT/'art/textures/ai_materials'/key
        runtime = ROOT/'game/assets/dream/microscopy'/key
        output.mkdir(parents=True,exist_ok=True)
        runtime.mkdir(parents=True,exist_ok=True)
        folds = np.sin(2*np.pi*(3*x+2*y))*.15
        pores = np.zeros_like(x)
        rng=np.random.default_rng(240304)
        for px,py in rng.random((28,2)):
            dxp=(x-px+.5)%1-.5;dyp=(y-py+.5)%1-.5
            pores-=.18*np.exp(-(dxp*dxp+dyp*dyp)/(.035**2))
        height = .5+folds+pores if substance!='mineral' else .5+.2*np.sin(2*np.pi*21*x)
        dx=(np.roll(height,-1,1)-np.roll(height,1,1))*relief*size/.08
        dy=(np.roll(height,-1,0)-np.roll(height,1,0))*relief*size/.08
        normal=np.stack((-dx,dy,np.ones_like(x)),axis=-1)
        normal/=np.linalg.norm(normal,axis=-1)[...,None]
        maps={'albedo':np.array(color)[None,None,:]*(.94+.06*height[...,None]),
              'roughness':rough+.12*(height-.5),'normal':normal*.5+.5}
        if substance=='membrane':
            # Same soft, multi-scale density islands as the guide-bell, with
            # scalar modulation only: retain warm stock and Euplotes' cool tint.
            warp=.38*np.sin(2*np.pi*(x+2*y))
            clouds=(np.sin(2*np.pi*(3*x+y)+warp)*np.cos(2*np.pi*(2*y-x))
                    +.45*np.sin(2*np.pi*(7*x+4*y)+warp)
                    +.2*np.cos(2*np.pi*(11*y-5*x)))/1.65
            clouds-=clouds.mean()
            original=maps['albedo']
            mottled=original*(1+.26*clouds[...,None])
            # Preserve mean RGB and therefore the authored overall palette.
            maps['albedo']=mottled*(original.mean(axis=(0,1))/mottled.mean(axis=(0,1)))
            maps['roughness']+=.065*clouds
        for name,value in maps.items():
            image=Image.fromarray(np.round(np.clip(value,0,1)*255).astype('uint8'))
            image.save(output/(name+'.png'))
            image.save(runtime/(name+'.png'))
        metadata={'material':key,'source':str(Path(__file__).relative_to(ROOT)).replace('\\','/'),
                  'source_sha256':hashlib.sha256(Path(__file__).read_bytes().replace(b'\r\n',b'\n')).hexdigest(),
                  'meters_per_tile':.04,'maps':{name:name+'.png' for name in maps},
                  'mottling':'guide-bell soft warped density islands; mean RGB preserved' if substance=='membrane' else 'unchanged',
                  'normal_authoring':{'construction':'membrane pores and reserve folds' if substance!='mineral' else 'longitudinal mineral draw marks','relief_m':relief,'convention':'OpenGL','strength':1.0}}
        (output/'material.json').write_text(json.dumps(metadata,indent=2)+'\n')
        catalog[key]={'base_color':list(color)+[1.0],'roughness':rough,'metallic':1 if substance=='mineral' else 0}
        mapping[key]='ai_materials/'+key
    for path,data in [(catalog_path,catalog),(mapping_path,mapping)]:
        newline='\r\n' if b'\r\n' in path.read_bytes() else '\n'
        path.write_bytes((json.dumps(data,indent=1)+'\n').replace('\n',newline).encode())

if __name__=='__main__': main()
