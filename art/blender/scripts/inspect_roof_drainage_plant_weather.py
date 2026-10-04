"""Reopen fitted plant boots, retained bearings and actual native leg contacts."""
from pathlib import Path
import sys,json,hashlib,math
import bpy,bmesh
from mathutils import Vector
from mathutils.bvhtree import BVHTree
sys.path.insert(0,str(Path(__file__).resolve().parent))
import roof_drainage_field as roof
R=roof.R;O=R/'art/blender';out=R/'tmp/roof-drainage-review/plant_weather';out.mkdir(parents=True,exist_ok=True)
report=json.loads((O/'roof_drainage_plant_weather_construction.json').read_bytes());native=O/'roof_drainage_plant_weather.blend';assert hashlib.sha256(native.read_bytes()).hexdigest()==report['native_sha256'];bpy.ops.wm.open_mainfile(filepath=str(native))
def b(p):return Vector((p[0],-p[2],p[1]))
def g(p):return Vector((p.x,p.z,-p.y))
trees={};closed=[]
for row in report['closed_stocks']:
 obj=bpy.data.objects[row['name']];bm=bmesh.new();bm.from_mesh(obj.data);assert all(e.is_manifold for e in bm.edges);volume=bm.calc_volume(signed=True);assert volume>0 and abs(volume-row['volume_m3'])<1e-9;bmesh.ops.triangulate(bm,faces=list(bm.faces));bm.free();closed.append(row)
 trees[obj.name]=(BVHTree.FromPolygons([v.co for v in obj.data.vertices],[tuple(p.vertices) for p in obj.data.polygons],all_triangles=False),obj.location.copy())
def hits(point,direction,distance,names):
 results=[]
 for name in names:
  tree,origin=trees[name];hit,normal,index,d=tree.ray_cast(b(point)-origin,b(direction),distance)
  if hit is not None:results.append((d,name,g(hit+origin)))
 return sorted(results,key=lambda q:q[0])
contacts=[]
for row in report['field_feet']:
 x,y,z=row['point'];result=hits([x,y+.01,z],[0,-1,0],.02,[row['owner']+'__WeatherBoot']);assert result and abs(result[0][2].y-y)<.000005,(row,result)
 contacts.append({'owner':row['owner'],'error_m':abs(result[0][2].y-y)})
bores=[];seats=[]
for fan in report['fan_curbs']:
 x,base,z=fan['center'];shift=fan['machine_offset_y'];names=[r['name'] for r in closed if r['owner']==fan['id']]
 for dx in [-.085,0,.085]:
  for dz in [-.085,0,.085]:
   assert not hits([x+dx,19.369+shift+.003,z+dz],[0,-1,0],shift+.006,names),(fan['id'],dx,dz)
   bores.append({'fan':fan['id'],'offset':[dx,dz]})
 for dx,dz in [(-.2,0),(.2,0),(0,-.2),(0,.2)]:
  result=hits([x+dx,19.2+shift+.01,z+dz],[0,-1,0],shift+.02,[fan['pedestal_stock']]);assert result and abs(result[0][2].y-(19.2+shift))<.000005
  seats.append({'fan':fan['id'],'upper_seat_error_m':abs(result[0][2].y-(19.2+shift))})
 assert fan['minimum_exposed_upstand_m']>=.179999 and fan['weather_terminal_y']+.002<19.2+shift+.157
# Reopen actual leg source meshes into read-only render context. Their geometry
# and original bearing remain unchanged, including native bevels at corners.
leg_names=[q['source_stock'] for q in report['tank_boots']]
with bpy.data.libraries.load(str(R/'art/blender/house_tank.blend'),link=False) as (available,target):target.objects=leg_names+[n for n in available.objects if n.startswith('ColumnRivet')]
body=next(q for q in json.loads((R/'game/data/orison_v2_blockout.json').read_bytes())['fixtures'] if q['id']=='ROOF_TANK_BODY');origin=b([body['position'][0],19.2,body['position'][2]])
leg_contacts=[];seal_contacts=[];rivet_clearances=[]
source_objects={obj.name:obj for obj in target.objects}
for obj in target.objects:
 bpy.context.scene.collection.objects.link(obj);obj.location+=origin
bpy.context.view_layer.update()
for row in report['tank_boots']:
 obj=source_objects[row['source_stock']]
 tree=BVHTree.FromPolygons([v.co for v in obj.data.vertices],[tuple(p.vertices) for p in obj.data.polygons],all_triangles=False)
 contour=row['outline'];center=Vector((sum(p[0] for p in contour)/len(contour),sum(p[1] for p in contour)/len(contour)))
 for first,second in zip(contour,contour[1:]+contour[:1]):
  mid=Vector(((first[0]+second[0])/2,(first[1]+second[1])/2));delta=(center-mid).normalized();y=row['weather_terminal_y']-.03
  hit,n,index,d=tree.ray_cast(b([mid.x-delta.x*.01,y,mid.y-delta.y*.01])-obj.location,b([delta.x,0,delta.y]),.02)
  assert hit is not None,(row['id'],mid,y);actual=g(hit+obj.location);error=math.hypot(actual.x-mid.x,actual.z-mid.y);assert error<.000005
  leg_contacts.append({'leg':row['id'],'native_bevel_contact_error_m':error})
  # At the terminal the stand-off sleeve narrows to the actual beveled leg.
  # Inspect the hidden inner seal face independently of the leg's own hit.
  y=row['weather_terminal_y']-.002
  result=hits([mid.x+delta.x*.005,y,mid.y+delta.y*.005],[-delta.x,0,-delta.y],.01,[row['id']+'__TerminalSeal'])
  assert result,(row['id'],'missing actual terminal seal',mid,y)
  error=math.hypot(result[0][2].x-mid.x,result[0][2].z-mid.y);assert error<.000005,(row['id'],'seal contact',error)
  seal_contacts.append({'leg':row['id'],'actual_seal_contact_error_m':error})
 boot=bpy.data.objects[row['id']+'__WeatherBoot'];boot_tree=BVHTree.FromPolygons([boot.matrix_world@v.co for v in boot.data.vertices],[tuple(p.vertices) for p in boot.data.polygons],all_triangles=False)
 for rivet in target.objects:
  if not rivet.name.startswith('ColumnRivet'):continue
  if (rivet.location-obj.location).length>.8:continue
  vertices=[rivet.matrix_world@v.co for v in rivet.data.vertices];rivet_tree=BVHTree.FromPolygons(vertices,[tuple(p.vertices) for p in rivet.data.polygons],all_triangles=False)
  assert not boot_tree.overlap(rivet_tree),(row['id'],'native rivet intersects weather sleeve',rivet.name)
  distances=[boot_tree.find_nearest(p)[3] for p in vertices];clearance=min(distances)
  assert clearance>.00199,(row['id'],rivet.name,'native rivet clearance',clearance)
  rivet_clearances.append({'leg':row['id'],'original_rivet':rivet.name,'minimum_native_vertex_clearance_m':clearance})
assert len(rivet_clearances)==16,(len(rivet_clearances),'all retained original column rivets inspected')
# Add actual retained fans raised as complete machines, solely for inspection.
fan_context=bpy.data.collections.new('ReadOnlyRaisedFans');bpy.context.scene.collection.children.link(fan_context)
for row in report['fan_curbs']:
 with bpy.data.libraries.load(str(R/'art/blender/roof_ventilator.blend'),link=False) as (available,target):target.objects=[n for n in available.objects if not n.startswith(('Rotor','GravitySlat'))]
 for obj in target.objects:
  if obj is None:continue
  fan_context.objects.link(obj);p=b(row['center'])+Vector((0,0,row['machine_offset_y']));obj.location=p+obj.location;obj.rotation_euler.z=-row['yaw']
with bpy.data.libraries.load(str(R/'art/blender/roof_drainage_falls.blend'),link=False) as (available,target):target.objects=[n for n in available.objects if '__Field_' in n]
for obj in target.objects:bpy.context.scene.collection.objects.link(obj)
scene=bpy.context.scene;scene.render.engine='BLENDER_EEVEE';scene.render.resolution_x=1440;scene.render.resolution_y=1080;scene.render.resolution_percentage=100
scene.world=bpy.data.worlds.new('DiagnosticWorld');scene.world.use_nodes=True;scene.world.node_tree.nodes['Background'].inputs['Color'].default_value=(.25,.25,.25,1);scene.world.node_tree.nodes['Background'].inputs['Strength'].default_value=.7
sun_data=bpy.data.lights.new('DiagnosticSun','SUN');sun_data.energy=2.;sun=bpy.data.objects.new('DiagnosticSun',sun_data);scene.collection.objects.link(sun);sun.rotation_euler=(.4,-.3,.4)
cam_data=bpy.data.cameras.new('DiagnosticCamera');cam=bpy.data.objects.new('DiagnosticCamera',cam_data);scene.collection.objects.link(cam);scene.camera=cam;cam_data.lens=42;cam_data.clip_start=.01
views=[]
for row in report['fan_curbs']:
 x,y,z=row['center'];views.append((row['id'],[x+1,20.2,z-.9],[x,row['weather_terminal_y']-.05,z]))
for row in report['tank_boots']:
 x,z=row['outline'][0];views.append((row['id'],[x+.55,row['weather_terminal_y']+.4,z-.55],[x+.1,row['weather_terminal_y']-.08,z+.1]))
for name,eye,target in views:
 cam.location=b(eye);cam.rotation_euler=(b(target)-cam.location).to_track_quat('-Z','Y').to_euler();scene.render.filepath=str(out/(name+'.png'));bpy.ops.render.render(write_still=True)
(out/'inspection.json').write_text(json.dumps({'evidence_class':'INERT','native_sha256':report['native_sha256'],'closed_stocks':closed,'field_contacts':contacts,'clear_fan_bores':bores,'retained_upper_seats':seats,'actual_native_leg_contacts':leg_contacts,'actual_terminal_seal_contacts':seal_contacts,'original_rivet_clearances':rivet_clearances,'renders':[v[0]+'.png' for v in views],'open_work':'import, live fan/control/audio and full composed route; door/ground interfaces'},indent=2)+'\n',newline='\n')
print('REOPENED PLANT WEATHER',len(closed),'closed stocks;',len(contacts),'field feet;',len(bores),'clear fan bores;',len(seats),'upper seats;',len(leg_contacts),'native beveled leg contacts')
