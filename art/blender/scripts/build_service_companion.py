"""Native companion candidate extending the installed, editable service set.

Not a production cutover. Existing printer, controls and materials are loaded
from their native source, never reverse-engineered or edited in glTF. Repeated
keycaps export once, with mounting sockets for a runtime MultiMesh.
Blender --background --python-exit-code 1 --python THIS -- --out tmp/companion
"""
from pathlib import Path
import argparse, collections, hashlib, json, math, sys
import bpy, bmesh
from mathutils import Matrix, Vector

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(Path(__file__).parent))
from fabrication_native_batch import material, partition, export

parser = argparse.ArgumentParser()
parser.add_argument('--out', required=True)
args = parser.parse_args(sys.argv[sys.argv.index('--') + 1:])
OUT = (ROOT / args.out).resolve()
assert OUT.is_relative_to((ROOT / 'tmp').resolve()), 'Candidate remains outside production'
for directory in ['art/blender', 'game/assets/props', 'review']:
    (OUT / directory).mkdir(parents=True, exist_ok=True)
SOURCE = ROOT / 'art/blender/service_radiophone_v2.blend'
bpy.ops.wm.open_mainfile(filepath=str(SOURCE))
bpy.context.preferences.filepaths.save_version = 0
stocks = bpy.data.collections['EditableIndividualStock']
exports = bpy.data.collections['ServiceRadiophoneV2']
review = bpy.data.collections['ReviewOnlyLetteringAndStage']
catalog = json.loads((ROOT / 'game/data/runtime_material_sets.json').read_text())['materials']
specs = {
    'CompanionSteel': dict(catalog_key='fire_hardware_steel', tint=[.34, .39, .37, 1], normal=.28, roughness=.75, pigment=.5),
    'CompanionBrass': dict(catalog_key='brass_dull', tint=[.86, .82, .67, 1], normal=.25, roughness=.85, pigment=.6),
    'CompanionKeys': dict(catalog_key='bakelite_black', tint=[.58, .67, .63, 1], normal=.22, roughness=.85, pigment=.4)
}
groups = collections.defaultdict(list)
pivots = {}
checks = []
original_draws=[obj for obj in exports.objects if obj.type=='MESH']

def coords(point): return Vector((point[0], -point[2], point[1]))

def stock(name, vertices, faces, surface='CompanionSteel', group='CompanionFixed'):
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata([coords(v) for v in vertices], [], faces)
    mesh.update()
    bm = bmesh.new(); bm.from_mesh(mesh)
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    assert all(edge.is_manifold for edge in bm.edges), (name, 'open stock')
    volume = bm.calc_volume(signed=True)
    assert volume > 1e-13, (name, volume)
    bm.to_mesh(mesh); bm.free()
    obj = bpy.data.objects.new('Stock__' + name, mesh); stocks.objects.link(obj)
    groups[(group, surface)].append(obj)
    checks.append(dict(name=name, volume_m3=volume))
    return obj

def box(name, center, size, surface='CompanionSteel', group='CompanionFixed'):
    low = Vector(center) - Vector(size) / 2; high = Vector(center) + Vector(size) / 2
    return stock(name, [(x,y,z) for z in [low.z,high.z] for y in [low.y,high.y] for x in [low.x,high.x]],
                 [(0,2,3,1),(4,5,7,6),(0,1,5,4),(2,6,7,3),(0,4,6,2),(1,3,7,5)],surface,group)

def ring(name, at, outer, inner, depth, surface='CompanionBrass', group='CompanionFixed', axis='y', count=24):
    assert 0 < inner < outer
    vertices=[]
    for radius, height in [(outer,-depth/2),(outer,depth/2),(inner,depth/2),(inner,-depth/2)]:
        for i in range(count):
            a=i*math.tau/count
            point=[radius*math.cos(a),radius*math.sin(a),height]
            if axis=='y': point=[point[0],height,point[1]]
            if axis=='x': point=[height,point[0],point[1]]
            vertices.append(tuple(point[j]+at[j] for j in range(3)))
    faces=[(k*count+i,k*count+(i+1)%count,((k+1)%4)*count+(i+1)%count,((k+1)%4)*count+i)
           for k in range(4) for i in range(count)]
    return stock(name,vertices,faces,surface,group)

def rod(name, a, b, radius=.002, surface='CompanionSteel', group='CompanionFixed', count=10):
    a,b=Vector(a),Vector(b);direction=(b-a).normalized()
    u=direction.cross(Vector((0,1,0)))
    if u.length<.01:u=direction.cross(Vector((1,0,0)))
    u.normalize();v=direction.cross(u).normalized()
    vertices=[tuple(point+radius*(u*math.cos(i*math.tau/count)+v*math.sin(i*math.tau/count)))
              for point in [a,b] for i in range(count)]
    faces=[tuple(reversed(range(count))),tuple(range(count,2*count))]
    faces += [(i,(i+1)%count,(i+1)%count+count,i+count) for i in range(count)]
    return stock(name,vertices,faces,surface,group)

def pivot(name, point):
    node=bpy.data.objects.new(name,None);exports.objects.link(node);node.location=coords(point)
    pivots[name]=node
    return node

# A cradled chassis: two through-bolted straps support the motor bearers. The
# blades live within two continuous rolled guard hoops, away from the copy bed.
for side in [-1,1]:
    x=side*.172
    for y in [-.064,.069]:
        box('Cradle strap', (side*.104,y,-.008),(.008,.014,.066))
        rod('Bearer tie',(side*.105,y,-.020),(x,.083,-.030),.003)
        ring('Chassis through-bolt washer',(side*.109,y,-.008),.006,.0025,.002,axis='x')
        rod('Chassis bolt',(side*.101,y,-.008),(side*.114,y,-.008),.0023)
    ring('Rolled guard', (x,.102,-.030),.072,.069,.012,'CompanionSteel')
    for angle in [0,math.pi/2,math.pi,math.pi*1.5]:
        endpoint=(x+.069*math.cos(angle),.102,-.030+.069*math.sin(angle))
        rod('Guard stay',(x,.082,-.030),endpoint,.0018)
    ring('Bored motor barrel',(x,.073,-.030),.015,.008,.034)
    ring('Upper journal',(x,.093,-.030),.010,.0035,.006)
    rod('Rotor shaft',(x,.064,-.030),(x,.112,-.030),.003)
    rotor='LiftRotor' + ('Port' if side<0 else 'Starboard')
    pivot(rotor,(x,.108,-.030))
    ring('Rotor hub',(x,.108,-.030),.009,.0035,.005,group=rotor)
    for angle in [0,math.pi]:
        # Closed, pitched, tapered wooden-airfoil substitute in stamped metal.
        # Root seats on the hub; the guard's radial clearance is >=6mm.
        points=[]
        for height in [-.0007,.0007]:
            for radius,width,pitch in [(.007,-.004,-.002),(.061,-.006,-.002),(.064,.005,.002),(.007,.004,.002)]:
                points.append((x+radius*math.cos(angle)-width*math.sin(angle),.108+pitch+height,
                               -.030+radius*math.sin(angle)+width*math.cos(angle)))
        stock('Pitched rotor blade',points,[(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)],group=rotor)

# Keyboard closes upright against the lower chassis. Its inner face carries
# the keys; a +90deg Godot X rotation presents them upward. Alternating bored
# knuckles share a real pin. Stop shoulders and folding stays carry open load.
hinge=(0,-.101,.110)
keyboard=pivot('CompanionKeyboard',hinge)
box('Keyboard tray', (0,-.057,.110),(.198,.088,.004),'CompanionSteel','CompanionKeyboard')
for x in [-.100,.100]:
    box('Returned tray edge',(x,-.057,.108),(.003,.091,.010),'CompanionBrass','CompanionKeyboard')
box('Returned tray lip',(0,-.012,.108),(.198,.003,.010),'CompanionBrass','CompanionKeyboard')
for i in range(9):
    x=-.084+i*.021
    group='CompanionFixed' if i%2==0 else 'CompanionKeyboard'
    ring('Interleaved hinge knuckle',(x,-.101,.110),.0045,.0021,.018,group=group,axis='x',count=16)
    box('Hinge leaf',(x,-.105 if i%2==0 else -.096,.112),(.018,.010,.0015),'CompanionBrass',group)
rod('Continuous hinge pin',(-.098,-.101,.110),(.098,-.101,.110),.0019,'CompanionSteel')
for x in [-.094,.094]:
    # Actual bearers join the projecting hinge to the lower chassis return.
    box('Hinge bearer',(x,-.1065,.076),(.010,.007,.076))
    box('Open angle stop',(x,-.1065,.117),(.010,.007,.008))
    ring('Stay pivot washer',(x,-.084,.042),.004,.0016,.002,axis='x')
    # Two separately pivoted links: runtime closure solves their elbow position.
    for label in ['Upper','Lower']:
        name=('Port' if x<0 else 'Starboard')+'KeyboardStay'+label
        pivot(name,(x,-.084,.042))
        rod(name,(x,-.080,.042),(x,-.038,.042),.0014,group=name)
        for y in [-.084,-.034]:
            ring('Stay eye',(x,y,.042),.0035,.0015,.0025,group=name,axis='x',count=12)
latch=pivot('CompanionKeyboardLatch',(.108,-.096,.114))
box('Latch supporting ear',(.108,-.096,.080),(.006,.009,.072))
ring('Latch bearing',(.108,-.096,.114),.004,.0015,.004,group='CompanionFixed',axis='z')
box('Latch spring',(.108,-.089,.117),(.004,.018,.002),'CompanionBrass','CompanionKeyboardLatch')
box('Latch hook',(.104,-.081,.116),(.013,.004,.004),'CompanionBrass','CompanionKeyboardLatch')
box('Latch keeper',(.100,-.081,.112),(.006,.006,.004),'CompanionSteel','CompanionKeyboard')

# One key mesh, 43 socket transforms. Source review duplicates share its mesh;
# production uses a single MultiMesh and updates only pressed key transforms.
key_home=Vector((-.079,-.029,.104))
key=box('Reusable phenolic keycap',key_home,(.013,.011,.004),'CompanionKeys','CompanionKeyBlank')
sockets=[]
rows=['QWERTYUIOP','ASDFGHJKL;', 'ZXCVBNM,./','1234567890']
for row,letters in enumerate(rows):
    for column,letter in enumerate(letters):
        point=key_home+Vector((column*.0175,-row*.0165,0))
        node=pivot('KeySocket%02d'%(row*10+column),point)
        node['character']=letter
        sockets.append(dict(name=node.name,character=letter,point=list(point),scale=[1,1,1]))
for index,letter,x,width in [(40,'SPACE',0,.090),(41,'ENTER',.079,.023),(42,'BACKSPACE',-.079,.028)]:
    point=(x,-.092,.104);node=pivot('KeySocket%02d'%index,point)
    node['character']=letter
    sockets.append(dict(name=node.name,character=letter,point=list(point),scale=[width/.013,.010/.011,1]))

for (group,surface),objects in groups.items():
    spec=specs[surface];mat=material(ROOT,surface,spec,catalog)
    for obj in objects:obj.data.materials.append(mat)
    obj=partition(exports,group+'__'+surface,objects,spec,mat,Matrix.Identity(4),catalog)
    if group in pivots:
        parent=pivots[group];obj.data.transform(Matrix.Translation(-parent.location));obj.parent=parent;obj.location=(0,0,0)
    if group=='CompanionKeyBlank':
        obj.data.transform(Matrix.Translation(-coords(key_home)))
        obj.location=coords(key_home)
        key_template=obj
bpy.context.view_layer.update()
for record in sockets:
    node=pivots[record['name']];world=node.matrix_world.copy();node.parent=keyboard;node.matrix_world=world
for name in ['PortKeyboardStayUpper','PortKeyboardStayLower','StarboardKeyboardStayUpper','StarboardKeyboardStayLower']:
    assert name in pivots
def pose_keyboard(opened):
    keyboard.rotation_euler.x=math.pi/2 if opened else 0
    latch.rotation_euler.z=-.65 if opened else 0
    bpy.context.view_layer.update()
    for x,label in [(-.094,'Port'),(.094,'Starboard')]:
        a=coords((x,-.084,.042));attachment=keyboard.matrix_world@coords((x,.016,-.006))
        delta=attachment-a;distance=delta.length
        assert distance<.100,distance
        perpendicular=Vector((0,-delta.z,delta.y)).normalized()
        elbow=(a+attachment)*.5+perpendicular*math.sqrt(.050**2-distance**2*.25)
        for suffix,start,end in [('Upper',a,elbow),('Lower',elbow,attachment)]:
            link=pivots[label+'KeyboardStay'+suffix];link.location=start
            link.rotation_euler=(end-start).to_track_quat('Z','Y').to_euler()
pose_keyboard(False)
fronts=[]
for draw in original_draws:
    for vertex in draw.data.vertices:
        point=draw.matrix_world@vertex.co
        if abs(point.x)<.099 and -.101<point.z<-.012:
            fronts.append(-point.y)
assert fronts
printer_front=max(fronts)
key_inner_front=key_home.z-.002
assert key_inner_front-printer_front>.005,('keyboard/printer overlap',printer_front,key_inner_front)
# Check the same independent original printer bound throughout deployment.
# This is a native clearance diagnostic, not a gameplay environment sweep.
deployment_gaps=[]
for sample in range(91):
    angle=sample*math.pi/180
    fronts=[]
    for record in sockets:
        x,y,z=record['point'];sx,sy,sz=record['scale']
        for yy in [y-.0055*sy,y+.0055*sy]:
            for zz in [z-.002*sz,z+.002*sz]:
                fronts.append(hinge[2]+math.sin(angle)*(yy-hinge[1])+math.cos(angle)*(zz-hinge[2]))
    gap=min(fronts)-printer_front;deployment_gaps.append(gap)
assert min(deployment_gaps)>.005,('deployment/printer overlap',min(deployment_gaps))
stocks.hide_render=True;stocks.hide_viewport=True
proof=export(OUT,'service_companion_v2',exports,material_names_only=True,staged_output=True)
assert proof['triangles']<50000,proof
assert sum(obj.type=='MESH' for obj in exports.objects)<64
metadata=dict(evidence_class='INERT',asset='res://assets/props/service_companion_v2.glb',
    source_sha256=hashlib.sha256(SOURCE.read_bytes()).hexdigest(),
    export=proof,finishes=specs,stocks=checks,keys=sockets,keyboard_hinge=list(hinge),
    keyboard_open_degrees=90,rotor_radius_m=.064,guard_inner_radius_m=.069,
    closed_keyboard_printer_gap_m=key_inner_front-printer_front,
    deployment_samples=91,minimum_deployment_printer_gap_m=min(deployment_gaps),
    limitations=['Candidate only; no production cutover','Sustained flight is fictional, not a historical claim',
                 'Runtime key MultiMesh, stay linkage, latch and clearance not yet qualified'])
(OUT/'review/construction.json').write_text(json.dumps(metadata,indent=2)+'\n',newline='\n')

# Review instances are not exported. No letters baked into generated textures.
key_template.hide_render=True
for record in sockets:
    draw=bpy.data.objects.new('ReviewKey'+record['character'],key_template.data);review.objects.link(draw)
    draw.parent=pivots[record['name']];draw.location=(0,0,0)
    scale=record['scale'];draw.scale=(scale[0],scale[2],scale[1])
font=bpy.data.fonts.load(str(ROOT/'game/assets/fonts/courier_prime/CourierPrime-Regular.ttf'))
def review_text(body,point,size,parent=None,key=False):
    curve=bpy.data.curves.new('Review lettering','FONT');curve.body=body;curve.size=size;curve.font=font
    obj=bpy.data.objects.new('Review lettering',curve);review.objects.link(obj);obj.location=coords(point)
    obj.rotation_euler=(-math.pi/2 if key else math.pi/2,0,0)
    material_name='Review key ink' if key else 'Review paper ink'
    mat=bpy.data.materials.get(material_name)
    if mat is None:
        mat=bpy.data.materials.new(material_name);mat.use_nodes=True
        mat.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value=(.82,.77,.60,1) if key else (.025,.018,.009,1)
    curve.materials.append(mat)
    if parent:
        bpy.context.view_layer.update();world=obj.matrix_world.copy();obj.parent=parent;obj.matrix_world=world
    return obj
review_text('SERVICE WIRE / COMPANION\n\nConnection established.\n\nI shall accompany you.\n\nThe line remains open.',(-.062,.067,.0529),.0065)
for record in sockets:
    # Native review lettering only; runtime labels must remain Label3D.
    x,y,z=record['point'];body=record['character']
    size=.0028 if len(body)>1 else .005
    review_text(body,(x-len(body)*size*.3,y+.0015,.1015),size,keyboard,True)
scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=24
scene.render.threads_mode='FIXED';scene.render.threads=6
scene.render.resolution_x=1200;scene.render.resolution_y=1000;scene.render.resolution_percentage=100
scene.world=bpy.data.worlds.new('Companion review');scene.world.use_nodes=True
scene.world.node_tree.nodes['Background'].inputs[0].default_value=(.16,.19,.23,1)
scene.world.node_tree.nodes['Background'].inputs[1].default_value=.5
def aim(obj,at):obj.rotation_euler=(coords(at)-obj.location).to_track_quat('-Z','Y').to_euler()
for name,at,energy,size in [('Key',(-.4,.5,.6),32,.4),('Rim',(.4,.2,-.4),22,.3),('Fill',(.3,-.2,.4),12,.3)]:
    data=bpy.data.lights.new(name,'AREA');data.energy=energy;data.shape='DISK';data.size=size
    obj=bpy.data.objects.new(name,data);review.objects.link(obj);obj.location=coords(at);aim(obj,(0,0,0))
camera=bpy.data.cameras.new('CompanionCamera');eye=bpy.data.objects.new('CompanionCamera',camera);review.objects.link(eye)
camera.type='ORTHO';camera.ortho_scale=.57;scene.camera=eye
for pose in ['travel','typing','rear']:
    pose_keyboard(pose=='typing')
    eye.location=coords((.36,.29,.65) if pose!='rear' else (-.35,.2,-.65));aim(eye,(0,-.01,0))
    scene.render.filepath=str(OUT/'review'/f'{pose}.png');bpy.ops.render.render(write_still=True)
# Keep review instances, cameras and the complete keyboard in the editable file.
# The exported collection stays separate from review-only lettering/instances.
pose_keyboard(False)
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'art/blender/service_companion_v2.blend'))
images=[]
for image in bpy.data.images:
    if image.source=='FILE':
        resolved=Path(bpy.path.abspath(image.filepath))
        assert resolved.is_file(),('missing native texture',image.name,str(resolved))
        images.append(dict(name=image.name,path=image.filepath))
(OUT/'review/native_images.json').write_text(json.dumps(dict(evidence_class='INERT',images=images),indent=2)+'\n',newline='\n')
print('COMPANION NATIVE CANDIDATE',proof['triangles'],'triangles',len(checks),'closed additions',len(sockets),'key sockets')
