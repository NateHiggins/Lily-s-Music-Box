"""Author the guarded passenger-lift drive in Blender; metres, no texture text.

The visible sheave is a separate transform so the existing lift's car position
can drive it. This model has no simulation, interlock or maintenance authority.
Run: blender -b -P art/blender/scripts/build_lift_drive.py
"""
from pathlib import Path
import math
import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[3]
OUTPUT = ROOT / 'game/assets/building/v2_lift_drive.glb'

def point(v):
    return Vector((v[0], -v[2], v[1]))

def material(name, color, metal=0.0, roughness=.7):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    shader = mat.node_tree.nodes.get('Principled BSDF')
    shader.inputs['Base Color'].default_value = (*color, 1)
    shader.inputs['Metallic'].default_value = metal
    shader.inputs['Roughness'].default_value = roughness
    return mat

def finish(obj, name, mat, bevel=.004):
    obj.name = name
    obj.data.materials.append(mat)
    if bevel:
        modifier = obj.modifiers.new('Cast edge', 'BEVEL')
        modifier.width = bevel
        modifier.segments = 2
    return obj

def box(name, at, size, mat):
    bpy.ops.mesh.primitive_cube_add(size=1, location=point(at))
    obj = bpy.context.object
    obj.scale = (size[0], size[2], size[1])
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return finish(obj, name, mat)

def cylinder(name, at, radius, length, axis, mat, vertices=32):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius,
                                      depth=length, location=point(at))
    obj = bpy.context.object
    obj.rotation_mode = 'QUATERNION'
    obj.rotation_quaternion = Vector((0, 0, 1)).rotation_difference(point(axis))
    return finish(obj, name, mat)

def parent_keep_world(obj, parent):
    bpy.context.view_layer.update()
    transform = obj.matrix_world.copy()
    obj.parent = parent
    obj.matrix_world = transform
    bpy.context.view_layer.update()

def main():
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete(use_global=False)
    iron = material('cast_iron', (.085,.09,.086), .6, .75)
    steel = material('metal', (.22,.24,.23), .8, .48)
    brass = material('brass', (.34,.22,.08), .7, .55)
    concrete = material('concrete', (.24,.23,.20))
    box('DrivePlinth', (0,.08,0), (1.65,.16,1.4), concrete)
    for x in [-.58,.58]:
        box('MountingRail', (x,.20,0), (.12,.10,1.15), iron)
        for z in [-.48,.48]:
            cylinder('HoldDownBolt', (x,.27,z), .027,.065,(0,1,0), steel, 6)
    box('WormHousing', (-.33,.66,-.12), (.55,.85,.64), iron)
    box('HousingCover', (-.33,.66,.215), (.47,.69,.025), steel)
    for y in [.38,.92]:
        for x in [-.5,-.16]:
            cylinder('CoverBolt', (x,y,.24), .018,.02,(0,0,1), brass, 6)
    cylinder('MotorBody', (.3,.55,-.12), .245,.61,(1,0,0), iron)
    for x in [.05,.16,.27,.38,.49,.60]:
        cylinder('MotorCoolingRib', (x,.55,-.12), .262,.019,(1,0,0), iron)
    cylinder('MotorEnd', (.65,.55,-.12), .21,.07,(1,0,0), steel)
    box('MotorFoot', (.3,.31,-.12), (.62,.10,.48), iron)
    box('TerminalBox', (.3,.79,-.12), (.22,.15,.22), iron)
    cylinder('DriveShaft', (-.55,1.02,-.12), .06,.5,(1,0,0), steel)
    bpy.ops.object.empty_add(type='PLAIN_AXES', location=point((-.65,1.02,-.12)))
    sheave = bpy.context.object
    sheave.name = 'TractionSheave'
    bpy.context.view_layer.update()
    # Grooved drum with visible spokes, not a featureless wheel.
    for x in [-.73,-.69,-.65,-.61,-.57]:
        parent_keep_world(cylinder('RopeFlange', (x,1.02,-.12), .34,.015,(1,0,0), iron), sheave)
    parent_keep_world(cylinder('RopeBed', (-.65,1.02,-.12), .315,.17,(1,0,0), steel), sheave)
    parent_keep_world(cylinder('SheaveHub', (-.755,1.02,-.12), .075,.045,(1,0,0), brass), sheave)
    for angle in range(0,360,60):
        a = math.radians(angle)
        spoke = box('SheaveSpoke', (-.785,1.02+.16*math.cos(a),-.12+.16*math.sin(a)), (.025,.29,.035), iron)
        spoke.rotation_euler.x = -a
        parent_keep_world(spoke, sheave)
    # The fixed cage is part of the equipment's architectural envelope.
    for x in [-1.05,1.05]:
        for z in [-1.075,1.075]:
            box('GuardPost', (x,.95,z), (.04,1.9,.04), iron)
    for y in [.12,1.0,1.9]:
        for z in [-1.075,1.075]:
            box('GuardRail', (0,y,z), (2.1,.025,.025), steel)
        for x in [-1.05,1.05]:
            box('GuardRail', (x,y,0), (.025,.025,2.15), steel)
    for index in range(15):
        x = -1.05+index*.15
        for z in [-1.075,1.075]:
            box('GuardBar', (x,1,z), (.013,1.8,.013), iron)
    for index in range(15):
        z = -1.075+index*(2.15/14)
        for x in [-1.05,1.05]:
            box('GuardBar', (x,1,z), (.013,1.8,.013), iron)
    # A handful of material draws, while retaining the driven sheave transform.
    for parent in [None, sheave]:
        for mat in [iron, steel, brass, concrete]:
            members = [obj for obj in bpy.context.scene.objects
                       if obj.type == 'MESH' and obj.parent == parent
                       and obj.data.materials[0] == mat]
            if not members:
                continue
            bpy.ops.object.select_all(action='DESELECT')
            for obj in members:
                obj.select_set(True)
            bpy.context.view_layer.objects.active = members[0]
            bpy.ops.object.join()
            members[0].name = ('Sheave_' if parent else 'Fixed_') + mat.name
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=str(OUTPUT), export_format='GLB',
                              export_apply=True, export_yup=True,
                              export_animations=False)
    print('Exported guarded lift drive:', OUTPUT)

if __name__ == '__main__':
    main()
