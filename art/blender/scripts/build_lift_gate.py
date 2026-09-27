"""Blender fabrication library for the V2 articulated car gate."""
from pathlib import Path
import math
import bpy
ROOT=Path(__file__).resolve().parents[3]
bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)
mat=bpy.data.materials.new('brass_bright'); mat.use_nodes=True
s=mat.node_tree.nodes['Principled BSDF']
s.inputs['Base Color'].default_value=(.62,.50,.26,1)
s.inputs['Metallic'].default_value=.85; s.inputs['Roughness'].default_value=.34
def finish(o,name,radius):
    o.name=name; o.data.materials.append(mat)
    bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
    if radius:
        m=o.modifiers.new('Machined edge radius','BEVEL'); m.width=radius; m.segments=3
        bpy.ops.object.modifier_apply(modifier=m.name)
    return o
bpy.ops.mesh.primitive_cube_add(size=1)
o=bpy.context.object; o.dimensions=(.012,.004,1)
finish(o,'GateLink',.0007)
# Flanged pivot: the spindle spans both staggered bar layers, capped on each
# side by a rounded head. It is never scaled with the changing lattice span.
parts=[]
for z,r,depth in [(0,.0028,.014),(-.008,.0055,.003),(.008,.0055,.003)]:
    bpy.ops.mesh.primitive_cylinder_add(vertices=32,radius=r,depth=depth,
        location=(0,-z,0),rotation=(math.pi/2,0,0))
    parts.append(finish(bpy.context.object,'PivotPart',.0004))
bpy.ops.object.select_all(action='DESELECT')
for o in parts: o.select_set(True)
bpy.context.view_layer.objects.active=parts[0]; bpy.ops.object.join()
bpy.context.object.name='GatePivot'
# Open channel cross section, normalized in X only. The lower rail is raised
# to the old 180 mm rail position, outside the walking floor's ownership.
section=[(-.014,-.01),(.014,-.01),(.014,.01),(.009,.01),(.009,-.005),(-.009,-.005),(-.009,.01),(-.014,.01)]
n=len(section)
vertices=[(x,-z,y) for x in [-.5,.5] for y,z in section]
faces=[tuple(reversed(range(n))),tuple(range(n,n*2))]+[(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
mesh=bpy.data.meshes.new('GateTrack'); mesh.from_pydata(vertices,[],faces); mesh.update()
o=bpy.data.objects.new('GateTrack',mesh); bpy.context.collection.objects.link(o)
bpy.context.view_layer.objects.active=o; finish(o,'GateTrack',0)
for o in list(bpy.context.scene.objects):
    if o.type!='MESH': continue
    bpy.ops.object.select_all(action='DESELECT'); o.select_set(True)
    bpy.context.view_layer.objects.active=o
    bpy.ops.object.mode_set(mode='EDIT'); bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.mesh.normals_make_consistent(inside=False); bpy.ops.uv.smart_project(island_margin=.01)
    bpy.ops.object.mode_set(mode='OBJECT')
    for face in o.data.polygons: face.use_smooth=True
    m=o.modifiers.new('Weighted normals','WEIGHTED_NORMAL'); m.keep_sharp=True
    bpy.ops.object.modifier_apply(modifier=m.name)
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'art/blender/lift_gate.blend'))
bpy.ops.export_scene.gltf(filepath=str(ROOT/'game/assets/props/lift_gate.glb'),export_format='GLB',export_yup=True,export_apply=True)

