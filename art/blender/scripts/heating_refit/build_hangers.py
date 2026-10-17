"""Build measured hanger candidates in a native copy; no shipping mutation."""
from pathlib import Path
import ast, bpy, bmesh, hashlib, json, math, os
from mathutils import Vector
from heating_refit_context import ROOT, OUT, PLAN
prefix=os.environ.get('HEATING_NATIVE_PREFIX','refit_pipes');outprefix=os.environ.get('HEATING_SUPPORTED_PREFIX','refit_supported')
report=json.loads((OUT/(prefix+'_native.json')).read_text())
native=OUT/(prefix+'_candidate.blend')
assert not report['failures'] and hashlib.sha256(native.read_bytes()).hexdigest()==report['native_sha256']
support_path=Path(os.environ.get('HEATING_SUPPORTS',str(OUT/'supports.json')))
data=json.loads(support_path.read_text())
assert not data['unserved'],data['unserved']
bpy.ops.wm.open_mainfile(filepath=str(native));bpy.context.preferences.filepaths.save_version=0
mat=bpy.data.materials['iron_neutral'];spec=json.loads((ROOT/'game/data/runtime_material_sets.json').read_text())['materials']['iron_neutral'];objects=[]
recipe=ROOT/'art/blender/scripts/review_heating_distribution.py';tree=ast.parse(recipe.read_text())
functions=[node for node in tree.body if isinstance(node,ast.FunctionDef) and node.name in ['cv','repair_boolean_charts','coupling']]
exec(compile(ast.Module(body=functions,type_ignores=[]),str(recipe),'exec'))
checks=[];parts=[]
def check(label,passed,**detail):checks.append(dict(label=label,passed=bool(passed),**detail))
for support in data['supports']:
    center=cv(support['center']);direction=cv(support['tangent']).normalized();half=support['band_length_m']*.5
    band=coupling(support['id']+'__Band',center-direction*half,center+direction*half,support['branch'][:3],outer=.034,inner=.029)
    names=[band['id']]
    check('measured downward-facing substrate',support['substrate_normal_godot'][1]<-.9,id=support['id'])
    check('positive stem reaches actual underside',support['stem_top_y']>support['stem_bottom_y'] and abs(support['stem_top_y']-support['substrate_y'])<1e-7,id=support['id'])
    for role,bottom,top,width in [('Stem',support['stem_bottom_y'],support['stem_top_y'],.008),('Foot',support['stem_top_y']-.004,support['stem_top_y'],.026)]:
        bpy.ops.mesh.primitive_cube_add(size=1,location=(center.x,center.y,(bottom+top)*.5));obj=bpy.context.object;obj.name=support['id']+'__'+role
        obj.dimensions=(width,width,top-bottom);bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
        modifier=obj.modifiers.new('EasedSteelEdges','BEVEL');modifier.width=.0004;modifier.segments=2;bpy.ops.object.modifier_apply(modifier=modifier.name)
        mesh=obj.data;mesh.materials.clear();mesh.materials.append(mat)
        for face in mesh.polygons:face.material_index=0
        for loop in mesh.uv_layers.active.data:loop.uv=(0,0)
        repair_boolean_charts(mesh);obj['level']=support['branch'][:3];objects.append(obj);names.append(obj.name)
    parts.append(dict(support,parts=names))
for obj in objects:
    bm=bmesh.new();bm.from_mesh(obj.data);check('closed positive hanger stock',all(e.is_manifold for e in bm.edges) and bm.calc_volume(signed=True)>0,id=obj.name);bm.free()
    mesh=obj.data;mesh.calc_loop_triangles();uv=mesh.uv_layers.active;bad=0
    for tri in mesh.loop_triangles:
        a,b,c=[uv.data[index].uv for index in tri.loops]
        if tri.area>1e-12 and abs((b.x-a.x)*(c.y-a.y)-(b.y-a.y)*(c.x-a.x))<1e-13:bad+=1
    check('finite noncollapsed hanger UV',uv is not None and bad==0 and all(math.isfinite(value) for item in uv.data for value in item.uv),id=obj.name)
destination=OUT/(outprefix+'_candidate.blend');bpy.ops.wm.save_as_mainfile(filepath=str(destination));bpy.ops.wm.open_mainfile(filepath=str(destination))
for image in bpy.data.images:
    if image.source=='FILE' and image.users:check('reopened source PBR resolves',Path(bpy.path.abspath(image.filepath)).is_file(),id=image.name)
failures=[row for row in checks if not row['passed']]
(OUT/('supported_native.json' if outprefix=='supported_rectilinear' else outprefix+'_native.json')).write_text(json.dumps(dict(evidence_class='INERT',scope='Uninstalled native pipe and measured hanger prototype. Supports meet acquired real undersides; complete collisions, shaft extension bearings, bored architecture, emitter fitting, strict export/runtime and human acceptance remain open.',native_file=destination.name,native_sha256=hashlib.sha256(destination.read_bytes()).hexdigest(),pipe_source_sha256=report['native_sha256'],support_source_sha256=hashlib.sha256(support_path.read_bytes()).hexdigest(),parts=parts,checks=checks,failures=failures),indent=2)+'\n')
print('MEASURED NATIVE HANGERS',len(parts),'checks',len(checks),'failures',len(failures),flush=True)
if failures:raise RuntimeError(str(failures))
