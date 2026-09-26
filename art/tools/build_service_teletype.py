"""Editable Blender teletype attachment. Dimensions are metres in Godot axes.
Run with blender --background --python art/tools/build_service_teletype.py.
No lettering is baked: production Label3D owns every printed character.
"""
import math
from pathlib import Path
import bpy

ROOT = Path(__file__).resolve().parents[2]
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)

def material(name, color, metal, rough):
    m = bpy.data.materials.new(name)
    m.diffuse_color = (*color, 1)
    m.use_nodes = True
    p = m.node_tree.nodes.get('Principled BSDF')
    p.inputs['Base Color'].default_value = (*color, 1)
    p.inputs['Metallic'].default_value = metal
    p.inputs['Roughness'].default_value = rough
    return m

brass = material('Aged machined brass', (.32,.22,.09), .82,.32)
steel = material('Blued tool steel', (.035,.045,.052), .8,.28)
rubber = material('Platen rubber', (.028,.022,.018), 0,.83)
ivory = material('Ceramic guide rollers', (.72,.64,.45), .05,.38)
ribbon = material('Carbon ink ribbon', (.032,.012,.016), 0,.92)
paper = material('Uncoated rag paper', (.88,.79,.60), 0,.92)
static = []

def finish(obj,name,at,mat,moving=False):
    obj.name = name
    obj.location = (at[0],-at[2],at[1])
    obj.data.materials.append(mat)
    bevel = obj.modifiers.new('Machined softened edges','BEVEL')
    bevel.width = .00055
    bevel.segments = 3
    obj.modifiers.new('Weighted corner normals','WEIGHTED_NORMAL')
    if not moving: static.append(obj)
    return obj

def box(name,at,size,mat,moving=False):
    bpy.ops.mesh.primitive_cube_add()
    o=bpy.context.object
    o.scale=(size[0]/2,size[2]/2,size[1]/2)
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    return finish(o,name,at,mat,moving)

def cylinder(name,at,radius,length,mat,axis='x',moving=False):
    bpy.ops.mesh.primitive_cylinder_add(vertices=48,radius=radius,depth=length)
    o=bpy.context.object
    if axis=='x': o.rotation_euler[1]=math.pi/2
    elif axis=='z': o.rotation_euler[0]=math.pi/2
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    for p in o.data.polygons: p.use_smooth=True
    return finish(o,name,at,mat,moving)

box('Printer frame',(0,.012,.062),(.202,.184,.014),steel)
box('Paper bed',(0,.025,.075),(.174,.157,.006),brass)
box('Paper',(0,.034,.080),(.163,.145,.0007),paper,True)
for x in [-.097,.097]:
    box('Folded brass cheek',(x,.01,.083),(.009,.181,.025),brass)
    for y in [-.068,.086]:
        cylinder('Slotted screw',(x,y,.098),.0032,.003,steel,'z')
        box('Screw slot',(x,y,.0996),(.004,.0006,.0005),brass)
    for y in [-.04,.06]:
        cylinder('Paper edge guide',(x*.86,y,.085),.004,.018,ivory,'y')
cylinder('Platen',(0,-.055,.086),.009,.176,rubber,moving=True)
cylinder('Guide rail',(0,-.070,.105),.0022,.194,steel)
cylinder('Return rail',(0,-.078,.100),.0016,.188,brass)
box('Carriage',(0,-.068,.109),(.023,.020,.014),brass,True)
box('Type hammer',(0,-.052,.100),(.005,.013,.008),steel,True)
box('Ink ribbon',(0,-.048,.097),(.176,.006,.001),ribbon)
for x,name in [(-.075,'SupplySpool'),(.075,'TakeupSpool')]:
    cylinder(name,(x,-.091,.096),.016,.006,steel,'z',True)
    cylinder('Ribbon winding',(x,-.091,.100),.012,.004,ribbon,'z')
    cylinder('Spool hub',(x,-.091,.104),.003,.005,brass,'z')
    for i in range(8):
        a=i*math.tau/8
        cylinder('Spool spoke rivet',(x+math.cos(a)*.013,-.091+math.sin(a)*.013,.101),.001,.002,brass,'z')
for x in [-.105,.105]:
    cylinder('Feed thumbwheel',(x,-.055,.086),.014,.012,brass)
    for i in range(32):
        a=i*math.tau/32
        cylinder('Knurl',(x,-.055+math.cos(a)*.014,.086+math.sin(a)*.014),.0007,.012,steel)
for i in range(24):
    box('Escapement rack tooth',(-.086+i*.0075,-.079,.112),(.003,.003,.003),brass)
for i in range(39):
    box('Serrated tear edge',(-.078+i*.004,.108,.084),(.002,.004,.0015),steel)
for i in range(16):
    cylinder('Return spring winding',(.104,-.01+i*.003,.080),.005,.001,steel,'y')

# Merge fixed hardware; named moving assemblies remain independently addressable.
bpy.ops.object.select_all(action='DESELECT')
for o in static: o.select_set(True)
bpy.context.view_layer.objects.active=static[0]
bpy.ops.object.convert(target='MESH')
bpy.ops.object.join()
bpy.context.object.name='PrinterFixedHardware'
source=ROOT/'art/models/service_teletype'
target=ROOT/'game/assets/device/service_teletype'
source.mkdir(parents=True,exist_ok=True); target.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.save_as_mainfile(filepath=str(source/'service_teletype.blend'))
bpy.ops.export_scene.gltf(filepath=str(target/'service_teletype.glb'),export_format='GLB',export_apply=True)
