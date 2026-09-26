"""V2 moulded wall switch. Metres, Godot-facing -Z; no gameplay authority.
Run: blender -b -P art/blender/scripts/build_light_switch.py
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
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    s = m.node_tree.nodes.get('Principled BSDF')
    s.inputs['Base Color'].default_value = (*color, 1)
    s.inputs['Metallic'].default_value = metal
    s.inputs['Roughness'].default_value = rough
    return m

phenolic = material('bakelite', (.065,.041,.027), 0, .32)
nickel = material('nickel_plated', (.64,.63,.58), .82, .3)
ceramic = material('porcelain', (.85,.82,.72), 0, .22)
dark = material('rubber_aged', (.018,.015,.013), 0, .8)

def finish(o, name, mat, bevel=0):
    o.name = name
    o.data.materials.append(mat)
    if bevel:
        mod = o.modifiers.new('Moulded edge radius', 'BEVEL')
        mod.width = bevel
        mod.segments = 4
        bpy.context.view_layer.objects.active = o
        bpy.ops.object.modifier_apply(modifier=mod.name)
    return o

def box(name, at, size, mat, bevel=0):
    bpy.ops.mesh.primitive_cube_add(size=1, location=p(at))
    o = bpy.context.object
    o.dimensions = (size[0],size[2],size[1])
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return finish(o,name,mat,bevel)

def cylinder(name, at, radius, depth, mat, bevel=.0007):
    bpy.ops.mesh.primitive_cylinder_add(vertices=48, radius=radius, depth=depth, location=p(at))
    o = bpy.context.object
    o.rotation_euler.x = math.pi/2
    return finish(o,name,mat,bevel)

def cut(o, cutter):
    bpy.context.view_layer.objects.active = o
    mod = o.modifiers.new('Recess', 'BOOLEAN')
    mod.operation = 'DIFFERENCE'
    mod.object = cutter
    bpy.ops.object.modifier_apply(modifier=mod.name)
    bpy.data.objects.remove(cutter, do_unlink=True)

# Back face matches the previous plate at z=-.008; no change to wall anchors.
box('BackingGasket',(0,0,-.009),(.116,.176,.002),dark,.001)
plate = box('MouldedPlate',(0,0,-.019),(.12,.18,.020),phenolic,.007)
slot = box('ToggleMortise',(0,0,-.032),(.018,.023,.021),dark,.005)
cut(plate,slot)
box('DarkSwitchThroat',(0,0,-.015),(.019,.039,.005),dark,.004)
for y in [-.063,.063]:
    pocket = cylinder('Counterbore',(0,y,-.030),.0065,.007,dark)
    cut(plate,pocket)
    head = cylinder('SlottedMountingScrew',(0,y,-.0275),.0054,.0025,nickel)
    slit = box('ScrewSlot',(0,y,-.029),(.0015,.009,.002),dark)
    cut(head,slit)
    box('SlotShadow',(0,y,-.0278),(.0012,.008,.0004),dark)
# Flanged nickel bushing, actual opening around the moving porcelain toggle.
collar = cylinder('ToggleCollar',(0,0,-.032),.014,.006,nickel)
cut(collar,cylinder('CollarBore',(0,0,-.032),.0095,.010,dark,0))
pivot = bpy.data.objects.new('TogglePivot',None)
bpy.context.collection.objects.link(pivot)
pivot.location = p((0,0,-.033))
stem = cylinder('NickelSpindle',(0,0,-.043),.005,.019,nickel)
grip = box('PorcelainToggle',(0,0,-.058),(.014,.017,.026),ceramic,.005)
for o in [stem,grip]:
    bpy.context.view_layer.update()
    transform = o.matrix_world.copy()
    o.parent = pivot
    o.matrix_world = transform

for o in list(bpy.context.scene.objects):
    if o.type != 'MESH': continue
    bpy.ops.object.select_all(action='DESELECT')
    o.select_set(True)
    bpy.context.view_layer.objects.active = o
    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.mesh.normals_make_consistent(inside=False)
    bpy.ops.uv.smart_project(island_margin=.02)
    bpy.ops.object.mode_set(mode='OBJECT')
    for face in o.data.polygons: face.use_smooth = True
    normal = o.modifiers.new('Weighted manufactured normals', 'WEIGHTED_NORMAL')
    normal.keep_sharp = True
    normal.weight = 50
    bpy.ops.object.modifier_apply(modifier=normal.name)
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'art/blender/light_switch.blend'))
# Keep the fabrication parts editable in the .blend; batch stationary hardware
# for the many installed instances. The toggle remains mechanically independent.
bpy.ops.object.select_all(action='DESELECT')
for o in bpy.context.scene.objects:
    if o.type == 'MESH' and o.parent is None: o.select_set(True)
bpy.context.view_layer.objects.active = plate
bpy.ops.object.join()
bpy.ops.export_scene.gltf(filepath=str(ROOT/'game/assets/props/light_switch.glb'),export_format='GLB',export_yup=True,export_apply=True)
