"""Fine-scale washer PBR, without baked light, rust islands or hardware."""
from pathlib import Path
import hashlib,json,shutil
import numpy as np
from PIL import Image
import generate_runtime_materials
ROOT=Path(__file__).resolve().parents[2]
SIZE=512
SPECS={'washer_zinc':(.12,[.62,.64,.65,1],.43,.94,.006),
       'washer_enamel':(.10,[.89,.88,.83,1],.24,0.0,.012),
       'washer_brass':(.08,[.71,.53,.23,1],.31,1.0,.004),
       'washer_rubber':(.10,[.095,.10,.092,1],.66,0.0,.024)}
for number,(key,(metres,color,roughness,metallic,relief_mm)) in enumerate(SPECS.items()):
 out=ROOT/'art/textures/procedural'/key;out.mkdir(parents=True,exist_ok=True)
 rng=np.random.default_rng(19281013+number);f=np.fft.fftfreq(SIZE);fx,fy=np.meshgrid(f,f)
 def noise(cutoff):
  a=np.fft.ifft2(np.fft.fft2(rng.standard_normal((SIZE,SIZE)))*np.exp(-((fx/cutoff)**2+(fy/cutoff)**2))).real
  return (a-a.mean())/a.std()
 micro=noise(.26);fine=noise(.12)
 height=np.clip(.5+.045*micro+.02*fine,.1,.9)
 slopes=(np.roll(height,-1,1)-np.roll(height,1,1))*relief_mm*.001*SIZE/(2*metres)
 slopes_y=(np.roll(height,-1,0)-np.roll(height,1,0))*relief_mm*.001*SIZE/(2*metres)
 normal=np.stack((-slopes,slopes_y,np.ones_like(height)),-1);normal/=np.linalg.norm(normal,axis=-1)[...,None]
 rough=np.clip(roughness+fine*(.009 if key=='washer_rubber' else .004)+micro*.003,.08,.9)
 def save(a,name):Image.fromarray(np.rint(np.clip(a,0,1)*255).astype('uint8')).save(out/(name+'.png'),optimize=True)
 if key=='washer_zinc':shutil.copyfile(ROOT/'art/textures/ai_sources/washer_zinc_20261013.png',out/'albedo.png')
 else:
  pigment=fine[...,None]*.0015+micro[...,None]*.0008
  save(np.array(color[:3])+pigment,'albedo')
 save(rough,'roughness');save(normal*.5+.5,'normal');save(height,'height')
 meta={'material':key,'generator':'art/tools/build_washer_materials.py','meters_per_tile':metres,'relief_mm':relief_mm,
       'maps':{'albedo':'albedo.png','roughness':'roughness.png','normal':'normal.png','height':'height.png'}}
 if key=='washer_zinc':
  meta['source']='art/textures/ai_sources/washer_zinc_20261013.png';meta['source_sha256']=hashlib.sha256((ROOT/meta['source']).read_bytes()).hexdigest()
 meta['map_sha256']={k:hashlib.sha256((out/v).read_bytes()).hexdigest() for k,v in meta['maps'].items()}
 (out/'material.json').write_text(json.dumps(meta,indent=2)+'\n',encoding='utf-8',newline='\n')
 for src,suffix in [('albedo','albedo'),('roughness','rough'),('normal','normal')]:shutil.copyfile(out/(src+'.png'),ROOT/'game/assets/building/textures'/('T_ai_materials_'+key+'_'+suffix+'.png'))
catalog_path=ROOT/'art/data/material_catalog.json';catalog=json.loads(catalog_path.read_text(encoding='utf-8'))
mapping_path=ROOT/'art/textures/catalog_mapping.json';mapping=json.loads(mapping_path.read_text(encoding='utf-8'))
for key,(metres,color,roughness,metallic,relief) in SPECS.items():
 catalog[key]={'base_color':color,'roughness':roughness,'metallic':metallic}
 mapping[key]='procedural/'+key
catalog_path.write_text(json.dumps(catalog,indent=1)+'\n',encoding='utf-8',newline='\n')
mapping_path.write_text(json.dumps(mapping,indent=1)+'\n',encoding='utf-8',newline='\n')
print('Washer maps built; contract files:',generate_runtime_materials.generate())
