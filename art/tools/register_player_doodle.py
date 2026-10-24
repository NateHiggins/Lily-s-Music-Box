"""Register the owner's unique charcoal/paper character atlas without tiling it."""
from pathlib import Path
import hashlib,json,shutil
root=Path(__file__).resolve().parents[2]
source=root/'art/source/player_doodle_20261023/Meshy_AI_Smiling_Stick_Figure_biped'
target=root/'art/textures/library/player_doodle';target.mkdir(parents=True,exist_ok=True)
prefix='Meshy_AI_Smiling_Stick_Figure_biped_texture_0'
sources={}
for channel,suffix,runtime in [('albedo','','albedo'),('roughness','_roughness','rough'),('normal','_normal','normal')]:
    path=source/(prefix+suffix+'.png');sources[path.relative_to(root).as_posix()]=hashlib.sha256(path.read_bytes()).hexdigest()
    shutil.copyfile(path,target/(channel+'.png'))
    shutil.copyfile(path,root/('game/assets/building/textures/T_library_player_doodle_'+runtime+'.png'))
metadata={'material':'player_doodle','source':'owner-provided rigged Meshy archive, 2026-10-23','generator':'art/tools/register_player_doodle.py','meters_per_tile':1.,'projection':'unique authored whole-character atlas; normalized UVs retained, no repetition','maps':{'albedo':'albedo.png','roughness':'roughness.png','normal':'normal.png'},'source_sha256':sources}
(target/'material.json').write_text(json.dumps(metadata,indent=2)+'\n',encoding='utf-8',newline='\n')
for name,value in [('art/data/material_catalog.json',{'base_color':[1.,1.,1.,1.],'roughness':1.,'metallic':0.}),('art/textures/catalog_mapping.json','library/player_doodle')]:
    path=root/name;data=json.loads(path.read_text());data['player_doodle']=value;path.write_text(json.dumps(data,indent=1)+'\n',encoding='utf-8',newline='\n')
# gen_layout owns catalogue regeneration too. Do not execute its world writer.
path=root/'art/data/gen_layout.py';text=path.read_text(encoding='utf-8')
if "'player_doodle':" not in text:
    text=text.replace('MATERIAL_CATALOG = {',"MATERIAL_CATALOG = {\n    'player_doodle': {'base_color': [1.0, 1.0, 1.0, 1.0], 'roughness': 1.0, 'metallic': 0.0},",1)
    path.write_text(text,encoding='utf-8',newline='\n')
