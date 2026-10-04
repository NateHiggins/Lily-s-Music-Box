"""Reopen positive threshold/pan/seal stocks and inspect actual corner joints."""
from pathlib import Path
import sys,json,hashlib,math
import bpy,bmesh
from mathutils import Vector
from mathutils.bvhtree import BVHTree
sys.path.insert(0,str(Path(__file__).resolve().parent));import roof_drainage_field as roof
R=roof.R;O=R/'art/blender';out=R/'tmp/roof-drainage-review/door_weather';out.mkdir(parents=True,exist_ok=True)
report=json.loads((O/'roof_drainage_door_weather_construction.json').read_bytes());native=O/'roof_drainage_door_weather.blend';assert hashlib.sha256(native.read_bytes()).hexdigest()==report['native_sha256'];bpy.ops.wm.open_mainfile(filepath=str(native))
def b(p):return Vector((p[0],-p[2],p[1]))
closed=[];trees={};contacts=[];miters=[]
for row in report['closed_stocks']:
 obj=bpy.data.objects[row['name']];bm=bmesh.new();bm.from_mesh(obj.data);assert all(e.is_manifold for e in bm.edges);volume=bm.calc_volume(signed=True);assert volume>0 and abs(volume-row['volume_m3'])<1e-9;bm.free();closed.append(row)
 trees[obj.name]=(BVHTree.FromPolygons([v.co for v in obj.data.vertices],[tuple(p.vertices) for p in obj.data.polygons],all_triangles=False),obj.location.copy())
def hit(name,point,direction,reach):
 tree,pivot=trees[name];at,n,index,d=tree.ray_cast(b(point)-pivot,b(direction),reach);return None if at is None else at+pivot
for row in report['field_feet']:
 x,y,z=row['point'];actual=hit(row['id']+'__Pan_'+row['side'],[x,y+.01,z],[0,-1,0],.02);assert actual is not None and abs(actual.z-y)<.000005,(row,actual);contacts.append({'id':row['id'],'side':row['side'],'error_m':abs(actual.z-y)})
for spec in report['door_pans']:
 ident=spec['id'];a,bz,c,d=spec['curb_rect'];top=spec['curb_top_y'];width=spec['source_record']['width']
 for corner,side,sign in [(bz,'South',-1),(d,'North',1)]:
  west=bpy.data.objects[ident+'__Pan_West'];end=bpy.data.objects[ident+'__Pan_'+side]
  def vertices(obj):return [obj.matrix_world@v.co for v in obj.data.vertices]
  w=vertices(west);e=vertices(end);boundary=[]
  for p in w:
   x,z,y=p.x,-p.y,p.z;u=a-x
   if abs(z-(corner+sign*u))<.000002:
    error=min((q-p).length for q in e);assert error<.000005,(ident,side,p,error);boundary.append(error)
  assert len(boundary)>=7,(ident,side,len(boundary));miters.append({'id':ident,'side':side,'shared_vertices':len(boundary),'maximum_error_m':max(boundary)})
 for u in [.03,width/2,width-.03]:
  at=hit(ident+'__BottomBlade',[u,.002,sum(spec['bottom_seal_z'])/2],[0,1,0],.01);assert at is not None and abs(at.z-.004)<.000005
 # Moving native stocks are leaf-local; present them at their closed source
 # opening for this diagnostic. Runtime/swing proof is a separate check.
 x,z=spec['source_record']['center'];yaw=spec['source_record']['yaw'];base=Vector((x,-z,top));rotation=__import__('mathutils').Matrix.Rotation(-yaw,4,'Z')
 for part in report['parts']:
  if part['owner'] not in [spec['moving_owner'],spec['fixed_owner']]:continue
  obj=bpy.data.objects[part['name']];obj.matrix_world=__import__('mathutils').Matrix.Translation(base)@rotation@__import__('mathutils').Matrix.Translation(Vector((-width/2,-spec['fitted_leaf_normal_offset_m'],0)))@obj.matrix_world
with bpy.data.libraries.load(str(R/'art/blender/roof_drainage_falls.blend'),link=False) as (available,target):target.objects=[n for n in available.objects if '__Field_' in n or n.endswith('__CurbBacking')]
for obj in target.objects:bpy.context.scene.collection.objects.link(obj)
scene=bpy.context.scene;scene.render.engine='BLENDER_EEVEE';scene.render.resolution_x=1440;scene.render.resolution_y=1080;scene.render.resolution_percentage=100
scene.world=bpy.data.worlds.new('DiagnosticWorld');scene.world.use_nodes=True;scene.world.node_tree.nodes['Background'].inputs['Color'].default_value=(.25,.25,.25,1);scene.world.node_tree.nodes['Background'].inputs['Strength'].default_value=.7
sun_data=bpy.data.lights.new('DiagnosticSun','SUN');sun_data.energy=2.;sun=bpy.data.objects.new('DiagnosticSun',sun_data);scene.collection.objects.link(sun);sun.rotation_euler=(.4,-.3,.4)
camera_data=bpy.data.cameras.new('DiagnosticCamera');camera=bpy.data.objects.new('DiagnosticCamera',camera_data);scene.collection.objects.link(camera);scene.camera=camera;camera_data.lens=42;camera_data.clip_start=.01
renders=[]
for spec in report['door_pans']:
 ident=spec['id'];a,bz,c,d=spec['curb_rect'];top=spec['curb_top_y']
 for label,eye,at in [('pan',[a-.75,top+.7,bz-.65],[a,top-.015,bz+.03]),('closed_seal',[a-.6,top+.25,(bz+d)/2],[spec['source_record']['center'][0],top+.017,(bz+d)/2])]:
  name=ident+'_'+label;camera.location=b(eye);camera.rotation_euler=(b(at)-camera.location).to_track_quat('-Z','Y').to_euler();scene.render.filepath=str(out/(name+'.png'));bpy.ops.render.render(write_still=True);renders.append(name+'.png')
(out/'inspection.json').write_text(json.dumps({'evidence_class':'INERT','native_sha256':report['native_sha256'],'closed_stocks':closed,'actual_field_contacts':contacts,'exact_pan_corner_joints':miters,'renders':renders,'open_work':'Actual imported leaf/saddle transforms, swing/UV and full normal-controller roof route'},indent=2)+'\n',newline='\n')
print('REOPENED DOOR WEATHER',len(closed),'closed stocks;',len(contacts),'field feet;',len(miters),'matched native corner joints')
