"""Unit-opening double-hung window framing; wall depth is .35 m at source scale."""
from pathlib import Path
import bpy
ROOT=Path(__file__).resolve().parents[3]
bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)
mat=bpy.data.materials.new('trim'); mat.use_nodes=True
s=mat.node_tree.nodes['Principled BSDF']; s.inputs['Base Color'].default_value=(.72,.69,.60,1); s.inputs['Roughness'].default_value=.5
def mesh(name,verts,faces):
    data=bpy.data.meshes.new(name); data.from_pydata([(x,-z,y) for x,y,z in verts],[],faces); data.update()
    obj=bpy.data.objects.new(name,data); bpy.context.collection.objects.link(obj); data.materials.append(mat)
    return obj
def ring(name,profile,cy=0):
    vertices=[(sx*x,cy+sy*y,z) for x,y,z in profile for sx,sy in [(-1,-1),(1,-1),(1,1),(-1,1)]]
    faces=[]
    for j in range(len(profile)):
        for i in range(4): faces.append((j*4+i,j*4+(i+1)%4,((j+1)%len(profile))*4+(i+1)%4,((j+1)%len(profile))*4+i))
    return mesh(name,vertices,faces)
ring('RebatedFrame',[(.535,.535,-.175),(.535,.535,.175),(.525,.525,.185),(.5,.5,.185),(.485,.485,.178),(.465,.465,.178),(.465,.465,-.178),(.485,.485,-.178),(.5,.5,-.185),(.525,.525,-.185)])
for cy in [-.2375,.2375]:
    ring('SashFrame',[(.465,.2275,-.024),(.465,.2275,.024),(.46,.2225,.026),(.44,.2025,.026),(.44,.2025,-.026),(.46,.2225,-.026)],cy)
bpy.ops.mesh.primitive_cube_add(size=1)
o=bpy.context.object; o.name='MeetingRail'; o.dimensions=(.93,.060,.035); o.data.materials.append(mat)
bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
profile=[(-.24,-.545),(-.175,-.535),(.175,-.535),(.24,-.545),(.24,-.565),(-.24,-.565)]
verts=[(x,y,z) for x in [-.57,.57] for z,y in profile]
n=len(profile); faces=[tuple(reversed(range(n))),tuple(range(n,2*n))]
faces += [(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
mesh('WeatheredSill',verts,faces)
for o in list(bpy.context.scene.objects):
    bpy.ops.object.select_all(action='DESELECT'); o.select_set(True); bpy.context.view_layer.objects.active=o
    bpy.ops.object.mode_set(mode='EDIT'); bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.mesh.normals_make_consistent(inside=False); bpy.ops.uv.smart_project(island_margin=.01)
    bpy.ops.object.mode_set(mode='OBJECT')
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'art/blender/window_joinery.blend'))
bpy.ops.object.select_all(action='SELECT'); bpy.context.view_layer.objects.active=bpy.context.selected_objects[0]
bpy.ops.object.join(); bpy.context.object.name='WindowJoinery'
bpy.ops.export_scene.gltf(filepath=str(ROOT/'game/assets/props/window_joinery.glb'),export_format='GLB',export_yup=True,export_apply=True)
