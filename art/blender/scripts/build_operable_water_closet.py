"""Editable hollow low-cistern closet with articulated seat, cover and ball-cock.
Run in Blender; runtime ownership remains in orison_v2_water_closet.gd.
"""
import bpy
import math
import json
import sys
import os
from pathlib import Path
from mathutils import Vector
ROOT=Path(os.environ.get("ORISON_REPO_ROOT",str(Path(__file__).resolve().parents[3])))
OUT=Path(os.environ.get("ORISON_OUTPUT_ROOT",str(ROOT)))
import sys
sys.path.insert(0, str(ROOT/"art/blender/scripts"))
from repair_surface_uvs import repair_scene
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
    (OUT/"art/blender").mkdir(parents=True,exist_ok=True)
    (OUT/"game/assets/props").mkdir(parents=True,exist_ok=True)
    repair_scene()
    bpy.ops.wm.save_as_mainfile(filepath=str(OUT/f'art/blender/{name}.blend'))
    repair_scene()
    bpy.ops.export_scene.gltf(filepath=str(OUT/f'game/assets/props/{name}.glb'),export_format='GLB',export_yup=True,export_apply=True)

# A hollow wash-down closet and low cistern, retaining the existing flush pivot.
clear()
nickel=material("nickel_plated",(.72,.71,.67),.82,.28)
brass=material("brass",(.55,.46,.26),.85,.3)
rubber=material("rubber_aged",(.026,.026,.022),0,.8)
glaze=material('porcelain_fixture',(.88,.87,.82),0,.22)
wood=material('wood_dark',(.075,.048,.026),0,.32)
fixed=group('WaterClosetCasting')
def oval_shell(name,rings,mat,parent=fixed):
    verts=[];faces=[];n=96
    for rx,rz,y,z in rings:
        for i in range(n):
            a=math.tau*i/n;verts.append((rx*math.cos(a),y,z+rz*math.sin(a)))
    for j in range(len(rings)):
        for i in range(n):faces.append((j*n+i,j*n+(i+1)%n,((j+1)%len(rings))*n+(i+1)%n,((j+1)%len(rings))*n+i))
    return mesh(name,verts,faces,mat,parent)
def rounded_box(name,at,size,mat,parent=fixed,bevel=.018):
    bpy.ops.mesh.primitive_cube_add(size=1,location=p(at));o=bpy.context.object;o.scale=(size[0],size[2],size[1])
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    m=o.modifiers.new('Cast radiused corners','BEVEL');m.width=bevel;m.segments=5
    o.modifiers.new('Weighted casting normals','WEIGHTED_NORMAL')
    return finish(o,name,mat,parent)
oval_shell('HollowWashDownBowl',[(.04,.045,.21,-.06),(.08,.09,.215,-.085),
    (.12,.17,.29,-.11),(.154,.215,.38,-.13),(.17,.238,.405,-.13),
    (.195,.265,.407,-.13),(.202,.267,.389,-.13),(.185,.24,.30,-.12),
    (.135,.19,.20,-.08),(.05,.06,.18,-.06)],glaze)
oval_shell('ClosetPedestal',[(.001,.001,.009,-.075),(.135,.205,.009,-.075),
    (.14,.21,.025,-.075),(.12,.18,.055,-.075),(.095,.135,.24,-.075),
    (.001,.001,.24,-.075)],glaze)
seat=group('SeatHinge',(0,.437,.105))
oval_shell('PolishedWoodSeat',[(.155,.214,.412,-.13),(.198,.262,.412,-.13),
    (.205,.269,.420,-.13),(.202,.266,.432,-.13),(.193,.256,.437,-.13),
    (.15,.207,.432,-.13)],wood,seat)
# Continuous outer wall, rim, inner wall and floor, with 16 mm porcelain stock.
rings=[(.2115,.094,.505,.020),(.2275,.11,.52,.028),(.2275,.11,.805,.028),
       (.2115,.094,.805,.012),(.2115,.094,.526,.012),(.002,.002,.526,.001),(.002,.002,.505,.001)]
verts=[];n=64
for hx,hz,y,r in rings:
    for i in range(n):
        a=math.tau*i/n;c=math.cos(a);q=math.sin(a)
        verts.append((math.copysign(hx-r,c)+r*c,y,.235+math.copysign(hz-r,q)+r*q))
faces=[]
for j in range(len(rings)):
    for i in range(n): faces.append((j*n+i,j*n+(i+1)%n,((j+1)%len(rings))*n+(i+1)%n,((j+1)%len(rings))*n+i))
mesh('HollowCistern',verts,faces,glaze,fixed)
cover=group('CisternCover',(0,.817,.235))
rounded_box('RemovableCisternLid',(0,.817,.235),(.475,.025,.235),glaze,cover,bevel=.009)
pipe('FlushConnection',[(0,.51,.235),(0,.38,.235),(0,.29,.11)],.029,glaze,fixed)
pipe('SupplyPipe',[(-.14,.52,.24),(-.14,.23,.31),(-.14,.23,.35)],.008,nickel,fixed)
cyl('SupplyShutoff',(-.14,.23,.32),.017,.028,nickel,(0,0,1),fixed)
for x in [-.092,.092]:
    cyl('FloorBolt',(x,.048,-.15),.012,.012,nickel,parent=fixed)
    cyl('SeatHingeBarrel',(x,.437,.105),.010,.048,nickel,(1,0,0),fixed)
# Raised lid is a separate editable rigid component, leaving the seat aperture open.
lid=group('RaisedLid',(0,.44,.108))
lid_mesh=oval_shell('Lid',[(.001,.001,.448,-.13),(.191,.255,.448,-.13),
    (.200,.263,.456,-.13),(.191,.255,.464,-.13),(.001,.001,.464,-.13)],wood,lid)
for face in lid_mesh.data.polygons:
    if abs(face.normal.z)>.99:face.use_smooth=False
lid.rotation_euler.x=math.radians(82)
lever=group('CisternHandle',(.25,.64,.12))
cyl('HandleRose',(.215,.64,.118),.017,.010,nickel,(0,0,1),fixed)
pipe('FlushLever',[(.215,.64,.105),(.25,.64,.097),(.335,.64,.098)],.007,nickel,lever)
# Period ball-cock and lift-ball discharge, independently articulated.
# Form references: US1551808A (1925) and US1190917A (1916); no image projection.
pipe('InletRiser',[(-.17,.52,.275),(-.17,.746,.275)],.008,brass,fixed)
cyl('InletValveBody',(-.17,.748,.275),.017,.045,brass,(1,0,0),fixed)
float_arm=group('FloatArm',(-.17,.748,.275))
pipe('FloatRod',[(-.17,.748,.275),(-.03,.728,.275),(.08,.725,.275)],.0032,brass,float_arm)
bpy.ops.mesh.primitive_uv_sphere_add(segments=48,ring_count=24,radius=.040,location=p((.08,.725,.275)))
finish(bpy.context.object,'BallFloat',brass,float_arm)
# Open overflow bore, not a capped cylinder.
def tube(name,at,r,wall,h,mat,parent):
    points=[];sides=48
    for rr,y in [(r,at[1]),(r,at[1]+h),(r-wall,at[1]+h),(r-wall,at[1])]:
        for i in range(sides):
            a=math.tau*i/sides;points.append((at[0]+rr*math.cos(a),y,at[2]+rr*math.sin(a)))
    fs=[]
    for j in range(4):
        for i in range(sides):fs.append((j*sides+i,j*sides+(i+1)%sides,((j+1)%4)*sides+(i+1)%sides,((j+1)%4)*sides+i))
    return mesh(name,points,fs,mat,parent)
tube('OverflowStandpipe',(.145,.523,.29),.017,.002,.258,brass,fixed)
tube('DischargeSeat',(.075,.526,.205),.033,.004,.010,brass,fixed)
flush_ball=group('FlushBall',(.075,.558,.205))
bpy.ops.mesh.primitive_uv_sphere_add(segments=40,ring_count=20,radius=.032,location=p((.075,.558,.205)))
finish(bpy.context.object,'RubberFlushBall',rubber,flush_ball)
cyl('LiftRod',(.075,.602,.205),.0025,.088,brass,parent=flush_ball)
pipe('HandleInsideArm',[(.25,.64,.12),(.20,.64,.205),(.075,.64,.205)],.004,brass,lever)
for x in [-.012,.012]:
    pipe('LiftGuide',[(.075+x,.526,.205),(.075+x,.645,.205),(.075,.645,.205)],.002,brass,fixed)
cistern_water=group('CisternWaterSurface',(0,.745,.235))
rounded_box('StoredWater',(0,.745,.235),(.421,.002,.185),material('WaterSeal',(.40,.48,.43),0,.2),cistern_water,bevel=.005)
# The water seal has its own ordinary transparent surface; no animation authority.
water=material('WaterSeal',(.40,.48,.43),0,.2)
oval_shell('WaterSeal',[(.001,.001,.221,-.08),(.07,.081,.221,-.08),
    (.07,.081,.219,-.08),(.001,.001,.219,-.08)],water)
apply();save('bath_water_closet')

