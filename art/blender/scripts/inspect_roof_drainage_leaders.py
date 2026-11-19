"""Reopen actual native hoppers/leaders; validate bore and inspect their form."""
from pathlib import Path
import json,hashlib,math,os
import bpy,bmesh
from mathutils import Vector
from mathutils.bvhtree import BVHTree
R=next(path for path in Path(__file__).resolve().parents if (path/'game/project.godot').is_file());O=R/'art/blender';out=Path(os.environ.get('ORISON_LEADERS_INSPECTION_OUT',str(R/'tmp/roof-drainage-review/leaders')));out.mkdir(parents=True,exist_ok=True)
report=json.loads((O/'roof_drainage_leaders_construction.json').read_bytes());native=O/'roof_drainage_leaders.blend';assert hashlib.sha256(native.read_bytes()).hexdigest()==report['native_sha256'];bpy.ops.wm.open_mainfile(filepath=str(native))
trees={};origins={};closed=[]
for row in report['closed_stocks']:
 obj=bpy.data.objects[row['name']];bm=bmesh.new();bm.from_mesh(obj.data);assert all(e.is_manifold for e in bm.edges);volume=bm.calc_volume(signed=True);assert volume>0 and abs(volume-row['volume_m3'])<1e-8;bm.free();closed.append({'name':obj.name,'volume_m3':volume})
 trees[obj.name]=BVHTree.FromPolygons([v.co for v in obj.data.vertices],[tuple(p.vertices) for p in obj.data.polygons],all_triangles=False);origins[obj.name]=obj.location.copy()
def b(p):return Vector((p[0],-p[2],p[1]))
def ray(name,p,d,reach):
 hit,n,index,distance=trees[name].ray_cast(p-origins[name],d,reach);return None if hit is None else hit+origins[name]

def clip_polygon(points,axis,bound,sign):
 clipped=[]
 for a,z in zip(points,points[1:]+points[:1]):
  da=sign*(a[axis]-bound);dz=sign*(z[axis]-bound)
  if da>=0:clipped.append(a)
  if (da>=0)!=(dz>=0):
   ratio=da/(da-dz);clipped.append(tuple(a[i]+ratio*(z[i]-a[i]) for i in range(2)))
 return clipped

def overlaps_window(triangle,bounds):
 left,bottom,right,top=bounds
 for axis,bound,sign in [(0,left,1),(0,right,-1),(1,bottom,1),(1,top,-1)]:
  triangle=clip_polygon(triangle,axis,bound,sign)
  if not triangle:return False
 return True

air=[];bands=[];bearings=[]
for leader in report['leaders']:
 c=b(leader['hopper_center']);up=Vector((0,0,1));path=[b(p) for p in leader['pipe_axis']]
 support=next(s for s in report['supports'] if s['port']==leader['id']);hopper_t=b(support['tangent']);n=b(support['normal']);t=b(leader.get('pipe_cross_section',support['tangent']))
 directions=[(z-a).normalized() for a,z in zip(path,path[1:])]
 mitres=[(directions[max(i-1,0)]+directions[min(i,len(directions)-1)]).normalized() for i in range(len(path))]
 # Axial rays follow each real offset segment. Four radial probes retain a
 # 140 mm test cylinder through the 152.4 mm faceted nominal bore. Clip each
 # ray at the two actual mitre planes, especially for the shallow offsets.
 for i,(a,z) in enumerate(zip(path,path[1:])):
  d=directions[i];v=d.cross(t).normalized()
  for du,dv in [(0,0),(.07,0),(-.07,0),(0,.07),(0,-.07)]:
   radial=t*du+v*dv
   start=a+radial-d*(mitres[i].dot(radial)/mitres[i].dot(d)-.0001)
   finish=z+radial-d*(mitres[i+1].dot(radial)/mitres[i+1].dot(d)+.0001)
   for row in report['closed_stocks']:
    hit=ray(row['name'],start,d,(finish-start).length);assert hit is None,('Blocked leader',leader['id'],row['name'],start,finish,hit)
   air.append({'id':leader['id'],'from':list(start),'to':list(finish),'radial_offset':[du,dv]})
 # Atmospheric center route enters from above and passes the open hopper,
 # overlapping socket and initial straight leader neck.
 for du,dv in [(0,0),(.06,0),(-.06,0),(0,.06),(0,-.06)]:
  start=c+hopper_t*du+n*dv+up*19.30
  for name in [leader['hopper_stock'],leader['pipe_stock']]:assert ray(name,start,-up,.70) is None,(leader['id'],name,'hopper inlet')
  air.append({'id':leader['id'],'hopper_probe':[du,dv]})
for support in report['supports']:
 c=b(support['clamp_center']);n=b(support['normal']);t=b(support['tangent']);up=Vector((0,0,1));wall=b(support['wall_point'])
 for u in [-.04,0,.04]:
  for v in [-support['plate_probe_y'],0,support['plate_probe_y']]:
   start=wall+t*u+up*v+n*.01;hit=ray(support['plate_stock'],start,-n,.02);assert hit is not None and abs((hit-wall).dot(n)-.004)<.000005,(support['id'],hit,wall)
   bearings.append({'id':support['id'],'offset':[u,v],'plate_front_error_m':abs((hit-wall).dot(n)-.004)})
 for angle in [.3,1.,2.,2.8,3.5,4.,5.,5.8]:
  radial=n*math.cos(angle)+t*math.sin(angle);name=support['id']+'_Band_'+str(0 if angle<math.pi else 1)
  inside=ray(support['pipe_stock'],c,radial,.12);assert inside is not None
  outside=ray(support['pipe_stock'],inside+radial*.0005,radial,.003);assert outside is not None
  hit=ray(name,outside+radial*.0002,radial,.01);assert hit is not None
  gap=(hit-outside).length;assert .000995<=gap<=.00180,(support['id'],angle,gap)
  bands.append({'id':support['id'],'angle':angle,'measured_gap_m':gap})
parts=[]
for part in report['parts']:
 obj=bpy.data.objects[part['name']];points=[obj.matrix_world@v.co for v in obj.data.vertices];span=[max(p[i] for p in points)-min(p[i] for p in points) for i in range(3)]
 assert max(span)<4.000005,(obj.name,span);assert obj.data.uv_layers.active is not None
 parts.append({'name':obj.name,'span_m':span,'vertices':len(obj.data.vertices),'faces':len(obj.data.polygons)})

# The native south stocks must not silhouette across any retained front
# aperture. Project actual triangles onto the front plane with 10 mm margin.
layout_path=R/'game/data/orison_v2_blockout.json';layout=json.loads(layout_path.read_bytes());levels={r['id']:r['y'] for r in layout['levels']};margin=.01
windows={w['id']:(w['center'][0]-w['width']/2-margin,levels[w['level']]+w['sill']-margin,
                   w['center'][0]+w['width']/2+margin,levels[w['level']]+w['sill']+w['height']+margin)
         for w in layout['windows'] if w['axis']=='x' and abs(w['center'][1]+12.35)<1e-6}
south=[row for row in report['leaders'] if row['side']=='south'];window_probes=[]
for leader in south:
 prefix='Leader_'+leader['id']+'__'
 for row in report['closed_stocks']:
  if not row['name'].startswith(prefix):continue
  obj=bpy.data.objects[row['name']];obj.data.calc_loop_triangles()
  points=[obj.matrix_world@v.co for v in obj.data.vertices];points=[(v.x,v.z) for v in points]
  left,bottom,right,top=min(p[0] for p in points),min(p[1] for p in points),max(p[0] for p in points),max(p[1] for p in points)
  near={key:bounds for key,bounds in windows.items() if left<=bounds[2] and right>=bounds[0] and bottom<=bounds[3] and top>=bounds[1]}
  for key,bounds in near.items():
   assert not any(overlaps_window([points[i] for i in face.vertices],bounds) for face in obj.data.loop_triangles),(leader['id'],obj.name,key)
  window_probes.append({'stock':obj.name,'apertures_checked':len(windows),'margin_m':margin})

renders=[]
if os.environ.get('ORISON_LEADERS_RENDER','1')=='1':
 scene=bpy.context.scene;scene.render.engine='BLENDER_EEVEE';scene.render.resolution_x=1440;scene.render.resolution_y=1080;scene.render.resolution_percentage=100
 scene.world=bpy.data.worlds.new('DiagnosticWorld');scene.world.use_nodes=True;scene.world.node_tree.nodes['Background'].inputs['Color'].default_value=(.25,.25,.25,1);scene.world.node_tree.nodes['Background'].inputs['Strength'].default_value=.7
 sun_data=bpy.data.lights.new('DiagnosticSun','SUN');sun_data.energy=2.;sun=bpy.data.objects.new('DiagnosticSun',sun_data);scene.collection.objects.link(sun);bpy.context.view_layer.update();sun.rotation_euler=(.4,-.3,.4)
 camera_data=bpy.data.cameras.new('DiagnosticCamera');camera=bpy.data.objects.new('DiagnosticCamera',camera_data);scene.collection.objects.link(camera);bpy.context.view_layer.update();scene.camera=camera;camera_data.lens=42;camera_data.clip_start=.01
 # Retained ports provide geometry context; this inspector never saves it.
 with bpy.data.libraries.load(str(R/'art/blender/roof_drainage_ports.blend'),link=False) as (source,target):target.objects=[name for name in source.objects if '__Channel' in name or '__Bed' in name]
 for obj in target.objects:
  if obj is not None:scene.collection.objects.link(obj);bpy.context.view_layer.update()
 for name,eye,at in [('east_hopper',(17.1,19.6,-6.9),(16.1,19.05,-7.5)),('north_offset',(12.2,19.1,13.6),(11.,18.35,11.4)),('north_bracket',(11.65,19.45,12.65),(11.,18.85,11.3)),('west_clamp',(-16.8,10.,1.0),(-16.02,9.45,.5)),('south_west_offsets',(-7.9,10.0,-33),(-7.9,10.0,-12.8)),('south_east_offsets',(10.2,10.0,-33),(10.2,10.0,-12.8))]:
  camera.location=b(eye);camera.rotation_euler=(b(at)-camera.location).to_track_quat('-Z','Y').to_euler();scene.render.filepath=str(out/(name+'.png'));bpy.ops.render.render(write_still=True);renders.append(name+'.png')
(out/'inspection.json').write_text(json.dumps({'evidence_class':'INERT','native_sha256':report['native_sha256'],'closed_stocks':closed,'airway_probes':air,'plate_surface_probes':bearings,'strap_clearance':bands,'bounded_parts':parts,'window_projection_probes':window_probes,'window_layout_sha256':hashlib.sha256(layout_path.read_bytes().replace(b'\r\n',b'\n')).hexdigest(),'renders':renders,'open_work':'Actual facade/whole-pipe collision, catalogue textures, ground receivers/branches and production acceptance remain open.'},indent=2)+'\n',newline='\n')
print('REOPENED LEADERS',len(closed),'closed stocks;',len(air),'airway probes;',len(bearings),'plate probes;',len(bands),'strap gaps;',len(parts),'bounded parts;',len(window_probes),'front-window stock projections')
