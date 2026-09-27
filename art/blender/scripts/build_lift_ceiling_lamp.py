"""Ceiling-seated brass fixture with a turned opal bowl and retaining hardware."""
from pathlib import Path
import math
import bpy
ROOT=Path(__file__).resolve().parents[3]
bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)
def material(name,color,metal,rough):
    m=bpy.data.materials.new(name); m.use_nodes=True
    s=m.node_tree.nodes['Principled BSDF']; s.inputs['Base Color'].default_value=(*color,1)
    s.inputs['Metallic'].default_value=metal; s.inputs['Roughness'].default_value=rough
    return m
brass=material('brass_bright',(.62,.50,.26),.85,.34)
opal=material('enamel',(.92,.90,.84),0,.22)
def lathe(name,profile,mat):
    # Closed radial/height profile spun about Godot Y, at the existing lamp centre.
    n=96; vertices=[]; faces=[]
    for radius,y in profile:
        for i in range(n):
            a=math.tau*i/n
            vertices.append((radius*math.cos(a),-(.02+radius*math.sin(a)),y))
    for j in range(len(profile)):
        for i in range(n):
            a=j*n+i; b=j*n+(i+1)%n; c=((j+1)%len(profile))*n+(i+1)%n; d=((j+1)%len(profile))*n+i
            faces.append((a,b,c,d))
    data=bpy.data.meshes.new(name); data.from_pydata(vertices,[],faces); data.update()
    obj=bpy.data.objects.new(name,data); bpy.context.collection.objects.link(obj); data.materials.append(mat)
    return obj
lathe('CeilingPlate',[(.001,2.240),(.253,2.240),(.258,2.236),(.258,2.230),(.250,2.226),(.001,2.226)],brass)
lathe('SteppedBezel',[(.225,2.226),(.249,2.226),(.249,2.216),(.244,2.212),(.244,2.202),(.235,2.197),(.222,2.197),(.222,2.205),(.225,2.209)],brass)
lathe('OpalBowl',[(.224,2.207),(.223,2.196),(.210,2.181),(.184,2.164),(.145,2.149),(.094,2.137),(.040,2.130),(.001,2.128),(.001,2.134),(.040,2.136),(.094,2.143),(.145,2.155),(.184,2.170),(.207,2.187),(.216,2.199),(.216,2.207)],opal)
for i in range(3):
    a=math.tau*i/3
    bpy.ops.mesh.primitive_cube_add(size=1,location=(.237*math.cos(a),-(.02+.237*math.sin(a)),2.198))
    o=bpy.context.object; o.name='RetainingClip'+str(i); o.dimensions=(.033,.017,.012); o.rotation_euler.z=-a
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True); o.data.materials.append(brass)
    bevel=o.modifiers.new('Rounded strap edges','BEVEL'); bevel.width=.002; bevel.segments=3
    bpy.context.view_layer.objects.active=o; bpy.ops.object.modifier_apply(modifier=bevel.name)
    bpy.ops.mesh.primitive_cylinder_add(vertices=32,radius=.007,depth=.004,location=(.245*math.cos(a),-(.02+.245*math.sin(a)),2.190))
    screw=bpy.context.object; screw.name='SlottedScrew'+str(i); screw.data.materials.append(brass)
    bpy.ops.mesh.primitive_cube_add(size=1,location=(.245*math.cos(a),-(.02+.245*math.sin(a)),2.188))
    cutter=bpy.context.object; cutter.dimensions=(.010,.0015,.002); cutter.rotation_euler.z=-a
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    bpy.context.view_layer.objects.active=screw
    mod=screw.modifiers.new('Driver slot','BOOLEAN'); mod.operation='DIFFERENCE'; mod.object=cutter
    bpy.ops.object.modifier_apply(modifier=mod.name); bpy.data.objects.remove(cutter,do_unlink=True)
for o in list(bpy.context.scene.objects):
    bpy.ops.object.select_all(action='DESELECT'); o.select_set(True); bpy.context.view_layer.objects.active=o
    bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
    bpy.ops.object.mode_set(mode='EDIT'); bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.mesh.normals_make_consistent(inside=False); bpy.ops.uv.smart_project(island_margin=.01)
    bpy.ops.object.mode_set(mode='OBJECT')
    if o.name=='OpalBowl':
        for polygon in o.data.polygons: polygon.use_smooth=True
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'art/blender/lift_ceiling_lamp.blend'))
bpy.ops.export_scene.gltf(filepath=str(ROOT/'game/assets/props/lift_ceiling_lamp.glb'),export_format='GLB',export_yup=True,export_apply=True)

