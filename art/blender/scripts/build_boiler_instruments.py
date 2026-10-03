"""Small fitted boiler instrument connections, glands and glass guards."""
from pathlib import Path
import bpy,bmesh
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[3]
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
mats={}
for role,color in {'Brass':(.58,.48,.27),'Steel':(.34,.33,.31),'Iron':(.20,.19,.18)}.items():
 m=bpy.data.materials.new(role);m.diffuse_color=(*color,1);mats[role]=m

def point(v):return Vector((v[0],-v[2],v[1]))
def finish(o,name,role,bevel=.001):
 o.name=name;o.data.materials.append(mats[role])
 if bevel:
  m=o.modifiers.new('Machined edge','BEVEL');m.width=bevel;m.segments=2;bpy.context.view_layer.objects.active=o;bpy.ops.object.modifier_apply(modifier=m.name)
 return o

def cyl(name,a,b,r,role='Brass',n=24):
 a,b=point(a),point(b);bpy.ops.mesh.primitive_cylinder_add(vertices=n,radius=r,depth=(b-a).length,location=(a+b)*.5);o=bpy.context.object;o.rotation_euler=(b-a).to_track_quat('Z','Y').to_euler();bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);return finish(o,name,role)

def box(name,at,size,role):
 bpy.ops.mesh.primitive_cube_add(size=1,location=point(at));o=bpy.context.object;o.dimensions=(size[0],size[2],size[1]);bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);return finish(o,name,role)

for y in [.82,1.34]:
 cyl('CasingBoss',(.5,y,-.528),(.5,y,-.552),.033,'Iron')
 cyl('ColumnFeed',(.5,y,-.537),(.5,y,-.590),.014)
 cyl('FeedUnion',(.5,y,-.543),(.5,y,-.560),.023,n=6)
 cyl('CockSpindle',(.5,y,-.585),(.5,y,-.642),.008)
 cyl('StemPacking',(.5,y,-.616),(.5,y,-.630),.015,n=6)
 gland_y=y+(.035 if y<1 else -.035)
 cyl('GlassPacking',(.5,gland_y-.008,-.585),(.5,gland_y+.008,-.585),.028,n=6)
 box('GlassGuardClip',(.5,gland_y,-.612),(.084,.012,.012),'Brass')
for x in [.466,.534]:cyl('GlassGuard',(x,.855,-.612),(x,1.305,-.612),.003,'Steel',12)
cyl('BlowdownSpindle',(.5,.72,-.57),(.5,.72,-.634),.008)
cyl('BlowdownPacking',(.5,.72,-.590),(.5,.72,-.608),.014,n=6)
cyl('GaugeBoss',(.31,1.48,-.525),(.31,1.48,-.551),.027,'Iron')
cyl('GaugeNipple',(.31,1.48,-.533),(.31,1.48,-.572),.014)
cyl('GaugeMountNut',(.31,1.48,-.541),(.31,1.48,-.558),.023,n=6)
for o in list(bpy.context.scene.objects):
 bm=bmesh.new();bm.from_mesh(o.data);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(o.data);bm.free()
 uv=o.data.uv_layers.new(name='UVMap')
 for p in o.data.polygons:
  axis=max(range(3),key=lambda i:abs(p.normal[i]));axes=((1,2),(0,2),(0,1))[axis]
  for loop in p.loop_indices:
   v=o.matrix_world@o.data.vertices[o.data.loops[loop].vertex_index].co;uv.data[loop].uv=(v[axes[0]],v[axes[1]])
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'art/blender/boiler_instruments.blend'))
for role,mat in mats.items():
 parts=[o for o in bpy.context.scene.objects if o.type=='MESH' and o.data.materials[0]==mat]
 bpy.ops.object.select_all(action='DESELECT')
 for o in parts:o.select_set(True)
 bpy.context.view_layer.objects.active=parts[0];bpy.ops.object.join();o=bpy.context.object;o.name=role;bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
bpy.ops.object.select_all(action='SELECT')
bpy.ops.export_scene.gltf(filepath=str(ROOT/'game/assets/props/boiler_instruments.glb'),export_format='GLB',export_yup=True,export_apply=True)
