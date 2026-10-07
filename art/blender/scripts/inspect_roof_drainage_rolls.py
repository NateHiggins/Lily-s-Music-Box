"""Reopen actual roll stocks and compare their upper faces to the retained field."""
from pathlib import Path
import json,hashlib,math
import bpy,bmesh
from mathutils import Vector
from mathutils.bvhtree import BVHTree
R=next(path for path in Path(__file__).resolve().parents if (path/'game/project.godot').is_file());O=R/'art/blender';out=R/'tmp/roof-drainage-review/rolls';out.mkdir(parents=True,exist_ok=True)
report=json.loads((O/'roof_membrane_construction.json').read_bytes());native=O/'roof_membrane.blend';assert hashlib.sha256(native.read_bytes()).hexdigest()==report['native_sha256'];bpy.ops.wm.open_mainfile(filepath=str(native))
context=bpy.data.collections.new('ReadOnlyField');bpy.context.scene.collection.children.link(context)
with bpy.data.libraries.load(str(R/'art/blender/roof_drainage_falls.blend'),link=False) as (available,target):target.objects=[name for name in available.objects if name.endswith('__Membrane')]
for obj in target.objects:
 if obj is not None:context.objects.link(obj);bpy.context.view_layer.update();obj.hide_render=True
trees={o.name.split('__')[0]:BVHTree.FromPolygons([v.co for v in o.data.vertices],[tuple(p.vertices) for p in o.data.polygons if p.normal.z>.999],all_triangles=False) for o in target.objects};origins={o.name.split('__')[0]:tuple(o.location) for o in target.objects}
def backing(owner,point):
 pivot=origins[owner]
 for dx,dy in [(0.,0.),(.000002,0.),(-.000002,0.),(0.,.000002),(0.,-.000002)]:
  query=Vector((point[0]+dx-pivot[0],point[1]+dy-pivot[1],point[2]+.03-pivot[2]));hit,n,index,d=trees[owner].ray_cast(query,Vector((0,0,-1)),.06)
  if hit is not None:return hit.z+pivot[2],[dx,dy]
 raise AssertionError(('Missing retained field under roll',owner,point))
closed=[];contacts=[];slopes=[]
for row in report['closed_stocks']:
 obj=bpy.data.objects[row['name']];bm=bmesh.new();bm.from_mesh(obj.data);assert all(e.is_manifold for e in bm.edges);volume=bm.calc_volume(signed=True);assert volume>0 and abs(volume-row['volume_m3'])<1e-8;bm.free();closed.append(row);obj.data.calc_loop_triangles()
 for triangle in obj.data.loop_triangles:
  face=obj.data.polygons[triangle.polygon_index]
  if face.normal.z<.999:continue
  slopes.append(math.hypot(face.normal.x/face.normal.z,face.normal.y/face.normal.z))
  points=[[float(obj.data.vertices[v].co[i])+float(obj.location[i]) for i in range(3)] for v in triangle.vertices];center=[sum(p[i] for p in points)/3 for i in range(3)]
  for at in [center]+[[center[i]*.6+p[i]*.4 for i in range(3)] for p in points]:
   height,offset=backing(row['owner'],at);error=abs(height-at[2]);assert error<.000005,(row['name'],at,height,error);contacts.append({'stock':row['name'],'error_m':error,'seam_probe_m':offset})
assert min(slopes)>.0098 and max(slopes)<.0144,(min(slopes),max(slopes))
colours=[]
for part in report['parts']:
 obj=bpy.data.objects[part['name']];points=[obj.matrix_world@v.co for v in obj.data.vertices];span=[max(p[i] for p in points)-min(p[i] for p in points) for i in range(3)];assert max(span)<4.000005
 tint=obj.data.color_attributes['SeamTint'];unique=sorted(set(round(float(v.color[0]),5) for v in tint.data));assert all(any(abs(v-q)<.00001 for q in [1.,report['recipe']['bond_tint']]) for v in unique);colours.append({'part':obj.name,'span_m':span,'native_linear_tints':unique})
scene=bpy.context.scene;scene.render.engine='BLENDER_EEVEE';scene.render.resolution_x=1440;scene.render.resolution_y=1080;scene.render.resolution_percentage=100
scene.world=bpy.data.worlds.new('DiagnosticWorld');scene.world.use_nodes=True;scene.world.node_tree.nodes['Background'].inputs['Color'].default_value=(.25,.25,.25,1);scene.world.node_tree.nodes['Background'].inputs['Strength'].default_value=.7
sun_data=bpy.data.lights.new('DiagnosticSun','SUN');sun_data.energy=2.;sun=bpy.data.objects.new('DiagnosticSun',sun_data);scene.collection.objects.link(sun);bpy.context.view_layer.update();sun.rotation_euler=(.4,-.3,.4)
camera_data=bpy.data.cameras.new('DiagnosticCamera');camera=bpy.data.objects.new('DiagnosticCamera',camera_data);scene.collection.objects.link(camera);bpy.context.view_layer.update();scene.camera=camera;camera_data.lens=35;camera_data.clip_start=.01
renders=[]
for name,eye,at in [('west_field',(-12.,1.,21.),(-10.,0.,19.35)),('bond_close',(-10.2,-.1,19.9),(-10.,-1.,19.35)),('north_divide',(4.2,-6.5,20.7),(6.,-8.5,19.4))]:
 camera.location=eye;camera.rotation_euler=(Vector(at)-camera.location).to_track_quat('-Z','Y').to_euler();scene.render.filepath=str(out/(name+'.png'));bpy.ops.render.render(write_still=True);renders.append(name+'.png')
(out/'inspection.json').write_text(json.dumps({'evidence_class':'INERT','native_sha256':report['native_sha256'],'closed_stocks':closed,'actual_retained_field_contacts':contacts,'native_gradient_range':[min(slopes),max(slopes)],'bounded_parts_and_tints':colours,'renders':renders,'open_work':'Game colour import, full composed roof walking and remaining weather/drainage interfaces.'},indent=2)+'\n',newline='\n')
print('REOPENED ROLLED ROOF',len(closed),'closed stocks;',len(contacts),'retained field comparisons; slope',min(slopes),max(slopes),'maximum error',max(r['error_m'] for r in contacts))
