"""Inspect actual saved ceiling stocks and source-equal charts; studio lights are diagnostic only."""
from pathlib import Path
import hashlib,json,os,math
import bpy,bmesh
from mathutils import Vector
from mathutils.bvhtree import BVHTree
R=next(p for p in Path(__file__).resolve().parents if (p/'game/project.godot').is_file());out=Path(os.environ.get('BAR_CEILING_INSPECT_OUT',str(R/'tmp/bar-ceiling-finish/native')));out.mkdir(parents=True,exist_ok=True)
report=json.loads((R/'art/blender/bar_ceiling_finish_construction.json').read_bytes());native=R/'art/blender/bar_ceiling_finish.blend';assert hashlib.sha256(native.read_bytes()).hexdigest()==report['native_sha256'];bpy.ops.wm.open_mainfile(filepath=str(native));checks=[]
for row in report['closed_stocks']:
 obj=bpy.data.objects[row['name']];bm=bmesh.new();bm.from_mesh(obj.data);assert all(e.is_manifold for e in bm.edges) and bm.calc_volume(signed=True)>0;assert abs(bm.calc_volume(signed=True)-row['volume_m3'])<1e-8;checks.append(row);bm.free()
part=bpy.data.objects[report['parts'][0]['name']]
def tree(objects):
 v=[];f=[]
 for obj in objects:
  if obj.type!='MESH':continue
  offset=len(v);v.extend(obj.matrix_world@x.co for x in obj.data.vertices)
  for p in obj.data.polygons:f.append(tuple(offset+i for i in p.vertices))
 return BVHTree.FromPolygons(v,f,all_triangles=False)
new_tree=tree([part]);before=set(bpy.context.scene.objects);bpy.ops.import_scene.gltf(filepath=str(R/'game/assets/building/floor_01_cells/shop_bar.gltf'));context=[x for x in bpy.context.scene.objects if x not in before];old_tree=tree(context)
def b(v):return Vector((v[0],-v[2],v[1]))
samples=[]
for row in report['original_triangles']:
 points=[b(p) for p in row['points']];normal=b(row['normal']);center=sum(points,Vector((0,0,0)))/3
 for at in [center]+[center*.6+p*.4 for p in points]:
  old,n,i,d=old_tree.ray_cast(at+normal*.004,-normal,.008);new,n2,i2,d2=new_tree.ray_cast(at+normal*.004,-normal,.008)
  assert old is not None and new is not None and (old-at).length<.00002 and (new-at).length<.00002,(row['source'],at,old,new)
  samples.append({'source':row['source'],'point':list(at),'old_error_m':(old-at).length,'new_error_m':(new-at).length})
# Remove only the four ceiling face ranges from read-only context for the render.
owner=next(o for o in context if o.name=='F01_OWN_SHOP_BAR_retail_bar_soot-col');bm=bmesh.new();bm.from_mesh(owner.data);remove=[]
for face in bm.faces:
 points=[owner.matrix_world@v.co for v in face.verts];n=owner.matrix_world.to_3x3().inverted().transposed()@face.normal;axis=max(range(3),key=lambda i:abs(n[i]))
 for row in report['original_records']:
  rect=row['rect'];low=Vector((rect[0],rect[1],row['z0']));high=Vector((rect[2],rect[3],row['z0']+row['h']));plane=high[axis] if n[axis]>0 else low[axis]
  if abs(n[axis])>.999 and all(all(low[i]-.00002<=p[i]<=high[i]+.00002 for i in range(3)) and abs(p[axis]-plane)<.00002 for p in points):remove.append(face);break
assert len(remove)==48;bmesh.ops.delete(bm,geom=remove,context='FACES');bm.to_mesh(owner.data);bm.free()
scene=bpy.context.scene;scene.render.engine='BLENDER_EEVEE';scene.render.resolution_x=1280;scene.render.resolution_y=960;scene.render.resolution_percentage=100
scene.world=bpy.data.worlds.new('DiagnosticStudio');scene.world.use_nodes=True;scene.world.node_tree.nodes['Background'].inputs['Color'].default_value=(.22,.22,.22,1);scene.world.node_tree.nodes['Background'].inputs['Strength'].default_value=.8
sun_data=bpy.data.lights.new('DiagnosticSun','SUN');sun_data.energy=2.;sun=bpy.data.objects.new('DiagnosticSun',sun_data);scene.collection.objects.link(sun);sun.rotation_euler=(.5,-.4,.2)
area_data=bpy.data.lights.new('DiagnosticRakingLight','AREA');area_data.energy=8.;area_data.size=.12;area=bpy.data.objects.new('DiagnosticRakingLight',area_data);scene.collection.objects.link(area);area.hide_render=True
camera_data=bpy.data.cameras.new('DiagnosticCamera');camera=bpy.data.objects.new('DiagnosticCamera',camera_data);scene.collection.objects.link(camera);scene.camera=camera;camera_data.lens=28;camera_data.clip_start=.01
views=[('micrograin',(-7.4,-31.25,-.27),(-7.4,-31.25,-.15),True),('pipe_bearing',(-7.5,-31.6,-.75),(-7.4,-31.6,-.15),True),('ceiling_field',(-7.4,-33.25,-1.365),(-7.4,-31.25,-.15),False),('well_boundary',(-3.8,-33.5,-1.365),(-5.65,-33.4,-.15),False)];renders=[]
for name,at,target,raking in views:
 camera.location=at;camera.rotation_euler=(Vector(target)-camera.location).to_track_quat('-Z','Y').to_euler();area.hide_render=not raking;area.location=Vector(target)+Vector((.12,-.1,-.04));area.rotation_euler=(Vector(target)-area.location).to_track_quat('-Z','Y').to_euler();scene.render.filepath=str(out/(name+'.png'));bpy.ops.render.render(write_still=True);renders.append(name+'.png')
(out/'inspection.json').write_text(json.dumps({'evidence_class':'INERT','native_sha256':report['native_sha256'],'closed_stocks':checks,'source_equal_samples':samples,'renders':renders,'note':'Saved native and catalogue maps with read-only original context. Raking studio light in micrograin/pipe_bearing is diagnostic only; production capture uses unchanged original fixtures and carried lamp.'},indent=2)+'\n')
print('NATIVE CEILING FINISH:',len(checks),'closed original stocks;',len(samples),'source-equal samples')
