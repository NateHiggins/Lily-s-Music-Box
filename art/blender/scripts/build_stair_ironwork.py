"""Blender-authored V2 outer stair rails, metres; no collision authority.

Run: blender -b -P art/blender/scripts/build_stair_ironwork.py
Two shared assemblies fit the public and service stair schedules exactly.
"""
from pathlib import Path
import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[3]

def point(v):
    return Vector((v[0], -v[2], v[1]))

def material(name, color, metal=0, rough=.5):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    bsdf = m.node_tree.nodes['Principled BSDF']
    bsdf.inputs['Base Color'].default_value = (*color, 1)
    bsdf.inputs['Metallic'].default_value = metal
    bsdf.inputs['Roughness'].default_value = rough
    return m

def box(name, at, size, mat, bevel=.002):
    bpy.ops.mesh.primitive_cube_add(size=1, location=point(at))
    obj = bpy.context.object
    obj.name = name
    obj.scale = (size[0], size[2], size[1])
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(mat)
    edge = obj.modifiers.new('Forged edge', 'BEVEL')
    edge.width = bevel
    edge.segments = 2
    obj.modifiers.new('Face normals', 'WEIGHTED_NORMAL')
    return obj

def rod(name, a, b, radius, mat):
    delta = point(b)-point(a)
    bpy.ops.mesh.primitive_cylinder_add(vertices=16, radius=radius,
                                      depth=delta.length, location=(point(a)+point(b))*.5)
    obj = bpy.context.object
    obj.name = name
    obj.rotation_mode = 'QUATERNION'
    obj.rotation_quaternion = Vector((0,0,1)).rotation_difference(delta)
    obj.data.materials.append(mat)
    for face in obj.data.polygons:
        face.use_smooth = len(face.vertices)==4
    return obj

def build(name, width, tread, landing):
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete(use_global=False)
    # Keep catalogue names exact across both assemblies in one Blender run.
    for old in list(bpy.data.materials):
        bpy.data.materials.remove(old)
    iron = material('cast_iron', (.055,.055,.052), .65, .55)
    wood = material('wood_dark', (.095,.052,.025), 0, .35)
    steel = material('steel', (.26,.27,.27), .8, .4)
    rise, count, gap, guard = .16, 10, .30, .91
    run, half = tread*count, rise*count
    right = width*2+gap-.025
    rear = run+landing+.7-.025

    def post(label, x, floor, z, heavy=False, height=guard):
        marker = bpy.data.objects.new('Foot_'+label, None)
        bpy.context.collection.objects.link(marker)
        marker.location = point((x,floor,z))
        size = .026 if heavy else .014
        box('ForgedPost', (x,floor+height*.5,z), (size,height-.045,size), iron)
        box('SocketFoot', (x,floor+.022,z), (.045,.044,.065), iron, .003)
        for dz in [-.023,.023]:
            rod('FixingRivet', (x,floor+.043,z+dz), (x,floor+.049,z+dz), .004, steel)
        for y in ([.14,.72] if heavy else [.16]):
            box('SquareCollar', (x,floor+y,z), (size+.010,.026,size+.010), iron)
        if heavy:
            box('NewelCap', (x,floor+height-.025,z), (.048,.04,.052), wood, .006)

    for flight in ['A','B']:
        points = []
        for i in range(count):
            floor = rise*(i+1)+(half if flight=='B' else 0)
            z = run+landing-tread*(i+.5) if flight=='B' else tread*(i+.5)
            x = right if flight=='B' else .025
            post(flight+str(i),x,floor,z,i in [0,count-1])
            points.append((x,floor+guard-.025,z))
        # A round graspable timber cap, with a narrow continuous iron bearer.
        rod('Handrail'+flight,points[0],points[-1],.023,wood)
        rod('RailBearer'+flight,(points[0][0],points[0][1]-.035,points[0][2]),
            (points[-1][0],points[-1][1]-.035,points[-1][2]),.009,iron)
        # Close the landing's rear edge and connect each flight to it.
        end = points[0] if flight=='B' else points[-1]
        corner = (x,half+guard-.025,rear)
        rod('LandingReturn'+flight,end,corner,.023,wood)
        for j in range(1,4):
            t=j/3
            z=end[2]+(rear-end[2])*t
            floor=half
            height=end[1]+(corner[1]-end[1])*t-floor+.025
            post('Return'+flight+str(j),x,floor,z,j==3,height)
    for i in range(1,12):
        x=.025+(right-.025)*i/12
        post('Landing'+str(i),x,half,rear)
    rod('LandingHandrail',(.025,half+guard-.025,rear),(right,half+guard-.025,rear),.023,wood)
    rod('LandingBearer',(.025,half+.18,rear),(right,half+.18,rear),.009,iron)

    # Apply machining before batching: only three material draws per assembly.
    for obj in list(bpy.context.scene.objects):
        if obj.type!='MESH': continue
        bpy.ops.object.select_all(action='DESELECT')
        obj.select_set(True)
        bpy.context.view_layer.objects.active=obj
        bpy.ops.object.convert(target='MESH')
        bpy.ops.object.mode_set(mode='EDIT')
        bpy.ops.mesh.select_all(action='SELECT')
        bpy.ops.uv.smart_project(island_margin=.01)
        bpy.ops.object.mode_set(mode='OBJECT')
    for mat in [iron,wood,steel]:
        parts=[o for o in bpy.context.scene.objects if o.type=='MESH' and o.data.materials[0]==mat]
        bpy.ops.object.select_all(action='DESELECT')
        for obj in parts: obj.select_set(True)
        bpy.context.view_layer.objects.active=parts[0]
        bpy.ops.object.join()
        parts[0].name='Ironwork_'+mat.name
    bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/f'art/blender/{name}.blend'))
    bpy.ops.export_scene.gltf(filepath=str(ROOT/f'game/assets/props/{name}.glb'),
        export_format='GLB',export_apply=True,export_yup=True,export_animations=False)

build('stair_ironwork_public',1.2,.285,1.2)
build('stair_ironwork_service',1.05,.275,1.05)
