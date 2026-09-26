"""Blender-authored period shower and draped lavatory towel, metres.
Exports editable sources, shared shower/towel GLBs through the existing
bath-details contract. No interactions or gameplay authority live in this file.
"""
import bpy
import math
import json
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[3]
def p(v): return Vector((v[0],-v[2],v[1]))
def clear():
    bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
def material(name,color,metal=0,rough=.5):
    m=bpy.data.materials.get(name) or bpy.data.materials.new(name);m.use_nodes=True
    s=m.node_tree.nodes.get('Principled BSDF');s.inputs['Base Color'].default_value=(*color,1)
    s.inputs['Metallic'].default_value=metal;s.inputs['Roughness'].default_value=rough
    return m
def group(name,at=(0,0,0)):
    o=bpy.data.objects.new(name,None);bpy.context.collection.objects.link(o);o.location=p(at);return o
def finish(o,name,mat,parent=None):
    o.name=name;o.data.materials.append(mat)
    if o.type=='MESH':
        for f in o.data.polygons:f.use_smooth=True
    bpy.context.view_layer.update();w=o.matrix_world.copy();o.parent=parent;o.matrix_world=w
    return o
def pipe(name,points,r,mat,parent=None):
    c=bpy.data.curves.new(name,'CURVE');c.dimensions='3D';c.resolution_u=12;c.bevel_depth=r;c.bevel_resolution=3;c.use_fill_caps=True
    s=c.splines.new('BEZIER');s.bezier_points.add(len(points)-1)
    for b,v in zip(s.bezier_points,points):b.co=p(v);b.handle_left_type=b.handle_right_type='AUTO'
    o=bpy.data.objects.new(name,c);bpy.context.collection.objects.link(o);return finish(o,name,mat,parent)
def cyl(name,at,r,h,mat,axis=(0,1,0),parent=None):
    bpy.ops.mesh.primitive_cylinder_add(vertices=32,radius=r,depth=h,location=p(at));o=bpy.context.object
    o.rotation_mode='QUATERNION';o.rotation_quaternion=Vector((0,0,1)).rotation_difference(p(axis))
    mod=o.modifiers.new('Soft machined edge','BEVEL');mod.width=.0015;mod.segments=3
    return finish(o,name,mat,parent)
def mesh(name,verts,faces,mat,parent=None,solid=0):
    m=bpy.data.meshes.new(name);m.from_pydata([p(v) for v in verts],[],faces);m.update()
    o=bpy.data.objects.new(name,m);bpy.context.collection.objects.link(o);finish(o,name,mat,parent)
    if solid:
        mod=o.modifiers.new('Physical cloth thickness','SOLIDIFY');mod.thickness=solid
    return o
def apply():
    for o in list(bpy.context.scene.objects):
        if o.type not in {'MESH','CURVE'}:continue
        bpy.ops.object.select_all(action='DESELECT');o.select_set(True);bpy.context.view_layer.objects.active=o;bpy.ops.object.convert(target='MESH')
        bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT');bpy.ops.mesh.normals_make_consistent(inside=False);bpy.ops.uv.smart_project(island_margin=.01);bpy.ops.object.mode_set(mode='OBJECT')
def save(name):
    bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/f'art/blender/{name}.blend'))
    bpy.ops.export_scene.gltf(filepath=str(ROOT/f'game/assets/props/{name}.glb'),export_format='GLB',export_yup=True,export_apply=True)

clear()
nickel=material('nickel_plated',(.72,.71,.67),.82,.28)
enamel=material('enamel',(.83,.84,.80),0,.3)
duck=material('shower_duck',(.88,.85,.77),0,.85)
rubber=material('rubber_aged',(.026,.026,.022),0,.8)
fixed=group('ShowerCasting')
# Rounded square shell; connected inner floor, cove, rim and outer apron.
rings=[(.034,.018),(.25,.021),(.316,.035),(.335,.098),(.345,.123),(.361,.129),(.377,.116),(.374,.014),(.035,.006)]
verts=[];n=96
for r,y in rings:
    for i in range(n):
        a=math.tau*i/n;c=math.cos(a);s=math.sin(a)
        # The throat is round; the receptor corners have an 8 cm radius.
        power=1 if r<.04 else .25
        verts.append((r*math.copysign(abs(c)**power,c),y,r*math.copysign(abs(s)**power,s)))
faces=[]
for j in range(len(rings)):
    for i in range(n):faces.append((j*n+i,j*n+(i+1)%n,((j+1)%len(rings))*n+(i+1)%n,((j+1)%len(rings))*n+i))
mesh('CovedReceptor',verts,faces,enamel,fixed)
cyl('WasteGrate',(0,.020,0),.033,.005,nickel,parent=fixed)
for x in range(-2,3):
    for z in range(-2,3):
        if x*x+z*z<7:cyl('DrainPerforation',(x*.009,.023,z*.009),.0025,.001,rubber,parent=fixed)
for x,name in [(-.095,'HotValve'),(.095,'ColdValve')]:
    cyl('WallFlange',(x,.98,.354),.027,.012,nickel,(0,0,1),fixed)
    pipe('Inlet',[(x,.98,.36),(x,.98,.286)],.014,nickel,fixed)
    valve=group(name,(x,.98,.335))
    cyl('Spindle',(x,.98,.273),.009,.029,nickel,(0,0,1),valve)
    for axis in [(1,0,0),(0,1,0)]:cyl('CrossHandle',(x,.98,.253),.006,.070,nickel,axis,valve)
    cyl('IndexCap',(x,.98,.246),.010,.005,enamel,(0,0,1),valve)
pipe('Manifold',[(-.095,.98,.31),(0,.98,.31),(.095,.98,.31)],.012,nickel,fixed)
pipe('RiserAndSwanNeck',[(0,.98,.31),(0,1.72,.31),(0,1.90,.30),(0,1.925,.21),(0,1.88,.18)],.012,nickel,fixed)
for y in [1.18,1.65]:
    cyl('RiserClip',(0,y,.31),.016,.020,nickel,parent=fixed)
    pipe('ClipStandoff',[(0,y,.325),(0,y,.355)],.006,nickel,fixed)
    cyl('ClipWallPlate',(0,y,.355),.021,.008,nickel,(0,0,1),fixed)
# Bell-shaped rose and a perforated underside, physically joined to the arm.
bpy.ops.mesh.primitive_cone_add(vertices=64,radius1=.070,radius2=.017,depth=.043,location=p((0,1.851,.18)))
finish(bpy.context.object,'ShowerRose',nickel,fixed)
cyl('RoseFace',(0,1.829,.18),.066,.004,nickel,parent=fixed)
for ring,count in [(1,8),(2,16),(3,24)]:
    for i in range(count):
        a=math.tau*i/count;cyl('RoseJet',(math.cos(a)*ring*.018,1.826,.18+math.sin(a)*ring*.018),.0017,.001,rubber,parent=fixed)
pipe('RoundedCurtainRod',[(-.34,2.02,.35),(-.34,2.02,-.26),(-.28,2.02,-.32),(.28,2.02,-.32),(.34,2.02,-.26),(.34,2.02,.35)],.009,nickel,fixed)
for x in [-.34,.34]:
    cyl('RodWallFlange',(x,2.02,.35),.027,.010,nickel,(0,0,1),fixed)
    pipe('RodBrace',[(x,2.02,-.20),(x,2.19,.35)],.005,nickel,fixed)
    cyl('BraceWallPlate',(x,2.19,.35),.019,.009,nickel,(0,0,1),fixed)
def cloth(name,gathered):
    parent=group(name);verts=[];faces=[];nx=144;ny=24
    for j in range(ny+1):
        v=j/ny
        for i in range(nx+1):
            u=i/nx
            if gathered:
                x=.34+(.018+.025*v)*math.sin(u*math.pi*18)+.006*v*math.sin(u*19+v*4)
                z=.14+.18*u+.006*v*math.sin(u*23)
            else:
                length=u*1.96
                if length<.64:x=-.34;z=.32-length;normal=(1,0)
                elif length<1.32:x=-.34+length-.64;z=-.32;normal=(0,1)
                else:x=.34;z=-.32+length-1.32;normal=(-1,0)
                wave=(.018+.005*v)*math.sin(u*math.tau*18)+.003*math.sin(v*7+u*21)
                x+=normal[0]*wave;z+=normal[1]*wave
            y=1.975-1.89*v+.005*math.sin(u*39)*v
            verts.append((x,y,z))
    for j in range(ny):
        for i in range(nx):
            a=j*(nx+1)+i;faces.append((a,a+1,a+nx+2,a+nx+1))
    mesh('RubberizedDuck',verts,faces,duck,parent,.0012)
    # Separate eyelets follow the gathered/drawn top edge; cloth hangs into tray.
    for i in range(19):
        u=i/18
        if gathered: x=.34;z=.14+.18*u;along_x=False
        else:
            if i in [6,12]:continue  # leave the two curved elbows free
            length=u*1.96
            if length<.64:x=-.34;z=.32-length;along_x=False
            elif length<1.32:x=-.34+length-.64;z=-.32;along_x=True
            else:x=.34;z=-.32+length-1.32;along_x=False
        bpy.ops.mesh.primitive_torus_add(major_radius=.020,minor_radius=.0025,major_segments=20,minor_segments=8,location=p((x,2.015,z)))
        o=bpy.context.object
        if along_x:o.rotation_euler.y=math.pi/2
        else:o.rotation_euler.x=math.pi/2
        finish(o,'CurtainRing',nickel,parent)
        pipe('CurtainHook',[(x,1.995,z),(x,1.972,z)],.0015,nickel,parent)
    return parent
cloth('CurtainDrawn',False);cloth('CurtainGathered',True)
apply()
# Batch immutable meshes within each moving group by material.
for parent in [o for o in bpy.context.scene.objects if o.type=='EMPTY']:
    for mat in [nickel,enamel,duck,rubber]:
        parts=[o for o in parent.children if o.type=='MESH' and o.data.materials[0]==mat]
        if not parts:continue
        bpy.ops.object.select_all(action='DESELECT')
        for o in parts:o.select_set(True)
        bpy.context.view_layer.objects.active=parts[0];bpy.ops.object.join();bpy.context.object.name=parent.name+'_'+mat.name
save('bath_shower')

clear()
linen=material('linen',(.82,.80,.72),0,.9)
# Two sockets under the basin apron carry a rounded rail; nothing straps the base.
for x in [-.12,.12]:
    cyl('UnderApronSocket',(x,.673,-.165),.018,.015,nickel)
    pipe('RailBracket',[(x,.668,-.165),(x,.63,-.18),(x,.63,-.26)],.006,nickel)
pipe('TowelRail',[(-.135,.63,-.26),(0,.63,-.26),(.135,.63,-.26)],.007,nickel)
# Fold back over the rail in a continuous sheet, with rounded fold and soft hem.
verts=[];faces=[];nx=24;ny=32
for j in range(ny+1):
    t=j/ny
    if t<.45:y=.30+.33*t/.45;z=-.272
    elif t<.55:
        a=(t-.45)/.10*math.pi;y=.63+.012*math.sin(a);z=-.26-.012*math.cos(a)
    else:y=.63-.24*(t-.55)/.45;z=-.248
    for i in range(nx+1):
        u=i/nx;fold=math.sin(u*math.tau*4+.3)*.0035
        verts.append(((u-.5)*.215,y+.002*math.sin(u*17),z+fold))
for j in range(ny):
    for i in range(nx):
        a=j*(nx+1)+i;faces.append((a,a+1,a+nx+2,a+nx+1))
mesh('DrapedHandTowel',verts,faces,linen,solid=.001)
apply();save('bath_towel')
# Keep semantic supports and bounds in the existing bath-details contract;
# geometry is shared through one imported model rather than twelve JSON copies.
all_points=[]
for o in bpy.context.scene.objects:
    if o.type=='MESH':
        for vertex in o.data.vertices:
            v=o.matrix_world@vertex.co
            all_points.append([round(v.x,6),round(v.z,6),round(-v.y,6)])
path=ROOT/'game/data/orison_v2/bath_details.json';data=json.loads(path.read_text())
bounds=[[min(v[i] for v in all_points) for i in range(3)],[max(v[i] for v in all_points) for i in range(3)]]
for record in data['props']:
    if record['kind']=='hand_towel':
        record.pop('surfaces',None)
        record['model']='res://assets/props/bath_towel.glb'
        record['bounds']=bounds
path.write_text(json.dumps(data,separators=(',',':'))+'\n')
