"""Reopen receiver stocks and measure actual bores, seats and native grades."""
from pathlib import Path
import json,hashlib,math
import bpy,bmesh
from mathutils import Vector
from mathutils.bvhtree import BVHTree
R=next(path for path in Path(__file__).resolve().parents if (path/'game/project.godot').is_file());O=R/'art/blender';out=R/'tmp/roof-drainage-review/receivers';out.mkdir(parents=True,exist_ok=True)
report=json.loads((O/'roof_drainage_receivers_construction.json').read_bytes());native=O/'roof_drainage_receivers.blend';assert hashlib.sha256(native.read_bytes()).hexdigest()==report['native_sha256'];bpy.ops.wm.open_mainfile(filepath=str(native))
def b(p):return Vector((p[0],-p[2],p[1]))
def g(p):return Vector((p.x,p.z,-p.y))
trees={};closed=[]
for row in report['closed_stocks']:
 obj=bpy.data.objects[row['name']];bm=bmesh.new();bm.from_mesh(obj.data);volume=bm.calc_volume(signed=True);assert all(e.is_manifold for e in bm.edges) and volume>0 and abs(volume-row['volume_m3'])<1e-8;bm.free();closed.append(row)
 trees[obj.name]=(BVHTree.FromPolygons([obj.location+v.co for v in obj.data.vertices],[tuple(p.vertices) for p in obj.data.polygons],all_triangles=False),obj)
def hit(name,point,direction,reach):
 p,n,i,d=trees[name][0].ray_cast(b(point),b(direction),reach);return None if p is None else (g(p),d)
pipe='RoofCollectorClosedWall';air=[];walls=[];seats=[];grade_contacts=[]
paths=[{'id':q['id'],'path':q['path'],'ri':q['bore_radius']} for q in report['trunks']]+[{'id':q['id'],'path':q['axis'],'ri':q['bore_radius']} for q in report['receivers']]+[{'id':q['id'],'path':q['riser_axis'],'ri':.1524} for q in report['cleanouts']]
for row in paths:
 for segment,(start,finish) in enumerate(zip(row['path'],row['path'][1:])):
  a=Vector(start);c=Vector(finish);axis=(c-a).normalized();seed=Vector((0,1,0)) if abs(axis.y)<.85 else Vector((1,0,0));u=(seed-axis*seed.dot(axis)).normalized();v=axis.cross(u).normalized();length=(c-a).length
  # End junction centres are deliberately inside shared air. Finite axial
  # rays at 90% of the specified bore must remain continuous to successors.
  for radius in [0.,row['ri']*.90]:
   for angle in ([0.] if radius==0 else [i*math.pi/4 for i in range(8)]):
    delta=radius*(u*math.cos(angle)+v*math.sin(angle));from_=a+axis*.012+delta;reach=length-.024
    assert hit(pipe,from_,axis,reach) is None,(row['id'],segment,'blocked native axial bore',radius,angle,hit(pipe,from_,axis,reach))
    air.append({'id':row['id'],'segment':segment,'radius_m':radius,'angle':angle,'clear_length_m':reach})
  if row['id'] in [q['id'] for q in report['trunks']]:
   for t in [.22,.52,.79]:
    center=a.lerp(c,t)
    if any((center-Vector(q['axis'][-1])).length<.4 for q in report['receivers']):continue
    if any((center-Vector(q['riser_axis'][0])).length<.4 for q in report['cleanouts']):continue
    for angle in [math.pi/8,3*math.pi/8,5*math.pi/8,7*math.pi/8]:
     direction=u*math.cos(angle)+v*math.sin(angle);inner=hit(pipe,center,direction,.19);outer=hit(pipe,center+direction*.22,-direction,.10)
     if inner is None or outer is None:continue
     thickness=(outer[0]-inner[0]).length;assert .0157<thickness<.0161,(row['id'],segment,t,angle,thickness);walls.append({'id':row['id'],'segment':segment,'native_wall_thickness_m':thickness})
for row in report['main_saddle_beds']:
 center=Vector(row['center']);axis=Vector(row['axis']);u=(Vector((0,1,0))-axis*axis.y).normalized();v=axis.cross(u).normalized()
 for shift in [-.045,0,.045]:
  for angle in [2*math.pi/3,5*math.pi/6,math.pi,7*math.pi/6,4*math.pi/3]:
   direction=u*math.cos(angle)+v*math.sin(angle);at=center+axis*shift
   # Intersecting exactly at a saved polygon corner can miss both incident
   # triangles and reach the bed bottom. Use real closest native faces at
   # the same axial/angular station, including the authored 32-sided form.
   bell,n,index,facet_offset=trees[row['stock']][0].find_nearest(b(at+direction*.185));assert bell is not None and facet_offset<.00090
   bed,n,index,error=trees[row['id']][0].find_nearest(bell);assert bed is not None and error<.000005,(row['id'],shift,angle,error)
   seats.append({'id':row['id'],'native_socket_contact_error_m':error})
grades=json.loads((R/'art/data/orison_roof_drainage/receiver_grade_datums.json').read_bytes());grade_points=[b(p) for station in grades['stations'] for row in station['retained_grade_triangles'] for p in row['points']];grade_tree=BVHTree.FromPolygons(grade_points,[(i,i+1,i+2) for i in range(0,len(grade_points),3)],all_triangles=True)
for row in report['receivers']+report['cleanouts']:
 names=[row['bed_owner'],row.get('grade_collar',row.get('cover'))]
 for name in names:
  obj=bpy.data.objects[name];obj.data.calc_loop_triangles()
  for triangle in obj.data.loop_triangles:
   face=obj.data.polygons[triangle.polygon_index]
   if face.normal.z<.99:continue
   p=sum((obj.location+obj.data.vertices[i].co for i in triangle.vertices),Vector())/3
   actual,n,i,d=grade_tree.ray_cast(p+Vector((0,0,.10)),Vector((0,0,-1)),.20)
   assert actual is not None
   # Recess floors and flange seats have their explicit 8/18/40 mm offsets.
   if abs(actual.z-p.z)>.000005:continue
   grade_contacts.append({'owner':name,'native_grade_error_m':abs(actual.z-p.z)})
 assert any(q['owner']==row['bed_owner'] for q in grade_contacts),row['id']
property_z=report['downstream']['point'][2]
for name in [pipe,'RoofDrainPropertyBlank']:
 obj=bpy.data.objects[name];minimum=min(-(obj.location+v.co).y for v in obj.data.vertices);assert abs(minimum-property_z)<.000002,(name,minimum,property_z)
# Native inspection views expose buried construction without changing source.
scene=bpy.context.scene;scene.render.engine='BLENDER_EEVEE';scene.render.resolution_x=1440;scene.render.resolution_y=1080;scene.render.resolution_percentage=100
scene.world=bpy.data.worlds.new('DiagnosticWorld');scene.world.use_nodes=True;scene.world.node_tree.nodes['Background'].inputs['Color'].default_value=(.2,.2,.2,1);scene.world.node_tree.nodes['Background'].inputs['Strength'].default_value=.8
sun_data=bpy.data.lights.new('DiagnosticSun','SUN');sun_data.energy=2.;sun=bpy.data.objects.new('DiagnosticSun',sun_data);scene.collection.objects.link(sun);sun.rotation_euler=(.4,-.3,.4)
cam_data=bpy.data.cameras.new('DiagnosticCamera');cam=bpy.data.objects.new('DiagnosticCamera',cam_data);scene.collection.objects.link(cam);scene.camera=cam;cam_data.lens=38;cam_data.clip_start=.01
views=[('buried_network',[-23,6,-23],[0,-1,-2]),('west_receiver',[-17.1,.8,4.8],[-16.1,.1,4.5]),('east_receiver',[15.2,.7,-8.2],[16.1,.1,-7.5]),('south_receiver',[-7.8,.8,-13.8],[-7,.1,-12.8]),('north_receiver',[10.2,.6,9.8],[11,.1,10.65]),('west_cleanout',[-16.9,.9,5.8],[-16.28,0,5]),('east_cleanout',[16.6,.8,14.8],[17.3,0,14]),('main_saddle',[-17.1,-2.1,1.6],[-16.28,-2.7,1.0]),('property_blank',[17.9,-2.4,-17.2],[17.3,-2.8759,-16.605])]
renders=[]
for name,eye,target in views:
 cam.location=b(eye);cam.rotation_euler=(b(target)-cam.location).to_track_quat('-Z','Y').to_euler();scene.render.filepath=str(out/(name+'.png'));bpy.ops.render.render(write_still=True);renders.append(name+'.png')
(out/'inspection.json').write_text(json.dumps({'evidence_class':'INERT','native_sha256':report['native_sha256'],'closed_stocks':closed,'clear_native_airways':air,'actual_main_wall_thickness':walls,'actual_socket_bearings':seats,'actual_grade_contacts':grade_contacts,'renders':renders,'open_work':report['open_work']},indent=2)+'\n',newline='\n')
print('REOPENED ROOF RECEIVERS',len(closed),'closed stocks;',len(air),'clear axial native bores;',len(walls),'actual wall samples;',len(seats),'native socket bearings;',len(grade_contacts),'native grade contacts')
