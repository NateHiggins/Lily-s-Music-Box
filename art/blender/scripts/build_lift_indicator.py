"""Shallow half-round lift indicator, Godot -Z front; no baked lettering."""
from pathlib import Path
import math
import bpy
ROOT=Path(__file__).resolve().parents[3]
bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)
def material(name,color,metal,rough):
    m=bpy.data.materials.new(name); m.use_nodes=True
    s=m.node_tree.nodes['Principled BSDF']
    s.inputs['Base Color'].default_value=(*color,1)
    s.inputs['Metallic'].default_value=metal; s.inputs['Roughness'].default_value=rough
    return m
brass=material('brass_bright',(.62,.50,.26),.85,.34)
enamel=material('indicator_enamel',(.88,.84,.75),0,.24)
black=material('bakelite_black',(.14,.12,.11),0,.28)
def outline(radius,bottom):
    return [(-radius,bottom),(radius,bottom)]+[(radius*math.cos(math.pi*i/64),radius*math.sin(math.pi*i/64)) for i in range(65)]
def mesh(name,vertices,faces,mat):
    data=bpy.data.meshes.new(name); data.from_pydata([(x,-z,y) for x,y,z in vertices],[],faces); data.update()
    obj=bpy.data.objects.new(name,data); bpy.context.collection.objects.link(obj); data.materials.append(mat)
    return obj
outer=outline(.18,-.022); inner=outline(.162,-.013); n=len(outer)
verts=[(x,y,z) for ring,z in [(outer,0),(outer,-.033),(inner,-.033),(inner,0)] for x,y in ring]
faces=[]
for ring in range(4):
    next_ring=(ring+1)%4
    for i in range(n):
        j=(i+1)%n
        faces.append((ring*n+i,ring*n+j,next_ring*n+j,next_ring*n+i))
mesh('IndicatorCase',verts,faces,brass)
def solid(name,points,back,front,mat):
    count=len(points)
    verts=[(x,y,z) for z in [back,front] for x,y in points]
    faces=[tuple(reversed(range(count))),tuple(range(count,count*2))]
    faces += [(i,(i+1)%count,(i+1)%count+count,i+count) for i in range(count)]
    return mesh(name,verts,faces,mat)
solid('IndicatorFace',outline(.1618,-.0128),-.006,-.030,enamel)
solid('IndicatorNeedle',[(-.005,-.012),(.005,-.012),(.005,.084),(.009,.084),(0,.112),(-.009,.084),(-.005,.084)],.003,-.003,black)
mounts=[]
for x in [-.105,.105]:
    for y,r,depth in [(.1675,.0045,.055),(.1935,.0125,.003)]:
        bpy.ops.mesh.primitive_cylinder_add(vertices=40,radius=r,depth=depth,location=(x,-(-.006),y))
        o=bpy.context.object; o.data.materials.append(brass); mounts.append(o)
bpy.ops.object.select_all(action='DESELECT')
for o in mounts: o.select_set(True)
bpy.context.view_layer.objects.active=mounts[0]; bpy.ops.object.join()
o=bpy.context.object; o.name='CeilingMounts'
bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
bpy.ops.mesh.primitive_cylinder_add(vertices=48,radius=.010,depth=.006,rotation=(math.pi/2,0,0))
o=bpy.context.object; o.name='PivotCap'; o.data.materials.append(brass)
bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
bpy.ops.mesh.primitive_cube_add(size=1)
o=bpy.context.object; o.name='Tick'; o.dimensions=(.002,.002,.008); o.data.materials.append(black)
bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
for o in list(bpy.context.scene.objects):
    if o.type!='MESH': continue
    bpy.ops.object.select_all(action='DESELECT'); o.select_set(True); bpy.context.view_layer.objects.active=o
    bpy.ops.object.mode_set(mode='EDIT'); bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.mesh.normals_make_consistent(inside=False); bpy.ops.uv.smart_project(island_margin=.01)
    bpy.ops.object.mode_set(mode='OBJECT')
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'art/blender/lift_indicator.blend'))
bpy.ops.export_scene.gltf(filepath=str(ROOT/'game/assets/props/lift_indicator.glb'),export_format='GLB',export_yup=True,export_apply=True)
