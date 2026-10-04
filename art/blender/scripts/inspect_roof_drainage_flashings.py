"""Reopen fitted flashing stocks and inspect their actual roof backing and airways."""
from pathlib import Path
import json,hashlib,math
import bpy,bmesh
from mathutils import Vector
from mathutils.bvhtree import BVHTree
R=next(path for path in Path(__file__).resolve().parents if (path/'game/project.godot').is_file());O=R/'art/blender';out=R/'tmp/roof-drainage-review/flashings';out.mkdir(parents=True,exist_ok=True)
report=json.loads((O/'roof_base_flashings_construction.json').read_bytes());native=O/'roof_base_flashings.blend';assert hashlib.sha256(native.read_bytes()).hexdigest()==report['native_sha256']
bpy.ops.wm.open_mainfile(filepath=str(native));closed=[];foot_samples=[]
context=bpy.data.collections.new('ReadOnlyFieldAndPorts');bpy.context.scene.collection.children.link(context)
for path,selector in [(R/'art/blender/roof_drainage_falls.blend',lambda n:'__Membrane' in n or '__Field_' in n),(R/'art/blender/roof_drainage_ports.blend',lambda n:True)]:
 with bpy.data.libraries.load(str(path),link=False) as (available,chosen):chosen.objects=[n for n in available.objects if selector(n)]
 for obj in chosen.objects:
  if obj is not None:context.objects.link(obj)
membranes=[o for o in context.objects if o.type=='MESH' and o.name.endswith('__Membrane')]
# Query only upward backing faces with exact BVH intersections. Blender's BVH
# epsilon displaced hits near thin triangles. Record a 2 micron seam probe
# only when the exact ray misses; contact height still has a 30 micron limit.
field_trees={o.name.split('__')[0]:BVHTree.FromPolygons([v.co for v in o.data.vertices],[tuple(p.vertices) for p in o.data.polygons if p.normal.z>.999],all_triangles=False) for o in membranes}
field_origins={o.name.split('__')[0]:tuple(o.location) for o in membranes}
def world(obj,vector):return [float(vector[i])+float(obj.location[i]) for i in range(3)]
def backing(point):
 for dx,dy in [(0.,0.),(.000002,0.),(-.000002,0.),(0.,.000002),(0.,-.000002)]:
  for owner,tree in field_trees.items():
   pivot=field_origins[owner];at=Vector((point[0]+dx-pivot[0],point[1]+dy-pivot[1],point[2]+.03-pivot[2]));hit,n,f,d=tree.ray_cast(at,Vector((0,0,-1)),.06)
   if hit is not None:return hit.z+pivot[2],owner,[dx,dy]
 return None,None,None
for row in report['closed_stocks']:
 obj=bpy.data.objects[row['name']];bm=bmesh.new();bm.from_mesh(obj.data);assert all(e.is_manifold for e in bm.edges) and bm.calc_volume(signed=True)>0;assert abs(bm.calc_volume(signed=True)-row['volume_m3'])<1e-8;bm.free();closed.append(row)
 if not obj.name.startswith('FoldedStrip_'):continue
 source=obj.data.attributes['SourceFace'];obj.data.calc_loop_triangles()
 for triangle in obj.data.loop_triangles:
  if source.data[triangle.polygon_index].value!=2:continue
  points=[world(obj,obj.data.vertices[i].co) for i in triangle.vertices];center=[sum(p[i] for p in points)/3 for i in range(3)]
  for at in [center]+[[center[i]*.6+p[i]*.4 for i in range(3)] for p in points]:
   height,owner,seam_probe=backing(at);assert height is not None and abs(height-at[2])<.00003,(obj.name,at,height)
   foot_samples.append({'stock':obj.name,'floor_owner':owner,'point':[at[0],at[2],-at[1]],'error_m':abs(height-at[2]),'query_offset_m':seam_probe})
visible=[o for o in bpy.context.scene.objects if o.type=='MESH' and not o.hide_render]
trees={o.name:BVHTree.FromPolygons([v.co for v in o.data.vertices],[tuple(p.vertices) for p in o.data.polygons],all_triangles=False) for o in visible};origins={o.name:tuple(o.location) for o in visible}
ports=json.loads((R/'art/blender/roof_drainage_ports_construction.json').read_bytes())['ports'];air=[]
def b(p):return Vector((p[0],-p[2],p[1]))
for port in ports:
 n=b(port['normal']);t=b(port['tangent']);p=b(port['inner_point']);up=Vector((0,0,1))
 for lateral in [-.10,0.,.10]:
  for height in [.02,.06,.10]:
   at=p+t*lateral+up*height-n*.015
   for name,tree in trees.items():
    hit,normal,face,d=tree.ray_cast(at-Vector(origins[name]),n,port['channel_length']+.03)
    assert hit is None,(port['id'],lateral,height,name,hit)
   air.append({'id':port['id'],'offset':[lateral,height],'length':port['channel_length']+.03})
scene=bpy.context.scene;scene.render.engine='BLENDER_EEVEE';scene.render.resolution_x=1280;scene.render.resolution_y=960;scene.render.resolution_percentage=100
scene.world=bpy.data.worlds.new('DiagnosticWorld');scene.world.use_nodes=True;scene.world.node_tree.nodes['Background'].inputs['Color'].default_value=(.25,.25,.25,1);scene.world.node_tree.nodes['Background'].inputs['Strength'].default_value=.7
sun_data=bpy.data.lights.new('DiagnosticSun','SUN');sun_data.energy=2.;sun=bpy.data.objects.new('DiagnosticSun',sun_data);scene.collection.objects.link(sun);sun.rotation_euler=(.4,-.3,.4)
camera_data=bpy.data.cameras.new('DiagnosticCamera');camera=bpy.data.objects.new('DiagnosticCamera',camera_data);scene.collection.objects.link(camera);scene.camera=camera;camera_data.lens=35;camera_data.clip_start=.01
renders=[]
for name,at,target in [('west_outlet',(-14.8,-.05,19.95),(-15.525,-.5,19.28)),('north_outlet',(10.5,-10.8,19.95),(11,-11.525,19.28)),('public_corner',(-3.1,-4.7,19.95),(-2.27,-3.92,19.5))]:
 camera.location=at;camera.rotation_euler=(Vector(target)-camera.location).to_track_quat('-Z','Y').to_euler();scene.render.filepath=str(out/(name+'.png'));bpy.ops.render.render(write_still=True);renders.append(name+'.png')
(out/'inspection.json').write_text(json.dumps({'evidence_class':'INERT','native_sha256':report['native_sha256'],'closed_stocks':closed,'fitted_foot_samples':foot_samples,'clear_combined_airways':air,'renders':renders,'note':'Scratch closed native and actual roof backing. Ports, field and flashing compose in read-only diagnostic context. Production ownership, door/fan/tank/old leader weather joints, receivers/downstream routes and final textures remain open.'},indent=2)+'\n',newline='\n')
print('REOPENED SCRATCH FLASHINGS',len(closed),'closed stocks;',len(foot_samples),'actual roof contacts;',len(air),'clear combined airways')
