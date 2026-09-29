"""Reproducible reading-room oak furniture library; Godot metres, no lettering."""
from pathlib import Path
import math, random
import bpy, bmesh
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[3]
bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)
COLORS={'Oak':(.35,.23,.12),'Iron':(.15,.14,.13),'Paper':(.69,.64,.51),
        'RedCloth':(.25,.095,.07),'GreenCloth':(.13,.19,.11),'BlueCloth':(.11,.14,.20)}
mats={}
for name,c in COLORS.items():
    mat=bpy.data.materials.new(name); mat.diffuse_color=(*c,1); mat.use_nodes=True
    mat.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value=(*c,1)
    mat.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value=.72
    mats[name]=mat

def point(v): return Vector((v[0],-v[2],v[1]))
def finish(obj,name,role,owner,bevel=.002):
    obj.name=name; obj.data.materials.append(mats[role]); obj.parent=owner
    if bevel:
        m=obj.modifiers.new('Worked edge','BEVEL');m.width=bevel;m.segments=2
        bpy.context.view_layer.objects.active=obj;bpy.ops.object.modifier_apply(modifier=m.name)
    return obj

def box(name,at,size,owner,role='Oak',bevel=.002):
    bpy.ops.mesh.primitive_cube_add(size=1,location=point(at));obj=bpy.context.object
    obj.dimensions=(size[0],size[2],size[1]);bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    return finish(obj,name,role,owner,bevel)

def beam(name,a,b,width,depth,owner,role='Oak'):
    a,b=point(a),point(b);bpy.ops.mesh.primitive_cube_add(size=1,location=(a+b)*.5);obj=bpy.context.object
    obj.dimensions=(width,depth,(b-a).length);obj.rotation_euler=(b-a).to_track_quat('Z','Y').to_euler()
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    return finish(obj,name,role,owner)

def root(name):
    obj=bpy.data.objects.new(name,None);bpy.context.collection.objects.link(obj);return obj

def turned_leg(x,z,owner):
    rings=[(0,.025),(.045,.031),(.075,.025),(.22,.023),(.28,.032),(.32,.035),(.37,.028),(.53,.031),(.59,.037),(.724,.037)]
    vertices=[];faces=[];n=16
    for y,r in rings:
        vertices += [point((x+math.cos(i*math.tau/n)*r,y,z+math.sin(i*math.tau/n)*r)) for i in range(n)]
    for j in range(len(rings)-1):
        for i in range(n):
            k=j*n+i;q=j*n+(i+1)%n;faces.append((k,q,q+n,k+n))
    faces.extend([tuple(reversed(range(n))),tuple((len(rings)-1)*n+i for i in range(n))])
    mesh=bpy.data.meshes.new('Turned oak');mesh.from_pydata(vertices,[],faces);mesh.update()
    obj=bpy.data.objects.new('TurnedLeg',mesh);bpy.context.collection.objects.link(obj);finish(obj,'TurnedLeg','Oak',owner,0)

table=root('ReadingTable')
# Five long boards run with the grain; breadboard ends restrain their ends.
for i in range(5): box('TopBoard',(0,.742,-.44+i*.22),(2.27,.036,.218),table,bevel=.004)
for x in [-1.17,1.17]: box('BreadboardEnd',(x,.742,0),(.068,.036,1.10),table,bevel=.003)
for z in [-.45,.45]: box('LongApron',(0,.665,z),(2.12,.118,.035),table)
for x in [-1.04,1.04]:
    box('EndApron',(x,.665,0),(.035,.118,.87),table)
    for z in [-.44,.44]: turned_leg(x,z,table)
    box('FootStretcher',(x,.24,0),(.035,.043,.88),table)
box('LongStretcher',(0,.24,0),(2.10,.050,.037),table)
for x in [-1.04,1.04]:
    for z in [-.468,.468]:
        box('TenonPeg',(x,.668,z),(.012,.015,.004),table,role='Iron',bevel=.001)

chair=root('ReadingChair')
# A softly scooped solid seat, not a flat card or hidden box envelope.
n=8;verts=[];faces=[]
for layer in [0,1]:
    for j in range(n+1):
        for i in range(n+1):
            x=-.225+i*.45/n;z=-.225+j*.45/n
            scoop=.012*max(0,1-(x/.225)**2)*max(0,1-(z/.225)**2)
            verts.append(point((x,.45-scoop-layer*.025,z)))
q=(n+1)**2
for j in range(n):
    for i in range(n):
        k=j*(n+1)+i;faces.append((k,k+1,k+n+2,k+n+1));faces.append((q+k+n+1,q+k+n+2,q+k+1,q+k))
edge=list(range(n+1))+[j*(n+1)+n for j in range(1,n+1)]+[n*(n+1)+i for i in range(n-1,-1,-1)]+[j*(n+1) for j in range(n-1,0,-1)]
for i,k in enumerate(edge):b=edge[(i+1)%len(edge)];faces.append((k,q+k,q+b,b))
mesh=bpy.data.meshes.new('Scooped seat');mesh.from_pydata(verts,[],faces);mesh.update()
obj=bpy.data.objects.new('Seat',mesh);bpy.context.collection.objects.link(obj);finish(obj,'Seat','Oak',chair,.002)
for x in [-.177,.177]:
    beam('FrontLeg',(x*1.10,0,-.19),(x,.428,-.17),.035,.035,chair)
    beam('BackPost',(x*1.10,0,.21),(x,.91,.25),.035,.036,chair)
    beam('SideStretcher',(x,.19,-.18),(x,.19,.22),.023,.025,chair)
    box('SeatRail',(x,.397,0),(.03,.055,.37),chair)
for z in [-.175,.182]: box('SeatApron',(0,.397,z),(.35,.055,.03),chair)
box('FrontStretcher',(0,.19,-.18),(.36,.023,.025),chair)
box('CrestRail',(0,.90,.25),(.40,.065,.035),chair,bevel=.007)
box('BackRail',(0,.52,.231),(.34,.042,.027),chair)
for x in [-.12,-.04,.04,.12]: beam('BackSplat',(x,.532,.232),(x,.875,.25),.035,.012,chair)

case=root('Bookcase')
for x in [-.77,.77]: box('CaseSide',(x,.82,0),(.04,1.64,.32),case)
box('CaseBack',(0,.84,.151),(1.50,1.59,.018),case,bevel=.001)
box('Cornice',(0,1.66,0),(1.63,.045,.36),case,bevel=.005)
box('Plinth',(0,.05,0),(1.61,.10,.35),case,bevel=.004)
for y in [.135,.50,.865,1.23,1.61]: box('Shelf',(0,y,0),(1.50,.027,.32),case)
rng=random.Random(731)
for tier,base in enumerate([.149,.514,.879,1.244]):
    x=-.70
    while x<.57:
        width=rng.uniform(.032,.061);height=rng.uniform(.225,.32);depth=rng.uniform(.18,.245)
        cover=['RedCloth','GreenCloth','BlueCloth'][rng.randrange(3)]
        z=.125-depth*.5
        box('Pages',(x+width*.5,base+height*.5,z),(width-.006,height-.009,depth-.007),case,'Paper',0)
        for side in [-1,1]:box('ClothCover',(x+width*.5+side*(width*.5-.0015),base+height*.5,z),(.003,height,depth),case,cover,0)
        box('ClothSpine',(x+width*.5,base+height*.5,z-depth*.5+.0015),(width,height,.003),case,cover,0)
        x+=width+.005
# All faces carry metre coordinates and all exported instances have unit scale.
for obj in list(bpy.context.scene.objects):
    if obj.type!='MESH':continue
    bm=bmesh.new();bm.from_mesh(obj.data);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(obj.data);bm.free()
    uv=obj.data.uv_layers.new(name='UVMap')
    for poly in obj.data.polygons:
        axis=max(range(3),key=lambda i:abs(poly.normal[i]));axes=((1,2),(0,2),(0,1))[axis]
        for loop in poly.loop_indices:
            p=obj.matrix_world@obj.data.vertices[obj.data.loops[loop].vertex_index].co
            uv.data[loop].uv=(p[axes[0]],p[axes[1]])
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'art/blender/reading_furniture.blend'))
for owner in [table,chair,case]:
    for role,mat in mats.items():
        parts=[o for o in owner.children if o.type=='MESH' and o.data.materials[0]==mat]
        if not parts:continue
        bpy.ops.object.select_all(action='DESELECT')
        for o in parts:o.select_set(True)
        bpy.context.view_layer.objects.active=parts[0];bpy.ops.object.join()
        obj=bpy.context.object;obj.name=owner.name+'_'+role
        bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
bpy.ops.object.select_all(action='SELECT')
bpy.ops.export_scene.gltf(filepath=str(ROOT/'game/assets/props/reading_furniture.glb'),export_format='GLB',export_yup=True,export_apply=True)
