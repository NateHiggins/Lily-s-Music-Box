"""Lobby benches and parcel racks; Godot metres, no lettering."""
from pathlib import Path
import math, random
import bpy, bmesh
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[3]
bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)
COLORS={'Oak':(.35,.23,.12),'Iron':(.15,.14,.13),'Paper':(.69,.64,.51),
        'RedCloth':(.25,.095,.07),'GreenCloth':(.13,.19,.11),'BlueCloth':(.11,.14,.20), 'Pine':(.44,.31,.17)}
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
for owner in [bench,rack]:
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
