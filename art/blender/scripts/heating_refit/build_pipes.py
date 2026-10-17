"""Offline native retrofit prototype; no shipping export or runtime acceptance."""
from pathlib import Path
import bpy,bmesh,ast,json,math,hashlib,sys,os
from mathutils import Vector
from mathutils.bvhtree import BVHTree
from heating_refit_context import ROOT, OUT, PLAN
sys.path.insert(0,str(ROOT/'tools'))
from heating_pipe_fittings import fitted_stations
source=ROOT/PLAN['base_native']['path'];bpy.ops.wm.open_mainfile(filepath=str(source));bpy.context.preferences.filepaths.save_version=0
original_names={o.name for o in bpy.data.objects};route_path=Path(os.environ.get('HEATING_CANDIDATE_ROUTES',str(OUT/'routes.json')));prefix=os.environ.get('HEATING_NATIVE_PREFIX','refit_pipes');data=json.loads(route_path.read_text());assert all(r['points_local_godot'] for r in data['branches'])
mat=bpy.data.materials['iron_neutral'];spec=json.loads((ROOT/'game/data/runtime_material_sets.json').read_text())['materials']['iron_neutral'];objects=[];rejected=[];census=[];joinery=[]
recipe=ROOT/'art/blender/scripts/review_heating_distribution.py';tree=ast.parse(recipe.read_text())
nodes=[n for n in tree.body if isinstance(n,ast.FunctionDef) and n.name in ['cv','repair_boolean_charts','coupling']]
body=next(n for n in tree.body if isinstance(n,ast.For) and ast.unparse(n.iter)=="data['branches']")
exec(compile(ast.Module(body=nodes+[body],type_ignores=[]),str(recipe),'exec'))
checks=[]
def check(label,passed,**detail):checks.append(dict(label=label,passed=bool(passed),**detail))
check('all four new bodies generated',len(census)==4 and not rejected)
# Keep the old H-D body and extend its open end; relocate its existing cap.
main=bpy.data.objects['Main_H-D'];old_end=max((main.matrix_world@Vector(v)).z for v in main.bound_box);top=max(r['points_local_godot'][0][1] for r in data['branches'] if r['riser']=='H-D')+.15
extension=coupling('Restricted_Main_H-D_Extension',cv([8.74,old_end,.59]),cv([8.74,top,.59]),'SHAFT',outer=.029,inner=.024)
# The retained pipe projects only 20mm above F04's floor. A generic 70mm
# collar would enter that slab. Fit this fixed repair sleeve to the available
# stub, leaving 2mm for the floor and at least 15mm engagement on each pipe.
layout=json.loads((ROOT/PLAN['source_layout']['path']).read_text())
floor=max(row['y'] for row in layout['levels'] if row['y']<=old_end)
overlap=min(.035,old_end-floor-.002)
assert overlap>=.015,'Retained stub is too short for a supported repair collar'
coupling('Restricted_Main_H-D_ExtensionUnion',cv([8.74,old_end-overlap,.59]),cv([8.74,old_end+overlap,.59]),'SHAFT',outer=.035,inner=.029)
check('fitted repair collar clears retained floor by at least 1.9mm',old_end-overlap-floor>=.0019)
check('fitted repair collar engages each pipe by at least 15mm',overlap>=.015)
for name in ['Main_H-D__CapSleeve','Main_H-D__CapCrown']:
 obj=bpy.data.objects[name];obj.location.z+=top-old_end
changed=[main,bpy.data.objects['Main_H-C']];ports=[]
def subtract(obj,cutter,label):
 bpy.context.view_layer.objects.active=obj
 modifier=obj.modifiers.new(label,'BOOLEAN');modifier.operation='DIFFERENCE';modifier.solver='EXACT';modifier.object=cutter
 bpy.ops.object.modifier_apply(modifier=modifier.name)
 # Weld sub-micron duplicate Boolean vertices before chart repair.
 bm=bmesh.new();bm.from_mesh(obj.data);bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=.000001);bmesh.ops.dissolve_degenerate(bm,edges=list(bm.edges),dist=.000001);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(obj.data);bm.free()
 repair_boolean_charts(obj.data)
for row in data['branches']:
 points=row['points_local_godot'];at=cv(points[0]);direction=(cv(points[1])-at).normalized()
 target=bpy.data.objects['Restricted_Main_H-D_Extension' if at.z>old_end and row['riser']=='H-D' else 'Main_'+row['riser']]
 bpy.ops.mesh.primitive_cylinder_add(vertices=48,radius=.0245,depth=.08,location=at+direction*.04);cutter=bpy.context.object;cutter.rotation_euler=direction.to_track_quat('Z','Y').to_euler()
 subtract(target,cutter,'RestrictedBranchPort');bpy.data.objects.remove(cutter,do_unlink=True)
 # Clear the branch end ring/sleeve from the main's real internal bore.
 low=-.45;high=top if row['riser']=='H-D' else 16.02
 bpy.ops.mesh.primitive_cylinder_add(vertices=32,radius=.024,depth=high-low+.02,location=(at.x,at.y,(high+low)/2));cutter=bpy.context.object
 members=[]
 for name in [row['id'],row['id']+'__Coupling_00_a']:
  obj=bpy.data.objects.get(name)
  if obj:subtract(obj,cutter,'OpenMainLumen');members.append(obj)
 bpy.data.objects.remove(cutter,do_unlink=True)
 def bvh(obj):
  bm=bmesh.new();bm.from_mesh(obj.data);bm.transform(obj.matrix_world);bm.normal_update();t=BVHTree.FromBMesh(bm);bm.free();return t
 trees=[bvh(o) for o in [target]+members];u=direction.cross(Vector((0,0,1))).normalized();v=direction.cross(u).normalized()
 for i in range(16):
  angle=math.tau*i/16;offset=.015*(math.cos(angle)*u+math.sin(angle)*v);a=at+direction*.008+offset;b=at+direction*.12+offset
  clear=all(t.ray_cast(a,(b-a).normalized(),(b-a).length)[0] is None for t in trees)
  check('actual native branch/main air passage',clear,branch=row['id'],ray=i)
 ports.append(dict(branch=row['id'],main=target.name,origin_blender=list(at),direction_blender=list(direction)))
new=[o for o in bpy.data.objects if o.type=='MESH' and o.name not in original_names]
for obj in new+changed:
 # Boolean cutters can introduce an unused UVMap in nondeterministic layer
 # order. Keep the actual active metric chart, matching the export policy.
 active_name=obj.data.uv_layers.active.name
 for layer in list(obj.data.uv_layers):
  if layer.name!=active_name:obj.data.uv_layers.remove(layer)
 bm=bmesh.new();bm.from_mesh(obj.data);check('closed positive native stock',all(e.is_manifold for e in bm.edges) and bm.calc_volume(signed=True)>0,id=obj.name);bm.free()
 mesh=obj.data;mesh.calc_loop_triangles();uv=mesh.uv_layers.active;bad=0
 for tri in mesh.loop_triangles:
  a,b,c=[uv.data[i].uv for i in tri.loops]
  if tri.area>1e-12 and abs((b.x-a.x)*(c.y-a.y)-(b.y-a.y)*(c.x-a.x))<1e-13:bad+=1
 check('finite noncollapsed native UV charts',uv is not None and bad==0 and all(math.isfinite(v) for item in uv.data for v in item.uv),id=obj.name)
# Actual old cap no longer obstructs the extension union's central lumen.
cap=bpy.data.objects['Main_H-D__CapCrown'];check('existing blind cap relocated above new highest port',min((cap.matrix_world@Vector(v)).z for v in cap.bound_box)>top)
for image in bpy.data.images:
 if image.source=='FILE':image.filepath=bpy.path.abspath(image.filepath)
new_names=[o.name for o in new]
native=OUT/(prefix+'_candidate.blend');bpy.ops.wm.save_as_mainfile(filepath=str(native));bpy.ops.file.make_paths_relative();bpy.ops.wm.save_mainfile();bpy.ops.wm.open_mainfile(filepath=str(native))
for image in bpy.data.images:
 if image.source=='FILE' and image.users:check('reopened native PBR image resolves',Path(bpy.path.abspath(image.filepath)).is_file(),id=image.name)
failures=[r for r in checks if not r['passed']]
report=dict(evidence_class='INERT',scope='Offline four-branch and H-D extension prototype only. No supports, architectural bores, room fittings, complete collision/flow, export, loaded Godot mips or runtime/human acceptance.',native_sha256=hashlib.sha256(native.read_bytes()).hexdigest(),route_sha256=hashlib.sha256(route_path.read_bytes()).hexdigest(),source_sha256=hashlib.sha256(source.read_bytes()).hexdigest(),new_stocks=new_names,ports=ports,old_main_end_y=old_end,new_main_end_y=top,checks=checks,failures=failures)
(OUT/('native_candidate.json' if prefix=='restricted_heating' else prefix+'_native.json')).write_text(json.dumps(report,indent=2)+'\n',newline='\n');print('RESTRICTED HEATING NATIVE:',len(checks),'checks;',len(failures),'failures')
if failures:raise RuntimeError(str(failures))
