from pathlib import Path
import ast,hashlib,json,struct,bpy,shutil
root=Path('C:/PleaseRemainOnTheLine');out=root/'tmp/v2-radiator-polish-20261017/distribution_cast_catalog'
source=root/'art/blender/scripts/review_radiator_distribution_retirement.py';tree=ast.parse(source.read_text())
fn=next(n for n in tree.body if isinstance(n,ast.FunctionDef) and n.name=='stocks');ns={'bpy':bpy,'hashlib':hashlib,'struct':struct}
exec(compile(ast.Module(body=[fn],type_ignores=[]),str(source),'exec'),ns)
before=root/'art/blender/heating_distribution.blend';after=out/'heating_distribution_candidate.blend';a=ns['stocks'](before);b=ns['stocks'](after)
assert a==b,(set(a)^set(b),[k for k in a.keys() & b.keys() if a[k]!=b[k]])
old_sha=hashlib.sha256(before.read_bytes()).hexdigest();new_sha=hashlib.sha256(after.read_bytes()).hexdigest()
report={'evidence_class':'INERT','status':'PASS','scope':'All retained native stock names, frames, vertices, faces, UVs and corner normals equal after source-plan material catalogue renewal; no new runtime qualification.','stocks':len(a),'before_native_sha256':old_sha,'after_native_sha256':new_sha,'equality_helper_sha256_lf':hashlib.sha256(source.read_bytes().replace(b'\r\n',b'\n')).hexdigest(),'runtime_glb_raw_equal':(root/'game/assets/props/heating_distribution.glb').read_bytes()==(out/'export/heating_distribution.glb').read_bytes()}
assert report['runtime_glb_raw_equal']
(out/'catalog_renewal_equality.json').write_text(json.dumps(report,indent=2)+'\n',newline='\n')
shutil.copyfile(after,before)
print('DISTRIBUTION CATALOGUE RENEWAL: PASS',len(a),'native stocks equal; runtime GLB byte-identical. Native source refreshed; no runtime reimport required.')
