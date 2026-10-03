"""Real-size brass lift call station, Godot +Z front. No baked lettering.
Run: blender -b -P art/blender/scripts/build_lift_call_plate.py
"""
from pathlib import Path
import math
import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[3]
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)

def p(v): return Vector((v[0], -v[2], v[1]))

def material(name, color, metal, rough):
    m=bpy.data.materials.new(name); m.use_nodes=True
    s=m.node_tree.nodes['Principled BSDF']
    s.inputs['Base Color'].default_value=(*color,1)
    s.inputs['Metallic'].default_value=metal
    s.inputs['Roughness'].default_value=rough
    return m

brass=material('brass_dull',(.62,.52,.28),.8,.35)
nickel=material('nickel_plated',(.64,.63,.58),.82,.3)
porcelain=material('porcelain',(.92,.88,.78),0,.24)

def bevel(o, radius):
    bpy.context.view_layer.objects.active=o
    mod=o.modifiers.new('Manufactured edge radius','BEVEL')
    mod.width=radius; mod.segments=4
    bpy.ops.object.modifier_apply(modifier=mod.name)

def box(name, at, size, mat, radius=0):
    bpy.ops.mesh.primitive_cube_add(size=1,location=p(at))
    o=bpy.context.object; o.name=name
    o.dimensions=(size[0],size[2],size[1])
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    o.data.materials.append(mat)
    if radius: bevel(o,radius)
    return o

def cylinder(name, at, radius, depth, mat, edge=0):
    bpy.ops.mesh.primitive_cylinder_add(vertices=64,radius=radius,depth=depth,
        location=p(at),rotation=(math.pi/2,0,0))
    o=bpy.context.object; o.name=name; o.data.materials.append(mat)
    bpy.ops.object.transform_apply(location=False,rotation=True,scale=True)
    if edge: bevel(o,edge)
    return o

def cut(o, cutter):
    bpy.context.view_layer.objects.active=o
    mod=o.modifiers.new('Machined opening','BOOLEAN')
    mod.operation='DIFFERENCE'; mod.object=cutter
    bpy.ops.object.modifier_apply(modifier=mod.name)
    bpy.data.objects.remove(cutter,do_unlink=True)

# Back is exactly z=0; runtime mounts this face on the actual V2 wall.
plate=box('CastBrassPlate',(0,0,.0075),(.10,.17,.015),brass,.0035)
cut(plate,cylinder('ButtonBore',(0,0,.01),.0185,.03,brass))
collar=cylinder('TurnedButtonCollar',(0,0,.019),.025,.014,brass,.001)
cut(collar,cylinder('CollarBore',(0,0,.019),.0185,.025,brass))
# The fine annular step catches the lamp around the button throat.
ring=cylinder('CollarFlange',(0,0,.015),.028,.004,brass,.0006)
cut(ring,cylinder('FlangeBore',(0,0,.015),.023,.01,brass))
screws=[]
for y in [-.062,.062]:
    cut(plate,cylinder('FixingCounterbore',(0,y,.015),.006,.006,brass))
    screw=cylinder('SlottedFixing',(0,y,.013),.0048,.002, nickel,.0003)
    cut(screw,box('DriverSlot',(0,y,.014),(.0013,.007,.002),nickel))
    screws.append(screw)
# Independent cap, origin at its rear face. Runtime supplies rest and press poses.
cap=cylinder('ButtonCap',(0,0,.006),.017,.012,porcelain,.0015)

for o in list(bpy.context.scene.objects):
    if o.type!='MESH': continue
    bpy.ops.object.select_all(action='DESELECT'); o.select_set(True)
    bpy.context.view_layer.objects.active=o
    bpy.ops.object.mode_set(mode='EDIT'); bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.mesh.normals_make_consistent(inside=False)
    bpy.ops.uv.smart_project(island_margin=.01)
    bpy.ops.object.mode_set(mode='OBJECT')
    for face in o.data.polygons: face.use_smooth=True
    normal=o.modifiers.new('Weighted normals','WEIGHTED_NORMAL')
    normal.keep_sharp=True
    bpy.ops.object.modifier_apply(modifier=normal.name)

bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'art/blender/lift_call_plate.blend'))
# Editable fabrication parts stay separate in the .blend. Export three shared
# meshes, all with identity transforms and geometry relative to their mount.
for name, group in [('CallPlate',[plate,collar,ring]),('CallFixings',screws),('ButtonCap',[cap])]:
    bpy.ops.object.select_all(action='DESELECT')
    for o in group: o.select_set(True)
    bpy.context.view_layer.objects.active=group[0]
    if len(group)>1: bpy.ops.object.join()
    o=bpy.context.object; o.name=name
    bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
bpy.ops.export_scene.gltf(filepath=str(ROOT/'game/assets/props/lift_call_plate.glb'),
    export_format='GLB',export_yup=True,export_apply=True)
