"""Blender-authored V2 stair rails, metres; runtime retains collision authority.

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


def stringer(name, x, width, tread, rise, count, offset, reverse, mat):
    """Closed plate with tread-bearing notches and a continuous lower edge."""
    bpy.ops.object.select_all(action='DESELECT')
    run = tread*count
    profile = []
    for i in range(count):
        profile.extend([(i*tread, i*rise+.012), ((i+1)*tread, i*rise+.012)])
    profile.extend([(run, count*rise-.30), (0, -.30)])
    def station(z, y, side):
        return point((x+side, offset+y, run+width-z if reverse else z))
    vertices = [station(z,y,side) for side in [-.022,.022] for z,y in profile]
    n = len(profile)
    faces = [tuple(reversed(range(n))), tuple(range(n,2*n))]
    faces += [(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    obj.data.materials.append(mat)
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.mesh.normals_make_consistent(inside=False)
    bpy.ops.object.mode_set(mode='OBJECT')
    obj.select_set(False)
    edge = obj.modifiers.new('Plate edges', 'BEVEL')
    edge.width = .0015
    edge.segments = 2
    obj.modifiers.new('Plate normals', 'WEIGHTED_NORMAL')
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

    # Structure remains a distinct mesh so clearance tests inspect real vertices.
    structure = []
    for flight in ['A','B']:
        x0 = width+gap if flight=='B' else 0
        offset = half if flight=='B' else 0
        for side in [.05,width-.05]:
            structure.append(stringer('NotchedStringer',x0+side,width,tread,rise,
                                      count,offset,flight=='B',iron))
        for i in range(count):
            y = offset+i*rise
            z = run+landing-tread*(i+.5) if flight=='B' else tread*(i+.5)
            structure.append(box('TreadBearer',(x0+width*.5,y-.020,z),
                                 (width-.06,.055,.065),iron,.002))
            for side in [.05,width-.05]:
                marker = bpy.data.objects.new('Bearing_'+flight+str(i)+'_'+str(side),None)
                bpy.context.collection.objects.link(marker)
                marker.location = point((x0+side,y-.02,z))
    for z in [run+.07,rear-.045]:
        structure.append(box('LandingBeam',(width+gap*.5,half-.26,z),
                             (width*2+gap-.02,.15,.10),iron,.003))

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

    # Inner flights remain separate. The return flight stops at its first
    # tread post: extending it onto the landing pinches the player's U-turn.
    for flight in ['A','B']:
        x = width+gap+.025 if flight=='B' else width-.025
        points = []
        for i in range(count):
            floor = rise*(i+1)+(half if flight=='B' else 0)
            z = run+landing-tread*(i+.5) if flight=='B' else tread*(i+.5)
            post('Inner'+flight+str(i),x,floor,z,i in [0,count-1])
            points.append((x,floor+guard-.025,z))
        rod('InnerHandrail'+flight,points[0],points[-1],.023,wood)
        rod('InnerBearer'+flight,(x,points[0][1]-.035,points[0][2]),
            (x,points[-1][1]-.035,points[-1][2]),.009,iron)
        if flight=='A':
            post('InnerTerminal'+flight,x,half,run,True)
            rod('InnerTerminalRail'+flight,points[-1],(x,half+guard-.025,run),.023,wood)

    # Apply machining before batching: three rail materials and one structure.
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
    groups = [(structure,'StairStructure')]
    for mat in [iron,wood,steel]:
        groups.append(([o for o in bpy.context.scene.objects if o.type=='MESH'
                       and o.data.materials[0]==mat and o not in structure], 'Ironwork_'+mat.name))
    for parts, label in groups:
        bpy.ops.object.select_all(action='DESELECT')
        for obj in parts: obj.select_set(True)
        bpy.context.view_layer.objects.active=parts[0]
        bpy.ops.object.join()
        parts[0].name=label
    bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/f'art/blender/{name}.blend'))
    bpy.ops.export_scene.gltf(filepath=str(ROOT/f'game/assets/props/{name}.glb'),
        export_format='GLB',export_apply=True,export_yup=True,export_animations=False)

build('stair_ironwork_public',1.2,.285,1.2)
build('stair_ironwork_service',1.05,.275,1.05)
