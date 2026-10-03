"""Editable apartment lavatory. Run blender -b -P this_file.py.

Metres; inputs use Godot coordinates. Moving valve and plug pivots are exported
separately. TapProp owns water, sound, maintenance and all interaction authority.
Existing catalogue finishes are assigned by material name at runtime.
"""
from pathlib import Path
import math
import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[3]
OUT = ROOT / 'game/assets/props/bath_lavatory.glb'
SOURCE = ROOT / 'art/blender/bath_lavatory.blend'
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)

def p(v): return Vector((v[0], -v[2], v[1]))

def mat(name, color, metal, rough):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    s = m.node_tree.nodes.get('Principled BSDF')
    s.inputs['Base Color'].default_value = (*color, 1)
    s.inputs['Metallic'].default_value = metal
    s.inputs['Roughness'].default_value = rough
    return m

glaze = mat('porcelain_fixture', (.88,.87,.82), 0, .22)
nickel = mat('nickel_plated', (.72,.71,.67), .82, .25)
rubber = mat('rubber_aged', (.035,.029,.023), 0, .72)

def group(name, at=(0,0,0)):
    obj = bpy.data.objects.new(name, None)
    bpy.context.collection.objects.link(obj)
    obj.location = p(at)
    return obj

fixed = group('CastAndPlumbing')

def finish(obj, name, material, parent=fixed, bevel=0):
    obj.name = name
    obj.data.materials.append(material)
    if bevel:
        mod = obj.modifiers.new('Rounded manufactured edges', 'BEVEL')
        mod.width = bevel
        mod.segments = 3
    if hasattr(obj.data, 'polygons'):
        for face in obj.data.polygons: face.use_smooth = True
    bpy.context.view_layer.update()
    world = obj.matrix_world.copy()
    obj.parent = parent
    obj.matrix_world = world
    return obj

def cylinder(name, at, radius, depth, material, axis=(0,1,0), parent=fixed, vertices=48):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=depth, location=p(at))
    obj = bpy.context.object
    obj.rotation_mode = 'QUATERNION'
    obj.rotation_quaternion = Vector((0,0,1)).rotation_difference(p(axis))
    return finish(obj, name, material, parent, .001)

def pipe(name, points, radius, material=nickel, parent=fixed):
    curve = bpy.data.curves.new(name, 'CURVE')
    curve.dimensions = '3D'
    curve.resolution_u = 16
    curve.bevel_depth = radius
    curve.bevel_resolution = 4
    curve.use_fill_caps = True
    spline = curve.splines.new('BEZIER')
    spline.bezier_points.add(len(points)-1)
    for bp, pos in zip(spline.bezier_points, points):
        bp.co = p(pos)
        bp.handle_left_type = bp.handle_right_type = 'AUTO'
    obj = bpy.data.objects.new(name, curve)
    bpy.context.collection.objects.link(obj)
    return finish(obj, name, material, parent)

def ring_mesh(name, rings, material, parent=fixed, n=96):
    # rx, rz, y, z offset, rear rise; connected rings form a watertight shell.
    verts = []
    for rx, rz, y, z, rise in rings:
        for i in range(n):
            a = math.tau*i/n
            rear = max(0, math.sin(a)) ** 4
            verts.append(p((rx*math.cos(a), y+rise*rear, z+rz*math.sin(a))))
    faces = []
    for j in range(len(rings)):
        k = (j+1) % len(rings)
        for i in range(n):
            h = (i+1) % n
            faces.append((j*n+i,j*n+h,k*n+h,k*n+i))
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    finish(obj, name, material, parent)
    # Recalculate normals and unwrap; no photographs or lettering in texture.
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.select_all(action='DESELECT')
    obj.select_set(True)
    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.mesh.normals_make_consistent(inside=False)
    bpy.ops.uv.smart_project(island_margin=.01)
    bpy.ops.object.mode_set(mode='OBJECT')
    return obj

# One casting: drain throat, shallow floor, rising bowl, rolled rim and underside.
# The rear of the same shell rises into a coved back; no board atop a torus.
ring_mesh('IntegralBowlAndBack', [
    (.024,.024,.680,-.02,0),(.026,.026,.687,-.02,0),
    (.090,.065,.690,-.02,0),(.185,.125,.704,-.02,0),
    (.250,.176,.742,-.02,.035),(.279,.200,.780,-.02,.175),
    (.288,.208,.795,-.02,.175),(.301,.220,.801,-.02,.168),
    (.313,.232,.792,-.02,.162),(.310,.231,.779,-.02,.157),
    (.284,.211,.722,-.02,.100),(.220,.159,.670,-.02,.040),
    (.085,.064,.662,-.02,0),(.024,.024,.673,-.02,0)],glaze)
# Slender pedestal supports the bowl forward of a genuinely exposed rear waste.
ring_mesh('Pedestal',[(.001,.001,.012,-.095,0),(.132,.105,.012,-.095,0),
    (.140,.112,.026,-.095,0),(.135,.108,.055,-.095,0),
    (.067,.058,.095,-.095,0),(.052,.043,.540,-.095,0),
    (.073,.064,.614,-.095,0),(.100,.086,.665,-.095,0),
    (.001,.001,.665,-.095,0)],glaze)

# Wall escutcheons and a bridge casting; valves remain independent pivots.
for x, name in [(-.09,'HotValve'),(.09,'ColdValve')]:
    cylinder('CastValveBoss',(x,.91,.166),.030,.058,glaze,(0,0,1))
    cylinder('Seat', (x,.91,.133), .025,.010,nickel,(0,0,1))
    pipe('ValveBody',[(x,.91,.184),(x,.91,.080)],.015)
    pivot = group(name,(x,.91,.1215))
    cylinder('Spindle',(x,.91,.073),.010,.036,nickel,(0,0,1),pivot)
    for axis in [(1,0,0),(0,1,0)]:
        cylinder('CrossGrip',(x,.91,.056),.005,.064,nickel,axis,pivot)
        for sign in [-1,1]:
            pos=(x+axis[0]*sign*.029,.91+axis[1]*sign*.029,.056)
            bpy.ops.mesh.primitive_uv_sphere_add(segments=16,ring_count=8,radius=.007,location=p(pos))
            finish(bpy.context.object,'GripEnd',nickel,pivot)
    cylinder('IndexButton',(x,.91,.046),.010,.006,glaze,(0,0,1),pivot)
pipe('Bridge',[(-.09,.91,.105),(0,.91,.105),(.09,.91,.105)],.011)
pipe('CurvedSpout',[(0,.91,.105),(0,.96,.10),(0,.967,.00),(0,.934,-.075),(0,.885,-.075)],.013)
cylinder('SpoutLip',(0,.888,-.075),.015,.012,nickel)
cylinder('SpoutBore',(0,.8815,-.075),.0105,.001,rubber)
ring_mesh('DrainFlange',[(.024,.024,.680,-.02,0),(.034,.034,.687,-.02,0),
    (.034,.034,.691,-.02,0),(.024,.024,.691,-.02,0)],nickel)
# Waste bends rearwards clear of the pedestal, then forms a real U and wall arm.
pipe('WasteAndTrap',[(0,.676,-.02),(0,.60,.06),(0,.48,.065),
    (0,.435,.11),(0,.46,.17),(0,.55,.18),(0,.55,.225)],.018)
for y,z in [(.62,.038),(.485,.065),(.53,.18)]:
    cylinder('SlipNut',(0,y,z),.025,.023,nickel,vertices=8)
cylinder('WasteWallPlate',(0,.55,.225),.039,.009,nickel,(0,0,1))
for x in [-.09,.09]:
    pipe('SupplyRiser',[(x,.30,.225),(x,.30,.18),(x,.84,.18),(x,.91,.184)],.007)
    cylinder('SupplyWallPlate',(x,.30,.225),.026,.009,nickel,(0,0,1))
    cylinder('AngleStop',(x,.30,.176),.014,.031,nickel,(0,0,1))
    cylinder('ServiceGrip',(x,.30,.152),.020,.006,nickel,(0,0,1))
    for y in [.32,.86]: cylinder('SupplyNut',(x,y,.18),.011,.017,nickel,vertices=6)

plug=group('Stopper',(0,.696,-.02))
cylinder('RubberPlug',(0,.696,-.02),.026,.016,rubber,parent=plug)
cylinder('PlugButton',(0,.706,-.02),.011,.003,nickel,parent=plug)
pipe('PlugEye',[(-.005,.707,-.02),(0,.716,-.02),(.005,.707,-.02)],.0018,parent=plug)
# Ball-chain slack is animated by TapProp using these individual links.
chain=group('StopperChain')
for i in range(24):
    t=i/23
    at=(.04*t,.714+.184*t-.045*math.sin(math.pi*t),-.02+.102*t)
    bpy.ops.mesh.primitive_uv_sphere_add(segments=8,ring_count=4,radius=.0024,location=p(at))
    finish(bpy.context.object,'ChainLink%02d'%i,nickel,chain)
pipe('FaucetChainEye',[(.035,.909,.092),(.04,.898,.082),(.045,.909,.092)],.0022)

# Apply curves/modifiers, then batch only static geometry by finish.
bpy.ops.object.select_all(action='DESELECT')
for obj in list(bpy.context.scene.objects):
    if obj.type in {'MESH','CURVE'}:
        bpy.context.view_layer.objects.active=obj
        obj.select_set(True)
        bpy.ops.object.convert(target='MESH')
        obj.select_set(False)
for parent in [fixed]+[o for o in bpy.context.scene.objects if o.name in {'HotValve','ColdValve','Stopper'}]:
    for material in [glaze,nickel,rubber]:
        parts=[o for o in parent.children if o.type=='MESH' and o.data.materials[0]==material]
        if not parts: continue
        bpy.ops.object.select_all(action='DESELECT')
        for o in parts:o.select_set(True)
        bpy.context.view_layer.objects.active=parts[0]
        bpy.ops.object.join()
        bpy.context.object.name=parent.name+'_'+material.name
OUT.parent.mkdir(parents=True,exist_ok=True)
SOURCE.parent.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE))
bpy.ops.export_scene.gltf(filepath=str(OUT),export_format='GLB',export_apply=True,export_yup=True,export_animations=False)
print('LAVATORY EXPORTED',OUT)
