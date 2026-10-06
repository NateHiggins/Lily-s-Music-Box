"""Inspect closed stocks, fitted joins and actual catalogue maps; render QA."""
from pathlib import Path
import hashlib,json,os
import bpy,bmesh
from mathutils import Vector
from mathutils.bvhtree import BVHTree
r=next(p for p in Path(__file__).resolve().parents if (p/'game/project.godot').is_file());out=Path(os.environ.get('PHOTO_PROCESS_INSPECTION',str(r/'tmp/v2-finish-review/photo-process-native')));out.mkdir(parents=True,exist_ok=True)
import os
source=Path(os.environ.get('PHOTO_PROCESS_OUT',str(r)));asset=source/'art/blender/photo_process.blend';bpy.ops.wm.open_mainfile(filepath=str(asset))
f=json.loads((source/'art/blender/photo_process_construction.json').read_text(encoding='utf-8'));assert f==json.loads((source/'game/tests/fixtures/orison_photo_process.json').read_text(encoding='utf-8'))
for rel,h in f['source_bindings'].items():
 data=(r/rel).read_bytes();data=data if Path(rel).suffix in ['.blend','.glb','.png','.bin'] else data.replace(b'\r\n',b'\n');assert hashlib.sha256(data).hexdigest()==h,rel
for image in bpy.data.images:
 if image.source=='FILE':assert image.filepath.startswith('//') and Path(bpy.path.abspath(image.filepath)).is_file(),image.filepath
volumes=[];trees={}
for o in bpy.data.collections['ClosedConstruction'].objects:
 o.data.calc_loop_triangles();bm=bmesh.new();bm.from_mesh(o.data);assert all(e.is_manifold and e.is_contiguous for e in bm.edges) and bm.calc_volume(signed=True)>0,o.name
 unseen=set(bm.verts);components=0
 while unseen:
  components+=1;stack=[unseen.pop()]
  while stack:
   v=stack.pop()
   for edge in v.link_edges:
    other=edge.other_vert(v)
    if other in unseen:unseen.remove(other);stack.append(other)
 assert components==1,o.name
 for tri in o.data.loop_triangles:assert tri.area>0,o.name
 volume=bm.calc_volume(signed=True);expected=next(x['volume_m3'] for x in f['closed_stocks'] if x['name']==o.name);assert abs(volume-expected)<1e-10
 volumes.append({'name':o.name,'volume_m3':volume});bm.free()
 trees[o.name]=BVHTree.FromPolygons([o.matrix_world@v.co for v in o.data.vertices],[list(p.vertices) for p in o.data.polygons],epsilon=.00002)
joins=[]
for a in f['assemblies']:
 stocks=[row['name'] for row in f['closed_stocks'] if row['assembly']==a['id']];adj={name:set() for name in stocks};edges=[]
 for i,left in enumerate(stocks):
  for right in stocks[i+1:]:
   if trees[left].overlap(trees[right]):adj[left].add(right);adj[right].add(left);edges.append([left,right])
 seen={stocks[0]};pending=list(seen)
 while pending:
  for neighbour in adj[pending.pop()]-seen:seen.add(neighbour);pending.append(neighbour)
 assert len(seen)==len(stocks),(a['id'],'disconnected',sorted(set(adj)-seen))
 joins.append({'assembly':a['id'],'connected_components':1,'surface_contact_edges':edges})
draws=[o for o in bpy.context.scene.objects if o.type=='MESH' and '__' in o.name and not o.hide_render];assert len(draws)==len(f['parts'])
scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=32;scene.render.resolution_x=1100;scene.render.resolution_y=720;scene.render.resolution_percentage=100
scene.world=bpy.data.worlds.new('Inspection');scene.world.use_nodes=True;scene.world.node_tree.nodes['Background'].inputs[0].default_value=(.5,.55,.6,1);scene.world.node_tree.nodes['Background'].inputs[1].default_value=.7
bpy.ops.object.light_add(type='SUN',location=(0,0,50));bpy.context.object.data.energy=2.3;bpy.context.object.rotation_euler=(.4,-.6,.3)
groups=[[a['id']] for a in f['assemblies']]
views=[]
for ids in groups:
 visible=[o for o in draws if any(o.name.startswith(identity+'__') for identity in ids)]
 for o in draws:o.hide_render=o not in visible
 vertices=[o.matrix_world@v.co for o in visible for v in o.data.vertices];low=Vector(tuple(min(v[i] for v in vertices) for i in range(3)));high=Vector(tuple(max(v[i] for v in vertices) for i in range(3)));center=(low+high)*.5
 size=max(high-low);distance=max(.6,size)*2.35
 for role,offset in [('front',Vector((-1,-.45,.30))),('rear',Vector((1,.45,.30)))]:
  name=ids[0]+'_'+role+'.png';views.append(name);bpy.ops.object.camera_add(location=center+offset*distance);cam=bpy.context.object;cam.data.lens=42;cam.rotation_euler=(center-cam.location).to_track_quat('-Z','Y').to_euler();scene.camera=cam;scene.render.filepath=str(out/name);bpy.ops.render.render(write_still=True);bpy.data.objects.remove(cam,do_unlink=True)
fit=f['fitted_receiver_clearance']
before=set(bpy.context.scene.objects);bpy.ops.import_scene.gltf(filepath=str(r/'game/assets/building/floor_01_cells/shop_photo_supplies.gltf'))
context=[o for o in bpy.context.scene.objects if o not in before and o.type=='MESH']
hulls=[o for o in context if o.name==fit['raw_hull_name']];assert len(hulls)==1
hull=hulls[0];hull.data.calc_loop_triangles();assert len(hull.data.loop_triangles)==12
points=[hull.matrix_world@v.co for v in hull.data.vertices]
low=Vector(tuple(min(v[i] for v in points) for i in range(3)));high=Vector(tuple(max(v[i] for v in points) for i in range(3)))
assert (low-Vector(fit['hull_low_b'])).length<.00003 and (high-Vector(fit['hull_high_b'])).length<.00003
def actual_tree(o):return BVHTree.FromPolygons([o.matrix_world@v.co for v in o.data.vertices],[list(p.vertices) for p in o.data.polygons],epsilon=0.)
dryer=[o for o in draws if o.name.startswith(fit['dryer_source_record']['id']+'__')];assert len(dryer)==3
vertices=[o.matrix_world@v.co for o in dryer for v in o.data.vertices];north=max(v.y for v in vertices);south=min(v.y for v in vertices)
assert abs(north-fit['dryer_north_y'])<.00003 and abs(north-south-fit['fitted_dryer_length_m'])<.00003
assert low.y-north>=float(fit['clearance_m'])-.00003
for obj in dryer:assert not actual_tree(obj).overlap(actual_tree(hull)),obj.name
clearances={'assembly':fit['dryer_source_record']['id'],'actual_north_y':north,'actual_hull_south_y':low.y,'gap_m':low.y-north,'fitted_length_m':north-south,'source_length_m':fit['source_dryer_length_m']}
# Keep the original hull and unrelated raw source. Only exact old equipment
# box surfaces retire in this temporary render context; never edit glTF.
retired={row['id']:0 for row in f['original_records']}
for old in context:
 bm=bmesh.new();bm.from_mesh(old.data);remove=[]
 for face in bm.faces:
  p=[old.matrix_world@v.co for v in face.verts];normal=(p[1]-p[0]).cross(p[2]-p[0]).normalized();axis=max(range(3),key=lambda i:abs(normal[i]))
  for row in f['original_records']:
   if not old.name.removesuffix('-col').endswith('_'+row['mat']):continue
   q=row['rect'];a=Vector((q[0],q[1],row['z0']));b=Vector((q[2],q[3],row['z0']+row['h']));plane=b[axis] if normal[axis]>0 else a[axis]
   if abs(normal[axis])>.999 and all(abs(v[axis]-plane)<.00003 and all(a[i]-.00003<=v[i]<=b[i]+.00003 for i in range(3)) for v in p):remove.append(face);retired[row['id']]+=1;break
 bmesh.ops.delete(bm,geom=remove,context='FACES');bm.to_mesh(old.data);bm.free()
assert all(count==12 for count in retired.values()),retired
for obj in draws:obj.hide_render=False
for obj in context:obj.hide_render=obj==hull
for label,eye,target in [('receiver_dryer_scope',(20.35,-60.1,1.44),(21.45,-59.736,1.20)),('receiver_dryer_supports',(20.35,-60.1,1.44),(21.35,-59.98,.08))]:
 bpy.ops.object.camera_add(location=eye);cam=bpy.context.object;cam.data.lens=42;cam.rotation_euler=(Vector(target)-cam.location).to_track_quat('-Z','Y').to_euler();scene.camera=cam;scene.render.filepath=str(out/(label+'.png'));bpy.ops.render.render(write_still=True);bpy.data.objects.remove(cam,do_unlink=True);views.append(label+'.png')
(out/'inspection.json').write_text(json.dumps({'evidence_class':'INERT','native_sha256':hashlib.sha256(asset.read_bytes()).hexdigest(),'closed_volumes':volumes,'assembly_stock_joins':joins,'source_boundary_stocks':len(bpy.data.collections['RetainedSourceBoxes'].objects),'parts':len(draws),'triangles':f['triangles'],'receiver_clearance':clearances,'retained_receiver_hull_triangles':12,'temporary_inspection_retirement_counts':retired,'views':views,'limits':'Only the dryer north end and its supports fit the complete original receiver hull. Temporary context retires the sixteen exact original equipment boxes, with unrelated raw source retained. Other native fittings, operation, services, continuous access and human acceptance remain separate obligations.'},indent=2)+'\n')
print('PHOTO PROCESS NATIVE QA',len(volumes),'closed connected stocks;',len(joins),'joined assemblies;',len(views),'views')
