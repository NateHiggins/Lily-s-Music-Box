"""Door-face-mounted mortise knob set, +Z front, spindle at local origin."""
from pathlib import Path
import math
import bpy
ROOT=Path(__file__).resolve().parents[3]
bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)
m=bpy.data.materials.new('brass_dull'); m.use_nodes=True
s=m.node_tree.nodes['Principled BSDF']; s.inputs['Base Color'].default_value=(.48,.35,.16,1)
s.inputs['Metallic'].default_value=.8; s.inputs['Roughness'].default_value=.4
def box(name,at,size,bevel=0):
    bpy.ops.mesh.primitive_cube_add(size=1,location=(at[0],-at[2],at[1]))
    o=bpy.context.object; o.name=name; o.dimensions=(size[0],size[2],size[1])
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True); o.data.materials.append(m)
    if bevel:
        mod=o.modifiers.new('Rounded pressed edge','BEVEL'); mod.width=bevel; mod.segments=4
        bpy.ops.object.modifier_apply(modifier=mod.name)
    return o
def cylinder(name,x,y,z,r,depth):
    bpy.ops.mesh.primitive_cylinder_add(vertices=48,radius=r,depth=depth,location=(x,-z,y),rotation=(math.pi/2,0,0))
    o=bpy.context.object; o.name=name; o.data.materials.append(m); return o
def cut(o,cutter):
    bpy.context.view_layer.objects.active=o
    mod=o.modifiers.new('Through opening','BOOLEAN'); mod.operation='DIFFERENCE'; mod.object=cutter
    bpy.ops.object.modifier_apply(modifier=mod.name); bpy.data.objects.remove(cutter,do_unlink=True)
plate=box('Escutcheon',(0,-.055,.0025),(.055,.18,.005),.002)
cut(plate,cylinder('Keyhole round',0,-.108,.0025,.004,.015))
cut(plate,box('Keyhole stem',(0,-.116,.0025),(.005,.013,.015)))
profile=[(0,.003),(.018,.003),(.020,.005),(.020,.009),(.016,.012),(.010,.014),(.009,.034),(.018,.037),(.025,.043),(.029,.053),(.028,.061),(.023,.067),(.012,.070),(0,.071)]
n=64; vertices=[]; faces=[]
for r,z in profile:
    for i in range(n):
        a=i*math.tau/n; vertices.append((r*math.cos(a),-z,r*math.sin(a)))
for j in range(len(profile)):
    for i in range(n): faces.append((j*n+i,j*n+(i+1)%n,((j+1)%len(profile))*n+(i+1)%n,((j+1)%len(profile))*n+i))
data=bpy.data.meshes.new('TurnedKnob'); data.from_pydata(vertices,[],faces); data.update()
o=bpy.data.objects.new('TurnedKnob',data); bpy.context.collection.objects.link(o); data.materials.append(m)
for y in [.026,-.135]:
    screw=cylinder('SlottedScrew',0,y,.006,.0035,.003)
    cut(screw,box('Slot',(0,y,.0074),(.005,.001,.0015)))
for o in list(bpy.context.scene.objects):
    bpy.ops.object.select_all(action='DESELECT'); o.select_set(True); bpy.context.view_layer.objects.active=o
    bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
    bpy.ops.object.mode_set(mode='EDIT'); bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.mesh.remove_doubles(threshold=.0000001); bpy.ops.mesh.normals_make_consistent(inside=False)
    bpy.ops.uv.smart_project(island_margin=.01); bpy.ops.object.mode_set(mode='OBJECT')
    if o.name=='TurnedKnob':
        for polygon in o.data.polygons: polygon.use_smooth=True
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'art/blender/door_knob_set.blend'))
bpy.ops.object.select_all(action='SELECT'); bpy.context.view_layer.objects.active=plate
bpy.ops.object.join(); bpy.context.object.name='KnobSet'
bpy.ops.export_scene.gltf(filepath=str(ROOT/'game/assets/props/door_knob_set.glb'),export_format='GLB',export_yup=True,export_apply=True)
