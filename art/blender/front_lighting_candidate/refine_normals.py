"""Refine moulded plate shading, proving every geometry/UV value is unchanged."""
from array import array
import ast
import hashlib
import json
from pathlib import Path
import bpy

ROOT=Path(__file__).resolve().parents[3]
OUT=ROOT/'tmp/v2-front-lighting-20261016'
native=ROOT/'art/blender/front_lighting_candidate.blend'
construction=json.loads((OUT/'native_inspection.json').read_text())
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
assert not construction['failures'] and construction['blend_sha256']==sha(native)
bpy.ops.wm.open_mainfile(filepath=str(native))
source=ROOT/'art/blender/scripts/package_heating_native.py'
tree=ast.parse(source.read_text())
exec(compile(ast.Module(body=[n for n in tree.body if isinstance(n,ast.FunctionDef) and n.name=='geometry_digest'],type_ignores=[]),str(source),'exec'))
before=geometry_digest();old_sha=sha(native);changed=[]
for obj in bpy.data.collections['FrontLightingCandidate'].objects:
    if obj.get('role')!='native_switch' or not obj.name.endswith('__MouldedPlate'):continue
    bpy.context.view_layer.objects.active=obj
    modifier=obj.modifiers.new('Moulded planar face normals','WEIGHTED_NORMAL')
    modifier.keep_sharp=True;modifier.weight=100
    bpy.ops.object.modifier_apply(modifier=modifier.name)
    changed.append(obj.name)
assert len(changed)==20,len(changed)
assert geometry_digest()==before,'Normal refinement altered geometry/UVs'
bpy.context.preferences.filepaths.save_version=0
bpy.ops.wm.save_as_mainfile(filepath=str(native))
bpy.ops.wm.open_mainfile(filepath=str(native))
assert geometry_digest()==before,'Saved refinement altered geometry/UVs'
report=dict(evidence_class='INERT',scope='Custom normal refinement only; exact geometry, UVs and transforms preserved.',
    source_blend_sha256=old_sha,blend_sha256=sha(native),geometry_uv_digest=before,parts=changed,failures=[],
    recipe_sha256_lf=hashlib.sha256(Path(__file__).read_bytes().replace(b'\r\n',b'\n')).hexdigest(),
    digest_helper_sha256_lf=hashlib.sha256(source.read_bytes().replace(b'\r\n',b'\n')).hexdigest())
(OUT/'normal_refinement.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8',newline='\n')
print('PLATE NORMALS:',len(changed),'parts; exact geometry/UV identity preserved')
