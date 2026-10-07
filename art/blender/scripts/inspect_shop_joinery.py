"""Inspect closed stocks, fitted joins and actual catalogue maps; render QA."""
from pathlib import Path
import hashlib,json,numpy as np
import bpy,bmesh
from mathutils import Vector
from mathutils.bvhtree import BVHTree
from bpy_extras.object_utils import world_to_camera_view
r=next(p for p in Path(__file__).resolve().parents if (p/'game/project.godot').is_file());out=r/'tmp/v2-finish-review/shop-joinery-native';out.mkdir(parents=True,exist_ok=True)
import os
source=Path(os.environ.get('SHOP_JOINERY_OUT',str(r)));asset=source/'art/blender/shop_joinery.blend';bpy.ops.wm.open_mainfile(filepath=str(asset))
f=json.loads((source/'art/blender/shop_joinery_construction.json').read_text(encoding='utf-8'));assert f==json.loads((source/'game/tests/fixtures/orison_shop_joinery.json').read_text(encoding='utf-8'))
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
uv_metrics=[]
for obj in draws:
 mesh=obj.data;mesh.calc_loop_triangles();points=np.asarray([v.co[:] for v in mesh.vertices],dtype=np.float64);indices=np.asarray([t.vertices[:] for t in mesh.loop_triangles]);p=points[indices];uv=np.asarray([[mesh.uv_layers.active.data[i].uv[:] for i in t.loops] for t in mesh.loop_triangles],dtype=np.float64)
 e=np.stack([p[:,1]-p[:,0],p[:,2]-p[:,0]],axis=2);d=np.stack([uv[:,1]-uv[:,0],uv[:,2]-uv[:,0]],axis=2);assert np.all(np.abs(np.linalg.det(d))>1e-12)
 metric=np.linalg.svd(e@np.linalg.inv(d),compute_uv=False);assert np.all((metric>.99)&(metric<1.01)),(obj.name,float(metric.min()),float(metric.max()))
 uv_metrics.append({'part':obj.name,'minimum_metres_per_uv':float(metric.min()),'maximum_metres_per_uv':float(metric.max())})
plan=json.loads((r/'art/data/shop_joinery/source_plan.json').read_text(encoding='utf-8'))
scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=24
scene.render.resolution_x=1200;scene.render.resolution_y=850;scene.render.resolution_percentage=100
scene.world=bpy.data.worlds.new('Inspection');scene.world.use_nodes=True
scene.world.node_tree.nodes['Background'].inputs[0].default_value=(.5,.55,.6,1)
scene.world.node_tree.nodes['Background'].inputs[1].default_value=.65
before=set(bpy.context.scene.objects);bpy.ops.import_scene.gltf(filepath=str(r/'game/assets/building/floor_01_cells/passage.gltf'))
passage=[o for o in bpy.context.scene.objects if o not in before and o.type=='MESH']
for obj in passage:obj.hide_render=True
all_contacts=[];all_counts={};all_allowed=[];views=[];contexts=[];assembled_retirements={}

def retire(context,records):
 counts={row['id']:0 for row in records};by_material={}
 for row in records:by_material.setdefault(row['mat'],[]).append(row)
 for old in context:
  candidates=next((items for key,items in by_material.items() if old.name.removesuffix('-col').endswith('_'+key)),[])
  if not candidates:continue
  bm=bmesh.new();bm.from_mesh(old.data);remove=[]
  for face in bm.faces:
   points=[old.matrix_world@v.co for v in face.verts];normal=(points[1]-points[0]).cross(points[2]-points[0]).normalized();axis=max(range(3),key=lambda i:abs(normal[i]));matches=[]
   if abs(normal[axis])<.999:continue
   for row in candidates:
    q=row['rect'];low=Vector((q[0],q[1],row['z0']));high=Vector((q[2],q[3],row['z0']+row['h']));plane=high[axis] if normal[axis]>0 else low[axis]
    if all(abs(v[axis]-plane)<.00003 and all(low[i]-.00003<=v[i]<=high[i]+.00003 for i in range(3)) for v in points):matches.append(row['id'])
   if matches:assert len(matches)==1;remove.append(face);counts[matches[0]]+=1
  bmesh.ops.delete(bm,geom=remove,context='FACES');bm.to_mesh(old.data);bm.free()
 assert all(count==12 for count in counts.values()),{key:value for key,value in counts.items() if value!=12}
 return counts

def render(label,eye,target,owner=None,room=False):
 for obj in context+accepted+passage:obj.hide_render=not room
 for obj in draws:obj.hide_render=obj not in local_draws or (owner is not None and not obj.name.startswith(owner+'__'))
 bpy.ops.object.camera_add(location=eye);camera=bpy.context.object;camera.data.lens=43 if not room else 30
 camera.rotation_euler=(Vector(target)-camera.location).to_track_quat('-Z','Y').to_euler();scene.camera=camera
 if owner is not None:
  corners=[obj.matrix_world@Vector(v) for obj in local_draws if not obj.hide_render for v in obj.bound_box]
  axis=(camera.location-Vector(target)).normalized();distance=(camera.location-Vector(target)).length
  for attempt in range(100):
   camera.location=Vector(target)+axis*distance;bpy.context.view_layer.update()
   points=[world_to_camera_view(scene,camera,v) for v in corners]
   if all(.05<p.x<.95 and .05<p.y<.95 and p.z>0 for p in points):break
   distance*=1.06
  else:raise AssertionError(('frame fit',owner))
 scene.render.filepath=str(out/(label+'.png'));bpy.ops.render.render(write_still=True)
 views.append({'id':label,'eye':list(camera.location),'target':list(target),'file':label+'.png','context':room})
 bpy.data.objects.remove(camera,do_unlink=True)

for cell in f['runtime']['cells']:
 identity=cell['id'];floor=next(a['floor'] for a in f['assemblies'] if a['cell']==identity);ground=floor['z0']+floor['h'];q=floor['rect']
 local_draws=[obj for obj in draws if any(part['name']==obj.name for part in cell['parts'])]
 for obj in local_draws:
  assert all(q[0]-.00003<=(obj.matrix_world@v.co).x<=q[2]+.00003 and q[1]-.00003<=(obj.matrix_world@v.co).y<=q[3]+.00003 and ground-.00003<=(obj.matrix_world@v.co).z<=3.3 for v in obj.data.vertices),('shop envelope',obj.name)
 before=set(bpy.context.scene.objects);bpy.ops.import_scene.gltf(filepath=str(r/f'game/assets/building/floor_01_cells/{identity}.gltf'))
 context=[o for o in bpy.context.scene.objects if o not in before and o.type=='MESH'];accepted=[]
 retirements={row['id']:row for row in f['original_records'] if row['batch']==floor['batch']}
 for family in plan['context_families']:
  fixture=json.loads((r/f'game/tests/fixtures/orison_{family}.json').read_text(encoding='utf-8'))
  wanted={part['name'] for part in fixture['parts'] if part.get('cell')==identity}
  if not wanted:continue
  if 'original_draws' in fixture['runtime']:
   original=fixture['runtime'];whole={part['name']:part['expected_triangles'] for part in original['original_draws']}
   whole[original['raw_hull_name']]=original['hull_triangles'];removed={}
   for obj in list(context):
    if obj.name not in whole:continue
    obj.data.calc_loop_triangles();assert len(obj.data.loop_triangles)==whole[obj.name]
    removed[obj.name]=whole[obj.name];context.remove(obj);bpy.data.objects.remove(obj,do_unlink=True)
   assert removed==whole,(family,'assembled receiver retirement')
   assembled_retirements.update(removed)
  for row in fixture['original_records']:
   if row.get('batch')==floor['batch'] and 'mat' in row:retirements[row['id']]=row
  with bpy.data.libraries.load(str(r/f'art/blender/{family}.blend'),link=False) as (src,dst):dst.objects=[name for name in src.objects if name in wanted]
  assert len(dst.objects)==len(wanted),(identity,family,'missing accepted native partitions')
  for obj in dst.objects:bpy.context.scene.collection.objects.link(obj);obj.hide_render=False;accepted.append(obj)
 counts=retire(context,list(retirements.values()));all_counts.update(counts)
 relevant=local_draws+context+accepted+passage;actual={obj:actual_tree(obj) for obj in relevant if obj.data.polygons}
 contacts=[c for c in f['contacts'] if any(part['name'].startswith(c['assembly']+'__') for part in cell['parts'])]
 for c in contacts:
  point=Vector((c['point'][0],-c['point'][2],c['point'][1]));direction=Vector((c['direction'][0],-c['direction'][2],c['direction'][1]))
  owners=[obj for obj in context if obj.name.removesuffix('-col').endswith('_'+rows[c['owner']]['mat']) and obj in actual]
  stocks=[obj for obj in local_draws if obj.name.startswith(c['assembly']+'__')]
  for objects,sign,label in [(owners,1,'owner'),(stocks,-1,'stock')]:
   hits=[]
   for obj in objects:
    hit,normal,_,_=actual[obj].ray_cast(point+direction*.006*sign,-direction*sign,.012)
    if hit is not None and normal.dot(direction*sign)>0:hits.append((hit-point).length)
   assert hits and min(hits)<.00003,(identity,label,c,hits)
  all_contacts.append(c)
 errors=[];allowed=[]
 for obj in local_draws:
  for other in context+accepted+passage:
   if other not in actual:continue
   for li,ri in actual[obj].overlap(actual[other]):
    a=[obj.matrix_world@obj.data.vertices[k].co for k in obj.data.polygons[li].vertices];b=[other.matrix_world@other.data.vertices[k].co for k in other.data.polygons[ri].vertices]
    ok=False
    for c in contacts:
     if not obj.name.startswith(c['assembly']+'__') or other not in context or not other.name.removesuffix('-col').endswith('_'+rows[c['owner']]['mat']):continue
     point=Vector((c['point'][0],-c['point'][2],c['point'][1]));direction=Vector((c['direction'][0],-c['direction'][2],c['direction'][1]))
     # Native points remain wholly outside the owner; overlap is their seating plane.
     if min((p-point).dot(direction) for p in a)>=-.00003 and max((p-point).dot(direction) for p in b)<=.00003:ok=True;break
    if ok:allowed.append([obj.name,other.name])
    else:errors.append([obj.name,other.name])
 if errors:(out/(identity+'_intersections.json')).write_text(json.dumps(sorted({tuple(x) for x in errors}),indent=2)+'\n',encoding='utf-8')
 assert not errors,(identity,errors[:12])
 all_allowed.extend(allowed);contexts.append({'cell':identity,'accepted_parts':len(accepted),'retired_source_records':len(counts),'unresolved_intersections':0})
 bpy.ops.object.light_add(type='AREA',location=((q[0]+q[2])/2,(q[1]+q[3])/2,3.15));light=bpy.context.object;light.data.energy=650;light.data.shape='DISK';light.data.size=4
 for assembly in [a for a in f['assemblies'] if a['cell']==identity]:
  row=rows[assembly['id']];rect=row['rect'];cx=(rect[0]+rect[2])/2;cy=(rect[1]+rect[3])/2
  if assembly['kind']=='closed_door':
   sign=1 if cy<(q[1]+q[3])/2 else -1
   render(identity+'_door',(cx+.90,cy+sign*3.0,1.65),(cx,cy,1.08),assembly['id'])
   inward_x=1 if cx<(q[0]+q[2])/2 else -1
   render(identity+'_context',(cx+inward_x*1.40,cy+sign*2.65,1.65),(cx,cy,1.15),room=True)
  else:
   render(identity+'_window_back',(cx-2.,cy-1.2,1.6),(cx,cy,.80),assembly['id'])
   render(identity+'_empty_window',(cx+2.,cy-1.2,1.6),(cx,cy,.70),assembly['id'])
 bpy.data.objects.remove(light,do_unlink=True)
 for obj in context+accepted:bpy.data.objects.remove(obj,do_unlink=True)
 for obj in passage:obj.hide_render=True

(out/'inspection.json').write_text(json.dumps({'evidence_class':'INERT','closed_stocks':len(volumes),'assemblies':joins,'contacts':all_contacts,'uv':uv_metrics,'source_triangle_retirement':all_counts,'assembled_retirements':assembled_retirements,'allowed_contact_pairs':sorted({tuple(x) for x in all_allowed}),'contexts':contexts,'views':views,'scope':'Closed door/frame and empty window display geometry only; backs remain unmodelled and non-interactive. Accepted receivers are included as conservative restoration context; production cabinet presence retains its existing owner.'},indent=2)+'\n',encoding='utf-8')
print('SHOP JOINERY NATIVE:',len(volumes),'closed stocks;',len(joins),'joined assemblies;',len(all_contacts),'bearings;',len(views),'views')
