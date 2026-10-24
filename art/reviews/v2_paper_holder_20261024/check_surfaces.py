"""Scoped imported paper-holder UV/PBR/mip review, without ledger promotion."""
import json, math
from pathlib import Path
root=Path(__file__).resolve().parent
data=json.loads((root/'cap_v1/paper_surfaces.json').read_text(encoding='utf-8'))
errors=[]
assert len(data['draws'])==36 and len(data['meshes'])==36
for key,mesh in data['meshes'].items():
 for surface in mesh['surfaces']:
  for flag in ['missing_uv','nonfinite_uv','degenerate_uv_triangles']:
   if surface[flag]:errors.append([key,flag])
for key,material in data['materials'].items():
 kind=material['type']
 names=['albedo_texture','roughness_texture','normal_texture'] if kind=='StandardMaterial3D' else ['albedo_tex','rough_tex','normal_tex']
 if kind not in ['StandardMaterial3D','ShaderMaterial']:errors.append([key,'unexpected material'])
 if kind=='StandardMaterial3D':
  if material['triplanar'] or not material['normal_enabled']:errors.append([key,'missing mapped normals'])
  if material['filter'] not in [2,3,4,5]:errors.append([key,'nonmip filter'])
 else:
  for name in names:
   if not material['mip_filters'].get(name):errors.append([key,'nonmip filter',name])
 for name in names:
  if not material['maps'].get(name):errors.append([key,'missing map',name])
for path,texture in data['textures'].items():
 if not texture['mips'] or texture['mip_levels']!=int(math.log2(max(texture['width'],texture['height']))):errors.append([path,'incomplete loaded mip chain'])
result=dict(evidence_class='INERT',scope='Only 12 installed paper holders; no whole-world qualification',draws=len(data['draws']),meshes=len(data['meshes']),textures=len(data['textures']),errors=errors,world_failures=data['failures'])
(root/'surface_checks.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8')
print(result)
assert not errors and not data['failures']
