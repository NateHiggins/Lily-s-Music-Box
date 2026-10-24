"""Inspect only the explicitly scoped new water/film surfaces, never qualify V2."""
import json,math
from pathlib import Path
OUT=Path(__file__).resolve().parent
results=[]
for name in ['after_v2','after_v3','after_v4']:
 path=OUT/name/'moisture_surfaces.json'
 if not path.exists():continue
 data=json.loads(path.read_text());assert data['schema']=='orison.v2-moisture-surfaces.diagnostic.v1'
 errors=[]
 for key,mesh in data['meshes'].items():
  for surface in mesh['surfaces']:
   for flag in ['missing_uv','nonfinite_uv','degenerate_uv_triangles']:
    if surface[flag]:errors.append([key,flag])
 for key,material in data['materials'].items():
  required=['albedo_texture','roughness_texture','normal_texture'] if material['type']=='StandardMaterial3D' else ['albedo_tex','rough_tex','normal_tex']
  if not all(material['maps'].get(k) for k in required):errors.append([key,'missing custom PBR maps'])
  if material['type']=='StandardMaterial3D':
   if material['triplanar'] or not material['normal_enabled']:errors.append([key,'UV/normal disabled'])
  else:
   for k in required:
    if not material['mip_filters'].get(k):errors.append([key,'nonmip filter',k])
 for path,texture in data['textures'].items():
  if not texture['mips'] or texture['mip_levels']!=int(math.log2(max(texture['width'],texture['height']))):errors.append([path,'incomplete loaded mip chain'])
 assert data['draws'] and data['materials'] and data['textures'],'empty scope'
 results.append(dict(run=name,draws=len(data['draws']),meshes=len(data['meshes']),maps=len(data['textures']),actual_passage_state=data['passage_state'],errors=errors))
print(results)
(OUT/'surface_checks.json').write_text(json.dumps(dict(evidence_class='INERT',scope='Only listed new spray/film surfaces; no passage or whole-world coverage assertion or runtime_contract.',checks=results),indent=2)+'\n',encoding='utf-8',newline='\n')
assert results and not any(r['errors'] for r in results)
