"""Inspect the saved mounts against imported retained faces; no source edits."""
from pathlib import Path
import hashlib,json,math,os
import bpy,bmesh
from mathutils import Vector
from mathutils.bvhtree import BVHTree
ROOT=next(p for p in Path(__file__).resolve().parents if (p/'game/project.godot').is_file())
OUT=Path(os.environ.get('BAR_FIXTURE_INSPECT_OUT',str(ROOT/'tmp/bar-fixture-supports/native')));OUT.mkdir(parents=True,exist_ok=True)
report=json.loads((ROOT/'art/blender/bar_fixture_mounts_construction.json').read_text())
plan=json.loads((ROOT/'art/data/bar_fixture_mounts/source_plan.json').read_text())
native=ROOT/'art/blender/bar_fixture_mounts.blend';assert hashlib.sha256(native.read_bytes()).hexdigest()==report['native_sha256']
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
verts=[];faces=[];owners=[]
for obj in context:
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
for row in report['retained_rods']:
 at=Vector(row['rod']['p0']);hit,n,index,d=tree.ray_cast(at-Vector((0,0,.004)),Vector((0,0,1)),.008)
 assert hit is not None and (hit-at).length<plan['fit_tolerance_m'],row
 bearings.append({'assembly':row['marker']['id'],'point':list(at),'owner':owners[index],'distance_m':(hit-at).length,'original_rod_retained':True})
scene=bpy.context.scene;scene.render.engine='BLENDER_EEVEE';scene.render.resolution_x=1280;scene.render.resolution_y=960;scene.render.resolution_percentage=100
scene.world=bpy.data.worlds.new('ReadOnlyStudio');scene.world.use_nodes=True;scene.world.node_tree.nodes['Background'].inputs['Color'].default_value=(.22,.22,.22,1);scene.world.node_tree.nodes['Background'].inputs['Strength'].default_value=.8
sun_data=bpy.data.lights.new('ReadOnlySun','SUN');sun_data.energy=2.;sun=bpy.data.objects.new('ReadOnlySun',sun_data);scene.collection.objects.link(sun);sun.rotation_euler=(.5,-.4,.2)
camera_data=bpy.data.cameras.new('ReadOnlyCamera');camera=bpy.data.objects.new('ReadOnlyCamera',camera_data);scene.collection.objects.link(camera);scene.camera=camera;camera_data.lens=28;camera_data.clip_start=.02
views=[('pool_mount',(-7.7,-32.3,-1.25),(-7.4,-31.25,-.27)),('canopy_stays',(-6.8,-31.5,-1.4),(-2,-29.7,-.65)),('west_wall_bearing',(-10.8,-35.7,-.60),(-11.44,-35.4,-.42)),('well_inline',(-2.4,-33.65,1.45),(-2.6,-33.4,1.64))]
renders=[]
for name,at,target in views:
 camera.location=at;camera.rotation_euler=(Vector(target)-camera.location).to_track_quat('-Z','Y').to_euler();scene.render.filepath=str(OUT/(name+'.png'));bpy.ops.render.render(write_still=True);renders.append(name+'.png')
(OUT/'inspection.json').write_text(json.dumps({'evidence_class':'INERT','native_sha256':report['native_sha256'],'closed_stocks':checks,'bearing_samples':bearings,'clear_span_samples':spans,'renders':renders,'note':'Saved native mounts and original retained geometry. Native renders omit the dynamic lighting actors; ordinary production views and route checks are separate.'},indent=2)+'\n')
print('NATIVE BAR MOUNTS:',len(checks),'closed stocks;',len(bearings),'bearing samples;',len(spans),'clear span samples')
