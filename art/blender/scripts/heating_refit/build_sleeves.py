"""Native measured wall/slab sleeves and retained-bearing main supports."""
from pathlib import Path
import bpy,bmesh,ast,json,math,hashlib
from mathutils import Vector
from mathutils.bvhtree import BVHTree
from heating_refit_context import ROOT as R, OUT as P, PLAN
source=P/'refit_supported_candidate.blend';prior=json.loads((P/'refit_supported_native.json').read_text());data=json.loads((P/'passages.json').read_text());routes=json.loads((P/'routes.json').read_text())
assert not prior['failures'] and hashlib.sha256(source.read_bytes()).hexdigest()==prior['native_sha256']
assert all(row['retained_bearing'] for row in data['bearing_checks'])
bpy.ops.wm.open_mainfile(filepath=str(source));bpy.context.preferences.filepaths.save_version=0
mat=bpy.data.materials['iron_neutral'];spec=json.loads((R/'game/data/runtime_material_sets.json').read_text())['materials']['iron_neutral'];objects=[]
recipe=R/'art/blender/scripts/review_heating_distribution.py';parsed=ast.parse(recipe.read_text());functions=[node for node in parsed.body if isinstance(node,ast.FunctionDef) and node.name in ['cv','repair_boolean_charts','coupling']]
exec(compile(ast.Module(body=functions,type_ignores=[]),str(recipe),'exec'))
checks=[];passages=[]
def check(label,passed,**detail):checks.append(dict(label=label,passed=bool(passed),**detail))
bybranch={row['id']:row for row in routes['branches']}
for passage in data['passages']:
    branch=passage['branch'];a,b=cv(passage['start']),cv(passage['end']);direction=(b-a).normalized();axis=passage['axis']
    normal_godot=[0.,0.,0.];normal_godot[axis]=1 if passage['end'][axis]>passage['start'][axis] else -1;normal=cv(normal_godot)
    shaft=all(owner['table']=='riser_openings' for owner in passage['owners'])
    if shaft:
        # The upper H-D main bore is new. Old composed shaft stock filled its
        # start; its final inner bearing face is the retained 40mm main bore.
        start=cv(bybranch[branch]['points_local_godot'][0]);a=start+direction*.045
    # Neck caps end INSIDE the four-mm plates. Matching their outer cap
    # planes would leave coincident visible annuli and flickering metal.
    # The 35mm coupling sleeves must fit inside the wall/floor liner too;
    # a bare-pipe-only 31mm bore intersects those existing mechanical stocks.
    neck=coupling(passage['id']+'__Neck',a-direction*.002,b+direction*.002,branch[:3],outer=.039,inner=.037)
    names=[neck['id']]
    enclosed_shaft=passage.get('enclosed_shaft',False)
    if enclosed_shaft:
        # A main inside the retained solid chase has no exposed wall face for
        # an escutcheon. Oversized plates would intersect the shaft around its
        # existing main bore. Retain only the annular through-slab liner.
        assert axis==1 and all(owner['table']=='slab_openings' for owner in passage['owners'])
        bore=data['replace_riser_openings'][0]['bounds']
        check('enclosed main liner fits wholly inside retained shaft bore',
              all(bore[i]+.0005<=min(passage['start'][i],passage['end'][i])-.039 and
                  max(passage['start'][i],passage['end'][i])+.039<=bore[i+3]-.0005 for i in [0,2]),id=passage['id'])
    faces=[] if enclosed_shaft else ([('Exit',b,normal)] if shaft else [('Entry',a,-normal),('Exit',b,normal)])
    face_bores=[]
    for label,center,outward in faces:
        bore=.031
        plate_lo=[min(center[i],(center+outward*.004)[i])-(.064 if abs(outward[i])<.5 else 0) for i in range(3)]
        plate_hi=[max(center[i],(center+outward*.004)[i])+(.064 if abs(outward[i])<.5 else 0) for i in range(3)]
        for obj in bpy.context.scene.objects:
            if not obj.name.startswith(branch+'__Coupling_'):continue
            corners=[obj.matrix_world@Vector(v) for v in obj.bound_box];lo=[min(v[i] for v in corners) for i in range(3)];hi=[max(v[i] for v in corners) for i in range(3)]
            if all(hi[i]>=plate_lo[i] and lo[i]<=plate_hi[i] for i in range(3)):bore=.037;break
        plate=coupling(passage['id']+'__'+label+'Plate',center,center+outward*.004,branch[:3],outer=.064,inner=bore)
        face_bores.append(dict(face=label,bore_radius_m=bore))
        names.append(plate['id'])
        # The circular plate masks the conservative rectangular source hole.
        transverse=math.sqrt(2)*.041+abs(passage['end'][1]-passage['start'][1]) if axis!=1 else math.sqrt(2)*.041
        check('round face plate covers rectangular port corners',transverse<.064-.001,id=plate['id'],required_radius_m=transverse)
    # No end cap or internal wall is allowed to block the existing steam bore.
    trees=[]
    for name in names:
        obj=bpy.data.objects[name];bm=bmesh.new();bm.from_mesh(obj.data);bm.transform(obj.matrix_world);bm.normal_update();trees.append(BVHTree.FromBMesh(bm));bm.free()
    u=direction.cross(Vector((0,0,1)) if abs(direction.z)<.9 else Vector((0,1,0))).normalized();v=direction.cross(u)
    for index in range(16):
        angle=math.tau*index/16;offset=.025*(math.cos(angle)*u+math.sin(angle)*v);origin=a-direction*.01+offset;end=b+direction*.01+offset
        clear=all(tree.ray_cast(origin,(end-origin).normalized(),(end-origin).length)[0] is None for tree in trees)
        check('actual native sleeve and both face bores remain open',clear,id=passage['id'],ray=index)
    passages.append(dict(passage,neck_start_blender=list(a),neck_end_blender=list(b),face_bores=face_bores,parts=names))

interfaces={'main_supports':data['new_main_supports']};main_supports=[]
for row in interfaces['main_supports']:assert bpy.data.objects.get(row['id']+'__Band') is None
body=next(node for node in parsed.body if isinstance(node,ast.For) and ast.unparse(node.iter)=="interfaces['main_supports']")
exec(compile(ast.Module(body=[body],type_ignores=[]),str(recipe),'exec'))
heating={'installed':data['append_installed_radiators']};anchors={row['id']:row for row in data['records']['anchors']};layout=json.loads((R/PLAN['source_layout']['path']).read_text());level_elevations={row['id']:row['y'] for row in layout['levels']};tailpieces=[]
body=next(node for node in parsed.body if isinstance(node,ast.For) and ast.unparse(node.iter)=="heating['installed']")
exec(compile(ast.Module(body=[body],type_ignores=[]),str(recipe),'exec'))
for obj in objects:
    bm=bmesh.new();bm.from_mesh(obj.data);check('closed positive sleeve/bearing stock',all(edge.is_manifold for edge in bm.edges) and bm.calc_volume(signed=True)>0,id=obj.name);bm.free()
    mesh=obj.data;mesh.calc_loop_triangles();uv=mesh.uv_layers.active;bad=0
    for tri in mesh.loop_triangles:
        a,b,c=[uv.data[index].uv for index in tri.loops]
        if tri.area>1e-12 and abs((b.x-a.x)*(c.y-a.y)-(b.y-a.y)*(c.x-a.x))<1e-13:bad+=1
    check('finite noncollapsed sleeve/bearing UV',uv is not None and bad==0 and all(math.isfinite(value) for item in uv.data for value in item.uv),id=obj.name)
for row in data['bearing_checks']:check('new main lug tip bears on retained shaft after all planned cuts',row['retained_bearing'],id=row['support'],point=row['point'])
native=P/'heating_distribution_candidate.blend';bpy.ops.wm.save_as_mainfile(filepath=str(native));bpy.ops.wm.open_mainfile(filepath=str(native))
for image in bpy.data.images:
    if image.source=='FILE' and image.users:check('reopened native PBR source resolves',Path(bpy.path.abspath(image.filepath)).is_file(),id=image.name)
failures=[row for row in checks if not row['passed']]
(P/'native_review.json').write_text(json.dumps(dict(evidence_class='INERT',scope='Native prototype with measured face sleeves, four additional retained-bearing H-D supports, and four union tails at the retained radiator actor datums. Source-owned architectural cuts are planned, not installed. Whole fitting containment/collision, emitter fit, strict export/runtime and human acceptance remain open.',native_file=native.name,native_sha256=hashlib.sha256(native.read_bytes()).hexdigest(),prior_native_sha256=prior['native_sha256'],passage_source_sha256=hashlib.sha256((P/'passages.json').read_bytes()).hexdigest(),passages=passages,main_supports=main_supports,tailpieces=tailpieces,checks=checks,failures=failures),indent=2)+'\n')
print('NATIVE REFIT SLEEVES',len(passages),'main bearings',len(main_supports),'checks',len(checks),'failures',len(failures),flush=True)
if failures:raise RuntimeError(str(failures))
