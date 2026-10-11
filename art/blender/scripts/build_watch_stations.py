"""Native cast watch-station stock. Godot metres; original mechanisms remain owners."""
from pathlib import Path
import math,json
import bpy,bmesh
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[3]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.context.preferences.filepaths.save_version=0
materials={}
for key in ['iron_neutral','brass_dull','enamel_appliance','indicator_enamel','iron_blackened']:
 m=bpy.data.materials.new(key);m.use_nodes=True;materials[key]=m
def b(v):return (v[0],-v[2],v[1])
def cube(size,at=(0,0,0),radius=.001):
 bpy.ops.mesh.primitive_cube_add(size=1,location=b(at));o=bpy.context.object
 o.dimensions=(size[0],size[2],size[1]);bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
 if radius:
  mod=o.modifiers.new('Cast edge radius','BEVEL');mod.width=radius;mod.segments=3
  bpy.ops.object.modifier_apply(modifier=mod.name)
 return o
def cyl(radius,height,at=(0,0,0)):
 bpy.ops.mesh.primitive_cylinder_add(vertices=48,radius=radius,depth=height,location=b(at));o=bpy.context.object
 mod=o.modifiers.new('Machined rim','BEVEL');mod.width=min(.001,height*.15);mod.segments=3;bpy.ops.object.modifier_apply(modifier=mod.name)
 return o
def stock(name,objects,key):
 if name in ['StationCase','DoorLeaf','DoorSash','TourKeySocket','HingeBarrel']:
  base=objects[0];bpy.context.view_layer.objects.active=base
  for other in objects[1:]:
   mod=base.modifiers.new('Continuous cast union','BOOLEAN');mod.operation='UNION';mod.solver='EXACT';mod.object=other
   bpy.ops.object.modifier_apply(modifier=mod.name);bpy.data.objects.remove(other,do_unlink=True)
  objects=[base]
 bpy.ops.object.select_all(action='DESELECT')
 for o in objects:o.select_set(True)
 bpy.context.view_layer.objects.active=objects[0];bpy.ops.object.join();o=bpy.context.object
 bpy.context.scene.cursor.location=(0,0,0);bpy.ops.object.origin_set(type='ORIGIN_CURSOR')
 o.name=name;o.data.materials.clear();o.data.materials.append(materials[key])
 bm=bmesh.new();bm.from_mesh(o.data)
 if name=='StationConduit':bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=1e-7)
 bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(o.data);bm.free()
 mod=o.modifiers.new('Stable triangle charts','TRIANGULATE');bpy.ops.object.modifier_apply(modifier=mod.name)
 o.data.update()
 for previous in list(o.data.uv_layers):o.data.uv_layers.remove(previous)
 uv=o.data.uv_layers.new(name='MetreStock')
 for face in o.data.polygons:
  vertices=[o.data.vertices[i].co for i in face.vertices]
  normal=(vertices[1]-vertices[0]).cross(vertices[2]-vertices[0])
  axis=max(range(3),key=lambda i:abs(normal[i]));a,c=[(1,2),(0,2),(0,1)][axis]
  for loop in face.loop_indices:
   p=o.data.vertices[o.data.loops[loop].vertex_index].co;uv.data[loop].uv=(p[a],p[c])
 return o
def box(name,size,key,radius=.001,at=(0,0,0)):return stock(name,[cube(size,at,radius)],key)
# Composite case: butted cheeks, head and sill; original back mounting plane.
stock('StationCase',[cube((.240,.320,.026),radius=.003),
 cube((.020,.320,.096),(-.115,0,.035),.002),
 *[cube((.020,h,.024),(-.115,y,.095),.001) for y,h in [(-.138,.044),(-.05,.068),(.05,.068),(.138,.044)]],
 cube((.020,.320,.120),(.115,0,.047),.002),
 cube((.210,.020,.120),(0,.150,.047),.002),cube((.210,.020,.120),(0,-.150,.047),.002)],'iron_neutral')
box('CaseLining',(.216,.296,.003),'enamel_appliance',.0003)
box('CaseBead',(.200,.010,.008),'iron_neutral',.0015,(0,0,-.008))
# Door is an actual through aperture, not glass layered onto an opaque slab.
stock('DoorLeaf',[cube((.210,.131,.014),(0,-.0845,0),.001),cube((.210,.079,.014),(0,.1105,0),.001),
 cube((.040,.090,.014),(-.085,.026,0),.001),cube((.040,.090,.014),(.085,.026,0),.001)],'iron_neutral')
# One closed annular casting avoids boolean seams at the glazing corners.
vertices=[]
for z in [-.003,.003]:
 for x,y in [(-.075,-.055),(.075,-.055),(.075,.055),(-.075,.055),(-.065,-.045),(.065,-.045),(.065,.045),(-.065,.045)]:vertices.append(b((x,y,z)))
faces=[]
for i in range(4):
 j=(i+1)%4
 faces.extend([(i,j,j+4,i+4),(i+8,i+12,j+12,j+8),(i,i+8,j+8,j),(i+4,j+4,j+12,i+12)])
mesh=bpy.data.meshes.new('SashCasting');mesh.from_pydata(vertices,[],faces);mesh.update();o=bpy.data.objects.new('SashCasting',mesh);bpy.context.collection.objects.link(o)
stock('DoorSash',[o],'iron_neutral')
box('StationPlate',(.156,.044,.004),'enamel_appliance',.001)
box('LatchSpring',(.014,.030,.010),'brass_dull',.001)
stock('DoorHandle',[cyl(.008,.040)],'brass_dull')
# Recessed keyway with a dark back; no fictional tour key is added.
stock('TourKeySocket',[cube((.034,.007,.010),(0,-.0135,0),.0005),cube((.034,.007,.010),(0,.0135,0),.0005),
 cube((.014,.020,.010),(-.010,0,0),.0005),cube((.014,.020,.010),(.010,0,0),.0005)],'iron_neutral')
box('SocketKeyway',(.006,.020,.0005),'iron_blackened',.0001,(0,0,-.011))
stock('CrankBoss',[cyl(.016,.014)],'iron_neutral')
box('CrankArm',(.014,.066,.010),'iron_neutral',.002)
stock('CrankGrip',[cyl(.008,.020)],'brass_dull')
stock('WheelDisc',[cyl(.030,.008)],'iron_neutral')
box('WheelTooth',(.007,.014,.009),'brass_dull',.0007)
box('PawlArm',(.038,.008,.008),'brass_dull',.001)
box('DropFlag',(.064,.076,.005),'indicator_enamel',.001)
box('DropFace',(.050,.060,.003),'indicator_enamel',.0005)
# Real bent conduit. Coordinates are local to the retained StationConduit node.
points=[(0,-.0375,0),(0,.014,0)]
for i in range(1,17):
 t=math.pi*.5*i/16;points.append((0,.014+.020*math.sin(t),-.020+.020*math.cos(t)))
points.append((0,.034,-.030))
curve=bpy.data.curves.new('ConduitSweep','CURVE');curve.dimensions='3D';curve.bevel_depth=.009;curve.bevel_resolution=3;curve.use_fill_caps=True
spline=curve.splines.new('POLY');spline.points.add(len(points)-1)
for point,p in zip(spline.points,points):point.co=(*b(p),1)
o=bpy.data.objects.new('StationConduit',curve);bpy.context.collection.objects.link(o);bpy.context.view_layer.objects.active=o;o.select_set(True)
bpy.ops.object.convert(target='MESH');stock('StationConduit',[o],'iron_neutral')
# Coaxial hinge stock fits the existing door pivot, without enlarging the case.
stock('HingeBarrel',[cyl(.004,.024),cube((.008,.020,.012),(.006,0,.007),.0005)],'brass_dull')
box('DoorGlass',(.130,.090,.004),'iron_neutral',.0002)
for o in bpy.context.scene.objects:
 if o.type=='MESH' and o.name in ['DoorLeaf','DoorSash','StationPlate','LatchSpring','DoorHandle','DoorGlass']:
  for v in o.data.vertices:v.co.y-=(.016 if o.name=="DoorSash" else .013 if o.name=="DoorGlass" else .014)
metrics={}
for o in bpy.context.scene.objects:
 if o.type!='MESH':continue
 o.data.calc_loop_triangles();uv=o.data.uv_layers.active;bad=0
 for t in o.data.loop_triangles:
  a,c,d=[uv.data[i].uv for i in t.loops]
  if t.area>1e-12 and abs((c.x-a.x)*(d.y-a.y)-(d.x-a.x)*(c.y-a.y))<1e-12:bad+=1
 bm=bmesh.new();bm.from_mesh(o.data);edges=sum(not e.is_manifold for e in bm.edges);volume=bm.calc_volume(signed=True);bm.free()
 metrics[o.name]={'triangles':len(o.data.loop_triangles),'degenerate_uv':bad,'nonmanifold_edges':edges,'volume_m3':volume}
 assert edges==0 and volume>0,(o.name,edges,volume)
 assert not bad,(o.name,bad)
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'art/blender/watch_stations.blend'))
bpy.ops.export_scene.gltf(filepath=str(ROOT/'game/assets/props/watch_stations.glb'),export_format='GLB',export_yup=True,export_materials='EXPORT')
(ROOT/'tmp/v2-next-batch-20261011/native-uv.json').write_text(json.dumps(metrics,indent=2)+'\n',encoding='utf8')
