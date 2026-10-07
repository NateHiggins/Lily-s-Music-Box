"""Inspect closed stocks, fitted joins and actual catalogue maps; render QA."""
from pathlib import Path
import hashlib,json,numpy as np
import bpy,bmesh
from mathutils import Vector
from mathutils.bvhtree import BVHTree
from bpy_extras.object_utils import world_to_camera_view
r=next(p for p in Path(__file__).resolve().parents if (p/'game/project.godot').is_file());out=r/'tmp/v2-finish-review/laundry-trade-native';out.mkdir(parents=True,exist_ok=True)
import os
source=Path(os.environ.get('LAUNDRY_TRADE_OUT',str(r)));asset=source/'art/blender/laundry_trade.blend';bpy.ops.wm.open_mainfile(filepath=str(asset))
f=json.loads((source/'art/blender/laundry_trade_construction.json').read_text(encoding='utf-8'));assert f==json.loads((source/'game/tests/fixtures/orison_laundry_trade.json').read_text(encoding='utf-8'))
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
def actual_tree(obj):return BVHTree.FromPolygons([obj.matrix_world@v.co for v in obj.data.vertices],[list(p.vertices) for p in obj.data.polygons],epsilon=0.)
layout=json.loads((r/'art/data/building_layout.json').read_text(encoding='utf-8'));rows={row['id']:row for floor in layout['floors'] if floor['id']=='F01' for row in floor['furniture']}
floor=rows['storm_shop_model_laundry_floor'];ground=floor['z0']+floor['h']
q=floor['rect'];low=[q[0],q[1],ground];high=[q[2],q[3],3.3]
for obj in draws:
 assert all(all(low[i]-.00003<=(obj.matrix_world@v.co)[i]<=high[i]+.00003 for i in range(3)) for v in obj.data.vertices),('shop envelope',obj.name)
uv_metrics=[]
for obj in draws:
 mesh=obj.data;mesh.calc_loop_triangles();points=np.asarray([v.co[:] for v in mesh.vertices],dtype=np.float64);indices=np.asarray([t.vertices[:] for t in mesh.loop_triangles]);p=points[indices];uv=np.asarray([[mesh.uv_layers.active.data[i].uv[:] for i in t.loops] for t in mesh.loop_triangles],dtype=np.float64)
 e=np.stack([p[:,1]-p[:,0],p[:,2]-p[:,0]],axis=2);d=np.stack([uv[:,1]-uv[:,0],uv[:,2]-uv[:,0]],axis=2);assert np.all(np.abs(np.linalg.det(d))>1e-12)
 metric=np.linalg.svd(e@np.linalg.inv(d),compute_uv=False);assert np.all((metric>.99)&(metric<1.01)),(obj.name,float(metric.min()),float(metric.max()))
 uv_metrics.append({'part':obj.name,'minimum_metres_per_uv':float(metric.min()),'maximum_metres_per_uv':float(metric.max())})
before=set(bpy.context.scene.objects);bpy.ops.import_scene.gltf(filepath=str(r/'game/assets/building/floor_01_cells/shop_model_laundry.gltf'));context=[o for o in bpy.context.scene.objects if o not in before and o.type=='MESH']
before=set(bpy.context.scene.objects);bpy.ops.import_scene.gltf(filepath=str(r/'game/assets/building/floor_01_cells/passage.gltf'));context.extend(o for o in bpy.context.scene.objects if o not in before and o.type=='MESH')
accepted=[];retirement_rows=list(f['original_records'])
for family in ['laundry_fittings','laundry_apparatus','shop_seating']:
 fixture=json.loads((r/f'game/tests/fixtures/orison_{family}.json').read_text(encoding='utf-8'))
 retirement_rows.extend(row for row in fixture['original_records'] if row.get('batch')=='shop_model_laundry')
 wanted={p['name'] for p in fixture['parts'] if p['cell']=='shop_model_laundry'}
 with bpy.data.libraries.load(str(r/f'art/blender/{family}.blend'),link=False) as (src,dst):dst.objects=[n for n in src.objects if n in wanted]
 assert len(dst.objects)==len(wanted),(family,len(dst.objects),len(wanted))
 for obj in dst.objects:
  bpy.context.scene.collection.objects.link(obj);bpy.context.view_layer.update();obj.hide_render=False;accepted.append(obj)
counts={row['id']:0 for row in retirement_rows}
for old in context:
 bm=bmesh.new();bm.from_mesh(old.data);remove=[]
 for face in bm.faces:
  points=[old.matrix_world@v.co for v in face.verts];n=(points[1]-points[0]).cross(points[2]-points[0]).normalized();axis=max(range(3),key=lambda i:abs(n[i]));matches=[]
  for row in retirement_rows:
   if not old.name.removesuffix('-col').endswith('_'+row['mat']):continue
   q=row['rect'];a=Vector((q[0],q[1],row['z0']));b=Vector((q[2],q[3],row['z0']+row['h']));plane=b[axis] if n[axis]>0 else a[axis]
   if abs(n[axis])>.999 and all(abs(v[axis]-plane)<.00003 and all(a[i]-.00003<=v[i]<=b[i]+.00003 for i in range(3)) for v in points):matches.append(row['id'])
  if matches:assert len(matches)==1;remove.append(face);counts[matches[0]]+=1
 bmesh.ops.delete(bm,geom=remove,context='FACES');bm.to_mesh(old.data);bm.free()
assert len(counts)==len(retirement_rows) and all(value==12 for value in counts.values()),counts
assert len(accepted)>=117
all_trees={obj:actual_tree(obj) for obj in draws+context+accepted if obj.data.polygons}
contacts_checked=[]
for c in f['contacts']:
 at=Vector((c['point'][0],-c['point'][2],c['point'][1]));direction=Vector((c['direction'][0],-c['direction'][2],c['direction'][1]))
 own=[obj for obj in draws if obj.name.startswith(c['assembly']+'__')]
 targets=[obj for obj in draws if obj.name.startswith(c['owner']+'__')] if c['native_owner'] else [obj for obj in context if obj.name.removesuffix('-col').endswith('_'+rows[c['owner']]['mat'])]
 distances=[]
 for obj in targets:
  hit,normal,_,_=all_trees[obj].ray_cast(at+direction*.006,-direction,.012)
  if hit is not None and normal.dot(direction)>0:distances.append((hit-at).length)
 assert distances and min(distances)<.00003,('owner contact',c,distances)
 own_hits=[]
 for obj in own:
  hit,normal,_,_=all_trees[obj].ray_cast(at-direction*.006,direction,.012)
  if hit is not None and normal.dot(-direction)>0:own_hits.append((hit-at).length)
 assert own_hits and min(own_hits)<.00003,('stock contact',c,own_hits)
 contacts_checked.append(c)
# Closed stock inspection distinguishes physical end joints from unintended penetrations.
errors=[];allowed=[]
stocks=list(bpy.data.collections['ClosedConstruction'].objects)
stock_owner={row['name']:row['assembly'] for row in f['closed_stocks']}
for i,left in enumerate(stocks):
 for right in stocks[i+1:]:
  la=stock_owner[left.name];ra=stock_owner[right.name]
  if la==ra:continue
  overlap=trees[left.name].overlap(trees[right.name])
  if not overlap:continue
  # All cross-assembly joints are listed contacts, with planar seating except the coat peg.
  bindings=[c for c in f['contacts'] if c['native_owner'] and {c['assembly'],c['owner']}=={la,ra}]
  for li,ri in overlap:
   lp=[left.matrix_world@left.data.vertices[k].co for k in left.data.polygons[li].vertices];rp=[right.matrix_world@right.data.vertices[k].co for k in right.data.polygons[ri].vertices]
   ok=False
   for c in bindings:
    if c['label']=='ticket bracket on rack post' and any(token in left.name or token in right.name for token in ['_PostPlate','_StandOff']):ok=True;break
    plane=c['point'][1]
    if (max(abs(p.z-plane) for p in lp)<.00004 and min(abs(p.z-plane) for p in rp)<.00004) or (max(abs(p.z-plane) for p in rp)<.00004 and min(abs(p.z-plane) for p in lp)<.00004):ok=True;break
   if ok:allowed.append([left.name,right.name])
   else:errors.append(['native',left.name,right.name])
for obj in draws:
 for other in context+accepted:
  if other not in all_trees:continue
  for li,ri in all_trees[obj].overlap(all_trees[other]):
   a=[obj.matrix_world@obj.data.vertices[k].co for k in obj.data.polygons[li].vertices];b=[other.matrix_world@other.data.vertices[k].co for k in other.data.polygons[ri].vertices]
   if other in context and other.name.removesuffix('-col').endswith('_'+floor['mat']) and min(p.z for p in a)>=ground-.00003 and max(p.z for p in b)<=ground+.00003:allowed.append([obj.name,other.name])
   elif obj.name.startswith('storm_shop_model_laundry_parcel_shelf0__') and other in accepted and other.name.startswith('storm_shop_model_laundry_parcel') and any(max(abs(p.z-(row['z0']+row['h'])) for p in a)<.00004 and min(p.z for p in b)>=row['z0']+row['h']-.00004 for row in f['original_records'] if '_parcel_shelf' in row['id']):allowed.append([obj.name,other.name])
   else:errors.append(['context',obj.name,other.name])
if errors:(out/'context_diagnostic.json').write_text(json.dumps({'evidence_class':'INERT','intersections':sorted({tuple(e) for e in errors})},indent=2)+'\n',newline='\n')
assert not errors,errors[:15]
scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=24;scene.render.resolution_x=1200;scene.render.resolution_y=800;scene.render.resolution_percentage=100
scene.world=bpy.data.worlds.new('Inspection');scene.world.use_nodes=True;scene.world.node_tree.nodes['Background'].inputs[0].default_value=(.5,.55,.6,1);scene.world.node_tree.nodes['Background'].inputs[1].default_value=.6
bpy.ops.object.light_add(type='AREA',location=(7.8,-42.0,3.1));bpy.context.object.data.energy=700;bpy.context.object.data.shape='DISK';bpy.context.object.data.size=4
views=[]
def render(label,eye,target,lens=45,owner=None,room=False):
 for obj in context+accepted:obj.hide_render=not room
 for obj in draws:obj.hide_render=owner is not None and not obj.name.startswith('storm_shop_model_laundry_'+owner+'__')
 bpy.ops.object.camera_add(location=eye);camera=bpy.context.object;camera.data.lens=lens;camera.rotation_euler=(Vector(target)-camera.location).to_track_quat('-Z','Y').to_euler();scene.camera=camera
 if owner is not None:
  corners=[obj.matrix_world@Vector(v) for obj in draws if not obj.hide_render for v in obj.bound_box]
  assert corners,owner
  middle=Vector(tuple((min(v[i] for v in corners)+max(v[i] for v in corners))*.5 for i in range(3)));axis=(camera.location-Vector(target)).normalized();distance=(camera.location-Vector(target)).length
  for attempt in range(100):
   camera.location=middle+axis*distance;camera.rotation_euler=(middle-camera.location).to_track_quat('-Z','Y').to_euler();bpy.context.view_layer.update()
   projected=[world_to_camera_view(scene,camera,v) for v in corners]
   if all(.05<p.x<.95 and .05<p.y<.95 and p.z>0 for p in projected):break
   distance*=1.07
  else:raise AssertionError(('frame fit',owner))
 scene.render.filepath=str(out/(label+'.png'));bpy.ops.render.render(write_still=True);views.append(label);bpy.data.objects.remove(camera,do_unlink=True)
render('room',(10.85,-43.5,1.65),(6.9,-41.7,1.30),28,room=True)
render('parcel_wall',(7.5,-42.0,1.7),(4.3,-42.0,1.50),34,room=True)
render('rack',(6.7,-42.0,1.6),(4.30,-42.0,1.35),42,'parcel_shelf0')
render('ticket_rail',(5.7,-42.0,2.50),(4.50,-42.0,2.44),42,'ticket_rail')
render('counter',(8.3,-42.0,1.65),(10.0,-41.3,.75),38,'counter')
render('window',(8.9,-41.3,1.10),(10.65,-41.3,.80),42,'window_plinth')
render('bench',(9.2,-43.25,.90),(9.2,-44.44,.32),46,'bench')
render('ledger_pencil',(8.9,-42.0,1.80),(9.98,-42.03,1.09),50)
(out/'inspection.json').write_text(json.dumps({'evidence_class':'INERT','closed_stocks':len(volumes),'assemblies':joins,'contacts':contacts_checked,'uv':uv_metrics,'source_triangle_retirement':counts,'allowed_contact_pairs':sorted({tuple(x) for x in allowed}),'unresolved_intersections':errors,'views':views},indent=2)+'\n',newline='\n')
print('LAUNDRY TRADE NATIVE:',len(volumes),'closed stocks;',len(joins),'joined assemblies;',len(contacts_checked),'bearings;',len(views),'rendered views')
