from pathlib import Path
import hashlib,json
import bpy,bmesh
from mathutils import Vector
from mathutils.bvhtree import BVHTree
r=next(p for p in Path(__file__).resolve().parents if (p/'game/project.godot').is_file());out=r/'tmp/shop-seating-native';out.mkdir(parents=True,exist_ok=True)
asset=r/'art/blender/shop_seating.blend';bpy.ops.wm.open_mainfile(filepath=str(asset))
f=json.loads((r/'art/blender/shop_seating_construction.json').read_text());assert f==json.loads((r/'game/tests/fixtures/orison_shop_seating.json').read_text())
for rel,h in f['source_bindings'].items():
 data=(r/rel).read_bytes();data=data if Path(rel).suffix in ['.blend','.glb','.png'] else data.replace(b'\r\n',b'\n');assert hashlib.sha256(data).hexdigest()==h,rel
for image in bpy.data.images:
 if image.source=='FILE':assert image.filepath.startswith('//') and Path(bpy.path.abspath(image.filepath)).is_file(),image.filepath
volumes=[]
for o in bpy.data.collections['ClosedConstruction'].objects:
 bm=bmesh.new();bm.from_mesh(o.data);assert all(e.is_manifold and e.is_contiguous for e in bm.edges) and bm.calc_volume(signed=True)>0,o.name
 unseen=set(bm.verts);components=0
 while unseen:
  components+=1;stack=[unseen.pop()]
  while stack:
   v=stack.pop()
   for edge in v.link_edges:
    other=edge.other_vert(v)
    if other in unseen:unseen.remove(other);stack.append(other)
 assert components==1,o.name
 actual=bm.calc_volume(signed=True);expected=next(x['volume_m3'] for x in f['closed_stocks'] if x['name']==o.name);assert abs(actual-expected)<1e-10
 volumes.append({'name':o.name,'volume_m3':actual});bm.free()
joins=[]
for a in f['assemblies']:
 stocks=[bpy.data.objects[row['name']] for row in f['closed_stocks'] if row['assembly']==a['id']]
 stock_trees={o.name:BVHTree.FromPolygons([o.matrix_world@v.co for v in o.data.vertices],[list(p.vertices) for p in o.data.polygons],epsilon=.00002) for o in stocks}
 adjacency={o.name:set() for o in stocks};edges=[]
 for i,left in enumerate(stocks):
  for right in stocks[i+1:]:
   intersections=stock_trees[left.name].overlap(stock_trees[right.name])
   if intersections:
    adjacency[left.name].add(right.name);adjacency[right.name].add(left.name);edges.append([left.name,right.name])
 seen={stocks[0].name};pending=list(seen)
 while pending:
  for neighbour in adjacency[pending.pop()]-seen:seen.add(neighbour);pending.append(neighbour)
 assert len(seen)==len(stocks),(a['id'],'disconnected stocks',sorted(set(adjacency)-seen))
 joins.append({'assembly':a['id'],'stocks':len(stocks),'surface_contact_edges':edges,'connected_components':1,'surface_contact_tolerance_m':.00002})
draws=[o for o in bpy.context.scene.objects if o.type=='MESH' and '__' in o.name and not o.hide_render];assert len(draws)==43
trees={}
for a in f['assemblies']:
 pieces=[o for o in draws if o.name.startswith(a['id']+'__')];vertices=[];faces=[]
 for o in pieces:
  start=len(vertices);vertices.extend(o.matrix_world@v.co for v in o.data.vertices);faces.extend([start+i for i in face.vertices] for face in o.data.polygons)
 trees[a['id']]=BVHTree.FromPolygons(vertices,faces,all_triangles=True)
 floor=a['floor'];fr=floor['rect'];z=floor['z0']+floor['h']
 assert min(v.z for v in vertices)>=z-.00002,a['id']
 for c in [c for c in f['contacts'] if c['assembly']==a['id']]:
  assert c['floor_owner']==floor['id']
  for p in [c['point']]+c['footprint']:
   at=Vector((p[0],-p[2],p[1]));assert abs(at.z-z)<.00002 and fr[0]<=at.x<=fr[2] and fr[1]<=at.y<=fr[3]
   hit,n,face,d=trees[a['id']].ray_cast(at-Vector((0,0,.005)),Vector((0,0,1)),.01)
   assert hit is not None and (hit-at).length<.00002,(a['id'],p)
scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=48;scene.render.resolution_x=1100;scene.render.resolution_y=720;scene.render.resolution_percentage=100
scene.world=bpy.data.worlds.new('Inspection');scene.world.use_nodes=True;scene.world.node_tree.nodes['Background'].inputs[0].default_value=(.5,.55,.6,1);scene.world.node_tree.nodes['Background'].inputs[1].default_value=.7
bpy.ops.object.light_add(type='SUN',location=(0,0,50));bpy.context.object.data.energy=2.3;bpy.context.object.rotation_euler=(.4,-.6,.3)
selected=[]
for kind,cell in [('chair','shop_funeral_parlour'),('pew','shop_funeral_parlour'),('stool','shop_otis_son'),('stool','shop_luncheonette')]:
 group=[a for a in f['assemblies'] if a['kind']==kind and a['cell']==cell];selected.extend([group[0],group[-1]])
views=[]
for a in selected:
 part=next(o for o in draws if o.name.startswith(a['id']+'__'));origin=part.location.copy();target=origin+Vector((0,0,.45 if a['kind']!='stool' else .42))
 for o in draws:o.hide_render=not o.name.startswith(a['id']+'__')
 for role,offset in [('front',Vector((-1.3,-1.4,.75))),('rear',Vector((1.3,1.4,.75)))]:
  if a['kind']=='pew':offset*=1.6
  name=a['id']+'_'+role+'.png';views.append(name);bpy.ops.object.camera_add(location=target+offset);cam=bpy.context.object;cam.data.lens=40;cam.rotation_euler=(target-cam.location).to_track_quat('-Z','Y').to_euler();scene.camera=cam;scene.render.filepath=str(out/name);bpy.ops.render.render(write_still=True);bpy.data.objects.remove(cam,do_unlink=True)
(out/'inspection.json').write_text(json.dumps({'evidence_class':'INERT','native_sha256':hashlib.sha256(asset.read_bytes()).hexdigest(),'closed_volumes':volumes,'assembly_stock_joins':joins,'source_boundary_stocks':len(bpy.data.collections['RetainedSourceBoxes'].objects),'bearing_samples':len(f['contacts'])*5,'parts':len(draws),'triangles':f['triangles'],'views':views},indent=2)+'\n')
print('SEATING NATIVE QA',len(volumes),'closed connected stocks;',len(f['contacts'])*5,'bearings;',len(views),'views')
