"""Lobby benches and parcel racks; Godot metres, no lettering."""
from pathlib import Path
import math, random
import bpy, bmesh
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[3]
bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)
COLORS={'Oak':(.35,.23,.12),'Iron':(.15,.14,.13),'Paper':(.69,.64,.51),
        'RedCloth':(.25,.095,.07),'GreenCloth':(.13,.19,.11),'BlueCloth':(.11,.14,.20), 'Pine':(.44,.31,.17),
        'Kraft':(.42,.30,.18),'Twine':(.62,.55,.40),'Brass':(.55,.42,.20),'Book':(.12,.16,.24)}
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

def cyl(name,at,radius,depth,owner,role,axis='y'):
    bpy.ops.mesh.primitive_cylinder_add(vertices=32,radius=radius,depth=depth,location=point(at));obj=bpy.context.object
    if axis=='z':
        obj.rotation_euler=(math.pi/2,0,0);bpy.ops.object.transform_apply(location=False,rotation=True,scale=False)
    return finish(obj,name,role,owner,0)

def parcel(owner,x,y,z,w,h,d):
    # String-tied brown paper: twine crosses the top and runs down every face; a blank slip sits on top.
    box('Parcel',(x,y+h/2,z),(w,h,d),owner,'Kraft',.003)
    box('TwineLong',(x,y+h/2,z),(w+.004,h+.004,.006),owner,'Twine',0)
    box('TwineCross',(x,y+h/2,z),(.006,h+.004,d+.004),owner,'Twine',0)
    box('Slip',(x+w*.22,y+h+.0015,z-d*.18),(.075,.003,.048),owner,'Paper',0)

def crate(owner,x,y,z,w,h,d):
    # An auction-room crate: slatted pine on end boards, a nailed lid, one twine and its slip.
    box('CrateBody',(x,y+h/2,z),(w-.02,h-.02,d-.02),owner,'Pine',.002)
    for i in range(3):
        sy=y+.03+i*(h-.06)/2
        box('CrateSlatF',(x,sy,z-d/2+.006),(w,.05,.012),owner,'Pine',.002)
        box('CrateSlatB',(x,sy,z+d/2-.006),(w,.05,.012),owner,'Pine',.002)
    for sx in [x-w/2+.006,x+w/2-.006]:box('CrateEnd',(sx,y+h/2,z),(.012,h,d),owner,'Pine',.002)
    box('CrateLid',(x,y+h-.006,z),(w,.012,d),owner,'Pine',.002)
    box('CrateTwine',(x,y+h/2,z),(.006,h+.004,d+.004),owner,'Twine',0)
    box('Slip',(x+w*.2,y+h+.0015,z),(.075,.003,.048),owner,'Paper',0)

def envelopes(owner,x,y,z):
    for i in range(6):box('Envelope',(x+(i%2)*.004,y+.004+i*.008,z),(.24,.008,.16),owner,'Paper',0)
    box('BundleTwine',(x,y+.025,z),(.006,.054,.164),owner,'Twine',0)

def ledgerbook(owner,x,y,z):
    box('BookLower',(x,y+.002,z),(.30,.004,.22),owner,'Book',.001)
    box('BookUpper',(x,y+.043,z),(.30,.004,.22),owner,'Book',.001)
    box('BookSpine',(x,y+.0225,z+.106),(.30,.045,.008),owner,'Book',.001)
    box('BookPages',(x,y+.0225,z-.003),(.29,.037,.21),owner,'Paper',0)

def springscale(owner,x,y,z):
    box('ScaleBase',(x,y+.015,z),(.22,.03,.18),owner,'Iron',.003)
    box('ScaleColumn',(x,y+.115,z+.05),(.05,.17,.05),owner,'Iron',.002)
    cyl('ScalePan',(x,y+.206,z+.02),.10,.012,owner,'Brass')
    cyl('ScaleDial',(x,y+.12,z+.005),.07,.045,owner,'Brass','z')
    cyl('ScaleFace',(x,y+.12,z-.0185),.06,.003,owner,'Paper','z')
    box('ScaleNeedle',(x+.008,y+.135,z-.0205),(.004,.05,.0015),owner,'Iron',0)

def stamppad(owner,x,y,z):
    box('PadTin',(x,y+.007,z),(.11,.014,.07),owner,'Iron',.001)
    box('PadFelt',(x,y+.016,z),(.096,.004,.056),owner,'RedCloth',0)
    box('PadLid',(x,y+.049,z+.0365),(.11,.07,.003),owner,'Iron',0)
    box('StampBlock',(x+.1,y+.0125,z),(.04,.025,.03),owner,'Iron',.001)
    cyl('StampHandle',(x+.1,y+.0525,z),.011,.055,owner,'Pine')


bench=root('LobbyBench')
# Three-person slatted oak bench, 1.8 m long, with mortised rails and arms.
for z in [-.18,-.06,.06,.18]: box('SeatSlat',(0,.455,z),(1.80,.035,.112),bench,bevel=.005)
for x in [-.76,.76]:
    for z in [-.17,.17]: box('Leg',(x,.217,z),(.058,.434,.058),bench,bevel=.003)
    box('SeatBearer',(x,.407,0),(.063,.06,.48),bench)
    beam('BackPost',(x,.35,.185),(x,.97,.255),.048,.048,bench)
    box('ArmPost',(x,.555,-.17),(.043,.22,.043),bench)
    box('ArmRest',(x,.69,.035),(.075,.033,.49),bench,bevel=.012)
    box('EndStretcher',(x,.18,0),(.04,.045,.39),bench)
for z in [-.17,.17]: box('SeatApron',(0,.395,z),(1.52,.074,.03),bench)
box('LongStretcher',(0,.18,0),(1.53,.045,.04),bench)
for y in [.60,.73,.86]:
    box('BackSlat',(0,y,.185+(y-.35)*.07/.62),(1.57,.105,.026),bench,bevel=.004)
for x in [-.76,.76]:
    for z in [-.193,.193]: box('MortisePeg',(x,.393,z),(.012,.014,.003),bench,'Iron',.001)
rack=root('ParcelRack')
# 0.45 m deep, fixed shelves on housed bearers with rear cross-bracing.
for x in [-.78,.78]:
    for z in [-.196,.196]:box('RackUpright',(x,.95,z),(.045,1.9,.045),rack,'Pine')
    for y in [.16,.62,1.08,1.54]:box('ShelfBearer',(x,y-.028,0),(.045,.04,.41),rack,'Pine')
for y in [.16,.62,1.08,1.54]:
    for z in [-.147,0,.147]:box('ShelfBoard',(0,y,z),(1.60,.026,.143),rack,'Pine')
    box('RearLip',(0,y+.036,.205),(1.58,.046,.022),rack,'Pine')
beam('RearBraceA',(-.78,.1,.223),(.78,1.87,.223),.035,.012,rack,'Iron')
beam('RearBraceB',(.78,.1,.237),(-.78,1.87,.237),.035,.012,rack,'Iron')
for x in [-.78,.78]:
    for y in [.16,.62,1.08,1.54]:box('BoltHead',(x,y-.03,-.224),(.012,.012,.006),rack,'Iron',.001)
# Parcel-room dressing (V2 environment dossier F01_PACKAGE-001): eight parcels by size,
# 2A's caption envelopes, the parcel book, a spring scale and a stamp pad. Each rack has
# its own load so the two racks never repeat; the runtime seats a load in its rack's body.
load_east=root('ParcelLoadEast')
for x,y,z,w,h,d in [(-.40,.173,-.01,.48,.30,.34),(.28,.173,0,.36,.22,.28),(-.45,.633,0,.30,.20,.24),
                    (-.10,.633,-.03,.20,.14,.16),(.20,.633,.02,.24,.12,.20),(.45,1.553,0,.26,.16,.22)]:
    parcel(load_east,x,y,z,w,h,d)
load_north=root('ParcelLoadNorth')
crate(load_north,.35,.173,0,.50,.28,.34)
parcel(load_north,-.40,.633,0,.34,.20,.26)
envelopes(load_north,.25,.633,-.02)
ledgerbook(load_north,-.40,1.093,-.02)
stamppad(load_north,-.05,1.093,-.06)
springscale(load_north,.42,1.093,0)
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
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'art/blender/public_furnishings.blend'))
for owner in [bench,rack,load_east,load_north]:
    for role,mat in mats.items():
        parts=[o for o in owner.children if o.type=='MESH' and o.data.materials[0]==mat]
        if not parts:continue
        bpy.ops.object.select_all(action='DESELECT')
        for o in parts:o.select_set(True)
        bpy.context.view_layer.objects.active=parts[0];bpy.ops.object.join()
        obj=bpy.context.object;obj.name=owner.name+'_'+role
        bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
bpy.ops.object.select_all(action='SELECT')
bpy.ops.export_scene.gltf(filepath=str(ROOT/'game/assets/props/public_furnishings.glb'),export_format='GLB',export_yup=True,export_apply=True)
