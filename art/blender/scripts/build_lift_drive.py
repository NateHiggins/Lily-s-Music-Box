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

def group(name):
    bpy.ops.object.empty_add(type='PLAIN_AXES')
    obj = bpy.context.object
    obj.name = name
    return obj

def rope(name, points, mat):
    curve = bpy.data.curves.new(name, 'CURVE')
    curve.dimensions = '3D'
    curve.bevel_depth = .006
    curve.bevel_resolution = 2
    spline = curve.splines.new('POLY')
    spline.points.add(len(points)-1)
    for p, v in zip(spline.points, points): p.co = (*point(v), 1)
    obj = bpy.data.objects.new(name, curve)
    bpy.context.collection.objects.link(obj)
    bpy.ops.object.select_all(action='DESELECT')
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.convert(target='MESH')
    obj.data.materials.append(mat)
    return obj

def suspension(iron, steel):
    moving = []
    # Four continuous parallel ropes: car leg, upper traction wrap, two
    # quarter-turn deflectors, then the counterweight behind the cabin.
    for index, x in enumerate([-.71,-.67,-.63,-.59]):
        points = [(x,1.02+.321*math.sin(a),-.12+.321*math.cos(a))
                  for a in [math.pi-i*math.pi/32 for i in range(33)]]
        points += [(x,.55,.201)]
        points += [(x,.55+.156*math.sin(a),.357+.156*math.cos(a))
                   for a in [math.pi+i*math.pi/24 for i in range(13)]]
        points += [(x,.394,1.07)]
        points += [(x,.238+.156*math.sin(a),1.07+.156*math.cos(a))
                   for a in [math.pi/2-i*math.pi/24 for i in range(13)]]
        rope('RopeWrap', points, steel)
        for prefix, z in [('CarRope',-.441),('CounterRope',1.226)]:
            node = group(prefix+str(index))
            # Unit centred segment; runtime sets only length and centre.
            parent_keep_world(cylinder(prefix, (x,0,z), .006,1,(0,1,0),steel,8), node)
            moving.append(node)
    for name, y, z in [('FirstDeflector',.55,.357),('SecondDeflector',.238,1.07)]:
        node = group(name)
        node.location = point((-.65,y,z))
        bpy.context.view_layer.update()
        for x in [-.73,-.69,-.65,-.61,-.57]:
            parent_keep_world(cylinder('DeflectorFlange',(x,y,z),.17,.012,(1,0,0),iron),node)
        parent_keep_world(cylinder('DeflectorBed',(-.65,y,z),.15,.17,(1,0,0),steel),node)
        cylinder('DeflectorAxle',(-.65,y,z),.035,.40,(1,0,0),steel)
        for x in [-.86,-.44]:
            box('BearingStand',(x,y*.5,z),(.07,y,.13),iron)
        moving.append(node)
    counter = group('Counterweight')
    for y in [-.70,.70]:
        parent_keep_world(box('WeightFrame',(-.65,y,1.22),(.40,.08,.10),steel),counter)
    for x in [-.83,-.47]:
        parent_keep_world(box('WeightUpright',(x,0,1.22),(.04,1.50,.10),steel),counter)
    for i in range(10):
        parent_keep_world(box('WeightSlab',(-.65,-.585+i*.13,1.22),(.32,.12,.09),iron),counter)
    parent_keep_world(box('WeightHitch',(-.65,.79,1.22),(.22,.08,.09),steel),counter)
    moving.append(counter)
    crosshead = group('CarCrosshead')
    parent_keep_world(box('CarHitchBeam',(.1,.05,-.441),(1.76,.10,.11),steel),crosshead)
    for x in [-.75,.95]:
        parent_keep_world(box('CarSlingShoe',(x,0,-.441),(.06,.16,.15),iron),crosshead)
    moving.append(crosshead)
    # Guide channels behind the car, fixed to the shaft wall. Their entire
    # envelope stays north of the passenger car's closed rear wall.
    for x in [-.90,-.40]:
        box('CounterGuide',(x,-11.35,1.22),(.025,22.30,.09),steel)
        for y in [-21.6,-18.4,-15.2,-12,-8.8,-5.6,-2.4]:
            box('GuideBracket',(x,y,1.28),(.08,.055,.12),iron)
    for x in [-.85,1.05]:
        box('CarGuide',(x,-11.35,-.441),(.025,22.30,.09),steel)
        for y in [-21.6,-18.4,-15.2,-12,-8.8,-5.6,-2.4]:
            toward_wall = -.08 if x < 0 else .08
            box('CarGuideBracket',(x+toward_wall,y,-.441),(.16,.055,.10),iron)
    return moving

def main():
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete(use_global=False)
    iron = material('cast_iron', (.085,.09,.086), .6, .75)
    steel = material('metal', (.22,.24,.23), .8, .48)
    brass = material('brass', (.34,.22,.08), .7, .55)
    concrete = material('concrete', (.24,.23,.20))
    # The car ropes pass through the foundation as well as the roof slab.
    for x0,z0,x1,z1 in [(-.825,-.7,-.76,.7),(-.54,-.7,.825,.7),
                        (-.76,-.7,-.54,-.48),(-.76,-.39,-.54,.7)]:
        box('DrivePlinth', ((x0+x1)/2,.08,(z0+z1)/2), (x1-x0,.16,z1-z0), concrete)
    for x in [-.33,.58]:
        box('MountingRail', (x,.20,0), (.12,.10,1.15), iron)
        for z in [-.48,.48]:
            cylinder('HoldDownBolt', (x,.27,z), .027,.065,(0,1,0), steel, 6)
    box('WormHousing', (-.33,.66,-.12), (.55,.85,.58), iron)
    box('HousingCover', (-.33,.66,.185), (.47,.69,.025), steel)
    for y in [.38,.92]:
        for x in [-.5,-.16]:
            cylinder('CoverBolt', (x,y,.21), .018,.02,(0,0,1), brass, 6)
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
    moving = suspension(iron, steel)
    # Extended front guard encloses the rear-shaft rope penetration.
    for x in [-1.05,1.05]:
        for z in [-1.075,1.31]:
            box('GuardPost', (x,.95,z), (.04,1.9,.04), iron)
    for y in [.12,1.0,1.9]:
        for z in [-1.075,1.31]:
            box('GuardRail', (0,y,z), (2.1,.025,.025), steel)
        for x in [-1.05,1.05]:
            box('GuardRail', (x,y,.1175), (.025,.025,2.385), steel)
    for index in range(15):
        x = -1.05+index*.15
        for z in [-1.075,1.31]:
            box('GuardBar', (x,1,z), (.013,1.8,.013), iron)
    for index in range(15):
        z = -1.075+index*(2.385/14)
        for x in [-1.05,1.05]:
            box('GuardBar', (x,1,z), (.013,1.8,.013), iron)
    # A handful of material draws, while retaining the driven sheave transform.
    for parent in [None, sheave] + moving:
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
            members[0].name = (parent.name+'_' if parent else 'Fixed_') + mat.name
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=str(OUTPUT), export_format='GLB',
                              export_apply=True, export_yup=True,
                              export_animations=False)
    print('Exported guarded lift drive:', OUTPUT)

if __name__ == '__main__':
    main()
