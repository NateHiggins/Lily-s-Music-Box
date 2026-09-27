"""Real-size brass lift cab station, Godot +Z front. No baked lettering.
Run: blender -b -P art/blender/scripts/build_lift_cab_controls.py
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

# Board back is z=0, +Z faces into the cab. Keep the original legend locations.
plate=box('CabBoard',(0,0,.008),(.22,.88,.016),brass,.003)
parts=[plate]; screws=[]
buttons=[1.22-.085*7*.5+(i+.5)*.085-1.1475 for i in range(7)]
buttons += [.8325-1.1475,.7575-1.1475]
for i,y in enumerate(buttons):
    bore=.027 if i==7 else .0185
    cut(plate,cylinder('ButtonBore',(0,y,.01),bore,.04,brass))
    collar=cylinder('TurnedCollar',(0,y,.020),bore+.0065,.012,brass,.0008)
    cut(collar,cylinder('OpenThroat',(0,y,.020),bore,.025,brass))
    parts.append(collar)
for x in [-.078,.078]:
    for y in [-.4125,.4125]:
        cut(plate,cylinder('Counterbore',(x,y,.016),.006,.005,brass))
        screw=cylinder('SlottedFixing',(x,y,.014),.0048,.002,nickel,.0003)
        cut(screw,box('DriverSlot',(x,y,.015),(.0013,.007,.002),nickel))
        screws.append(screw)
    # Below the painted field the metal car wall is 18 mm farther back.
    parts.append(cylinder('LowerMountSpacer',(x,-.4125,-.009),.007,.018,brass,.0004))
stop=cylinder('StopCap',(0,0,.006),.026,.012,porcelain,.002)
for o in list(bpy.context.scene.objects):
    if o.type!='MESH': continue
    bpy.ops.object.select_all(action='DESELECT'); o.select_set(True)
    bpy.context.view_layer.objects.active=o
    bpy.ops.object.mode_set(mode='EDIT'); bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.mesh.normals_make_consistent(inside=False)
    bpy.ops.uv.smart_project(island_margin=.01)
    bpy.ops.object.mode_set(mode='OBJECT')
    for face in o.data.polygons:
        # Keep broad machined faces flat after the boolean holes; only curved
        # bores/edges interpolate normals. This avoids diagonal highlight seams.
        face.use_smooth=abs(face.normal.y)<.999
    normal=o.modifiers.new('Weighted normals','WEIGHTED_NORMAL')
    normal.keep_sharp=True
    bpy.ops.object.modifier_apply(modifier=normal.name)

bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'art/blender/lift_cab_controls.blend'))
# Editable fabrication parts stay separate in the .blend. Export three shared
# meshes, all with identity transforms and geometry relative to their mount.
for name, group in [('CabPlate',parts),('CabFixings',screws),('StopCap',[stop])]:
    bpy.ops.object.select_all(action='DESELECT')
    for o in group: o.select_set(True)
    bpy.context.view_layer.objects.active=group[0]
    if len(group)>1: bpy.ops.object.join()
    o=bpy.context.object; o.name=name
    bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
bpy.ops.export_scene.gltf(filepath=str(ROOT/'game/assets/props/lift_cab_controls.glb'),
    export_format='GLB',export_yup=True,export_apply=True)
