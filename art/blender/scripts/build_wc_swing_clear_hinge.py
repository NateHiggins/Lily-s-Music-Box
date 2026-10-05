"""Cranked wide-throw halves for the retained 700 mm Harukiya opening.

Closed coordinates use the original leaf datum. The barrel is 80 mm outboard
and 40 mm toward the opening side; runtime attaches each half to its owner.
"""
from pathlib import Path
import sys,math,json
import bpy,bmesh
import numpy as np
ROOT=Path(__file__).resolve().parents[3]
sys.path.insert(0,str(Path(__file__).parent))
from fabrication_uvs import chart_for_triangle
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
bpy.context.preferences.filepaths.save_version=0
mat=bpy.data.materials.new('iron_blackened');mat.use_nodes=True
s=mat.node_tree.nodes['Principled BSDF'];s.inputs['Base Color'].default_value=(.045,.04,.034,1)
s.inputs['Metallic'].default_value=.55;s.inputs['Roughness'].default_value=.5
groups={'Fixed':[],'Moving':[]}

def box(name,at,size,group):
 bpy.ops.mesh.primitive_cube_add(size=1,location=(at[0],-at[2],at[1]))
 o=bpy.context.object;o.name=name;o.dimensions=(size[0],size[2],size[1])
 bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
 o.data.materials.append(mat);groups[group].append(o)
 return o

def ring(name,y,group):
 n=40;verts=[];faces=[]
 for radius,dy in [(.0078,-.009),(.0078,.009),(.0036,.009),(.0036,-.009)]:
  for i in range(n):
   a=math.tau*i/n;verts.append((-.08+radius*math.cos(a),.04-radius*math.sin(a),y+dy))
 for j in range(4):
  for i in range(n):faces.append((j*n+i,j*n+(i+1)%n,((j+1)%4)*n+(i+1)%n,((j+1)%4)*n+i))
 data=bpy.data.meshes.new(name);data.from_pydata(verts,[],faces);data.update()
 o=bpy.data.objects.new(name,data);bpy.context.collection.objects.link(o)
 data.materials.append(mat);groups[group].append(o)

box('JambPlate',(-.045,0,-.0385),(.066,.105,.003),'Fixed')
box('FixedNeck',(-.066,0,-.04),(.028,.052,.006),'Fixed')
for y in [-.04,0,.04]:ring('FixedKnuckle',y,'Fixed')
box('LeafPlate',(.016,0,-.0315),(.048,.094,.003),'Moving')
for y in [-.02,.02]:
 ring('MovingKnuckle',y,'Moving')
 box('CrankArm',(-.024,y,-.04),(.10,.018,.006),'Moving')
 box('CrankReturn',(.024,y,-.035),(.006,.018,.016),'Moving')
for group,x,z in [('Fixed',-.045,-.041),('Moving',.016,-.034)]:
 for y in [-.028,.028]:
  bpy.ops.mesh.primitive_cylinder_add(vertices=32,radius=.0035,depth=.002,
   location=(x,-z,y),rotation=(math.pi/2,0,0))
  screw=bpy.context.object;screw.name=group+'SlottedScrew';screw.data.materials.append(mat)
  bpy.ops.mesh.primitive_cube_add(size=1,location=(x,-z+.001,y))
  cut=bpy.context.object;cut.dimensions=(.005,.0015,.001)
  bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
  bpy.context.view_layer.objects.active=screw
  mod=screw.modifiers.new('DriverSlot','BOOLEAN');mod.operation='DIFFERENCE';mod.object=cut
  bpy.ops.object.modifier_apply(modifier=mod.name);bpy.data.objects.remove(cut,do_unlink=True)
  groups[group].append(screw)
bpy.ops.mesh.primitive_cylinder_add(vertices=40,radius=.0034,depth=.114,location=(-.08,.04,0))
pin=bpy.context.object;pin.name='FixedPin';pin.data.materials.append(mat);groups['Fixed'].append(pin)
for y in [-.059,.059]:
 bpy.ops.mesh.primitive_uv_sphere_add(segments=24,ring_count=12,radius=1,location=(-.08,.04,y))
 o=bpy.context.object;o.name='PinCap';o.scale=(.008,.008,.003)
 o.data.materials.append(mat);groups['Fixed'].append(o)
for group,parts in groups.items():
 for o in parts:
  o['hinge_half']=group
  bpy.ops.object.select_all(action='DESELECT');o.select_set(True);bpy.context.view_layer.objects.active=o
  bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
  bm=bmesh.new();bm.from_mesh(o.data);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
  bmesh.ops.triangulate(bm,faces=list(bm.faces));bm.to_mesh(o.data)
  assert all(e.is_manifold for e in bm.edges) and bm.calc_volume(signed=True)>0,o.name
  bm.free()
  for layer in list(o.data.uv_layers):o.data.uv_layers.remove(layer)
  uv=o.data.uv_layers.new(name='Metres')
  o.data.materials.clear();o.data.materials.append(mat)
  for face in o.data.polygons:face.material_index=0
  for face in o.data.polygons:
   points=np.array([o.data.vertices[o.data.loops[i].vertex_index].co[:] for i in face.loop_indices])
   normal,u,values,fallback=chart_for_triangle(points,np.zeros(3),.4)
   for i,value in zip(face.loop_indices,values):uv.data[i].uv=value
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'art/blender/wc_swing_clear_hinge.blend'))
for name,parts in groups.items():
 bpy.ops.object.select_all(action='DESELECT')
 for o in parts:o.select_set(True)
 bpy.context.view_layer.objects.active=parts[0];bpy.ops.object.join();bpy.context.object.name=name
import io_scene_gltf2
class ExportUVHandedness:
 partitions=0
 def gather_attribute_change(self,attribute,data,normalized,export_settings):
  if attribute=='TANGENT':
   data['data'][:,3]*=-1
   type(self).partitions+=1
io_scene_gltf2.glTF2ExportUserExtension=ExportUVHandedness
bpy.ops.export_scene.gltf(filepath=str(ROOT/'game/assets/props/wc_swing_clear_hinge.glb'),export_format='GLB',export_yup=True,export_apply=True,export_tangents=True)
assert ExportUVHandedness.partitions==2
print('WC SWING CLEAR HINGE: fixed and moving native halves; axis=(-.08,0,-.04)')
