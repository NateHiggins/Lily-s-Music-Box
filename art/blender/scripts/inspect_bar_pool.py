"""Inspect closed stocks, fitted joins and actual catalogue maps; render QA."""
from pathlib import Path
import hashlib,json
import bpy,bmesh
from mathutils import Vector
from mathutils.bvhtree import BVHTree
r=next(p for p in Path(__file__).resolve().parents if (p/'game/project.godot').is_file());out=r/'tmp/pool-fabrication/production-native';out.mkdir(parents=True,exist_ok=True)
source=r;asset=source/'art/blender/bar_pool.blend';bpy.ops.wm.open_mainfile(filepath=str(asset))
f=json.loads((source/'art/blender/bar_pool_construction.json').read_text());assert f==json.loads((source/'game/tests/fixtures/orison_bar_pool.json').read_text())
for rel,h in f['source_bindings'].items():
 data=(r/rel).read_bytes();data=data if Path(rel).suffix in ['.blend','.glb','.png','.bin'] else data.replace(b'\r\n',b'\n');assert hashlib.sha256(data).hexdigest()==h,rel
for image in bpy.data.images:
 if image.source=='FILE':assert image.filepath.startswith('//') and Path(bpy.path.abspath(image.filepath)).is_file(),image.filepath
volumes=[];trees={}
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
native_vertices=[];native_faces=[]
for o in draws:
 offset=len(native_vertices);native_vertices.extend(o.matrix_world@v.co for v in o.data.vertices)
 native_faces.extend(tuple(offset+i for i in p.vertices) for p in o.data.polygons)
table=BVHTree.FromPolygons(native_vertices,native_faces)
pocket_samples=[]
for pocket in f['pockets']:
 for dx,dz in [( .013,.017),(-.018,.011)]:
  x,y,z=pocket['mouth'];at=Vector((x+dx,-z-dz,y+.008));hit=table.ray_cast(at,Vector((0,0,-1)),.23)
  assert hit[0] is not None and abs(hit[0].z-pocket['floor_open_until'])<.00003,(pocket['id'],at,hit,pocket['floor_open_until'])
  pocket_samples.append({'pocket':pocket['id'],'hit_native':list(hit[0]),'inner_bottom_y':pocket['floor_open_until']})
scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=24;scene.render.resolution_x=1100;scene.render.resolution_y=720;scene.render.resolution_percentage=100
scene.world=bpy.data.worlds.new('Inspection');scene.world.use_nodes=True;scene.world.node_tree.nodes['Background'].inputs[0].default_value=(.5,.55,.6,1);scene.world.node_tree.nodes['Background'].inputs[1].default_value=.7
bpy.ops.object.light_add(type='SUN',location=(0,0,50));bpy.context.object.data.energy=2.3;bpy.context.object.rotation_euler=(.4,-.6,.3)
groups=[[a['id'] for a in f['assemblies']]]
views=[]
for ids in groups:
 visible=[o for o in draws if any(o.name.startswith(identity+'__') for identity in ids)]
 for o in draws:o.hide_render=o not in visible
 vertices=[o.matrix_world@v.co for o in visible for v in o.data.vertices];low=Vector(tuple(min(v[i] for v in vertices) for i in range(3)));high=Vector(tuple(max(v[i] for v in vertices) for i in range(3)));center=(low+high)*.5
 size=max(high-low);distance=max(.6,size)*1.7
 for role,offset in [('front',Vector((1,-.65,.50))),('rear',Vector((-1,.65,.40))),('top',Vector((.2,-.3,1.2)))]:
  name=ids[0]+'_'+role+'.png';views.append(name);bpy.ops.object.camera_add(location=center+offset*distance);cam=bpy.context.object;cam.data.lens=42;cam.rotation_euler=(center-cam.location).to_track_quat('-Z','Y').to_euler();scene.camera=cam;scene.render.filepath=str(out/name);bpy.ops.render.render(write_still=True);bpy.data.objects.remove(cam,do_unlink=True)
(out/'inspection.json').write_text(json.dumps({'evidence_class':'INERT','native_sha256':hashlib.sha256(asset.read_bytes()).hexdigest(),'closed_volumes':volumes,'assembly_stock_joins':joins,'source_boundary_stocks':len(bpy.data.collections['RetainedSourceBoxes'].objects),'parts':len(draws),'triangles':f['triangles'],'pocket_samples':pocket_samples,'views':views},indent=2)+'\n')
print('BAR POOL NATIVE QA',len(volumes),'closed connected stocks;',len(joins),'joined assemblies;',len(views),'views')
