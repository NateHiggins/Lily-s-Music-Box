"""Blender steam takeoff, equalizer and supported feed to the V2 heat shaft."""
from pathlib import Path
import json, math
import bpy, bmesh
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[3]
source=json.loads((ROOT/'game/data/orison_v2_blockout.json').read_text())
anchors={r['id']:r for r in source['anchors']}
plant=anchors['B1_BOILER_01']; stance=anchors['B1_BOILER_CONTROL_STANCE']
base=next(r['y'] for r in source['levels'] if r['id']==plant['level'])
origin=Vector((plant['position'][0],base,plant['position'][2]))
delta=Vector(stance['position'])-Vector(plant['position']);angle=math.atan2(-delta.x,-delta.z)
def installed(p):
 x,y,z=p
 return origin+Vector((math.cos(angle)*x+math.sin(angle)*z,y,-math.sin(angle)*x+math.cos(angle)*z))
shaft=next(r for r in source['risers'] if r['id']=='HEAT_STACK')['rect']
shaft_center=Vector(((shaft[0]+shaft[2])/2,base+2.65,(shaft[1]+shaft[3])/2))
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
bpy.context.preferences.filepaths.save_version=0
mats={}
for key,color in {'Iron':(.18,.17,.15),'Steel':(.32,.31,.28)}.items():
 m=bpy.data.materials.new(key);m.diffuse_color=(*color,1);mats[key]=m

def point(v):return Vector((v[0],-v[2],v[1]))
def finish(o,name,role):
 o.name=name;o.data.materials.append(mats[role]);return o

def tube(name,stations,radius,role='Iron',thickness=.005,sides=32):
 verts=[];faces=[];uvs=[];distance=0
 for layer,rad in enumerate([radius,radius-thickness]):
  distance=0;previous_u=None
  for i,(at,tangent) in enumerate(stations):
   if i:distance+=(at-stations[i-1][0]).length
   seed=Vector((0,0,1)) if abs(tangent.z)<.95 else Vector((0,1,0))
   u=tangent.cross(seed).normalized() if previous_u is None else (previous_u-tangent*previous_u.dot(tangent)).normalized()
   previous_u=u;v=tangent.cross(u).normalized()
   for k in range(sides):
    a=k*math.tau/sides;verts.append(point(at+rad*(u*math.cos(a)+v*math.sin(a))))
    uvs.append((a*radius,distance))
 layer_size=len(stations)*sides
 for layer in range(2):
  for i in range(len(stations)-1):
   for k in range(sides):
    a=layer*layer_size+i*sides+k;b=layer*layer_size+i*sides+(k+1)%sides
    f=(a,b,b+sides,a+sides);faces.append(f if layer==0 else tuple(reversed(f)))
 for end in [0,len(stations)-1]:
  for k in range(sides):
   a=end*sides+k;b=end*sides+(k+1)%sides;faces.append((a,a+layer_size,b+layer_size,b))
 mesh=bpy.data.meshes.new(name);mesh.from_pydata(verts,[],faces);mesh.update()
 o=bpy.data.objects.new(name,mesh);bpy.context.collection.objects.link(o);finish(o,name,role)
 uv=mesh.uv_layers.new(name='UVMap')
 for p in mesh.polygons:
  for loop in p.loop_indices:uv.data[loop].uv=uvs[mesh.loops[loop].vertex_index]
 return o

def path(name,points,radius,bend):
 points=[Vector(p) for p in points]
 # Each elbow is a separate open fitting; straight ends meet its mouths.
 for i in range(len(points)-1):
  direction=(points[i+1]-points[i]).normalized()
  a=points[i]+direction*(bend if i else 0)
  b=points[i+1]-direction*(bend if i<len(points)-2 else 0)
  assert (b-a).dot(direction)>.01,(name,i,a,b)
  tube(name+'Straight',[(a,direction),(b,direction)],radius)
  if i<len(points)-2:
   c=points[i+1];out=(points[i+2]-c).normalized();center=c-direction*bend+out*bend
   assert abs(direction.dot(out))<.001
   stations=[]
   for step in range(17):
    t=step*math.pi/32
    stations.append((center-out*bend*math.cos(t)+direction*bend*math.sin(t),out*math.sin(t)+direction*math.cos(t)))
   tube(name+'Elbow',stations,radius)
  for at in [a,b]:tube('FittingSocket',[(at-direction*.035,direction),(at+direction*.035,direction)],radius+.009,'Steel',.008)

def cylinder(name,a,b,radius,role='Steel',sides=16):
 a,b=point(a),point(b);bpy.ops.mesh.primitive_cylinder_add(vertices=sides,radius=radius,depth=(b-a).length,location=(a+b)/2)
 o=bpy.context.object;o.rotation_euler=(b-a).to_track_quat('Z','Y').to_euler();bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
 return finish(o,name,role)

start=installed((.05,2.02,.02));high=Vector((start.x,base+2.65,start.z))
turn=Vector((shaft_center.x,high.y,high.z))
path('SteamFeed',[start,high,turn,shaft_center],.078,.14)
path('Equalizer',[installed((.05,2.35,.02)),installed((-.76,2.35,.02)),installed((-.76,2.35,.28)),installed((-.76,.18,.28)),installed((-.565,.18,.28))],.038,.08)
path('ReliefDischarge',[installed((-.30,1.745,-.10)),installed((-.30,2.18,-.10)),installed((-.30,2.18,.95)),installed((-.30,.20,.95))],.022,.07)
# Sliding clamps support the exposed side legs without obstructing controls.
for y in [.70,1.30]:
 at=installed((-.76,y,.28));axis=Vector((0,1,0))
 tube('EqualizerClip',[(at-axis*.016,axis),(at+axis*.016,axis)],.049,'Steel',.009)
 cylinder('EqualizerBracket',installed((-.615,y,.28)),installed((-.715,y,.28)),.009)
 cylinder('EqualizerPlate',installed((-.615,y,.28)),installed((-.63,y,.28)),.045)
 at=installed((-.30,y,.95))
 tube('DischargeClip',[(at-axis*.014,axis),(at+axis*.014,axis)],.032,'Steel',.008)
 cylinder('DischargeBracket',installed((-.30,y,.548)),installed((-.30,y,.925)),.007)
 cylinder('DischargePlate',installed((-.30,y,.543)),installed((-.30,y,.558)),.035)
# Threaded rods, split pipe rings and ceiling bearing plates clear the aisle.
for x in [9.8,10.9,12.0]:
 at=Vector((x,high.y,high.z));direction=Vector((1,0,0))
 tube('PipeHangerRing',[(at-direction*.022,direction),(at+direction*.022,direction)],.091,'Steel',.010)
 a=at+Vector((0,.09,0));b=Vector((x,base+float(source['dimensions']['clear_height'])-.015,high.z))
 cylinder('HangerRod',a,b,.006)
 cylinder('CeilingPlate',b,b+Vector((0,.015,0)),.05)
 for y in [a.y+.018,b.y-.01]:cylinder('HangerNut',(x,y-.006,high.z),(x,y+.006,high.z),.012,sides=6)
# A wall sleeve makes the concealed shaft transition explicit.
at=Vector((9.58,high.y,high.z));direction=Vector((1,0,0))
tube('WallEscutcheon',[(at-direction*.008,direction),(at+direction*.008,direction)],.13,'Steel',.045)
# The existing equalizer shares the steam takeoff. Its two independently
# generated open tubes previously left their hidden end rings/side walls
# inside one another. Open only the internal junction, retaining the installed
# route, outer silhouettes, socket bands, supports and all plant authority.
tee=installed((.05,2.35,.02))
junction_cutters=[]
for name,a,b,radius in [
 ('SteamTeeLumen',tee-Vector((0,.15,0)),tee+Vector((0,.15,0)),.0715),
 ('EqualizerTeeLumen',tee,tee+Vector((0,0,.15)),.032)]:
 cutter=cylinder(name,a,b,radius,sides=64)
 cutter.data.materials.clear();junction_cutters.append(cutter)
original_parts=[o for o in bpy.context.scene.objects if o.type=='MESH' and o not in junction_cutters]
changed=[]
for o in original_parts:
 bounds=[o.matrix_world@Vector(p) for p in o.bound_box]
 low=Vector(tuple(min(p[i] for p in bounds) for i in range(3)))
 high_box=Vector(tuple(max(p[i] for p in bounds) for i in range(3)))
 at=point(tee)
 if any(high_box[i]<at[i]-.16 or low[i]>at[i]+.16 for i in range(3)):continue
 bpy.context.view_layer.objects.active=o
 for cutter in junction_cutters:
  mod=o.modifiers.new(cutter.name,'BOOLEAN');mod.operation='DIFFERENCE';mod.solver='EXACT';mod.object=cutter
  bpy.ops.object.modifier_apply(modifier=mod.name)
 o.data.validate(clean_customdata=False)
 changed.append(o.name)
 if not o.data.polygons:
  # The takeoff's old socket was wholly hidden inside the parent tube.
  # The open junction consumes that redundant internal ring completely.
  bpy.data.objects.remove(o,do_unlink=True)
  continue
 uv=o.data.uv_layers.active
 if uv is None:uv=o.data.uv_layers.new(name='UVMap')
 for face in o.data.polygons:
  normal=face.normal.normalized();seed=Vector((0,0,1)) if abs(normal.z)<.9 else Vector((0,1,0))
  u=normal.cross(seed).normalized();v=normal.cross(u).normalized();origin=o.data.vertices[face.vertices[0]].co
  for loop in face.loop_indices:
   p=o.data.vertices[o.data.loops[loop].vertex_index].co-origin;uv.data[loop].uv=(p.dot(u),p.dot(v))
for cutter in junction_cutters:bpy.data.objects.remove(cutter,do_unlink=True)
print('BOILER INTERNAL TEE: fitted source parts='+str(changed))
for o in bpy.context.scene.objects:
 if o.type!='MESH':continue
 bm=bmesh.new();bm.from_mesh(o.data);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(o.data);bm.free()
 if not o.data.uv_layers:
  uv=o.data.uv_layers.new(name='UVMap')
  for p in o.data.polygons:
   axis=max(range(3),key=lambda i:abs(p.normal[i]));axes=((1,2),(0,2),(0,1))[axis]
   for loop in p.loop_indices:
    v=o.matrix_world@o.data.vertices[o.data.loops[loop].vertex_index].co;uv.data[loop].uv=(v[axes[0]],v[axes[1]])
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'art/blender/boiler_pipework.blend'))
for role,mat in mats.items():
 parts=[o for o in bpy.context.scene.objects if o.type=='MESH' and o.data.materials[0]==mat]
 bpy.ops.object.select_all(action='DESELECT')
 for o in parts:o.select_set(True)
 bpy.context.view_layer.objects.active=parts[0];bpy.ops.object.join();o=bpy.context.object;o.name=role
 bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
bpy.ops.object.select_all(action='SELECT')
bpy.ops.export_scene.gltf(filepath=str(ROOT/'game/assets/props/boiler_pipework.glb'),export_format='GLB',export_yup=True,export_apply=True)
