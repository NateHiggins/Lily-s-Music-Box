"""Inspect the saved mounts against imported retained faces; no source edits."""
from pathlib import Path
import hashlib,json,math,os
import bpy,bmesh
from mathutils import Vector
from mathutils.bvhtree import BVHTree
ROOT=next(p for p in Path(__file__).resolve().parents if (p/'game/project.godot').is_file())
OUT=Path(os.environ.get('BAR_PIPE_INSPECT_OUT',str(ROOT/'tmp/bar-pipe-supports/native')));OUT.mkdir(parents=True,exist_ok=True)
report=json.loads((ROOT/'art/blender/bar_pipe_supports_construction.json').read_text())
plan=json.loads((ROOT/'art/data/bar_pipe_supports/source_plan.json').read_text())
native=ROOT/'art/blender/bar_pipe_supports.blend';assert hashlib.sha256(native.read_bytes()).hexdigest()==report['native_sha256']
bpy.ops.wm.open_mainfile(filepath=str(native))
checks=[]
for row in report['closed_stocks']:
 obj=bpy.data.objects[row['name']];bm=bmesh.new();bm.from_mesh(obj.data)
 assert all(e.is_manifold for e in bm.edges) and bm.calc_volume(signed=True)>0,row['name']
 assert abs(bm.calc_volume(signed=True)-row['volume_m3'])<1e-8,row['name']
 checks.append({'name':obj.name,'volume_m3':bm.calc_volume(signed=True),'nonmanifold_edges':0});bm.free()
before=set(bpy.context.scene.objects)
bpy.ops.import_scene.gltf(filepath=str(ROOT/'game/assets/building/floor_01_cells/shop_bar.gltf'))
context=[obj for obj in bpy.context.scene.objects if obj not in before]
# Existing newly fitted light mounts are read-only conflict/context geometry.
before=set(bpy.context.scene.objects);bpy.ops.import_scene.gltf(filepath=str(ROOT/'game/assets/props/bar_fixture_mounts.glb'))
fixture_context=[obj for obj in bpy.context.scene.objects if obj not in before]
for obj in fixture_context:
 if obj.type=='MESH':
  key='brass_dull' if '__brass_dull' in obj.name else 'iron_blackened'
  if key in bpy.data.materials:obj.data.materials.clear();obj.data.materials.append(bpy.data.materials[key])
verts=[];faces=[];owners=[]
for obj in context+fixture_context:
 if obj.type!='MESH':continue
 offset=len(verts);verts.extend(obj.matrix_world@v.co for v in obj.data.vertices)
 for p in obj.data.polygons:faces.append(tuple(offset+i for i in p.vertices));owners.append(obj.name)
tree=BVHTree.FromPolygons(verts,faces,all_triangles=False)
def b(value):return Vector((value[0],-value[2],value[1]))
bearings=[];spans=[]
for row in report['contacts']:
 at=b(row['bearing']);direction=b(row['direction']);seed=Vector((1,0,0)) if abs(direction.z)>.9 else Vector((0,0,1));other=direction.cross(seed)
 if 'inline_source' in row:
  points=[at]+[at+row['bearing_radius_m']*.8*(seed*math.cos(i*math.tau/8)+other*math.sin(i*math.tau/8)) for i in range(8)]
 else:
  points=[at+seed*u+other*v for u in [-.044,-.022,0,.022,.044] for v in [-.044,-.022,0,.022,.044]]
 for point in points:
  hit,n,index,d=tree.ray_cast(point-direction*.004,direction,.008)
  assert hit is not None and (hit-point).length<plan['fit_tolerance_m'] and owners[index]==row['owner'],(row['id'],point,hit,None if index is None else owners[index])
  bearings.append({'assembly':row['id'],'point':list(point),'owner':owners[index],'distance_m':(hit-point).length})
 start=b(row['fixture_endpoint']);end=at
 routes=[(start,end)]+[(b(row['free_offset_riser'][0]),b(row['free_offset_riser'][1]))] if 'free_offset_riser' in row else [(start,end)]
 for start,end in routes:
  direction=(end-start).normalized();seed=Vector((1,0,0)) if abs(direction.z)>.9 else Vector((0,0,1));other=direction.cross(seed)
  for offset in [Vector((0,0,0)),seed*.006,-seed*.006,other*.006,-other*.006]:
   hit,n,index,d=tree.ray_cast(start+direction*.014+offset,direction,(end-start).length-.03)
   assert hit is None,(row['id'],'blocked native span',hit,owners[index])
   spans.append({'assembly':row['id'],'start':list(start+offset),'end':list(end+offset),'clear':True})
pipe_samples=[]
def stock_tree(objects):
 points=[];triangles=[]
 for obj in objects:
  offset=len(points);points.extend(obj.matrix_world@v.co for v in obj.data.vertices)
  for face in obj.data.polygons:triangles.append(tuple(offset+i for i in face.vertices))
 return BVHTree.FromPolygons(points,triangles,all_triangles=False)
band_trees={}
for row in report['pipe_contacts']:
 name=row['assembly']
 if name not in band_trees:band_trees[name]=stock_tree([bpy.data.objects[name+'_UpperBand'],bpy.data.objects[name+'_LowerBand']])
 at=b(row['point']);normal=b(row['normal']);start=at-normal*.004
 old,n,index,d=tree.ray_cast(start,normal,.008);new,n2,i2,d2=band_trees[name].ray_cast(start,normal,.008)
 assert old is not None and new is not None and (old-at).length<plan['fit_tolerance_m'] and (new-at).length<plan['fit_tolerance_m'],(name,at,old,new)
 assert owners[index]==row['owner'],(name,owners[index],row['owner'])
 pipe_samples.append({'assembly':name,'point':list(at),'old_error_m':(old-at).length,'new_error_m':(new-at).length})
scene=bpy.context.scene;scene.render.engine='BLENDER_EEVEE';scene.render.resolution_x=1280;scene.render.resolution_y=960;scene.render.resolution_percentage=100
scene.world=bpy.data.worlds.new('ReadOnlyStudio');scene.world.use_nodes=True;scene.world.node_tree.nodes['Background'].inputs['Color'].default_value=(.22,.22,.22,1);scene.world.node_tree.nodes['Background'].inputs['Strength'].default_value=.8
sun_data=bpy.data.lights.new('ReadOnlySun','SUN');sun_data.energy=2.;sun=bpy.data.objects.new('ReadOnlySun',sun_data);scene.collection.objects.link(sun);sun.rotation_euler=(.5,-.4,.2)
camera_data=bpy.data.cameras.new('ReadOnlyCamera');camera=bpy.data.objects.new('ReadOnlyCamera',camera_data);scene.collection.objects.link(camera);scene.camera=camera;camera_data.lens=28;camera_data.clip_start=.02
views=[('collar_close',(-7.56,-36.42,-.57),(-7.4,-36.2,-.32)),('bolted_split',(-7.4,-36.36,-.27),(-7.4,-36.27,-.34)),('ceiling_grid',(-10.5,-33.1,-1.4),(-2.,-34.3,-.2)),('well_drop',(-4.8,-33.7,.4),(-4.4,-34.1,1.4))]
renders=[]
for name,at,target in views:
 camera.location=at;camera.rotation_euler=(Vector(target)-camera.location).to_track_quat('-Z','Y').to_euler();scene.render.filepath=str(OUT/(name+'.png'));bpy.ops.render.render(write_still=True);renders.append(name+'.png')
(OUT/'inspection.json').write_text(json.dumps({'evidence_class':'INERT','native_sha256':report['native_sha256'],'closed_stocks':checks,'bearing_samples':bearings,'pipe_samples':pipe_samples,'clear_span_samples':spans,'renders':renders,'note':'Saved native mounts and original retained geometry. Native renders omit the dynamic lighting actors; ordinary production views and route checks are separate.'},indent=2)+'\n')
print('NATIVE PIPE SUPPORTS:',len(checks),'closed stocks;',len(bearings),'bearing samples;',len(spans),'clear span samples')
