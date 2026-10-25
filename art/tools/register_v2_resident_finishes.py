"""Deterministic V2 atlas finish prototype. Source meshes and V1 maps are read-only."""
from pathlib import Path
import json,hashlib,shutil
import numpy as np
from PIL import Image,ImageFilter
ROOT=Path(__file__).resolve().parents[2]
profiles=json.loads((ROOT/'game/data/resident_animation_profiles.json').read_text(encoding='utf8'))
schedules=json.loads((ROOT/'game/data/resident_schedules.json').read_text(encoding='utf8'))['residents']
assert len(profiles)==18 and {p['slug'] for p in profiles}==set(schedules)
rows=[{'resident':p['slug'],'model':'game/assets/characters/'+p['slug']+'/'+p['slug']+'.gltf'} for p in profiles]
OUT=ROOT/'art/textures/library'
report=[]
for row in rows:
 source=ROOT/row['model'];gltf=json.loads(source.read_text(encoding='utf8'));m=gltf['materials'][0];pbr=m.get('pbrMetallicRoughness',{})
 def image_path(texture):return source.parent/gltf['images'][gltf['textures'][texture['index']]['source']]['uri']
 albedo=image_path(pbr['baseColorTexture']);normal=image_path(m['normalTexture']) if 'normalTexture' in m else None;rough=image_path(pbr['metallicRoughnessTexture']) if 'metallicRoughnessTexture' in pbr else None
 key='resident_'+row['resident'];folder=OUT/key;folder.mkdir(exist_ok=True)
 im=Image.open(albedo).convert('RGB');original=im.size
 if max(im.size)>2048:im.thumbnail((2048,2048),Image.Resampling.LANCZOS)
 im.save(folder/'albedo.png');rgb=np.asarray(im,dtype=np.float32)/255.;luma=rgb@np.array([.2126,.7152,.0722],dtype=np.float32)
 if rough:
  # glTF metallic-roughness stores perceptual roughness in GREEN.
  rough_image=Image.open(rough).convert('RGB').getchannel('G').resize(im.size,Image.Resampling.LANCZOS)
 else:
  sat=rgb.max(2)-rgb.min(2)
  rough_image=Image.fromarray(np.round(np.clip(.74+.10*(1-luma)+.03*sat,.65,.9)*255).astype('uint8'))
 rough_image.save(folder/'roughness.png')
 if normal:Image.open(normal).convert('RGB').resize(im.size,Image.Resampling.LANCZOS).save(folder/'normal.png')
 else:
  # Restrained, nonperiodic atlas detail. Do not turn broad painted shading
  # into displacement, tiled cloth, or geometry. A two-pixel high-pass only.
  gray=im.convert('L');low=np.asarray(gray.filter(ImageFilter.GaussianBlur(2)),dtype=np.float32)/255.
  height=(luma-low)*.018;dy,dx=np.gradient(height)
  n=np.stack((-dx,dy,np.ones_like(dx)),axis=-1);n/=np.linalg.norm(n,axis=-1,keepdims=True)
  Image.fromarray(np.round((n*.5+.5)*255).astype('uint8')).save(folder/'normal.png')
 for channel,suffix in [('albedo','albedo'),('roughness','rough'),('normal','normal')]:
  shutil.copyfile(folder/(channel+'.png'),ROOT/('game/assets/building/textures/T_library_'+key+'_'+suffix+'.png'))
 sources=[albedo]+([normal] if normal else [])+([rough] if rough else [])
 metadata={'material':key,'source':'existing approved V1 character; original UV atlas and rig retained','generator':'art/tools/register_v2_resident_finishes.py','meters_per_tile':1.,'projection':'unique whole-character atlas; normalized UVs, no repetition','maps':{'albedo':'albedo.png','roughness':'roughness.png','normal':'normal.png'},'source_sha256':{s.relative_to(ROOT).as_posix():hashlib.sha256(s.read_bytes()).hexdigest() for s in sources}}
 (folder/'material.json').write_bytes((json.dumps(metadata,indent=2)+'\n').encode('utf8'))
 report.append({'resident':row['resident'],'original_size':original,'atlas_size':im.size,'normal':'retained source' if normal else 'subtle high-pass atlas relief, no geometric displacement','metallic':0,'model_unchanged_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'sources':{s.relative_to(ROOT).as_posix():hashlib.sha256(s.read_bytes()).hexdigest() for s in sources},'outputs':{f.name:hashlib.sha256(f.read_bytes()).hexdigest() for f in folder.glob('*.png')}})
(ROOT/'art/reviews/v2_resident_cast_20261024').mkdir(exist_ok=True)
(ROOT/'art/reviews/v2_resident_cast_20261024/finish_generation.json').write_bytes((json.dumps({'evidence_class':'INERT','scope':'Generated local V2 atlases. Original character models unchanged; no runtime qualification.','residents':report},indent=2)+'\n').encode('utf8'))
print('Built',len(report),'original-UV atlas finish sets; V1 sources unchanged')

keys=['resident_'+r['resident'] for r in rows]
for name in ['art/data/material_catalog.json','art/textures/catalog_mapping.json']:
 path=ROOT/name;data=json.loads(path.read_text(encoding='utf8'))
 for key in keys:data[key]=({'base_color':[1.,1.,1.,1.],'roughness':1.,'metallic':0.} if 'material_catalog' in name else 'library/'+key)
 path.write_bytes((json.dumps(data,indent=1)+'\n').encode('utf8'))
# Persist through the owning layout generator, without invoking world generation.
path=ROOT/'art/data/gen_layout.py';text=path.read_text(encoding='utf8')
for key in keys:
 if repr(key)+':' not in text:text=text.replace('MATERIAL_CATALOG = {','MATERIAL_CATALOG = {\n    '+repr(key)+": {'base_color': [1.0, 1.0, 1.0, 1.0], 'roughness': 1.0, 'metallic': 0.0},",1)
path.write_bytes(text.encode('utf8'))
