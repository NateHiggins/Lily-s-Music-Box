"""Inspect closed stocks, fitted joins and actual catalogue maps; render QA."""
from pathlib import Path
import hashlib,json,numpy as np
import bpy,bmesh
from mathutils import Vector
from mathutils.bvhtree import BVHTree
from bpy_extras.object_utils import world_to_camera_view
r=next(p for p in Path(__file__).resolve().parents if (p/'game/project.godot').is_file());out=r/'tmp/v2-finish-review/work-tables-native';out.mkdir(parents=True,exist_ok=True)
import os
source=Path(os.environ.get('WORK_TABLES_OUT',str(r)));asset=source/'art/blender/work_tables.blend';bpy.ops.wm.open_mainfile(filepath=str(asset))
f=json.loads((source/'art/blender/work_tables_construction.json').read_text(encoding='utf-8'));assert f==json.loads((source/'game/tests/fixtures/orison_work_tables.json').read_text(encoding='utf-8'))
for rel,h in f['source_bindings'].items():
 data=(r/rel).read_bytes();data=data if Path(rel).suffix in ['.blend','.glb','.png','.bin'] else data.replace(b'\r\n',b'\n');assert hashlib.sha256(data).hexdigest()==h,rel
for image in bpy.data.images:
 if image.source=='FILE':assert image.filepath.startswith('//') and Path(bpy.path.abspath(image.filepath)).is_file(),image.filepath
volumes=[];trees={}
bpy.context.view_layer.update()
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
joins=[];join_failures=[]
for a in f['assemblies']:
 stocks=[row['name'] for row in f['closed_stocks'] if row['assembly']==a['id']];adj={name:set() for name in stocks};edges=[]
 for i,left in enumerate(stocks):
  for right in stocks[i+1:]:
   if trees[left].overlap(trees[right]):adj[left].add(right);adj[right].add(left);edges.append([left,right])
 seen={stocks[0]};pending=list(seen)
 while pending:
  for neighbour in adj[pending.pop()]-seen:seen.add(neighbour);pending.append(neighbour)
 if len(seen)!=len(stocks):join_failures.append((a['id'],'disconnected',sorted(set(adj)-seen)))
 joins.append({'assembly':a['id'],'connected_components':1,'surface_contact_edges':edges})
assert not join_failures,join_failures
draws=[o for o in bpy.context.scene.objects if o.type=='MESH' and '__' in o.name and not o.hide_render];assert len(draws)==len(f['parts'])
def actual_tree(obj):return BVHTree.FromPolygons([obj.matrix_world@v.co for v in obj.data.vertices],[list(p.vertices) for p in obj.data.polygons],epsilon=0.)
uv_metrics=[]
for obj in draws:
 mesh=obj.data;mesh.calc_loop_triangles();points=np.asarray([v.co[:] for v in mesh.vertices],dtype=np.float64);indices=np.asarray([t.vertices[:] for t in mesh.loop_triangles]);p=points[indices];uv=np.asarray([[mesh.uv_layers.active.data[i].uv[:] for i in t.loops] for t in mesh.loop_triangles],dtype=np.float64)
 e=np.stack([p[:,1]-p[:,0],p[:,2]-p[:,0]],axis=2);d=np.stack([uv[:,1]-uv[:,0],uv[:,2]-uv[:,0]],axis=2);assert np.all(np.abs(np.linalg.det(d))>1e-12)
 metric=np.linalg.svd(e@np.linalg.inv(d),compute_uv=False);assert np.all((metric>.99)&(metric<1.01)),(obj.name,float(metric.min()),float(metric.max()))
 # A twisted welt can be manifold while its smoothed normal crosses a face.
 # Catch that tangent-handedness failure here, before Godot imports anything.
 for triangle in mesh.loop_triangles:
  for loop in triangle.loops:assert triangle.normal.dot(mesh.corner_normals[loop].vector)>.05,(obj.name,'inverted smooth corner',loop)
 uv_metrics.append({'part':obj.name,'minimum_metres_per_uv':float(metric.min()),'maximum_metres_per_uv':float(metric.max())})

import math
from mathutils import Matrix
scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=32
scene.render.resolution_x=1100;scene.render.resolution_y=950;scene.render.resolution_percentage=100
scene.world=bpy.data.worlds.new('Neutral table inspection');scene.world.use_nodes=True
scene.world.node_tree.nodes['Background'].inputs[0].default_value=(.55,.60,.65,1)
scene.world.node_tree.nodes['Background'].inputs[1].default_value=.6
for at,power,size in [((1,-1.5,2.5),150,1.5),((-1,.5,1.8),90,1.2)]:
 bpy.ops.object.light_add(type='AREA',location=at);light=bpy.context.object;light.data.energy=power;light.data.shape='DISK';light.data.size=size
 light.rotation_euler=(Vector((0,0,.5))-light.location).to_track_quat('-Z','Y').to_euler()
def bp(p):return Vector((p[0],-p[2],p[1]))
def pose(p,yaw):return Matrix.Translation(bp(p))@Matrix.Rotation(yaw,4,'Z')
assembly_trees={a['id']:[actual_tree(o) for o in draws if o.name.startswith(a['id']+'__')] for a in f['assemblies']}
supports=[]
for contact in f['contacts']:
 at=bp(contact['point']);assert contact['owner']=='floor' and abs(at.z)<.00003,contact
 hits=[t.ray_cast(at+Vector((0,0,-.004)),Vector((0,0,1)),.008) for t in assembly_trees[contact['assembly']]]
 assert any(p is not None and (p-at).length<.00003 and n.z<-.99 for p,n,_,_ in hits),contact
 supports.append(contact)
for obj in draws:assert min((obj.matrix_world@v.co).z for v in obj.data.vertices)>=-.00003,obj.name
with bpy.data.libraries.load(str(r/'art/blender/task_lamps.blend'),link=False) as (src,dst):dst.objects=[n for n in src.objects if n.startswith('TaskLamp_') and '__' in n]
lamps=dst.objects
for obj in lamps:scene.collection.objects.link(obj);obj.hide_render=True
bpy.context.view_layer.update()
installations=json.loads((r/'game/data/orison_v2/task_lamp_installations.json').read_text())['lamps']
radii={'office_green':.078,'bench_friction':.110,'landlord_enamel':.082,'architect_counterweight':.112}
bearings=[]
for row in installations:
 if row['support'] not in assembly_trees:continue
 center=bp(row['position']);radius=radii[row['variant']];points=[center]+[center+Vector((radius*f*math.cos(i*math.tau/64),radius*f*math.sin(i*math.tau/64),0)) for f in (.33,.67,1.) for i in range(64)]
 for at in points:
  hits=[t.ray_cast(at+Vector((0,0,.004)),Vector((0,0,-1)),.008) for t in assembly_trees[row['support']]]
  assert any(p is not None and (p-at).length<.00003 and n.z>.99 for p,n,_,_ in hits),(row['id'],list(at))
 bearings.append({'lamp':row['id'],'support':row['support'],'samples':len(points),'maximum_error_m':.00003})
# The original passive tabletop stock remains owned by its existing helper.
# Verify the lowest stock ring, plus support-local bounds, against new geometry.
props=json.loads((r/'game/data/orison_v2/domestic_surface_props.json').read_text())['props'];adjacent=[]
for prop in props:
 if prop['support'] not in assembly_trees:continue
 transform=pose(prop['position'],prop['yaw']);points=[]
 for surface in prop['surfaces']:
  values=surface['vertices'];points.extend(transform@bp(values[i:i+3]) for i in range(0,len(values),3))
 lowest=min(p.z for p in points);base={tuple(round(c,6) for c in p) for p in points if p.z<lowest+.00003};hits=0
 for point in base:
  at=Vector(point)
  if any(p is not None and abs(p.z-lowest)<.0005 and n.z>.9 for p,n,_,_ in [t.ray_cast(at+Vector((0,0,.004)),Vector((0,0,-1)),.010) for t in assembly_trees[prop['support']]]):hits+=1
 assert hits,(prop['id'],'no retained stock bearing',lowest)
 adjacent.append({'id':prop['id'],'support':prop['support'],'lowest_points':len(base),'seated_points':hits,'minimum_height':lowest})
views=[]
if os.environ.get('WORK_TABLES_RENDER','1')!='0':
 for identity,eye,target in [('2A_desk',(1.6,2.1,1.55),(0,0,.42)),('3B_workbench',(2.2,2.6,1.85),(0,0,.5)),('4B_terminal_desk',(1.45,1.9,1.55),(0,0,.5)),('5A_plantable',(2.4,2.8,2.),(0,0,.5)),('6A_deskwall',(2.8,3.5,2.),(0,0,.45)),('3B_workbench_detail',(1.8,1.1,1.2),(.72,.38,.82))]:
  table_id=identity.removesuffix('_detail')
  for obj in draws:obj.hide_render=not obj.name.startswith(table_id+'__')
  for obj in lamps:obj.hide_render=True
  row=next((x for x in installations if x['support']==table_id),None)
  if row:
   for obj in lamps:
    if obj.name.startswith('TaskLamp_'+row['variant']+'__'):
     obj.hide_render=False;obj.matrix_world=pose(row['position'],row['yaw'])
  bpy.ops.object.camera_add(location=eye);camera=bpy.context.object;camera.data.lens=48;camera.rotation_euler=(Vector(target)-camera.location).to_track_quat('-Z','Y').to_euler();scene.camera=camera
  scene.render.filepath=str(out/(identity+'.png'));bpy.ops.render.render(write_still=True);views.append({'id':identity,'file':identity+'.png'});bpy.data.objects.remove(camera,do_unlink=True)
(out/'inspection.json').write_text(json.dumps({'evidence_class':'INERT','closed_stocks':len(volumes),'joined_assemblies':joins,'uv':uv_metrics,'floor_contacts':supports,'lamp_bearings':bearings,'adjacent_stock':adjacent,'views':views,'scope':'Native local stock, metre charts and actual bearings. Runtime placement, collision and appearance require engine validation.'},indent=2)+'\n',newline='\n')
print('WORK TABLES NATIVE',len(volumes),'closed stocks;',len(supports),'floor contacts;',sum(x['samples'] for x in bearings),'lamp samples;',len(adjacent),'stock bearings;',len(views),'views')
